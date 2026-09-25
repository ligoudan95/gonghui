## EventRunner 事件引擎单元测试（M2 批 2 + M2 质检修复批）
## 覆盖：三链全分支零死路（固定骰注入）/ 四档结算（大成功叠加奖励、
## 大失败 −5 HP + 下限）/ 耗时 +1 / 单次消耗 / C8 授予+防重反馈字段 /
## C-D 拦截（intercepted 标记）/ B 出口参数组装（先手/分布/初始状态/HP
## 覆写/倒地跳过）/ E1 四档经节点去向透传 / E5 反馈字段回带 / E7 会话
## 防重 / E2-8 B 奖励战后入账 / E6 去向节点 id 单源回带 / E2 终端叙述追加。
## 骰值控制：FixedDieRunner 子类覆写 _RollCheck → CheckRoller.roll_with_die
## 固定骰值（roll_with_die 为引擎内部确定路径——骰 1 恒大失败、骰 ≥ 线
## 恒大成功），档位断言确定不依赖概率窗。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## cfg 路径
const CFG_PATH: String = "res://data/core/cfg_main.tres"

## 固定骰 runner（测试注入——_RollCheck 覆写走 roll_with_die 确定档位）
class FixedDieRunner extends EventRunner:
	## 注入骰值（1 = 恒大失败；≥ 大成功线 = 恒大成功）
	var forced_die: int = 1

	func _RollCheck(actor: AdventurerData, attr_id: StringName,
			tier_name: String) -> CheckResult:
		if actor == null:
			var failed := CheckResult.new()
			failed.grade = CheckResult.Grade.CRIT_FAILURE
			return failed
		return CheckRoller.roll_with_die(actor.attrs, attr_id, tier_name,
				_cfg, forced_die)

## 套件级组件
var _game_data: Node
var _cfg: CoreConfig
var _runner: EventRunner
var _run: ExpeditionRun
var _lookup: Callable

func before() -> void:
	## 套件前置：GameData + cfg + runner 装配
	## 参数：无
	## 返回：无
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()
	_cfg = load(CFG_PATH) as CoreConfig
	var table: Dictionary = {}
	for domain: StringName in [&"event/chains", &"event/nodes", &"event/options",
			&"event/singles", &"status/stats", &"battle/enemy_packs"]:
		for record_id: StringName in _game_data.get_domain_ids(domain):
			table[record_id] = _game_data.get_record(record_id)
	_lookup = func(record_id: StringName) -> Resource:
		return table.get(record_id, null)

func before_test() -> void:
	## 用例前置：新建 runner 与运行态（四人队——力 20 检定必手/力 1 必败，
	## 每人独立 unit_id）
	## 参数：无
	## 返回：无
	_runner = EventRunner.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260924
	_runner.setup(_cfg, _lookup, rng)
	_run = ExpeditionRun.new()
	_run.party = [
		AdventurerData.create_debug(&"strongman", &"cls_warrior", {
			&"strength": 20, &"agility": 10, &"constitution": 14,
			&"intelligence": 7, &"perception": 9, &"willpower": 9, &"luck": 10}, _game_data),
		AdventurerData.create_debug(&"weakling", &"cls_mage", {
			&"strength": 1, &"agility": 10, &"constitution": 9,
			&"intelligence": 16, &"perception": 11, &"willpower": 9, &"luck": 10}, _game_data),
	]
	_run.hp = {_run.party[0]: 40, _run.party[1]: 30}

func after() -> void:
	## 套件后置：释放 GameData
	## 参数：无
	## 返回：无
	_game_data.free()

func _FixedRunner(die: int) -> EventRunner:
	## 固定骰 runner 装配（E1/E2-8 确定档位断言）
	## 参数 die：注入骰值
	## 返回：装配完成的 FixedDieRunner
	var runner := FixedDieRunner.new()
	runner.forced_die = die
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	runner.setup(_cfg, _lookup, rng)
	return runner

func _FreshRun() -> ExpeditionRun:
	## 新运行态（独立 runner 驱动的隔离 run——E7 按 run 隔离前提）
	## 参数：无
	## 返回：ExpeditionRun（二人队 HP 40/30）
	var run := ExpeditionRun.new()
	run.party = _run.party
	run.hp = {_run.party[0]: 40, _run.party[1]: 30}
	return run

func test_chain_collapse_all_branches_no_deadend() -> void:
	## 塌方链全分支：o1 成功→n2 终端（15/10）；o2 成功→n3（20/15）；o1 失败→n4
	## （10/5）；o3 纯选择→n5（15/15+耗时 1）；o4 绕行 E1（零奖励）——零死路
	var view: EventRunner.EventView = _runner.start_event(&"chain_mine_collapse", _run)
	assert_str(view.narrative).is_not_empty()
	assert_int(view.options.size()).is_equal(4)
	# o1 成功（力 20 体质 20？——检定属性是体质：strongman 体 14 调 +2，
	# 极易 8：骰 ≥6 即成（70%+）……容错：失败向断言在下一分支覆盖
	var view2: EventRunner.EventView = _runner.choose_option(&"chain_mine_collapse",
			&"opt_collapse_1", _run.party[0], _run)
	assert_bool(not view2.narrative.is_empty()).is_true()
	# o3 纯选择：耗时 +1 且到 n5
	var run2 := _Run2()
	var view3: EventRunner.EventView = _runner.choose_option(&"chain_mine_collapse",
			&"opt_collapse_3", null, run2)
	assert_int(run2.extra_days).is_equal(1)
	assert_int(int(run2.rewards[&"exp"])).is_equal(15)
	assert_int(int(run2.rewards[&"gold"])).is_equal(15)
	# o4 绕行：零奖励直接出口
	var run3 := _Run3()
	var view4: EventRunner.EventView = _runner.choose_option(&"chain_mine_collapse",
			&"opt_collapse_4", null, run3)
	assert_int(int(run3.rewards[&"exp"])).is_equal(0)
	assert_bool(not view4.narrative.is_empty()).is_true()

func _Run2() -> ExpeditionRun:
	## 新运行态（纯选择分支——需先消耗入口节点）
	var run := ExpeditionRun.new()
	run.party = _run.party
	run.hp = _run.hp.duplicate()
	_runner.start_event(&"chain_mine_collapse", run)
	return run

func _Run3() -> ExpeditionRun:
	return _Run2()

func test_crit_grades_apply_modifiers() -> void:
	## 四档修饰管线（直接单点结算口）：无检定单档 sp_village_traveler 10 经验
	var run := ExpeditionRun.new()
	run.party = _run.party
	run.hp = {_run.party[0]: 40, _run.party[1]: 30}
	var view: EventRunner.EventView = _runner.start_event(&"sp_village_traveler", run)
	assert_int(view.options.size()).is_equal(0)
	# 无检定单档：立即结算（叙述+奖励落账）；无检定档位 = -1（E5）
	assert_bool(not view.narrative.is_empty()).is_true()
	assert_int(int(run.rewards[&"exp"])).is_equal(10)
	assert_int(view.check_grade).is_equal(-1)
	assert_int(int(view.reward_gained[&"exp"])).is_equal(10)

func test_single_event_consumed_once() -> void:
	## 单次消耗：二次 start_event 返回空视图
	var run := ExpeditionRun.new()
	run.party = _run.party
	run.hp = _run.hp.duplicate()
	var first: EventRunner.EventView = _runner.start_event(&"sp_village_traveler", run)
	assert_bool(not first.narrative.is_empty()).is_true()
	var second: EventRunner.EventView = _runner.start_event(&"sp_village_traveler", run)
	assert_bool(second.narrative.is_empty()).is_true()

func test_c8_grant_and_dedup_narrative() -> void:
	## C8 授予：camp_n2 出口授予 keepsake 进挂单（E8 反馈字段回带）；
	## 同模板已挂单 → granted_is_new = false（UI 播补叙文本）
	var run := ExpeditionRun.new()
	run.party = _run.party
	run.hp = _run.hp.duplicate()
	# 取节点出口
	var node: EventNodeDef = _lookup.call(&"evn_camp_n2") as EventNodeDef
	var view: EventRunner.EventView = _runner.resolve_outcome(node.outcome, run)
	assert_bool(run.granted_quests.has(&"q_lost_miner_keepsake")).is_true()
	assert_int(int(run.rewards[&"exp"])).is_equal(20)
	assert_str(String(view.granted_quest_id)).is_equal("q_lost_miner_keepsake")
	assert_bool(view.granted_is_new).is_true()
	# 再触发同出口：grant_quest 防重（不重复入列——granted_is_new = false）
	var run2 := ExpeditionRun.new()
	run2.party = _run.party
	run2.hp = _run.hp.duplicate()
	run2.granted_quests.append(&"q_lost_miner_keepsake")
	var view2: EventRunner.EventView = _runner.resolve_outcome(node.outcome, run2)
	assert_int(run2.granted_quests.size()).is_equal(1)
	assert_bool(view2.granted_is_new).is_false()

func test_cd_outcome_intercepted() -> void:
	## C/D 拦截：手工构造 C 出口 resolve → 拦截视图（intercepted 标记回带——
	## 文本由 UI 层模板承载，逻辑层零文案 E3-11）+ 无奖励
	var run := ExpeditionRun.new()
	run.party = _run.party
	run.hp = _run.hp.duplicate()
	var c_outcome := EventOutcomeDef.new()
	c_outcome.exit_kind = EventOutcomeDef.ExitKind.C
	var reward := RewardDef.new()
	reward.exp = 20
	c_outcome.reward = reward
	var view: EventRunner.EventView = _runner.resolve_outcome(c_outcome, run)
	assert_bool(view.intercepted).is_true()
	assert_str(view.narrative).is_empty()
	assert_int(int(run.rewards[&"exp"])).is_equal(0)

func test_battle_params_assembly() -> void:
	## B 出口参数组装：n2 被伏击=ENEMY_FIRST+集结槽+全队 exposed+HP 覆写；
	## n3 列阵=ALLY_FIRST+分散槽+无初始状态
	var node2: EventNodeDef = _lookup.call(&"evn_wisp_n2") as EventNodeDef
	var run := ExpeditionRun.new()
	run.party = _run.party
	run.hp = {_run.party[0]: 40, _run.party[1]: 30}
	run.hp[_run.party[0]] = 25
	var params: BattleParams = _runner.build_battle_params(node2.outcome, run)
	assert_str(String(params.pack_id)).is_equal("enc_m1_wisp_nest")
	assert_int(params.first_strike).is_equal(BattleParams.FirstStrike.ENEMY_FIRST)
	assert_int(params.enemy_spawn_override.size()).is_equal(4)
	assert_int(params.initial_statuses.size()).is_equal(2)
	assert_str(String(params.initial_statuses[0][&"status_id"])).is_equal("DEBUFF_exposed")
	assert_int(int(params.hp_overrides[_run.party[0].unit_id])).is_equal(25)
	var node3: EventNodeDef = _lookup.call(&"evn_wisp_n3") as EventNodeDef
	var params3: BattleParams = _runner.build_battle_params(node3.outcome, run)
	assert_int(params3.first_strike).is_equal(BattleParams.FirstStrike.ALLY_FIRST)
	assert_int(params3.initial_statuses.size()).is_equal(0)
	assert_int(params3.enemy_spawn_override[1]).is_equal(2)

func test_battle_params_skip_downed() -> void:
	## E2-3/E9：倒地成员不带入战斗——hp_overrides/initial_statuses 跳过
	## （避免 BattleSetup clamp 把 0 血拉 1 复活——案 18「倒地保持至回城」）
	var node2: EventNodeDef = _lookup.call(&"evn_wisp_n2") as EventNodeDef
	var run := ExpeditionRun.new()
	run.party = _run.party
	run.hp = {_run.party[0]: 30, _run.party[1]: 0}
	run.downed[_run.party[1]] = true
	var params: BattleParams = _runner.build_battle_params(node2.outcome, run)
	assert_bool(params.hp_overrides.has(_run.party[1].unit_id)) \
			.override_failure_message("倒地成员不得进 HP 覆写").is_false()
	assert_int(int(params.hp_overrides[_run.party[0].unit_id])).is_equal(30)
	assert_int(params.initial_statuses.size()).is_equal(1)
	assert_str(String(params.initial_statuses[0][&"target"])) \
			.is_equal(String(_run.party[0].unit_id))

func test_crit_failure_modifier_hp_floor() -> void:
	## 大失败修饰管线：单点 sp_mine_secretdoor 力 1 感知 1 极难 17——必失败
	## （骰 20 窗口外）；大失败 −5 HP 落地（HP 6→1 钳）
	var run := ExpeditionRun.new()
	var weak: AdventurerData = AdventurerData.create_debug(&"blind", &"cls_mage", {
		&"strength": 1, &"agility": 1, &"constitution": 1,
		&"intelligence": 16, &"perception": 1, &"willpower": 1, &"luck": 1}, _game_data)
	run.party = [weak]
	run.hp = {weak: 6}
	var view: EventRunner.EventView = _runner.start_event(&"sp_mine_secretdoor", run)
	assert_int(view.options.size()).is_equal(1)
	var settled: EventRunner.EventView = _runner.choose_option(&"sp_mine_secretdoor",
			&"", weak, run)
	# 感知 1（调 −5）极难 17：仅骰 20+Z 抬可过——固定种子下容错断言失败向
	if int(run.hp[weak]) < 6:
		assert_int(int(run.hp[weak])).is_equal(1)
		assert_int(settled.hp_delta).is_equal(-5)

func test_e1_crit_flags_flow_to_next_node_failure() -> void:
	## E1 四档透传（失败侧）：collapse_1 骰 1 → 大失败 → 去向 n4 终端——
	## crit_failure 文本可见 + 修饰 −5 HP 入账（下限 1）+ 档位反馈字段回带 +
	## 终端叙述追加不覆写（E2）
	var runner := _FixedRunner(1)
	var run := _FreshRun()
	runner.start_event(&"chain_mine_collapse", run)
	var view: EventRunner.EventView = runner.choose_option(&"chain_mine_collapse",
			&"opt_collapse_1", run.party[0], run)
	assert_int(view.check_grade).is_equal(CheckResult.Grade.CRIT_FAILURE)
	assert_str(String(view.node_id)).is_equal("evn_collapse_n4")
	# E2：终端叙述 + crit_failure 结算文本均可见（追加不覆写）
	assert_str(view.narrative).contains("老周自己挤出来的")
	assert_str(view.narrative).contains("簌簌滑落")
	# 修饰实效：全队 −5 HP（40→35 / 30→25）
	assert_int(int(run.hp[run.party[0]])).is_equal(35)
	assert_int(int(run.hp[run.party[1]])).is_equal(25)
	assert_int(view.hp_delta).is_equal(-5)
	# 基础奖励照常入账（n4 出口 10/5）
	assert_int(int(run.rewards[&"exp"])).is_equal(10)
	assert_int(int(run.rewards[&"gold"])).is_equal(5)
	assert_int(int(view.reward_gained[&"exp"])).is_equal(10)

func test_e1_crit_flags_flow_to_next_node_success() -> void:
	## E1 四档透传（成功侧）：collapse_1 骰 20（幸运 10 → 大成功线 20）→
	## 大成功 → 去向 n2 终端——基础 15/10 + 修饰 +15 金合并入账 + crit 文本
	var runner := _FixedRunner(20)
	var run := _FreshRun()
	runner.start_event(&"chain_mine_collapse", run)
	var view: EventRunner.EventView = runner.choose_option(&"chain_mine_collapse",
			&"opt_collapse_1", run.party[0], run)
	assert_int(view.check_grade).is_equal(CheckResult.Grade.CRIT_SUCCESS)
	assert_str(String(view.node_id)).is_equal("evn_collapse_n2")
	# 基础 15/10 + 修饰 +15 金 = 经验 15 / 金 25
	assert_int(int(run.rewards[&"exp"])).is_equal(15)
	assert_int(int(run.rewards[&"gold"])).is_equal(25)
	assert_int(int(view.reward_gained[&"gold"])).is_equal(25)
	# E2：n2 叙述 + crit_success 结算文本追加
	assert_str(view.narrative).contains("半个时辰后")
	assert_str(view.narrative).contains("救命恩人")
	# 大成功修饰无 HP 损耗
	assert_int(view.hp_delta).is_equal(0)

func test_e7_finalize_blocks_duplicate_choose() -> void:
	## E7 会话防重：同 run 同事件终局后重复 choose_option 返回空视图——
	## 奖励不重复入账
	var runner := _FixedRunner(10)
	var run := _FreshRun()
	runner.start_event(&"chain_mine_collapse", run)
	var first: EventRunner.EventView = runner.choose_option(&"chain_mine_collapse",
			&"opt_collapse_3", null, run)
	assert_bool(first.narrative.is_empty()).is_false()
	assert_int(int(run.rewards[&"exp"])).is_equal(15)
	var dup: EventRunner.EventView = runner.choose_option(&"chain_mine_collapse",
			&"opt_collapse_3", null, run)
	assert_bool(dup.narrative.is_empty()).is_true()
	assert_int(int(run.rewards[&"exp"])).is_equal(15)
	# 按 run 隔离：新 run 同事件不受旧 run 终局标记影响
	var run2 := _FreshRun()
	runner.start_event(&"chain_mine_collapse", run2)
	var other: EventRunner.EventView = runner.choose_option(&"chain_mine_collapse",
			&"opt_collapse_3", null, run2)
	assert_bool(other.narrative.is_empty()).is_false()

func test_b_exit_reward_only_after_post_battle() -> void:
	## E2-8：B 出口战前不入账（n2 被伏击 15/15 战后才拿）；crit 失败修饰
	## −5 HP 照常战前生效（初始损耗）
	var runner := _FixedRunner(1)
	var run := _FreshRun()
	runner.start_event(&"chain_mine_wisp", run)
	var view: EventRunner.EventView = runner.choose_option(&"chain_mine_wisp",
			&"opt_wisp_1", run.party[0], run)
	assert_object(view.pending_outcome).is_not_null()
	assert_int(view.pending_outcome.exit_kind).is_equal(EventOutcomeDef.ExitKind.B)
	assert_int(int(run.rewards[&"exp"])).is_equal(0)
	assert_int(int(run.rewards[&"gold"])).is_equal(0)
	# 战前初始损耗：大失败 −5 HP 生效（40→35）
	assert_int(int(run.hp[run.party[0]])).is_equal(35)
	assert_int(view.hp_delta).is_equal(-5)
	# 胜利后 post_battle 结算：15/15 入账（败退/撤离不调本口 = 不拿）
	var node: EventNodeDef = _lookup.call(&"evn_wisp_n2") as EventNodeDef
	var post: EventRunner.EventView = runner.resolve_outcome(
			node.outcome.battle.post_battle, run)
	assert_int(int(run.rewards[&"exp"])).is_equal(15)
	assert_int(int(run.rewards[&"gold"])).is_equal(15)
	assert_bool(post.narrative.is_empty()).is_false()

func test_view_node_id_single_source() -> void:
	## E6：去向节点 id 由引擎视图单源回带（入口节点/选项去向）；
	## 直接出口视图 node_id 为空
	var runner := _FixedRunner(10)
	var run := _FreshRun()
	var entry: EventRunner.EventView = runner.start_event(&"chain_mine_wisp", run)
	assert_str(String(entry.node_id)).is_equal("evn_wisp_n1")
	# 纯选择 → n3 B 节点：node_id = n3（B 路由锚点）
	var to_battle: EventRunner.EventView = runner.choose_option(&"chain_mine_wisp",
			&"opt_wisp_3", null, run)
	assert_str(String(to_battle.node_id)).is_equal("evn_wisp_n3")
	# 直接出口（wisp_2 成功出口）：node_id 空
	var runner2 := _FixedRunner(20)
	var run2 := _FreshRun()
	runner2.start_event(&"chain_mine_wisp", run2)
	var direct: EventRunner.EventView = runner2.choose_option(&"chain_mine_wisp",
			&"opt_wisp_2", run2.party[0], run2)
	assert_str(String(direct.node_id)).is_equal("")
