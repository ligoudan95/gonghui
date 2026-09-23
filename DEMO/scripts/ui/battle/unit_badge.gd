## 单位徽章（UnitBadge，Control——战场格子层子节点）
## 职责：单个战斗单位的视觉呈现——像素小人 sprite（64×64 = 32×32 的 2× 放大、
## Nearest 过滤保持锐利；精英 ×1.3）、头顶 HP 条 + 本系资源条（Pixel 风细条）、
## 当前行动高亮环、蛊惑紫边闪烁、倒地灰度化（0.5 透明）。
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

func setup(badge_unit: BattleUnit, badge_texture: Texture2D, badge_cell_size: float) -> void:
	## 装配徽章：建子节点（sprite/条/环）并按单位数据初刷
	## 参数 badge_unit：绑定单位；badge_texture：sprite 纹理（可空）；
	## badge_cell_size：所在格像素尺寸
	## 返回：无
	unit = badge_unit
	texture = badge_texture
	cell_size = badge_cell_size
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
	_hp_fill.color = Color(0.9, 0.25, 0.2) if hp_ratio <= 0.35 else Color(0.35, 0.8, 0.3)
	# 本系资源条（法力蓝/精力黄）
	if unit.resource_kind == SkillDef.ResourceKind.MANA:
		_res_fill.color = Color(0.3, 0.5, 0.95)
	else:
		_res_fill.color = Color(0.9, 0.75, 0.25)
	var res_max: int = unit.max_mana if unit.resource_kind == SkillDef.ResourceKind.MANA \
			else unit.max_stamina
	var res_cur: int = unit.current_mana if unit.resource_kind == SkillDef.ResourceKind.MANA \
			else unit.current_stamina
	var res_ratio: float = clampf(float(res_cur) / float(maxi(1, res_max)), 0.0, 1.0)
	_res_fill.size.x = _res_back.size.x * res_ratio
	# 倒地：灰度化 + 透明 0.5
	if unit.alive:
		modulate = Color(1, 1, 1, 1)
	else:
		modulate = Color(0.5, 0.5, 0.5, 0.5)

func set_current(current: bool) -> void:
	## 当前行动高亮环开关
	## 参数 current：true = 高亮
	## 返回：无
	for edge: ColorRect in _ring:
		edge.visible = current

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
	var is_elite: bool = unit.role_tag == &"elite"
	var sprite_size: float = BASE_SPRITE_SIZE * (ELITE_SCALE if is_elite else 1.0)
	# sprite 居中（超大时按格宽钳制）
	sprite_size = minf(sprite_size, cell_size + 12.0)
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
		_fallback.color = Color(0.55, 0.6, 0.75) if unit.side == SkillDef.SkillSide.ALLY \
				else Color(0.75, 0.45, 0.3)
		_fallback.size = Vector2(sprite_size * 0.7, sprite_size * 0.7)
		_fallback.position = (Vector2(cell_size, cell_size) - _fallback.size) * 0.5
		add_child(_fallback)
	# HP 条（格顶）
	var bar_width: float = cell_size - 10.0
	_hp_back = _MakeBar(Vector2(5, 2), Vector2(bar_width, 6), Color(0.08, 0.08, 0.08, 0.85))
	_hp_fill = _MakeBar(Vector2(5, 2), Vector2(bar_width, 6), Color(0.35, 0.8, 0.3))
	_hp_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 本系资源条（HP 条下方细条）
	_res_back = _MakeBar(Vector2(5, 9), Vector2(bar_width, 4), Color(0.08, 0.08, 0.08, 0.85))
	_res_fill = _MakeBar(Vector2(5, 9), Vector2(bar_width, 4), Color(0.9, 0.75, 0.25))
	# 高亮环（金色四边）与蛊惑边（紫色四边）
	_ring = _MakeRing(Color(1.0, 0.85, 0.2, 0.95))
	_bewitch_ring = _MakeRing(Color(0.7, 0.3, 0.9, 0.95))
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

func _MakeRing(color: Color) -> Array[ColorRect]:
	## 构建四边框环（上/下/左/右各一条 3px 色带）
	## 参数 color：环色
	## 返回：四条 ColorRect
	var edges: Array[ColorRect] = []
	var thickness: float = 3.0
	var full: Vector2 = Vector2(cell_size, cell_size)
	edges.append(_MakeBar(Vector2(0, 0), Vector2(full.x, thickness), color))
	edges.append(_MakeBar(Vector2(0, full.y - thickness), Vector2(full.x, thickness), color))
	edges.append(_MakeBar(Vector2(0, 0), Vector2(thickness, full.y), color))
	edges.append(_MakeBar(Vector2(full.x - thickness, 0), Vector2(thickness, full.y), color))
	return edges
