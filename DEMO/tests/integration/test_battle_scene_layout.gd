## 战斗场景布局契约测试（M1 硬验收门点击无反应 BUG 修复防回归，2026-09-24；
## 批次 B 布局重构改版 2026-10-07：回合大字+竖排序条+信息卡归左带、五钮
## ButtonRow 左下贴底、棋盘上下撑满、右栏提示行首位+日志加宽；
## E1 批 2026-10-09：棋盘改剩余区适配居中——底边扣按钮行区 -84、顶边贴屏顶）
## 覆盖：battle_screen.tscn 静态布局契约——ResultLayer（全屏 CenterContainer）
## 必须 IGNORE（树序顶层若为默认 PASS 会截获全屏点击，导致棋盘/底栏全部
## 无反应，即 2026-09-24 实锤的"战斗场景点击无响应"根因）；ResultPanel
## 保持 STOP（父级 IGNORE 不遮子树命中，结算面板与返回按钮正常可点）；
## 关键输入节点在位且 BoardLayer.gui_input 已连接 battle_screen；右栏
## 新锚定契约（-332/12/-12/-12 竖撑满+EnemyTurnHint 首子+BattleLog 正尺寸）；
## 左带契约（BoardLayer 满高扣两侧/LeftPanel 304/RoundLabel 首子/TurnOrderBar
## 在 LeftScroll/UnitInfoCard 末子/ButtonRow 五钮贴底对齐+树序浮层）；按钮行
## natural 宽契约（复核缺陷修复：长技能名替换后盒容纳/屏内/互不重叠/贴底维持）。
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
	## 右侧栏布局契约（批次 B 布局重构改版：RightPanel 右侧上下撑满——
	## 提示行+日志加宽贴右）：RightPanel 右锚定（top=12/bottom=-12 竖撑满）
	## + 横向滚动禁用；EnemyTurnHint 升 RightLayout 首子；BattleLog STOP
	##（要滚动）+ 正尺寸；BoardLayer 正尺寸断言防锚点塌缩类 BUG
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	var right_panel: ScrollContainer = battle.get_node("%RightPanel") as ScrollContainer
	assert_object(right_panel).is_not_null()
	assert_float(right_panel.anchor_left).is_equal(1.0)
	assert_float(right_panel.anchor_right).is_equal(1.0)
	assert_float(right_panel.anchor_top).is_equal(0.0)
	assert_float(right_panel.anchor_bottom).is_equal(1.0)
	assert_float(right_panel.offset_left).is_equal(-332.0)
	assert_float(right_panel.offset_top).is_equal(12.0)
	assert_float(right_panel.offset_right).is_equal(-12.0)
	assert_float(right_panel.offset_bottom).is_equal(-12.0)
	assert_int(right_panel.horizontal_scroll_mode) \
			.is_equal(ScrollContainer.SCROLL_MODE_DISABLED)
	# 提示行升首位（批次 B：日志上方常驻位）
	var right_layout: VBoxContainer = battle.get_node(
			"%RightPanel/RightLayout") as VBoxContainer
	var hint: Label = battle.get_node("%EnemyTurnHint") as Label
	assert_object(hint).is_not_null()
	assert_str(hint.get_parent().name).is_equal("RightLayout")
	assert_int(hint.get_index()).is_equal(0) \
			.override_failure_message("EnemyTurnHint 应为 RightLayout 首子")
	var log_panel: PanelContainer = battle.get_node("%BattleLog") as PanelContainer
	assert_object(log_panel).is_not_null()
	assert_str(log_panel.get_parent().name).is_equal("RightLayout")
	assert_int(log_panel.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	# 正尺寸契约（headless 布局照常计算；视口无关——只断言明显大于可显示下限）
	assert_float(log_panel.size.y).is_greater(200.0) \
			.override_failure_message("BattleLog 高度塌缩（%s）——检查右栏容器" % log_panel.size)
	assert_float(log_panel.size.x).is_greater(200.0)
	var board: Control = battle.get_node("%BoardLayer") as Control
	assert_float(board.size.x).is_greater(200.0) \
			.override_failure_message("BoardLayer 宽度塌缩（%s）" % board.size)
	assert_float(board.size.y).is_greater(200.0)

func test_left_belt_layout_contract() -> void:
	## 左带布局契约（批次 B 布局重构 + E1 剩余区适配居中改版）：BoardLayer
	## 顶边贴屏顶（顶部无回合条区——回合大字在左带，方案 §〇.6 实测修正）、
	## 底边扣按钮行区（offset_bottom == -84——ButtonRow 占屏底 84px 起，棋盘
	## 不再被按钮行遮挡）且水平扣两侧 UI（left=324/right=-340 不变）；
	## LeftPanel 宽 304（回合大字首子 + LeftScroll 竖排序条 + UnitInfoCard
	## 末子）；TurnOrderBar 父 == LeftScroll 且横滚禁用；ButtonRow 五钮在位、
	## 贴屏底（offset_bottom=-12 ± 0.5）且左缘与信息卡左缘对齐
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	# 棋盘带：剩余区适配（顶贴屏顶、底扣按钮行、左右扣两侧）
	var board: Control = battle.get_node("%BoardLayer") as Control
	assert_float(board.offset_top).is_equal(0.0) \
			.override_failure_message("BoardLayer 顶边应贴屏顶（顶部无回合条区——左带结构）")
	assert_float(board.offset_bottom).is_equal(-84.0) \
			.override_failure_message("BoardLayer 底边应扣按钮行区 -84（剩余区适配居中）")
	assert_float(board.offset_left).is_equal(324.0)
	assert_float(board.offset_right).is_equal(-340.0)
	# 左带容器：定宽 304（12→316 锚定，分辨率无关）
	var left_panel: VBoxContainer = battle.get_node("%LeftPanel") as VBoxContainer
	assert_object(left_panel).is_not_null()
	assert_float(absf(left_panel.size.x - 304.0)).is_less_equal(0.5) \
			.override_failure_message("LeftPanel 宽度应为 304（实际 %s）" % left_panel.size)
	# 回合大字首子 / 序条在 LeftScroll 内 / 信息卡 LeftPanel 末子
	var round_label: Label = battle.get_node("%RoundLabel") as Label
	assert_str(round_label.get_parent().name).is_equal("LeftPanel")
	assert_int(round_label.get_index()).is_equal(0) \
			.override_failure_message("RoundLabel 应为 LeftPanel 首子")
	var left_scroll: ScrollContainer = battle.get_node("%LeftScroll") as ScrollContainer
	assert_object(left_scroll).is_not_null()
	assert_int(left_scroll.horizontal_scroll_mode) \
			.is_equal(ScrollContainer.SCROLL_MODE_DISABLED)
	var order_bar: Control = battle.get_node("%TurnOrderBar")
	assert_str(order_bar.get_parent().name).is_equal("LeftScroll")
	var info_card: Control = battle.get_node("%UnitInfoCard")
	assert_str(info_card.get_parent().name).is_equal("LeftPanel")
	assert_int(info_card.get_index()).is_equal(left_panel.get_child_count() - 1) \
			.override_failure_message("UnitInfoCard 应为 LeftPanel 末子")
	# 五钮单行：全部 ButtonRow 子节点 + 树序在 BoardLayer 之后（浮层契约——
	# 按钮 min 撑开溢出 offset 盒的部分伸入棋盘区，绘制/点击须在棋盘之上）
	# + 贴屏底（-12 ± 0.5）+ 左缘对齐信息卡
	var button_row: Control = battle.get_node("%ButtonRow")
	assert_object(button_row).is_not_null()
	assert_bool(button_row.get_index() > board.get_index()).is_true() \
			.override_failure_message("ButtonRow 树序应在 BoardLayer 之后（浮层不被棋盘遮盖）")
	for button_name: String in ["%AttackButton", "%SkillButtonA", "%SkillButtonB",
			"%EndTurnButton", "%RetreatButton"]:
		var button: Control = battle.get_node(button_name)
		assert_object(button).is_not_null()
		assert_str(button.get_parent().name).is_equal("ButtonRow") \
				.override_failure_message("%s 应为 ButtonRow 子节点" % button_name)
	assert_bool(absf((button_row.position.y + button_row.size.y) \
			- (battle.size.y - 12.0)) <= 0.5).is_true() \
			.override_failure_message("ButtonRow 应贴屏底 12px（底边 %s vs 屏高-12=%s）" % [
					button_row.position.y + button_row.size.y, battle.size.y - 12.0])
	assert_bool(absf(button_row.position.x - info_card.global_position.x) <= 0.5).is_true() \
			.override_failure_message("ButtonRow 左缘 %s 应与信息卡左缘 %s 对齐" % [
					button_row.position.x, info_card.global_position.x])

func test_button_row_natural_width_contract() -> void:
	## 按钮行 natural 宽契约（复核缺陷修复防回归）：运行时技能名替换为长名
	##（射击/穿云箭/布置陷阱/行动结束/撤退——生产链 _RefreshActionBar 口径）
	## 后：①ButtonRow 盒宽（min 撑开后 size）容纳五钮 natural 总和（HBox 不
	## 溢出挤压——间距均匀的机制前提）；②五钮矩形全在屏内（1280×720 不溢出
	## 硬性条款——本用例在测试视口断言机制，三档分辨率由 stretch 等比保证）；
	## ③相邻钮互不重叠；④贴屏底与左缘对齐在长名态维持
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	var button_row: Control = battle.get_node("%ButtonRow")
	var button_names: Array[String] = ["%AttackButton", "%SkillButtonA",
			"%SkillButtonB", "%EndTurnButton", "%RetreatButton"]
	# 生产长技能名替换（游侠档：射击/穿云箭/布置陷阱——四字三字混合最长档）
	var long_texts: Array[String] = ["射击", "穿云箭", "布置陷阱", "行动结束", "撤退"]
	for index: int in button_names.size():
		var button: Button = battle.get_node(button_names[index]) as Button
		button.text = long_texts[index]
	await get_tree().process_frame
	await get_tree().process_frame
	# ①盒容纳 natural（min 撑开机制：size >= combined min——不依赖具体字体宽）
	var natural_total: float = button_row.get_combined_minimum_size().x
	assert_float(button_row.size.x).is_greater_equal(natural_total - 0.5) \
			.override_failure_message("ButtonRow 盒宽 %s 未容纳五钮 natural 总宽 %s——HBox 溢出挤压" % [
					button_row.size.x, natural_total])
	# ②③全在屏内 + 相邻互不重叠（rect 间隙 >= 0）
	var screen_rect: Rect2 = battle.get_global_rect()
	var prev_end_x: float = -1.0
	for button_name: String in button_names:
		var button: Control = battle.get_node(button_name)
		var rect: Rect2 = button.get_global_rect()
		assert_bool(screen_rect.encloses(rect)).is_true() \
				.override_failure_message("%s 矩形 %s 越出屏幕 %s" % [button_name, rect, screen_rect])
		if prev_end_x >= 0.0:
			assert_float(rect.position.x).is_greater_equal(prev_end_x - 0.5) \
					.override_failure_message("%s 与前钮重叠（左缘 %s < 前右缘 %s）" % [
							button_name, rect.position.x, prev_end_x])
		prev_end_x = rect.end.x
	# ④长名态贴底 + 左缘维持
	var info_card: Control = battle.get_node("%UnitInfoCard")
	assert_bool(absf((button_row.position.y + button_row.size.y) \
			- (battle.size.y - 12.0)) <= 0.5).is_true() \
			.override_failure_message("长名态 ButtonRow 应贴屏底 12px")
	assert_bool(absf(button_row.position.x - info_card.global_position.x) <= 0.5).is_true() \
			.override_failure_message("长名态 ButtonRow 左缘应与信息卡对齐")
