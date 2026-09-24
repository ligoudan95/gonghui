## BattleGrid 单元测试（M1 批 1）
## 覆盖：Dijkstra 可达集（存活单位互为障碍——敌我对称不可穿越不可停留，
## 2026-09-24 用户拍板口径/障碍阻断/定身空集）、
## 曼哈顿射程、3×3 切比雪夫光环、视线遮挡（障碍阻断/单位不阻断/相邻恒通）、
## 动态陷阱（动态优先/触发即消失）——地图与地格用 data/ 真实表。
## 8×8 图布置参照 gen_m1_battle_data：障碍 y2:(2)(7) y3:(1)(3) y4:(2)(6) y5:(1)(7)、
## 草丛 (5,2)(3,4)(5,4)、高地 (5,3)(2,5)、毒沼 (4,5)。
extends GdUnitTestSuite

## 真实数据路径
const MAP_PATH: String = "res://data/battle/maps/btm_m1_random_8x8.tres"
const TILE_DIR: String = "res://data/battle/tiles/"

## 套件级组件
var _grid: BattleGrid
var _tiles: Dictionary = {}

## 测试替身单位（鸭子契约：side/alive/grid_pos）
class FakeUnit:
	extends RefCounted
	var id: StringName = &"unit"
	var side: int = 0
	var alive: bool = true
	var grid_pos: Vector2i = Vector2i.ZERO

func before() -> void:
	## 套件前置：加载 6 张地格表与 8×8 地图（before 为套件级钩子，重资源只载一次）
	## 参数：无
	## 返回：无
	_tiles = {}
	for tile_id: StringName in [&"tile_normal", &"tile_obstacle", &"tile_grass",
			&"tile_highground", &"tile_poison_swamp", &"tile_trap"]:
		_tiles[tile_id] = load(TILE_DIR + String(tile_id) + ".tres")

func before_test() -> void:
	## 用例前置：重建战场（单格/占位/动态地格为可变状态，逐用例隔离——
	## gdUnit before() 系套件级钩子，用例级须用 before_test）
	## 参数：无
	## 返回：无
	var map_def: BattleMapDef = load(MAP_PATH) as BattleMapDef
	_grid = BattleGrid.new()
	var ok: bool = _grid.setup(map_def, _LookupTile)
	assert_bool(ok).is_true()

func _LookupTile(tile_id: StringName) -> TileTypeDef:
	## 地格定义解析闭包（字典查找）
	## 参数 tile_id：地格 id
	## 返回：TileTypeDef（未登记返回 null）
	return _tiles.get(tile_id, null)

func _MakeUnit(side_value: int, pos: Vector2i) -> FakeUnit:
	## 构建并放置一个单位
	## 参数 side_value：阵营；pos：所在格
	## 返回：已放置的单位
	var unit := FakeUnit.new()
	unit.side = side_value
	unit.grid_pos = pos
	_grid.place_unit(pos, unit)
	return unit

func test_setup_resolves_layout() -> void:
	## 布局解析：障碍/草丛/高地/毒沼各就各位（动态优先未启用时取基础层）
	assert_int(_grid.size.x).is_equal(8)
	assert_int(_grid.size.y).is_equal(8)
	assert_str(String(_grid.tile_id_at(Vector2i(2, 2)))).is_equal("tile_obstacle")
	assert_str(String(_grid.tile_id_at(Vector2i(5, 2)))).is_equal("tile_grass")
	assert_str(String(_grid.tile_id_at(Vector2i(5, 3)))).is_equal("tile_highground")
	assert_str(String(_grid.tile_id_at(Vector2i(4, 5)))).is_equal("tile_poison_swamp")
	assert_str(String(_grid.tile_id_at(Vector2i(0, 0)))).is_equal("tile_normal")
	assert_str(String(_grid.tile_id_at(Vector2i(8, 0)))).is_empty()

func test_dijkstra_reachable_respects_move_budget() -> void:
	## 基本可达：(3,6) 移动 2 → (3,4)（经 (3,5)）；障碍格 (2,4) 永不可达；起始格不在结果
	var unit := _MakeUnit(0, Vector2i(3, 6))
	var reachable: Array[Vector2i] = _grid.find_reachable(unit, 2)
	assert_bool(reachable.has(Vector2i(3, 4))).is_true()
	assert_bool(reachable.has(Vector2i(3, 5))).is_true()
	assert_bool(reachable.has(Vector2i(3, 6))).is_false()
	assert_bool(reachable.has(Vector2i(2, 4))).is_false()

func test_dijkstra_enemy_blocks() -> void:
	## 敌方占据阻断：(3,5) 放敌方 → 移动 2 内 (3,4) 不可达（绕行需 4 步）、(3,5) 不可入
	var unit := _MakeUnit(0, Vector2i(3, 6))
	_MakeUnit(1, Vector2i(3, 5))
	var reachable: Array[Vector2i] = _grid.find_reachable(unit, 2)
	assert_bool(reachable.has(Vector2i(3, 4))).is_false()
	assert_bool(reachable.has(Vector2i(3, 5))).is_false()

func test_dijkstra_ally_blocks_symmetric() -> void:
	## 友方占位同样阻断（2026-09-24 用户拍板：存活单位互为障碍——敌我对称）：
	## (3,5) 放友方 → 移动 2 内 (3,4) 不可达（绕行需 4 步）、(3,5) 不可入不可停
	var unit := _MakeUnit(0, Vector2i(3, 6))
	_MakeUnit(0, Vector2i(3, 5))
	var reachable: Array[Vector2i] = _grid.find_reachable(unit, 2)
	assert_bool(reachable.has(Vector2i(3, 4))).is_false()
	assert_bool(reachable.has(Vector2i(3, 5))).is_false()
	# 敌方视角被友方挡同样成立（对称性）：敌方 (3,4) 移动 2 内不可入 (3,5)、
	# 不可穿达 (3,6)
	var enemy := _MakeUnit(1, Vector2i(3, 4))
	var enemy_reachable: Array[Vector2i] = _grid.find_reachable(enemy, 2)
	assert_bool(enemy_reachable.has(Vector2i(3, 5))).is_false()
	assert_bool(enemy_reachable.has(Vector2i(3, 6))).is_false()

func test_dijkstra_rooted_returns_empty() -> void:
	## 定身（move_final ≤ 0）：可达集为空
	var unit := _MakeUnit(0, Vector2i(3, 6))
	assert_int(_grid.find_reachable(unit, 0).size()).is_equal(0)
	assert_int(_grid.find_reachable(unit, -2).size()).is_equal(0)

func test_find_path_reconstructs() -> void:
	## 单目标寻路：(3,6) → (3,4) 移动 2：路径 = [(3,5),(3,4)]（不含起点、含终点）；
	## 不可达（移动不足）返回空
	var unit := _MakeUnit(0, Vector2i(3, 6))
	var path: Array[Vector2i] = _grid.find_path(unit, Vector2i(3, 6), Vector2i(3, 4), 2)
	assert_int(path.size()).is_equal(2)
	assert_int(path[0].x).is_equal(3)
	assert_int(path[0].y).is_equal(5)
	assert_int(path[1].x).is_equal(3)
	assert_int(path[1].y).is_equal(4)
	assert_int(_grid.find_path(unit, Vector2i(3, 6), Vector2i(3, 2), 2).size()).is_equal(0)

func test_cells_in_range_manhattan() -> void:
	## 曼哈顿射程：(3,3) 距离 2 → 含 (1,3)(5,3)(3,1)(3,5) 与中心；不含 (1,2)（欧氏近但曼哈顿 3）
	var cells: Array[Vector2i] = _grid.cells_in_range(Vector2i(3, 3), 2)
	assert_bool(cells.has(Vector2i(3, 3))).is_true()
	assert_bool(cells.has(Vector2i(1, 3))).is_true()
	assert_bool(cells.has(Vector2i(5, 3))).is_true()
	assert_bool(cells.has(Vector2i(3, 1))).is_true()
	assert_bool(cells.has(Vector2i(3, 5))).is_true()
	assert_bool(cells.has(Vector2i(1, 2))).is_false()
	assert_bool(cells.has(Vector2i(5, 5))).is_false()

func test_cells_aura_3x3_chebyshev() -> void:
	## 3×3 切比雪夫光环：角点 (0,0) 界内裁剪为 4 格；中心 (3,3) 满 9 格
	var corner: Array[Vector2i] = _grid.cells_aura_3x3(Vector2i(0, 0))
	assert_int(corner.size()).is_equal(4)
	assert_bool(corner.has(Vector2i(0, 0))).is_true()
	assert_bool(corner.has(Vector2i(1, 1))).is_true()
	assert_bool(corner.has(Vector2i(2, 1))).is_false()
	assert_int(_grid.cells_aura_3x3(Vector2i(3, 3)).size()).is_equal(9)

func test_line_of_sight_blocked_by_obstacle() -> void:
	## 视线：同行 (0,2)→(7,2) 中间 (2,2) 障碍 → 阻断；(0,6)→(7,6) 全通行 → 通畅；
	## 相邻恒通（近战免视线口径的几何基础）
	assert_bool(_grid.has_line_of_sight(Vector2i(0, 2), Vector2i(7, 2))).is_false()
	assert_bool(_grid.has_line_of_sight(Vector2i(0, 6), Vector2i(7, 6))).is_true()
	assert_bool(_grid.has_line_of_sight(Vector2i(0, 0), Vector2i(1, 0))).is_true()

func test_line_of_sight_units_do_not_block() -> void:
	## 单位不阻断视线：(0,6)→(7,6) 中间放单位仍通畅
	_MakeUnit(1, Vector2i(3, 6))
	assert_bool(_grid.has_line_of_sight(Vector2i(0, 6), Vector2i(7, 6))).is_true()

func test_dynamic_trap_priority_and_consume() -> void:
	## 动态陷阱：生成后动态层优先（tile_at 取 trap 定义）；触发即消失
	## （consume 返回数据并清除、tile_id_at 回落基础层）
	_grid.spawn_dynamic_tile(Vector2i(1, 1), &"tile_trap", 16, &"r1")
	var trap_tile: TileTypeDef = _grid.tile_at(Vector2i(1, 1))
	assert_object(trap_tile).is_not_null()
	assert_str(String(trap_tile.id)).is_equal("tile_trap")
	assert_bool(trap_tile.trigger == TileTypeDef.Trigger.ENEMY_ENTER_ONCE).is_true()
	var data: Dictionary = _grid.consume_dynamic_tile(Vector2i(1, 1))
	assert_int(data[&"damage"]).is_equal(16)
	assert_str(String(data[&"source_id"])).is_equal("r1")
	assert_str(String(_grid.tile_id_at(Vector2i(1, 1)))).is_equal("tile_normal")
	assert_int(_grid.consume_dynamic_tile(Vector2i(1, 1)).size()).is_equal(0)

func test_manhattan_static_single_source() -> void:
	## 曼哈顿静态单源（批 4 C 组 M3）：原 4 份复刻（grid/controller/AI/executor
	## 内联）收敛后的统一口径——同点 0 / 轴对齐 / 对角 / 负象限
	assert_int(BattleGrid.manhattan(Vector2i(3, 4), Vector2i(3, 4))).is_equal(0)
	assert_int(BattleGrid.manhattan(Vector2i(3, 4), Vector2i(7, 4))).is_equal(4)
	assert_int(BattleGrid.manhattan(Vector2i(0, 0), Vector2i(3, 5))).is_equal(8)
	assert_int(BattleGrid.manhattan(Vector2i(5, 2), Vector2i(1, 0))).is_equal(6)

func test_legend_missing_dot_reports_issue() -> void:
	## legend 缺 '.' 图例项（A-7）：setup 记 setup_issue 不再静默回退
	## tile_normal——破损显式可见（返回 false）
	var map_def := BattleMapDef.new()
	map_def.id = &"btm_test_no_dot"
	map_def.size = Vector2i(2, 1)
	map_def.rows = ["AB"]
	map_def.legend = {"A": &"tile_normal", "B": &"tile_obstacle"}
	var grid := BattleGrid.new()
	var ok: bool = grid.setup(map_def, func(tile_id: StringName) -> Resource:
		return _tiles.get(tile_id, null))
	assert_bool(ok).is_false()
	assert_int(grid.setup_issues.size()).is_greater(0)
	var has_dot_issue: bool = false
	for issue: String in grid.setup_issues:
		if issue.contains("'.'" ):
			has_dot_issue = true
	assert_bool(has_dot_issue).override_failure_message("缺 '.' 图例未报 setup_issue").is_true()
