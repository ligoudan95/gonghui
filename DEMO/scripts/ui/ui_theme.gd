## UI 主题单源（UiTheme，纯静态工具类）
## 职责：UI 视觉参数的代码兜底常量组 + 表驱动读取口（B 席批单源化）——
## 全部 UI 颜色/字号的生产值入 cfg_main「UI 视觉参数」分区，本类承载：
## ①字段未回填/未注入 cfg 时的兜底常量（值 == cfg_main 表值，C-3 护栏锚定）
## ②color_of/font_of 读取口（表值优先、兜底回退，消费点一行替换）
## ③共享构建（B-4 深底面板样式 / B-19 四边框条）与 B-20 百分比换算。
## 纯逻辑约束：不触 autoload——cfg 经参数注入（可空 = 纯兜底模式）。
## M6 批 3.5b：make_dark_panel_style 扩 game_data 参——深底面板九宫格单源
## 切换（ui_panel_ninepatch 在档 → StyleBoxTexture 四边 24px 边距；缺件
## 回退 StyleBoxFlat 占位——缺件态视觉零回归）。
class_name UiTheme
extends RefCounted

## 深底面板九宫格贴图资产 id（M6 批 3.5b 组 7——AssetRegistry 单源路径映射）
const PANEL_NINEPATCH_ASSET_ID: StringName = &"ui_panel_ninepatch"
## 九宫格贴图态四边纹理边距（px——StyleBoxTexture texture_margin）
const PANEL_NINEPATCH_MARGIN: float = 24.0

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

# ---- 飘字/tips（S4-M4-3-d：battle_board 飘字与 tips 两行配色入表）----
const DAMAGE_CRIT: Color = Color(1.0, 0.4, 0.3)
const DAMAGE_NORMAL: Color = Color(1.0, 0.9, 0.6)
const TIPS_LINE1: Color = Color(0.98, 0.6, 0.5)
const TIPS_LINE2: Color = Color(0.85, 0.88, 0.9)

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
## 事件四档反馈色兜底（M2——cfg ui_event_grade_*）
const EVENT_GRADE_CRIT_SUCCESS: Color = Color(0.35, 0.85, 0.4)
const EVENT_GRADE_SUCCESS: Color = Color(0.6, 0.8, 0.55)
const EVENT_GRADE_FAILURE: Color = Color(0.9, 0.5, 0.4)
const EVENT_GRADE_CRIT_FAILURE: Color = Color(0.8, 0.3, 0.3)
## D20 演出滚动时长兜底（秒——M2）
const D20_ROLL_SECONDS: float = 0.9

# ---- M6 批 1 单位动作集演出兜底（cfg ui_anim_*/ui_battle_move_step_seconds/
# ui_hit_flash_seconds——V-B2-cfg-fallback 锚定，值 == cfg_main 表值）----
## 待机动作帧率兜底（帧/秒）
const ANIM_IDLE_FPS: float = 6.0
## 移动动作帧率兜底（帧/秒）
const ANIM_MOVE_FPS: float = 10.0
## 攻击动作帧率兜底（帧/秒——近战/施放共用档）
const ANIM_ATTACK_FPS: float = 8.0
## 受击动作帧率兜底（帧/秒）
const ANIM_HIT_FPS: float = 8.0
## 倒地动作帧率兜底（帧/秒）
const ANIM_DOWNED_FPS: float = 6.0
## 战场徽章移动演出单步时长兜底（秒/步——D6=A）
const BATTLE_MOVE_STEP_SECONDS: float = 0.15
## 徽章受击白闪时长兜底（秒）
const HIT_FLASH_SECONDS: float = 0.25
## 徽章受击白闪峰值色兜底（HDR 亮白——modulate 分量 > 1 提亮；盲审低14 入表）
const HIT_FLASH_PEAK: Color = Color(4.0, 4.0, 4.0)
## 战场徽章移动演出步数上限兜底（低15：远距 tween 总时长钳制护栏——
## D6 语义「总时长 = 步长 × 步数」的步数封顶，入表可调）
const BATTLE_MOVE_MAX_STEPS: int = 6
## 战场路径闪烁高光色兜底（试玩反馈批：路径箭头改闪烁高光——金色系与
## 范围染蓝/染红区分；cfg ui_battle_path_highlight_* 表驱动）
const BATTLE_PATH_HIGHLIGHT_COLOR: Color = Color(1.0, 0.85, 0.35, 1.0)
## 路径高光呼吸峰值 alpha 兜底
const BATTLE_PATH_HIGHLIGHT_PEAK_ALPHA: float = 0.55
## 路径高光呼吸周期兜底（秒——一完整明暗循环）
const BATTLE_PATH_HIGHLIGHT_FLASH_SECONDS: float = 0.8
## 路径高光呼吸渐变形态兜底（Tween.TransitionType——SINE 正弦呼吸）
const BATTLE_PATH_HIGHLIGHT_TRANS: int = Tween.TransitionType.TRANS_SINE
## 路径高光呼吸渐变形态合法值集（LINEAR=0 作未回填哨兵弃用外全集；4.7.2
## 实测值序非字母序：QUART=3/EXPO=5/ELASTIC=6/CUBIC=7/CIRC=8/BOUNCE=9/
## BACK=10——枚举静态本体不可 find_key，以常量名引用列集合自适应序变）
const BATTLE_PATH_HIGHLIGHT_TRANS_VALID: Array[int] = [
	Tween.TRANS_SINE, Tween.TRANS_QUINT, Tween.TRANS_QUART, Tween.TRANS_EXPO,
	Tween.TRANS_ELASTIC, Tween.TRANS_CUBIC, Tween.TRANS_BOUNCE,
	Tween.TRANS_CIRC, Tween.TRANS_BACK,
]
## 结算战败/撤退色兜底（R3-08）
const RESULT_DEFEAT: Color = Color(0.95, 0.4, 0.35)
const RESULT_RETREAT: Color = Color(0.7, 0.8, 0.95)

# ---- E1 战棋等距投影兜底（cfg ui_battle_iso_* + 徽章底圈双色——V-B2
# # cfg-fallback 锚定，值 == cfg_main 表值；数学单源锚点 = E1 方案 §二）----
## 菱形纵横比兜底（cell_height = cell_width × 本值；2:1 等距）
const ISO_RATIO: float = 0.5
## 菱形全宽钳制带下限兜底（像素）
const ISO_CELL_WIDTH_MIN: float = 72.0
## 菱形全宽钳制带上限兜底（像素）
const ISO_CELL_WIDTH_MAX: float = 176.0
## 徽章 sprite 显示宽占格宽比兜底
const ISO_SPRITE_WIDTH_RATIO: float = 0.9
## 徽章脚踩线占格高比兜底（0.5 = 脚踩菱形中心）
const ISO_FEET_Y_RATIO: float = 0.5
## 徽章椭圆底圈半径占半轴比兜底
const ISO_RING_RATIO: float = 0.42
## 徽章底圈我方色兜底（E1：阵营辨识椭圆底圈）
const BADGE_BASE_RING_ALLY: Color = Color(0.29, 0.49, 0.85, 0.85)
## 徽章底圈敌方色兜底
const BADGE_BASE_RING_ENEMY: Color = Color(0.85, 0.32, 0.28, 0.85)

# ---- 探索层（M3——cfg ui_fog_*/ui_explore_* 兜底）----
## 探索逐格步进演出时长兜底（秒/格）
const EXPLORE_MOVE_STEP_SECONDS: float = 0.18
## 迷雾未探索遮蔽色兜底（浓雾）
const FOG_UNSEEN: Color = Color(0.02, 0.02, 0.03, 0.92)
## 迷雾已探索遮蔽色兜底（记忆态）
const FOG_DIM: Color = Color(0.04, 0.04, 0.05, 0.55)
## 探索小队图标色兜底
const EXPLORE_PARTY: Color = Color(0.95, 0.95, 0.85)
## 目标点激活色兜底（绑定目标高亮）
const EXPLORE_TARGET_ACTIVE: Color = Color(1.0, 0.85, 0.3)
## 目标点灰显色兜底（非绑定目标/未激活出口）
const EXPLORE_TARGET_DIM: Color = Color(0.45, 0.45, 0.5)
## 判据达成横幅色兜底
const EXPLORE_GOAL_BANNER: Color = Color(0.35, 0.85, 0.4)
## 探索常显图标衬底色兜底（迷雾之上目标点的对比底——2026-09-25 层级修复；
## cfg 字段 ui_explore_icon_backdrop_color 已回填 cfg_main 同值——席4 L3，
## 本常量为未注入/丢表时的兜底）
const EXPLORE_ICON_BACKDROP: Color = Color(0.02, 0.02, 0.03, 0.62)
## 探索屏左右侧栏宽度兜底（px——三栏布局；cfg ui_explore_side_panel_width）
const EXPLORE_SIDE_PANEL_WIDTH: int = 280
## 探索屏三栏列间距兜底（px——cfg ui_explore_column_gap）
const EXPLORE_COLUMN_GAP: int = 12
## 探索板面等比缩放上限兜底（放宽 >1.0——cfg ui_explore_board_fit_max_scale）
const EXPLORE_BOARD_FIT_MAX: float = 1.2
## 矿洞段可通行格染色兜底（淡鹅黄 ≈ #E8D9A8；cfg ui_explore_mine_walk_tint_color
## ——试玩反馈批 B：可通行/不可通行区域区分，村子段全亮行不染）
const EXPLORE_MINE_WALK_TINT: Color = Color(0.91, 0.851, 0.659)

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

static func make_dark_panel_style(cfg: CoreConfig = null,
		game_data: Node = null) -> StyleBox:
	## 深底面板样式单源（B-4：battle_board tips 与 battle_log 共用——
	## 原 alpha 0.92/0.86 漂移统一为 0.9）：占位态圆角 6 + 内边距 8；
	## M6 批 3.5b 组 7：game_data 注入且 ui_panel_ninepatch 在档 →
	## StyleBoxTexture（四边 24px 纹理边距）——九宫格单源切换，缺件/
	## 未注入回退 StyleBoxFlat 占位（缺件态视觉零回归）
	## 参数 cfg：总控配置（可空——ui_panel_dark_color 表驱动）；
	## game_data：GameData（可空——AssetTex 解析九宫格纹理）
	## 返回：StyleBox（贴图态 StyleBoxTexture / 占位态 StyleBoxFlat——
	## 调用方 add_theme_stylebox_override("panel", ...)）
	var texture: Texture2D = AssetTex.texture_of(PANEL_NINEPATCH_ASSET_ID,
			game_data) if game_data != null else null
	if texture != null:
		var tex_style := StyleBoxTexture.new()
		tex_style.texture = texture
		tex_style.set_texture_margin_all(PANEL_NINEPATCH_MARGIN)
		return tex_style
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
