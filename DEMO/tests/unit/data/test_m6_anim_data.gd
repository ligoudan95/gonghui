## M6 批 1 数据侧单元测试：attack_pose 逐条回填契约 + V-M6 组正反
## 覆盖：23 技能姿态分布（MELEE 8/CAST 13/NONE 2）逐 id 断言；V-M6-skill-pose
## 负注入（伤害技置 NONE 必报错）；V-M0-enum 越界；V-M6-anim-quad 负注入
##（撤登记键必报错）；V-M6-anim-geometry 负注入（非 PNG 头/尺寸非法必报错）；
## 全库干净态零 V-M6 错误。注入即恢复（共享实例卫生——validator 套件先例）。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 实例
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData 并显式初始化
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

func _PoseOf(skill_id: StringName) -> int:
	## 技能姿态读取口
	## 参数 skill_id：技能 id
	## 返回：SkillDef.AttackPose
	var skill: SkillDef = _game_data.get_record(skill_id) as SkillDef
	return skill.attack_pose

func test_attack_pose_distribution_matches_plan() -> void:
	## D4=A 拍板回填分布：MELEE 8 / CAST 13 / NONE 2——逐 id 断言
	for skill_id: StringName in [&"skl_atk_warrior", &"skl_atk_rogue",
			&"skl_atk_enemy_common", &"skl_warrior_power_strike",
			&"skl_rogue_backstab", &"skl_enemy_plague_bite",
			&"skl_enemy_dirty_trick", &"skl_enemy_relentless"]:
		assert_int(_PoseOf(skill_id)).is_equal(SkillDef.AttackPose.MELEE) \
				.override_failure_message("%s 应为 MELEE" % skill_id)
	for skill_id: StringName in [&"skl_atk_mage", &"skl_atk_priest",
			&"skl_atk_arcanist", &"skl_atk_ranger", &"skl_mage_fireball",
			&"skl_mage_frost_chain", &"skl_priest_heal", &"skl_priest_smite",
			&"skl_ranger_piercing_arrow", &"skl_ranger_set_trap",
			&"skl_arcanist_curse", &"skl_arcanist_bewitch",
			&"skl_enemy_intimidating_roar"]:
		assert_int(_PoseOf(skill_id)).is_equal(SkillDef.AttackPose.CAST) \
				.override_failure_message("%s 应为 CAST" % skill_id)
	for skill_id: StringName in [&"skl_warrior_shield_wall", &"skl_rogue_sprint"]:
		assert_int(_PoseOf(skill_id)).is_equal(SkillDef.AttackPose.NONE) \
				.override_failure_message("%s 应为 NONE" % skill_id)

func test_all_skills_pose_in_enum_domain() -> void:
	## 全表枚举域：23 条 attack_pose 全部 ∈ [0, 2]
	var skills: Array[Resource] = _game_data.get_domain(&"class/skills")
	assert_int(skills.size()).is_equal(23)
	for record: Resource in skills:
		var skill := record as SkillDef
		assert_bool(skill.attack_pose >= 0
				and skill.attack_pose < SkillDef.AttackPose.size()).is_true()

func test_clean_run_has_no_vm6_errors() -> void:
	## 干净态全绿：零错误零警告（V-M6 组正态——V-A-sprite-id 收窄后不再
	## 查单图键登记）
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report.errors.size()).is_equal(0)
	assert_int(report.warnings.size()).is_equal(0)

func test_damage_skill_pose_none_is_caught() -> void:
	## V-M6-skill-pose 负注入：伤害技（挥击 damage_type=PHYSICAL）置 NONE
	## → 必报错；恢复归零
	var skill: SkillDef = _game_data.get_record(&"skl_atk_warrior") as SkillDef
	var original: int = skill.attack_pose
	skill.attack_pose = SkillDef.AttackPose.NONE
	var report: ValidationReport = DataValidator.run_all(_game_data)
	skill.attack_pose = original
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M6-skill-pose") and entry.contains("skl_atk_warrior"):
			matched = true
	assert_bool(matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_pose_enum_out_of_range_is_caught() -> void:
	## V-M0-enum 负注入：attack_pose = 99 越界必报错
	var skill: SkillDef = _game_data.get_record(&"skl_priest_heal") as SkillDef
	var original: int = skill.attack_pose
	skill.attack_pose = 99
	var report: ValidationReport = DataValidator.run_all(_game_data)
	skill.attack_pose = original
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M0-enum") and entry.contains("SkillDef.attack_pose"):
			matched = true
	assert_bool(matched).is_true()

func test_anim_quad_missing_key_is_caught() -> void:
	## V-M6-anim-quad 负注入：撤战士 hit 动作键 → 必报错（缺件 = 动作哑火）
	var registry: AssetRegistry = _game_data.get_record(&"registry") as AssetRegistry
	var original_path: String = registry.mapping[&"spr_cls_warrior_hit"]
	registry.mapping.erase(&"spr_cls_warrior_hit")
	var report: ValidationReport = DataValidator.run_all(_game_data)
	registry.mapping[&"spr_cls_warrior_hit"] = original_path
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M6-anim-quad") and entry.contains("spr_cls_warrior_hit"):
			matched = true
	assert_bool(matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_anim_geometry_non_png_is_caught() -> void:
	## V-M6-anim-geometry 负注入①：动作键改指非 PNG 文件（icon.svg）→
	## PNG 头解析失败必报错
	var registry: AssetRegistry = _game_data.get_record(&"registry") as AssetRegistry
	var original_path: String = registry.mapping[&"spr_cls_mage_downed"]
	registry.mapping[&"spr_cls_mage_downed"] = "res://icon.svg"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	registry.mapping[&"spr_cls_mage_downed"] = original_path
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M6-anim-geometry") and entry.contains("spr_cls_mage_downed"):
			matched = true
	assert_bool(matched).is_true()

func test_anim_geometry_bad_size_is_caught() -> void:
	## V-M6-anim-geometry 负注入②：动作键改指非 128 宽 PNG（插件图标 256×256
	## ——只读引用不改 addons）→ 尺寸非法必报错
	var registry: AssetRegistry = _game_data.get_record(&"registry") as AssetRegistry
	var original_path: String = registry.mapping[&"spr_cls_mage_move"]
	registry.mapping[&"spr_cls_mage_move"] = \
			"res://addons/phantom_camera/icons/phantom_camera_logo.png"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	registry.mapping[&"spr_cls_mage_move"] = original_path
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M6-anim-geometry") and entry.contains("spr_cls_mage_move"):
			matched = true
	assert_bool(matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_anim_geometry_missing_file_reported_not_skipped() -> void:
	## V-M6-anim-geometry 负注入③（中6 盲审）：登记键改指不存在文件 →
	## geometry 报「文件不存在」（与 anim-quad 双查口径统一——此前只查
	## FileAccess 且静默 continue，ResourceLoader 可见而物理缺失的件整条
	## 逃过几何校验）；恢复归零
	var registry: AssetRegistry = _game_data.get_record(&"registry") as AssetRegistry
	var original_path: String = registry.mapping[&"spr_cls_rogue_move"]
	registry.mapping[&"spr_cls_rogue_move"] = "res://assets/units/_nope_.png"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	registry.mapping[&"spr_cls_rogue_move"] = original_path
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M6-anim-geometry") and entry.contains("spr_cls_rogue_move") \
				and entry.contains("不存在"):
			matched = true
	assert_bool(matched).is_true() \
			.override_failure_message("geometry 对缺失文件静默跳过（中6 口径未统一）")
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_anim_geometry_frames_out_of_band_caught() -> void:
	## V-M6-anim-geometry 负注入④（低10 盲审）：宽 128/高 640（idle 5 帧）越
	## idle 规格带 [2, 4] → 帧数越带必报错（user:// 临时 PNG——IHDR 直读
	## 不经导入；此前帧数带无负注入红灯锚定）；恢复归零
	var oversize: Image = Image.create(SpriteResolver.ANIM_FRAME_SIZE,
			5 * SpriteResolver.ANIM_FRAME_SIZE, false, Image.FORMAT_RGBA8)
	var temp_path: String = "user://m6_oversize_idle_test.png"
	assert_int(oversize.save_png(temp_path)).is_equal(OK)
	var registry: AssetRegistry = _game_data.get_record(&"registry") as AssetRegistry
	var original_path: String = registry.mapping[&"spr_cls_warrior_idle"]
	registry.mapping[&"spr_cls_warrior_idle"] = temp_path
	var report: ValidationReport = DataValidator.run_all(_game_data)
	registry.mapping[&"spr_cls_warrior_idle"] = original_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M6-anim-geometry") and entry.contains("spr_cls_warrior_idle") \
				and entry.contains("越出规格带"):
			matched = true
	assert_bool(matched).is_true() \
			.override_failure_message("帧数越带未被拦截（低10 红灯缺失）")
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_anim_frame_bands_actions_consistent() -> void:
	## 低1（盲审）：ANIM_ACTIONS ↔ _AnimFrameBands 键集一致锚定 + 规格带数值
	## 契约（硬拷贝锚定先例 = test_asset_registry.gd ACTIONS；缺键时校验器
	## 报错不崩——防御已加，本用例锁定两清单与六带数值不漂移）
	var expected: Dictionary = {
		&"idle": Vector2i(2, 4),
		&"move": Vector2i(4, 6),
		&"melee_attack": Vector2i(2, 4),
		&"cast_ranged": Vector2i(2, 4),
		&"hit": Vector2i(1, 2),
		&"downed": Vector2i(2, 3),
	}
	var bands: Dictionary = DataValidator._AnimFrameBands()
	assert_int(bands.size()).is_equal(SpriteResolver.ANIM_ACTIONS.size())
	for action: StringName in SpriteResolver.ANIM_ACTIONS:
		assert_bool(bands.has(action)).is_true() \
				.override_failure_message("动作 '%s' 缺帧数规格带" % action)
		assert_bool(expected.has(action)).is_true()
		var band: Vector2i = bands[action]
		var want: Vector2i = expected[action]
		assert_int(band.x).is_equal(want.x) \
				.override_failure_message("动作 '%s' 带下限漂移（%d != %d）" % [action, band.x, want.x])
		assert_int(band.y).is_equal(want.y) \
				.override_failure_message("动作 '%s' 带上限漂移（%d != %d）" % [action, band.y, want.y])

func test_cfg_anim_params_positive_domain() -> void:
	## V-M0-cfg-domain 扩展负注入：ui_anim_idle_fps 置 0 → 必报错（生产表值
	## 域——测试运行态注 0 不进表不受检）
	var cfg: CoreConfig = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var original: float = cfg.ui_anim_idle_fps
	cfg.ui_anim_idle_fps = 0.0
	var report: ValidationReport = DataValidator.run_all(_game_data)
	cfg.ui_anim_idle_fps = original
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M0-cfg-domain") and entry.contains("ui_anim_idle_fps"):
			matched = true
	assert_bool(matched).is_true()

func test_cfg_move_max_steps_domain_and_fallback_anchor() -> void:
	## 低15：ui_battle_move_max_steps 值域（≤ 0 报 V-M0-cfg-domain）+ 兜底
	## 锚定（表值 != UiTheme 兜底报 V-B2-cfg-fallback）双红灯；恢复归零
	var cfg: CoreConfig = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var original: int = cfg.ui_battle_move_max_steps
	cfg.ui_battle_move_max_steps = 0
	var report: ValidationReport = DataValidator.run_all(_game_data)
	cfg.ui_battle_move_max_steps = original
	var domain_hit: bool = false
	var fallback_hit: bool = false
	for entry: String in report.errors:
		if entry.contains("ui_battle_move_max_steps"):
			if entry.begins_with("V-M0-cfg-domain"):
				domain_hit = true
			elif entry.begins_with("V-B2-cfg-fallback"):
				fallback_hit = true
	assert_bool(domain_hit).is_true()
	assert_bool(fallback_hit).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_cfg_hit_flash_peak_color_fallback_anchor() -> void:
	## 低14：ui_hit_flash_peak_color 兜底锚定（改表不奏兜底 → V-B2-cfg-fallback
	## 报错）；恢复归零
	var cfg: CoreConfig = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var original: Color = cfg.ui_hit_flash_peak_color
	cfg.ui_hit_flash_peak_color = Color(2.0, 2.0, 2.0)
	var report: ValidationReport = DataValidator.run_all(_game_data)
	cfg.ui_hit_flash_peak_color = original
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-B2-cfg-fallback") and entry.contains("ui_hit_flash_peak_color"):
			matched = true
	assert_bool(matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)
