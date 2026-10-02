## 升级与倾向选择面板（LevelupPanel，代码构建 UI 组件）
## 职责：pending 队列驱动——悬置成员（pending_tendency_levels）逐个列出，
## 每人倾向选项按钮（GrowthCore.set_tendency——选定即按积压档数补加侧重成长
## 并清悬置）；升级效果说明（全属性+1+倾向侧重+1——17-C3 全额口径）；
## 支持聚焦成员（详情弹层入口——未悬置也可预选）。
## **续选链路（Z2-3 修复）**：多成员悬置时选定一人只移除该员区块（差量
## queue_free，不整面板重建——规避重建期按名查找命中已释放实例），队列还有
## 未选成员则留在面板续选；全部选完自动关闭。公会壳侧提供直入入口
##（pending>0 时显示按钮）。
## 数据来源：案 5 §2.3（职业倾向选择）；案 10 §2.1（倾向清单归职业表）；
## 案 17 §3.6（成长数值收口）。
## UI 规范：UiTheme 深底面板/字号档位；弹层 z=100 置顶（organize_panel 先例）。
class_name LevelupPanel
extends PanelContainer

## 关闭请求
signal close_requested
## 成员数据变更（选倾向——宿主刷新总览与详情）
signal member_changed(unit_id: StringName)

## 弹层 z（单源置顶）
const POPUP_Z_INDEX: int = 100

## 总控配置
var _cfg: CoreConfig = null
## 内容容器
var _box: VBoxContainer = null
## 公会核心（open 注入）
var _core: GuildCore = null
## 成员区块节点记录（String(unit_id) -> Array[Node]——差量移除用，Z2-3）
var _sections: Dictionary = {}

func setup(cfg: CoreConfig, game_data: Node = null) -> void:
	## 构建弹层骨架（初始隐藏）；M6 批 3.5b：game_data 注入（九宫格面板贴图
	## 态；空 = 缺件降级 StyleBoxFlat）
	## 参数 cfg：总控配置；game_data：GameData（可空）
	## 返回：无
	_cfg = cfg
	visible = false
	z_index = POPUP_Z_INDEX
	add_theme_stylebox_override("panel", UiTheme.make_dark_panel_style(cfg, game_data))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)

func open(core: GuildCore, focus_unit_id: StringName = &"") -> void:
	## 打开并构建：升级效果说明 + 成员区块队列（悬置成员全体 + 聚焦成员——
	## 聚焦置顶、去重；未悬置聚焦成员也可预选倾向）
	## 参数 core：公会核心；focus_unit_id：聚焦成员 id（空=纯队列模式——
	## 公会壳直入入口消费）
	## 返回：无
	_core = core
	_Rebuild(focus_unit_id)
	visible = true

## UI 文案单源（M6 批 2 挂账 4.2：内联 UI 中文收编——改措辞只动此处）
const UI_TEXTS: Dictionary = {
	&"title": "升级与倾向",
	&"explain": "升级效果：每级全属性 +1；选定倾向后，侧重属性每级额外 +1（升级时未选的档数会在选择时一次补加）。",
	&"empty_hint": "（暂无待选倾向的成员——升级且未选倾向时会出现在这里）",
	&"close_button": "关闭",
	&"member_header_format": "%s（Lv%d）%s",
	&"header_chosen_format": "——已选「%s」",
	&"header_pending_backlog_format": "——待选倾向（悬置 %d 级）",
	&"header_pending": "——待选倾向",
	&"tendency_option_format": "%s（侧重 %s）",
}

func close() -> void:
	## 关闭弹层
	## 参数：无
	## 返回：无
	visible = false

func _Rebuild(focus_unit_id: StringName) -> void:
	## 内容全量重建（仅 open 入口——选定后走差量移除不整建）
	## 参数 focus_unit_id：聚焦成员 id
	## 返回：无
	for child: Node in _box.get_children():
		child.queue_free()
	_sections.clear()
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = UI_TEXTS[&"title"]
	title.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	_box.add_child(title)
	var explain := Label.new()
	explain.name = "EffectLabel"
	explain.text = UI_TEXTS[&"explain"]
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explain.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	_box.add_child(explain)
	# 成员队列：悬置成员全体 + 聚焦成员（去重、聚焦置顶）
	var unit_queue: Array[StringName] = []
	if focus_unit_id != &"":
		unit_queue.append(focus_unit_id)
	for unit_key: String in _core.pending_tendency_levels:
		var unit_id: StringName = StringName(unit_key)
		if not unit_queue.has(unit_id):
			unit_queue.append(unit_id)
	if unit_queue.is_empty():
		var empty := Label.new()
		empty.name = "EmptyLabel"
		empty.text = UI_TEXTS[&"empty_hint"]
		empty.add_theme_font_size_override("font_size",
				UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
		_box.add_child(empty)
	for unit_id: StringName in unit_queue:
		_AddMemberSection(unit_id)
	var close_button := Button.new()
	close_button.name = "CloseLevelupButton"
	close_button.text = UI_TEXTS[&"close_button"]
	close_button.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	close_button.pressed.connect(func() -> void: close_requested.emit())
	_box.add_child(close_button)

func _AddMemberSection(unit_id: StringName) -> void:
	## 单成员倾向选择区（职业倾向选项按钮；区块节点入 _sections 供差量移除）
	## 参数 unit_id：成员 id
	## 返回：无
	var member: AdventurerData = _core.find_member(unit_id)
	if member == null:
		return
	var game_data: Node = _core.game_data
	var cls: ClassDef = game_data.get_record(member.class_id) as ClassDef
	var backlog: int = int(_core.pending_tendency_levels.get(String(unit_id), 0))
	var section_nodes: Array = []
	var header := Label.new()
	header.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_body", UiTheme.FONT_BODY))
	var chosen: TendencyDef = GrowthCore.resolve_tendency(member, game_data)
	header.text = UI_TEXTS[&"member_header_format"] % [member.display_name, member.level,
			UI_TEXTS[&"header_chosen_format"] % chosen.display_name if chosen != null
			else UI_TEXTS[&"header_pending_backlog_format"] % backlog if backlog > 0
			else UI_TEXTS[&"header_pending"]]
	_box.add_child(header)
	section_nodes.append(header)
	if chosen != null:
		_sections[String(unit_id)] = section_nodes
		return
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 12)
	_box.add_child(options)
	section_nodes.append(options)
	if cls == null:
		_sections[String(unit_id)] = section_nodes
		return
	var option_index: int = 0
	for tendency: TendencyDef in cls.tendencies:
		var button := Button.new()
		# 同级同名会触发 Godot 自动改名——仅首枚定名（UI 级测试驱动位）
		if option_index == 0:
			button.name = "TendencyOptionButton"
		option_index += 1
		var focus_names: PackedStringArray = []
		for attr_id: StringName in tendency.focus_attrs:
			focus_names.append(String(QuestCard.ATTR_NAMES.get(attr_id, attr_id)))
		button.text = UI_TEXTS[&"tendency_option_format"] % [tendency.display_name, "、".join(focus_names)]
		button.add_theme_font_size_override("font_size",
				UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
		button.pressed.connect(_OnTendencyChosen.bind(unit_id, tendency.id))
		options.add_child(button)
	_sections[String(unit_id)] = section_nodes

func _OnTendencyChosen(unit_id: StringName, tendency_id: StringName) -> void:
	## 倾向选定（GrowthCore.set_tendency——按积压补加侧重成长、清悬置）→
	## **差量移除该员区块**（Z2-3：队列仍有未选成员则续选，全部选完自动关闭）；
	## 失败（倾向不属本职业）静默——配置层已由数据表约束
	## 参数 unit_id：成员 id；tendency_id：倾向 id
	## 返回：无
	var member: AdventurerData = _core.find_member(unit_id)
	if member == null:
		return
	if not GrowthCore.set_tendency(member, tendency_id, _cfg, _core.game_data,
			_core.pending_tendency_levels):
		return
	member_changed.emit(unit_id)
	var section_key: String = String(unit_id)
	if _sections.has(section_key):
		for node: Node in _sections[section_key]:
			node.queue_free()
		_sections.erase(section_key)
	if _sections.is_empty():
		close_requested.emit()
