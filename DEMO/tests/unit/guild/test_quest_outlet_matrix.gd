## 五出口交叉矩阵单元测试（M5 批 1）
## 覆盖：SUCCESS/DEFEAT/RETREAT/GOAL_FAILED 四回城出口 + 挂单到期失败共五出口
## 交叉「实例移除 × 人力释放 × 进行中归零 × 同模板可再接 × 每日出征标记 ×
## 板凳 × 占用并集」状态矩阵（纯 GuildCore 层）；轻度占用×战斗出征互斥回归、
## 每日一次门禁单元口径、进行中上限与出口释放的交叉。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 与 GuildCore
var _game_data: Node
var _core: GuildCore

func before_test() -> void:
	## 用例级前置：GameData 实例 + 固定种子核心
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()
	_core = GuildCore.new()
	_core.setup(_Cfg(), _game_data, _MakeRng(601))

func after_test() -> void:
	## 用例级后置：释放 GameData
	_game_data.free()

func _Cfg() -> CoreConfig:
	## 总控配置读取口
	return _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig

func _MakeRng(seed_value: int) -> RandomNumberGenerator:
	## 固定种子随机源
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _RosterIds(indexes: Array) -> Array[StringName]:
	## 名册下标列表 -> 成员 id 列表（形参无类型化——range()/字面量实参兼容）
	var ids: Array[StringName] = []
	for index: int in indexes:
		ids.append(_core.roster[int(index)].unit_id)
	return ids

func _SpawnAndStart(template_id: StringName, party_count: int) -> QuestInstance:
	## 装配并出征一个指定模板委托（定点生成——确定性）
	var inst: QuestInstance = _core.board.spawn_on_board(template_id, 1)
	var party: Array[StringName] = _RosterIds(range(party_count))
	assert_bool(_core.accept_quest(inst.serial, party)).is_true()
	assert_bool(_core.start_expedition(inst.serial)).is_true()
	return inst

func _MakeRun(template_id: StringName, party_count: int,
		total_days: int = 1) -> ExpeditionRun:
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

func _AssertOutletReleased(inst: QuestInstance) -> void:
	## 五出口共同矩阵断言：实例移除/占用释放/进行中归零
	assert_object(_core.board.find_accepted(inst.serial)).is_null()
	assert_int(_core.board.accepted.size()).is_equal(0)
	assert_int(_core.board.occupied_member_ids().size()).is_equal(0)
	assert_int(_core.board.in_progress_count()).is_equal(0)

func test_success_outlet_full_release_matrix() -> void:
	## SUCCESS 出口矩阵：奖励入账 + 实例移除/占用释放/进行中归零 + 每日出征
	## 标记已消耗（锚出发日）+ 同模板可再接 + 回城日（day+1）再出征放行
	var inst: QuestInstance = _SpawnAndStart(&"q_lair_purge", 3)
	var party: Array[StringName] = inst.party_ids.duplicate()
	var gold_before: int = _core.gold
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(
			_MakeRun(&"q_lair_purge", 3), GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(summary.gold_gained).is_equal(150)
	assert_int(_core.gold - gold_before).is_equal(150)
	_AssertOutletReleased(inst)
	# 出征额度已消耗：标记锚出发日 1（补结算推进后 day=2）
	for member_id: StringName in party:
		assert_int(_core.find_member(member_id).last_expedition_day).is_equal(1)
	# 同模板可再接（旧实例已移除——G-2 不再拦截）
	var again: QuestInstance = _core.board.spawn_on_board(&"q_lair_purge", _core.day)
	assert_bool(_core.accept_quest(again.serial, party)).is_true()
	# 回城日 ≠ 出发日 → 同批成员可再出征
	assert_bool(_core.start_expedition(again.serial)).is_true()
	assert_int(_core.board.in_progress_count()).is_equal(1)

func test_success_bench_share_credited() -> void:
	## SUCCESS × 板凳分享入账：3 人下限编队无超额（150 金/5 声望）；板凳第 4 人
	## 基础经验 80×0.3=24（拍板④：基数不含超额）
	_SpawnAndStart(&"q_lair_purge", 3)
	var gold_before: int = _core.gold
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(
			_MakeRun(&"q_lair_purge", 3), GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(_core.gold - gold_before).is_equal(150)
	assert_int(_core.reputation).is_equal(5)
	assert_int(_core.roster[3].exp).is_equal(24)
	assert_int(int(summary.bench_exp.get(String(_core.roster[3].unit_id), 0))).is_equal(24)
	# 板凳成员不在出战明细（委托经验只给出战者）
	assert_bool(summary.exp_gained.has(String(_core.roster[3].unit_id))).is_false()

func test_defeat_outlet_full_release_matrix() -> void:
	## DEFEAT 出口矩阵：零入账 + 全队重伤（应用 3 − 补结算 1 = 余 2）+ 板凳不受
	## 牵连 + 占用释放 + 额度已消耗 + 重伤成员释放后不可即编（健康校验拦截）+
	## 同模板可再接（板凳成员顶上）
	var inst: QuestInstance = _SpawnAndStart(&"q_vein_survey", 2)
	var party: Array[StringName] = inst.party_ids.duplicate()
	var gold_before: int = _core.gold
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(
			_MakeRun(&"q_vein_survey", 2), GuildCore.ExpeditionOutcome.DEFEAT)
	assert_int(summary.gold_gained).is_equal(0)
	assert_int(_core.gold).is_equal(gold_before)
	assert_int(summary.injury_rest_days).is_equal(3)
	_AssertOutletReleased(inst)
	for index: int in 2:
		assert_int(_core.roster[index].status).is_equal(AdventurerData.Status.RESTING)
		assert_int(_core.roster[index].rest_days).is_equal(2)
		assert_int(_core.roster[index].last_expedition_day).is_equal(1)
	# 板凳成员（roster[2]/[3]）不受牵连
	assert_int(_core.roster[2].status).is_equal(AdventurerData.Status.HEALTHY)
	assert_int(_core.roster[3].status).is_equal(AdventurerData.Status.HEALTHY)
	# 占用已释放但重伤成员不可即编（释放 ≠ 可用——健康校验拦截）
	var again: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", _core.day)
	assert_bool(_core.accept_quest(again.serial, party)).is_false()
	assert_str(_core.last_error).contains("非健康态")
	# 同模板可再接：板凳成员顶上
	assert_bool(_core.accept_quest(again.serial, _RosterIds([2, 3]))).is_true()

func test_defeat_bench_member_can_expedition_same_day() -> void:
	## DEFEAT × 板凳交叉：出征队战败重伤——板凳成员同日（回城日）即可组队出征
	## （不受牵连的进阶：无出征标记占用）
	var inst: QuestInstance = _SpawnAndStart(&"q_vein_survey", 2)
	_core.settle_expedition(_MakeRun(&"q_vein_survey", 2),
			GuildCore.ExpeditionOutcome.DEFEAT)
	assert_int(_core.roster[0].status).is_equal(AdventurerData.Status.RESTING)
	assert_int(_core.roster[1].status).is_equal(AdventurerData.Status.RESTING)
	var again: QuestInstance = _core.board.spawn_on_board(&"q_north_survey", _core.day)
	assert_bool(_core.accept_quest(again.serial, _RosterIds([2, 3]))).is_true()
	assert_bool(_core.start_expedition(again.serial)).is_true()
	assert_int(_core.board.in_progress_count()).is_equal(1)

func test_retreat_outlet_full_release_matrix() -> void:
	## RETREAT 出口矩阵：零入账零重伤 + 全释放 + 额度已消耗（撤退不退额度）+
	## 同模板可再接 + 回城日再出征放行
	var inst: QuestInstance = _SpawnAndStart(&"q_lair_purge", 3)
	var party: Array[StringName] = inst.party_ids.duplicate()
	var gold_before: int = _core.gold
	var reputation_before: int = _core.reputation
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(
			_MakeRun(&"q_lair_purge", 3), GuildCore.ExpeditionOutcome.RETREAT)
	assert_int(summary.gold_gained).is_equal(0)
	assert_int(summary.injury_rest_days).is_equal(0)
	assert_int(_core.gold).is_equal(gold_before)
	assert_int(_core.reputation).is_equal(reputation_before)
	_AssertOutletReleased(inst)
	for member_id: StringName in party:
		var member: AdventurerData = _core.find_member(member_id)
		assert_int(member.status).is_equal(AdventurerData.Status.HEALTHY)
		# 撤退同样消耗当日出征额度（出征事实已发生）
		assert_int(member.last_expedition_day).is_equal(1)
	var again: QuestInstance = _core.board.spawn_on_board(&"q_lair_purge", _core.day)
	assert_bool(_core.accept_quest(again.serial, party)).is_true()
	assert_bool(_core.start_expedition(again.serial)).is_true()

func test_goal_failed_outlet_zero_reward_full_release() -> void:
	## GOAL_FAILED 出口（无 DEMO 触发器——直接构造 settle 验证代码路径）：
	## 无奖励无重伤 + 实例移除 + 占用释放 + 额度已消耗 + 同模板可再接
	var inst: QuestInstance = _SpawnAndStart(&"q_vein_survey", 2)
	var party: Array[StringName] = inst.party_ids.duplicate()
	var gold_before: int = _core.gold
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(
			_MakeRun(&"q_vein_survey", 2), GuildCore.ExpeditionOutcome.GOAL_FAILED)
	assert_int(summary.gold_gained).is_equal(0)
	assert_int(summary.injury_rest_days).is_equal(0)
	assert_int(summary.reputation_gained).is_equal(0)
	assert_int(_core.gold).is_equal(gold_before)
	_AssertOutletReleased(inst)
	for member_id: StringName in party:
		var member: AdventurerData = _core.find_member(member_id)
		assert_int(member.status).is_equal(AdventurerData.Status.HEALTHY)
		assert_int(member.last_expedition_day).is_equal(1)
	var again: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", _core.day)
	assert_bool(_core.accept_quest(again.serial, party)).is_true()

func test_expiration_failure_release_matrix() -> void:
	## 到期失败出口（日结算挂单通道）：挂单移除 + 占用释放 + 无奖励无重伤 +
	## 不涉及出征标记（成员同日即可再编队出征）
	var inst: QuestInstance = _core.board.spawn_on_board(&"q_north_survey", 1)
	var party: Array[StringName] = _RosterIds([2, 3])
	assert_bool(_core.accept_quest(inst.serial, party)).is_true()
	var failed_summary: GuildCore.DaySummary = null
	for _day_index: int in 5:
		var summary: GuildCore.DaySummary = _core.settle_one_day()
		if summary.accepted_failed.has("q_north_survey"):
			failed_summary = summary
	assert_object(failed_summary).is_not_null()
	assert_int(_core.day).is_equal(6)
	assert_object(_core.board.find_accepted(inst.serial)).is_null()
	assert_int(_core.board.occupied_member_ids().size()).is_equal(0)
	assert_int(_core.board.in_progress_count()).is_equal(0)
	assert_int(_core.gold).is_equal(500)
	for member_id: StringName in party:
		var member: AdventurerData = _core.find_member(member_id)
		# 到期失败不涉及出征标记（从未出征）
		assert_int(member.last_expedition_day).is_equal(0)
		assert_int(member.status).is_equal(AdventurerData.Status.HEALTHY)
	# 释放后同日可再编队出征（无额度占用）
	var again: QuestInstance = _core.board.spawn_on_board(&"q_north_survey", _core.day)
	assert_bool(_core.accept_quest(again.serial, party)).is_true()
	assert_bool(_core.start_expedition(again.serial)).is_true()

func test_light_occupation_blocks_battle_party_regression() -> void:
	## 轻度占用 × 战斗出征校验互斥回归：轻度编队成员被战斗委托编队拦截；
	## 轻度不占战斗名额（in_progress 不计轻度）也不消耗出征额度
	var light: QuestInstance = _core.board.spawn_on_board(&"q_chore_supply_run", 1)
	assert_bool(_core.start_light_quest(light.serial, [_core.roster[0].unit_id])).is_true()
	var battle: QuestInstance = _core.board.spawn_on_board(&"q_lair_purge", 1)
	# 编队含轻度占用成员 → 占用拦截
	assert_bool(_core.accept_quest(battle.serial,
			_RosterIds([0, 1, 2]))).is_false()
	assert_str(_core.last_error).contains("占用")
	# 不含占用成员的 3 人队照常接取出征（轻度不占战斗名额）
	assert_bool(_core.accept_quest(battle.serial,
			_RosterIds([1, 2, 3]))).is_true()
	assert_bool(_core.start_expedition(battle.serial)).is_true()
	assert_int(_core.board.in_progress_count()).is_equal(1)
	# 轻度编队成员出征额度未消耗
	assert_int(_core.roster[0].last_expedition_day).is_equal(0)

func test_occupied_union_two_pending_partial_release() -> void:
	## 占用并集 × 部分释放：两挂单并集占用 4 人；放弃其一 → 余集精确保持；
	## 全弃 → 空（并集口径不串扰）
	var inst_a: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", 1)
	var inst_b: QuestInstance = _core.board.spawn_on_board(&"q_north_survey", 1)
	assert_bool(_core.accept_quest(inst_a.serial, _RosterIds([0, 1]))).is_true()
	assert_bool(_core.accept_quest(inst_b.serial, _RosterIds([2, 3]))).is_true()
	assert_int(_core.board.occupied_member_ids().size()).is_equal(4)
	assert_bool(_core.abandon_quest(inst_a.serial)).is_true()
	var occupied: Array[StringName] = _core.board.occupied_member_ids()
	assert_int(occupied.size()).is_equal(2)
	assert_bool(occupied.has(_core.roster[2].unit_id)).is_true()
	assert_bool(occupied.has(_core.roster[3].unit_id)).is_true()
	assert_bool(_core.abandon_quest(inst_b.serial)).is_true()
	assert_int(_core.board.occupied_member_ids().size()).is_equal(0)

func test_daily_quota_gate_rejects_same_day() -> void:
	## 每日一次门禁单元：last_expedition_day == day 拒（今日已出征）；
	## == day-1 放行（昨日出征不占今日额度）
	var inst: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", 1)
	assert_bool(_core.accept_quest(inst.serial, _RosterIds([0, 1]))).is_true()
	_core.roster[0].last_expedition_day = _core.day
	assert_bool(_core.start_expedition(inst.serial)).is_false()
	assert_str(_core.last_error).contains("今日已出征")
	_core.roster[0].last_expedition_day = _core.day - 1
	assert_bool(_core.start_expedition(inst.serial)).is_true()

func test_in_progress_cap_after_outlet_release() -> void:
	## 出征进行中 × 挂单并存交叉：A 进行中时 B 出征被「同时 1 个」拦；
	## A 结算释放后 B 可出征（名额与占用双释放）
	var inst_a: QuestInstance = _SpawnAndStart(&"q_vein_survey", 2)
	var inst_b: QuestInstance = _core.board.spawn_on_board(&"q_north_survey", 1)
	assert_bool(_core.accept_quest(inst_b.serial, _RosterIds([2, 3]))).is_true()
	assert_bool(_core.start_expedition(inst_b.serial)).is_false()
	assert_str(_core.last_error).contains("同时 1 个")
	_core.settle_expedition(_MakeRun(&"q_vein_survey", 2, 2),
			GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(_core.board.in_progress_count()).is_equal(0)
	assert_bool(_core.start_expedition(inst_b.serial)).is_true()
	assert_int(_core.board.in_progress_count()).is_equal(1)
