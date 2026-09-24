## 战斗场景布局契约测试（M1 硬验收门点击无反应 BUG 修复防回归，2026-09-24）
## 覆盖：battle_screen.tscn 静态布局契约——ResultLayer（全屏 CenterContainer）
## 必须 IGNORE（树序顶层若为默认 PASS 会截获全屏点击，导致棋盘/底栏全部
## 无反应，即 2026-09-24 实锤的"战斗场景点击无响应"根因）；ResultPanel
## 保持 STOP（父级 IGNORE 不遮子树命中，结算面板与返回按钮正常可点）；
## 关键输入节点在位且 BoardLayer.gui_input 已连接 battle_screen。
## headless 无法模拟真实鼠标 GUI 派发（push_input 不触发派发），只做静态契约断言。
extends GdUnitTestSuite

## 战斗场景路径
const BATTLE_SCENE: String = "res://scenes/battle/battle_screen.tscn"

func test_result_layer_mouse_filter_contract() -> void:
	## 防回归核心：ResultLayer 必须 IGNORE、ResultPanel 必须 STOP——
	## "平时不挡棋盘"与"弹出时可点"两条命中契约一次锁死
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	# ResultLayer 未设 unique_name_in_owner，走普通相对路径
	var result_layer: CenterContainer = battle.get_node("ResultLayer") as CenterContainer
	assert_object(result_layer).is_not_null()
	assert_int(result_layer.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var result_panel: PanelContainer = battle.get_node("%ResultPanel") as PanelContainer
	assert_object(result_panel).is_not_null()
	assert_int(result_panel.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

func test_input_nodes_and_connections_contract() -> void:
	## 关键输入节点在位 + BoardLayer.gui_input 已连接 battle_screen——
	## 场景能实例化不报错本身即冒烟（直开走无参降级路径）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	var board: Control = battle.get_node("%BoardLayer") as Control
	assert_object(board).is_not_null()
	# 棋盘输入链：gui_input 必须挂到 battle_screen（场景 [connection] 的运行时投影）
	var board_connected: bool = false
	for connection: Dictionary in board.gui_input.get_connections():
		var target: Callable = connection["callable"] as Callable
		if target.get_object() == battle:
			board_connected = true
	assert_bool(board_connected).is_true()
	# 底栏五按钮（普攻/技能1/技能2/行动结束/撤退）全部在位
	var button_names: Array[String] = [
		"%AttackButton",
		"%SkillButtonA",
		"%SkillButtonB",
		"%EndTurnButton",
		"%RetreatButton",
	]
	for button_name: String in button_names:
		assert_object(battle.get_node_or_null(button_name)).is_not_null()

func test_battle_log_layout_contract() -> void:
	## 日志栏布局契约（2026-09-24 五轮反馈；六轮补尺寸断言堵盲区）：存在 +
	## STOP（要滚动）+ 右侧锚定窄栏 + **正尺寸**（>200×200——六轮实锤 BUG：
	## anchor_bottom 缺失致 rect 负高被钳最小值 16px，日志不可见而条目数测试
	## 照样全绿）；顺带对 UnitInfoCard/BoardLayer 加同类正尺寸断言，防今后
	## 任何锚点塌缩类 BUG 再漏过
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	var log_panel: PanelContainer = battle.get_node("%BattleLog") as PanelContainer
	assert_object(log_panel).is_not_null()
	assert_int(log_panel.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_float(log_panel.anchor_left).is_equal(1.0)
	assert_float(log_panel.anchor_right).is_equal(1.0)
	assert_float(log_panel.anchor_bottom).is_equal(1.0)
	assert_float(log_panel.offset_left).is_equal(-296.0)
	assert_float(log_panel.offset_right).is_equal(-12.0)
	# 正尺寸契约（headless 布局照常计算；视口无关——只断言明显大于可显示下限）
	assert_float(log_panel.size.y).is_greater(200.0) \
			.override_failure_message("BattleLog 高度塌缩（%s）——检查锚点 offset" % log_panel.size)
	assert_float(log_panel.size.x).is_greater(200.0)
	var info_card: Control = battle.get_node("%UnitInfoCard") as Control
	assert_float(info_card.size.y).is_greater(100.0) \
			.override_failure_message("UnitInfoCard 高度塌缩（%s）" % info_card.size)
	assert_float(info_card.size.x).is_greater(200.0)
	var board: Control = battle.get_node("%BoardLayer") as Control
	assert_float(board.size.x).is_greater(200.0) \
			.override_failure_message("BoardLayer 宽度塌缩（%s）" % board.size)
	assert_float(board.size.y).is_greater(200.0)
