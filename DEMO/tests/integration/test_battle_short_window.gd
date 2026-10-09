## 极矮窗口契约测试（M6 批 2 挂账 4.3；批次 B 布局重构改版 2026-10-07；
## 布局三改批 2026-10-09：右栏退役、日志卷轴化——右栏/中4 滚动条补偿
## 契约随 RightPanel 整树退役删除，日志右缘改卷轴展开态口径）
## 覆盖：project 最小窗口 1280×720 设置且不与双档视口冲突；新树结构契约
##（UnitInfoCard 归 LeftPanel 末子、BattleLog 归 ExpandPanel、EnemyTurnHint
## 退役、HitArea/AnchorBar 在 LogScroller 内、TurnOrderBar 在 LeftScroll 内）；
## 720 档左栏 7 条目不溢出（LeftScroll 在位且无需滚动）；600 嵌入视口档
## LeftScroll 纵向可滚 + 棋盘正尺寸 + 日志卷轴展开态右缘不越屏宽−12；
## ButtonRow 右缘不越屏右缘内边 12px（遮蔽护栏）；E1 等距 720 档棋盘右扩后
##（1028 宽）菱形全宽达全带 [72,176] 不再让位。
extends GdUnitTestSuite

## 战斗场景路径
const BATTLE_SCENE: String = "res://scenes/battle/battle_screen.tscn"

func test_project_minimum_window_settings() -> void:
	## project.godot 最小窗口契约：1280×720（不与双档 viewport 1440×900 冲突
	##——minimum ≤ viewport 双向断言）
	var min_width: int = int(ProjectSettings.get_setting(
			"display/window/size/minimum_width", 0))
	var min_height: int = int(ProjectSettings.get_setting(
			"display/window/size/minimum_height", 0))
	assert_int(min_width).is_equal(1280)
	assert_int(min_height).is_equal(720)
	var vp_width: int = int(ProjectSettings.get_setting(
			"display/window/size/viewport_width", 0))
	var vp_height: int = int(ProjectSettings.get_setting(
			"display/window/size/viewport_height", 0))
	assert_int(vp_width).is_equal(1440)
	assert_int(vp_height).is_equal(900)
	assert_bool(min_width <= vp_width and min_height <= vp_height).is_true() \
			.override_failure_message("最小窗口超双档视口——设置冲突")

func _MakeUnits(count: int) -> Array:
	## 手造测试单位（rebuild 消费面：unit_id/attrs/alive——speed_for_order
	## 未 bind 走兜底 0，条目尺寸契约与速度值无关）
	## 参数 count：单位数
	## 返回：BattleUnit 数组
	var units: Array = []
	for i: int in range(count):
		var unit := BattleUnit.new()
		unit.unit_id = StringName("probe_unit_%d" % i)
		unit.display_name = "探针%d" % i
		unit.alive = true
		units.append(unit)
	return units

func test_layout_structure_new_tree() -> void:
	## 新树结构契约（批次 B 布局重构 + 布局三改批卷轴化）：RoundLabel=
	## LeftPanel 首子、TurnOrderBar=LeftScroll 内、UnitInfoCard=LeftPanel
	## 末子；BattleLog=ExpandPanel 内（LogScroller 卷轴）、EnemyTurnHint
	## 退役；HitArea/AnchorBar/AnchorLabel 在 LogScroller 子树
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	var left_panel: Control = battle.get_node("%LeftPanel")
	var round_label: Control = battle.get_node("%RoundLabel")
	assert_str(round_label.get_parent().name).is_equal("LeftPanel")
	assert_int(round_label.get_index()).is_equal(0)
	var order_bar: Control = battle.get_node("%TurnOrderBar")
	assert_str(order_bar.get_parent().name).is_equal("LeftScroll")
	assert_str(order_bar.get_parent().get_parent().name).is_equal("LeftPanel")
	var info_card: Control = battle.get_node("%UnitInfoCard")
	assert_str(info_card.get_parent().name).is_equal("LeftPanel")
	assert_int(info_card.get_index()).is_equal(left_panel.get_child_count() - 1)
	var log_panel: Control = battle.get_node("%BattleLog")
	assert_str(log_panel.get_parent().name).is_equal("ExpandPanel")
	assert_str(log_panel.get_parent().get_parent().name).is_equal("LogScroller")
	# 卷轴子树在位：HitArea→AnchorBar→AnchorLabel 链
	var hit_area: Control = battle.get_node("%HitArea")
	assert_str(hit_area.get_parent().name).is_equal("LogScroller")
	var anchor_bar: Control = battle.get_node("%AnchorBar")
	assert_str(anchor_bar.get_parent().name).is_equal("HitArea")
	var anchor_label: Control = battle.get_node("%AnchorLabel")
	assert_str(anchor_label.get_parent().name).is_equal("AnchorBar")
	# 敌方提示行随右栏整树退役（文案并入卷轴锚点条）
	assert_object(battle.get_node_or_null("%EnemyTurnHint")).is_null()

func test_short_window_left_panel_no_overflow() -> void:
	## 720 档左栏不溢出契约（批次 B 改版）：模拟 1280×720 根尺寸 + 信息卡
	## 点亮 + 序条 7 条目 rebuild（满员口径）——左栏内容 min 总高（31+8+356+
	## 8+180 = 583）低于左栏可用高（720 − 12 顶 − 92 底 = 616），LeftScroll
	## 无需纵向滚动（v_bar max == 0）；LeftScroll 在位（结构不塌）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	battle.get_node("%UnitInfoCard").visible = true
	var order_bar: TurnOrderBar = battle.get_node("%TurnOrderBar") as TurnOrderBar
	order_bar.rebuild(_MakeUnits(7))
	battle.size = Vector2(1280.0, 720.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var left_scroll: ScrollContainer = battle.get_node("%LeftScroll") as ScrollContainer
	assert_object(left_scroll).is_not_null() \
			.override_failure_message("LeftScroll 结构塌失")
	assert_float(left_scroll.size.y).is_greater(200.0) \
			.override_failure_message("720 档 LeftScroll 高度塌缩（%s）" % left_scroll.size)
	# 溢出判据：v_bar max_value 语义 = 内容总高（Range.max）——无溢出 = 内容高
	# 不超视口高（max ≤ size.y；条目总高 332-356 < 720 档视口 ~384 恰好收纳）
	assert_float(left_scroll.get_v_scroll_bar().max_value) \
			.is_less_equal(left_scroll.size.y + 0.5) \
			.override_failure_message("720 档左栏溢出（内容高 %s > 视口高 %s）——满员序条+信息卡应恰好收纳" % [
					left_scroll.get_v_scroll_bar().max_value, left_scroll.size.y])

func test_600_height_left_scroll_and_log_and_board() -> void:
	## 600 嵌入视口监测档（低16 同款：编辑器嵌入不守最小窗——回归红灯）：
	## 1280×600 下左栏必然超高（LeftScroll 可滚 = 7 条目竖列完整可达）+
	## 棋盘正尺寸（满高布局不塌）+ 日志卷轴展开态右缘不越屏宽−12（布局三改：
	## 右栏退役、日志改卷轴浮层——展开面板右缘 = 屏宽 − 锚点边距 − 展开边距）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	battle.get_node("%UnitInfoCard").visible = true
	var order_bar: TurnOrderBar = battle.get_node("%TurnOrderBar") as TurnOrderBar
	order_bar.rebuild(_MakeUnits(7))
	battle.size = Vector2(1280.0, 600.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var left_scroll: ScrollContainer = battle.get_node("%LeftScroll") as ScrollContainer
	var left_bar: VScrollBar = left_scroll.get_v_scroll_bar()
	assert_bool(left_bar.is_visible_in_tree()).is_true() \
			.override_failure_message("600 档左栏滚动条未出现——竖列序条不可达")
	# 溢出判据（v_bar max = 内容总高）：内容高超视口高 = 纵向可滚（序条可达）
	assert_float(left_bar.max_value).is_greater(left_scroll.size.y) \
			.override_failure_message("600 档左栏不可滚动（内容高 %s ≤ 视口高 %s）" % [
					left_bar.max_value, left_scroll.size.y])
	var board: Control = battle.get_node("%BoardLayer")
	assert_float(board.size.x).is_greater(200.0)
	assert_float(board.size.y).is_greater(150.0) \
			.override_failure_message("600 档棋盘高度塌缩（%s）" % board.size)
	# 日志卷轴展开态（即时态注入）右缘不越屏宽−12——卷轴右挂锚定的矮档护栏
	var scroller: BattleLogScroller = battle.get_node("%LogScroller") as BattleLogScroller
	var cfg: CoreConfig = load("res://data/core/cfg_main.tres") as CoreConfig
	var original_seconds: float = cfg.ui_battle_log_toggle_seconds
	cfg.ui_battle_log_toggle_seconds = 0.0
	scroller.apply_cfg(cfg, null)
	scroller.set_expanded(true)
	await get_tree().process_frame
	var expand_panel: PanelContainer = battle.get_node("%ExpandPanel") as PanelContainer
	assert_float(expand_panel.get_global_rect().end.x) \
			.is_less_equal(battle.get_global_rect().end.x - 12.0 + 0.5) \
			.override_failure_message("600 档展开日志右缘 %s 越屏宽−12 %s" % [
					expand_panel.get_global_rect().end.x,
					battle.get_global_rect().end.x - 12.0])
	scroller.set_expanded(false)
	cfg.ui_battle_log_toggle_seconds = original_seconds

func test_short_window_button_row_within_screen() -> void:
	## 模拟 1280×720 根尺寸：ButtonRow 右缘不越屏右缘内边 12px（布局三改：
	## 右栏退役后遮蔽护栏改屏缘口径——五钮左下单行不越棋盘右缘锚定线）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	battle.size = Vector2(1280.0, 720.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var button_row: Control = battle.get_node("%ButtonRow")
	assert_float(button_row.get_global_rect().end.x) \
			.is_less_equal(battle.get_global_rect().end.x - 12.0 + 0.5) \
			.override_failure_message("ButtonRow 右缘 %s 越屏右缘内边 12px %s——遮蔽护栏" % [
					button_row.get_global_rect().end.x,
					battle.get_global_rect().end.x - 12.0])

func test_720_iso_board_full_band_no_overflow() -> void:
	## E1 等距 720 档适配复核（布局三改批棋盘右扩版）：10×10 图在 720 档
	## BoardLayer 剩余区（1280−240−12 = 1028 宽 × 720−84 = 636 高）——
	## fit_w = 2×1028/20 = 102.8 ≥ 下限 72 不再让位，取钳制带内值 102.8
	##（∈ [72,176] 全带达标）；断言：cell_width 达标、包围盒不溢出板面、
	## 全宽 ≥ 72 触控下限、全格中心命中恒等
	var board: BattleBoard = auto_free(BattleBoard.new())
	add_child(board)
	board.size = Vector2(1028.0, 636.0)
	var map_def: BattleMapDef = load("res://data/battle/maps/btm_m1_lair_10x10.tres") as BattleMapDef
	var tiles: Dictionary = {}
	for tile_id: StringName in [&"tile_normal", &"tile_obstacle", &"tile_grass",
			&"tile_highground", &"tile_poison_swamp", &"tile_trap"]:
		tiles[tile_id] = load("res://data/battle/tiles/" + String(tile_id) + ".tres")
	var grid := BattleGrid.new()
	assert_bool(grid.setup(map_def, func(tile_id: StringName) -> TileTypeDef:
		return tiles.get(tile_id, null) as TileTypeDef)).is_true()
	var context := BattleSetup.BattleContext.new()
	context.grid = grid
	context.units = []
	var game_data: Node = get_tree().root.get_node("GameData")
	board.setup(context, game_data)
	# 达标：fit_w = 102.8 ∈ [72,176] → cell_width = 102.8（钳制带内非让位）
	assert_float(board.cell_width).is_equal_approx(102.8, 0.01) \
			.override_failure_message("720 档 10×10 应取钳制带内 102.8（实际 %s）" % str(board.cell_width))
	assert_float(board.cell_width).is_greater_equal(72.0)
	assert_float(board.cell_width).is_less_equal(176.0)
	# 包围盒不溢出
	var span: float = 20.0
	var box: Vector2 = Vector2(span * board.cell_width * 0.5,
			span * board.cell_height * 0.5)
	assert_bool(board.origin.x >= -0.5 and board.origin.y >= -0.5).is_true()
	assert_bool(board.origin.x + box.x <= 1028.0 + 0.5
			and board.origin.y + box.y <= 636.0 + 0.5) \
			.override_failure_message("720 档达标分支包围盒溢出（origin %s + box %s）" % [
					str(board.origin), str(box)])
	# 全格中心命中恒等
	for y: int in 10:
		for x: int in 10:
			var cell: Vector2i = Vector2i(x, y)
			assert_vector(board.cell_from_local(board.cell_rect(cell).get_center())) \
					.is_equal(cell)
