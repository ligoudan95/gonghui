## E1 战棋等距深度排序单元测试（手动 z_index——不用 Y-sort：BattleBoard
## 子节点异质，Y-sort 会重排覆盖层容器/tips/飘字破坏树序契约；等距深度
## = x+y 精确 O(1)，探索屏 Z_* 先例）
## 覆盖：地格 z == cell.x+cell.y / 徽章 z == grid_pos.x+grid_pos.y /
## 覆盖层容器 z == Z_OVERLAY(100) / tips·飘字 z == Z_TEXT(200) /
## move_badge 逐段跨格 z 随步更新（tween 回调与朝向同插入位）/ 瞬移一次
## 设定 / 倒地徽章 z 不变（尸态不重排）。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## 真实 8×8 地图
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
	## 用例前置：清纹理缓存（用例间隔离）
	## 参数：无
	## 返回：无
	AssetTex.clear_cache()

func after() -> void:
	## 套件后置：清纹理缓存（防污染后续套件）
	## 参数：无
	## 返回：无
	AssetTex.clear_cache()

func _MakeBoard() -> BattleBoard:
	## 构建挂树装配板（真实 8×8 地图 + 单测试单位——move_badge 消费面）
	## 参数：无
	## 返回：已 setup 的板层实例（auto_free 释放）
	var map_def: BattleMapDef = load(MAP_PATH) as BattleMapDef
	var grid := BattleGrid.new()
	assert_bool(grid.setup(map_def, _LookupTile)).is_true()
	var unit := BattleUnit.new()
	unit.unit_id = &"depth_probe"
	unit.current_hp = 50
	unit.max_hp = 50
	unit.grid_pos = Vector2i(2, 2)
	var context := BattleSetup.BattleContext.new()
	context.grid = grid
	context.units = [unit]
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

func _BadgeOf(board: BattleBoard) -> UnitBadge:
	## 板面徽章池取测试单位徽章
	## 参数 board：战斗板层
	## 返回：徽章
	return board._badges[&"depth_probe"]

func test_cell_depth_equals_x_plus_y() -> void:
	## 地格深度：全图每格视觉根 z_index == cell.x + cell.y
	##（12×12 上限 22 < Z_OVERLAY——覆盖层恒压格）
	var board: BattleBoard = _MakeBoard()
	for y: int in 8:
		for x: int in 8:
			var cell: Vector2i = Vector2i(x, y)
			assert_int(board._cells[cell].z_index).is_equal(x + y) \
					.override_failure_message("格 %s 深度 z != x+y" % str(cell))

func test_badge_depth_equals_grid_pos_sum() -> void:
	## 徽章深度：初建徽章 z == unit.grid_pos.x + y（与所在格同深——
	## 同格 tie-break 树序格→徽章天然正确）
	var board: BattleBoard = _MakeBoard()
	var badge: UnitBadge = _BadgeOf(board)
	assert_int(badge.z_index).is_equal(4)

func test_overlay_layer_and_texts_depth() -> void:
	## 覆盖层容器 z == Z_OVERLAY(100)、tips/飘字 z == Z_TEXT(200)——
	## 恒压一切格/徽章深度（≤ 22）与覆盖层；视口批：容器/tips/飘字挂
	## WorldLayer 下——查找路径与遍历随挂载点（断言语义不变）
	var board: BattleBoard = _MakeBoard()
	board.show_move_range([Vector2i(0, 0)])
	var overlay_layer: Control = board.get_node("WorldLayer/OverlayLayer") as Control
	assert_object(overlay_layer).is_not_null()
	assert_int(overlay_layer.z_index).is_equal(BattleBoard.Z_OVERLAY)
	assert_int(BattleBoard.Z_OVERLAY).is_equal(100)
	board.show_target_tips(Vector2i(3, 3), "预计伤害 5", "命中率 85%")
	assert_int(board.target_tips_panel().z_index).is_equal(BattleBoard.Z_TEXT)
	assert_int(BattleBoard.Z_TEXT).is_equal(200)
	# 飘字：伤害数字 Label z == Z_TEXT（挂 WorldLayer 下）
	board.show_damage_number(Vector2i(3, 3), 5, false)
	var damage_labels: Array = board._world_layer.get_children().filter(
			func(child: Node) -> bool:
				return child is Label and (child as Label).text == "5")
	assert_int(damage_labels.size()).is_equal(1)
	assert_int((damage_labels[0] as Label).z_index).is_equal(BattleBoard.Z_TEXT)

func test_move_badge_updates_depth_per_step() -> void:
	## move_badge 逐段跨格 z 随步更新：tween 链回调（与朝向同插入位）——
	## 链首即刻按第一目标格设深度、迈入瞬间切目标格深度、终点保持
	var board: BattleBoard = _MakeBoard()
	var unit: BattleUnit = board.context.units[0] as BattleUnit
	var badge: UnitBadge = _BadgeOf(board)
	var cfg: CoreConfig = auto_free(CoreConfig.new())
	cfg.ui_battle_move_step_seconds = 0.3
	cfg.ui_battle_move_max_steps = 6
	cfg.ui_battle_iso_ratio = 0.5
	board.context.cfg = cfg
	unit.grid_pos = Vector2i(4, 2)
	board.move_badge(unit, Vector2i(2, 2),
			[Vector2i(3, 2), Vector2i(4, 2)])
	# 链首回调随 tween 启动后首帧执行（批次 A 朝向链首同口径）：深度切
	# 第一目标格 (3,2) → z=5
	await get_tree().process_frame
	assert_int(badge.z_index).is_equal(5)
	# 第一段（0.3s）完成、迈入终点格 (4,2)：z=6
	await get_tree().create_timer(0.55).timeout
	assert_int(badge.z_index).is_equal(6)
	# 全程完成：终点深度保持
	var waited: int = 0
	while board._move_tweens.has(unit.unit_id) and waited < 300:
		await get_tree().process_frame
		waited += 1
	assert_int(badge.z_index).is_equal(6)

func test_teleport_move_sets_depth_once() -> void:
	## 瞬移分支：深度一次设定（终点格 x+y）——无逐步演出过程
	var board: BattleBoard = _MakeBoard()
	var unit: BattleUnit = board.context.units[0] as BattleUnit
	var badge: UnitBadge = _BadgeOf(board)
	var cfg: CoreConfig = auto_free(CoreConfig.new())
	cfg.ui_battle_move_step_seconds = 0.0
	cfg.ui_battle_iso_ratio = 0.5
	board.context.cfg = cfg
	unit.grid_pos = Vector2i(5, 3)
	board.move_badge(unit, Vector2i(2, 2), [Vector2i(5, 3)])
	assert_int(badge.z_index).is_equal(8)
	assert_vector(badge.position).is_equal(board.cell_rect(Vector2i(5, 3)).position)

func test_downed_badge_keeps_depth() -> void:
	## 倒地徽章 z 不变：refresh 倒地（隐藏条/环/底圈）不动深度——尸态不重排
	var board: BattleBoard = _MakeBoard()
	var unit: BattleUnit = board.context.units[0] as BattleUnit
	var badge: UnitBadge = _BadgeOf(board)
	var depth_before: int = badge.z_index
	unit.current_hp = 0
	unit.alive = false
	badge.refresh()
	assert_int(badge.z_index).is_equal(depth_before)

func test_trap_mark_depth_follows_cell() -> void:
	## 陷阱标记深度：随所在格 z = x+y（树序在徽章后——同格 tie-break 现状；
	## 视口批：标记挂 WorldLayer 下——查找遍历随挂载点）
	var board: BattleBoard = _MakeBoard()
	var trap_cell: Vector2i = (board.context.units[0] as BattleUnit).grid_pos
	board.context.grid.spawn_dynamic_tile(trap_cell, &"tile_trap", 5, &"")
	board.RefreshDynamicMarks()
	var mark: Control = null
	for child: Node in board._world_layer.get_children():
		if child is Control and child.get_meta(&"trap_mark", false):
			mark = child as Control
	assert_object(mark).is_not_null()
	assert_int(mark.z_index).is_equal(trap_cell.x + trap_cell.y)
