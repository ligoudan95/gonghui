## AssetRegistry 单位 sprite 登记单元测试（插队任务）
## 覆盖：registry 9 条 spr_* 映射可经 GameData.get_asset_path 取到且文件存在；
## 全库校验零错误零警告（checked_count 64——盲审批 2 A-9 assets 域纳入校验计数）；
## 断链注入（临时把一条映射改为不存在路径 → 必须报 V-M1-ref-asset 且
## to_text 含资源 id → 恢复原值后归零）。
## 说明：GameData 经脚本实例化 + 显式 initialize_data（gdUnit CI 运行器不注册 autoload）。
extends GdUnitTestSuite

## GameData 自动加载脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 9 个单位 sprite 资源 id（tools/gen_unit_sprites.gd 同源清单）
const SPRITE_IDS: Array[StringName] = [
	&"spr_cls_warrior", &"spr_cls_rogue", &"spr_cls_mage",
	&"spr_cls_priest", &"spr_cls_ranger", &"spr_cls_arcanist",
	&"spr_en_mutant_rat", &"spr_en_goblin_miner", &"spr_en_elite_boss",
]

## 套件级 GameData 实例
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData 并显式初始化（扫描全数据域，含 assets 域 registry）
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

func test_registry_nine_entries_resolvable() -> void:
	## 9 条 spr_* 映射：get_asset_path 非空、指向 assets/units/ 下、物理文件存在
	for sprite_id: StringName in SPRITE_IDS:
		var path: String = _game_data.get_asset_path(sprite_id)
		assert_str(path).is_not_empty()
		assert_bool(path.begins_with("res://assets/units/")).is_true()
		assert_bool(path.ends_with("%s.png" % sprite_id)).is_true()
		assert_bool(FileAccess.file_exists(path)).is_true()

func test_run_all_clean_with_registry() -> void:
	## 全库校验应零错误零警告（registry 加入 assets 域后计数带不变；M3 后全库 121）
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report.checked_count).is_equal(121)
	assert_int(report.errors.size()).is_equal(0)
	assert_int(report.warnings.size()).is_equal(0)
	assert_bool(report.is_ok()).is_true()

func test_broken_asset_path_is_caught_and_restored() -> void:
	## 断链注入：战士映射改为不存在路径 → 校验必须抓到单条 V-M1-ref-asset
	## 错误且 to_text 含资源 id；恢复后归零
	var registry: AssetRegistry = _game_data.get_record(&"registry") as AssetRegistry
	assert_object(registry).is_not_null()
	var original_path: String = registry.mapping[&"spr_cls_warrior"]
	registry.mapping[&"spr_cls_warrior"] = "res://assets/units/spr_nope.png"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	# 立即恢复（gdUnit 断言失败不中断函数，恢复代码必达，不污染缓存共享实例）
	registry.mapping[&"spr_cls_warrior"] = original_path
	assert_int(report.errors.size()).is_equal(1)
	assert_bool(report.errors[0].begins_with("V-M1-ref-asset")).is_true()
	assert_str(report.errors[0]).contains("spr_cls_warrior")
	assert_str(report.to_text()).contains("spr_cls_warrior")
	# 恢复后复查归零
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)
