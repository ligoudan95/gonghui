## 通用资产登记同步工具契约测试（M6 方案 §3.2「批 3 +6（sync 三态）」）
## 覆盖：build_diff 三态（新增文件/孤儿键/未登记文件）+ 安全写入语义
##（只增不删不覆写）+ id 错配防御（派生 id 被占用跳过增补）。纯逻辑直调
##（注入构造数据，不触盘不依赖真实 registry 实况——仓库实态零差异证明在
## headless 工具跑批输出，不入套件防资产增删即红的脆弱耦合）。
extends GdUnitTestSuite

## sync 工具脚本（SceneTree 脚本——静态函数经 preload 类访问，不实例化）
const SyncTool: GDScript = preload("res://tools/sync_asset_registry.gd")

func _MakeFiles() -> Dictionary:
	## 文件集夹具：三组四件（bg 两件 + ui 两件）
	## 参数：无
	## 返回：{String 路径: String 派生 id}
	return {
		"res://assets/bg/bg_title.png": "bg_title",
		"res://assets/bg/bg_explore.png": "bg_explore",
		"res://assets/icons/icon_res_gold.png": "icon_res_gold",
		"res://assets/ui/main_theme.tres": "main_theme",
	}

func _MakeMapping() -> Dictionary:
	## registry 映射夹具：四键与文件集对齐（键名≠文件名先例：ui_main_theme）
	## 参数：无
	## 返回：{StringName id: String 路径}
	return {
		&"bg_title": "res://assets/bg/bg_title.png",
		&"bg_explore": "res://assets/bg/bg_explore.png",
		&"icon_res_gold": "res://assets/icons/icon_res_gold.png",
		&"ui_main_theme": "res://assets/ui/main_theme.tres",
	}

func test_zero_diff_when_all_matched() -> void:
	## 三态零差异：文件集/映射/naming 全对齐 → 四差异区全空 + 规模计数正确
	var report: Dictionary = SyncTool.build_diff(_MakeFiles(), _MakeMapping(), [
		&"bg_title", &"bg_explore", &"icon_res_gold", &"ui_main_theme", &"registry",
	])
	assert_int(report[&"new_files"].size()).is_equal(0)
	assert_int(report[&"orphan_keys"].size()).is_equal(0)
	assert_int(report[&"naming_pending"].size()).is_equal(0)
	assert_int(report[&"id_conflicts"].size()).is_equal(0)
	assert_int(report[&"file_count"]).is_equal(4)
	assert_int(report[&"key_count"]).is_equal(4)

func test_new_file_reported_and_registered() -> void:
	## 状态① 新增文件：未登记文件进 new_files → 安全写入增补派生 id→路径，
	## 且既有键零改动（只增语义）
	var files: Dictionary = _MakeFiles()
	files["res://assets/bg/bg_new_scene.png"] = "bg_new_scene"
	var mapping: Dictionary = _MakeMapping()
	var report: Dictionary = SyncTool.build_diff(files, mapping, [
		&"bg_title", &"bg_explore", &"icon_res_gold", &"ui_main_theme",
	])
	assert_int(report[&"new_files"].size()).is_equal(1)
	assert_str(String(report[&"new_files"][0])).is_equal(
			"res://assets/bg/bg_new_scene.png")
	var additions: Dictionary = SyncTool.registry_additions(files, mapping, report)
	assert_int(additions.size()).is_equal(1)
	assert_str(String(additions.get(&"bg_new_scene", ""))).is_equal(
			"res://assets/bg/bg_new_scene.png")
	# 应用后：只增（新键入表），既有键原值原样
	for key: StringName in additions:
		mapping[key] = additions[key]
	assert_int(mapping.size()).is_equal(5)
	assert_str(String(mapping[&"ui_main_theme"])).is_equal(
			"res://assets/ui/main_theme.tres")

func test_orphan_key_reported_not_removed() -> void:
	## 状态② 孤儿键：registry 有键无文件 → 进 orphan_keys 报告；安全写入增量
	## 不含任何删除动作（增量表为空——孤儿键处置归人工）
	var files: Dictionary = _MakeFiles()
	files.erase("res://assets/bg/bg_explore.png")
	var mapping: Dictionary = _MakeMapping()
	var report: Dictionary = SyncTool.build_diff(files, mapping, [
		&"bg_title", &"bg_explore", &"icon_res_gold", &"ui_main_theme",
	])
	assert_int(report[&"orphan_keys"].size()).is_equal(1)
	assert_str(String(report[&"orphan_keys"][0])).is_equal("bg_explore")
	var additions: Dictionary = SyncTool.registry_additions(files, mapping, report)
	assert_int(additions.size()).is_equal(0)

func test_naming_pending_printed_as_draft_only() -> void:
	## 状态③ 未登记文件：registry 键无 naming 条目 → 进 naming_pending；草稿
	## 行含 id 与 domain 建议、display_name 留空待人工——草稿为纯打印数据，
	## 不回写任何结构（naming 落盘归人工粘贴）
	var mapping: Dictionary = _MakeMapping()
	var report: Dictionary = SyncTool.build_diff(_MakeFiles(), mapping, [
		&"bg_title", &"bg_explore", &"icon_res_gold", &"ui_main_theme", &"registry",
	])
	assert_int(report[&"naming_pending"].size()).is_equal(0)
	var report_missing: Dictionary = SyncTool.build_diff(_MakeFiles(), mapping, [
		&"bg_title", &"icon_res_gold", &"ui_main_theme", &"registry",
	])
	assert_int(report_missing[&"naming_pending"].size()).is_equal(1)
	assert_str(String(report_missing[&"naming_pending"][0])).is_equal("bg_explore")
	var draft: PackedStringArray = SyncTool.naming_draft_lines(
			report_missing[&"naming_pending"])
	assert_int(draft.size()).is_equal(1)
	assert_str(draft[0]).contains("resource_id = &\"bg_explore\"")
	assert_str(draft[0]).contains("domain = &\"assets\"")
	assert_str(draft[0]).contains("display_name = \"\"")

func test_id_conflict_blocks_addition() -> void:
	## id 错配防御：新文件派生 id 已被其他路径占用 → 进 id_conflicts 报告，
	## 安全写入增量跳过该 id（不覆写既有键——人工裁定归置）
	var files: Dictionary = _MakeFiles()
	files["res://assets/ui/main_theme.png"] = "main_theme"
	var mapping: Dictionary = _MakeMapping()
	# 既有键 main_theme 映射到另一路径（键名≠文件名先例的错配形态）
	mapping[&"main_theme"] = "res://assets/units/main_theme.png"
	var report: Dictionary = SyncTool.build_diff(files, mapping, [
		&"bg_title", &"bg_explore", &"icon_res_gold", &"ui_main_theme", &"main_theme",
	])
	assert_int(report[&"id_conflicts"].size()).is_equal(1)
	assert_str(String(report[&"id_conflicts"][0])).contains("main_theme")
	var additions: Dictionary = SyncTool.registry_additions(files, mapping, report)
	assert_bool(additions.has(&"main_theme")).is_false()
	assert_str(String(mapping[&"main_theme"])).is_equal(
			"res://assets/units/main_theme.png")

func test_orphan_with_new_file_addition_coexists() -> void:
	## 三态并存：孤儿键 + 新增文件同时出现 → 两态各自报告互不干扰，安全
	## 写入只补新文件（孤儿键保留在映射中——删除归人工决策）
	var files: Dictionary = _MakeFiles()
	files.erase("res://assets/icons/icon_res_gold.png")
	files["res://assets/icons/icon_res_new.png"] = "icon_res_new"
	var mapping: Dictionary = _MakeMapping()
	var report: Dictionary = SyncTool.build_diff(files, mapping, [
		&"bg_title", &"bg_explore", &"icon_res_gold", &"ui_main_theme", &"icon_res_new",
	])
	assert_int(report[&"orphan_keys"].size()).is_equal(1)
	assert_str(String(report[&"orphan_keys"][0])).is_equal("icon_res_gold")
	assert_int(report[&"new_files"].size()).is_equal(1)
	var additions: Dictionary = SyncTool.registry_additions(files, mapping, report)
	assert_int(additions.size()).is_equal(1)
	assert_bool(additions.has(&"icon_res_new")).is_true()
	assert_bool(mapping.has(&"icon_res_gold")).is_true()
