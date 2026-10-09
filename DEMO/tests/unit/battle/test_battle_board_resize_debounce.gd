## BattleBoard resized 防抖一帧合并单元测试（拍板 A——循环盲审暂存项实施）
## 覆盖：同帧连发多次 resized（尺寸连变 + 挂起期直调 _OnResized）帧末只
## 全量重建一次（脏标记 + call_deferred 去重——新增子节点恰一组、旧组恰
## 一批排队释放、几何以最终尺寸执行）、跨帧两次 resized 各自重建（待执行
## 标记置回——防抖只合并同帧，不吞后续帧的真实几何变化）。
## 板面真实 8×8 地图 + 空队伍上下文（子节点计数纯格池，无徽章/覆盖层噪声）；
## 重建发起帧旧视觉立即隐藏口径见集成测 test_battle_ui_flow（S4-R3-01）。
extends GdUnitTestSuite

## GameData 脚本路径（AssetTex 纹理解析注入）
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## 8×8 真实地图（与 test_battle_grid 同源）
const MAP_PATH: String = "res://data/battle/maps/btm_m1_random_8x8.tres"
## 地格表目录
const TILE_DIR: String = "res://data/battle/tiles/"
## 8×8 全场地格数（空队伍板面一次重建的新增子节点基数）
const CELL_COUNT: int = 64

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

func _MakeBoard() -> BattleBoard:
	## 构建挂树装配板（真实 8×8 地图 + 空队伍上下文——挂树后 resized 信号
	## 才在 _ready 接线；空队伍无徽章/覆盖层，子节点计数纯格池）
	## 参数：无
	## 返回：已 setup 的板层实例（auto_free 释放）
	var map_def: BattleMapDef = load(MAP_PATH) as BattleMapDef
	var grid := BattleGrid.new()
	assert_bool(grid.setup(map_def, _LookupTile)).is_true()
	var context := BattleSetup.BattleContext.new()
	context.grid = grid
	context.units = []
	var board: BattleBoard = auto_free(BattleBoard.new())
	add_child(board)
	board.size = Vector2(640.0, 640.0)
	board.setup(context, _game_data)
	return board

func _LookupTile(tile_id: StringName) -> TileTypeDef:
	## 地格定义解析闭包（字典查找——test_battle_grid 同式）
	## 参数 tile_id：地格 id
	## 返回：TileTypeDef（未登记返回 null）
	return _tiles.get(tile_id, null)

func test_same_frame_multi_resized_rebuilds_once() -> void:
	## 拍板 A 防抖：同帧连变两次尺寸（resized 同步连发）+ 挂起期直调
	## _OnResized——帧末恰重建一次（新增恰一组格池、旧组恰一批排队、
	## 几何以最终尺寸执行、标记置回）
	var board: BattleBoard = _MakeBoard()
	assert_int(board.get_child_count()).is_equal(CELL_COUNT)
	assert_bool(board._resize_rebuild_queued) \
			.override_failure_message("稳态下不得残留待执行标记").is_false()
	var old_children: Array[Node] = []
	for child: Node in board.get_children():
		old_children.append(child)
	var added: Array[Node] = []
	board.child_entered_tree.connect(
		func(node: Node) -> void: added.append(node))
	# 同帧连变两次尺寸（窗口拖动期 resized 每帧多发的模拟）
	board.size = Vector2(300.0, 300.0)
	board.size = Vector2(480.0, 360.0)
	# 挂起标记期内直调不重复排队（重复 call_deferred 去重探针）
	board._OnResized()
	assert_bool(board._resize_rebuild_queued).is_true()
	# 发起帧：重建尚未执行（帧末合并）——旧视觉未排队释放、无新增
	for old_child: Node in old_children:
		assert_bool(old_child.is_queued_for_deletion()) \
				.override_failure_message("防抖挂起帧不得提前重建").is_false()
	assert_int(added.size()).is_equal(0)
	await get_tree().process_frame
	# 帧末恰重建一次：新增恰一组（防抖失效=两次重建两组 128）
	assert_int(added.size()).override_failure_message(
			"同帧多次 resized 应合并为一次重建（新增恰一组格池）") \
			.is_equal(CELL_COUNT)
	# 存活子节点恰新一组（旧组已随帧末 queue_free 释放出树——两次重建则
	## 中间组同样入 added 被计数，零重建则 added 为空）
	assert_int(board.get_child_count()).override_failure_message(
			"重建后板面应恰余新一组格池").is_equal(CELL_COUNT)
	for node: Node in added:
		assert_bool(node.is_queued_for_deletion()).is_false()
	# 旧组已实际释放（帧末重建的 queue_free 已执行出树——不再驻留占位）
	for old_child: Node in old_children:
		assert_bool(is_instance_valid(old_child)) \
				.override_failure_message("旧视觉应在帧末重建后释放出树").is_false()
	assert_int(board._cells.size()).is_equal(CELL_COUNT)
	# 几何以最终尺寸（480×360）执行（E1 等距：span=16、fit_w = 2×480/16 = 60、
	# fit_h = 2×360/(16×0.5) = 90 → min=60 < 下限 72 让位取 60；包围盒
	# 480×240 居中 → origin = (0, 60)）
	assert_float(board.cell_width).is_equal(60.0)
	assert_vector(board.origin).is_equal(Vector2(0.0, 60.0))
	# 待执行标记置回（后续 resized 不被吞）
	assert_bool(board._resize_rebuild_queued).is_false()

func test_resized_across_frames_rebuilds_each_time() -> void:
	## 待执行标记置回契约：跨帧两次 resized 各自重建（防抖只合并同帧——
	## 第二帧几何变化必须生效，锚定 cell_size/origin 逐帧推进）
	var board: BattleBoard = _MakeBoard()
	# 第一帧：(300,300)——E1 等距：fit_w = 37.5 < 下限 72 让位取 37.5、
	# 包围盒 300×150 居中 origin = (0, 75)（旧方形 40 钳制口径已废）
	board.size = Vector2(300.0, 300.0)
	await get_tree().process_frame
	assert_float(board.cell_width).is_equal(37.5)
	assert_vector(board.origin).is_equal(Vector2(0.0, 75.0))
	# 第二帧：(500,500)——fit_w = 62.5 让位取 62.5、包围盒 500×250 origin = (0, 125)
	#（标记已置回才可能）
	board.size = Vector2(500.0, 500.0)
	await get_tree().process_frame
	assert_float(board.cell_width).is_equal(62.5)
	assert_vector(board.origin).is_equal(Vector2(0.0, 125.0))
	assert_int(board._cells.size()).is_equal(CELL_COUNT)
