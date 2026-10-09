## 单位徽章（UnitBadge，Control——战场格子层子节点）
## 职责：单个战斗单位的视觉呈现——六动作帧动画载体（M6 批 1：竖条 PNG +
## AtlasTexture + UnitAnimState 代码帧推进；E1：显示宽 = cell_width ×
## cfg.ui_battle_iso_sprite_width_ratio（帧方形高同比、精英 ×1.3 与格宽
## 钳制余量沿用）、底边踩 cfg.ui_battle_iso_feet_y_ratio 线（默认 0.5 =
## 脚踩菱形中心））、头顶 HP 条 + 本系资源条（Pixel 风细条；E1：条锚定
## 改「sprite 顶」——y 相对 sprite 顶偏移、条宽 = cell_width − BAR_X_MARGIN×2）、
## 椭圆底圈（E1 纯新增：阵营色 draw_polyline 椭圆点集——cfg
## ui_badge_base_ring_ally/enemy_color；倒地随 _SetBarsVisible 一并隐藏）、
## 当前行动高亮环（5px 金边 + 呼吸脉动——2026-09-24 试玩反馈增强辨识；
## E1：贴图态 fx_battle_select 满盒菱形 STRETCH_SCALE 零改）、血条伤害预览
##（预扣色带 + 「−N」闪烁数字——二轮试玩反馈）、蛊惑紫边闪烁、受击白闪
##（M6：ui_hit_flash_seconds）、倒地尸态（D5=A：downed 末帧锁定 + 灰度
## 维持 + 隐藏血条/资源条/高亮环/底圈）。
## M6 批 3.5b 组 8：当前行动高亮环贴图接线——fx_battle_select 在档 →
## 单 TextureRect 满盒选中框（盒尺寸 STRETCH_SCALE）；缺件回退现状金边
## 四边带；呼吸 tween 对 _ring 元素 modulate.a 泛化 Control 后两态零改复用。
## 数据来源：M1 批 3 方案 §7.1 + E1 方案 §二（等距锚定数学单源锚点）；
## 动作资产 = DEMO/assets/units/spr_*_<action>.png
##（AssetRegistry 登记 54 动作键，tools/gen_unit_anim_frames.gd 占位产出）。
## 输入口径：本节点不消费鼠标（mouse_filter = IGNORE）——点击统一由
## BoardLayer gui_input 按格命中分发。
class_name UnitBadge
extends Control

## 精英放大系数
const ELITE_SCALE: float = 1.3
## 蛊惑闪烁周期（秒）
const BEWITCH_FLICK_PERIOD: float = 0.8
## 行动高亮环条宽（像素——2026-09-24 试玩反馈加粗）
const RING_THICKNESS: float = 5.0
## 蛊惑环条宽（像素）
const BEWITCH_RING_THICKNESS: float = 3.0
## 行动高亮呼吸半周期（秒，一次明暗起伏 = 2 × 半周期）
const RING_BREATH_HALF_PERIOD: float = 0.55
## 行动高亮呼吸透明度下限（1.0 → 下限 → 1.0 循环）
const RING_BREATH_ALPHA_MIN: float = 0.45
## 预览闪烁半周期（秒）
const PREVIEW_FLICK_HALF: float = 0.4
## 条几何（B-17：HP 条/资源条的位相与尺寸——x 边距/高；E1：BAR_*_Y 改
## 相对 **sprite 顶**偏移（原相对格顶——菱形下格顶在钻石后方不贴单位））
const BAR_X_MARGIN: float = 5.0
const BAR_HP_Y: float = 2.0
const BAR_RES_Y: float = 9.0
const BAR_HEIGHT_HP: float = 6.0
const BAR_HEIGHT_RES: float = 4.0
## 预览数字纵向偏移（血条上方）
const PREVIEW_LABEL_Y_OFFSET: float = -16.0
## 预览数字描边宽
const PREVIEW_OUTLINE_SIZE: int = 3
## 精英超大时按格宽加成的余量
const ELITE_CLAMP_MARGIN: float = 12.0
## 椭圆底圈折线段数（E1：24 段近似椭圆——视觉平滑与顶点开销折中）
const BASE_RING_SEGMENTS: int = 24
## 椭圆底圈线宽（像素——E1）
const BASE_RING_LINE_WIDTH: float = 2.0
## 当前行动选中框贴图资产 id（M6 批 3.5b 组 8：fx_battle_select 在档 →
## 单 TextureRect 替代四边金边带；缺件回退现状四边带——蛊惑紫边不接线）
const SELECT_RING_ASSET_ID: StringName = &"fx_battle_select"

## 总控配置（B-1：配色表驱动注入——setup 传入，空 = 纯兜底模式）
var _cfg: CoreConfig = null
## GameData（M6 批 3.5b 组 8：选中框贴图解析——AssetTex 单源；空 = 占位
## 四边带降级，纯兜底模式兼容）
var _game_data: Node = null

## 表驱动色读取（B-1：cfg ui_badge_* 优先、UiTheme 兜底）
func _Color(field: StringName, fallback: Color) -> Color:
	## 参数 field：cfg 字段名；fallback：UiTheme 兜底常量
	## 返回：生效颜色
	return UiTheme.color_of(_cfg, field, fallback)

## 字号档位读取（B-7）
func _UiFont(field: StringName, fallback: int) -> int:
	## 参数 field：cfg 字段名；fallback：UiTheme 兜底档位
	## 返回：生效字号
	return UiTheme.font_of(_cfg, field, fallback)

## 绑定单位
var unit: BattleUnit = null
## 动作状态机（M6：帧推进与动作仲裁——测试/分派查询口）
var anim: UnitAnimState = UnitAnimState.new()
## 六动作竖条纹理表（UnitAnimState.Action -> Texture2D；空 = 占位色块回退）
var _anim_textures: Dictionary = {}
## 动作单帧显示 AtlasTexture（region 随 frame_index 重设）
var _anim_atlas: AtlasTexture = null
## 帧推进前帧位（变更检测——region 只在跨帧时重设）
var _last_frame_index: int = -1
## 受击白闪 Tween（null = 无闪烁）
var _flash_tween: Tween = null
## 菱形全宽（像素——E1：原 cell_size 方形边长口径退役）
var cell_width: float = 72.0
## 菱形全高（像素——setup 时按注入 cfg 的 iso_ratio 派生：cell_width × ratio）
var _cell_height: float = 36.0
## 椭圆底圈可见性（E1：倒地随 _SetBarsVisible 一并隐藏——_draw 条件消费）
var _base_ring_visible: bool = true
## 椭圆底圈色（E1：阵营色——setup 时按 unit.side 取 cfg 键/UiTheme 兜底）
var _base_ring_color: Color = UiTheme.BADGE_BASE_RING_ALLY

## sprite 节点
var _sprite: TextureRect = null
## 占位回退色块（无纹理时）
var _fallback: ColorRect = null
## HP 条背景/填充
var _hp_back: ColorRect = null
var _hp_fill: ColorRect = null
## 资源条背景/填充
var _res_back: ColorRect = null
var _res_fill: ColorRect = null
## 当前行动高亮环（贴图态单 TextureRect / 占位态金色四边——组 8 泛化 Control）
var _ring: Array[Control] = []
## 蛊惑紫边（闪烁——组 8 泛化 Control，视觉不动）
var _bewitch_ring: Array[Control] = []
## 行动高亮呼吸 Tween（当前行动单位激活；否则为 null/失效）
var _ring_tween: Tween = null
## 伤害预览预扣色带（血条末段闪烁；null = 无预览）
var _preview_strip: ColorRect = null
## 伤害预览「−N」数字（血条上方闪烁；null = 无预览）
var _preview_label: Label = null
## 预览闪烁 Tween（null = 无预览）
var _preview_tween: Tween = null
## 蛊惑标记（battle_screen 依控制状态置位）
var bewitched: bool = false:
	set(value):
		bewitched = value
		if not value:
			for edge: Control in _bewitch_ring:
				edge.visible = false

func _init() -> void:
	## 构造：不消费鼠标（点击走 BoardLayer 格命中）
	## 参数：无
	## 返回：无
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## E1 等距纵横比读取口（cfg ui_battle_iso_ratio 优先、UiTheme.ISO_RATIO 兜底；
## 值域外非法回退兜底——battle_board._IsoRatio 同式，徽章侧 cfg 经 setup 注入）
func _IsoRatio() -> float:
	## 参数：无
	## 返回：生效比例（(0, 1]）
	var raw: float = UiTheme.ISO_RATIO
	if _cfg != null:
		raw = _cfg.ui_battle_iso_ratio
	if raw <= 0.0 or raw > 1.0:
		return UiTheme.ISO_RATIO
	return raw

## E1 徽章 sprite 宽比读取口（cfg 优先、UiTheme 兜底；非法回退）
func _IsoSpriteWidthRatio() -> float:
	## 参数：无
	## 返回：生效比例（(0, 1.5]）
	var raw: float = UiTheme.ISO_SPRITE_WIDTH_RATIO
	if _cfg != null:
		raw = _cfg.ui_battle_iso_sprite_width_ratio
	if raw <= 0.0 or raw > 1.5:
		return UiTheme.ISO_SPRITE_WIDTH_RATIO
	return raw

## E1 徽章脚踩线比读取口（cfg 优先、UiTheme 兜底；非法回退）
func _IsoFeetYRatio() -> float:
	## 参数：无
	## 返回：生效比例（[0.25, 0.75]）
	var raw: float = UiTheme.ISO_FEET_Y_RATIO
	if _cfg != null:
		raw = _cfg.ui_battle_iso_feet_y_ratio
	if raw < 0.25 or raw > 0.75:
		return UiTheme.ISO_FEET_Y_RATIO
	return raw

## E1 椭圆底圈半径比读取口（cfg 优先、UiTheme 兜底；非法回退）
func _IsoRingRatio() -> float:
	## 参数：无
	## 返回：生效比例（(0, 0.5]）
	var raw: float = UiTheme.ISO_RING_RATIO
	if _cfg != null:
		raw = _cfg.ui_battle_iso_ring_ratio
	if raw <= 0.0 or raw > 0.5:
		return UiTheme.ISO_RING_RATIO
	return raw

func setup(badge_unit: BattleUnit, badge_cell_width: float,
		cfg: CoreConfig = null, anim_textures: Dictionary = {},
		game_data: Node = null) -> void:
	## 装配徽章：建子节点（sprite/条/环/底圈）并按单位数据初刷；B-1：cfg
	## 注入（配色表驱动，缺省纯兜底）；M6：六动作竖条纹理注入（空 = 占位
	## 色块）；M6 批 3.5b 组 8：game_data 注入（选中框 fx_battle_select 贴图
	## 解析；空 = 占位四边带降级——纯兜底模式兼容）；E1：badge_cell_width
	## = 所在格菱形全宽（cell_height 按 cfg iso_ratio 派生）+ 底圈阵营色定色
	## 参数 badge_unit：绑定单位；badge_cell_width：所在格菱形全宽（像素）；
	## cfg：总控配置（可空）；anim_textures：UnitAnimState.Action -> 竖条纹理；
	## game_data：GameData（可空）
	## 返回：无
	unit = badge_unit
	cell_width = badge_cell_width
	_cell_height = badge_cell_width * _IsoRatio()
	_cfg = cfg
	_anim_textures = anim_textures
	_game_data = game_data
	_base_ring_color = _Color(&"ui_badge_base_ring_ally_color",
			UiTheme.BADGE_BASE_RING_ALLY) \
			if unit.side == SkillDef.SkillSide.ALLY \
			else _Color(&"ui_badge_base_ring_enemy_color",
					UiTheme.BADGE_BASE_RING_ENEMY)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_BuildChildren()
	refresh()

func play_action(action: int) -> bool:
	## 播放动作（M6：battle_board 转发口）——按竖条图高推导帧数请求状态机；
	## 低12（盲审）：纹理缺失（占位色块回退态）时状态机**仍进态**——逻辑
	## 表现生效（DOWNED 尸态锁定/is_downed_pose 查询不因缺件失效；「逻辑
	## 进态、视觉缺省」一致性推及一切动作），无帧可驱动时告警
	## 末帧保护窗（M6 修复二段）：单次动作末帧停留未满一个动画帧时长时，
	## 低优先级外部请求被拒——移动 tween 完成回调/回合流转的 IDLE 恰在末帧
	## 刚落位时到达（is_once_finished 后 transient_playing=false 不再压制），
	## 末帧 5ms 级被打断吞帧（两帧动作的挥砍帧不可见即此路径）
	## 参数 action：UnitAnimState.Action
	## 返回：true = 受理（状态机切换；纹理缺失时无视觉；保护窗拒 false）
	if _OnceHoldBlocking(action):
		return false
	var strip: Texture2D = _anim_textures.get(action, null) as Texture2D
	var frames: int = SpriteResolver.frame_count_of(strip)
	if not anim.request(action as UnitAnimState.Action, frames):
		return false
	if strip == null:
		push_warning("UnitBadge: 单位 '%s' 动作 %d 竖条纹理缺失——逻辑进态生效、视觉占位缺省" % [
				unit.unit_id if unit != null else &"?", action])
		return true
	_last_frame_index = -1
	_ApplyAnimFrame()
	return true

func _OnceHoldBlocking(action: int) -> bool:
	## 末帧保护窗判定：当前为单次动作且已停末帧、停留计时未满一个动画帧
	## 时长、且来请动作优先级低于当前——拒绝（受击 HIT/倒地 DOWNED 更高
	## 优先级照常打断；DOWNED 自身经倒地锁不经此路径）
	## 参数 action：来请动作
	## 返回：true = 保护窗拦截（play_action 返 false）
	if anim.is_downed_locked():
		return false
	if UnitAnimState.is_loop(anim.current as UnitAnimState.Action):
		return false
	if not anim.is_once_finished():
		return false
	var fps: float = _AnimFpsOf(anim.current)
	if fps <= 0.0:
		return false
	return _once_hold_elapsed < 1.0 / fps \
			and UnitAnimState.priority_of(action as UnitAnimState.Action) \
			< UnitAnimState.priority_of(anim.current as UnitAnimState.Action)

func current_action() -> int:
	## 当前动作查询（测试契约口）
	## 参数：无
	## 返回：UnitAnimState.Action
	return anim.current

func is_downed_pose() -> bool:
	## 尸态锁定查询（D5：倒地末帧锁定——测试契约口）
	## 参数：无
	## 返回：true = 已倒地锁定
	return anim.is_downed_locked()

func set_flip(flip: bool) -> void:
	## 朝向翻转（M6：攻击时按施放者/目标 x 相位翻面——无朝向素材的廉价朝向）
	## 参数 flip：true = 水平翻转
	## 返回：无
	if _sprite != null:
		_sprite.flip_h = flip

func play_hit_flash() -> void:
	## 受击白闪（M6：sprite modulate 亮白 → 复位，时长 = cfg.
	## ui_hit_flash_seconds；时长 ≤ 0 立即复位——测试注 0 口径）
	## 参数：无
	## 返回：无
	if _sprite == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	var duration: float = UiTheme.HIT_FLASH_SECONDS
	if _cfg != null:
		duration = _cfg.ui_hit_flash_seconds
	# 低14（盲审）：白闪峰值色入表（cfg ui_hit_flash_peak_color——HDR 亮白
	# modulate 分量 > 1 提亮；UiTheme.HIT_FLASH_PEAK 兜底锚定）
	_sprite.modulate = _Color(&"ui_hit_flash_peak_color", UiTheme.HIT_FLASH_PEAK)
	if duration <= 0.0:
		_sprite.modulate = Color(1, 1, 1, 1)
		return
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), duration)

func _AnimFpsOf(action: int) -> float:
	## 动作帧率读取（cfg 表驱动：ui_anim_*_fps；cfg 注入即取表值——
	## 测试注 0/高 fps 经表值直改；未注入回退 UiTheme 兜底）
	## 参数 action：UnitAnimState.Action
	## 返回：帧率（帧/秒）
	if _cfg == null:
		return UiTheme.ANIM_IDLE_FPS
	match action:
		UnitAnimState.Action.MOVE:
			return _cfg.ui_anim_move_fps
		UnitAnimState.Action.MELEE_ATTACK, UnitAnimState.Action.CAST_RANGED:
			return _cfg.ui_anim_attack_fps
		UnitAnimState.Action.HIT:
			return _cfg.ui_anim_hit_fps
		UnitAnimState.Action.DOWNED:
			return _cfg.ui_anim_downed_fps
		_:
			return _cfg.ui_anim_idle_fps if _cfg != null else UiTheme.ANIM_IDLE_FPS

func _ApplyAnimFrame() -> void:
	## 当前帧落位（AtlasTexture.region 重设 + 缓存帧位）
	## 参数：无
	## 返回：无
	if _anim_atlas == null:
		return
	var strip: Texture2D = _anim_textures.get(anim.current, null) as Texture2D
	if strip == null:
		return
	if _anim_atlas.atlas != strip:
		_anim_atlas.atlas = strip
	var frame_size: float = float(SpriteResolver.ANIM_FRAME_SIZE)
	_anim_atlas.region = Rect2(0.0, float(anim.frame_index) * frame_size,
			frame_size, frame_size)
	_last_frame_index = anim.frame_index

func refresh() -> void:
	## 刷新显示：位置跟随、HP/资源条比例、精英放大、倒地尸态（D5=灰度维持
	## + 隐藏血条/资源条/高亮环/蛊惑边——预览随 HP 失效路径防御清理）
	## 参数：无
	## 返回：无
	if unit == null:
		return
	# HP 条（头顶）
	var hp_ratio: float = clampf(float(unit.current_hp) / float(maxi(1, unit.max_hp)), 0.0, 1.0)
	_hp_fill.size.x = _hp_back.size.x * hp_ratio
	# R3-08：低血阈值表驱动（cfg.ui_badge_hp_low_threshold）
	var hp_low_line: float = _cfg.ui_badge_hp_low_threshold if _cfg != null \
			and _cfg.ui_badge_hp_low_threshold > 0.0 else UiTheme.BADGE_HP_LOW_THRESHOLD
	_hp_fill.color = _Color(&"ui_badge_hp_low_color", UiTheme.BADGE_HP_LOW) \
			if hp_ratio <= hp_low_line else _Color(&"ui_badge_hp_ok_color", UiTheme.BADGE_HP_OK)
	# 本系资源条（法力蓝/精力黄）
	if unit.resource_kind == SkillDef.ResourceKind.MANA:
		_res_fill.color = _Color(&"ui_badge_res_mana_color", UiTheme.BADGE_RES_MANA)
	else:
		_res_fill.color = _Color(&"ui_badge_res_stamina_color", UiTheme.BADGE_RES_STAMINA)
	var res_max: int = unit.max_mana if unit.resource_kind == SkillDef.ResourceKind.MANA \
			else unit.max_stamina
	var res_cur: int = unit.current_mana if unit.resource_kind == SkillDef.ResourceKind.MANA \
			else unit.current_stamina
	var res_ratio: float = clampf(float(res_cur) / float(maxi(1, res_max)), 0.0, 1.0)
	_res_fill.size.x = _res_back.size.x * res_ratio
	# 倒地：灰度维持（modulate）+ 隐藏条/环（D5=A）；预览防御清理
	if unit.alive:
		modulate = Color(1, 1, 1, 1)
	else:
		modulate = _Color(&"ui_downed_modulate_color", UiTheme.DOWNED_MODULATE)
		clear_damage_preview()
	_SetBarsVisible(unit.alive)

func _SetBarsVisible(visible_bars: bool) -> void:
	## 血条/资源条可见性 + 倒地态高亮环/蛊惑边/椭圆底圈清理（D5：倒地隐藏
	## ——尸态只留 sprite；E1：底圈随本口一并隐藏；存活时环可见性仍由
	## set_current 独立管理）
	## 参数 visible_bars：true = 显示条
	## 返回：无
	for bar: ColorRect in [_hp_back, _hp_fill, _res_back, _res_fill]:
		if bar != null:
			bar.visible = visible_bars
	_base_ring_visible = visible_bars
	queue_redraw()
	if not visible_bars:
		for edge: Control in _ring:
			edge.visible = false
		bewitched = false
		for edge: Control in _bewitch_ring:
			edge.visible = false
		_StopRingBreath()

func show_damage_preview(amount: int) -> void:
	## 血条伤害预览：当前 HP 末段显示预扣色带 + 血条上方「−N」数字，
	## 双节点闪烁循环（预扣比例 = min(预计伤害, 当前HP) / 最大HP——
	## 2026-09-24 二轮试玩反馈：技能确认前显示预计伤害）
	## 参数 amount：预计伤害（≤0 视为无效直接清）
	## 返回：无
	clear_damage_preview()
	if unit == null or amount <= 0 or unit.current_hp <= 0:
		return
	var max_hp_safe: int = maxi(1, unit.max_hp)
	var preview_ratio: float = clampf(
			float(mini(amount, unit.current_hp)) / float(max_hp_safe), 0.0, 1.0)
	if preview_ratio <= 0.0:
		return
	var hp_ratio: float = clampf(float(unit.current_hp) / float(max_hp_safe), 0.0, 1.0)
	var bar_width: float = _hp_back.size.x
	_preview_strip = ColorRect.new()
	_preview_strip.color = _Color(&"ui_badge_preview_strip_color", UiTheme.BADGE_PREVIEW_STRIP)
	_preview_strip.size = Vector2(bar_width * preview_ratio, _hp_back.size.y)
	_preview_strip.position = Vector2(
			_hp_back.position.x + bar_width * (hp_ratio - preview_ratio), _hp_back.position.y)
	_preview_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview_strip)
	_preview_label = Label.new()
	_preview_label.text = "−%d" % amount
	_preview_label.add_theme_font_size_override("font_size",
			_UiFont(&"ui_font_size_small", UiTheme.FONT_SMALL))
	_preview_label.add_theme_color_override("font_color",
			_Color(&"ui_badge_preview_text_color", UiTheme.BADGE_PREVIEW_TEXT))
	_preview_label.add_theme_color_override("font_outline_color",
			_Color(&"ui_badge_outline_color", UiTheme.BADGE_OUTLINE))
	_preview_label.add_theme_constant_override("outline_size", PREVIEW_OUTLINE_SIZE)
	_preview_label.position = _hp_back.position + Vector2(0, PREVIEW_LABEL_Y_OFFSET)
	_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview_label)
	_preview_tween = create_tween().set_loops()
	_preview_tween.tween_method(_SetPreviewAlpha, 1.0, 0.25, PREVIEW_FLICK_HALF)
	_preview_tween.tween_method(_SetPreviewAlpha, 0.25, 1.0, PREVIEW_FLICK_HALF)

func clear_damage_preview() -> void:
	## 清除伤害预览（停闪烁 + 释放色带/数字；幂等）
	## 参数：无
	## 返回：无
	if _preview_tween != null:
		_preview_tween.kill()
		_preview_tween = null
	if _preview_strip != null:
		_preview_strip.queue_free()
		_preview_strip = null
	if _preview_label != null:
		_preview_label.queue_free()
		_preview_label = null

func is_damage_preview_active() -> bool:
	## 伤害预览激活状态（测试契约查询；queue_free 后节点即视为无效）
	## 参数：无
	## 返回：true = 预览显示中
	return _preview_strip != null and is_instance_valid(_preview_strip)

func _SetPreviewAlpha(alpha: float) -> void:
	## 统一设置预览色带/数字透明度（闪烁动画驱动）
	## 参数 alpha：目标透明度
	## 返回：无
	if _preview_strip != null:
		_preview_strip.modulate.a = alpha
	if _preview_label != null:
		_preview_label.modulate.a = alpha

func set_current(current: bool) -> void:
	## 当前行动高亮环开关（开启时呼吸脉动——2026-09-24 试玩反馈增强辨识）
	## 参数 current：true = 高亮
	## 返回：无
	for edge: Control in _ring:
		edge.visible = current
	if current:
		_StartRingBreath()
	else:
		_StopRingBreath()

func _StartRingBreath() -> void:
	## 启动高亮环呼吸（透明度 1.0 → 下限 → 1.0 循环 Tween；已在跑则不重启）
	## 参数：无
	## 返回：无
	if _ring_tween != null and _ring_tween.is_valid():
		return
	_ring_tween = create_tween().set_loops()
	_ring_tween.tween_method(_SetRingAlpha, 1.0, RING_BREATH_ALPHA_MIN, RING_BREATH_HALF_PERIOD)
	_ring_tween.tween_method(_SetRingAlpha, RING_BREATH_ALPHA_MIN, 1.0, RING_BREATH_HALF_PERIOD)

func _StopRingBreath() -> void:
	## 停止呼吸并复位环透明度
	## 参数：无
	## 返回：无
	if _ring_tween != null:
		_ring_tween.kill()
		_ring_tween = null
	_SetRingAlpha(1.0)

func _SetRingAlpha(alpha: float) -> void:
	## 统一设置行动高亮环四边透明度（呼吸动画驱动）
	## 参数 alpha：目标透明度
	## 返回：无
	for edge: Control in _ring:
		edge.modulate.a = alpha

func _process(delta: float) -> void:
	## 帧推进驱动（M6：UnitAnimState.advance + 跨帧重设 AtlasTexture.region；
	## 单次动作播完自动回落 IDLE——DOWNED 例外锁末帧）+ 蛊惑紫边闪烁
	## 参数 delta：帧间隔
	## 返回：无
	_AdvanceAnim(delta)
	if not bewitched:
		return
	var visible_phase: bool = fmod(Time.get_ticks_msec() / 1000.0, BEWITCH_FLICK_PERIOD) \
			< BEWITCH_FLICK_PERIOD * 0.5
	for edge: Control in _bewitch_ring:
		edge.visible = visible_phase

## 单次动作末帧停留计时（秒——M6 修复：advance 推到末帧与 is_once_finished
## 回落同帧发生时，末帧从未渲染即被吞（frame_index 净变化 0 → region 不重设，
## 竖条还停在首帧）——末帧落位后至少停留一个动画帧时长再回落，两帧动作的
## 末帧（如挥砍）才可见；回落本身亦属动作切换，_last_frame_index 置 -1
## 强制重设 region（否则回落帧位恰与首帧同号时 atlas 不切回 idle 竖条）
var _once_hold_elapsed: float = 0.0

func _AdvanceAnim(delta: float) -> void:
	## 动作帧推进：advance → 跨帧落位；单次动作（非 DOWNED）播完回落 IDLE
	## （HIT/攻击类停末帧等 finish_check 的消费侧——回落即此口；末帧停留
	## ≥ 一个动画帧时长，见 _once_hold_elapsed 注）
	## 参数 delta：帧间隔
	## 返回：无
	if _anim_textures.is_empty() or _anim_atlas == null:
		return
	anim.advance(delta, _AnimFpsOf(anim.current))
	if anim.is_once_finished() and not anim.is_downed_locked():
		if anim.frame_index != _last_frame_index:
			# 本帧刚推到末帧：先落位显示（尾部统一 _ApplyAnimFrame）
			_once_hold_elapsed = 0.0
		else:
			_once_hold_elapsed += delta
			if _once_hold_elapsed >= 1.0 / maxf(_AnimFpsOf(anim.current), 0.001):
				_once_hold_elapsed = 0.0
				anim.request(UnitAnimState.Action.IDLE,
						SpriteResolver.frame_count_of(
								_anim_textures.get(UnitAnimState.Action.IDLE, null) as Texture2D))
				_last_frame_index = -1
	else:
		_once_hold_elapsed = 0.0
	if anim.frame_index != _last_frame_index:
		_ApplyAnimFrame()

func _BuildChildren() -> void:
	## 构建子节点树：sprite（动作 AtlasTexture——E1 等距锚定：宽 =
	## cell_width × sprite_width_ratio（精英 ×1.3 + 格宽钳制余量沿用）、
	## 底边踩 feet_y 线）/资源条/HP 条（锚定 sprite 顶）/高亮环/蛊惑边；
	## 椭圆底圈为徽章根 _draw 纯新增（无子节点）
	## 参数：无
	## 返回：无
	var is_elite: bool = unit.role_tag == UnitTags.ROLE_ELITE
	var sprite_width: float = cell_width * _IsoSpriteWidthRatio() \
			* (ELITE_SCALE if is_elite else 1.0)
	# sprite 超大时按格宽钳制（余量沿用）
	sprite_width = minf(sprite_width, cell_width + ELITE_CLAMP_MARGIN)
	# 等距锚定：水平居中 + 底边踩 feet 线（默认 0.5 = 菱形中心）
	var feet_y: float = _cell_height * _IsoFeetYRatio()
	var sprite_top: float = feet_y - sprite_width
	var idle_strip: Texture2D = _anim_textures.get(UnitAnimState.Action.IDLE, null) as Texture2D
	if idle_strip != null:
		# M6：六动作帧动画载体——AtlasTexture 首帧落位（region 随帧推进重设）
		_sprite = TextureRect.new()
		_anim_atlas = AtlasTexture.new()
		_anim_atlas.atlas = idle_strip
		var frame_size: float = float(SpriteResolver.ANIM_FRAME_SIZE)
		_anim_atlas.region = Rect2(0.0, 0.0, frame_size, frame_size)
		anim.frame_count = SpriteResolver.frame_count_of(idle_strip)
		_last_frame_index = 0
		_sprite.texture = _anim_atlas
		_sprite.stretch_mode = TextureRect.STRETCH_SCALE
		_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sprite.size = Vector2(sprite_width, sprite_width)
		_sprite.position = Vector2((cell_width - sprite_width) * 0.5, sprite_top)
		add_child(_sprite)
	else:
		_fallback = ColorRect.new()
		_fallback.color = _Color(&"ui_badge_fallback_ally_color", UiTheme.BADGE_FALLBACK_ALLY) \
				if unit.side == SkillDef.SkillSide.ALLY \
				else _Color(&"ui_badge_fallback_enemy_color", UiTheme.BADGE_FALLBACK_ENEMY)
		_fallback.size = Vector2(sprite_width * 0.7, sprite_width * 0.7)
		_fallback.position = Vector2((cell_width - _fallback.size.x) * 0.5,
				feet_y - _fallback.size.y)
		add_child(_fallback)
	# HP 条（sprite 顶）与资源条（HP 条下方细条）——几何经 B-17 常量（E1：
	## y 相对 sprite 顶偏移）、配色表驱动
	var bar_width: float = cell_width - BAR_X_MARGIN * 2.0
	var bar_back_color: Color = _Color(&"ui_badge_bar_back_color", UiTheme.BADGE_BAR_BACK)
	_hp_back = _MakeBar(Vector2(BAR_X_MARGIN, sprite_top + BAR_HP_Y),
			Vector2(bar_width, BAR_HEIGHT_HP), bar_back_color)
	_hp_fill = _MakeBar(Vector2(BAR_X_MARGIN, sprite_top + BAR_HP_Y),
			Vector2(bar_width, BAR_HEIGHT_HP),
			_Color(&"ui_badge_hp_ok_color", UiTheme.BADGE_HP_OK))
	_hp_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res_back = _MakeBar(Vector2(BAR_X_MARGIN, sprite_top + BAR_RES_Y),
			Vector2(bar_width, BAR_HEIGHT_RES), bar_back_color)
	_res_fill = _MakeBar(Vector2(BAR_X_MARGIN, sprite_top + BAR_RES_Y),
			Vector2(bar_width, BAR_HEIGHT_RES),
			_Color(&"ui_badge_res_stamina_color", UiTheme.BADGE_RES_STAMINA))
	# 高亮环（M6 批 3.5b 组 8：fx_battle_select 在档 → 单 TextureRect 选中框
	## 满盒菱形尺寸 STRETCH_SCALE；缺件回退现状金色四边 5px——B-3 表驱动）
	## 与蛊惑边（紫色四边 3px——B-1 表驱动，不接线维持程序带）
	var select_texture: Texture2D = AssetTex.texture_of(SELECT_RING_ASSET_ID,
			_game_data)
	if select_texture != null:
		_ring = [_MakeSelectRing(select_texture)]
	else:
		_ring = _MakeRing(_Color(&"ui_highlight_gold_color", UiTheme.HIGHLIGHT_GOLD),
				RING_THICKNESS)
	_bewitch_ring = _MakeRing(_Color(&"ui_badge_bewitch_color", UiTheme.BADGE_BEWITCH),
			BEWITCH_RING_THICKNESS)
	for edge: Control in _ring + _bewitch_ring:
		edge.visible = false

func _MakeBar(position: Vector2, size: Vector2, color: Color) -> ColorRect:
	## 构建条形子节点并挂树
	## 参数 position/size/color：几何与颜色
	## 返回：ColorRect
	var rect := ColorRect.new()
	rect.position = position
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect

func _MakeRing(color: Color, thickness: float = BEWITCH_RING_THICKNESS) -> Array[Control]:
	## 构建四边框环（B-19 单源：UiTheme.make_edge_strip_bars——组 8 返回
	## 泛化 Control：_ring 贴图态/四边态同池管理；E1：环几何 = 菱形盒）
	## 参数 color：环色；thickness：条宽（行动环 5px / 蛊惑边 3px）
	## 返回：四条色带 Control
	var edges: Array[Control] = []
	for rect: ColorRect in UiTheme.make_edge_strip_bars(
			Vector2(cell_width, _cell_height), thickness, color):
		add_child(rect)
		edges.append(rect)
	return edges

func _MakeSelectRing(texture: Texture2D) -> Control:
	## 构建贴图态选中框（M6 批 3.5b 组 8）：单 TextureRect 替代四边带——
	## 满盒菱形尺寸 STRETCH_SCALE；呼吸 tween 对 _ring 元素 modulate.a 泛化
	## Control 后零改复用（set_current/_StartRingBreath/_SetRingAlpha 不动）
	## 参数 texture：fx_battle_select 已解析贴图
	## 返回：选中框节点（已挂树）
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = Vector2(cell_width, _cell_height)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect

func _draw() -> void:
	## 引擎回调：椭圆底圈绘制（E1 纯新增）——draw_polyline 椭圆点集
	##（BASE_RING_SEGMENTS 段折线近似；中心 = 菱形盒中心、rx/ry =
	## 半轴 × cfg.ui_battle_iso_ring_ratio）；倒地 _base_ring_visible=false
	## 跳过（随 _SetBarsVisible 一并隐藏）；数学单源锚点 = E1 方案 §二
	## 参数：无
	## 返回：无
	if not _base_ring_visible:
		return
	var center: Vector2 = Vector2(cell_width, _cell_height) * 0.5
	var radius_x: float = cell_width * 0.5 * _IsoRingRatio()
	var radius_y: float = _cell_height * 0.5 * _IsoRingRatio()
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in BASE_RING_SEGMENTS:
		var angle: float = TAU * float(index) / float(BASE_RING_SEGMENTS)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	points.append(points[0])
	draw_polyline(points, _base_ring_color, BASE_RING_LINE_WIDTH, true)
