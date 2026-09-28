## 挂单管理面板（AcceptedPanel，代码构建 UI 组件）
## 职责：协会屏挂单分区——已接（含进行中）委托行（名称/状态/剩余天数/编队），
## 每行三操作：出征（start）/重编队（reassign）/放弃（abandon）——请求经信号
## 回抛，协会屏消费 GuildCore 对应门面校验。
## 数据来源：案 6 §2.4（执行状态机与 P2 放弃拍板）。
class_name AcceptedPanel
extends VBoxContainer

## 出征请求（serial）
signal start_requested(serial: int)
## 重编队请求（serial）
signal reassign_requested(serial: int)
## 放弃请求（serial）
signal abandon_requested(serial: int)

## 总控配置
var _cfg: CoreConfig = null
## 标题行
var _title_label: Label = null
## 行容器
var _row_box: VBoxContainer = null
## 空挂单提示
var _empty_label: Label = null
## 行记录（刷新重建——低级1：泛型类型化）
var _rows: Array[HBoxContainer] = []

func setup(cfg: CoreConfig) -> void:
	## 构建面板骨架
	## 参数 cfg：总控配置
	## 返回：无
	_cfg = cfg
	add_theme_constant_override("separation", 6)
	_title_label = Label.new()
	_title_label.text = "挂单委托"
	_title_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	add_child(_title_label)
	_row_box = VBoxContainer.new()
	_row_box.add_theme_constant_override("separation", 6)
	add_child(_row_box)
	_empty_label = Label.new()
	_empty_label.text = "（暂无挂单——去委托板接单）"
	_empty_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	add_child(_empty_label)

func refresh(instances: Array[QuestInstance], core: GuildCore) -> void:
	## 刷新挂单行（全量重建；成员名读名册、剩余天数读日历）
	## 参数 instances：挂单实例（ACCEPTED+IN_PROGRESS）；core：公会核心
	## 返回：无
	for row: HBoxContainer in _rows:
		row.queue_free()
	_rows.clear()
	for inst: QuestInstance in instances:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_row_box.add_child(row)
		var summary: Label = _MakeRowLabel(row)
		var state_text: String = "进行中" if inst.state == QuestInstance.State.IN_PROGRESS else "已接"
		var member_names: PackedStringArray = []
		for member_id: StringName in inst.party_ids:
			var member: AdventurerData = core.find_member(member_id)
			member_names.append(member.display_name if member != null else String(member_id))
		var party_text: String = "、".join(member_names) if not member_names.is_empty() else "未编队"
		summary.text = "%s｜%s｜剩 %d 天｜编队：%s" % [inst.display_name(core.game_data),
				state_text, maxi(0, inst.remaining_days(core.day)), party_text]
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if inst.state == QuestInstance.State.ACCEPTED:
			_AddRowButton(row, "出征", "StartButton", inst.serial,
					func(serial: int) -> void: start_requested.emit(serial))
			_AddRowButton(row, "重编队", "ReassignButton", inst.serial,
					func(serial: int) -> void: reassign_requested.emit(serial))
			var tpl: QuestTemplateDef = core.game_data.get_record(inst.template_id) as QuestTemplateDef
			if tpl == null or tpl.abandonable:
				_AddRowButton(row, "放弃", "AbandonButton", inst.serial,
						func(serial: int) -> void: abandon_requested.emit(serial))
		_rows.append(row)
	_empty_label.visible = instances.is_empty()

func _MakeRowLabel(parent: Node) -> Label:
	## 建行摘要标签
	## 参数 parent：父容器
	## 返回：Label
	var label := Label.new()
	label.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	parent.add_child(label)
	return label

func _AddRowButton(parent: Node, text: String, button_name: String, serial: int,
		handler: Callable) -> void:
	## 建行操作按钮（定名供 UI 级测试驱动；绑定序号回抛）
	## 参数 parent/text/button_name/serial/handler：父容器 / 文案 / 节点名 / 序号 / 回抛闭包
	## 返回：无
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	button.pressed.connect(func() -> void: handler.call(serial))
	parent.add_child(button)
