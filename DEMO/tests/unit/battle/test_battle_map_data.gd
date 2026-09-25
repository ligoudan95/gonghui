## 战斗域数据表单元测试（M1 批 1）
## 覆盖：新表结构（tile_×6/btm_×2/eqp_×6 + 回填 3 张队伍 + naming_registry 62 条）
## 与 V-M1-* 六条校验（断链注入 → 报错 → 恢复归零，仿 M0 test_data_validator 写法）。
extends GdUnitTestSuite

## GameData 自动加载脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 实例
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData 并显式初始化（gdUnit CI 运行器不注册 autoload）
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

func test_domain_counts() -> void:
	## 新三域计数：地格 6 / 地图 2 / 装备 6；全库总数 63（49 + 14）
	assert_int(_game_data.get_domain(&"battle/tiles").size()).is_equal(6)
	assert_int(_game_data.get_domain(&"battle/maps").size()).is_equal(2)
	assert_int(_game_data.get_domain(&"equip").size()).is_equal(6)
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report.checked_count).is_equal(92)

func test_tile_bindings() -> void:
	## 地格绑定：草丛/高地/毒沼绑定对应状态（allowed_sources 含 TILE）；
	## 陷阱无状态绑定 + ENEMY_ENTER_ONCE；障碍不可通行；全表 description 非空
	## （hover tooltip 文案入表——2026-09-24 试玩反馈，UI 零硬编码文案）
	var grass: TileTypeDef = _game_data.get_record(&"tile_grass")
	assert_str(String(grass.status_id)).is_equal("BUFF_tile_grass")
	var highground: TileTypeDef = _game_data.get_record(&"tile_highground")
	assert_str(String(highground.status_id)).is_equal("BUFF_tile_highground")
	var poison: TileTypeDef = _game_data.get_record(&"tile_poison_swamp")
	assert_str(String(poison.status_id)).is_equal("DEBUFF_tile_poison")
	var trap: TileTypeDef = _game_data.get_record(&"tile_trap")
	assert_str(String(trap.status_id)).is_empty()
	assert_int(trap.trigger).is_equal(TileTypeDef.Trigger.ENEMY_ENTER_ONCE)
	var obstacle: TileTypeDef = _game_data.get_record(&"tile_obstacle")
	assert_bool(obstacle.walkable).is_false()
	assert_bool(_game_data.get_record(&"tile_normal").walkable).is_true()
	for tile_id: StringName in [&"tile_normal", &"tile_obstacle", &"tile_grass",
			&"tile_highground", &"tile_poison_swamp", &"tile_trap"]:
		var tile: TileTypeDef = _game_data.get_record(tile_id)
		assert_str(tile.description) \
				.override_failure_message("地格 %s 缺 description（tooltip 文案入表）" % tile_id) \
				.is_not_empty()

func test_map_structure() -> void:
	## 地图结构：8×8/10×10 尺寸与行数、出生位 4+4、出生位全可通行
	var random_map: BattleMapDef = _game_data.get_record(&"btm_m1_random_8x8")
	assert_int(random_map.size.x).is_equal(8)
	assert_int(random_map.size.y).is_equal(8)
	assert_int(random_map.rows.size()).is_equal(8)
	assert_int(random_map.player_spawns.size()).is_equal(4)
	assert_int(random_map.enemy_spawns.size()).is_equal(4)
	var lair_map: BattleMapDef = _game_data.get_record(&"btm_m1_lair_10x10")
	assert_int(lair_map.size.x).is_equal(10)
	assert_int(lair_map.size.y).is_equal(10)
	assert_int(lair_map.rows.size()).is_equal(10)
	assert_int(lair_map.player_spawns.size()).is_equal(4)
	for map_id: StringName in [&"btm_m1_random_8x8", &"btm_m1_lair_10x10"]:
		var map_def: BattleMapDef = _game_data.get_record(map_id)
		var spawn_cells: Array = map_def.player_spawns + Array(map_def.enemy_spawns)
		for cell: Vector2i in spawn_cells:
			var char_key: String = map_def.rows[cell.y][cell.x]
			var tile: TileTypeDef = _game_data.get_record(map_def.legend[char_key]) as TileTypeDef
			assert_bool(tile.walkable) \
					.override_failure_message("出生位 (%d,%d) 不可通行（%s）" % [cell.x, cell.y, map_id]).is_true()

func test_pack_map_refs_backfilled() -> void:
	## 队伍地图引用回填：随机→8×8 / 巢穴→10×10 / 魔宠巢→8×8（复用）
	assert_str(String((_game_data.get_record(&"enc_m1_random_pack") as EnemyPackDef).battle_map_ref)).is_equal("btm_m1_random_8x8")
	assert_str(String((_game_data.get_record(&"enc_m1_lair_pack") as EnemyPackDef).battle_map_ref)).is_equal("btm_m1_lair_10x10")
	assert_str(String((_game_data.get_record(&"enc_m1_wisp_nest") as EnemyPackDef).battle_map_ref)).is_equal("btm_m1_random_8x8")

func test_equip_values() -> void:
	## 装备数值（17 案 §3.4 武器加值行 + §3.11 #7）：战 4/5 盗 3/3 游 3/2 法 2/1 牧 2/1 奇 2/1
	var expects: Dictionary = {
		&"eqp_init_warrior": [4, 5, &"cls_warrior"],
		&"eqp_init_rogue": [3, 3, &"cls_rogue"],
		&"eqp_init_ranger": [3, 2, &"cls_ranger"],
		&"eqp_init_mage": [2, 1, &"cls_mage"],
		&"eqp_init_priest": [2, 1, &"cls_priest"],
		&"eqp_init_arcanist": [2, 1, &"cls_arcanist"],
	}
	for equip_id: StringName in expects:
		var equip: EquipDef = _game_data.get_record(equip_id)
		assert_int(equip.weapon_bonus).is_equal(expects[equip_id][0])
		assert_int(equip.armor_value).is_equal(expects[equip_id][1])
		assert_str(String(equip.class_ref)).is_equal(String(expects[equip_id][2]))

func test_naming_registry_extended() -> void:
	## 命名登记表：62 条（48 + 14），新资源全部登记且含域前缀规则注
	var registry: NamingRegistry = _game_data.get_record(&"naming_registry")
	assert_int(registry.entries.size()).is_equal(113)
	var registered: Dictionary = {}
	for entry: NamingEntry in registry.entries:
		registered[entry.resource_id] = entry
	for resource_id: StringName in [&"btm_m1_random_8x8", &"btm_m1_lair_10x10",
			&"tile_normal", &"tile_obstacle", &"tile_grass", &"tile_highground",
			&"tile_poison_swamp", &"tile_trap",
			&"eqp_init_warrior", &"eqp_init_rogue", &"eqp_init_ranger",
			&"eqp_init_mage", &"eqp_init_priest", &"eqp_init_arcanist"]:
		assert_bool(registered.has(resource_id)) \
				.override_failure_message("资源 '%s' 未登记命名表" % resource_id).is_true()

func test_tile_visual_fields_backfilled() -> void:
	## 地格视觉表驱动断言（批 A H2）：6 张表 fill_color/style 回填且与
	## 原硬编码视觉值一致（现值搬家零变化）；RAISED/BLOCK 格 accent 回填
	var expects: Dictionary = {
		&"tile_normal": [Color(0.32, 0.36, 0.29, 1), TileTypeDef.Style.PLAIN],
		&"tile_obstacle": [Color(0.2, 0.19, 0.17, 1), TileTypeDef.Style.BLOCK],
		&"tile_grass": [Color(0.14, 0.56, 0.2, 1), TileTypeDef.Style.PLAIN],
		&"tile_highground": [Color(0.88, 0.78, 0.3, 1), TileTypeDef.Style.RAISED],
		&"tile_poison_swamp": [Color(0.42, 0.13, 0.5, 1), TileTypeDef.Style.PLAIN],
		&"tile_trap": [Color(0.32, 0.36, 0.29, 1), TileTypeDef.Style.PLAIN],
	}
	for tile_id: StringName in expects:
		var tile: TileTypeDef = _game_data.get_record(tile_id)
		assert_bool(tile.fill_color.is_equal_approx(expects[tile_id][0])) \
				.override_failure_message("%s fill_color 与回填基线不符" % tile_id).is_true()
		assert_int(tile.style).is_equal(expects[tile_id][1])
		if tile.style != TileTypeDef.Style.PLAIN:
			assert_bool(tile.accent_color.a > 0.0) \
					.override_failure_message("%s 缺 accent_color" % tile_id).is_true()

func test_sprite_ids_backfilled_and_registered() -> void:
	## sprite_id 入表断言（批 A H3）：6 职业 + 3 敌人表回填且 AssetRegistry
	## 有登记（读取链数据侧——UI 渲染经 GameData 查表消费同值）
	var sprite_ids: Array[StringName] = []
	for record: Resource in _game_data.get_domain(&"class/classes"):
		var cls := record as ClassDef
		assert_bool(String(cls.sprite_id).is_empty()) \
				.override_failure_message("%s 缺 sprite_id" % cls.id).is_false()
		sprite_ids.append(cls.sprite_id)
	for record: Resource in _game_data.get_domain(&"battle/enemies"):
		var enemy := record as EnemyDef
		assert_bool(String(enemy.sprite_id).is_empty()) \
				.override_failure_message("%s 缺 sprite_id" % enemy.id).is_false()
		sprite_ids.append(enemy.sprite_id)
	assert_int(sprite_ids.size()).is_equal(9)
	for sprite_id: StringName in sprite_ids:
		assert_bool(_game_data.get_asset_path(sprite_id).is_empty()) \
				.override_failure_message("sprite '%s' 未在 AssetRegistry 登记" % sprite_id).is_false()

func test_broken_mod_key_caught() -> void:
	## V-A-mod-keys 注入（批 A H4）：状态表 modifiers 拼错键 → 报错 → 恢复归零；
	## 技能 COMBAT_MOD 键拼错同样拦截
	var grass: StatusDef = _game_data.get_record(&"BUFF_tile_grass")
	# 修正键常量类型化取值（存取前快照恢复）
	var original_modifiers: Dictionary = grass.modifiers.duplicate()
	grass.modifiers[&"doge"] = 0.15
	var report: ValidationReport = DataValidator.run_all(_game_data)
	grass.modifiers = original_modifiers
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-A-mod-keys") and entry.contains("doge"):
			matched = true
	assert_bool(matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_content_count_band_cfg_takes_effect() -> void:
	## 计数带参数化生效（批 C M6：cfg content_* 组驱动校验带——改带值校验
	## 行为即时变化，恢复归位）：状态计数带收到 9（当前 11）→ 出警告；
	## 放宽到 99 → 无该警告
	var cfg: CoreConfig = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var original_max: int = cfg.content_status_max
	cfg.content_status_max = 9
	var tight: ValidationReport = DataValidator.run_all(_game_data)
	var tight_warned: bool = false
	for entry: String in tight.warnings:
		if entry.contains("状态计数") and entry.contains("越界"):
			tight_warned = true
	assert_bool(tight_warned).is_true()
	cfg.content_status_max = 99
	var loose: ValidationReport = DataValidator.run_all(_game_data)
	cfg.content_status_max = original_max
	for entry: String in loose.warnings:
		assert_bool(entry.contains("状态计数") and entry.contains("越界")) \
				.override_failure_message("放宽后不应再有状态计数警告").is_false()

func test_broken_equip_class_ref_caught() -> void:
	## V-B2-eq-class 注入（盲审批 2 A-1）：装备 class_ref 改不存在 id → 报错 →
	## 恢复归零；同职业双装备引用 → 唯一性报错 → 恢复
	var equip: EquipDef = _game_data.get_record(&"eqp_init_warrior")
	var original: StringName = equip.class_ref
	equip.class_ref = &"cls_nope"
	var broken: ValidationReport = DataValidator.run_all(_game_data)
	equip.class_ref = original
	var matched: bool = false
	for entry: String in broken.errors:
		if entry.begins_with("V-B2-eq-class") and entry.contains("eqp_init_warrior"):
			matched = true
	assert_bool(matched).is_true()
	# 唯一性：把法师装备的 class_ref 改成战士（职业双引用）
	var mage_equip: EquipDef = _game_data.get_record(&"eqp_init_mage")
	var mage_original: StringName = mage_equip.class_ref
	mage_equip.class_ref = &"cls_warrior"
	var duplicated: ValidationReport = DataValidator.run_all(_game_data)
	mage_equip.class_ref = mage_original
	var dup_matched: bool = false
	for entry: String in duplicated.errors:
		if entry.begins_with("V-B2-eq-class") and entry.contains("cls_warrior"):
			dup_matched = true
	assert_bool(dup_matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_pack_capacity_overflow_caught() -> void:
	## V-M1-ref-pack-map 加严注入（盲审批 2 A-3）：条目 count_max 总和超地图
	## 敌方出生位 → 报错（运行时静默截断吞兵在数据侧拦截）→ 恢复归零
	var pack: EnemyPackDef = _game_data.get_record(&"enc_m1_random_pack")
	var original: int = pack.entries[0].count_max
	pack.entries[0].count_max = 5
	var overflow: ValidationReport = DataValidator.run_all(_game_data)
	pack.entries[0].count_max = original
	var matched: bool = false
	for entry: String in overflow.errors:
		if entry.begins_with("V-M1-ref-pack-map") and entry.contains("enc_m1_random_pack"):
			matched = true
	assert_bool(matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_status_source_linkage_caught() -> void:
	## V-B2-status-src 注入（盲审批 2 A-4）：技能引用的状态 allowed_sources 不含
	## SKILL → error；零技能引用的 SKILL 状态 → warning 孤儿
	var slow: StatusDef = _game_data.get_record(&"DEBUFF_slow")
	var original: Array[StringName] = slow.allowed_sources.duplicate()
	slow.allowed_sources = [&"TILE"]
	var mismatch: ValidationReport = DataValidator.run_all(_game_data)
	slow.allowed_sources = original
	var matched: bool = false
	for entry: String in mismatch.errors:
		if entry.begins_with("V-B2-status-src") and entry.contains("DEBUFF_slow"):
			matched = true
	assert_bool(matched).is_true()
	# 孤儿 warning：把诅咒技的效果类型改 HEAL 使 curse 失去技能引用（最小注入）
	var curse_skill: SkillDef = _game_data.get_record(&"skl_arcanist_curse")
	var original_kind: int = curse_skill.effects[0].effect_kind
	curse_skill.effects[0].effect_kind = SkillEffect.EffectKind.HEAL
	var orphan: ValidationReport = DataValidator.run_all(_game_data)
	curse_skill.effects[0].effect_kind = original_kind
	var orphan_matched: bool = false
	for entry: String in orphan.warnings:
		if entry.begins_with("V-B2-status-src") and entry.contains("DEBUFF_curse"):
			orphan_matched = true
	assert_bool(orphan_matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_owner_closure_caught() -> void:
	## V-B2-owner 注入（盲审批 2 A-5）：普攻 owner 改错职业 → error → 恢复归零
	var attack: SkillDef = _game_data.get_record(&"skl_atk_warrior")
	var original_owner: StringName = attack.owner_id
	attack.owner_id = &"cls_mage"
	var wrong: ValidationReport = DataValidator.run_all(_game_data)
	attack.owner_id = original_owner
	var matched: bool = false
	for entry: String in wrong.errors:
		if entry.begins_with("V-B2-owner") and entry.contains("skl_atk_warrior"):
			matched = true
	assert_bool(matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_cfg_domain_guard_caught() -> void:
	## V-M0-cfg-domain 注入（盲审批 2 A-6）：除数置 0 / 钳制带倒序 → 报错 →
	## 恢复归零
	var cfg: CoreConfig = _game_data.get_record(CoreConfig.CFG_MAIN_ID)
	var original_divisor: int = cfg.attr_modifier_divisor
	var original_min: float = cfg.hit_clamp_min
	var original_max: float = cfg.hit_clamp_max
	cfg.attr_modifier_divisor = 0
	cfg.hit_clamp_min = 0.9
	cfg.hit_clamp_max = 0.1
	var broken: ValidationReport = DataValidator.run_all(_game_data)
	cfg.attr_modifier_divisor = original_divisor
	cfg.hit_clamp_min = original_min
	cfg.hit_clamp_max = original_max
	var divisor_matched: bool = false
	var clamp_matched: bool = false
	for entry: String in broken.errors:
		if entry.begins_with("V-M0-cfg-domain"):
			if entry.contains("attr_modifier_divisor"):
				divisor_matched = true
			if entry.contains("钳制带"):
				clamp_matched = true
	assert_bool(divisor_matched).is_true()
	assert_bool(clamp_matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_naming_registry_bidirectional_caught() -> void:
	## V-B2-naming 注入（盲审批 2 A-2 顺带）：登记条目改错域 → 域错配报错 →
	## 恢复归零（双向比对）
	var registry: NamingRegistry = _game_data.get_record(&"naming_registry")
	for entry: NamingEntry in registry.entries:
		if entry.resource_id == &"tile_grass":
			var original_domain: StringName = entry.domain
			entry.domain = &"equip"
			var mismatch: ValidationReport = DataValidator.run_all(_game_data)
			entry.domain = original_domain
			var matched: bool = false
			for record: String in mismatch.errors:
				if record.begins_with("V-B2-naming") and record.contains("tile_grass"):
					matched = true
			assert_bool(matched).is_true()
			break
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_validator_clean() -> void:
	## 全库校验零错误零警告（64 条——批 2 A-9 assets 域计入；V-M1-*/V-B2-* 全命中）
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report.errors.size()).is_equal(0)
	assert_int(report.warnings.size()).is_equal(0)
	assert_bool(report.is_ok()).is_true()

func test_broken_tile_status_binding_caught() -> void:
	## V-M1-tile-status 断链注入：草丛绑定状态改不存在 id → 报错 → 恢复归零
	var tile: TileTypeDef = _game_data.get_record(&"tile_grass")
	var original: StringName = tile.status_id
	tile.status_id = &"BUFF_nope"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	tile.status_id = original
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M1-tile-status") and entry.contains("tile_grass"):
			matched = true
	assert_bool(matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_tile_status_source_without_tile_token_caught() -> void:
	## V-M1-tile-status 来源注入：绑定 BUFF_ambush（来源 CHECKIN 不含 TILE）→ 报错
	var tile: TileTypeDef = _game_data.get_record(&"tile_grass")
	var original: StringName = tile.status_id
	tile.status_id = &"BUFF_ambush"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	tile.status_id = original
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M1-tile-status") and entry.contains("tile_grass"):
			matched = true
	assert_bool(matched).is_true()

func test_broken_map_layout_caught() -> void:
	## V-M1-map-layout 注入：legend 加非法值（'@'→tile_nope）+ 行内插非法字符
	## （'*' 不在 legend）→ 双报错 → 恢复归零
	var map_def: BattleMapDef = _game_data.get_record(&"btm_m1_random_8x8")
	var original_row: String = map_def.rows[2]
	var original_legend: Dictionary[String, StringName] = {}
	for legend_key: String in map_def.legend:
		original_legend[legend_key] = map_def.legend[legend_key]
	map_def.legend["@"] = &"tile_nope"
	map_def.rows[2] = "..*..g.X"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	map_def.rows[2] = original_row
	map_def.legend = original_legend
	var layout_errors: int = 0
	for entry: String in report.errors:
		if entry.begins_with("V-M1-map-layout") and entry.contains("btm_m1_random_8x8"):
			layout_errors += 1
	assert_int(layout_errors).is_equal(2)
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_spawn_on_obstacle_caught() -> void:
	## V-M1-map-spawns 注入：出生位移到障碍格 (2,2) → 报错 → 恢复归零
	var map_def: BattleMapDef = _game_data.get_record(&"btm_m1_random_8x8")
	var original: Vector2i = map_def.player_spawns[0]
	map_def.player_spawns[0] = Vector2i(2, 2)
	var report: ValidationReport = DataValidator.run_all(_game_data)
	map_def.player_spawns[0] = original
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M1-map-spawns") and entry.contains("btm_m1_random_8x8"):
			matched = true
	assert_bool(matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_broken_skill_tile_ref_caught() -> void:
	## V-M1-ref-skill-tile 断链注入：布置陷阱的地格引用改不存在 id → 报错 → 恢复归零
	var skill: SkillDef = _game_data.get_record(&"skl_ranger_set_trap")
	var original: StringName = skill.effects[0].tile_type_id
	skill.effects[0].tile_type_id = &"tile_nope"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	skill.effects[0].tile_type_id = original
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M1-ref-skill-tile") and entry.contains("skl_ranger_set_trap"):
			matched = true
	assert_bool(matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_empty_pack_map_ref_caught() -> void:
	## V-M1-ref-pack-map 加严注入：battle_map_ref 置空 → 报错（M1 起强制）→ 恢复归零
	var pack: EnemyPackDef = _game_data.get_record(&"enc_m1_random_pack")
	var original: StringName = pack.battle_map_ref
	pack.battle_map_ref = &""
	var report: ValidationReport = DataValidator.run_all(_game_data)
	pack.battle_map_ref = original
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M1-ref-pack-map") and entry.contains("enc_m1_random_pack"):
			matched = true
	assert_bool(matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)
