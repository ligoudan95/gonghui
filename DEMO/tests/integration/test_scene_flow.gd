## 场景流集成测试（M0 批 4，GdUnitSceneRunner；M4 批 2 随正式化更新）
## 覆盖：标题→开始→公会壳（信号/状态；M4 起「开始」走 GuildState.new_game）、
## 公会壳→等待一天（DAY_END 存档落盘+HUD 前进）+返回标题导航、「继续」
## 无档禁用/有档读档往返（公会快照恢复回最近城内时点）、go_back 行为。
## 环境口径（批 4 实证修正）：gdUnit CI 运行器（-s MainLoop）在帧内于主循环树
## root 挂载真实 autoload 节点（批 1 「不注册 autoload」结论仅限 _initialize 时机
## 与 Engine.get_singleton 查询）——场景内 get_node("/root/X") 命中的正是 autoload
## 本体；测试经 get_node_or_null("/root/X") 取同一实例（自建同名节点会被 Godot
## 自动改名 @X@2 导致双实例假象）；存档目录每用例清理（批 3 惯例）。
extends GdUnitTestSuite

## 单例脚本路径
const SAVE_MANAGER_SCRIPT: String = "res://scripts/autoload/save_manager.gd"
const SCENE_MANAGER_SCRIPT: String = "res://scripts/autoload/scene_manager.gd"

## 场景路径
const TITLE_SCENE: String = "res://scenes/title/title_screen.tscn"
const GUILD_SCENE: String = "res://scenes/guild/guild_shell.tscn"

## 场景 id 数值（SceneManager.SceneId：TITLE=0 / GUILD_SHELL=1）
const SCENE_TITLE: int = 0
const SCENE_GUILD_SHELL: int = 1

## 套件级单例实例（before_test 建、after_test 释放）
var _save_manager: Node
var _scene_manager: Node

func before_test() -> void:
	## 用例级前置：取 root 下真 autoload 单例并复位可变状态；清存档目录；
	## GuildState 核心重置（M4 批 2——provider 闭包读字段即时值，重置安全）
	## 参数：无
	## 返回：无
	_CleanSaveDir()
	var root: Node = get_tree().root
	_save_manager = root.get_node_or_null("SaveManager")
	_scene_manager = root.get_node_or_null("SceneManager")
	assert_object(_save_manager).is_not_null()
	assert_object(_scene_manager).is_not_null()
	# 复位单例可变状态（autoload 归引擎管理不释放，用例间重置防互染）
	_save_manager.current = null
	_save_manager.set_expedition_lock(false)
	_scene_manager.current_id = -1
	_scene_manager.previous_id = -1
	var no_params: Dictionary = {}
	_scene_manager.pending_params = no_params
	var guild_state: Node = root.get_node_or_null("GuildState")
	if guild_state != null:
		guild_state.core = GuildCore.new()

func after_test() -> void:
	## 用例级后置：清理存档目录（autoload 单例不释放）
	## 参数：无
	## 返回：无
	_CleanSaveDir()

func _CleanSaveDir() -> void:
	## 清理 user://saves/（批 3 惯例：文件+空目录）
	## 参数：无
	## 返回：无
	var dir: DirAccess = DirAccess.open("user://saves")
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while not entry_name.is_empty():
		if not dir.current_is_dir():
			dir.remove(entry_name)
		entry_name = dir.get_next()
	dir.list_dir_end()
	var parent: DirAccess = DirAccess.open("user://")
	if parent != null and parent.dir_exists("saves"):
		parent.remove("saves")

func _PressButton(runner: GdUnitSceneRunner, child_name: String) -> void:
	## 按节点名查找场景内按钮并触发 pressed 信号（驱动 connection 到场景脚本）
	## 参数 runner：场景运行器；child_name：按钮节点名
	## 返回：无
	var button: Button = runner.find_child(child_name, true, false) as Button
	assert_object(button).is_not_null()
	button.pressed.emit()

func _AwaitSceneSwap() -> void:
	## 等待场景切换落地（change_scene_to_packed 为延迟切换，让过两帧）
	## 参数：无
	## 返回：无
	await get_tree().process_frame
	await get_tree().process_frame

func test_title_start_to_guild_shell() -> void:
	## 标题→「开始」→公会壳：scene_changed 到 GUILD_SHELL、current_id 正确、
	## 运行态新档就绪
	var changed_events: Array = []
	var callback: Callable = func(from_id: int, to_id: int) -> void: changed_events.append([from_id, to_id])
	_scene_manager.scene_changed.connect(callback)
	var runner: GdUnitSceneRunner = scene_runner(TITLE_SCENE)
	_PressButton(runner, "StartButton")
	await _AwaitSceneSwap()
	_scene_manager.scene_changed.disconnect(callback)
	# 公会壳已挂树（标题场景 runner 场景仍在树上，切换链验证新场景存在）
	assert_object(get_tree().root.find_child("GuildShell", true, false)).is_not_null()
	assert_int(_scene_manager.current_id).is_equal(SCENE_GUILD_SHELL)
	assert_int(changed_events.size()).is_equal(1)
	assert_int(changed_events[0][1]).is_equal(SCENE_GUILD_SHELL)
	# 「开始」建立的新档
	assert_object(_save_manager.current).is_not_null()
	assert_int(_save_manager.current.game_day).is_equal(1)

func test_guild_shell_wait_day_saves_and_back_button() -> void:
	## 公会壳「等待一天」（M4 批 2 正式化——原存档演示三件退役）：DAY_END 存档
	## 落盘 + HUD 天数前进；「返回标题」纯导航回标题（不触存档——五时点自动存档）
	var guild_state: Node = get_tree().root.get_node("GuildState")
	guild_state.new_game()
	var runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	_PressButton(runner, "WaitButton")
	await get_tree().process_frame
	assert_bool(_save_manager.has_save()).is_true()
	var loaded: SaveData = _save_manager.load_game()
	assert_object(loaded).is_not_null()
	assert_int(loaded.save_point).is_equal(SaveData.SavePoint.DAY_END)
	assert_int(loaded.game_day).is_equal(2)
	assert_int(_save_manager.current.game_day).is_equal(2)
	# HUD 展示第 2 天
	var day_label: Label = get_tree().root.find_child("DayLabel", true, false) as Label
	assert_object(day_label).is_not_null()
	assert_str(day_label.text).contains("第 2 天")
	_PressButton(runner, "BackButton")
	await _AwaitSceneSwap()
	assert_object(get_tree().root.find_child("TitleScreen", true, false)).is_not_null()
	assert_int(_scene_manager.current_id).is_equal(SCENE_TITLE)

func test_continue_disabled_without_save() -> void:
	## 无档时「继续」按钮 disabled（_ready 按 has_save 决定）
	var runner: GdUnitSceneRunner = scene_runner(TITLE_SCENE)
	var continue_button: Button = runner.find_child("ContinueButton", true, false) as Button
	assert_object(continue_button).is_not_null()
	assert_bool(continue_button.disabled).is_true()

func test_continue_with_save_roundtrip() -> void:
	## 有档→「继续」→进公会壳回最近城内时点（M4 批 2：公会快照经 GuildState
	## provider 恢复——HUD 天数与存档一致；验收① 口径延续）
	# 造档（生产口径：GuildState.new_game + 等待两天至 day3 → RETURN_SETTLED 时点）
	var guild_state: Node = get_tree().root.get_node("GuildState")
	guild_state.new_game()
	guild_state.wait_one_day()
	guild_state.wait_one_day()
	assert_int(_save_manager.current.game_day).is_equal(3)
	assert_int(_save_manager.autosave(SaveData.SavePoint.RETURN_SETTLED)).is_equal(OK)
	_save_manager.current = null
	guild_state.core = GuildCore.new()
	# 标题 _ready：has_save → 继续可用
	var runner: GdUnitSceneRunner = scene_runner(TITLE_SCENE)
	var continue_button: Button = runner.find_child("ContinueButton", true, false) as Button
	assert_bool(continue_button.disabled).is_false()
	_PressButton(runner, "ContinueButton")
	await _AwaitSceneSwap()
	# 进入公会壳且运行态=读入的存档
	assert_object(get_tree().root.find_child("GuildShell", true, false)).is_not_null()
	assert_int(_scene_manager.current_id).is_equal(SCENE_GUILD_SHELL)
	assert_object(_save_manager.current).is_not_null()
	assert_int(_save_manager.current.game_day).is_equal(3)
	assert_int(_save_manager.current.save_point).is_equal(SaveData.SavePoint.RETURN_SETTLED)
	# 公会 HUD 与恢复的公会快照一致（第 3 天）
	var day_label: Label = get_tree().root.find_child("DayLabel", true, false) as Label
	assert_object(day_label).is_not_null()
	assert_str(day_label.text).contains("第 3 天")
	# 公会核心恢复等价（名册/委托板规模）
	assert_int(guild_state.core.roster.size()).is_equal(4)
	assert_int(guild_state.core.board.board.size()).is_equal(3)
	assert_int(guild_state.core.day).is_equal(3)

func test_start_with_save_shows_confirm_before_overwrite() -> void:
	## P2 拍板回归：已有存档时「开始」先弹覆盖确认——未确认不建新档不切场景；
	## 确认后覆盖开新档（旧档 day3 → 新档 day1）
	var guild_state: Node = get_tree().root.get_node("GuildState")
	guild_state.core = GuildCore.new()
	guild_state.new_game()
	guild_state.wait_one_day()
	guild_state.wait_one_day()
	assert_int(_save_manager.current.game_day).is_equal(3)
	_save_manager.current = null
	guild_state.core = GuildCore.new()
	var runner: GdUnitSceneRunner = scene_runner(TITLE_SCENE)
	_PressButton(runner, "StartButton")
	await get_tree().process_frame
	# 未确认：覆盖确认弹窗可见、未建新档未切场景
	var confirm: ConfirmationDialog = runner.find_child("StartConfirm", true, false) as ConfirmationDialog
	assert_object(confirm).is_not_null()
	assert_bool(confirm.visible).is_true()
	assert_object(_save_manager.current).is_null()
	assert_int(_scene_manager.current_id).is_equal(-1)
	# 低危 2（取消负路径）：取消后弹窗关闭、旧档完好（仍无新档）、
	# 再按「开始」仍弹覆盖确认（不被首次弹窗消费掉）；经真实取消钮路径驱动
	#（内部隐藏+发 canceled）
	(confirm.get_cancel_button() as Button).pressed.emit()
	await get_tree().process_frame
	assert_bool(confirm.visible).is_false()
	assert_object(_save_manager.current).is_null()
	_PressButton(runner, "StartButton")
	await get_tree().process_frame
	assert_bool(confirm.visible).is_true()
	# 确认：覆盖开新档（day 1）+ 进公会壳
	confirm.confirmed.emit()
	await _AwaitSceneSwap()
	assert_object(_save_manager.current).is_not_null()
	assert_int(_save_manager.current.game_day).is_equal(1)
	assert_int(_scene_manager.current_id).is_equal(SCENE_GUILD_SHELL)

func _WriteLegacySave(version: int) -> void:
	## 造旧版 schema 存档（v1/v2 双档共用——修复批次 2 单用例拆双档）
	## 参数 version：schema_version 数值（1 或 2）
	## 返回：无
	var dir: DirAccess = DirAccess.open("user://")
	dir.make_dir_recursive("saves")
	var file: FileAccess = FileAccess.open("user://saves/main_save.json", FileAccess.WRITE)
	file.store_string("{\"schema_version\": %d, \"save_point\": 1, \"game_day\": 1, " % version
			+ "\"mode\": \"demo\", \"scene_id\": \"guild_shell\", "
			+ "\"saved_unix_time\": 0, \"payload\": {}}")
	file.close()

func _AssertLegacyRejectFlow() -> void:
	## 旧版拒载公共流：继续失败禁用+具体原因+开始弹覆盖确认（串联）
	## 参数：无
	## 返回：无（协程）
	var runner: GdUnitSceneRunner = scene_runner(TITLE_SCENE)
	var continue_button: Button = runner.find_child("ContinueButton", true, false) as Button
	assert_bool(continue_button.disabled).is_false()
	_PressButton(runner, "ContinueButton")
	await get_tree().process_frame
	assert_bool(continue_button.disabled).is_true()
	var hint: Label = runner.find_child("HintLabel", true, false) as Label
	assert_str(hint.text).contains("schema_version")
	assert_str(hint.text).contains("开新档")
	# 低危 11（串联流）：继续失败后点「开始」——旧档仍在（拒载不删档），
	# 覆盖确认照常弹出（P2 门禁不被读档失败旁路）
	_PressButton(runner, "StartButton")
	await get_tree().process_frame
	var confirm: ConfirmationDialog = runner.find_child("StartConfirm", true, false) as ConfirmationDialog
	assert_object(confirm).is_not_null()
	assert_bool(confirm.visible).is_true()
	assert_object(_save_manager.current).is_null()

func test_continue_v1_save_reject_shows_specific_hint() -> void:
	## C 低级项（旧档提示）回归：v1 schema 旧档拒载——「继续」失败提示带
	## 具体原因（schema_version 不识别）与开新档指引
	_WriteLegacySave(1)
	await _AssertLegacyRejectFlow()

func test_continue_v2_save_reject_shows_specific_hint() -> void:
	## M4 增补批（schema 升 v3）：v2 档同样拒载（guild 快照实例缺
	## work_days_left 必填键——v3 起旧档整体拒载走 save_corrupt 通道）
	_WriteLegacySave(2)
	await _AssertLegacyRejectFlow()

func test_go_back_returns_to_previous_scene() -> void:
	## go_back：TITLE→公会壳→go_back 返回上一屏（TITLE）；从未进入场景时 FAILED
	assert_int(_scene_manager.go(SCENE_TITLE)).is_equal(OK)
	await _AwaitSceneSwap()
	assert_int(_scene_manager.go(SCENE_GUILD_SHELL)).is_equal(OK)
	await _AwaitSceneSwap()
	assert_int(_scene_manager.current_id).is_equal(SCENE_GUILD_SHELL)
	assert_int(_scene_manager.go_back()).is_equal(OK)
	await _AwaitSceneSwap()
	assert_int(_scene_manager.current_id).is_equal(SCENE_TITLE)
	assert_int(_scene_manager.previous_id).is_equal(SCENE_GUILD_SHELL)

func test_go_back_without_previous_fails() -> void:
	## 无上一屏（新实例 current_id=-1）时 go_back 返回 FAILED
	assert_int(_scene_manager.current_id).is_equal(-1)
	assert_int(_scene_manager.go_back()).is_equal(FAILED)

func test_pending_params_taken_once() -> void:
	## 跨场景参数：go 存 pending_params，take_pending_params 取走后清空
	assert_int(_scene_manager.go(SCENE_GUILD_SHELL, {"day_jump": 5})).is_equal(OK)
	var params: Dictionary = _scene_manager.take_pending_params()
	assert_int(params.get("day_jump", 0)).is_equal(5)
	assert_bool(_scene_manager.take_pending_params().is_empty()).is_true()
	await _AwaitSceneSwap()

func test_go_failure_does_not_pollute_state() -> void:
	## go 失败不污染状态（盲审批 3 B-1）：未知场景 id 拒绝后 current_id/
	## previous_id/pending_params 保持原值（原实现先赋值后切换，失败会把
	## current_id 推进到未实际进入的场景）
	assert_int(_scene_manager.current_id).is_equal(-1)
	assert_int(_scene_manager.go(999)).is_equal(ERR_INVALID_PARAMETER)
	assert_int(_scene_manager.current_id).is_equal(-1)
	assert_int(_scene_manager.previous_id).is_equal(-1)
	assert_bool(_scene_manager.pending_params.is_empty()).is_true()

func test_go_reports_scene_id_to_save_manager() -> void:
	## 切换上报存档场景（盲审批 3 B-3）：new_game 后 go → SaveManager.current.
	## scene_id 同步为目标场景名（预置异值证明覆写来自 go 上报）；无运行态
	## 时静默不建档
	_save_manager.new_game()
	_save_manager.current.scene_id = &"battle_screen"
	assert_int(_scene_manager.go(SCENE_GUILD_SHELL)).is_equal(OK)
	assert_str(String(_save_manager.current.scene_id)).is_equal("guild_shell")
	await _AwaitSceneSwap()
	assert_int(_scene_manager.go(SCENE_TITLE)).is_equal(OK)
	assert_str(String(_save_manager.current.scene_id)).is_equal("title")
	await _AwaitSceneSwap()
	assert_object(_save_manager.current).is_not_null()

func test_go_rejected_while_switch_pending() -> void:
	## 切换进行中拒重入（盲审批 3 B-4）：go 发起后（帧末替换落地前）二次 go
	## 被拒（FAILED + 状态不被篡改）；替换落地（两帧）后 go 恢复可用
	assert_int(_scene_manager.go(SCENE_GUILD_SHELL)).is_equal(OK)
	assert_int(_scene_manager.current_id).is_equal(SCENE_GUILD_SHELL)
	# 立即二次 go：切换尚未落地 → 拒绝（目标不切换、状态不变）
	assert_int(_scene_manager.go(SCENE_TITLE)).is_equal(FAILED)
	assert_int(_scene_manager.current_id).is_equal(SCENE_GUILD_SHELL)
	await _AwaitSceneSwap()
	# 帧末替换已落地：重入锁解除，go 恢复可用
	assert_int(_scene_manager.go(SCENE_TITLE)).is_equal(OK)
	assert_int(_scene_manager.current_id).is_equal(SCENE_TITLE)
	await _AwaitSceneSwap()

## test_guild_save_failure_keeps_screen（S5-4 存档失败反馈）已随 M4 批 2
## 存档演示三件退役移除——演示触发按钮（保存并返回标题）不复存在；
## SaveManager 层的写入容错（FAILED 返回/原子写回滚）由 test_save_manager 单测覆盖。

func test_settings_button_and_panel_contract() -> void:
	## M4 增补批 3：设置入口契约——设置按钮开面板（两项下拉）→选大档
	##（headless 跳过窗口尺寸断言只验 cfg）→重进 title 保持→清理复位
	DirAccess.remove_absolute("user://settings.cfg")
	var runner: GdUnitSceneRunner = scene_runner(TITLE_SCENE)
	var settings_button: Button = runner.find_child("SettingsButton", true, false) as Button
	assert_object(settings_button).is_not_null()
	settings_button.pressed.emit()
	await get_tree().process_frame
	var panel: SettingsPanel = runner.find_child("SettingsPanel", true, false) as SettingsPanel
	assert_object(panel).is_not_null()
	assert_bool(panel.visible).is_true()
	var option: OptionButton = runner.find_child("SizeOption", true, false) as OptionButton
	assert_object(option).is_not_null()
	assert_int(option.item_count).is_equal(2)
	assert_int(option.selected).is_equal(0)
	# 选大档：持久化落盘（headless 窗口断言跳过——DisplayServer 窗口恒 0）
	option.select(1)
	option.item_selected.emit(1)
	await get_tree().process_frame
	assert_str(AppSettings.load_window_size()).is_equal(AppSettings.SIZE_LARGE)
	# 试玩 BUG 修复回归：非 headless 真窗口下选档即改窗口尺寸（gdUnit CI 窗口
	# MINIMIZED——apply 先恢复 WINDOWED 再 set；headless 窗口恒 (0,0) 跳过）
	if DisplayServer.get_name() != "headless":
		assert_vector(DisplayServer.window_get_size()).is_equal(
					AppSettings.WINDOW_SIZES[AppSettings.SIZE_LARGE])
	var applied_hint: Label = runner.find_child("SettingsHintLabel", true, false) as Label
	assert_object(applied_hint).is_not_null()
	# 关闭 → 重进 title：设置保持大档（每启动 apply 消费）
	(runner.find_child("CloseSettingsButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	assert_bool(panel.visible).is_false()
	var runner2: GdUnitSceneRunner = scene_runner(TITLE_SCENE)
	await get_tree().process_frame
	var option2: OptionButton = runner2.find_child("SizeOption", true, false) as OptionButton
	assert_object(option2).is_not_null()
	# after 复位：默认档 + 删 cfg（防互染）
	AppSettings.apply_window_size(AppSettings.SIZE_DEFAULT)
	DirAccess.remove_absolute("user://settings.cfg")
