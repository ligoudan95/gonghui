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
	assert_int(report.checked_count).is_equal(63)

func test_tile_bindings() -> void:
	## 地格绑定：草丛/高地/毒沼绑定对应状态（allowed_sources 含 TILE）；
	## 陷阱无状态绑定 + ENEMY_ENTER_ONCE；障碍不可通行
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
	assert_int(registry.entries.size()).is_equal(62)
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

func test_validator_clean() -> void:
	## 全库校验零错误零警告（63 条；V-M1-* 计数带全命中）
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
