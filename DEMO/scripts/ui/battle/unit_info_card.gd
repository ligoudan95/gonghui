## 单位信息卡（UnitInfoCard，PanelContainer——右侧悬停面板）
## 职责：点选单位的详情展示——名称/阵营/HP/本系资源/在场状态列表
## （状态图标 + 悬停/长按 Tooltip 详情：名称、剩余回合、修正量、来源）。
## 数据来源：M1 批 3 方案 §7.1（UnitInfoCard + StatusTooltip）。
class_name UnitInfoCard
extends PanelContainer

## 状态图标尺寸
const STATUS_ICON_SIZE: float = 22.0

## 状态定义解析回调（StringName -> StatusDef；setup 注入）
var _status_lookup: Callable = Callable()
## 名称标签
var _name_label: Label = null
## 属性标签（HP/资源）
var _stats_label: Label = null
## 状态图标行
var _status_box: HBoxContainer = null

func setup(status_lookup: Callable) -> void:
	## 装配信息卡子节点（battle_screen _ready 调）
	## 参数 status_lookup：状态定义解析回调
	## 返回：无
	_status_lookup = status_lookup
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_name_label)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 15)
	box.add_child(_stats_label)
	var status_title := Label.new()
	status_title.text = "状态"
	status_title.add_theme_font_size_override("font_size", 13)
	status_title.modulate = Color(0.8, 0.8, 0.8)
	box.add_child(status_title)
	_status_box = HBoxContainer.new()
	_status_box.add_theme_constant_override("separation", 6)
	box.add_child(_status_box)
	add_child(box)
	visible = false

func show_unit(unit: BattleUnit) -> void:
	## 展示单位详情（点选任意单位刷新）
	## 参数 unit：目标单位
	## 返回：无
	var side_text: String = "我方" if unit.side == SkillDef.SkillSide.ALLY else "敌方"
	_name_label.text = "%s（%s）" % [unit.display_name, side_text]
	var resource_text: String
	if unit.resource_kind == SkillDef.ResourceKind.MANA:
		resource_text = "法力 %d/%d" % [unit.current_mana, unit.max_mana]
	else:
		resource_text = "精力 %d/%d" % [unit.current_stamina, unit.max_stamina]
	_stats_label.text = "HP %d/%d｜%s" % [unit.current_hp, unit.max_hp, resource_text]
	for child: Node in _status_box.get_children():
		child.queue_free()
	for instance: StatusInstance in unit.statuses:
		_status_box.add_child(_MakeStatusIcon(instance))
	if unit.statuses.is_empty():
		var none_label := Label.new()
		none_label.text = "（无）"
		none_label.add_theme_font_size_override("font_size", 12)
		none_label.modulate = Color(0.6, 0.6, 0.6)
		_status_box.add_child(none_label)
	visible = true

func _MakeStatusIcon(instance: StatusInstance) -> Control:
	## 构建状态图标（极性色点 + Tooltip 详情：悬停/长按查看）
	## 参数 instance：状态实例
	## 返回：图标节点
	var status: StatusDef = _status_lookup.call(instance.status_id) as StatusDef
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	icon.size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	var display_name: String = String(instance.status_id)
	var detail: String = ""
	if status != null:
		display_name = status.display_name
		var polarity: String = "增益" if status.polarity == StatusDef.Polarity.BUFF else "减益"
		icon.color = Color(0.3, 0.75, 0.35) if status.polarity == StatusDef.Polarity.BUFF \
				else Color(0.85, 0.35, 0.3)
		var mod_text: String = ""
		for key: StringName in status.modifiers:
			mod_text += "%s%+g " % [key, status.modifiers[key]]
		detail = "%s（%s）｜剩余 %d 回合%s%s" % [
			display_name, polarity, instance.remaining,
			("｜修正 " + mod_text) if not mod_text.is_empty() else "",
			"｜即时" if instance.duration_zero else "",
		]
	else:
		icon.color = Color(0.6, 0.6, 0.6)
	icon.tooltip_text = detail if not detail.is_empty() else display_name
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	return icon
