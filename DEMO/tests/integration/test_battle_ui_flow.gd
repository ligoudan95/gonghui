## 战棋 UI 流集成测试（M1 批 3，GdUnitSceneRunner）
## 覆盖：battle_screen 经调试入口加载（guild_shell → 随机遭遇按钮 → 场景切换）、
## 信号流冒烟（round_started/turn_started 到达——轮询式驱动到回合 2 佐证）、
## request_move 走通（我方单位移动生效）、battle_screen 直开无参优雅降级。
## UI 视觉细节（sprite/覆盖层/结算面板观感）不测——人工验收（编辑器五条清单）。
extends GdUnitTestSuite

## 场景路径
const GUILD_SCENE: String = "res://scenes/guild/guild_shell.tscn"
const BATTLE_SCENE: String = "res://scenes/battle/battle_screen.tscn"
## 信号等待帧上限（超时防死等）
const MAX_WAIT_FRAMES: int = 300

func before_test() -> void:
	## 用例前置：复位 SceneManager 可变状态（autoload 归引擎管理不释放）
	## 参数：无
	## 返回：无
	var scene_manager: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_object(scene_manager).is_not_null()
	scene_manager.current_id = -1
	scene_manager.previous_id = -1
	var no_params: Dictionary = {}
	scene_manager.pending_params = no_params

func test_guild_debug_entry_opens_battle_screen() -> void:
	## 调试入口全链路：公会壳 → 默认 4 职业勾选 → 随机遭遇按钮 →
	## BATTLE_SCREEN 挂载 + 战斗装配成立（徽章/上下文/控制器就绪）
	var runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	var button: Button = runner.find_child("DebugRandomButton", true, false) as Button
	assert_object(button).is_not_null()
	button.pressed.emit()
	await _AwaitSceneSwap()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	assert_object(battle.controller).is_not_null()
	assert_object(battle.context).is_not_null()
	assert_int(battle.context.allies.size()).is_equal(4)
	assert_int(battle.context.enemies.size()).is_equal(3)
	# 徽章池已建（我方 4 + 敌方 3）
	battle.controller.delay_seconds = 0.0
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	assert_int(board.get_children().filter(func(child): return child is UnitBadge).size()).is_equal(7)
	battle.controller.abort_battle()

func test_signal_flow_and_request_move() -> void:
	## 信号流冒烟 + 指令走通：调试入口进战斗 → 轮询等首轮我方指令窗 →
	## 连接信号 → 自动打完整回合（我方全部结束行动轮）→ 回合 2 的
	## round_started 到达佐证信号流；随后 request_move 生效（单位位置变更）
	var runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	var button: Button = runner.find_child("DebugRandomButton", true, false) as Button
	button.pressed.emit()
	await _AwaitSceneSwap()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	# 轮询等首个我方指令窗（战斗在 _ready 同步开战——round 1 信号早于本处连接，
	# 以回合 2 的信号到达为冒烟断言）
	var waited: int = 0
	while (battle.controller.current_unit == null \
			or not battle.controller.awaiting_command) and waited < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
	assert_bool(battle.controller.awaiting_command).is_true()
	var events: Dictionary = {&"round2": false, &"turn": false}
	battle.controller.round_started.connect(func(round_no: int) -> void:
		if round_no >= 2:
			events[&"round2"] = true)
	battle.controller.turn_started.connect(func(_unit: BattleUnit) -> void:
		events[&"turn"] = true)
	# 自动打完回合 1 与回合 2 的我方轮（敌方轮自动推进），直到回合 2 信号到达
	waited = 0
	while not events[&"round2"] and waited < MAX_WAIT_FRAMES:
		if battle.controller.awaiting_command:
			battle.controller.request_end_unit_turn()
		await get_tree().process_frame
		waited += 1
	assert_bool(events[&"round2"]).is_true()
	assert_bool(events[&"turn"]).is_true()
	# 回合 2 首个我方指令窗：request_move 走通（可达格 → 位置变更）
	waited = 0
	while not battle.controller.awaiting_command and waited < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
	var unit: BattleUnit = battle.controller.current_unit
	assert_object(unit).is_not_null()
	var reachable: Array[Vector2i] = battle.context.grid.find_reachable(unit, unit.move_final())
	assert_int(reachable.size()).is_greater(0)
	var dest: Vector2i = reachable[0]
	assert_bool(battle.controller.request_move(dest)).is_true()
	assert_int(unit.grid_pos.x).is_equal(dest.x)
	assert_int(unit.grid_pos.y).is_equal(dest.y)
	battle.controller.abort_battle()

func test_battle_screen_direct_load_smoke() -> void:
	## 直开冒烟：无跨场景参数 → 优雅降级（IdleLabel 提示、不开战不崩溃）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	assert_object(battle.context).is_null()
	var idle: Label = battle.get_node("%IdleLabel") as Label
	assert_object(idle).is_not_null()
	assert_bool(idle.visible).is_true()

func _AwaitSceneSwap() -> void:
	## 等待场景切换落地（change_scene_to_packed 延迟切换，让过两帧——M0 惯例）
	## 参数：无
	## 返回：无（协程）
	await get_tree().process_frame
	await get_tree().process_frame
