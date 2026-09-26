## 事件面板（EventPanel，PanelContainer——可复用弹层组件）
## 职责：事件视图呈现与交互——叙述文本、选项列表（尾部自动拼「属性·难度(线)」
## 标注）、改派子面板（按所点选项属性现算候选、排序默认最高高亮、空名单
## 提示+取消）、D20 演出（数字滚动点按跳过、演出期输入门禁）、四档反馈条
## （四色标签+结算文本+数值反馈行）、B 出口战前演出视图（「进入战斗」）。
## check_cast 改派面板内嵌（M2 方案批 3 允许合并）。
## 数据来源：M2 方案批 3；案 18 §3（机制词只在反馈标签不入叙述）。
## UI 口径：字号走 UiTheme 档位；四档色 cfg 表驱动；属性中文映射 = UI 层
## 有限枚举字典（豁免先例）；热区 ≥48px。
class_name EventPanel
extends PanelContainer

## 选项选择信号（参数 = 选项 id + 施检者——宿主路由 choose_option）
signal option_chosen(option_id: StringName, actor: AdventurerData)
## 继续信号（结算视图的「继续」钮）
signal continue_pressed
## 进入战斗信号（B 出口战前演出视图的「进入战斗」钮——宿主路由战斗屏）
signal battle_pressed

## 七属性 id -> 中文（UI 层有限枚举字典——豁免先例：展示映射非业务口径）
const ATTR_NAMES: Dictionary = {
	&"strength": "力量", &"agility": "敏捷", &"constitution": "体质",
	&"intelligence": "智力", &"perception": "感知", &"willpower": "意志",
	&"luck": "幸运",
}
## 空改派名单提示（E3-13：全员倒地可达——提示+取消路径）
const NO_CAST_TEXT: String = "没有能执行检定的队员。"

## 总控配置（setup 注入）
var _cfg: CoreConfig = null
## 改派候选供给闭包（attr_id -> Array——宿主注入按属性现算 E4；
## 未注入时按空名单处理）
var _cast_provider: Callable = Callable()
## 叙述标签
var _narrative_label: RichTextLabel = null
## 选项容器
var _options_box: VBoxContainer = null
## 改派子面板（候选人按钮组）
var _cast_box: VBoxContainer = null
## 当前检定视图（改派中/取消恢复用）
var _pending_check: Dictionary = {}
## 当前呈现视图（空名单取消时恢复呈现）
var _current_view: EventRunner.EventView = null
## D20 演出标签（滚动期显示）
var _d20_label: Label = null
## 反馈条（四档标签+文本+数值行）
var _grade_label: Label = null
var _result_label: RichTextLabel = null
## 继续钮
var _continue_button: Button = null
## 进入战斗钮（B 出口战前演出视图）
var _battle_button: Button = null
## D20 跳过请求
var _d20_skip: bool = false
## 输入门禁（E3-03：D20 演出期候选/选项钮可点会双结算——演出起闭、
## 呈结果止，期间禁用全部交互钮）
var _busy: bool = false

func setup(cfg: CoreConfig) -> void:
	## 装配面板子树（宿主 _ready 调）；B-4 深底 + UiTheme 档位
	## 参数 cfg：总控配置（四档色/字号/演出时长表驱动）
	## 返回：无
	_cfg = cfg
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiTheme.make_dark_panel_style(cfg))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_narrative_label = RichTextLabel.new()
	_narrative_label.bbcode_enabled = true
	_narrative_label.fit_content = true
	_narrative_label.scroll_active = false
	_narrative_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narrative_label.add_theme_font_size_override("normal_font_size",
			UiTheme.font_of(cfg, &"ui_font_size_body", UiTheme.FONT_BODY))
	box.add_child(_narrative_label)
	_options_box = VBoxContainer.new()
	_options_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options_box.add_theme_constant_override("separation", 6)
	box.add_child(_options_box)
	_cast_box = VBoxContainer.new()
	_cast_box.visible = false
	box.add_child(_cast_box)
	_d20_label = Label.new()
	_d20_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d20_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_display", UiTheme.FONT_DISPLAY))
	_d20_label.visible = false
	box.add_child(_d20_label)
	_grade_label = Label.new()
	_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	_grade_label.visible = false
	box.add_child(_grade_label)
	_result_label = RichTextLabel.new()
	_result_label.bbcode_enabled = true
	_result_label.fit_content = true
	_result_label.scroll_active = false
	_result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_label.add_theme_font_size_override("normal_font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	box.add_child(_result_label)
	_continue_button = Button.new()
	_continue_button.text = "继续"
	_continue_button.custom_minimum_size = Vector2(160, 48)
	_continue_button.visible = false
	_continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	box.add_child(_continue_button)
	_battle_button = Button.new()
	_battle_button.text = "进入战斗"
	_battle_button.custom_minimum_size = Vector2(160, 48)
	_battle_button.visible = false
	_battle_button.pressed.connect(func() -> void: battle_pressed.emit())
	box.add_child(_battle_button)
	add_child(box)

func set_cast_provider(provider: Callable) -> void:
	## 注入改派候选供给闭包（E4：按**所点选项**的属性现算——多属性节点
	## 点不同选项各按其属性取候选，取代视图首个检定选项口径）
	## 参数 provider：attr_id -> Array（CheckPicker.candidates 产物）
	## 返回：无
	_cast_provider = provider

func show_view(view: EventRunner.EventView) -> void:
	## 呈现事件视图：叙述 + 选项（检定选项带标注+进入改派；纯选择直选）
	## 参数 view：事件视图
	## 返回：无
	_Reset()
	_current_view = view
	_narrative_label.text = view.narrative
	_pending_check = {}
	for entry: Dictionary in view.options:
		var option_id: StringName = entry[&"id"]
		var button := Button.new()
		button.text = _OptionText(entry)
		button.custom_minimum_size = Vector2(0, 48)
		button.add_theme_font_size_override("font_size",
				UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
		if String(option_id) == "":
			# 单点事件检定视图：直接进入改派
			button.pressed.connect(_BeginCast.bind(entry, &""))
		else:
			button.pressed.connect(_OnOptionPressed.bind(option_id, entry))
		_options_box.add_child(button)

func show_settled(grade: int, text: String, reward_text: String,
		roll_text: String = "") -> void:
	## 呈现结算视图：四档反馈条（色标签）+ 掷骰明细行（可选）+ 结算文本 +
	## 数值反馈行 + 继续钮
	## 参数 grade：CheckResult.Grade（无检定传 -1——不显示档位标签）；
	## text：结算文本；reward_text：数值反馈行（如「+15 经验 +10 金」）；
	## roll_text：掷骰明细行（如「掷出 14 ＋ 2 ＝ 16（容易 8）」——2026-09-25
	## 试玩反馈②：空串不显示行；M2 既有调用不传保持零变化）
	## 返回：无
	_Reset()
	if grade >= 0:
		_grade_label.visible = true
		_grade_label.text = _GradeText(grade)
		_grade_label.add_theme_color_override("font_color", _GradeColor(grade))
	_result_label.text = _ComposeResultBody(roll_text, text, reward_text)
	_continue_button.visible = true

func show_battle_intro(view: EventRunner.EventView, reward_text: String,
		roll_text: String = "") -> void:
	## 呈现 B 出口战前演出视图（E3-06 拍板 A：先播再战）——叙述+结算文本+
	## 四档反馈（若经检定）+ 掷骰明细行（可选）+ 数值反馈行 +「进入战斗」钮
	## 参数 view：B 出口视图（narrative = 叙述+战前结算文本）；reward_text：
	## 数值反馈行（如「−5 HP」）；roll_text：掷骰明细行（同 show_settled——
	## 战前演出经检定进入时难度与骰面可见）
	## 返回：无
	_Reset()
	if view.check_grade >= 0:
		_grade_label.visible = true
		_grade_label.text = _GradeText(view.check_grade)
		_grade_label.add_theme_color_override("font_color", _GradeColor(view.check_grade))
	_result_label.text = _ComposeResultBody(roll_text, view.narrative, reward_text)
	_battle_button.visible = true

func _ComposeResultBody(roll_text: String, text: String, reward_text: String) -> String:
	## 结算呈现文本拼装：掷骰明细行（有则置首行——醒目）+ 正文 + 数值反馈行
	## 参数 roll_text：掷骰明细行（空 = 无行）；text：正文；reward_text：
	## 数值反馈行（空 = 无行）
	## 返回：bbcode 文本
	var body: String = text
	if not roll_text.is_empty():
		body = roll_text + "\n" + body
	if not reward_text.is_empty():
		body += "\n[b]" + reward_text + "[/b]"
	return body

func clear() -> void:
	## 清空呈现区（E3-15：结算继续后清面板残留——回菜单不再显示旧结果）
	## 参数：无
	## 返回：无
	_Reset()
	_current_view = null

func _OnOptionPressed(option_id: StringName, entry: Dictionary) -> void:
	## 选项点按：纯选择直接发出；检定选项进入改派（D20 演出期门禁拦截）
	## 参数 option_id/entry：选项要素
	## 返回：无
	if _busy:
		return
	if String(entry.get(&"attr_label", "")).is_empty():
		option_chosen.emit(option_id, null)
		return
	_BeginCast(entry, option_id)

func _BeginCast(entry: Dictionary, option_id: StringName) -> void:
	## 改派子面板：按所点选项属性现算候选（E4）→ 候选按钮组（默认最高
	## 高亮）——点选即以该成员掷骰；空名单提示+取消路径（E3-13）
	## 参数 entry：检定选项条目；option_id：归属选项
	## 返回：无
	_options_box.visible = false
	_cast_box.visible = true
	var attr_id: StringName = StringName(str(entry.get(&"attr_label", "")))
	_pending_check = {&"option_id": option_id, &"attr_id": attr_id}
	var cast: Array = _cast_provider.call(attr_id) if _cast_provider.is_valid() else []
	var title := Label.new()
	title.text = "选择执行人"
	title.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_small", UiTheme.FONT_SMALL))
	_cast_box.add_child(title)
	if cast.is_empty():
		# E3-13：空改派名单（全员倒地可达）——提示 + 取消回选项视图
		title.text = NO_CAST_TEXT
		var cancel := Button.new()
		cancel.text = "返回"
		cancel.custom_minimum_size = Vector2(160, 48)
		cancel.pressed.connect(_OnCastCancelled)
		_cast_box.add_child(cancel)
		return
	for index: int in cast.size():
		var candidate: Dictionary = cast[index]
		var adv: AdventurerData = candidate[&"adv"]
		var button := Button.new()
		button.text = "%s（%s %+d）" % [adv.display_name,
				ATTR_NAMES.get(attr_id, String(attr_id)),
				int(candidate[&"modifier"])]
		button.custom_minimum_size = Vector2(0, 48)
		if index == 0:
			# 默认最高：高亮提示（modulate 金边近似——复用高亮色）
			button.modulate = UiTheme.color_of(_cfg, &"ui_highlight_gold_color",
					UiTheme.HIGHLIGHT_GOLD)
		button.pressed.connect(_OnCastPicked.bind(adv))
		_cast_box.add_child(button)

func _OnCastCancelled() -> void:
	## 空名单取消：恢复当前选项视图呈现（E3-13 取消路径）
	## 参数：无
	## 返回：无
	if _current_view != null:
		show_view(_current_view)

func _OnCastPicked(actor: AdventurerData) -> void:
	## 改派点选完成：发出选择（宿主路由 choose_option + D20 演出由宿主驱动；
	## D20 演出期门禁拦截）
	## 参数 actor：施检者
	## 返回：无
	if _busy:
		return
	var option_id: StringName = _pending_check.get(&"option_id", &"")
	option_chosen.emit(option_id, actor)

func play_d20_roll() -> void:
	## D20 演出：数字滚动 ui_d20_roll_seconds（点按面板宿主任意处跳过——
	## 演出本身不改结算，仅视觉）；演出期输入门禁（E3-03：演出起禁用全部
	## 交互钮、呈结果止恢复——防演出期连点双结算）；
	## W3-03（拍板 a）：演出期面板置 STOP——面板区即跳过热区（宿主根的
	## gui_input 跳过链原先被板面 STOP 吞掉面板区域点击，演出无法点跳），
	## 演出结束恢复 IGNORE（常态面板不挡板面输入）
	## 参数：无
	## 返回：无（协程）
	var seconds: float = _cfg.ui_d20_roll_seconds if _cfg != null \
			and _cfg.ui_d20_roll_seconds > 0.0 else UiTheme.D20_ROLL_SECONDS
	_busy = true
	_SetInteractive(false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_d20_skip = false
	_d20_label.visible = true
	_d20_label.text = "?"
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()
	var elapsed: float = 0.0
	while elapsed < seconds and not _d20_skip and is_inside_tree():
		_d20_label.text = str(rng.randi_range(1, 20))
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_d20_label.visible = false
	_busy = false
	_SetInteractive(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _gui_input(event: InputEvent) -> void:
	## 面板内点按（W3-03：D20 演出期 = 跳过热区——演出期面板 STOP 接管本
	## 回调；非演出期面板 IGNORE，本口不可达）
	## 参数 event：输入事件
	## 返回：无
	if _busy and event is InputEventMouseButton \
			and (event as InputEventMouseButton).pressed:
		skip_d20()
		accept_event()

func skip_d20() -> void:
	## 跳过 D20 演出（宿主点按转发）
	## 参数：无
	## 返回：无
	_d20_skip = true

func is_busy() -> bool:
	## 演出期门禁状态查询（E3-03——宿主侧入口拦截消费）
	## 参数：无
	## 返回：true = D20 演出进行中
	return _busy

func _SetInteractive(enabled: bool) -> void:
	## 交互钮批量启停（E3-03 门禁的消费面：选项/改派/继续/进入战斗）
	## 参数 enabled：true = 恢复可点
	## 返回：无
	for child: Node in _options_box.get_children():
		if child is Button:
			(child as Button).disabled = not enabled
	for child: Node in _cast_box.get_children():
		if child is Button:
			(child as Button).disabled = not enabled
	_continue_button.disabled = not enabled
	_battle_button.disabled = not enabled

func _OptionText(entry: Dictionary) -> String:
	## 选项文本拼装：正文 + 尾部「属性·难度(线)」标注（案 15 文案位——机制
	## 标注不进正文）
	## 参数 entry：选项视图条目
	## 返回：按钮文本
	var text: String = entry[&"text"]
	var attr_label: String = entry.get(&"attr_label", "")
	if not attr_label.is_empty():
		var attr_name: String = String(ATTR_NAMES.get(StringName(str(attr_label)), attr_label))
		text += "　%s·%s(%d)" % [attr_name, entry.get(&"tier_label", ""),
				int(entry.get(&"tier_line", 0))]
	var cost_days: int = int(entry.get(&"cost_days", 0))
	if cost_days > 0:
		text += "　耗时+%d天" % cost_days
	return text

func _GradeText(grade: int) -> String:
	## 档位标签文本
	## 参数 grade：CheckResult.Grade
	## 返回：标签
	match grade:
		CheckResult.Grade.CRIT_SUCCESS:
			return "【大成功】"
		CheckResult.Grade.SUCCESS:
			return "【成功】"
		CheckResult.Grade.FAILURE:
			return "【失败】"
		_:
			return "【大失败】"

func _GradeColor(grade: int) -> Color:
	## 档位反馈色（cfg 四色表驱动）
	## 参数 grade：档位
	## 返回：颜色
	match grade:
		CheckResult.Grade.CRIT_SUCCESS:
			return UiTheme.color_of(_cfg, &"ui_event_grade_crit_success_color",
					UiTheme.EVENT_GRADE_CRIT_SUCCESS)
		CheckResult.Grade.SUCCESS:
			return UiTheme.color_of(_cfg, &"ui_event_grade_success_color",
					UiTheme.EVENT_GRADE_SUCCESS)
		CheckResult.Grade.FAILURE:
			return UiTheme.color_of(_cfg, &"ui_event_grade_failure_color",
					UiTheme.EVENT_GRADE_FAILURE)
		_:
			return UiTheme.color_of(_cfg, &"ui_event_grade_crit_failure_color",
					UiTheme.EVENT_GRADE_CRIT_FAILURE)

func _Reset() -> void:
	## 复位呈现区（切换视图前）
	## 参数：无
	## 返回：无
	for child: Node in _options_box.get_children():
		child.queue_free()
	for child: Node in _cast_box.get_children():
		child.queue_free()
	_cast_box.visible = false
	_options_box.visible = true
	_grade_label.visible = false
	_result_label.text = ""
	_continue_button.visible = false
	_battle_button.visible = false
	_d20_label.visible = false
