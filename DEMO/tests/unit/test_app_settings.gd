## 应用设置单元测试（M4 增补批 3——设置界面双档分辨率；M5 验收 BUG 修复扩）
## 覆盖：save/load 往返/未知键回退默认档/缺文件回退默认档/非法键 save 拒 false/
## 基准锚定（ProjectSettings viewport == WINDOW_SIZES[SIZE_DEFAULT]——防编辑器
## 改基准漂移）/apply 尺寸生效（headless 下 DisplayServer 仍可查询窗口尺寸）；
## M5 修复：面板信号链（popup.index_pressed 直连——同项再选也触发=本 BUG 回归）、
## open() 实测校准提示行、applied 提示带应用后实测值（headless 口径——运行时
## 读值比对，不断言固定数字）。
## 隔离：after_test 强制删 user://settings.cfg 防套件间互染。
extends GdUnitTestSuite

func after_test() -> void:
	## 用例级后置：删设置文件（防互染——本套件与场景流套件共用 user://）
	## 参数：无
	## 返回：无
	DirAccess.remove_absolute(AppSettings.SETTINGS_PATH)

func _MakePanel() -> SettingsPanel:
	## 装配设置面板（setup(null)——cfg 兜底档位；add_child+auto_free 供树内查找）
	## 参数：无
	## 返回：SettingsPanel
	var panel := SettingsPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.setup(null)
	return panel

func test_save_load_roundtrip() -> void:
	## 双档往返：save LARGE → load == LARGE；save DEFAULT → load == DEFAULT
	assert_bool(AppSettings.save_window_size(AppSettings.SIZE_LARGE)).is_true()
	assert_str(AppSettings.load_window_size()).is_equal(AppSettings.SIZE_LARGE)
	assert_bool(AppSettings.save_window_size(AppSettings.SIZE_DEFAULT)).is_true()
	assert_str(AppSettings.load_window_size()).is_equal(AppSettings.SIZE_DEFAULT)

func test_missing_file_falls_back_default() -> void:
	## 缺文件回退默认档
	DirAccess.remove_absolute(AppSettings.SETTINGS_PATH)
	assert_str(AppSettings.load_window_size()).is_equal(AppSettings.SIZE_DEFAULT)

func test_unknown_stored_key_falls_back_default() -> void:
	## 持久化了非法键（手改 cfg）→ load 回退默认档
	assert_bool(AppSettings.save_window_size(AppSettings.SIZE_LARGE)).is_true()
	var config := ConfigFile.new()
	config.load(AppSettings.SETTINGS_PATH)
	config.set_value(AppSettings.SECTION_DISPLAY, AppSettings.KEY_WINDOW_SIZE, "800x600")
	config.save(AppSettings.SETTINGS_PATH)
	assert_str(AppSettings.load_window_size()).is_equal(AppSettings.SIZE_DEFAULT)

func test_invalid_key_save_rejected() -> void:
	## save 非法键 → false 且不落盘
	assert_bool(AppSettings.save_window_size("800x600")).is_false()
	DirAccess.remove_absolute(AppSettings.SETTINGS_PATH)
	assert_str(AppSettings.load_window_size()).is_equal(AppSettings.SIZE_DEFAULT)

func test_viewport_base_anchor() -> void:
	## 基准锚定：ProjectSettings 视口 == 默认档尺寸（防编辑器改基准漂移——
	## 双档语义以 1440×900 为默认基准）
	var width: int = int(ProjectSettings.get_setting(
			"display/window/size/viewport_width", 0))
	var height: int = int(ProjectSettings.get_setting(
			"display/window/size/viewport_height", 0))
	assert_vector(Vector2i(width, height)).is_equal(
			AppSettings.WINDOW_SIZES[AppSettings.SIZE_DEFAULT])

func test_apply_window_size_effective() -> void:
	## apply 即时生效：窗口尺寸切换为档位值（headless 下 DisplayServer 窗口
	## 尺寸恒 (0,0) 不可断言——仅非 headless 验证，headless 验证不崩即过）。
	## 非 headless 下 gdUnit CI 窗口为 MINIMIZED 态（GdUnitCmdTool 固定最小化）
	## ——apply 先恢复 WINDOWED 再 set，本用例同时回归「最大化/最小化态下
	## set_size 被忽略」的试玩 BUG 修复
	## 参数：无
	## 返回：无
	if DisplayServer.get_name() == "headless":
		AppSettings.apply_window_size(AppSettings.SIZE_LARGE)
		AppSettings.apply_window_size(AppSettings.SIZE_DEFAULT)
		return
	AppSettings.apply_window_size(AppSettings.SIZE_LARGE)
	assert_vector(DisplayServer.window_get_size()).is_equal(
				AppSettings.WINDOW_SIZES[AppSettings.SIZE_LARGE])
	AppSettings.apply_window_size(AppSettings.SIZE_DEFAULT)
	assert_vector(DisplayServer.window_get_size()).is_equal(
				AppSettings.WINDOW_SIZES[AppSettings.SIZE_DEFAULT])

func test_apply_invalid_key_silent_default() -> void:
	## apply 非法键静默回退默认档（不崩；headless 仅验证不崩）
	## 参数：无
	## 返回：无
	AppSettings.apply_window_size("not-a-size")
	if DisplayServer.get_name() == "headless":
		return
	assert_vector(DisplayServer.window_get_size()).is_equal(
				AppSettings.WINDOW_SIZES[AppSettings.SIZE_DEFAULT])

func test_apply_restores_from_maximized() -> void:
	## 试玩 BUG 回归：MAXIMIZED 态下 apply——须先恢复 WINDOWED 且尺寸生效
	##（headless 下 DisplayServer 窗口模式恒 (0,0) 尺寸——仅非 headless 断言）
	## 参数：无
	## 返回：无
	if DisplayServer.get_name() == "headless":
		AppSettings.apply_window_size(AppSettings.SIZE_LARGE)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	AppSettings.apply_window_size(AppSettings.SIZE_LARGE)
	assert_int(DisplayServer.window_get_mode()).is_equal(DisplayServer.WINDOW_MODE_WINDOWED)
	assert_vector(DisplayServer.window_get_size()).is_equal(
				AppSettings.WINDOW_SIZES[AppSettings.SIZE_LARGE])

func test_panel_popup_signal_same_item_retriggers() -> void:
	## M5 验收 BUG 回归：同项再选也触发——信号直连 popup.index_pressed 后，
	## selected 已是 1 时再发 index_pressed(1) 处理器必须再次执行
	##（Godot 4.7 OptionButton.item_selected 同项早退被绕开；修复前用户点
	## 当前已选项零反应）。判别用持久化档位副作用（改写盘上档为默认再发 →
	## 必须回到 LARGE——环境无关，不依赖 hint 文案分支）
	var panel: SettingsPanel = _MakePanel()
	DirAccess.remove_absolute(AppSettings.SETTINGS_PATH)
	panel.open()
	assert_int(panel._size_option.selected).is_equal(0)
	# 异项选择（0→1）：选中态同步 + 持久化落盘 + 提示行变化
	panel._size_option.get_popup().emit_signal("index_pressed", 1)
	assert_int(panel._size_option.selected).is_equal(1)
	assert_bool(panel._hint_label.text.is_empty()).is_false()
	assert_str(AppSettings.load_window_size()).is_equal(AppSettings.SIZE_LARGE)
	# 本 BUG 回归：同项再选（selected 已是 1）——改写盘上档为默认制造判别差，
	## 再发后档位必须回到 LARGE + hint 再度非空（处理器真实再跑）
	AppSettings.save_window_size(AppSettings.SIZE_DEFAULT)
	panel._hint_label.text = ""
	panel._size_option.get_popup().emit_signal("index_pressed", 1)
	assert_str(AppSettings.load_window_size()).is_equal(AppSettings.SIZE_LARGE) \
			.override_failure_message("同项再选零反应（M5 验收 BUG 复现）")
	assert_bool(panel._hint_label.text.is_empty()).is_false()

func test_panel_open_shows_measured_window_size() -> void:
	## M5 修复 + 受限适配：open() 实测校准——提示行初始含当前窗口实测尺寸
	##（headless 下 window_get_size 返回视口尺寸——运行时读值比对）；
	## 实测与两档均不匹配时追加受限说明（不再裸显非档位数字让人困惑），
	## 匹配任一档时裸显实测无附加行
	var panel: SettingsPanel = _MakePanel()
	DirAccess.remove_absolute(AppSettings.SETTINGS_PATH)
	panel.open()
	var size: Vector2i = DisplayServer.window_get_size()
	var expected: String = "当前：%d × %d" % [size.x, size.y]
	if not AppSettings.WINDOW_SIZES.values().has(size):
		expected += "\n" + String(SettingsPanel.UI_TEXTS[&"limited_note"])
	assert_str(panel._hint_label.text).is_equal(expected)

func test_panel_applied_hint_limited_branch_headless() -> void:
	## M5 受限适配：applied 提示走 BuildAppliedHint 回读比对——headless 下
	## 实测（视口尺寸）恒≠档位 → **真实走不匹配分支**：断言受限文案
	##（已保存请求档位+受限说明）；匹配分支由 BuildAppliedHint 纯静态
	## 传参单测覆盖（headless 窗口不可能匹配档位，不可强测）
	var panel: SettingsPanel = _MakePanel()
	DirAccess.remove_absolute(AppSettings.SETTINGS_PATH)
	panel.open()
	panel._size_option.get_popup().emit_signal("index_pressed", 1)
	var actual: Vector2i = DisplayServer.window_get_size()
	assert_bool(actual == AppSettings.WINDOW_SIZES[AppSettings.SIZE_LARGE]).is_false()
	var hint: String = panel._hint_label.text
	assert_str(hint).contains("已保存：1920 × 1080")
	assert_str(hint).contains("独立运行时生效")
	assert_str(hint).is_equal(SettingsPanel.BuildAppliedHint(
			AppSettings.WINDOW_SIZES[AppSettings.SIZE_LARGE], actual))

func test_build_applied_hint_matched_branch() -> void:
	## 受限适配·匹配分支（纯静态传参）：实测==请求档位 → 「已切换：实测」
	var hint: String = SettingsPanel.BuildAppliedHint(
			Vector2i(1920, 1080), Vector2i(1920, 1080))
	assert_str(hint).is_equal("已切换：1920 × 1080")

func test_build_applied_hint_limited_branch() -> void:
	## 受限适配·不匹配分支（纯静态传参）：实测≠请求 → 「已保存：请求档位
	## ——受限说明」（中性措辞——覆盖嵌入/受限/被钳制/手拉非标准档，
	## 不断言具体环境）；两档反向同口径
	var hint: String = SettingsPanel.BuildAppliedHint(
			Vector2i(1920, 1080), Vector2i(1200, 800))
	assert_str(hint).is_equal("已保存：1920 × 1080——%s"
			% SettingsPanel.UI_TEXTS[&"limited_note"])
	var hint_default: String = SettingsPanel.BuildAppliedHint(
			Vector2i(1440, 900), Vector2i(1920, 1922))
	assert_str(hint_default).is_equal("已保存：1440 × 900——%s"
			% SettingsPanel.UI_TEXTS[&"limited_note"])
