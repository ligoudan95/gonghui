## 战争迷雾（FogOfWar，RefCounted 纯逻辑类）
## 职责：探索层视野状态机——以小队位置为中心的圆形视野（格心欧氏距离
## ≤ radius）内逐格视线判定（2026-09-26 拍板：视野被墙体遮挡——Bresenham
## 直线中间格遮蔽阻断、端点不算，格线算法与战棋 BattleGrid.has_line_of_sight
## 单源共用 BattleGrid.line_of_sight_clear）、全亮行恒亮（村子段不随距离退暗）、
## 已探索记忆集（DIM 态——记忆不受遮挡影响，曾见格保持暗态）。
## 已探索集合单源在本类内（ExpeditionRun.fog 引用，run 不重复存）。
## 数据来源：案 7《地图与探索》（迷雾口径）；案 17 §3.10/§3.11 #17
## （视野半径 R 欧氏圆形度量——cfg.vision_radius 表值注入）。
## 纯逻辑约束：不触任何 autoload；radius/lit_rows/size/is_opaque 全参数注入
## （本类不知地图——墙体遮蔽经回调实时查询，暗门 reveal 后格变 etile_path
## 遮挡随之解除）。
class_name FogOfWar
extends RefCounted

## 格子可见态
enum CellState {
	UNSEEN,  ## 未探索（浓雾遮蔽）
	DIM,     ## 已探索但不在当前视野（记忆态）
	LIT,     ## 当前视野内 / 全亮行
}

## 视野半径（格——setup 注入）
var _radius: int = 0
## 全亮行号集（setup 注入；村子段恒 LIT）
var _lit_rows: Dictionary = {}
## 地图尺寸（setup 注入；可见集计算裁边）
var _size: Vector2i = Vector2i.ZERO
## 已探索格集（Vector2i -> true；含历史视野覆盖格，不含全亮行自动亮）
var _explored: Dictionary = {}
## 墙体遮蔽回调（Vector2i -> bool——true = 该格遮挡视线；无效回调 = 全透明）
var _is_opaque: Callable = Callable()

func setup(radius: int, lit_rows: Array[int], size: Vector2i,
		is_opaque: Callable = Callable()) -> void:
	## 装配迷雾（依赖注入——headless 可测；重复 setup 重置探索记忆）
	## 参数 radius：视野半径（格）；lit_rows：全亮行号列表；size：地图尺寸；
	## is_opaque：墙体遮蔽回调（缺省 = 无墙透明——纯圆形视野口径）
	## 返回：无
	_radius = maxi(0, radius)
	_lit_rows.clear()
	for row: int in lit_rows:
		_lit_rows[row] = true
	_size = size
	_is_opaque = is_opaque
	_explored.clear()

func set_opaque_probe(is_opaque: Callable) -> void:
	## 运行时挂接遮蔽回调（2026-09-26 遮挡拍板）：迷雾在 ExpeditionRun.
	## start_explore 建立时地图运行态（ExploreMapState）尚未装配——宿主屏
	## 建 _state 后经本口挂接实时墙体查询（回调按次现查非快照，暗门 reveal
	## 后遮挡自然解除）；不清探索记忆
	## 参数 is_opaque：墙体遮蔽回调（Vector2i -> bool）
	## 返回：无
	_is_opaque = is_opaque

func visible_cells(pos: Vector2i) -> Array[Vector2i]:
	## 当前位置视野格集：格心欧氏距离 ≤ radius 的圆形内逐格视线判定
	## （无遮蔽回调时等价纯圆；裁边到界内）
	## 参数 pos：小队所在格
	## 返回：可见格列表（界内；radius 0 = 仅本格）
	var cells: Array[Vector2i] = []
	if not _InBounds(pos):
		return cells
	var r_sq: float = float(_radius) * float(_radius)
	for dy: int in range(-_radius, _radius + 1):
		for dx: int in range(-_radius, _radius + 1):
			if float(dx) * float(dx) + float(dy) * float(dy) > r_sq:
				continue
			var cell: Vector2i = Vector2i(pos.x + dx, pos.y + dy)
			if _InBounds(cell) and _IsVisibleFrom(pos, cell):
				cells.append(cell)
	return cells

func on_moved(pos: Vector2i) -> Array[Vector2i]:
	## 移动结算：新揭示集 = visible(pos) − 已探索，并入已探索后返回
	## （口径统一 L1：全亮行格在视野圆内照常并入记忆集；其恒亮由行规则
	## 独立保证，与记忆集无关——圆外全亮行不入集）
	## 参数 pos：小队新所在格
	## 返回：本次新揭示格列表（空 = 无新揭示）
	var newly: Array[Vector2i] = []
	for cell: Vector2i in visible_cells(pos):
		if _explored.has(cell):
			continue
		_explored[cell] = true
		newly.append(cell)
	return newly

func state_of(cell: Vector2i, pos: Vector2i) -> CellState:
	## 格子可见态判定：界内前置（W1-7/W2-4：界外格不查全亮行——越界行号
	## 误撞全亮集会白得 LIT）→ 全亮行恒 LIT → 当前视野内（圆形 + 遮挡视线
	## ——几何现算，先于记忆集，已探索格回到视野内须回亮）→ 已探索 DIM
	## （记忆不受遮挡影响——曾从别处看过的格保持暗态）→ UNSEEN
	## 参数 cell：查询格；pos：小队当前格
	## 返回：CellState
	if not _InBounds(cell):
		return CellState.UNSEEN
	if _lit_rows.has(cell.y):
		return CellState.LIT
	if _IsVisibleFrom(pos, cell):
		return CellState.LIT
	if _explored.has(cell):
		return CellState.DIM
	return CellState.UNSEEN

func is_explored(cell: Vector2i) -> bool:
	## 已探索查询（记忆集口径——全亮行不在集内，可见性另行判定）
	## 参数 cell：查询格
	## 返回：true = 曾入视野
	return _explored.has(cell)

func explored_count() -> int:
	## 已探索格计数（进度展示/测试锚点；语义注记 L1：记忆集口径——含
	## 踏足时在视野圆内的全亮行格，不含圆外恒亮行——非「已见全集」）
	## 参数：无
	## 返回：记忆集大小
	return _explored.size()

func lit_rows() -> Array[int]:
	## 全亮行号列表（宿主渲染/区域判定消费）
	## 参数：无
	## 返回：行号列表（升序重建）
	var rows: Array[int] = []
	for row: int in _lit_rows:
		rows.append(row)
	rows.sort()
	return rows

func _IsVisibleFrom(pos: Vector2i, cell: Vector2i) -> bool:
	## 视野可见判定（单源——visible_cells 与 state_of 共用）：格心欧氏
	## ≤ radius 圆内 + 队伍位置→该格 Bresenham 直线不被墙遮挡（中间格阻断、
	## 端点不算——墙格自身可见，墙后格不可见；口径对齐战棋视线）
	## 参数 pos：小队所在格；cell：查询格
	## 返回：true = 当前可见
	var delta: Vector2i = cell - pos
	if float(delta.x) * float(delta.x) + float(delta.y) * float(delta.y) \
			> float(_radius) * float(_radius):
		return false
	return BattleGrid.line_of_sight_clear(pos, cell, _is_opaque)

func _InBounds(cell: Vector2i) -> bool:
	## 界内判定（内部口）
	## 参数 cell：查询格
	## 返回：true = 界内
	return cell.x >= 0 and cell.x < _size.x and cell.y >= 0 and cell.y < _size.y
