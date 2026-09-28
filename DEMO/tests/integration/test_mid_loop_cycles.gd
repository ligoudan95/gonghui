## 中循环委托运转集成测试（M5 批 1）
## 覆盖：new_game → 多轮委托循环全链模拟（真 autoload GuildState/SaveManager，
## 无 UI 交互）——成功×2 连续复用 / 战败重伤→恢复→同批复用 / 撤退+挂单等待
## 到期失败 / 事件授予转挂单→重编队→完成。断言贯穿全程：in_progress_count
## 恒 ≤1、人力占用守恒（释放后可复用）、经济只增不减（本套件无招募/升级消费）。
extends GdUnitTestSuite

func before_test() -> void:
	## 用例级前置：复位 SceneManager/SaveManager/GuildState 可变状态 + 清存档目录
	_CleanSaveDir()
	var root: Node = get_tree().root
	var scene_manager: Node = root.get_node_or_null("SceneManager")
	if scene_manager != null:
		scene_manager.current_id = -1
		scene_manager.previous_id = -1
		var no_params: Dictionary = {}
		scene_manager.pending_params = no_params
	var save_manager: Node = root.get_node_or_null("SaveManager")
	if save_manager != null:
		save_manager.current = null
		save_manager.set_expedition_lock(false)
	var guild_state: Node = root.get_node_or_null("GuildState")
	if guild_state != null:
		guild_state.core = GuildCore.new()

func after_test() -> void:
	## 用例级后置：清存档目录 + 复位真 autoload 出征锁与运行态
	_CleanSaveDir()
	var save_manager: Node = get_tree().root.get_node_or_null("SaveManager")
	if save_manager != null:
		save_manager.current = null
		save_manager.set_expedition_lock(false)

func _CleanSaveDir() -> void:
	## 清理 user://saves 全部文件
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

func _GuildState() -> Node:
	## 取 GuildState autoload
	return get_tree().root.get_node("GuildState")

func _Core() -> GuildCore:
	## 取公会核心
	return _GuildState().core

func _SaveManager() -> Node:
	## 取 SaveManager autoload
	return get_tree().root.get_node("SaveManager")

func _NewGame() -> void:
	## 建新档（GuildState 入口——生产口径）
	_GuildState().new_game()

func _Ids(indexes: Array) -> Array[StringName]:
	## 名册下标列表 -> 成员 id 列表（形参无类型化——字面量实参兼容）
	var ids: Array[StringName] = []
	for index: int in indexes:
		ids.append(_Core().roster[int(index)].unit_id)
	return ids

func _AssertInProgressAtMostOne() -> void:
	## 全程断言：进行中战斗委托恒 ≤1（#23 同时 1 个上限）
	assert_int(_Core().board.in_progress_count()).is_less_equal(1)

func test_cycle_success_chain_reusable_and_monotonic_economy() -> void:
	## 循环 A/A'：成功→同模板同批成员再出征再成功——占用释放可复用、
	## 经济单调不减（500→650→800）、板凳两轮入账、出征锁随 begin/settle 开合
	_NewGame()
	var core: GuildCore = _Core()
	var gold_trace: Array[int] = [core.gold]
	# 循环 A：接 q_lair_purge（前 3 人）→ begin（锁）→ SUCCESS
	var inst_a: QuestInstance = core.board.spawn_on_board(&"q_lair_purge", core.day)
	assert_bool(core.accept_quest(inst_a.serial, _Ids([0, 1, 2]))).is_true()
	var run_a: ExpeditionRun = _GuildState().begin_expedition(inst_a)
	assert_object(run_a).is_not_null()
	assert_bool(_SaveManager().is_expedition_locked()).is_true()
	_AssertInProgressAtMostOne()
	var summary_a: Variant = _GuildState().settle_expedition(run_a,
			GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(summary_a.gold_gained).is_equal(150)
	assert_bool(_SaveManager().is_expedition_locked()).is_false()
	assert_int(core.day).is_equal(2)
	assert_int(core.roster[3].exp).is_equal(24)
	assert_int(core.board.occupied_member_ids().size()).is_equal(0)
	_AssertInProgressAtMostOne()
	gold_trace.append(core.gold)
	# 循环 A'：同模板同批成员再出征（last=1 < day=2 放行——占用守恒复用）
	var inst_b: QuestInstance = core.board.spawn_on_board(&"q_lair_purge", core.day)
	assert_bool(core.accept_quest(inst_b.serial, _Ids([0, 1, 2]))).is_true()
	var run_b: ExpeditionRun = _GuildState().begin_expedition(inst_b)
	assert_object(run_b).is_not_null()
	_AssertInProgressAtMostOne()
	_GuildState().settle_expedition(run_b, GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(core.gold).is_equal(800)
	# 板凳两轮：roster[3] 24+24=48；声望两轮 10
	assert_int(core.roster[3].exp).is_equal(48)
	assert_int(core.reputation).is_equal(10)
	_AssertInProgressAtMostOne()
	gold_trace.append(core.gold)
	# 经济只增不减
	for index: int in range(1, gold_trace.size()):
		assert_int(gold_trace[index]).is_greater_equal(gold_trace[index - 1])

func test_cycle_defeat_recovery_and_occupation_conservation() -> void:
	## 循环 B：战败重伤（零入账+释放+板凳不受牵连）→ 重伤成员不可即编 →
	## 板凳成员顶上撤退 → 恢复后同批成员复用（占用守恒）
	_NewGame()
	var core: GuildCore = _Core()
	var inst_a: QuestInstance = core.board.spawn_on_board(&"q_vein_survey", core.day)
	assert_bool(core.accept_quest(inst_a.serial, _Ids([0, 1]))).is_true()
	var run_a: ExpeditionRun = _GuildState().begin_expedition(inst_a)
	var gold_at_defeat: int = core.gold
	var summary_a: Variant = _GuildState().settle_expedition(run_a,
			GuildCore.ExpeditionOutcome.DEFEAT)
	assert_int(core.gold).is_equal(gold_at_defeat)
	assert_int(summary_a.injury_rest_days).is_equal(3)
	assert_int(core.board.occupied_member_ids().size()).is_equal(0)
	_AssertInProgressAtMostOne()
	# 重伤成员：占用已释放但健康校验拦截新编队
	var inst_b: QuestInstance = core.board.spawn_on_board(&"q_vein_survey", core.day)
	assert_bool(core.accept_quest(inst_b.serial, _Ids([0, 1]))).is_false()
	assert_str(core.last_error).contains("非健康态")
	# 板凳成员顶上（不受牵连）：同日可接可出征，走 RETREAT
	assert_bool(core.accept_quest(inst_b.serial, _Ids([2, 3]))).is_true()
	var run_b: ExpeditionRun = _GuildState().begin_expedition(inst_b)
	assert_object(run_b).is_not_null()
	_GuildState().settle_expedition(run_b, GuildCore.ExpeditionOutcome.RETREAT)
	assert_int(core.day).is_equal(3)
	# 恢复链：DEFEAT 补结算 day2（rest 3→2）→ RETREAT 补结算 day3（2→1）→
	# wait day4（1→0 转健康）→ 同批成员复用出征成功
	_GuildState().wait_one_day()
	assert_int(core.day).is_equal(4)
	assert_int(core.roster[0].status).is_equal(AdventurerData.Status.HEALTHY)
	assert_int(core.roster[1].status).is_equal(AdventurerData.Status.HEALTHY)
	var inst_c: QuestInstance = core.board.spawn_on_board(&"q_vein_survey", core.day)
	assert_bool(core.accept_quest(inst_c.serial, _Ids([0, 1]))).is_true()
	var run_c: ExpeditionRun = _GuildState().begin_expedition(inst_c)
	assert_object(run_c).is_not_null()
	_AssertInProgressAtMostOne()
	var summary_c: Variant = _GuildState().settle_expedition(run_c,
			GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(summary_c.gold_gained).is_equal(150)
	assert_int(core.board.occupied_member_ids().size()).is_equal(0)

func test_cycle_retreat_and_expiry_channels() -> void:
	## 循环 C/D：撤退（零入账零重伤+释放+次日复用）→ 挂单等待至到期失败
	##（占用释放后成员可再编队出征）
	_NewGame()
	var core: GuildCore = _Core()
	# 循环 C：RETREAT
	var inst_a: QuestInstance = core.board.spawn_on_board(&"q_vein_survey", core.day)
	assert_bool(core.accept_quest(inst_a.serial, _Ids([0, 1]))).is_true()
	var run_a: ExpeditionRun = _GuildState().begin_expedition(inst_a)
	var gold_before: int = core.gold
	var summary_a: Variant = _GuildState().settle_expedition(run_a,
			GuildCore.ExpeditionOutcome.RETREAT)
	assert_int(core.gold).is_equal(gold_before)
	assert_int(summary_a.injury_rest_days).is_equal(0)
	assert_int(core.board.occupied_member_ids().size()).is_equal(0)
	assert_int(core.day).is_equal(2)
	_AssertInProgressAtMostOne()
	# 循环 D：挂单等待至到期——上板日 2、时限 5 → day7 结算到期失败
	var inst_b: QuestInstance = core.board.spawn_on_board(&"q_north_survey", core.day)
	assert_int(inst_b.expire_day).is_equal(7)
	assert_bool(core.accept_quest(inst_b.serial, _Ids([2, 3]))).is_true()
	var failed_day: int = -1
	for _day_index: int in 5:
		var summary: GuildCore.DaySummary = _GuildState().wait_one_day()
		if summary.accepted_failed.has("q_north_survey"):
			failed_day = core.day
		_AssertInProgressAtMostOne()
	assert_int(failed_day).is_equal(7)
	assert_object(core.board.find_accepted(inst_b.serial)).is_null()
	assert_int(core.board.occupied_member_ids().size()).is_equal(0)
	# 到期失败释放后：从未出征的 r2/r3 可再编队出征（无额度占用）
	var inst_c: QuestInstance = core.board.spawn_on_board(&"q_north_survey", core.day)
	assert_bool(core.accept_quest(inst_c.serial, _Ids([2, 3]))).is_true()
	assert_bool(_GuildState().begin_expedition(inst_c) != null).is_true()
	_AssertInProgressAtMostOne()
	# 经济只增不减：等待不产钱也无惩罚
	assert_int(core.gold).is_equal(gold_before)

func test_cycle_granted_quest_loop() -> void:
	## 循环 E：事件授予（经 run.granted_quests 走 _ConvertGrantedQuests 转挂单
	## ——EventRunner 集成不新做）→ 空编队经重编队口指派 → 出征完成入账
	_NewGame()
	var core: GuildCore = _Core()
	var inst_a: QuestInstance = core.board.spawn_on_board(&"q_vein_survey", core.day)
	assert_bool(core.accept_quest(inst_a.serial, _Ids([0, 1]))).is_true()
	var run_a: ExpeditionRun = _GuildState().begin_expedition(inst_a)
	assert_object(run_a).is_not_null()
	# 出征会话中被授予委托 → 回城转挂单
	run_a.granted_quests.append(&"q_lost_miner_keepsake")
	var summary_a: Variant = _GuildState().settle_expedition(run_a,
			GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(core.day).is_equal(2)
	assert_int(summary_a.quests_granted.size()).is_equal(1)
	var granted: QuestInstance = core.board.find_accepted_by_template(
			&"q_lost_miner_keepsake")
	assert_object(granted).is_not_null()
	# 授予直入挂单：ACCEPTED、空编队、到期线=回城日 2 + 时限 7 = 9
	assert_int(granted.state).is_equal(QuestInstance.State.ACCEPTED)
	assert_int(granted.party_ids.size()).is_equal(0)
	assert_int(granted.expire_day).is_equal(9)
	assert_bool(core.has_unseen_grants).is_true()
	_AssertInProgressAtMostOne()
	# 经重编队口指派（授予挂单生命周期）→ 出征 → 完成循环
	assert_bool(core.reassign_party(granted.serial, _Ids([2, 3]))).is_true()
	var run_b: ExpeditionRun = _GuildState().begin_expedition(granted)
	assert_object(run_b).is_not_null()
	_AssertInProgressAtMostOne()
	var gold_before: int = core.gold
	var summary_b: Variant = _GuildState().settle_expedition(run_b,
			GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(summary_b.gold_gained).is_equal(150)
	assert_int(core.gold - gold_before).is_equal(150)
	assert_object(core.board.find_accepted_by_template(
			&"q_lost_miner_keepsake")).is_null()
	assert_int(core.board.occupied_member_ids().size()).is_equal(0)
