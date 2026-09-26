## 数据加载器（自动加载单例：GameData）
## 职责：_ready 时按 DOMAIN_SCHEMA 扫描 data/ 全域递归 .tres 资源，
## 建立 id -> record 与 id -> path 双索引及域索引；对外提供按 id / 类 / 域 /
## 资源路径映射的查询接口与域级热重载。
## 数据来源：data_defs/ 全部 Resource 类；域目录与类型白名单以案 16
## 《内容数据与配置化》配置化目录为准。
## 校验口径：重复 id / 类型域不匹配记入 issues 数组（供批 2 校验器消费），
## M0 阶段同步 push_warning。
## id 提取规则：资源含 id 字段用字段值（AssetRegistry/NamingRegistry 等无 id
## 表以文件名 stem 为索引，保证「文件名 == id」约束全域成立）。
extends Node

## 域热重载完成信号（reload_domain 成功后发出，参数为重载的域键）
signal data_reloaded(domain: StringName)

## 数据根目录
const DATA_ROOT: String = "res://data"

## 域 -> 允许的 Resource 类白名单（域即 data/ 下子目录路径；
## core 域为多类混合：总控配置 / 命名登记表 / 资源注册表）。
## 注：方案原文为 const；GDScript 常量表达式不支持类引用字面量，降为实例 var
## （只读使用约定：外部不得改写，命名保留全大写以示常量语义）。
var DOMAIN_SCHEMA: Dictionary[StringName, Array] = {
	&"core": [CoreConfig, NamingRegistry, AssetRegistry],
	&"class/classes": [ClassDef],
	&"class/skills": [SkillDef],
	&"status/stats": [StatusDef],
	&"status/mutex_groups": [MutexGroupDef],
	&"battle/enemies": [EnemyDef],
	&"battle/enemy_packs": [EnemyPackDef],
	&"battle/maps": [BattleMapDef],
	&"battle/tiles": [TileTypeDef],
	&"equip": [EquipDef],
	&"event/chains": [EventChainDef],
	&"event/nodes": [EventNodeDef],
	&"event/options": [EventOptionDef],
	&"event/singles": [SingleEventDef],
	&"event/hidden_marks": [HiddenMarkDef],
	&"quest/templates": [QuestTemplateDef],
	&"assets": [AssetRegistry],
	# ---- M3 探索层六域（map/ 五域 + world/regions）----
	&"map/maps": [ExploreMapDef],
	&"map/tiles": [ExploreTileDef],
	&"map/interact_points": [InteractPointDef],
	&"map/target_points": [TargetPointDef],
	&"map/encounter_weights": [EncounterWeightDef],
	&"world/regions": [RegionDef],
}

## id -> 资源记录 索引
var _records: Dictionary[StringName, Resource] = {}
## id -> 资源路径 索引
var _paths: Dictionary[StringName, String] = {}
## 域 -> 该域资源 id 列表 索引（内层为 Array[StringName]；
## Godot 4.7 不支持嵌套类型化集合，故内层声明为 Array，经 _GetDomainIds 类型化存取）
var _domain_ids: Dictionary[StringName, Array] = {}
## 校验问题记录（重复 id / 类型域不匹配等，供批 2 校验器消费）
var issues: Array[String] = []

func _ready() -> void:
	## 引擎回调：启动时扫描全部数据域并建索引
	## 参数：无
	## 返回：无
	initialize_data()

func initialize_data() -> void:
	## 扫描全部数据域并建三类索引（autoload _ready 与工具/测试手动加载的共用入口；
	## -s MainLoop 模式下 root.add_child 不触发 _ready，须显式调用——批 1 实测结论）
	## S5-6：入口全量重置（issues + 三类索引清空）——重复 initialize 不累积
	## 旧问题记录、不因索引残留产生「重复 id」误报
	## 参数：无
	## 返回：无
	issues.clear()
	_records.clear()
	_paths.clear()
	_domain_ids.clear()
	for domain: StringName in DOMAIN_SCHEMA:
		_ScanDomain(domain, false)

func _ScanDomain(domain: StringName, rescan: bool) -> void:
	## 扫描单个数据域：递归收集 .tres、校验类型白名单、建三类索引
	## 参数 domain：域键（DOMAIN_SCHEMA 之一）；rescan：true = 热重载（R4-01：
	## IGNORE 读盘 → **新值逐属性拷入旧实例壳**（同址刷新）→ 索引仍指旧实例——
	## 既有引用方（GameConfig._config / context.cfg 等）不换对象即可见新值；
	## S5-6：rescan 同时清空 issues——重扫即全量重建问题列表，不累积）
	## 返回：无（问题记入 issues 并 push_warning；未知域 push_warning 后跳过）
	if not DOMAIN_SCHEMA.has(domain):
		push_warning("GameData: 未知数据域 '%s'，跳过扫描" % domain)
		return
	if rescan:
		issues.clear()
	# 热重载容器：保留旧实例引用（新值拷入旧壳）；本域旧索引键全清
	# （磁盘上已删除的记录自索引消失），域 id 列表重建
	var kept_records: Dictionary = {}
	if rescan:
		for old_id: StringName in _GetDomainIds(domain):
			kept_records[old_id] = _records[old_id]
			_records.erase(old_id)
			_paths.erase(old_id)
		var cleared_ids: Array[StringName] = []
		_domain_ids[domain] = cleared_ids
	var allowed_classes: Array = DOMAIN_SCHEMA[domain]
	var domain_ids: Array[StringName] = _GetDomainIds(domain)
	for file_path: String in _CollectTresFiles(DATA_ROOT + "/" + domain):
		# S5-5/R4-01：常规扫描 REUSE（core 域 cfg 与 GameConfig 共享实例）；
		# 热重载走 IGNORE——绕缓存直读磁盘新内容（旧实例仍在缓存槽，拷贝后弃新壳）
		var cache_mode: int = ResourceLoader.CACHE_MODE_IGNORE if rescan \
				else ResourceLoader.CACHE_MODE_REUSE
		var record: Resource = ResourceLoader.load(file_path, "", cache_mode)
		if record == null:
			_RecordIssue("资源加载失败：%s" % file_path)
			continue
		if not _IsScriptAllowed(record, allowed_classes):
			_RecordIssue("类型域不匹配：%s（实际类 %s，域 '%s' 白名单外）" % [
				file_path,
				record.get_script().resource_path,
				domain,
			])
			continue
		var record_id: StringName = _ExtractRecordId(record, file_path)
		if rescan and kept_records.has(record_id):
			# R4-01 同址刷新：磁盘新值拷入旧实例（嵌套子资源引用一并替换），
			# 索引继续指旧实例——所有旧引用同对象见新值，不撕裂
			var old_record: Resource = kept_records[record_id]
			CoreConfig.copy_props(record, old_record)
			record = old_record
			_records[record_id] = record
			_paths[record_id] = file_path
			domain_ids.append(record_id)
			continue
		if _records.has(record_id):
			_RecordIssue("重复 id '%s'：%s 与 %s 冲突" % [record_id, _paths[record_id], file_path])
			continue
		_records[record_id] = record
		_paths[record_id] = file_path
		domain_ids.append(record_id)


func _CollectTresFiles(dir_path: String) -> PackedStringArray:
	## 递归收集目录下全部 .tres 文件路径
	## 参数 dir_path：目录 res:// 路径
	## 返回：.tres 文件路径列表（目录不存在时为空）
	var result: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while not entry_name.is_empty():
		# 跳过编辑器隐藏目录（.godot 等）与备份文件
		if dir.current_is_dir() and not entry_name.begins_with("."):
			result.append_array(_CollectTresFiles(dir_path.path_join(entry_name)))
		elif entry_name.ends_with(".tres"):
			result.append(dir_path.path_join(entry_name))
		entry_name = dir.get_next()
	dir.list_dir_end()
	return result

func _GetDomainIds(domain: StringName) -> Array[StringName]:
	## 取域 id 列表（缺失时建空表），保证内层数组始终为 Array[StringName] 类型
	## 参数 domain：域键
	## 返回：该域的资源 id 列表（可变引用，直接追加即写入索引）
	if not _domain_ids.has(domain):
		var fresh_ids: Array[StringName] = []
		_domain_ids[domain] = fresh_ids
	return _domain_ids[domain]

func _IsScriptAllowed(record: Resource, allowed_classes: Array) -> bool:
	## 校验资源脚本是否在白名单内（沿基类链向上查，兼容未来子类化）
	## 参数 record：待校验资源；allowed_classes：白名单（元素为 Script）
	## 返回：true = 白名单内（含基类匹配）
	var script: Script = record.get_script()
	while script != null:
		if allowed_classes.has(script):
			return true
		script = script.get_base_script()
	return false

func _ExtractRecordId(record: Resource, file_path: String) -> StringName:
	## 提取资源索引 id：有 id 字段用字段值，无 id 字段回退文件名 stem
	## 参数 record：已加载资源；file_path：资源路径
	## 返回：索引 id（保证「文件名 == id」约束成立）
	if "id" in record:
		var field_value: Variant = record.get("id")
		if field_value is StringName:
			return field_value
		if field_value is String:
			return StringName(field_value)
	return StringName(file_path.get_file().get_basename())

func _RecordIssue(message: String) -> void:
	## 记录一条校验问题（issues 数组 + push_warning）
	## 参数 message：问题描述
	## 返回：无
	issues.append(message)
	push_warning("GameData: %s" % message)

func get_record(id: StringName) -> Resource:
	## 按 id 取资源记录
	## 参数 id：资源 id
	## 返回：资源记录；不存在时返回 null 并 push_warning
	if not _records.has(id):
		push_warning("GameData: 资源 id '%s' 未注册" % id)
		return null
	return _records[id]

func get_resource_path(id: StringName) -> String:
	## 按 id 取资源路径（id -> path 双索引的读取口）
	## 参数 id：资源 id
	## 返回：res:// 路径；不存在时返回空串并 push_warning（避开 Node.get_path 原生方法名）
	if not _paths.has(id):
		push_warning("GameData: 资源 id '%s' 无路径索引" % id)
		return ""
	return _paths[id]

func get_records_of_class(cls: Script) -> Array[Resource]:
	## 按类取全部资源记录（含子类，沿基类链匹配）
	## 参数 cls：目标类（Script）
	## 返回：该类全部记录（无序）
	var result: Array[Resource] = []
	for record: Resource in _records.values():
		var script: Script = record.get_script()
		while script != null:
			if script == cls:
				result.append(record)
				break
			script = script.get_base_script()
	return result

func get_domain(domain: StringName) -> Array[Resource]:
	## 按域取全部资源记录
	## 参数 domain：域键（DOMAIN_SCHEMA 之一）
	## 返回：该域全部记录；未知域返回空数组并 push_warning
	if not _domain_ids.has(domain):
		push_warning("GameData: 未知数据域 '%s'" % domain)
		return []
	var result: Array[Resource] = []
	for record_id: StringName in _GetDomainIds(domain):
		result.append(_records[record_id])
	return result

func get_domain_ids(domain: StringName) -> Array[StringName]:
	## 按域取全部资源 id 列表（索引侧含无 id 表的文件名回退语义，供校验器遍历）
	## 参数 domain：域键（DOMAIN_SCHEMA 之一）
	## 返回：该域资源 id 列表；未知域返回空数组并 push_warning
	if not _domain_ids.has(domain):
		push_warning("GameData: 未知数据域 '%s'" % domain)
		var empty_ids: Array[StringName] = []
		return empty_ids
	return _domain_ids[domain]

func get_asset_path(id: StringName) -> String:
	## 按资源 id 查 AssetRegistry 映射的路径（多 registry 任意命中即返回——
	## R4-13 勘正：REUSE 缓存下遍历序不保证加载序）
	## 参数 id：资源 id（如 vfx/icon/portrait 引用 id）
	## 返回：res:// 路径；未登记时返回空串并 push_warning
	for record: Resource in get_records_of_class(AssetRegistry):
		var registry: AssetRegistry = record as AssetRegistry
		if registry != null and registry.mapping.has(id):
			return registry.mapping[id]
	push_warning("GameData: 资源 id '%s' 未登记于任何 AssetRegistry" % id)
	return ""

func reload_domain(domain: StringName) -> Error:
	## 热重载单个数据域（清旧索引后重扫，IGNORE 读盘 + 同址拷贝刷新旧实例），
	## 成功后发出 data_reloaded（R4-11：未知域失败不发信号）。
	## W4-08 issues 语义声明：issues 为**全局单列表非按域隔离**——rescan 开头
	## 全量清空重建（S5-6），未 rescan 域的问题记录不保留；消费方（校验器/
	## 测试）读到的恒为「最近一次扫描口径」的问题全集
	## 参数 domain：域键（DOMAIN_SCHEMA 之一）
	## 返回：OK = 重载完成；ERR_INVALID_PARAMETER = 未知域（信号未发）
	if not DOMAIN_SCHEMA.has(domain):
		push_warning("GameData: 未知数据域 '%s'，跳过热重载" % domain)
		return ERR_INVALID_PARAMETER
	_ScanDomain(domain, true)
	data_reloaded.emit(domain)
	return OK
