## 场景流集成测试（M0 批 4，GdUnitSceneRunner）
## 覆盖：标题→开始→公会壳（信号/状态）、公会壳→保存并返回标题（存档落盘）、
## 「继续」无档禁用/有档读档往返（验收①）、go_back 行为。
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
	## 用例级前置：取 root 下真 autoload 单例并复位可变状态；清存档目录
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

func test_guild_shell_save_and_back_to_title() -> void:
	## 公会壳→「保存并返回标题」：DAY_END 存档落盘 + 标题场景挂树
	_save_manager.new_game()
	_save_manager.current.game_day = 2
	var runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	_PressButton(runner, "SaveAndBackButton")
	await _AwaitSceneSwap()
	assert_bool(_save_manager.has_save()).is_true()
	assert_object(get_tree().root.find_child("TitleScreen", true, false)).is_not_null()
	assert_int(_scene_manager.current_id).is_equal(SCENE_TITLE)
	# 落盘内容与触发时点一致
	var loaded: SaveData = _save_manager.load_game()
	assert_object(loaded).is_not_null()
	assert_int(loaded.save_point).is_equal(SaveData.SavePoint.DAY_END)
	assert_int(loaded.game_day).is_equal(2)

func test_continue_disabled_without_save() -> void:
	## 无档时「继续」按钮 disabled（_ready 按 has_save 决定）
	var runner: GdUnitSceneRunner = scene_runner(TITLE_SCENE)
	var continue_button: Button = runner.find_child("ContinueButton", true, false) as Button
	assert_object(continue_button).is_not_null()
	assert_bool(continue_button.disabled).is_true()

func test_continue_with_save_roundtrip() -> void:
	## 有档→「继续」→进公会壳且展示 save_point/game_day 与存档一致（验收①）
	# 造档：day=3、时点 RETURN_SETTLED、场景 guild_shell
	var seed_save: SaveData = _save_manager.new_game()
	seed_save.game_day = 3
	assert_int(_save_manager.autosave(SaveData.SavePoint.RETURN_SETTLED)).is_equal(OK)
	_save_manager.current = null
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
	# 公会壳展示锚点与存档一致（save_point 名 / game_day / mode）
	var info_label: Label = get_tree().root.find_child("SaveInfoLabel", true, false) as Label
	assert_object(info_label).is_not_null()
	assert_str(info_label.text).is_not_empty()
	assert_str(info_label.text).contains("RETURN_SETTLED")
	assert_str(info_label.text).contains("3")

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
