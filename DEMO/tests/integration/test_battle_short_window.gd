## 极矮窗口契约测试（M6 批 2 挂账 4.3；批次 B 布局重构改版 2026-10-07；
## 布局三改批 2026-10-09：右栏退役、日志卷轴化；顶部横条批 2026-10-11：
## LeftPanel 整树退役——左栏/滚动条契约随整树退役删除，改顶部横条条目
## 宽度契约）
## 覆盖：project 最小窗口 1280×720 设置且不与双档视口冲突；新树结构契约
##（RoundLabel/TurnOrderBar 归 TopBar/MarginBox/TopBarContent、UnitInfoCard
## 挂 BattleScreen 直下浮层化、LeftPanel/LeftScroll 退役、BattleLog 归
## ExpandPanel、HitArea/AnchorBar 在 LogScroller 内）；720 档横条 8 条目
## 宽度收纳（TopBarContent combined min ≤ 可用宽实测）；600 嵌入视口档
## 棋盘正尺寸 + 日志卷轴展开态右缘不越屏宽−12 + 信息卡点亮态与日志展开态
## 矩形不相交；ButtonRow 右缘不越屏右缘内边 12px（遮蔽护栏）；E1 等距
## 720 档棋盘板区扩容后（1244×568）菱形全宽 113.6 达全带 [72,176]。
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
	## 新树结构契约（顶部横条批）：RoundLabel=TopBarContent 首子、
	## TurnOrderBar=TopBarContent 次子（TopBar/MarginBox/TopBarContent 链）、
	## UnitInfoCard=BattleScreen 直下（浮层化）；BattleLog=ExpandPanel 内
	##（LogScroller 卷轴）、LeftPanel/LeftScroll/EnemyTurnHint 退役；
	## HitArea/AnchorBar/AnchorLabel 在 LogScroller 子树
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	var topbar: Control = battle.get_node("%TopBar")
	assert_object(topbar.get_parent()).is_same(battle)
	var round_label: Control = battle.get_node("%RoundLabel")
	assert_str(round_label.get_parent().name).is_equal("TopBarContent")
	assert_str(round_label.get_parent().get_parent().name).is_equal("MarginBox")
	assert_str(round_label.get_parent().get_parent().get_parent().name).is_equal("TopBar")
	assert_int(round_label.get_index()).is_equal(0)
	var order_bar: Control = battle.get_node("%TurnOrderBar")
	assert_str(order_bar.get_parent().name).is_equal("TopBarContent")
	assert_int(order_bar.get_index()).is_equal(1)
	var info_card: Control = battle.get_node("%UnitInfoCard")
	assert_object(info_card.get_parent()).is_same(battle) \
			.override_failure_message("UnitInfoCard 应挂 BattleScreen 直下（浮层化）")
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
	# 左带与敌方提示行整树退役（残留即场景未同步）
	assert_object(battle.get_node_or_null("%LeftPanel")).is_null()
	assert_object(battle.get_node_or_null("%LeftScroll")).is_null()
	assert_object(battle.get_node_or_null("%EnemyTurnHint")).is_null()

func test_720_topbar_8_entries_fit() -> void:
	## 720 档横条宽度收纳契约（顶部横条批）：模拟 1280×720 根尺寸 + 序条
	## 8 条目 rebuild（DEMO 满员口径）——TopBarContent combined min 实测
	## ≤ 可用宽（1280 − 左边距 12 − 右预留 174 = 1094）；不假设字体宽度，
	## 全实测断言（8×92 + 7×8 间距 = 792 + 回合标签 ≈ 百级仍收纳）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var order_bar: TurnOrderBar = battle.get_node("%TurnOrderBar") as TurnOrderBar
	order_bar.rebuild(_MakeUnits(8))
	battle.size = Vector2(1280.0, 720.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var content: Control = battle.get_node("TopBar/MarginBox/TopBarContent")
	var available: float = 1280.0 - UiTheme.TOPBAR_LEFT_MARGIN - UiTheme.TOPBAR_RIGHT_RESERVE
	assert_float(content.get_combined_minimum_size().x).is_less_equal(available) \
			.override_failure_message("720 档横条 8 条目 combined min %s 超可用宽 %s" % [
					content.get_combined_minimum_size().x, available])
	# 8 条目 = 常规构造（非降级）：92×44 全卡
	assert_float(order_bar.get_combined_minimum_size().x).is_greater_equal(
			8.0 * TurnOrderBar.ENTRY_WIDTH - 1.0)
	assert_int(order_bar.get_child_count()).is_equal(8)

func test_600_height_board_log_and_card() -> void:
	## 600 嵌入视口监测档（低16 同款：编辑器嵌入不守最小窗——回归红灯）：
	## 1280×600 下棋盘正尺寸（满高布局不塌）+ 日志卷轴展开态右缘不越屏宽−12
	## + 信息卡点亮态与日志展开态矩形不相交（两浮层零遮挡——顶部横条批
	## 信息卡左下浮层与右上卷轴展开的隔离断言）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	battle.get_node("%UnitInfoCard").visible = true
	battle.size = Vector2(1280.0, 600.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
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
	# 信息卡点亮态与日志展开态矩形不相交（左下浮层 vs 右上展开——两浮层隔离）
	var info_card: Control = battle.get_node("%UnitInfoCard")
	assert_bool(info_card.get_global_rect().intersects(
			expand_panel.get_global_rect())).is_false() \
			.override_failure_message("600 档信息卡 %s 与展开日志 %s 矩形相交——两浮层须隔离" % [
					info_card.get_global_rect(), expand_panel.get_global_rect()])
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
	## E1 等距 720 档适配复核（顶部横条批板区扩容版）：10×10 图在 720 档
	## BoardLayer 剩余区（1280−24−12 = 1244 宽 × 720−68−84 = 568 高）——
	## fit_w = 2×1244/20 = 124.4、fit_h = 2×568/(20×0.5) = 113.6 → 高约束
	## 取 113.6（∈ [72,176] 全带达标）；断言：cell_width 达标、包围盒不溢出
	## 板面、全宽 ≥ 72 触控下限、全格中心命中恒等
	var board: BattleBoard = auto_free(BattleBoard.new())
	add_child(board)
	board.size = Vector2(1244.0, 568.0)
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
	# 达标：fit = 113.6（高约束）∈ [72,176] → cell_width = 113.6（钳制带内非让位）
	assert_float(board.cell_width).is_equal_approx(113.6, 0.01) \
			.override_failure_message("720 档 10×10 应取高约束 113.6（实际 %s）" % str(board.cell_width))
	assert_float(board.cell_width).is_greater_equal(72.0)
	assert_float(board.cell_width).is_less_equal(176.0)
	# 包围盒不溢出
	var span: float = 20.0
	var box: Vector2 = Vector2(span * board.cell_width * 0.5,
			span * board.cell_height * 0.5)
	assert_bool(board.origin.x >= -0.5 and board.origin.y >= -0.5).is_true()
	assert_bool(board.origin.x + box.x <= 1244.0 + 0.5
			and board.origin.y + box.y <= 568.0 + 0.5) \
			.override_failure_message("720 档达标分支包围盒溢出（origin %s + box %s）" % [
					str(board.origin), str(box)])
	# 全格中心命中恒等
	for y: int in 10:
		for x: int in 10:
			var cell: Vector2i = Vector2i(x, y)
			assert_vector(board.cell_from_local(board.cell_rect(cell).get_center())) \
					.is_equal(cell)
	# 视口批顺加：720 档 zoom 档表非单档（fit 113.6 → zoom_max = 176/113.6
	## ≈ 1.55，1.1 步进多档——缩放在该档位仍有操作空间）+ WorldLayer 已随
	## 装配懒建（地格挂其下）
	assert_int(board._zoom_steps.size()).is_greater(2) \
			.override_failure_message("720 档 10×10 档表应非单档（zoom_max ≈ 1.55）")
	assert_float(board._zoom_steps[0]).is_equal(1.0)
	assert_object(board._world_layer).is_not_null()
