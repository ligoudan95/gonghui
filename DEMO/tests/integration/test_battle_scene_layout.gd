## 战斗场景布局契约测试（M1 硬验收门点击无反应 BUG 修复防回归，2026-09-24；
## 批次 B 布局重构改版 2026-10-07；E1 批 2026-10-09：棋盘改剩余区适配
## 居中；布局三改批 2026-10-09：右栏退役日志卷轴化；顶部横条批 2026-10-11：
## LeftPanel 整树退役——回合 UI+行动序上移顶部横条（TopBar z=250 全宽顶部条）
## +信息卡改左下角点选浮层（z=250 默认 invisible）+棋盘放大（左缘 240→24/
## 顶 68 让横条））
## 覆盖：battle_screen.tscn 静态布局契约——ResultLayer（全屏 CenterContainer）
## 必须 IGNORE（树序顶层若为默认 PASS 会截获全屏点击，导致棋盘/底栏全部
## 无反应，即 2026-09-24 实锤的"战斗场景点击无响应"根因）且 z=400 压卷轴；
## ResultPanel 保持 STOP（父级 IGNORE 不遮子树命中，结算面板与返回按钮正常
## 可点）；关键输入节点在位且 BoardLayer.gui_input 已连接 battle_screen；
## 日志卷轴契约（LogScroller 挂 BattleScreen 直下/z=300/根 IGNORE/ExpandPanel
## 默认 invisible 且 STOP/BattleLog 迁 ExpandPanel/AnchorLabel 占位；
## RightPanel/EnemyTurnHint 退役不再存在）；顶部横条契约（TopBar 挂
## BattleScreen 直下 BoardLayer 后/z=250/IGNORE/clip_contents、MarginBox
## 四 margin=cfg 值、RoundLabel 首子+TurnOrderBar 次子、BoardLayer 四 offset
## 24/68/-12/-84、LeftPanel/LeftScroll 退役、UnitInfoCard 浮层化——直下/
## z=250/默认 invisible/底边在按钮行上缘之上）；按钮行 natural 宽契约
##（长技能名替换后盒容纳/屏内/互不重叠/贴底维持）；视口批契约（常驻 UI
## z=250 四成员压棋盘 tips/飘字让卷轴结算；WorldLayer 懒建结构——装配后
## 挂 BoardLayer 直下/IGNORE/z=0/FULL_RECT 尺寸==板尺寸）。
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

func test_topbar_layout_contract() -> void:
	## 顶部横条布局契约（顶部横条批：LeftPanel 整树退役）：TopBar 挂
	## BattleScreen 直下（BoardLayer 之后树序）+ z=250 + IGNORE + clip_contents；
	## MarginBox 四 margin = cfg 兜底值（降级直开口径 12/12/12/174——
	## cfg_main 表值与兜底同值）；RoundLabel 首子 + TurnOrderBar 次子在
	## TopBarContent 内；BoardLayer 四 offset 新值 24/68/-12/-84（棋盘左缘
	## 贴左带退役后的 24、顶让横条 68、底扣按钮行 -84、右贴 -12）；
	## LeftPanel/LeftScroll 退役不再存在；UnitInfoCard 浮层化——挂直下、
	## z=250、默认 invisible、底边在按钮行上缘之上（零重叠 + 8px 间隙）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	# 横条容器：直下 + 树序 BoardLayer 后 + z250 + IGNORE + clip_contents
	var board: Control = battle.get_node("%BoardLayer") as Control
	var topbar: Control = battle.get_node("%TopBar")
	assert_object(topbar).is_not_null()
	assert_object(topbar.get_parent()).is_same(battle) \
			.override_failure_message("TopBar 应挂 BattleScreen 直下")
	assert_bool(topbar.get_index() > board.get_index()).is_true() \
			.override_failure_message("TopBar 树序应在 BoardLayer 之后")
	assert_int(topbar.z_index).is_equal(250)
	assert_int(topbar.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_bool(topbar.clip_contents).is_true() \
			.override_failure_message("TopBar 应 clip_contents（极端降级溢出裁切护栏）")
	# MarginBox 四边距 = 兜底值（cfg_main 表值同值——两态一致）
	var margin_box: MarginContainer = battle.get_node("TopBar/MarginBox") as MarginContainer
	assert_object(margin_box).is_not_null()
	assert_int(margin_box.get_theme_constant("margin_left")).is_equal(
			int(UiTheme.TOPBAR_LEFT_MARGIN))
	assert_int(margin_box.get_theme_constant("margin_right")).is_equal(
			int(UiTheme.TOPBAR_RIGHT_RESERVE)) \
			.override_failure_message("MarginBox 右预留应为 %d（日志锚点让位）" % int(UiTheme.TOPBAR_RIGHT_RESERVE))
	assert_int(margin_box.get_theme_constant("margin_top")).is_equal(
			int(UiTheme.TOPBAR_MARGIN_TOP))
	assert_int(margin_box.get_theme_constant("margin_bottom")).is_equal(
			int(UiTheme.TOPBAR_MARGIN_BOTTOM))
	# 回合标签首子 + 行动序次子（TopBarContent 内）
	var round_label: Label = battle.get_node("%RoundLabel") as Label
	assert_str(round_label.get_parent().name).is_equal("TopBarContent")
	assert_int(round_label.get_index()).is_equal(0) \
			.override_failure_message("RoundLabel 应为 TopBarContent 首子")
	var order_bar: Control = battle.get_node("%TurnOrderBar")
	assert_str(order_bar.get_parent().name).is_equal("TopBarContent")
	assert_int(order_bar.get_index()).is_equal(1) \
			.override_failure_message("TurnOrderBar 应为 TopBarContent 次子")
	# 棋盘带：左缘 24 / 顶让横条 68 / 右 -12 / 底扣按钮行 -84
	assert_float(board.offset_left).is_equal(24.0)
	assert_float(board.offset_top).is_equal(68.0) \
			.override_failure_message("BoardLayer 顶边应让横条 68（顶部横条结构）")
	assert_float(board.offset_right).is_equal(-12.0)
	assert_float(board.offset_bottom).is_equal(-84.0)
	# 退役节点不再存在（左带整树删除——残留即场景未同步）
	assert_object(battle.get_node_or_null("%LeftPanel")).is_null()
	assert_object(battle.get_node_or_null("%LeftScroll")).is_null()
	# 信息卡浮层化：直下 + z250 + 默认 invisible + 底边在按钮行上缘之上
	var info_card: Control = battle.get_node("%UnitInfoCard")
	assert_object(info_card.get_parent()).is_same(battle) \
			.override_failure_message("UnitInfoCard 应挂 BattleScreen 直下（浮层化）")
	assert_bool(info_card.get_index() > board.get_index()).is_true()
	assert_int(info_card.z_index).is_equal(250)
	assert_bool(info_card.visible).is_false() \
			.override_failure_message("UnitInfoCard 默认应 invisible（点选驱动）")
	assert_float(info_card.offset_left).is_equal(32.0)
	assert_float(info_card.offset_bottom).is_equal(-92.0)
	# 五钮单行：全部 ButtonRow 子节点 + 树序在 BoardLayer 之后 + 贴屏底
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
	# 信息卡底边 = 按钮行上缘 − 8px 间隙（三席盲审 T1-4：升级等值断言——
	## 两 8px 结构间隙之一（卡底/按钮行上缘），零重叠弱断言升级为精确间隙）
	info_card.visible = true
	assert_float(info_card.get_global_rect().end.y).is_equal_approx(
			button_row.get_global_rect().position.y - 8.0, 0.5) \
			.override_failure_message("信息卡底边 %s 应距按钮行上缘 %s 恰 8px 间隙" % [
					info_card.get_global_rect().end.y,
					button_row.get_global_rect().position.y])
	info_card.visible = false

func test_viewport_ui_z_layers_contract() -> void:
	## 视口批 UI 层级契约（顶部横条批四成员）：TopBar/ButtonRow/IdleLabel/
	## UnitInfoCard 常驻 UI 基座 z=250（UI_BASE_Z）——棋盘缩放平移放大后
	## 仍恒置顶不遮操作区；三向比较：250 > 棋盘 tips/飘字（Z_TEXT=200）、
	## 250 < LogScroller（300）/ResultLayer（400）——卷轴结算恒压常驻 UI
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	var topbar: Control = battle.get_node("%TopBar")
	var button_row: Control = battle.get_node("%ButtonRow")
	var idle_label: Control = battle.get_node("%IdleLabel")
	var info_card: Control = battle.get_node("%UnitInfoCard")
	for base_node: Control in [topbar, button_row, idle_label, info_card]:
		assert_int(base_node.z_index).is_equal(250) \
				.override_failure_message("%s z_index 应为常驻 UI 基座 250" % base_node.name)
	# 三向比较：压棋盘文本层 / 让卷轴与结算
	var scroller: Control = battle.get_node("%LogScroller")
	var result_layer: Control = battle.get_node("ResultLayer")
	assert_bool(topbar.z_index > BattleBoard.Z_TEXT).is_true() \
			.override_failure_message("常驻 UI 基座应压棋盘 tips/飘字（Z_TEXT=%d）" % BattleBoard.Z_TEXT)
	assert_bool(topbar.z_index < scroller.z_index).is_true() \
			.override_failure_message("日志卷轴应恒压常驻 UI 基座")
	assert_bool(result_layer.z_index > topbar.z_index).is_true() \
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
	## ③相邻钮互不重叠；④贴屏底与贴屏左 12px 在长名态维持（顶部横条批：
	## 左带退役后按钮行独立贴屏左 12——不再与信息卡对齐）
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
	# ④长名态贴底 + 贴屏左维持
	assert_bool(absf((button_row.position.y + button_row.size.y) \
			- (battle.size.y - 12.0)) <= 0.5).is_true() \
			.override_failure_message("长名态 ButtonRow 应贴屏底 12px")
	assert_bool(absf(button_row.position.x - 12.0) <= 0.5).is_true() \
			.override_failure_message("长名态 ButtonRow 左缘应贴屏左 12px（实际 %s）" % button_row.position.x)
