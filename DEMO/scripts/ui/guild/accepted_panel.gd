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

## UI 文案单源（M4 增补批：轻度进行中行；M6 批 2 挂账 4.2：内联 UI 中文
## 收编——改措辞只动此处）
const UI_TEXTS: Dictionary = {
	&"title": "挂单委托",
	&"empty_hint": "（暂无挂单——去委托板接单）",
	&"state_in_progress": "进行中",
	&"state_accepted": "已接",
	&"remain_format": "剩 %d 天",
	&"party_empty": "未编队",
	&"row_format": "%s｜%s｜%s｜编队：%s",
	&"start_button": "出征",
	&"reassign_button": "重编队",
	&"abandon_button": "放弃",
	&"state_light_running": "进行中（轻度）",
	&"light_row_remain": "工期剩 %d 天",
}

## 总控配置
var _cfg: CoreConfig = null
## 标题行
var _title_label: Label = null
## 行容器
var _row_box: VBoxContainer = null
## 空挂单提示
var _empty_label: Label = null
## 行记录（刷新重建——低级1：泛型类型化；S4-R2-01 起行为摘要/操作两行 VBox）
var _rows: Array[VBoxContainer] = []

func setup(cfg: CoreConfig) -> void:
	## 构建面板骨架
	## 参数 cfg：总控配置
	## 返回：无
	_cfg = cfg
	add_theme_constant_override("separation", 6)
	_title_label = Label.new()
	_title_label.text = UI_TEXTS[&"title"]
	_title_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	add_child(_title_label)
	_row_box = VBoxContainer.new()
	_row_box.add_theme_constant_override("separation", 6)
	add_child(_row_box)
	_empty_label = Label.new()
	_empty_label.text = UI_TEXTS[&"empty_hint"]
	_empty_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	add_child(_empty_label)

func refresh(instances: Array[QuestInstance], core: GuildCore) -> void:
	## 刷新挂单行（全量重建；成员名读名册、剩余天数读日历）；S4-R2-01：
	## 行结构摘要/操作两行化——满编 4 人摘要行 ≈758px 超出列宽 458px，原单行
	## HBox 溢出把按钮画到招募池上方（参考 roster_overview M4-5 换行先例，
	## 摘要 Label 补 WORD_SMART 自动换行，按钮恒在本行操作行内）
	## 参数 instances：挂单实例（ACCEPTED+IN_PROGRESS）；core：公会核心
	## 返回：无
	for row: VBoxContainer in _rows:
		# S4-R3-01 同式（event_panel._Reset 先例）：旧行先隐藏断输入/渲染再
		# 释放（queue_free 延迟帧末——旧行与新行一帧叠渲）
		row.visible = false
		row.queue_free()
	_rows.clear()
	for inst: QuestInstance in instances:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		_row_box.add_child(row)
		var summary: Label = _MakeRowLabel(row)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# M4 增补批：LIGHT_RUNNING 轻度行——状态/剩余取工期、放弃按模板、
		# 不出征不重编队（战斗三操作仅 ACCEPTED 态呈现）
		var state_text: String = UI_TEXTS[&"state_in_progress"] \
				if inst.state == QuestInstance.State.IN_PROGRESS else UI_TEXTS[&"state_accepted"]
		var remain_text: String = UI_TEXTS[&"remain_format"] % maxi(0, inst.remaining_days(core.day))
		if inst.state == QuestInstance.State.LIGHT_RUNNING:
			state_text = UI_TEXTS[&"state_light_running"]
			remain_text = String(UI_TEXTS[&"light_row_remain"]) % maxi(0, inst.work_days_left)
		var member_names: PackedStringArray = []
		for member_id: StringName in inst.party_ids:
			var member: AdventurerData = core.find_member(member_id)
			member_names.append(member.display_name if member != null else String(member_id))
		var party_text: String = "、".join(member_names) if not member_names.is_empty() \
				else UI_TEXTS[&"party_empty"]
		summary.text = UI_TEXTS[&"row_format"] % [inst.display_name(core.game_data),
				state_text, remain_text, party_text]
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		row.add_child(actions)
		var row_tpl: QuestTemplateDef = core.game_data.get_record(inst.template_id) as QuestTemplateDef
		if inst.state == QuestInstance.State.ACCEPTED:
			_AddRowButton(actions, UI_TEXTS[&"start_button"], "StartButton", inst.serial,
					func(serial: int) -> void: start_requested.emit(serial))
			_AddRowButton(actions, UI_TEXTS[&"reassign_button"], "ReassignButton", inst.serial,
					func(serial: int) -> void: reassign_requested.emit(serial))
			if row_tpl == null or row_tpl.abandonable:
				_AddRowButton(actions, UI_TEXTS[&"abandon_button"], "AbandonButton", inst.serial,
						func(serial: int) -> void: abandon_requested.emit(serial))
		elif inst.state == QuestInstance.State.LIGHT_RUNNING:
			# 轻度进行中：仅放弃（可弃时——工期作废立即释放，二次确认在协会屏）
			if row_tpl == null or row_tpl.abandonable:
				_AddRowButton(actions, UI_TEXTS[&"abandon_button"], "AbandonButton", inst.serial,
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
