## SaveManager 存档管理器单元测试（M0 批 3，事务类——失败即阻塞级）
## 覆盖：往返一致、出征锁（锁时跳过/解锁可写）、SavePoint 恰四值、
## 损坏容错（坏 JSON 不崩+信号）、schema_version 不识别拒载、has_save 翻转。
## 隔离：每用例 before/after 清理 user://saves/（防用例间与真实存档互染；
## user:// 在 headless 下指向本机 appdata，务必清理）。
## 说明：gdUnit CI 运行器不注册 autoload，故实例化真实脚本节点；
## _ResolveMode 在无 autoload 环境回退 demo（设计内防御）。
extends GdUnitTestSuite

## SaveManager 自动加载脚本路径
const SAVE_MANAGER_SCRIPT: String = "res://scripts/autoload/save_manager.gd"

## 存档目录（与 SaveManager 常量一致，用于清理）
const SAVE_DIR: String = "user://saves"
const SAVE_PATH: String = "user://saves/main_save.json"

## 套件级 SaveManager 实例
var _save_manager: Node

func before_test() -> void:
	## 用例级前置（gdUnit 钩子：每测试用例前调用——隔离关键，before() 是套件级
	## 只跑一次，曾致文件/current 跨用例残留）：清目录+新建实例
	## 参数：无
	## 返回：无
	_CleanSaveDir()
	_save_manager = load(SAVE_MANAGER_SCRIPT).new()
	add_child(_save_manager)

func after_test() -> void:
	## 用例级后置：手动释放实例（auto_free 释放晚于 orphan 检测、曾报 7 orphans）
	## 并清理存档目录（不留残留、不互染真实存档）
	## 参数：无
	## 返回：无
	if is_instance_valid(_save_manager):
		_save_manager.free()
	_CleanSaveDir()

func _CleanSaveDir() -> void:
	## 清理 user://saves/ 全部文件并移除空目录（正本/tmp/残留）
	## 参数：无
	## 返回：无
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while not entry_name.is_empty():
		if not dir.current_is_dir():
			dir.remove(entry_name)
		entry_name = dir.get_next()
	dir.list_dir_end()
	# 删除空的 saves 目录本身（DirAccess.remove 对空目录有效；父目录视角相对名）
	var parent: DirAccess = DirAccess.open("user://")
	if parent != null and parent.dir_exists("saves"):
		parent.remove("saves")

func _ReadSaveText() -> String:
	## 读取存档正本文本（用例内比对用）
	## 参数：无
	## 返回：文件内容；不存在返回空串
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text

func _WriteRawSave(text: String) -> void:
	## 直接写存档正本（损坏注入用，绕过 SaveManager）
	## 参数 text：原始文本
	## 返回：无
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func test_roundtrip_consistency() -> void:
	## 往返一致：new_game→改字段→autosave→置空 current→load_game→逐字段相等
	var save: SaveData = _save_manager.new_game()
	save.game_day = 42
	save.scene_id = &"battle_m1_01"
	save.payload["quest"] = {"accepted": ["q_lost_miner_keepsake"], "day_issued": 7}
	assert_int(_save_manager.autosave(SaveData.SavePoint.RETURN_SETTLED)).is_equal(OK)
	_save_manager.current = null
	var loaded: SaveData = _save_manager.load_game()
	assert_object(loaded).is_not_null()
	assert_int(loaded.schema_version).is_equal(1)
	assert_int(loaded.save_point).is_equal(SaveData.SavePoint.RETURN_SETTLED)
	assert_int(loaded.game_day).is_equal(42)
	assert_str(loaded.mode).is_equal("demo")
	assert_str(String(loaded.scene_id)).is_equal("battle_m1_01")
	assert_int(loaded.saved_unix_time).is_greater(0)
	assert_bool(loaded.payload.has("quest")).is_true()
	# JSON 数字桥口径：parse 后嵌套 Dictionary 内数字为 float，断言侧显式 int 化
	assert_int(int(loaded.payload["quest"]["day_issued"])).is_equal(7)
	# current 已更新为载入实例
	assert_object(_save_manager.current).is_same(loaded)

func test_expedition_lock_blocks_autosave() -> void:
	## 出征锁：锁生效时 autosave 跳过（返回 OK、文件不变）；解锁后可写
	var save: SaveData = _save_manager.new_game()
	save.game_day = 5
	assert_int(_save_manager.autosave(SaveData.SavePoint.DAY_END)).is_equal(OK)
	var baseline: String = _ReadSaveText()
	assert_str(baseline).is_not_empty()
	_save_manager.set_expedition_lock(true)
	save.game_day = 6
	assert_int(_save_manager.autosave(SaveData.SavePoint.DAY_END)).is_equal(OK)
	assert_str(_ReadSaveText()).is_equal(baseline)
	# 解锁后可写且内容更新
	_save_manager.set_expedition_lock(false)
	save.game_day = 7
	assert_int(_save_manager.autosave(SaveData.SavePoint.DAY_END)).is_equal(OK)
	var unlocked: String = _ReadSaveText()
	assert_str(unlocked).is_not_equal(baseline)

func test_save_point_enum_has_four_values() -> void:
	## SavePoint 枚举恰四值（#26 定稿四时点）
	assert_int(SaveData.SavePoint.size()).is_equal(4)
	assert_int(SaveData.SavePoint.DAY_END).is_equal(0)
	assert_int(SaveData.SavePoint.RETURN_SETTLED).is_equal(1)
	assert_int(SaveData.SavePoint.FACILITY_UPGRADED).is_equal(2)
	assert_int(SaveData.SavePoint.RECRUIT_DONE).is_equal(3)

func test_corrupt_json_tolerated() -> void:
	## 损坏容错：坏 JSON→load_game 返回 null + save_corrupt 信号，进程不崩
	_WriteRawSave("{ broken json !!!")
	var corrupt_reasons: Array[String] = []
	var callback: Callable = func(reason: String) -> void: corrupt_reasons.append(reason)
	_save_manager.save_corrupt.connect(callback)
	var loaded: SaveData = _save_manager.load_game()
	_save_manager.save_corrupt.disconnect(callback)
	assert_object(loaded).is_null()
	assert_int(corrupt_reasons.size()).is_equal(1)
	assert_str(corrupt_reasons[0]).is_not_empty()
	# current 未被污染（仍为 null）
	assert_object(_save_manager.current).is_null()

func test_unsupported_schema_version_rejected() -> void:
	## schema_version 不识别（999）→拒载 + save_corrupt 信号含版本信息
	_WriteRawSave("{\"schema_version\": 999, \"save_point\": 0, \"game_day\": 1, \"mode\": \"demo\", \"scene_id\": \"guild_shell\", \"saved_unix_time\": 0, \"payload\": {}}")
	var corrupt_reasons: Array[String] = []
	var callback: Callable = func(reason: String) -> void: corrupt_reasons.append(reason)
	_save_manager.save_corrupt.connect(callback)
	var loaded: SaveData = _save_manager.load_game()
	_save_manager.save_corrupt.disconnect(callback)
	assert_object(loaded).is_null()
	assert_int(corrupt_reasons.size()).is_equal(1)
	assert_str(corrupt_reasons[0]).contains("schema_version")

func test_has_save_flips() -> void:
	## has_save 状态翻转：无→写入后有→删除后无
	assert_bool(_save_manager.has_save()).is_false()
	var save: SaveData = _save_manager.new_game()
	assert_int(_save_manager.autosave(SaveData.SavePoint.RECRUIT_DONE)).is_equal(OK)
	assert_bool(_save_manager.has_save()).is_true()
	DirAccess.remove_absolute(SAVE_PATH)
	assert_bool(_save_manager.has_save()).is_false()

func test_save_written_signal_and_overwrite() -> void:
	## save_written 信号带时点；二次 autosave 覆盖正本（rename 替换链路）
	var save: SaveData = _save_manager.new_game()
	var written_points: Array[int] = []
	var callback: Callable = func(point: SaveData.SavePoint) -> void: written_points.append(point)
	_save_manager.save_written.connect(callback)
	save.game_day = 1
	assert_int(_save_manager.autosave(SaveData.SavePoint.FACILITY_UPGRADED)).is_equal(OK)
	var first_text: String = _ReadSaveText()
	save.game_day = 2
	assert_int(_save_manager.autosave(SaveData.SavePoint.RECRUIT_DONE)).is_equal(OK)
	_save_manager.save_written.disconnect(callback)
	assert_int(written_points.size()).is_equal(2)
	assert_int(written_points[0]).is_equal(SaveData.SavePoint.FACILITY_UPGRADED)
	assert_int(written_points[1]).is_equal(SaveData.SavePoint.RECRUIT_DONE)
	assert_str(_ReadSaveText()).is_not_equal(first_text)
	# 覆盖后重读仍是最新值
	var loaded: SaveData = _save_manager.load_game()
	assert_int(loaded.game_day).is_equal(2)
