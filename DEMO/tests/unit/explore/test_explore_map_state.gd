## 探索地图运行态单元测试（M3 批 1）
## 覆盖：setup 预校验（尺寸/legend '.'）/ 寻路绕障（BFS 最短路）/ 不可达空数组 /
## 暗门揭示后通行改变（reveal_secret 覆写生效）/ 同格路径 / 越界拒绝。
extends GdUnitTestSuite

## 测试地格 id
const FLOOR: StringName = &"etile_floor"
const WALL: StringName = &"etile_wall"

func _TileLookup() -> Callable:
	## 地格解析闭包（两格测试表：floor 可行 / wall 障碍）
	## 参数：无
	## 返回：Callable
	var floor := ExploreTileDef.new()
	floor.id = FLOOR
	floor.walkable = true
	var wall := ExploreTileDef.new()
	wall.id = WALL
	wall.walkable = false
	var table: Dictionary = {FLOOR: floor, WALL: wall}
	return func(tile_id: StringName) -> ExploreTileDef: return table.get(tile_id, null)

func _MakeMap(rows: Array[String]) -> ExploreMapDef:
	## 构建测试图定义（legend 固定 '.'/'X' 两键）
	## 参数 rows：布局行
	## 返回：ExploreMapDef
	var map_def := ExploreMapDef.new()
	map_def.id = &"map_test"
	map_def.size = Vector2i(rows[0].length(), rows.size())
	map_def.rows = rows
	var legend: Dictionary[StringName, StringName] = {&".": FLOOR, &"X": WALL}
	map_def.legend = legend
	return map_def

func test_setup_validates_dimensions() -> void:
	## 预校验：行数 != size.y / 行长不一致 / legend 缺 '.' 均拒绝（返 false）
	var state := ExploreMapState.new()
	var bad_rows: Array[String] = ["...", ".."]
	var bad_map := _MakeMap(bad_rows)
	bad_map.size = Vector2i(3, 3)
	assert_bool(state.setup(bad_map, _TileLookup())).is_false()
	assert_bool(state.is_valid()).is_false()
	# legend 缺 '.'
	var no_dot := _MakeMap(["..."])
	var no_dot_legend: Dictionary[StringName, StringName] = {&"X": WALL}
	no_dot.legend = no_dot_legend
	assert_bool(state.setup(no_dot, _TileLookup())).is_false()
	# 合法图通过
	assert_bool(state.setup(_MakeMap(["..."]), _TileLookup())).is_true()

func test_find_path_detours_wall() -> void:
	## 寻路绕障：中列墙 (x=2, y=0..1)——(0,0)→(4,0) 经底行绕行（最短 8 步 9 格）
	var rows: Array[String] = ["..X..", "..X..", "....."]
	var state := ExploreMapState.new()
	state.setup(_MakeMap(rows), _TileLookup())
	var path: Array[Vector2i] = state.find_path(Vector2i(0, 0), Vector2i(4, 0))
	assert_int(path.size()).is_equal(9)
	assert_bool(path[0] == Vector2i(0, 0)).is_true()
	assert_bool(path[path.size() - 1] == Vector2i(4, 0)).is_true()
	for cell: Vector2i in path:
		assert_bool(state.walkable(cell)).is_true()

func test_find_path_unreachable_returns_empty() -> void:
	## 不可达：整行墙隔断 → 空数组；目标为障碍格 → 空数组
	var rows: Array[String] = ["...", "XXX", "..."]
	var state := ExploreMapState.new()
	state.setup(_MakeMap(rows), _TileLookup())
	assert_int(state.find_path(Vector2i(0, 0), Vector2i(0, 2)).size()).is_equal(0)
	assert_int(state.find_path(Vector2i(0, 0), Vector2i(1, 1)).size()).is_equal(0)
	# 越界目标拒绝
	assert_int(state.find_path(Vector2i(0, 0), Vector2i(9, 9)).size()).is_equal(0)

func test_find_path_same_cell() -> void:
	## 同格路径：from == to 返回单格序列
	var state := ExploreMapState.new()
	state.setup(_MakeMap(["..."]), _TileLookup())
	var path: Array[Vector2i] = state.find_path(Vector2i(1, 0), Vector2i(1, 0))
	assert_int(path.size()).is_equal(1)
	assert_bool(path[0] == Vector2i(1, 0)).is_true()

func test_reveal_secret_changes_walkability() -> void:
	## 暗门揭示：墙格揭示为捷径地格后可通行 + 原隔断路径打通
	var rows: Array[String] = ["...", "XXX", "..."]
	var state := ExploreMapState.new()
	state.setup(_MakeMap(rows), _TileLookup())
	assert_bool(state.walkable(Vector2i(1, 1))).is_false()
	# 揭示前隔断
	assert_int(state.find_path(Vector2i(0, 0), Vector2i(2, 2)).size()).is_equal(0)
	state.reveal_secret([Vector2i(1, 1)], FLOOR)
	assert_bool(state.walkable(Vector2i(1, 1))).is_true()
	# 揭示后打通：直线 5 格
	var path: Array[Vector2i] = state.find_path(Vector2i(0, 0), Vector2i(2, 2))
	assert_int(path.size()).is_equal(5)
	# 揭示格地格覆写生效（tile_at 返回揭示地格 id）
	assert_str(String(state.tile_at(Vector2i(1, 1)).id)).is_equal(String(FLOOR))

func test_tile_at_out_of_bounds_null() -> void:
	## 越界/未装配安全降级：tile_at 返 null / walkable 返 false
	var state := ExploreMapState.new()
	state.setup(_MakeMap(["..."]), _TileLookup())
	assert_object(state.tile_at(Vector2i(5, 5))).is_null()
	assert_bool(state.walkable(Vector2i(-1, 0))).is_false()
	var bare := ExploreMapState.new()
	assert_object(bare.tile_at(Vector2i(0, 0))).is_null()

func test_region_index_by_lit_rows() -> void:
	## 区域下标惯例：全亮行段 = region_ids[0]（村子）/ 其余 = [1]（矿洞）
	var map_def := _MakeMap(["...", "...", "..."])
	map_def.fog_lit_rows = [0]
	map_def.region_ids = [&"reg_village", &"reg_mine"]
	var state := ExploreMapState.new()
	state.setup(map_def, _TileLookup())
	assert_int(state.region_index_of(Vector2i(1, 0))).is_equal(0)
	assert_int(state.region_index_of(Vector2i(1, 1))).is_equal(1)
	assert_int(state.region_index_of(Vector2i(1, 2))).is_equal(1)
