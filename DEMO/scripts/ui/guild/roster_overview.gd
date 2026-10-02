## 队伍总览（RosterOverview，代码构建 UI 组件）
## 职责：公会主界面名册总览——每名成员行（姓名/职业/等级/状态/占用委托/
## 当日已出征标记）；行点击经信号回抛（成员详情弹层批 3 接线，本批占位）。
## 数据来源：案 5 §2.5（状态机）/§2.6（占用一览——案 15 公会主界面落位）。
class_name RosterOverview
extends VBoxContainer

## 成员行点击（unit_id——批 3 详情弹层消费）
signal member_selected(unit_id: StringName)

## UI 文案单源（M6 批 2 挂账 4.2：内联 UI 中文收编——改措辞只动此处）
const UI_TEXTS: Dictionary = {
	&"title": "队伍总览",
	&"status_healthy": "健康",
	&"status_resting_format": "休养 %d 天",
	&"mark_quest_format": "执行『%s』",
	&"mark_deployed_today": "今日已出征",
	&"mark_pending_tendency": "待选倾向",
	&"row_format": "%s（%s Lv%d）｜%s",
}

## 行首职业图标最大宽（px——中4：64×64 裸贴图标撑爆行高的钳制；与其他
## 落点 16-20px 口径统一（recruit_panel CLASS_ICON_SIZE=20 同基准），行高
## 回归 ~38px；占位 UI 结构参数，X3-06 豁免先例同口径）
const CLASS_ICON_MAX_WIDTH: int = 20

## 总控配置
var _cfg: CoreConfig = null
## 标题行
var _title_label: Label = null
## 成员行容器
var _row_box: VBoxContainer = null
## 行按钮记录（低级 1：泛型类型化）
var _row_buttons: Array[Button] = []

func setup(cfg: CoreConfig) -> void:
	## 构建总览骨架
	## 参数 cfg：总控配置
	## 返回：无
	_cfg = cfg
	add_theme_constant_override("separation", 4)
	_title_label = Label.new()
	_title_label.text = UI_TEXTS[&"title"]
	_title_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	add_child(_title_label)
	_row_box = VBoxContainer.new()
	_row_box.add_theme_constant_override("separation", 4)
	add_child(_row_box)

func refresh(members: Array[AdventurerData], board: QuestBoard, day: int,
		game_data: Node, pending: Dictionary = {}) -> void:
	## 刷新成员行（全量重建；占用 = 挂单+进行中全部实例编队并集；
	## pending = 悬置倾向表——待选成员补「待选倾向」标记，Z2-3）
	## 参数 members：名册；board：委托板（占用查询）；day：当日天数；
	## game_data：GameData（职业名解析）；pending：core.pending_tendency_levels
	## 返回：无
	for button: Button in _row_buttons:
		# S4-R3-01 同式（event_panel._Reset 先例）：旧行先隐藏断输入/渲染再
		# 释放（queue_free 延迟帧末——旧行与新行一帧叠渲）
		button.visible = false
		button.queue_free()
	_row_buttons.clear()
	var occupied_by: Dictionary = {}
	for inst: QuestInstance in board.accepted:
		for member_id: StringName in inst.party_ids:
			occupied_by[member_id] = inst
	var member_index: int = 0
	for member: AdventurerData in members:
		var button := Button.new()
		# 同级同名会触发 Godot 自动改名——仅首行定名（UI 级测试驱动位）
		if member_index == 0:
			button.name = "MemberRow"
		member_index += 1
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# M4-5：长文案（占用委托名等）自动换行防 1080p 溢出
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size",
				UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
		var cls: ClassDef = game_data.get_record(member.class_id) as ClassDef
		var status_text: String = UI_TEXTS[&"status_healthy"]
		if member.status == AdventurerData.Status.RESTING:
			status_text = UI_TEXTS[&"status_resting_format"] % member.rest_days
		var marks: PackedStringArray = [status_text]
		if occupied_by.has(member.unit_id):
			var inst: QuestInstance = occupied_by[member.unit_id]
			marks.append(UI_TEXTS[&"mark_quest_format"] % inst.display_name(game_data))
		if member.last_expedition_day == day:
			marks.append(UI_TEXTS[&"mark_deployed_today"])
		if pending.has(String(member.unit_id)):
			marks.append(UI_TEXTS[&"mark_pending_tendency"])
		button.text = UI_TEXTS[&"row_format"] % [member.display_name,
				cls.display_name if cls != null else String(member.class_id),
				member.level, "｜".join(marks)]
		# M6 批 3.5b 组 6：行首职业图标（ClassDef.icon_id 在档 → Button.icon；
		## 缺件/查无降级 = 纯文字行现状零改）；中4：icon 钳制 20px——64 源
		## 裸贴撑爆行高（~64px→~38px 回归，expand_icon=false + icon_max_width）
		if cls != null and not String(cls.icon_id).is_empty():
			button.icon = AssetTex.texture_of(cls.icon_id, game_data)
			button.expand_icon = false
			button.add_theme_constant_override("icon_max_width",
					CLASS_ICON_MAX_WIDTH)
		var picked_id: StringName = member.unit_id
		button.pressed.connect(func() -> void: member_selected.emit(picked_id))
		_row_box.add_child(button)
		_row_buttons.append(button)
