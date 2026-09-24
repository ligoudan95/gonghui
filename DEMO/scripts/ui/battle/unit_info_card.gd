## 单位信息卡（UnitInfoCard，PanelContainer——右侧悬停面板）
## 职责：点选单位的详情展示——名称/阵营/HP/本系资源/在场状态列表
## （状态图标 + 悬停/长按 Tooltip 详情：名称、剩余回合、修正量、来源）。
## 数据来源：M1 批 3 方案 §7.1（UnitInfoCard + StatusTooltip）。
class_name UnitInfoCard
extends PanelContainer

## 状态图标尺寸
const STATUS_ICON_SIZE: float = 22.0

## 总控配置（B-1：配色/字号表驱动注入——setup 传入，空 = 纯兜底模式）
var _cfg: CoreConfig = null

## 表驱动色读取（B-1：cfg ui_card_* 优先、UiTheme 兜底）
func _Color(field: StringName, fallback: Color) -> Color:
	## 参数 field：cfg 字段名；fallback：UiTheme 兜底常量
	## 返回：生效颜色
	return UiTheme.color_of(_cfg, field, fallback)

## 字号档位读取（B-7）
func _UiFont(field: StringName, fallback: int) -> int:
	## 参数 field：cfg 字段名；fallback：UiTheme 兜底档位
	## 返回：生效字号
	return UiTheme.font_of(_cfg, field, fallback)

## 状态定义解析回调（StringName -> StatusDef；setup 注入）
var _status_lookup: Callable = Callable()
## 显示名解析回调（unit_id -> String；S4-9 单源——BattleContext.display_name_of
## 注入；无效/空显示名回退 unit.display_name 直读）
var _name_resolver: Callable = Callable()
## 名称标签
var _name_label: Label = null
## 属性标签（HP/资源）
var _stats_label: Label = null
## 状态图标行
var _status_box: HBoxContainer = null
## 状态区标题标签（R3-02：apply_cfg 重设字号需成员引用）
var _status_title: Label = null

func setup(status_lookup: Callable, name_resolver: Callable = Callable(),
		cfg: CoreConfig = null) -> void:
	## 装配信息卡子节点（battle_screen _ready 调）；S4-4：面板容器 IGNORE
	## （不遮右侧点击链），状态图标单独 STOP 保 tooltip；S4-9：name_resolver
	## 显示名单源注入（缺省回退 unit.display_name 直读）
	## 参数 status_lookup：状态定义解析回调；name_resolver：unit_id -> String 解析
	## 返回：无
	_status_lookup = status_lookup
	_name_resolver = name_resolver
	_cfg = cfg
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", _UiFont(&"ui_font_size_body", UiTheme.FONT_BODY))
	box.add_child(_name_label)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", _UiFont(&"ui_font_size_small", UiTheme.FONT_SMALL))
	box.add_child(_stats_label)
	var status_title := Label.new()
	_status_title = status_title
	status_title.text = "状态"
	status_title.add_theme_font_size_override("font_size", _UiFont(&"ui_font_size_minor", UiTheme.FONT_MINOR))
	status_title.modulate = _Color(&"ui_card_muted_color", UiTheme.CARD_MUTED)
	box.add_child(status_title)
	_status_box = HBoxContainer.new()
	_status_box.add_theme_constant_override("separation", 6)
	box.add_child(_status_box)
	add_child(box)
	visible = false

func apply_cfg(cfg: CoreConfig) -> void:
	## 后置注入总控配置（B-1：battle_screen 装配上下文后补cfg——
	## setup 先于 context 建立的时序适配）；R3-02：常驻标签字号随 cfg 重设
	## （setup 期 cfg 为空时字号用兜底档，注入后按表值刷新）
	## 参数 cfg：总控配置
	## 返回：无
	_cfg = cfg
	_name_label.add_theme_font_size_override("font_size",
			_UiFont(&"ui_font_size_body", UiTheme.FONT_BODY))
	_stats_label.add_theme_font_size_override("font_size",
			_UiFont(&"ui_font_size_small", UiTheme.FONT_SMALL))
	if _status_title != null:
		_status_title.add_theme_font_size_override("font_size",
				_UiFont(&"ui_font_size_minor", UiTheme.FONT_MINOR))

func show_unit(unit: BattleUnit) -> void:
	## 展示单位详情（点选任意单位刷新；S4-9：名称经 name_resolver 单源解析）
	## 参数 unit：目标单位
	## 返回：无
	var side_text: String = "我方" if unit.side == SkillDef.SkillSide.ALLY else "敌方"
	_name_label.text = "%s（%s）" % [_DisplayNameOf(unit), side_text]
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
		none_label.add_theme_font_size_override("font_size", _UiFont(&"ui_font_size_minor", UiTheme.FONT_MINOR))
		none_label.modulate = _Color(&"ui_card_unknown_color", UiTheme.CARD_UNKNOWN)
		_status_box.add_child(none_label)
	visible = true

func _DisplayNameOf(unit: BattleUnit) -> String:
	## 单位显示名单源解析（S4-9）：resolver 有效且解析非空优先（BattleContext.
	## display_name_of 口径）；否则回退 unit.display_name 直读（降级路径/
	## 旧调用兼容）
	## 参数 unit：目标单位
	## 返回：显示名
	if _name_resolver.is_valid():
		var resolved: String = String(_name_resolver.call(unit.unit_id))
		if not resolved.is_empty() and resolved != String(unit.unit_id):
			return resolved
	return unit.display_name

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
		icon.color = _Color(&"ui_card_buff_color", UiTheme.CARD_BUFF) \
				if status.polarity == StatusDef.Polarity.BUFF \
				else _Color(&"ui_card_debuff_color", UiTheme.CARD_DEBUFF)
		var mod_text: String = ""
		for key: StringName in status.modifiers:
			# 修正量显示（2026-09-24 九轮后 BUG 修复：%g 非 GDScript % 运算符
			# 支持的格式字符——改 %d/%f 系；整数域不带小数点、小数域两位小数）
			var mod_value: float = status.modifiers[key]
			var sign: String = "+" if mod_value >= 0.0 else ""
			if is_equal_approx(mod_value, roundf(mod_value)):
				mod_text += "%s%s%d " % [String(key), sign, int(mod_value)]
			else:
				mod_text += "%s%s%.2f " % [String(key), sign, mod_value]
		detail = "%s（%s）｜剩余 %d 回合%s%s" % [
			display_name, polarity, instance.remaining,
			("｜修正 " + mod_text) if not mod_text.is_empty() else "",
			"｜即时" if instance.duration_zero else "",
		]
	else:
		icon.color = _Color(&"ui_card_unknown_color", UiTheme.CARD_UNKNOWN)
	icon.tooltip_text = detail if not detail.is_empty() else display_name
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	return icon
