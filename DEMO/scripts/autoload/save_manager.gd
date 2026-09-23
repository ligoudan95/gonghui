## 存档管理器（自动加载单例：SaveManager）
## 职责：#26 最简自动存档——运行态 SaveData 的建立（new_game）、四时点自动写盘
## （autosave，出征锁跳过）、读档（load_game，损坏容错不崩）与各系统快照
## provider 的注册扩展点（M0 空 registry、机制就位）。
## 数据来源：M0 批 3 方案；存档路径 user://saves/main_save.json。
## 事务口径：原子写——先写 main_save.json.tmp 再 rename 替换正本，
## 半写/中断不污染既有存档（rename 覆盖失败时降级 remove+rename 两段式）。
## 依赖口径：不依赖 SceneManager（批 4 才有）；scene_id 以 StringName 字面量占位。
extends Node

## 自动存档写入完成信号（point=本次写入时点）
signal save_written(point: SaveData.SavePoint)
## 读档成功信号（save_data=已载入的存档）
signal save_loaded(save_data: SaveData)
## 存档损坏信号（reason=损坏原因；进程不崩、current 不变）
signal save_corrupt(reason: String)

## 存档目录与文件（user:// 在本机指向 appdata；测试须清理防互染）
const SAVE_DIR: String = "user://saves"
const SAVE_PATH: String = "user://saves/main_save.json"
const TEMP_PATH: String = "user://saves/main_save.json.tmp"

## 识别的存档结构版本（不识别则拒载走 save_corrupt）
const SUPPORTED_SCHEMA_VERSION: int = 1

## 占位场景 id：公会壳（批 4 SceneManager 落地前）
const SCENE_GUILD_SHELL: StringName = &"guild_shell"

## 运行态存档（new_game/load_game 建立前为 null）
var current: SaveData

## 出征锁（#26：出征中不自动存档；M3 出征层经 set_expedition_lock 调用）
var _expedition_lock: bool = false

## 快照 provider 注册表：系统名 -> [save_fn, restore_fn]（M0 空，机制就位）
var _snapshot_providers: Dictionary[StringName, Array] = {}

func new_game() -> SaveData:
	## 建立新档：重置运行态（game_day=1、mode 取 GameConfig、scene_id=公会壳占位）
	## 参数：无
	## 返回：新建的 SaveData（同时赋给 current）
	current = SaveData.new()
	current.schema_version = SUPPORTED_SCHEMA_VERSION
	current.save_point = SaveData.SavePoint.DAY_END
	current.game_day = 1
	current.mode = _ResolveMode()
	current.scene_id = SCENE_GUILD_SHELL
	current.saved_unix_time = 0
	current.payload = {}
	return current

func autosave(point: SaveData.SavePoint) -> Error:
	## 自动存档：出征锁生效时跳过（返回 OK + push_warning，#26 口径）；
	## 否则填时点/时间戳→收集快照→原子写盘→成功发 save_written
	## 参数 point：写入时点（四时点之一）
	## 返回：OK=写入成功或锁跳过；FAILED=运行态缺失或写盘失败（附 push_error）
	if _expedition_lock:
		push_warning("SaveManager: 出征锁生效，跳过自动存档（时点 %d）" % point)
		return OK
	if current == null:
		push_error("SaveManager: 运行态缺失，请先 new_game/load_game")
		return FAILED
	current.save_point = point
	current.saved_unix_time = int(Time.get_unix_time_from_system())
	_CollectSnapshots()
	var err: Error = _WriteAtomic(JSON.stringify(current.to_dict()))
	if err != OK:
		push_error("SaveManager: 存档写入失败（错误码 %d）" % err)
		return err
	save_written.emit(point)
	return OK

func load_game() -> SaveData:
	## 读档：文件缺失返回 null（不发信号）；JSON 解析失败/版本不识别/字段校验
	## 失败→emit save_corrupt 并返回 null（不崩、current 不变）；
	## 成功→from_dict→current 更新→恢复快照→emit save_loaded
	## 参数：无
	## 返回：载入的 SaveData；无文件或损坏返回 null
	if not has_save():
		return null
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		save_corrupt.emit("存档文件无法打开（错误码 %d）" % FileAccess.get_open_error())
		return null
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		save_corrupt.emit("JSON 解析失败")
		return null
	var version_value: Variant = parsed.get("schema_version", null)
	if not SaveData.IsIntLike(version_value) or int(version_value) != SUPPORTED_SCHEMA_VERSION:
		save_corrupt.emit("schema_version 不识别（%s，支持 %d）" % [str(version_value), SUPPORTED_SCHEMA_VERSION])
		return null
	var data: SaveData = SaveData.from_dict(parsed)
	if data == null:
		save_corrupt.emit("存档字段类型校验失败")
		return null
	current = data
	_RestoreSnapshots()
	save_loaded.emit(data)
	return data

func has_save() -> bool:
	## 是否存在存档文件
	## 参数：无
	## 返回：true = 正本存在
	return FileAccess.file_exists(SAVE_PATH)

func set_expedition_lock(locked: bool) -> void:
	## 设置出征锁（M3 出征层调用；锁生效期间 autosave 跳过）
	## 参数 locked：true = 出征中
	## 返回：无
	_expedition_lock = locked

func register_snapshot_provider(sys_name: StringName, save_fn: Callable, restore_fn: Callable) -> void:
	## 注册系统快照 provider（M1+ 各系统扩展点）：autosave 时 payload[sys_name]=
	## save_fn() 返回值；load 后以 payload[sys_name] 调 restore_fn
	## 参数 sys_name：系统名（payload 键）；save_fn：快照收集回调（-> Dictionary）；
	## restore_fn：快照恢复回调（Dictionary -> void）
	## 返回：无
	_snapshot_providers[sys_name] = [save_fn, restore_fn]

func _CollectSnapshots() -> void:
	## 遍历 provider 收集各系统快照到 current.payload
	## 参数：无
	## 返回：无
	for sys_name: StringName in _snapshot_providers:
		var provider: Array = _snapshot_providers[sys_name]
		var snapshot: Variant = provider[0].call()
		if snapshot is Dictionary:
			current.payload[sys_name] = snapshot
		else:
			push_warning("SaveManager: 快照 provider '%s' 返回值非 Dictionary，跳过" % sys_name)

func _RestoreSnapshots() -> void:
	## 遍历 provider 恢复各系统快照（payload 无该系统键则跳过）
	## 参数：无
	## 返回：无
	for sys_name: StringName in _snapshot_providers:
		if not current.payload.has(sys_name):
			continue
		var provider: Array = _snapshot_providers[sys_name]
		provider[1].call(current.payload[sys_name])

func _WriteAtomic(json_text: String) -> Error:
	## 原子写：建目录→写 tmp→rename 替换正本（rename 覆盖失败降级 remove+rename）
	## 参数 json_text：序列化后的 JSON 文本
	## 返回：OK=正本已替换；否则为文件/目录操作错误码
	var dir_err: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if dir_err != OK:
		return dir_err
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_text)
	file.flush()
	file.close()
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return FAILED
	var rename_err: Error = dir.rename(TEMP_PATH, SAVE_PATH)
	if rename_err == OK:
		return OK
	# Windows 平台 rename 覆盖已存在目标可能失败：降级两段式（移除旧正本再改名）
	push_warning("SaveManager: rename 直接覆盖失败（错误码 %d），降级 remove+rename" % rename_err)
	var remove_err: Error = dir.remove(SAVE_PATH)
	if remove_err != OK and has_save():
		return remove_err
	return dir.rename(TEMP_PATH, SAVE_PATH)

func _ResolveMode() -> String:
	## 解析运行模式：优先取 GameConfig 自动加载单例；不在树内或单例缺失时
	## 回退 demo（测试/gdUnit 环境无 autoload 的防御口径——批 1 实测结论）
	## 参数：无
	## 返回："demo" 或 "full"
	if not is_inside_tree():
		return "demo"
	var game_config: Node = get_node_or_null("/root/GameConfig")
	if game_config == null:
		return "demo"
	return "demo" if game_config.is_demo_mode() else "full"
