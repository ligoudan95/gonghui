## 战斗演出防护护栏单元测试（拍板 B 2026-10-01：演出墙钟护栏 + 敌方轮看门狗）
## 覆盖：①_wait_delay 墙钟超限 push_warning（含耗时/上限）并强制返回——注入
## 假钟模拟环境性 delta 停更 ②常规小延时路径零 warning（护栏不误伤）③敌方轮
## 看门狗超时 push_warning 留痕且行动正常完成（不中断不改动行为）④常规敌方轮
## 零 warning。headless delay=0 常规路径零影响由既有全量用例回归覆盖。
## 环境口径：gdUnit -s 运行器帧内挂真实 autoload——GameData 经 root 取本体
##（test_battle_first_strike 同式）。
extends GdUnitTestSuite

## 护栏用例演出延时（秒——1.0 → 墙钟上限 10 s，headless 单帧 delta 不可达，
## 保证先触发墙钟检查而非 delta 累计达标）
const TEST_DELAY_SECONDS: float = 1.0
## 常规路径演出延时（秒）
const NORMAL_DELAY_SECONDS: float = 0.05
## 假钟步进（毫秒/次——一次读钟跳 60 s，远超护栏/看门狗上限）
const FAKE_CLOCK_STEP_MSEC: int = 60000
## 敌方轮看门狗上限断言锚点（与实现常量同步——改实现须同步此处）
const WATCHDOG_MSEC: int = 15000
## 墙钟护栏倍率断言锚点（同上）
const WALL_CLOCK_RATIO: int = 10

func before_test() -> void:
	## 用例前置：取 root 下真 GameData autoload 本体（敌方轮用例装配消费）
	## 参数：无
	## 返回：无
	assert_object(get_tree().root.get_node_or_null("GameData")).is_not_null()

func _MakeContext() -> BattleSetup.BattleContext:
	## 装配四人队 vs 随机包上下文（固定种子——敌方轮用例消费）
	## 参数：无
	## 返回：BattleContext
	var game_data: Node = get_tree().root.get_node("GameData")
	var params := BattleParams.new()
	params.pack_id = &"enc_m1_random_pack"
	params.first_strike = BattleParams.FirstStrike.NORMAL
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261001
	params.rng = rng
	var party: Array[AdventurerData] = []
	for entry: Array in [
		[&"warrior", &"cls_warrior"], [&"rogue", &"cls_rogue"],
		[&"mage", &"cls_mage"], [&"priest", &"cls_priest"],
	]:
		party.append(AdventurerData.create_debug(entry[0], entry[1], {
			&"strength": 10, &"agility": 10, &"constitution": 10,
			&"intelligence": 10, &"perception": 10, &"willpower": 10,
			&"luck": 10,
		}, game_data))
	params.party = party
	return BattleSetup.build(params, game_data)

func _MakeBareController(delay_value: float) -> BattleController:
	## 构建挂树裸控制器（不装配上下文——_wait_delay 不依赖 context；
	## auto_free 释放）
	## 参数 delay_value：演出延时秒数
	## 返回：已挂树控制器
	var controller := BattleController.new()
	controller.delay_seconds = delay_value
	add_child(controller)
	auto_free(controller)
	return controller

func _MakeEnemyTurnController() -> BattleController:
	## 构建敌方轮驱动控制器（delay 0 + 装配上下文 + 回合 1 就绪——直调
	## _run_enemy_turn 消费）
	## 参数：无
	## 返回：已挂树控制器
	var controller := BattleController.new()
	controller.delay_seconds = 0.0
	controller.prepare(_MakeContext())
	add_child(controller)
	auto_free(controller)
	controller._do_round_start()
	return controller

func _InjectFakeClock(controller: BattleController) -> void:
	## 注入跳步假钟（每次读钟 +60000 ms——模拟环境性墙钟流逝/帧 delta 停更；
	## Dictionary 闭包按引用捕获可变）
	## 参数 controller：目标控制器
	## 返回：无
	var state: Dictionary = {&"reads": 0}
	controller._wall_clock = func() -> int:
		state[&"reads"] = int(state[&"reads"]) + 1
		return int(state[&"reads"]) * FAKE_CLOCK_STEP_MSEC

func test_wait_delay_wall_clock_guardrail_warns_and_forces_return() -> void:
	## 墙钟护栏：假钟跳步 → 首帧墙钟超限 push_warning（含耗时/上限）并强制
	## 返回——await 达成即证明协程收束未永挂（跳过/离树退出逻辑未动）
	var controller := _MakeBareController(TEST_DELAY_SECONDS)
	_InjectFakeClock(controller)
	var limit_msec: int = int(TEST_DELAY_SECONDS * 1000.0 * WALL_CLOCK_RATIO)
	var expected: String = "BattleController: 演出延时墙钟护栏触发（单位 无行动单位，已耗时 %d ms 超上限 %d ms）——强制返回防演出永挂" % [
			FAKE_CLOCK_STEP_MSEC, limit_msec]
	await assert_error(func() -> void: await controller._wait_delay()) \
			.is_push_warning(expected)

func test_wait_delay_normal_path_no_warning() -> void:
	## 常规路径：真实墙钟 + 小延时正常逐帧累计收束，零 warning（护栏不误伤）
	var controller := _MakeBareController(NORMAL_DELAY_SECONDS)
	await assert_error(func() -> void: await controller._wait_delay()).is_success()

func test_enemy_turn_watchdog_warns_and_completes() -> void:
	## 看门狗：假钟跳步（入口/出口两次读钟 → 记 60 s）→ 敌方轮出口超上限
	## push_warning 留痕（含单位 id/回合数/耗时），行动正常完成——
	## has_acted 置位且战局未收束（不中断不改动行为）
	var controller := _MakeEnemyTurnController()
	var enemy: BattleUnit = controller._context.enemies[0]
	_InjectFakeClock(controller)
	var expected: String = "BattleController: 敌方轮看门狗超时（单位 %s / 第 %d 回合 / 耗时 %d ms 超上限 %d ms）——仅留痕不中断" % [
			String(enemy.unit_id), 1, FAKE_CLOCK_STEP_MSEC, WATCHDOG_MSEC]
	await assert_error(func() -> void: await controller._run_enemy_turn(enemy)) \
			.is_push_warning(expected)
	assert_bool(enemy.has_acted).is_true()
	assert_bool(controller.is_battle_over()).is_false()
	controller.abort_battle()

func test_enemy_turn_watchdog_silent_on_fast_turn() -> void:
	## 常规敌方轮：真实墙钟耗时远低于上限 → 零 warning（看门狗不误伤），行动
	## 照常完成
	var controller := _MakeEnemyTurnController()
	var enemy: BattleUnit = controller._context.enemies[0]
	await assert_error(func() -> void: await controller._run_enemy_turn(enemy)) \
			.is_success()
	assert_bool(enemy.has_acted).is_true()
	controller.abort_battle()
