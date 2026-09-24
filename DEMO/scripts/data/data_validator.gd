## 数据校验器（DataValidator，纯静态类）
## 职责：对 GameData 已加载的全库数据表跑 14 条 M0 校验规则 + 6 条 V-M1-* 战斗域
## 规则 + 1 条 V-M1-ref-asset 资源引用规则（错误阻断 / 警告非阻断），产出
## ValidationReport；供 tools/run_validation.gd（CI 退出码）与 gdUnit 断言消费。
## 数据来源：data/ 全域 .tres；规则口径=M0 批 2 方案（12 条规则展开为 14 个检查位）
## + M1 批 1 方案（V-M1-* 六条：地格状态绑定/地图布局/出生位/技能地格引用/
## 队伍地图引用加严/战斗域计数）+ 插队任务（V-M1-ref-asset：AssetRegistry
## 非空条目 path 必须文件存在——案 16 资源引用规范的落盘校验位）。
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

## assets 域固定资源白名单（盲审批 2 A-9：assets 域纳入校验遍历——仅 registry 一条）
const ASSETS_WHITELIST: Array[StringName] = [&"registry"]

## 敌人职能标记合法集（盲审批 2 A-7：role_tag 值域——与 BattleUnit 消费口径对齐）
const ENEMY_ROLE_TAGS: Array[StringName] = [&"trash", &"elite"]

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
	&"assets": [&"registry"],
}

## 六数据域键（校验遍历范围；core/assets 域一并处理——盲审批 2 A-9）
const DATA_DOMAINS: Array[StringName] = [
	&"class/classes", &"class/skills", &"status/stats",
	&"status/mutex_groups", &"battle/enemies", &"battle/enemy_packs",
	&"battle/maps", &"battle/tiles", &"equip", &"assets",
]

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
		_CheckEnumRange(report, enemy.id, "EnemyDef.race_tag", enemy.race_tag, EnemyDef.RaceTag.size() - 1)
	for record: Resource in _DomainRecords(game_data, &"battle/tiles"):
		var tile := record as TileTypeDef
		_CheckEnumRange(report, tile.id, "TileTypeDef.kind", tile.kind, TileTypeDef.Kind.size() - 1)
		_CheckEnumRange(report, tile.id, "TileTypeDef.trigger", tile.trigger, TileTypeDef.Trigger.size() - 1)
		_CheckEnumRange(report, tile.id, "TileTypeDef.style", tile.style, TileTypeDef.Style.size() - 1)
	# V-A-class-attr（批 C M8）：法穿换算源表驱动字段必填且 ∈ 七属性
	for record: Resource in _DomainRecords(game_data, &"class/classes"):
		var cls := record as ClassDef
		if String(cls.mag_pierce_source_attr).is_empty():
			report.add_error("V-A-class-attr", cls.id, "mag_pierce_source_attr 为空")
		elif not SEVEN_ATTRS.has(cls.mag_pierce_source_attr):
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
	## V-M0-ref-pack：队伍条目敌人引用闭合；数量区间 1≤min≤max≤4
	## （battle_map_ref 校验自 M1 批 1 起移入 V-M1-ref-pack-map 加严规则）
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
	## 布局字符 ∈ legend / legend 值为已存在的地格 id
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"battle/maps"):
		var map_def := record as BattleMapDef
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
	## 取 cfg_main 的计数带（<prefix>_min/<prefix>_max；值 ≤0 视为未设回退）
	## 参数 game_data：GameData；field_prefix：cfg 字段前缀；fallback：回退定值
	## 返回：Vector2i(min, max)
	var cfg: CoreConfig = game_data.get_record(&"cfg_main") as CoreConfig
	var band_min: int = fallback
	var band_max: int = fallback
	if cfg != null:
		var cfg_min: int = int(cfg.get(field_prefix + "_min"))
		var cfg_max: int = int(cfg.get(field_prefix + "_max"))
		if cfg_min > 0:
			band_min = cfg_min
		if cfg_max > 0:
			band_max = cfg_max
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

static func _CheckTileVisual(report: ValidationReport, game_data: Node) -> void:
	## V-A-tile-visual：地格视觉表驱动字段必填（批 A H2）——fill_color 非默认
	## 透明（alpha > 0）；style 为 RAISED/BLOCK 时 accent_color 必填
	## 参数：报告 / GameData
	## 返回：无
	for record: Resource in _DomainRecords(game_data, &"battle/tiles"):
		var tile := record as TileTypeDef
		if tile.fill_color.a <= 0.0:
			report.add_error("V-A-tile-visual", tile.id, "fill_color 未回填（alpha ≤ 0）")
		if tile.style != TileTypeDef.Style.PLAIN and tile.accent_color.a <= 0.0:
			report.add_error("V-A-tile-visual", tile.id,
					"style=%d 需要 accent_color 但未回填（alpha ≤ 0）" % tile.style)

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
		if rid.begins_with("spr_"):
			if asset_registry == null or not asset_registry.mapping.has(entry.resource_id):
				report.add_error("V-B2-naming", entry.resource_id,
						"spr_ 登记未在 AssetRegistry mapping 中")
		elif rid.begins_with("tend_"):
			if not tend_ids.has(entry.resource_id):
				report.add_error("V-B2-naming", entry.resource_id,
						"tend_ 登记不存在于任何职业表 tendencies")
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
		var owner: Resource = game_data.get_record(skill.owner_id)
		if owner is EnemyDef:
			var enemy := owner as EnemyDef
			if not enemy.skill_ids.has(skill.id) \
					and enemy.common_attack_skill_id != skill.id:
				report.add_error("V-B2-owner", skill.id,
						"owner 为敌人 '%s' 但其技能清单未回含本技能" % enemy.id)
		elif owner is ClassDef and skill.tier == 0 and not base_attack_ids.has(skill.id):
			report.add_warning("V-B2-owner", skill.id,
					"owner 为职业的 tier=0 技能未被任何职业普攻位引用（运行时不可达）")

static func _CheckCfgDomains(report: ValidationReport, game_data: Node) -> void:
	## V-M0-cfg-domain（A-6）：总控配置值域——除数 > 0（防 NaN）、钳制带有序
	## 且 ∈ [0,1]、难度五档键集恰合、系统启用清单键域合法且全覆盖、公式/计数
	## 参数基本值域（批 B/M 系字段：正数 / 率值 (0,1] / 带序）
	## 参数：报告 / GameData
	## 返回：无
	var cfg: CoreConfig = game_data.get_record(&"cfg_main") as CoreConfig
	if cfg == null:
		report.add_error("V-M0-cfg-domain", &"cfg_main", "总控配置缺失")
		return
	for divisor_name: String in ["attr_modifier_divisor", "crit_success_drop_divisor",
			"luck_floor_z_divisor"]:
		if int(cfg.get(divisor_name)) <= 0:
			report.add_error("V-M0-cfg-domain", &"cfg_main",
					"%s ≤ 0（除零 NaN 风险）" % divisor_name)
	if cfg.hit_clamp_min < 0.0 or cfg.hit_clamp_max > 1.0 or cfg.hit_clamp_min > cfg.hit_clamp_max:
		report.add_error("V-M0-cfg-domain", &"cfg_main",
				"命中钳制带 [%f, %f] 非法" % [cfg.hit_clamp_min, cfg.hit_clamp_max])
	var tiers: Array = ["极易", "容易", "普通", "困难", "极难"]
	if cfg.difficulty_tiers.size() != tiers.size():
		report.add_error("V-M0-cfg-domain", &"cfg_main",
				"难度档数 %d != 5" % cfg.difficulty_tiers.size())
	for tier: String in tiers:
		if not cfg.difficulty_tiers.has(tier):
			report.add_error("V-M0-cfg-domain", &"cfg_main", "难度档缺失 '%s'" % tier)
	var system_keys: Array[StringName] = GameConfigScript.SYSTEM_KEYS
	for sys_key: StringName in cfg.enabled_systems:
		if not system_keys.has(sys_key):
			report.add_error("V-M0-cfg-domain", &"cfg_main",
					"enabled_systems 含未知系统键 '%s'" % sys_key)
	for sys_key: StringName in system_keys:
		if not cfg.enabled_systems.has(sys_key):
			report.add_error("V-M0-cfg-domain", &"cfg_main",
					"enabled_systems 缺少系统键 '%s'（须全覆盖）" % sys_key)
	# 批 B/M 公式参数基本值域
	for positive_name: String in ["hp_base", "hp_con_mult", "pool_base", "pool_mult",
			"move_base_cap", "agility_move_bonus_line", "ai_roar_ally_count_line",
			"recruit_band_min", "recruit_band_max"]:
		if int(cfg.get(positive_name)) <= 0:
			report.add_error("V-M0-cfg-domain", &"cfg_main",
					"%s ≤ 0" % positive_name)
	if cfg.recruit_band_min > cfg.recruit_band_max:
		report.add_error("V-M0-cfg-domain", &"cfg_main", "招募带 min > max")
	for rate_name: String in ["hit_base", "dodge_base", "attr_hit_weight",
			"attr_dodge_weight", "status_resist_base", "status_resist_weight",
			"resist_weight", "crit_base", "crit_luck_weight", "crit_agility_weight"]:
		var rate_value: float = float(cfg.get(rate_name))
		if rate_value <= 0.0 or rate_value > 1.0:
			report.add_error("V-M0-cfg-domain", &"cfg_main",
					"%s = %f 越界 (0, 1]" % [rate_name, rate_value])
	if cfg.crit_mult_base < 1.0:
		report.add_error("V-M0-cfg-domain", &"cfg_main",
				"crit_mult_base %f < 1.0" % cfg.crit_mult_base)
	for band_name: String in ["content_skill_attacks", "content_class_skills",
			"content_enemy_skills", "content_enemy_common", "content_status",
			"content_enemies", "content_packs", "content_maps", "content_tiles",
			"content_equip"]:
		var band_min: int = int(cfg.get(band_name + "_min"))
		var band_max: int = int(cfg.get(band_name + "_max"))
		if band_min < 0 or band_min > band_max:
			report.add_error("V-M0-cfg-domain", &"cfg_main",
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
		if not ENEMY_ROLE_TAGS.has(enemy.role_tag):
			report.add_error("V-B2-value-domain", enemy.id,
					"role_tag '%s' 不在合法集 %s" % [enemy.role_tag, str(ENEMY_ROLE_TAGS)])
	for record: Resource in _DomainRecords(game_data, &"status/stats"):
		var status := record as StatusDef
		if status.default_duration < 0:
			report.add_error("V-B2-value-domain", status.id,
					"default_duration %d 为负" % status.default_duration)

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
			if not SEVEN_ATTRS.has(effect.dot_attr_id):
				report.add_error("V-B2-tile-matrix", skill.id,
						"TILE_SPAWN dot_attr_id '%s' 不在七属性集" % effect.dot_attr_id)

# --------------------------------------------------------------------------
# 辅助
# --------------------------------------------------------------------------

static func _MoveBaseCap(game_data: Node) -> int:
	## 移动力基准段上限（读 cfg_main.move_base_cap——批 B M2 与单位终值同源；
	## 缺省回退 6 与 cfg 表值一致）
	## 参数：GameData
	## 返回：上限值
	var cfg: CoreConfig = game_data.get_record(&"cfg_main") as CoreConfig
	return cfg.move_base_cap if cfg != null and cfg.move_base_cap > 0 else 6

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
