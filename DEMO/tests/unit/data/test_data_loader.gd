## GameData 数据加载器单元测试（M0 批 1）
## 覆盖：core 域扫描发现、id 索引可取、文件名==id 约束、
## DOMAIN_SCHEMA 类型匹配、全量计数占位（批 2 激活，见独立占位套件）。
## 说明：gdUnit CI 运行器（-s SceneTree 模式）不注册 autoload 单例，
## 故测试内实例化真实脚本节点（add_child 触发 _ready 走完整加载链路，
## 与 autoload 行为等价）。
extends GdUnitTestSuite

## GameData 自动加载脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 实例（before 建树、after 摘除）
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData 脚本节点并显式初始化（扫描全数据域）
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

func _is_script_allowed(record: Resource, allowed_classes: Array) -> bool:
	## 沿基类链校验资源脚本是否在白名单内（与 GameData._IsScriptAllowed 同口径的测试侧复刻）
	## 参数 record：待校验资源；allowed_classes：白名单（元素为 Script）
	## 返回：true = 白名单内（含基类匹配）
	var script: Script = record.get_script()
	while script != null:
		if allowed_classes.has(script):
			return true
		script = script.get_base_script()
	return false

func test_domain_scan_discovers_core_records() -> void:
	## 域扫描应发现 cfg_main（CoreConfig）与 naming_registry（NamingRegistry）
	var core_domain: Array = _game_data.get_domain(&"core")
	assert_int(core_domain.size()).is_equal(2)
	var cfg: Variant = _game_data.get_record(&"cfg_main")
	assert_object(cfg).is_not_null()
	assert_bool(cfg is CoreConfig).is_true()
	var naming: Variant = _game_data.get_record(&"naming_registry")
	assert_object(naming).is_not_null()
	assert_bool(naming is NamingRegistry).is_true()

func test_id_index_lookup() -> void:
	## id 索引可取：命中返回记录；未知 id 返回 null
	var cfg: CoreConfig = _game_data.get_record(&"cfg_main")
	assert_str(String(cfg.id)).is_equal("cfg_main")
	assert_object(_game_data.get_record(&"no_such_id")).is_null()

func test_filename_matches_id() -> void:
	## 文件名==id 约束：资源路径 stem 与索引 id 一致（cfg_main 显式 id 字段；
	## naming_registry 无 id 字段走文件名回退）
	for record_id: StringName in [&"cfg_main", &"naming_registry"]:
		var path: String = _game_data.get_resource_path(record_id)
		assert_str(path.get_file().get_basename()).is_equal(String(record_id))

func test_domain_schema_type_match() -> void:
	## DOMAIN_SCHEMA 类型匹配：全域记录脚本均在所属域白名单内，且无校验问题
	var schema: Dictionary = _game_data.DOMAIN_SCHEMA
	for domain: StringName in schema:
		var allowed_classes: Array = schema[domain]
		for record: Resource in _game_data.get_domain(domain):
			assert_bool(_is_script_allowed(record, allowed_classes)) \
					.override_failure_message("域 '%s' 记录类型不在白名单" % domain).is_true()
	assert_int(_game_data.issues.size()).is_equal(0)

func test_get_records_of_class() -> void:
	## 按类查询：CoreConfig 全库恰 1 条；NamingRegistry 全库恰 1 条
	assert_int(_game_data.get_records_of_class(CoreConfig).size()).is_equal(1)
	assert_int(_game_data.get_records_of_class(NamingRegistry).size()).is_equal(1)

func test_reload_domain() -> void:
	## 域热重载：重扫后索引仍完整且无问题记录，data_reloaded 信号以正确域键发出
	var emitted_domains: Array[StringName] = []
	var callback: Callable = func(domain: StringName) -> void: emitted_domains.append(domain)
	_game_data.data_reloaded.connect(callback)
	_game_data.reload_domain(&"core")
	_game_data.data_reloaded.disconnect(callback)
	assert_int(emitted_domains.size()).is_equal(1)
	assert_str(String(emitted_domains[0])).is_equal("core")
	assert_int(_game_data.get_domain(&"core").size()).is_equal(2)
	assert_int(_game_data.issues.size()).is_equal(0)

## 全量计数断言占位见同目录 test_data_full_count_placeholder.gd
## （gdUnit4 无单测级 skip，占位断言独立成套件用套件级 do_skip 标记）
