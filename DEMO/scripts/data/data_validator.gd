## 数据校验器（DataValidator，纯静态类）
## 职责：对 GameData 已加载的全库数据表跑 14 条 M0 校验规则 + 6 条 V-M1-* 战斗域
## 规则 + 1 条 V-M1-ref-asset 资源引用规则（错误阻断 / 警告非阻断），产出
## ValidationReport；供 tools/run_validation.gd（CI 退出码）与 gdUnit 断言消费。
## 数据来源：data/ 全域 .tres；规则口径=M0 批 2 方案（12 条规则展开为 14 个检查位）
## + M1 批 1 方案（V-M1-* 六条：地格状态绑定/地图布局/出生位/技能地格引用/
## 队伍地图引用加严/战斗域计数）+ 插队任务（V-M1-ref-asset：AssetRegistry
## 非空条目 path 必须文件存在——案 16 资源引用规范的落盘校验位）
## + 第四轮审计补强（2026-09-26：W4-15 V-M3-quest-reward 奖励量级带 /
## W5-6 V-M3-map-connectivity 图连通性 / W2-13 fog-region 一致性 /
## W4-06 chain-point 反向断言 / W2-6 普攻重复挂载 / W2-9 空敌清单 /
## W4-13 空揭示表 / W4-03 cfg 值域与 base_expedition_days 加严）。
## 用法：DataValidator.run_all(game_data)——game_data 为 GameData 自动加载单例或其实例。
class_name DataValidator
extends RefCounted

## 七属性 id 全集取值口（单源 AttrKeys.seven_attrs——批 4 C 组属性常量类；
## 校验 ref-skill-attr 用；const 表达式不支持函数调用，降为静态取值口）
static func _SevenAttrs() -> Array[StringName]:
	## 参数：无
	## 返回：七属性 id 全集
	return AttrKeys.seven_attrs()

## 叠加规则 token 值域（空=未指定）
const STACK_RULES: Array[StringName] = [&"no_stack_take_larger"]

## core 域 M0 固定资源白名单（id 前缀规则的例外表）
const CORE_WHITELIST: Array[StringName] = [CoreConfig.CFG_MAIN_ID, &"naming_registry"]

## assets 域固定资源白名单（盲审批 2 A-9：assets 域纳入校验遍历——仅 registry 一条）
const ASSETS_WHITELIST: Array[StringName] = [&"registry"]

## 敌人职能标记合法集取值口（单源 UnitTags.role_tags——批 4 C 组；
## 盲审批 2 A-7 口径：表值必须可被 BattleUnit/AI/UI 消费）
static func _EnemyRoleTags() -> Array[StringName]:
	## 参数：无
	## 返回：合法职能标记全集
	return UnitTags.role_tags()

## naming 前缀校验注册表（C-6：spr_/tend_ 等前缀特改数据驱动——
## 前缀 -> 附加校验类别（AssetRegistry 映射 / 职业倾向存在性））
const NAMING_PREFIX_CHECKS: Array = [
	{"prefix": "spr_", "check": &"asset_registry"},
	{"prefix": "tend_", "check": &"class_tendencies"},
]

## owner 为空的技能白名单（C-6 具名化：敌方通用普攻 skl_atk_enemy_common——
## 全敌人共用的普攻无单一归属职业/敌人，语义豁免）
const OWNER_EMPTY_WHITELIST: Array[StringName] = [&"skl_atk_enemy_common"]

## 预期孤儿状态白名单（盲审批 2 A-4②：allowed_sources 含 SKILL 但零技能
## 引用的豁免清单——【占位·完整版】检定带入技能未实现前的预留；当前全库
## SKILL 来源状态全部有技能引用，白名单为空集）
const SKILL_ORPHAN_WHITELIST: Array[StringName] = []

## GameConfig 脚本引用（SYSTEM_KEYS 常量——enabled_systems 键域校验消费；
## preload 脚本常量，headless 测试无 autoload 节点也可取）
const GameConfigScript: GDScript = preload("res://scripts/autoload/game_config.gd")

## 域 -> id 前缀规范（core/assets 域走白名单例外）
const DOMAIN_PREFIXES: Dictionary[StringName, Array] = {
	&"class/classes": [&"cls_"],
	&"class/skills": [&"skl_"],
	&"status/stats": [&"BUFF_", &"DEBUFF_"],
	&"status/mutex_groups": [&"mgrp_"],
	&"battle/enemies": [&"en_"],
	&"battle/enemy_packs": [&"enc_"],
	&"battle/maps": [&"btm_"],
	&"battle/tiles": [&"tile_"],
	&"equip": [&"eqp_"],
	&"event/chains": [&"chain_"],
	&"event/nodes": [&"evn_"],
	&"event/options": [&"opt_"],
	&"event/singles": [&"sp_"],
	&"event/hidden_marks": [&"hm_"],
	&"quest/templates": [&"q_"],
	# ---- M3 探索层六域 ----
	&"map/maps": [&"map_"],
	&"map/tiles": [&"etile_"],
	&"map/interact_points": [&"evp_"],
	&"map/target_points": [&"tp_"],
	&"map/encounter_weights": [&"encw_"],
	&"world/regions": [&"reg_"],
}

static func run_all(game_data: Node) -> ValidationReport:
	## 全库校验入口：M0/M1/批 A/批 2 规则顺序执行并返回报告
	## 参数 game_data：已完成扫描的 GameData 实例（autoload 或手动建树）
	## 返回：ValidationReport（零错误即通过；计数类问题为 warning）
	var report := ValidationReport.new()
	report.checked_count = _CountAll(game_data)
	# 装载问题转译（盲审批 2 A-9②：GameData 扫描层 issues（重复 id/类型域
	# 不匹配/坏 .tres）转 error——run_validation 单独跑坏文件不再绿灯；原
	# _CheckIdUniqueness 死规则删除：重复 id 在 GameData 层已 skip 并记
	# issues，转译后无信息丢失）
	for issue: String in game_data.issues:
		report.add_error("V-M0-load", "<loader>", issue)
	_CheckIdRequired(report, game_data)
	_CheckIdFilename(report, game_data)
	_CheckIdPrefix(report, game_data)
	_CheckEnumDomains(report, game_data)
	_CheckRefSkillStatus(report, game_data)
	_CheckRefSkillAttr(report, game_data)
	_CheckRefSkillOwner(report, game_data)
	_CheckRefClassAttack(report, game_data)
	_CheckRefEnemySkill(report, game_data)
	_CheckRefPack(report, game_data)
	_CheckRefMutex(report, game_data)
	_CheckNumericDomains(report, game_data)
	_CheckCounts(report, game_data)
	# ---- M1 批 1 新增（V-M1-* 六条）----
	_CheckTileStatus(report, game_data)
	_CheckMapLayout(report, game_data)
	_CheckMapSpawns(report, game_data)
	_CheckRefSkillTile(report, game_data)
	_CheckRefPackMap(report, game_data)
	_CheckBattleCounts(report, game_data)
	# ---- 插队任务新增（单位占位 sprite 资源登记）----
	_CheckRefAssetPath(report, game_data)
	# ---- 批 A 解耦整改新增（V-A-* 三条：地格视觉表驱动 / sprite_id 入表 /
	# 修正键合法集——2026-09-24）----
	_CheckTileVisual(report, game_data)
	_CheckSpriteIds(report, game_data)
	_CheckModKeys(report, game_data)
	# ---- 盲审批 2 新增（V-B2-* 七条 + 加严两条，2026-09-24）----
	_CheckEquipClassRef(report, game_data)
	_CheckNamingRegistry(report, game_data)
	_CheckStatusSources(report, game_data)
	_CheckOwnerClosure(report, game_data)
	_CheckCfgDomains(report, game_data)
	_CheckValueDomains(report, game_data)
	_CheckTileMatrix(report, game_data)
	# ---- 解耦复审 C 批新增（V-B2-cfg-fallback：兜底常量与表值一致性——C-3）----
	_CheckCfgFallbacks(report, game_data)
	# ---- 三轮复审新增（R1-5：AURA_3X3 技组合合法性）----
	_CheckAuraCombo(report, game_data)
	# ---- M2 批 1 新增（V-M2 八组：事件与检定域）----
	_CheckEventRefGraph(report, game_data)
	_CheckEventRefExit(report, game_data)
	_CheckEventRefBattle(report, game_data)
	_CheckEventRefQuest(report, game_data)
	_CheckEventNumDomain(report, game_data)
	_CheckEventFourTexts(report, game_data)
	_CheckEventCounts(report, game_data)
	# ---- M3 批 1 新增（V-M3 十一组：探索层域）+ V-5（2026-09-26 审计新增）----
	_CheckExploreMapLayout(report, game_data)
	_CheckExploreMapRegionCount(report, game_data)
	_CheckExploreMapPoints(report, game_data)
	_CheckExploreFogLit(report, game_data)
	_CheckExploreRefPointEvent(report, game_data)
	_CheckExploreRefChainPoint(report, game_data)
	_CheckExploreRefQuestGoal(report, game_data)
	_CheckExploreRefRegion(report, game_data)
	_CheckExploreSecretReveal(report, game_data)
	_CheckExploreHiddenMark(report, game_data)
	_CheckExploreEncwDomain(report, game_data)
	_CheckExploreTreasureDomain(report, game_data)
	_CheckExploreCounts(report, game_data)
	# ---- 第四轮审计新增（2026-09-26：W4-15 委托奖励量级带 / W5-6 图连通性）----
	_CheckQuestRewardDomain(report, game_data)
	_CheckExploreMapConnectivity(report, game_data)
	return report

# --------------------------------------------------------------------------
# 基础规则（必填 / 文件名一致 / 前缀规范）
# --------------------------------------------------------------------------

static func _CheckIdRequired(report: ValidationReport, game_data: Node) -> void:
	## V-M0-id-required：id 与 display_name 必填非空（无 display_name 的表只查 id）
	## 参数：报告 / GameData
	## 返回：无
	for domain: StringName in _AllDomains(game_data):
		for record_id: StringName in game_data.get_domain_ids(domain):
			var record: Resource = game_data.get_record(record_id)
			if record == null:
				continue
			if String(record_id).is_empty():
				report.add_error("V-M0-id-required", "<empty>",
						"域 '%s' 存在空 id 记录" % domain)
			if "display_name" in record and String(record.display_name).is_empty():
				report.add_error("V-M0-id-required", record_id, "display_name 为空")

static func _CheckIdFilename(report: ValidationReport, game_data: Node) -> void:
	## V-M0-id-filename：文件名 stem 必须等于资源 id
	## 参数：报告 / GameData
	## 返回：无
	for domain: StringName in _AllDomains(game_data):
		for record_id: StringName in game_data.get_domain_ids(domain):
			var stem: String = _RecordPath(game_data, record_id).get_file().get_basename()
			if stem != String(record_id):
				report.add_error("V-M0-id-filename", record_id,
						"文件名 '%s' 与 id 不一致" % stem)

static func _CheckIdPrefix(report: ValidationReport, game_data: Node) -> void:
	## V-M0-id-prefix：id 前缀符合域规范（core/assets 域走白名单——批 2 A-9）
	## 参数：报告 / GameData
	## 返回：无
	for domain: StringName in _AllDomains(game_data):
		for record_id: StringName in game_data.get_domain_ids(domain):
			if domain == &"core":
				if not CORE_WHITELIST.has(record_id):
					report.add_error("V-M0-id-prefix", record_id,
							"core 域仅允许白名单 id：%s" % str(CORE_WHITELIST))
				continue
			if domain == &"assets":
				if not ASSETS_WHITELIST.has(record_id):
					report.add_error("V-M0-id-prefix", record_id,
							"assets 域仅允许白名单 id：%s" % str(ASSETS_WHITELIST))
				continue
			var prefixes: Array = DOMAIN_PREFIXES.get(domain, [])
			var matched: bool = false
			for prefix: StringName in prefixes:
				if String(record_id).begins_with(String(prefix)):
					matched = true
					break
			if not matched:
				report.add_error("V-M0-id-prefix", record_id,
						"域 '%s' 的 id 前缀不符合规范 %s" % [domain, str(prefixes)])

# --------------------------------------------------------------------------
# 枚举值域
# --------------------------------------------------------------------------

static func _CheckEnumDomains(report: ValidationReport, game_data: Node) -> void:
	## V-M0-enum：枚举字段值域合法（int 越界）+ 来源/叠加/移除 token 值域
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		_CheckEnumRange(report, skill.id, "SkillDef.damage_type", skill.damage_type, SkillDef.DamageType.size() - 1)
		_CheckEnumRange(report, skill.id, "SkillDef.target_side", skill.target_side, SkillDef.TargetSide.size() - 1)
		_CheckEnumRange(report, skill.id, "SkillDef.target_shape", skill.target_shape, SkillDef.TargetShape.size() - 1)
		_CheckEnumRange(report, skill.id, "SkillDef.side", skill.side, SkillDef.SkillSide.size() - 1)
		_CheckEnumRange(report, skill.id, "SkillDef.resource_type", skill.resource_type, SkillDef.ResourceKind.size() - 1)
		for effect: SkillEffect in skill.effects:
			_CheckEnumRange(report, skill.id, "SkillEffect.effect_kind", effect.effect_kind, SkillEffect.EffectKind.size() - 1)
	for record: Resource in _DomainRecords(game_data, &"status/stats"):
		var status := record as StatusDef
		_CheckEnumRange(report, status.id, "StatusDef.category", status.category, StatusDef.Category.size() - 1)
		_CheckEnumRange(report, status.id, "StatusDef.polarity", status.polarity, StatusDef.Polarity.size() - 1)
		_CheckEnumRange(report, status.id, "StatusDef.control_kind", status.control_kind, StatusDef.ControlKind.size() - 1)
		_CheckEnumRange(report, status.id, "StatusDef.duration_type", status.duration_type, StatusDef.DurationType.size() - 1)
		if status.dot != null:
			_CheckEnumRange(report, status.id, "DotParams.mode", status.dot.mode, DotParams.Mode.size() - 1)
		for source: StringName in status.allowed_sources:
			if not StatusDef.allowed_source_tokens().has(source):
				report.add_error("V-M0-enum", status.id,
						"allowed_sources 含未知来源 token '%s'" % source)
		if not String(status.stack_rule).is_empty() and not STACK_RULES.has(status.stack_rule):
			report.add_error("V-M0-enum", status.id,
					"stack_rule 含未知 token '%s'" % status.stack_rule)
		if not String(status.remove_policy).is_empty() \
				and not StatusDef.remove_policies().has(status.remove_policy):
			report.add_error("V-M0-enum", status.id,
					"remove_policy 含未知 token '%s'" % status.remove_policy)
	for record: Resource in _DomainRecords(game_data, &"battle/enemies"):
		var enemy := record as EnemyDef
		_CheckEnumRange(report, enemy.id, "EnemyDef.race_tag", enemy.race_tag, EnemyDef.RaceTag.size() - 1)
	for record: Resource in _DomainRecords(game_data, &"battle/tiles"):
		var tile := record as TileTypeDef
		_CheckEnumRange(report, tile.id, "TileTypeDef.kind", tile.kind, TileTypeDef.Kind.size() - 1)
		_CheckEnumRange(report, tile.id, "TileTypeDef.trigger", tile.trigger, TileTypeDef.Trigger.size() - 1)
		_CheckEnumRange(report, tile.id, "TileTypeDef.style", tile.style, TileTypeDef.Style.size() - 1)
	# M3 探索层枚举值域（探索地格样式 / 交互点类别与触发方式）
	for record: Resource in _DomainRecords(game_data, &"map/tiles"):
		var etile := record as ExploreTileDef
		_CheckEnumRange(report, etile.id, "ExploreTileDef.style", etile.style, ExploreTileDef.Style.size() - 1)
	for record: Resource in _DomainRecords(game_data, &"map/interact_points"):
		var point := record as InteractPointDef
		_CheckEnumRange(report, point.id, "InteractPointDef.kind", point.kind, InteractPointDef.Kind.size() - 1)
		_CheckEnumRange(report, point.id, "InteractPointDef.trigger", point.trigger, InteractPointDef.Trigger.size() - 1)
	# V-A-class-attr（批 C M8）：法穿换算源表驱动字段必填且 ∈ 七属性
	for record: Resource in _DomainRecords(game_data, &"class/classes"):
		var cls := record as ClassDef
		if String(cls.mag_pierce_source_attr).is_empty():
			report.add_error("V-A-class-attr", cls.id, "mag_pierce_source_attr 为空")
		elif not _SevenAttrs().has(cls.mag_pierce_source_attr):
			report.add_error("V-A-class-attr", cls.id,
					"mag_pierce_source_attr '%s' 不在七属性集" % cls.mag_pierce_source_attr)

static func _CheckEnumRange(report: ValidationReport, record_id: StringName,
		field_name: String, value: int, max_value: int) -> void:
	## 枚举 int 值域检查（合法区间 [0, max_value]）
	## 参数：报告 / 资源 id / 字段名 / 枚举值 / 枚举最大序号
	## 返回：无
	if value < 0 or value > max_value:
		report.add_error("V-M0-enum", record_id,
				"%s 枚举值 %d 越界 [0, %d]" % [field_name, value, max_value])

# --------------------------------------------------------------------------
# 技能引用类规则
# --------------------------------------------------------------------------

static func _CheckRefSkillStatus(report: ValidationReport, game_data: Node) -> void:
	## V-M0-ref-skill-status：技能 STATUS_APPLY 效果引用的状态必须存在
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		for effect: SkillEffect in skill.effects:
			if effect.effect_kind != SkillEffect.EffectKind.STATUS_APPLY:
				continue
			if game_data.get_record(effect.status_id) == null:
				report.add_error("V-M0-ref-skill-status", skill.id,
						"引用状态 '%s' 不存在" % effect.status_id)

static func _CheckRefSkillAttr(report: ValidationReport, game_data: Node) -> void:
	## V-M0-ref-skill-attr：权重键∈七属性、权重非负、伤害技权重和=1.0±0.01
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		var weight_sum: float = 0.0
		for attr_id: StringName in skill.attr_weights:
			if not _SevenAttrs().has(attr_id):
				report.add_error("V-M0-ref-skill-attr", skill.id,
						"权重键 '%s' 不在七属性集" % attr_id)
			var weight: float = skill.attr_weights[attr_id]
			if weight < 0.0:
				report.add_error("V-M0-ref-skill-attr", skill.id,
						"权重键 '%s' 为负值 %f" % [attr_id, weight])
			weight_sum += weight
		if skill.damage_type != SkillDef.DamageType.NONE and not skill.attr_weights.is_empty():
			if absf(weight_sum - 1.0) > 0.01:
				report.add_error("V-M0-ref-skill-attr", skill.id,
						"伤害技权重和 %f 越界 1.0±0.01" % weight_sum)

static func _CheckRefSkillOwner(report: ValidationReport, game_data: Node) -> void:
	## V-M0-ref-skill-owner：owner 必须是已存在的职业/敌人 id（W4-04：as 类型
	## 断言——全域撞 id 的异类记录不放行，模式照 _CheckExploreRefPointEvent）；
	## skl_atk_enemy_common 的空 owner 为全库唯一放行；owner 为职业时 side 必须 ALLY
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		if String(skill.owner_id).is_empty():
			if not OWNER_EMPTY_WHITELIST.has(skill.id):
				report.add_error("V-M0-ref-skill-owner", skill.id,
						"owner 为空（仅 %s 放行——敌方通用普攻无单一归属者）" %
						str(OWNER_EMPTY_WHITELIST))
			continue
		var owner_class: ClassDef = game_data.get_record(skill.owner_id) as ClassDef
		var owner_enemy: EnemyDef = game_data.get_record(skill.owner_id) as EnemyDef
		if owner_class == null and owner_enemy == null:
			report.add_error("V-M0-ref-skill-owner", skill.id,
					"owner '%s' 不存在或非职业/敌人表" % skill.owner_id)
		elif owner_class != null and skill.side != SkillDef.SkillSide.ALLY:
			report.add_error("V-M0-ref-skill-owner", skill.id,
					"owner 为职业但 side != ALLY")

static func _CheckRefClassAttack(report: ValidationReport, game_data: Node) -> void:
	## V-M0-ref-class-atk：职业 base_attack_skill_id 存在、tier=0、
	## 且普攻权重表唯一键==该职业资源换算源属性（17 案 §3.4 D3 定稿口径）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"class/classes"):
		var cls := record as ClassDef
		var attack: SkillDef = game_data.get_record(cls.base_attack_skill_id) as SkillDef
		if attack == null:
			report.add_error("V-M0-ref-class-atk", cls.id,
					"内置普攻 '%s' 不存在" % cls.base_attack_skill_id)
			continue
		if attack.tier != 0:
			report.add_error("V-M0-ref-class-atk", cls.id,
					"内置普攻 '%s' tier != 0" % attack.id)
		if attack.attr_weights.size() != 1 or not attack.attr_weights.has(cls.resource_source_attr):
			report.add_error("V-M0-ref-class-atk", cls.id,
					"普攻权重表唯一键 != 职业资源换算源属性 '%s'" % cls.resource_source_attr)

static func _CheckRefEnemySkill(report: ValidationReport, game_data: Node) -> void:
	## V-M0-ref-enemy-skill：敌人技能引用闭合（skill_ids/common 均存在且为
	## 技能表——W4-04 as 类型断言）；skill_ids 不得重复挂通用普攻（W2-6——
	## 普攻位已单列 common_attack_skill_id，清单重复挂载导致 AI 技能选择双计）；
	## owner 为敌人的技能 side 必须 ENEMY
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"battle/enemies"):
		var enemy := record as EnemyDef
		for skill_id: StringName in enemy.skill_ids:
			if game_data.get_record(skill_id) as SkillDef == null:
				report.add_error("V-M0-ref-enemy-skill", enemy.id,
						"技能引用 '%s' 不存在或非技能表" % skill_id)
		if game_data.get_record(enemy.common_attack_skill_id) as SkillDef == null:
			report.add_error("V-M0-ref-enemy-skill", enemy.id,
					"通用普攻引用 '%s' 不存在或非技能表" % enemy.common_attack_skill_id)
		if enemy.skill_ids.has(enemy.common_attack_skill_id):
			report.add_error("V-M0-ref-enemy-skill", enemy.id,
					"skill_ids 不应重复挂载通用普攻 '%s'（普攻位单列）" % enemy.common_attack_skill_id)
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		var owner_enemy: EnemyDef = game_data.get_record(skill.owner_id) as EnemyDef \
				if not String(skill.owner_id).is_empty() else null
		if owner_enemy != null and skill.side != SkillDef.SkillSide.ENEMY:
			report.add_error("V-M0-ref-enemy-skill", skill.id,
					"owner 为敌人但 side != ENEMY")

static func _CheckRefPack(report: ValidationReport, game_data: Node) -> void:
	## V-M0-ref-pack：队伍条目敌人引用闭合；数量区间 1≤min≤max≤4；
	## W2-9：enemy_ids 非空（空候选 + count ≥1 会让装配侧 randi_range(0,-1)
	## 越界吞敌）（battle_map_ref 校验自 M1 批 1 起移入 V-M1-ref-pack-map 加严规则）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"battle/enemy_packs"):
		var pack := record as EnemyPackDef
		for entry: PackEntry in pack.entries:
			if entry.enemy_ids.is_empty():
				report.add_error("V-M0-ref-pack", pack.id,
						"条目 enemy_ids 为空（空候选装配越界——count ≥1 无兵可抽）")
				continue
			for enemy_id: StringName in entry.enemy_ids:
				if game_data.get_record(enemy_id) == null:
					report.add_error("V-M0-ref-pack", pack.id,
							"条目敌人引用 '%s' 不存在" % enemy_id)
			if entry.count_min < 1 or entry.count_min > entry.count_max or entry.count_max > 4:
				report.add_error("V-M0-ref-pack", pack.id,
						"数量区间非法（min=%d, max=%d，要求 1≤min≤max≤4）" % [entry.count_min, entry.count_max])

static func _CheckRefMutex(report: ValidationReport, game_data: Node) -> void:
	## V-M0-ref-mutex：互斥组双向一致——组员存在且组员.mutex_group_id 指回本组；
	## 状态.mutex_group_id 指向的组存在且包含该状态
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in game_data.get_domain(&"status/mutex_groups"):
		var group := record as MutexGroupDef
		for member_id: StringName in group.members:
			var member: StatusDef = game_data.get_record(member_id) as StatusDef
			if member == null:
				report.add_error("V-M0-ref-mutex", group.id,
						"组员状态 '%s' 不存在" % member_id)
			elif member.mutex_group_id != group.id:
				report.add_error("V-M0-ref-mutex", group.id,
						"组员 '%s' 的 mutex_group_id 未指回本组（='%s'）" % [member_id, member.mutex_group_id])
	for record: Resource in _DomainRecords(game_data, &"status/stats"):
		var status := record as StatusDef
		if String(status.mutex_group_id).is_empty():
			continue
		var group: MutexGroupDef = game_data.get_record(status.mutex_group_id) as MutexGroupDef
		if group == null:
			report.add_error("V-M0-ref-mutex", status.id,
					"互斥组 '%s' 不存在" % status.mutex_group_id)
		elif not group.members.has(status.id):
			report.add_error("V-M0-ref-mutex", status.id,
					"互斥组 '%s' 未包含本状态（双向不一致）" % status.mutex_group_id)

# --------------------------------------------------------------------------
# 数值域规则
# --------------------------------------------------------------------------

static func _CheckNumericDomains(report: ValidationReport, game_data: Node) -> void:
	## V-M0-num-domain：资源消耗≥0、射程∈[0,5]、职业/敌人移动力∈[1, move_base_cap]
	## （上限读 cfg_main.move_base_cap——批 B M2：移动力域与单位终值上限同源）、
	## 生命/系数为正、抗性∈[0,1]、敌人属性为正
	## 参数：报告 / GameData
	## 返回：无
	var move_cap: int = _MoveBaseCap(game_data)
	var range_max: int = _SkillRangeMax(game_data)
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		if skill.resource_cost < 0:
			report.add_error("V-M0-num-domain", skill.id,
					"资源消耗 %d 为负" % skill.resource_cost)
		if skill.range < 0 or skill.range > range_max:
			report.add_error("V-M0-num-domain", skill.id,
					"射程 %d 越界 [0, %d]" % [skill.range, range_max])
	for record: Resource in _DomainRecords(game_data, &"class/classes"):
		var cls := record as ClassDef
		if cls.move_range < 1 or cls.move_range > move_cap:
			report.add_error("V-M0-num-domain", cls.id,
					"移动力 %d 越界 [1, %d]" % [cls.move_range, move_cap])
		if cls.hp_coefficient <= 0.0:
			report.add_error("V-M0-num-domain", cls.id,
					"生命系数 %f 非正" % cls.hp_coefficient)
	for record: Resource in _DomainRecords(game_data, &"battle/enemies"):
		var enemy := record as EnemyDef
		if enemy.move_range < 1 or enemy.move_range > move_cap:
			report.add_error("V-M0-num-domain", enemy.id,
					"移动力 %d 越界 [1, %d]" % [enemy.move_range, move_cap])
		if enemy.hp <= 0:
			report.add_error("V-M0-num-domain", enemy.id,
					"生命 %d 非正" % enemy.hp)
		if enemy.resist_pct < 0.0 or enemy.resist_pct > 1.0:
			report.add_error("V-M0-num-domain", enemy.id,
					"抗性 %f 越界 [0, 1]" % enemy.resist_pct)
		for attr_id: StringName in enemy.attrs:
			if enemy.attrs[attr_id] <= 0:
				report.add_error("V-M0-num-domain", enemy.id,
						"属性 '%s' 值 %d 非正" % [attr_id, enemy.attrs[attr_id]])

# --------------------------------------------------------------------------
# 计数规则（warning 级）
# --------------------------------------------------------------------------

static func _CheckCounts(report: ValidationReport, game_data: Node) -> void:
	## V-M0-count：全库计数带校验（warning 级）——**带值读 cfg_main content_*
	## 组**（批 C M6：M2 加内容改表即可；cfg 缺省回退 M1 现值）
	## 参数：报告 / GameData
	## 返回：无
	var skills: Array = _DomainRecords(game_data, &"class/skills")
	var basic_attacks: int = 0
	var class_skills: int = 0
	var enemy_skills: int = 0
	var enemy_common: int = 0
	for record: Resource in skills:
		var skill := record as SkillDef
		if skill.id == &"skl_atk_enemy_common":
			enemy_common += 1
		elif String(skill.id).begins_with("skl_atk_"):
			basic_attacks += 1
		elif String(skill.id).begins_with("skl_enemy_"):
			enemy_skills += 1
		else:
			class_skills += 1
	_CheckCountBand(report, game_data, "<skills>", "content_skill_attacks",
			"六职业普攻", basic_attacks, 6)
	_CheckCountBand(report, game_data, "<skills>", "content_class_skills",
			"职业档 1 技能", class_skills, 12)
	_CheckCountBand(report, game_data, "<skills>", "content_enemy_skills",
			"敌方技能", enemy_skills, 4)
	_CheckCountBand(report, game_data, "<skills>", "content_enemy_common",
			"敌方通用普攻", enemy_common, 1)
	_CheckCountBand(report, game_data, "<status>", "content_status",
			"状态", game_data.get_domain_ids(&"status/stats").size(), 10)
	_CheckCountBand(report, game_data, "<enemies>", "content_enemies",
			"敌人", game_data.get_domain_ids(&"battle/enemies").size(), 3)
	_CheckCountBand(report, game_data, "<packs>", "content_packs",
			"敌方队伍", game_data.get_domain_ids(&"battle/enemy_packs").size(), 3)

# --------------------------------------------------------------------------
# M1 批 1 战斗域规则（V-M1-* 六条）
# --------------------------------------------------------------------------

static func _CheckTileStatus(report: ValidationReport, game_data: Node) -> void:
	## V-M1-tile-status：地格 status_id 非空时必须存在且目标状态 allowed_sources 含 TILE
	## （陷阱纯伤害地格 status_id 为空、跳过——第九轮拍板口径）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"battle/tiles"):
		var tile := record as TileTypeDef
		if String(tile.status_id).is_empty():
			continue
		var status: StatusDef = game_data.get_record(tile.status_id) as StatusDef
		if status == null:
			report.add_error("V-M1-tile-status", tile.id,
					"绑定状态 '%s' 不存在" % tile.status_id)
		elif not status.allowed_sources.has(&"TILE"):
			report.add_error("V-M1-tile-status", tile.id,
					"绑定状态 '%s' 的 allowed_sources 不含 TILE" % tile.status_id)

static func _CheckMapLayout(report: ValidationReport, game_data: Node) -> void:
	## V-M1-map-layout：地图 rows 行数 == size.y / 每行行长 == size.x /
	## 布局字符 ∈ legend / legend 值为已存在的地格 id / legend 必含 '.'
	## 空格图例（A-7——运行时 BattleGrid 兜底不再静默回退，表侧拦截缺项）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"battle/maps"):
		var map_def := record as BattleMapDef
		if not map_def.legend.has("."):
			report.add_error("V-M1-map-layout", map_def.id,
					"legend 缺 '.' 图例项（空格地格未定义——运行时不再静默回退）")
		if map_def.rows.size() != map_def.size.y:
			report.add_error("V-M1-map-layout", map_def.id,
					"rows 行数 %d != size.y %d" % [map_def.rows.size(), map_def.size.y])
		for row_index: int in map_def.rows.size():
			var row: String = map_def.rows[row_index]
			if row.length() != map_def.size.x:
				report.add_error("V-M1-map-layout", map_def.id,
						"第 %d 行行长 %d != size.x %d" % [row_index, row.length(), map_def.size.x])
				continue
			for row_char: String in row:
				if not map_def.legend.has(row_char):
					report.add_error("V-M1-map-layout", map_def.id,
							"布局字符 '%s' 不在 legend" % row_char)
		for legend_char: String in map_def.legend:
			var tile_id: StringName = map_def.legend[legend_char]
			if game_data.get_record(tile_id) == null:
				report.add_error("V-M1-map-layout", map_def.id,
						"legend 值 '%s'（字符 '%s'）不是已存在的地格 id" % [tile_id, legend_char])

static func _CheckMapSpawns(report: ValidationReport, game_data: Node) -> void:
	## V-M1-map-spawns：出生位界内 / 非障碍 / 不重复（我方+敌方联合查重）；
	## player_spawns ≥ 4 为 warning 级
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"battle/maps"):
		var map_def := record as BattleMapDef
		var seen_cells: Dictionary = {}
		# 外层不类型化（Array[Vector2i] 与 Array[Array] 之间无常变协变，Godot 类型化集合不变式）
		var spawn_lists: Array = [map_def.player_spawns, map_def.enemy_spawns]
		for spawn_list: Array in spawn_lists:
			for cell: Vector2i in spawn_list:
				if cell.x < 0 or cell.x >= map_def.size.x or cell.y < 0 or cell.y >= map_def.size.y:
					report.add_error("V-M1-map-spawns", map_def.id,
							"出生位 (%d, %d) 越界" % [cell.x, cell.y])
					continue
				var char_key: String = map_def.rows[cell.y][cell.x]
				var tile: TileTypeDef = game_data.get_record(map_def.legend.get(char_key, &"")) as TileTypeDef
				if tile == null or not tile.walkable:
					report.add_error("V-M1-map-spawns", map_def.id,
							"出生位 (%d, %d) 位于不可通行地格" % [cell.x, cell.y])
				if seen_cells.has(cell):
					report.add_error("V-M1-map-spawns", map_def.id,
							"出生位 (%d, %d) 重复" % [cell.x, cell.y])
				else:
					seen_cells[cell] = true
		if map_def.player_spawns.size() < 4:
			report.add_warning("V-M1-map-spawns", map_def.id,
					"player_spawns 数 %d < 4" % map_def.player_spawns.size())

static func _CheckRefSkillTile(report: ValidationReport, game_data: Node) -> void:
	## V-M1-ref-skill-tile：技能 TILE_SPAWN 效果的地格类型引用必须存在
	## （启用 M0 预留口——地格域 M1 批 1 落地后收紧）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		for effect: SkillEffect in skill.effects:
			if effect.effect_kind != SkillEffect.EffectKind.TILE_SPAWN:
				continue
			if game_data.get_record(effect.tile_type_id) == null:
				report.add_error("V-M1-ref-skill-tile", skill.id,
						"地格类型引用 '%s' 不存在" % effect.tile_type_id)

static func _CheckRefPackMap(report: ValidationReport, game_data: Node) -> void:
	## V-M1-ref-pack-map：敌方队伍 battle_map_ref 非空强制（error）且必须可解析
	## （M0 预留口加严：空 = error；地图域 M1 批 1 落地）；**批 2 A-3 再加严**：
	## 条目 count_max 总和 ≤ 引用地图 enemy_spawns 数（超容 battle_setup 会
	## 静默截断吞兵——error 拦截在数据侧）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"battle/enemy_packs"):
		var pack := record as EnemyPackDef
		if String(pack.battle_map_ref).is_empty():
			report.add_error("V-M1-ref-pack-map", pack.id,
					"battle_map_ref 为空（M1 起强制回填）")
			continue
		var map_def: BattleMapDef = game_data.get_record(pack.battle_map_ref) as BattleMapDef
		if map_def == null:
			report.add_error("V-M1-ref-pack-map", pack.id,
					"战场地图引用 '%s' 不存在" % pack.battle_map_ref)
			continue
		var max_total: int = 0
		for entry: PackEntry in pack.entries:
			max_total += entry.count_max
		if max_total > map_def.enemy_spawns.size():
			report.add_error("V-M1-ref-pack-map", pack.id,
					"条目 count_max 总和 %d 超地图敌方出生位 %d（运行时会静默截断吞兵）" % [
						max_total, map_def.enemy_spawns.size(),
					])

static func _CheckBattleCounts(report: ValidationReport, game_data: Node) -> void:
	## V-M1-count：战斗域计数带校验（warning 级）——带值读 cfg_main content_*
	## 组（批 C M6；cfg 缺省回退 M1 现值）
	## 参数：报告 / GameData
	## 返回：无
	_CheckCountBand(report, game_data, "<maps>", "content_maps",
			"战场地图", game_data.get_domain_ids(&"battle/maps").size(), 2, "V-M1-count")
	_CheckCountBand(report, game_data, "<tiles>", "content_tiles",
			"地格类型", game_data.get_domain_ids(&"battle/tiles").size(), 6, "V-M1-count")
	_CheckCountBand(report, game_data, "<equip>", "content_equip",
			"初始装备", game_data.get_domain_ids(&"equip").size(), 6, "V-M1-count")

static func _CheckCountBand(report: ValidationReport, game_data: Node, scope: String,
		field_prefix: String, label: String, count: int, fallback: int, code: String = "V-M0-count") -> void:
	## 计数带检查（cfg content_* 字段组读取——min/max 同值 = 恒定断言；
	## cfg 缺省回退 [fallback, fallback] 与 M1 现值一致）
	## 参数 report/game_data/scope/field_prefix/label/count/fallback：
	## 报告 / GameData / 作用域标签 / cfg 字段前缀 / 条目名 / 实际计数 / 回退定值
	## 返回：无
	var band: Vector2i = _CountBand(game_data, field_prefix, fallback)
	if count < band.x or count > band.y:
		report.add_warning(code, scope,
				"%s计数 %d 越界 [%d, %d]" % [label, count, band.x, band.y])

static func _CountBand(game_data: Node, field_prefix: String, fallback: int) -> Vector2i:
	## 取 cfg_main 的计数带（<prefix>_min/<prefix>_max）；W4-07 语义统一：
	## 字段**已设置且 ≥0** 即采用（负值 = 未设回退；字段缺失 null = 未设回退）——
	## 显式 0 是合法下界不再是「未设」，与 V-M0-cfg-domain 的 band 合法性
	## （min ≥ 0 且 min ≤ max）口径闭环；cfg 资源整体缺失回退 [fallback, fallback]
	## 参数 game_data：GameData；field_prefix：cfg 字段前缀；fallback：回退定值
	## 返回：Vector2i(min, max)
	var cfg: CoreConfig = game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var band_min: int = fallback
	var band_max: int = fallback
	if cfg != null:
		var raw_min: Variant = cfg.get(field_prefix + "_min")
		var raw_max: Variant = cfg.get(field_prefix + "_max")
		if raw_min != null and int(raw_min) >= 0:
			band_min = int(raw_min)
		if raw_max != null and int(raw_max) >= 0:
			band_max = int(raw_max)
	return Vector2i(band_min, band_max)

static func _CheckRefAssetPath(report: ValidationReport, game_data: Node) -> void:
	## V-M1-ref-asset：AssetRegistry 非空条目的 path 必须 res:// 开头且文件存在
	## （FileAccess 物理存在或 ResourceLoader 已导入任一命中即通过——兼容
	## headless 未 import 的工具环境与编辑器导入后的运行时环境双场景）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"assets"):
		var registry := record as AssetRegistry
		if registry == null:
			continue
		for asset_id: StringName in registry.mapping:
			var path: String = registry.mapping[asset_id]
			if path.is_empty():
				report.add_error("V-M1-ref-asset", asset_id, "path 为空")
				continue
			if not path.begins_with("res://"):
				report.add_error("V-M1-ref-asset", asset_id,
						"path '%s' 不以 res:// 开头" % path)
				continue
			if not (FileAccess.file_exists(path) or ResourceLoader.exists(path)):
				report.add_error("V-M1-ref-asset", asset_id,
						"path '%s' 文件不存在" % path)

# --------------------------------------------------------------------------
# 批 A 解耦整改规则（V-A-* 三条）
# --------------------------------------------------------------------------

static func _CheckAuraCombo(report: ValidationReport, game_data: Node) -> void:
	## V-M1-aura-combo（R1-5）：AURA_3X3 技能组合合法性——damage_type 必须 NONE
	## （DEMO 怒吼无伤害段；伤害型光环待需求出现时松绑）且 effects ⊆ STATUS_APPLY
	## （HEAL/TILE_SPAWN/COMBAT_MOD 对光环无消费通路）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		if skill.target_shape != SkillDef.TargetShape.AURA_3X3:
			continue
		_ReportAuraComboIssue(skill, report)

static func _ReportAuraComboIssue(skill: SkillDef, report: ValidationReport) -> void:
	## 单技 AURA 组合检查（R1-5 可测口：测试侧手造坏技能直调）
	## 参数 skill：技能定义；report：报告
	## 返回：无
	if skill.target_shape != SkillDef.TargetShape.AURA_3X3:
		return
	if skill.damage_type != SkillDef.DamageType.NONE:
		report.add_error("V-M1-aura-combo", skill.id,
				"AURA_3X3 技 damage_type 必须 NONE（当前 %d——DEMO 怒吼无伤害段）" % skill.damage_type)
	for effect: SkillEffect in skill.effects:
		if effect.effect_kind != SkillEffect.EffectKind.STATUS_APPLY:
			report.add_error("V-M1-aura-combo", skill.id,
					"AURA_3X3 技含无消费通路的效果类型 %d（仅允许 STATUS_APPLY）" % effect.effect_kind)

static func _CheckTileVisual(report: ValidationReport, game_data: Node) -> void:
	## V-A-tile-visual：地格视觉表驱动字段必填（批 A H2）——fill_color 非默认
	## 透明（alpha > 0）；style 为 RAISED/BLOCK 时 accent_color 必填；
	## ENEMY_ENTER_ONCE 陷阱类 mark_color 必填（S1-4：动态地格标记色入表）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"battle/tiles"):
		var tile := record as TileTypeDef
		if tile.fill_color.a <= 0.0:
			report.add_error("V-A-tile-visual", tile.id, "fill_color 未回填（alpha ≤ 0）")
		if tile.style != TileTypeDef.Style.PLAIN and tile.accent_color.a <= 0.0:
			report.add_error("V-A-tile-visual", tile.id,
					"style=%d 需要 accent_color 但未回填（alpha ≤ 0）" % tile.style)
		if tile.trigger == TileTypeDef.Trigger.ENEMY_ENTER_ONCE and tile.mark_color.a <= 0.0:
			report.add_error("V-A-tile-visual", tile.id,
					"ENEMY_ENTER_ONCE 触发类需要 mark_color 但未回填（alpha ≤ 0）")
		elif tile.id == &"tile_trap" and not tile.mark_color.is_equal_approx(
				BattleBoard.COLOR_TRAP_MARK_FALLBACK):
			# #8：陷阱标记色与 UI 兜底常量锚定（表值调色须同步 battle_board 兜底）
			report.add_error("V-A-tile-visual", tile.id,
					"mark_color %s != UI 兜底常量 %s（调表须同步）" % [
						str(tile.mark_color), str(BattleBoard.COLOR_TRAP_MARK_FALLBACK)])

static func _CheckSpriteIds(report: ValidationReport, game_data: Node) -> void:
	## V-A-sprite-id：职业/敌人表 sprite_id 非空且在 AssetRegistry 有登记
	## （批 A H3：sprite id 入表，路径仍走 AssetRegistry）
	## 参数：报告 / GameData
	## 返回：无
	var targets: Array = [_DomainRecords(game_data, &"class/classes"),
			_DomainRecords(game_data, &"battle/enemies")]
	for records: Array in targets:
		for record: Resource in records:
			var sprite_id: StringName = record.get("sprite_id")
			if String(sprite_id).is_empty():
				report.add_error("V-A-sprite-id", record.get("id"),
						"sprite_id 为空（批 A H3 起强制回填）")
				continue
			if game_data.get_asset_path(sprite_id).is_empty():
				report.add_error("V-A-sprite-id", record.get("id"),
						"sprite_id '%s' 未在 AssetRegistry 登记" % sprite_id)

static func _CheckModKeys(report: ValidationReport, game_data: Node) -> void:
	## V-A-mod-keys：修正键合法集校验（批 A H4）——StatusDef.modifiers 键 ∈
	## ModKeys.status_keys()（拼错键 = get_stat_mod 静默返 0，校验侧拦截）；
	## SkillEffect COMBAT_MOD 的 key ∈ ModKeys.combat_mod_keys()
	## 参数：报告 / GameData
	## 返回：无
	var legal_status_keys: Array[StringName] = ModKeys.status_keys()
	for record: Resource in _DomainRecords(game_data, &"status/stats"):
		var status := record as StatusDef
		for mod_key: StringName in status.modifiers:
			if not legal_status_keys.has(mod_key):
				report.add_error("V-A-mod-keys", status.id,
						"modifiers 键 '%s' 不在 ModKeys 合法集（拼错或未登记）" % mod_key)
	var legal_combat_keys: Array[StringName] = ModKeys.combat_mod_keys()
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		for effect: SkillEffect in skill.effects:
			if effect.effect_kind != SkillEffect.EffectKind.COMBAT_MOD:
				continue
			if not legal_combat_keys.has(effect.key):
				report.add_error("V-A-mod-keys", skill.id,
						"COMBAT_MOD 键 '%s' 不在 ModKeys 合法集" % effect.key)

# --------------------------------------------------------------------------
# 盲审批 2 校验补强（V-B2-* 七条——2026-09-24）
# --------------------------------------------------------------------------

static func _CheckEquipClassRef(report: ValidationReport, game_data: Node) -> void:
	## V-B2-eq-class（A-1）：装备 class_ref 存在且为 ClassDef（error）+ 每职业
	## 至多一条初始装备引用（唯一性 error）——原断链仅运行时静默按零装备装配
	## 参数：报告 / GameData
	## 返回：无
	var class_ref_counts: Dictionary = {}
	for record: Resource in _DomainRecords(game_data, &"equip"):
		var equip := record as EquipDef
		var owner: Resource = game_data.get_record(equip.class_ref)
		if owner == null or not owner is ClassDef:
			report.add_error("V-B2-eq-class", equip.id,
					"class_ref '%s' 不存在或非职业表" % equip.class_ref)
			continue
		class_ref_counts[equip.class_ref] = int(class_ref_counts.get(equip.class_ref, 0)) + 1
	for class_id: StringName in class_ref_counts:
		if int(class_ref_counts[class_id]) > 1:
			report.add_error("V-B2-eq-class", class_id,
					"职业有 %d 条初始装备引用（至多一条）" % int(class_ref_counts[class_id]))

static func _CheckNamingRegistry(report: ValidationReport, game_data: Node) -> void:
	## V-B2-naming（A-2）：登记表双向比对——①全库顶层资源 id 必须有登记条目
	## 且 domain 与实际所在域一致；②条目查重；③spr_ 条目须在 AssetRegistry
	## mapping；④tend_ 条目须存在于某职业表 tendencies；⑤其余前缀条目须为
	## 已知顶层 id（多登记拦截）
	## 参数：报告 / GameData
	## 返回：无
	var registry: NamingRegistry = game_data.get_record(&"naming_registry") as NamingRegistry
	if registry == null:
		report.add_error("V-B2-naming", &"naming_registry", "登记表资源缺失")
		return
	var asset_registry: AssetRegistry = game_data.get_record(&"registry") as AssetRegistry
	var tend_ids: Array[StringName] = []
	for record: Resource in _DomainRecords(game_data, &"class/classes"):
		var cls := record as ClassDef
		for tendency: TendencyDef in cls.tendencies:
			tend_ids.append(tendency.id)
	# 顶层 id -> 实际域映射
	var id_domains: Dictionary = {}
	for domain: StringName in _AllDomains(game_data):
		for record_id: StringName in game_data.get_domain_ids(domain):
			id_domains[record_id] = domain
	var registered: Dictionary = {}
	for entry: NamingEntry in registry.entries:
		if registered.has(entry.resource_id):
			report.add_error("V-B2-naming", entry.resource_id, "登记条目重复")
			continue
		registered[entry.resource_id] = true
		var rid: String = String(entry.resource_id)
		# C-6：前缀特判改注册表驱动（前缀 -> 校验类别；新增前缀类别只加一行）
		var prefix_rule: Dictionary = {}
		for rule: Dictionary in NAMING_PREFIX_CHECKS:
			if rid.begins_with(String(rule["prefix"])):
				prefix_rule = rule
				break
		if not prefix_rule.is_empty():
			var check_kind: StringName = prefix_rule["check"]
			if check_kind == &"asset_registry":
				if asset_registry == null or not asset_registry.mapping.has(entry.resource_id):
					report.add_error("V-B2-naming", entry.resource_id,
							"%s 登记未在 AssetRegistry mapping 中" % prefix_rule["prefix"])
			elif check_kind == &"class_tendencies":
				if not tend_ids.has(entry.resource_id):
					report.add_error("V-B2-naming", entry.resource_id,
							"%s 登记不存在于任何职业表 tendencies" % prefix_rule["prefix"])
		elif id_domains.has(entry.resource_id):
			if id_domains[entry.resource_id] != entry.domain:
				report.add_error("V-B2-naming", entry.resource_id,
						"登记域 '%s' 与实际所在域 '%s' 错配" % [
							entry.domain, id_domains[entry.resource_id],
						])
		else:
			report.add_error("V-B2-naming", entry.resource_id,
					"登记了不存在的资源（多登记/未知 id）")
	for record_id: StringName in id_domains:
		if not registered.has(record_id):
			report.add_error("V-B2-naming", record_id, "资源未登记命名表（漏登记）")

static func _CheckStatusSources(report: ValidationReport, game_data: Node) -> void:
	## V-B2-status-src（A-4）：①技能 STATUS_APPLY 引用的状态 allowed_sources
	## 必含 SKILL（error）；②allowed_sources 含 SKILL 的状态零技能引用 →
	## warning（意外孤儿；SKILL_ORPHAN_WHITELIST 豁免——【占位·完整版】预留，
	## 当前空集：全库 SKILL 来源状态均被技能引用）
	## 参数：报告 / GameData
	## 返回：无
	var skill_referenced: Dictionary = {}
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		for effect: SkillEffect in skill.effects:
			if effect.effect_kind != SkillEffect.EffectKind.STATUS_APPLY:
				continue
			var status: StatusDef = game_data.get_record(effect.status_id) as StatusDef
			if status == null:
				continue
			skill_referenced[status.id] = true
			if not status.allowed_sources.has(&"SKILL"):
				report.add_error("V-B2-status-src", status.id,
						"被技能 '%s' 引用但 allowed_sources 不含 SKILL" % skill.id)
	for record: Resource in _DomainRecords(game_data, &"status/stats"):
		var status := record as StatusDef
		if not status.allowed_sources.has(&"SKILL"):
			continue
		if not skill_referenced.has(status.id) and not SKILL_ORPHAN_WHITELIST.has(status.id):
			report.add_warning("V-B2-status-src", status.id,
					"allowed_sources 含 SKILL 但零技能引用（意外孤儿）")

static func _CheckOwnerClosure(report: ValidationReport, game_data: Node) -> void:
	## V-B2-owner（A-5）：①普攻 owner == 引用职业（error）；②owner 为敌人的
	## 技能须被其 skill_ids/common 回含（error）；③owner 为职业的 tier=0 技能
	## 未被任何职业 base_attack 引用 → warning（运行时不可达普攻）
	## 参数：报告 / GameData
	## 返回：无
	var base_attack_ids: Dictionary = {}
	for record: Resource in _DomainRecords(game_data, &"class/classes"):
		var cls := record as ClassDef
		base_attack_ids[cls.base_attack_skill_id] = cls.id
		var attack: SkillDef = game_data.get_record(cls.base_attack_skill_id) as SkillDef
		if attack != null and attack.owner_id != cls.id:
			report.add_error("V-B2-owner", attack.id,
					"普攻 owner '%s' != 引用职业 '%s'" % [attack.owner_id, cls.id])
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		if String(skill.owner_id).is_empty():
			continue
		# W4-04：as 类型断言半边补齐（全域撞 id 的异类记录不放行）
		var owner_enemy: EnemyDef = game_data.get_record(skill.owner_id) as EnemyDef
		var owner_class: ClassDef = game_data.get_record(skill.owner_id) as ClassDef
		if owner_enemy != null:
			if not owner_enemy.skill_ids.has(skill.id) \
					and owner_enemy.common_attack_skill_id != skill.id:
				report.add_error("V-B2-owner", skill.id,
						"owner 为敌人 '%s' 但其技能清单未回含本技能" % owner_enemy.id)
		elif owner_class != null and skill.tier == 0 and not base_attack_ids.has(skill.id):
			report.add_warning("V-B2-owner", skill.id,
					"owner 为职业的 tier=0 技能未被任何职业普攻位引用（运行时不可达）")

static func _CheckCfgDomains(report: ValidationReport, game_data: Node) -> void:
	## V-M0-cfg-domain（A-6）：总控配置值域——除数 > 0（防 NaN）、钳制带有序
	## 且 ∈ [0,1]、难度五档键集恰合、系统启用清单键域合法且全覆盖、公式/计数
	## 参数基本值域（批 B/M 系字段：正数 / 率值 (0,1] / 带序）
	## 参数：报告 / GameData
	## 返回：无
	var cfg: CoreConfig = game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	if cfg == null:
		report.add_error("V-M0-cfg-domain", CoreConfig.CFG_MAIN_ID, "总控配置缺失")
		return
	for divisor_name: String in ["attr_modifier_divisor", "crit_success_drop_divisor",
			"luck_floor_z_divisor"]:
		if int(cfg.get(divisor_name)) <= 0:
			report.add_error("V-M0-cfg-domain", CoreConfig.CFG_MAIN_ID,
					"%s ≤ 0（除零 NaN 风险）" % divisor_name)
	# M2 加严（检定幸运兜底一致性——案 17：骰 1 不兜而 Y/Z 同除数）：
	# luck_floor_y 必须 == luck_floor_z_divisor，两参数漂移即报错
	if cfg.luck_floor_y != cfg.luck_floor_z_divisor:
		report.add_error("V-M0-cfg-domain", CoreConfig.CFG_MAIN_ID,
				"luck_floor_y(%d) != luck_floor_z_divisor(%d)——幸运兜底两参数须同值" % [
					cfg.luck_floor_y, cfg.luck_floor_z_divisor])
	if cfg.hit_clamp_min < 0.0 or cfg.hit_clamp_max > 1.0 or cfg.hit_clamp_min > cfg.hit_clamp_max:
		report.add_error("V-M0-cfg-domain", CoreConfig.CFG_MAIN_ID,
				"命中钳制带 [%f, %f] 非法" % [cfg.hit_clamp_min, cfg.hit_clamp_max])
	var tiers: Array = ["极易", "容易", "普通", "困难", "极难"]
	if cfg.difficulty_tiers.size() != tiers.size():
		report.add_error("V-M0-cfg-domain", CoreConfig.CFG_MAIN_ID,
				"难度档数 %d != 5" % cfg.difficulty_tiers.size())
	for tier: String in tiers:
		if not cfg.difficulty_tiers.has(tier):
			report.add_error("V-M0-cfg-domain", CoreConfig.CFG_MAIN_ID, "难度档缺失 '%s'" % tier)
	var system_keys: Array[StringName] = GameConfigScript.SYSTEM_KEYS
	for sys_key: StringName in cfg.enabled_systems:
		if not system_keys.has(sys_key):
			report.add_error("V-M0-cfg-domain", CoreConfig.CFG_MAIN_ID,
					"enabled_systems 含未知系统键 '%s'" % sys_key)
	for sys_key: StringName in system_keys:
		if not cfg.enabled_systems.has(sys_key):
			report.add_error("V-M0-cfg-domain", CoreConfig.CFG_MAIN_ID,
					"enabled_systems 缺少系统键 '%s'（须全覆盖）" % sys_key)
	# 批 B/M 公式参数基本值域（W4-03 补：vision_radius / secret_door_trigger_radius /
	# crit_success_line_min / luck_floor_z_base——M3 探索层与检定域新入表字段）
	for positive_name: String in ["hp_base", "hp_con_mult", "pool_base", "pool_mult",
			"move_base_cap", "agility_move_bonus_line", "ai_roar_ally_count_line",
			"recruit_band_min", "recruit_band_max", "vision_radius",
			"secret_door_trigger_radius", "crit_success_line_min", "luck_floor_z_base"]:
		if int(cfg.get(positive_name)) <= 0:
			report.add_error("V-M0-cfg-domain", CoreConfig.CFG_MAIN_ID,
					"%s ≤ 0" % positive_name)
	if cfg.recruit_band_min > cfg.recruit_band_max:
		report.add_error("V-M0-cfg-domain", CoreConfig.CFG_MAIN_ID, "招募带 min > max")
	for rate_name: String in ["hit_base", "dodge_base", "attr_hit_weight",
			"attr_dodge_weight", "status_resist_base", "status_resist_weight",
			"resist_weight", "crit_base", "crit_luck_weight", "crit_agility_weight"]:
		var rate_value: float = float(cfg.get(rate_name))
		if rate_value <= 0.0 or rate_value > 1.0:
			report.add_error("V-M0-cfg-domain", CoreConfig.CFG_MAIN_ID,
					"%s = %f 越界 (0, 1]" % [rate_name, rate_value])
	if cfg.crit_mult_base < 1.0:
		report.add_error("V-M0-cfg-domain", CoreConfig.CFG_MAIN_ID,
				"crit_mult_base %f < 1.0" % cfg.crit_mult_base)
	for band_name: String in ["content_skill_attacks", "content_class_skills",
			"content_enemy_skills", "content_enemy_common", "content_status",
			"content_enemies", "content_packs", "content_maps", "content_tiles",
			"content_equip", "content_map_count", "content_interact_points",
			"content_target_points", "content_encounter_weights",
			"content_event_chains", "content_event_singles"]:
		var band_min: int = int(cfg.get(band_name + "_min"))
		var band_max: int = int(cfg.get(band_name + "_max"))
		if band_min < 0 or band_min > band_max:
			report.add_error("V-M0-cfg-domain", CoreConfig.CFG_MAIN_ID,
					"%s 计数带 [%d, %d] 非法" % [band_name, band_min, band_max])

static func _CheckValueDomains(report: ValidationReport, game_data: Node) -> void:
	## V-B2-value-domain（A-7）：值域盲位——职业 attr_ranges 每键下限 ≤ 上限；
	## 敌人 role_tag ∈ 合法集；状态 default_duration ≥ 0
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"class/classes"):
		var cls := record as ClassDef
		for attr_id: StringName in cls.attr_ranges:
			var bounds: Vector2i = cls.attr_ranges[attr_id]
			if bounds.x > bounds.y:
				report.add_error("V-B2-value-domain", cls.id,
						"属性 '%s' 区间下限 %d > 上限 %d" % [attr_id, bounds.x, bounds.y])
	for record: Resource in _DomainRecords(game_data, &"battle/enemies"):
		var enemy := record as EnemyDef
		if not _EnemyRoleTags().has(enemy.role_tag):
			report.add_error("V-B2-value-domain", enemy.id,
					"role_tag '%s' 不在合法集 %s" % [enemy.role_tag, str(_EnemyRoleTags())])
	for record: Resource in _DomainRecords(game_data, &"status/stats"):
		var status := record as StatusDef
		if status.default_duration < 0:
			report.add_error("V-B2-value-domain", status.id,
					"default_duration %d 为负" % status.default_duration)
	# cfg UI 视觉参数回填（S1-4：地格兜底色入表——alpha ≤ 0 = 未回填）
	var cfg: CoreConfig = game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	if cfg != null and cfg.ui_tile_fallback_color.a <= 0.0:
		report.add_error("V-B2-value-domain", CoreConfig.CFG_MAIN_ID,
				"ui_tile_fallback_color 未回填（alpha ≤ 0）")

static func _CheckCfgFallbacks(report: ValidationReport, game_data: Node) -> void:
	## V-B2-cfg-fallback（C-3 护栏）：全部代码兜底常量 == cfg_main 对应字段值——
	## 表值调整而兜底漏改（cfg 未注入路径行为分叉）在落盘校验侧即拦截。
	## 跨层口径特例：本规则引用 battle/adventurer/ui 层兜底常量做一致性断言
	## （校验器性质 = 跨层一致性工具；被引类不反向依赖校验器，无环）。
	## 参数：报告 / GameData
	## 返回：无
	var cfg: CoreConfig = game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	if cfg == null:
		return
	# int 域（字段名 -> 兜底常量）
	var int_pairs: Array = [
		["attr_modifier_offset", DerivedStats.ATTR_MODIFIER_OFFSET_FALLBACK],
		["attr_modifier_divisor", DerivedStats.ATTR_MODIFIER_DIVISOR_FALLBACK],
		["damage_floor", BattleRules.DAMAGE_FLOOR_FALLBACK],
		["move_base_cap", BattleUnit.MOVE_BASE_CAP_FALLBACK],
		["agility_move_bonus_line", BattleUnit.AGILITY_MOVE_BONUS_LINE_FALLBACK],
		["agility_move_bonus_amount", BattleUnit.AGILITY_MOVE_BONUS_AMOUNT_FALLBACK],
		["ai_roar_ally_count_line", EnemyAI.ROAR_ALLY_COUNT_LINE_FALLBACK],
		["status_stack_limit", StatusManager.STACK_LIMIT_FALLBACK],
		["hp_base", DerivedStats.HP_BASE_FALLBACK],
		["hp_con_mult", DerivedStats.HP_CON_MULT_FALLBACK],
		["pool_base", DerivedStats.POOL_BASE_FALLBACK],
		["pool_mult", DerivedStats.POOL_MULT_FALLBACK],
		["pierce_per_modifier", DerivedStats.PIERCE_PER_MODIFIER_FALLBACK],
		["armor_per_modifier", DerivedStats.ARMOR_PER_MODIFIER_FALLBACK],
		["skill_range_max", SKILL_RANGE_MAX_FALLBACK],
	]
	for pair: Array in int_pairs:
		var raw_int: Variant = cfg.get(pair[0])
		if not (raw_int is int):
			report.add_error("V-B2-cfg-fallback", CoreConfig.CFG_MAIN_ID,
					"%s 字段类型异常（期望 int，实际 %s）" % [pair[0], typeof(raw_int)])
			continue
		var table_value: int = raw_int
		if table_value != int(pair[1]):
			report.add_error("V-B2-cfg-fallback", CoreConfig.CFG_MAIN_ID,
					"%s 表值 %d != 兜底常量 %d（调表须同步兜底）" % [pair[0], table_value, int(pair[1])])
	# float 域（近似比较；R3-08：徽章低血阈值入列；M3：探索步进演出时长入列）
	var float_pairs: Array = [
		["ui_badge_hp_low_threshold", UiTheme.BADGE_HP_LOW_THRESHOLD],
		["ui_explore_move_step_seconds", UiTheme.EXPLORE_MOVE_STEP_SECONDS],
		["crit_mult_base", BattleRules.CRIT_MULT_BASE_FALLBACK],
		["crit_base", BattleRules.CRIT_BASE_FALLBACK],
		["crit_luck_weight", BattleRules.CRIT_LUCK_WEIGHT_FALLBACK],
		["crit_agility_weight", BattleRules.CRIT_AGILITY_WEIGHT_FALLBACK],
		["hit_clamp_min", BattleRules.HIT_CLAMP_MIN_FALLBACK],
		["hit_clamp_max", BattleRules.HIT_CLAMP_MAX_FALLBACK],
		["attr_hit_weight", DerivedStats.ATTR_HIT_WEIGHT_FALLBACK],
		["attr_dodge_weight", DerivedStats.ATTR_DODGE_WEIGHT_FALLBACK],
		["status_resist_base", DerivedStats.STATUS_RESIST_BASE_FALLBACK],
		["status_resist_weight", DerivedStats.STATUS_RESIST_WEIGHT_FALLBACK],
		["resist_weight", DerivedStats.RESIST_WEIGHT_FALLBACK],
		["hit_base", DerivedStats.HIT_BASE_FALLBACK],
		["dodge_base", DerivedStats.DODGE_BASE_FALLBACK],
	]
	for pair: Array in float_pairs:
		var raw_float: Variant = cfg.get(pair[0])
		if not (raw_float is float):
			report.add_error("V-B2-cfg-fallback", CoreConfig.CFG_MAIN_ID,
					"%s 字段类型异常（期望 float，实际 %s）" % [pair[0], typeof(raw_float)])
			continue
		var table_value_f: float = raw_float
		if not is_equal_approx(table_value_f, float(pair[1])):
			report.add_error("V-B2-cfg-fallback", CoreConfig.CFG_MAIN_ID,
					"%s 表值 %s != 兜底常量 %s（调表须同步兜底）" % [pair[0], str(table_value_f), str(pair[1])])
	# UI 颜色域（表值须回填且 == UiTheme 兜底常量）
	var color_pairs: Array = [
		["ui_tile_fallback_color", UiTheme.TILE_FALLBACK],
		["ui_result_defeat_color", UiTheme.RESULT_DEFEAT],
		["ui_result_retreat_color", UiTheme.RESULT_RETREAT],
		["ui_event_grade_crit_success_color", UiTheme.EVENT_GRADE_CRIT_SUCCESS],
		["ui_event_grade_success_color", UiTheme.EVENT_GRADE_SUCCESS],
		["ui_event_grade_failure_color", UiTheme.EVENT_GRADE_FAILURE],
		["ui_event_grade_crit_failure_color", UiTheme.EVENT_GRADE_CRIT_FAILURE],
		["ui_badge_hp_low_color", UiTheme.BADGE_HP_LOW],
		["ui_badge_hp_ok_color", UiTheme.BADGE_HP_OK],
		["ui_badge_bar_back_color", UiTheme.BADGE_BAR_BACK],
		["ui_badge_res_mana_color", UiTheme.BADGE_RES_MANA],
		["ui_badge_res_stamina_color", UiTheme.BADGE_RES_STAMINA],
		["ui_badge_fallback_ally_color", UiTheme.BADGE_FALLBACK_ALLY],
		["ui_badge_fallback_enemy_color", UiTheme.BADGE_FALLBACK_ENEMY],
		["ui_badge_bewitch_color", UiTheme.BADGE_BEWITCH],
		["ui_badge_preview_strip_color", UiTheme.BADGE_PREVIEW_STRIP],
		["ui_badge_preview_text_color", UiTheme.BADGE_PREVIEW_TEXT],
		["ui_badge_outline_color", UiTheme.BADGE_OUTLINE],
		["ui_card_buff_color", UiTheme.CARD_BUFF],
		["ui_card_debuff_color", UiTheme.CARD_DEBUFF],
		["ui_card_unknown_color", UiTheme.CARD_UNKNOWN],
		["ui_card_muted_color", UiTheme.CARD_MUTED],
		["ui_overlay_move_fill_color", UiTheme.OVERLAY_MOVE_FILL],
		["ui_overlay_move_border_color", UiTheme.OVERLAY_MOVE_BORDER],
		["ui_overlay_skill_fill_color", UiTheme.OVERLAY_SKILL_FILL],
		["ui_overlay_skill_border_color", UiTheme.OVERLAY_SKILL_BORDER],
		["ui_overlay_blocked_fill_color", UiTheme.OVERLAY_BLOCKED_FILL],
		["ui_overlay_blocked_border_color", UiTheme.OVERLAY_BLOCKED_BORDER],
		["ui_overlay_blocked_slash_color", UiTheme.OVERLAY_BLOCKED_SLASH],
		["ui_overlay_path_color", UiTheme.OVERLAY_PATH],
		["ui_overlay_confirm_color", UiTheme.OVERLAY_CONFIRM],
		["ui_log_system_color", UiTheme.LOG_SYSTEM],
		["ui_log_damage_color", UiTheme.LOG_DAMAGE],
		["ui_log_heal_color", UiTheme.LOG_HEAL],
		["ui_log_status_color", UiTheme.LOG_STATUS],
		["ui_log_move_color", UiTheme.LOG_MOVE],
		["ui_downed_modulate_color", UiTheme.DOWNED_MODULATE],
		["ui_highlight_gold_color", UiTheme.HIGHLIGHT_GOLD],
		["ui_panel_dark_color", UiTheme.PANEL_DARK],
		# M3 探索层配色（表值须回填且 == UiTheme 兜底常量）
		["ui_fog_unseen_color", UiTheme.FOG_UNSEEN],
		["ui_fog_dim_color", UiTheme.FOG_DIM],
		["ui_explore_party_color", UiTheme.EXPLORE_PARTY],
		["ui_explore_target_active_color", UiTheme.EXPLORE_TARGET_ACTIVE],
		["ui_explore_target_dim_color", UiTheme.EXPLORE_TARGET_DIM],
		["ui_explore_goal_banner_color", UiTheme.EXPLORE_GOAL_BANNER],
	]
	for pair: Array in color_pairs:
		var raw_color: Variant = cfg.get(pair[0])
		var table_color: Color = raw_color if raw_color is Color else Color(0, 0, 0, 0)
		if table_color.a <= 0.0:
			report.add_error("V-B2-cfg-fallback", CoreConfig.CFG_MAIN_ID,
					"%s 未回填（alpha ≤ 0）" % pair[0])
		elif not table_color.is_equal_approx(pair[1]):
			report.add_error("V-B2-cfg-fallback", CoreConfig.CFG_MAIN_ID,
					"%s 表值 %s != 兜底常量 %s（调表须同步兜底）" % [pair[0], str(table_color), str(pair[1])])
	# UI 字号档位（表值须回填且 == UiTheme 兜底档位）
	var font_pairs: Array = [
		["ui_font_size_display", UiTheme.FONT_DISPLAY],
		["ui_font_size_title", UiTheme.FONT_TITLE],
		["ui_font_size_heading", UiTheme.FONT_HEADING],
		["ui_font_size_subheading", UiTheme.FONT_SUBHEADING],
		["ui_font_size_large", UiTheme.FONT_LARGE],
		["ui_font_size_body", UiTheme.FONT_BODY],
		["ui_font_size_normal", UiTheme.FONT_NORMAL],
		["ui_font_size_small", UiTheme.FONT_SMALL],
		["ui_font_size_minor", UiTheme.FONT_MINOR],
	]
	for pair: Array in font_pairs:
		var raw_font: Variant = cfg.get(pair[0])
		var table_font: int = raw_font if raw_font is int else 0
		if table_font <= 0:
			report.add_error("V-B2-cfg-fallback", CoreConfig.CFG_MAIN_ID,
					"%s 未回填（≤ 0）" % pair[0])
		elif table_font != int(pair[1]):
			report.add_error("V-B2-cfg-fallback", CoreConfig.CFG_MAIN_ID,
					"%s 表值 %d != 兜底档位 %d（调表须同步兜底）" % [pair[0], table_font, int(pair[1])])
	# M2 演出时长完备性（非负）
	if float(cfg.get("ui_d20_roll_seconds")) < 0.0:
		report.add_error("V-B2-cfg-fallback", CoreConfig.CFG_MAIN_ID,
				"ui_d20_roll_seconds 为负")
	# 版本标签/演出延时（非锚定值：仅完备性——非空/正数）
	var raw_label: Variant = cfg.get("version_label")
	if not (raw_label is String) or String(raw_label).is_empty():
		report.add_error("V-B2-cfg-fallback", CoreConfig.CFG_MAIN_ID,
				"version_label 未回填（空串）")
	var raw_delay: Variant = cfg.get("ui_battle_delay_seconds")
	if (raw_delay is float and raw_delay < 0.0) or (raw_delay is int and raw_delay < 0):
		report.add_error("V-B2-cfg-fallback", CoreConfig.CFG_MAIN_ID,
				"ui_battle_delay_seconds 为负")

static func _CheckTileMatrix(report: ValidationReport, game_data: Node) -> void:
	## V-B2-tile-matrix（A-8）：地格三元联动矩阵——NORMAL/OBSTACLE 必空
	## status_id、STATUS+STANDING 必带、STATUS+ENEMY_ENTER_ONCE 允许空
	## （纯伤害陷阱口径）；TILE_SPAWN 技能效果 dot_attr_id ∈ 七属性
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"battle/tiles"):
		var tile := record as TileTypeDef
		var has_status: bool = not String(tile.status_id).is_empty()
		match tile.kind:
			TileTypeDef.Kind.NORMAL, TileTypeDef.Kind.OBSTACLE:
				if has_status:
					report.add_error("V-B2-tile-matrix", tile.id,
							"kind=%d 不应绑定 status_id '%s'" % [tile.kind, tile.status_id])
			TileTypeDef.Kind.STATUS:
				if tile.trigger == TileTypeDef.Trigger.STANDING and not has_status:
					report.add_error("V-B2-tile-matrix", tile.id,
							"STATUS+STANDING 必须绑定 status_id")
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		for effect: SkillEffect in skill.effects:
			if effect.effect_kind != SkillEffect.EffectKind.TILE_SPAWN:
				continue
			if not _SevenAttrs().has(effect.dot_attr_id):
				report.add_error("V-B2-tile-matrix", skill.id,
						"TILE_SPAWN dot_attr_id '%s' 不在七属性集" % effect.dot_attr_id)

# --------------------------------------------------------------------------
# 辅助
# --------------------------------------------------------------------------

## 技能射程上限兜底（= cfg_main.skill_range_max——C-8）
const SKILL_RANGE_MAX_FALLBACK: int = 5

static func _SkillRangeMax(game_data: Node) -> int:
	## 技能射程上限（读 cfg_main.skill_range_max——C-8 入表；缺省回退兜底常量）
	## 参数：GameData
	## 返回：上限值
	var cfg: CoreConfig = game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	return cfg.skill_range_max if cfg != null and cfg.skill_range_max > 0  \
			else SKILL_RANGE_MAX_FALLBACK

static func _MoveBaseCap(game_data: Node) -> int:
	## 移动力基准段上限（读 cfg_main.move_base_cap——批 B M2 与单位终值同源；
	## 缺省回退 6 与 cfg 表值一致）
	## 参数：GameData
	## 返回：上限值
	var cfg: CoreConfig = game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	return cfg.move_base_cap if cfg != null and cfg.move_base_cap > 0 \
			else BattleUnit.MOVE_BASE_CAP_FALLBACK

# --------------------------------------------------------------------------
# M2 事件与检定域（V-M2 八组）
# --------------------------------------------------------------------------

## 检定档名合法集（难度五档——与 cfg.difficulty_tiers 键集同源；运行时查表）
static func _TierNames(cfg: CoreConfig) -> Array:
	## 参数 cfg：总控配置
	## 返回：合法难度档名数组
	return cfg.difficulty_tiers.keys() if cfg != null else []

static func _CheckEventRefGraph(report: ValidationReport, game_data: Node) -> void:
	## V-M2-ref-graph：事件图引用——选项去向节点存在且**同链**（E10①）；
	## 链入口存在且属本链；检定选项双去向非空；*_to 与 *_outcome 互斥；
	## 孤儿选项报错（E10②）；检定链可达节点 outcome crit 档强制非空
	## （E10③）；节点 outcome 与 option_ids 混排禁止（E10④）
	## 参数：报告 / GameData
	## 返回：无
	var nodes: Dictionary = {}
	for record: Resource in _DomainRecords(game_data, &"event/nodes"):
		var node := record as EventNodeDef
		nodes[node.id] = node
	for record: Resource in _DomainRecords(game_data, &"event/chains"):
		var chain := record as EventChainDef
		var entry: EventNodeDef = nodes.get(chain.entry_node_id, null) as EventNodeDef
		if entry == null:
			report.add_error("V-M2-ref-graph", chain.id,
					"入口节点 '%s' 不存在" % chain.entry_node_id)
		elif entry.chain_id != chain.id:
			report.add_error("V-M2-ref-graph", chain.id,
					"入口节点 chain_id 与本链不一致（'%s'）" % chain.entry_node_id)
	var options: Dictionary = {}
	for record: Resource in _DomainRecords(game_data, &"event/options"):
		var option := record as EventOptionDef
		options[option.id] = option
		if option.success_to != &"" and option.success_outcome != null:
			report.add_error("V-M2-ref-graph", option.id,
					"success_to 与 success_outcome 互斥（同侧只允许一族）")
		if option.failure_to != &"" and option.failure_outcome != null:
			report.add_error("V-M2-ref-graph", option.id,
					"failure_to 与 failure_outcome 互斥")
		var success_ok: bool = option.success_to != &"" or option.success_outcome != null
		if not success_ok:
			report.add_error("V-M2-ref-graph", option.id, "成功去向双空（死路）")
		if option.kind == EventOptionDef.OptionKind.CHECK:
			var failure_ok: bool = option.failure_to != &"" or option.failure_outcome != null
			if not failure_ok:
				report.add_error("V-M2-ref-graph", option.id,
						"检定选项失败去向双空（失败也推进硬标准）")
			if String(option.check_attr_id).is_empty() or option.difficulty_tier.is_empty():
				report.add_error("V-M2-ref-graph", option.id,
						"检定选项缺属性或难度档名")
			elif not AttrKeys.seven_attrs().has(option.check_attr_id):
				report.add_error("V-M2-ref-graph", option.id,
						"检定属性 '%s' 不在七属性域" % option.check_attr_id)
		elif option.failure_to != &"" or option.failure_outcome != null:
			report.add_error("V-M2-ref-graph", option.id,
					"纯选择不允许失败去向（无检定无分流）")
		for target_id: StringName in [option.success_to, option.failure_to]:
			if target_id == &"":
				continue
			var target: EventNodeDef = nodes.get(target_id, null) as EventNodeDef
			if target == null:
				report.add_error("V-M2-ref-graph", option.id,
						"去向节点 '%s' 不存在" % target_id)
	# 检定链可达档位表（E10③）：node_id -> {&"crit_success"/&"crit_failure": true}
	# ——CHECK 选项 success_to 命中侧 crit_success 可达、failure_to 命中侧
	# crit_failure 可达（PURE 选项去向无档位语义不计）
	var crit_reach: Dictionary = {}
	for option_id: StringName in options:
		var option: EventOptionDef = options[option_id]
		if option.kind != EventOptionDef.OptionKind.CHECK:
			continue
		for pair: Array in [[option.success_to, &"crit_success"],
				[option.failure_to, &"crit_failure"]]:
			var target_id: StringName = pair[0]
			var side: StringName = pair[1]
			if target_id == &"":
				continue
			if not crit_reach.has(target_id):
				crit_reach[target_id] = {}
			crit_reach[target_id][side] = true
	# 节点侧：选项挂载存在（反向一致性）+ 去向同链（E10①）+ 混排禁止（E10④）
	# + 检定可达 crit 档强制非空（E10③）+ 孤儿选项收集
	var mounted_options: Dictionary = {}
	for node_id: StringName in nodes:
		var node: EventNodeDef = nodes[node_id]
		if node.outcome != null and not node.option_ids.is_empty():
			report.add_error("V-M2-ref-graph", node.id,
					"outcome 与 option_ids 混排（终端节点不带选项）")
		for option_id: StringName in node.option_ids:
			mounted_options[option_id] = true
			if not options.has(option_id):
				report.add_error("V-M2-ref-graph", node.id,
						"挂载选项 '%s' 不存在" % option_id)
				continue
			var mounted: EventOptionDef = options[option_id]
			for target_id: StringName in [mounted.success_to, mounted.failure_to]:
				if target_id == &"":
					continue
				var target: EventNodeDef = nodes.get(target_id, null) as EventNodeDef
				if target != null and target.chain_id != node.chain_id:
					# E10①：去向节点须与挂载节点同链（跨链去向 = 链图越界）
					report.add_error("V-M2-ref-graph", mounted.id,
							"去向节点 '%s' 与挂载节点不同链（'%s' != '%s'）" % [
									target_id, target.chain_id, node.chain_id])
		if node.outcome != null and crit_reach.has(node_id):
			var sides: Dictionary = crit_reach[node_id]
			for side: StringName in sides:
				if String(node.outcome.texts.get(side, "")).is_empty():
					report.add_error("V-M2-ref-graph", node.id,
							"检定链可达节点 outcome 缺 '%s' 档文本（E10③）" % side)
	# 孤儿选项（E10②）：无任何节点挂载
	for option_id: StringName in options:
		if not mounted_options.has(option_id):
			report.add_error("V-M2-ref-graph", option_id,
					"孤儿选项（无节点挂载——不可达）")

static func _CheckEventRefExit(report: ValidationReport, game_data: Node) -> void:
	## V-M2-ref-exit：出口类型值域——C/D 计数 == 0（DEMO 零实例口径）；
	## B 出口必带 battle.pack_id 与 battle.post_battle
	## 参数：报告 / GameData
	## 返回：无
	for outcome_pair: Array in _AllEventOutcomes(game_data):
		var owner_id: StringName = outcome_pair[0]
		var outcome: EventOutcomeDef = outcome_pair[1]
		if outcome.exit_kind == EventOutcomeDef.ExitKind.C \
				or outcome.exit_kind == EventOutcomeDef.ExitKind.D:
			report.add_error("V-M2-ref-exit", owner_id,
					"exit_kind=C/D（DEMO 零实例口径——拦截通路留引擎不留数据）")
		if outcome.exit_kind == EventOutcomeDef.ExitKind.B:
			if outcome.battle == null or String(outcome.battle.pack_id).is_empty():
				report.add_error("V-M2-ref-exit", owner_id, "B 出口缺 battle.pack_id")
			elif outcome.battle.post_battle == null:
				report.add_error("V-M2-ref-exit", owner_id, "B 出口缺 battle.post_battle（战后出口）")

static func _CheckEventRefBattle(report: ValidationReport, game_data: Node) -> void:
	## V-M2-ref-battle：B 出口战斗引用——pack_id ∈ enemy_packs；先手/分布
	## token 空串合法走默认、非空查值域（E11 放宽——对齐案 8「未填走默认」）；
	## initial_status_id ∈ status/stats 且 allowed_sources 含 CHECKIN 且
	## **禁控制类状态**（E2-10：定身/蛊惑经 CHECKIN 因 from_next_turn_only
	## + duration 1 完全空转）
	## 参数：报告 / GameData
	## 返回：无
	for outcome_pair: Array in _AllEventOutcomes(game_data):
		var owner_id: StringName = outcome_pair[0]
		var outcome: EventOutcomeDef = outcome_pair[1]
		if outcome.battle == null:
			continue
		var battle := outcome.battle
		if game_data.get_record(battle.pack_id) as EnemyPackDef == null:
			report.add_error("V-M2-ref-battle", owner_id,
					"pack_id '%s' 不在 enemy_packs 域" % battle.pack_id)
		if String(battle.first_strike_token) != "" \
				and not [&"ally_first", &"enemy_first"].has(battle.first_strike_token):
			report.add_error("V-M2-ref-battle", owner_id,
					"first_strike_token '%s' 不在值域" % battle.first_strike_token)
		if String(battle.enemy_layout_token) != "" \
				and not [&"clustered", &"spread"].has(battle.enemy_layout_token):
			report.add_error("V-M2-ref-battle", owner_id,
					"enemy_layout_token '%s' 不在值域" % battle.enemy_layout_token)
		if not String(battle.initial_status_id).is_empty():
			var status: StatusDef = game_data.get_record(battle.initial_status_id) as StatusDef
			if status == null:
				report.add_error("V-M2-ref-battle", owner_id,
						"initial_status_id '%s' 不在 status/stats 域" % battle.initial_status_id)
			elif not status.allowed_sources.has(StatusDef.source_kind_token(
					StatusInstance.SourceKind.CHECKIN)):
				report.add_error("V-M2-ref-battle", owner_id,
						"initial_status_id 的 allowed_sources 不含 CHECKIN")
			elif status.control_kind != StatusDef.ControlKind.NONE:
				# E2-10：控制类状态经 CHECKIN 载入不生效（from_next_turn_only +
				# duration 1 开局即过期）——配置层拦截
				report.add_error("V-M2-ref-battle", owner_id,
						"initial_status_id '%s' 为控制类状态（CHECKIN 载入空转——禁用）" % [
								battle.initial_status_id])

static func _CheckEventRefQuest(report: ValidationReport, game_data: Node) -> void:
	## V-M2-ref-quest：授予委托引用——grant_quest_id ∈ quest/templates 且
	## 模板 acquire_channel == EVENT_GRANT（事件授予专用口径 18-C3）
	## 参数：报告 / GameData
	## 返回：无
	for outcome_pair: Array in _AllEventOutcomes(game_data):
		var owner_id: StringName = outcome_pair[0]
		var outcome: EventOutcomeDef = outcome_pair[1]
		if String(outcome.grant_quest_id).is_empty():
			continue
		var quest: QuestTemplateDef = game_data.get_record(outcome.grant_quest_id) as QuestTemplateDef
		if quest == null:
			report.add_error("V-M2-ref-quest", owner_id,
					"grant_quest_id '%s' 不在 quest/templates 域" % outcome.grant_quest_id)
		elif quest.acquire_channel != QuestTemplateDef.AcquireChannel.EVENT_GRANT:
			report.add_error("V-M2-ref-quest", owner_id,
					"授予委托 '%s' 的 acquire_channel != EVENT_GRANT" % quest.id)

static func _CheckEventNumDomain(report: ValidationReport, game_data: Node) -> void:
	## V-M2-num-domain：事件数值域——exp ∈ [10,20] / gold ∈ [5,30] / reputation
	## ∈ [0,2] / cost_days ∈ {0,1} / party_hp_delta ∈ [−10,0] / 难度档名 ∈ cfg 键集
	## 参数：报告 / GameData
	## 返回：无
	var cfg: CoreConfig = game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var tier_names: Array = _TierNames(cfg)
	for outcome_pair: Array in _AllEventOutcomes(game_data):
		var owner_id: StringName = outcome_pair[0]
		var outcome: EventOutcomeDef = outcome_pair[1]
		if outcome.reward != null:
			if outcome.reward.exp != 0 and (outcome.reward.exp < 10 or outcome.reward.exp > 20):
				report.add_error("V-M2-num-domain", owner_id,
						"exp %d 越界 [10,20]" % outcome.reward.exp)
			if outcome.reward.gold != 0 and (outcome.reward.gold < 5 or outcome.reward.gold > 30):
				report.add_error("V-M2-num-domain", owner_id,
						"gold %d 越界 [5,30]" % outcome.reward.gold)
			if outcome.reward.reputation < 0 or outcome.reward.reputation > 2:
				report.add_error("V-M2-num-domain", owner_id,
						"reputation %d 越界 [0,2]" % outcome.reward.reputation)
	for record: Resource in _DomainRecords(game_data, &"event/options"):
		var option := record as EventOptionDef
		if option.cost_days != 0 and option.cost_days != 1:
			report.add_error("V-M2-num-domain", option.id,
					"cost_days %d 越界 {0,1}（DEMO 档）" % option.cost_days)
		if not tier_names.is_empty() and not option.difficulty_tier.is_empty() \
				and not tier_names.has(option.difficulty_tier):
			report.add_error("V-M2-num-domain", option.id,
					"难度档名 '%s' 不在 cfg 键集" % option.difficulty_tier)
		for modifier: EventModifierDef in [option.crit_modifier, option.crit_fail_modifier]:
			if modifier != null and (modifier.party_hp_delta < -10 or modifier.party_hp_delta > 0):
				report.add_error("V-M2-num-domain", option.id,
						"party_hp_delta %d 越界 [-10,0]" % modifier.party_hp_delta)
	for record: Resource in _DomainRecords(game_data, &"event/singles"):
		var single := record as SingleEventDef
		if not tier_names.is_empty() and not single.difficulty_tier.is_empty() \
				and not tier_names.has(single.difficulty_tier):
			report.add_error("V-M2-num-domain", single.id,
					"难度档名 '%s' 不在 cfg 键集" % single.difficulty_tier)
		for modifier: EventModifierDef in [single.crit_modifier, single.crit_fail_modifier]:
			if modifier != null and (modifier.party_hp_delta < -10 or modifier.party_hp_delta > 0):
				report.add_error("V-M2-num-domain", single.id,
						"party_hp_delta %d 越界 [-10,0]" % modifier.party_hp_delta)

static func _CheckEventFourTexts(report: ValidationReport, game_data: Node) -> void:
	## V-M2-four-texts：四档文本——success/failure 非空（全出口）；链内出口
	## crit_success/crit_failure 必填、单点出口可空（案 18 §2.4 放宽）
	## 参数：报告 / GameData
	## 返回：无
	# 四档严格域 = 检定选项的直接出口（双档分流配四档文本）；纯选择出口与
	# 节点/单点出口仅要求 success/failure 非空（无检定无四档语义——B 演出
	# 节点的 crit 档位由选项侧 modifier 承载）
	for record: Resource in _DomainRecords(game_data, &"event/options"):
		var option := record as EventOptionDef
		var strict: bool = option.kind == EventOptionDef.OptionKind.CHECK
		if option.success_outcome != null:
			_ReportOutcomeTextGaps(option.id, option.success_outcome, strict, report)
		if option.failure_outcome != null:
			_ReportOutcomeTextGaps(option.id, option.failure_outcome, strict, report)
	for record: Resource in _DomainRecords(game_data, &"event/nodes"):
		var node := record as EventNodeDef
		if node.outcome != null:
			_ReportOutcomeTextGaps(node.id, node.outcome, false, report)
	for record: Resource in _DomainRecords(game_data, &"event/singles"):
		var single := record as SingleEventDef
		if single.success_outcome != null:
			_ReportOutcomeTextGaps(single.id, single.success_outcome, false, report)
		if single.failure_outcome != null:
			_ReportOutcomeTextGaps(single.id, single.failure_outcome, false, report)

static func _ReportOutcomeTextGaps(owner_id: StringName, outcome: EventOutcomeDef,
		chain_strict: bool, report: ValidationReport) -> void:
	## 单出口文本档位检查（可测口）
	## 参数 owner_id：归属资源 id；outcome：出口；chain_strict：链内严格（crit 必填）；
	## report：报告
	## 返回：无
	for key: StringName in [&"success", &"failure"]:
		if String(outcome.texts.get(key, "")).is_empty():
			report.add_error("V-M2-four-texts", owner_id, "texts 缺 '%s' 档" % key)
	if chain_strict:
		for key: StringName in [&"crit_success", &"crit_failure"]:
			if String(outcome.texts.get(key, "")).is_empty():
				report.add_error("V-M2-four-texts", owner_id,
						"链内出口缺 '%s' 档（四档必填）" % key)

static func _CheckEventCounts(report: ValidationReport, game_data: Node) -> void:
	## V-M2-counts：事件域计数带（cfg content_event_*——链 3/单点 3 恒定断言）
	## 参数：报告 / GameData
	## 返回：无
	var cfg: CoreConfig = game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	if cfg == null:
		return
	var chain_count: int = _DomainRecords(game_data, &"event/chains").size()
	if chain_count < cfg.content_event_chains_min or chain_count > cfg.content_event_chains_max:
		report.add_error("V-M2-counts", &"<event/chains>",
				"链计数 %d 越界 [%d,%d]" % [chain_count,
						cfg.content_event_chains_min, cfg.content_event_chains_max])
	var single_count: int = _DomainRecords(game_data, &"event/singles").size()
	if single_count < cfg.content_event_singles_min or single_count > cfg.content_event_singles_max:
		report.add_error("V-M2-counts", &"<event/singles>",
				"单点计数 %d 越界 [%d,%d]" % [single_count,
						cfg.content_event_singles_min, cfg.content_event_singles_max])

static func _AllEventOutcomes(game_data: Node) -> Array:
	## 全库事件出口枚举（节点 outcome / 选项 success/failure outcome / 单点
	## 双 outcome——校验遍历共用口；元素 [owner_id, EventOutcomeDef]）
	## 参数：GameData
	## 返回：出口对列表
	var pairs: Array = []
	for record: Resource in _DomainRecords(game_data, &"event/nodes"):
		var node := record as EventNodeDef
		if node.outcome != null:
			pairs.append([node.id, node.outcome])
	for record: Resource in _DomainRecords(game_data, &"event/options"):
		var option := record as EventOptionDef
		if option.success_outcome != null:
			pairs.append([option.id, option.success_outcome])
		if option.failure_outcome != null:
			pairs.append([option.id, option.failure_outcome])
	for record: Resource in _DomainRecords(game_data, &"event/singles"):
		var single := record as SingleEventDef
		if single.success_outcome != null:
			pairs.append([single.id, single.success_outcome])
		if single.failure_outcome != null:
			pairs.append([single.id, single.failure_outcome])
	return pairs

# --------------------------------------------------------------------------
# M3 探索层域（V-M3 十一组 + 计数带）
# --------------------------------------------------------------------------

static func _CheckExploreMapLayout(report: ValidationReport, game_data: Node) -> void:
	## V-M3-map-layout：探索图布局——rows 行数 == size.y / 每行行长 == size.x /
	## 布局字符 ∈ legend / legend 值为已存在的探索地格 id / legend 必含 '.'；
	## W4-03：base_expedition_days ≥ 1（耗时基准唯一权威——0/负值会让
	## total_days 归零起步，探索白嫖）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"map/maps"):
		var map_def := record as ExploreMapDef
		if not map_def.legend.has(&"."):
			report.add_error("V-M3-map-layout", map_def.id,
					"legend 缺 '.' 图例项（空格地格未定义）")
		if map_def.base_expedition_days < 1:
			report.add_error("V-M3-map-layout", map_def.id,
					"base_expedition_days %d < 1（耗时基准非法）" % map_def.base_expedition_days)
		if map_def.rows.size() != map_def.size.y:
			report.add_error("V-M3-map-layout", map_def.id,
					"rows 行数 %d != size.y %d" % [map_def.rows.size(), map_def.size.y])
		for row_index: int in map_def.rows.size():
			var row: String = map_def.rows[row_index]
			if row.length() != map_def.size.x:
				report.add_error("V-M3-map-layout", map_def.id,
						"第 %d 行行长 %d != size.x %d" % [row_index, row.length(), map_def.size.x])
				continue
			for row_char: String in row:
				if not map_def.legend.has(StringName(row_char)):
					report.add_error("V-M3-map-layout", map_def.id,
							"布局字符 '%s' 不在 legend" % row_char)
		for legend_char: StringName in map_def.legend:
			var tile_id: StringName = map_def.legend[legend_char]
			if game_data.get_record(tile_id) == null:
				report.add_error("V-M3-map-layout", map_def.id,
						"legend 值 '%s'（字符 '%s'）不是已存在的探索地格 id" % [tile_id, legend_char])

static func _CheckExploreMapRegionCount(report: ValidationReport, game_data: Node) -> void:
	## V-M3-map-region-count（V-5 2026-09-26 审计）：region_ids 数量 ≤ 2——
	## DEMO 口径冻结（两段语义：全亮行段 [0] + 其余 [1]，ExploreMapState.
	## region_index_of 的下标推导与遭遇权重查表均按此假设）；超界报错
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"map/maps"):
		var map_def := record as ExploreMapDef
		if map_def.region_ids.size() > 2:
			report.add_error("V-M3-map-region-count", map_def.id,
					"region_ids 数量 %d 超出 DEMO 冻结口径 ≤ 2（两段下标推导假设被破坏）"
					% map_def.region_ids.size())

static func _CheckExploreMapPoints(report: ValidationReport, game_data: Node) -> void:
	## V-M3-map-points：点位坐标——交互点/目标点界内 + 非障碍 + 全域坐标查重
	## （含 start_cell——同格双语义拦截）；DEMO 单图口径：多图时点位归属字段
	## 未定（M4 多图时点表须加 map_ref），>1 图报 warning 后跳过界内校验
	## 参数：报告 / GameData
	## 返回：无
	var maps: Array[Resource] = _DomainRecords(game_data, &"map/maps")
	if maps.is_empty():
		return
	if maps.size() > 1:
		# W4-02：warning 后即 return（原仅警告不返回——maps[0] 单图口径在多图
		# 数据下越权校验他图点位坐标）
		report.add_warning("V-M3-map-points", &"<map/maps>",
				"多图点位归属字段未定（%d 图）——跳过界内/障碍校验" % maps.size())
		return
	var map_def: ExploreMapDef = maps[0] as ExploreMapDef
	var seen_cells: Dictionary = {}
	if in_bounds_cell(map_def, map_def.start_cell):
		_RegisterPointCell(report, seen_cells, map_def.id, map_def.start_cell)
		# M1（质检补）：出生格非障碍断言——出生在墙上 = 进图即死格
		_CheckExplorePointCell(report, game_data, map_def, map_def.id, map_def.start_cell)
	else:
		report.add_error("V-M3-map-points", map_def.id,
				"start_cell (%d, %d) 越界" % [map_def.start_cell.x, map_def.start_cell.y])
	for record: Resource in _DomainRecords(game_data, &"map/interact_points"):
		var point := record as InteractPointDef
		_CheckExplorePointCell(report, game_data, map_def, point.id, point.cell)
		_RegisterPointCell(report, seen_cells, point.id, point.cell)
	for record: Resource in _DomainRecords(game_data, &"map/target_points"):
		var target := record as TargetPointDef
		_CheckExplorePointCell(report, game_data, map_def, target.id, target.cell)
		_RegisterPointCell(report, seen_cells, target.id, target.cell)

static func in_bounds_cell(map_def: ExploreMapDef, cell: Vector2i) -> bool:
	## 探索图界内判定（校验器内部口）
	## 参数 map_def：探索图定义；cell：查询格
	## 返回：true = 界内
	return cell.x >= 0 and cell.x < map_def.size.x \
			and cell.y >= 0 and cell.y < map_def.size.y

static func _CheckExplorePointCell(report: ValidationReport, game_data: Node,
		map_def: ExploreMapDef, owner_id: StringName, cell: Vector2i) -> void:
	## 单点位界内 + 非障碍检查（V-M3-map-points 内部口）
	## 参数 report/game_data/map_def/owner_id/cell：报告 / GameData / 图 / 归属 / 坐标
	## 返回：无
	if not in_bounds_cell(map_def, cell):
		report.add_error("V-M3-map-points", owner_id,
				"坐标 (%d, %d) 越界" % [cell.x, cell.y])
		return
	var char_key: StringName = StringName(String(map_def.rows[cell.y][cell.x]))
	var tile: ExploreTileDef = game_data.get_record(
			map_def.legend.get(char_key, &"")) as ExploreTileDef
	if tile == null or not tile.walkable:
		report.add_error("V-M3-map-points", owner_id,
				"坐标 (%d, %d) 位于不可通行地格" % [cell.x, cell.y])

static func _RegisterPointCell(report: ValidationReport, seen_cells: Dictionary,
		owner_id: StringName, cell: Vector2i) -> void:
	## 点位坐标查重登记（V-M3-map-points 内部口——同格双语义拦截）
	## 参数 report/seen_cells/owner_id/cell：报告 / 已占格表 / 归属 / 坐标
	## 返回：无
	if seen_cells.has(cell):
		report.add_error("V-M3-map-points", owner_id,
				"坐标 (%d, %d) 与 '%s' 重复" % [cell.x, cell.y, seen_cells[cell]])
	else:
		seen_cells[cell] = owner_id

static func _CheckExploreFogLit(report: ValidationReport, game_data: Node) -> void:
	## V-M3-fog-lit：fog_lit_rows ⊆ [0, size.y)（越界行号 = 无效全亮段）；
	## L8：fog_enabled 须 true（关闭迷雾的消费通路未接——M4 接线前拦截）；
	## W2-13：fog_lit_rows 非空 ↔ region_ids 恰 2（两段语义互为前提——
	## ExploreMapState.region_index_of 的下标推导按全亮行段 [0] + 其余 [1]，
	## 单边缺失即语义撕裂）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"map/maps"):
		var map_def := record as ExploreMapDef
		if not map_def.fog_enabled:
			report.add_error("V-M3-fog-lit", map_def.id,
					"fog_enabled = false（关闭迷雾通路未接——M4 接线前恒 true）")
		for row: int in map_def.fog_lit_rows:
			if row < 0 or row >= map_def.size.y:
				report.add_error("V-M3-fog-lit", map_def.id,
						"fog_lit_rows 行号 %d 越界 [0, %d)" % [row, map_def.size.y])
		var has_lit_rows: bool = not map_def.fog_lit_rows.is_empty()
		if has_lit_rows and map_def.region_ids.size() != 2:
			report.add_error("V-M3-fog-lit", map_def.id,
					"fog_lit_rows 非空但 region_ids 数 %d != 2（两段语义断裂）" %
					map_def.region_ids.size())
		elif not has_lit_rows and map_def.region_ids.size() == 2:
			report.add_error("V-M3-fog-lit", map_def.id,
					"region_ids 恰 2 但 fog_lit_rows 为空（全亮行段缺定义——两段语义断裂）")

static func _CheckExploreRefPointEvent(report: ValidationReport, game_data: Node) -> void:
	## V-M3-ref-point-event：交互点事件引用——CHAIN -> chains 域 / SINGLE、
	## SECRET_DOOR -> singles 域 / BATTLE -> enemy_packs 域存在（L3：类型
	## 断言——全域撞 id 的异类记录拦截）；TREASURE/EXIT ref 须空；
	## L4：trigger × kind 合法组合矩阵（CHAIN/SINGLE/BATTLE=ENTER、
	## TREASURE/EXIT=TAP、SECRET_DOOR=NEAR）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"map/interact_points"):
		var point := record as InteractPointDef
		# L4：组合矩阵
		var expected_trigger: int = -1
		match point.kind:
			InteractPointDef.Kind.CHAIN, InteractPointDef.Kind.SINGLE, \
					InteractPointDef.Kind.BATTLE:
				expected_trigger = InteractPointDef.Trigger.ENTER
			InteractPointDef.Kind.TREASURE, InteractPointDef.Kind.EXIT:
				expected_trigger = InteractPointDef.Trigger.TAP
			InteractPointDef.Kind.SECRET_DOOR:
				expected_trigger = InteractPointDef.Trigger.NEAR
		if point.trigger != expected_trigger:
			report.add_error("V-M3-ref-point-event", point.id,
					"kind=%d × trigger=%d 非法组合（期望 trigger=%d）" % [
							point.kind, point.trigger, expected_trigger])
		match point.kind:
			InteractPointDef.Kind.CHAIN:
				var chain: EventChainDef = game_data.get_record(point.ref_id) as EventChainDef
				if chain == null:
					report.add_error("V-M3-ref-point-event", point.id,
							"CHAIN 引用链 '%s' 不存在或非链表" % point.ref_id)
			InteractPointDef.Kind.SINGLE, InteractPointDef.Kind.SECRET_DOOR:
				var single: SingleEventDef = game_data.get_record(point.ref_id) as SingleEventDef
				if single == null:
					report.add_error("V-M3-ref-point-event", point.id,
							"%d 类引用单点事件 '%s' 不存在" % [point.kind, point.ref_id])
			InteractPointDef.Kind.BATTLE:
				var pack: EnemyPackDef = game_data.get_record(point.ref_id) as EnemyPackDef
				if pack == null:
					report.add_error("V-M3-ref-point-event", point.id,
							"BATTLE 引用敌方队伍 '%s' 不存在或非队伍表" % point.ref_id)
			InteractPointDef.Kind.TREASURE, InteractPointDef.Kind.EXIT:
				if String(point.ref_id) != "":
					report.add_error("V-M3-ref-point-event", point.id,
							"kind=%d（TREASURE/EXIT）不应携带 ref_id '%s'" % [point.kind, point.ref_id])

static func _CheckExploreRefChainPoint(report: ValidationReport, game_data: Node) -> void:
	## V-M3-ref-chain-point（M2 挂起①激活 + W4-06 反向补齐）：链
	## trigger_point_id 非空 -> 交互点存在 + kind == CHAIN + ref_id 回指本链
	## （双向一致）；反向（W4-06 收紧）：kind=CHAIN 的交互点其 ref_id 指向的
	## 链 trigger_point_id 须回指本点——空值报错（被挂链漏填触发点 = 板面
	## 无入口，链不可达）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"event/chains"):
		var chain := record as EventChainDef
		if String(chain.trigger_point_id) == "":
			continue
		var point: InteractPointDef = game_data.get_record(chain.trigger_point_id) as InteractPointDef
		if point == null:
			report.add_error("V-M3-ref-chain-point", chain.id,
					"触发点 '%s' 不在 map/interact_points 域" % chain.trigger_point_id)
		elif point.kind != InteractPointDef.Kind.CHAIN:
			report.add_error("V-M3-ref-chain-point", chain.id,
					"触发点 '%s' kind != CHAIN" % point.id)
		elif point.ref_id != chain.id:
			report.add_error("V-M3-ref-chain-point", chain.id,
					"触发点 '%s' 的 ref_id '%s' 未回指本链（双向不一致）" % [
							point.id, point.ref_id])
	# W4-06 反向断言：CHAIN 点 -> 链 trigger_point_id 回指（空报错收紧）
	for record: Resource in _DomainRecords(game_data, &"map/interact_points"):
		var point := record as InteractPointDef
		if point.kind != InteractPointDef.Kind.CHAIN:
			continue
		var chain: EventChainDef = game_data.get_record(point.ref_id) as EventChainDef
		if chain == null:
			continue
		if chain.trigger_point_id != point.id:
			report.add_error("V-M3-ref-chain-point", point.id,
					"引用链 '%s' 的 trigger_point_id '%s' 未回指本点（空/错指——板面链不可达）" % [
							chain.id, chain.trigger_point_id])

static func _CheckExploreRefQuestGoal(report: ValidationReport, game_data: Node) -> void:
	## V-M3-ref-quest-goal（M2 挂起②③激活）：委托判据引用——goal_param 非空且
	## EXPLORE -> target_points 域 / CLEAR -> enemy_packs 域存在（X3-11 域收紧：
	## 按域成员判定而非全域 get_record——跨域撞 id 不放行）；L5：ESCORT/COLLECT
	## DEMO 不支持（无判据消费通路）；map_id/region_id 非空时按域可解析
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"quest/templates"):
		var quest := record as QuestTemplateDef
		if quest.goal_type != QuestTemplateDef.GoalType.CLEAR \
				and quest.goal_type != QuestTemplateDef.GoalType.EXPLORE:
			# L5：DEMO 判据消费通路仅 CLEAR/EXPLORE（GoalTracker 双通道）
			report.add_error("V-M3-ref-quest-goal", quest.id,
					"goal_type=%d（DEMO 仅支持 CLEAR/EXPLORE）" % quest.goal_type)
		if String(quest.goal_param).is_empty():
			report.add_error("V-M3-ref-quest-goal", quest.id,
					"goal_param 为空（判据无参数 = 死委托）")
		elif quest.goal_type == QuestTemplateDef.GoalType.EXPLORE \
				and not _InDomain(game_data, &"map/target_points", quest.goal_param):
			report.add_error("V-M3-ref-quest-goal", quest.id,
					"EXPLORE 判据参数 '%s' 不在 map/target_points 域" % quest.goal_param)
		elif quest.goal_type == QuestTemplateDef.GoalType.CLEAR \
				and not _InDomain(game_data, &"battle/enemy_packs", quest.goal_param):
			report.add_error("V-M3-ref-quest-goal", quest.id,
					"CLEAR 判据参数 '%s' 不在 battle/enemy_packs 域" % quest.goal_param)
		if not String(quest.map_id).is_empty() \
				and not _InDomain(game_data, &"map/maps", quest.map_id):
			report.add_error("V-M3-ref-quest-goal", quest.id,
					"map_id '%s' 不可解析（map/maps 域）" % quest.map_id)
		if not String(quest.region_id).is_empty() \
				and not _InDomain(game_data, &"world/regions", quest.region_id):
			report.add_error("V-M3-ref-quest-goal", quest.id,
					"region_id '%s' 不可解析（world/regions 域）" % quest.region_id)

static func _InDomain(game_data: Node, domain: StringName, record_id: StringName) -> bool:
	## 域成员判定（X3-11 收口口——按域 id 列表而非全域索引）
	## 参数 game_data/domain/record_id：GameData / 域键 / 记录 id
	## 返回：true = 该域含此 id
	return game_data.get_domain_ids(domain).has(record_id)

static func _CheckExploreRefRegion(report: ValidationReport, game_data: Node) -> void:
	## V-M3-ref-region：区域引用——map.region_ids 与 encw.region_id 均须为
	## world/regions 域已有记录（W4-04：as 类型断言——全域撞 id 不放行）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"map/maps"):
		var map_def := record as ExploreMapDef
		for region_id: StringName in map_def.region_ids:
			if game_data.get_record(region_id) as RegionDef == null:
				report.add_error("V-M3-ref-region", map_def.id,
						"区域引用 '%s' 不在 world/regions 域" % region_id)
	for record: Resource in _DomainRecords(game_data, &"map/encounter_weights"):
		var weight := record as EncounterWeightDef
		if game_data.get_record(weight.region_id) as RegionDef == null:
			report.add_error("V-M3-ref-region", weight.id,
					"区域引用 '%s' 不在 world/regions 域" % weight.region_id)

static func _CheckExploreSecretReveal(report: ValidationReport, game_data: Node) -> void:
	## V-M3-secret-reveal：暗门揭示配置——reveal_cells 非空（W4-13：空表 =
	## 死配置——检定成功后无处揭示）+ reveal_cells 界内 + reveal_tile_id
	## 可解析且可通行（揭示格必为捷径——障碍揭示格是死配置）+ 引用单点事件
	## 的成功出口 unlock_flag 非空（揭示状态经 unlock_flag 消费——闭环锚点）；
	## W4-02：多图与 map-points 同口径（warning 后跳过，不做 maps[0] 越权校验）
	## 参数：报告 / GameData
	## 返回：无
	var maps: Array[Resource] = _DomainRecords(game_data, &"map/maps")
	if maps.is_empty():
		return
	if maps.size() > 1:
		report.add_warning("V-M3-secret-reveal", &"<map/maps>",
				"多图点位归属字段未定（%d 图）——跳过暗门揭示界内校验" % maps.size())
		return
	var map_def: ExploreMapDef = maps[0] as ExploreMapDef
	for record: Resource in _DomainRecords(game_data, &"map/interact_points"):
		var point := record as InteractPointDef
		if point.kind != InteractPointDef.Kind.SECRET_DOOR:
			continue
		if point.reveal_cells.is_empty():
			report.add_error("V-M3-secret-reveal", point.id,
					"reveal_cells 为空（暗门揭示无目标格——死配置）")
			continue
		for cell: Vector2i in point.reveal_cells:
			if not in_bounds_cell(map_def, cell):
				report.add_error("V-M3-secret-reveal", point.id,
						"揭示格 (%d, %d) 越界" % [cell.x, cell.y])
				continue
		var reveal_tile: ExploreTileDef = game_data.get_record(point.reveal_tile_id) as ExploreTileDef
		if reveal_tile == null:
			report.add_error("V-M3-secret-reveal", point.id,
					"reveal_tile_id '%s' 不可解析（map/tiles 域）" % point.reveal_tile_id)
		elif not reveal_tile.walkable:
			report.add_error("V-M3-secret-reveal", point.id,
					"reveal_tile_id '%s' 不可通行（捷径格必须可通行）" % point.reveal_tile_id)
		var single: SingleEventDef = game_data.get_record(point.ref_id) as SingleEventDef
		if single == null or single.success_outcome == null \
				or String(single.success_outcome.unlock_flag).is_empty():
			report.add_error("V-M3-secret-reveal", point.id,
					"引用单点事件 '%s' 的成功出口缺 unlock_flag（揭示消费闭环断链）" % point.ref_id)

static func _CheckExploreHiddenMark(report: ValidationReport, game_data: Node) -> void:
	## V-M3-hidden-mark：隐藏标记闭环——hm.unlock_flag 必须与事件域某出口的
	## unlock_flag 匹配（登记了无消费方的标记 = 死配置）
	## 参数：报告 / GameData
	## 返回：无
	var event_flags: Dictionary = {}
	for outcome_pair: Array in _AllEventOutcomes(game_data):
		var outcome: EventOutcomeDef = outcome_pair[1]
		if not String(outcome.unlock_flag).is_empty():
			event_flags[outcome.unlock_flag] = outcome_pair[0]
	for record: Resource in _DomainRecords(game_data, &"event/hidden_marks"):
		var mark := record as HiddenMarkDef
		if String(mark.unlock_flag).is_empty():
			report.add_error("V-M3-hidden-mark", mark.id, "unlock_flag 为空")
		elif not event_flags.has(mark.unlock_flag):
			report.add_error("V-M3-hidden-mark", mark.id,
					"unlock_flag '%s' 无事件出口承载（闭环断链）" % mark.unlock_flag)

static func _CheckExploreEncwDomain(report: ValidationReport, game_data: Node) -> void:
	## V-M3-encw-domain：遭遇权重量域——chance ∈ [0,1] / random_max ≥ 1 /
	## random_pack_id 可解析（battle/enemy_packs 域——W4-04 as 类型断言）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"map/encounter_weights"):
		var weight := record as EncounterWeightDef
		if weight.encounter_chance < 0.0 or weight.encounter_chance > 1.0:
			report.add_error("V-M3-encw-domain", weight.id,
					"encounter_chance %f 越界 [0, 1]" % weight.encounter_chance)
		if weight.random_max < 1:
			report.add_error("V-M3-encw-domain", weight.id,
					"random_max %d < 1" % weight.random_max)
		if game_data.get_record(weight.random_pack_id) as EnemyPackDef == null:
			report.add_error("V-M3-encw-domain", weight.id,
					"random_pack_id '%s' 不在 battle/enemy_packs 域" % weight.random_pack_id)

static func _CheckExploreTreasureDomain(report: ValidationReport, game_data: Node) -> void:
	## V-M3-treasure-domain：宝箱金域——TREASURE 点金域 ∈ [20,40] 且
	## min ≤ max（DEMO 带宽——案 18 §2 口径）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"map/interact_points"):
		var point := record as InteractPointDef
		if point.kind != InteractPointDef.Kind.TREASURE:
			continue
		if point.gold_min < 20 or point.gold_max > 40 or point.gold_min > point.gold_max:
			report.add_error("V-M3-treasure-domain", point.id,
					"金域 [%d, %d] 非法（要求 20 ≤ min ≤ max ≤ 40）" % [
							point.gold_min, point.gold_max])

static func _CheckExploreCounts(report: ValidationReport, game_data: Node) -> void:
	## V-M3-count：探索域计数带（cfg content_map_count/content_interact_points/
	## content_target_points/content_encounter_weights 四组——warning 级）
	## 参数：报告 / GameData
	## 返回：无
	_CheckCountBand(report, game_data, "<map/maps>", "content_map_count",
			"探索图", game_data.get_domain_ids(&"map/maps").size(), 1, "V-M3-count")
	_CheckCountBand(report, game_data, "<map/interact_points>", "content_interact_points",
			"交互点", game_data.get_domain_ids(&"map/interact_points").size(), 11, "V-M3-count")
	_CheckCountBand(report, game_data, "<map/target_points>", "content_target_points",
			"目标点", game_data.get_domain_ids(&"map/target_points").size(), 6, "V-M3-count")
	_CheckCountBand(report, game_data, "<map/encounter_weights>", "content_encounter_weights",
			"遭遇权重", game_data.get_domain_ids(&"map/encounter_weights").size(), 2, "V-M3-count")

static func _CheckQuestRewardDomain(report: ValidationReport, game_data: Node) -> void:
	## V-M3-quest-reward（W4-15）：委托模板奖励量级带宽校验——exp ∈ [40, 120] /
	## gold ∈ [50, 300] / reputation ∈ [0, 10] / reward 非空。
	## 带宽声明（DEMO 经济档，2026-09-26 审计自定）：当前两行委托均为
	## 80 exp / 150 金 / 5 声望（案 18 §2.3/§2.6 定稿），带宽按 ±50% 容差取整
	## 收口——数值改表越带即拦截，防单行手滑数量级错误（如 1500 金）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"quest/templates"):
		var quest := record as QuestTemplateDef
		if quest.reward == null:
			report.add_error("V-M3-quest-reward", quest.id,
					"reward 为空（委托无奖励——结算申报空转）")
			continue
		if quest.reward.exp < 40 or quest.reward.exp > 120:
			report.add_error("V-M3-quest-reward", quest.id,
					"exp %d 越界 [40, 120]（DEMO 经济带宽）" % quest.reward.exp)
		if quest.reward.gold < 50 or quest.reward.gold > 300:
			report.add_error("V-M3-quest-reward", quest.id,
					"gold %d 越界 [50, 300]（DEMO 经济带宽）" % quest.reward.gold)
		if quest.reward.reputation < 0 or quest.reward.reputation > 10:
			report.add_error("V-M3-quest-reward", quest.id,
					"reputation %d 越界 [0, 10]（DEMO 经济带宽）" % quest.reward.reputation)

static func _CheckExploreMapConnectivity(report: ValidationReport, game_data: Node) -> void:
	## V-M3-map-connectivity（W5-6）：探索图连通性——start_cell 出发四向 BFS
	## （可通行地格）可达全部交互点/目标点（不达 = 板面点位永不可触达——
	## 暗门捷径格不在此列：其为墙格揭示后开放，非点位承载格）；多图口径与
	## map-points 同（W4-02：warning 后跳过）
	## 参数：报告 / GameData
	## 返回：无
	var maps: Array[Resource] = _DomainRecords(game_data, &"map/maps")
	if maps.is_empty() or maps.size() > 1:
		return
	var map_def: ExploreMapDef = maps[0] as ExploreMapDef
	# 可通行格闭包（legend -> 地格 walkable——不建 ExploreMapState，校验器
	# 侧最小 BFS；揭示覆写不参与：暗门捷径属运行时解锁非基础连通义务；
	# 行长错位保护：短行越界列跳过——行长合法域归 V-M3-map-layout 拦截）
	var walkable_cells: Dictionary = {}
	for row_index: int in map_def.size.y:
		if row_index >= map_def.rows.size():
			break
		for col: int in mini(map_def.size.x, map_def.rows[row_index].length()):
			var char_key: StringName = StringName(String(map_def.rows[row_index][col]))
			var tile_id: StringName = map_def.legend.get(char_key, &"")
			var tile: ExploreTileDef = game_data.get_record(tile_id) as ExploreTileDef
			if tile != null and tile.walkable:
				walkable_cells[Vector2i(col, row_index)] = true
	# BFS 自 start_cell（start 不可通行时全部点位报不可达——同口径暴露）
	var reachable: Dictionary = {}
	var frontier: Array[Vector2i] = []
	if walkable_cells.has(map_def.start_cell):
		reachable[map_def.start_cell] = true
		frontier.append(map_def.start_cell)
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN,
				Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + direction
			if reachable.has(next) or not walkable_cells.has(next):
				continue
			reachable[next] = true
			frontier.append(next)
	# 全点位可达断言（交互点 + 目标点）
	for record: Resource in _DomainRecords(game_data, &"map/interact_points"):
		var point := record as InteractPointDef
		if not reachable.has(point.cell):
			report.add_error("V-M3-map-connectivity", point.id,
					"点位 (%d, %d) 自 start_cell 不可达（基础连通断裂）" % [
							point.cell.x, point.cell.y])
	for record: Resource in _DomainRecords(game_data, &"map/target_points"):
		var target := record as TargetPointDef
		if not reachable.has(target.cell):
			report.add_error("V-M3-map-connectivity", target.id,
					"点位 (%d, %d) 自 start_cell 不可达（基础连通断裂）" % [
							target.cell.x, target.cell.y])

static func _AllDomains(game_data: Node) -> Array[StringName]:
	## 全部数据域键（C-1 单源：从 GameData.DOMAIN_SCHEMA 键集派生——域清单
	## 唯一登记处即 DOMAIN_SCHEMA，校验器不再自持第二份清单；运行时实例
	## 读取无 preload/加载序问题）
	## 参数：GameData
	## 返回：域键数组
	var domains: Array[StringName] = []
	for domain: StringName in game_data.DOMAIN_SCHEMA:
		domains.append(domain)
	return domains

static func _DomainRecords(game_data: Node, domain: StringName) -> Array[Resource]:
	## 按域取记录列表（以域 id 索引为遍历基准——含无 id 表的文件名回退语义）
	## 参数：GameData / 域键
	## 返回：该域全部记录
	var result: Array[Resource] = []
	for record_id: StringName in game_data.get_domain_ids(domain):
		var record: Resource = game_data.get_record(record_id)
		if record != null:
			result.append(record)
	return result

static func _RecordPath(game_data: Node, record_id: StringName) -> String:
	## 取资源路径索引（仅对已注册 id 调用，不触发未知 id 警告）
	## 参数：GameData / 资源 id
	## 返回：res:// 路径（无索引返回空串）
	return game_data.get_resource_path(record_id)

static func _CountAll(game_data: Node) -> int:
	## 统计全库记录数
	## 参数：GameData
	## 返回：记录总数
	var total: int = 0
	for domain: StringName in _AllDomains(game_data):
		total += game_data.get_domain_ids(domain).size()
	return total
