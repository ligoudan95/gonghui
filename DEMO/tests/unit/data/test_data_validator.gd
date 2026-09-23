## DataValidator 单元测试（M0 批 2）
## 覆盖：全库 run_all 零错误零警告；断链注入（临时改一条技能状态引用为不存在 id
## → 必须报 V-M0-ref-skill-status 且 to_text 含记录 id → 恢复原值后归零）。
## 说明：GameData 经脚本实例化 + 显式 initialize_data（gdUnit CI 运行器不注册 autoload）。
extends GdUnitTestSuite

## GameData 自动加载脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 实例
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData 并显式初始化（扫描全数据域）
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

func test_run_all_clean() -> void:
	## 全库校验应零错误零警告（49 条记录；计数带全部命中预期）
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report.checked_count).is_equal(49)
	assert_int(report.errors.size()).is_equal(0)
	assert_int(report.warnings.size()).is_equal(0)
	assert_bool(report.is_ok()).is_true()

func test_broken_status_ref_is_caught_and_restored() -> void:
	## 断链注入：寒冰锁链首效果状态引用改为不存在 id → 校验必须抓到单条
	## V-M0-ref-skill-status 错误且 to_text 含记录 id；恢复后归零
	var skill: SkillDef = _game_data.get_record(&"skl_mage_frost_chain")
	assert_object(skill).is_not_null()
	var original_id: StringName = skill.effects[0].status_id
	skill.effects[0].status_id = &"DEBUFF_nope"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	# 立即恢复（gdUnit 断言失败不中断函数，恢复代码必达，不污染缓存共享实例）
	skill.effects[0].status_id = original_id
	assert_int(report.errors.size()).is_equal(1)
	assert_bool(report.errors[0].begins_with("V-M0-ref-skill-status")).is_true()
	assert_str(report.errors[0]).contains("skl_mage_frost_chain")
	assert_str(report.to_text()).contains("skl_mage_frost_chain")
	# 恢复后复查归零
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_broken_owner_ref_is_caught() -> void:
	## 断链注入（第二样本）：技能 owner 改为不存在 id → 报 V-M0-ref-skill-owner
	var skill: SkillDef = _game_data.get_record(&"skl_warrior_power_strike")
	var original_owner: StringName = skill.owner_id
	skill.owner_id = &"cls_nope"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	skill.owner_id = original_owner
	assert_bool(report.has_errors()).is_true()
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M0-ref-skill-owner") and entry.contains("skl_warrior_power_strike"):
			matched = true
	assert_bool(matched).is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)
