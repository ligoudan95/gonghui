## 事件→战斗→续跑集成测试（M2 批 2 + M2 质检 E2-6 修复）
## 覆盖：被伏击 = ENEMY_FIRST + 集结槽 + 全队 DEBUFF_exposed + HP−5 带入
## （固定骰 1 注入——大失败确定断言，无概率窗）；战前不入账（E2-8）；
## 强制胜利（敌方预置全灭）→ post_battle 奖励 15/15 入 run、HP 带入下探到
## 装配后 current_hp；列阵 = ALLY_FIRST + 分散槽。
## 环境：gdUnit 帧内真 autoload（GameData）+ delay 0。
extends GdUnitTestSuite

## GameData 脚本路径（取真 autoload）
const CFG_PATH: String = "res://data/core/cfg_main.tres"

## 固定骰 runner（测试注入——骰 1 恒大失败，档位确定）
class FixedDieRunner extends EventRunner:
	## 注入骰值
	var forced_die: int = 1

	func _RollCheck(actor: AdventurerData, attr_id: StringName,
			tier_name: String) -> CheckResult:
		if actor == null:
			var failed := CheckResult.new()
			failed.grade = CheckResult.Grade.CRIT_FAILURE
			return failed
		return CheckRoller.roll_with_die(actor.attrs, attr_id, tier_name,
				_cfg, forced_die)

func before_test() -> void:
	## 用例前置：取真 GameData
	## 参数：无
	## 返回：无
	var game_data: Node = get_tree().root.get_node_or_null("GameData")
	assert_object(game_data).is_not_null()

func _MakeRunner(game_data: Node, die: int = 1) -> EventRunner:
	## 装配固定骰 runner（四域合一 lookup）
	## 参数 game_data：GameData；die：注入骰值
	## 返回：FixedDieRunner
	var runner := FixedDieRunner.new()
	runner.forced_die = die
	var table: Dictionary = {}
	for domain: StringName in [&"event/chains", &"event/nodes", &"event/options",
			&"event/singles", &"status/stats"]:
		for record_id: StringName in game_data.get_domain_ids(domain):
			table[record_id] = game_data.get_record(record_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	runner.setup(load(CFG_PATH) as CoreConfig,
			func(record_id: StringName) -> Resource: return table.get(record_id, null), rng)
	return runner

func test_ambush_route_full_chain() -> void:
	## 被伏击全链：opt_wisp_1 骰 1（大失败）→ n2 B 出口 → ENEMY_FIRST + 集结 +
	## 全队 exposed + HP 带入（初始 45 − 修饰 5 = 40）；战前奖励不入账（E2-8）；
	## 强制胜利 → post_battle 15/15 入 run（断言不再包在概率 if 内——E2-6）
	var game_data: Node = get_tree().root.get_node_or_null("GameData")
	var runner := _MakeRunner(game_data, 1)
	var run := ExpeditionRun.new()
	var weak_eye: AdventurerData = AdventurerData.create_debug(&"blindman", &"cls_warrior", {
		&"strength": 16, &"agility": 10, &"constitution": 14,
		&"intelligence": 7, &"perception": 1, &"willpower": 9, &"luck": 9}, game_data)
	run.party = [weak_eye]
	run.hp = {weak_eye: 45}
	# 进入链 → 选 o1（感知检定·骰 1 注入 = 恒大失败）→ n2 B 出口
	runner.start_event(&"chain_mine_wisp", run)
	var view: EventRunner.EventView = runner.choose_option(&"chain_mine_wisp",
			&"opt_wisp_1", weak_eye, run)
	assert_object(view.pending_outcome).is_not_null()
	var outcome: EventOutcomeDef = view.pending_outcome
	assert_int(outcome.exit_kind).is_equal(EventOutcomeDef.ExitKind.B)
	# 战前不入账（E2-8）：B 出口奖励 15/15 战后才拿；大失败修饰 −5 HP 已生效
	assert_int(int(run.rewards[&"exp"])).is_equal(0)
	assert_int(int(run.rewards[&"gold"])).is_equal(0)
	assert_int(int(run.hp[weak_eye])).is_equal(40)
	# B 出口参数：敌先手+集结+全员 exposed（CHECKIN 载入链）+ HP 覆写 40
	var params: BattleParams = runner.build_battle_params(outcome, run)
	assert_int(params.first_strike).is_equal(BattleParams.FirstStrike.ENEMY_FIRST)
	assert_int(params.enemy_spawn_override.size()).is_equal(4)
	assert_int(params.initial_statuses.size()).is_equal(1)
	assert_str(String(params.initial_statuses[0][&"status_id"])).is_equal("DEBUFF_exposed")
	assert_int(int(params.hp_overrides[weak_eye.unit_id])).is_equal(40)
	# 组装完整战斗（补 party——typed assign）→ 装配校验：全员 exposed 在身 +
	# HP 带入下探到装配后 current_hp（E2-6：参数层断言不够——clamp/装配链路
	# 一并覆盖）
	params.party.assign(run.party)
	var context: BattleSetup.BattleContext = BattleSetup.build(params, game_data)
	assert_object(context).is_not_null()
	var warrior: BattleUnit = context.find_unit(&"blindman")
	assert_int(warrior.current_hp).is_equal(40)
	var has_exposed: bool = false
	for instance: StatusInstance in context.status_manager.get_statuses(warrior):
		if instance.status_id == &"DEBUFF_exposed":
			has_exposed = true
	assert_bool(has_exposed).override_failure_message("被伏击全员应带暴露减益").is_true()
	# 强制胜利（E2-6：断言时点确定——敌方预置全灭，我方被动结束行动轮，
	# 回合末 _check_battle_end 即 VICTORY，不再依赖被动战局胜败概率）
	var controller := BattleController.new()
	controller.delay_seconds = 0.0
	for enemy: BattleUnit in context.enemies:
		enemy.current_hp = 0
		enemy.alive = false
	controller.prepare(context)
	add_child(controller)
	auto_free(controller)
	controller.turn_started.connect(func(unit: BattleUnit) -> void:
		if unit.is_controllable() and controller.current_unit == unit:
			controller.request_end_unit_turn()
	)
	controller.start_battle(context)
	var result: BattleResult = await controller.battle_ended
	assert_int(result.kind).is_equal(BattleResult.ResultKind.VICTORY)
	# 战后回写链路：end_stats 回写 + post_battle 结算 15/15 入 run（无前置叠加）
	run.apply_battle_result(result.end_stats)
	var post: EventRunner.EventView = runner.resolve_outcome(outcome.battle.post_battle, run)
	assert_int(int(run.rewards[&"exp"])).is_equal(15)
	assert_int(int(run.rewards[&"gold"])).is_equal(15)
	assert_bool(not post.narrative.is_empty()).is_true()

func test_formation_route_params() -> void:
	## 列阵线：opt_wisp_3 纯选择 → n3 B 出口 = ALLY_FIRST + 分散槽 + 无初始状态
	var game_data: Node = get_tree().root.get_node_or_null("GameData")
	var runner := _MakeRunner(game_data, 10)
	var run := ExpeditionRun.new()
	var any: AdventurerData = AdventurerData.create_debug(&"anyone", &"cls_warrior", {
		&"strength": 16, &"agility": 10, &"constitution": 14,
		&"intelligence": 7, &"perception": 9, &"willpower": 9, &"luck": 9}, game_data)
	run.party = [any]
	run.hp = {any: 40}
	runner.start_event(&"chain_mine_wisp", run)
	var view: EventRunner.EventView = runner.choose_option(&"chain_mine_wisp",
			&"opt_wisp_3", null, run)
	assert_object(view.pending_outcome).is_not_null()
	var params: BattleParams = runner.build_battle_params(view.pending_outcome, run)
	assert_int(params.first_strike).is_equal(BattleParams.FirstStrike.ALLY_FIRST)
	assert_int(params.enemy_spawn_override[0]).is_equal(0)
	assert_int(params.enemy_spawn_override[1]).is_equal(2)
	assert_int(params.initial_statuses.size()).is_equal(0)
