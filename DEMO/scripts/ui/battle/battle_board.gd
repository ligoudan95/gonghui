## 战场板层（BattleBoard，Control——格子网格 + 覆盖层 + 单位徽章容器）
## 职责：按 BattleContext 渲染战场——地格色块池（tile 表 kind/status_id 驱动：
## 草丛绿/高地亮黄凸边/毒沼紫黑/障碍深灰块/普通土色）、动态地格标记（陷阱点）、
## 覆盖层（移动范围高亮/技能范围红显/路径预览/二次确认提示）、单位徽章池、
## 飘字伤害数字；提供本地坐标 → 格坐标换算（点击命中入口）。
## 数据来源：M1 批 3 方案 §7.1；格子尺寸自适应版面（40-88px 钳制）。
## 输入口径：本层 gui_input 统一接点按（battle_screen 分发两段式确认）；
## 徽章与覆盖块均不消费鼠标。
class_name BattleBoard
extends Control

## 格子尺寸钳制带（像素）
const CELL_SIZE_MIN: float = 40.0
const CELL_SIZE_MAX: float = 88.0
## 地格配色（tile kind/status_id -> 底色）
const COLOR_NORMAL: Color = Color(0.32, 0.36, 0.29)
const COLOR_OBSTACLE: Color = Color(0.16, 0.16, 0.18)
const COLOR_GRASS: Color = Color(0.24, 0.50, 0.26)
const COLOR_HIGHGROUND: Color = Color(0.86, 0.76, 0.32)
const COLOR_HIGHGROUND_INNER: Color = Color(0.70, 0.60, 0.24)
const COLOR_POISON: Color = Color(0.30, 0.15, 0.36)
## 覆盖层配色（移动高亮/技能红显/路径/确认点）
const COLOR_MOVE_RANGE: Color = Color(0.4, 0.7, 1.0, 0.30)
const COLOR_SKILL_RANGE: Color = Color(1.0, 0.3, 0.25, 0.28)
const COLOR_PATH: Color = Color(1.0, 0.9, 0.4, 0.45)
const COLOR_CONFIRM: Color = Color(1.0, 0.95, 0.5, 0.65)
const COLOR_TRAP_MARK: Color = Color(1.0, 0.5, 0.1, 0.8)

## 战斗上下文（setup 注入）
var context: BattleSetup.BattleContext = null
## 格子像素尺寸
var cell_size: float = 72.0
## 板面原点（本地坐标）
var origin: Vector2 = Vector2.ZERO

## 地格色块池（Vector2i -> Control）
var _cells: Dictionary = {}
## 覆盖层池（三层）
var _move_overlays: Array[ColorRect] = []
var _skill_overlays: Array[ColorRect] = []
var _path_overlays: Array[ColorRect] = []
## 单位徽章池（unit_id -> UnitBadge）
var _badges: Dictionary = {}
## sprite 纹理缓存（sprite id -> Texture2D）
var _texture_cache: Dictionary = {}
## GameData（sprite 路径解析）
var _game_data: Node = null

func setup(board_context: BattleSetup.BattleContext, game_data: Node) -> void:
	## 装配板层：计算格子几何 → 画地格 → 建徽章（battle_screen 在 _ready 调）
	## 参数 board_context：战斗上下文；game_data：GameData（AssetRegistry 取图）
	## 返回：无
	context = board_context
	_game_data = game_data
	_BuildLayout()
	_BuildCells()
	_BuildBadges()
	RefreshDynamicMarks()

func cell_from_local(local_pos: Vector2) -> Vector2i:
	## 本地坐标 → 格坐标（界外返回 (-1, -1)）
	## 参数 local_pos：BoardLayer 本地坐标
	## 返回：格坐标
	var grid_size: Vector2i = context.grid.size
	var cell: Vector2i = Vector2i(int(floor((local_pos - origin).x / cell_size)),
			int(floor((local_pos - origin).y / cell_size)))
	if cell.x < 0 or cell.x >= grid_size.x or cell.y < 0 or cell.y >= grid_size.y:
		return Vector2i(-1, -1)
	return cell

func cell_rect(cell: Vector2i) -> Rect2:
	## 格坐标 → 本地像素矩形
	## 参数 cell：格坐标
	## 返回：Rect2
	return Rect2(origin + Vector2(cell) * cell_size, Vector2(cell_size, cell_size))

func show_move_range(cells: Array[Vector2i]) -> void:
	## 移动范围高亮（清旧画新）
	## 参数 cells：可达格列表
	## 返回：无
	_ShowOverlay(cells, COLOR_MOVE_RANGE, _move_overlays)

func show_skill_range(cells: Array[Vector2i]) -> void:
	## 技能范围红显（清旧画新）
	## 参数 cells：射程内格列表
	## 返回：无
	_ShowOverlay(cells, COLOR_SKILL_RANGE, _skill_overlays)

func show_path_preview(from_cell: Vector2i, to_cell: Vector2i) -> void:
	## 路径预览（直线近似：起终间逐格高亮——M1 无寻路折线渲染，确认执行后以
	## 实际移动为准）
	## 参数 from_cell/to_cell：起终格
	## 返回：无
	var cells: Array[Vector2i] = []
	var steps: int = maxi(absi(to_cell.x - from_cell.x), absi(to_cell.y - from_cell.y))
	for index: int in range(1, steps + 1):
		var t: float = float(index) / float(steps)
		cells.append(Vector2i(roundi(lerpf(from_cell.x, to_cell.x, t)),
				roundi(lerpf(from_cell.y, to_cell.y, t))))
	_ShowOverlay(cells, COLOR_PATH, _path_overlays)

func show_target_confirm(cell: Vector2i) -> void:
	## 二次确认提示（目标格亮框）
	## 参数 cell：待确认目标格
	## 返回：无
	var cells: Array[Vector2i] = [cell]
	_ShowOverlay(cells, COLOR_CONFIRM, _path_overlays)

func clear_overlays() -> void:
	## 清空全部覆盖层
	## 参数：无
	## 返回：无
	_ClearOverlay(_move_overlays)
	_ClearOverlay(_skill_overlays)
	_ClearOverlay(_path_overlays)

func refresh_badge(unit: BattleUnit) -> void:
	## 刷新单单位徽章（HP/资源/倒地态）
	## 参数 unit：单位
	## 返回：无
	var badge: UnitBadge = _badges.get(unit.unit_id, null)
	if badge != null:
		badge.refresh()

func refresh_all_badges() -> void:
	## 刷新全部徽章
	## 参数：无
	## 返回：无
	for badge: UnitBadge in _badges.values():
		badge.refresh()

func move_badge(unit: BattleUnit) -> void:
	## 徽章位置跟随单位（移动/生成后）
	## 参数 unit：单位
	## 返回：无
	var badge: UnitBadge = _badges.get(unit.unit_id, null)
	if badge != null:
		badge.position = origin + Vector2(unit.grid_pos) * cell_size

func set_current_unit(unit: BattleUnit) -> void:
	## 当前行动高亮（其余清亮）
	## 参数 unit：当前行动单位（null = 全清）
	## 返回：无
	for badge: UnitBadge in _badges.values():
		badge.set_current(badge.unit == unit)

func set_bewitched(unit: BattleUnit, active: bool) -> void:
	## 蛊惑紫边闪烁开关
	## 参数 unit：单位；active：true = 闪烁提示被控
	## 返回：无
	var badge: UnitBadge = _badges.get(unit.unit_id, null)
	if badge != null:
		badge.bewitched = active

func show_damage_number(cell: Vector2i, amount: int, is_crit: bool) -> void:
	## 飘字伤害数字（上浮淡出后自毁；暴击加大加色）
	## 参数 cell：目标格；amount：伤害值；is_crit：暴击标记
	## 返回：无
	var label := Label.new()
	label.text = ("暴击 %d" if is_crit else "%d") % amount
	label.add_theme_font_size_override("font_size", 26 if is_crit else 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3) if is_crit \
			else Color(1.0, 0.9, 0.6))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.position = cell_rect(cell).position + Vector2(cell_size * 0.22, -6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 34.0, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)

func RefreshDynamicMarks() -> void:
	## 动态地格标记刷新（陷阱橙色点——调试可见口径）
	## 参数：无
	## 返回：无
	for child: Node in get_children():
		if child is ColorRect and child.get_meta(&"trap_mark", false):
			child.queue_free()
	for cell: Vector2i in context.grid.dynamic_tiles:
		var mark := ColorRect.new()
		mark.color = COLOR_TRAP_MARK
		mark.size = Vector2(12, 12)
		mark.position = cell_rect(cell).position + Vector2(cell_size - 18, cell_size - 18)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.set_meta(&"trap_mark", true)
		add_child(mark)

func _BuildLayout() -> void:
	## 版面计算：格子尺寸（界内自适应 + 钳制）与居中原点
	## 参数：无
	## 返回：无
	var grid_size: Vector2i = context.grid.size
	cell_size = minf(size.x / float(grid_size.x), size.y / float(grid_size.y))
	cell_size = clampf(cell_size, CELL_SIZE_MIN, CELL_SIZE_MAX)
	origin = (size - Vector2(grid_size) * cell_size) * 0.5

func _BuildCells() -> void:
	## 地格色块池（kind/status_id 驱动配色；高地双层凸边）
	## 参数：无
	## 返回：无
	for y: int in context.grid.size.y:
		for x: int in context.grid.size.x:
			var cell: Vector2i = Vector2i(x, y)
			var tile: TileTypeDef = context.grid.tile_at(cell)
			_cells[cell] = _MakeCellVisual(cell, tile)

func _MakeCellVisual(cell: Vector2i, tile: TileTypeDef) -> Control:
	## 构建单个地格视觉（返回容器便于高地挂内层）
	## 参数 cell：格坐标；tile：地格定义
	## 返回：视觉根节点
	var rect: ColorRect
	if tile != null and tile.kind == TileTypeDef.Kind.OBSTACLE:
		rect = _MakeCellRect(cell, COLOR_OBSTACLE, 0.0)
		var inner := ColorRect.new()
		inner.color = COLOR_OBSTACLE.darkened(0.3)
		inner.size = Vector2(cell_size - 12, cell_size - 12)
		inner.position = Vector2(6, 6)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.add_child(inner)
	elif tile != null and tile.status_id == &"BUFF_tile_highground":
		# 高地：亮黄外层 + 深黄内层 = 凸边效果
		rect = _MakeCellRect(cell, COLOR_HIGHGROUND, 0.0)
		var inner_high := ColorRect.new()
		inner_high.color = COLOR_HIGHGROUND_INNER
		inner_high.size = Vector2(cell_size - 12, cell_size - 12)
		inner_high.position = Vector2(6, 6)
		inner_high.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.add_child(inner_high)
	else:
		rect = _MakeCellRect(cell, _TileColorOf(tile), 2.0)
	return rect

func _MakeCellRect(cell: Vector2i, color: Color, gap: float) -> ColorRect:
	## 构建地格底色块（gap = 格间缝）
	## 参数 cell/color/gap：坐标、颜色、缝宽
	## 返回：ColorRect
	var rect := ColorRect.new()
	rect.color = color
	rect.position = origin + Vector2(cell) * cell_size + Vector2(gap, gap) * 0.5
	rect.size = Vector2(cell_size - gap, cell_size - gap)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect

func _TileColorOf(tile: TileTypeDef) -> Color:
	## 地格底色（status_id 驱动；kind=STATUS 未识别状态回退普通色）
	## 参数 tile：地格定义
	## 返回：颜色
	if tile == null:
		return COLOR_NORMAL
	match tile.status_id:
		&"BUFF_tile_grass":
			return COLOR_GRASS
		&"DEBUFF_tile_poison":
			return COLOR_POISON
		_:
			return COLOR_NORMAL

func _BuildBadges() -> void:
	## 单位徽章池（sprite 经 GameData.get_asset_path 解析，缓存复用）
	## 参数：无
	## 返回：无
	for unit: BattleUnit in context.units:
		var badge := UnitBadge.new()
		var texture: Texture2D = _TextureOf(_SpriteIdOf(unit))
		badge.setup(unit, texture, cell_size)
		badge.position = origin + Vector2(unit.grid_pos) * cell_size
		add_child(badge)
		_badges[unit.unit_id] = badge

func _TextureOf(sprite_id: StringName) -> Texture2D:
	## sprite id → 纹理（AssetRegistry 路径解析 + 缓存；缺登记回退 null 占位）
	## 参数 sprite_id：资源 id（spr_cls_* / spr_en_*）
	## 返回：Texture2D（未登记返回 null——徽章回退色块）
	if _texture_cache.has(sprite_id):
		return _texture_cache[sprite_id]
	var path: String = _game_data.get_asset_path(sprite_id)
	var texture: Texture2D = null
	if not path.is_empty():
		texture = load(path) as Texture2D
	_texture_cache[sprite_id] = texture
	return texture

func _SpriteIdOf(unit: BattleUnit) -> StringName:
	## 单位 → sprite 资源 id（我方 spr_cls_<职业>；敌方 spr_en_<敌名去区域前缀>）
	## 参数 unit：单位
	## 返回：sprite id
	if unit.side == SkillDef.SkillSide.ALLY:
		return StringName("spr_%s" % unit.class_id)
	return StringName("spr_en_%s" % String(unit.enemy_id).trim_prefix("en_m1_"))

func _ShowOverlay(cells: Array[Vector2i], color: Color, pool: Array[ColorRect]) -> void:
	## 覆盖层画制（清池重画）
	## 参数 cells/color/pool：格列表、颜色、目标池
	## 返回：无
	_ClearOverlay(pool)
	for cell: Vector2i in cells:
		var overlay := ColorRect.new()
		overlay.color = color
		overlay.position = origin + Vector2(cell) * cell_size
		overlay.size = Vector2(cell_size, cell_size)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overlay)
		pool.append(overlay)

func _ClearOverlay(pool: Array[ColorRect]) -> void:
	## 清空覆盖层池
	## 参数 pool：目标池
	## 返回：无
	for overlay: ColorRect in pool:
		overlay.queue_free()
	pool.clear()
