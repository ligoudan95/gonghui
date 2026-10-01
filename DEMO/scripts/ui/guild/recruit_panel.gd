## 招募池面板（RecruitPanel，代码构建 UI 组件）
## 职责：协会屏招募分区——候选卡（姓名/职业/属性总和/花费）+ 每行招募按钮 +
## 每日刷新提示行；招募请求经信号回抛（协会屏消费 GuildCore.recruit——
## 余额/宿舍容量校验与扣款入册在门面层）。
## 数据来源：案 5 §2.4（招募池细则）；案 17 §3.7（三档花费）。
class_name RecruitPanel
extends VBoxContainer

## 招募请求（index=候选下标）
signal recruit_requested(index: int)

## UI 文案单源（M6 批 2 挂账 4.2：内联 UI 中文收编——改措辞只动此处）
const UI_TEXTS: Dictionary = {
	&"title": "招募池",
	&"refresh_hint": "（每日日结算整池刷新；偏向缺少的职业）",
	&"empty_hint": "（今日候选已招空——等明日刷新）",
	&"candidate_format": "%s（%s）｜属性总和 %d｜花费 %d 金",
	&"recruit_button": "招募",
	&"dorm_tooltip_format": "宿舍 %d/%d｜余额 %d 金",
}

## 总控配置
var _cfg: CoreConfig = null
## 标题行
var _title_label: Label = null
## 刷新提示行
var _hint_label: Label = null
## 候选行容器
var _row_box: VBoxContainer = null
## 空池提示
var _empty_label: Label = null
## 行记录（低级1：泛型类型化）
var _rows: Array[HBoxContainer] = []

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
	_hint_label = Label.new()
	_hint_label.text = UI_TEXTS[&"refresh_hint"]
	_hint_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_small", UiTheme.FONT_SMALL))
	add_child(_hint_label)
	_row_box = VBoxContainer.new()
	_row_box.add_theme_constant_override("separation", 6)
	add_child(_row_box)
	_empty_label = Label.new()
	_empty_label.text = UI_TEXTS[&"empty_hint"]
	_empty_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	add_child(_empty_label)

func refresh(core: GuildCore) -> void:
	## 刷新候选行（全量重建；花费读表落位不得错报）
	## 参数 core：公会核心（候选与花费口径）
	## 返回：无
	for row: HBoxContainer in _rows:
		row.queue_free()
	_rows.clear()
	for index: int in core.recruit_pool.candidates.size():
		var candidate: AdventurerData = core.recruit_pool.candidates[index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_row_box.add_child(row)
		var summary: Label = Label.new()
		var cls: ClassDef = core.game_data.get_record(candidate.class_id) as ClassDef
		summary.text = UI_TEXTS[&"candidate_format"] % [candidate.display_name,
				cls.display_name if cls != null else String(candidate.class_id),
				RecruitPool.total_attrs(candidate), core.recruit_pool.cost_of(candidate)]
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary.add_theme_font_size_override("font_size",
				UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
		row.add_child(summary)
		var button := Button.new()
		button.name = "RecruitButton"
		button.text = UI_TEXTS[&"recruit_button"]
		button.disabled = core.gold < core.recruit_pool.cost_of(candidate) \
				or core.roster.size() >= core.dorm_capacity()
		button.tooltip_text = UI_TEXTS[&"dorm_tooltip_format"] % [core.roster.size(),
				core.dorm_capacity(), core.gold]
		button.add_theme_font_size_override("font_size",
				UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
		var picked_index: int = index
		button.pressed.connect(func() -> void: recruit_requested.emit(picked_index))
		row.add_child(button)
		_rows.append(row)
	_empty_label.visible = core.recruit_pool.candidates.is_empty()
