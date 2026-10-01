## 成员详情弹层（MemberDetailPanel，代码构建 UI 组件）
## 职责：单名成员养成总览——属性七项/装备槽位（字段位展示——DEMO 固定初始
## 套装不卸换）/状态与休养/技能总览（**普攻条目 D3 口径：skl_atk_* 常驻展示
## 不占技能点、不入解锁列表**）/花技能点解锁档 1 技能（GrowthCore.unlock_skill）
## /倾向选择入口（转发 LevelupPanel）。
## 数据来源：案 5 §2.1/§2.3/§3（属性/成长/装备槽字段）；案 10 §3（D3 普攻口径）。
## UI 规范：UiTheme 深底面板/字号档位；弹层 z=100 置顶（organize_panel 先例）。
class_name MemberDetailPanel
extends PanelContainer

## 关闭请求
signal close_requested
## 倾向选择入口（unit_id——宿主转开 LevelupPanel）
signal tendency_select_requested(unit_id: StringName)
## 成员数据变更（技能解锁——宿主刷新总览）
signal member_changed(unit_id: StringName)

## 弹层 z（单源置顶——organize_panel 先例）
const POPUP_Z_INDEX: int = 100

## UI 文案单源（M6 批 2 挂账 4.2：内联 UI 中文收编——改措辞只动此处）
const UI_TEXTS: Dictionary = {
	&"title_format": "%s（%s Lv%d）",
	&"status_healthy": "健康",
	&"status_resting_format": "休养 %d 天",
	&"status_backlog_format": "｜有 %d 级成长待选倾向",
	&"exp_format": "经验 %d/%d",
	&"exp_capped": "已满级",
	&"status_line_format": "状态：%s｜%s｜技能点 %d",
	&"attr_line_format": "%s %d",
	&"skills_title": "技能",
	&"attack_skill_format": "· %s（普攻·常驻不占点）",
	&"learned_skill_format": "· %s（已解锁）",
	&"no_learned_skill": "·（暂无已解锁技能——初始队员技能已预解锁、招募成员花点解锁）",
	&"locked_skill_format": "· %s（未解锁）",
	&"unlock_button_format": "解锁（%d 点）",
	&"tendency_chosen_format": "倾向：%s（侧重 %s）",
	&"tendency_none_format": "倾向：未选（升级侧重成长待定%s）",
	&"tendency_backlog_format": "——已有 %d 级悬置",
	&"choose_tendency_button": "选择倾向",
	&"close_button": "关闭",
	&"equip_format": "装备（初始套装·固定）：%s｜武器加值 %d｜护甲 %d",
	&"equip_missing": "装备（初始套装·固定）：未查到职业套装",
}

## 总控配置
var _cfg: CoreConfig = null
## 内容容器
var _box: VBoxContainer = null
## 当前展示成员
var _member: AdventurerData = null
## 公会核心（注入于 open——pending 悬置读数）
var _core: GuildCore = null

func setup(cfg: CoreConfig) -> void:
	## 构建弹层骨架（初始隐藏）
	## 参数 cfg：总控配置
	## 返回：无
	_cfg = cfg
	visible = false
	z_index = POPUP_Z_INDEX
	add_theme_stylebox_override("panel", UiTheme.make_dark_panel_style(cfg))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)

func open(member: AdventurerData, core: GuildCore) -> void:
	## 打开并构建成员详情（全量重建——解锁/选倾向后重开即刷新）
	## 参数 member：目标成员；core：公会核心（pending 悬置与数据源）
	## 返回：无
	_member = member
	_core = core
	_Rebuild()
	visible = true

func close() -> void:
	## 关闭弹层
	## 参数：无
	## 返回：无
	visible = false

func _Rebuild() -> void:
	## 内容全量重建（标题/属性/装备/状态/技能/倾向）
	## 参数：无
	## 返回：无
	for child: Node in _box.get_children():
		child.queue_free()
	var game_data: Node = _core.game_data
	var cls: ClassDef = game_data.get_record(_member.class_id) as ClassDef
	var class_name_text: String = cls.display_name if cls != null else String(_member.class_id)
	_MakeLabel("title", &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING).text = \
			UI_TEXTS[&"title_format"] % [_member.display_name, class_name_text, _member.level]
	# 状态行（健康/休养 + 悬置倾向提示；满级成员经验段显示「已满级」——M4-8）
	var status_text: String = UI_TEXTS[&"status_healthy"] \
			if _member.status == AdventurerData.Status.HEALTHY \
			else UI_TEXTS[&"status_resting_format"] % _member.rest_days
	var backlog: int = int(_core.pending_tendency_levels.get(String(_member.unit_id), 0))
	if backlog > 0:
		status_text += UI_TEXTS[&"status_backlog_format"] % backlog
	var exp_text: String = UI_TEXTS[&"exp_format"] % [_member.exp,
			GrowthCore.exp_to_next(_member.level, _cfg)] \
			if _member.level < _cfg.level_cap else UI_TEXTS[&"exp_capped"]
	_MakeLabel("", &"ui_font_size_normal", UiTheme.FONT_NORMAL).text = \
			UI_TEXTS[&"status_line_format"] % [
			status_text, exp_text, _member.skill_points]
	# 属性行（七属性中文——QuestCard.ATTR_NAMES 单源复用）
	var attr_parts: PackedStringArray = []
	for attr_id: StringName in AttrKeys.seven_attrs():
		attr_parts.append(UI_TEXTS[&"attr_line_format"] % [String(QuestCard.ATTR_NAMES.get(attr_id, attr_id)),
				int(_member.attrs.get(attr_id, AttrKeys.DEFAULT_ATTR_VALUE))])
	_MakeLabel("", &"ui_font_size_normal", UiTheme.FONT_NORMAL).text = " ".join(attr_parts)
	# 装备槽位（字段位展示——DEMO 固定初始套装：按职业查 equip 域）
	_MakeLabel("", &"ui_font_size_normal", UiTheme.FONT_NORMAL).text = _EquipText(game_data)
	# 技能总览：普攻（D3 常驻不占点）+ 已解锁 + 可解锁（花点按钮）
	_MakeLabel("", &"ui_font_size_body", UiTheme.FONT_BODY).text = UI_TEXTS[&"skills_title"]
	var attack_id: StringName = cls.base_attack_skill_id if cls != null else &""
	var attack: SkillDef = game_data.get_record(attack_id) as SkillDef
	_MakeLabel("", &"ui_font_size_normal", UiTheme.FONT_NORMAL).text = UI_TEXTS[&"attack_skill_format"] % [
			attack.display_name if attack != null else String(attack_id)]
	var learned: PackedStringArray = []
	for skill_id: StringName in _member.skill_ids:
		var skill: SkillDef = game_data.get_record(skill_id) as SkillDef
		learned.append(UI_TEXTS[&"learned_skill_format"] % (skill.display_name if skill != null else String(skill_id)))
	if learned.is_empty():
		learned.append(UI_TEXTS[&"no_learned_skill"])
	for line: String in learned:
		_MakeLabel("", &"ui_font_size_normal", UiTheme.FONT_NORMAL).text = line
	var tier_one_ids: Array[StringName] = []
	for skill_id: StringName in game_data.get_domain_ids(&"class/skills"):
		var skill: SkillDef = game_data.get_record(skill_id) as SkillDef
		if skill != null and skill.owner_id == _member.class_id and skill.tier == 1 \
				and not _member.skill_ids.has(skill_id):
			tier_one_ids.append(skill_id)
	tier_one_ids.sort()
	for skill_id: StringName in tier_one_ids:
		var skill: SkillDef = game_data.get_record(skill_id) as SkillDef
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_box.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size",
				UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
		label.text = UI_TEXTS[&"locked_skill_format"] % (skill.display_name if skill != null else String(skill_id))
		row.add_child(label)
		var button := Button.new()
		button.name = "UnlockButton"
		button.text = UI_TEXTS[&"unlock_button_format"] % _cfg.skill_unlock_cost
		button.disabled = _member.skill_points < _cfg.skill_unlock_cost
		button.add_theme_font_size_override("font_size",
				UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
		button.pressed.connect(_OnUnlockPressed.bind(skill_id))
		row.add_child(button)
	# 倾向区：已选展示 / 未选入口（LevelupPanel 消费）
	var tendency_area := HBoxContainer.new()
	tendency_area.add_theme_constant_override("separation", 8)
	_box.add_child(tendency_area)
	var tendency_label := Label.new()
	tendency_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tendency_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	var chosen: TendencyDef = GrowthCore.resolve_tendency(_member, game_data)
	if chosen != null:
		var focus_names: PackedStringArray = []
		for attr_id: StringName in chosen.focus_attrs:
			focus_names.append(String(QuestCard.ATTR_NAMES.get(attr_id, attr_id)))
		tendency_label.text = UI_TEXTS[&"tendency_chosen_format"] % [chosen.display_name, "、".join(focus_names)]
	else:
		tendency_label.text = UI_TEXTS[&"tendency_none_format"] % \
				(UI_TEXTS[&"tendency_backlog_format"] % backlog if backlog > 0 else "")
	tendency_area.add_child(tendency_label)
	if chosen == null:
		var tendency_button := Button.new()
		tendency_button.name = "ChooseTendencyButton"
		tendency_button.text = UI_TEXTS[&"choose_tendency_button"]
		tendency_button.add_theme_font_size_override("font_size",
				UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
		tendency_button.pressed.connect(func() -> void:
				tendency_select_requested.emit(_member.unit_id))
		tendency_area.add_child(tendency_button)
	# 关闭
	var close_button := Button.new()
	close_button.name = "CloseDetailButton"
	close_button.text = UI_TEXTS[&"close_button"]
	close_button.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	close_button.pressed.connect(func() -> void: close_requested.emit())
	_box.add_child(close_button)

func _EquipText(game_data: Node) -> String:
	## 装备槽位文案（字段位展示：DEMO 固定初始套装——按职业查 equip 域；
	## 换装管理归完整版，案 4）
	## 参数 game_data：GameData
	## 返回：装备文案
	for record: Resource in game_data.get_domain(&"equip"):
		var equip := record as EquipDef
		if equip.class_ref == _member.class_id:
			return UI_TEXTS[&"equip_format"] % [
					equip.display_name, equip.weapon_bonus, equip.armor_value]
	return UI_TEXTS[&"equip_missing"]

func _OnUnlockPressed(skill_id: StringName) -> void:
	## 技能解锁（GrowthCore.unlock_skill——校验点数/归属/重复；成功后重建+通知）
	## 参数 skill_id：技能 id
	## 返回：无
	if GrowthCore.unlock_skill(_member, skill_id, _cfg, _core.game_data):
		_Rebuild()
		member_changed.emit(_member.unit_id)

func _MakeLabel(node_name: String, field: StringName, fallback: int) -> Label:
	## 建标签（可选节点名——测试驱动位）
	## 参数 node_name：节点名（空=不定名）；field/fallback：cfg 字段与兜底档位
	## 返回：Label
	var label := Label.new()
	if not node_name.is_empty():
		label.name = node_name
	label.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, field, fallback))
	_box.add_child(label)
	return label
