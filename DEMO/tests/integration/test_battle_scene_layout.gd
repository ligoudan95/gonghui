## 战斗场景布局契约测试（M1 硬验收门点击无反应 BUG 修复防回归，2026-09-24；
## 批次 B 布局重构改版 2026-10-07：回合大字+竖排序条+信息卡归左带、五钮
## ButtonRow 左下贴底、棋盘上下撑满；E1 批 2026-10-09：棋盘改剩余区适配
## 居中——底边扣按钮行区 -84、顶边贴屏顶；布局三改批 2026-10-09：右栏退役
## 日志卷轴化——LeftPanel 收窄 220/信息卡 min 212/棋盘右扩 240→-12/日志改
## LogScroller 浮层（z=300）+敌方提示并入锚点条）
## 覆盖：battle_screen.tscn 静态布局契约——ResultLayer（全屏 CenterContainer）
## 必须 IGNORE（树序顶层若为默认 PASS 会截获全屏点击，导致棋盘/底栏全部
## 无反应，即 2026-09-24 实锤的"战斗场景点击无响应"根因）且 z=400 压卷轴；
## ResultPanel 保持 STOP（父级 IGNORE 不遮子树命中，结算面板与返回按钮正常
## 可点）；关键输入节点在位且 BoardLayer.gui_input 已连接 battle_screen；
## 日志卷轴契约（LogScroller 挂 BattleScreen 直下/z=300/根 IGNORE/ExpandPanel
## 默认 invisible 且 STOP/BattleLog 迁 ExpandPanel/AnchorLabel 占位；
## RightPanel/EnemyTurnHint 退役不再存在）；左带契约（BoardLayer 满高扣两侧
## 240/-12/LeftPanel 220/RoundLabel 首子/TurnOrderBar 在 LeftScroll/
## UnitInfoCard 末子/ButtonRow 五钮贴底对齐+树序浮层）；按钮行 natural 宽
## 契约（复核缺陷修复：长技能名替换后盒容纳/屏内/互不重叠/贴底维持）；
## 视口批契约（常驻 UI z=250 三节点压棋盘 tips/飘字让卷轴结算；WorldLayer
## 懒建结构——装配后挂 BoardLayer 直下/IGNORE/z=0/FULL_RECT 尺寸==板尺寸）。
## headless 无法模拟真实鼠标 GUI 派发（push_input 不触发派发），只做静态契约断言。
extends GdUnitTestSuite

## 战斗场景路径
const BATTLE_SCENE: String = "res://scenes/battle/battle_screen.tscn"

func test_result_layer_mouse_filter_contract() -> void:
	## 防回归核心：ResultLayer 必须 IGNORE、ResultPanel 必须 STOP——
	## "平时不挡棋盘"与"弹出时可点"两条命中契约一次锁死；布局三改批补
	## z 序：ResultLayer z=400 恒压日志卷轴浮层（z=300）——结算弹出不被
	## 卷轴遮挡
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	# ResultLayer 未设 unique_name_in_owner，走普通相对路径
	var result_layer: CenterContainer = battle.get_node("ResultLayer") as CenterContainer
	assert_object(result_layer).is_not_null()
	assert_int(result_layer.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(result_layer.z_index).is_equal(400) \
			.override_failure_message("ResultLayer z_index 应为 400（压日志卷轴 300）")
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
	## 战斗日志卷轴契约（布局三改批：右栏退役、日志卷轴化）：LogScroller 挂
	## BattleScreen 直下（不挂 BoardLayer——_ApplyResizeRebuild 会全量
	## queue_free 子节点）+ z=Z_LOG_OVERLAY(300) 压棋盘 tips/飘字 + 根
	## IGNORE 全穿透；ExpandPanel 默认 invisible 且 STOP（展开态才命中）；
	## BattleLog 迁 ExpandPanel 内（unique_name 迁父后 %BattleLog 引用不变）；
	## AnchorLabel 占位「战斗日志 (0)」；RightPanel/RightLayout/EnemyTurnHint
	## 整树已删；板面正尺寸护栏保留（防锚点塌缩类 BUG）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	var scroller: Control = battle.get_node("%LogScroller")
	assert_object(scroller).is_not_null()
	# 父 == 场景根本体（is_same——gdUnit 同套件多实例根节点会带 @id 防重名
	# 后缀，字面名断言脆；实例同一性才是「挂 BattleScreen 直下」的契约本体）
	assert_object(scroller.get_parent()).is_same(battle) \
			.override_failure_message("LogScroller 应挂 BattleScreen 直下（不挂 BoardLayer）")
	assert_int(scroller.z_index).is_equal(BattleLogScroller.Z_LOG_OVERLAY) \
			.override_failure_message("LogScroller z_index 应为 Z_LOG_OVERLAY %d" % BattleLogScroller.Z_LOG_OVERLAY)
	assert_int(scroller.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE) \
			.override_failure_message("LogScroller 根必须 IGNORE（收起态棋盘零遮挡）")
	var expand_panel: PanelContainer = battle.get_node("%ExpandPanel") as PanelContainer
	assert_object(expand_panel).is_not_null()
	assert_bool(expand_panel.visible).is_false() \
			.override_failure_message("ExpandPanel 默认应 invisible（新日志不自动展开）")
	assert_int(expand_panel.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	var log_panel: PanelContainer = battle.get_node("%BattleLog") as PanelContainer
	assert_object(log_panel).is_not_null()
	assert_str(log_panel.get_parent().name).is_equal("ExpandPanel")
	assert_int(log_panel.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	var anchor_label: Label = battle.get_node("%AnchorLabel") as Label
	assert_object(anchor_label).is_not_null()
	assert_str(anchor_label.text).is_equal("战斗日志 (0)")
	# 退役节点不再存在（右栏整树删除——残留即场景未同步）
	assert_object(battle.get_node_or_null("%RightPanel")).is_null()
	assert_object(battle.get_node_or_null("%EnemyTurnHint")).is_null()
	# 板面正尺寸护栏（headless 布局照常计算；视口无关——只断言明显大于可显示下限）
	var board: Control = battle.get_node("%BoardLayer") as Control
	assert_float(board.size.x).is_greater(200.0) \
			.override_failure_message("BoardLayer 宽度塌缩（%s）" % board.size)
	assert_float(board.size.y).is_greater(200.0)

func test_left_belt_layout_contract() -> void:
	## 左带布局契约（批次 B 布局重构 + E1 剩余区适配居中 + 布局三改批收窄/
	## 右扩）：BoardLayer 顶边贴屏顶（顶部无回合条区——回合大字在左带）、
	## 底边扣按钮行区（offset_bottom == -84）且水平扣两侧 UI（left=240/
	## right=-12——左列收窄 220 + 右栏退役棋盘右扩贴边）；LeftPanel 宽 220
	##（回合大字首子 + LeftScroll 竖排序条 + UnitInfoCard 末子 min 212）；
	## TurnOrderBar 父 == LeftScroll 且横滚禁用；ButtonRow 五钮在位、贴屏底
	##（offset_bottom=-12 ± 0.5）且左缘与信息卡左缘对齐
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	# 棋盘带：剩余区适配（顶贴屏顶、底扣按钮行、左右扣两侧）
	var board: Control = battle.get_node("%BoardLayer") as Control
	assert_float(board.offset_top).is_equal(0.0) \
			.override_failure_message("BoardLayer 顶边应贴屏顶（顶部无回合条区——左带结构）")
	assert_float(board.offset_bottom).is_equal(-84.0) \
			.override_failure_message("BoardLayer 底边应扣按钮行区 -84（剩余区适配居中）")
	assert_float(board.offset_left).is_equal(240.0)
	assert_float(board.offset_right).is_equal(-12.0)
	# 左带容器：定宽 220（12→232 锚定，分辨率无关）
	var left_panel: VBoxContainer = battle.get_node("%LeftPanel") as VBoxContainer
	assert_object(left_panel).is_not_null()
	assert_float(absf(left_panel.size.x - 220.0)).is_less_equal(0.5) \
			.override_failure_message("LeftPanel 宽度应为 220（实际 %s）" % left_panel.size)
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

func test_viewport_ui_z_layers_contract() -> void:
	## 视口批 UI 层级契约：LeftPanel/ButtonRow/IdleLabel 常驻 UI 基座
	## z=250（UI_BASE_Z）——棋盘缩放平移放大后仍恒置顶不遮操作区；
	## 三向比较：250 > 棋盘 tips/飘字（Z_TEXT=200）、250 < LogScroller
	##（300）/ResultLayer（400）——卷轴结算恒压常驻 UI
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	var left_panel: Control = battle.get_node("%LeftPanel")
	var button_row: Control = battle.get_node("%ButtonRow")
	var idle_label: Control = battle.get_node("%IdleLabel")
	for base_node: Control in [left_panel, button_row, idle_label]:
		assert_int(base_node.z_index).is_equal(250) \
				.override_failure_message("%s z_index 应为常驻 UI 基座 250" % base_node.name)
	# 三向比较：压棋盘文本层 / 让卷轴与结算
	var scroller: Control = battle.get_node("%LogScroller")
	var result_layer: Control = battle.get_node("ResultLayer")
	assert_bool(left_panel.z_index > BattleBoard.Z_TEXT).is_true() \
			.override_failure_message("常驻 UI 基座应压棋盘 tips/飘字（Z_TEXT=%d）" % BattleBoard.Z_TEXT)
	assert_bool(left_panel.z_index < scroller.z_index).is_true() \
			.override_failure_message("日志卷轴应恒压常驻 UI 基座")
	assert_bool(result_layer.z_index > left_panel.z_index).is_true() \
			.override_failure_message("结算层应恒压常驻 UI 基座")
	assert_int(scroller.z_index).is_equal(BattleLogScroller.Z_LOG_OVERLAY)

func test_viewport_world_layer_structure_contract() -> void:
	## 视口批 WorldLayer 结构契约：装配后（setup 走 _EnterRandomBattle 同源
	## 调试链不可用——降级直开场景 BoardLayer 未装配无 WorldLayer，此处
	## 用手动 setup 契约断言：代码懒建 Control）——parent == BoardLayer、
	## IGNORE、z == 0、FULL_RECT 尺寸 == 板尺寸（缩放/平移载体唯一性；
	## 降级路径不懒建视口层——空板直开不产生中间层）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	assert_object(board).is_not_null()
	# 降级契约：未装配不懒建（board 直挂子零——无 WorldLayer 残留）
	assert_object(board._world_layer).is_null()
	assert_int(board.get_child_count()).is_equal(0)
	# 手动装配（空上下文夹具——WorldLayer 随首格懒建）
	var grid := BattleGrid.new()
	var map_def: BattleMapDef = load("res://data/battle/maps/btm_m1_random_8x8.tres") as BattleMapDef
	var tiles: Dictionary = {}
	for tile_id: StringName in [&"tile_normal", &"tile_obstacle", &"tile_grass",
			&"tile_highground", &"tile_poison_swamp", &"tile_trap"]:
		tiles[tile_id] = load("res://data/battle/tiles/" + String(tile_id) + ".tres")
	assert_bool(grid.setup(map_def, func(tile_id: StringName) -> TileTypeDef:
		return tiles.get(tile_id, null) as TileTypeDef)).is_true()
	var context := BattleSetup.BattleContext.new()
	context.grid = grid
	context.units = []
	board.setup(context, get_tree().root.get_node("GameData"))
	var world: Control = board._world_layer
	assert_object(world).is_not_null() \
			.override_failure_message("装配后 WorldLayer 应懒建")
	assert_object(world.get_parent()).is_same(board)
	assert_int(world.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE) \
			.override_failure_message("WorldLayer 必须 IGNORE（不截获板面命中）")
	assert_int(world.z_index).is_equal(0)
	await get_tree().process_frame
	assert_vector(world.size).is_equal(board.size) \
			.override_failure_message("WorldLayer FULL_RECT 尺寸应 == 板尺寸（%s vs %s）" % [
					world.size, board.size])

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
