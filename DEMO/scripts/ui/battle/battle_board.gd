## 战场板层（BattleBoard，Control——格子网格 + 覆盖层 + 单位徽章容器）
## 职责：按 BattleContext 渲染战场——地格池（M6 批 3.5b 组 3 贴图接线：
## tile.asset_id/asset_variants → pick_variant 混铺 → Control 根+满盒贴图；
## E1 批：2:1 等距菱形网格——逻辑坐标不动、纯渲染层投影（_CellAnchor 正
## 投影单源，11 处内联摆放公式收口消费；tile 源 256×128 菱形；缺件降级
## 菱形色面 _MakeDiamondFill：草丛绿/高地亮黄内缩母题/毒沼紫黑/障碍深灰
## 岩块内缩母题/普通土色+深色菱形描边保格界）、地格 hover 描述
## （特殊/障碍格 PASS + tooltip_text，文案取 tile 表 description——UI 零硬编码；
## 2026-09-24 试玩反馈）、动态地格标记（陷阱点——贴图态整盒半透明/缺件
## 菱形下角角块）、覆盖层（移动范围高亮/技能范围红显——组 8 fx_battle_range
## 菱形染色态；E1：程序四边框带退役——菱形描边随贴图自带/
## 路径预览高光与移动燃线（试玩反馈批：A8 箭头表现改呼吸式高光标记——D4
## 契约修订，移动过程真实路径逐格熄灭；漏洞1 修复：燃线挂独立生命周期——
## 与 clear_overlays/_ClearSelection 解耦，由逐格熄灭回调与移动 tween
## finished 自然烧完自清，行动轮切换不截断在途燃线）/二次确认提示）、
## 单位徽章池、飘字伤害数字；提供本地坐标 → 格坐标换算（点击命中入口——
## E1：菱形反投影 round 判据，共享边确定性归属单格）。
## E1 深度排序 = 手动 z_index（等距深度 = x+y，不用 Y-sort——子节点异质
## 重排破坏树序契约；探索屏 Z_* 先例）：格/陷阱标记/徽章 z = x+y、
## 覆盖层容器 Z_OVERLAY=100、tips/飘字 Z_TEXT=200（树序置顶逻辑保留双保险）。
## 数据来源：M1 批 3 方案 §7.1 + E1 方案 §二（投影数学单源锚点）；
## 菱形全宽自适应版面（cfg 钳制带 [min,max] + fit 不足让位护栏）。
## 输入口径：本层 gui_input 统一接点按（battle_screen 分发两段式确认）；
## 徽章与覆盖块均不消费鼠标；地格块 PASS 参与命中后冒泡回本层（点击链路不变）。
## 视口批：滚轮缩放 + 中键拖动平移——全部动态视觉收挂中间层 WorldLayer
##（懒建 FULL_RECT IGNORE），视口态只动其 scale/position 两属性，棋盘内部
## 一切坐标零感知；点击命中经 cell_from_board_local 逆变换（battle_screen
## 唯一消费）；缩放档表/锚点推算/贴边钳制三纯函数单源。
class_name BattleBoard
extends Control

## 覆盖层容器 z_index（恒压一切格/徽章深度——12×12 上限 x+y=22）
const Z_OVERLAY: int = 100
## tips 面板/飘字 z_index（恒压覆盖层——树序置顶逻辑保留作双保险）
const Z_TEXT: int = 200
## 平移拖动激活阈值（像素——按下位移达阈值才进入拖动，防误触吞格点按；
## 结构契约常量不入 cfg——策划拍板豁免，案 16 §2.7 登记口径）
const PAN_DRAG_THRESHOLD: float = 4.0
## 菱形命中判据浮点容差（边界点 round 归属的数值抖动护栏）
const HIT_EPS: float = 0.0001
## 覆盖层边框条宽（像素——E1 程序四边框带退役后仅 _MakeEdgeStrips 签名默认值保留）
const OVERLAY_BORDER_WIDTH: float = 2.0
## 陷阱标记色兜底（S1-4：主值入 tile 表 mark_color——tile_trap.tres；
## 表值缺失时的回退护栏）
const COLOR_TRAP_MARK_FALLBACK: Color = Color(1.0, 0.5, 0.1, 0.8)
## 地格解析失败兜底色兜底（S1-4/#8：主值入 cfg_main.ui_tile_fallback_color；
## 常量单源在 UiTheme.TILE_FALLBACK——DataValidator C-3 同引）
const TILE_FALLBACK_COLOR_FALLBACK: Color = UiTheme.TILE_FALLBACK
## 范围层边框条宽（像素——E1 同上退役，签名默认值保留）
const RANGE_BORDER_WIDTH: float = 3.0
## 视线阻断格中心斜杠条高（像素）
const BLOCKED_SLASH_WIDTH: float = 3.0
## 阻断斜杠长占菱形全宽比（E1 复核：2:1 菱形内 45° 可容线段全长 =
## √2×w×ratio/(1+ratio) ≈ 0.471w——0.45 留安全余量不越菱形）
const BLOCKED_SLASH_LENGTH_RATIO: float = 0.45
## 降级菱形色面描边宽（像素——格界辨识）
const DIAMOND_BORDER_WIDTH: float = 2.0
## 降级菱形母题内缩比（BLOCK/RAISED 内层菱形 = 外层 × (1−本值×2)——
## E1 退役 CELL_GAP/TILE_INNER_INSET 方形内缩口径改比例）
const DIAMOND_INNER_INSET_RATIO: float = 0.12
## 陷阱标记尺寸（B-17；E1：定位改菱形下角内侧——TRAP_MARK_CORNER_OFFSET
## 方形角偏移口径退役）
const TRAP_MARK_SIZE: float = 12.0
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
## 飘字文案（M6 批 1：MISS 变体——闪避=不播受击+MISS 飘字拍板口径；
## per-file UI_TEXTS 既定模式）
const UI_TEXTS: Dictionary = {
	&"miss_text": "闪避",
}
## 路径箭头资产 id（M6 批 3.5a A8：右向基准素材——上/下 rotate ±90°、
## 左 rotate 180° 复用单件，不出多朝向素材）
## 试玩反馈批（D4 契约修订）：路径箭头表现被推翻改闪烁高光——本消费点
## 已拆除，素材键保留 registry 登记不删（零改表原则，未来可用）
const PATH_ARROW_ASSET_ID: StringName = &"fx_battle_path_arrow"
## 范围覆盖贴图资产 id（M6 批 3.5b 组 8：_ShowOverlay 填充块贴图态——
## modulate = cfg 填充色染蓝/染红；缺件回退现状 ColorRect）
const RANGE_OVERLAY_ASSET_ID: StringName = &"fx_battle_range"
## 陷阱格贴图态整格透明度（组 3——贴图自带纹样，半透明显「区域」而非「实心」）
const TRAP_TILE_ALPHA: float = 0.55
## 方向 → 箭头旋转角（度；右向基准：右 0 / 下 90 / 左 180 / 上 270——
## 09 组规格 v1.1 勘正口径）——试玩反馈批 D4 契约修订：箭头渲染拆除，
## 常量一并移除（素材键保留见 PATH_ARROW_ASSET_ID 注）
## 路径高光呼吸谷值比（闪烁渐变形态的一部分：谷值 = 峰值 × 本值——
## 公式形态代码化；峰值/周期/曲线经 cfg ui_battle_path_highlight_* 表驱动）
const PATH_HIGHLIGHT_TROUGH_RATIO: float = 0.3
## 移动演出步数上限口径注（D6：tween 总时长 = 步长 × min(路径步数, 上限)——
## 远距移动时长钳制防长路径演出拖沓；低15 盲审修复：上限值入表
## cfg.ui_battle_move_max_steps（UiTheme.BATTLE_MOVE_MAX_STEPS 兜底 +
## V-B2 锚定/V-M0 值域），读取口 _MoveTweenMaxSteps）
## 飘字配色与 tips 行配色（S4-M4-3-d：入表——cfg ui_damage_*/ui_tips_* 字段
## 消费经 _OverlayColor 同款 color_of 读取口；UiTheme 兜底常量锚定）
## 战斗上下文（setup 注入）
var context: BattleSetup.BattleContext = null
## 菱形全宽（像素——E1 改造：原 cell_size 方形边长口径退役）
var cell_width: float = 72.0
## 菱形全高（像素——派生只读：cell_width × iso_ratio，cfg 驱动即时反映）
var cell_height: float:
	get:
		return cell_width * _IsoRatio()
## 板面原点（本地坐标——E1：全棋盘菱形包围盒左上角）
var origin: Vector2 = Vector2.ZERO

## 地格色块池（Vector2i -> Control）
var _cells: Dictionary = {}
## 在飞飘字 tween 池（S4-R2-03：resize 全量重建前 kill——防 tween 对已
## queue_free 的 label 继续插值报错刷屏；正常播完自行出池）
var _float_tweens: Array[Tween] = []
## 覆盖层池（选择态生命周期——clear_overlays 统一清理）：移动范围/技能范围/
## 路径预览高光（show_path_preview——首点未确认时的预览，维持现有清理路径
## 不变）；_path_overlays 池另承载技能目标确认框（show_target_confirm——同随
## 选择态生灭）
var _move_overlays: Array[Control] = []
var _skill_overlays: Array[Control] = []
var _path_overlays: Array[Control] = []
## 路径预览高光格映射（Vector2i -> 高光 holder——预览层索引视图；随
## _path_overlays 池同步生灭）
var _path_highlight_cells: Dictionary = {}
## 移动燃线池（漏洞1 修复：独立演出生命周期）：move_badge 确认移动后按真实
## 路径建的闪烁高光——与 clear_overlays/_ClearSelection **解耦**，由逐格熄灭
## 回调与移动 tween finished 自然烧完自清（或再次移动重建/resize 全量重建时
## 清）；turn_started 等行动轮切换不再截断在途燃线（漏洞2 随之统一解决——
## 敌方长距移动「人还在走、线已消失」消除）；holder 挂 _overlay_layer 随板
## 释放无泄漏（战斗结束亦不强制清——自然烧完，终局面板窗口 <0.9s）
var _burning_overlays: Array[Control] = []
## 移动燃线格映射（Vector2i -> holder——逐格熄灭查表；随 _burning_overlays
## 池同步生灭）
var _burning_highlight_cells: Dictionary = {}
## 表驱动覆盖层色读取（B-5：cfg ui_overlay_* 优先、UiTheme 兜底）
func _OverlayColor(field: StringName, fallback: Color) -> Color:
	## 参数 field：cfg 字段名；fallback：UiTheme 兜底常量
	## 返回：生效颜色
	return UiTheme.color_of(context.cfg if context != null else null, field, fallback)

func _DamageCritColor() -> Color:
	## 飘字暴击色（cfg 表驱动——兜底 UiTheme.DAMAGE_CRIT）
	## 参数：无
	## 返回：生效颜色
	return _OverlayColor(&"ui_damage_crit_color", UiTheme.DAMAGE_CRIT)

func _DamageNormalColor() -> Color:
	## 飘字普通色（cfg 表驱动——兜底 UiTheme.DAMAGE_NORMAL）
	## 参数：无
	## 返回：生效颜色
	return _OverlayColor(&"ui_damage_normal_color", UiTheme.DAMAGE_NORMAL)

func _TipsLine1Color() -> Color:
	## tips 第一行色（cfg 表驱动——兜底 UiTheme.TIPS_LINE1）
	## 参数：无
	## 返回：生效颜色
	return _OverlayColor(&"ui_tips_line1_color", UiTheme.TIPS_LINE1)

func _TipsLine2Color() -> Color:
	## tips 第二行色（cfg 表驱动——兜底 UiTheme.TIPS_LINE2）
	## 参数：无
	## 返回：生效颜色
	return _OverlayColor(&"ui_tips_line2_color", UiTheme.TIPS_LINE2)

## 字号档位读取口（B-7：cfg ui_font_size_* 优先、UiTheme 兜底）
func _UiFont(field: StringName, fallback: int) -> int:
	## 参数 field：cfg 字段名；fallback：UiTheme 兜底档位
	## 返回：生效字号
	return UiTheme.font_of(context.cfg if context != null else null, field, fallback)

## 覆盖层专用父容器（懒建全屏 IGNORE——2026-09-24 九轮后修复：覆盖层与
## tips 同为 board 子节点时，tips 显示后重建的覆盖层会 add 到尾部压住 tips；
## 分层后覆盖层全部收进容器，tips 恒在容器之上，无论覆盖层何时重建）
var _overlay_layer: Control = null
## 视口中间层（视口批：地格/徽章/覆盖层容器/tips/飘字的统一挂载点——
## 懒建 FULL_RECT IGNORE，尺寸恒 == 板区；缩放/平移只动本层 scale/position
## 两属性，棋盘内部一切坐标零感知；resize 全量重建跳过本层不释放）
var _world_layer: Control = null
## 缩放档表（0 档 = fit 态 1.0——_BuildLayout 末尾按 fit 全宽与钳制上限生成）
var _zoom_steps: Array[float] = []
## 当前缩放档下标
var _zoom_index: int = 0
## 平移目标位（连续滚动/拖动推算一律取目标态——非 tween 中间值）
var _view_pan_target: Vector2 = Vector2.ZERO
## 在途缩放 tween（重缩放/拖动激活/resize 重置三入口统一 kill）
var _zoom_tween: Tween = null
## 平移按下位（板层本地坐标——中键 press 时记）
var _pan_press_pos: Vector2 = Vector2.ZERO
## 平移起点快照（激活时 _view_pan_target 的备份——拖动增量基准）
var _pan_start_pos: Vector2 = Vector2.ZERO
## 平移按下待激活标记（未过阈值前——轻点吞格防护）
var _pan_pending: bool = false
## 平移拖动激活标记
var _pan_active: bool = false
## 在飞飘字 Label 池（视口批：label 挂 _world_layer 后 resize 重建不再随
## 板级清子释放——kill tween 时须显式释放；正常播完自行出池）
var _float_labels: Array[Label] = []
## 单位徽章池（unit_id -> UnitBadge）
var _badges: Dictionary = {}
## 徽章移动 tween 池（unit_id -> Tween——重移动前 kill 旧 tween；W3 重建清池）
var _move_tweens: Dictionary = {}
## 目标确认 tips 面板（技能点选目标的属性数据小窗——懒建单例，九轮反馈）
var _tips_panel: PanelContainer = null
## tips 第一行（预计伤害/治疗/技能名）
var _tips_line1: Label = null
## tips 第二行（命中率；空文本 = 隐藏）
var _tips_line2: Label = null
## GameData（sprite 路径解析——批 4 H3：纹理缓存与解析逻辑单源至 SpriteResolver，
## 本层缓存字段删除）
var _game_data: Node = null
## resized 重建待执行标记（拍板 A 防抖一帧合并：同帧多次 resized 只排一次
## call_deferred——重复排队前查此标记防重入；帧末执行体置回）
var _resize_rebuild_queued: bool = false

## E1 等距投影参数读取口（cfg ui_battle_iso_* 优先、UiTheme ISO_* 兜底；
## 值域外非法值回退兜底——与 _PathHighlight* 三口同模式；徽章侧
## sprite/feet/ring 三参读取口在 UnitBadge 自建同款，本层不重复）
func _IsoRatio() -> float:
	## 菱形纵横比（cell_height = cell_width × 本值；2:1 等距 = 0.5）
	## 参数：无
	## 返回：生效比例（(0, 1]）
	var raw: float = UiTheme.ISO_RATIO
	if context != null and context.cfg != null:
		raw = context.cfg.ui_battle_iso_ratio
	if raw <= 0.0 or raw > 1.0:
		return UiTheme.ISO_RATIO
	return raw

func _IsoCellWidthMin() -> float:
	## 菱形全宽钳制带下限（像素——保底触控面积）
	## 参数：无
	## 返回：生效下限（> 0）
	var raw: float = UiTheme.ISO_CELL_WIDTH_MIN
	if context != null and context.cfg != null:
		raw = context.cfg.ui_battle_iso_cell_width_min
	if raw <= 0.0:
		return UiTheme.ISO_CELL_WIDTH_MIN
	return raw

func _IsoCellWidthMax() -> float:
	## 菱形全宽钳制带上限（像素）
	## 参数：无
	## 返回：生效上限（> 0）
	var raw: float = UiTheme.ISO_CELL_WIDTH_MAX
	if context != null and context.cfg != null:
		raw = context.cfg.ui_battle_iso_cell_width_max
	if raw <= 0.0:
		return UiTheme.ISO_CELL_WIDTH_MAX
	return raw

func _ZoomStepRatio() -> float:
	## 缩放档距比读取（视口批：cfg ui_battle_zoom_step_ratio 表驱动——
	## UiTheme.BATTLE_ZOOM_STEP_RATIO 兜底；值域 [UiTheme.ZOOM_MIN_STEP_GAP,
	## UiTheme.ZOOM_MAX_STEP_RATIO] 外非法回退（R1-02/03：上下限常量 UiTheme
	## 单源——下限与档表防退步档差同值，过小档距互踩产无感档），_IsoRatio
	## 同模式）
	## 参数：无
	## 返回：生效档距比
	var raw: float = UiTheme.BATTLE_ZOOM_STEP_RATIO
	if context != null and context.cfg != null:
		raw = context.cfg.ui_battle_zoom_step_ratio
	if raw < UiTheme.ZOOM_MIN_STEP_GAP or raw > UiTheme.ZOOM_MAX_STEP_RATIO:
		return UiTheme.BATTLE_ZOOM_STEP_RATIO
	return raw

func _ZoomSeconds() -> float:
	## 缩放档切换动画时长读取（cfg ui_battle_zoom_seconds 表驱动——
	## UiTheme.BATTLE_ZOOM_SECONDS 兜底；值域 [0, 0.5] 外非法回退；
	## 0 = 瞬跳直落——表侧显式 0 合法、未回填哨兵同走即时，
	## log_toggle_seconds 先例口径）
	## 参数：无
	## 返回：生效时长（秒）
	var raw: float = UiTheme.BATTLE_ZOOM_SECONDS
	if context != null and context.cfg != null:
		raw = context.cfg.ui_battle_zoom_seconds
	if raw < 0.0 or raw > 0.5:
		return UiTheme.BATTLE_ZOOM_SECONDS
	return raw

func _ready() -> void:
	## 引擎回调：尺寸变化监听挂接（W3-04——窗口/容器尺寸变化后格子几何、
	## 徽章与动态标记须重算落位，此前仅 setup 时布局一次）
	## 参数：无
	## 返回：无
	resized.connect(_OnResized)

func _process(_delta: float) -> void:
	## 引擎回调：平移拖动轮询（视口批——中键 release 的 gui_input 可能因
	## 拖出板面/被其他层截获而丢失，全局轮询兜底收口）：①中键已松开 →
	## viewport_end_pan（幂等）②全局鼠标位 → 板层本地坐标
	##（get_global_transform().affine_inverse()——含视口 stretch 变换）
	## ③待激活态位移过阈值 → 激活 ④激活态按「起点 + 位移增量」推
	## world.position → 贴边钳制 → 同步目标位；非拖动态首行早退零开销
	## 参数 _delta：帧间隔（未用——位移按帧即时量）
	## 返回：无
	if not _pan_pending and not _pan_active:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		viewport_end_pan()
		return
	# 盲审修复 8（S3-03）：视口层失效的拖动态异常收口（与公开口同式守卫
	#——正常路径 begin_pan 已挡，防御层）
	if _world_layer == null or not is_instance_valid(_world_layer):
		viewport_end_pan()
		return
	var cur: Vector2 = get_global_transform().affine_inverse() * get_global_mouse_position()
	if _pan_pending and cur.distance_to(_pan_press_pos) >= PAN_DRAG_THRESHOLD:
		_ActivatePan()
	if _pan_active:
		var zoom_now: float = _zoom_steps[_zoom_index] \
				if _zoom_index < _zoom_steps.size() else 1.0
		var new_pan: Vector2 = _pan_start_pos + (cur - _pan_press_pos)
		new_pan = clamp_viewport_position(origin, _BoardBoxOf(), size, zoom_now, new_pan)
		_world_layer.position = new_pan
		_view_pan_target = new_pan

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
	## 拍板 A 防抖一帧合并：窗口拖动期 resized 每帧触发、origin 随尺寸必变
	## 致几何变更判定恒真、每帧全量重建几百节点——同帧多次 resized 只在帧末
	## 合并重建一次（脏标记 + call_deferred——重复排队前查待执行标记防重入）；
	## 几何架构零改：origin 计算与重建逻辑原样收口 _ApplyResizeRebuild
	## 参数：无
	## 返回：无
	if context == null or context.grid == null:
		return
	if _resize_rebuild_queued:
		return
	_resize_rebuild_queued = true
	_ApplyResizeRebuild.call_deferred()

func _ApplyResizeRebuild() -> void:
	## resized 防抖执行体（帧末单次——原 _OnResized 重建逻辑原样迁移）：
	## 先置回待执行标记（后续 resized 可再排队）→ 几何实际变化才全量重建
	##（格子尺寸/原点/地格/徽章/覆盖层/动态标记——覆盖层与 tips 随重建清空，
	## 选择态由宿主后续交互重建，属可接受瞬时态）；
	## S4-R2-03：重建前 kill 在飞飘字 tween（label 随下方全量重建统一释放，
	## kill 阻断 tween_callback 的二次 queue_free 与对已释放对象的插值报错）
	## 参数：无
	## 返回：无
	_resize_rebuild_queued = false
	if context == null or context.grid == null:
		return
	# 视口批：视口态全复位（几何比较早退之前——resized 即便几何未变也归位
	# 缩放/平移，与档表随 _BuildLayout 重建归 0 档一致）
	_ResetViewportState()
	var old_width: float = cell_width
	var old_origin: Vector2 = origin
	_BuildLayout()
	if is_equal_approx(old_width, cell_width) and old_origin == origin:
		return
	_KillFloatingTweens()
	for unit_id: StringName in _move_tweens.keys():
		_KillMoveTween(unit_id)
	for child: Node in get_children():
		# 视口批：WorldLayer 跳过——格/徽章/覆盖层/tips/飘字已收挂其下，
		# 全量重建只清动态视觉；层自身变换已由 _ResetViewportState 归位、
		# FULL_RECT 锚点随新板尺寸自动跟随，重建后免重挂
		if child == _world_layer:
			continue
		# S4-R3-01 同式（event_panel._Reset 先例）：先隐藏断输入/渲染再释放
		#（queue_free 延迟帧末——旧格子层与新层一帧叠渲）
		var visual: CanvasItem = child as CanvasItem
		if visual != null:
			visual.visible = false
		child.queue_free()
	# 视口层子视觉全清（等价原板级全量清子面：格/徽章/陷阱标记/覆盖层
	# 容器/tips/飘字——统一挂载点后的重建释放路径）
	if _world_layer != null and is_instance_valid(_world_layer):
		for child: Node in _world_layer.get_children():
			var world_visual: CanvasItem = child as CanvasItem
			if world_visual != null:
				world_visual.visible = false
			child.queue_free()
	_cells.clear()
	_badges.clear()
	_ClearOverlay(_move_overlays)
	_ClearOverlay(_skill_overlays)
	_ClearOverlay(_path_overlays)
	_path_highlight_cells.clear()
	# 漏洞1 修复边界：重建前移动 tween 已全 kill（上方循环）——燃线熄灭回调
	# 随 tween 失效不再触发，在途燃线必须在此显式清（否则随新层永久残留）
	_ClearBurningPathHighlights()
	_overlay_layer = null
	_tips_panel = null
	_tips_line1 = null
	_tips_line2 = null
	_BuildCells()
	_BuildBadges()
	RefreshDynamicMarks()

func cell_from_local(local_pos: Vector2) -> Vector2i:
	## 本地坐标 → 格坐标（E1 菱形反投影——_CellAnchor 正投影的严格逆变换：
	## 连续格坐标 (x_f, y_f) 下菱形格区域 = 轴对齐单位方形，round 最近格即
	## 命中；共享边由 round 远零侧确定性归属单格、菱形咬合区（盒四角外三角）
	## 归属邻格——全平面无空隙无重叠；界外返回 (-1, -1)；降级路径 context 空
	## 守卫——盲审批 1-6：直开场景点击不崩，返回界外哨兵）
	## 数学单源锚点 = E1 方案 §二（正投影公式）；实现偏离注：方案判据原文为
	## L1 ≤ 0.5，与本板正投影不自洽（L1 内切菱形会丢方形角部 = 菱形顶点
	## 死区），按正投影严格逆变换取 round + 方形判据（|dx|/|dy| ≤ 0.5+HIT_EPS
	## 正常恒真，仅浮点边界护栏）——已上报记录
	## 参数 local_pos：BoardLayer 本地坐标
	## 返回：格坐标
	if context == null or context.grid == null:
		return Vector2i(-1, -1)
	var grid_size: Vector2i = context.grid.size
	if cell_width <= 0.0 or cell_height <= 0.0:
		return Vector2i(-1, -1)
	var d: Vector2 = local_pos - origin
	var p_axis: float = d.x / (cell_width * 0.5)
	var q_axis: float = d.y / (cell_height * 0.5)
	var x_f: float = (p_axis + q_axis - float(grid_size.y) - 1.0) * 0.5
	var y_f: float = (q_axis - p_axis + float(grid_size.y) - 1.0) * 0.5
	var rx: int = roundi(x_f)
	var ry: int = roundi(y_f)
	# 三格共享顶点仲裁：x/y 双 0.5 恰界（连续坐标四方格公共角——真实几何
	# 为 (cx,cy)/(cx+1,cy)/(cx,cy+1) 三菱形共享顶点，双上取会误归第 4 格
	# (cx+1,cy+1)——该点不在其菱形内）；y 回退下侧归东邻（其菱形左上边
	# 端点=本顶点，几何合法归属）
	if absf(absf(x_f - float(rx)) - 0.5) < HIT_EPS \
			and absf(absf(y_f - float(ry)) - 0.5) < HIT_EPS:
		ry -= 1
	if rx < 0 or rx >= grid_size.x or ry < 0 or ry >= grid_size.y:
		return Vector2i(-1, -1)
	if absf(x_f - float(rx)) > 0.5 + HIT_EPS \
			or absf(y_f - float(ry)) > 0.5 + HIT_EPS:
		return Vector2i(-1, -1)
	return Vector2i(rx, ry)

func _CellAnchor(cell: Vector2i) -> Vector2:
	## 格坐标 → 菱形包围盒左上角（E1 正投影单源——与现行 holder.position
	## 语义无缝对接；全图包围盒 = origin 起 (gw+gh)×w/2 × (gw+gh)×h/2）；
	## 降级守卫：context/grid 空返回 ZERO（cell_from_local 哨兵先例同式）
	## 数学单源锚点 = E1 方案 §二（反投影/生成器 _DiamondMask 同构互引）
	## 参数 cell：格坐标
	## 返回：该格菱形包围盒左上角（本地坐标）
	if context == null or context.grid == null:
		return Vector2.ZERO
	var gh: int = context.grid.size.y
	return Vector2(
			origin.x + (float(cell.x - cell.y) + float(gh - 1)) * cell_width * 0.5,
			origin.y + float(cell.x + cell.y) * cell_height * 0.5)

func cell_rect(cell: Vector2i) -> Rect2:
	## 格坐标 → 本地像素矩形（E1：菱形包围盒——签名与外部消费口径不变）
	## 参数 cell：格坐标
	## 返回：Rect2（盒尺寸 = (cell_width, cell_height)）
	return Rect2(_CellAnchor(cell), Vector2(cell_width, cell_height))

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

func show_path_preview(path_cells: Array[Vector2i]) -> void:
	## 路径预览（试玩反馈批修复：预览高光与移动裁决**同源**——调用方用
	## BattleGrid.find_path（controller._move_unit 移动同款寻路函数）算出
	## 真实路径逐格传入，本层零路径计算纯渲染，杜绝箭头时代直线近似
	##（lerp 插值穿障碍）与真实寻路的偏差；路径含终点不含起点，与
	## move_badge 燃线口径一致——确认移动后同一路径衔接重建+逐格熄灭，
	## 全程严格一一对应；空路径（不可达/退化）= 清旧预览不画高光
	##（调用方可达性过滤外的双保险）；画入**预览池**（_path_overlays——
	## 选择态生命周期，clear_overlays 可清；与移动燃线池分层互不串扰）
	## 参数 path_cells：真实寻路路径（find_path 结果——含终点不含起点）
	## 返回：无
	_ShowPathHighlights(path_cells, _path_overlays, _path_highlight_cells)

func _ShowPathHighlights(cells: Array[Vector2i], pool: Array[Control],
		cell_map: Dictionary) -> void:
	## 路径闪烁高光渲染（试玩反馈批内部口——预览/燃线共用渲染体）：清指定
	## 池重画——每格一个满格 ColorRect（cfg 高光色 + alpha 峰值起步）+ 呼吸
	## 循环 tween（峰值 ⇄ 谷值，周期/曲线 cfg 表驱动）；holder 入 pool 并登记
	## cell_map（逐格熄灭查表用）；闪烁 tween 用 holder.create_tween() 绑定
	## 节点——holder 释放（clear/熄灭/重建）时 tween 自动失效，无需独立
	## kill 池（区别于飘字 tween 挂 board 的先例）
	## 参数 cells：路径格列表；pool：目标覆盖层池；cell_map：格 → holder 映射
	## 返回：无
	_ClearOverlay(pool)
	cell_map.clear()
	_EnsureOverlayLayer()
	var peak: float = _PathHighlightPeakAlpha()
	var trough: float = peak * PATH_HIGHLIGHT_TROUGH_RATIO
	var half_cycle: float = _PathHighlightFlashSeconds() * 0.5
	var trans: int = _PathHighlightTrans()
	for cell: Vector2i in cells:
		var holder := Control.new()
		holder.position = _CellAnchor(cell)
		holder.size = Vector2(cell_width, cell_height)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glow: Control = _MakeDiamondFill(_PathHighlightColor())
		glow.size = holder.size
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.modulate.a = peak
		holder.add_child(glow)
		# 呼吸循环：峰值 → 谷值 → 峰值（一完整明暗循环 = cfg 周期；曲线 cfg 表驱动）
		var flash: Tween = holder.create_tween()
		flash.set_loops()
		flash.tween_property(glow, "modulate:a", trough, half_cycle).set_trans(trans)
		flash.tween_property(glow, "modulate:a", peak, half_cycle).set_trans(trans)
		_overlay_layer.add_child(holder)
		pool.append(holder)
		cell_map[cell] = holder

func _ExtinguishPathHighlight(cell: Vector2i) -> void:
	## 熄灭单格移动燃线（试玩反馈批：移动过程「走过的格熄灭」——move_badge
	## 逐格链每段到达回调消费；漏洞1 修复：熄灭对象为燃线池（独立生命周期
	## ——预览层不走熄灭，二次预览由 show_path_preview 清池重画）；holder
	## 释放时其呼吸 tween 随节点绑定自动失效）
	## 参数 cell：已走过的格
	## 返回：无
	var holder: Control = _burning_highlight_cells.get(cell, null)
	_burning_highlight_cells.erase(cell)
	if holder == null or not is_instance_valid(holder):
		return
	_burning_overlays.erase(holder)
	holder.queue_free()

func _ClearBurningPathHighlights() -> void:
	## 清空全部移动燃线（漏洞1 修复边界 c 收口单源）：在途移动 tween 被 kill
	## 时（resize 全量重建 / move_badge 直落·瞬移分支中断演出）逐格熄灭回调
	## 随 tween 失效——燃线必须显式清，否则失去唯一清理者残留；幂等（空池
	## 无操作），_ShowPathHighlights 重建燃线池时开头的清池不走本口（参数化
	## 双池共用渲染体）
	## 参数：无
	## 返回：无
	_ClearOverlay(_burning_overlays)
	_burning_highlight_cells.clear()

func _PathHighlightColor() -> Color:
	## 路径高光色读取（cfg ui_battle_path_highlight_color 表驱动——
	## UiTheme.BATTLE_PATH_HIGHLIGHT_COLOR 兜底）
	## 参数：无
	## 返回：生效颜色
	return _OverlayColor(&"ui_battle_path_highlight_color",
			UiTheme.BATTLE_PATH_HIGHLIGHT_COLOR)

func _PathHighlightPeakAlpha() -> float:
	## 路径高光呼吸峰值 alpha 读取（cfg 表驱动，值域 (0, 1]——非法回退兜底）
	## 参数：无
	## 返回：峰值 alpha
	var raw: float = UiTheme.BATTLE_PATH_HIGHLIGHT_PEAK_ALPHA
	if context != null and context.cfg != null:
		raw = context.cfg.ui_battle_path_highlight_peak_alpha
	if raw <= 0.0 or raw > 1.0:
		return UiTheme.BATTLE_PATH_HIGHLIGHT_PEAK_ALPHA
	return raw

func _PathHighlightFlashSeconds() -> float:
	## 路径高光呼吸周期读取（cfg 表驱动，≤ 0 非法回退兜底）
	## 参数：无
	## 返回：呼吸周期（秒）
	var raw: float = UiTheme.BATTLE_PATH_HIGHLIGHT_FLASH_SECONDS
	if context != null and context.cfg != null:
		raw = context.cfg.ui_battle_path_highlight_flash_seconds
	if raw <= 0.0:
		return UiTheme.BATTLE_PATH_HIGHLIGHT_FLASH_SECONDS
	return raw

func _PathHighlightTrans() -> int:
	## 路径高光呼吸渐变形态读取（cfg 表驱动；Tween.TransitionType 值——
	## 0 = 未回填哨兵（同 ui_battle_move_max_steps 的 >0 判据惯例，
	## LINEAR 形态被牺牲不用），非合法值集成员同回退兜底 SINE——合法集单源
	## UiTheme.BATTLE_PATH_HIGHLIGHT_TRANS_VALID（V-M0 校验同引））
	## 参数：无
	## 返回：Tween.TransitionType 枚举值
	var raw: int = UiTheme.BATTLE_PATH_HIGHLIGHT_TRANS
	if context != null and context.cfg != null:
		raw = context.cfg.ui_battle_path_highlight_trans
	if raw <= Tween.TransitionType.TRANS_LINEAR \
			or not UiTheme.BATTLE_PATH_HIGHLIGHT_TRANS_VALID.has(raw):
		return UiTheme.BATTLE_PATH_HIGHLIGHT_TRANS
	return raw

func show_target_confirm(cell: Vector2i) -> void:
	## 二次确认提示（目标格亮框）
	## 参数 cell：待确认目标格
	## 返回：无
	var cells: Array[Vector2i] = [cell]
	_ShowOverlay(cells, _OverlayColor(&"ui_overlay_confirm_color", UiTheme.OVERLAY_CONFIRM), _path_overlays)

func clear_overlays() -> void:
	## 清空选择态覆盖层 + 伤害预览 + 目标确认 tips（预览/tips 生命周期与覆盖层
	## 一致——确认/取消/行动轮开始/技能执行后均经此清理，防残留）；路径预览
	## 高光映射随池同步清空（holder 由池统一释放，呼吸 tween 随节点绑定失效）；
	## **移动燃线池不在此列**（漏洞1 修复：燃线独立演出生命周期——由逐格熄灭
	## 回调与移动 tween finished 自然烧完自清，clear_overlays/_ClearSelection
	## 均不得触及在途燃线，行动轮切换不再截断）
	## 参数：无
	## 返回：无
	_ClearOverlay(_move_overlays)
	_ClearOverlay(_skill_overlays)
	_ClearOverlay(_path_overlays)
	_path_highlight_cells.clear()
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
	# 盲审修复 4（S4-03）：pos 为 world 本地坐标——上界判据与左右钳制的
	# 板面边界在板层坐标系，先正变换到板本地（pos×zoom + pan）判/钳，再
	# 逆变换回 world 本地落位（fit 态 zoom=1、pan=0 两系重合——行为零变化）
	var rect: Rect2 = cell_rect(cell)
	var pos: Vector2 = Vector2(rect.position.x + (rect.size.x - tips_size.x) * 0.5,
			rect.position.y - tips_size.y - TIPS_MARGIN)
	var has_world: bool = _world_layer != null and is_instance_valid(_world_layer)
	var zoom: float = _world_layer.scale.x if has_world else 1.0
	var pan: Vector2 = _world_layer.position if has_world else Vector2.ZERO
	if (pos * zoom + pan).y < 0.0:
		pos.y = rect.position.y + rect.size.y + TIPS_MARGIN
	var board_pos: Vector2 = pos * zoom + pan
	board_pos.x = clampf(board_pos.x, TIPS_CLAMP_MARGIN,
			maxf(TIPS_CLAMP_MARGIN, size.x - tips_size.x - TIPS_CLAMP_MARGIN))
	_tips_panel.position = (board_pos - pan) / zoom
	_tips_panel.visible = true
	# 置顶（2026-09-24 九轮后修复：覆盖层在 tips 之后重建会压住 tips——
	# 每次显示挪到子节点最尾，z 序恒高于任何后建覆盖层；视口批：tips 挂
	# _world_layer 下，置顶上下文随之）
	_world_layer.move_child(_tips_panel, _world_layer.get_child_count() - 1)

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
	# B-4：深底面板样式单源（UiTheme.make_dark_panel_style——与 BattleLog 共用；
	## M6 批 3.5b 组 7：九宫格贴图态经 game_data 参切换）
	_tips_panel.add_theme_stylebox_override("panel",
			UiTheme.make_dark_panel_style(context.cfg if context != null else null,
					_game_data))
	_tips_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# E1：tips 恒压覆盖层容器（z 带显式设定——树序置顶逻辑保留双保险）
	_tips_panel.z_index = Z_TEXT
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	_tips_line1 = Label.new()
	_tips_line1.add_theme_font_size_override("font_size", _UiFont(&"ui_font_size_small", UiTheme.FONT_SMALL))
	_tips_line1.add_theme_color_override("font_color", _TipsLine1Color())
	_tips_line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_tips_line1)
	_tips_line2 = Label.new()
	_tips_line2.add_theme_font_size_override("font_size", _UiFont(&"ui_font_size_minor", UiTheme.FONT_MINOR))
	_tips_line2.add_theme_color_override("font_color", _TipsLine2Color())
	_tips_line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_tips_line2)
	_tips_panel.add_child(box)
	# 视口批：挂 _world_layer（tips 随视口缩放平移同步——棋盘世界坐标系）
	_EnsureWorldLayer()
	_world_layer.add_child(_tips_panel)

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

static func facing_flip_of(from_x: int, to_x: int) -> bool:
	## 移动朝向相位判定（批次 A 纯函数——移动演出随步设朝向与攻击翻面
	## 共用单源）：下一格 x 更小 → 面左（flip）；更大 → 面右（默认）；
	## x 相等（竖直步）→ 回正默认朝向（与攻击同列回正同口径）
	## 参数 from_x：当前格 x；to_x：下一格 x
	## 返回：true = 水平翻转面左
	return to_x < from_x

func _MoveTweenMaxSteps(cfg: CoreConfig) -> int:
	## 移动演出步数上限读取（低15：cfg.ui_battle_move_max_steps 表驱动——
	## UiTheme.BATTLE_MOVE_MAX_STEPS 兜底；D6 语义 = tween 总时长钳制护栏）
	## 参数 cfg：总控配置（可空）
	## 返回：步数上限（表值非法 ≤ 0 回退兜底）
	if cfg != null and cfg.ui_battle_move_max_steps > 0:
		return cfg.ui_battle_move_max_steps
	return UiTheme.BATTLE_MOVE_MAX_STEPS

func _FaceBadgeOnStep(badge: UnitBadge, from_x: int, to_x: int) -> void:
	## 徽章迈步入格瞬间设朝向（批次 A 私有助手——move_badge 逐段链前回调
	## 与瞬移一次判定共用；纯表现层，grid_pos 位置权威不受影响）
	## 参数 badge：移动单位徽章；from_x：本步起点格 x；to_x：本步终点格 x
	## 返回：无
	badge.set_flip(facing_flip_of(from_x, to_x))

func _UpdateBadgeDepth(badge: UnitBadge, cell: Vector2i) -> void:
	## 徽章等距深度设定（E1 私有助手——move_badge 逐段链回调与瞬移/直落
	## 一次设定共用）：z = cell.x + cell.y（与地格同深；同格 tie-break 树序
	## 格→陷阱标记→徽章天然正确；12×12 上限 22 < Z_OVERLAY）
	## 参数 badge：移动单位徽章；cell：所在/迈入格
	## 返回：无
	badge.z_index = cell.x + cell.y

func move_badge(unit: BattleUnit, from_pos: Vector2i = Vector2i(-9999, -9999),
		path_cells: Array = []) -> void:
	## 徽章位置跟随单位（M6 D6=A：from_pos 有效时播移动演出——tween 滑动 +
	## MOVE 动作，tween 完回落 IDLE；步长 = cfg.ui_battle_move_step_seconds，
	## ≤ 0 瞬移直落后**立即回落 IDLE**【低6：与 tween 分支对称——cfg 置 0 不再
	## 走步动画常驻】；低9 盲审修复：path_cells 携带 controller 寻路真实踏过
	## 格序（unit_moved 信号扩 4 参）——逐格序列 tween 不再穿障碍格直插，
	## 步数按真实路径长计（无路径数据回退曼哈顿直线兜底）；总时长 =
	## 步长 × min(步数, cfg.ui_battle_move_max_steps)（钳制语义保留）；
	## grid_pos 仍为位置权威——动画纯视觉不阻塞；
	## 试玩反馈批：tween 分支同时按真实路径建闪烁高光并逐格熄灭（走过的
	## 格熄灭——直落/瞬移分支无演出过程不建高光）；漏洞1 修复：高光入独立
	## 燃线池——不随 clear_overlays/_ClearSelection 清理，自然烧完自清；
	## 批次 A：移动演出全程随步设朝向——每迈入下一格按 x 相位翻转/回正
	##（facing_flip_of 单源；无位移分支不触发；瞬移起终点一次判定；敌我同权）
	## 参数 unit：单位；from_pos：移动起点格（无效哨兵 = 直落不演出）；
	## path_cells：踏过格序（含终点不含起点；空 = 曼哈顿直线兜底）
	## 返回：无
	var badge: UnitBadge = _badges.get(unit.unit_id, null)
	if badge == null:
		return
	var dest: Vector2 = _CellAnchor(unit.grid_pos)
	# 盲审 R4-1：尸体直落位不播演出（MOVE tween/燃线/朝向链）——grid_pos
	## 位置权威语义保持（战续回带/尸体归位消费），只挡演出层；尸体无在途
	## 移动 tween（controller 只 move 存活单位），无需燃线清理路径
	if not unit.alive:
		badge.position = dest
		_UpdateBadgeDepth(badge, unit.grid_pos)
		return
	# 在途演出中断标记（漏洞1 修复边界 c 收口）：本分支若 kill 了该单位在途
	# 移动 tween（直落/瞬移不重建燃线），逐格熄灭回调随 kill 失效——在途
	# 燃线必须随之清，否则失去唯一清理者残留至 resize 重建；had_tween 守卫
	# 保证多单位并发在途（他单位燃线）不被误清
	var had_move_tween: bool = _move_tweens.has(unit.unit_id)
	_KillMoveTween(unit.unit_id)
	if from_pos == Vector2i(-9999, -9999) or from_pos == unit.grid_pos:
		badge.position = dest
		_UpdateBadgeDepth(badge, unit.grid_pos)
		if had_move_tween:
			_ClearBurningPathHighlights()
		return
	var step_seconds: float = UiTheme.BATTLE_MOVE_STEP_SECONDS
	var max_steps: int = UiTheme.BATTLE_MOVE_MAX_STEPS
	if context != null and context.cfg != null:
		step_seconds = context.cfg.ui_battle_move_step_seconds
		max_steps = _MoveTweenMaxSteps(context.cfg)
	# 逐格序列整理（试玩反馈批修复注：path_cells 来自 find_path/stepped_cells
	# 本就是**逐格序列**——无拐点压缩，中途格全在列；滤起点/去重仅防御信号
	# 侧坏数据，保证末点 == 目的地不把徽章留在半途；空链退化为单段直插
	# = 旧直线行为兜底）
	var path_sequence: Array[Vector2i] = []
	for cell: Vector2i in path_cells:
		if cell != from_pos and not path_sequence.has(cell):
			path_sequence.append(cell)
	if path_sequence.is_empty() or path_sequence[path_sequence.size() - 1] != unit.grid_pos:
		path_sequence.append(unit.grid_pos)
	# 计步：有路径数据按真实踏过格数；无路径回退曼哈顿（旧口径）
	var raw_steps: int = path_sequence.size()
	if path_cells.is_empty():
		raw_steps = maxi(absi(unit.grid_pos.x - from_pos.x)
				+ absi(unit.grid_pos.y - from_pos.y), 1)
	var total_steps: int = mini(maxi(raw_steps, 1), max_steps)
	if step_seconds <= 0.0:
		# 瞬移（测试注 0 / 生产 cfg 置 0）：位置直落；动作走一遍 MOVE 再立即
		# 回落 IDLE（低6 对称修复；攻击演出中两请求均被压制属预期优先级语义）；
		# 瞬移无演出过程不建燃线——若 kill 了在途 tween（had_move_tween）其
		# 燃线随 kill 失去熄灭回调，一并清（漏洞1 修复边界 c 收口）；
		# 批次 A：朝向退化起终点一次判定（无逐步演出过程）；E1：深度一次设定
		badge.position = dest
		badge.play_action(UnitAnimState.Action.MOVE)
		badge.play_action(UnitAnimState.Action.IDLE)
		_FaceBadgeOnStep(badge, from_pos.x, unit.grid_pos.x)
		_UpdateBadgeDepth(badge, unit.grid_pos)
		if had_move_tween:
			_ClearBurningPathHighlights()
		return
	badge.position = _CellAnchor(from_pos)
	_UpdateBadgeDepth(badge, from_pos)
	badge.play_action(UnitAnimState.Action.MOVE)
	# 试玩反馈批：移动过程路径闪烁高光——按真实路径逐格建**燃线**（预览高光
	## 已被 unit_moved 前置 clear_overlays 清空；预览与移动消费同一 find_path
	## 结果——首尾严格一一对应），每格到达即熄灭该格高光（「走过的格熄灭」
	## ——燃线式进度感，与逐格 tween 时序天然对齐）；漏洞1 修复：燃线画入
	## 独立燃线池（不随 clear_overlays/_ClearSelection/turn_started 清理——
	## 由本熄灭回调与 tween finished 自然烧完自清）；再次移动杀旧 tween 时
	## 高光由 _ShowPathHighlights 开头清池重建，无泄漏路径
	_ShowPathHighlights(path_sequence, _burning_overlays, _burning_highlight_cells)
	# 逐格等分时长链式 tween（总时长 = 步长 × 钳制步数——D6 语义不变）
	var leg_seconds: float = step_seconds * float(total_steps) / float(path_sequence.size())
	var tween: Tween = create_tween()
	# 批次 A：每段 tween_property 之前插朝向回调——迈入下一格的瞬间按
	# 「当前格→下一格」x 相位翻转/回正；prev_cell 段后推进（bind 值捕获同
	# _ExtinguishPathHighlight.bind 先例）；链首段回调随 tween 启动立即执行
	#（= 移动开始同时按第一步定初始朝向）；结束后保持最终朝向（无复位回调）
	# E1：同插入位并插深度回调——迈入瞬间 z 切目标格深度（x+y），跨格移动
	# 徽章与地格遮挡关系随步正确
	var prev_cell: Vector2i = from_pos
	for cell: Vector2i in path_sequence:
		tween.tween_callback(_FaceBadgeOnStep.bind(badge, prev_cell.x, cell.x))
		tween.tween_callback(_UpdateBadgeDepth.bind(badge, cell))
		tween.tween_property(badge, "position",
				_CellAnchor(cell), leg_seconds)
		tween.tween_callback(_ExtinguishPathHighlight.bind(cell))
		prev_cell = cell
	tween.tween_callback(func() -> void:
		if is_instance_valid(badge):
			badge.play_action(UnitAnimState.Action.IDLE))
	_move_tweens[unit.unit_id] = tween
	tween.finished.connect(func() -> void: _move_tweens.erase(unit.unit_id))

func _KillMoveTween(unit_id: StringName) -> void:
	## 终止单位在途移动 tween（重移动/重建前调用）
	## 参数 unit_id：单位 id
	## 返回：无
	var tween: Tween = _move_tweens.get(unit_id, null) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_move_tweens.erase(unit_id)

func play_badge_action(unit: BattleUnit, action: int) -> void:
	## 单位动作播放转发（M6：battle_screen 十信号分派消费口）
	## 参数 unit：单位；action：UnitAnimState.Action
	## 返回：无
	var badge: UnitBadge = _badges.get(unit.unit_id, null)
	if badge != null:
		badge.play_action(action)

func play_all_badges_action(action: int) -> void:
	## 全员动作播放（M6：battle_started → 全员 IDLE）
	## 参数 action：UnitAnimState.Action
	## 返回：无
	for badge: UnitBadge in _badges.values():
		badge.play_action(action)

func set_badge_flip(unit: BattleUnit, flip: bool) -> void:
	## 单位徽章朝向翻转（M6：skill_executed 按双方 x 相位消费）
	## 参数 unit：单位；flip：true = 水平翻转
	## 返回：无
	var badge: UnitBadge = _badges.get(unit.unit_id, null)
	if badge != null:
		badge.set_flip(flip)

func flash_badge(unit: BattleUnit) -> void:
	## 单位徽章受击白闪转发（M6：skill_executed 命中伤害路径消费）
	## 参数 unit：单位
	## 返回：无
	var badge: UnitBadge = _badges.get(unit.unit_id, null)
	if badge != null:
		badge.play_hit_flash()

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
	_SpawnFloatText(cell, (DAMAGE_TEXT_CRIT if is_crit else DAMAGE_TEXT_NORMAL) % amount,
			_DamageCritColor() if is_crit else _DamageNormalColor(),
			&"ui_font_size_large" if is_crit else &"ui_font_size_body",
			UiTheme.FONT_LARGE if is_crit else UiTheme.FONT_BODY)

func show_miss_text(cell: Vector2i) -> void:
	## 飘字 MISS（M6 批 1：闪避=不播受击 + MISS 飘字——文案 UI_TEXTS 单源；
	## 配色/字号取 tips 次行档与伤害数字错开）
	## 参数 cell：目标格
	## 返回：无
	_SpawnFloatText(cell, String(UI_TEXTS[&"miss_text"]),
			_TipsLine2Color(), &"ui_font_size_body", UiTheme.FONT_BODY)

func _SpawnFloatText(cell: Vector2i, text: String, color: Color,
		font_field: StringName, font_fallback: int) -> void:
	## 飘字泛化（M6：伤害/MISS 共用）——上浮淡出后自毁；S4-11：创建后保
	## tips 恒顶层；S4-R2-03：tween 入池（resize 重建前 kill）
	## 参数 cell：目标格；text：文本；color：字色；font_field/font_fallback：
	## 字号 cfg 字段与兜底档
	## 返回：无
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _UiFont(font_field, font_fallback))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color",
			_OverlayColor(&"ui_badge_outline_color", UiTheme.BADGE_OUTLINE))
	label.add_theme_constant_override("outline_size", DAMAGE_OUTLINE_SIZE)
	label.position = cell_rect(cell).position \
			+ Vector2(cell_width * DAMAGE_CELL_OFFSET_X, DAMAGE_CELL_OFFSET_Y)
	label.z_index = Z_TEXT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 视口批：挂 _world_layer（飘字随视口缩放平移同步）+ label 入池
	#（挂视口层后不再随板级清子释放——kill tween 时显式释放）
	_EnsureWorldLayer()
	_world_layer.add_child(label)
	_float_labels.append(label)
	_KeepTipsOnTop()
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - DAMAGE_FLOAT_DISTANCE,
			DAMAGE_FLOAT_DURATION)
	tween.parallel().tween_property(label, "modulate:a", 0.0, DAMAGE_FLOAT_DURATION)
	# 盲审修复 7（S3-02）：出池移出有效性分支——label 已失效（外部释放）也
	# 出池，防僵尸条目驻留 _float_labels
	tween.tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
		_float_labels.erase(label))
	# S4-R2-03：入池登记（resize 重建前 kill）；正常播完自行出池
	_float_tweens.append(tween)
	tween.finished.connect(_float_tweens.erase.bind(tween))

func _KillFloatingTweens() -> void:
	## 在飞飘字 tween 终止（S4-R2-03：_OnResized 全量重建前调用——kill 后
	## tween_callback 不再触发；视口批：label 挂 _world_layer 下不随板级
	## 清子释放，须在此显式释放——否则失去唯一释放者残留）
	## 参数：无
	## 返回：无
	for tween: Tween in _float_tweens.duplicate():
		if tween.is_valid():
			tween.kill()
	_float_tweens.clear()
	for label: Label in _float_labels.duplicate():
		if is_instance_valid(label):
			label.queue_free()
	_float_labels.clear()

func _KeepTipsOnTop() -> void:
	## 目标确认 tips 置顶（S4-11：飘字/陷阱标记等后建子节点会把 tips 挤下——
	## 创建后挪回末位，z 序恒高于一切运行时节点；视口批：置顶上下文随挂载
	## 点走 _world_layer）
	## 参数：无
	## 返回：无
	if _tips_panel != null and is_instance_valid(_tips_panel) and _tips_panel.visible \
			and _world_layer != null and is_instance_valid(_world_layer):
		_world_layer.move_child(_tips_panel, _world_layer.get_child_count() - 1)

func RefreshDynamicMarks() -> void:
	## 动态地格标记刷新（陷阱——调试可见口径；S1-4：标记色经 tile 表
	## mark_color 字段驱动）；M6 批 3.5b 组 3：tile 表贴图在档（如 tile_trap
	## → tile_battle_trap）→ 整格半透明 TextureRect（贴图自带纹样，alpha=
	## TRAP_TILE_ALPHA；meta trap_mark 沿用），缺件回退现状橙色角块；
	## 地格 hover 描述全量重算（动态陷阱格经 tile_at 动态优先获得陷阱描述，
	## 消耗后回落基础层）；S4-11：创建后保 tips 恒顶层
	## 参数：无
	## 返回：无
	# 视口批：标记挂 _world_layer 下——清理遍历随挂载点走（板级子仅视口层）
	if _world_layer != null and is_instance_valid(_world_layer):
		for child: Node in _world_layer.get_children():
			if child.get_meta(&"trap_mark", false):
				child.queue_free()
	_ApplyAllCellTooltips()
	for cell: Vector2i in context.grid.dynamic_tiles:
		var tile: TileTypeDef = context.grid.tile_at(cell)
		var trap_texture: Texture2D = _TileTextureOf(cell, tile)
		var mark: Control = null
		if trap_texture != null:
			# 贴图态：整盒半透明陷阱面（格根 IGNORE + 满盒贴图）
			var holder := Control.new()
			holder.position = cell_rect(cell).position
			holder.size = Vector2(cell_width, cell_height)
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.modulate.a = TRAP_TILE_ALPHA
			var rect := TextureRect.new()
			rect.texture = trap_texture
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.size = holder.size
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(rect)
			mark = holder
		else:
			# 缺件降级：橙色角块（S1-4 表驱动标记色；E1：定位改菱形下角内侧
			#——原方形角偏移口径在菱形下落于钻石外）
			var corner := ColorRect.new()
			corner.color = _TrapMarkColorOf(cell)
			corner.size = Vector2(TRAP_MARK_SIZE, TRAP_MARK_SIZE)
			corner.position = cell_rect(cell).position \
					+ Vector2(cell_width * 0.5, cell_height * 0.75)
			corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark = corner
		# E1：标记随格深度（树序在徽章后——同格 tie-break 天然压徽章，现状语义）
		mark.z_index = cell.x + cell.y
		mark.set_meta(&"trap_mark", true)
		_EnsureWorldLayer()
		_world_layer.add_child(mark)
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
	## 版面计算（E1 等距重设计）：菱形全宽（界内自适应 + cfg 钳制带）与
	## 全棋盘菱形包围盒居中原点；fit 通式 = 2×size/(span×ratio)（宽向不带
	## ratio、高向带——ratio=0.5 时数值 == 方案 §二简式 4×size/span）；
	## 让位护栏：fit < min 时保适配弃保底（cell_width = fit + push_warning
	## ——720 档已知妥协在案，防「保底压爆版面」）；W_MIN/W_MAX cfg 驱动
	##（UiTheme 兜底——原 CELL_SIZE_MIN/MAX 40-88 方形钳制带退役）
	## 参数：无
	## 返回：无
	var grid_size: Vector2i = context.grid.size
	var span: float = float(grid_size.x + grid_size.y)
	var ratio: float = _IsoRatio()
	var fit_w: float = 2.0 * size.x / span
	var fit_h: float = 2.0 * size.y / (span * ratio)
	var fit: float = minf(fit_w, fit_h)
	var width_min: float = _IsoCellWidthMin()
	if width_min > fit:
		# 让位：小版面下钳制下限会撑爆包围盒——取 fit 保适配（触控面积
		# 妥协在案，warning 提示档位）
		push_warning("BattleBoard: 版面 fit %s 低于菱形全宽下限 %s——让位取 fit（保适配弃保底）" % [
				str(fit), str(width_min)])
		cell_width = maxf(fit, 0.0)
	else:
		cell_width = clampf(fit, width_min, _IsoCellWidthMax())
	# 盲审修复 5（S2-3）：包围盒尺寸单源 _BoardBoxOf（与视口钳制/锚点
	## 推算消费同一实现——内联公式退役）
	var board_box: Vector2 = _BoardBoxOf()
	origin = (size - board_box) * 0.5
	# 视口批：缩放档表按 fit 全宽与钳制上限生成（fit 重建后档表随之重建、
	# 档归 0——fit 态即缩放基准态）
	_zoom_steps = zoom_steps_of(cell_width, _IsoCellWidthMax(), _ZoomStepRatio())
	_zoom_index = 0

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
	## 驱动——UI 只按样式枚举分支，新增状态地格改表零改码）；M6 批 3.5b 组 3：
	## match 前贴图分支——tile.asset_id/asset_variants → pick_variant 稳定哈希
	## 混铺（同格恒定/异格打散）→ AssetTex 在档走 Control 根容器 + 满盒
	## TextureRect 子节点（贴图态 gap=0 无缝）；缺件/空 id 落回色块分支
	##（E1：色块 = 菱形色面 _MakeDiamondFill + 深色菱形描边保格界——
	## 原 ColorRect 方形/CELL_GAP 缝/TILE_INNER_INSET 内缩口径退役）；
	## E1：返回前设等距深度 z = x+y
	## 参数 cell：格坐标；tile：地格定义
	## 返回：视觉根节点
	var visual: Control = null
	if tile == null:
		visual = _MakeCellRect(cell, _TileFallbackColor())
	else:
		var tile_texture: Texture2D = _TileTextureOf(cell, tile)
		if tile_texture != null:
			visual = _MakeTexturedCell(cell, tile_texture)
		else:
			visual = _MakeDegradedCell(cell, tile)
	visual.z_index = cell.x + cell.y
	return visual

func _MakeDegradedCell(cell: Vector2i, tile: TileTypeDef) -> Control:
	## 色块降级地格（E1：TileTypeDef.Style 分支保留——菱形母题内缩形态）
	## 参数 cell：格坐标；tile：地格定义
	## 返回：视觉根节点（已挂树）
	match tile.style:
		TileTypeDef.Style.BLOCK:
			# 障碍岩块：底色菱形 + 深色内缩母题（darkened 同原式）+ 强调色描边
			var rect := _MakeCellRect(cell, tile.fill_color)
			rect.add_child(_MakeInnerDiamond(tile.fill_color.darkened(0.3),
					tile.accent_color))
			return rect
		TileTypeDef.Style.RAISED:
			# 平台凸边：外层底色 + 内层强调色内缩母题双层
			var raised := _MakeCellRect(cell, tile.fill_color)
			raised.add_child(_MakeInnerDiamond(tile.accent_color, Color(0, 0, 0, 0)))
			return raised
		_:
			# PLAIN：平色菱形（格界描边）
			return _MakeCellRect(cell, tile.fill_color)

func _MakeInnerDiamond(fill: Color, border: Color) -> Control:
	## 降级地格内缩母题菱形（E1：BLOCK 内块/RAISED 内层同几何——外层盒
	## × (1−内缩比×2) 居中；挂树由调用方）
	## 参数 fill：内层填充色；border：内层描边色（alpha ≤ 0 无描边）
	## 返回：内层菱形节点（未挂树）
	var inner := _MakeDiamondFill(fill, border)
	var inner_scale: float = 1.0 - DIAMOND_INNER_INSET_RATIO * 2.0
	inner.size = Vector2(cell_width, cell_height) * inner_scale
	inner.position = Vector2(cell_width, cell_height) * DIAMOND_INNER_INSET_RATIO
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return inner

func _TileTextureOf(cell: Vector2i, tile: TileTypeDef) -> Texture2D:
	## 地格贴理解析（组 3 接线口）：tile 空/asset_id 空 → null（降级信号）；
	## pick_variant 主件+变体按格坐标稳定哈希选取 → AssetTex.texture_of
	##（进程级缓存——逐格解析开销恒定；缺件 null 穿透）
	## 参数 cell：格坐标（哈希种子）；tile：地格定义
	## 返回：贴图；无贴图位/缺件返回 null
	if tile == null or String(tile.asset_id).is_empty():
		return null
	var asset_id: StringName = AssetTex.pick_variant(tile.asset_id,
			tile.asset_variants, cell)
	return AssetTex.texture_of(asset_id, _game_data)

func _MakeTexturedCell(cell: Vector2i, texture: Texture2D) -> Control:
	## 构建贴图态地格视觉（组 3；E1：满**盒**菱形贴图 256×128 STRETCH_SCALE
	## 拉伸至 (cell_width, cell_height)）：Control 根容器（IGNORE——tooltip/
	## mouse_filter 契约与 _ApplyCellTooltip 的色块根同构）+ 满盒 TextureRect
	## 子节点；贴图态 gap=0 无缝（整片战场连贴图）
	## 参数 cell：格坐标；texture：已解析地格贴图
	## 返回：视觉根节点（已挂树）
	var holder := Control.new()
	holder.position = _CellAnchor(cell)
	holder.size = Vector2(cell_width, cell_height)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = holder.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rect)
	_EnsureWorldLayer()
	_world_layer.add_child(holder)
	return holder

func _MakeCellRect(cell: Vector2i, color: Color) -> Control:
	## 构建地格底色菱形面（E1：原 ColorRect 方形+CELL_GAP 缝口径退役——
	## fill 色 + 深色菱形描边保格界辨识；描边色 = fill 深化 0.4 与贴图态
	## 生成器描边同观感）
	## 参数 cell/color：坐标、颜色
	## 返回：菱形色面节点（已挂树）
	var rect: Control = _MakeDiamondFill(color, color.darkened(0.4), DIAMOND_BORDER_WIDTH)
	rect.position = _CellAnchor(cell)
	rect.size = Vector2(cell_width, cell_height)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_EnsureWorldLayer()
	_world_layer.add_child(rect)
	return rect

## 菱形色面节点（E1：Control 子类 _draw draw_polygon 四顶点——顶点单源
## _DiamondPoints 静态函数；缺件回退统一形态：覆盖层填充/高光/地格色块）
class DiamondFill:
	extends Control
	## 填充色
	var fill_color: Color = Color.WHITE
	## 描边色（alpha ≤ 0 无描边）
	var border_color: Color = Color(0, 0, 0, 0)
	## 描边宽（像素）
	var border_width: float = 0.0

	func _draw() -> void:
		## 引擎回调：绘制菱形填充面 + 可选描边（尺寸变化自动重绘——Control
		## resize 触发 redraw）
		## 参数：无
		## 返回：无
		var points: PackedVector2Array = BattleBoard._DiamondPoints(size)
		draw_polygon(points, PackedColorArray([fill_color]))
		if border_color.a > 0.0 and border_width > 0.0:
			points.append(points[0])
			draw_polyline(points, border_color, border_width, true)

static func _DiamondPoints(box: Vector2) -> PackedVector2Array:
	## 盒尺寸 → 菱形四顶点（E1 单源：上/右/下/左——顺时针序；供 DiamondFill
	## 绘制与外部几何消费；数学单源锚点 = E1 方案 §二，与 tools/
	## gen_asset_placeholders.gd _DiamondMask 同构互引）
	## 参数 box：包围盒尺寸 (w, h)
	## 返回：四顶点数组
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(box.x * 0.5, 0.0))
	points.append(Vector2(box.x, box.y * 0.5))
	points.append(Vector2(box.x * 0.5, box.y))
	points.append(Vector2(0.0, box.y * 0.5))
	return points

func _MakeDiamondFill(fill: Color, border: Color = Color(0, 0, 0, 0),
		border_width: float = 0.0) -> Control:
	## 构建菱形色面节点（不挂树由调用方挂入——覆盖层/高光/地格共用）
	## 参数 fill/border/border_width：填充色、描边色（alpha ≤ 0 无描边）、描边宽
	## 返回：DiamondFill 节点
	var diamond := DiamondFill.new()
	diamond.fill_color = fill
	diamond.border_color = border
	diamond.border_width = border_width
	return diamond

func _BuildBadges() -> void:
	## 单位徽章池（M6：六动作竖条经 SpriteResolver.anim_texture_of 解析装配；
	## 单条竖条进程级缓存复用——逐动作解析一次）
	## 参数：无
	## 返回：无
	for unit: BattleUnit in context.units:
		var badge := UnitBadge.new()
		var sprite_id: StringName = SpriteResolver.sprite_id_of(unit, _game_data)
		var anim_textures: Dictionary = {}
		for action: int in UnitAnimState.Action.size():
			var strip: Texture2D = SpriteResolver.anim_texture_of(sprite_id,
					action, _game_data)
			if strip != null:
				anim_textures[action] = strip
		badge.setup(unit, cell_width, context.cfg, anim_textures, _game_data)
		badge.position = _CellAnchor(unit.grid_pos)
		_UpdateBadgeDepth(badge, unit.grid_pos)
		_EnsureWorldLayer()
		_world_layer.add_child(badge)
		_badges[unit.unit_id] = badge

func _ShowOverlay(cells: Array[Vector2i], color: Color, pool: Array[Control],
		border_color: Color = Color(0, 0, 0, 0), border_width: float = OVERLAY_BORDER_WIDTH) -> void:
	## 覆盖层画制（清池重画；每格容器 = 菱形填充面）；挂覆盖层专用容器——
	## 层级见 _overlay_layer 注；M6 批 3.5b 组 8：fx_battle_range 在档 →
	## 填充块 TextureRect + modulate=填充色（E1：菱形染色态——贴图自带菱形
	## 描边，移动范围染蓝/技能范围染红，α 语义随 cfg 色不变）；缺件回退
	## 菱形色面（E1：原 ColorRect 方形回退与程序四边框带退役——方形元素
	## 越菱形界；border_color/border_width 签名保留兼容、不再消费）
	## 参数 cells/color/pool/border_color/border_width：格列表、填充色、目标池、
	## 边框色（退役不消费）、边框条宽（退役不消费）
	## 返回：无
	_ClearOverlay(pool)
	_EnsureOverlayLayer()
	var range_texture: Texture2D = AssetTex.texture_of(RANGE_OVERLAY_ASSET_ID,
			_game_data)
	for cell: Vector2i in cells:
		var holder := Control.new()
		holder.position = _CellAnchor(cell)
		holder.size = Vector2(cell_width, cell_height)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if range_texture != null:
			# 贴图染色态：贴图 + modulate = 填充色（α 随色——淡填充语义不变）
			var fill_tex := TextureRect.new()
			fill_tex.texture = range_texture
			fill_tex.modulate = color
			fill_tex.stretch_mode = TextureRect.STRETCH_SCALE
			fill_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			fill_tex.size = holder.size
			fill_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(fill_tex)
		else:
			var fill := _MakeDiamondFill(color)
			fill.size = holder.size
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(fill)
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
	# E1：覆盖层容器恒压一切格/徽章深度（z = x+y ≤ 22 < Z_OVERLAY）
	_overlay_layer.z_index = Z_OVERLAY
	# 视口批：挂 _world_layer（缩放/平移随视口同步——覆盖层贴棋盘世界）
	_EnsureWorldLayer()
	_world_layer.add_child(_overlay_layer)

func _ShowBlockedOverlay(cells: Array[Vector2i], pool: Array[Control]) -> void:
	## 视线阻断格渲染（十四轮反馈）：极淡灰菱形填充 + 中心 45° 斜杠
	##（ColorRect 旋转组合；E1：长度系数按 cell_width 复核 = 0.45 全宽——
	## 2:1 菱形内 45° 可容全长 ≈ 0.471w，方形边框带退役）；holder 带
	## &"los_blocked" 元标记（测试/调试契约）
	## 参数 cells/pool：格列表、目标池
	## 返回：无
	_EnsureOverlayLayer()
	for cell: Vector2i in cells:
		var holder := Control.new()
		holder.position = _CellAnchor(cell)
		holder.size = Vector2(cell_width, cell_height)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_meta(&"los_blocked", true)
		var fill := _MakeDiamondFill(
				_OverlayColor(&"ui_overlay_blocked_fill_color", UiTheme.OVERLAY_BLOCKED_FILL))
		fill.size = holder.size
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(fill)
		# 中心斜杠（绕自身中心旋转 45°——长度按菱形全宽比例收窄不越菱形）
		var slash := ColorRect.new()
		slash.color = _OverlayColor(&"ui_overlay_blocked_slash_color", UiTheme.OVERLAY_BLOCKED_SLASH)
		slash.size = Vector2(cell_width * BLOCKED_SLASH_LENGTH_RATIO, BLOCKED_SLASH_WIDTH)
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
	# R1-05 防御：未装配上下文早退（与 cell_from_local 哨兵守卫同式——
	# 降级路径直调不崩）
	if context == null or context.grid == null:
		return
	var tile: TileTypeDef = context.grid.tile_at(cell)
	if tile == null or tile.kind == TileTypeDef.Kind.NORMAL:
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.tooltip_text = ""
		return
	visual.mouse_filter = Control.MOUSE_FILTER_PASS
	visual.tooltip_text = "%s\n%s" % [tile.display_name, tile.description]

# --------------------------------------------------------------------------
# 视口交互（视口批：滚轮缩放 + 中键拖动平移——WorldLayer 两属性变换，
# 棋盘内部坐标零感知）
# --------------------------------------------------------------------------

static func zoom_steps_of(base_width: float, max_width: float,
		step_ratio: float) -> Array[float]:
	## 缩放档表生成（视口批纯函数）：zoom_max = max_width/base_width
	##（base ≤ 钳制上限保证 zoom_max ≥ 1）；从 1.0 逐档 ×(1+step_ratio)
	## 直至 ≥ zoom_max，末档取 zoom_max 截断；末档与前档差 <
	## UiTheme.ZOOM_MIN_STEP_GAP（R1-02：常量 UiTheme 单源）丢弃前档
	##（无感档不占位——首档 1.0/末档 zoom_max 为结构位恒保留，两档表不丢
	## 防「fit 档被吞」）；非法入参（base/ratio ≤ 0）与 zoom_max ≤ 1 均返回
	## [1.0] 单档（zoom_max == 1 为合法已知行为——钳制上限 == fit）
	## 参数 base_width：fit 态菱形全宽；max_width：钳制带上限；
	## step_ratio：档距比
	## 返回：缩放档表（首档恒 1.0）
	if base_width <= 0.0 or step_ratio <= 0.0:
		return [1.0]
	var zoom_max: float = max_width / base_width
	if zoom_max <= 1.0:
		return [1.0]
	var steps: Array[float] = []
	var current: float = 1.0
	while current < zoom_max:
		steps.append(current)
		current *= 1.0 + step_ratio
	steps.append(zoom_max)
	if steps.size() > 2 \
			and zoom_max - steps[steps.size() - 2] < UiTheme.ZOOM_MIN_STEP_GAP:
		steps.remove_at(steps.size() - 2)
	return steps

static func zoom_position_for_anchor(p0: Vector2, z0: float, z1: float,
		anchor: Vector2) -> Vector2:
	## 锚点缩放平移推算（视口批纯函数）：p1 = anchor − (anchor − p0) × z1/z0
	##——锚点（板层本地坐标）处的棋盘内容缩放前后视觉位置不动；贴边
	## 钳制由调用方组合 clamp_viewport_position（本函数只承载数学单源）；
	## 非法 z（≤ 0）防御返回 p0 原样（档表值恒 ≥ 1，护栏）
	## 参数 p0：缩放前平移位；z0/z1：缩放前后档值；anchor：锚点（板层本地）
	## 返回：缩放后平移位
	if z0 <= 0.0 or z1 <= 0.0:
		return p0
	return anchor - (anchor - p0) * (z1 / z0)

static func clamp_viewport_position(origin: Vector2, board_box: Vector2,
		layer_size: Vector2, zoom: float, pos: Vector2) -> Vector2:
	## 平移位贴边钳制（视口批纯函数）：逐轴判溢出（board_box.axis × zoom >
	## layer_size.axis——缩放后内容大于视口，平移语义 = 内容覆盖视口不露
	## 板外空白）——溢出轴 clampf 到贴边带 [layer_size − (origin+board_box)
	## ×zoom, −origin×zoom]（下界 = 内容右缘贴板右缘 / 上界 = 内容左缘贴
	## 板左缘；带序自洽：溢出 ⇔ 下界 ≤ 上界——方案原文两界序颠倒系笔误，
	## 按「包围盒边对齐」几何语义自洽序实现）；无溢出轴强制 0（fit 回正
	## 口径——缩回 0 档 pan 自然归零，无专门复位路径）；zoom ≤ 0 防御
	## 返回 pos 原样
	## 参数 origin：棋盘包围盒居中原点（_BuildLayout 口径）；board_box：
	## 包围盒尺寸；layer_size：视口层尺寸（== 板面尺寸）；zoom：当前档值；
	## pos：待钳制平移位
	## 返回：钳制后平移位
	if zoom <= 0.0:
		return pos
	var clamped: Vector2 = pos
	if board_box.x * zoom > layer_size.x:
		clamped.x = clampf(pos.x, layer_size.x - (origin.x + board_box.x) * zoom,
				-origin.x * zoom)
	else:
		clamped.x = 0.0
	if board_box.y * zoom > layer_size.y:
		clamped.y = clampf(pos.y, layer_size.y - (origin.y + board_box.y) * zoom,
				-origin.y * zoom)
	else:
		clamped.y = 0.0
	return clamped

func _BoardBoxOf() -> Vector2:
	## 全棋盘菱形包围盒尺寸（span × cell 尺寸 × 0.5——钳制/锚点推算与
	## _BuildLayout 居中原点共四消费点单源，盲审修复 5）
	## 参数：无
	## 返回：包围盒尺寸（无装配返回 ZERO）
	if context == null or context.grid == null:
		return Vector2.ZERO
	var span: float = float(context.grid.size.x + context.grid.size.y)
	return Vector2(span * cell_width * 0.5, span * cell_height * 0.5)

func _EnsureWorldLayer() -> void:
	## 懒建视口中间层（FULL_RECT IGNORE——尺寸恒 == 板区随锚点自动跟随；
	## z=0 显式设定；_overlay_layer 懒建先例同式，幂等）
	## 参数：无
	## 返回：无
	if _world_layer != null and is_instance_valid(_world_layer):
		return
	_world_layer = Control.new()
	_world_layer.name = "WorldLayer"
	_world_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_layer.z_index = 0
	add_child(_world_layer)

func _KillZoomTween() -> void:
	## 终止在途缩放 tween（重缩放/拖动激活/resize 重置三入口统一）
	## 参数：无
	## 返回：无
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = null

func _ResetViewportState() -> void:
	## 视口态全复位（resize 重建最前调用）：kill 在途缩放 tween、档归 0、
	## world 变换归位、平移目标清零、拖动四态复位 + 激活中的拖动态表现
	## 恢复（tooltip/光标——未激活过的轻点无表现无需恢复）
	## 参数：无
	## 返回：无
	_KillZoomTween()
	_zoom_index = 0
	if _world_layer != null and is_instance_valid(_world_layer):
		_world_layer.scale = Vector2.ONE
		_world_layer.position = Vector2.ZERO
	_view_pan_target = Vector2.ZERO
	var was_active: bool = _pan_active
	_pan_pending = false
	_pan_active = false
	if was_active:
		_ExitPanVisuals()

func viewport_zoom_step(delta: int, anchor_board_pos: Vector2) -> void:
	## 缩放步进（滚轮公开口——battle_screen 滚轮分支唯一消费）：拖动态
	## 早退（盲审修复 1【用户拍板 a】：拖动中禁缩放——拖动位移与锚点推算
	## 互踩的竞态最简收口，松手后可再缩放）；未装配/未建视口层/档表空
	## 早退（降级路径零风险）；新档 clampi 越界早退（触顶/触底无效滚动）；
	## 锚点推算一律取目标态（档表值与 _view_pan_target——非 tween 中间值，
	## 连续滚动可叠加）；新平移位贴边钳制；kill 在途 _zoom_tween 后按
	## _ZoomSeconds() 瞬跳直落或 SINE/OUT 并行插值 scale/position；更新档下标
	## 参数 delta：步进方向（+1 放大 / -1 缩小）；anchor_board_pos：锚点
	##（板层本地坐标——该点处棋盘内容缩放前后视觉不动）
	## 返回：无
	if _pan_active:
		return
	if context == null or context.grid == null:
		return
	if _world_layer == null or not is_instance_valid(_world_layer):
		return
	if _zoom_steps.is_empty():
		return
	var new_index: int = clampi(_zoom_index + delta, 0, _zoom_steps.size() - 1)
	if new_index == _zoom_index:
		return
	var z0: float = _zoom_steps[_zoom_index]
	var z1: float = _zoom_steps[new_index]
	_view_pan_target = zoom_position_for_anchor(_view_pan_target, z0, z1,
			anchor_board_pos)
	# 贴边钳制（缩回 0 档两轴无溢出时 pan 自然归 0——fit 回正）
	_view_pan_target = clamp_viewport_position(origin, _BoardBoxOf(), size,
			z1, _view_pan_target)
	_KillZoomTween()
	_zoom_index = new_index
	var seconds: float = _ZoomSeconds()
	if seconds <= 0.0:
		_world_layer.scale = Vector2(z1, z1)
		_world_layer.position = _view_pan_target
		return
	_zoom_tween = create_tween()
	_zoom_tween.set_parallel(true)
	_zoom_tween.tween_property(_world_layer, "scale", Vector2(z1, z1), seconds) \
			.set_trans(Tween.TransitionType.TRANS_SINE) \
			.set_ease(Tween.EaseType.EASE_OUT)
	_zoom_tween.tween_property(_world_layer, "position", _view_pan_target, seconds) \
			.set_trans(Tween.TransitionType.TRANS_SINE) \
			.set_ease(Tween.EaseType.EASE_OUT)

func viewport_begin_pan(board_pos: Vector2) -> void:
	## 平移开始（中键按下公开口）：记按下位与当前目标平移位快照、置待激活
	## 标记；未建视口层早退（降级路径零风险）；激活判定在 _process 轮询
	##（位移过 PAN_DRAG_THRESHOLD 才激活——轻点吞格防护）
	## 参数 board_pos：板层本地坐标（gui_input event.position）
	## 返回：无
	if _world_layer == null or not is_instance_valid(_world_layer):
		return
	_pan_press_pos = board_pos
	_pan_start_pos = _view_pan_target
	_pan_pending = true
	_pan_active = false

func viewport_end_pan() -> void:
	## 平移结束（中键 release 公开口——gui_input 直收或 _process 轮询兜底，
	## 幂等）：清四态；激活过的拖动态表现经单源恢复（tooltip/光标）
	## 参数：无
	## 返回：无
	var was_active: bool = _pan_active
	_pan_pending = false
	_pan_active = false
	if was_active:
		_ExitPanVisuals()

func viewport_is_panning() -> bool:
	## 平移进行中查询（battle_screen LEFT 选格链守卫消费——拖动态吞左键
	## 点按防误选）
	## 参数：无
	## 返回：true = 待激活或拖动激活中
	return _pan_pending or _pan_active

func _ActivatePan() -> void:
	## 平移拖动激活（位移过阈值——私有口，_process 消费）：kill 在途缩放
	## tween 并把 scale/position 直落当前目标档值（终态即视觉——中断缩放
	## 无残留中间态）；进入拖动态表现（格 tooltip/命中抑制 + 移动光标）；
	## 盲审修复 2（S2-2）：激活时以当前目标位重锚增量基准——pending 期间
	## 滚轮仍可改 _view_pan_target（修复 1 只挡 active 态），拖动位移须从
	## 激活瞬间的终态起算，否则首帧出现基准跳变
	## 参数：无
	## 返回：无
	if _world_layer == null or not is_instance_valid(_world_layer):
		return
	_KillZoomTween()
	var zoom_now: float = _zoom_steps[_zoom_index] \
			if _zoom_index < _zoom_steps.size() else 1.0
	_world_layer.scale = Vector2(zoom_now, zoom_now)
	_world_layer.position = _view_pan_target
	_pan_pending = false
	_pan_active = true
	_pan_start_pos = _view_pan_target
	for cell: Vector2i in _cells:
		var visual: Control = _cells.get(cell, null)
		if visual != null:
			# 拖动态格不参与命中/hover（拖动中误弹 tooltip 打断手感；
			# 松手经 _ApplyAllCellTooltips 单源全量重算恢复）
			visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			visual.tooltip_text = ""
	mouse_default_cursor_shape = Control.CURSOR_MOVE

func _ExitPanVisuals() -> void:
	## 拖动态表现恢复（松手/视口重置——仅激活过时调）：tooltip 经单源
	## _ApplyAllCellTooltips 全量重算、光标回默认
	## 参数：无
	## 返回：无
	_ApplyAllCellTooltips()
	mouse_default_cursor_shape = Control.CURSOR_ARROW

func cell_from_board_local(board_pos: Vector2) -> Vector2i:
	## 板层本地坐标 → 格坐标（视口态逆变换公开口——battle_screen 点击
	## 命中唯一生产消费点）：world_local = (board_local − world.position)/zoom
	##（无旋转），再走现行 cell_from_local（严格零改）；未建视口层
	##（降级/装配前）直透 cell_from_local；zoom ≤ 0 防御早退返回界外哨兵
	##（口径同 cell_from_local 越界返回）
	## 参数 board_pos：BoardLayer 本地坐标（gui_input event.position）
	## 返回：格坐标
	if _world_layer == null or not is_instance_valid(_world_layer):
		return cell_from_local(board_pos)
	var zoom: float = _world_layer.scale.x
	if zoom <= 0.0:
		return Vector2i(-1, -1)
	return cell_from_local((board_pos - _world_layer.position) / zoom)
