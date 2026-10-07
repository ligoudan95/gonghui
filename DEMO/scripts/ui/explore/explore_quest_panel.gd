## 探索屏右栏（ExploreQuestPanel，代码构建 UI 组件——三栏改版批）
## 职责：委托信息侧栏——委托名/状态行（达成态绿显）/耗时行/途中所得行
## （三项全零隐藏整行；拼装与 explore_screen._RewardTextOf 同构防双源）/
## 图例行（五类点位 icon_pt_* 贴图，缺件降级字形——ExploreBoard.KIND_GLYPHS
## 值语义）/弹性 spacer/撤退按钮（触控热区 220×48 保持断言口径）。
## 文案口径：UI 层单源（no_quest/free_status 等状态文案在宿主
## explore_screen.UI_TEXTS——经 refresh_quest 参数传入；本表只承载右栏
## 结构文案与图例文案）。
## 组件内运行时节点不用 % 唯一名（DaySummaryPanel 先例——成员变量直引）。
class_name ExploreQuestPanel
extends VBoxContainer

## 撤退按钮按下信号（内部 Button.pressed 转发——宿主接 _OnRetreatPressed）
signal retreat_pressed

## UI 文案单源（改措辞只动此处；reward_* 三段格式串与
## explore_screen.UI_TEXTS 同值语义——防双源，改一处须同步另一处）
const UI_TEXTS: Dictionary = {
	&"days_format": "耗时 %d 天",
	&"reward_exp_format": "+%d 经验",
	&"reward_gold_format": "+%d 金",
	&"reward_reputation_format": "+%d 声望",
	&"legend_treasure": "宝箱",
	&"legend_event": "事件",
	&"legend_battle": "遭遇",
	&"legend_exit": "出口",
	&"legend_target": "目标",
}

## 图例图标渲染边长（px——占位 UI 结构参数，X3-06 豁免先例同口径，
## 归口案 16 §2.7——文档登记由 docs-updater 后续补；不入 CoreConfig）
const LEGEND_ICON_SIZE: float = 24.0
## 图例行标签字号档（cfg 键名——small 档收口）
const LEGEND_FONT_FIELD: StringName = &"ui_font_size_small"
## 撤退按钮触控热区（px——test_touch_hotzone 断言口径同值）
const RETREAT_BUTTON_MIN_SIZE: Vector2 = Vector2(220, 48)

## 图例行条目（资产 id / 降级字形 / 文案键——字形与
## ExploreBoard.KIND_GLYPHS·TARGET_GLYPH 同值语义）
const LEGEND_ENTRIES: Array = [
	{&"asset": &"icon_pt_treasure", &"glyph": "箱", &"key": &"legend_treasure"},
	{&"asset": &"icon_pt_event", &"glyph": "!", &"key": &"legend_event"},
	{&"asset": &"icon_pt_battle", &"glyph": "戈", &"key": &"legend_battle"},
	{&"asset": &"icon_pt_exit", &"glyph": "出", &"key": &"legend_exit"},
	{&"asset": &"icon_pt_target", &"glyph": "◇", &"key": &"legend_target"},
]

## 总控配置（setup 注入）
var _cfg: CoreConfig = null
## GameData（setup 注入——图例贴图解析）
var _game_data: Node = null
## 委托名行
var _quest_label: Label = null
## 状态行（达成态绿显）
var _status_label: Label = null
## 耗时行
var _days_label: Label = null
## 途中所得行（三项全零隐藏）
var _rewards_label: Label = null
## 撤退按钮（名 RetreatButton——触控热区断言锚点）
var _retreat_button: Button = null

func setup(cfg: CoreConfig, game_data: Node) -> void:
	## 构建侧栏骨架（深底面板外壳：委托名/状态/耗时/所得/图例 + 弹性 spacer
	## + 撤退按钮贴右栏底部）
	## 参数 cfg：总控配置；game_data：GameData 单例
	## 返回：无
	_cfg = cfg
	_game_data = game_data
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_FILL
	add_theme_constant_override("separation", 12)
	var shell := PanelContainer.new()
	shell.name = "Shell"
	shell.size_flags_horizontal = Control.SIZE_FILL
	shell.add_theme_stylebox_override("panel",
			UiTheme.make_dark_panel_style(cfg, game_data))
	add_child(shell)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	shell.add_child(box)
	_quest_label = Label.new()
	_quest_label.name = "QuestLabel"
	_quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	box.add_child(_quest_label)
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	box.add_child(_status_label)
	_days_label = Label.new()
	_days_label.name = "DaysLabel"
	_days_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	box.add_child(_days_label)
	_rewards_label = Label.new()
	_rewards_label.name = "RewardsLabel"
	_rewards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rewards_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	box.add_child(_rewards_label)
	box.add_child(_MakeLegendRow())
	# 弹性 spacer（面板外壳之上撑开——撤退按钮贴右栏底部）
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	_retreat_button = Button.new()
	_retreat_button.name = "RetreatButton"
	_retreat_button.custom_minimum_size = RETREAT_BUTTON_MIN_SIZE
	_retreat_button.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	_retreat_button.pressed.connect(func() -> void: retreat_pressed.emit())
	add_child(_retreat_button)

func refresh_quest(quest_name: String, status_text: String,
		status_positive: bool, run: ExpeditionRun) -> void:
	## 刷新右栏字段（委托名/状态行〔positive 绿显〕/耗时/途中所得）
	## 参数 quest_name：委托显示名；status_text：状态段文案；
	## status_positive：正向状态（出口可交付——绿显）；run：出征运行态
	## 返回：无
	_quest_label.text = quest_name
	_status_label.text = status_text
	if status_positive:
		_status_label.add_theme_color_override("font_color",
				UiTheme.color_of(_cfg, &"ui_explore_goal_banner_color",
						UiTheme.EXPLORE_GOAL_BANNER))
	else:
		_status_label.remove_theme_color_override("font_color")
	if run == null:
		_days_label.text = ""
		_rewards_label.visible = false
		return
	_days_label.text = String(UI_TEXTS[&"days_format"]) % run.total_days()
	var reward_text: String = _RewardsTextOf(run)
	_rewards_label.text = reward_text
	_rewards_label.visible = not reward_text.is_empty()

func set_retreat_button_text(text: String) -> void:
	## 撤退按钮文案落位（宿主 UI_TEXTS 单源经此口传入）
	## 参数 text：按钮文案
	## 返回：无
	_retreat_button.text = text

func set_retreat_interactable(enabled: bool) -> void:
	## 撤退按钮可用态（宿主 _SyncRetreatButton 镜像口——会话终结/移动演出/
	## 事件面板/续跑待处理期视觉禁用）
	## 参数 enabled：true = 可交互
	## 返回：无
	_retreat_button.disabled = not enabled

func _RewardsTextOf(run: ExpeditionRun) -> String:
	## 途中所得行拼装（+经验/+金/+声望——逐项非零拼接、空格 join；
	## 与 explore_screen._RewardTextOf 同构防双源：改格式串须两处同步）
	## 参数 run：出征运行态（rewards 读值）
	## 返回：所得行文本（三项全零 = 空串 → 调用方隐藏整行）
	var parts: PackedStringArray = []
	var exp: int = int(run.rewards.get(&"exp", 0))
	var gold: int = int(run.rewards.get(&"gold", 0))
	var reputation: int = int(run.rewards.get(&"reputation", 0))
	if exp != 0:
		parts.append(String(UI_TEXTS[&"reward_exp_format"]) % exp)
	if gold != 0:
		parts.append(String(UI_TEXTS[&"reward_gold_format"]) % gold)
	if reputation != 0:
		parts.append(String(UI_TEXTS[&"reward_reputation_format"]) % reputation)
	return " ".join(parts)

func _MakeLegendRow() -> HFlowContainer:
	## 构建图例行（五条目：图标/降级字形 + 标签；缺件降级字形口径与板面
	## 图标一致——AssetTex 查无走 Label 字形）。HFlowContainer 流式排布：
	## 侧栏固定宽内放不下自动换行——单行 min 宽不整行求和（不撑破 280 固定宽）
	## 参数：无
	## 返回：图例行 HFlowContainer（未挂树由调用方挂入）
	var row := HFlowContainer.new()
	row.name = "LegendRow"
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 4)
	for entry: Dictionary in LEGEND_ENTRIES:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		row.add_child(item)
		var texture: Texture2D = AssetTex.texture_of(
				entry[&"asset"] as StringName, _game_data)
		if texture != null:
			var icon := TextureRect.new()
			icon.texture = texture
			# 属性序契约（_MakeIconNode 同坑规避）：stretch/expand 先于尺寸
			icon.stretch_mode = TextureRect.STRETCH_SCALE
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.custom_minimum_size = Vector2.ONE * LEGEND_ICON_SIZE
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			item.add_child(icon)
		else:
			var glyph := Label.new()
			glyph.text = String(entry[&"glyph"])
			glyph.custom_minimum_size = Vector2.ONE * LEGEND_ICON_SIZE
			glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			item.add_child(glyph)
		var caption := Label.new()
		caption.text = String(UI_TEXTS[entry[&"key"]])
		caption.add_theme_font_size_override("font_size",
				UiTheme.font_of(_cfg, LEGEND_FONT_FIELD, UiTheme.FONT_SMALL))
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(caption)
	return row
