## 探索图板（ExploreBoard，Control——程序化占位视觉组件）
## 职责：探索图渲染与点按命中——地格表驱动色块（Style 语义：PLAIN 平色块 /
## RAISED 凸边 / BLOCK 障碍块）、三态迷雾遮罩（UNSEEN 浓雾/DIM 记忆/LIT 透）、
## 交互点图标（已消耗灰态、暗门未揭示隐藏）、目标点常显（绑定目标金色高亮/
## 非绑定灰显——绘制在迷雾层之上）、小队图标、出口达成态。
## 显示层级（2026-09-25 用户拍板）：底格(Z_TILE) < 已探索内容图标(Z_CONTENT)
## < 迷雾遮罩(Z_FOG——画在图标之后：DIM 半透明压暗已探索图标) <
## 常显目标点+衬底(Z_OVERLAY) < 小队图标(Z_PARTY)；UI 弹层（事件面板等）
## 在 explore_screen 侧以 UI_POPUP_Z_INDEX 更高位整体压过 board（z_index
## 在 CanvasLayer 内跨子树全局生效——弹层绝不能留默认 0，否则被迷雾穿透）。
## 数据来源：M3 方案批 2（色块 + 图标占位视觉）；配色 cfg 表驱动
## （ui_fog_*/ui_explore_*——UiTheme 兜底）。
## UI 口径：单格设计边长 CELL_SIZE（触控热区基准 ≥48——经 fit_to 缩放后以
## effective_cell_size 实际 px 复验）；点按经 cell_pressed 信号上报（命中格坐标）。
## 布局适配（M3 质检 X3-02）：板面按宿主可用空间等比缩放（fit_to）——
## 设计空间 1920×1080 下缩放后热区 ≈57px ≥48 达标；窗口缩小场景由项目级
## canvas_items stretch 等比缩放全局 UI（战斗屏 48px 按钮同比缩小），
## 板面与之同口径——不单独承担窗口级热区保底。
class_name ExploreBoard
extends Control

## 点按命中信号（参数 = 命中格；界外点按不上报）
signal cell_pressed(cell: Vector2i)

## 单格边长（设计 px——缩放前基准；触控热区按 effective_cell_size 复验）
const CELL_SIZE: int = 60
## 绘制层 z 值单源（层级契约锚点——test_explore_layering 消费；
## 语义见文件头「显示层级」）：底格 < 已探索内容 < 迷雾 < 常显目标点 < 小队
const Z_TILE: int = 0
const Z_CONTENT: int = 1
const Z_FOG: int = 2
const Z_OVERLAY: int = 3
const Z_PARTY: int = 4
## 常显图标衬底内缩（设计 px——衬底不顶满格线）
## （占位 UI 结构参数，2026-09-26 审计 V-6 拍板豁免登记，归口案 16 §2.7——
## 文档登记由 docs-updater 后续补；不入 CoreConfig）
const BACKDROP_INSET: int = 8
## 小队图标描边宽（占位视觉结构参数——X3-06 豁免先例同口径）
const PARTY_OUTLINE_SIZE: int = 4
## 交互点图标字形（占位视觉：链/单点/宝箱/暗门/战斗/出口）
const KIND_GLYPHS: Dictionary = {
	InteractPointDef.Kind.CHAIN: "!",
	InteractPointDef.Kind.SINGLE: "?",
	InteractPointDef.Kind.TREASURE: "箱",
	InteractPointDef.Kind.SECRET_DOOR: "门",
	InteractPointDef.Kind.BATTLE: "戈",
	InteractPointDef.Kind.EXIT: "出",
}
## 目标点图标字形（常显）
const TARGET_GLYPH: String = "◇"
## 小队图标字形
const PARTY_GLYPH: String = "队"

## 总控配置（setup 注入）
var _cfg: CoreConfig = null
## 地图定义（setup 注入）
var _map_def: ExploreMapDef = null
## 地图运行态（setup 注入——tile_at 覆写感知）
var _state: ExploreMapState = null
## GameData（setup 注入——点位表查询）
var _game_data: Node = null
## 格根节点表（Vector2i -> Panel——底格层）
var _cell_panels: Dictionary = {}
## 迷雾遮罩表（Vector2i -> ColorRect）
var _fog_rects: Dictionary = {}
## 交互点图标表（point_id -> Label）
var _point_icons: Dictionary = {}
## 目标点图标表（tp_id -> Label——迷雾上层常显）
var _target_icons: Dictionary = {}
## 目标点衬底表（tp_id -> ColorRect——迷雾上层常显对比底）
var _target_backdrops: Dictionary = {}
## 小队图标
var _party_icon: Label = null
## 当前适配缩放（fit_to 计算；1.0 = 原尺寸）
var _fit_scale: float = 1.0

func setup(cfg: CoreConfig, map_def: ExploreMapDef, state: ExploreMapState,
		game_data: Node) -> void:
	## 装配板面：建底格层/迷雾层/图标层（一次构建；reveal 后调 refresh_tiles）
	## 参数 cfg/map_def/state/game_data：配置 / 图定义 / 运行态 / 数据单例
	## 返回：无
	_cfg = cfg
	_map_def = map_def
	_state = state
	_game_data = game_data
	for child: Node in get_children():
		child.queue_free()
	_cell_panels.clear()
	_fog_rects.clear()
	_point_icons.clear()
	_target_icons.clear()
	_target_backdrops.clear()
	_fit_scale = 1.0
	scale = Vector2.ONE
	custom_minimum_size = Vector2i(map_def.size.x, map_def.size.y) * CELL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_BuildTileLayer()
	_BuildFogLayer()
	_BuildIconLayers()

func fit_to(available: Vector2) -> void:
	## 板面适配（X3-02；V-1 修复 2026-09-26 审计；W3-01 高危 2026-09-26）：
	## 按宿主可用空间等比缩放（宽高取窄，上限 1.0——放大不做）；缩放经 scale
	## 变换（子节点设计坐标不变，点按命中经引擎逆变换仍按设计格换算）。
	## V-1 命中区一致性：custom_minimum_size 恒保持 design 不随 fit 收缩——
	## 控件命中区 = rect × scale == 视觉区（此前 min 同缩 → 命中区 = 视觉 × fit，
	## fit<1 时板面底/右缘视觉带点击穿透）；pivot 置 rect 中心后 scale 围绕中心
	## 收缩（居中偏移 = (design − design×fit)/2 两方向自动成立）
	## W3-01 根因（第四轮审计高危）：宿主原为 CenterContainer——其最小尺寸随
	## 子节点 min=design 膨胀到 900，VBox 分配恒 ≥ 900 → available ≥ design →
	## fit 恒 1.0（机制从未介入）且底部控件被顶出屏；宿主已改普通全伸展
	## Control（不自动排版子节点、min 不受子节点传导），available = 真实剩余
	## 空间，居中改经 center_in_host 手动落位
	## 参数 available：宿主可用尺寸（px）
	## 返回：无
	if _map_def == null:
		return
	var design: Vector2 = Vector2(_map_def.size) * float(CELL_SIZE)
	var fit: float = minf(minf(1.0, available.x / design.x), available.y / design.y)
	if fit <= 0.0 or is_nan(fit):
		return
	_fit_scale = fit
	pivot_offset = design * 0.5
	scale = Vector2.ONE * fit
	custom_minimum_size = design
	# W3-01：宿主改普通 Control 后无容器排版——size 须显式落位（命中区 =
	# rect × scale，rect 零尺寸会让板面永久点击穿透）
	size = design

func center_in_host(host_size: Vector2) -> void:
	## 缩放后板面在宿主内手动居中（W3-01 方案 A：宿主改普通 Control 后不再
	## 自动居中——rect 落位 (host − design)/2；pivot 已置 rect 中心，scale 围绕
	## 中心收缩 → rect 居中即视觉居中，命中区（rect × scale）同步一致）。
	## 与 fit_to 成对调用（resized 重算 + 首帧延迟两入口同口径）
	## 参数 host_size：宿主实际尺寸（px）
	## 返回：无
	if _map_def == null:
		return
	var design: Vector2 = Vector2(_map_def.size) * float(CELL_SIZE)
	position = (host_size - design) * 0.5

func visual_rect() -> Rect2:
	## 缩放后实际视觉占位矩形（V-1 契约锚点——测试/X3-02 完整可见断言消费）：
	## 全局变换 × 设计内容矩形；与命中矩形（全局变换 × 控件 rect，min 恒
	## design 时两者恒等）一致性由 test_v1 断言
	## 参数：无
	## 返回：视觉矩形（全局坐标；未装配返回空矩形）
	if _map_def == null:
		return Rect2()
	var design: Vector2 = Vector2(_map_def.size) * float(CELL_SIZE)
	return get_global_transform() * Rect2(Vector2.ZERO, design)

func effective_cell_size() -> float:
	## 缩放后实际单格边长（触控热区复验口径——X3-16 断言消费）
	## 参数：无
	## 返回：实际 px
	return float(CELL_SIZE) * _fit_scale

func refresh_tiles() -> void:
	## 底格层重建（暗门揭示后调用——reveal 覆写生效）
	## 参数：无
	## 返回：无
	_BuildTileLayer()

func refresh(party_pos: Vector2i, fog: FogOfWar, consumed: Dictionary,
		unlock_flags: Dictionary, active_tp_id: StringName,
		exit_active: bool) -> void:
	## 全量刷新迷雾遮罩与图标态（移动每格/交互后调用——225 格级重绘，DEMO 量级）
	## 参数 party_pos：小队格；fog：迷雾（null = 全图常亮）；consumed：已消耗事件
	## id 集（run.consumed_events）；unlock_flags：解锁标记（run.unlock_flags——
	## 暗门揭示态）；active_tp_id：本委托绑定目标点 id（空 = 无）；exit_active：
	## 出口激活（判据达成）
	## 返回：无
	var unseen_color: Color = UiTheme.color_of(_cfg, &"ui_fog_unseen_color",
			UiTheme.FOG_UNSEEN)
	var dim_color: Color = UiTheme.color_of(_cfg, &"ui_fog_dim_color",
			UiTheme.FOG_DIM)
	var dim_glyph: Color = UiTheme.color_of(_cfg, &"ui_explore_target_dim_color",
			UiTheme.EXPLORE_TARGET_DIM)
	for cell: Vector2i in _fog_rects:
		var overlay: ColorRect = _fog_rects[cell]
		var cell_state: int = FogOfWar.CellState.LIT
		if fog != null:
			cell_state = fog.state_of(cell, party_pos)
		match cell_state:
			FogOfWar.CellState.UNSEEN:
				overlay.color = unseen_color
				overlay.visible = true
			FogOfWar.CellState.DIM:
				overlay.color = dim_color
				overlay.visible = true
			_:
				overlay.visible = false
	# 交互点图标：UNSEEN 隐藏 / 已消耗灰态 / 暗门未揭示未消耗隐藏（隐藏内容不剧透）/
	# 出口激活金色、未达成灰显；查无记录跳过该图标（X3-10——刷新不中断）
	for point_id: StringName in _point_icons:
		var icon: Label = _point_icons[point_id]
		var point: InteractPointDef = _game_data.get_record(point_id) as InteractPointDef
		if point == null:
			push_warning("ExploreBoard: 交互点 '%s' 查无——图标跳过" % point_id)
			icon.visible = false
			continue
		var cell_state_point: int = FogOfWar.CellState.LIT
		if fog != null:
			cell_state_point = fog.state_of(point.cell, party_pos)
		var is_consumed: bool = consumed.has(point.ref_id) \
				or ((point.kind == InteractPointDef.Kind.TREASURE \
				or point.kind == InteractPointDef.Kind.BATTLE) and consumed.has(point.id))
		var is_revealed: bool = point.kind != InteractPointDef.Kind.SECRET_DOOR \
				or _SecretDoorRevealed(point, unlock_flags)
		icon.visible = cell_state_point != FogOfWar.CellState.UNSEEN \
				and is_revealed
		if point.kind == InteractPointDef.Kind.EXIT:
			# 出口：激活金色 / 未达成灰显
			icon.modulate = _ActiveColor() if exit_active else dim_glyph
		else:
			# 未消耗常态白（X3-06 豁免登记：占位视觉中性色，非业务口径——
			# 与 EventPanel.ATTR_NAMES 同先例不入表）
			icon.modulate = dim_glyph if is_consumed else Color(1, 1, 1)
	# 目标点常显：绑定目标金色高亮 / 非绑定灰显（衬底恒定深色不随刷新）
	for tp_id: StringName in _target_icons:
		_target_icons[tp_id].modulate = _ActiveColor() if tp_id == active_tp_id \
				else dim_glyph
	# 小队图标
	_party_icon.position = Vector2(party_pos) * float(CELL_SIZE)

func _BuildTileLayer() -> void:
	## 底格层：按地格表驱动样式逐格构建（占位色块；z_index 分层——重建不破层序）
	## 参数：无
	## 返回：无
	for cell_key: Vector2i in _cell_panels:
		var old_panel: Panel = _cell_panels[cell_key]
		old_panel.queue_free()
	_cell_panels.clear()
	for y: int in _map_def.size.y:
		for x: int in _map_def.size.x:
			var cell: Vector2i = Vector2i(x, y)
			var tile: ExploreTileDef = _state.tile_at(cell)
			var panel := Panel.new()
			panel.position = Vector2(cell) * float(CELL_SIZE)
			panel.size = Vector2.ONE * float(CELL_SIZE)
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.z_index = Z_TILE
			panel.add_theme_stylebox_override("panel", _TileStyleOf(tile))
			add_child(panel)
			_cell_panels[cell] = panel

func _BuildFogLayer() -> void:
	## 迷雾遮罩层（Z_FOG——画在已探索内容图标之后：DIM 半透明压暗记忆格图标 /
	## UNSEEN 浓雾遮蔽；常显目标点与小队在更高层不受遮）
	## 参数：无
	## 返回：无
	for y: int in _map_def.size.y:
		for x: int in _map_def.size.x:
			var cell: Vector2i = Vector2i(x, y)
			var overlay := ColorRect.new()
			overlay.position = Vector2(cell) * float(CELL_SIZE)
			overlay.size = Vector2.ONE * float(CELL_SIZE)
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.z_index = Z_FOG
			add_child(overlay)
			_fog_rects[cell] = overlay

func _BuildIconLayers() -> void:
	## 图标层：交互点图标（Z_CONTENT 已探索内容层——迷雾之下，DIM 态被遮罩
	## 压暗）/ 目标点常显图标+衬底（Z_OVERLAY——迷雾之上）/ 小队图标
	## （Z_PARTY——迷雾之上，深色描边保证可读）
	## 参数：无
	## 返回：无
	for record: Resource in _game_data.get_domain(&"map/interact_points"):
		var point := record as InteractPointDef
		var icon := _MakeGlyphLabel(KIND_GLYPHS.get(point.kind, "?"))
		icon.position = Vector2(point.cell) * float(CELL_SIZE)
		icon.z_index = Z_CONTENT
		add_child(icon)
		_point_icons[point.id] = icon
	for record: Resource in _game_data.get_domain(&"map/target_points"):
		var target := record as TargetPointDef
		# 衬底先入树（同 z 按树序后画在上——衬底垫图标之下）
		var backdrop := _MakeBackdrop()
		backdrop.position = Vector2(target.cell) * float(CELL_SIZE) \
				+ Vector2.ONE * float(BACKDROP_INSET)
		backdrop.z_index = Z_OVERLAY
		add_child(backdrop)
		_target_backdrops[target.id] = backdrop
		var icon := _MakeGlyphLabel(TARGET_GLYPH)
		icon.position = Vector2(target.cell) * float(CELL_SIZE)
		icon.z_index = Z_OVERLAY
		add_child(icon)
		_target_icons[target.id] = icon
	_party_icon = _MakeGlyphLabel(PARTY_GLYPH)
	_party_icon.add_theme_color_override("font_color",
			UiTheme.color_of(_cfg, &"ui_explore_party_color", UiTheme.EXPLORE_PARTY))
	_party_icon.add_theme_color_override("font_outline_color", UiTheme.BADGE_OUTLINE)
	_party_icon.add_theme_constant_override("outline_size", PARTY_OUTLINE_SIZE)
	_party_icon.z_index = Z_PARTY
	add_child(_party_icon)

func _MakeGlyphLabel(glyph: String) -> Label:
	## 图标标签构建（居中字形——占位视觉）
	## 参数 glyph：字形
	## 返回：Label
	var label := Label.new()
	label.text = glyph
	label.size = Vector2.ONE * float(CELL_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_title", UiTheme.FONT_TITLE))
	return label

func _MakeBackdrop() -> ColorRect:
	## 常显图标衬底构建（迷雾之上图标的对比底——内缩不顶格线；position 由
	## 调用方按格偏移设定）。
	## W4-14 登记注：backdrop 色当前为半透明纯色（UiTheme.EXPLORE_ICON_BACKDROP
	## / cfg ui_explore_icon_backdrop_color 表驱动）——衬底贴图/九宫格资源化
	## 归 M4 占位视觉退役统一处理，届时本构建改贴图加载
	## 参数：无
	## 返回：ColorRect
	var backdrop := ColorRect.new()
	backdrop.size = Vector2.ONE * float(CELL_SIZE - BACKDROP_INSET * 2)
	backdrop.color = UiTheme.color_of(_cfg, &"ui_explore_icon_backdrop_color",
			UiTheme.EXPLORE_ICON_BACKDROP)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return backdrop

func _ActiveColor() -> Color:
	## 激活高亮色（绑定目标点/激活出口共用——金色）
	## 参数：无
	## 返回：颜色
	return UiTheme.color_of(_cfg, &"ui_explore_target_active_color",
			UiTheme.EXPLORE_TARGET_ACTIVE)

func _SecretDoorRevealed(point: InteractPointDef, unlock_flags: Dictionary) -> bool:
	## 暗门揭示态判定（unlock_flag 已解锁 = 揭示——18-C4 揭示态单源）
	## 参数 point：暗门交互点；unlock_flags：run 解锁标记
	## 返回：true = 已揭示（图标可见）
	var single: SingleEventDef = _game_data.get_record(point.ref_id) as SingleEventDef
	if single == null or single.success_outcome == null:
		return false
	return unlock_flags.has(single.success_outcome.unlock_flag)

func _TileStyleOf(tile: ExploreTileDef) -> StyleBoxFlat:
	## 地格样式构建（表驱动三样式：PLAIN/RAISED/BLOCK）
	## 参数 tile：地格定义（null = 解析失败兜底色）
	## 返回：StyleBoxFlat
	var style := StyleBoxFlat.new()
	if tile == null:
		style.bg_color = UiTheme.TILE_FALLBACK
		return style
	style.bg_color = tile.fill_color
	match tile.style:
		ExploreTileDef.Style.RAISED:
			style.border_color = tile.accent_color
			style.set_border_width_all(3)
			style.set_corner_radius_all(6)
		ExploreTileDef.Style.BLOCK:
			style.bg_color = tile.fill_color.darkened(0.35)
			style.border_color = tile.accent_color
			style.set_border_width_all(2)
			style.set_corner_radius_all(4)
		_:
			pass
	return style

func _gui_input(event: InputEvent) -> void:
	## 板面点按：左键 → 格命中 → cell_pressed（命中失败不上报）
	## 参数 event：输入事件
	## 返回：无
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var cell: Vector2i = cell_from_local(mouse_event.position)
	if cell != Vector2i(-1, -1):
		cell_pressed.emit(cell)
		accept_event()

func cell_from_local(local_pos: Vector2) -> Vector2i:
	## 本地坐标 → 格坐标（界外返回 (-1,-1)）
	## 参数 local_pos：板面本地坐标
	## 返回：命中格；界外 (-1,-1)
	if local_pos.x < 0.0 or local_pos.y < 0.0:
		return Vector2i(-1, -1)
	var cell: Vector2i = Vector2i(local_pos / float(CELL_SIZE))
	if cell.x < 0 or cell.x >= _map_def.size.x \
			or cell.y < 0 or cell.y >= _map_def.size.y:
		return Vector2i(-1, -1)
	return cell
