## 标题屏（title_screen）场景脚本
## 职责：展示游戏名/版本；「开始」=无档直接新档、有档先弹覆盖确认（P2 拍板）
## 后进公会壳；「继续」=按存档可用性启用、点击读档成功后跳存档场景
##（失败则禁用+具体原因提示——v1 旧档拒载含 schema 不识别文案）。
## 数据来源：M0 批 4 方案；文案=案 15 口径（游戏名「传奇冒险公会」）。
## 单例访问：统一 get_node("/root/X")（gdUnit 测试环境不注册 autoload 标识符——
## 批 1 实测结论；节点路径方式在运行与测试环境行为一致）。
extends Control

## SceneManager 脚本常量引用（枚举常量不可经实例属性访问——运行时 Invalid get index；
## 经 preloaded 脚本访问 SceneId 是环境无关且类型安全的方式）
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")

## 读档直进路由白名单（S5-01：城内四屏——title「继续」只直进城内时点；存档
## scene_id 非白名单（title/战斗/探索屏名或畸形值）一律回退 GUILD_SHELL，
## 对齐畸形存档保守处理拍板先例——战斗/探索屏不可裸开）
const TOWN_SCENE_WHITELIST: Array[StringName] = [
	&"guild_shell",
	&"association_screen",
	&"guild_dormitory",
	&"guild_training_ground",
]

## UI 文案单源（M4 增补批 3：设置入口与设置面板提示——改措辞只动此处；
## S3-R2-03：开始/继续 go 失败提示；M6 批 2 挂账 4.2：读档失败提示收编）
const UI_TEXTS: Dictionary = {
	&"settings_button": "设置",
	&"settings_applied_hint": "已切换。",
	&"settings_save_failed_hint": "写入设置失败——请重试。",
	&"go_fail_hint_format": "进入游戏失败（错误码 %d）——请重试。",
	&"save_corrupt_format": "存档无法读取——%s，请开新档",
	&"save_load_failed": "存档读取失败，已禁用继续",
	&"save_no_guild_data": "存档无经营数据（旧版存档）——请开新档",
}

## 设置面板（M4 增补批 3——代码构建弹层）
var _settings_panel: SettingsPanel = null
## 最近一次存档拒载原因（C 低级项：save_corrupt 信号缓存——「继续」失败分支
## 拼具体提示，v1 旧档 schema_version 不识别不再只剩泛化「读取失败」）
var _save_corrupt_reason: String = ""

func _ready() -> void:
	## 引擎回调：应用持久化窗口尺寸（每启动必经 title——首帧默认尺寸闪烁
	## DEMO 接受注记）→ 刷新版本号/按钮可用性 → 装配设置面板 → 订阅存档拒载
	## 参数：无
	## 返回：无
	AppSettings.apply_window_size(AppSettings.load_window_size())
	_ApplyFontTiers()
	%VersionLabel.text = _BuildVersionText()
	# S3/S5-R4-01：可读档判定走正本或 .bak 任一（bak-only 崩溃窗口下
	## 「继续」可用、「开始」仍弹 P2 覆盖确认——防唯一幸存档被静默删除）
	%ContinueButton.disabled = not _save_manager().has_loadable_save()
	%HintLabel.text = ""
	_save_corrupt_reason = ""
	_save_manager().save_corrupt.connect(_OnSaveCorrupt)
	# M4 增补批 3：设置面板装配与入口接线
	_settings_panel = SettingsPanel.new()
	_settings_panel.setup(_cfg())
	_settings_panel.closed.connect(_OnSettingsClosed)
	%SettingsHost.add_child(_settings_panel)
	%SettingsButton.text = UI_TEXTS[&"settings_button"]

func _OnSaveCorrupt(reason: String) -> void:
	## 存档拒载原因缓存（SaveManager save_corrupt 信号——读档失败时点回填，
	## 「继续」失败提示消费）
	## 参数 reason：拒载原因（如「schema_version 不识别（1，支持 2）」）
	## 返回：无
	_save_corrupt_reason = reason

func _ApplyFontTiers() -> void:
	## tscn 内嵌字号档位覆写（B-7）：游戏名（64→display）/ VersionLabel
	## （20→body）/ HintLabel（18→normal）；W3-08：开始/继续按钮补齐
	## （按钮统一 normal 档，三屏收口）
	## 参数：无
	## 返回：无
	var game_data: Node = get_node_or_null("/root/GameData")
	var cfg: CoreConfig = null
	if game_data != null:
		cfg = game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	%VersionLabel.get_parent().get_node("TitleLabel").add_theme_font_size_override(
			"font_size", UiTheme.font_of(cfg, &"ui_font_size_display", UiTheme.FONT_DISPLAY))
	%VersionLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_body", UiTheme.FONT_BODY))
	%HintLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	var button_font: int = UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL)
	%StartButton.add_theme_font_size_override("font_size", button_font)
	%ContinueButton.add_theme_font_size_override("font_size", button_font)

func _cfg() -> CoreConfig:
	## 总控配置读取口（设置面板装配消费）
	## 参数：无
	## 返回：CoreConfig；GameData 缺失返回 null
	var game_data: Node = get_node_or_null("/root/GameData")
	if game_data == null:
		return null
	return game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig

func _on_settings_pressed() -> void:
	## 设置按钮：打开设置弹层
	## 参数：无
	## 返回：无
	_settings_panel.open()
	%SettingsHost.visible = true

func _OnSettingsClosed() -> void:
	## 设置面板关闭（隐藏宿主）
	## 参数：无
	## 返回：无
	_settings_panel.close()
	%SettingsHost.visible = false

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
	var cfg: CoreConfig = null
	if game_data != null:
		cfg = game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var label: String = cfg.version_label if cfg != null and not cfg.version_label.is_empty() \
			else "DEMO"
	var version: String = String(ProjectSettings.get_setting("application/config/version", ""))
	if version.is_empty():
		return label
	return "%s · v%s" % [label, version]

func _on_start_pressed() -> void:
	## 「开始」按钮：新档入口（M4 批 2 接线）——P2 拍板：已有存档先弹覆盖
	## 确认（StartConfirm），确认后才 new_game 覆盖；无档直接开始
	## 参数：无
	## 返回：无
	if _save_manager().has_loadable_save():
		%StartConfirm.popup_centered()
		return
	_StartNewGame()

func _on_start_confirm_confirmed() -> void:
	## 覆盖确认弹窗「开始新游戏」（P2：用户已确认覆盖旧档）
	## 参数：无
	## 返回：无
	_StartNewGame()

func _StartNewGame() -> void:
	## 新档建立与跳转（P2 拆口——开始/覆盖确认共用）：GuildState.new_game
	##（初始资金/种子名册/委托板预生成/招募池首刷 + NEW_GAME 存档）→ 公会壳
	## 参数：无
	## 返回：无
	get_node("/root/GuildState").new_game()
	var err: Error = _scene_manager().go(SceneManagerScript.SceneId.GUILD_SHELL)
	if err != OK:
		if err == FAILED:
			# S4-07：重入拒绝（SceneManager 切换进行中）属正常切换态——
			# 不弹「进入游戏失败」误报
			push_warning("title_screen: 进入公会壳被拒——场景切换进行中（正常重入）")
			return
		push_warning("title_screen: 进入公会壳失败（错误码 %d）" % err)
		%HintLabel.text = String(UI_TEXTS[&"go_fail_hint_format"]) % err

func _on_continue_pressed() -> void:
	## 「继续」按钮：读档（公会快照经 GuildState provider 恢复——回最近城内
	## 时点；RETURN_SETTLED 存档锚定公会壳）；失败禁用按钮并提示（不崩）；
	## D-7 轻量版：读档成功但公会快照为空（无经营数据的旧档）——留在标题提示
	## 开新档，不进公会占位屏
	## 参数：无
	## 返回：无
	var loaded: SaveData = _save_manager().load_game()
	if loaded == null:
		%ContinueButton.disabled = true
		# C 低级项（旧档提示）：拒载原因具体化——v1 旧档 schema 不识别等不再
		# 只剩泛化「读取失败」（原因经 save_corrupt 信号缓存；低危 8：单层
		# 括号——消三层嵌套）
		if not _save_corrupt_reason.is_empty():
			%HintLabel.text = UI_TEXTS[&"save_corrupt_format"] % _save_corrupt_reason
		else:
			%HintLabel.text = UI_TEXTS[&"save_load_failed"]
		return
	var guild_state: Node = get_node_or_null("/root/GuildState")
	if guild_state != null and not guild_state.has_guild_data():
		%HintLabel.text = UI_TEXTS[&"save_no_guild_data"]
		return
	# S5-01：读档直进白名单化——目标 scene_id 非城内四屏（含未登记名/畸形值/
	# 战斗·探索屏名）一律回退 GUILD_SHELL（对齐畸形存档保守处理拍板先例）
	var target_id: int = _scene_manager().id_from_scene_name(loaded.scene_id)
	if target_id < 0 or not TOWN_SCENE_WHITELIST.has(loaded.scene_id):
		target_id = SceneManagerScript.SceneId.GUILD_SHELL
	var err: Error = _scene_manager().go(target_id)
	if err != OK:
		push_warning("title_screen: 进入存档场景失败（错误码 %d）" % err)
		%HintLabel.text = String(UI_TEXTS[&"go_fail_hint_format"]) % err
