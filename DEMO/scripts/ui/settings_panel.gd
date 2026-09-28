## 设置面板（SettingsPanel，代码构建 UI 组件——M4 增补批 3）
## 职责：窗口尺寸双档选择（OptionButton 默认/大）+ 即时生效（AppSettings.
## apply_window_size）+ 持久化（save_window_size）+ 提示行（已切换/写失败重试）。
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
	&"save_failed_hint": "写入设置失败——请重试。",
	&"close_button": "关闭",
}

## 总控配置（setup 注入——字号档位）
var _cfg: CoreConfig = null
## 尺寸档选择器
var _size_option: OptionButton = null
## 提示行
var _hint_label: Label = null

func setup(cfg: CoreConfig) -> void:
	## 构建面板骨架（初始隐藏）
	## 参数 cfg：总控配置
	## 返回：无
	_cfg = cfg
	name = "SettingsPanel"
	visible = false
	z_index = POPUP_Z_INDEX
	add_theme_stylebox_override("panel", UiTheme.make_dark_panel_style(cfg))
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
	_size_option.item_selected.connect(_OnSizeSelected)
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
	## 打开面板：按当前持久化档选中下拉项（未知档回退默认）
	## 参数：无
	## 返回：无
	var current_key: String = AppSettings.load_window_size()
	_size_option.selected = 1 if current_key == AppSettings.SIZE_LARGE else 0
	_hint_label.text = ""
	visible = true

func close() -> void:
	## 关闭面板
	## 参数：无
	## 返回：无
	visible = false

func _SizeOptionText(index: int) -> String:
	## 下拉项序 -> 档显示文案（提示行反馈消费——效果不可误判）
	## 参数 index：下拉项序（0=默认 / 1=大）
	## 返回：档位显示文案
	return (String(UI_TEXTS[&"size_large"]) if index == 1
			else String(UI_TEXTS[&"size_default"]))

func _OnSizeSelected(index: int) -> void:
	## 选档：即时生效 → 持久化 → 提示（写失败提示重试；非法项不动作）
	## 参数 index：下拉项序（0=默认 / 1=大）
	## 返回：无
	var key: String = AppSettings.SIZE_LARGE if index == 1 else AppSettings.SIZE_DEFAULT
	AppSettings.apply_window_size(key)
	if AppSettings.save_window_size(key):
		_hint_label.text = String(UI_TEXTS[&"applied_hint_format"]) % _SizeOptionText(index)
	else:
		_hint_label.text = UI_TEXTS[&"save_failed_hint"]
