## 设置面板（SettingsPanel，代码构建 UI 组件——M4 增补批 3；M5 验收 BUG 修复）
## 职责：窗口尺寸双档选择（OptionButton 默认/大）+ 即时生效（AppSettings.
## apply_window_size）+ 持久化（save_window_size）+ 提示行（open 校准当前实测
## 尺寸/已切换带实测值/写失败重试）。
## M5 验收 BUG 修复（同项再选无反应）：选项信号直连 popup.index_pressed——
## Godot 4.7 OptionButton 同项再选不发射 item_selected（PopupMenu 点选后
## _selected 同值早退），popup.index_pressed 同项/异项均发射（幂等 apply+save
## 无害）；open 时提示行显示窗口实测尺寸（消除「预选项与实际不符」盲区）；
## applied 提示带应用后实测值。
## M5 受限适配（用户拍板）：嵌入/受限窗口（如编辑器嵌入窗口拒绝一切
## window_set_size/set_position）下 apply 被引擎忽略——回读实测与请求档位
## 比对（BuildAppliedHint 静态单源）：不匹配时如实提示「已保存+受限说明」
##（档位已存盘、独立运行生效），不误判为 BUG；open 校准同理附加说明。
## UI 规范：UiTheme 深底面板/字号档位；弹层 z=100 置顶（organize_panel 先例）。
class_name SettingsPanel
extends PanelContainer

## 关闭请求（宿主隐藏弹层）
signal closed

## 弹层 z（单源置顶——organize_panel 先例）
const POPUP_Z_INDEX: int = 100

## UI 文案单源（改措辞只动此处）
const UI_TEXTS: Dictionary = {
	&"panel_title": "设置",
	&"size_label": "界面大小：",
	&"size_default": "1440 × 900（默认）",
	&"size_large": "1920 × 1080",
	&"applied_hint_format": "已切换：%s",
	&"applied_limited_hint_format": "已保存：%s——%s",
	&"limited_note": "当前窗口尺寸受限或非标准档（如编辑器嵌入窗口），独立运行时生效",
	&"current_hint_format": "当前：%s",
	&"save_failed_hint": "写入设置失败——请重试。",
	&"close_button": "关闭",
}

## 总控配置（setup 注入——字号档位）
var _cfg: CoreConfig = null
## 尺寸档选择器
var _size_option: OptionButton = null
## 提示行
var _hint_label: Label = null

func setup(cfg: CoreConfig, game_data: Node = null) -> void:
	## 构建面板骨架（初始隐藏）；M6 批 3.5b：game_data 注入（九宫格面板贴图
	## 态；空 = 缺件降级 StyleBoxFlat）
	## 参数 cfg：总控配置；game_data：GameData（可空）
	## 返回：无
	_cfg = cfg
	name = "SettingsPanel"
	visible = false
	z_index = POPUP_Z_INDEX
	add_theme_stylebox_override("panel", UiTheme.make_dark_panel_style(cfg, game_data))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = UI_TEXTS[&"panel_title"]
	title.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	box.add_child(title)
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 8)
	box.add_child(size_row)
	var size_label := Label.new()
	size_label.text = UI_TEXTS[&"size_label"]
	size_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	size_row.add_child(size_label)
	_size_option = OptionButton.new()
	_size_option.name = "SizeOption"
	_size_option.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	_size_option.add_item(UI_TEXTS[&"size_default"])
	_size_option.add_item(UI_TEXTS[&"size_large"])
	# M5 验收 BUG 修复：选项信号直连 popup.index_pressed（同项/异项均发射——
	## OptionButton.item_selected 同项早退不再消费）
	_size_option.get_popup().index_pressed.connect(_OnSizeSelected)
	size_row.add_child(_size_option)
	_hint_label = Label.new()
	_hint_label.name = "SettingsHintLabel"
	_hint_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	box.add_child(_hint_label)
	var close_button := Button.new()
	close_button.name = "CloseSettingsButton"
	close_button.text = UI_TEXTS[&"close_button"]
	close_button.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	close_button.pressed.connect(func() -> void: closed.emit())
	box.add_child(close_button)

func open() -> void:
	## 打开面板：按当前持久化档选中下拉项（未知档回退默认）+ 提示行初始显示
	## 当前窗口**实测**尺寸（M5 修复：open 校准——消除「预选项与实际窗口不符」
	## 的感知盲区）；实测与两档均不匹配时附加受限说明（M5 受限适配——不再
	## 裸显一个非档位数字让人困惑）
	## 参数：无
	## 返回：无
	var current_key: String = AppSettings.load_window_size()
	_size_option.selected = 1 if current_key == AppSettings.SIZE_LARGE else 0
	_hint_label.text = _OpenHintText()
	visible = true

func close() -> void:
	## 关闭面板
	## 参数：无
	## 返回：无
	visible = false

static func _FormatSize(size: Vector2i) -> String:
	## 尺寸文本格式化（W × H——与档位文案同形；静态供 BuildAppliedHint 共用）
	## 参数 size：窗口尺寸
	## 返回：如「1920 × 1080」
	return "%d × %d" % [size.x, size.y]

static func BuildAppliedHint(requested: Vector2i, actual: Vector2i) -> String:
	## 应用后提示文案（apply 回读比对——单源可测，铁律⑥）：
	## 匹配=「已切换：实测」；不匹配（嵌入/受限/被钳制/手拉非标准档——
	## 不必然是嵌入，措辞中性覆盖）=「已保存：请求档位——受限说明」
	##（如实告知：档位已存盘、窗口暂不可调不可误判为 BUG、独立运行生效）
	## 参数 requested：请求档位尺寸；actual：应用后窗口实测尺寸
	## 返回：提示文案
	if actual == requested:
		return String(UI_TEXTS[&"applied_hint_format"]) % _FormatSize(actual)
	return String(UI_TEXTS[&"applied_limited_hint_format"]) % [
			_FormatSize(requested), UI_TEXTS[&"limited_note"]]

func _OpenHintText() -> String:
	## open 校准提示（M5 受限适配）：实测匹配任一档 → 裸显实测；与两档均
	## 不匹配 → 追加受限说明（复用 limited_note 单源键）
	## 参数：无
	## 返回：提示文本（受限时两行）
	var size: Vector2i = DisplayServer.window_get_size()
	var text: String = String(UI_TEXTS[&"current_hint_format"]) % _FormatSize(size)
	if not AppSettings.WINDOW_SIZES.values().has(size):
		text += "\n" + String(UI_TEXTS[&"limited_note"])
	return text

func _OnSizeSelected(index: int) -> void:
	## 选档（popup.index_pressed 直连——同项/异项均达）：选中态手动同步 →
	## 即时生效 → 持久化 → 提示（apply 回读实测比对——BuildAppliedHint
	## 单源；写失败提示重试；越界项防御不动作）
	## 参数 index：下拉项序（0=默认 / 1=大——popup 项序与下拉项序一致）
	## 返回：无
	if index < 0 or index >= _size_option.item_count:
		return
	_size_option.selected = index
	var key: String = AppSettings.SIZE_LARGE if index == 1 else AppSettings.SIZE_DEFAULT
	var requested: Vector2i = AppSettings.WINDOW_SIZES[key]
	AppSettings.apply_window_size(key)
	if AppSettings.save_window_size(key):
		_hint_label.text = BuildAppliedHint(requested,
				DisplayServer.window_get_size())
	else:
		_hint_label.text = UI_TEXTS[&"save_failed_hint"]
