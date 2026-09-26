## M3 探索层数据与校验测试（V-M3 十一组正反用例）
## 覆盖：域计数（图 1/地格 4/交互点 11/目标点 6/权重 2/区域 3/标记 1）+
## 全库 run_all 零错误零警告 + 挂起规则激活（链触发点双向/委托判据闭环）+
## 断链注入逐条（map-layout/map-points 坐标与查重/fog-lit/ref-point-event/
## ref-chain-point/ref-quest-goal/ref-region/secret-reveal/hidden-mark/
## encw-domain/treasure-domain）→ 恢复后归零。
extends GdUnitTestSuite

## GameData 自动加载脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 实例
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData 并显式初始化
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

func _RunClean() -> void:
	## 全库零错误零警告断言（正样本基线）
	## 参数：无
	## 返回：无
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report.errors.size()).is_equal(0)
	assert_int(report.warnings.size()).is_equal(0)

func _ExpectError(code: String, record_id: String) -> void:
	## 断言当前库存在指定规则错误（含记录 id）
	## 参数 code：规则码；record_id：记录 id
	## 返回：无
	var report: ValidationReport = DataValidator.run_all(_game_data)
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with(code) and entry.contains(record_id):
			matched = true
	assert_bool(matched).override_failure_message(
			"期望 %s 错误（记录 %s）未出现：%s" % [code, record_id,
					"; ".join(report.errors)]).is_true()

func test_domain_counts() -> void:
	## 域计数：探索层六域 + 隐藏标记落内容（29 条新增）
	assert_int(_game_data.get_domain(&"map/maps").size()).is_equal(1)
	assert_int(_game_data.get_domain(&"map/tiles").size()).is_equal(4)
	assert_int(_game_data.get_domain(&"map/interact_points").size()).is_equal(11)
	assert_int(_game_data.get_domain(&"map/target_points").size()).is_equal(6)
	assert_int(_game_data.get_domain(&"map/encounter_weights").size()).is_equal(2)
	assert_int(_game_data.get_domain(&"world/regions").size()).is_equal(3)
	assert_int(_game_data.get_domain(&"event/hidden_marks").size()).is_equal(1)

func test_full_library_clean() -> void:
	## 全库正样本：121 资源零错误零警告（含挂起规则激活后的链触发点/委托判据闭环）
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report.checked_count).is_equal(121)
	assert_int(report.errors.size()).is_equal(0)
	assert_int(report.warnings.size()).is_equal(0)

func test_suspended_chain_point_rule_active() -> void:
	## 挂起①激活回归：现有三链 trigger_point_id 与交互点双向回指（数据侧零新错）
	var chain: EventChainDef = _game_data.get_record(&"chain_mine_collapse") as EventChainDef
	assert_str(String(chain.trigger_point_id)).is_equal("evp_mine_01")
	var point: InteractPointDef = _game_data.get_record(&"evp_mine_01") as InteractPointDef
	assert_int(point.kind).is_equal(InteractPointDef.Kind.CHAIN)
	assert_str(String(point.ref_id)).is_equal("chain_mine_collapse")
	# 反向断链：链触发点指向非 CHAIN 点 → 双向不一致报错
	chain.trigger_point_id = &"evp_mine_lair"
	_ExpectError("V-M3-ref-chain-point", "chain_mine_collapse")
	chain.trigger_point_id = &"evp_mine_01"
	_RunClean()

func test_suspended_quest_goal_rule_active() -> void:
	## 挂起②③激活回归：q_lost_miner_keepsake 判据/map_id/region_id 闭环 +
	## q_lair_purge CLEAR 判据闭环；断链注入（goal_param 不存在 → 报错）
	var quest: QuestTemplateDef = _game_data.get_record(&"q_lost_miner_keepsake") as QuestTemplateDef
	assert_str(String(quest.goal_param)).is_equal("tp_old_well")
	assert_str(String(quest.map_id)).is_equal("map_m1_village_mine")
	assert_str(String(quest.region_id)).is_equal("reg_mine")
	var original: StringName = quest.goal_param
	quest.goal_param = &"tp_nope"
	_ExpectError("V-M3-ref-quest-goal", "q_lost_miner_keepsake")
	quest.goal_param = original
	# CLEAR 类断链（q_lair_purge 判据队伍不存在）
	var purge: QuestTemplateDef = _game_data.get_record(&"q_lair_purge") as QuestTemplateDef
	assert_int(purge.goal_type).is_equal(QuestTemplateDef.GoalType.CLEAR)
	var purge_param: StringName = purge.goal_param
	purge.goal_param = &"enc_nope"
	_ExpectError("V-M3-ref-quest-goal", "q_lair_purge")
	purge.goal_param = purge_param
	_RunClean()

func test_map_layout_broken() -> void:
	## map-layout：行长不一致 → 报错；恢复后归零
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	var original_rows: Array[String] = map_def.rows.duplicate()
	var broken: Array[String] = original_rows.duplicate()
	broken[0] = "vvvvvvvvvvvv"
	map_def.rows = broken
	_ExpectError("V-M3-map-layout", "map_m1_village_mine")
	map_def.rows = original_rows
	_RunClean()

func test_map_points_on_wall_and_duplicate() -> void:
	## map-points：点位挪到岩壁（不可通行）→ 报错；与他点同格 → 查重报错
	var point: InteractPointDef = _game_data.get_record(&"evp_mine_01") as InteractPointDef
	var original: Vector2i = point.cell
	point.cell = Vector2i(0, 3)
	_ExpectError("V-M3-map-points", "evp_mine_01")
	point.cell = Vector2i(9, 4)
	_ExpectError("V-M3-map-points", "evp_mine_01")
	point.cell = original
	_RunClean()

func test_fog_lit_out_of_range() -> void:
	## fog-lit：全亮行号越界 → 报错
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	var original: Array[int] = map_def.fog_lit_rows.duplicate()
	map_def.fog_lit_rows = [0, 1, 2, 15]
	_ExpectError("V-M3-fog-lit", "map_m1_village_mine")
	map_def.fog_lit_rows = original
	_RunClean()

func test_ref_point_event_broken() -> void:
	## ref-point-event：CHAIN 引用断链 → 报错
	var point: InteractPointDef = _game_data.get_record(&"evp_mine_01") as InteractPointDef
	var original: StringName = point.ref_id
	point.ref_id = &"chain_nope"
	_ExpectError("V-M3-ref-point-event", "evp_mine_01")
	point.ref_id = original
	_RunClean()

func test_ref_region_broken() -> void:
	## ref-region：图区域引用断链 → 报错；恢复后归零
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	var original: Array[StringName] = map_def.region_ids.duplicate()
	var broken: Array[StringName] = original.duplicate()
	broken.append(&"reg_nope")
	map_def.region_ids = broken
	_ExpectError("V-M3-ref-region", "map_m1_village_mine")
	map_def.region_ids = original
	_RunClean()

func test_secret_reveal_broken() -> void:
	## secret-reveal：揭示地格改为不可通行（岩壁）→ 报错；恢复后归零
	var point: InteractPointDef = _game_data.get_record(&"evp_mine_secret") as InteractPointDef
	var original: StringName = point.reveal_tile_id
	point.reveal_tile_id = &"etile_wall"
	_ExpectError("V-M3-secret-reveal", "evp_mine_secret")
	point.reveal_tile_id = original
	_RunClean()

func test_hidden_mark_broken() -> void:
	## hidden-mark：unlock_flag 无事件出口承载 → 报错；恢复后归零
	var mark: HiddenMarkDef = _game_data.get_record(&"hm_mine_secret_door") as HiddenMarkDef
	var original: StringName = mark.unlock_flag
	mark.unlock_flag = &"flag_nope"
	_ExpectError("V-M3-hidden-mark", "hm_mine_secret_door")
	mark.unlock_flag = original
	_RunClean()

func test_encw_domain_broken() -> void:
	## encw-domain：概率越界 → 报错；恢复后归零
	var weight: EncounterWeightDef = _game_data.get_record(&"encw_mine") as EncounterWeightDef
	var original: float = weight.encounter_chance
	weight.encounter_chance = 1.5
	_ExpectError("V-M3-encw-domain", "encw_mine")
	weight.encounter_chance = original
	_RunClean()

func test_treasure_domain_broken() -> void:
	## treasure-domain：宝箱金域下限越带 → 报错；恢复后归零
	var point: InteractPointDef = _game_data.get_record(&"evp_mine_chest_01") as InteractPointDef
	var original: int = point.gold_min
	point.gold_min = 10
	_ExpectError("V-M3-treasure-domain", "evp_mine_chest_01")
	point.gold_min = original
	_RunClean()

func test_quest_map_backfill_closure() -> void:
	## 委托-地图回填闭环：两委托 map_id 均指向 DEMO 总图（V-M3 验证通过的
	## 数据侧前提——挂起③激活后无空 map_id 断链）
	for quest_id: StringName in [&"q_lost_miner_keepsake", &"q_lair_purge"]:
		var quest: QuestTemplateDef = _game_data.get_record(quest_id) as QuestTemplateDef
		assert_str(String(quest.map_id)).is_equal("map_m1_village_mine")


func test_start_cell_on_wall_rejected() -> void:
	## 质检 M3（#9）：start_cell 落障碍格 → V-M3-map-points 拦截
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	var original: Vector2i = map_def.start_cell
	map_def.start_cell = Vector2i(0, 3)
	_ExpectError("V-M3-map-points", "map_m1_village_mine")
	map_def.start_cell = original
	_RunClean()

func test_kind_trigger_matrix_rejected() -> void:
	## 质检 L4（#14）：CHAIN 点改 TAP 触发 → 组合矩阵非法报错
	var point: InteractPointDef = _game_data.get_record(&"evp_mine_01") as InteractPointDef
	var original: int = point.trigger
	point.trigger = InteractPointDef.Trigger.TAP
	_ExpectError("V-M3-ref-point-event", "evp_mine_01")
	point.trigger = original
	_RunClean()

func test_escort_goal_type_rejected() -> void:
	## 质检 L5（#15）：ESCORT 判据（DEMO 无消费通路）→ 报错
	var quest: QuestTemplateDef = _game_data.get_record(&"q_lair_purge") as QuestTemplateDef
	var original: int = quest.goal_type
	quest.goal_type = QuestTemplateDef.GoalType.ESCORT
	_ExpectError("V-M3-ref-quest-goal", "q_lair_purge")
	quest.goal_type = original
	_RunClean()

func test_fog_disabled_rejected() -> void:
	## 质检 L8（#18）：fog_enabled=false（关闭迷雾通路未接）→ 报错
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	var original: bool = map_def.fog_enabled
	map_def.fog_enabled = false
	_ExpectError("V-M3-fog-lit", "map_m1_village_mine")
	map_def.fog_enabled = original
	_RunClean()

func test_tp_old_well_in_mine_avoids_lair_path() -> void:
	## 质检 M1（#7 拍板 B 复验）：老井暗窖移矿洞底层 (5,13)——目标点数据
	## 落位 + 从出生格可达 + 最短路不经巢穴必然遭遇格 (7,14)
	var target: TargetPointDef = _game_data.get_record(&"tp_old_well") as TargetPointDef
	assert_bool(target.cell == Vector2i(5, 13)).is_true()
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	var state := ExploreMapState.new()
	state.setup(map_def, func(tile_id: StringName) -> ExploreTileDef:
		return _game_data.get_record(tile_id) as ExploreTileDef)
	var path: Array[Vector2i] = state.find_path(map_def.start_cell, target.cell)
	assert_int(path.size()).is_greater(0)
	assert_bool(path.has(Vector2i(7, 14))).override_failure_message(
			"目标点路径不应经必然遭遇格").is_false()

# --------------------------------------------------------------------------
# 第四轮审计补测（2026-09-26：W4-03/W4-06/W4-13/W4-15/W2-6/W2-9/W2-13/W5-6/W5-3）
# --------------------------------------------------------------------------

func test_w43_vision_radius_zero_rejected() -> void:
	## W4-03：cfg 正数组新成员 vision_radius ≤ 0 → V-M0-cfg-domain 报错
	var cfg: CoreConfig = _game_data.get_record(&"cfg_main") as CoreConfig
	var original: int = cfg.vision_radius
	cfg.vision_radius = 0
	_ExpectError("V-M0-cfg-domain", "vision_radius")
	cfg.vision_radius = original
	_RunClean()

func test_w43_base_expedition_days_floor() -> void:
	## W4-03：map.base_expedition_days < 1 → V-M3-map-layout 报错
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	var original: int = map_def.base_expedition_days
	map_def.base_expedition_days = 0
	_ExpectError("V-M3-map-layout", "base_expedition_days")
	map_def.base_expedition_days = original
	_RunClean()

func test_w46_chain_point_reverse_broken() -> void:
	## W4-06 反向断言：CHAIN 点引用的链 trigger_point_id 清空 → 报错收紧
	var chain: EventChainDef = _game_data.get_record(&"chain_mine_collapse") as EventChainDef
	var original: StringName = chain.trigger_point_id
	chain.trigger_point_id = &""
	_ExpectError("V-M3-ref-chain-point", "evp_mine_01")
	chain.trigger_point_id = original
	_RunClean()

func test_w213_fog_region_consistency() -> void:
	## W2-13：fog_lit_rows 非空 ↔ region_ids 恰 2——region_ids 减一报错；
	## fog_lit_rows 清空（region_ids 保持 2）同样报错（双向）
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	var original_regions: Array[StringName] = map_def.region_ids.duplicate()
	var original_rows: Array[int] = map_def.fog_lit_rows.duplicate()
	var single_region: Array[StringName] = [&"reg_mine"]
	map_def.region_ids = single_region
	_ExpectError("V-M3-fog-lit", "map_m1_village_mine")
	map_def.region_ids = original_regions
	map_def.fog_lit_rows = []
	_ExpectError("V-M3-fog-lit", "map_m1_village_mine")
	map_def.fog_lit_rows = original_rows
	_RunClean()

func test_w413_empty_reveal_cells_rejected() -> void:
	## W4-13：暗门 reveal_cells 清空 → 死配置报错
	var point: InteractPointDef = _game_data.get_record(&"evp_mine_secret") as InteractPointDef
	var original: Array[Vector2i] = point.reveal_cells.duplicate()
	point.reveal_cells = []
	_ExpectError("V-M3-secret-reveal", "evp_mine_secret")
	point.reveal_cells = original
	_RunClean()

func test_w415_quest_reward_band() -> void:
	## W4-15：委托奖励量级带——gold 越带（150→1500）报错；reward 置空报错
	var quest: QuestTemplateDef = _game_data.get_record(&"q_lair_purge") as QuestTemplateDef
	var original_gold: int = quest.reward.gold
	var original_reward: RewardDef = quest.reward
	quest.reward.gold = 1500
	_ExpectError("V-M3-quest-reward", "q_lair_purge")
	quest.reward.gold = original_gold
	quest.reward = null
	_ExpectError("V-M3-quest-reward", "q_lair_purge")
	quest.reward = original_reward
	_RunClean()

func test_w26_common_attack_dup_in_skill_ids() -> void:
	## W2-6：敌人 skill_ids 重复挂载通用普攻 → V-M0-ref-enemy-skill 报错
	var enemy: EnemyDef = _game_data.get_record(&"en_m1_goblin_miner") as EnemyDef
	var original: Array[StringName] = enemy.skill_ids.duplicate()
	enemy.skill_ids.append(enemy.common_attack_skill_id)
	_ExpectError("V-M0-ref-enemy-skill", "en_m1_goblin_miner")
	enemy.skill_ids = original
	_RunClean()

func test_w29_empty_enemy_ids_rejected() -> void:
	## W2-9：队伍条目 enemy_ids 清空 → V-M0-ref-pack 报错（空候选装配越界）
	var pack: EnemyPackDef = _game_data.get_record(&"enc_m1_random_pack") as EnemyPackDef
	var original: Array[StringName] = pack.entries[0].enemy_ids.duplicate()
	pack.entries[0].enemy_ids = []
	_ExpectError("V-M0-ref-pack", "enc_m1_random_pack")
	pack.entries[0].enemy_ids = original
	_RunClean()

func test_w56_map_connectivity_broken() -> void:
	## W5-6：封死村矿通道（行 3 唯一缺口 (7,3) 改墙）→ 矿洞全部点位自出生格
	## 不可达 → V-M3-map-connectivity 逐点报错；恢复后归零
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	var original_rows: Array[String] = map_def.rows.duplicate()
	var sealed: Array[String] = original_rows.duplicate()
	sealed[3] = "XXXXXXXXXXXXXXX"
	map_def.rows = sealed
	_ExpectError("V-M3-map-connectivity", "evp_mine_lair")
	_ExpectError("V-M3-map-connectivity", "tp_old_well")
	map_def.rows = original_rows
	_RunClean()

func test_w56_map_connectivity_clean() -> void:
	## W5-6 正样本：现网图全部交互点/目标点自 start_cell BFS 可达（零连通错）
	var report: ValidationReport = DataValidator.run_all(_game_data)
	for entry: String in report.errors:
		assert_bool(entry.begins_with("V-M3-map-connectivity")).override_failure_message(
				"现网图不应有连通断点：%s" % entry).is_false()

func test_w53_explicit_table_values_locked() -> void:
	## W5-3：tres 显式落值断言——q_lair_purge.party_max == 4 与
	## map_m1_village_mine.base_expedition_days == 1（脚本默认值漂移在此拦截）
	var quest: QuestTemplateDef = _game_data.get_record(&"q_lair_purge") as QuestTemplateDef
	assert_int(quest.party_min).is_equal(3)
	assert_int(quest.party_max).is_equal(4)
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	assert_int(map_def.base_expedition_days).is_equal(1)
	# 落盘侧：磁盘 .tres 文本含显式字段行（防字段被误删回落脚本默认）
	var quest_text: String = FileAccess.open(
			"res://data/quest/templates/q_lair_purge.tres", FileAccess.READ).get_as_text()
	assert_bool(quest_text.contains("party_max = 4")).is_true()
	var map_text: String = FileAccess.open(
			"res://data/map/maps/map_m1_village_mine.tres", FileAccess.READ).get_as_text()
	assert_bool(map_text.contains("base_expedition_days = 1")).is_true()
