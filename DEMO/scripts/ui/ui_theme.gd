## UI 主题单源（UiTheme，纯静态工具类）
## 职责：UI 视觉参数的代码兜底常量组 + 表驱动读取口（B 席批单源化）——
## 全部 UI 颜色/字号的生产值入 cfg_main「UI 视觉参数」分区，本类承载：
## ①字段未回填/未注入 cfg 时的兜底常量（值 == cfg_main 表值，C-3 护栏锚定）
## ②color_of/font_of 读取口（表值优先、兜底回退，消费点一行替换）
## ③共享构建（B-4 深底面板样式 / B-19 四边框条）与 B-20 百分比换算。
## 纯逻辑约束：不触 autoload——cfg 经参数注入（可空 = 纯兜底模式）。
class_name UiTheme
extends RefCounted

# ---- 徽章（B-1：unit_badge 内联色兜底）----
const BADGE_HP_LOW: Color = Color(0.9, 0.25, 0.2)
const BADGE_HP_OK: Color = Color(0.35, 0.8, 0.3)
const BADGE_BAR_BACK: Color = Color(0.08, 0.08, 0.08, 0.85)
const BADGE_RES_MANA: Color = Color(0.3, 0.5, 0.95)
const BADGE_RES_STAMINA: Color = Color(0.9, 0.75, 0.25)
const BADGE_FALLBACK_ALLY: Color = Color(0.55, 0.6, 0.75)
const BADGE_FALLBACK_ENEMY: Color = Color(0.75, 0.45, 0.3)
const BADGE_BEWITCH: Color = Color(0.7, 0.3, 0.9, 0.95)
const BADGE_PREVIEW_STRIP: Color = Color(1.0, 0.55, 0.45, 0.95)
const BADGE_PREVIEW_TEXT: Color = Color(1.0, 0.62, 0.55)
const BADGE_OUTLINE: Color = Color(0, 0, 0)

# ---- 信息卡（B-1：unit_info_card 内联色兜底）----
const CARD_BUFF: Color = Color(0.3, 0.75, 0.35)
const CARD_DEBUFF: Color = Color(0.85, 0.35, 0.3)
const CARD_UNKNOWN: Color = Color(0.6, 0.6, 0.6)
const CARD_MUTED: Color = Color(0.8, 0.8, 0.8)

# ---- 覆盖层（B-5：battle_board 范围/路径/确认/阻断兜底）----
const OVERLAY_MOVE_FILL: Color = Color(0.4, 0.7, 1.0, 0.10)
const OVERLAY_MOVE_BORDER: Color = Color(0.55, 0.85, 1.0, 0.95)
const OVERLAY_SKILL_FILL: Color = Color(1.0, 0.3, 0.25, 0.10)
const OVERLAY_SKILL_BORDER: Color = Color(1.0, 0.42, 0.35, 0.95)
const OVERLAY_BLOCKED_FILL: Color = Color(0.35, 0.35, 0.38, 0.08)
const OVERLAY_BLOCKED_BORDER: Color = Color(0.45, 0.45, 0.5, 0.85)
const OVERLAY_BLOCKED_SLASH: Color = Color(0.55, 0.55, 0.6, 0.9)
const OVERLAY_PATH: Color = Color(1.0, 0.9, 0.4, 0.60)
const OVERLAY_CONFIRM: Color = Color(1.0, 0.95, 0.5, 0.75)

# ---- 战斗日志（B-6：五色兜底）----
const LOG_SYSTEM: Color = Color(0.85, 0.88, 0.9)
const LOG_DAMAGE: Color = Color(0.98, 0.55, 0.45)
const LOG_HEAL: Color = Color(0.5, 0.9, 0.55)
const LOG_STATUS: Color = Color(0.75, 0.6, 0.95)
const LOG_MOVE: Color = Color(0.6, 0.65, 0.62)

# ---- 共享（B-2 倒地灰显 / B-3 金色高亮 / B-4 深底面板）----
const DOWNED_MODULATE: Color = Color(0.5, 0.5, 0.5, 0.5)
const HIGHLIGHT_GOLD: Color = Color(1.0, 0.85, 0.3)
const PANEL_DARK: Color = Color(0.07, 0.08, 0.09, 0.9)
## 地格解析失败兜底色（#8 上移单源：battle_board 与 DataValidator C-3 共引）
const TILE_FALLBACK: Color = Color(0.32, 0.36, 0.29)
## 徽章 HP 低血阈值兜底（= cfg_main.ui_badge_hp_low_threshold——R3-08）
const BADGE_HP_LOW_THRESHOLD: float = 0.35
## 结算战败/撤退色兜底（R3-08）
const RESULT_DEFEAT: Color = Color(0.95, 0.4, 0.35)
const RESULT_RETREAT: Color = Color(0.7, 0.8, 0.95)

# ---- 字号档位（B-7 兜底；cfg 字段 ui_font_size_*）----
const FONT_DISPLAY: int = 64
const FONT_TITLE: int = 48
const FONT_HEADING: int = 34
const FONT_SUBHEADING: int = 22
const FONT_LARGE: int = 26
const FONT_BODY: int = 20
const FONT_NORMAL: int = 16
const FONT_SMALL: int = 14
const FONT_MINOR: int = 12

static func color_of(cfg: CoreConfig, field: StringName, fallback: Color) -> Color:
	## 表驱动颜色读取（B 席批）：cfg 字段值（alpha > 0）优先，未回填/
	## 未注入 cfg 回退兜底常量——消费点一行替换内联 Color()
	## 参数 cfg：总控配置（可空）；field：cfg 字段名（ui_* 命名）；
	## fallback：兜底常量（本类 const）
	## 返回：生效颜色
	if cfg == null:
		return fallback
	var raw: Variant = cfg.get(field)
	if raw is Color and raw.a > 0.0:
		return raw
	return fallback

static func font_of(cfg: CoreConfig, field: StringName, fallback: int) -> int:
	## 表驱动字号读取（B-7）：cfg 字段值（> 0）优先，回退兜底档位
	## 参数 cfg：总控配置（可空）；field：cfg 字段名（ui_font_size_*）；
	## fallback：兜底档位常量
	## 返回：生效字号
	if cfg == null:
		return fallback
	var raw: Variant = cfg.get(field)
	if raw is int and raw > 0:
		return raw
	return fallback

static func make_dark_panel_style(cfg: CoreConfig = null) -> StyleBoxFlat:
	## 深底面板样式单源（B-4：battle_board tips 与 battle_log 共用——
	## 原 alpha 0.92/0.86 漂移统一为 0.9）：圆角 6 + 内边距 8
	## 参数 cfg：总控配置（可空——ui_panel_dark_color 表驱动）
	## 返回：StyleBoxFlat（调用方 add_theme_stylebox_override("panel", ...)）
	var style := StyleBoxFlat.new()
	style.bg_color = color_of(cfg, &"ui_panel_dark_color", PANEL_DARK)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	return style

static func make_edge_strip_bars(full: Vector2, thickness: float,
		color: Color) -> Array[ColorRect]:
	## 四边框条构建单源（B-19：battle_board 边框 / unit_badge 环共用）——
	## 上/下/左/右各一条贴边色带（不挂树，调用方 add_child）
	## 参数 full：宿主尺寸；thickness：条宽；color：颜色
	## 返回：四条 ColorRect
	var edges: Array[ColorRect] = []
	edges.append(_strip(Vector2(0, 0), Vector2(full.x, thickness), color))
	edges.append(_strip(Vector2(0, full.y - thickness), Vector2(full.x, thickness), color))
	edges.append(_strip(Vector2(0, 0), Vector2(thickness, full.y), color))
	edges.append(_strip(Vector2(full.x - thickness, 0), Vector2(thickness, full.y), color))
	return edges

static func _strip(bar_position: Vector2, bar_size: Vector2, color: Color) -> ColorRect:
	## 构建单条色带（不挂树；B-19 内部口）
	## 参数 bar_position/bar_size/color：几何与颜色
	## 返回：ColorRect
	var rect := ColorRect.new()
	rect.position = bar_position
	rect.size = bar_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

static func pct(ratio: float) -> int:
	## 概率 → 整型百分比（B-20 单源：tips/日志显示换算共 5 处收口）
	## 参数 ratio：0-1 概率
	## 返回：百分比整数（四舍五入）
	return roundi(ratio * 100.0)
