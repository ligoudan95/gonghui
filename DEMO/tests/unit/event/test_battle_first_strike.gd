## first_strike 战斗先手消费单元测试（M2 批 2）
## 覆盖：ENEMY_FIRST 回合 1 敌方全前；ALLY_FIRST 我方全前（镜像）；
## 回合 2 起维持全量重排（速度序回归）；同速我方优先规则不破。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 用例级 GameData
var _game_data: Node

func before_test() -> void:
	## 用例前置：取 root 下真 GameData autoload 本体
	## 参数：无
	## 返回：无
	_game_data = get_tree().root.get_node_or_null("GameData")
	assert_object(_game_data).is_not_null()

func _MakeContext(first_strike: int, seed_value: int) -> BattleSetup.BattleContext:
	## 装配战斗上下文（四人队 vs 巢穴包——敌方含精英高速度，天然混合序）
	## 参数 first_strike：先手口径；seed_value：随机种子
	## 返回：BattleContext
	var params := BattleParams.new()
	params.pack_id = &"enc_m1_wisp_nest"
	params.first_strike = first_strike
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	params.rng = rng
	var party: Array[AdventurerData] = []
	for entry: Array in [
		[&"warrior", &"cls_warrior"], [&"rogue", &"cls_rogue"],
		[&"mage", &"cls_mage"], [&"priest", &"cls_priest"],
	]:
		party.append(AdventurerData.create_debug(entry[0], entry[1], {
			&"strength": 10, &"agility": 10, &"constitution": 10,
			&"intelligence": 10, &"perception": 10, &"willpower": 10, &"luck": 10,
		}, _game_data))
	params.party = party
	return BattleSetup.build(params, _game_data)

func test_enemy_first_round_one_orders_enemies_first() -> void:
	## 敌先手：回合 1 行动序列敌方全前（我方全后）
	var context := _MakeContext(BattleParams.FirstStrike.ENEMY_FIRST, 11)
	var controller := BattleController.new()
	controller.delay_seconds = 0.0
	controller.prepare(context)
	add_child(controller)
	auto_free(controller)
	controller._do_round_start()
	var seen_ally: bool = false
	for unit: BattleUnit in context.turn_order:
		if unit.side == SkillDef.SkillSide.ALLY:
			seen_ally = true
		elif seen_ally:
			assert_bool(false).override_failure_message("敌先手回合 1 敌方应全前").is_true()
	assert_bool(seen_ally).is_true()
	controller.abort_battle()

func test_ally_first_round_one_orders_allies_first() -> void:
	## 我先手（镜像）：回合 1 我方全前
	var context := _MakeContext(BattleParams.FirstStrike.ALLY_FIRST, 12)
	var controller := BattleController.new()
	controller.delay_seconds = 0.0
	controller.prepare(context)
	add_child(controller)
	auto_free(controller)
	controller._do_round_start()
	var seen_enemy: bool = false
	for unit: BattleUnit in context.turn_order:
		if unit.side != SkillDef.SkillSide.ALLY:
			seen_enemy = true
		elif seen_enemy:
			assert_bool(false).override_failure_message("我先手回合 1 我方应全前").is_true()
	controller.abort_battle()

func test_round_two_restores_speed_order() -> void:
	## 次回合重排：回合 2 恢复全量速度序（无阵营分组残留）
	var context := _MakeContext(BattleParams.FirstStrike.ENEMY_FIRST, 13)
	var controller := BattleController.new()
	controller.delay_seconds = 0.0
	controller.prepare(context)
	add_child(controller)
	auto_free(controller)
	controller._do_round_start()
	controller._do_round_end()
	controller._do_round_start()
	# 回合 2 序列须与「纯速度排序」一致（同速我方优先→槽位序）
	var expected: Array = context.units.filter(func(unit): return unit.alive)
	expected.sort_custom(func(a, b):
		if a.speed_for_order() != b.speed_for_order():
			return a.speed_for_order() > b.speed_for_order()
		if a.side != b.side:
			return a.side < b.side
		return a.slot_index < b.slot_index)
	for index: int in expected.size():
		assert_str(String(context.turn_order[index].unit_id)) \
				.is_equal(String(expected[index].unit_id)) \
				.override_failure_message("回合 %d 序位 %d 应恢复速度序" % [2, index])
	controller.abort_battle()

func test_normal_first_strike_unchanged() -> void:
	## NORMAL 口径：回合 1 即全量速度序（不分组）
	var context := _MakeContext(BattleParams.FirstStrike.NORMAL, 14)
	var controller := BattleController.new()
	controller.delay_seconds = 0.0
	controller.prepare(context)
	add_child(controller)
	auto_free(controller)
	controller._do_round_start()
	var expected: Array = context.units.filter(func(unit): return unit.alive)
	expected.sort_custom(func(a, b):
		if a.speed_for_order() != b.speed_for_order():
			return a.speed_for_order() > b.speed_for_order()
		if a.side != b.side:
			return a.side < b.side
		return a.slot_index < b.slot_index)
	for index: int in expected.size():
		assert_str(String(context.turn_order[index].unit_id)) \
				.is_equal(String(expected[index].unit_id))
	controller.abort_battle()
