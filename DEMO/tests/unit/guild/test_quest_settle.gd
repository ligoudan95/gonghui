## 委托回城结算单元测试（M4 批 1）
## 覆盖：成功（奖励×超额 ×(1+0.15×超额) 货币经验、声望不加、explore 满编 1.3）/战败
##（全队重伤休养 3 天、宿舍 Lv2 缩 2）/撤退/判据失败（均无奖励）/挂单跨补结算
## 到期失败/出征委托先结算不被补结算误判/授予委托转挂单（防重）/事件累计入账/
## 板凳分享（基数=基础经验不含超额，拍板④）/锁序（settle_expedition 前释锁）。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## SaveManager 脚本路径（锁序用例）
const SAVE_MANAGER_SCRIPT: String = "res://scripts/autoload/save_manager.gd"
## GuildState 脚本路径（锁序用例）
const GUILD_STATE_SCRIPT: String = "res://scripts/autoload/guild_state.gd"
## 存档目录（锁序用例清理）
const SAVE_PATH: String = "user://saves/main_save.json"

## 套件级 GameData 与 GuildCore
var _game_data: Node
var _core: GuildCore

func before_test() -> void:
	## 用例级前置：GameData 实例 + 固定种子核心
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()
	_core = GuildCore.new()
	_core.setup(_Cfg(), _game_data, _MakeRng(201))

func after_test() -> void:
	## 用例级后置：释放 GameData、清理存档目录（锁序用例写盘）
	_game_data.free()
	_CleanSaveDir()

func _Cfg() -> CoreConfig:
	## 总控配置读取口
	return _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig

func _MakeRng(seed_value: int) -> RandomNumberGenerator:
	## 固定种子随机源
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _CleanSaveDir() -> void:
	## 清理 user://saves（锁序用例防互染）
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

func _SpawnAndStart(template_id: StringName, party_count: int) -> QuestInstance:
	## 装配并出征一个指定模板委托（板清空后定点生成——确定性）
	var inst: QuestInstance = _core.board.spawn_on_board(template_id, 1)
	var party: Array[StringName] = []
	for index: int in party_count:
		party.append(_core.roster[index].unit_id)
	assert_bool(_core.accept_quest(inst.serial, party)).is_true()
	assert_bool(_core.start_expedition(inst.serial)).is_true()
	return inst

func _MakeRun(template_id: StringName, party_count: int, total_days: int = 1) -> ExpeditionRun:
	## 构建出征会话（队员=名册前 N 人引用；判据上下文按模板对齐）
	var run := ExpeditionRun.new()
	run.base_days = total_days
	for index: int in party_count:
		run.party.append(_core.roster[index])
	run.quest_template_id = template_id
	var tpl: QuestTemplateDef = _game_data.get_record(template_id) as QuestTemplateDef
	if tpl != null:
		run.goal_kind = tpl.goal_type
		run.goal_param = tpl.goal_param
	return run

func test_success_clear_full_party_excess_bonus() -> void:
	## 成功出口：clear 3-4 人力满编 4 → 超额 1 → ×1.15（货币 172.5 四舍五入 173、
	## 经验 92；声望不加超额=5——案 17 §3.7）
	_SpawnAndStart(&"q_lair_purge", 4)
	var gold_before: int = _core.gold
	var summary = _core.settle_expedition(_MakeRun(&"q_lair_purge", 4),
			GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(_core.gold - gold_before).is_equal(173)
	assert_int(summary.gold_gained).is_equal(173)
	assert_int(_core.reputation).is_equal(5)
	assert_int(summary.quest_exp_final).is_equal(92)
	# 出战者各得全额（含超额）——92 < 100 不升级
	for index: int in 4:
		assert_int(_core.roster[index].exp).is_equal(92)
		assert_int(_core.roster[index].level).is_equal(1)
	# 委托移除+占用释放
	assert_int(_core.board.accepted.size()).is_equal(0)
	assert_int(_core.board.occupied_member_ids().size()).is_equal(0)

func test_success_explore_full_party_x130() -> void:
	## 成功出口：explore 2-4 人力满编 4 → 超额 2 → ×1.3（195 金/104 经验——
	## 案 18 §2.6 自洽注口径复核；104 ≥ 100 → 出战者升 2 级余 4）
	_SpawnAndStart(&"q_vein_survey", 4)
	var gold_before: int = _core.gold
	var summary = _core.settle_expedition(_MakeRun(&"q_vein_survey", 4),
			GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(_core.gold - gold_before).is_equal(195)
	assert_int(summary.quest_exp_final).is_equal(104)
	for index: int in 4:
		assert_int(_core.roster[index].level).is_equal(2)
		assert_int(_core.roster[index].exp).is_equal(4)

func test_success_min_party_no_excess_and_bench_share() -> void:
	## 成功出口：clear 下限 3 人编队 → 无超额（150/80/5）；第 4 人板凳分享
	## 基础经验 80×0.3=24（拍板④：基数不含超额）
	_SpawnAndStart(&"q_lair_purge", 3)
	var gold_before: int = _core.gold
	var summary = _core.settle_expedition(_MakeRun(&"q_lair_purge", 3),
			GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(_core.gold - gold_before).is_equal(150)
	assert_int(summary.quest_exp_final).is_equal(80)
	for index: int in 3:
		assert_int(_core.roster[index].exp).is_equal(80)
	# 板凳成员（第 4 人，健康）= 24
	assert_int(_core.roster[3].exp).is_equal(24)
	assert_int(int(summary.bench_exp.get(String(_core.roster[3].unit_id), 0))).is_equal(24)

func test_defeat_injures_party() -> void:
	## 战败出口：全队重伤休养 3 天（宿舍 Lv1 基础值）；无奖励；委托移除
	_SpawnAndStart(&"q_lair_purge", 3)
	var gold_before: int = _core.gold
	var summary = _core.settle_expedition(_MakeRun(&"q_lair_purge", 3),
			GuildCore.ExpeditionOutcome.DEFEAT)
	assert_int(_core.gold).is_equal(gold_before)
	assert_int(_core.reputation).is_equal(0)
	assert_int(summary.injury_rest_days).is_equal(3)
	for index: int in 3:
		assert_int(_core.roster[index].status).is_equal(AdventurerData.Status.RESTING)
		# 基础 3 天 − 补结算 1 天（回城申报耗时的日结算照常推进休养）
		assert_int(_core.roster[index].rest_days).is_equal(2)
	# 板凳成员不受牵连
	assert_int(_core.roster[3].status).is_equal(AdventurerData.Status.HEALTHY)
	assert_int(_core.board.accepted.size()).is_equal(0)
	# 休养逐日恢复：补结算后余 2 天，再 2 次日结算归零转健康
	_core.settle_one_day()
	assert_int(_core.roster[0].status).is_equal(AdventurerData.Status.RESTING)
	_core.settle_one_day()
	assert_int(_core.roster[0].status).is_equal(AdventurerData.Status.HEALTHY)

func test_defeat_rest_shortened_by_dorm_lv2() -> void:
	## 战败休养：宿舍 Lv2 缩减 −1 → 2 天（17 案 §3.5）
	_core.gold = 1000
	assert_bool(_core.upgrade_facility(&"fac_dormitory")).is_true()
	_SpawnAndStart(&"q_lair_purge", 3)
	var summary = _core.settle_expedition(_MakeRun(&"q_lair_purge", 3),
			GuildCore.ExpeditionOutcome.DEFEAT)
	assert_int(summary.injury_rest_days).is_equal(2)
	# 2 天 − 补结算 1 天 → 余 1
	assert_int(_core.roster[0].rest_days).is_equal(1)

func test_retreat_no_reward_no_injury() -> void:
	## 撤退出口：无奖励无重伤（#7 口径）
	_SpawnAndStart(&"q_lair_purge", 3)
	var gold_before: int = _core.gold
	var summary = _core.settle_expedition(_MakeRun(&"q_lair_purge", 3),
			GuildCore.ExpeditionOutcome.RETREAT)
	assert_int(_core.gold).is_equal(gold_before)
	assert_int(summary.gold_gained).is_equal(0)
	assert_int(summary.injury_rest_days).is_equal(0)
	assert_int(_core.roster[0].status).is_equal(AdventurerData.Status.HEALTHY)
	assert_int(_core.board.accepted.size()).is_equal(0)

func test_goal_failed_no_reward_no_injury() -> void:
	## 判据失败出口：同撤退口径（无奖励、不触发重伤）
	_SpawnAndStart(&"q_vein_survey", 2)
	var gold_before: int = _core.gold
	var summary = _core.settle_expedition(_MakeRun(&"q_vein_survey", 2),
			GuildCore.ExpeditionOutcome.GOAL_FAILED)
	assert_int(_core.gold).is_equal(gold_before)
	assert_int(summary.injury_rest_days).is_equal(0)
	assert_int(_core.board.accepted.size()).is_equal(0)

func test_accepted_quest_expires_during_catchup() -> void:
	## 挂单跨补结算到期失败：A 出征中（explore 2 人）、B 挂单（explore 2 人，
	## 到期线 6）；出征 6 天补结算至 day7 → B 在 day6 结算到期自动失败（无奖励）
	var quest_a: QuestInstance = _SpawnAndStart(&"q_vein_survey", 2)
	var quest_b: QuestInstance = _core.board.spawn_on_board(&"q_north_survey", 1)
	var party_b: Array[StringName] = [
		_core.roster[2].unit_id, _core.roster[3].unit_id,
	]
	assert_bool(_core.accept_quest(quest_b.serial, party_b)).is_true()
	_core.settle_expedition(_MakeRun(&"q_vein_survey", 2, 6),
			GuildCore.ExpeditionOutcome.SUCCESS)
	# 出征委托 A 先结算不被补结算误判（成功入账、非到期失败；2 人下限编队无超额=150）
	assert_int(_core.gold).is_equal(500 + 150)
	# B 到期失败：挂单清空
	assert_int(_core.board.accepted.size()).is_equal(0)
	assert_int(_core.day).is_equal(7)

func test_granted_quests_convert_to_accepted() -> void:
	## 授予委托转挂单（C8）：回城时逐个转挂单；M3/Z-2 修复口径——转挂单在
	## 补结算**之后**（expire_day 以推进后终 day 起算：day 1+补结算 1=2，
	## 2+模板时限 7=9）；同模板防重（18-C6）
	_SpawnAndStart(&"q_vein_survey", 2)
	var run := _MakeRun(&"q_vein_survey", 2)
	run.granted_quests.append(&"q_lost_miner_keepsake")
	run.granted_quests.append(&"q_lost_miner_keepsake")
	var summary = _core.settle_expedition(run, GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(_core.board.accepted.size()).is_equal(1)
	var granted: QuestInstance = _core.board.accepted[0]
	assert_str(String(granted.template_id)).is_equal("q_lost_miner_keepsake")
	assert_int(granted.state).is_equal(QuestInstance.State.ACCEPTED)
	assert_int(granted.expire_day).is_equal(9)
	assert_int(summary.quests_granted.size()).is_equal(1)

func test_granted_quest_survives_long_catchup() -> void:
	## M3/Z-2 回归：长途出征（total_days 7 ≥ 时限 7）期间授予的委托不再
	##「授予即到期」——补结算推进至 day 8 后转挂单，到期线 8+7=15 存活
	_SpawnAndStart(&"q_vein_survey", 2)
	var run := _MakeRun(&"q_vein_survey", 2, 7)
	run.granted_quests.append(&"q_lost_miner_keepsake")
	_core.settle_expedition(run, GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(_core.day).is_equal(8)
	assert_int(_core.board.accepted.size()).is_equal(1)
	var granted: QuestInstance = _core.board.accepted[0]
	assert_str(String(granted.template_id)).is_equal("q_lost_miner_keepsake")
	assert_int(granted.expire_day).is_equal(15)

func test_settle_idempotent_on_repeat() -> void:
	## G-2 回归：settle_expedition 幂等——二次调用返回空摘要，不重复入账/
	## 推日历/移除实例
	_SpawnAndStart(&"q_lair_purge", 3)
	var run := _MakeRun(&"q_lair_purge", 3)
	var first = _core.settle_expedition(run, GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(first.gold_gained).is_equal(150)
	var gold_after: int = _core.gold
	var day_after: int = _core.day
	var second = _core.settle_expedition(run, GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(second.gold_gained).is_equal(0)
	assert_int(_core.gold).is_equal(gold_after)
	assert_int(_core.day).is_equal(day_after)

func test_same_template_copies_settle_by_serial_and_progress() -> void:
	## G-2 根修回归：同模板「板上+挂单」并存（历史脏档/数据异常兜底）——
	## 结算命中 IN_PROGRESS 实例（serial 携带时精确匹配；未携带时
	## IN_PROGRESS 优先），板上副本不误删
	var inst: QuestInstance = _SpawnAndStart(&"q_vein_survey", 2)
	# 手造同模板板上副本（正常流程已被源头拦截——防御纵深用例）
	var board_copy: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", 1)
	var run := _MakeRun(&"q_vein_survey", 2)
	run.quest_serial = inst.serial
	_core.settle_expedition(run, GuildCore.ExpeditionOutcome.SUCCESS)
	# 出征实例（IN_PROGRESS）已移除；板上副本仍在板
	assert_int(_core.board.find_accepted(inst.serial) != null).is_equal(false)
	assert_int(_core.board.find_on_board(board_copy.serial) != null).is_equal(true)
	assert_int(_core.board.in_progress_count()).is_equal(0)
	# 未携带 serial 的旧式 run：IN_PROGRESS 优先匹配同样命中（再造一组）
	var inst_b: QuestInstance = _SpawnAndStart(&"q_north_survey", 2)
	_core.board.spawn_on_board(&"q_north_survey", 1)
	var legacy_run := _MakeRun(&"q_north_survey", 2)
	_core.settle_expedition(legacy_run, GuildCore.ExpeditionOutcome.RETREAT)
	assert_int(_core.board.find_accepted(inst_b.serial) != null).is_equal(false)
	assert_int(_core.board.in_progress_count()).is_equal(0)

func test_run_rewards_cashed_in() -> void:
	## 事件/宝箱累计奖励入账（M3 只累计 → 回城入账；不吃超额系数；事件经验
	## 出战者各得全额）
	_SpawnAndStart(&"q_lair_purge", 3)
	var run := _MakeRun(&"q_lair_purge", 3)
	run.add_reward(15, 20, 1)
	var gold_before: int = _core.gold
	var summary = _core.settle_expedition(run, GuildCore.ExpeditionOutcome.SUCCESS)
	# 委托 150 + 事件金 20
	assert_int(_core.gold - gold_before).is_equal(170)
	assert_int(summary.gold_gained).is_equal(170)
	assert_int(_core.reputation).is_equal(6)
	# 出战者经验 = 委托 80 + 事件 15
	for index: int in 3:
		assert_int(_core.roster[index].exp).is_equal(95)

func test_lock_released_before_return_settled_autosave() -> void:
	## 锁序用例：settle_expedition 前释锁——出征锁生效期间经 GuildState 回城结算，
	## RETURN_SETTLED autosave 不被 #26 跳过（save_written 收到时点）
	var save_manager: Node = load(SAVE_MANAGER_SCRIPT).new()
	add_child(save_manager)
	var state: Node = load(GUILD_STATE_SCRIPT).new()
	add_child(state)
	var rng := _MakeRng(202)
	state._rng = rng
	state.bind(save_manager, _game_data)
	state.new_game()
	var inst: QuestInstance = state.core.board.spawn_on_board(&"q_lair_purge", 1)
	var party: Array[StringName] = []
	for index: int in 3:
		party.append(state.core.roster[index].unit_id)
	assert_bool(state.core.accept_quest(inst.serial, party)).is_true()
	assert_bool(state.core.start_expedition(inst.serial)).is_true()
	save_manager.set_expedition_lock(true)
	var run := ExpeditionRun.new()
	run.base_days = 1
	for index: int in 3:
		run.party.append(state.core.roster[index])
	run.quest_template_id = &"q_lair_purge"
	var written_points: Array = []
	var callback: Callable = func(point: SaveData.SavePoint) -> void: written_points.append(point)
	save_manager.save_written.connect(callback)
	state.settle_expedition(run, GuildCore.ExpeditionOutcome.SUCCESS)
	# RETURN_SETTLED 已实际写盘（锁已先释放）
	assert_int(written_points.size()).is_equal(1)
	assert_int(written_points[0]).is_equal(SaveData.SavePoint.RETURN_SETTLED)
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_true()
	state.free()
	save_manager.free()
