## 通用资产登记同步工具（sync_asset_registry——M6 方案 §3.2 第④步落地）
## 职责：assets/ 分组目录扫描（units/tiles/icons/ui/bg/fx）+ AssetRegistry +
## naming_registry 三方 diff，差异报告三态：
##   ① 新增文件（未登记键）→ registry **安全写入**（只增不删不覆写、保留既有
##      comment、无增量不落盘——幂等）
##   ② 孤儿键（registry 有键无文件）→ 只报告不删（删除属人工决策）
##   ③ 未登记文件（registry 键无 naming 条目）→ naming 待补条目**只打印草稿
##      不自动写入**（人工粘贴保持可审查——方案原话）
## 另报：id 错配（新文件派生 id 已被其他路径占用——安全写入跳过，人工裁定）。
## 同 id 原位替换场景预期输出「无差异」报告（正式素材批量入库的零改表证明）。
## 口径注意：naming 比对按 **registry 键**（id 空间）而非文件名——ui_main_theme
## 键名 ≠ 文件名 main_theme 的既有先例不受误报；naming 中非资产文件条目
##（如 registry 表自身）不在本工具比对范围。
## 纯逻辑约束：diff/登记增量/naming 草稿为纯静态函数（gdUnit 契约测试直调，
## tests/unit/data/test_sync_asset_registry.gd）；IO（扫描/装载/落盘）仅在
## _initialize——headless 单跑不触 autoload。
## 用法：godot --headless -s res://tools/sync_asset_registry.gd
##   （registry 增量落盘后需跑 godot --headless --import 重建导入缓存）
extends SceneTree

## AssetRegistry 路径
const REGISTRY_PATH: String = "res://data/assets/registry.tres"
## naming_registry 路径
const NAMING_PATH: String = "res://data/core/naming_registry.tres"

## assets/ 分组目录（M6 方案 §3.2 ③：units/tiles/icons/ui/bg/fx）
const ASSET_GROUPS: PackedStringArray = ["units", "tiles", "icons", "ui", "bg", "fx"]

## 资产文件扩展名白名单（.import/.uid 等导入伴生文件天然排除）
const ASSET_EXTENSIONS: PackedStringArray = [".png", ".webp", ".tres", ".ttf", ".otf"]

## naming 草稿 rule_note 建议（前缀 -> 注记——人工审定后粘贴）
const DRAFT_RULE_NOTES: Dictionary = {
	"bg_": "bg_<场景名>：场景背景图（1920×1080 不透明）",
	"tile_": "tile_<语义>：地形/物件 tile（128×128）",
	"icon_": "icon_<语义>：图标（64×64）",
	"ui_": "ui_<语义>：UI 母图",
	"fx_": "fx_<语义>：迷雾/叠加/演出件",
	"spr_": "spr_<单位>_<动作>：单位动作帧带（M6 批 1 竖条同族）",
}

func _initialize() -> void:
	## MainLoop 回调：扫描 assets/ → 装载 registry/naming → 三方 diff →
	## 差异报告 → registry 安全写入（仅增量）→ naming 草稿打印（不落盘）
	## 参数：无
	## 返回：无（registry/naming 装载失败按退出码 1 结束）
	var registry: AssetRegistry = load(REGISTRY_PATH) as AssetRegistry
	if registry == null:
		printerr("sync_asset_registry: AssetRegistry 装载失败 %s" % REGISTRY_PATH)
		quit(1)
		return
	var naming: NamingRegistry = load(NAMING_PATH) as NamingRegistry
	if naming == null:
		printerr("sync_asset_registry: naming_registry 装载失败 %s" % NAMING_PATH)
		quit(1)
		return
	var naming_ids: Array = []
	for entry: NamingEntry in naming.entries:
		naming_ids.append(entry.resource_id)
	var files: Dictionary = _ScanAssetDirs()
	# registry 值可能指向扫描范围外的合法路径（如未来 data/ 域直引）——
	# 磁盘实存者并入文件全集，防误报孤儿键
	for key: StringName in registry.mapping:
		var path: String = registry.mapping[key]
		if not files.has(path) and FileAccess.file_exists(path):
			files[path] = path.get_file().get_basename()
	var report: Dictionary = build_diff(files, registry.mapping, naming_ids)
	_PrintReport(report, files, registry.mapping, naming.entries.size())
	var additions: Dictionary = registry_additions(files, registry.mapping, report)
	if not additions.is_empty():
		for key: StringName in additions:
			registry.mapping[key] = additions[key]
		var err: Error = ResourceSaver.save(registry, REGISTRY_PATH)
		if err != OK:
			printerr("sync_asset_registry: registry 保存失败（错误码 %d）" % err)
			quit(1)
			return
		print("sync_asset_registry: registry 安全写入 +%d 键（现共 %d 键；只增不删，comment 未改动）" % [
				additions.size(), registry.mapping.size()])
	var draft: PackedStringArray = naming_draft_lines(report[&"naming_pending"])
	if not draft.is_empty():
		print("sync_asset_registry: naming_registry 待补条目草稿（**不自动写入**——人工审定 display_name/rule_note 后粘贴至 %s）：" % NAMING_PATH)
		for line: String in draft:
			print("  " + line)
	var dirty_count: int = report[&"new_files"].size() + report[&"orphan_keys"].size() \
			+ report[&"naming_pending"].size()
	if dirty_count == 0:
		print("sync_asset_registry: 无差异——registry/naming 与 assets/ 目录一致（同 id 原位替换零改表证明）")
	quit(0)

func _ScanAssetDirs() -> Dictionary:
	## assets/ 分组目录扫描：合格扩展名文件 → {res:// 路径: 派生 id（文件名去扩展名）}
	## 参数：无
	## 返回：{String 路径: String id}（字典序稳定）
	var files: Dictionary = {}
	for group: String in ASSET_GROUPS:
		var dir: DirAccess = DirAccess.open("res://assets/%s" % group)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while not file_name.is_empty():
			if dir.current_is_dir():
				file_name = dir.get_next()
				continue
			var matched: bool = false
			for ext: String in ASSET_EXTENSIONS:
				if file_name.ends_with(ext):
					matched = true
					break
			if matched:
				files["res://assets/%s/%s" % [group, file_name]] = file_name.get_basename()
			file_name = dir.get_next()
		dir.list_dir_end()
	return files

static func build_diff(files: Dictionary, mapping: Dictionary, naming_ids: Array) -> Dictionary:
	## 三方 diff 纯逻辑：文件集 ↔ registry 映射 ↔ naming id 集
	## 参数 files：{String 路径: String 派生 id}；mapping：{StringName id: String 路径}；
	## naming_ids：naming 全域已登记 id 集
	## 返回：{new_files: Array[String]（未登记键的新文件路径）/ orphan_keys:
	## Array[StringName]（有键无文件）/ naming_pending: Array[StringName]（键无
	## naming 条目）/ id_conflicts: Array[String]（新文件 id 已被其他路径占用——
	## 描述串）/ file_count: int / key_count: int}
	var registry_paths: Dictionary = {}
	for key: StringName in mapping:
		registry_paths[mapping[key]] = key
	var new_files: Array[String] = []
	for path: String in files:
		if not registry_paths.has(path):
			new_files.append(path)
	new_files.sort()
	var orphan_keys: Array[StringName] = []
	for key: StringName in mapping:
		if not files.has(mapping[key]):
			orphan_keys.append(key)
	orphan_keys.sort()
	var naming_pending: Array[StringName] = []
	for key: StringName in mapping:
		if not naming_ids.has(key):
			naming_pending.append(key)
	naming_pending.sort()
	var id_conflicts: Array[String] = []
	for path: String in new_files:
		var derived_id: StringName = StringName(String(files[path]))
		if mapping.has(derived_id) and String(mapping[derived_id]) != path:
			id_conflicts.append("%s 派生 id '%s' 已映射 %s（键名≠文件名或历史错配——人工裁定）" % [
					path, derived_id, mapping[derived_id]])
	id_conflicts.sort()
	return {
		&"new_files": new_files,
		&"orphan_keys": orphan_keys,
		&"naming_pending": naming_pending,
		&"id_conflicts": id_conflicts,
		&"file_count": files.size(),
		&"key_count": mapping.size(),
	}

static func registry_additions(files: Dictionary, mapping: Dictionary,
		report: Dictionary) -> Dictionary:
	## registry 安全写入增量计算（纯逻辑）：新文件且派生 id 未占用 → {id: 路径}。
	## 安全语义三不：不删除孤儿键 / 不覆写既有键（id 冲突项跳过归人工）/ 不动
	## comment——调用方仅按本表增补后落盘
	## 参数 files/report：build_diff 同源；mapping：registry 现映射
	## 返回：{StringName id: String 路径} 增量表（空表 = 无需落盘）
	var additions: Dictionary = {}
	for path: String in report[&"new_files"]:
		var derived_id: StringName = StringName(String(files[path]))
		if mapping.has(derived_id):
			continue
		additions[derived_id] = path
	return additions

static func naming_draft_lines(pending_ids: Array) -> PackedStringArray:
	## naming 待补条目草稿行（纯打印数据——不落盘，人工审定后粘贴）
	## 参数 pending_ids：待补 id 列表（build_diff.naming_pending）
	## 返回：草稿行（resource_id/domain/display_name 空/rule_note 前缀建议）
	var lines: PackedStringArray = PackedStringArray()
	for raw_id: Variant in pending_ids:
		var asset_id: String = String(raw_id)
		var note: String = "assets 域登记键（sync 草稿——人工补写规则注记）"
		for prefix: String in DRAFT_RULE_NOTES:
			if asset_id.begins_with(prefix):
				note = String(DRAFT_RULE_NOTES[prefix])
				break
		lines.append("resource_id = &\"%s\"  domain = &\"assets\"  display_name = \"\"  rule_note = \"%s\"" % [
				asset_id, note])
	return lines

func _PrintReport(report: Dictionary, files: Dictionary, mapping: Dictionary,
		naming_count: int) -> void:
	## 差异报告打印（stdout——入库流程第④步证据）
	## 参数 report：build_diff 产物；files/mapping/naming_count：三方规模
	## 返回：无
	print("sync_asset_registry: 扫描 %d 组 %d 文件 / registry %d 键 / naming %d 条" % [
			ASSET_GROUPS.size(), files.size(), mapping.size(), naming_count])
	_PrintSection("新增文件（未登记键——安全写入 registry）", report[&"new_files"])
	_PrintSection("孤儿键（registry 有键无文件——只报告不删，人工决策）",
			report[&"orphan_keys"])
	_PrintSection("未登记文件（缺 naming 条目——草稿打印不落盘）",
			report[&"naming_pending"])
	_PrintSection("id 错配（派生 id 已被占用——安全写入跳过，人工裁定）",
			report[&"id_conflicts"])

func _PrintSection(title: String, items: Array) -> void:
	## 报告分区打印（空区打印 0 项——零差异报告可见性）
	## 参数 title：分区标题；items：条目列表
	## 返回：无
	print("sync_asset_registry: 【%s】%d 项" % [title, items.size()])
	for item: Variant in items:
		print("sync_asset_registry:   - %s" % String(item))
