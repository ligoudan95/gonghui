## 探索图板（ExploreBoard，Control——程序化占位视觉组件）
## 职责：探索图渲染与点按命中——地格表驱动（M6 批 3.5b 组 2 贴图接线：
## etile.asset_id/asset_variants → AssetTex.pick_variant 稳定哈希混铺贴图，
## 缺件降级 Style 三样式色块 PLAIN/RAISED/BLOCK）、三态迷雾遮罩（组 5：
## UNSEEN 浓雾/DIM 记忆贴图染色态 modulate=cfg 色（净 α=cfg 调定值——中2：
## 贴图与纯色兜底同格二选一显示，不再叠加），LIT 透——缺件纯色现状）、
## 交互点图标（组 4：icon_pt_* 贴图 48 居中，缺件降级字形；已消耗灰态、
## 暗门未揭示隐藏）、目标点常显（icon_pt_target，仅当前会话绑定委托的
## 目标点渲染金色高亮——2026-10-03 试玩反馈修订：未绑定目标点完全隐藏、
## 自由探索不显示任何目标点，绘制在迷雾层之上）、小队图标
## （icon_explore_party）、出口达成态、矿洞段可通行格淡鹅黄染色（同批
## 反馈 B——modulate 承载，村子段全亮行与不可通行格不染）。
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
## 渲染上下镜像总开关（三栏改版批 C2 拍板 (b) 渲染镜像）：数据 y=0
## 〔北/村口〕绘制于屏幕**下方**——玩家从下往上探索（案 7 方向注记锚点）。
## 逐图差异字段化时的单点替换位——本批不加 ExploreMapDef 字段，镜像为
## 渲染层口径（数据格坐标/迷雾/寻路/邻接判定零改，仅绘制落位翻转）
const RENDER_FLIP_VERTICAL: bool = true
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
## 交互点图标字形（占位降级视觉：链/单点/宝箱/暗门/战斗/出口——贴图缺件时
## 的 Label 字形回退；贴图接线后仅为降级分支）
const KIND_GLYPHS: Dictionary = {
	InteractPointDef.Kind.CHAIN: "!",
	InteractPointDef.Kind.SINGLE: "?",
	InteractPointDef.Kind.TREASURE: "箱",
	InteractPointDef.Kind.SECRET_DOOR: "门",
	InteractPointDef.Kind.BATTLE: "戈",
	InteractPointDef.Kind.EXIT: "出",
}
## 交互点图标资产 id（M6 批 3.5b 组 4：Kind -> icon_pt_*——贴图分支单源；
## SECRET_DOOR 无图标资产（暗门揭示前隐藏、揭示后走事件流——维持字形降级）
const KIND_ICONS: Dictionary = {
	InteractPointDef.Kind.CHAIN: &"icon_pt_event",
	InteractPointDef.Kind.SINGLE: &"icon_pt_event",
	InteractPointDef.Kind.TREASURE: &"icon_pt_treasure",
	InteractPointDef.Kind.BATTLE: &"icon_pt_battle",
	InteractPointDef.Kind.EXIT: &"icon_pt_exit",
}
## 目标点图标资产 id（常显层）
const TARGET_ASSET_ID: StringName = &"icon_pt_target"
## 目标点图标字形（常显——降级）
const TARGET_GLYPH: String = "◇"
## 小队图标资产 id
const PARTY_ASSET_ID: StringName = &"icon_explore_party"
## 小队图标字形（降级）
const PARTY_GLYPH: String = "队"
## 图标贴图渲染边长（px——64 源渲染 48 居中；占位 UI 结构参数，
## X3-06 豁免先例同口径）
const ICON_RENDER_SIZE: float = 48.0
## 迷雾贴图资产 id（M6 批 3.5b 组 5：UNSEEN 浓雾 / DIM 记忆——任一在档即
## 懒挂子贴图染色态；modulate = cfg 色，α 语义不变）
const FOG_UNSEEN_ASSET_ID: StringName = &"fx_fog_unseen"
const FOG_DIM_ASSET_ID: StringName = &"fx_fog_dim"

## 总控配置（setup 注入）
var _cfg: CoreConfig = null
## 地图定义（setup 注入）
var _map_def: ExploreMapDef = null
## 地图运行态（setup 注入——tile_at 覆写感知）
var _state: ExploreMapState = null
## GameData（setup 注入——点位表查询）
var _game_data: Node = null
## 格根节点表（Vector2i -> Control——底格层：贴图态 TextureRect /
## 占位降级 Panel，M6 批 3.5b 组 2 泛化）
var _cell_panels: Dictionary = {}
## 迷雾遮罩表（Vector2i -> ColorRect——常驻纯色兜底）
var _fog_rects: Dictionary = {}
## 迷雾贴图表（Vector2i -> TextureRect——组 5 懒建染色态，与 _fog_rects 同格
## 兄弟节点（中2：父隐藏连带隐藏子树，兄弟才能贴图/纯色二选一显示）；空表 =
## 两键均缺件不建，纯色现状零回归）
var _fog_textures: Dictionary = {}
## 迷雾贴图解析缓存（_BuildFogLayer 期一次解析——setup 后不变）
var _fog_unseen_tex: Texture2D = null
var _fog_dim_tex: Texture2D = null
## 交互点图标表（point_id -> Control——贴图态 TextureRect / 降级 Label）
var _point_icons: Dictionary = {}
## 目标点图标表（tp_id -> Control——迷雾上层常显；贴图态 TextureRect /
## 降级 Label）
var _target_icons: Dictionary = {}
## 目标点衬底表（tp_id -> ColorRect——迷雾上层常显对比底）
var _target_backdrops: Dictionary = {}
## 小队图标（贴图态 TextureRect / 降级 Label）
var _party_icon: Control = null
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
		# S4-R3-01 同式（_BuildTileLayer 先例）：queue_free 延迟帧末——先隐藏
		# 断渲染再释放，防旧板面与重建层一帧叠渲（setup 重复装配可感知）
		var old_visual: CanvasItem = child as CanvasItem
		if old_visual != null:
			old_visual.visible = false
		child.queue_free()
	_cell_panels.clear()
	_fog_rects.clear()
	_fog_textures.clear()
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
	## 按宿主可用空间等比缩放（宽高取窄；上限表驱动 ui_explore_board_fit_max_scale
	## ——三栏改版批 C7 放宽 1.2，cfg 缺省回退 UiTheme 兜底）；缩放经 scale
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
	# 缩放上限参数化（三栏改版批 C7：放宽 1.0 → cfg 表驱动，缺省/≤0 回退
	## UiTheme 兜底——探索界面满高放大口径）
	var fit_cap: float = _cfg.ui_explore_board_fit_max_scale \
			if _cfg != null and _cfg.ui_explore_board_fit_max_scale > 0.0 \
			else UiTheme.EXPLORE_BOARD_FIT_MAX
	var fit: float = minf(minf(fit_cap, available.x / design.x), available.y / design.y)
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
				_ApplyFogTexture(cell, _fog_unseen_tex, unseen_color)
				# 中2 修复：贴图态父纯色隐藏（父+子同显 α 叠加 UNSEEN 0.92→0.99、
				## DIM 0.55→0.69 偏离 cfg）；子贴图已移为兄弟节点——父隐藏不连带
				## 遮蔽贴图；该态缺件 → 父纯色恢复显示（净 α = cfg 调定值）
				overlay.visible = _fog_unseen_tex == null
			FogOfWar.CellState.DIM:
				overlay.color = dim_color
				_ApplyFogTexture(cell, _fog_dim_tex, dim_color)
				overlay.visible = _fog_dim_tex == null
			_:
				overlay.visible = false
				_ApplyFogTexture(cell, null, Color.WHITE)
	# 交互点图标：UNSEEN 隐藏 / 已消耗灰态 / 暗门未揭示未消耗隐藏（隐藏内容不剧透）/
	# 出口激活金色、未达成灰显；查无记录跳过该图标（X3-10——刷新不中断）
	for point_id: StringName in _point_icons:
		var icon: Control = _point_icons[point_id]
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
	# 目标点常显（2026-10-03 试玩反馈批 A 口径修订——推翻案 7 §2.1/案 20
	# §3.1「非绑定灰显」：灰色委托交互点误导玩家）：仅当前会话绑定委托的
	# 目标点渲染（金色高亮口径不变）；未绑定目标点完全隐藏（图标+衬底——
	# 原非绑定灰显渲染路径删除）；自由探索（active_tp_id 空）不显示任何目标点
	for tp_id: StringName in _target_icons:
		var is_bound: bool = tp_id == active_tp_id
		_target_icons[tp_id].visible = is_bound
		_target_backdrops[tp_id].visible = is_bound
		if is_bound:
			_target_icons[tp_id].modulate = _ActiveColor()
	# 小队图标
	_party_icon.position = _cell_origin(party_pos)

func _cell_origin(cell: Vector2i) -> Vector2:
	## 数据格 → 板面绘制原点（渲染镜像单一映射——全部绘制落位唯一走本口）：
	## 镜像态 y' = size.y-1-cell.y（数据 y=0〔北〕绘于屏幕最下行，玩家从下
	## 往上探索）；非镜像态恒等。命中反解（cell_from_local）与本口互逆
	## 参数 cell：数据格坐标
	## 返回：绘制原点（px）
	if RENDER_FLIP_VERTICAL:
		return Vector2(cell.x, _map_def.size.y - 1 - cell.y) * float(CELL_SIZE)
	return Vector2(cell) * float(CELL_SIZE)

func _BuildTileLayer() -> void:
	## 底格层：按地格表逐格构建（M6 批 3.5b 组 2——贴图分支在前：etile 表
	## asset_id + pick_variant 稳定哈希混铺；缺件/空 asset_id 降级现状占位
	## Panel 色块；z_index 分层——重建不破层序）
	## 参数：无
	## 返回：无
	for cell_key: Vector2i in _cell_panels:
		var old_visual: Control = _cell_panels[cell_key]
		# S4-R3-01 同式（event_panel._Reset 先例）：queue_free 延迟帧末——先
		# 隐藏断渲染再释放，防旧底格层与新层一帧叠渲（暗门揭示等重建可感知）
		old_visual.visible = false
		old_visual.queue_free()
	_cell_panels.clear()
	for y: int in _map_def.size.y:
		for x: int in _map_def.size.x:
			var cell: Vector2i = Vector2i(x, y)
			var tile: ExploreTileDef = _state.tile_at(cell)
			var visual: Control = _MakeTileVisual(cell, tile)
			add_child(visual)
			_cell_panels[cell] = visual

func _MakeTileVisual(cell: Vector2i, tile: ExploreTileDef) -> Control:
	## 构建单个底格视觉（组 2 接线口）：贴图分支在前——pick_variant（同格
	## 恒定/异格打散）→ AssetTex.texture_of 有 → TextureRect（STRETCH_SCALE
	## 满格、z=Z_TILE）；无/空 asset_id → 现状 Panel + _TileStyleOf 占位色块
	## 降级（缺件态视觉零回归）；两分支同落矿洞段可通行格染色（试玩反馈批 B
	## ——modulate 承载，缺件降级态视觉口径一致）
	## 参数 cell：格坐标；tile：地格定义（null = 解析失败走占位）
	## 返回：格视觉根（未挂树由调用方挂入）
	if tile != null and not String(tile.asset_id).is_empty():
		var asset_id: StringName = AssetTex.pick_variant(tile.asset_id,
				tile.asset_variants, cell)
		var texture: Texture2D = AssetTex.texture_of(asset_id, _game_data)
		if texture != null:
			var rect := TextureRect.new()
			rect.texture = texture
			# 属性序契约：expand 必须先于 position/size——expand 默认 KEEP_SIZE
			# 时 position setter 会把 size 撑到纹理尺寸且旧 min 缓存钳住后续
			# size 赋值（Godot Control 坑——顺序反了格子尺寸漂移成纹理原尺寸）
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.position = _cell_origin(cell)
			rect.size = Vector2.ONE * float(CELL_SIZE)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.z_index = Z_TILE
			rect.modulate = _MineWalkTintOf(cell, tile)
			return rect
	var panel := Panel.new()
	panel.position = _cell_origin(cell)
	panel.size = Vector2.ONE * float(CELL_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = Z_TILE
	panel.add_theme_stylebox_override("panel", _TileStyleOf(tile))
	panel.modulate = _MineWalkTintOf(cell, tile)
	return panel

func _MineWalkTintOf(cell: Vector2i, tile: ExploreTileDef) -> Color:
	## 矿洞段可通行格染色取值（2026-10-03 试玩反馈批 B）：矿洞段可通行格
	## modulate 淡鹅黄（cfg 表驱动——迷雾/染色类 modulate 承载同构口径，
	## 不改素材文件）；村子段与不可通行格不染（WHITE 等价原色）。村子段
	## 判据 = fog_lit_rows 全亮行单源（ExploreMapDef 类头惯例序 [0] 段——
	## 图定义无独立「段」字段，全亮行口径即现有唯一段定义）
	## 参数 cell：格坐标；tile：地格定义（null = 解析失败占位——保守不染）
	## 返回：modulate 染色（WHITE = 不染）
	if tile == null or not tile.walkable:
		return Color.WHITE
	if _map_def.fog_lit_rows.has(cell.y):
		return Color.WHITE
	return UiTheme.color_of(_cfg, &"ui_explore_mine_walk_tint_color",
			UiTheme.EXPLORE_MINE_WALK_TINT)

func _BuildFogLayer() -> void:
	## 迷雾遮罩层（Z_FOG——画在已探索内容图标之后：DIM 半透明压暗记忆格图标 /
	## UNSEEN 浓雾遮蔽；常显目标点与小队在更高层不受遮）；M6 批 3.5b 组 5：
	## 每格 ColorRect 常驻兜底 + 懒建同格兄弟 TextureRect（fx_fog_unseen/
	## fx_fog_dim 任一在档即建——染色态 refresh 按态选贴图 modulate=cfg 色，
	## 净 α = cfg 调定值；两键均缺件不建——纯色现状零回归）。中2 修复：贴图
	## 与纯色是同格二选一显示（refresh 切换），故为兄弟节点而非父子——父
	## ColorRect visible=false 时引擎连带隐藏整棵子树，父子结构无法只显贴图
	## 参数：无
	## 返回：无
	_fog_unseen_tex = AssetTex.texture_of(FOG_UNSEEN_ASSET_ID, _game_data)
	_fog_dim_tex = AssetTex.texture_of(FOG_DIM_ASSET_ID, _game_data)
	var has_fog_texture: bool = _fog_unseen_tex != null or _fog_dim_tex != null
	for y: int in _map_def.size.y:
		for x: int in _map_def.size.x:
			var cell: Vector2i = Vector2i(x, y)
			var overlay := ColorRect.new()
			overlay.position = _cell_origin(cell)
			overlay.size = Vector2.ONE * float(CELL_SIZE)
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.z_index = Z_FOG
			add_child(overlay)
			_fog_rects[cell] = overlay
			if has_fog_texture:
				var fog_tex := TextureRect.new()
				fog_tex.stretch_mode = TextureRect.STRETCH_SCALE
				fog_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				fog_tex.position = _cell_origin(cell)
				fog_tex.size = Vector2.ONE * float(CELL_SIZE)
				fog_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
				fog_tex.z_index = Z_FOG
				fog_tex.visible = false
				add_child(fog_tex)
				_fog_textures[cell] = fog_tex

func _ApplyFogTexture(cell: Vector2i, texture: Texture2D, tint: Color) -> void:
	## 迷雾贴图按态落位（组 5 refresh 内部口）：该态贴图在档 → 贴图显示 +
	## modulate=cfg 色（染色不换色语义——净遮蔽 α = cfg 色原样，父纯色由
	## refresh 隐藏）；该态缺件 → 贴图隐藏（父 ColorRect 纯色兜底可见，现状
	## 分支）；未建贴图（两键全缺）跳过。LIT 态 texture=null + 白 tint 隐藏
	## 贴图（tint 不生效——仅占位参数）
	## 参数 cell：格坐标；texture：该态贴图（可空）；tint：cfg 遮蔽色
	## 返回：无
	if not _fog_textures.has(cell):
		return
	var fog_tex: TextureRect = _fog_textures[cell]
	fog_tex.texture = texture
	fog_tex.modulate = tint
	fog_tex.visible = texture != null

func _BuildIconLayers() -> void:
	## 图标层：交互点图标（Z_CONTENT 已探索内容层——迷雾之下，DIM 态被遮罩
	## 压暗）/ 目标点常显图标+衬底（Z_OVERLAY——迷雾之上）/ 小队图标
	## （Z_PARTY——迷雾之上，深色描边保证可读）；M6 批 2 挂账 4.1：按当前图
	##（_map_def.id）过滤点位归属——多图数据不越权建图标；
	## M6 批 3.5b 组 4：图标经 _MakeIconNode 接线——贴图在档走 icon_pt_* /
	## icon_pt_target / icon_explore_party（64 源渲染 48 居中），缺件降级
	## 现状 Label 字形（衬底 _MakeBackdrop 维持色块不动）
	## 参数：无
	## 返回：无
	for record: Resource in _game_data.get_domain(&"map/interact_points"):
		var point := record as InteractPointDef
		if point.map_ref != _map_def.id:
			continue
		var icon: Control = _MakeIconNode(
				KIND_ICONS.get(point.kind, &"") as StringName,
				String(KIND_GLYPHS.get(point.kind, "?")))
		icon.position = _cell_origin(point.cell)
		icon.z_index = Z_CONTENT
		add_child(icon)
		_point_icons[point.id] = icon
	for record: Resource in _game_data.get_domain(&"map/target_points"):
		var target := record as TargetPointDef
		if target.map_ref != _map_def.id:
			continue
		# 衬底先入树（同 z 按树序后画在上——衬底垫图标之下）
		var backdrop := _MakeBackdrop()
		backdrop.position = _cell_origin(target.cell) \
				+ Vector2.ONE * float(BACKDROP_INSET)
		backdrop.z_index = Z_OVERLAY
		# 试玩反馈批 A：目标点默认隐藏——绑定判定归 refresh（首帧 refresh
		# 前不闪现未绑定图标/衬底）
		backdrop.visible = false
		add_child(backdrop)
		_target_backdrops[target.id] = backdrop
		var icon: Control = _MakeIconNode(TARGET_ASSET_ID, TARGET_GLYPH)
		icon.position = _cell_origin(target.cell)
		icon.z_index = Z_OVERLAY
		icon.visible = false
		add_child(icon)
		_target_icons[target.id] = icon
	_party_icon = _MakeIconNode(PARTY_ASSET_ID, PARTY_GLYPH)
	if _party_icon is Label:
		# 占位降级态（Label 字形）配色/描边维持现状；贴图态纹理自带颜色不染
		var party_label: Label = _party_icon as Label
		party_label.add_theme_color_override("font_color",
				UiTheme.color_of(_cfg, &"ui_explore_party_color", UiTheme.EXPLORE_PARTY))
		party_label.add_theme_color_override("font_outline_color", UiTheme.BADGE_OUTLINE)
		party_label.add_theme_constant_override("outline_size", PARTY_OUTLINE_SIZE)
	_party_icon.z_index = Z_PARTY
	add_child(_party_icon)

func _MakeIconNode(asset_id: StringName, glyph: String) -> Control:
	## 图标节点构建（组 4 接线口）：贴图在档 → 满格 Control 根（几何与降级
	## Label 同构——格原点定位/满格 rect，refresh 的 position/modulate/visible
	## 逻辑零改适用）+ 子 TextureRect（64 源渲染 48 居中）；空 id（如
	## SECRET_DOOR）/缺件 → 现状 Label 居中字形降级（占位态视觉零回归）
	## 参数 asset_id：图标资产 id（空 = 无贴图位）；glyph：降级字形
	## 返回：图标节点（未挂树由调用方挂入）
	if not String(asset_id).is_empty():
		var texture: Texture2D = AssetTex.texture_of(asset_id, _game_data)
		if texture != null:
			var host := Control.new()
			host.size = Vector2.ONE * float(CELL_SIZE)
			host.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var rect := TextureRect.new()
			rect.texture = texture
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.size = Vector2.ONE * ICON_RENDER_SIZE
			rect.position = Vector2.ONE * ((float(CELL_SIZE) - ICON_RENDER_SIZE) * 0.5)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			host.add_child(rect)
			return host
	return _MakeGlyphLabel(glyph)

func _MakeGlyphLabel(glyph: String) -> Label:
	## 图标标签构建（居中字形——占位降级视觉，组 4 接线后仅供缺件分支）
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
	## 本地坐标 → 格坐标（界外返回 (-1,-1)；镜像态与 _cell_origin 互逆——
	## 界内返回 (raw.x, size.y-1-raw.y)，点按命中与绘制落位同口径翻转）
	## 参数 local_pos：板面本地坐标
	## 返回：命中格；界外 (-1,-1)
	if local_pos.x < 0.0 or local_pos.y < 0.0:
		return Vector2i(-1, -1)
	var raw: Vector2i = Vector2i(local_pos / float(CELL_SIZE))
	if raw.x < 0 or raw.x >= _map_def.size.x \
			or raw.y < 0 or raw.y >= _map_def.size.y:
		return Vector2i(-1, -1)
	if RENDER_FLIP_VERTICAL:
		return Vector2i(raw.x, _map_def.size.y - 1 - raw.y)
	return raw
