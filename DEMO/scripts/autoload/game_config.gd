## 总控配置加载器（自动加载单例：GameConfig）
## 职责：_ready 时加载 data/core/cfg_main.tres（ResourceLoader 缓存共享），
## 对外提供运行模式 / 系统启用 / 参数读取 / 难度档位查询与热重载接口。
## 数据来源：CoreConfig（res://scripts/data_defs/core_config.gd）；
## 数值权威见案 16 / 案 17 §3.1/§3.3/§3.10/§3.11。
## 接口契约：缺键行为——is_system_enabled 缺键按 false 并 push_warning；
## get_param 缺键返回 null 并 push_warning；get_difficulty_tier 缺档返回 -1。
extends Node

## 配置热重载完成信号（reload() 成功后发出，监听方应重新取参数）
signal config_reloaded

## 总控配置资源路径（core 域固定主配置）
const CONFIG_PATH: String = "res://data/core/cfg_main.tres"

## enabled_systems 合法系统键全集（13 真 + 9 假，案 16 启用清单）
const SYSTEM_KEYS: Array[StringName] = [
	# DEMO 启用（真键 13）
	&"calendar",
	&"guild_facility",
	&"economy",
	&"adventurer",
	&"quest",
	&"map_explore",
	&"event_check",
	&"battle",
	&"class_skill",
	&"status",
	&"world_scene",
	&"ui_config",
	&"auto_save",
	# DEMO 禁用（假键 9）
	&"stress",
	&"second_class",
	&"shop",
	&"craft_chain",
	&"quest_noncombat",
	&"event_exit_d",
	&"hidden_content",
	&"npc_place",
	&"story",
]

## 已加载的总控配置（缓存共享实例）
var _config: CoreConfig

func _ready() -> void:
	## 引擎回调：启动时加载总控配置
	_LoadConfig(false)

func _LoadConfig(force: bool) -> void:
	## 加载总控配置资源
	## 参数 force：true = 强制从磁盘重读并替换缓存（热重载）；false = 走缓存共享
	## 返回：无（失败时 push_error 并保持 _config 为 null）
	var cache_mode: int = ResourceLoader.CACHE_MODE_REUSE
	if force:
		cache_mode = ResourceLoader.CACHE_MODE_REPLACE
	_config = ResourceLoader.load(CONFIG_PATH, "", cache_mode) as CoreConfig
	if _config == null:
		push_error("GameConfig: 无法加载总控配置 %s" % CONFIG_PATH)

func is_demo_mode() -> bool:
	## 查询当前是否 DEMO 运行模式
	## 参数：无
	## 返回：true = DEMO 模式；配置缺失时返回 false
	return _config != null and _config.mode == CoreConfig.Mode.DEMO

func is_system_enabled(sys: StringName) -> bool:
	## 查询系统是否启用（缺键按 false 处理并 push_warning）
	## 参数 sys：系统键（合法键见 SYSTEM_KEYS）
	## 返回：true = 启用；false = 显式禁用或键缺失
	if _config == null:
		return false
	if not _config.enabled_systems.has(sys):
		push_warning("GameConfig: 系统键 '%s' 未在 enabled_systems 定义，按 false 处理" % sys)
		return false
	return _config.enabled_systems[sys]

func get_param(param_name: StringName) -> Variant:
	## 按字段名读取总控配置参数（透传 CoreConfig 任意导出字段）
	## 参数 param_name：CoreConfig 的字段名（如 &"vision_radius"）
	## 返回：字段值；配置缺失或字段不存在时返回 null（后者附 push_warning）
	if _config == null:
		return null
	if not (param_name in _config):
		push_warning("GameConfig: 总控配置无字段 '%s'" % param_name)
		return null
	return _config.get(param_name)

func get_difficulty_tier(tier: StringName) -> int:
	## 查询难度档位的判定线
	## 参数 tier：档名（极易/容易/普通/困难/极难）
	## 返回：判定线 int；配置缺失或档名不存在时返回 -1（后者附 push_warning）
	if _config == null:
		return -1
	var tier_key: String = String(tier)
	if not _config.difficulty_tiers.has(tier_key):
		push_warning("GameConfig: 难度档 '%s' 未定义" % tier_key)
		return -1
	return _config.difficulty_tiers[tier_key]

func reload() -> void:
	## 热重载总控配置（强制从磁盘重读并替换共享缓存），完成后发出 config_reloaded
	## 参数：无
	## 返回：无
	_LoadConfig(true)
	config_reloaded.emit()
