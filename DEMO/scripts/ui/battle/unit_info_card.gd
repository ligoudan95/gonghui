## 单位信息卡（UnitInfoCard，PanelContainer——右侧悬停面板）
## 职责：点选单位的详情展示——名称/阵营/HP/本系资源/在场状态列表
## （状态图标 + 悬停/长按 Tooltip 详情：名称、剩余回合、修正量、来源）。
## 数据来源：M1 批 3 方案 §7.1（UnitInfoCard + StatusTooltip）。
class_name UnitInfoCard
extends PanelContainer

## 状态图标尺寸
const STATUS_ICON_SIZE: float = 22.0
## HP 图标资产 id（M6 批 3.5b 组 6：_stats_label 行前——固定 HP 图标）
const HP_ICON_ASSET_ID: StringName = &"icon_res_hp"
## 资源图标资产 id（法力/精力——按 unit.resource_kind 选）
const RES_ICON_MANA_ASSET_ID: StringName = &"icon_res_mp"
const RES_ICON_STAMINA_ASSET_ID: StringName = &"icon_res_sp"
## 状态行图标边长（px）
const STAT_ICON_SIZE: float = 16.0

## 修正键中文映射（S4-R4-02：状态 tooltip 修正量英文键直出「dodge+0.15」
## ——UI 层有限枚举字典，ATTR_NAMES（event_panel）豁免先例同口径；
## 未登记键回退原文——新增修正键漏登记不阻断展示）
const MOD_NAMES: Dictionary = {
	ModKeys.HIT: "命中", ModKeys.DODGE: "闪避",
	ModKeys.STATUS_RESIST: "异常抗性", ModKeys.PHYS_RESIST: "物理抗性",
	ModKeys.MAG_RESIST: "法术抗性", ModKeys.PHYS_PIERCE: "物理穿甲",
	ModKeys.MAG_PIERCE: "法术穿甲", ModKeys.MOVE_RANGE: "移动力",
	ModKeys.SPEED: "速度", ModKeys.ARMOR_PHYSICAL: "物理护甲",
	ModKeys.ARMOR_MAGICAL: "法术护甲", ModKeys.DAMAGE_PANEL_MULT: "面板伤害",
}

## 总控配置（B-1：配色/字号表驱动注入——setup 传入，空 = 纯兜底模式）
var _cfg: CoreConfig = null
## GameData（M6 批 3.5b 组 6：状态行 HP/资源图标解析——apply_cfg 注入；
## 空 = 缺件降级单 Label 现状）
var _game_data: Node = null

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
## 属性行容器（组 6：缺件态单 Label / 贴图态 [HP 图标+HP 段][资源图标+资源段]
## 两形态切换）
var _stats_box: HBoxContainer = null
## 属性标签（HP/资源——缺件降级态整行文本，现状分支保留）
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
	_stats_box = HBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 6)
	box.add_child(_stats_box)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", _UiFont(&"ui_font_size_small", UiTheme.FONT_SMALL))
	_stats_box.add_child(_stats_label)
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

func apply_cfg(cfg: CoreConfig, game_data: Node = null) -> void:
	## 后置注入总控配置（B-1：battle_screen 装配上下文后补cfg——
	## setup 先于 context 建立的时序适配）；R3-02：常驻标签字号随 cfg 重设
	## （setup 期 cfg 为空时字号用兜底档，注入后按表值刷新）；M6 批 3.5b 组 6：
	## game_data 一并注入（状态行 HP/资源图标解析；空 = 缺件降级）
	## 参数 cfg：总控配置；game_data：GameData（可空）
	## 返回：无
	_cfg = cfg
	_game_data = game_data
	_name_label.add_theme_font_size_override("font_size",
			_UiFont(&"ui_font_size_body", UiTheme.FONT_BODY))
	_stats_label.add_theme_font_size_override("font_size",
			_UiFont(&"ui_font_size_small", UiTheme.FONT_SMALL))
	if _status_title != null:
		_status_title.add_theme_font_size_override("font_size",
				_UiFont(&"ui_font_size_minor", UiTheme.FONT_MINOR))

func show_unit(unit: BattleUnit) -> void:
	## 展示单位详情（点选任意单位刷新；S4-9：名称经 name_resolver 单源解析；
	## M6 批 3.5b 组 6：HP/资源贴图齐备 → 状态行拆段带图标（HP 固定
	## icon_res_hp、资源按 resource_kind 选 icon_res_mp/icon_res_sp）；任一
	## 缺件 → 单 Label 整行文本现状零回归）
	## 参数 unit：目标单位
	## 返回：无
	var side_text: String = "我方" if unit.side == SkillDef.SkillSide.ALLY else "敌方"
	_name_label.text = "%s（%s）" % [_DisplayNameOf(unit), side_text]
	var resource_text: String
	if unit.resource_kind == SkillDef.ResourceKind.MANA:
		resource_text = "法力 %d/%d" % [unit.current_mana, unit.max_mana]
	else:
		resource_text = "精力 %d/%d" % [unit.current_stamina, unit.max_stamina]
	var hp_icon: Texture2D = AssetTex.texture_of(HP_ICON_ASSET_ID, _game_data)
	var res_icon: Texture2D = AssetTex.texture_of(
			RES_ICON_MANA_ASSET_ID if unit.resource_kind == SkillDef.ResourceKind.MANA
					else RES_ICON_STAMINA_ASSET_ID, _game_data)
	_stats_label.text = "HP %d/%d｜%s" % [unit.current_hp, unit.max_hp, resource_text]
	if hp_icon == null or res_icon == null:
		# 缺件降级：单 Label 整行文本（现状分支——_stats_label 常驻 _stats_box）
		for child: Node in _stats_box.get_children():
			if child != _stats_label:
				child.queue_free()
		_stats_label.visible = true
	else:
		# 贴图态：[HP 图标+HP 段][资源图标+资源段] 拆段（整行文本仍写
		# _stats_label——测试契约读值不因形态切换漂移）
		_stats_label.visible = false
		for child: Node in _stats_box.get_children():
			if child != _stats_label:
				child.queue_free()
		_stats_box.add_child(_MakeStatIcon(hp_icon))
		_stats_box.add_child(_MakeStatLabel("HP %d/%d" % [unit.current_hp, unit.max_hp]))
		_stats_box.add_child(_MakeStatIcon(res_icon))
		_stats_box.add_child(_MakeStatLabel(resource_text))
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

func _MakeStatIcon(texture: Texture2D) -> TextureRect:
	## 状态行图标节点构建（组 6：16px 垂直居中——不挂树由调用方挂入）
	## 参数 texture：已解析图标贴图
	## 返回：TextureRect
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2.ONE * STAT_ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _MakeStatLabel(text: String) -> Label:
	## 状态行拆段标签构建（组 6：字号随 _stats_label 同档；不挂树由调用方挂入）
	## 参数 text：段文本
	## 返回：Label
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",
			_UiFont(&"ui_font_size_small", UiTheme.FONT_SMALL))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

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
			# 支持的格式字符——改 %d/%f 系；整数域不带小数点、小数域两位小数）；
			# S4-R4-02：修正键经 MOD_NAMES 中文化（未登记键回退原文）
			var mod_value: float = status.modifiers[key]
			var sign: String = "+" if mod_value >= 0.0 else ""
			var key_label: String = String(MOD_NAMES.get(key, key))
			if is_equal_approx(mod_value, roundf(mod_value)):
				mod_text += "%s%s%d " % [key_label, sign, int(mod_value)]
			else:
				mod_text += "%s%s%.2f " % [key_label, sign, mod_value]
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
