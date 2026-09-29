## 出征冻结 × 到期 × 补结算时序交叉单元测试（M5 批 1）
## 覆盖：补结算内挂单到期失败/周刷新日清板重抽/轻度工期归零聚合、战败重伤 ×
## 补结算天数三态、长途授予到期线起算=回城日、出征中关游戏（锁期不落盘+读档
## 回出发前时点）、回城当日再出征、battle 屏回探索会话的持锁跳过、begin 成功
## 但 go 失败三路回退、同模板挂单并存结算匹配三档。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## SaveManager 脚本路径（局部实例用例）
const SAVE_MANAGER_SCRIPT: String = "res://scripts/autoload/save_manager.gd"
## GuildState 脚本路径（局部实例用例）
const GUILD_STATE_SCRIPT: String = "res://scripts/autoload/guild_state.gd"
## battle_screen 场景（锁移交用例直构）
const BATTLE_SCENE: String = "res://scenes/battle/battle_screen.tscn"
## SceneManager 脚本常量引用（SceneId 枚举——环境无关取值）
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")
## 存档路径（读档一致性断言）
const SAVE_PATH: String = "user://saves/main_save.json"

## 套件级 GameData 与 GuildCore
var _game_data: Node
var _core: GuildCore

func before_test() -> void:
	## 用例级前置：GameData 实例 + 固定种子核心
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()
	_core = GuildCore.new()
	_core.setup(_Cfg(), _game_data, _MakeRng(611))

func after_test() -> void:
	## 用例级后置：释放 GameData、清存档目录（局部写盘用例）、复位真 autoload
	## 出征锁（battle 锁移交用例写真 SaveManager）
	_game_data.free()
	_CleanSaveDir()
	var save_manager: Node = get_tree().root.get_node_or_null("SaveManager")
	if save_manager != null:
		save_manager.set_expedition_lock(false)

func _Cfg() -> CoreConfig:
	## 总控配置读取口
	return _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig

func _MakeRng(seed_value: int) -> RandomNumberGenerator:
	## 固定种子随机源
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _CleanSaveDir() -> void:
	## 清理 user://saves（写盘用例防互染）
	var dir: DirAccess = DirAccess.open("user://saves")
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while not entry_name.is_empty():
		if not dir.current_is_dir():
			dir.remove(entry_name)
		entry_name = dir.get_next()
	dir.list_dir_end()

func _ReadSaveText() -> String:
	## 读存档正本文本
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text

func _SpawnAndStart(template_id: StringName, party_count: int) -> QuestInstance:
	## 装配并出征一个指定模板委托（定点生成——确定性）
	var inst: QuestInstance = _core.board.spawn_on_board(template_id, 1)
	var party: Array[StringName] = []
	for index: int in party_count:
		party.append(_core.roster[index].unit_id)
	assert_bool(_core.accept_quest(inst.serial, party)).is_true()
	assert_bool(_core.start_expedition(inst.serial)).is_true()
	return inst

func _MakeRun(template_id: StringName, party_count: int,
		total_days: int = 1, mark_downed: bool = false) -> ExpeditionRun:
	## 构建出征会话（队员=名册前 N 人引用；判据上下文按模板对齐；批 3 起
	## mark_downed=全队 run.downed 标记——DEFEAT 等价性=战败全员必倒地）
	var run := ExpeditionRun.new()
	run.base_days = total_days
	for index: int in party_count:
		run.party.append(_core.roster[index])
	if mark_downed:
		for adv: AdventurerData in run.party:
			run.downed[adv] = true
	run.quest_template_id = template_id
	var tpl: QuestTemplateDef = _game_data.get_record(template_id) as QuestTemplateDef
	if tpl != null:
		run.goal_kind = tpl.goal_type
		run.goal_param = tpl.goal_param
	return run

func _MakeLocalState() -> Array:
	## 局部 SaveManager + GuildState 装配（套件隔离口径：不 add_child GuildState
	## ——避免 _ready bind 命中真 autoload 覆写 provider；手动等价初始化）
	## 返回：[save_manager, state]（调用方负责 free）
	var save_manager: Node = load(SAVE_MANAGER_SCRIPT).new()
	add_child(save_manager)
	var state: Node = load(GUILD_STATE_SCRIPT).new()
	state.core = GuildCore.new()
	state._rng = _MakeRng(612)
	state.bind(save_manager, _game_data)
	return [save_manager, state]

func test_catchup_expires_pending_and_releases() -> void:
	## 组合 1：出发日 4、出征 3 天（补结算 day5/6/7）——挂单 B（上板日 1、
	## 到期线 6）在补结算 day6 到期自动失败：移除+释放+无重伤；出征单 A 先
	## 结算不被补结算误判（成功入账照常）；B 编队成员吃出征板凳分享
	for _day_index: int in 3:
		_core.settle_one_day()
	assert_int(_core.day).is_equal(4)
	var inst_a: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", _core.day)
	assert_bool(_core.accept_quest(inst_a.serial,
			[_core.roster[0].unit_id, _core.roster[1].unit_id])).is_true()
	var inst_b: QuestInstance = _core.board.spawn_on_board(&"q_north_survey", 1)
	assert_bool(_core.accept_quest(inst_b.serial,
			[_core.roster[2].unit_id, _core.roster[3].unit_id])).is_true()
	assert_bool(_core.start_expedition(inst_a.serial)).is_true()
	var gold_before: int = _core.gold
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(
			_MakeRun(&"q_vein_survey", 2, 3), GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(_core.day).is_equal(7)
	assert_int(_core.gold - gold_before).is_equal(150)
	assert_int(summary.day_summaries.size()).is_equal(3)
	# B 在 day6（day_summaries[1]）到期失败
	var day6: GuildCore.DaySummary = summary.day_summaries[1]
	assert_bool(day6.accepted_failed.has("q_north_survey")).is_true()
	assert_object(_core.board.find_accepted(inst_b.serial)).is_null()
	assert_int(_core.board.occupied_member_ids().size()).is_equal(0)
	# B 成员：到期失败无重伤 + 出征板凳分享 24（busy=出征队，挂单占用不入 busy 集）
	for index: int in [2, 3]:
		assert_int(_core.roster[index].status).is_equal(AdventurerData.Status.HEALTHY)
		assert_int(_core.roster[index].exp).is_equal(24)

func test_catchup_week_refresh_inside_catchup() -> void:
	## 组合 2：出发日 6、耗时 3 天 → 补结算含第 8 天周刷新——清板重抽
	##（新一批 quest_week_draw=3）+ 跳过常规到期（三表现明细全空、
	## 出发前板上到期的实例随清板消失而非走三表现）
	for _day_index: int in 5:
		_core.settle_one_day()
	assert_int(_core.day).is_equal(6)
	var inst: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", _core.day)
	assert_bool(_core.accept_quest(inst.serial,
			[_core.roster[0].unit_id, _core.roster[1].unit_id])).is_true()
	assert_bool(_core.start_expedition(inst.serial)).is_true()
	# day8 到期的板上实例（上板日 3 + 时限 5）——周刷新日不走三表现
	var expiring: QuestInstance = _core.board.spawn_on_board(&"q_bounty_boss", 3)
	assert_int(expiring.expire_day).is_equal(8)
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(
			_MakeRun(&"q_vein_survey", 2, 3), GuildCore.ExpeditionOutcome.RETREAT)
	assert_int(_core.day).is_equal(9)
	var day8: GuildCore.DaySummary = summary.day_summaries[1]
	assert_bool(day8.week_refreshed).is_true()
	# 周刷新日跳过常规到期：三表现明细全空
	assert_int(day8.board_removed.size()).is_equal(0)
	assert_int(day8.board_refreshed.size()).is_equal(0)
	assert_int(day8.board_replaced.size()).is_equal(0)
	# 清板重抽：旧板（含 expiring）全清、新一批 3 个
	assert_int(_core.board.board.size()).is_equal(3)
	assert_object(_core.board.find_on_board(expiring.serial)).is_null()
	# 撤退出口零入账
	assert_int(summary.gold_gained).is_equal(0)

func test_catchup_light_completes_with_bench_inside_loop() -> void:
	## 组合 3：补结算期间轻度工期归零——day1 开工（工期 2）+ 出征 3 天：
	## 补结算 day3 归零完成结算（60 金+板凳分享）聚合进 day_summaries[1]；
	## 委托板凳与轻度板凳两次分享各自独立计（busy 集不同）
	var light: QuestInstance = _core.board.spawn_on_board(&"q_chore_supply_run", 1)
	assert_bool(_core.start_light_quest(light.serial,
			[_core.roster[0].unit_id])).is_true()
	var battle: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", 1)
	assert_bool(_core.accept_quest(battle.serial,
			[_core.roster[1].unit_id, _core.roster[2].unit_id])).is_true()
	assert_bool(_core.start_expedition(battle.serial)).is_true()
	var gold_before: int = _core.gold
	var run := _MakeRun(&"q_vein_survey", 2, 3)
	run.party = [_core.roster[1], _core.roster[2]]
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(run,
			GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(_core.day).is_equal(4)
	# 轻度在补结算循环内（day3）归零完成：载荷聚合进当日 DaySummary
	var day3: GuildCore.DaySummary = summary.day_summaries[1]
	assert_int(day3.light_completed.size()).is_equal(1)
	var result: GuildCore.LightQuestResult = day3.light_completed[0]
	assert_str(String(result.template_id)).is_equal("q_chore_supply_run")
	assert_int(result.gold).is_equal(60)
	# 轻度板凳：busy=轻度编队（roster[0]）——其余 3 人各 9（拍板①）
	assert_int(result.bench_member_count).is_equal(3)
	assert_int(result.bench_exp_per_member).is_equal(9)
	# 总入账：委托 150 + 轻度 60 = 210
	assert_int(_core.gold - gold_before).is_equal(210)
	# 经验分流：轻度编队 r0=30+委托板凳 24；出战 r1/r2=80+轻度板凳 9；
	# 纯板凳 r3=委托板凳 24+轻度板凳 9
	assert_int(_core.roster[0].exp).is_equal(54)
	assert_int(_core.roster[1].exp).is_equal(89)
	assert_int(_core.roster[2].exp).is_equal(89)
	assert_int(_core.roster[3].exp).is_equal(33)

func test_defeat_injury_remaining_by_trip_length() -> void:
	## 组合 4：战败重伤（应用 3 天）× 补结算天数三态——total 2 → remaining 1；
	## total 3 → 0（恰耗尽转健康）；total 4 → 0（恢复后不倒扣）
	var expected_remaining: Array[int] = [1, 0, 0]
	for trip_index: int in 3:
		var trip_days: int = trip_index + 2
		var core := GuildCore.new()
		core.setup(_Cfg(), _game_data, _MakeRng(613))
		var inst: QuestInstance = core.board.spawn_on_board(&"q_lair_purge", 1)
		var party: Array[StringName] = [core.roster[0].unit_id,
				core.roster[1].unit_id, core.roster[2].unit_id]
		assert_bool(core.accept_quest(inst.serial, party)).is_true()
		assert_bool(core.start_expedition(inst.serial)).is_true()
		var run := ExpeditionRun.new()
		run.base_days = trip_days
		run.party = [core.roster[0], core.roster[1], core.roster[2]]
		run.quest_template_id = &"q_lair_purge"
		# 批 3：DEFEAT 等价性——战败全员必倒地
		for adv: AdventurerData in run.party:
			run.downed[adv] = true
		var summary: GuildCore.ExpeditionSummary = core.settle_expedition(run,
				GuildCore.ExpeditionOutcome.DEFEAT)
		assert_int(summary.injury_rest_days).is_equal(3)
		assert_int(summary.injury_rest_days_remaining).is_equal(
				expected_remaining[trip_index])
		# 面板口径与名册一致（全队同值）
		for member_index: int in 3:
			assert_int(core.roster[member_index].rest_days).is_equal(
					expected_remaining[trip_index])

func test_granted_expire_counts_from_arrival_day() -> void:
	## 组合 5：出发日 4、耗时 3 天（回城日 7）最后一日授予——挂单到期线 =
	## 回城日 7 + 时限 7 = 14（转挂单后置补结算，expire_day 以终 day 起算，
	## 不「授予即到期」；出发日非 1 的漂移变体锚定起算日）
	for _day_index: int in 3:
		_core.settle_one_day()
	assert_int(_core.day).is_equal(4)
	var inst: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", _core.day)
	assert_bool(_core.accept_quest(inst.serial,
			[_core.roster[0].unit_id, _core.roster[1].unit_id])).is_true()
	assert_bool(_core.start_expedition(inst.serial)).is_true()
	var run := _MakeRun(&"q_vein_survey", 2, 3)
	run.granted_quests.append(&"q_lost_miner_keepsake")
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(run,
			GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(_core.day).is_equal(7)
	assert_int(summary.quests_granted.size()).is_equal(1)
	var granted: QuestInstance = _core.board.find_accepted_by_template(
			&"q_lost_miner_keepsake")
	assert_object(granted).is_not_null()
	assert_int(granted.expire_day).is_equal(14)

func test_shutdown_during_expedition_keeps_departure_save() -> void:
	## 组合 6：出征中关游戏——begin 置 IN_PROGRESS+锁；锁期 autosave 跳过
	##（盘上仍为出发前档）；新会话 load_game → 委托回 ACCEPTED（出征态不入档）、
	## 锁 false、has_guild_data() true
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	state.new_game()
	var core: GuildCore = state.core
	var inst: QuestInstance = core.board.spawn_on_board(&"q_lair_purge", core.day)
	var party: Array[StringName] = [core.roster[0].unit_id,
			core.roster[1].unit_id, core.roster[2].unit_id]
	assert_bool(core.accept_quest(inst.serial, party)).is_true()
	# 出发前档：等待一天落 DAY_END（挂单 ACCEPTED 入档——「接单次日出发」时点）
	state.wait_one_day()
	assert_int(core.day).is_equal(2)
	var departure_text: String = _ReadSaveText()
	assert_str(departure_text).is_not_empty()
	# 出征：begin 同段置锁 + IN_PROGRESS（run 运行态不入档）
	var run: ExpeditionRun = state.begin_expedition(inst)
	assert_object(run).is_not_null()
	assert_int(inst.state).is_equal(QuestInstance.State.IN_PROGRESS)
	assert_bool(save_manager.is_expedition_locked()).is_true()
	# 出征中任何 autosave 被锁跳过：盘上仍是出发前档
	assert_int(save_manager.autosave(SaveData.SavePoint.DAY_END)).is_equal(OK)
	assert_str(_ReadSaveText()).is_equal(departure_text)
	# 模拟关游戏（丢弃运行态与核心）→ 继续：读档回出发前时点
	save_manager.current = null
	state.core = GuildCore.new()
	var loaded: SaveData = save_manager.load_game()
	assert_object(loaded).is_not_null()
	assert_bool(save_manager.is_expedition_locked()).is_false()
	assert_bool(state.has_guild_data()).is_true()
	var restored: QuestInstance = state.core.board.find_accepted_by_template(
			&"q_lair_purge")
	assert_object(restored).is_not_null()
	assert_int(restored.state).is_equal(QuestInstance.State.ACCEPTED)
	assert_int(state.core.day).is_equal(2)
	assert_int(state.core.board.in_progress_count()).is_equal(0)
	state.free()
	save_manager.free()

func test_return_day_re_expedition_allowed() -> void:
	## 组合 7：回城当日（补结算推进后）再编队再出征——last_expedition_day < day
	## 放行（回城日 ≠ 出发日）；二次出征额度锚回城日（同日重复拦截的单元口径
	## 见 test_quest_outlet_matrix.test_daily_quota_gate_rejects_same_day）
	var inst: QuestInstance = _SpawnAndStart(&"q_lair_purge", 3)
	var party: Array[StringName] = inst.party_ids.duplicate()
	_core.settle_expedition(_MakeRun(&"q_lair_purge", 3, 1),
			GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(_core.day).is_equal(2)
	for member_id: StringName in party:
		assert_int(_core.find_member(member_id).last_expedition_day).is_equal(1)
	# 回城当日再编队再出征：放行
	var again: QuestInstance = _core.board.spawn_on_board(&"q_lair_purge", _core.day)
	assert_bool(_core.accept_quest(again.serial, party)).is_true()
	assert_bool(_core.start_expedition(again.serial)).is_true()
	assert_int(_core.board.in_progress_count()).is_equal(1)
	# 二次出征额度锚回城日
	for member_id: StringName in party:
		assert_int(_core.find_member(member_id).last_expedition_day).is_equal(2)

func test_battle_exit_tree_holds_lock_for_explore_return() -> void:
	## 组合 8：explore→battle（return_to=EXPLORE）——battle `_exit_tree` 判定
	## `_HoldsExpeditionLock` 持锁跳过（锁随会话移交宿主屏）；会话结束去向
	##（公会壳）正常释放
	var save_manager: Node = get_tree().root.get_node("SaveManager")
	save_manager.set_expedition_lock(true)
	var battle: Control = (load(BATTLE_SCENE) as PackedScene).instantiate()
	add_child(battle)
	auto_free(battle)
	# 回探索会话：持锁跳过（不释放）
	battle._return_to = SceneManagerScript.SceneId.EXPLORE_SCREEN
	battle._exit_tree()
	assert_bool(save_manager.is_expedition_locked()).is_true()
	# 会话结束（返回公会壳/无回向）：释放
	battle._return_to = -1
	battle._exit_tree()
	assert_bool(save_manager.is_expedition_locked()).is_false()

func test_begin_then_go_fail_full_rollback() -> void:
	## 组合 9：begin 成功但 go 失败三路回退（association_screen go 失败分支的
	## 回退序列复现）——释锁 + 委托回 ACCEPTED + 出征日标记恢复；回退后可
	## 重新出征（三路回退不再全堵）
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	state.new_game()
	var core: GuildCore = state.core
	var inst: QuestInstance = core.board.spawn_on_board(&"q_lair_purge", core.day)
	var party: Array[StringName] = [core.roster[0].unit_id,
			core.roster[1].unit_id, core.roster[2].unit_id]
	assert_bool(core.accept_quest(inst.serial, party)).is_true()
	# 出征日标记快照（go 失败回退用——association_screen 同口径）
	var previous_days: Dictionary = {}
	for member_id: StringName in inst.party_ids:
		previous_days[String(member_id)] = \
				core.find_member(member_id).last_expedition_day
	var run: ExpeditionRun = state.begin_expedition(inst)
	assert_object(run).is_not_null()
	assert_int(inst.state).is_equal(QuestInstance.State.IN_PROGRESS)
	assert_bool(save_manager.is_expedition_locked()).is_true()
	for member_id: StringName in party:
		assert_int(core.find_member(member_id).last_expedition_day).is_equal(1)
	# 模拟 go 失败（SceneManager 拒重入/装载失败分支）——三路回退
	save_manager.set_expedition_lock(false)
	assert_bool(core.abort_expedition(inst.serial, previous_days)).is_true()
	assert_bool(save_manager.is_expedition_locked()).is_false()
	assert_int(inst.state).is_equal(QuestInstance.State.ACCEPTED)
	for member_id: StringName in party:
		assert_int(core.find_member(member_id).last_expedition_day).is_equal(0)
	# 回退后同批成员可重新出征（标记恢复——每日一次不再拦）
	assert_bool(core.start_expedition(inst.serial)).is_true()
	assert_int(inst.state).is_equal(QuestInstance.State.IN_PROGRESS)
	state.free()
	save_manager.free()

func test_same_template_settle_match_priority_matrix() -> void:
	## 组合 10：同模板挂单并存结算匹配三档——①serial 携带=精确命中该实例；
	## ②无 serial=IN_PROGRESS 优先；③无 serial 且无 IN_PROGRESS=同模板首匹配
	# ①serial 精确：IN_PROGRESS 实例与 ACCEPTED 副本并存 → 命中出征实例
	#（同模板挂单并存已被 G-2 接取拦截——正常流程不可达，副本直塞挂单数组
	# 模拟历史脏档/数据异常兜底场景）
	var in_progress: QuestInstance = _SpawnAndStart(&"q_vein_survey", 2)
	var accepted_copy := QuestInstance.new()
	accepted_copy.serial = 9001
	accepted_copy.template_id = &"q_vein_survey"
	accepted_copy.state = QuestInstance.State.ACCEPTED
	accepted_copy.expire_day = 99
	accepted_copy.party_ids = [_core.roster[2].unit_id, _core.roster[3].unit_id]
	_core.board.accepted.append(accepted_copy)
	var run_a := _MakeRun(&"q_vein_survey", 2)
	run_a.quest_serial = in_progress.serial
	_core.settle_expedition(run_a, GuildCore.ExpeditionOutcome.RETREAT)
	assert_object(_core.board.find_accepted(in_progress.serial)).is_null()
	assert_object(_core.board.find_accepted(accepted_copy.serial)).is_not_null()
	# ②无 serial：IN_PROGRESS 优先——副本升进行中再造一份 ACCEPTED 并存
	assert_bool(_core.start_expedition(accepted_copy.serial)).is_true()
	var idle_copy: QuestInstance = _core.board.grant_to_accepted(&"q_vein_survey", _core.day)
	var run_b := _MakeRun(&"q_vein_survey", 2)
	run_b.party = [_core.roster[2], _core.roster[3]]
	_core.settle_expedition(run_b, GuildCore.ExpeditionOutcome.RETREAT)
	assert_object(_core.board.find_accepted(accepted_copy.serial)).is_null()
	assert_object(_core.board.find_accepted(idle_copy.serial)).is_not_null()
	# ③无 serial 且无 IN_PROGRESS：同模板首匹配（数组首份命中、余份保留）
	var second_idle: QuestInstance = _core.board.grant_to_accepted(&"q_vein_survey", _core.day)
	var run_c := _MakeRun(&"q_vein_survey", 2)
	_core.settle_expedition(run_c, GuildCore.ExpeditionOutcome.RETREAT)
	assert_object(_core.board.find_accepted(idle_copy.serial)).is_null()
	assert_object(_core.board.find_accepted(second_idle.serial)).is_not_null()
