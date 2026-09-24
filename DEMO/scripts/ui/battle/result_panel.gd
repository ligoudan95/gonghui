## 战斗结算面板（ResultPanel，PanelContainer——居中弹出）
## 职责：终局结算展示——胜（「战斗胜利」+ 奖励占位文案）/ 败（「战败·全队
## 重伤休养」占位）/ 撤退（「撤退成功·委托失败」占位）+ 战报摘要（回合数/
## 倒地名单）+ 返回按钮（发出信号由 battle_screen 路由回公会壳）。
## 数据来源：M1 批 3 方案 §7.1（ResultPanel 文案口径）。
class_name ResultPanel
extends PanelContainer

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
	box.custom_minimum_size = Vector2(420, 0)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title_label)
	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 16)
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_label)
	_return_button = Button.new()
	_return_button.text = "返回公会"
	_return_button.custom_minimum_size = Vector2(200, 56)
	_return_button.pressed.connect(func() -> void: return_pressed.emit())
	box.add_child(_return_button)
	add_child(box)
	visible = false

func show_result(result: BattleResult, name_lookup: Callable = Callable()) -> void:
	## 展示终局结算（文案按口径；战报摘要附详情行）
	## 参数 result：战斗结果；name_lookup：unit_id → 显示名解析（2026-09-24
	## 七轮反馈：倒地名单中文化；缺省回退 id 原文）
	## 返回：无
	match result.kind:
		BattleResult.ResultKind.VICTORY:
			_title_label.text = "战斗胜利"
			_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			_detail_label.text = "奖励结算（占位文案——M2 委托结算接入）"
		BattleResult.ResultKind.DEFEAT:
			_title_label.text = "战败·全队重伤休养"
			_title_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.35))
			_detail_label.text = "全队重伤休养 3 天（占位文案——M2 战败流程接入）"
		_:
			_title_label.text = "撤退成功·委托失败"
			_title_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
			_detail_label.text = "委托按失败结算（占位文案——M2 委托结算接入）"
	var downed_text: String = "、".join(result.downed_units.map(func(unit_id):
		if name_lookup.is_valid():
			return String(name_lookup.call(unit_id))
		return String(unit_id)))
	_detail_label.text += "\n回合数：%d｜倒地：%s" % [
		result.rounds_used,
		downed_text if not downed_text.is_empty() else "无",
	]
	visible = true
