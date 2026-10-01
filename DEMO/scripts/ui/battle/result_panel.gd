## 战斗结算面板（ResultPanel，PanelContainer——居中弹出）
## 职责：终局结算展示——胜（「战斗胜利」）/ 败（「战败·全队重伤休养」——
## 天数以回城结算为准，不在本面板硬编码）/ 撤退（「撤退成功·委托失败·
## 无重伤」P1 口径）+ 战报摘要（回合数/倒地名单）+ 返回按钮（发出信号由
## battle_screen 路由回公会壳）。
## 数据来源：M1 批 3 方案 §7.1（ResultPanel 文案口径）；M-1/P1 文案修订。
class_name ResultPanel
extends PanelContainer

## 返回按钮文案（M-6 拍板：按去向分流——探索通道（遭遇战/B 出口战胜回探索
## 屏续跑）=「继续探索」；缺省（回城终结）=「返回公会」——常量惯例对齐
## battle_screen.COMMON_ATTACK_NAME 先例）
const RETURN_LABEL_EXPLORE: String = "继续探索"
const RETURN_LABEL_GUILD: String = "返回公会"
## 面板最小尺寸（S5-M5-1-h：原 Vector2 字面量提常量）
const PANEL_MIN_SIZE: Vector2 = Vector2(420, 0)
## 返回按钮最小尺寸（S4-10：与 PANEL_MIN_SIZE 同口径提常量——原内联字面量）
const RETURN_BUTTON_MIN_SIZE: Vector2 = Vector2(200, 56)
## 撤退分流文案（功能二批 3 Q-A：有倒地者——委托失败但倒地队员回城转重伤）
const RETREAT_DOWNED_DETAIL: String = "委托按失败结算；倒地的 %d 名队员回城将转重伤休养（天数以回城结算为准）。"
## 胜利追加行（功能二批 3：胜利但有倒地者——回城同样转重伤）
const VICTORY_DOWNED_LINE: String = "%d 名队员倒地——回城将转重伤休养。"

## UI 文案单源（M6 批 2 挂账 4.2：内联 UI 中文收编——改措辞只动此处）
const UI_TEXTS: Dictionary = {
	&"victory_title": "战斗胜利",
	&"victory_detail": "奖励与经验将在回城结算时入账。",
	&"defeat_title": "战败·全队重伤休养",
	&"defeat_detail": "全队将重伤休养——天数以回城结算为准。",
	&"retreat_title": "撤退成功·委托失败",
	&"retreat_no_downed_detail": "委托按失败结算，队伍不会重伤。",
	&"summary_line_format": "\n回合数：%d｜倒地：%s",
	&"downed_none": "无",
}

## 返回按钮按下信号（battle_screen 连接并路由场景切换）
signal return_pressed


## 标题标签
var _title_label: Label = null
## 详情标签
var _detail_label: Label = null
## 返回按钮
var _return_button: Button = null

func _ready() -> void:
	## 引擎回调：构建面板子节点（默认隐藏）
	## 参数：无
	## 返回：无
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = PANEL_MIN_SIZE
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title_label)
	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_label)
	_return_button = Button.new()
	_return_button.text = RETURN_LABEL_GUILD
	# R3-08：占位字号档位化（弹出前布局按档位预估——tscn/默认值不参与体系）
	_title_label.add_theme_font_size_override("font_size", UiTheme.FONT_HEADING)
	_detail_label.add_theme_font_size_override("font_size", UiTheme.FONT_NORMAL)
	_return_button.custom_minimum_size = RETURN_BUTTON_MIN_SIZE
	_return_button.pressed.connect(func() -> void: return_pressed.emit())
	box.add_child(_return_button)
	add_child(box)
	visible = false

func set_return_label(return_to_explore: bool) -> void:
	## 返回按钮文案分流（M-6 拍板——battle_screen 按 _return_to 通道调用）
	## 参数 return_to_explore：true = 回探索屏续跑（继续探索）；false = 回公会
	## 返回：无
	_return_button.text = RETURN_LABEL_EXPLORE if return_to_explore \
			else RETURN_LABEL_GUILD

func show_result(result: BattleResult, name_lookup: Callable = Callable(),
		cfg: CoreConfig = null, ally_downed_names: Array[String] = []) -> void:
	## 展示终局结算（文案按口径；战报摘要附详情行）
	## 参数 result：战斗结果；name_lookup：unit_id → 显示名解析（2026-09-24
	## 七轮反馈：倒地名单中文化；缺省回退 id 原文）；cfg：总控配置（B-3/B-7
	## 表驱动配色与字号，可空）；ally_downed_names：本战我方倒地名单
	##（功能二批 3——battle_screen 经 context.allies 过滤传入，默认空 =
	## 旧调用方零改动）
	## 返回：无
	# B-7：字号档位（heading/normal）
	_title_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_heading", UiTheme.FONT_HEADING))
	_detail_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	var victory_color: Color = UiTheme.color_of(cfg, &"ui_highlight_gold_color",
			UiTheme.HIGHLIGHT_GOLD)
	match result.kind:
		BattleResult.ResultKind.VICTORY:
			_title_label.text = UI_TEXTS[&"victory_title"]
			# B-3：金色高亮三处统一（序条/结算/徽章环共用 ui_highlight_gold_color）
			_title_label.add_theme_color_override("font_color", victory_color)
			# M-1：天数/奖励不在本面板硬编码——具体数值以回城结算面板为准
			_detail_label.text = UI_TEXTS[&"victory_detail"]
			# 功能二批 3：胜利但有倒地者——追加转重伤提示行
			if not ally_downed_names.is_empty():
				_detail_label.text += "\n" + VICTORY_DOWNED_LINE % ally_downed_names.size()
		BattleResult.ResultKind.DEFEAT:
			_title_label.text = UI_TEXTS[&"defeat_title"]
			_title_label.add_theme_color_override("font_color",
					UiTheme.color_of(cfg, &"ui_result_defeat_color", UiTheme.RESULT_DEFEAT))
			# M-1：休养天数随宿舍等级浮动——不在本面板硬编码，以回城结算为准
			_detail_label.text = UI_TEXTS[&"defeat_detail"]
		_:
			_title_label.text = UI_TEXTS[&"retreat_title"]
			_title_label.add_theme_color_override("font_color",
					UiTheme.color_of(cfg, &"ui_result_retreat_color", UiTheme.RESULT_RETREAT))
			# P1 拍板：撤退=委托失败但无重伤（文案与 RETREAT 单独映射口径同步）；
			# 功能二批 3 Q-A：有倒地者分流——回城转重伤（天数以回城结算为准）
			if ally_downed_names.is_empty():
				_detail_label.text = UI_TEXTS[&"retreat_no_downed_detail"]
			else:
				_detail_label.text = RETREAT_DOWNED_DETAIL % ally_downed_names.size()
	var downed_text: String = "、".join(result.downed_units.map(func(unit_id):
		if name_lookup.is_valid():
			return String(name_lookup.call(unit_id))
		return String(unit_id)))
	_detail_label.text += UI_TEXTS[&"summary_line_format"] % [
			result.rounds_used,
			downed_text if not downed_text.is_empty() else UI_TEXTS[&"downed_none"],
	]
	visible = true
