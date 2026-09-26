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
## 热重载用例的 cfg_main 原文缓存（R5-10 最小加固：after 兜底还原——用例
## 中途断言失败时防止磁盘留脏，代价仅一次文件写）
var _original_cfg_text: String = ""
## 热重载用例的 map_m1 原文缓存（W4-11 同口径兜底还原）
var _original_map_text: String = ""

func after() -> void:
	## 套件后置：热重载用例兜底还原（原文缓存非空 = 用例中断未还原）
	## 参数：无
	## 返回：无
	if not _original_cfg_text.is_empty():
		var restorer: FileAccess = FileAccess.open("res://data/core/cfg_main.tres",
				FileAccess.WRITE)
		restorer.store_string(_original_cfg_text)
		restorer.close()
		_original_cfg_text = ""
	if not _original_map_text.is_empty():
		var map_restorer: FileAccess = FileAccess.open(
				"res://data/map/maps/map_m1_village_mine.tres", FileAccess.WRITE)
		map_restorer.store_string(_original_map_text)
		map_restorer.close()
		_original_map_text = ""

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
	var cfg: Variant = _game_data.get_record(CoreConfig.CFG_MAIN_ID)
	assert_object(cfg).is_not_null()
	assert_bool(cfg is CoreConfig).is_true()
	var naming: Variant = _game_data.get_record(&"naming_registry")
	assert_object(naming).is_not_null()
	assert_bool(naming is NamingRegistry).is_true()

func test_id_index_lookup() -> void:
	## id 索引可取：命中返回记录；未知 id 返回 null
	var cfg: CoreConfig = _game_data.get_record(CoreConfig.CFG_MAIN_ID)
	assert_str(String(cfg.id)).is_equal("cfg_main")
	assert_object(_game_data.get_record(&"no_such_id")).is_null()

func test_filename_matches_id() -> void:
	## 文件名==id 约束：资源路径 stem 与索引 id 一致（cfg_main 显式 id 字段；
	## naming_registry 无 id 字段走文件名回退）
	for record_id: StringName in [CoreConfig.CFG_MAIN_ID, &"naming_registry"]:
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

func test_w411_reload_map_domain_updates_values_and_keeps_instance() -> void:
	## W4-11（2026-09-26 审计）：map/maps 域热重载用例（复制 core 域模式）——
	## 改盘 base_expedition_days → reload_domain(map/maps) → 内存值更新 +
	## 旧实例同址刷新（take_over）；还原磁盘 → 再 reload → 值还原。after 兜底还原
	var map_path: String = "res://data/map/maps/map_m1_village_mine.tres"
	_original_map_text = FileAccess.open(map_path, FileAccess.READ).get_as_text()
	var before: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	assert_int(before.base_expedition_days).is_equal(1)
	# ①改盘：探针字段 1 → 2 写回
	var probe_line: String = "base_expedition_days = 1"
	var mutated_line: String = "base_expedition_days = 2"
	assert_bool(_original_map_text.contains(probe_line)).is_true()
	DirAccess.copy_absolute(map_path, "user://map_m1_backup.tres")
	var writer: FileAccess = FileAccess.open(map_path, FileAccess.WRITE)
	writer.store_string(_original_map_text.replace(probe_line, mutated_line))
	writer.close()
	# ②热重载：内存值更新 + 同址刷新（引用不撕裂）
	_game_data.reload_domain(&"map/maps")
	var reloaded: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	assert_int(reloaded.base_expedition_days).is_equal(2)
	assert_object(reloaded).is_same(before) \
			.override_failure_message("map 域热重载须同址刷新旧引用——实例被替换即撕裂")
	assert_int(_game_data.get_domain(&"map/maps").size()).is_equal(1)
	assert_int(_game_data.issues.size()).is_equal(0)
	# ③还原：盘还原 → 再 reload → 值还原且实例仍同址
	var restorer: FileAccess = FileAccess.open(map_path, FileAccess.WRITE)
	restorer.store_string(_original_map_text)
	restorer.close()
	_game_data.reload_domain(&"map/maps")
	assert_int((_game_data.get_record(&"map_m1_village_mine") as ExploreMapDef)
			.base_expedition_days).is_equal(1)
	assert_object(_game_data.get_record(&"map_m1_village_mine")).is_same(before)
	DirAccess.remove_absolute("user://map_m1_backup.tres")
	_original_map_text = ""

## 全量计数断言占位见同目录 test_data_full_count_placeholder.gd
## （gdUnit4 无单测级 skip，占位断言独立成套件用套件级 do_skip 标记）

func test_issues_cleared_on_initialize_and_rescan() -> void:
	## issues 清理（S5-6）：initialize_data / reload_domain(rescan) 开头清空
	## issues——重复扫描不累积旧问题记录
	_game_data.issues.append("stale issue from previous scan")
	_game_data.initialize_data()
	assert_int(_game_data.issues.size()).is_equal(0)
	# rescan 路径：塞入假记录后热重载单域 → 清空
	_game_data.issues.append("stale issue before rescan")
	_game_data.reload_domain(&"core")
	assert_int(_game_data.issues.size()).is_equal(0)

func test_hot_reload_takes_over_cache_and_updates_values() -> void:
	## 热重载闭环（R4-01+02 集成锁）：改磁盘 cfg_main 内容 → reload_domain(core)
	## → 内存值变更（IGNORE+take_over_path 生效）；还原磁盘 → 再 reload → 还原。
	## 隔离：原文缓存于成员，after_test 兜底还原（用例中断不留脏文件）。
	var cfg_path: String = ProjectSettings.globalize_path("res://data/core/cfg_main.tres")
	_original_cfg_text = FileAccess.open("res://data/core/cfg_main.tres",
			FileAccess.READ).get_as_text()
	var before: CoreConfig = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var original_day: int = 0
	# 取一个非护栏字段做探针（crit_success_line_min 不在 V-B2 锚定集——仅本测试改）
	original_day = before.crit_success_line_min
	# ①改盘：探针字段值 +1 后写回
	var probe_line: String = "crit_success_line_min = %d" % original_day
	var mutated_line: String = "crit_success_line_min = %d" % (original_day + 1)
	assert_bool(_original_cfg_text.contains(probe_line)).is_true()
	DirAccess.copy_absolute("res://data/core/cfg_main.tres", "user://cfg_main_backup.tres")
	var mutated: String = _original_cfg_text.replace(probe_line, mutated_line)
	var writer: FileAccess = FileAccess.open("res://data/core/cfg_main.tres", FileAccess.WRITE)
	writer.store_string(mutated)
	writer.close()
	# ②热重载：内存值更新 + 旧实例引用同址刷新（take_over_path 不撕裂）
	_game_data.reload_domain(&"core")
	var reloaded: CoreConfig = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	assert_int(reloaded.crit_success_line_min).is_equal(original_day + 1)
	assert_object(reloaded).is_same(before) \
			.override_failure_message("热重载须同址刷新旧引用（take_over_path）——实例被替换即撕裂")
	# ③还原：盘还原 → 再 reload → 值还原且实例仍同址
	var restorer: FileAccess = FileAccess.open("res://data/core/cfg_main.tres", FileAccess.WRITE)
	restorer.store_string(_original_cfg_text)
	restorer.close()
	_game_data.reload_domain(&"core")
	assert_int((_game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig)
			.crit_success_line_min).is_equal(original_day)
	assert_object(_game_data.get_record(CoreConfig.CFG_MAIN_ID)).is_same(before)
	DirAccess.remove_absolute("user://cfg_main_backup.tres")
	_original_cfg_text = ""

func test_game_config_shares_instance_with_game_data() -> void:
	## 实例一致性（R4-02）：GameConfig._config 与 GameData.get_record(cfg_main)
	## 同一 CoreConfig 实例（REUSE 共享——热重载后经 take_over_path 仍同址）
	var game_config: Node = get_tree().root.get_node_or_null("GameConfig")
	if game_config == null:
		push_warning("test: GameConfig autoload 不在树（CI 变体）——跳过实例断言")
		return
	assert_object(game_config._config).is_not_null()
	assert_object(game_config._config) \
			.is_same(_game_data.get_record(CoreConfig.CFG_MAIN_ID)) \
			.override_failure_message("GameConfig 与 GameData 的 cfg_main 须共享同一实例")
