## 毒沼探索层测试（功能一试玩批 2——etile_poison_swamp 踏入效果链）
## 覆盖：apply_tile_effect 全队扣血（下限 1 止/已倒地不扣不标）/逐格途经
## 连续扣/build_poison_initial_statuses 形状/clear_poison 清除+路由失败不清/
## 集成 _MoveTo 途经中毒（标记+HP+不中断）/带入遭遇战 initial_statuses
## CHECKIN 施加/战后续跑 clear（回城无残留）/V-P1-etile-effect 与
## V-P1-map-poison 负反。
## 环境口径：单元组直构 ExpeditionRun；集成组真 autoload + SceneManager
## 挂载（test_explore_flow 同款）。
extends GdUnitTestSuite

## 场景 id（SceneManager：EXPLORE_SCREEN=3）
const SCENE_EXPLORE: int = 3
## 毒沼探索地格表路径
const ETILE_PATH: String = "res://data/map/tiles/etile_poison_swamp.tres"

func before_test() -> void:
	## 用例前置：复位 SceneManager 可变状态 + 清存档
	## 参数：无
	## 返回：无
	var scene_manager: Node = get_tree().root.get_node_or_null("SceneManager")
	if scene_manager != null:
		scene_manager.current_id = -1
		scene_manager.previous_id = -1
		var no_params: Dictionary = {}
		scene_manager.pending_params = no_params
		scene_manager._switch_pending = false
	for entry_name: String in ["main_save.json", "main_save.json.bak",
			"main_save.json.tmp"]:
		DirAccess.remove_absolute("user://saves/" + entry_name)
	var save_manager: Node = get_tree().root.get_node_or_null("SaveManager")
	if save_manager != null:
		save_manager.current = null
		save_manager.set_expedition_lock(false)
	var guild_state: Node = get_tree().root.get_node_or_null("GuildState")
	if guild_state != null:
		guild_state.core = GuildCore.new()

func _WaitFrames(frames: int) -> void:
	## 帧等待助手
	## 参数 frames：帧数
	## 返回：无（协程）
	for _i: int in frames:
		await get_tree().process_frame

func _MakeRun() -> ExpeditionRun:
	## 构建双成员运行态（甲 hp5 / 乙 hp3 且倒地——扣血口径断言消费）
	## 参数：无
	## 返回：ExpeditionRun
	var game_data: Node = get_tree().root.get_node("GameData")
	var run := ExpeditionRun.new()
	var adv_a: AdventurerData = AdventurerData.create_debug(&"a", &"cls_warrior", {
			&"strength": 14, &"agility": 10, &"constitution": 14,
			&"intelligence": 7, &"perception": 15, &"willpower": 9, &"luck": 10}, game_data)
	var adv_b: AdventurerData = AdventurerData.create_debug(&"b", &"cls_rogue", {
			&"strength": 10, &"agility": 16, &"constitution": 10,
			&"intelligence": 9, &"perception": 11, &"willpower": 10, &"luck": 13}, game_data)
	run.party.append(adv_a)
	run.party.append(adv_b)
	run.hp[adv_a] = 5
	run.hp[adv_b] = 3
	run.downed[adv_b] = true
	return run

func _PoisonTile() -> ExploreTileDef:
	## 加载毒沼探索地格表
	## 参数：无
	## 返回：ExploreTileDef
	return load(ETILE_PATH) as ExploreTileDef

# --------------------------------------------------------------------------
# 单元组：ExpeditionRun 染毒三方法
# --------------------------------------------------------------------------

func test_apply_tile_effect_damage_and_marks() -> void:
	## apply_tile_effect：全队扣 effect_damage（下限 1 止）、已倒地不扣
	## 不标；null/NONE 地格 false
	var run := _MakeRun()
	var adv_a: AdventurerData = run.party[0]
	var adv_b: AdventurerData = run.party[1]
	assert_bool(run.apply_tile_effect(_PoisonTile())).is_true()
	assert_int(int(run.hp[adv_a])).is_equal(3)
	assert_int(int(run.hp[adv_b])).is_equal(3)
	assert_bool(run.poisoned.has(adv_a)).is_true()
	assert_bool(run.poisoned.has(adv_b)).is_false()
	# 下限 1 止（再踏一格不归零、标记幂等保留）
	assert_bool(run.apply_tile_effect(_PoisonTile())).is_true()
	assert_int(int(run.hp[adv_a])).is_equal(1)
	assert_bool(run.apply_tile_effect(_PoisonTile())).is_true()
	assert_int(int(run.hp[adv_a])).is_equal(1)
	# 非效果地格/空安全
	assert_bool(run.apply_tile_effect(null)).is_false()
	var plain: ExploreTileDef = get_tree().root.get_node("GameData").get_record(
			&"etile_floor") as ExploreTileDef
	assert_bool(run.apply_tile_effect(plain)).is_false()

func test_apply_tile_effect_per_cell_repeat() -> void:
	## 逐格途经连续毒沼逐格扣：两次踏入 = 两格各扣（5 → 3 → 1）
	var run := _MakeRun()
	var adv_a: AdventurerData = run.party[0]
	run.hp[adv_a] = 5
	assert_bool(run.apply_tile_effect(_PoisonTile())).is_true()
	assert_int(int(run.hp[adv_a])).is_equal(3)
	assert_bool(run.apply_tile_effect(_PoisonTile())).is_true()
	assert_int(int(run.hp[adv_a])).is_equal(1)

func test_build_poison_initial_statuses_shape() -> void:
	## build_poison_initial_statuses：染毒∩未倒地 → {status_id/target/
	## duration} 形状（duration 0 回退 default_duration=2——战斗侧口径）
	var run := _MakeRun()
	var adv_a: AdventurerData = run.party[0]
	var adv_b: AdventurerData = run.party[1]
	assert_bool(run.apply_tile_effect(_PoisonTile())).is_true()
	run.poisoned[adv_b] = &"DEBUFF_poison"
	var entries: Array = run.build_poison_initial_statuses()
	assert_int(entries.size()).is_equal(1)
	assert_str(String(entries[0].get(&"status_id", &""))).is_equal("DEBUFF_poison")
	assert_str(String(entries[0].get(&"target", &""))).is_equal("a")
	assert_int(int(entries[0].get(&"duration", -1))).is_equal(0)

func test_clear_poison_and_route_fail_keeps_marks() -> void:
	## clear_poison 清除；路由失败（_switch_pending 注入 go 拒）不清——
	## 染毒标记保留供重试再注入
	var run := _MakeRun()
	var adv_a: AdventurerData = run.party[0]
	assert_bool(run.apply_tile_effect(_PoisonTile())).is_true()
	run.clear_poison()
	assert_bool(run.poisoned.is_empty()).is_true()
	# 屏级路由失败路径：_GoBattle go 拒 → poisoned 不清
	assert_bool(run.apply_tile_effect(_PoisonTile())).is_true()
	var game_data: Node = get_tree().root.get_node("GameData")
	var cfg: CoreConfig = game_data.get_record(&"cfg_main") as CoreConfig
	var screen_run := ExpeditionRun.new()
	var adv: AdventurerData = AdventurerData.create_debug(&"t", &"cls_warrior", {
			&"strength": 14, &"agility": 10, &"constitution": 14,
			&"intelligence": 7, &"perception": 15, &"willpower": 9, &"luck": 10}, game_data)
	screen_run.party.append(adv)
	screen_run.hp[adv] = 30
	var map_def: ExploreMapDef = game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	screen_run.start_explore(map_def, null, cfg.vision_radius)
	screen_run.poisoned[adv] = &"DEBUFF_poison"
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	assert_int(scene_manager.go(SCENE_EXPLORE, {&"expedition_run": screen_run})).is_equal(OK)
	await _WaitFrames(4)
	var screen: Control = get_tree().current_scene as Control
	screen.step_seconds_override = 0.0
	var params := BattleParams.new()
	params.pack_id = &"enc_m1_random_pack"
	scene_manager._switch_pending = true
	assert_bool(screen._GoBattle(params, {&"encounter_pack_id": &"enc_m1_random_pack"})).is_false()
	scene_manager._switch_pending = false
	assert_bool(screen_run.poisoned.has(adv)).is_true()

# --------------------------------------------------------------------------
# 集成组：探索屏途经/带入/回城
# --------------------------------------------------------------------------

func _MakeScreenRun() -> ExpeditionRun:
	## 构建单成员挂屏运行态（途经集成组共用）
	## 参数：无
	## 返回：ExpeditionRun
	var game_data: Node = get_tree().root.get_node("GameData")
	var cfg: CoreConfig = game_data.get_record(&"cfg_main") as CoreConfig
	var run := ExpeditionRun.new()
	var adv: AdventurerData = AdventurerData.create_debug(&"t", &"cls_warrior", {
			&"strength": 14, &"agility": 10, &"constitution": 14,
			&"intelligence": 7, &"perception": 15, &"willpower": 9, &"luck": 10}, game_data)
	run.party.append(adv)
	run.hp[adv] = 30
	var map_def: ExploreMapDef = game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	run.start_explore(map_def, null, cfg.vision_radius)
	return run

func _OpenScreen(run: ExpeditionRun) -> Control:
	## 挂载探索屏（演出加速）
	## 参数 run：出征运行态
	## 返回：探索屏根节点
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	assert_int(scene_manager.go(SCENE_EXPLORE, {&"expedition_run": run})).is_equal(OK)
	await _WaitFrames(4)
	var screen: Control = get_tree().current_scene as Control
	screen.step_seconds_override = 0.0
	return screen

func test_move_to_through_poison_marks_and_damages() -> void:
	## 集成：_MoveTo 途经 (7,11)(7,12) 双毒沼格 → HP -4、染毒标记、
	## 移动不中断（达 (7,13)）
	var run := _MakeScreenRun()
	run.party_pos = Vector2i(7, 10)
	run.visited_cells.clear()
	var screen: Control = await _OpenScreen(run)
	screen._OnCellPressed(Vector2i(7, 13))
	await _WaitFrames(8)
	assert_bool(run.party_pos == Vector2i(7, 13)) \
			.override_failure_message("途经毒沼不中断移动").is_true()
	assert_int(int(run.hp[run.party[0]])).is_equal(26)
	assert_bool(run.poisoned.has(run.party[0])).is_true()

func test_battle_bring_in_applies_checkin_poison() -> void:
	## 集成：染毒成员路由遭遇战 → initial_statuses 注入 → 战斗侧 CHECKIN
	## 施加 DEBUFF_poison（remaining=default_duration 2）
	var run := _MakeScreenRun()
	run.poisoned[run.party[0]] = &"DEBUFF_poison"
	var screen: Control = await _OpenScreen(run)
	var params := BattleParams.new()
	params.pack_id = &"enc_m1_random_pack"
	assert_bool(screen._GoBattle(params, {&"encounter_pack_id": &"enc_m1_random_pack"})).is_true()
	await _WaitFrames(6)
	var battle: Control = get_tree().current_scene as Control
	assert_object(battle).is_not_null()
	var unit: BattleUnit = battle.context.find_unit(&"t")
	assert_object(unit).is_not_null()
	var found: StatusInstance = null
	for instance: StatusInstance in battle.context.status_manager.get_statuses(unit):
		if instance.status_id == &"DEBUFF_poison":
			found = instance
	assert_object(found).is_not_null()
	assert_int(found.source_kind).is_equal(StatusInstance.SourceKind.CHECKIN)
	assert_int(found.remaining).is_equal(2)

func test_resume_after_battle_clears_poison() -> void:
	## 集成：战后续跑（遭遇胜利通道）头部 clear_poison——回城无染毒残留
	var run := _MakeScreenRun()
	run.poisoned[run.party[0]] = &"DEBUFF_poison"
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var payload: Dictionary = {
		&"expedition_run": run,
		&"battle_result": _MakeVictory(),
		&"event_id": &"",
		&"battle_node_id": &"",
		&"encounter_pack_id": &"enc_m1_random_pack",
	}
	assert_int(scene_manager.go(SCENE_EXPLORE, payload)).is_equal(OK)
	await _WaitFrames(8)
	assert_bool(run.poisoned.is_empty()) \
			.override_failure_message("战后续跑应清染毒标记（回城无残留）").is_true()

func _MakeVictory() -> BattleResult:
	## 构造单成员胜利战斗结果
	## 参数：无
	## 返回：BattleResult
	var result := BattleResult.new()
	result.kind = BattleResult.ResultKind.VICTORY
	var stats: Array[Dictionary] = []
	stats.append({&"unit_id": &"t", &"end_hp": 20, &"downed": false})
	result.end_stats = stats
	return result

# --------------------------------------------------------------------------
# 校验负反：V-P1-etile-effect / V-P1-map-poison
# --------------------------------------------------------------------------

func _HasError(report: ValidationReport, prefix: String, needle: String) -> bool:
	## 报告内按前缀+关键字匹配错误
	## 参数 report/prefix/needle：报告 / 规则前缀 / 关键字
	## 返回：true = 命中
	for entry: String in report.errors:
		if entry.begins_with(prefix) and entry.contains(needle):
			return true
	return false

func test_v_p1_etile_effect_negative() -> void:
	## V-P1-etile-effect 负反：坏 status 引用 / effect_damage 0 均报错
	var game_data: Node = get_tree().root.get_node("GameData")
	var etile: ExploreTileDef = game_data.get_record(&"etile_poison_swamp") as ExploreTileDef
	var original_status: StringName = etile.effect_status_id
	var original_damage: int = etile.effect_damage
	etile.effect_status_id = &"DEBUFF_nope"
	var report: ValidationReport = DataValidator.run_all(game_data)
	assert_bool(_HasError(report, "V-P1-etile-effect", "DEBUFF_nope")) \
			.override_failure_message("坏 status 引用应报错").is_true()
	etile.effect_status_id = original_status
	etile.effect_damage = 0
	var damage_report: ValidationReport = DataValidator.run_all(game_data)
	etile.effect_damage = original_damage
	assert_bool(_HasError(damage_report, "V-P1-etile-effect", "effect_damage")) \
			.override_failure_message("零伤毒沼应报死效果").is_true()
	var report_after: ValidationReport = DataValidator.run_all(game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_v_p1_map_poison_negative() -> void:
	## V-P1-map-poison 负反（S1-08 一般化——全部 legend 字符查 rows 出现，
	## warning 级死图例）：legend 配图例但 rows 未使用报 warning；生产数据
	## 删死图例 'p' 后全图例零死配置
	var game_data: Node = get_tree().root.get_node("GameData")
	var map_def: ExploreMapDef = game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	map_def.legend[&"Z"] = &"etile_poison_swamp"
	var report: ValidationReport = DataValidator.run_all(game_data)
	map_def.legend.erase(&"Z")
	var warned: bool = false
	for entry: String in report.warnings:
		if entry.begins_with("V-P1-map-poison") and entry.contains("Z"):
			warned = true
	assert_bool(warned) \
			.override_failure_message("未使用图例应报死图例 warning").is_true()
	var report_after: ValidationReport = DataValidator.run_all(game_data)
	assert_int(report_after.errors.size()).is_equal(0)
	assert_int(report_after.warnings.size()).is_equal(0)

# --------------------------------------------------------------------------
# P1/S5-01 回归：屏级 _GoBattle 合流——exposed 与染毒开局状态并存
# --------------------------------------------------------------------------

func test_go_battle_b_exit_merges_exposed_and_poison() -> void:
	## S5-01 回归（经屏级合流点 _GoBattle）：B 出口战 initial_status_id 载入
	## 条目（evn_wisp_n2 → DEBUFF_exposed，build_battle_params 填充）与染毒
	## 条目（DEBUFF_poison，_GoBattle 追加）并存不被覆写；无染毒时仅含
	## exposed 条目（原无条件赋值会抹掉 exposed）
	var game_data: Node = get_tree().root.get_node("GameData")
	var node: EventNodeDef = game_data.get_record(&"evn_wisp_n2") as EventNodeDef
	assert_object(node).is_not_null()
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var run := _MakeScreenRun()
	run.poisoned[run.party[0]] = &"DEBUFF_poison"
	var screen: Control = await _OpenScreen(run)
	# go 拒注入（_switch_pending=true → FAILED）阻断真实路由——断言停留参数层
	scene_manager._switch_pending = true
	var params: BattleParams = screen._runner.build_battle_params(node.outcome, run)
	assert_bool(screen._GoBattle(params, {
			&"event_id": &"chain_mine_wisp",
			&"battle_node_id": &"evn_wisp_n2",
	})).is_false()
	scene_manager._switch_pending = false
	assert_int(params.initial_statuses.size()).is_equal(2)
	var status_ids: PackedStringArray = []
	for entry: Dictionary in params.initial_statuses:
		status_ids.append(String(entry.get(&"status_id", &"")))
	assert_bool(status_ids.has("DEBUFF_exposed")) \
			.override_failure_message("B 出口开局载入状态（exposed）被染毒注入覆写").is_true()
	assert_bool(status_ids.has("DEBUFF_poison")) \
			.override_failure_message("染毒条目未合入开局状态清单").is_true()
	# 无染毒基线：清毒后仅含 exposed 条目
	run.clear_poison()
	scene_manager._switch_pending = true
	var clean_params: BattleParams = screen._runner.build_battle_params(node.outcome, run)
	assert_bool(screen._GoBattle(clean_params, {
			&"event_id": &"chain_mine_wisp",
			&"battle_node_id": &"evn_wisp_n2",
	})).is_false()
	scene_manager._switch_pending = false
	assert_int(clean_params.initial_statuses.size()).is_equal(1)
	assert_str(String(clean_params.initial_statuses[0].get(&"status_id", &""))) \
			.is_equal("DEBUFF_exposed")
