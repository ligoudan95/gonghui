## 极矮窗口契约测试（M6 批 2 挂账 4.3；批次 B 布局重构改版 2026-10-07：
## 左带（回合大字+竖排序条+信息卡）与右栏（提示行+日志）新结构下 720px
## 最小窗口完整可操作）
## 覆盖：project 最小窗口 1280×720 设置且不与双档视口冲突；新树结构契约
##（UnitInfoCard 归 LeftPanel 末子、BattleLog 归 RightLayout、EnemyTurnHint
## 首位、TurnOrderBar 在 LeftScroll 内）；720 档左栏 7 条目不溢出（LeftScroll
## 在位且无需滚动）；600 嵌入视口档 LeftScroll 纵向可滚 + 棋盘正尺寸 + 日志
## 右缘不越；ButtonRow 右缘不越 RightPanel 左缘；中4（盲审）竖滚动条占宽
## 补偿契约（强制法：临时放大 BattleLog min.y 制造右栏溢出断言补偿，用后
## 还原——右栏常态 min 428 恒低于可用高，自然溢出不再可复现）。
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
	## 新树结构契约（批次 B 布局重构）：RoundLabel=LeftPanel 首子、
	## TurnOrderBar=LeftScroll 内、UnitInfoCard=LeftPanel 末子；
	## EnemyTurnHint=RightLayout 首子、BattleLog=RightLayout 内
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
	assert_str(log_panel.get_parent().name).is_equal("RightLayout")
	var hint: Control = battle.get_node("%EnemyTurnHint")
	assert_str(hint.get_parent().name).is_equal("RightLayout")
	assert_int(hint.get_index()).is_equal(0)

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
	## 棋盘正尺寸（满高布局不塌）+ 日志右缘不越面板可视右缘（补偿覆盖矮档）
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
	var right_panel: ScrollContainer = battle.get_node("%RightPanel") as ScrollContainer
	var right_bar: VScrollBar = right_panel.get_v_scroll_bar()
	var bar_width: float = right_bar.size.x if right_bar.is_visible_in_tree() else 0.0
	var log_panel: PanelContainer = battle.get_node("%BattleLog") as PanelContainer
	assert_float(log_panel.get_global_rect().end.x) \
			.is_less_equal(right_panel.get_global_rect().end.x - bar_width + 0.5) \
			.override_failure_message("600 档日志右缘被裁（%s 越可视右缘 %s）" % [
					log_panel.get_global_rect().end.x,
					right_panel.get_global_rect().end.x - bar_width])

func test_short_window_button_row_not_overlapping_right_panel() -> void:
	## 模拟 1280×720 根尺寸：ButtonRow 右缘不越 RightPanel 左缘（五钮左下单行
	## 与右栏无水平重叠——批次 B 新版遮蔽契约，替代原「底栏不遮右栏」）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	battle.size = Vector2(1280.0, 720.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var button_row: Control = battle.get_node("%ButtonRow")
	var right_panel: Control = battle.get_node("%RightPanel")
	assert_float(button_row.get_global_rect().end.x) \
			.is_less_equal(right_panel.get_global_rect().position.x + 0.5) \
			.override_failure_message("ButtonRow 右缘 %s 越过 RightPanel 左缘 %s——水平重叠" % [
					button_row.get_global_rect().end.x,
					right_panel.get_global_rect().position.x])

func test_720_iso_board_yield_path_no_overflow() -> void:
	## E1 等距 720 档适配复核：10×10 图在 720 档 BoardLayer 剩余区
	##（1280−324−340 = 616 宽 × 720−84 = 636 高）——fit_w = 2×616/20 =
	## 61.6 < 下限 72 走让位（保适配弃保底）；断言：让位取 fit（非 72）、
	## 包围盒不溢出板面、可玩性下限（cell_width ≥ 48 触控最低限——
	## 等效方边 ≈ 43.6 的已知妥协在案，全宽仍达标）、全格中心命中恒等
	var board: BattleBoard = auto_free(BattleBoard.new())
	add_child(board)
	board.size = Vector2(616.0, 636.0)
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
	# 让位：fit_w = 61.6 < 72 → cell_width = 61.6（非 72 钳制）
	assert_float(board.cell_width).is_equal_approx(61.6, 0.01) \
			.override_failure_message("720 档 10×10 应让位取 fit 61.6（实际 %s）" % str(board.cell_width))
	# 包围盒不溢出
	var span: float = 20.0
	var box: Vector2 = Vector2(span * board.cell_width * 0.5,
			span * board.cell_height * 0.5)
	assert_bool(board.origin.x >= -0.5 and board.origin.y >= -0.5).is_true()
	assert_bool(board.origin.x + box.x <= 616.0 + 0.5
			and board.origin.y + box.y <= 636.0 + 0.5) \
			.override_failure_message("720 档让位分支包围盒溢出（origin %s + box %s）" % [
					str(board.origin), str(box)])
	# 可玩性下限：全宽 ≥ 48（触控最低限）；全格中心命中恒等
	assert_float(board.cell_width).is_greater_equal(48.0)
	for y: int in 10:
		for x: int in 10:
			var cell: Vector2i = Vector2i(x, y)
			assert_vector(board.cell_from_local(board.cell_rect(cell).get_center())) \
					.is_equal(cell)

func test_short_window_scrollbar_compensation_forced() -> void:
	## 中4（盲审）契约（批次 B 强制法版）：右栏常态内容 min（提示行隐藏 +
	## 日志 420 + 间距）恒低于可用高——竖滚动条自然溢出不再可复现，改为
	## 临时放大 BattleLog min.y（base 同步改——防补偿回调按旧 base 回写引发
	## 显隐振荡）强制溢出：①补偿生效（min 宽 + 条宽 ≤ 面板宽）；②日志右缘
	## 不越面板可视右缘（横滚禁用下越界即恒裁不可达）；用后双还原
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	battle.size = Vector2(1280.0, 720.0)
	var log_panel: PanelContainer = battle.get_node("%BattleLog") as PanelContainer
	var base: Vector2 = battle._right_log_min_base
	# 强制溢出：min.y 放大至超右栏可用高（720 − 12 顶 − 12 底 = 696），base 同步
	battle._right_log_min_base = Vector2(base.x, 900.0)
	log_panel.custom_minimum_size = Vector2(base.x, 900.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var right_panel: ScrollContainer = battle.get_node("%RightPanel") as ScrollContainer
	var bar: VScrollBar = right_panel.get_v_scroll_bar()
	assert_bool(bar.is_visible_in_tree()).is_true() \
			.override_failure_message("强制溢出下右栏竖滚动条未出现——契约前置失效")
	# ① 补偿数值契约：内容 min 宽已让出滚动条宽
	assert_float(log_panel.custom_minimum_size.x + bar.size.x) \
			.is_less_equal(right_panel.size.x + 0.5) \
			.override_failure_message("内容 min 宽 %s + 滚动条宽 %s 超面板宽 %s——补偿未生效" % [
					log_panel.custom_minimum_size.x, bar.size.x, right_panel.size.x])
	# ② 视口层契约：日志右缘不越面板可视右缘（面板右缘 − 条宽）
	assert_float(log_panel.get_global_rect().end.x) \
			.is_less_equal(right_panel.get_global_rect().end.x - bar.size.x + 0.5) \
			.override_failure_message("BattleLog 右缘 %s 越可视右缘 %s——矮窗右缘恒裁不可达" % [
					log_panel.get_global_rect().end.x,
					right_panel.get_global_rect().end.x - bar.size.x])
	# 双还原（min + base——防污染后续用例）
	battle._right_log_min_base = base
	log_panel.custom_minimum_size = base
	await get_tree().process_frame
