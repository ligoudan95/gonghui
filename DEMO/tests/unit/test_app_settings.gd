## 应用设置单元测试（M4 增补批 3——设置界面双档分辨率）
## 覆盖：save/load 往返/未知键回退默认档/缺文件回退默认档/非法键 save 拒 false/
## 基准锚定（ProjectSettings viewport == WINDOW_SIZES[SIZE_DEFAULT]——防编辑器
## 改基准漂移）/apply 尺寸生效（headless 下 DisplayServer 仍可查询窗口尺寸）。
## 隔离：after_test 强制删 user://settings.cfg 防套件间互染。
extends GdUnitTestSuite

func after_test() -> void:
	## 用例级后置：删设置文件（防互染——本套件与场景流套件共用 user://）
	## 参数：无
	## 返回：无
	DirAccess.remove_absolute(AppSettings.SETTINGS_PATH)

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
