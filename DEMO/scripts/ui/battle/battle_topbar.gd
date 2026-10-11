## 战斗屏顶部横条（BattleTopBar，PanelContainer——回合标签+行动序横条容器）
## 职责：顶部横条批——LeftPanel 整树退役后，回合 UI 与行动序上移画面最顶
## 横条：MarginBox 四边距（左 = 回合标签边距 / 右 = 日志锚点条区让位预留）
## + RoundLabel 回合标签 + TurnOrderBar 横排行动序（子节点均在 tscn 内建，
## 本组件只管几何与衬底）；全树纯展示（根与子容器 IGNORE——无命中需求，
## z = 250 只管绘制压序：压棋盘 tips/飘字（200）、被日志卷轴（300）与结算
##（400）压）；clip_contents 兜底极端裁切（DEMO 8 单位封顶 + 降级护栏 11+
## 双保险）；cfg ui_battle_topbar_* 表驱动（UiTheme 兜底、值域外回退）；
## 降级路径（无参直开不调 setup）_ready 走兜底常量布局——横条在位内容空
##（与卷轴「存在保持收起」同构；tscn 占位 68 == 兜底总高两态一致）。
## 几何单源：横条总高四消费点（本组件 offset_bottom / 板区顶覆写 / IdleLabel
## 顶覆写 / 日志卷轴展开顶）全走 UiTheme.topbar_total_height。
class_name BattleTopBar
extends PanelContainer

## 总控配置（几何/衬底表驱动；null = 纯兜底模式——降级路径）
var _cfg: CoreConfig = null
## GameData（深底面板九宫格贴图解析；null = 缺件降级 StyleBoxFlat）
var _game_data: Node = null
## 四边距容器（_ready 取——setup 先于挂树时几何延后由 _ready 补齐）
var _margin_box: MarginContainer = null

func _ready() -> void:
	## 引擎回调：取子容器引用 + 兜底态几何/衬底应用（setup 后再按表值刷新）；
	## get_node_or_null 容错——独立构造（无 tscn 子树，测试注入口）不报错，
	## 边距部分自然跳过
	## 参数：无
	## 返回：无
	_margin_box = get_node_or_null("MarginBox") as MarginContainer
	_ApplyGeometry()
	_ApplyStyle()

func setup(cfg: CoreConfig, game_data: Node = null) -> void:
	## 装配（battle_screen 有参路径调用）：cfg/game_data 注入 + 几何/衬底按表值
	## 参数 cfg：总控配置（可空 = 兜底模式）；game_data：GameData（可空）
	## 返回：无
	_cfg = cfg
	if game_data != null:
		_game_data = game_data
	_ApplyGeometry()
	_ApplyStyle()

func apply_cfg(cfg: CoreConfig) -> void:
	## cfg 注入 / 热更新口（测试注入口——几何/衬底即时反映）
	## 参数 cfg：总控配置（可空 = 兜底模式）
	## 返回：无
	_cfg = cfg
	_ApplyGeometry()
	_ApplyStyle()

func total_height() -> float:
	## 横条总高实例口（battle_screen 板区顶/IdleLabel 顶覆写消费——薄转发
	## UiTheme 单源静态口）
	## 参数：无
	## 返回：总高（像素）
	return UiTheme.topbar_total_height(_cfg)

func _ApplyGeometry() -> void:
	## 几何应用：自身 offset_bottom = 横条总高（全宽顶部条锚定 left=0/top=0/
	## right=1/bottom=0——anchors 全锚下 resize 只变宽不变高，无需 resize
	## 监听）；MarginBox 四边距 = cfg 表值（兜底 12/12/12/174）
	## 参数：无
	## 返回：无
	offset_bottom = UiTheme.topbar_total_height(_cfg)
	if _margin_box == null:
		return
	_margin_box.add_theme_constant_override("margin_top",
			int(UiTheme.topbar_margin_top_of(_cfg)))
	_margin_box.add_theme_constant_override("margin_bottom",
			int(UiTheme.topbar_margin_bottom_of(_cfg)))
	_margin_box.add_theme_constant_override("margin_left", int(_LeftMargin()))
	_margin_box.add_theme_constant_override("margin_right", int(_RightReserve()))

func _ApplyStyle() -> void:
	## 衬底应用：深底面板样式单源 + 横条透明度调制（make_dark_panel_style
	## 第三参——既有调用点零传参零变化）；内容边距归零——PanelContainer
	## 内建把 stylebox 内容边距（占位 8 / 九宫格 24）叠加到子容器，总高
	## 68 = margin 12 + 条目 44 + margin 12 的算术要求内边距唯一归 MarginBox
	##（贴图态 24×2 会把内容区压到 20 < 条目高 44）
	## 参数：无
	## 返回：无
	var style: StyleBox = UiTheme.make_dark_panel_style(_cfg, _game_data, _BgAlpha())
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	add_theme_stylebox_override("panel", style)

# ---- cfg 读取口（cfg 优先、UiTheme 兜底、值域外回退——log_scroller
# ---- _AnchorWidth 同模式；本组件消费 5 键，degrade_count/compact_width
# ---- 归 TurnOrderBar 消费；margin 两键经 UiTheme 静态口与总高单源）----

func _LeftMargin() -> float:
	## 横条左端内容边距（cfg 优先；值域 (0,32] 外回退兜底——0 哨兵同
	## UiTheme margin 口径回退）
	## 参数：无
	## 返回：生效边距（像素）
	var raw: float = UiTheme.TOPBAR_LEFT_MARGIN
	if _cfg != null:
		raw = _cfg.ui_battle_topbar_left_margin
	if raw <= 0.0 or raw > 32.0:
		return UiTheme.TOPBAR_LEFT_MARGIN
	return raw

func _RightReserve() -> float:
	## 横条右端预留宽（cfg 优先；值域 [120,280] 外回退兜底——日志锚点条区
	## 让位：174 > 锚点热区 162 不撞头像）
	## 参数：无
	## 返回：生效预留宽（像素）
	var raw: float = UiTheme.TOPBAR_RIGHT_RESERVE
	if _cfg != null:
		raw = _cfg.ui_battle_topbar_right_reserve
	if raw < 120.0 or raw > 280.0:
		return UiTheme.TOPBAR_RIGHT_RESERVE
	return raw

func _BgAlpha() -> float:
	## 横条衬底透明度（cfg 优先；值域 (0,1] 外回退兜底）
	## 参数：无
	## 返回：生效透明度
	var raw: float = UiTheme.TOPBAR_BG_ALPHA
	if _cfg != null:
		raw = _cfg.ui_battle_topbar_bg_alpha
	if raw <= 0.0 or raw > 1.0:
		return UiTheme.TOPBAR_BG_ALPHA
	return raw
