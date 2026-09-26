## 探索地图运行态（ExploreMapState，RefCounted 纯逻辑类）
## 职责：探索图的运行时格子数据——布局解析（legend -> 地格表）、通行判定、
## BFS 四向等权最短路、暗门揭示覆写。揭示状态唯一运行时承载在本类
## （_revealed 覆写表——不落数据表、不入存档，随出征会话实例存续）。
## 数据来源：案 7《地图与探索》；M3 方案批 1（沿 BattleMapDef 字符阵列 +
## legend 先例）。
## 纯逻辑约束：不触任何 autoload；map_def/tile_lookup 全参数注入。
class_name ExploreMapState
extends RefCounted

## 地图定义（setup 注入）
var _map_def: ExploreMapDef = null
## 地格解析闭包（etile_ id -> ExploreTileDef；setup 注入）
var _tile_lookup: Callable = Callable()
## 揭示覆写表（Vector2i -> etile_ id——暗门捷径的唯一运行时承载）
var _revealed: Dictionary = {}
## setup 预校验结果（false = 布局非法，查询口安全降级）
var _valid: bool = false

func setup(map_def: ExploreMapDef, tile_lookup: Callable) -> bool:
	## 装配地图态：预校验（尺寸一致 / legend 必含 '.'）后缓存定义
	## 参数 map_def：地图定义；tile_lookup：etile_ id -> ExploreTileDef 闭包
	## 返回：true = 校验通过（本态可用）；false = 布局非法（push_warning，
	## 查询口安全降级：tile_at 返 null / walkable 返 false）
	_map_def = map_def
	_tile_lookup = tile_lookup
	_revealed.clear()
	_valid = false
	if map_def == null:
		push_warning("ExploreMapState: map_def 为空")
		return false
	if map_def.rows.size() != map_def.size.y:
		push_warning("ExploreMapState: rows 行数 %d != size.y %d（%s）" % [
			map_def.rows.size(), map_def.size.y, map_def.id])
		return false
	for row_index: int in map_def.rows.size():
		if map_def.rows[row_index].length() != map_def.size.x:
			push_warning("ExploreMapState: 第 %d 行行长 != size.x（%s）" % [
				row_index, map_def.id])
			return false
	if not map_def.legend.has(&"."):
		push_warning("ExploreMapState: legend 缺 '.' 图例项（%s）" % map_def.id)
		return false
	_valid = true
	return true

func is_valid() -> bool:
	## 预校验结果查询
	## 参数：无
	## 返回：true = 布局合法
	return _valid

func in_bounds(cell: Vector2i) -> bool:
	## 界内判定
	## 参数 cell：查询格
	## 返回：true = 界内
	if _map_def == null:
		return false
	return cell.x >= 0 and cell.x < _map_def.size.x \
			and cell.y >= 0 and cell.y < _map_def.size.y

func tile_at(cell: Vector2i) -> ExploreTileDef:
	## 取格地格定义（揭示覆写优先——暗门捷径格经 reveal_secret 覆写后
	## 返回揭示地格）
	## 参数 cell：查询格
	## 返回：ExploreTileDef；界外/未装配/解析失败返回 null
	if not _valid or not in_bounds(cell):
		return null
	var tile_id: StringName = _revealed.get(cell, _TileIdOf(cell))
	if not _tile_lookup.is_valid():
		return null
	return _tile_lookup.call(tile_id) as ExploreTileDef

func walkable(cell: Vector2i) -> bool:
	## 通行判定（揭示覆写生效——揭示为捷径地格后原障碍格可通行）
	## 参数 cell：查询格
	## 返回：true = 可通行
	var tile: ExploreTileDef = tile_at(cell)
	return tile != null and tile.walkable

func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	## BFS 四向等权最短路（含起终点；不可达/起终点非法/不可通行返空数组）
	## 参数 from/to：起/终格
	## 返回：路径格序列（from 开头 to 结尾）；空 = 不可达
	if not _valid or not in_bounds(from) or not in_bounds(to):
		return []
	if not walkable(from) or not walkable(to):
		return []
	if from == to:
		return [from]
	var came_from: Dictionary = {}
	var frontier: Array[Vector2i] = [from]
	var visited: Dictionary = {from: true}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN,
				Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + direction
			if visited.has(next) or not in_bounds(next) or not walkable(next):
				continue
			visited[next] = true
			came_from[next] = current
			if next == to:
				return _RebuildPath(came_from, from, to)
			frontier.append(next)
	return []

func reveal_secret(cells: Array[Vector2i], tile_id: StringName) -> void:
	## 暗门揭示：覆写目标格地格（重复揭示幂等——后写覆盖同值）
	## 参数 cells：揭示格列表；tile_id：目标地格 id（map/tiles 域）
	## 返回：无
	for cell: Vector2i in cells:
		_revealed[cell] = tile_id

func region_index_of(cell: Vector2i) -> int:
	## 格所在区域下标（region_ids 惯例序：全亮行段 = [0]，其余 = [1]——
	## 遭遇权重查表消费；region_ids 空时返回 0 由调用方兜底）。
	## V-M3-map-region-count 冻结（2026-09-26 审计 V-5）：DEMO region_ids ≤ 2
	## ——本下标推导按两段语义假设（DataValidator 校验超界）
	## 参数 cell：查询格
	## 返回：region_ids 下标（越界安全钳到末位）
	if _map_def == null or _map_def.region_ids.is_empty():
		return 0
	var is_lit: bool = false
	for row: int in _map_def.fog_lit_rows:
		if row == cell.y:
			is_lit = true
			break
	if is_lit:
		return 0
	return mini(1, _map_def.region_ids.size() - 1)

func _TileIdOf(cell: Vector2i) -> StringName:
	## 布局字符 -> 地格 id（legend 解析；未登记字符返回 '.' 图例兜底——
	## 布局校验归 V-M3-map-layout，运行态不再静默回退为墙）
	## 参数 cell：查询格
	## 返回：地格 id
	var char_key: StringName = StringName(String(_map_def.rows[cell.y][cell.x]))
	return _map_def.legend.get(char_key, _map_def.legend[&"."])

func _RebuildPath(came_from: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	## BFS 路径回溯（came_from 链从 to 回溯到 from 后反转）
	## 参数 came_from：前驱表；from/to：起/终格
	## 返回：路径格序列
	var path: Array[Vector2i] = []
	var cursor: Vector2i = to
	while cursor != from:
		path.append(cursor)
		cursor = came_from[cursor]
	path.append(from)
	path.reverse()
	return path
