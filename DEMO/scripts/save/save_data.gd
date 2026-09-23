## 存档数据（SaveData）
## 职责：#26 最简自动存档的数据载体——运行态与磁盘 JSON 的中间层，
## to_dict/from_dict 为 JSON 序列化桥（含类型校验，异常返回 null）。
## 数据来源：M0 批 3 方案（#26 定稿四时点）；payload 为各系统快照预留
## （键=系统名，M0 空，M1+ 由 SaveManager 快照 provider 填充）。
## id 命名规范：本类为运行时资源，非数据表，无域前缀 id。
## 事务口径：磁盘写入由 SaveManager 原子写（tmp + rename）保证半写不污染正本。
class_name SaveData
extends Resource

## 自动存档时点（#26 定稿四时点：日结算/回城结算/设施升级/招募完成）
enum SavePoint {
	DAY_END,
	RETURN_SETTLED,
	FACILITY_UPGRADED,
	RECRUIT_DONE,
}

## 存档结构版本（结构变更时递增；旧版拒载走 save_corrupt）
const SCHEMA_VERSION: int = 1

## 存档结构版本
@export var schema_version: int = SCHEMA_VERSION
## 写入时点
@export var save_point: SavePoint = SavePoint.DAY_END
## 游戏内天数（新档从 1 起）
@export var game_day: int = 1
## 运行模式（demo/full）
@export var mode: String = "demo"
## 场景 id（占位：批 4 SceneManager 落地前的 StringName 字面量）
@export var scene_id: StringName = &"guild_shell"
## 写入时刻的 Unix 时间戳（秒）
@export var saved_unix_time: int = 0
## 各系统快照（键=系统名 StringName，值=该系统快照 Dictionary；M0 空）
@export var payload: Dictionary = {}

func to_dict() -> Dictionary:
	## 序列化为可 JSON 化的 Dictionary（save_point 落枚举序号）
	## 参数：无
	## 返回：含全字段的 Dictionary（String 键）
	return {
		"schema_version": schema_version,
		"save_point": save_point,
		"game_day": game_day,
		"mode": mode,
		"scene_id": String(scene_id),
		"saved_unix_time": saved_unix_time,
		"payload": payload,
	}

static func from_dict(data: Dictionary) -> SaveData:
	## 反序列化（JSON 桥）：全字段存在性与类型校验，任一异常返回 null
	## 参数 data：JSON.parse_string 产出的 Dictionary
	## 返回：SaveData；校验失败返回 null（调用方走 save_corrupt 流程）
	# 必需键齐备
	for key: String in ["schema_version", "save_point", "game_day", "mode", "scene_id", "saved_unix_time", "payload"]:
		if not data.has(key):
			return null
	# 类型校验（JSON 数字解析为 float，int 字段容错整数性 float）
	if not IsIntLike(data["schema_version"]) or not IsIntLike(data["save_point"]):
		return null
	if not IsIntLike(data["game_day"]) or not IsIntLike(data["saved_unix_time"]):
		return null
	if not (data["mode"] is String) or String(data["mode"]).is_empty():
		return null
	if not (data["scene_id"] is String):
		return null
	if not (data["payload"] is Dictionary):
		return null
	var point_value: int = int(data["save_point"])
	if point_value < 0 or point_value >= SavePoint.size():
		return null
	if int(data["game_day"]) < 1:
		return null
	# 校验通过，构建实例
	var save := SaveData.new()
	save.schema_version = int(data["schema_version"])
	save.save_point = point_value as SavePoint
	save.game_day = int(data["game_day"])
	save.mode = String(data["mode"])
	save.scene_id = StringName(String(data["scene_id"]))
	save.saved_unix_time = int(data["saved_unix_time"])
	save.payload = data["payload"]
	return save

static func IsIntLike(value: Variant) -> bool:
	## int 兼容校验：int 直过；float 须为整数值（JSON 数字桥容错）；其余拒绝
	## 参数 value：待校验值
	## 返回：true = 可安全转 int
	if value is int:
		return true
	if value is float:
		return is_equal_approx(float(int(value)), value)
	return false
