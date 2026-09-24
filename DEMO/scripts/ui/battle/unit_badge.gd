## 单位徽章（UnitBadge，Control——战场格子层子节点）
## 职责：单个战斗单位的视觉呈现——像素小人 sprite（64×64 = 32×32 的 2× 放大、
## Nearest 过滤保持锐利；精英 ×1.3）、头顶 HP 条 + 本系资源条（Pixel 风细条）、
## 当前行动高亮环（5px 金边 + 呼吸脉动——2026-09-24 试玩反馈增强辨识）、
## 血条伤害预览（预扣色带 + 「−N」闪烁数字——二轮试玩反馈）、蛊惑紫边闪烁、
## 倒地灰度化（0.5 透明）。
## 数据来源：M1 批 3 方案 §7.1；sprite 资产 = DEMO/assets/units/spr_*.png
## （AssetRegistry 登记 spr_cls_*/spr_en_*，并行代理产出）。
## 输入口径：本节点不消费鼠标（mouse_filter = IGNORE）——点击统一由
## BoardLayer gui_input 按格命中分发。
class_name UnitBadge
extends Control

## 基准显示尺寸（32×32 sprite 的 2× 放大）
const BASE_SPRITE_SIZE: float = 64.0
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
## 条几何（B-17：HP 条/资源条的位相与尺寸——x 边距/y 偏移/长缩量/高）
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

## 总控配置（B-1：配色表驱动注入——setup 传入，空 = 纯兜底模式）
var _cfg: CoreConfig = null

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
## sprite 纹理（null = 占位色块回退）
var texture: Texture2D = null
## 格子像素尺寸
var cell_size: float = 72.0

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
## 当前行动高亮环（金色四边）
var _ring: Array[ColorRect] = []
## 蛊惑紫边（闪烁）
var _bewitch_ring: Array[ColorRect] = []
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
			for edge: ColorRect in _bewitch_ring:
				edge.visible = false

func _init() -> void:
	## 构造：不消费鼠标（点击走 BoardLayer 格命中）
	## 参数：无
	## 返回：无
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(badge_unit: BattleUnit, badge_texture: Texture2D, badge_cell_size: float,
		cfg: CoreConfig = null) -> void:
	## 装配徽章：建子节点（sprite/条/环）并按单位数据初刷；B-1：cfg 注入
	## （配色表驱动，缺省纯兜底）
	## 参数 badge_unit：绑定单位；badge_texture：sprite 纹理（可空）；
	## badge_cell_size：所在格像素尺寸；cfg：总控配置（可空）
	## 返回：无
	unit = badge_unit
	texture = badge_texture
	cell_size = badge_cell_size
	_cfg = cfg
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_BuildChildren()
	refresh()

func refresh() -> void:
	## 刷新显示：位置跟随、HP/资源条比例、精英放大、倒地灰度
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
	# 倒地：灰度化 + 透明 0.5；预览随 HP 失效路径防御清理
	if unit.alive:
		modulate = Color(1, 1, 1, 1)
	else:
		modulate = _Color(&"ui_downed_modulate_color", UiTheme.DOWNED_MODULATE)
		clear_damage_preview()

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
	for edge: ColorRect in _ring:
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
	for edge: ColorRect in _ring:
		edge.modulate.a = alpha

func _process(delta: float) -> void:
	## 蛊惑紫边闪烁（周期 0.8s 半亮半灭）
	## 参数 delta：帧间隔
	## 返回：无
	if not bewitched:
		return
	var visible_phase: bool = fmod(Time.get_ticks_msec() / 1000.0, BEWITCH_FLICK_PERIOD) \
			< BEWITCH_FLICK_PERIOD * 0.5
	for edge: ColorRect in _bewitch_ring:
		edge.visible = visible_phase

func _BuildChildren() -> void:
	## 构建子节点树：sprite（精英放大）/资源条/HP 条/高亮环/蛊惑边
	## 参数：无
	## 返回：无
	var is_elite: bool = unit.role_tag == UnitTags.ROLE_ELITE
	var sprite_size: float = BASE_SPRITE_SIZE * (ELITE_SCALE if is_elite else 1.0)
	# sprite 居中（超大时按格宽钳制）
	sprite_size = minf(sprite_size, cell_size + ELITE_CLAMP_MARGIN)
	if texture != null:
		_sprite = TextureRect.new()
		_sprite.texture = texture
		_sprite.stretch_mode = TextureRect.STRETCH_SCALE
		_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sprite.size = Vector2(sprite_size, sprite_size)
		_sprite.position = Vector2((cell_size - sprite_size) * 0.5, (cell_size - sprite_size) * 0.5)
		add_child(_sprite)
	else:
		_fallback = ColorRect.new()
		_fallback.color = _Color(&"ui_badge_fallback_ally_color", UiTheme.BADGE_FALLBACK_ALLY) \
				if unit.side == SkillDef.SkillSide.ALLY \
				else _Color(&"ui_badge_fallback_enemy_color", UiTheme.BADGE_FALLBACK_ENEMY)
		_fallback.size = Vector2(sprite_size * 0.7, sprite_size * 0.7)
		_fallback.position = (Vector2(cell_size, cell_size) - _fallback.size) * 0.5
		add_child(_fallback)
	# HP 条（格顶）与资源条（HP 条下方细条）——几何经 B-17 常量、配色表驱动
	var bar_width: float = cell_size - BAR_X_MARGIN * 2.0
	var bar_back_color: Color = _Color(&"ui_badge_bar_back_color", UiTheme.BADGE_BAR_BACK)
	_hp_back = _MakeBar(Vector2(BAR_X_MARGIN, BAR_HP_Y),
			Vector2(bar_width, BAR_HEIGHT_HP), bar_back_color)
	_hp_fill = _MakeBar(Vector2(BAR_X_MARGIN, BAR_HP_Y),
			Vector2(bar_width, BAR_HEIGHT_HP),
			_Color(&"ui_badge_hp_ok_color", UiTheme.BADGE_HP_OK))
	_hp_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res_back = _MakeBar(Vector2(BAR_X_MARGIN, BAR_RES_Y),
			Vector2(bar_width, BAR_HEIGHT_RES), bar_back_color)
	_res_fill = _MakeBar(Vector2(BAR_X_MARGIN, BAR_RES_Y),
			Vector2(bar_width, BAR_HEIGHT_RES),
			_Color(&"ui_badge_res_stamina_color", UiTheme.BADGE_RES_STAMINA))
	# 高亮环（金色四边 5px——B-3 表驱动）与蛊惑边（紫色四边 3px——B-1 表驱动）
	_ring = _MakeRing(_Color(&"ui_highlight_gold_color", UiTheme.HIGHLIGHT_GOLD), RING_THICKNESS)
	_bewitch_ring = _MakeRing(_Color(&"ui_badge_bewitch_color", UiTheme.BADGE_BEWITCH),
			BEWITCH_RING_THICKNESS)
	for edge: ColorRect in _ring + _bewitch_ring:
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

func _MakeRing(color: Color, thickness: float = BEWITCH_RING_THICKNESS) -> Array[ColorRect]:
	## 构建四边框环（B-19 单源：UiTheme.make_edge_strip_bars——与 battle_board
	## 覆盖层边框同构收口；条带挂树复用 _MakeBar）
	## 参数 color：环色；thickness：条宽（行动环 5px / 蛊惑边 3px）
	## 返回：四条 ColorRect
	var edges: Array[ColorRect] = []
	for rect: ColorRect in UiTheme.make_edge_strip_bars(
			Vector2(cell_size, cell_size), thickness, color):
		add_child(rect)
		edges.append(rect)
	return edges
