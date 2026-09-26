## 场景管理器（自动加载单例：SceneManager）
## 职责：M0 场景流——场景表驱动的切换（go/go_back）、跨场景参数传递
## （pending_params，目标场景 _ready 经 take_pending_params 读取并清空）、
## scene_changed 信号；后续里程碑场景在 SceneId/SCENE_REGISTRY 追加。
## 加固（盲审批 3）：go 失败不污染状态（B-1）；切换进行中拒重入（B-4）；
## 切换成功上报 SaveManager.current.scene_id（B-3，下游报上游合规向）。
## 战斗中存档快照登记注（后延归属拍板④）：战斗中 autosave 的出征参数快照
## 归 M5 设计；结算面板委托结算归 M4；事件奖励只累计不入账归 M4。
## 数据来源：M0 批 4 方案；场景规格=案 15 §2.2（横屏 16:9 基准）。
## 依赖口径：不阻塞于 SaveManager（场景脚本自行决定存档时点）；
## change_scene_to_packed 为延迟切换（帧末生效），go 返回值为装载校验结果。
extends Node

## 场景 id 枚举（后续里程碑在此追加）
enum SceneId {
	TITLE,
	GUILD_SHELL,
	BATTLE_SCREEN,
	EVENT_SCREEN,
	EXPLORE_SCREEN,
}

## 切换完成信号（from_id=切换前场景、to_id=目标场景；发起切换即发，
## 实际场景树替换在帧末完成）
signal scene_changed(from_id: int, to_id: int)

## 场景注册表（C-4 单表合并：场景名 -> {id, path}——原 SCENE_TABLE 与
## SCENE_NAME_TO_ID 双表收敛为一处登记，id/path/名三者恒一致；
## 新增场景只加一行，反查经遍历推导）
const SCENE_REGISTRY: Dictionary = {
	&"title": {&"id": SceneId.TITLE, &"path": "res://scenes/title/title_screen.tscn"},
	&"guild_shell": {&"id": SceneId.GUILD_SHELL, &"path": "res://scenes/guild/guild_shell.tscn"},
	&"battle_screen": {&"id": SceneId.BATTLE_SCREEN, &"path": "res://scenes/battle/battle_screen.tscn"},
	&"event_screen": {&"id": SceneId.EVENT_SCREEN, &"path": "res://scenes/event/event_screen.tscn"},
	&"explore_screen": {&"id": SceneId.EXPLORE_SCREEN, &"path": "res://scenes/explore/explore_screen.tscn"},
}

## 当前场景 id（未进入任何场景时 = -1）
var current_id: int = -1
## 上一场景 id（供 go_back；无上一屏 = -1）
var previous_id: int = -1
## 跨场景参数（目标场景 _ready 经 take_pending_params 取走并清空）
var pending_params: Dictionary = {}

## 切换进行中标记（change_scene_to_packed 为帧末延迟替换——盲审批 3 B-4：
## 发起到替换落地期间拒绝二次 go，防重入导致切换链/参数互相覆盖）
var _switch_pending: bool = false

func go(scene_id: int, params: Dictionary = {}) -> Error:
	## 切换到目标场景：装载校验→change_scene_to_packed（帧末替换）→
	## **切换发起成功后**才记录切换链/存 pending_params（盲审批 3 B-1：失败
	## 不污染状态——原实现先赋值后切换，装载/切换失败会把 current_id 推进到
	## 未实际进入的场景）→上报存档场景名（B-3）→发 scene_changed
	## 参数 scene_id：目标场景（SceneId 之一）；params：传给目标场景的参数
	## 返回：OK=已发起切换；ERR_INVALID_PARAMETER=未知场景 id；
	## ERR_CANT_OPEN=场景资源装载失败；FAILED=上一次切换尚未完成（B-4 拒重入）
	if _switch_pending:
		push_warning("SceneManager: 上一次场景切换尚未完成，拒绝重复 go（%d）" % scene_id)
		return FAILED
	var scene_path: String = _PathOf(scene_id)
	if scene_path.is_empty():
		push_warning("SceneManager: 未知场景 id %d" % scene_id)
		return ERR_INVALID_PARAMETER
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("SceneManager: 场景装载失败 %s" % scene_path)
		return ERR_CANT_OPEN
	var err: Error = get_tree().change_scene_to_packed(packed)
	if err != OK:
		push_error("SceneManager: 场景切换失败 %s（错误码 %d）" % [scene_path, err])
		return err
	previous_id = current_id
	current_id = scene_id
	pending_params = params
	_switch_pending = true
	_FinishSwitch()
	_ReportSceneToSave(scene_id)
	scene_changed.emit(previous_id, scene_id)
	return OK

func _FinishSwitch() -> void:
	## 切换收尾：帧末替换落地（让过两帧——change_scene_to_packed 延迟语义）
	## 后清除进行中标记，恢复 go 可用
	## 参数：无
	## 返回：无（协程——fire-and-forget，go 同步返回不受阻）
	await get_tree().process_frame
	await get_tree().process_frame
	_switch_pending = false

func _ReportSceneToSave(scene_id: int) -> void:
	## 场景切换上报存档运行态（盲审批 3 B-3）：SaveManager.current.scene_id
	## 同步为目标场景名——下游 SceneManager 向上游 SaveManager 上报，依赖方向
	## 与铁律④链（…→SaveManager→SceneManager）一致；无 SaveManager 节点
	## （headless 测试）或无运行态（未 new_game/load_game）时静默跳过
	## 参数 scene_id：目标场景（SceneId 之一）
	## 返回：无
	if not is_inside_tree():
		return
	var save_manager: Node = get_tree().root.get_node_or_null("SaveManager")
	if save_manager == null or save_manager.current == null:
		return
	var scene_name: StringName = _SceneNameOf(scene_id)
	if scene_name != &"":
		save_manager.current.scene_id = scene_name

func _SceneNameOf(scene_id: int) -> StringName:
	## SceneId -> 场景名（C-4：SCENE_REGISTRY 反查；SaveData.scene_id 存名口径）
	## 参数 scene_id：场景枚举值
	## 返回：场景名；未登记返回空 StringName
	for scene_name: StringName in SCENE_REGISTRY:
		if SCENE_REGISTRY[scene_name][&"id"] == scene_id:
			return scene_name
	push_warning("SceneManager: 场景 id %d 未登记于 SCENE_REGISTRY" % scene_id)
	return &""

func _PathOf(scene_id: int) -> String:
	## SceneId -> 场景资源路径（C-4：SCENE_REGISTRY 推导；未登记返回空串）
	## 参数 scene_id：场景枚举值
	## 返回：资源路径
	for scene_name: StringName in SCENE_REGISTRY:
		if SCENE_REGISTRY[scene_name][&"id"] == scene_id:
			return SCENE_REGISTRY[scene_name][&"path"]
	return ""

func go_back() -> Error:
	## 返回上一屏：有上一屏则 go(previous_id)；无则 FAILED + push_warning
	## 参数：无
	## 返回：OK=已发起切换；FAILED=无上一屏
	if previous_id < 0 or _PathOf(previous_id).is_empty():
		push_warning("SceneManager: 无上一屏可返回（previous_id=%d）" % previous_id)
		return FAILED
	return go(previous_id)

func take_pending_params() -> Dictionary:
	## 取走跨场景参数并清空（目标场景 _ready 调用；未传参返回空表）
	## 参数：无
	## 返回：本次切换传入的参数 Dictionary
	var params: Dictionary = pending_params
	pending_params = {}
	return params

func id_from_scene_name(scene_name: StringName) -> int:
	## 存档 scene_id（StringName）解析为 SceneId
	## 参数 scene_name：场景名（SaveData.scene_id）
	## 返回：对应 SceneId；未登记返回 -1
	if SCENE_REGISTRY.has(scene_name):
		return SCENE_REGISTRY[scene_name][&"id"]
	push_warning("SceneManager: 场景名 '%s' 未登记于 SCENE_REGISTRY" % scene_name)
	return -1
