## 战场板层（BattleBoard，Control——格子网格 + 覆盖层 + 单位徽章容器）
## 职责：按 BattleContext 渲染战场——地格色块池（tile 表 kind/status_id 驱动：
## 草丛绿/高地亮黄凸边/毒沼紫黑/障碍深灰岩块描边/普通土色）、地格 hover 描述
## （特殊/障碍格 PASS + tooltip_text，文案取 tile 表 description——UI 零硬编码；
## 2026-09-24 试玩反馈）、动态地格标记（陷阱点）、覆盖层（移动范围高亮+亮边框/
## 技能范围红显/路径预览/二次确认提示）、单位徽章池、飘字伤害数字；
## 提供本地坐标 → 格坐标换算（点击命中入口）。
## 数据来源：M1 批 3 方案 §7.1；格子尺寸自适应版面（40-88px 钳制）。
## 输入口径：本层 gui_input 统一接点按（battle_screen 分发两段式确认）；
## 徽章与覆盖块均不消费鼠标；地格块 PASS 参与命中后冒泡回本层（点击链路不变）。
class_name BattleBoard
extends Control

## 格子尺寸钳制带（像素）
const CELL_SIZE_MIN: float = 40.0
const CELL_SIZE_MAX: float = 88.0
## 覆盖层边框条宽（像素）
const OVERLAY_BORDER_WIDTH: float = 2.0
## 陷阱标记色兜底（S1-4：主值入 tile 表 mark_color——tile_trap.tres；
## 表值缺失时的回退护栏）
const COLOR_TRAP_MARK_FALLBACK: Color = Color(1.0, 0.5, 0.1, 0.8)
## 地格解析失败兜底色兜底（S1-4/#8：主值入 cfg_main.ui_tile_fallback_color；
## 常量单源在 UiTheme.TILE_FALLBACK——DataValidator C-3 同引）
const TILE_FALLBACK_COLOR_FALLBACK: Color = UiTheme.TILE_FALLBACK
## 范围层边框条宽（像素——加粗以显边界）
const RANGE_BORDER_WIDTH: float = 3.0
## 视线阻断格中心斜杠条高（像素）
const BLOCKED_SLASH_WIDTH: float = 3.0
## 格间缝宽（B-17：PLAIN 色块缝隙几何提名）
const CELL_GAP: float = 2.0
## 障碍/凸边内层缩进（B-17：BLOCK 内块与 RAISED 内层同几何）
const TILE_INNER_INSET: float = 6.0
## 陷阱标记尺寸与角偏移（B-17）
const TRAP_MARK_SIZE: float = 12.0
const TRAP_MARK_CORNER_OFFSET: float = 18.0
## tips 定位边距与左右钳位边距（B-17）
const TIPS_MARGIN: float = 8.0
const TIPS_CLAMP_MARGIN: float = 4.0
## 飘字演出参数（B-16：上浮距离/时长/格内偏移/纵向偏移/描边宽）
const DAMAGE_FLOAT_DISTANCE: float = 34.0
const DAMAGE_FLOAT_DURATION: float = 0.7
const DAMAGE_CELL_OFFSET_X: float = 0.22
const DAMAGE_CELL_OFFSET_Y: float = -6.0
const DAMAGE_OUTLINE_SIZE: int = 4
## 飘字文案模板（B-8：暴击/普通两态——文案单源，改措辞只动此处）
const DAMAGE_TEXT_CRIT: String = "暴击 %d"
const DAMAGE_TEXT_NORMAL: String = "%d"
## 飘字配色与 tips 行配色（本文件视觉常量——暴击/普通/tips 两行）
const COLOR_DAMAGE_CRIT: Color = Color(1.0, 0.4, 0.3)
const COLOR_DAMAGE_NORMAL: Color = Color(1.0, 0.9, 0.6)
const COLOR_TIPS_LINE1: Color = Color(0.98, 0.6, 0.5)
const COLOR_TIPS_LINE2: Color = Color(0.85, 0.88, 0.9)

## 战斗上下文（setup 注入）
var context: BattleSetup.BattleContext = null
## 格子像素尺寸
var cell_size: float = 72.0
## 板面原点（本地坐标）
var origin: Vector2 = Vector2.ZERO

## 地格色块池（Vector2i -> Control）
var _cells: Dictionary = {}
## 覆盖层池（三层；每格一个容器 Control——填充 + 可选边框）
var _move_overlays: Array[Control] = []
var _skill_overlays: Array[Control] = []
var _path_overlays: Array[Control] = []
## 表驱动覆盖层色读取（B-5：cfg ui_overlay_* 优先、UiTheme 兜底）
func _OverlayColor(field: StringName, fallback: Color) -> Color:
	## 参数 field：cfg 字段名；fallback：UiTheme 兜底常量
	## 返回：生效颜色
	return UiTheme.color_of(context.cfg if context != null else null, field, fallback)

## 字号档位读取口（B-7：cfg ui_font_size_* 优先、UiTheme 兜底）
func _UiFont(field: StringName, fallback: int) -> int:
	## 参数 field：cfg 字段名；fallback：UiTheme 兜底档位
	## 返回：生效字号
	return UiTheme.font_of(context.cfg if context != null else null, field, fallback)

## 覆盖层专用父容器（懒建全屏 IGNORE——2026-09-24 九轮后修复：覆盖层与
## tips 同为 board 子节点时，tips 显示后重建的覆盖层会 add 到尾部压住 tips；
## 分层后覆盖层全部收进容器，tips 恒在容器之上，无论覆盖层何时重建）
var _overlay_layer: Control = null
## 单位徽章池（unit_id -> UnitBadge）
var _badges: Dictionary = {}
## 目标确认 tips 面板（技能点选目标的属性数据小窗——懒建单例，九轮反馈）
var _tips_panel: PanelContainer = null
## tips 第一行（预计伤害/治疗/技能名）
var _tips_line1: Label = null
## tips 第二行（命中率；空文本 = 隐藏）
var _tips_line2: Label = null
## GameData（sprite 路径解析——批 4 H3：纹理缓存与解析逻辑单源至 SpriteResolver，
## 本层缓存字段删除）
var _game_data: Node = null

func _ready() -> void:
	## 引擎回调：尺寸变化监听挂接（W3-04——窗口/容器尺寸变化后格子几何、
	## 徽章与动态标记须重算落位，此前仅 setup 时布局一次）
	## 参数：无
	## 返回：无
	resized.connect(_OnResized)

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

func _OnResized() -> void:
	## 尺寸变化重算（W3-04）：未装配（降级路径/装配前首帧零尺寸）跳过；
	## 几何实际变化才全量重建（格子尺寸/原点/地格/徽章/覆盖层/动态标记——
	## 覆盖层与 tips 随重建清空，选择态由宿主后续交互重建，属可接受瞬时态）
	## 参数：无
	## 返回：无
	if context == null or context.grid == null:
		return
	var old_cell: float = cell_size
	var old_origin: Vector2 = origin
	_BuildLayout()
	if is_equal_approx(old_cell, cell_size) and old_origin == origin:
		return
	for child: Node in get_children():
		child.queue_free()
	_cells.clear()
	_badges.clear()
	_ClearOverlay(_move_overlays)
	_ClearOverlay(_skill_overlays)
	_ClearOverlay(_path_overlays)
	_overlay_layer = null
	_tips_panel = null
	_tips_line1 = null
	_tips_line2 = null
	_BuildCells()
	_BuildBadges()
	RefreshDynamicMarks()

func cell_from_local(local_pos: Vector2) -> Vector2i:
	## 本地坐标 → 格坐标（界外返回 (-1, -1)；降级路径 context 空守卫——
	## 盲审批 1-6：直开场景点击不崩，返回界外哨兵）
	## 参数 local_pos：BoardLayer 本地坐标
	## 返回：格坐标
	if context == null or context.grid == null:
		return Vector2i(-1, -1)
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

func cell_visual(cell: Vector2i) -> Control:
	## 取地格视觉根节点（tooltip/输入契约测试与 UI 查询入口）
	## 参数 cell：格坐标
	## 返回：视觉根；未建返回 null
	return _cells.get(cell, null)

func show_move_range(cells: Array[Vector2i]) -> void:
	## 移动范围高亮（清旧画新；极淡填充 + 3px 亮蓝边框——2026-09-24 二轮反馈：
	## 纯边框化，不盖状态地格底色）
	## 参数 cells：可达格列表
	## 返回：无
	_ShowOverlay(cells, _OverlayColor(&"ui_overlay_move_fill_color", UiTheme.OVERLAY_MOVE_FILL),
			_move_overlays,
			_OverlayColor(&"ui_overlay_move_border_color", UiTheme.OVERLAY_MOVE_BORDER),
			RANGE_BORDER_WIDTH)

func show_skill_range(cells: Array[Vector2i], caster_pos: Vector2i,
		los_required: bool) -> void:
	## 技能范围红显（清旧画新；2026-09-24 十四轮反馈：按视线通/断分组——
	## 通格红边框；断格暗灰边框 + 中心斜杠标记，被障碍挡住的格一眼可辨）。
	## los_required = 技能射程 > 1（与 SkillExecutor 视线校验同口径——近战
	## 射程 1 免视线，全部格视为通）；进入技能模式/切换技能/移动后重显时重算
	## 参数 cells：射程内格列表；caster_pos：施放者格；los_required：是否判视线
	## 返回：无
	var visible: Array[Vector2i] = []
	var blocked: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if los_required and not context.grid.has_line_of_sight(caster_pos, cell):
			blocked.append(cell)
		else:
			visible.append(cell)
	_ShowOverlay(visible, _OverlayColor(&"ui_overlay_skill_fill_color", UiTheme.OVERLAY_SKILL_FILL),
			_skill_overlays,
			_OverlayColor(&"ui_overlay_skill_border_color", UiTheme.OVERLAY_SKILL_BORDER),
			RANGE_BORDER_WIDTH)
	_ShowBlockedOverlay(blocked, _skill_overlays)

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
	_ShowOverlay(cells, _OverlayColor(&"ui_overlay_path_color", UiTheme.OVERLAY_PATH), _path_overlays)

func show_target_confirm(cell: Vector2i) -> void:
	## 二次确认提示（目标格亮框）
	## 参数 cell：待确认目标格
	## 返回：无
	var cells: Array[Vector2i] = [cell]
	_ShowOverlay(cells, _OverlayColor(&"ui_overlay_confirm_color", UiTheme.OVERLAY_CONFIRM), _path_overlays)

func clear_overlays() -> void:
	## 清空全部覆盖层 + 伤害预览 + 目标确认 tips（预览/tips 生命周期与覆盖层
	## 一致——确认/取消/行动轮开始/技能执行后均经此清理，防残留）
	## 参数：无
	## 返回：无
	_ClearOverlay(_move_overlays)
	_ClearOverlay(_skill_overlays)
	_ClearOverlay(_path_overlays)
	clear_damage_previews()
	hide_target_tips()

func show_damage_preview(unit: BattleUnit, amount: int) -> void:
	## 目标单位血条伤害预览（转发徽章——2026-09-24 二轮试玩反馈：技能确认
	## 前显示预计伤害）
	## 参数 unit：目标单位；amount：预计伤害
	## 返回：无
	var badge: UnitBadge = _badges.get(unit.unit_id, null)
	if badge != null:
		badge.show_damage_preview(amount)

func clear_damage_previews() -> void:
	## 清全部徽章伤害预览（不影响覆盖层——换目标重选时单独调用）
	## 参数：无
	## 返回：无
	for badge: UnitBadge in _badges.values():
		badge.clear_damage_preview()

func show_target_tips(cell: Vector2i, line1: String, line2: String = "") -> void:
	## 目标确认 tips 弹出（2026-09-24 九轮反馈）：目标格上方小窗显示最终
	## 数据两行（文案与数值由 battle_screen 拼装，本层只管定位与生命周期）；
	## 纯展示 IGNORE 不遮目标格再次点击确认（ResultLayer 事故口径）
	## 参数 cell/line1/line2：目标格、第一行文本、第二行文本（空 = 隐藏）
	## 返回：无
	_EnsureTipsPanel()
	_tips_line1.text = line1
	_tips_line2.text = line2
	_tips_line2.visible = not line2.is_empty()
	var tips_size: Vector2 = _tips_panel.get_minimum_size()
	_tips_panel.size = tips_size
	# 定位：格上方居中；上界出界改格下方；左右钳制板内（定位方式参照飘字）
	var rect: Rect2 = cell_rect(cell)
	var pos: Vector2 = Vector2(rect.position.x + (rect.size.x - tips_size.x) * 0.5,
			rect.position.y - tips_size.y - TIPS_MARGIN)
	if pos.y < 0.0:
		pos.y = rect.position.y + rect.size.y + TIPS_MARGIN
	pos.x = clampf(pos.x, TIPS_CLAMP_MARGIN,
			maxf(TIPS_CLAMP_MARGIN, size.x - tips_size.x - TIPS_CLAMP_MARGIN))
	_tips_panel.position = pos
	_tips_panel.visible = true
	# 置顶（2026-09-24 九轮后修复：覆盖层在 tips 之后重建会压住 tips——
	# 每次显示挪到子节点最尾，z 序恒高于任何后建覆盖层）
	move_child(_tips_panel, get_child_count() - 1)

func hide_target_tips() -> void:
	## 隐藏目标确认 tips（幂等）
	## 参数：无
	## 返回：无
	if _tips_panel != null:
		_tips_panel.visible = false

func is_target_tips_visible() -> bool:
	## tips 可见状态（测试契约查询）
	## 参数：无
	## 返回：true = 显示中
	return _tips_panel != null and is_instance_valid(_tips_panel) and _tips_panel.visible

func target_tips_text() -> String:
	## tips 当前文本（可见行拼接；测试契约查询）
	## 参数：无
	## 返回：文本（未显示返回空）
	if not is_target_tips_visible():
		return ""
	if _tips_line2.visible:
		return "%s\n%s" % [_tips_line1.text, _tips_line2.text]
	return _tips_line1.text

func target_tips_panel() -> PanelContainer:
	## tips 面板引用（测试断言 mouse_filter 契约用；可能为 null）
	## 参数：无
	## 返回：PanelContainer
	return _tips_panel

func _EnsureTipsPanel() -> void:
	## 懒建 tips 面板（半透明深底风格同日志栏；子节点与自身全 IGNORE）
	## 参数：无
	## 返回：无
	if _tips_panel != null and is_instance_valid(_tips_panel):
		return
	_tips_panel = PanelContainer.new()
	# B-4：深底面板样式单源（UiTheme.make_dark_panel_style——与 BattleLog 共用）
	_tips_panel.add_theme_stylebox_override("panel",
			UiTheme.make_dark_panel_style(context.cfg if context != null else null))
	_tips_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	_tips_line1 = Label.new()
	_tips_line1.add_theme_font_size_override("font_size", _UiFont(&"ui_font_size_small", UiTheme.FONT_SMALL))
	_tips_line1.add_theme_color_override("font_color", COLOR_TIPS_LINE1)
	_tips_line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_tips_line1)
	_tips_line2 = Label.new()
	_tips_line2.add_theme_font_size_override("font_size", _UiFont(&"ui_font_size_minor", UiTheme.FONT_MINOR))
	_tips_line2.add_theme_color_override("font_color", COLOR_TIPS_LINE2)
	_tips_line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_tips_line2)
	_tips_panel.add_child(box)
	add_child(_tips_panel)

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
	## 飘字伤害数字（上浮淡出后自毁；暴击加大加色）；S4-11：创建后保 tips
	## 恒顶层（后建节点不压住目标确认小窗）
	## 参数 cell：目标格；amount：伤害值；is_crit：暴击标记
	## 返回：无
	var label := Label.new()
	label.text = (DAMAGE_TEXT_CRIT if is_crit else DAMAGE_TEXT_NORMAL) % amount
	label.add_theme_font_size_override("font_size", _UiFont(&"ui_font_size_large", UiTheme.FONT_LARGE) \
			if is_crit else _UiFont(&"ui_font_size_body", UiTheme.FONT_BODY))
	label.add_theme_color_override("font_color", COLOR_DAMAGE_CRIT if is_crit \
			else COLOR_DAMAGE_NORMAL)
	label.add_theme_color_override("font_outline_color",
			_OverlayColor(&"ui_badge_outline_color", UiTheme.BADGE_OUTLINE))
	label.add_theme_constant_override("outline_size", DAMAGE_OUTLINE_SIZE)
	label.position = cell_rect(cell).position \
			+ Vector2(cell_size * DAMAGE_CELL_OFFSET_X, DAMAGE_CELL_OFFSET_Y)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_KeepTipsOnTop()
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - DAMAGE_FLOAT_DISTANCE,
			DAMAGE_FLOAT_DURATION)
	tween.parallel().tween_property(label, "modulate:a", 0.0, DAMAGE_FLOAT_DURATION)
	tween.tween_callback(label.queue_free)

func _KeepTipsOnTop() -> void:
	## 目标确认 tips 置顶（S4-11：飘字/陷阱标记等后建子节点会把 tips 挤下——
	## 创建后挪回末位，z 序恒高于一切运行时节点）
	## 参数：无
	## 返回：无
	if _tips_panel != null and is_instance_valid(_tips_panel) and _tips_panel.visible:
		move_child(_tips_panel, get_child_count() - 1)

func RefreshDynamicMarks() -> void:
	## 动态地格标记刷新（陷阱橙色点——调试可见口径；S1-4：标记色经 tile 表
	## mark_color 字段驱动）；地格 hover 描述全量重算（动态陷阱格经 tile_at
	## 动态优先获得陷阱描述，消耗后回落基础层）；S4-11：创建后保 tips 恒顶层
	## 参数：无
	## 返回：无
	for child: Node in get_children():
		if child is ColorRect and child.get_meta(&"trap_mark", false):
			child.queue_free()
	_ApplyAllCellTooltips()
	for cell: Vector2i in context.grid.dynamic_tiles:
		var mark := ColorRect.new()
		mark.color = _TrapMarkColorOf(cell)
		mark.size = Vector2(TRAP_MARK_SIZE, TRAP_MARK_SIZE)
		mark.position = cell_rect(cell).position \
				+ Vector2(cell_size - TRAP_MARK_CORNER_OFFSET, cell_size - TRAP_MARK_CORNER_OFFSET)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.set_meta(&"trap_mark", true)
		add_child(mark)
	_KeepTipsOnTop()

func _TrapMarkColorOf(cell: Vector2i) -> Color:
	## 陷阱标记色（S1-4 表驱动）：动态地格的 tile 表 mark_color；表未回填/
	## 解析失败回退代码兜底常量（COLOR_TRAP_MARK_FALLBACK）
	## 参数 cell：动态地格所在格
	## 返回：标记色
	var tile: TileTypeDef = context.grid.tile_at(cell)
	if tile != null and tile.mark_color.a > 0.0:
		return tile.mark_color
	return COLOR_TRAP_MARK_FALLBACK

func _TileFallbackColor() -> Color:
	## 地格解析失败兜底色（S1-4 表驱动）：cfg_main.ui_tile_fallback_color；
	## cfg 缺失/未回填回退代码兜底常量
	## 参数：无
	## 返回：兜底色
	if context != null and context.cfg != null and context.cfg.ui_tile_fallback_color.a > 0.0:
		return context.cfg.ui_tile_fallback_color
	return TILE_FALLBACK_COLOR_FALLBACK

func _BuildLayout() -> void:
	## 版面计算：格子尺寸（界内自适应 + 钳制）与居中原点
	## 参数：无
	## 返回：无
	var grid_size: Vector2i = context.grid.size
	cell_size = minf(size.x / float(grid_size.x), size.y / float(grid_size.y))
	cell_size = clampf(cell_size, CELL_SIZE_MIN, CELL_SIZE_MAX)
	origin = (size - Vector2(grid_size) * cell_size) * 0.5

func _BuildCells() -> void:
	## 地格色块池（kind/status_id 驱动配色；高地双层凸边；障碍岩块描边）
	## + 地格 hover 描述配置
	## 参数：无
	## 返回：无
	for y: int in context.grid.size.y:
		for x: int in context.grid.size.x:
			var cell: Vector2i = Vector2i(x, y)
			var tile: TileTypeDef = context.grid.tile_at(cell)
			_cells[cell] = _MakeCellVisual(cell, tile)
	_ApplyAllCellTooltips()

func _MakeCellVisual(cell: Vector2i, tile: TileTypeDef) -> Control:
	## 构建单个地格视觉（批 A H2 表驱动：fill_color/accent_color/style 三字段
	## 驱动——UI 只按样式枚举分支，新增状态地格改表零改码）
	## 参数 cell：格坐标；tile：地格定义
	## 返回：视觉根节点
	if tile == null:
		return _MakeCellRect(cell, _TileFallbackColor(), CELL_GAP)
	match tile.style:
		TileTypeDef.Style.BLOCK:
			# 障碍岩块：底色 + 深色内块（darkened 同原式）+ 强调色描边
			var rect := _MakeCellRect(cell, tile.fill_color, 0.0)
			var inner := ColorRect.new()
			inner.color = tile.fill_color.darkened(0.3)
			inner.size = Vector2(cell_size - TILE_INNER_INSET * 2.0,
					cell_size - TILE_INNER_INSET * 2.0)
			inner.position = Vector2(TILE_INNER_INSET, TILE_INNER_INSET)
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.add_child(inner)
			for edge: ColorRect in _MakeEdgeStrips(inner.size, tile.accent_color):
				inner.add_child(edge)
			return rect
		TileTypeDef.Style.RAISED:
			# 平台凸边：外层底色 + 内层强调色双层
			var raised := _MakeCellRect(cell, tile.fill_color, 0.0)
			var inner_raised := ColorRect.new()
			inner_raised.color = tile.accent_color
			inner_raised.size = Vector2(cell_size - TILE_INNER_INSET * 2.0,
					cell_size - TILE_INNER_INSET * 2.0)
			inner_raised.position = Vector2(TILE_INNER_INSET, TILE_INNER_INSET)
			inner_raised.mouse_filter = Control.MOUSE_FILTER_IGNORE
			raised.add_child(inner_raised)
			return raised
		_:
			# PLAIN：平色块（格间缝）
			return _MakeCellRect(cell, tile.fill_color, CELL_GAP)

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

func _BuildBadges() -> void:
	## 单位徽章池（sprite 经 GameData.get_asset_path 解析，缓存复用）
	## 参数：无
	## 返回：无
	for unit: BattleUnit in context.units:
		var badge := UnitBadge.new()
		var texture: Texture2D = SpriteResolver.texture_of(
				SpriteResolver.sprite_id_of(unit, _game_data), _game_data)
		badge.setup(unit, texture, cell_size, context.cfg)
		badge.position = origin + Vector2(unit.grid_pos) * cell_size
		add_child(badge)
		_badges[unit.unit_id] = badge

func _ShowOverlay(cells: Array[Vector2i], color: Color, pool: Array[Control],
		border_color: Color = Color(0, 0, 0, 0), border_width: float = OVERLAY_BORDER_WIDTH) -> void:
	## 覆盖层画制（清池重画；每格容器 = 极淡填充 + 可选四边框；挂覆盖层专用
	## 容器——层级见 _overlay_layer 注）
	## 参数 cells/color/pool/border_color/border_width：格列表、填充色、目标池、
	## 边框色（alpha ≤ 0 无边框）、边框条宽
	## 返回：无
	_ClearOverlay(pool)
	_EnsureOverlayLayer()
	for cell: Vector2i in cells:
		var holder := Control.new()
		holder.position = origin + Vector2(cell) * cell_size
		holder.size = Vector2(cell_size, cell_size)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		fill.color = color
		fill.size = holder.size
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(fill)
		if border_color.a > 0.0:
			for edge: ColorRect in _MakeEdgeStrips(holder.size, border_color, border_width):
				holder.add_child(edge)
		_overlay_layer.add_child(holder)
		pool.append(holder)

func _EnsureOverlayLayer() -> void:
	## 懒建覆盖层专用容器（全屏 IGNORE——徽章之后建立保持「地格→徽章→
	## 覆盖层」现状层级；tips 恒在其后建，z 序恒高）
	## 参数：无
	## 返回：无
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		return
	_overlay_layer = Control.new()
	_overlay_layer.name = "OverlayLayer"
	_overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_layer)

func _ShowBlockedOverlay(cells: Array[Vector2i], pool: Array[Control]) -> void:
	## 视线阻断格渲染（十四轮反馈）：极淡灰填充 + 灰边框 + 中心 45° 斜杠
	## （ColorRect 旋转组合）；holder 带 &"los_blocked" 元标记（测试/调试契约）
	## 参数 cells/pool：格列表、目标池
	## 返回：无
	_EnsureOverlayLayer()
	for cell: Vector2i in cells:
		var holder := Control.new()
		holder.position = origin + Vector2(cell) * cell_size
		holder.size = Vector2(cell_size, cell_size)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_meta(&"los_blocked", true)
		var fill := ColorRect.new()
		fill.color = _OverlayColor(&"ui_overlay_blocked_fill_color", UiTheme.OVERLAY_BLOCKED_FILL)
		fill.size = holder.size
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(fill)
		for edge: ColorRect in _MakeEdgeStrips(holder.size,
				_OverlayColor(&"ui_overlay_blocked_border_color", UiTheme.OVERLAY_BLOCKED_BORDER),
				OVERLAY_BORDER_WIDTH):
			holder.add_child(edge)
		# 中心斜杠（绕自身中心旋转 45°）
		var slash := ColorRect.new()
		slash.color = _OverlayColor(&"ui_overlay_blocked_slash_color", UiTheme.OVERLAY_BLOCKED_SLASH)
		slash.size = Vector2(cell_size * 0.72, BLOCKED_SLASH_WIDTH)
		slash.pivot_offset = slash.size * 0.5
		slash.position = (holder.size - slash.size) * 0.5
		slash.rotation = PI * 0.25
		slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(slash)
		_overlay_layer.add_child(holder)
		pool.append(holder)

func _ClearOverlay(pool: Array[Control]) -> void:
	## 清空覆盖层池
	## 参数 pool：目标池
	## 返回：无
	for overlay: Control in pool:
		overlay.queue_free()
	pool.clear()

func _MakeEdgeStrips(strip_size: Vector2, color: Color,
		thickness: float = OVERLAY_BORDER_WIDTH) -> Array[ColorRect]:
	## 构建四边框色带（B-19 单源：UiTheme.make_edge_strip_bars——与
	## unit_badge 高亮环/蛊惑边同构收口；不挂树由调用方挂入）
	## 参数 strip_size/color/thickness：宿主尺寸、色、条宽
	## 返回：四条 ColorRect
	return UiTheme.make_edge_strip_bars(strip_size, thickness, color)

func _ApplyAllCellTooltips() -> void:
	## 全场地格 hover 描述重算（初建与动态地格增删后调用）
	## 参数：无
	## 返回：无
	for cell: Vector2i in _cells:
		_ApplyCellTooltip(cell)

func _ApplyCellTooltip(cell: Vector2i) -> void:
	## 地格 hover 描述配置：特殊/障碍格 PASS + tooltip_text（地格名 + description，
	## 文案入表——UI 零硬编码，铁律①）；普通格 IGNORE 不打扰（2026-09-24 试玩反馈）
	## 参数 cell：格坐标
	## 返回：无
	var visual: Control = _cells.get(cell, null)
	if visual == null:
		return
	var tile: TileTypeDef = context.grid.tile_at(cell)
	if tile == null or tile.kind == TileTypeDef.Kind.NORMAL:
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.tooltip_text = ""
		return
	visual.mouse_filter = Control.MOUSE_FILTER_PASS
	visual.tooltip_text = "%s\n%s" % [tile.display_name, tile.description]
