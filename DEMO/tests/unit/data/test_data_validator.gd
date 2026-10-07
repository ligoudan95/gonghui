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
	## 全库校验应零错误零警告（144 条记录 = M0 49 + M1 战斗域 14 + M2 事件 29 + M3 探索层 30 + M4 经营层 13 + M4 增补批轻度 3 + 功能一批 2 染毒毒瘴 2 + M6 批 3.5a 探索地格 +5（隐秘通道拆分 + 装饰格 ×4）；计数带全部命中预期）
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report.checked_count).is_equal(144)
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

# --------------------------------------------------------------------------
# 盲审第 1 轮补强（V-R1-*——2026-09-29；正反口径：全库合法归零见
# test_run_all_clean，以下逐条注入负反样本验证拦截）
# --------------------------------------------------------------------------

func test_r1_heal_source_attr_domain() -> void:
	## V-R1-heal-attr（S1-02）：HEAL 效果 source_attr 拼错键/置空必须报错
	var skill: SkillDef = _game_data.get_record(&"skl_priest_heal") as SkillDef
	assert_object(skill).is_not_null()
	var original: StringName = skill.effects[0].source_attr
	skill.effects[0].source_attr = &"percepton_typo"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report, "V-R1-heal-attr", "skl_priest_heal")) \
			.override_failure_message("HEAL 源属性拼错应报错").is_true()
	skill.effects[0].source_attr = &""
	var report_empty: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report_empty, "V-R1-heal-attr", "source_attr 为空")) \
			.override_failure_message("HEAL 源属性为空应报错").is_true()
	skill.effects[0].source_attr = original
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r1_dot_domain_mode_params() -> void:
	## V-R1-dot-domain（S1-03）：ATTR_RATIO 模式 attr_id 拼错/ratio ≤ 0 必须报错
	var status: StatusDef = _game_data.get_record(&"DEBUFF_curse") as StatusDef
	assert_object(status).is_not_null()
	assert_object(status.dot).is_not_null()
	var original_attr: StringName = status.dot.attr_id
	var original_ratio: float = status.dot.ratio
	status.dot.attr_id = &"wilpoer_typo"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report, "V-R1-dot-domain", "DEBUFF_curse")) \
			.override_failure_message("DOT attr_id 拼错应报错").is_true()
	status.dot.attr_id = original_attr
	status.dot.ratio = 0.0
	var report_ratio: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report_ratio, "V-R1-dot-domain", "ratio")) \
			.override_failure_message("DOT ratio ≤ 0 应报错").is_true()
	status.dot.ratio = original_ratio
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r1_tendency_focus_attrs_domain() -> void:
	## V-R1-tend-attr（S1-04）：倾向 focus_attrs 拼错键必须报错
	var cls: ClassDef = _game_data.get_record(&"cls_warrior") as ClassDef
	assert_object(cls).is_not_null()
	assert_int(cls.tendencies.size()).is_greater(0)
	var original: Array[StringName] = cls.tendencies[0].focus_attrs.duplicate()
	cls.tendencies[0].focus_attrs = [&"strenght_typo"]
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report, "V-R1-tend-attr", "cls_warrior")) \
			.override_failure_message("倾向 focus_attrs 拼错应报错").is_true()
	cls.tendencies[0].focus_attrs = original
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r1_optional_asset_refs_guard() -> void:
	## V-R1-asset-ref（S1-05）：非空即查——drop_ref 未登记 / vfx_id 不可解析必须报错
	var enemy: EnemyDef = _game_data.get_record(&"en_m1_mutant_rat") as EnemyDef
	assert_object(enemy).is_not_null()
	enemy.drop_ref = &"drop_rat_fang_unregistered"
	var enemy_report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(enemy_report, "V-R1-asset-ref", "en_m1_mutant_rat")) \
			.override_failure_message("drop_ref 未登记应报错").is_true()
	enemy.drop_ref = &""
	var skill: SkillDef = _game_data.get_record(&"skl_priest_heal") as SkillDef
	skill.vfx_id = &"vfx_unregistered"
	var skill_report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(skill_report, "V-R1-asset-ref", "skl_priest_heal")) \
			.override_failure_message("vfx_id 不可解析应报错").is_true()
	skill.vfx_id = &""
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r1_check_option_exit_must_be_terminal() -> void:
	## V-R1-check-exit（S2-05）：CHECK 选项去向指向非终端节点（有选项无 outcome）
	## 必须报错——四档透传协议锁死「去向=终端」形态（opt_collapse_1 为真 CHECK
	## 选项——OptionKind.CHECK=0；evn_collapse_n1 为非终端链内节点）
	var option: EventOptionDef = _game_data.get_record(&"opt_collapse_1") as EventOptionDef
	assert_object(option).is_not_null()
	var original: StringName = option.success_to
	option.success_to = &"evn_collapse_n1"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	option.success_to = original
	assert_bool(_HasError(report, "V-R1-check-exit", "非终端")) \
			.override_failure_message("CHECK 选项去向非终端节点应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

# --------------------------------------------------------------------------
# 盲审第 2 轮补强（V-R2-* + V-R1 加严——2026-09-29；正反口径：全库合法归零
# 见 test_run_all_clean，以下逐条注入负反样本验证拦截）
# --------------------------------------------------------------------------

func test_r2_heal_ratio_flat_domain() -> void:
	## S1-R2-01/S2-R2-02：HEAL ratio/flat 非负且至少一项为正（均非正=恒 ≤ 0
	## 死技能；负值=反向伤害）
	var skill: SkillDef = _game_data.get_record(&"skl_priest_heal") as SkillDef
	var original_ratio: float = skill.effects[0].ratio
	var original_flat: int = skill.effects[0].flat
	skill.effects[0].ratio = 0.0
	skill.effects[0].flat = 0
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report, "V-R1-heal-attr", "均非正")) \
			.override_failure_message("HEAL ratio 与 flat 均非正应报错").is_true()
	skill.effects[0].flat = -5
	var negative_report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(negative_report, "V-R1-heal-attr", "flat")) \
			.override_failure_message("HEAL flat 为负应报错").is_true()
	skill.effects[0].ratio = original_ratio
	skill.effects[0].flat = original_flat
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r2_status_icon_id_asset_ref_guard() -> void:
	## S1-R2-03：StatusDef.icon_id 非空即查 AssetRegistry（第 6 个资源引用
	## 字段补入护栏）
	var status: StatusDef = _game_data.get_record(&"DEBUFF_curse") as StatusDef
	status.icon_id = &"icon_unregistered"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report, "V-R1-asset-ref", "DEBUFF_curse")) \
			.override_failure_message("icon_id 不可解析应报错").is_true()
	status.icon_id = &""
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r2_dot_category_reverse_and_fixed_floor() -> void:
	## S1-R2-06：dot 配在非 DOT 类上=死配置报错；FIXED 模式 fixed < 1 报错
	var status: StatusDef = _game_data.get_record(&"DEBUFF_curse") as StatusDef
	var original_category: int = status.category
	status.category = StatusDef.Category.STAT_MOD
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report, "V-R1-dot-domain", "非 DOT 类")) \
			.override_failure_message("dot 配在非 DOT 类上应报错").is_true()
	status.category = original_category
	var poison: StatusDef = _game_data.get_record(&"DEBUFF_tile_poison") as StatusDef
	var original_fixed: int = poison.dot.fixed
	poison.dot.fixed = 0
	var fixed_report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(fixed_report, "V-R1-dot-domain", "死 DOT")) \
			.override_failure_message("FIXED 模式 fixed < 1 应报错").is_true()
	poison.dot.fixed = original_fixed
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r2_skill_resource_track_consistency() -> void:
	## S1-R2-02：资源轨一致性——敌方技能挂 MANA（无法力池）报错；职业技错轨
	##（牧师 MANA 轨技能改 STAMINA）报错
	var enemy_skill: SkillDef = _game_data.get_record(&"skl_enemy_plague_bite") as SkillDef
	var original_kind: int = enemy_skill.resource_type
	enemy_skill.resource_type = SkillDef.ResourceKind.MANA
	var enemy_report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(enemy_report, "V-R2-skill-resource", "无法力池")) \
			.override_failure_message("敌方技能挂 MANA 应报错").is_true()
	enemy_skill.resource_type = original_kind
	var class_skill: SkillDef = _game_data.get_record(&"skl_priest_heal") as SkillDef
	var original_class_kind: int = class_skill.resource_type
	class_skill.resource_type = SkillDef.ResourceKind.STAMINA
	var class_report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(class_report, "V-R2-skill-resource", "资源轨")) \
			.override_failure_message("职业技资源轨与职业轨错位应报错").is_true()
	class_skill.resource_type = original_class_kind
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r2_tier_line_strictly_increasing() -> void:
	## S1-R2-04：难度档判定线严格递增 + ∈ [1,20]——极难改 5（< 困难 14）必报
	var cfg: CoreConfig = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var original_line: int = cfg.difficulty_tiers["极难"]
	cfg.difficulty_tiers["极难"] = 5
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report, "V-R2-tier-domain", "极难")) \
			.override_failure_message("判定线未严格递增应报错").is_true()
	cfg.difficulty_tiers["极难"] = 25
	var range_report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(range_report, "V-R2-tier-domain", "越界")) \
			.override_failure_message("判定线越界 [1,20] 应报错").is_true()
	cfg.difficulty_tiers["极难"] = original_line
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r2_battle_map_connectivity_detected() -> void:
	## S1-R2-05：战场地图连通性——enemy_spawns 注入界外格（必不在可达闭包）
	## 必报 V-R2-battle-map-conn；恢复后归零（真实两图连通=正反锚）
	var map_def: BattleMapDef = _game_data.get_record(&"btm_m1_random_8x8") as BattleMapDef
	assert_object(map_def).is_not_null()
	var spawn_count: int = map_def.enemy_spawns.size()
	map_def.enemy_spawns.append(Vector2i(0, 99))
	var report: ValidationReport = DataValidator.run_all(_game_data)
	map_def.enemy_spawns.resize(spawn_count)
	assert_bool(_HasError(report, "V-R2-battle-map-conn", "btm_m1_random_8x8")) \
			.override_failure_message("不可达敌方出生位应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r2_quest_region_id_checked_for_light_templates() -> void:
	## S1-R2-07：region_id 查域对轻度模板同样生效（此前 NON_COMBAT 分支整段
	## 跳过——配了坏 region_id 不拦）
	var quest: QuestTemplateDef = _game_data.get_record(&"q_chore_tavern_help") as QuestTemplateDef
	assert_object(quest).is_not_null()
	var original_region: StringName = quest.region_id
	quest.region_id = &"reg_nope"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	quest.region_id = original_region
	assert_bool(_HasError(report, "V-M3-ref-quest-goal", "region_id")) \
			.override_failure_message("轻度模板坏 region_id 应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r2_encounter_weight_coverage_detected() -> void:
	## S1-R2-08：map.region_ids 项无 encw 行必报（漏配=该区域遭遇静默关闭）
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	var original_regions: Array[StringName] = map_def.region_ids.duplicate()
	map_def.region_ids.append(&"reg_nope")
	var report: ValidationReport = DataValidator.run_all(_game_data)
	map_def.region_ids = original_regions
	assert_bool(_HasError(report, "V-R2-encw-coverage", "reg_nope")) \
			.override_failure_message("区域无遭遇权重行应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r2_status_control_kind_bidirectional() -> void:
	## S1-R2-09：category×control_kind 双向——CONTROL 无种类 / 非控制类带种类
	## 均报错
	var root: StatusDef = _game_data.get_record(&"DEBUFF_root") as StatusDef
	var original_kind: int = root.control_kind
	root.control_kind = StatusDef.ControlKind.NONE
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report, "V-R2-status-control", "DEBUFF_root")) \
			.override_failure_message("CONTROL 无控制种类应报错").is_true()
	root.control_kind = original_kind
	var ambush: StatusDef = _game_data.get_record(&"BUFF_ambush") as StatusDef
	var ambush_kind: int = ambush.control_kind
	ambush.control_kind = StatusDef.ControlKind.ROOT
	var reverse_report: ValidationReport = DataValidator.run_all(_game_data)
	ambush.control_kind = ambush_kind
	assert_bool(_HasError(reverse_report, "V-R2-status-control", "BUFF_ambush")) \
			.override_failure_message("非控制类带控制种类应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r2_quest_time_limit_days_floor() -> void:
	## S1-R2-10：time_limit_days ≥ 1（0=首日结算即到期瞬刷）
	var quest: QuestTemplateDef = _game_data.get_record(&"q_lair_purge") as QuestTemplateDef
	var original_limit: int = quest.time_limit_days
	quest.time_limit_days = 0
	var report: ValidationReport = DataValidator.run_all(_game_data)
	quest.time_limit_days = original_limit
	assert_bool(_HasError(report, "V-M4-quest-template", "time_limit_days")) \
			.override_failure_message("time_limit_days < 1 应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r2_option_level_exit_banned() -> void:
	## S2-R2-03：选项级出口禁 B——opt_camp_2 的 success_outcome 改 exit_kind=B
	## 必报（战斗出口只能节点级/单点级——锚点不回写战后续跑链断）
	var option: EventOptionDef = _game_data.get_record(&"opt_camp_2") as EventOptionDef
	assert_object(option).is_not_null()
	assert_object(option.success_outcome).is_not_null()
	var original_kind: int = option.success_outcome.exit_kind
	option.success_outcome.exit_kind = EventOutcomeDef.ExitKind.B
	var report: ValidationReport = DataValidator.run_all(_game_data)
	option.success_outcome.exit_kind = original_kind
	assert_bool(_HasError(report, "V-R2-option-exit", "opt_camp_2")) \
			.override_failure_message("选项级 B 出口应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

# --------------------------------------------------------------------------
# 盲审第 3 轮补强（V-R3-* + 既有规则扩口——2026-09-29）
# --------------------------------------------------------------------------

func test_r3_battle_map_spawn_interconnectivity_detected() -> void:
	## S1-R3-01：我方出生位互连断言——spawns[2] 改指 (2,3)（全障碍包围的
	## 独立可通行格）必报「与首位出生位不连通」；恢复后归零
	var map_def: BattleMapDef = _game_data.get_record(&"btm_m1_random_8x8") as BattleMapDef
	assert_object(map_def).is_not_null()
	var original_spawn: Vector2i = map_def.player_spawns[2]
	map_def.player_spawns[2] = Vector2i(2, 3)
	var report: ValidationReport = DataValidator.run_all(_game_data)
	map_def.player_spawns[2] = original_spawn
	assert_bool(_HasError(report, "V-R2-battle-map-conn", "不连通")) \
			.override_failure_message("圈进障碍的隔离出生位应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r3_single_check_failure_outcome_required() -> void:
	## S2-R3-01：检定单点缺 failure_outcome 必报（运行时检定失败事件静默烧掉）
	var single: SingleEventDef = _game_data.get_record(&"sp_village_cart") as SingleEventDef
	assert_object(single).is_not_null()
	assert_object(single.failure_outcome).is_not_null()
	var original: EventOutcomeDef = single.failure_outcome
	single.failure_outcome = null
	var report: ValidationReport = DataValidator.run_all(_game_data)
	single.failure_outcome = original
	assert_bool(_HasError(report, "V-R3-single-exit", "sp_village_cart")) \
			.override_failure_message("检定单点缺失败出口应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r3_battle_exit_payload_fields_must_be_empty() -> void:
	## S2-R3-02：B 出口自带 reward/grant_quest_id/unlock_flag 必报（运行时
	## 静默丢弃——应配 post_battle）
	var node: EventNodeDef = _game_data.get_record(&"evn_wisp_n3") as EventNodeDef
	assert_object(node.outcome).is_not_null()
	var original_reward: RewardDef = node.outcome.reward
	var original_grant: StringName = node.outcome.grant_quest_id
	node.outcome.reward = RewardDef.new()
	node.outcome.grant_quest_id = &"q_chore_supply_run"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	node.outcome.reward = original_reward
	node.outcome.grant_quest_id = original_grant
	assert_bool(_HasError(report, "V-M2-ref-exit", "reward")) \
			.override_failure_message("B 出口自带 reward 应报错").is_true()
	assert_bool(_HasError(report, "V-M2-ref-exit", "grant_quest_id")) \
			.override_failure_message("B 出口自带 grant_quest_id 应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r3_chain_entry_narrative_required() -> void:
	## S2-R3-03：链入口节点 narrative_text 为空必报（空视图不落消耗——
	## 重踏重触发整链）
	var node: EventNodeDef = _game_data.get_record(&"evn_collapse_n1") as EventNodeDef
	var original: String = node.narrative_text
	node.narrative_text = ""
	var report: ValidationReport = DataValidator.run_all(_game_data)
	node.narrative_text = original
	assert_bool(_HasError(report, "V-R3-chain-entry", "chain_mine_collapse")) \
			.override_failure_message("链入口叙述为空应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r3_owner_empty_whitelist_skill_requires_none_resource() -> void:
	## S1-R3-06：owner 空白名单技能（通用普攻）挂消耗轨必报（无资源轨定义
	## ——死技能）
	var skill: SkillDef = _game_data.get_record(&"skl_atk_enemy_common") as SkillDef
	var original: int = skill.resource_type
	skill.resource_type = SkillDef.ResourceKind.STAMINA
	var report: ValidationReport = DataValidator.run_all(_game_data)
	skill.resource_type = original
	assert_bool(_HasError(report, "V-R2-skill-resource", "skl_atk_enemy_common")) \
			.override_failure_message("白名单技能挂消耗轨应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r3_encw_orphan_row_detected() -> void:
	## S1-R3-07：encw 反向断言——行 region_id 不属于任何地图区域必报
	##（无主行=死配置；注入 reg_nope 同时触发正向缺行报错，断言只锚反向）
	var weight: EncounterWeightDef = _game_data.get_record(&"encw_mine") as EncounterWeightDef
	var original: StringName = weight.region_id
	weight.region_id = &"reg_nope"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	weight.region_id = original
	assert_bool(_HasError(report, "V-R2-encw-coverage", "无主行")) \
			.override_failure_message("无所属区域的 encw 行应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r3_naming_entry_name_must_start_with_record_name() -> void:
	## S1-R3-02②：登记名以记录显示名开头（宽松 begins_with——占位名漂移
	## 拦截；①实名同步由 test_run_all_clean 零错误锚定）
	var registry: NamingRegistry = _game_data.get_record(&"naming_registry") as NamingRegistry
	assert_object(registry).is_not_null()
	var target: NamingEntry = null
	for entry: NamingEntry in registry.entries:
		if entry.resource_id == &"tend_warrior_a":
			target = entry
			break
	assert_object(target).is_not_null()
	var original_name: String = target.display_name
	target.display_name = "战士 倾向 A"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	target.display_name = original_name
	assert_bool(_HasError(report, "V-B2-naming", "tend_warrior_a")) \
			.override_failure_message("登记名占位漂移应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r4_single_exit_both_sides_and_dead_fields() -> void:
	## S1/S2-R4-01 + S1-R4-07：检定单点 success 半边齐备；无检定单点
	## success 必备 + failure 死配置 + tier 死字段
	var single: SingleEventDef = _game_data.get_record(&"sp_village_cart") as SingleEventDef
	var original_success: EventOutcomeDef = single.success_outcome
	var original_attr: StringName = single.check_attr_id
	single.success_outcome = null
	var miss_report: ValidationReport = DataValidator.run_all(_game_data)
	single.success_outcome = original_success
	assert_bool(_HasError(miss_report, "V-R3-single-exit", "success_outcome")) \
			.override_failure_message("检定单点缺 success_outcome 应报错").is_true()
	single.check_attr_id = &""
	var nocheck_report: ValidationReport = DataValidator.run_all(_game_data)
	single.check_attr_id = original_attr
	assert_bool(_HasError(nocheck_report, "V-R3-single-exit", "failure_outcome")) \
			.override_failure_message("无检定单点配 failure_outcome 应报错").is_true()
	assert_bool(_HasError(nocheck_report, "V-M2-num-domain", "死字段")) \
			.override_failure_message("tier 非空但 attr 为空应报死字段").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r4_post_battle_exit_kind_and_battle_placement() -> void:
	## S1-R4-02/S2-R4-04：post_battle 出口必须 A；battle 子资源仅允许 B 出口
	var node: EventNodeDef = _game_data.get_record(&"evn_wisp_n3") as EventNodeDef
	var post_battle: EventOutcomeDef = node.outcome.battle.post_battle
	var original_kind: int = post_battle.exit_kind
	post_battle.exit_kind = EventOutcomeDef.ExitKind.B
	var kind_report: ValidationReport = DataValidator.run_all(_game_data)
	post_battle.exit_kind = original_kind
	assert_bool(_HasError(kind_report, "V-M2-ref-exit", "post_battle 出口")) \
			.override_failure_message("post_battle 非 A 出口应报错").is_true()
	var option: EventOptionDef = _game_data.get_record(&"opt_camp_2") as EventOptionDef
	var original_battle: BattleOpeningDef = option.success_outcome.battle
	option.success_outcome.battle = BattleOpeningDef.new()
	var place_report: ValidationReport = DataValidator.run_all(_game_data)
	option.success_outcome.battle = original_battle
	assert_bool(_HasError(place_report, "V-M2-ref-exit", "battle 子资源")) \
			.override_failure_message("非 B 出口带 battle 子资源应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r4_naming_empty_record_name_guard_no_false_positive() -> void:
	## S1-R4-03（终轮口径更新 S1-R5-02）：tendency 域空实名改为**报错**
	##（内嵌子资源无 V-M0 兜底——死口关闭）；顶层记录分支空实名仍跳过
	##（V-M0-id-required 另行拦截）。置空一条 → 恰 1 条错误（无级联误报）
	var cls: ClassDef = _game_data.get_record(&"cls_warrior") as ClassDef
	var original_name: String = cls.tendencies[0].display_name
	cls.tendencies[0].display_name = ""
	var report: ValidationReport = DataValidator.run_all(_game_data)
	cls.tendencies[0].display_name = original_name
	assert_int(report.errors.size()).is_equal(1)
	assert_bool(_HasError(report, "V-B2-naming", "display_name 为空")) \
			.override_failure_message("倾向空实名应报且仅报一条").is_true()

func test_r4_facility_count_band_consumed() -> void:
	## S1-R4-04：设施计数带消费——带值收紧（min=5 > 现值 2）必出 warning
	var cfg: CoreConfig = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var original_min: int = cfg.content_facilities_min
	cfg.content_facilities_min = 5
	var report: ValidationReport = DataValidator.run_all(_game_data)
	cfg.content_facilities_min = original_min
	var band_warned: bool = false
	for entry: String in report.warnings:
		if entry.contains("设施计数 2 越界"):
			band_warned = true
	assert_bool(band_warned).override_failure_message("设施计数带越界应出 warning").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r4_resource_pool_and_cost_linkage() -> void:
	## S1-R4-05/S1-R4-08：敌方资源池非负 + 敌技消耗 ≤ 池 + NONE 技零消耗
	var enemy: EnemyDef = _game_data.get_record(&"en_m1_mutant_rat") as EnemyDef
	var original_pool: int = enemy.resource_pool
	enemy.resource_pool = -1
	var pool_report: ValidationReport = DataValidator.run_all(_game_data)
	enemy.resource_pool = original_pool
	assert_bool(_HasError(pool_report, "V-M0-num-domain", "资源池")) \
			.override_failure_message("负资源池应报错").is_true()
	var skill: SkillDef = _game_data.get_record(&"skl_enemy_plague_bite") as SkillDef
	var original_cost: int = skill.resource_cost
	skill.resource_cost = 999
	var cost_report: ValidationReport = DataValidator.run_all(_game_data)
	skill.resource_cost = original_cost
	assert_bool(_HasError(cost_report, "V-R2-skill-resource", "资源池")) \
			.override_failure_message("敌技消耗超池应报错").is_true()
	var basic: SkillDef = _game_data.get_record(&"skl_atk_warrior") as SkillDef
	var original_basic_cost: int = basic.resource_cost
	basic.resource_cost = 5
	var none_report: ValidationReport = DataValidator.run_all(_game_data)
	basic.resource_cost = original_basic_cost
	assert_bool(_HasError(none_report, "V-R2-skill-resource", "NONE")) \
			.override_failure_message("NONE 技非零消耗应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r4_battle_map_obstacle_seed_not_in_closure() -> void:
	## S1-R4-06：_BfsWalkable 种子可通行前置——出生位落在障碍格时种子
	## 不入闭包（互连断言独立跑不漏报；此注入同时触发 map-spawns 不可通行
	## 报错，断言只锚互连错误）
	var map_def: BattleMapDef = _game_data.get_record(&"btm_m1_random_8x8") as BattleMapDef
	var original_spawn: Vector2i = map_def.player_spawns[2]
	map_def.player_spawns[2] = Vector2i(2, 2)
	var report: ValidationReport = DataValidator.run_all(_game_data)
	map_def.player_spawns[2] = original_spawn
	assert_bool(_HasError(report, "V-R2-battle-map-conn", "不连通")) \
			.override_failure_message("障碍格种子不应入闭包——互连断言须报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r5_single_failure_post_battle_texts_collected() -> void:
	## S1-R5-01：单点 failure 半边 post_battle 文本收编（与 _AllEventOutcomes
	## 双半边同步——注入 B 出口 + 空 texts post_battle 必报 four-texts）
	var single: SingleEventDef = _game_data.get_record(&"sp_village_cart") as SingleEventDef
	var original_kind: int = single.failure_outcome.exit_kind
	var original_battle: BattleOpeningDef = single.failure_outcome.battle
	var b_opening := BattleOpeningDef.new()
	b_opening.post_battle = EventOutcomeDef.new()
	single.failure_outcome.exit_kind = EventOutcomeDef.ExitKind.B
	single.failure_outcome.battle = b_opening
	var report: ValidationReport = DataValidator.run_all(_game_data)
	single.failure_outcome.exit_kind = original_kind
	single.failure_outcome.battle = original_battle
	assert_bool(_HasError(report, "V-M2-four-texts", "sp_village_cart:post_battle")) \
			.override_failure_message("failure 半边 post_battle 空文本应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_r5_tendency_display_name_empty_reported() -> void:
	## S1-R5-02：倾向 display_name 空串必报（内嵌子资源无 V-M0 兜底——
	## naming 空串跳过在 tendency 域是死口）
	var cls: ClassDef = _game_data.get_record(&"cls_warrior") as ClassDef
	var original_name: String = cls.tendencies[0].display_name
	cls.tendencies[0].display_name = ""
	var report: ValidationReport = DataValidator.run_all(_game_data)
	cls.tendencies[0].display_name = original_name
	assert_bool(_HasError(report, "V-B2-naming", "display_name 为空")) \
			.override_failure_message("倾向实名空串应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_v_b2_status_src_three_pool_orphans() -> void:
	## S1-05/S5-03 三池孤儿：CHECKIN 池零引用状态（临时加 token 无引用）报
	## warning；TILE 池同构；SKILL 白名单先例不变；BUFF_ambush 在
	## CHECKIN_ORPHAN_WHITELIST（占位预留语义）常态零警告
	var slow: StatusDef = _game_data.get_record(&"DEBUFF_slow") as StatusDef
	assert_object(slow).is_not_null()
	var sources_size: int = slow.allowed_sources.size()
	slow.allowed_sources.append(&"CHECKIN")
	var report: ValidationReport = DataValidator.run_all(_game_data)
	slow.allowed_sources.resize(sources_size)
	var checkin_orphan: bool = false
	for entry: String in report.warnings:
		if entry.begins_with("V-B2-status-src") and entry.contains("DEBUFF_slow") \
				and entry.contains("CHECKIN"):
			checkin_orphan = true
	assert_bool(checkin_orphan) \
			.override_failure_message("CHECKIN 零引用状态应报池孤儿 warning").is_true()
	# TILE 池同构：零地格引用的 TILE 来源状态报 warning
	var bewitch: StatusDef = _game_data.get_record(&"DEBUFF_bewitch") as StatusDef
	var bewitch_size: int = bewitch.allowed_sources.size()
	bewitch.allowed_sources.append(&"TILE")
	var tile_report: ValidationReport = DataValidator.run_all(_game_data)
	bewitch.allowed_sources.resize(bewitch_size)
	var tile_orphan: bool = false
	for entry: String in tile_report.warnings:
		if entry.begins_with("V-B2-status-src") and entry.contains("DEBUFF_bewitch") \
				and entry.contains("TILE"):
			tile_orphan = true
	assert_bool(tile_orphan) \
			.override_failure_message("TILE 零引用状态应报池孤儿 warning").is_true()
	# 白名单命中豁免：BUFF_ambush（CHECKIN 孤儿、白名单登记）常态零警告
	var after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(after.warnings.size()).is_equal(0)

func _HasWarning(report: ValidationReport, prefix: String, needle: String) -> bool:
	## 报告内按前缀+关键字匹配警告（S1-08 warning 级规则断言口）
	## 参数 report/prefix/needle：报告 / 规则前缀 / 关键字
	## 返回：true = 命中
	for entry: String in report.warnings:
		if entry.begins_with(prefix) and entry.contains(needle):
			return true
	return false

func test_v_r4_dead_content_reverse() -> void:
	## V-R4-dead-content（S1-07）：摘除 pack 引用 → 地图零引用 warning；
	## 职业摘 equip 覆盖 → warning（当前数据全健康，注入后命中、恢复后归零）
	var pack: EnemyPackDef = _game_data.get_record(&"enc_m1_lair_pack") as EnemyPackDef
	var original_map_ref: StringName = pack.battle_map_ref
	pack.battle_map_ref = &"btm_m1_random_8x8"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	pack.battle_map_ref = original_map_ref
	assert_bool(_HasWarning(report, "V-R4-dead-content", "btm_m1_lair")) \
			.override_failure_message("零 pack 引用地图应报死内容").is_true()
	var equip: EquipDef = _game_data.get_record(&"eqp_init_warrior") as EquipDef
	var original_class_ref: StringName = equip.class_ref
	equip.class_ref = &"cls_nope"
	var equip_report: ValidationReport = DataValidator.run_all(_game_data)
	equip.class_ref = original_class_ref
	assert_bool(_HasWarning(equip_report, "V-R4-dead-content", "cls_warrior")) \
			.override_failure_message("零 equip 覆盖职业应报死内容").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.warnings.size()).is_equal(0)

func test_v_r4_fog_lit_prefix_segment() -> void:
	## S1-09：fog_lit_rows 跳行（[0,1,2] → [0,2]）报 V-M3-fog-lit 前缀段错误
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	var original_rows: Array[int] = map_def.fog_lit_rows.duplicate()
	map_def.fog_lit_rows = [0, 2]
	var report: ValidationReport = DataValidator.run_all(_game_data)
	map_def.fog_lit_rows = original_rows
	assert_bool(_HasError(report, "V-M3-fog-lit", "前缀段")) \
			.override_failure_message("跳行 fog_lit_rows 应报前缀段错误").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_v_r4_asset_reverse_registered() -> void:
	## S1-10：registry 摘一条映射 → assets 资源文件未登记报 V-R4-asset-reverse；
	## _preview* 工具产物不报（白名单排除）
	var registry: AssetRegistry = _game_data.get_record(&"registry") as AssetRegistry
	var original_path: String = registry.mapping[&"spr_cls_warrior_idle"]
	registry.mapping.erase(&"spr_cls_warrior_idle")
	var report: ValidationReport = DataValidator.run_all(_game_data)
	registry.mapping[&"spr_cls_warrior_idle"] = original_path
	assert_bool(_HasError(report, "V-R4-asset-reverse", "spr_cls_warrior_idle")) \
			.override_failure_message("assets 文件摘登记应报未登记").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_v_r4_pack_elite_first() -> void:
	## S2-06：精英条目不在 entries[0]（后置）报 V-R4-pack-elite-first；
	## 生产 lair pack 精英首位常态零错误
	var pack: EnemyPackDef = _game_data.get_record(&"enc_m1_lair_pack") as EnemyPackDef
	var elite_index: int = -1
	for index: int in pack.entries.size():
		if pack.entries[index].is_elite:
			elite_index = index
	assert_int(elite_index).is_equal(0)
	# 注入：精英条目与非精英条目换位 → 后置精英报错
	var swapped: Array = pack.entries.duplicate()
	swapped.reverse()
	pack.entries = swapped
	var report: ValidationReport = DataValidator.run_all(_game_data)
	pack.entries = swapped.duplicate()
	pack.entries.reverse()
	assert_bool(_HasError(report, "V-R4-pack-elite-first", "enc_m1_lair_pack")) \
			.override_failure_message("后置精英条目应报首位约定破坏").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

# --------------------------------------------------------------------------
# M6 批 3.5a 方案一 naming 校验改造（domain 驱动分支重排——U1-U7；
# 真库注入-还原模式：注入后必须命中，还原后 run_all 零错误）
# --------------------------------------------------------------------------

func test_u1_assets_entry_with_mapping_passes() -> void:
	## U1 正例：资产条目（tile_mine_wall 生产条目）+ mapping 在档——摘除后
	## 报「registry 键无 naming 登记」，回填（注入）后全库零错误
	var naming: NamingRegistry = _game_data.get_record(&"naming_registry") as NamingRegistry
	assert_object(naming).is_not_null()
	var target: NamingEntry = null
	var kept: Array[NamingEntry] = []
	for entry: NamingEntry in naming.entries:
		if entry.resource_id == &"tile_mine_wall":
			target = entry
		else:
			kept.append(entry)
	assert_object(target).is_not_null()
	naming.entries = kept
	var missing_report: ValidationReport = DataValidator.run_all(_game_data)
	naming.entries.append(target)
	assert_bool(_HasError(missing_report, "V-B2-naming", "registry 键无 naming 登记")) \
			.override_failure_message("摘条目后应报 registry 键无登记").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_u2_assets_entry_without_mapping_reported() -> void:
	## U2 反例：assets 域条目未在 AssetRegistry mapping——注入临时条目必报；
	## 还原后归零
	var naming: NamingRegistry = _game_data.get_record(&"naming_registry") as NamingRegistry
	var entry := NamingEntry.new()
	entry.resource_id = &"tile_probe_unmapped"
	entry.domain = &"assets"
	entry.display_name = "探针条目"
	entry.rule_note = "测试注入"
	naming.entries.append(entry)
	var report: ValidationReport = DataValidator.run_all(_game_data)
	naming.entries.remove_at(naming.entries.size() - 1)
	assert_bool(_HasError(report, "V-B2-naming", "未在 AssetRegistry mapping")) \
			.override_failure_message("无 mapping 的资产条目应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_u3_data_entry_domain_mismatch_still_caught() -> void:
	## U3 反例：tile_normal 数据条目 domain 误改为 assets——数据身份优先
	## （分支一），报「域错配」而非资产分支文案（撞带解除的回归锚定）
	var naming: NamingRegistry = _game_data.get_record(&"naming_registry") as NamingRegistry
	var target: NamingEntry = null
	for entry: NamingEntry in naming.entries:
		if entry.resource_id == &"tile_normal":
			target = entry
			break
	assert_object(target).is_not_null()
	var original_domain: StringName = target.domain
	target.domain = &"assets"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	target.domain = original_domain
	assert_bool(_HasError(report, "V-B2-naming", "错配")) \
			.override_failure_message("数据条目误改 assets 应报域错配").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_u4_unknown_entry_guidance_message() -> void:
	## U4 反例：非数据记录、非 assets 域、非子资源前缀的未知条目——引导
	## 文案「资产条目请填 domain=&'assets'」；还原后归零
	var naming: NamingRegistry = _game_data.get_record(&"naming_registry") as NamingRegistry
	var entry := NamingEntry.new()
	entry.resource_id = &"bg_probe_wrong_domain"
	entry.domain = &"core"
	entry.display_name = "探针条目"
	entry.rule_note = "测试注入"
	naming.entries.append(entry)
	var report: ValidationReport = DataValidator.run_all(_game_data)
	naming.entries.remove_at(naming.entries.size() - 1)
	assert_bool(_HasError(report, "V-B2-naming", "资产条目请填 domain=&'assets'")) \
			.override_failure_message("未知条目应报引导文案").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_u5_assets_prefix_outside_legal_set() -> void:
	## U5 反例：assets 域条目前缀不在合法集（zzbad_ 前缀 + mapping 注入
	## 存在路径使 mapping 检查不触发——单锚前缀错误）；还原后归零
	var naming: NamingRegistry = _game_data.get_record(&"naming_registry") as NamingRegistry
	var registry: AssetRegistry = _game_data.get_record(&"registry") as AssetRegistry
	var entry := NamingEntry.new()
	entry.resource_id = &"zzbad_probe"
	entry.domain = &"assets"
	entry.display_name = "探针条目"
	entry.rule_note = "测试注入"
	naming.entries.append(entry)
	registry.mapping[&"zzbad_probe"] = "res://assets/bg/bg_guild_hall.png"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	naming.entries.remove_at(naming.entries.size() - 1)
	registry.mapping.erase(&"zzbad_probe")
	assert_bool(_HasError(report, "V-B2-naming", "不在资产前缀合法集")) \
			.override_failure_message("前缀漂移的资产条目应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_u6_registry_entry_no_false_positive() -> void:
	## U6 回归零误报：registry 自身条目（domain=assets 的数据记录）按数据身份
	## 走分支一——不被资产分支误报「未在 AssetRegistry mapping」（生产态
	## run_all 零错误即为锚定）
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report.errors.size()).is_equal(0)
	var naming_error: bool = false
	for entry: String in report.errors:
		if entry.contains("registry") and entry.contains("未在 AssetRegistry mapping"):
			naming_error = true
	assert_bool(naming_error) \
			.override_failure_message("registry 自身条目不应被资产分支误报").is_false()

func test_u7_registry_key_without_naming_entry() -> void:
	## U7 反例（加严③反向断言）：移除 bg_guild_hall naming 条目——registry
	## 键仍在而登记缺失，报「registry 键无 naming 登记」；还原后归零
	var naming: NamingRegistry = _game_data.get_record(&"naming_registry") as NamingRegistry
	var kept: Array[NamingEntry] = []
	var removed: NamingEntry = null
	for entry: NamingEntry in naming.entries:
		if entry.resource_id == &"bg_guild_hall":
			removed = entry
		else:
			kept.append(entry)
	assert_object(removed).is_not_null()
	naming.entries = kept
	var report: ValidationReport = DataValidator.run_all(_game_data)
	naming.entries.append(removed)
	assert_bool(_HasError(report, "V-B2-naming", "registry 键无 naming 登记")) \
			.override_failure_message("registry 键缺登记应报错（加严③）").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

# --------------------------------------------------------------------------
# M6 批 3.5a V-M6 接线机制组（tile-asset / class-icon / fac-bg——非空即查）
# --------------------------------------------------------------------------

func test_v_m6_tile_asset_ref_guard() -> void:
	## V-M6-tile-asset：asset_id/variants 非空即查——注入坏 id 必报；置空
	## 合法（占位过渡态不收紧——主键 asset_id 空）；恢复后归零
	var etile: ExploreTileDef = _game_data.get_record(&"etile_floor") as ExploreTileDef
	assert_object(etile).is_not_null()
	var original_asset: StringName = etile.asset_id
	var original_variants: Array[StringName] = etile.asset_variants.duplicate()
	etile.asset_id = &"tile_nope_unregistered"
	var asset_report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(asset_report, "V-M6-tile-asset", "etile_floor")) \
			.override_failure_message("坏 asset_id 应报错").is_true()
	etile.asset_id = original_asset
	etile.asset_variants = [&"zzbad_variant"]
	var variant_report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(variant_report, "V-M6-tile-asset", "etile_floor")) \
			.override_failure_message("坏 variants 项应报错").is_true()
	etile.asset_variants = original_variants
	var tile: TileTypeDef = _game_data.get_record(&"tile_obstacle") as TileTypeDef
	var original_tile_asset: StringName = tile.asset_id
	var original_tile_variants: Array[StringName] = tile.asset_variants.duplicate()
	tile.asset_id = &""
	tile.asset_variants = []
	var empty_report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(empty_report.errors.size()).is_equal(0)
	tile.asset_id = original_tile_asset
	tile.asset_variants = original_tile_variants
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_v_m6_tile_asset_empty_variant_element_reported() -> void:
	## 顺手3：asset_variants 数组内空串元素 = 数据错误必报（带下标定位）；
	## 与主键 asset_id 空 = 占位合法区分（正例：主键空+变体空列表零误报）；
	## 恢复后归零
	var etile: ExploreTileDef = _game_data.get_record(&"etile_floor") as ExploreTileDef
	assert_object(etile).is_not_null()
	var original_asset: StringName = etile.asset_id
	var original_variants: Array[StringName] = etile.asset_variants.duplicate()
	# 反例：变体位空串元素——数据错误
	etile.asset_variants = [&""]
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report, "V-M6-tile-asset", "为空串")) \
			.override_failure_message("asset_variants 空串元素应报错（数组空项 ≠ 主键空占位）").is_true()
	# 正例：主键空 + 变体空列表 = 占位合法（零误报——空项已删非空串驻留）
	etile.asset_variants = []
	etile.asset_id = &""
	var empty_report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(empty_report.errors.size()).is_equal(0)
	# 恢复归零
	etile.asset_id = original_asset
	etile.asset_variants = original_variants
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_assets_prefix_error_message_shows_raw_id() -> void:
	## 顺手1：无下划线 id（fontx）的前缀报错文案直接显示原 id + 合法前缀集
	## 说明——不再构造伪前缀『fontx_』误导排障；还原后归零
	var naming: NamingRegistry = _game_data.get_record(&"naming_registry") as NamingRegistry
	var registry: AssetRegistry = _game_data.get_record(&"registry") as AssetRegistry
	var entry := NamingEntry.new()
	entry.resource_id = &"fontx"
	entry.domain = &"assets"
	entry.display_name = "探针条目"
	entry.rule_note = "测试注入"
	naming.entries.append(entry)
	registry.mapping[&"fontx"] = "res://assets/bg/bg_guild_hall.png"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	naming.entries.remove_at(naming.entries.size() - 1)
	registry.mapping.erase(&"fontx")
	var hit: String = ""
	for err_text: String in report.errors:
		if err_text.begins_with("V-B2-naming") and err_text.contains("fontx"):
			hit = err_text
			break
	assert_bool(hit.is_empty()).override_failure_message("fontx 应触发前缀报错").is_false()
	assert_str(hit).contains("id 'fontx'")
	assert_bool(hit.contains("fontx_")).override_failure_message(
			"文案不得构造伪前缀 fontx_").is_false()
	assert_str(hit).contains("bg_")
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_v_m6_class_icon_ref_guard() -> void:
	## V-M6-class-icon：icon_id 非空即查——注入坏 id 必报；置空合法；恢复归零
	var cls: ClassDef = _game_data.get_record(&"cls_warrior") as ClassDef
	assert_object(cls).is_not_null()
	var original: StringName = cls.icon_id
	cls.icon_id = &"icon_class_nope"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report, "V-M6-class-icon", "cls_warrior")) \
			.override_failure_message("坏 icon_id 应报错").is_true()
	cls.icon_id = &""
	var empty_report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(empty_report.errors.size()).is_equal(0)
	cls.icon_id = original
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_v_m6_fac_bg_ref_guard() -> void:
	## V-M6-fac-bg：bg_asset_id 非空即查——注入坏 id 必报；置空合法；恢复归零
	var fac: FacilityDef = _game_data.get_record(&"fac_dormitory") as FacilityDef
	assert_object(fac).is_not_null()
	var original: StringName = fac.bg_asset_id
	fac.bg_asset_id = &"bg_nope_unregistered"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report, "V-M6-fac-bg", "fac_dormitory")) \
			.override_failure_message("坏 bg_asset_id 应报错").is_true()
	fac.bg_asset_id = &""
	var empty_report: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(empty_report.errors.size()).is_equal(0)
	fac.bg_asset_id = original
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

# --------------------------------------------------------------------------
# 校验器健壮性回归（2026-10-03 审计修复：行数缺口防护——rows 行数 < size.y
# 且出生位/点位 cell.y 落在缺口区间的坏地图须产出报告条目，不得越界崩溃）
# --------------------------------------------------------------------------

func test_rows_count_gap_battle_spawn_guard() -> void:
	## 行数缺口防护（V-M1-map-spawns 侧）：rows 截断至 2 行（< size.y 8）后
	## 我方出生位 y=7 落在缺口区间 → run_all 完整跑完不崩溃，坏数据产出
	## V-M1-map-layout 行数报告条目；恢复后归零
	var map_def: BattleMapDef = _game_data.get_record(&"btm_m1_random_8x8") as BattleMapDef
	assert_object(map_def).is_not_null()
	assert_int(map_def.size.y).is_greater(2)
	var original_rows: Array[String] = map_def.rows.duplicate()
	map_def.rows.resize(2)
	var report: ValidationReport = DataValidator.run_all(_game_data)
	map_def.rows = original_rows
	assert_bool(_HasError(report, "V-M1-map-layout", "rows 行数")) \
			.override_failure_message("行数缺口应产出 layout 报告条目而非校验器崩溃").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func test_rows_count_gap_explore_point_guard() -> void:
	## 行数缺口防护（V-M3-map-points 侧）：rows 截断至 3 行（< size.y 15）且
	## start_cell 改指缺口区间 (2, 10) → run_all 完整跑完不崩溃，坏数据产出
	## V-M3-map-layout 行数报告条目；恢复后归零
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	assert_object(map_def).is_not_null()
	assert_int(map_def.size.y).is_greater(10)
	var original_rows: Array[String] = map_def.rows.duplicate()
	var original_start: Vector2i = map_def.start_cell
	map_def.rows.resize(3)
	map_def.start_cell = Vector2i(2, 10)
	var report: ValidationReport = DataValidator.run_all(_game_data)
	map_def.rows = original_rows
	map_def.start_cell = original_start
	assert_bool(_HasError(report, "V-M3-map-layout", "rows 行数")) \
			.override_failure_message("行数缺口应产出 layout 报告条目而非校验器崩溃").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

