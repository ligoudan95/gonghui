## 应用设置（AppSettings，纯静态工具类）
## 职责：窗口尺寸双档（默认 1440×900 / 大 1920×1080）的持久化与即时生效
##——user://settings.cfg ConfigFile 载入/保存；DisplayServer 应用+工作区居中。
## 数据来源：M4 增补批架构拍板③（设置界面双档分辨率）。
## 纯逻辑约束：不触任何 autoload；非法键/缺文件/非法值一律回退默认档。
class_name AppSettings
extends RefCounted

## 设置文件路径
const SETTINGS_PATH: String = "user://settings.cfg"
## 显示配置节名
const SECTION_DISPLAY: String = "display"
## 窗口尺寸键名
const KEY_WINDOW_SIZE: String = "window_size"
## 默认档键（1440×900）
const SIZE_DEFAULT: String = "1440x900"
## 大档键（1920×1080）
const SIZE_LARGE: String = "1920x1080"
## 档位键 -> 窗口尺寸（合法键单源——新增档位只改此处）
const WINDOW_SIZES: Dictionary = {
	SIZE_DEFAULT: Vector2i(1440, 900),
	SIZE_LARGE: Vector2i(1920, 1080),
}

static func load_window_size() -> String:
	## 读取持久化窗口尺寸档（ConfigFile）；失败/缺键/非法键回退默认档
	## 参数：无
	## 返回：档位键（SIZE_DEFAULT 或 SIZE_LARGE 或回退 SIZE_DEFAULT）
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return SIZE_DEFAULT
	var raw: String = config.get_value(SECTION_DISPLAY, KEY_WINDOW_SIZE, SIZE_DEFAULT)
	if WINDOW_SIZES.has(raw):
		return raw
	return SIZE_DEFAULT

static func save_window_size(key: String) -> bool:
	## 持久化窗口尺寸档（ConfigFile 原子写由 Godot 保证——flush 落盘）
	## 参数 key：档位键（须为 WINDOW_SIZES 合法键）
	## 返回：true = 写入成功；非法键/写盘失败返回 false
	if not WINDOW_SIZES.has(key):
		return false
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION_DISPLAY, KEY_WINDOW_SIZE, key)
	return config.save(SETTINGS_PATH) == OK

static func apply_window_size(key: String) -> void:
	## 即时生效窗口尺寸（DisplayServer 设置 + 工作区居中——防大档贴出屏外）；
	## 非法键静默回退默认档。
	## **修复（试玩 BUG）**：最大化/最小化/全屏态下 window_set_size 被忽略
	##（Godot/Windows 口径——真机探针实证：MAXIMIZED 态 set 纹丝不动，恢复
	## WINDOWED 后生效）——先恢复普通窗口态再改尺寸；origin 钳制工作区内
	##（防大档在 1080 屏标题栏顶出屏外）。
	## 参数 key：档位键
	## 返回：无
	var size: Vector2i = WINDOW_SIZES.get(key, WINDOW_SIZES[SIZE_DEFAULT])
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	var screen_area: Rect2i = DisplayServer.screen_get_usable_rect()
	var origin: Vector2i = screen_area.position \
			+ (screen_area.size - size) / Vector2i(2, 2)
	origin.x = maxi(origin.x, screen_area.position.x)
	origin.y = maxi(origin.y, screen_area.position.y)
	DisplayServer.window_set_position(origin)
