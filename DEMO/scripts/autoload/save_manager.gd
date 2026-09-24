## 存档管理器（自动加载单例：SaveManager）
## 职责：#26 最简自动存档——运行态 SaveData 的建立（new_game）、四时点自动写盘
## （autosave，出征锁跳过）、读档（load_game，损坏容错不崩）与各系统快照
## provider 的注册扩展点（M0 空 registry、机制就位）。
## 数据来源：M0 批 3 方案；存档路径 user://saves/main_save.json。
## 事务口径：原子写（盲审批 3 B-2 三段式加固）——写 tmp → 正本备份 .bak →
## tmp 回正本（成功清 .bak，失败回滚 .bak），半写/中断不污染既有存档；
## 读档对「正本缺失但 .bak 在」的崩溃窗口走兜底。
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
## 备份路径（盲审批 3 B-2 三段式 rename 的中转：正本→.bak→tmp 回正本，
## 任一步失败可回滚——防 remove+rename 两段式窗口内崩溃写坏正本）
const BAK_PATH: String = "user://saves/main_save.json.bak"

## 识别的存档结构版本（不识别则拒载走 save_corrupt）——**单源读 SaveData
## 常量**（批 D L8：原双份字面量已删，版本号只在 SaveData.SCHEMA_VERSION 一处）
const SUPPORTED_SCHEMA_VERSION: int = SaveData.SCHEMA_VERSION

## 占位场景 id：公会壳（C-4 单源：引 SaveData.SCENE_GUILD_SHELL——
## 场景名字面量不在本类重复定义）
const SCENE_GUILD_SHELL: StringName = SaveData.SCENE_GUILD_SHELL

## 运行态存档（new_game/load_game 建立前为 null）
var current: SaveData
## 最近一次解析失败原因（S5-1：load_game 统一信号文案的传递位）
var _last_parse_fail_reason: String = ""

## 出征锁（#26：出征中不自动存档；M3 出征层经 set_expedition_lock 调用）
var _expedition_lock: bool = false

## 快照 provider 注册表：系统名 -> [save_fn, restore_fn]（M0 空，机制就位）
var _snapshot_providers: Dictionary[StringName, Array] = {}

func new_game() -> SaveData:
	## 建立新档：重置运行态（game_day=1、mode 取 GameConfig、scene_id=公会壳
	## 占位）；S5-3：同步重置出征锁（新档无出征语义，防上一局的锁泄漏）
	## 参数：无
	## 返回：新建的 SaveData（同时赋给 current）
	_expedition_lock = false
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
	## 读档（S5-1 加固）：正本可读但解析/校验失败且 .bak 存在 → 兜底重试
	## .bak（正本半写/外写坏时的恢复通路；两处均败才发 save_corrupt）；
	## 正本缺失但有 .bak 同样兜底（B-2 崩溃窗口）；成功→current 更新→
	## 恢复快照→emit save_loaded；S5-3：成功路径重置出征锁（读档回到存档
	## 时点的非出征态）
	## 参数：无
	## 返回：载入的 SaveData；无文件或损坏返回 null
	if not has_save() and not FileAccess.file_exists(BAK_PATH):
		return null
	var text: String = _ReadSaveTextWithFallback()
	var fail_reason: String = "存档文件无法打开（错误码 %d）" % FileAccess.get_open_error()
	var data: SaveData = null
	if not text.is_empty():
		data = _ParseSaveText(text)
		fail_reason = _last_parse_fail_reason
	if data == null and FileAccess.file_exists(BAK_PATH):
		# 正本不可用（打不开/解析失败）→ .bak 兜底重试
		push_warning("SaveManager: 正本不可用，尝试 .bak 兜底读档")
		var bak_text: String = _ReadFileAt(BAK_PATH)
		if not bak_text.is_empty() and bak_text != text:
			data = _ParseSaveText(bak_text)
			if data == null:
				fail_reason = _last_parse_fail_reason
	if data == null:
		save_corrupt.emit(fail_reason)
		return null
	current = data
	_expedition_lock = false
	_RestoreSnapshots()
	save_loaded.emit(data)
	return data

func _ParseSaveText(text: String) -> SaveData:
	## 存档文本解析管线（S5-1 抽取）：JSON → 版本 → 字段校验；任一失败
	## 返回 null 并记录原因（不发 save_corrupt——由 load_game 统一决定
	## 是否 .bak 兜底与最终信号文案）
	## 参数 text：存档 JSON 文本
	## 返回：SaveData；解析失败返回 null
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		_last_parse_fail_reason = "JSON 解析失败"
		return null
	var version_value: Variant = parsed.get("schema_version", null)
	if not SaveData.IsIntLike(version_value) or int(version_value) != SUPPORTED_SCHEMA_VERSION:
		_last_parse_fail_reason = "schema_version 不识别（%s，支持 %d）" % [
			str(version_value), SUPPORTED_SCHEMA_VERSION]
		return null
	var data: SaveData = SaveData.from_dict(parsed)
	if data == null:
		_last_parse_fail_reason = "存档字段类型校验失败"
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
	## 原子写（B-2 三段式 + S5-1 半写链加固）：建目录→写 tmp（store 后查
	## get_error——写失败直接返回不动正本）→tmp 文本 JSON.parse_string 自校验
	## （内存损坏/序列化异常在替换正本前拦截）→正本备份 .bak→tmp 回正本→
	## 成功清 .bak；回正本失败→.bak 回滚；正本备份失败降级旧两段式
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
	# S5-1①：写入侧错误检查——store/flush 失败（磁盘满等）直接失败，正本未动
	var write_err: Error = file.get_error()
	file.close()
	if write_err != OK:
		push_error("SaveManager: tmp 写入异常（错误码 %d），中止替换" % write_err)
		DirAccess.remove_absolute(TEMP_PATH)
		return write_err
	# S5-1②：tmp 文本回读自校验——序列化产物必须是合法 JSON 才允许替换正本
	var verify: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.READ)
	if verify == null:
		return FileAccess.get_open_error()
	var verify_text: String = verify.get_as_text()
	verify.close()
	if JSON.parse_string(verify_text) == null:
		push_error("SaveManager: tmp 自校验失败（JSON 非法），中止替换——正本未动")
		DirAccess.remove_absolute(TEMP_PATH)
		return FAILED
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		DirAccess.remove_absolute(TEMP_PATH)
		return FAILED
	# ②正本 → .bak（存在旧正本才备份；失败降级两段式）
	if has_save():
		dir.remove(BAK_PATH)
		var backup_err: Error = dir.rename(SAVE_PATH, BAK_PATH)
		if backup_err != OK:
			push_warning("SaveManager: 正本备份失败（错误码 %d），降级 remove+rename" % backup_err)
			var remove_err: Error = dir.remove(SAVE_PATH)
			if remove_err != OK and has_save():
				return remove_err
			return dir.rename(TEMP_PATH, SAVE_PATH)
	# ③tmp → 正本（正本已挪走，无覆盖冲突）；成功清 .bak
	var rename_err: Error = dir.rename(TEMP_PATH, SAVE_PATH)
	if rename_err == OK:
		dir.remove(BAK_PATH)
		return OK
	# ④回滚：.bak 恢复为正本（保证正本回到上一完整版本；R4-12：残留 tmp 清除）
	push_error("SaveManager: tmp 回正本失败（错误码 %d），回滚 .bak" % rename_err)
	dir.remove(TEMP_PATH)
	dir.remove(SAVE_PATH)
	var rollback_err: Error = dir.rename(BAK_PATH, SAVE_PATH)
	if rollback_err != OK:
		push_error("SaveManager: .bak 回滚失败（错误码 %d）——正本缺失，下次读档走 .bak 兜底" % rollback_err)
	return rename_err

func _ReadSaveTextWithFallback() -> String:
	## 读正本文本；正本无法打开（缺失/占用/坏盘）且 .bak 存在时兜底读 .bak
	## （B-2：三段式中途被杀的崩溃窗口——正本已挪 .bak、tmp 未回正）
	## 参数：无
	## 返回：存档文本；两处均不可读返回空串
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: 正本无法打开（错误码 %d），尝试 .bak 兜底" % FileAccess.get_open_error())
		file = FileAccess.open(BAK_PATH, FileAccess.READ)
		if file == null:
			return ""
	var text: String = file.get_as_text()
	file.close()
	return text

func _ReadFileAt(path: String) -> String:
	## 读指定路径文本（S5-1：.bak 兜底重试的独立读取口——正本可读场景下
	## .bak 与正本内容比对去重用）
	## 参数 path：user:// 文件路径
	## 返回：文件内容；不可读返回空串
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text

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
