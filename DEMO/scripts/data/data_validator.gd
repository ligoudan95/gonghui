## 数据校验器（DataValidator，纯静态类）
## 职责：对 GameData 已加载的全库数据表跑 14 条 M0 校验规则（错误阻断 / 警告非阻断），
## 产出 ValidationReport；供 tools/run_validation.gd（CI 退出码）与 gdUnit 断言消费。
## 数据来源：data/ 全域 .tres；规则口径=M0 批 2 方案（12 条规则展开为 14 个检查位）。
## 用法：DataValidator.run_all(game_data)——game_data 为 GameData 自动加载单例或其实例。
class_name DataValidator
extends RefCounted

## 七属性 id 全集（17 案 §3.1 一级属性域；校验 ref-skill-attr 用）
const SEVEN_ATTRS: Array[StringName] = [
	&"strength", &"agility", &"constitution",
	&"intelligence", &"perception", &"willpower", &"luck",
]

## 状态允许来源 token 值域
const ALLOWED_SOURCES: Array[StringName] = [&"SKILL", &"CHECKIN", &"TILE"]

## 叠加规则 token 值域（空=未指定）
const STACK_RULES: Array[StringName] = [&"no_stack_take_larger"]

## 移除策略 token 值域（空=回合计数流逝）
const REMOVE_POLICIES: Array[StringName] = [&"on_leave_tile"]

## core 域 M0 固定资源白名单（id 前缀规则的例外表）
const CORE_WHITELIST: Array[StringName] = [&"cfg_main", &"naming_registry"]

## 域 -> id 前缀规范（core 域走白名单例外）
const DOMAIN_PREFIXES: Dictionary[StringName, Array] = {
	&"class/classes": [&"cls_"],
	&"class/skills": [&"skl_"],
	&"status/stats": [&"BUFF_", &"DEBUFF_"],
	&"status/mutex_groups": [&"mgrp_"],
	&"battle/enemies": [&"en_"],
	&"battle/enemy_packs": [&"enc_"],
}

## 六数据域键（校验遍历范围；core 域单独处理）
const DATA_DOMAINS: Array[StringName] = [
	&"class/classes", &"class/skills", &"status/stats",
	&"status/mutex_groups", &"battle/enemies", &"battle/enemy_packs",
]

static func run_all(game_data: Node) -> ValidationReport:
	## 全库校验入口：顺序跑 14 条规则并返回报告
	## 参数 game_data：已完成扫描的 GameData 实例（autoload 或手动建树）
	## 返回：ValidationReport（零错误即通过；计数类问题为 warning）
	var report := ValidationReport.new()
	report.checked_count = _CountAll(game_data)
	_CheckIdUniqueness(report, game_data)
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
	return report

# --------------------------------------------------------------------------
# 基础规则（id 唯一 / 必填 / 文件名一致 / 前缀规范）
# --------------------------------------------------------------------------

static func _CheckIdUniqueness(report: ValidationReport, game_data: Node) -> void:
	## V-M0-id-uniq：全库 id 唯一（跨域查重，以域 id 索引为遍历基准）
	## 参数：报告 / GameData
	## 返回：无（重复写入 report.errors）
	var seen: Dictionary = {}
	for domain: StringName in _AllDomains(game_data):
		for record_id: StringName in game_data.get_domain_ids(domain):
			if seen.has(record_id):
				report.add_error("V-M0-id-uniq", record_id,
						"重复 id（与 %s 冲突）" % seen[record_id])
			else:
				seen[record_id] = _RecordPath(game_data, record_id)

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
	## V-M0-id-prefix：id 前缀符合域规范（core 域走白名单）
	## 参数：报告 / GameData
	## 返回：无
	for domain: StringName in _AllDomains(game_data):
		for record_id: StringName in game_data.get_domain_ids(domain):
			if domain == &"core":
				if not CORE_WHITELIST.has(record_id):
					report.add_error("V-M0-id-prefix", record_id,
							"core 域仅允许白名单 id：%s" % str(CORE_WHITELIST))
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
		_CheckEnumRange(report, skill.id, "SkillDef.damage_type", skill.damage_type, 2)
		_CheckEnumRange(report, skill.id, "SkillDef.target_side", skill.target_side, 2)
		_CheckEnumRange(report, skill.id, "SkillDef.target_shape", skill.target_shape, 3)
		_CheckEnumRange(report, skill.id, "SkillDef.side", skill.side, 1)
		_CheckEnumRange(report, skill.id, "SkillDef.resource_type", skill.resource_type, 2)
		for effect: SkillEffect in skill.effects:
			_CheckEnumRange(report, skill.id, "SkillEffect.effect_kind", effect.effect_kind, 3)
	for record: Resource in _DomainRecords(game_data, &"status/stats"):
		var status := record as StatusDef
		_CheckEnumRange(report, status.id, "StatusDef.category", status.category, 3)
		_CheckEnumRange(report, status.id, "StatusDef.polarity", status.polarity, 1)
		_CheckEnumRange(report, status.id, "StatusDef.control_kind", status.control_kind, 2)
		_CheckEnumRange(report, status.id, "StatusDef.duration_type", status.duration_type, 2)
		if status.dot != null:
			_CheckEnumRange(report, status.id, "DotParams.mode", status.dot.mode, 1)
		for source: StringName in status.allowed_sources:
			if not ALLOWED_SOURCES.has(source):
				report.add_error("V-M0-enum", status.id,
						"allowed_sources 含未知来源 token '%s'" % source)
		if not String(status.stack_rule).is_empty() and not STACK_RULES.has(status.stack_rule):
			report.add_error("V-M0-enum", status.id,
					"stack_rule 含未知 token '%s'" % status.stack_rule)
		if not String(status.remove_policy).is_empty() and not REMOVE_POLICIES.has(status.remove_policy):
			report.add_error("V-M0-enum", status.id,
					"remove_policy 含未知 token '%s'" % status.remove_policy)
	for record: Resource in _DomainRecords(game_data, &"battle/enemies"):
		var enemy := record as EnemyDef
		_CheckEnumRange(report, enemy.id, "EnemyDef.race_tag", enemy.race_tag, 1)

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
			if not SEVEN_ATTRS.has(attr_id):
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
	## V-M0-ref-skill-owner：owner 必须是已存在的职业/敌人 id；
	## skl_atk_enemy_common 的空 owner 为全库唯一放行；owner 为职业时 side 必须 ALLY
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		if String(skill.owner_id).is_empty():
			if skill.id != &"skl_atk_enemy_common":
				report.add_error("V-M0-ref-skill-owner", skill.id,
						"owner 为空（仅 skl_atk_enemy_common 放行）")
			continue
		var owner: Resource = game_data.get_record(skill.owner_id)
		if owner == null:
			report.add_error("V-M0-ref-skill-owner", skill.id,
					"owner '%s' 不存在（非 cls_/en_ 域 id）" % skill.owner_id)
		elif owner is ClassDef and skill.side != SkillDef.SkillSide.ALLY:
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
	## V-M0-ref-enemy-skill：敌人技能引用闭合（skill_ids/common 均存在）；
	## owner 为敌人的技能 side 必须 ENEMY
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"battle/enemies"):
		var enemy := record as EnemyDef
		for skill_id: StringName in enemy.skill_ids:
			if game_data.get_record(skill_id) == null:
				report.add_error("V-M0-ref-enemy-skill", enemy.id,
						"技能引用 '%s' 不存在" % skill_id)
		if game_data.get_record(enemy.common_attack_skill_id) == null:
			report.add_error("V-M0-ref-enemy-skill", enemy.id,
					"通用普攻引用 '%s' 不存在" % enemy.common_attack_skill_id)
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		var owner: Resource = game_data.get_record(skill.owner_id) if not String(skill.owner_id).is_empty() else null
		if owner is EnemyDef and skill.side != SkillDef.SkillSide.ENEMY:
			report.add_error("V-M0-ref-enemy-skill", skill.id,
					"owner 为敌人但 side != ENEMY")

static func _CheckRefPack(report: ValidationReport, game_data: Node) -> void:
	## V-M0-ref-pack：队伍条目敌人引用闭合；数量区间 1≤min≤max≤4；
	## battle_map_ref 非空时必须可解析（当前地图域未建，非空即报错、空=批 4 回填放行）
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"battle/enemy_packs"):
		var pack := record as EnemyPackDef
		for entry: PackEntry in pack.entries:
			for enemy_id: StringName in entry.enemy_ids:
				if game_data.get_record(enemy_id) == null:
					report.add_error("V-M0-ref-pack", pack.id,
							"条目敌人引用 '%s' 不存在" % enemy_id)
			if entry.count_min < 1 or entry.count_min > entry.count_max or entry.count_max > 4:
				report.add_error("V-M0-ref-pack", pack.id,
						"数量区间非法（min=%d, max=%d，要求 1≤min≤max≤4）" % [entry.count_min, entry.count_max])
		if not String(pack.battle_map_ref).is_empty() and game_data.get_record(pack.battle_map_ref) == null:
			report.add_error("V-M0-ref-pack", pack.id,
					"战场地图引用 '%s' 不存在" % pack.battle_map_ref)

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
	## V-M0-num-domain：资源消耗≥0、射程∈[0,5]、职业/敌人移动力∈[1,6]、
	## 生命/系数为正、抗性∈[0,1]、敌人属性为正
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"class/skills"):
		var skill := record as SkillDef
		if skill.resource_cost < 0:
			report.add_error("V-M0-num-domain", skill.id,
					"资源消耗 %d 为负" % skill.resource_cost)
		if skill.range < 0 or skill.range > 5:
			report.add_error("V-M0-num-domain", skill.id,
					"射程 %d 越界 [0, 5]" % skill.range)
	for record: Resource in _DomainRecords(game_data, &"class/classes"):
		var cls := record as ClassDef
		if cls.move_range < 1 or cls.move_range > 6:
			report.add_error("V-M0-num-domain", cls.id,
					"移动力 %d 越界 [1, 6]" % cls.move_range)
		if cls.hp_coefficient <= 0.0:
			report.add_error("V-M0-num-domain", cls.id,
					"生命系数 %f 非正" % cls.hp_coefficient)
	for record: Resource in _DomainRecords(game_data, &"battle/enemies"):
		var enemy := record as EnemyDef
		if enemy.move_range < 1 or enemy.move_range > 6:
			report.add_error("V-M0-num-domain", enemy.id,
					"移动力 %d 越界 [1, 6]" % enemy.move_range)
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
	## V-M0-count：全库计数带校验（技能 23=6+12+4+1；状态 10-15；敌 3；配置 3）——warning 级
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
	if basic_attacks != 6:
		report.add_warning("V-M0-count", "<skills>", "六职业普攻计数 %d != 6" % basic_attacks)
	if class_skills != 12:
		report.add_warning("V-M0-count", "<skills>", "职业档 1 技能计数 %d != 12" % class_skills)
	if enemy_skills != 4:
		report.add_warning("V-M0-count", "<skills>", "敌方技能计数 %d != 4" % enemy_skills)
	if enemy_common != 1:
		report.add_warning("V-M0-count", "<skills>", "敌方通用普攻计数 %d != 1" % enemy_common)
	var status_count: int = game_data.get_domain_ids(&"status/stats").size()
	if status_count < 10 or status_count > 15:
		report.add_warning("V-M0-count", "<status>", "状态计数 %d 越界 [10, 15]" % status_count)
	var enemy_count: int = game_data.get_domain_ids(&"battle/enemies").size()
	if enemy_count != 3:
		report.add_warning("V-M0-count", "<enemies>", "敌人计数 %d != 3" % enemy_count)
	var pack_count: int = game_data.get_domain_ids(&"battle/enemy_packs").size()
	if pack_count != 3:
		report.add_warning("V-M0-count", "<packs>", "敌方队伍计数 %d != 3" % pack_count)

# --------------------------------------------------------------------------
# 辅助
# --------------------------------------------------------------------------

static func _AllDomains(game_data: Node) -> Array[StringName]:
	## 全部数据域键（六数据域 + core）
	## 参数：GameData
	## 返回：域键数组
	var domains: Array[StringName] = []
	domains.append_array(DATA_DOMAINS)
	domains.append(&"core")
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
