## 战斗日志卷轴（BattleLogScroller，Control——战斗屏全屏浮层）
## 职责：布局三改批「日志卷轴化」——右栏退役，日志改右上锚点条 + 点击
## 展开/收起浮层：收起态仅锚点热区命中（根 IGNORE 棋盘零遮挡；新条目计
## 未读、未读 > 0 锚点文案染 badge 色）；展开态浮层压棋盘 tips/飘字
##（z = Z_LOG_OVERLAY 300）、面板内滚动读日志、点外不收起（无 outside
## 关闭逻辑——拍板口径）；敌方轮锚点条切提示语（拍板 C 文案单源自
## battle_screen 迁入本组件）、我方轮/终局恢复；resize 跟随重算（板区高
## 变化 → 展开钳制公式重算 + kill 在途 tween，锚点条右上锚定静态 offset
## 免重算）。展开几何 = cfg ui_battle_log_* 十键表驱动（UiTheme
## BATTLE_LOG_* 兜底、值域外回退）；未读计数单源 = BattleLog 条目容器
## child_entered_tree（不订 controller 信号，与日志渲染解耦）。
## 输入口径：仅锚点 HitArea STOP + 展开 ExpandPanel STOP，其余全穿透；
## 不新增项目级信号；降级路径（无参直开不调 setup）卷轴存在保持收起、
## cfg 读取口 null 回退——不遮任何节点。
class_name BattleLogScroller
extends Control

## 卷轴浮层 z_index（结构契约：压棋盘 tips/飘字 BattleBoard.Z_TEXT=200、
## 被 ResultLayer z=400 压——与 BattleBoard.Z_OVERLAY/Z_TEXT 同先例不入 cfg）
const Z_LOG_OVERLAY: int = 300
## 展开面板顶与锚点条下缘间距（像素——结构常量，方案钳制公式定值 8px）
const EXPAND_TOP_GAP: float = 8.0
## 板区底保留高（像素——镜像 tscn BoardLayer offset_bottom=-84 按钮行区；
## 展开钳制公式的 board_h = 屏高 − 本值）
const BOARD_BOTTOM_RESERVE: float = 84.0

## UI 文案单源（改措辞只动此处；enemy_turn_hint 自 battle_screen.UI_TEXTS
## 迁入——布局三改批敌方提示并入锚点条）
const UI_TEXTS: Dictionary = {
	&"anchor_label_format": "战斗日志 (%d)",
	&"enemy_turn_hint": "敌方行动中…（点按战场可跳过演出）",
}

## 托管日志面板（setup 注入；未注入 = 降级态锚点可用、无未读接线）
var _battle_log: BattleLog = null
## 总控配置（几何参数读取；null = UiTheme 兜底模式）
var _cfg: CoreConfig = null
## GameData（深底面板九宫格贴图解析；null = 缺件降级 StyleBoxFlat）
var _game_data: Node = null
## 展开逻辑态（true = 展开目标态；收起回落 tween 在途仍记 false）
var _is_expanded: bool = false
## 未读计数（收起态新条目累计；展开清零、收起不清）
var _unread_count: int = 0
## 敌方提示激活态（锚点三态文案分派）
var _enemy_hint_active: bool = false
## 在途展开/收起 tween（新动作/resize 先 kill 防插值竞态）
var _toggle_tween: Tween = null
## 展开面板顶 offset（_RecalcLayout 缓存——tween 插值/回落目标基准）
var _expand_top: float = 48.0
## 展开面板高（_RecalcLayout 缓存——钳制公式结果）
var _expand_height: float = 240.0

## 锚点热区（收起态唯一命中区——gui_input 挂此）
var _hit_area: Control = null
## 锚点条（深底面板横条——视觉 150×28 居中命中垫内）
var _anchor_bar: PanelContainer = null
## 锚点文案（三态：敌方提示语 / 未读计数 / 零未读）
var _anchor_label: Label = null
## 展开面板（日志浮层——默认 invisible，展开 STOP 命中）
var _expand_panel: PanelContainer = null

func _ready() -> void:
	## 引擎回调：取子节点引用 + 锚点输入/尺寸监听挂接 + 深底样式与字号
	## 占位（B-4/B-7 兜底态）+ 布局初算（首帧零尺寸由后续 resized 修正）
	## 参数：无
	## 返回：无
	_hit_area = get_node("HitArea") as Control
	_anchor_bar = get_node("HitArea/AnchorBar") as PanelContainer
	_anchor_label = get_node("HitArea/AnchorBar/AnchorLabel") as Label
	_expand_panel = get_node("ExpandPanel") as PanelContainer
	_hit_area.gui_input.connect(_OnHitAreaInput)
	resized.connect(_RecalcLayout)
	_ApplyStyle()
	_RecalcLayout()
	_RefreshAnchorText()

func setup(scroller_log: BattleLog, cfg: CoreConfig = null,
		game_data: Node = null) -> void:
	## 装配（battle_screen 有参路径调用）：托管日志 + cfg/game_data 注入 +
	## 未读计数接线（单源 = 日志条目容器 child_entered_tree——不订 controller
	## 信号，日志渲染与计数解耦；重复 setup 不重复连接）
	## 参数 scroller_log：战斗日志面板；cfg：总控配置（可空）；
	## game_data：GameData（可空）
	## 返回：无
	_battle_log = scroller_log
	apply_cfg(cfg, game_data)
	var entries: VBoxContainer = _battle_log.get_entries()
	if entries != null and not entries.child_entered_tree.is_connected(_OnLogLineAdded):
		entries.child_entered_tree.connect(_OnLogLineAdded)

func apply_cfg(cfg: CoreConfig, game_data: Node = null) -> void:
	## cfg 注入 / 热更新：几何读取口即时反映（样式重建 + 布局重算 + 锚点
	## 文案刷新——R3-01：_ready 期 cfg 未注入走兜底，setup 后按表值生效）
	## 参数 cfg：总控配置（可空 = 兜底模式）；game_data：GameData（可空 =
	## 保留既有注入）
	## 返回：无
	_cfg = cfg
	if game_data != null:
		_game_data = game_data
	_ApplyStyle()
	_RecalcLayout()
	_RefreshAnchorText()

func set_enemy_hint_active(active: bool) -> void:
	## 敌方轮提示切换（battle_screen turn_started/battle_ended 消费）：
	## active = 锚点条显提示语；false = 恢复「战斗日志 (N)」
	## 参数 active：敌方轮标记
	## 返回：无
	if _enemy_hint_active == active:
		return
	_enemy_hint_active = active
	_RefreshAnchorText()

func toggle_expanded() -> void:
	## 展开/收起切换（锚点点击入口——薄转发）
	## 参数：无
	## 返回：无
	set_expanded(not _is_expanded)

func set_expanded(open: bool) -> void:
	## 展开/收起（tween 插值 offset_bottom：TRANS_SINE/EASE_OUT、时长 cfg
	## 驱动（0 = 即时无动画）；展开即清未读；收起回落完成回调 visible=false；
	## 展开态点外不收起——无 outside 关闭逻辑；在途 tween 先 kill）
	## 参数 open：true = 展开
	## 返回：无
	if open == _is_expanded:
		return
	_is_expanded = open
	_KillToggleTween()
	var seconds: float = _ToggleSeconds()
	if open:
		_unread_count = 0
		_RefreshAnchorText()
		_expand_panel.visible = true
		if seconds <= 0.0:
			_expand_panel.offset_bottom = _expand_top + _expand_height
			return
		_expand_panel.offset_bottom = _expand_top
		_toggle_tween = create_tween()
		_toggle_tween.tween_property(_expand_panel, "offset_bottom",
				_expand_top + _expand_height, seconds) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		if seconds <= 0.0:
			_expand_panel.offset_bottom = _expand_top
			_expand_panel.visible = false
			return
		_toggle_tween = create_tween()
		_toggle_tween.tween_property(_expand_panel, "offset_bottom",
				_expand_top, seconds) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_toggle_tween.finished.connect(func() -> void:
			_expand_panel.visible = false)

func is_expanded() -> bool:
	## 展开态查询（逻辑目标态——测试与宿主消费）
	## 参数：无
	## 返回：true = 展开
	return _is_expanded

func get_unread_count() -> int:
	## 未读计数查询（测试与宿主消费；展开清零、收起不清）
	## 参数：无
	## 返回：未读条数
	return _unread_count

func _RecalcLayout() -> void:
	## 布局重算（resize 跟随 / cfg 变更 / 初帧）：锚点热区右上锚定静态
	## offset（热区 = max(锚点视觉, 触控下限)，视觉条居中命中垫内——随屏
	## 尺寸免重算）；展开面板 rect 按钳制公式（右缘 = 屏宽 − 锚点边距 −
	## 展开边距、顶 = 锚点下缘 + 8、高 = 钳制公式）；在途 tween 先 kill；
	## 已展开态直接落位新 rect，已收起态强制闭落位（kill 中途回落不留半开）
	## 参数：无
	## 返回：无
	_KillToggleTween()
	var anchor_w: float = _AnchorWidth()
	var anchor_h: float = _AnchorHeight()
	var hit_min: float = _HitMinSize()
	var anchor_margin: float = _AnchorMargin()
	var hit_w: float = maxf(anchor_w, hit_min)
	var hit_h: float = maxf(anchor_h, hit_min)
	# 锚点热区（右上锚定——静态 offset，窗口尺寸变化由锚点自动跟随）
	_hit_area.anchor_left = 1.0
	_hit_area.anchor_right = 1.0
	_hit_area.anchor_top = 0.0
	_hit_area.anchor_bottom = 0.0
	_hit_area.offset_left = -(anchor_margin + hit_w)
	_hit_area.offset_top = anchor_margin
	_hit_area.offset_right = -anchor_margin
	_hit_area.offset_bottom = anchor_margin + hit_h
	# 锚点条：热区内满锚 + 居中差分 offset（视觉横条居中命中垫内）
	_anchor_bar.anchor_left = 0.0
	_anchor_bar.anchor_right = 1.0
	_anchor_bar.anchor_top = 0.0
	_anchor_bar.anchor_bottom = 1.0
	_anchor_bar.offset_left = (hit_w - anchor_w) * 0.5
	_anchor_bar.offset_right = -(hit_w - anchor_w) * 0.5
	_anchor_bar.offset_top = (hit_h - anchor_h) * 0.5
	_anchor_bar.offset_bottom = -(hit_h - anchor_h) * 0.5
	_anchor_bar.custom_minimum_size = Vector2(anchor_w, anchor_h)
	# 展开面板（右上锚定 + 钳制公式——唯一随屏高重算的量）
	var expand_w: float = _ExpandWidth()
	var expand_margin: float = _ExpandMargin()
	_expand_height = _ExpandHeightOf(size)
	_expand_top = anchor_margin + anchor_h + EXPAND_TOP_GAP
	_expand_panel.anchor_left = 1.0
	_expand_panel.anchor_right = 1.0
	_expand_panel.anchor_top = 0.0
	_expand_panel.anchor_bottom = 0.0
	_expand_panel.offset_right = -(anchor_margin + expand_margin)
	_expand_panel.offset_left = -(anchor_margin + expand_margin + expand_w)
	_expand_panel.offset_top = _expand_top
	_expand_panel.offset_bottom = _expand_top + _expand_height
	if _is_expanded:
		_expand_panel.visible = true
	else:
		_expand_panel.offset_bottom = _expand_top
		_expand_panel.visible = false

func _ExpandHeightOf(scroller_size: Vector2) -> float:
	## 展开高钳制公式（方案 §卷轴组件——纯函数口径便于测试复算）：
	## board_h = 屏高 − 按钮行区 → clamp(board_h × 高比, 最小高,
	## board_h − 锚点下缘 − 展开边距)；上限不足时最小高兜底（极矮窗 450 档
	## → 240）
	## 参数 scroller_size：卷轴当前尺寸（全屏锚定 = 战斗屏尺寸）
	## 返回：展开面板高（像素）
	var board_h: float = scroller_size.y - BOARD_BOTTOM_RESERVE
	var anchor_bottom_y: float = _AnchorMargin() + _AnchorHeight()
	var max_h: float = board_h - anchor_bottom_y - _ExpandMargin()
	return clampf(board_h * _ExpandHeightRatio(), _ExpandMinHeight(), max_h)

func _ApplyStyle() -> void:
	## 深底面板样式 + 锚点字号档（B-4 单源 make_dark_panel_style / B-7 minor
	## 档——cfg 未注入走兜底，setup 注入后按表值重建）
	## 参数：无
	## 返回：无
	_anchor_bar.add_theme_stylebox_override("panel",
			UiTheme.make_dark_panel_style(_cfg, _game_data))
	_expand_panel.add_theme_stylebox_override("panel",
			UiTheme.make_dark_panel_style(_cfg, _game_data))
	_anchor_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_minor", UiTheme.FONT_MINOR))

func _OnHitAreaInput(event: InputEvent) -> void:
	## 锚点热区输入（gui_input 挂 HitArea）：左键点按 → 展开/收起切换
	## 参数 event：输入事件
	## 返回：无
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		toggle_expanded()

func _OnLogLineAdded(_node: Node) -> void:
	## 日志新条目（未读计数单源）：仅收起态累计 +1（展开态实时可视不计）；
	## 展开清零、收起不清
	## 参数 _node：新条目节点（不消费）
	## 返回：无
	if _is_expanded:
		return
	_unread_count += 1
	_RefreshAnchorText()

func _RefreshAnchorText() -> void:
	## 锚点文案三态分派：敌方提示语（提示态）/「战斗日志 (N)」（常态——
	## N = 未读计数）；未读 > 0 染 badge 色（cfg 表驱动），否则还原默认色
	## 参数：无
	## 返回：无
	if _enemy_hint_active:
		_anchor_label.text = UI_TEXTS[&"enemy_turn_hint"]
		_anchor_label.remove_theme_color_override("font_color")
		return
	_anchor_label.text = UI_TEXTS[&"anchor_label_format"] % _unread_count
	if _unread_count > 0:
		_anchor_label.add_theme_color_override("font_color", _BadgeColor())
	else:
		_anchor_label.remove_theme_color_override("font_color")

func _KillToggleTween() -> void:
	## 在途展开/收起 tween 终止（新动作/resize 前调用——防对旧目标继续插值）
	## 参数：无
	## 返回：无
	if _toggle_tween != null and _toggle_tween.is_valid():
		_toggle_tween.kill()
	_toggle_tween = null

# ---- cfg 读取口（cfg 优先、UiTheme 兜底、值域外回退——_IsoRatio 同模式）----

func _AnchorWidth() -> float:
	## 锚点条视觉宽（cfg 优先；值域 [96,280] 外回退兜底）
	## 参数：无
	## 返回：生效宽（像素）
	var raw: float = UiTheme.BATTLE_LOG_ANCHOR_WIDTH
	if _cfg != null:
		raw = _cfg.ui_battle_log_anchor_width
	if raw < 96.0 or raw > 280.0:
		return UiTheme.BATTLE_LOG_ANCHOR_WIDTH
	return raw

func _AnchorHeight() -> float:
	## 锚点条视觉高（cfg 优先；值域 [20,48] 外回退兜底）
	## 参数：无
	## 返回：生效高（像素）
	var raw: float = UiTheme.BATTLE_LOG_ANCHOR_HEIGHT
	if _cfg != null:
		raw = _cfg.ui_battle_log_anchor_height
	if raw < 20.0 or raw > 48.0:
		return UiTheme.BATTLE_LOG_ANCHOR_HEIGHT
	return raw

func _AnchorMargin() -> float:
	## 锚点条距屏右上角边距（cfg 优先；值域 [0,64] 外回退兜底）
	## 参数：无
	## 返回：生效边距（像素）
	var raw: float = UiTheme.BATTLE_LOG_ANCHOR_MARGIN
	if _cfg != null:
		raw = _cfg.ui_battle_log_anchor_margin
	if raw < 0.0 or raw > 64.0:
		return UiTheme.BATTLE_LOG_ANCHOR_MARGIN
	return raw

func _HitMinSize() -> float:
	## 锚点热区最小边长（cfg 优先；值域 [48,96] 外回退兜底——触控硬条款）
	## 参数：无
	## 返回：生效下限（像素）
	var raw: float = UiTheme.BATTLE_LOG_HIT_MIN
	if _cfg != null:
		raw = _cfg.ui_battle_log_hit_min_size
	if raw < 48.0 or raw > 96.0:
		return UiTheme.BATTLE_LOG_HIT_MIN
	return raw

func _ExpandWidth() -> float:
	## 展开面板宽（cfg 优先；值域 [240,480] 外回退兜底）
	## 参数：无
	## 返回：生效宽（像素）
	var raw: float = UiTheme.BATTLE_LOG_EXPAND_WIDTH
	if _cfg != null:
		raw = _cfg.ui_battle_log_expand_width
	if raw < 240.0 or raw > 480.0:
		return UiTheme.BATTLE_LOG_EXPAND_WIDTH
	return raw

func _ExpandHeightRatio() -> float:
	## 展开面板高占板区高比（cfg 优先；值域 [0.3,0.9] 外回退兜底）
	## 参数：无
	## 返回：生效比例
	var raw: float = UiTheme.BATTLE_LOG_EXPAND_HEIGHT_RATIO
	if _cfg != null:
		raw = _cfg.ui_battle_log_expand_height_ratio
	if raw < 0.3 or raw > 0.9:
		return UiTheme.BATTLE_LOG_EXPAND_HEIGHT_RATIO
	return raw

func _ExpandMinHeight() -> float:
	## 展开面板最小高（cfg 优先；值域 [160,480] 外回退兜底）
	## 参数：无
	## 返回：生效最小高（像素）
	var raw: float = UiTheme.BATTLE_LOG_EXPAND_MIN_HEIGHT
	if _cfg != null:
		raw = _cfg.ui_battle_log_expand_min_height
	if raw < 160.0 or raw > 480.0:
		return UiTheme.BATTLE_LOG_EXPAND_MIN_HEIGHT
	return raw

func _ExpandMargin() -> float:
	## 展开面板与屏缘边距（cfg 优先；值域 [0,64] 外回退兜底）
	## 参数：无
	## 返回：生效边距（像素）
	var raw: float = UiTheme.BATTLE_LOG_EXPAND_MARGIN
	if _cfg != null:
		raw = _cfg.ui_battle_log_expand_margin
	if raw < 0.0 or raw > 64.0:
		return UiTheme.BATTLE_LOG_EXPAND_MARGIN
	return raw

func _ToggleSeconds() -> float:
	## 展开/收起动画时长（cfg 优先；值域 [0,1] 外回退兜底；0 = 即时——
	## 表侧显式 0 合法、未回填 0 哨兵同走即时口径）
	## 参数：无
	## 返回：生效时长（秒）
	var raw: float = UiTheme.BATTLE_LOG_TOGGLE_SECONDS
	if _cfg != null:
		raw = _cfg.ui_battle_log_toggle_seconds
	if raw < 0.0 or raw > 1.0:
		return UiTheme.BATTLE_LOG_TOGGLE_SECONDS
	return raw

func _BadgeColor() -> Color:
	## 未读 badge 提醒色（cfg 优先——color_of alpha > 0 判回填）
	## 参数：无
	## 返回：生效颜色
	return UiTheme.color_of(_cfg, &"ui_battle_log_badge_color",
			UiTheme.BATTLE_LOG_BADGE)
