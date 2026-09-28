## 委托板单元测试（M4 批 1）
## 覆盖：开局预生成 3（不放回、同批不重复）/周刷新同规则/到期三表现（刷新补位
## 不与在板重复、消失、替换=加急+3 天+奖励不变）/接取不补位/状态机迁移/
## 占用起点=编队确认+重编队转移+出征锁定/进行中 1 上限/每人每日一次（日结算过期）。
## 模式先例：纯逻辑类 new+注入（GameData 实例 + cfg + 固定种子 rng）。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 与 GuildCore
var _game_data: Node
var _core: GuildCore

func before_test() -> void:
	## 用例级前置：GameData 实例 + 固定种子核心（用例间隔离）
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()
	_core = GuildCore.new()
	_core.setup(_Cfg(), _game_data, _MakeRng(101))

func after_test() -> void:
	## 用例级后置：释放 GameData
	_game_data.free()

func _Cfg() -> CoreConfig:
	## 总控配置读取口
	return _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig

func _MakeRng(seed_value: int) -> RandomNumberGenerator:
	## 固定种子随机源（确定性用例）
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _BoardTemplateIds() -> Array[StringName]:
	## 板刷池全集（8 模板）
	var ids: Array[StringName] = []
	for tpl_id: StringName in _game_data.get_domain_ids(&"quest/templates"):
		var tpl: QuestTemplateDef = _game_data.get_record(tpl_id) as QuestTemplateDef
		if tpl.acquire_channel == QuestTemplateDef.AcquireChannel.BOARD:
			ids.append(tpl_id)
	return ids

func _RosterIds(count: int) -> Array[StringName]:
	## 名册前 count 人 id
	var ids: Array[StringName] = []
	for index: int in mini(count, _core.roster.size()):
		ids.append(_core.roster[index].unit_id)
	return ids

func test_initial_fill_draws_three_unique() -> void:
	## 开局预生成：恰 3 个、同批不重复、全部来自板刷池
	assert_int(_core.board.board.size()).is_equal(3)
	var seen: Dictionary = {}
	for inst: QuestInstance in _core.board.board:
		assert_bool(seen.has(inst.template_id)).is_false()
		seen[inst.template_id] = true
		assert_bool(_BoardTemplateIds().has(inst.template_id)).is_true()
		# 到期线=上板日 1+时限 5=6（不含上板当日）
		assert_int(inst.expire_day).is_equal(6)

func test_week_refresh_redraws_batch() -> void:
	## 周刷新：day8 日结算整板重抽 3、同批不重复（跨周重置=自全池重抽）
	for _day_index: int in range(7):
		_core.settle_one_day()
	assert_int(_core.day).is_equal(8)
	assert_int(_core.board.board.size()).is_equal(3)
	var seen: Dictionary = {}
	for inst: QuestInstance in _core.board.board:
		assert_bool(seen.has(inst.template_id)).is_false()
		seen[inst.template_id] = true

func test_expire_vanish_removes_only() -> void:
	## 到期表现=消失：仅移除不补位（q_shaft_echo 板上到期→板空合法）
	_core.board.board.clear()
	_core.board.spawn_on_board(&"q_shaft_echo", 1)
	while _core.day < 6:
		_core.settle_one_day()
	assert_int(_core.board.board.size()).is_equal(0)

func test_expire_refresh_refills_one() -> void:
	## 到期表现=刷新：移除+池内重抽补位 1（不与在板重复——本例移除后板空）
	_core.board.board.clear()
	_core.board.spawn_on_board(&"q_lair_purge", 1)
	while _core.day < 6:
		_core.settle_one_day()
	assert_int(_core.board.board.size()).is_equal(1)
	assert_bool(_BoardTemplateIds().has(_core.board.board[0].template_id)).is_true()

func test_expire_refresh_not_duplicate_on_board() -> void:
	## 刷新补位不与在板重复：板上留一个 q_lair_purge（已接的挂单不算在板），
	## 到期一个 q_bounty_boss → 补位不得再抽 q_lair_purge
	_core.board.board.clear()
	_core.board.spawn_on_board(&"q_lair_purge", 1)
	_core.board.spawn_on_board(&"q_bounty_boss", 1)
	while _core.day < 6:
		_core.settle_one_day()
	# day6 结算：q_bounty_boss 到期（REFRESH）移除补位；q_lair_purge 同日到期也移除补位
	# ——两行同时到期则两次补位互不重复，板上限 2
	assert_int(_core.board.board.size()).is_equal(2)
	var seen: Dictionary = {}
	for inst: QuestInstance in _core.board.board:
		assert_bool(seen.has(inst.template_id)).is_false()
		seen[inst.template_id] = true

func test_expire_replace_urgent_instance() -> void:
	## 到期表现=替换：同模板新实例「加急·」前缀+时限 3 天（cfg）+奖励不变（同模板）
	_core.board.board.clear()
	_core.board.spawn_on_board(&"q_vein_survey", 1)
	while _core.day < 6:
		_core.settle_one_day()
	assert_int(_core.board.board.size()).is_equal(1)
	var replaced: QuestInstance = _core.board.board[0]
	assert_str(String(replaced.template_id)).is_equal("q_vein_survey")
	assert_bool(replaced.urgent).is_true()
	assert_str(replaced.display_name(_game_data)).is_equal("加急·矿脉复查")
	# day6 替换 + 时限 3 → 到期线 9
	assert_int(replaced.expire_day).is_equal(9)
	var tpl: QuestTemplateDef = _game_data.get_record(&"q_vein_survey") as QuestTemplateDef
	assert_int(tpl.reward.gold).is_equal(150)

func test_accept_no_refill() -> void:
	## 接取不补位：板上 3 → 接 1 → 板上 2（空位不即时补充）
	var inst: QuestInstance = _core.board.board[0]
	var tpl: QuestTemplateDef = _game_data.get_record(inst.template_id) as QuestTemplateDef
	var party_size: int = tpl.party_min
	assert_bool(_core.accept_quest(inst.serial, _RosterIds(party_size))).is_true()
	assert_int(_core.board.board.size()).is_equal(2)
	assert_int(_core.board.accepted.size()).is_equal(1)

func test_state_machine_transitions() -> void:
	## 状态机：ON_BOARD→ACCEPTED（接取）→IN_PROGRESS（出征确认）→移除（放弃口径外的
	## 结算口在 test_quest_settle）；ACCEPTED→移除（到期/放弃）
	_core.board.board.clear()
	var inst: QuestInstance = _core.board.spawn_on_board(&"q_lair_purge", 1)
	assert_bool(_core.accept_quest(inst.serial, _RosterIds(3))).is_true()
	assert_int(inst.state).is_equal(QuestInstance.State.ACCEPTED)
	assert_bool(_core.start_expedition(inst.serial)).is_true()
	assert_int(inst.state).is_equal(QuestInstance.State.IN_PROGRESS)
	# 进行中不可放弃、不可重编队（锁定）
	assert_bool(_core.abandon_quest(inst.serial)).is_false()
	assert_bool(_core.reassign_party(inst.serial, _RosterIds(3))).is_false()

func test_abandon_releases_occupancy() -> void:
	## 放弃出口：ACCEPTED→移除、无惩罚、释放占用
	_core.board.board.clear()
	var inst: QuestInstance = _core.board.spawn_on_board(&"q_lair_purge", 1)
	assert_bool(_core.accept_quest(inst.serial, _RosterIds(3))).is_true()
	assert_bool(_core.abandon_quest(inst.serial)).is_true()
	assert_int(_core.board.accepted.size()).is_equal(0)
	assert_int(_core.board.occupied_member_ids().size()).is_equal(0)

func test_occupancy_starts_at_accept_and_transfers() -> void:
	## 占用起点=编队确认（挂单期即占用）+重编队转移+接取冲突拦截
	##（A 用 explore 2-4 人力区间——重编队可收到下限 2 人）
	_core.board.board.clear()
	var quest_a: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", 1)
	var quest_b: QuestInstance = _core.board.spawn_on_board(&"q_north_survey", 1)
	assert_bool(_core.accept_quest(quest_a.serial, _RosterIds(4))).is_true()
	# 全员被 A 占用：B 接取失败（无可用成员）
	assert_bool(_core.accept_quest(quest_b.serial, _RosterIds(2))).is_false()
	assert_str(_core.last_error).contains("已被其他委托占用")
	# 重编队转移：A 改为前 2 人 → 后 2 人释放
	assert_bool(_core.reassign_party(quest_a.serial, _RosterIds(2))).is_true()
	var occupied: Array[StringName] = _core.board.occupied_member_ids()
	assert_int(occupied.size()).is_equal(2)
	# 释放的 2 人可接 B
	assert_bool(_core.accept_quest(quest_b.serial, _RosterIds2From(2))).is_true()

func _RosterIds2From(start: int) -> Array[StringName]:
	## 名册自 start 起取 2 人 id（重编队释放段校验用）
	var ids: Array[StringName] = []
	ids.append(_core.roster[start].unit_id)
	ids.append(_core.roster[start + 1].unit_id)
	return ids

func test_in_progress_limit_one() -> void:
	## 战斗委托进行中同时 1 个（#23）：A 进行中 → B 出征确认被拦
	##（两单均 explore 2-4——名册 4 人可分出互不重叠的两队 2+2）
	_core.board.board.clear()
	var quest_a: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", 1)
	var quest_b: QuestInstance = _core.board.spawn_on_board(&"q_north_survey", 1)
	assert_bool(_core.accept_quest(quest_a.serial, _RosterIds(2))).is_true()
	assert_bool(_core.start_expedition(quest_a.serial)).is_true()
	assert_bool(_core.accept_quest(quest_b.serial, _RosterIds2From(2))).is_true()
	assert_bool(_core.start_expedition(quest_b.serial)).is_false()
	assert_str(_core.last_error).contains("同时 1 个")

func test_daily_once_expedition_gate() -> void:
	## 每人每日一次出征：同日再出征被拦（防御性约束——零耗时往返场景）；
	## 日结算自然过期（day+1 后可再出征）
	_core.board.board.clear()
	var quest_a: QuestInstance = _core.board.spawn_on_board(&"q_lair_purge", 1)
	var quest_b: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", 1)
	assert_bool(_core.accept_quest(quest_a.serial, _RosterIds(3))).is_true()
	assert_bool(_core.start_expedition(quest_a.serial)).is_true()
	# A 移除模拟结算完毕（占用释放），当日同人再出征 B → 拦截
	_core.board.remove(quest_a)
	assert_bool(_core.accept_quest(quest_b.serial, _RosterIds(3))).is_true()
	assert_bool(_core.start_expedition(quest_b.serial)).is_false()
	assert_str(_core.last_error).contains("每日一次")
	# 日结算过一天 → 限制自然过期
	_core.settle_one_day()
	assert_bool(_core.start_expedition(quest_b.serial)).is_true()

func test_resting_member_blocked() -> void:
	## 休养成员不可出征（编队校验）
	_core.board.board.clear()
	var quest_a: QuestInstance = _core.board.spawn_on_board(&"q_lair_purge", 1)
	_core.roster[0].status = AdventurerData.Status.RESTING
	_core.roster[0].rest_days = 2
	var party: Array[StringName] = [
		_core.roster[0].unit_id, _core.roster[1].unit_id, _core.roster[2].unit_id,
	]
	assert_bool(_core.accept_quest(quest_a.serial, party)).is_false()
	assert_str(_core.last_error).contains("非健康态")

func test_duplicate_party_member_blocked() -> void:
	## D-1：编队重复成员拦截（虚占席位/excess 计数失真）
	_core.board.board.clear()
	var quest_a: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", 1)
	var party: Array[StringName] = [
		_core.roster[0].unit_id, _core.roster[0].unit_id,
	]
	assert_bool(_core.accept_quest(quest_a.serial, party)).is_false()
	assert_str(_core.last_error).contains("重复")

func test_accept_same_template_blocked() -> void:
	## G-2 源头防并存：同模板已在挂单时接取板上同模板委托被拦截
	_core.board.board.clear()
	var first_inst: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", 1)
	assert_bool(_core.accept_quest(first_inst.serial, _RosterIds(2))).is_true()
	var second_inst: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", 1)
	assert_bool(_core.accept_quest(second_inst.serial, _RosterIds2From(2))).is_false()
	assert_str(_core.last_error).contains("同模板委托已在挂单")

func test_abort_expedition_restores_state() -> void:
	## M4 回退口：abort_expedition——IN_PROGRESS 回 ACCEPTED + 出征日标记按快照
	## 恢复（缺键保持现值——部分快照不误伤未记录成员）；全量快照（生产形态=
	## 协会屏 go 失败回退）恢复后可重出征
	_core.board.board.clear()
	var inst: QuestInstance = _core.board.spawn_on_board(&"q_lair_purge", 1)
	assert_bool(_core.accept_quest(inst.serial, _RosterIds(3))).is_true()
	assert_bool(_core.start_expedition(inst.serial)).is_true()
	assert_int(_core.roster[0].last_expedition_day).is_equal(1)
	# 全量快照：全员恢复 0 → 回 ACCEPTED 后当日可重出征（生产路径形态）
	var full_snapshot: Dictionary = {}
	for member_id: StringName in inst.party_ids:
		full_snapshot[String(member_id)] = 0
	assert_bool(_core.abort_expedition(inst.serial, full_snapshot)).is_true()
	assert_int(inst.state).is_equal(QuestInstance.State.ACCEPTED)
	assert_int(_core.roster[0].last_expedition_day).is_equal(0)
	assert_bool(_core.start_expedition(inst.serial)).is_true()
	# 部分快照：仅 roster[0] 恢复 0；未记录的 roster[1] 保持当日标记 1——
	# 当日重出征被「每日一次」拦截（缺键不清 0 的可观察后果）
	assert_bool(_core.abort_expedition(inst.serial,
			{String(_core.roster[0].unit_id): 0})).is_true()
	assert_int(inst.state).is_equal(QuestInstance.State.ACCEPTED)
	assert_int(_core.roster[0].last_expedition_day).is_equal(0)
	assert_int(_core.roster[1].last_expedition_day).is_equal(1)
	assert_bool(_core.start_expedition(inst.serial)).is_false()
	assert_str(_core.last_error).contains("每日一次")

func test_setup_resets_accepted_and_badge() -> void:
	## G-1 回归：同 core 连续两次 setup——挂单清空/占用释放/角标复位
	_core.board.board.clear()
	var inst: QuestInstance = _core.board.spawn_on_board(&"q_lair_purge", 1)
	assert_bool(_core.accept_quest(inst.serial, _RosterIds(3))).is_true()
	assert_bool(_core.start_expedition(inst.serial)).is_true()
	_core.has_unseen_grants = true
	assert_int(_core.board.accepted.size()).is_equal(1)
	_core.setup(_Cfg(), _game_data, _MakeRng(999))
	assert_int(_core.board.accepted.size()).is_equal(0)
	assert_int(_core.board.occupied_member_ids().size()).is_equal(0)
	assert_int(_core.board.in_progress_count()).is_equal(0)
	assert_bool(_core.has_unseen_grants).is_false()
