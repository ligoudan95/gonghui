## 单位装配器（UnitBuilder，纯静态工具类）
## 职责：把 AdventurerData（我方）与 EnemyDef（敌方）装配为 BattleUnit——
## 我方走 DerivedStats 派生（HP/资源双轨按 17 案 §3.2），敌方直读表定值
## （HP/武器/护甲 flat/抗性/移动力，§3.8）。
## 数据来源：案 17 §3.2（生命/资源换算）/§3.8（敌人表直读口径：护甲双轨
## 同值、抗性表定、资源挂精力池）；M1 调试口径（出战技能 = 普攻 + 档 1 全部）。
## 纯逻辑约束：不触任何 autoload——全部输入经参数注入。
class_name UnitBuilder
extends RefCounted

static func build_ally(adv: AdventurerData, cls: ClassDef, eqp: EquipDef) -> BattleUnit:
	## 装配我方单位：HP = 20+体×5+系数×(等级−1)；双资源池 = 10+换算源属性×3
	## （同源双轨——非本系资源仅供面板完整性显示，§3.2）；武器/护甲来自装备表
	## ## 参数 adv：冒险者出战数据；cls：职业表；eqp：装备表（可为 null——无装备装配）
	## 返回：BattleUnit（side=ALLY；slot_index/绑定由 BattleSetup 回填）
	var unit := BattleUnit.new()
	unit.unit_id = adv.unit_id
	unit.display_name = adv.display_name if not adv.display_name.is_empty() else String(adv.unit_id)
	unit.side = SkillDef.SkillSide.ALLY
	unit.class_id = adv.class_id
	unit.level = adv.level
	unit.attrs = adv.attrs.duplicate()
	unit.max_hp = DerivedStats.calc_hp(int(adv.attrs.get(&"constitution", 10)), cls, adv.level)
	unit.current_hp = unit.max_hp
	var source_value: int = int(adv.attrs.get(cls.resource_source_attr, 10))
	unit.max_mana = DerivedStats.calc_mana(source_value)
	unit.current_mana = unit.max_mana
	unit.max_stamina = DerivedStats.calc_stamina(source_value)
	unit.current_stamina = unit.max_stamina
	if eqp != null:
		unit.weapon_bonus = eqp.weapon_bonus
		unit.armor_equip = eqp.armor_value
	unit.base_move_range = cls.move_range
	unit.base_attack_id = cls.base_attack_skill_id
	unit.resource_kind = SkillDef.ResourceKind.MANA \
			if cls.resource_type == ClassDef.ResourceType.MANA else SkillDef.ResourceKind.STAMINA
	var skills: Array[StringName] = [cls.base_attack_skill_id]
	for skill_id: StringName in adv.skill_ids:
		if not skills.has(skill_id):
			skills.append(skill_id)
	unit.skill_ids = skills
	unit.race_tag = &""
	unit.role_tag = &""
	return unit

static func build_enemy(enemy: EnemyDef, slot: int) -> BattleUnit:
	## 装配敌方单位：数值直读表定值（HP/武器/护甲 flat 双轨/抗性/移动力），
	## 资源池挂精力轨（法力 0）；unit_id 唯一化 = "<enemy_id>_<槽序>"
	## 参数 enemy：敌人表；slot：配置序（unit_id 后缀 + 排序次级键）
	## 返回：BattleUnit（side=ENEMY；flat_defense=true）
	var unit := BattleUnit.new()
	unit.unit_id = StringName("%s_%d" % [enemy.id, slot])
	unit.display_name = enemy.display_name
	unit.side = SkillDef.SkillSide.ENEMY
	unit.enemy_id = enemy.id
	unit.slot_index = slot
	unit.attrs = enemy.attrs.duplicate()
	unit.max_hp = enemy.hp
	unit.current_hp = unit.max_hp
	unit.max_stamina = enemy.resource_pool
	unit.current_stamina = enemy.resource_pool
	unit.weapon_bonus = enemy.weapon_bonus
	unit.armor_equip = enemy.armor
	unit.flat_defense = true
	unit.fixed_resist = enemy.resist_pct
	unit.base_move_range = enemy.move_range
	var skills: Array[StringName] = []
	for skill_id: StringName in enemy.skill_ids:
		if not skills.has(skill_id):
			skills.append(skill_id)
	skills.append(enemy.common_attack_skill_id)
	unit.skill_ids = skills
	unit.base_attack_id = enemy.common_attack_skill_id
	unit.resource_kind = SkillDef.ResourceKind.STAMINA
	unit.race_tag = _RaceTagOf(enemy.race_tag)
	unit.role_tag = enemy.role_tag
	return unit

static func _RaceTagOf(race_tag: int) -> StringName:
	## 敌表种族枚举 -> StringName 标记（种族克制消费口径）
	## 参数 race_tag：EnemyDef.RaceTag 枚举值
	## 返回：&"beast"/&"humanoid"
	if race_tag == EnemyDef.RaceTag.BEAST:
		return &"beast"
	return &"humanoid"
