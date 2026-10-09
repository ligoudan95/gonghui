## AssetRegistry 单位动作集登记单元测试（插队任务 + M6 批 1 扩 54 键）
## 覆盖：registry 54 条 spr_*_<action> 六动作映射可经 GameData.get_asset_path
## 取到且文件存在（M6 批 1 静态单图 ×9 退役——单图键不再登记）；
## 全库校验零错误零警告；断链注入（临时把一条映射改为不存在路径 → 必须
## 报 V-M1-ref-asset 且 to_text 含资源 id → 恢复原值后归零）。
## 说明：GameData 经脚本实例化 + 显式 initialize_data（gdUnit CI 运行器不注册 autoload）。
extends GdUnitTestSuite

## GameData 自动加载脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 9 个单位 sprite 基 id（tools/gen_unit_anim_frames.gd 同源清单）
const SPRITE_IDS: Array[StringName] = [
	&"spr_cls_warrior", &"spr_cls_rogue", &"spr_cls_mage",
	&"spr_cls_priest", &"spr_cls_ranger", &"spr_cls_arcanist",
	&"spr_en_mutant_rat", &"spr_en_goblin_miner", &"spr_en_elite_boss",
]

## 六动作后缀（SpriteResolver.ANIM_ACTIONS 同源展开——const 常量数组不能
## 引用静态属性，此处硬拷贝由 test 断言锚定一致性）
const ACTIONS: Array[StringName] = [
	&"idle", &"move", &"melee_attack", &"cast_ranged", &"hit", &"downed",
]

## 套件级 GameData 实例
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData 并显式初始化（扫描全数据域，含 assets 域 registry）
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

func test_registry_anim_entries_resolvable() -> void:
	## 54 条 spr_*_<action> 动作映射：get_asset_path 非空、指向 assets/units/
	## 下、物理文件存在；后缀序与 SpriteResolver.ANIM_ACTIONS 一致锚定
	##（M6 批 3 首批背景入库 +bg_guild_hall 1 键；M6 批 3.5a 占位资产 +63 键
	## = 62 件 PNG + ui_main_theme 主题，总数 55→118；E1 批 +12 战棋菱形
	## tile 键（矿洞 _iso 5 + 村子 _iso 7 完整版预备），118→130）
	assert_int(ACTIONS.size()).is_equal(SpriteResolver.ANIM_ACTIONS.size())
	for index: int in ACTIONS.size():
		assert_str(String(ACTIONS[index])).is_equal(String(SpriteResolver.ANIM_ACTIONS[index]))
	var registry: AssetRegistry = _game_data.get_record(&"registry") as AssetRegistry
	assert_int(registry.mapping.size()).is_equal(130)
	for sprite_id: StringName in SPRITE_IDS:
		for action: StringName in ACTIONS:
			var asset_id: StringName = StringName(String(sprite_id) + "_" + String(action))
			var path: String = _game_data.get_asset_path(asset_id)
			assert_str(path).is_not_empty()
			assert_bool(path.begins_with("res://assets/units/")).is_true()
			assert_bool(path.ends_with("%s.png" % asset_id)).is_true()
			assert_bool(FileAccess.file_exists(path)).is_true()
	# 旧静态单图键退役核销：单位基 id 不再登记（消费面全走六动作件）
	for sprite_id: StringName in SPRITE_IDS:
		assert_str(_game_data.get_asset_path(sprite_id)).is_empty()

func test_run_all_clean_with_registry() -> void:
	## 全库校验应零错误零警告（registry 加入 assets 域后计数带不变；M6 批 3.5a 后全库 144）
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report.checked_count).is_equal(144)
	assert_int(report.errors.size()).is_equal(0)
	assert_int(report.warnings.size()).is_equal(0)
	assert_bool(report.is_ok()).is_true()

func test_broken_asset_path_is_caught_and_restored() -> void:
	## 断链注入：战士 idle 动作映射改为不存在路径 → 校验必须抓到 V-M1-ref-asset
	## 错误且 to_text 含资源 id（S1-10 起原路径文件脱离映射，V-R4-asset-reverse
	## 反向规则同报；M6 批 1 起 V-M6-anim-quad 动作齐套对坏路径同报；盲审中6
	## 起 V-M6-anim-geometry 存在性口径统一双查对坏路径同报——四向命中 4 条）；
	## 恢复后归零
	var registry: AssetRegistry = _game_data.get_record(&"registry") as AssetRegistry
	assert_object(registry).is_not_null()
	var original_path: String = registry.mapping[&"spr_cls_warrior_idle"]
	registry.mapping[&"spr_cls_warrior_idle"] = "res://assets/units/spr_nope.png"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	# 立即恢复（gdUnit 断言失败不中断函数，恢复代码必达，不污染缓存共享实例）
	registry.mapping[&"spr_cls_warrior_idle"] = original_path
	assert_int(report.errors.size()).is_equal(4)
	var ref_asset_caught: bool = false
	var reverse_caught: bool = false
	var geometry_caught: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M1-ref-asset") and entry.contains("spr_cls_warrior"):
			ref_asset_caught = true
		if entry.begins_with("V-R4-asset-reverse") and entry.contains("spr_cls_warrior"):
			reverse_caught = true
		if entry.begins_with("V-M6-anim-geometry") and entry.contains("spr_cls_warrior"):
			geometry_caught = true
	assert_bool(ref_asset_caught) \
			.override_failure_message("坏路径应报 V-M1-ref-asset").is_true()
	assert_bool(reverse_caught) \
			.override_failure_message("摘映射的原文件应报 V-R4-asset-reverse").is_true()
	assert_bool(geometry_caught) \
			.override_failure_message("坏路径应报 V-M6-anim-geometry（中6 双查口径统一）").is_true()
	assert_str(report.to_text()).contains("spr_cls_warrior_idle")
	# 恢复后复查归零
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)
