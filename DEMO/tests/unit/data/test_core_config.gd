## 总控配置（GameConfig + cfg_main.tres）单元测试（M0 批 1）
## 覆盖：DEMO 模式、17 案定值抽查（视野/暗门半径/难度五档/大成功下限）、
## 系统启用清单标志、SYSTEM_KEYS 对 enabled_systems 的双向覆盖。
## 说明：gdUnit CI 运行器（-s SceneTree 模式）不注册 autoload 单例，
## 故测试内实例化真实 GameConfig 脚本节点（add_child 触发 _ready 加载链路，
## 与 autoload 行为等价）；SYSTEM_KEYS 为脚本常量，直接 preload 读取。
extends GdUnitTestSuite

## GameConfig 自动加载脚本路径
const GAME_CONFIG_SCRIPT: String = "res://scripts/autoload/game_config.gd"

## 总控配置资源路径（直读数据表用）
const CFG_MAIN_PATH: String = "res://data/core/cfg_main.tres"

## 套件级 GameConfig 实例（before 建树、after 摘除）

func _game_data() -> CoreConfig:
	## 总控配置直读（R4-08：数值参数经 GameData.get_record(CFG_MAIN_ID)）
	## 参数：无
	## 返回：CoreConfig（树上有 GameData autoload 用之；否则手动实例）
	var game_data: Node = get_tree().root.get_node_or_null("GameData")
	if game_data != null:
		return game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var manual: Node = load("res://scripts/autoload/game_data.gd").new()
	manual.initialize_data()
	var cfg: CoreConfig = manual.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	manual.free()
	return cfg
var _game_config: Node

func before() -> void:
	## 套件前置：实例化 GameConfig 脚本节点并加入树（触发 _ready 加载 cfg_main）
	## 参数：无
	## 返回：无
	_game_config = auto_free(load(GAME_CONFIG_SCRIPT).new())
	add_child(_game_config)

func after() -> void:
	## 套件后置：从树摘除 GameConfig 实例（auto_free 负责释放）
	## 参数：无
	## 返回：无
	if is_instance_valid(_game_config) and _game_config.get_parent() == self:
		remove_child(_game_config)

func test_demo_mode() -> void:
	## 运行模式应为 DEMO
	assert_bool(_game_config.is_demo_mode()).is_true()

func test_vision_radius() -> void:
	## 探索视野半径 R=3（案 17 §3.10/§3.11 #17）
	assert_int(_game_data().vision_radius).is_equal(3)

func test_secret_door_trigger_radius() -> void:
	## 暗门检定触发半径=2（案 17 §3.10/§3.11 #17）
	assert_int(_game_data().secret_door_trigger_radius).is_equal(2)

func test_difficulty_tiers() -> void:
	## 难度五档判定线 5/8/11/14/17（案 17 §3.3）
	assert_int(_game_data().difficulty_tiers["极易"]).is_equal(5)
	assert_int(_game_data().difficulty_tiers["容易"]).is_equal(8)
	assert_int(_game_data().difficulty_tiers["普通"]).is_equal(11)
	assert_int(_game_data().difficulty_tiers["困难"]).is_equal(14)
	assert_int(_game_data().difficulty_tiers["极难"]).is_equal(17)

func test_crit_success_line_min() -> void:
	## 大成功判定线下限=16（案 17 §3.3）
	assert_int(_game_data().crit_success_line_min).is_equal(16)

func test_system_enabled_flags() -> void:
	## 系统启用标志：battle 真 / stress 假（案 16 启用清单）
	assert_bool(_game_config.is_system_enabled(&"battle")).is_true()
	assert_bool(_game_config.is_system_enabled(&"stress")).is_false()

func test_system_keys_cover_enabled_systems() -> void:
	## SYSTEM_KEYS 与 enabled_systems 双向覆盖（合法键枚举无遗漏、无越界键）
	var game_config_script: GDScript = load(GAME_CONFIG_SCRIPT)
	var cfg: CoreConfig = load(CFG_MAIN_PATH)
	var system_keys: Array = game_config_script.SYSTEM_KEYS
	for enabled_key: StringName in cfg.enabled_systems:
		assert_bool(system_keys.has(enabled_key)) \
				.override_failure_message("enabled_systems 键 '%s' 不在 SYSTEM_KEYS" % enabled_key).is_true()
	for system_key: StringName in system_keys:
		assert_bool(cfg.enabled_systems.has(system_key)) \
				.override_failure_message("SYSTEM_KEYS 键 '%s' 未在 enabled_systems 定义" % system_key).is_true()
