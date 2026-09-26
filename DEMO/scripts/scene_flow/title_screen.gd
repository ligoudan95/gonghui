## 标题屏（title_screen）场景脚本
## 职责：展示游戏名/版本；「开始」=新档进公会壳；「继续」=按存档可用性启用、
## 点击读档成功后跳存档场景（失败则禁用+提示）。
## 数据来源：M0 批 4 方案；文案=案 15 口径（游戏名「传奇冒险公会」）。
## 单例访问：统一 get_node("/root/X")（gdUnit 测试环境不注册 autoload 标识符——
## 批 1 实测结论；节点路径方式在运行与测试环境行为一致）。
extends Control

## SceneManager 脚本常量引用（枚举常量不可经实例属性访问——运行时 Invalid get index；
## 经 preloaded 脚本访问 SceneId 是环境无关且类型安全的方式）
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")

func _ready() -> void:
	## 引擎回调：刷新版本号文案与「继续」按钮可用性；B-7：tscn 内嵌字号
	## 按档位覆写（tscn 值留占位——字号体系只动 cfg）
	## 参数：无
	## 返回：无
	_ApplyFontTiers()
	%VersionLabel.text = _BuildVersionText()
	%ContinueButton.disabled = not _save_manager().has_save()
	%HintLabel.text = ""

func _ApplyFontTiers() -> void:
	## tscn 内嵌字号档位覆写（B-7）：游戏名（64→display）/ VersionLabel
	## （20→body）/ HintLabel（18→normal）；W3-08：开始/继续按钮补齐
	## （按钮统一 normal 档，三屏收口）
	## 参数：无
	## 返回：无
	var game_data: Node = get_node_or_null("/root/GameData")
	var cfg: CoreConfig = game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig 			if game_data != null else null
	%VersionLabel.get_parent().get_node("TitleLabel").add_theme_font_size_override(
			"font_size", UiTheme.font_of(cfg, &"ui_font_size_display", UiTheme.FONT_DISPLAY))
	%VersionLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_body", UiTheme.FONT_BODY))
	%HintLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	var button_font: int = UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL)
	%StartButton.add_theme_font_size_override("font_size", button_font)
	%ContinueButton.add_theme_font_size_override("font_size", button_font)

func _save_manager() -> Node:
	## 取 SaveManager 自动加载单例（节点路径方式，环境无关）
	## 参数：无
	## 返回：SaveManager 节点
	return get_node("/root/SaveManager")

func _scene_manager() -> Node:
	## 取 SceneManager 自动加载单例（节点路径方式，环境无关）
	## 参数：无
	## 返回：SceneManager 节点
	return get_node("/root/SceneManager")

func _BuildVersionText() -> String:
	## 构建版本号文案（B-11 单源：cfg_main.version_label 替代「DEMO M0」
	## 三处字面量）+ ProjectSettings 版本（未设则只显示前者）
	## 参数：无
	## 返回：版本号文本
	var game_data: Node = get_node_or_null("/root/GameData")
	var cfg: CoreConfig = game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig 			if game_data != null else null
	var label: String = cfg.version_label if cfg != null and not cfg.version_label.is_empty() \
			else "DEMO"
	var version: String = String(ProjectSettings.get_setting("application/config/version", ""))
	if version.is_empty():
		return label
	return "%s · v%s" % [label, version]

func _on_start_pressed() -> void:
	## 「开始」按钮：新建存档并进入公会壳
	## 参数：无
	## 返回：无
	_save_manager().new_game()
	_scene_manager().go(SceneManagerScript.SceneId.GUILD_SHELL)

func _on_continue_pressed() -> void:
	## 「继续」按钮：读档成功跳存档场景；失败禁用按钮并提示（不崩）
	## 参数：无
	## 返回：无
	var loaded: SaveData = _save_manager().load_game()
	if loaded == null:
		%ContinueButton.disabled = true
		%HintLabel.text = "存档读取失败，已禁用继续"
		return
	var target_id: int = _scene_manager().id_from_scene_name(loaded.scene_id)
	if target_id < 0:
		# 存档场景名未登记：回退公会壳（M0 唯一业务场景）
		target_id = SceneManagerScript.SceneId.GUILD_SHELL
	_scene_manager().go(target_id)
