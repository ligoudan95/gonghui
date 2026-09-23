## 场景管理器（自动加载单例：SceneManager）
## 职责：M0 场景流——场景表驱动的切换（go/go_back）、跨场景参数传递
## （pending_params，目标场景 _ready 经 take_pending_params 读取并清空）、
## scene_changed 信号；后续里程碑场景在 SceneId/SCENE_TABLE 追加。
## 数据来源：M0 批 4 方案；场景规格=案 15 §2.2（横屏 16:9 基准）。
## 依赖口径：不阻塞于 SaveManager（场景脚本自行决定存档时点）；
## change_scene_to_packed 为延迟切换（帧末生效），go 返回值为装载校验结果。
extends Node

## 场景 id 枚举（后续里程碑在此追加）
enum SceneId {
	TITLE,
	GUILD_SHELL,
}

## 切换完成信号（from_id=切换前场景、to_id=目标场景；发起切换即发，
## 实际场景树替换在帧末完成）
signal scene_changed(from_id: int, to_id: int)

## 场景表：SceneId -> 场景资源路径
const SCENE_TABLE: Dictionary = {
	SceneId.TITLE: "res://scenes/title/title_screen.tscn",
	SceneId.GUILD_SHELL: "res://scenes/guild/guild_shell.tscn",
}

## 场景名 -> SceneId 映射（SaveData.scene_id 的 StringName 到枚举的解析）
const SCENE_NAME_TO_ID: Dictionary = {
	&"title": SceneId.TITLE,
	&"guild_shell": SceneId.GUILD_SHELL,
}

## 当前场景 id（未进入任何场景时 = -1）
var current_id: int = -1
## 上一场景 id（供 go_back；无上一屏 = -1）
var previous_id: int = -1
## 跨场景参数（目标场景 _ready 经 take_pending_params 取走并清空）
var pending_params: Dictionary = {}

func go(scene_id: int, params: Dictionary = {}) -> Error:
	## 切换到目标场景：装载校验→记录切换链→存 pending_params→
	## change_scene_to_packed（帧末替换）→发 scene_changed
	## 参数 scene_id：目标场景（SceneId 之一）；params：传给目标场景的参数
	## 返回：OK=已发起切换；ERR_INVALID_PARAMETER=未知场景 id；
	## ERR_CANT_OPEN=场景资源装载失败
	if not SCENE_TABLE.has(scene_id):
		push_warning("SceneManager: 未知场景 id %d" % scene_id)
		return ERR_INVALID_PARAMETER
	var scene_path: String = SCENE_TABLE[scene_id]
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("SceneManager: 场景装载失败 %s" % scene_path)
		return ERR_CANT_OPEN
	previous_id = current_id
	current_id = scene_id
	pending_params = params
	var err: Error = get_tree().change_scene_to_packed(packed)
	if err != OK:
		push_error("SceneManager: 场景切换失败 %s（错误码 %d）" % [scene_path, err])
		return err
	scene_changed.emit(previous_id, scene_id)
	return OK

func go_back() -> Error:
	## 返回上一屏：有上一屏则 go(previous_id)；无则 FAILED + push_warning
	## 参数：无
	## 返回：OK=已发起切换；FAILED=无上一屏
	if previous_id < 0 or not SCENE_TABLE.has(previous_id):
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
	if SCENE_NAME_TO_ID.has(scene_name):
		return SCENE_NAME_TO_ID[scene_name]
	push_warning("SceneManager: 场景名 '%s' 未登记于 SCENE_NAME_TO_ID" % scene_name)
	return -1
