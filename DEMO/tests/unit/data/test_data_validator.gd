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
	## 全库校验应零错误零警告（121 条记录 = M0 49 + M1 战斗域 14 + M2 事件 29 + M3 探索层 29；计数带全部命中预期）
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report.checked_count).is_equal(121)
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

func test_all_domains_derived_from_schema() -> void:
	## 域清单单源（C-1）：校验遍历域 = GameData.DOMAIN_SCHEMA 键全集——
	## 校验器不再自持第二份清单（新增域只改 DOMAIN_SCHEMA 一处）
	var domains: Array[StringName] = DataValidator._AllDomains(_game_data)
	assert_int(domains.size()).is_equal(_game_data.DOMAIN_SCHEMA.size())
	for domain: StringName in _game_data.DOMAIN_SCHEMA:
		assert_bool(domains.has(domain)).is_true()

func _HasError(report: ValidationReport, prefix: String, needle: String) -> bool:
	## 报告内按前缀+关键字匹配错误（多条断言复用口）
	## 参数 report：校验报告；prefix：规则前缀（如 V-M2-ref-graph）；needle：
	## 错误文本须包含的关键字（通常为记录 id）
	## 返回：true = 命中
	for entry: String in report.errors:
		if entry.begins_with(prefix) and entry.contains(needle):
			return true
	return false

func test_m2_empty_battle_tokens_allowed() -> void:
	## E11：先手/分布 token 空串合法（走默认——引擎 _FirstStrikeOf/
	## _LayoutSlotsOf 已支持）；改空后校验零错误
	var node: EventNodeDef = _game_data.get_record(&"evn_wisp_n3") as EventNodeDef
	var fs_token: StringName = node.outcome.battle.first_strike_token
	var layout_token: StringName = node.outcome.battle.enemy_layout_token
	node.outcome.battle.first_strike_token = &""
	node.outcome.battle.enemy_layout_token = &""
	var report: ValidationReport = DataValidator.run_all(_game_data)
	node.outcome.battle.first_strike_token = fs_token
	node.outcome.battle.enemy_layout_token = layout_token
	assert_int(report.errors.size()).is_equal(0)

func test_m2_control_status_checkin_banned() -> void:
	## E2-10：B 出口 initial_status_id 禁控制类状态（CHECKIN 载入空转）——
	## 注入 DEBUFF_root（定身·临时补 CHECKIN 来源以隔离控制类分支）必须报
	## V-M2-ref-battle
	var root: StatusDef = _game_data.get_record(&"DEBUFF_root") as StatusDef
	var checkin_token: StringName = StatusDef.source_kind_token(
			StatusInstance.SourceKind.CHECKIN)
	var sources_size: int = root.allowed_sources.size()
	root.allowed_sources.append(checkin_token)
	var node: EventNodeDef = _game_data.get_record(&"evn_wisp_n2") as EventNodeDef
	var original: StringName = node.outcome.battle.initial_status_id
	node.outcome.battle.initial_status_id = &"DEBUFF_root"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	# 立即恢复双注入点
	node.outcome.battle.initial_status_id = original
	root.allowed_sources.resize(sources_size)
	assert_bool(_HasError(report, "V-M2-ref-battle", "控制类状态")) \
			.override_failure_message("控制类状态经 CHECKIN 载入应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_m2_graph_orphan_option_detected() -> void:
	## E10②：孤儿选项（无节点挂载）报错——摘除挂载后必须命中
	var node: EventNodeDef = _game_data.get_record(&"evn_collapse_n1") as EventNodeDef
	var option_id: StringName = node.option_ids[3]
	node.option_ids.remove_at(3)
	var report: ValidationReport = DataValidator.run_all(_game_data)
	node.option_ids.insert(3, option_id)
	assert_bool(_HasError(report, "V-M2-ref-graph", String(option_id))) \
			.override_failure_message("摘挂后的选项应报孤儿错误").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_m2_graph_cross_chain_target_detected() -> void:
	## E10①：去向节点须与挂载节点同链——改指他链节点必须命中
	var option: EventOptionDef = _game_data.get_record(&"opt_collapse_1") as EventOptionDef
	var original: StringName = option.success_to
	option.success_to = &"evn_wisp_n1"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	option.success_to = original
	assert_bool(_HasError(report, "V-M2-ref-graph", "不同链")) \
			.override_failure_message("跨链去向应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_m2_graph_reachable_crit_required() -> void:
	## E10③：检定链可达节点 outcome crit 档强制非空——清空 collapse_n2
	## 的 crit_success（o1 成功去向）必须命中
	var node: EventNodeDef = _game_data.get_record(&"evn_collapse_n2") as EventNodeDef
	var original: String = node.outcome.texts[&"crit_success"]
	node.outcome.texts[&"crit_success"] = ""
	var report: ValidationReport = DataValidator.run_all(_game_data)
	node.outcome.texts[&"crit_success"] = original
	assert_bool(_HasError(report, "V-M2-ref-graph", "evn_collapse_n2")) \
			.override_failure_message("可达侧 crit 档清空应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_m2_graph_outcome_option_mix_detected() -> void:
	## E10④：节点 outcome 与 option_ids 混排禁止——终端节点补挂选项必须命中
	var node: EventNodeDef = _game_data.get_record(&"evn_camp_n2") as EventNodeDef
	node.option_ids.append(&"opt_camp_1")
	var report: ValidationReport = DataValidator.run_all(_game_data)
	node.option_ids.remove_at(node.option_ids.size() - 1)
	assert_bool(_HasError(report, "V-M2-ref-graph", "混排")) \
			.override_failure_message("终端节点混排选项应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_v5_map_region_count_over_two_is_caught() -> void:
	## V-5（2026-09-26 审计）：region_ids 数量 ≤ 2——DEMO 口径冻结
	## （ExploreMapState.region_index_of 两段下标推导假设）；负反注入第 3 段
	## → 必须报 V-M3-map-region-count 且 to_text 含记录 id；恢复后归零
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	assert_object(map_def).is_not_null()
	var original: Array[StringName] = map_def.region_ids.duplicate()
	map_def.region_ids.append(&"reg_city")
	var report: ValidationReport = DataValidator.run_all(_game_data)
	map_def.region_ids = original
	assert_bool(_HasError(report, "V-M3-map-region-count", "map_m1_village_mine")) \
			.override_failure_message("region_ids 超 DEMO 冻结口径 ≤ 2 应报错").is_true()
	assert_str(report.to_text()).contains("map_m1_village_mine")
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)
