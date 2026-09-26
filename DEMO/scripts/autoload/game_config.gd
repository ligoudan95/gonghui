## 总控配置加载器（自动加载单例：GameConfig）
## 职责：_ready 时加载 data/core/cfg_main.tres（ResourceLoader 缓存共享），
## 对外提供运行模式 / 系统启用 / 参数读取 / 难度档位查询与热重载接口。
## 数据来源：CoreConfig（res://scripts/data_defs/core_config.gd）；
## 数值权威见案 16 / 案 17 §3.1/§3.3/§3.10/§3.11。
## 接口契约：缺键行为——is_system_enabled 缺键按 false 并 push_warning
## （R4-08：get_param/get_difficulty_tier 已删——数值直读 GameData.get_record
## (CoreConfig.CFG_MAIN_ID)，难度档读 cfg.difficulty_tiers）。
## 职责收窄口径（C-5 + R4-08 收紧）：**本单例专用 = 系统启停 / 难度档**；
## 数值参数的合法读取口径 = 经 GameData
## get_record(CoreConfig.CFG_MAIN_ID) 取 CoreConfig 实例后按字段直读
## （各系统 cfg 注入消费——铁律④合向），不在本单例扩数值镜像接口。
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

func _LoadConfig(force: bool) -> bool:
	## 加载总控配置资源
	## 参数 force：true = 强制从磁盘重读（热重载——R4-01 同址刷新：磁盘新值
	## 逐属性拷入 _config 旧壳，_config 对象恒不变；与 GameData.reload_domain
	## 同方案，两单例的 cfg 引用恒同实例）；false = 走缓存共享
	## 返回：true = 加载成功；false = 失败（push_error 并保持 _config 现状——
	## W4-09：调用方凭返回值决定是否发 config_reloaded，失败不发）
	var cache_mode: int = ResourceLoader.CACHE_MODE_REUSE
	if force:
		cache_mode = ResourceLoader.CACHE_MODE_IGNORE
	var fresh: CoreConfig = ResourceLoader.load(CONFIG_PATH, "", cache_mode) as CoreConfig
	if fresh == null:
		push_error("GameConfig: 无法加载总控配置 %s" % CONFIG_PATH)
		return false
	if force and _config != null:
		CoreConfig.copy_props(fresh, _config)
	else:
		_config = fresh
	return true

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

func reload() -> void:
	## 热重载总控配置（强制从磁盘重读并替换共享缓存），完成后发出 config_reloaded；
	## W4-09：加载失败不发信号（监听方重取参数会拿到旧值——失败时保持旧配置
	## 并 push_error，调用方无须额外处理）
	## 参数：无
	## 返回：无
	if _LoadConfig(true):
		config_reloaded.emit()
