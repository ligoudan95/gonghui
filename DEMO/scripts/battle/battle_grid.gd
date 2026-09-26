## 战场格子（BattleGrid，RefCounted 纯逻辑类）
## 职责：承载战场格子数据（基础地格阵列 + 动态地格 + 单位占位索引），
## 提供寻路（Dijkstra）、射程（曼哈顿度量）、光环（3×3 切比雪夫）、
## 视线（Bresenham，障碍阻断/单位不阻断）与动态地格生命周期。
## 数据来源：案 9《战棋战斗》；案 21《战棋专项案》（曼哈顿度量知情确认：
## 射程/移动 = 曼哈顿距离，3×3 怒吼 = 切比雪夫 ≤1）；BattleMapDef/TileTypeDef。
## 纯逻辑约束：不触任何 autoload——地图经 BattleMapDef 参数注入、
## 地格定义经 tile_lookup 回调注入（批 2 接 GameData，测试接字典闭包）。
## 单位鸭子契约（不依赖 BattleUnit 类定义，批 2 实现同契约）：
## - side: int（0 = 我方 ALLY / 1 = 敌方 ENEMY，与 SkillDef.SkillSide 对齐）
## - alive: bool（倒地单位不阻挡、不可停留判定按存活计——2026-09-24 用户拍板：
##   存活单位一律互为障碍，占位判定不再区分敌我）
## - grid_pos: Vector2i（所在格）
class_name BattleGrid
extends RefCounted

## 曼哈顿距离（静态单源——批 4 C 组 M3：射程/移动度量，原 battle_grid/
## battle_controller/enemy_ai 三份私有实现 + skill_executor 内联式共 4 份
## 收敛于此）
static func manhattan(a: Vector2i, b: Vector2i) -> int:
	## 参数 a/b：两坐标
	## 返回：|dx| + |dy|
	return absi(a.x - b.x) + absi(a.y - b.y)

## 地图尺寸（格；x = 列数 / y = 行数）
var size: Vector2i = Vector2i.ZERO
## 基础地格 id 阵列（展平行主序：index = y × size.x + x；setup 解析 BattleMapDef.rows）
var base_tiles: Array[StringName] = []
## 动态地格索引：pos -> {tile_id: StringName, damage: int, source_id: StringName}
## （陷阱：tile id + 预结算伤害 + 施放者；tile_at 动态优先于基础）
var dynamic_tiles: Dictionary[Vector2i, Dictionary] = {}
## 单位占位索引：pos -> 单位（鸭子契约对象；place_unit/remove_unit 维护）
var unit_at: Dictionary[Vector2i, Object] = {}
## setup 解析问题记录（非法字符/行列数不符；push_error 同步输出，测试断言消费）
var setup_issues: Array[String] = []

## 地格定义解析回调（StringName tile id -> TileTypeDef；setup 注入，null = 未知 id）
var _tile_lookup: Callable = Callable()

func setup(map_def: BattleMapDef, tile_lookup: Callable) -> bool:
	## 按 BattleMapDef 解析战场：rows 逐字符经 legend 映射为地格 id，建展平阵列；
	## 非法字符（不在 legend）push_error 记 setup_issues 并回退 '.' 图例项
	## 参数 map_def：战场地图定义；tile_lookup：地格 id -> TileTypeDef 回调
	## 返回：true = 解析零问题
	_tile_lookup = tile_lookup
	size = map_def.size
	base_tiles = []
	setup_issues = []
	dynamic_tiles = {}
	unit_at = {}
	if map_def.rows.size() != map_def.size.y:
		push_error("BattleGrid: rows 行数 %d != size.y %d（%s）" % [
			map_def.rows.size(), map_def.size.y, map_def.id,
		])
		setup_issues.append("rows 行数 %d != size.y %d" % [map_def.rows.size(), map_def.size.y])
	# '.' 图例兜底（A-7：legend 缺 '.' 不再静默回退 tile_normal——记 setup_issue，
	# 回退空 id 走不可通行/渲染兜底色块，破损显式可见）
	var fallback: StringName = map_def.legend.get(".", &"")
	if String(fallback).is_empty():
		push_error("BattleGrid: legend 缺 '.' 图例项（%s）——空格无地格定义" % map_def.id)
		setup_issues.append("legend 缺 '.' 图例项（空格地格未定义）")
	# W1-6：行长 == size.x 校验入 setup_issues（与 V-M1-map-layout 同口径——
	# 此前仅数据侧拦截，运行时行长错位静默错读展平行列）
	for row_index: int in map_def.rows.size():
		if map_def.rows[row_index].length() != map_def.size.x:
			push_error("BattleGrid: 第 %d 行行长 %d != size.x %d（%s）" % [
				row_index, map_def.rows[row_index].length(), map_def.size.x, map_def.id,
			])
			setup_issues.append("第 %d 行行长 %d != size.x %d" % [
				row_index, map_def.rows[row_index].length(), map_def.size.x,
			])
	for row: String in map_def.rows:
		for row_char: String in row:
			var tile_id: StringName = map_def.legend.get(row_char, &"")
			if String(tile_id).is_empty():
				push_error("BattleGrid: 非法布局字符 '%s'（%s，按空格处理）" % [row_char, map_def.id])
				setup_issues.append("非法布局字符 '%s'" % row_char)
				tile_id = fallback
			base_tiles.append(tile_id)
	return setup_issues.is_empty()

func tile_id_at(pos: Vector2i) -> StringName:
	## 取格子的地格 id（动态地格优先于基础地格）
	## 参数 pos：格子坐标
	## 返回：地格 id；越界或未初始化返回空 StringName
	if dynamic_tiles.has(pos):
		return dynamic_tiles[pos].get(&"tile_id", &"")
	if not _InBounds(pos):
		return &""
	var index: int = pos.y * size.x + pos.x
	if index < 0 or index >= base_tiles.size():
		return &""
	return base_tiles[index]

func tile_at(pos: Vector2i) -> TileTypeDef:
	## 取格子的地格定义（动态优先；经 _tile_lookup 解析）
	## 参数 pos：格子坐标
	## 返回：TileTypeDef；越界或未知 id 返回 null
	var tile_id: StringName = tile_id_at(pos)
	if String(tile_id).is_empty():
		return null
	return _tile_lookup.call(tile_id) as TileTypeDef

func dynamic_tile_at(pos: Vector2i) -> Dictionary:
	## 取动态地格数据（陷阱：tile id + 预结算伤害 + 施放者）
	## 参数 pos：格子坐标
	## 返回：动态地格字典；无动态地格返回空字典
	return dynamic_tiles.get(pos, {})

func get_unit_at(pos: Vector2i) -> Object:
	## 取格子上的单位
	## 参数 pos：格子坐标
	## 返回：单位（鸭子契约对象）；空格返回 null
	return unit_at.get(pos, null)

func place_unit(pos: Vector2i, unit: Object) -> void:
	## 放置单位到格子（占位索引写入；调用方保证 unit.grid_pos 同步）
	## 参数 pos：格子坐标；unit：单位
	## 返回：无
	unit_at[pos] = unit

func remove_unit(pos: Vector2i) -> void:
	## 移除格子上的单位（占位索引清除；倒地/撤离时调用）
	## 参数 pos：格子坐标
	## 返回：无
	unit_at.erase(pos)

func find_reachable(unit: Object, move_final: int) -> Array[Vector2i]:
	## Dijkstra 可达集：障碍与存活单位占据格不可进（2026-09-24 用户拍板：
	## 存活单位一律互为障碍，敌我对称——不可穿越且不可停留）、
	## 定身（move_final ≤ 0）返回空；结果不含起始格、不含任何存活单位占据格
	## 参数 unit：移动单位（鸭子契约）；move_final：移动力终值（批 2 预算后传入）
	## 返回：可达目的地列表（按 y/x 排序，确定性输出）
	if move_final <= 0:
		return []
	var dist: Dictionary = {unit.grid_pos: 0}
	var visited: Dictionary = {}
	while true:
		var current: Vector2i = Vector2i.ZERO
		var current_cost: int = move_final + 1
		var found: bool = false
		for pos: Vector2i in dist:
			if visited.has(pos):
				continue
			if not found or dist[pos] < current_cost:
				current = pos
				current_cost = dist[pos]
				found = true
		if not found:
			break
		visited[current] = true
		for neighbor: Vector2i in _Neighbors4(current):
			if not _IsEnterable(neighbor):
				continue
			var tile: TileTypeDef = tile_at(neighbor)
			var new_cost: int = current_cost + maxi(1, tile.move_cost)
			if new_cost > move_final:
				continue
			if not dist.has(neighbor) or new_cost < dist[neighbor]:
				dist[neighbor] = new_cost
	var result: Array[Vector2i] = []
	for pos: Vector2i in dist:
		if pos == unit.grid_pos:
			continue
		# 兜底过滤：结果不含任何存活单位占据格（主口径在 _IsEnterable 已阻断，
		# 此处防御占位索引与占位状态不一致的边界情形）
		var occupant: Object = unit_at.get(pos, null)
		if occupant != null and occupant.alive:
			continue
		result.append(pos)
	result.sort()
	return result

func find_path(unit: Object, from: Vector2i, to: Vector2i, move_final: int) -> Array[Vector2i]:
	## Dijkstra 单目标寻路：通行规则同 find_reachable（存活单位互为障碍）；
	## 终点须可停留（无存活占位）
	## 参数 unit：移动单位（鸭子契约）；from/to：起终坐标；move_final：移动力终值
	## 返回：路径（不含起点、含终点）；不可达/定身/终点不可停留返回空
	if move_final <= 0 or from == to or not _InBounds(to):
		return []
	var target_occupant: Object = unit_at.get(to, null)
	if target_occupant != null and target_occupant.alive:
		return []
	var dist: Dictionary = {from: 0}
	var parents: Dictionary = {}
	var visited: Dictionary = {}
	while true:
		var current: Vector2i = Vector2i.ZERO
		var current_cost: int = move_final + 1
		var found: bool = false
		for pos: Vector2i in dist:
			if visited.has(pos):
				continue
			if not found or dist[pos] < current_cost:
				current = pos
				current_cost = dist[pos]
				found = true
		if not found or current == to:
			break
		visited[current] = true
		for neighbor: Vector2i in _Neighbors4(current):
			if not _IsEnterable(neighbor):
				continue
			var tile: TileTypeDef = tile_at(neighbor)
			var new_cost: int = current_cost + maxi(1, tile.move_cost)
			if new_cost > move_final:
				continue
			if not dist.has(neighbor) or new_cost < dist[neighbor]:
				dist[neighbor] = new_cost
				parents[neighbor] = current
	if not parents.has(to):
		return []
	var path: Array[Vector2i] = []
	var step: Vector2i = to
	while step != from:
		path.append(step)
		step = parents[step]
	path.reverse()
	return path

func cells_in_range(origin: Vector2i, distance: int) -> Array[Vector2i]:
	## 射程格集：曼哈顿距离 ≤ distance 的界内格（含原点；射程/移动 = 曼哈顿度量）
	## 参数 origin：原点坐标；distance：曼哈顿射程
	## 返回：格列表（按 y/x 排序）
	var result: Array[Vector2i] = []
	for y: int in range(maxi(0, origin.y - distance), mini(size.y, origin.y + distance + 1)):
		for x: int in range(maxi(0, origin.x - distance), mini(size.x, origin.x + distance + 1)):
			var pos: Vector2i = Vector2i(x, y)
			if manhattan(origin, pos) <= distance:
				result.append(pos)
	result.sort()
	return result

func cells_aura_3x3(origin: Vector2i) -> Array[Vector2i]:
	## 3×3 光环格集：切比雪夫距离 ≤ 1 的界内格（含中心；怒吼 AoE 度量）
	## 参数 origin：中心坐标
	## 返回：格列表（按 y/x 排序）
	var result: Array[Vector2i] = []
	for y: int in range(maxi(0, origin.y - 1), mini(size.y, origin.y + 2)):
		for x: int in range(maxi(0, origin.x - 1), mini(size.x, origin.x + 2)):
			result.append(Vector2i(x, y))
	result.sort()
	return result

func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	## 视线判定：Bresenham 格线，中间格（不含端点）障碍阻断、单位不阻断；
	## 动态地格不改变通行性（陷阱落于普通地面）
	## 参数 from/to：起终坐标
	## 返回：true = 视线通畅（同格或相邻恒 true）
	if from == to:
		return true
	return line_of_sight_clear(from, to,
			func(cell: Vector2i) -> bool:
				var tile: TileTypeDef = _BaseTileAt(cell)
				return tile == null or not tile.walkable)

static func line_of_sight_clear(from: Vector2i, to: Vector2i, is_opaque: Callable) -> bool:
	## 视线通透判定（Bresenham 单源——2026-09-26 视野遮挡拍板）：中间格
	## （不含端点）经注入 is_opaque 回调判定阻断、端点不算；战棋 has_line_of_sight
	## 与探索层迷雾（FogOfWar）两消费点共用同一格线算法——墙格自身可见
	## （作为目标格的墙不经中间格判定）
	## 参数 from/to：起终坐标；is_opaque：格遮蔽回调（cell -> true = 遮挡视线；
	## 无效回调 = 全透明）
	## 返回：true = 视线通畅（同格恒 true）
	if from == to:
		return true
	if not is_opaque.is_valid():
		return true
	var line: Array[Vector2i] = _Bresenham(from, to)
	for index: int in range(1, line.size() - 1):
		if is_opaque.call(line[index]):
			return false
	return true

func spawn_dynamic_tile(pos: Vector2i, tile_id: StringName, damage: int, source_id: StringName) -> void:
	## 生成动态地格（陷阱等）：伤害预结算入格（免判定免减免，D7 口径——
	## 触发时直取存储值）
	## 参数 pos：格子坐标；tile_id：地格类型 id；damage：预结算伤害；source_id：施放者 id
	## 返回：无
	dynamic_tiles[pos] = {
		&"tile_id": tile_id,
		&"damage": damage,
		&"source_id": source_id,
	}

func consume_dynamic_tile(pos: Vector2i) -> Dictionary:
	## 消耗动态地格（ENEMY_ENTER_ONCE 触发即移除）：取出并清除
	## 参数 pos：格子坐标
	## 返回：被消耗的动态地格字典；无动态地格返回空字典
	var data: Dictionary = dynamic_tiles.get(pos, {})
	if not data.is_empty():
		dynamic_tiles.erase(pos)
	return data

func _InBounds(pos: Vector2i) -> bool:
	## 坐标是否在地图界内
	## 参数 pos：坐标
	## 返回：true = 界内
	return pos.x >= 0 and pos.x < size.x and pos.y >= 0 and pos.y < size.y

func _Neighbors4(pos: Vector2i) -> Array[Vector2i]:
	## 四邻格（上下左右；曼哈顿度量下的移动邻接）
	## 参数 pos：坐标
	## 返回：界内四邻格列表
	var result: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var neighbor: Vector2i = pos + offset
		if _InBounds(neighbor):
			result.append(neighbor)
	return result

func _IsEnterable(pos: Vector2i) -> bool:
	## 格子可进入判定：界内 + 地格可通行 + 无任何存活单位占据
	## （2026-09-24 用户拍板：存活单位一律互为障碍——敌我对称，
	## 不可穿越且不可停留；倒地单位不阻挡）
	## 参数 pos：坐标
	## 返回：true = 可进入（Dijkstra 边合法性）
	if not _InBounds(pos):
		return false
	var tile: TileTypeDef = tile_at(pos)
	if tile == null or not tile.walkable:
		return false
	var occupant: Object = unit_at.get(pos, null)
	if occupant != null and occupant.alive:
		return false
	return true

func _BaseTileAt(pos: Vector2i) -> TileTypeDef:
	## 取基础地格定义（不经动态层；视线/通行性只看基础地形）
	## 参数 pos：坐标
	## 返回：TileTypeDef；越界或未知 id 返回 null
	if not _InBounds(pos):
		return null
	var index: int = pos.y * size.x + pos.x
	if index < 0 or index >= base_tiles.size():
		return null
	return _tile_lookup.call(base_tiles[index]) as TileTypeDef

static func _Bresenham(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	## Bresenham 格线（整数误差项迭代，端点含）
	## 参数 from/to：起终坐标
	## 返回：线上的格坐标序列（含两端）
	var points: Array[Vector2i] = []
	var x: int = from.x
	var y: int = from.y
	var dx: int = absi(to.x - from.x)
	var dy: int = -absi(to.y - from.y)
	var step_x: int = 1 if to.x > from.x else -1
	var step_y: int = 1 if to.y > from.y else -1
	var error: int = dx + dy
	while true:
		points.append(Vector2i(x, y))
		if x == to.x and y == to.y:
			break
		var double_error: int = 2 * error
		if double_error >= dy:
			error += dy
			x += step_x
		if double_error <= dx:
			error += dx
			y += step_y
	return points
