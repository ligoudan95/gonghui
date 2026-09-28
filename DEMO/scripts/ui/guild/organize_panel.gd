## 编队派遣弹层（OrganizePanel，代码构建 UI 组件）
## 职责：接单/重编队共用的选人弹层——名册成员勾选列表（带占用/休养/当日已
## 出征标记，不可选者禁用）+ 人力区间提示 + 确认/取消；**三预览（M4 批 3）**：
## ①检定预览=对照模板 recommend_attrs 逐人显示推荐属性值、低于调整值线的
## 短板属性标 △；②超额预览=当前勾选人数的奖励倍率与预计奖励（口径=模板
## excess>0 否则 cfg.quest_excess_bonus_per_head，拍板③——×(1+率×超额) 仅货币
## 与经验、声望不加）；③沿用上次编队一键（last_party_by_tpl 已持久化）。
## 数据来源：案 5 §2.6（编队）；案 6 §2.4（人力区间+超额加成）；案 17 §3.7。
## UI 规范：UiTheme 深底面板/字号档位；弹层 z 置顶（宿主屏 z 契约）。
class_name OrganizePanel
extends PanelContainer

## 编队确认（serial=实例序号；member_ids=选中成员 id——顺序即队伍序）
signal confirmed(serial: int, member_ids: Array[StringName])
## 取消
signal cancelled

## 弹层 z（压过屏内容——宿主屏消费同值契约；对齐 explore 屏 UI 弹层口径）
const POPUP_Z_INDEX: int = 100
## 弹层最小宽（Z2-13：给 autowrap 留换行空间；占位 UI 结构参数——
## EVENT_PANEL_WIDTH 同豁免口径）
const ORGANIZE_PANEL_MIN_WIDTH: int = 560
## 人力区间兜底（模板查无时的展示兜底——校验权威在 GuildCore 门面）
const FALLBACK_PARTY_MIN: int = 1
const FALLBACK_PARTY_MAX: int = 4

## UI 文案单源（M4 增补批：轻度弹层适配——改措辞只动此处）
const UI_TEXTS: Dictionary = {
	&"light_open_hint": "确认后立即开工：工期 %d 天（无需出征，占用至完成或放弃）",
	&"light_confirm": "派出开工",
}

## 总控配置
var _cfg: CoreConfig = null
## 标题（委托名+人力区间）
var _title_label: Label = null
## 预览行（超额奖励倍率——勾选联动刷新）
var _preview_label: Label = null
## 检定预览行（模板推荐属性汇总）
var _recommend_label: Label = null
## 提示行（区间/失败原因）
var _hint_label: Label = null
## 成员勾选容器
var _member_box: VBoxContainer = null
## 确认/取消/沿用上次按钮
var _confirm_button: Button = null
var _last_party_button: Button = null
## 当前编辑实例序号
var _serial: int = 0
## 当前编辑实例模板（预览口径）
var _tpl: QuestTemplateDef = null
## 公会核心（沿用上次编队读 last_party_by_tpl）
var _core: GuildCore = null
## 勾选节点记录（unit_id -> CheckBox）
var _checks: Dictionary = {}

func setup(cfg: CoreConfig) -> void:
	## 构建弹层骨架（初始隐藏）
	## 参数 cfg：总控配置
	## 返回：无
	_cfg = cfg
	visible = false
	z_index = POPUP_Z_INDEX
	add_theme_stylebox_override("panel", UiTheme.make_dark_panel_style(cfg))
	custom_minimum_size = Vector2(ORGANIZE_PANEL_MIN_WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title_label = _MakeLabel(box, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recommend_label = _MakeLabel(box, &"ui_font_size_normal", UiTheme.FONT_NORMAL)
	_recommend_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label = _MakeLabel(box, &"ui_font_size_normal", UiTheme.FONT_NORMAL)
	_preview_label.add_theme_color_override("font_color",
			UiTheme.color_of(cfg, &"ui_highlight_gold_color", UiTheme.HIGHLIGHT_GOLD))
	_hint_label = _MakeLabel(box, &"ui_font_size_normal", UiTheme.FONT_NORMAL)
	_member_box = VBoxContainer.new()
	_member_box.add_theme_constant_override("separation", 4)
	box.add_child(_member_box)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	_last_party_button = Button.new()
	_last_party_button.name = "UseLastPartyButton"
	_last_party_button.text = "沿用上次编队"
	_last_party_button.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	_last_party_button.pressed.connect(_OnUseLastPartyPressed)
	buttons.add_child(_last_party_button)
	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmButton"
	_confirm_button.text = "确认编队"
	_confirm_button.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	_confirm_button.pressed.connect(_OnConfirmPressed)
	buttons.add_child(_confirm_button)
	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
	buttons.add_child(cancel_button)

func open(inst: QuestInstance, core: GuildCore) -> void:
	## 打开弹层（接单/重编队共用——重编队预选当前编队，接单预选沿用记忆）：
	## 成员行按名册全列，占用（他单）/休养/当日已出征者禁选；推荐属性值随行
	## 展示（短板标 △——低于 cfg.attr_modifier_offset 即调整值转负线）
	## 参数 inst：目标实例；core：公会核心
	## 返回：无
	_serial = inst.serial
	_core = core
	_tpl = core.game_data.get_record(inst.template_id) as QuestTemplateDef
	var party_min: int = _tpl.party_min if _tpl != null else FALLBACK_PARTY_MIN
	var party_max: int = _tpl.party_max if _tpl != null else FALLBACK_PARTY_MAX
	_title_label.text = "编队：%s（需 %d-%d 人）" % [inst.display_name(core.game_data),
			party_min, party_max]
	_hint_label.text = ""
	for check: CheckBox in _checks.values():
		check.queue_free()
	_checks.clear()
	var occupied: Array[StringName] = core.board.occupied_member_ids(inst)
	var preselect: Array[StringName] = []
	if not inst.party_ids.is_empty():
		preselect = inst.party_ids
	elif core.last_party_by_tpl.has(String(inst.template_id)):
		for member_id: StringName in core.last_party_by_tpl[String(inst.template_id)]:
			preselect.append(member_id)
	_last_party_button.visible = core.last_party_by_tpl.has(String(inst.template_id))
	for member: AdventurerData in core.roster:
		var check := CheckBox.new()
		check.add_theme_font_size_override("font_size",
				UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
		var marks: PackedStringArray = []
		if member.status == AdventurerData.Status.RESTING:
			marks.append("休养%d天" % member.rest_days)
		if occupied.has(member.unit_id):
			marks.append("占用中")
		if member.last_expedition_day == core.day:
			marks.append("今日已出征")
		var cls: ClassDef = core.game_data.get_record(member.class_id) as ClassDef
		check.text = "%s（%s Lv%d）%s%s" % [member.display_name,
				cls.display_name if cls != null else String(member.class_id),
				member.level, _RecommendTextOf(member), "｜".join(marks)]
		check.disabled = member.status != AdventurerData.Status.HEALTHY \
				or occupied.has(member.unit_id)
		check.button_pressed = preselect.has(member.unit_id) and not check.disabled
		check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		check.toggled.connect(func(_on: bool) -> void: _UpdatePreview())
		_member_box.add_child(check)
		_checks[member.unit_id] = check
	_recommend_label.text = _RecommendSummary()
	# M4 增补批：轻度弹层适配——提示行与确认钮换轻度文案（confirmed 信号与
	# 禁选逻辑零改动——路由分流在协会屏 _OnOrganizeConfirmed）
	if _tpl != null and _tpl.exec_class == QuestTemplateDef.ExecClass.NON_COMBAT:
		_hint_label.text = String(UI_TEXTS[&"light_open_hint"]) % _tpl.duration_days
		_confirm_button.text = UI_TEXTS[&"light_confirm"]
	else:
		_confirm_button.text = "确认编队"
	_UpdatePreview()
	visible = true

func _RecommendAttrs() -> Array[StringName]:
	## 模板推荐属性对（空=无推荐口径）
	## 参数：无
	## 返回：推荐属性 id 列表
	if _tpl == null:
		return []
	return _tpl.recommend_attrs

func _RecommendTextOf(member: AdventurerData) -> String:
	## 单成员检定预览段：推荐属性值逐项（低于调整值线=短板标 △）
	## 参数 member：成员
	## 返回：文案段（无推荐属性返回空串）
	var attrs: Array[StringName] = _RecommendAttrs()
	if attrs.is_empty():
		return ""
	var parts: PackedStringArray = []
	for attr_id: StringName in attrs:
		var value: int = int(member.attrs.get(attr_id, AttrKeys.DEFAULT_ATTR_VALUE))
		var mark: String = " △" if value < _cfg.attr_modifier_offset else ""
		parts.append("%s%d%s" % [String(QuestCard.ATTR_NAMES.get(attr_id, attr_id)),
				value, mark])
	return "｜推荐：%s " % " ".join(parts)

func _RecommendSummary() -> String:
	## 检定预览汇总行（推荐属性名+短板判定线说明）
	## 参数：无
	## 返回：汇总文案
	var attrs: Array[StringName] = _RecommendAttrs()
	if attrs.is_empty():
		return "本委托无推荐属性口径。"
	var names: PackedStringArray = []
	for attr_id: StringName in attrs:
		names.append(String(QuestCard.ATTR_NAMES.get(attr_id, attr_id)))
	return "检定预览：推荐 %s（数值低于 %d 的短板属性已标 △）" % [
			"、".join(names), _cfg.attr_modifier_offset]

func _UpdatePreview() -> void:
	## 超额预览刷新（勾选联动）：当前人数/超额数/倍率/预计货币与经验；
	## **超上限警示**（Z2-4：超出 party_max 改警示文案非金色——不诱导确认）
	## 参数：无
	## 返回：无
	if _tpl == null or _tpl.reward == null:
		_preview_label.text = ""
		return
	var picked: int = _CountChecked()
	if picked > _tpl.party_max:
		_preview_label.add_theme_color_override("font_color",
				UiTheme.color_of(_cfg, &"ui_result_defeat_color", UiTheme.RESULT_DEFEAT))
		_preview_label.text = "已选 %d 人——超出上限 %d，无法确认" % [
				picked, _tpl.party_max]
		return
	var excess: int = maxi(0, picked - _tpl.party_min)
	var rate: float = _tpl.excess_bonus_per_head if _tpl.excess_bonus_per_head > 0.0 \
			else _cfg.quest_excess_bonus_per_head
	var multiplier: float = 1.0 + rate * excess
	_preview_label.add_theme_color_override("font_color",
			UiTheme.color_of(_cfg, &"ui_highlight_gold_color", UiTheme.HIGHLIGHT_GOLD))
	_preview_label.text = "超额预览：已选 %d 人（超额 %d）→ 奖励 ×%.2f ≈ %d 金 / %d 经验（声望不加）" % [
			picked, excess, multiplier, roundi(_tpl.reward.gold * multiplier),
			roundi(_tpl.reward.exp * multiplier)]

func _CountChecked() -> int:
	## 勾选人数
	## 参数：无
	## 返回：人数
	var count: int = 0
	for check: CheckBox in _checks.values():
		if check.button_pressed:
			count += 1
	return count

func _OnUseLastPartyPressed() -> void:
	## 沿用上次编队一键：按 last_party_by_tpl 勾选（不可选成员自动跳过）
	## 参数：无
	## 返回：无
	if _core == null or _tpl == null:
		return
	var last_party: Array[StringName] = []
	if _core.last_party_by_tpl.has(String(_tpl.id)):
		for member_id: StringName in _core.last_party_by_tpl[String(_tpl.id)]:
			last_party.append(member_id)
	if last_party.is_empty():
		return
	for unit_id: StringName in _checks:
		var check: CheckBox = _checks[unit_id]
		check.button_pressed = last_party.has(unit_id) and not check.disabled
	_UpdatePreview()

func close() -> void:
	## 关闭弹层
	## 参数：无
	## 返回：无
	visible = false

func _OnConfirmPressed() -> void:
	## 确认编队：收集勾选成员回抛（人数区间校验归 GuildCore 门面——
	## 失败原因经 hint 呈现）
	## 参数：无
	## 返回：无
	var selected: Array[StringName] = []
	for unit_id: StringName in _checks:
		var check: CheckBox = _checks[unit_id]
		if check.button_pressed:
			selected.append(unit_id)
	confirmed.emit(_serial, selected)

func show_hint(text: String) -> void:
	## 校验失败提示（GuildCore.last_error 呈现口）
	## 参数 text：提示文本
	## 返回：无
	_hint_label.text = text

func _MakeLabel(parent: Node, field: StringName, fallback: int) -> Label:
	## 建标签（字号档位表驱动）
	## 参数 parent：父容器；field/fallback：cfg 字段与兜底档位
	## 返回：Label
	var label := Label.new()
	label.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, field, fallback))
	parent.add_child(label)
	return label
