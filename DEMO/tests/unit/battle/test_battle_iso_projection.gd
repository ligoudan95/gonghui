## E1 战棋等距投影单元测试（2:1 菱形网格——逻辑坐标不动、纯渲染层投影）
## 覆盖：全格中心正反投影恒等（_CellAnchor + 盒尺寸/2 == 格中心 →
## cell_from_local == 该格）/ 菱形盒四角外三角不命中本格（菱形咬合区归
## 邻格或界外——不崩不误归属）/ 共享边单格归属（round 确定性——东/南共享
## 边中点各归一侧）/ cfg 非法值回退 UiTheme 兜底（六 iso 读取口）/
## resize 前后往返一致（同 cfg 重算几何不破恒等）/ 钳制带与让位护栏
##（fit ∈ [min,max] 取 fit；fit < min 让位取 fit 保适配弃保底）/ 上限
## 钳制（大版面 fit > max 取 max）。
## 数学单源锚点 = E1 方案 §二（正投影/反投影/布局公式）。
extends GdUnitTestSuite

## GameData 脚本路径（AssetTex 纹理解析注入）
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## 真实 8×8 地图（test_battle_board_resize_debounce 同源夹具）
const MAP_PATH: String = "res://data/battle/maps/btm_m1_random_8x8.tres"
## 地格表目录
const TILE_DIR: String = "res://data/battle/tiles/"

## 套件级 GameData 实例
var _game_data: Node
## 地格定义表（id -> TileTypeDef）
var _tiles: Dictionary = {}

func before() -> void:
	## 套件前置：实例化 GameData 并加载地格表
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()
	_tiles = {}
	for tile_id: StringName in [&"tile_normal", &"tile_obstacle", &"tile_grass",
			&"tile_highground", &"tile_poison_swamp", &"tile_trap"]:
		_tiles[tile_id] = load(TILE_DIR + String(tile_id) + ".tres")

func before_test() -> void:
	## 用例前置：清纹理缓存（用例间隔离——含缺件 null 驻留）
	## 参数：无
	## 返回：无
	AssetTex.clear_cache()

func after() -> void:
	## 套件后置：清纹理缓存（防污染后续套件）
	## 参数：无
	## 返回：无
	AssetTex.clear_cache()

func _MakeBoard(board_size: Vector2, cfg: CoreConfig = null) -> BattleBoard:
	## 构建挂树装配板（真实 8×8 地图 + 空队伍；cfg 可注入——空 = 纯兜底模式）
	## 参数 board_size：板面像素尺寸；cfg：总控配置（可空）
	## 返回：已 setup 的板层实例（auto_free 释放）
	var map_def: BattleMapDef = load(MAP_PATH) as BattleMapDef
	var grid := BattleGrid.new()
	assert_bool(grid.setup(map_def, _LookupTile)).is_true()
	var context := BattleSetup.BattleContext.new()
	context.grid = grid
	context.units = []
	context.cfg = cfg
	var board: BattleBoard = auto_free(BattleBoard.new())
	add_child(board)
	board.size = board_size
	board.setup(context, _game_data)
	return board

func _LookupTile(tile_id: StringName) -> TileTypeDef:
	## 地格定义解析闭包（字典查找——test_battle_grid 同式）
	## 参数 tile_id：地格 id
	## 返回：TileTypeDef（未登记返回 null）
	return _tiles.get(tile_id, null)

func test_all_cell_centers_roundtrip_identity() -> void:
	## 正反投影恒等：全图每格中心（cell_rect 取中心——消除用例内联数学）
	## 反投影必回本格；格中心同时 == _CellAnchor + 盒尺寸/2（锚定自洽）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0))
	for y: int in 8:
		for x: int in 8:
			var cell: Vector2i = Vector2i(x, y)
			var center: Vector2 = board.cell_rect(cell).get_center()
			assert_vector(board.cell_from_local(center)).is_equal(cell) \
					.override_failure_message("格 %s 中心反投影失恒等" % str(cell))
			assert_vector(center).is_equal(board._CellAnchor(cell)
					+ board.cell_rect(cell).size * 0.5)

func test_box_corner_outer_triangles_not_own_cell() -> void:
	## 菱形盒四角外三角：盒四角点（菱形外区域）不得命中**本格**（菱形咬合
	## 区归属邻格或界外哨兵——不崩、不误归属本格即「角外三角不命中」）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0))
	for y: int in 8:
		for x: int in 8:
			var cell: Vector2i = Vector2i(x, y)
			var rect: Rect2 = board.cell_rect(cell)
			for corner: Vector2 in [rect.position, rect.position + Vector2(rect.size.x, 0.0),
					rect.position + Vector2(0.0, rect.size.y), rect.end]:
				var hit: Vector2i = board.cell_from_local(corner)
				assert_vector(hit).is_not_equal(cell) \
						.override_failure_message("格 %s 盒角 %s 命中本格（菱形外三角误归属）" % [
								str(cell), str(corner)])
				# 咬合区归属必须合法：界内格或界外哨兵（不产生越界坐标）
				if hit != Vector2i(-1, -1):
					assert_bool(hit.x >= 0 and hit.x < 8 and hit.y >= 0 and hit.y < 8) \
							.override_failure_message("盒角命中越界坐标 %s" % str(hit)).is_true()

func test_shared_edge_single_owner_deterministic() -> void:
	## 共享边单格归属：与东邻 (cx+1,cy) 共享边（本格右下边——盒 (0.75w,
	## 0.75h) 处）中点归属东邻、与南邻 (cx,cy+1) 共享边（本格左下边——盒
	## (0.25w, 0.75h) 处）中点归属南邻（round 远零侧确定性——同点重投恒同格）；
	## 三格共享顶点（盒下边中点）仲裁归东邻（双 0.5 恰界 y 回退——不误归
	## 第 4 格）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0))
	var cell: Vector2i = Vector2i(3, 3)
	var rect: Rect2 = board.cell_rect(cell)
	# 东共享边中点（连续格坐标 (cx+0.5, cy) → round 上取归东邻）
	var east_edge_mid: Vector2 = rect.position + rect.size * Vector2(0.75, 0.75)
	assert_vector(board.cell_from_local(east_edge_mid)).is_equal(Vector2i(4, 3))
	assert_vector(board.cell_from_local(east_edge_mid)).is_equal(Vector2i(4, 3)) \
			.override_failure_message("共享边重投归属漂移（不确定性）")
	# 南共享边中点（连续格坐标 (cx, cy+0.5) → round 上取归南邻）
	var south_edge_mid: Vector2 = rect.position + rect.size * Vector2(0.25, 0.75)
	assert_vector(board.cell_from_local(south_edge_mid)).is_equal(Vector2i(3, 4))
	# 三格共享顶点（本格下顶点 = 东邻/南邻菱形边端点）——仲裁归东邻
	var bottom_vertex: Vector2 = rect.position + Vector2(rect.size.x * 0.5, rect.size.y)
	assert_vector(board.cell_from_local(bottom_vertex)).is_equal(Vector2i(4, 3))

func test_iso_params_fallback_on_missing_or_invalid_cfg() -> void:
	## cfg 非法回退：六 iso 参数读取口在 cfg 未注入（null）与表值非法
	##（越界/≤ 0）时回退 UiTheme 兜底常量；合法表值注入生效——ratio/
	## min/max 锤 BattleBoard 板层口（布局消费），sprite/feet/ring 锤
	## UnitBadge 徽章口（锚定消费——两处同款读取模式）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0))
	assert_float(board._IsoRatio()).is_equal_approx(UiTheme.ISO_RATIO, 0.0001)
	assert_float(board._IsoCellWidthMin()).is_equal_approx(UiTheme.ISO_CELL_WIDTH_MIN, 0.0001)
	assert_float(board._IsoCellWidthMax()).is_equal_approx(UiTheme.ISO_CELL_WIDTH_MAX, 0.0001)
	var badge: UnitBadge = _MakeBadge()
	assert_float(badge._IsoSpriteWidthRatio()).is_equal_approx(UiTheme.ISO_SPRITE_WIDTH_RATIO, 0.0001)
	assert_float(badge._IsoFeetYRatio()).is_equal_approx(UiTheme.ISO_FEET_Y_RATIO, 0.0001)
	assert_float(badge._IsoRingRatio()).is_equal_approx(UiTheme.ISO_RING_RATIO, 0.0001)
	var cfg: CoreConfig = auto_free(CoreConfig.new())
	board.context.cfg = cfg
	badge._cfg = cfg
	assert_float(board._IsoRatio()).is_equal_approx(UiTheme.ISO_RATIO, 0.0001) \
			.override_failure_message("ratio 0（未回填）应回退兜底")
	assert_float(board._IsoCellWidthMin()).is_equal_approx(UiTheme.ISO_CELL_WIDTH_MIN, 0.0001)
	assert_float(board._IsoCellWidthMax()).is_equal_approx(UiTheme.ISO_CELL_WIDTH_MAX, 0.0001)
	assert_float(badge._IsoSpriteWidthRatio()).is_equal_approx(UiTheme.ISO_SPRITE_WIDTH_RATIO, 0.0001)
	assert_float(badge._IsoFeetYRatio()).is_equal_approx(UiTheme.ISO_FEET_Y_RATIO, 0.0001)
	assert_float(badge._IsoRingRatio()).is_equal_approx(UiTheme.ISO_RING_RATIO, 0.0001)
	cfg.ui_battle_iso_ratio = 1.5
	cfg.ui_battle_iso_cell_width_min = -10.0
	cfg.ui_battle_iso_cell_width_max = 0.0
	cfg.ui_battle_iso_sprite_width_ratio = -0.5
	cfg.ui_battle_iso_feet_y_ratio = 2.0
	cfg.ui_battle_iso_ring_ratio = 0.0
	assert_float(board._IsoRatio()).is_equal_approx(UiTheme.ISO_RATIO, 0.0001)
	assert_float(board._IsoCellWidthMin()).is_equal_approx(UiTheme.ISO_CELL_WIDTH_MIN, 0.0001)
	assert_float(board._IsoCellWidthMax()).is_equal_approx(UiTheme.ISO_CELL_WIDTH_MAX, 0.0001)
	assert_float(badge._IsoSpriteWidthRatio()).is_equal_approx(UiTheme.ISO_SPRITE_WIDTH_RATIO, 0.0001)
	assert_float(badge._IsoFeetYRatio()).is_equal_approx(UiTheme.ISO_FEET_Y_RATIO, 0.0001)
	assert_float(badge._IsoRingRatio()).is_equal_approx(UiTheme.ISO_RING_RATIO, 0.0001)
	cfg.ui_battle_iso_ratio = 0.6
	cfg.ui_battle_iso_cell_width_min = 80.0
	cfg.ui_battle_iso_cell_width_max = 200.0
	cfg.ui_battle_iso_sprite_width_ratio = 1.1
	cfg.ui_battle_iso_feet_y_ratio = 0.6
	cfg.ui_battle_iso_ring_ratio = 0.3
	assert_float(board._IsoRatio()).is_equal_approx(0.6, 0.0001)
	assert_float(board._IsoCellWidthMin()).is_equal_approx(80.0, 0.0001)
	assert_float(board._IsoCellWidthMax()).is_equal_approx(200.0, 0.0001)
	assert_float(badge._IsoSpriteWidthRatio()).is_equal_approx(1.1, 0.0001)
	assert_float(badge._IsoFeetYRatio()).is_equal_approx(0.6, 0.0001)
	assert_float(badge._IsoRingRatio()).is_equal_approx(0.3, 0.0001)

func _MakeBadge() -> UnitBadge:
	## 构建挂树空徽章（徽章侧 iso 参数读取口消费面——cfg 后注）
	## 参数：无
	## 返回：已 setup 的徽章（auto_free 释放）
	var unit := BattleUnit.new()
	unit.unit_id = &"iso_param_probe"
	unit.current_hp = 50
	unit.max_hp = 100
	var badge := UnitBadge.new()
	add_child(badge)
	auto_free(badge)
	badge.setup(unit, 72.0)
	return badge

func test_cell_height_tracks_width_by_ratio() -> void:
	## 派生几何：cell_height == cell_width × ratio（cfg 驱动即时反映——
	## 比例恒等是正反投影自洽的前提）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0))
	assert_float(board.cell_height).is_equal_approx(
			board.cell_width * UiTheme.ISO_RATIO, 0.0001)
	var cfg: CoreConfig = auto_free(CoreConfig.new())
	cfg.ui_battle_iso_ratio = 0.5
	board.context.cfg = cfg
	assert_float(board.cell_height).is_equal_approx(
			board.cell_width * 0.5, 0.0001)

func test_layout_clamp_band_and_fit_formula() -> void:
	## 布局公式：8×8 板（span=16）640×640——fit_w = 2×640/16 = 80、
	## fit_h = 2×640/(16×0.5) = 160 → min=80 ∈ [72,176] 取 80；
	## 包围盒 = span×w/2 × span×h/2 = 640×320；origin = (0, (640−320)/2 = 160)
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0))
	assert_float(board.cell_width).is_equal(80.0)
	assert_float(board.cell_height).is_equal(40.0)
	var board_box: Vector2 = Vector2(
			16.0 * board.cell_width * 0.5, 16.0 * board.cell_height * 0.5)
	assert_vector(board.origin).is_equal((Vector2(640.0, 640.0) - board_box) * 0.5)

func test_layout_max_clamp() -> void:
	## 上限钳制：超大版面 fit > max → cell_width 钳上限（cfg 驱动注 100 上限
	## 复核钳制带参数化）
	var cfg: CoreConfig = auto_free(CoreConfig.new())
	cfg.ui_battle_iso_cell_width_min = 72.0
	cfg.ui_battle_iso_cell_width_max = 100.0
	cfg.ui_battle_iso_ratio = 0.5
	var board: BattleBoard = _MakeBoard(Vector2(2000.0, 2000.0), cfg)
	# fit_w = 2×2000/16 = 250 > 100 → 钳 100
	assert_float(board.cell_width).is_equal(100.0)

func test_layout_fit_below_min_yields_to_fit() -> void:
	## 让位护栏（720 档已知妥协在案）：fit < min 时保适配弃保底——
	## cell_width = fit（非 min）；包围盒不溢出板面（origin ≥ 0 且
	## origin+box ≤ size——溢出即「保底压适配」回归）
	var board: BattleBoard = _MakeBoard(Vector2(480.0, 360.0))
	# 8×8：fit_w = 2×480/16 = 60、fit_h = 2×360/(16×0.5) = 90 → min = 60 < 72
	assert_float(board.cell_width).is_equal(60.0) \
			.override_failure_message("fit 60 < min 72 应让位取 fit（非 min 钳制）")
	var box: Vector2 = Vector2(16.0 * 60.0 * 0.5, 16.0 * 30.0 * 0.5)
	assert_vector(board.origin).is_equal((Vector2(480.0, 360.0) - box) * 0.5)
	assert_bool(board.origin.x >= 0.0 and board.origin.y >= 0.0).is_true()
	assert_bool(board.origin.x + box.x <= 480.0 + 0.5
			and board.origin.y + box.y <= 360.0 + 0.5) \
			.override_failure_message("让位分支包围盒溢出板面").is_true()
	# 全格中心恒等在让位几何下维持
	for y: int in 8:
		for x: int in 8:
			var cell: Vector2i = Vector2i(x, y)
			assert_vector(board.cell_from_local(board.cell_rect(cell).get_center())) \
					.is_equal(cell)

func test_resize_keeps_roundtrip_consistency() -> void:
	## resize 前后往返一致：同 cfg（兜底）尺寸变化 → 防抖重建后全格中心
	## 恒等维持、几何按新尺寸重算（锚定 cell_width/origin 推进）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0))
	assert_float(board.cell_width).is_equal(80.0)
	board.size = Vector2(800.0, 700.0)
	await get_tree().process_frame
	# fit_w = 2×800/16 = 100、fit_h = 2×700/8 = 175 → min = 100 ∈ 带
	assert_float(board.cell_width).is_equal(100.0)
	for y: int in 8:
		for x: int in 8:
			var cell: Vector2i = Vector2i(x, y)
			assert_vector(board.cell_from_local(board.cell_rect(cell).get_center())) \
					.is_equal(cell) \
					.override_failure_message("resize 后格 %s 往返恒等破坏" % str(cell))

func test_out_of_board_points_return_sentinel() -> void:
	## 界外哨兵：远界外点与降级守卫（context null）返回 (-1,-1)
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0))
	assert_vector(board.cell_from_local(Vector2(-500.0, -500.0))).is_equal(Vector2i(-1, -1))
	assert_vector(board.cell_from_local(Vector2(10000.0, 10000.0))).is_equal(Vector2i(-1, -1))
	var degraded: BattleBoard = auto_free(BattleBoard.new())
	add_child(degraded)
	assert_vector(degraded.cell_from_local(Vector2(100.0, 100.0))).is_equal(Vector2i(-1, -1))
