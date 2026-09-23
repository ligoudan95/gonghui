## M0 批 2 全量数据生成器
## 职责：生成 48 张数据表（.tres）——职业 6 / 技能 23 / 状态 11 / 互斥组 1 /
## 敌人 3 / 敌方队伍 3 / 资源命名登记表 1（重写批 1 版、扩至全库 48 条登记）。
## 数值来源：17 案 §3.1（六职业属性区间）/§3.2（资源换算与生命系数）/
## §3.4（DEMO 技能参数表）/§3.8（敌人表+敌方技能表 17-C12~C16）/
## §3.9（状态持续与地格效果）；案 10 §2.1（职业定位）/§2.4（倾向清单）。
## 用法：godot --headless --import 后
##   godot --headless -s res://tools/gen_m0_batch2_data.gd
## 注：cfg_main 仍由 gen_m0_placeholders.gd 生成（批 1 职责划分）；
## 全部数值【占位·试玩校准】；区间字段存区间、单值字段按区间中值（杂兵武器
## 加值区间 2-3 取上值 3——任务定值、区间内，见完成报告偏差注）。
extends SceneTree

# ---- 属性 id 常量（七属性，小写下划线，naming_registry 登记说明） ----
const ATTR_STRENGTH: StringName = &"strength"
const ATTR_AGILITY: StringName = &"agility"
const ATTR_CONSTITUTION: StringName = &"constitution"
const ATTR_INTELLIGENCE: StringName = &"intelligence"
const ATTR_PERCEPTION: StringName = &"perception"
const ATTR_WILLPOWER: StringName = &"willpower"
const ATTR_LUCK: StringName = &"luck"

## 七属性 id 全集（供属性区间表与权重表构建）
const SEVEN_ATTRS: Array[StringName] = [
	ATTR_STRENGTH, ATTR_AGILITY, ATTR_CONSTITUTION,
	ATTR_INTELLIGENCE, ATTR_PERCEPTION, ATTR_WILLPOWER, ATTR_LUCK,
]

func _initialize() -> void:
	## MainLoop 回调：依次生成六域数据与命名登记表后退出
	## 参数：无
	## 返回：无（任一保存失败按退出码 1 结束）
	var ok: bool = true
	ok = _GenerateClasses() and ok
	ok = _GenerateSkills() and ok
	ok = _GenerateStatuses() and ok
	ok = _GenerateMutexGroups() and ok
	ok = _GenerateEnemies() and ok
	ok = _GenerateEnemyPacks() and ok
	ok = _GenerateNamingRegistry() and ok
	if ok:
		print("gen_m0_batch2_data: 全部数据生成完成")
		quit(0)
	else:
		printerr("gen_m0_batch2_data: 存在保存失败项")
		quit(1)

func _SaveResource(resource: Resource, path: String) -> bool:
	## 保存资源到指定路径并打印结果
	## 参数 resource：待保存资源；path：目标 res:// 路径
	## 返回：true = 保存成功
	var err: Error = ResourceSaver.save(resource, path)
	if err != OK:
		printerr("gen_m0_batch2_data: 保存失败 %s（错误码 %d）" % [path, err])
		return false
	print("gen_m0_batch2_data: 已生成 %s" % path)
	return true

# =========================================================================
# 职业域 class/classes（6 张，ClassDef）
# =========================================================================

func _GenerateClasses() -> bool:
	## 生成 6 职业 ClassDef（17 案 §3.1 属性区间逐格取值 + §3.2 系数 + 案 10 §2.1/§2.4）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	ok = _SaveResource(_MakeClass(
		&"cls_warrior", "战士", "前排坦克/近战输出",
		[ATTR_STRENGTH, ATTR_CONSTITUTION],
		{
			ATTR_STRENGTH: Vector2i(15, 17), ATTR_AGILITY: Vector2i(9, 11),
			ATTR_CONSTITUTION: Vector2i(13, 15), ATTR_INTELLIGENCE: Vector2i(6, 8),
			ATTR_PERCEPTION: Vector2i(8, 10), ATTR_WILLPOWER: Vector2i(8, 10),
			ATTR_LUCK: Vector2i(8, 10),
		},
		ClassDef.ResourceType.STAMINA, ATTR_STRENGTH, 8.0, 3, &"skl_atk_warrior",
		_MakeTendency(&"tend_warrior_a", "狂战", [ATTR_STRENGTH]),
		_MakeTendency(&"tend_warrior_b", "守卫", [ATTR_CONSTITUTION])
	), "res://data/class/classes/cls_warrior.tres") and ok
	ok = _SaveResource(_MakeClass(
		&"cls_rogue", "盗贼", "高机动/暴击/检定多面手",
		[ATTR_AGILITY, ATTR_LUCK],
		{
			ATTR_STRENGTH: Vector2i(9, 11), ATTR_AGILITY: Vector2i(15, 17),
			ATTR_CONSTITUTION: Vector2i(9, 11), ATTR_INTELLIGENCE: Vector2i(8, 10),
			ATTR_PERCEPTION: Vector2i(10, 12), ATTR_WILLPOWER: Vector2i(9, 11),
			ATTR_LUCK: Vector2i(12, 14),
		},
		ClassDef.ResourceType.STAMINA, ATTR_AGILITY, 4.0, 5, &"skl_atk_rogue",
		_MakeTendency(&"tend_rogue_a", "刺杀", [ATTR_AGILITY]),
		_MakeTendency(&"tend_rogue_b", "陷阱", [ATTR_PERCEPTION])
	), "res://data/class/classes/cls_rogue.tres") and ok
	ok = _SaveResource(_MakeClass(
		&"cls_mage", "法师", "AOE 法术输出/硬控制",
		[ATTR_INTELLIGENCE],
		{
			ATTR_STRENGTH: Vector2i(6, 8), ATTR_AGILITY: Vector2i(9, 11),
			ATTR_CONSTITUTION: Vector2i(8, 10), ATTR_INTELLIGENCE: Vector2i(15, 17),
			ATTR_PERCEPTION: Vector2i(10, 12), ATTR_WILLPOWER: Vector2i(8, 10),
			ATTR_LUCK: Vector2i(8, 10),
		},
		ClassDef.ResourceType.MANA, ATTR_INTELLIGENCE, 3.0, 3, &"skl_atk_mage",
		_MakeTendency(&"tend_mage_a", "轰炸", [ATTR_INTELLIGENCE]),
		_MakeTendency(&"tend_mage_b", "控制", [ATTR_INTELLIGENCE])
	), "res://data/class/classes/cls_mage.tres") and ok
	ok = _SaveResource(_MakeClass(
		&"cls_priest", "牧师", "治疗/驱散/亡灵克制",
		[ATTR_PERCEPTION, ATTR_WILLPOWER],
		{
			ATTR_STRENGTH: Vector2i(9, 11), ATTR_AGILITY: Vector2i(9, 11),
			ATTR_CONSTITUTION: Vector2i(10, 12), ATTR_INTELLIGENCE: Vector2i(8, 10),
			ATTR_PERCEPTION: Vector2i(14, 16), ATTR_WILLPOWER: Vector2i(12, 14),
			ATTR_LUCK: Vector2i(8, 10),
		},
		ClassDef.ResourceType.MANA, ATTR_PERCEPTION, 5.0, 4, &"skl_atk_priest",
		_MakeTendency(&"tend_priest_a", "治疗", [ATTR_PERCEPTION]),
		_MakeTendency(&"tend_priest_b", "惩戒", [ATTR_WILLPOWER])
	), "res://data/class/classes/cls_priest.tres") and ok
	ok = _SaveResource(_MakeClass(
		&"cls_ranger", "游侠", "远程物理/地形利用",
		[ATTR_AGILITY, ATTR_PERCEPTION],
		{
			ATTR_STRENGTH: Vector2i(10, 12), ATTR_AGILITY: Vector2i(14, 16),
			ATTR_CONSTITUTION: Vector2i(10, 12), ATTR_INTELLIGENCE: Vector2i(8, 10),
			ATTR_PERCEPTION: Vector2i(12, 14), ATTR_WILLPOWER: Vector2i(8, 10),
			ATTR_LUCK: Vector2i(8, 10),
		},
		ClassDef.ResourceType.STAMINA, ATTR_AGILITY, 5.0, 5, &"skl_atk_ranger",
		_MakeTendency(&"tend_ranger_a", "狙杀", [ATTR_AGILITY]),
		_MakeTendency(&"tend_ranger_b", "游猎", [ATTR_PERCEPTION])
	), "res://data/class/classes/cls_ranger.tres") and ok
	ok = _SaveResource(_MakeClass(
		&"cls_arcanist", "奇术师", "控制系：施加负面状态削弱绞杀",
		[ATTR_WILLPOWER, ATTR_PERCEPTION],
		{
			ATTR_STRENGTH: Vector2i(6, 8), ATTR_AGILITY: Vector2i(9, 11),
			ATTR_CONSTITUTION: Vector2i(8, 10), ATTR_INTELLIGENCE: Vector2i(10, 12),
			ATTR_PERCEPTION: Vector2i(12, 14), ATTR_WILLPOWER: Vector2i(15, 17),
			ATTR_LUCK: Vector2i(8, 10),
		},
		ClassDef.ResourceType.MANA, ATTR_WILLPOWER, 4.0, 4, &"skl_atk_arcanist",
		_MakeTendency(&"tend_arcanist_a", "诅咒", [ATTR_WILLPOWER]),
		_MakeTendency(&"tend_arcanist_b", "蛊惑", [ATTR_WILLPOWER])
	), "res://data/class/classes/cls_arcanist.tres") and ok
	return ok

func _MakeClass(
		class_id: StringName, display_name: String, role_desc: String,
		main_attrs: Array[StringName], attr_ranges: Dictionary,
		resource_type: ClassDef.ResourceType, resource_source_attr: StringName,
		hp_coefficient: float, move_range: int, base_attack_skill_id: StringName,
		tendency_a: TendencyDef, tendency_b: TendencyDef
) -> ClassDef:
	## 构建 ClassDef 资源（attr_ranges 为 Dictionary[StringName, Vector2i] 字面量）
	## 参数：见 ClassDef 字段（tendency_a/b 为该职业两个倾向分支）
	## 返回：填充完成的 ClassDef
	var cls := ClassDef.new()
	cls.id = class_id
	cls.display_name = display_name
	cls.role_desc = role_desc
	cls.main_attrs = main_attrs
	var ranges: Dictionary[StringName, Vector2i] = {}
	for attr_id: StringName in SEVEN_ATTRS:
		ranges[attr_id] = attr_ranges[attr_id]
	cls.attr_ranges = ranges
	cls.resource_type = resource_type
	cls.resource_source_attr = resource_source_attr
	cls.hp_coefficient = hp_coefficient
	cls.move_range = move_range
	cls.base_attack_skill_id = base_attack_skill_id
	var tendencies: Array[TendencyDef] = [tendency_a, tendency_b]
	cls.tendencies = tendencies
	cls.comment = "【占位·试玩校准】属性区间/资源换算/生命系数/移动来源：17 案 §3.1/§3.2（17-C2/17-C8）+ 案 10 §2.1/§2.4"
	return cls

func _MakeTendency(tendency_id: StringName, display_name: String, focus_attrs: Array[StringName]) -> TendencyDef:
	## 构建 TendencyDef 内嵌子资源（案 10 §2.4 倾向清单；盗贼刺杀不含幸运=17-C18）
	## 参数：倾向 id / 中文名 / 侧重属性集
	## 返回：填充完成的 TendencyDef
	var tendency := TendencyDef.new()
	tendency.id = tendency_id
	tendency.display_name = display_name
	tendency.focus_attrs = focus_attrs
	return tendency

# =========================================================================
# 技能域 class/skills（23 张，SkillDef；17 案 §3.4 + §3.8 敌方技能表）
# =========================================================================

func _GenerateSkills() -> bool:
	## 生成 23 张技能表（6 职业普攻 + 12 职业档 1 技 + 4 敌方技 + 1 敌方通用普攻）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	# ---- 六职业内置普攻（tier=0 内置、资源 0、权重=职业换算源属性 1.0，D3 定稿）----
	ok = _SaveResource(_MakeAttackSkill(&"skl_atk_warrior", "挥击", &"cls_warrior",
		{ATTR_STRENGTH: 1.0}, SkillDef.DamageType.PHYSICAL), "res://data/class/skills/skl_atk_warrior.tres") and ok
	ok = _SaveResource(_MakeAttackSkill(&"skl_atk_rogue", "突刺", &"cls_rogue",
		{ATTR_AGILITY: 1.0}, SkillDef.DamageType.PHYSICAL), "res://data/class/skills/skl_atk_rogue.tres") and ok
	ok = _SaveResource(_MakeAttackSkill(&"skl_atk_mage", "魔弹", &"cls_mage",
		{ATTR_INTELLIGENCE: 1.0}, SkillDef.DamageType.MAGICAL), "res://data/class/skills/skl_atk_mage.tres") and ok
	ok = _SaveResource(_MakeAttackSkill(&"skl_atk_priest", "圣击", &"cls_priest",
		{ATTR_PERCEPTION: 1.0}, SkillDef.DamageType.MAGICAL), "res://data/class/skills/skl_atk_priest.tres") and ok
	ok = _SaveResource(_MakeAttackSkill(&"skl_atk_ranger", "射击", &"cls_ranger",
		{ATTR_AGILITY: 1.0}, SkillDef.DamageType.PHYSICAL), "res://data/class/skills/skl_atk_ranger.tres") and ok
	ok = _SaveResource(_MakeAttackSkill(&"skl_atk_arcanist", "咒击", &"cls_arcanist",
		{ATTR_WILLPOWER: 1.0}, SkillDef.DamageType.MAGICAL), "res://data/class/skills/skl_atk_arcanist.tres") and ok
	# ---- 职业档 1 技能（12 张，17 案 §3.4 DEMO 技能参数表）----
	ok = _SaveResource(_MakeSkill(&"skl_warrior_power_strike", "痛击", &"cls_warrior", 1,
		SkillDef.ResourceKind.STAMINA, 8, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.SINGLE,
		1, _Weights({ATTR_STRENGTH: 0.6, ATTR_CONSTITUTION: 0.4}),
		SkillDef.DamageType.PHYSICAL, 1.3, []), "res://data/class/skills/skl_warrior_power_strike.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_warrior_shield_wall", "盾墙", &"cls_warrior", 1,
		SkillDef.ResourceKind.STAMINA, 6, SkillDef.TargetSide.SELF, SkillDef.TargetShape.SINGLE,
		0, _Weights({}), SkillDef.DamageType.NONE, 0.0,
		[_EffectStatus(&"BUFF_shield_wall", 2, 0.0)]), "res://data/class/skills/skl_warrior_shield_wall.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_rogue_backstab", "背刺", &"cls_rogue", 1,
		SkillDef.ResourceKind.STAMINA, 10, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.SINGLE,
		1, _Weights({ATTR_AGILITY: 0.8, ATTR_LUCK: 0.2}),
		SkillDef.DamageType.PHYSICAL, 1.6,
		[_EffectCombatMod(&"crit_bonus", 0.10)]), "res://data/class/skills/skl_rogue_backstab.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_rogue_sprint", "疾步", &"cls_rogue", 1,
		SkillDef.ResourceKind.STAMINA, 8, SkillDef.TargetSide.SELF, SkillDef.TargetShape.SINGLE,
		0, _Weights({}), SkillDef.DamageType.NONE, 0.0,
		[_EffectStatus(&"BUFF_sprint", 0, 0.0)]), "res://data/class/skills/skl_rogue_sprint.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_mage_fireball", "火球术", &"cls_mage", 1,
		SkillDef.ResourceKind.MANA, 12, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.SINGLE,
		5, _Weights({ATTR_INTELLIGENCE: 1.0}),
		SkillDef.DamageType.MAGICAL, 1.4, []), "res://data/class/skills/skl_mage_fireball.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_mage_frost_chain", "寒冰锁链", &"cls_mage", 1,
		SkillDef.ResourceKind.MANA, 10, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.SINGLE,
		5, _Weights({ATTR_INTELLIGENCE: 1.0}),
		SkillDef.DamageType.MAGICAL, 0.6,
		[_EffectStatus(&"DEBUFF_root", 1, 0.0), _EffectStatus(&"DEBUFF_slow", 2, 0.0)]),
		"res://data/class/skills/skl_mage_frost_chain.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_priest_heal", "治愈术", &"cls_priest", 1,
		SkillDef.ResourceKind.MANA, 10, SkillDef.TargetSide.ALLY, SkillDef.TargetShape.SINGLE,
		5, _Weights({}), SkillDef.DamageType.NONE, 0.0,
		[_EffectHeal(ATTR_PERCEPTION, 1.5, 10)]), "res://data/class/skills/skl_priest_heal.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_priest_smite", "圣光惩击", &"cls_priest", 1,
		SkillDef.ResourceKind.MANA, 8, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.SINGLE,
		5, _Weights({ATTR_PERCEPTION: 1.0}),
		SkillDef.DamageType.MAGICAL, 1.2,
		[_EffectCombatMod(&"race_undead_damage_mult", 1.5)]), "res://data/class/skills/skl_priest_smite.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_ranger_piercing_arrow", "穿云箭", &"cls_ranger", 1,
		SkillDef.ResourceKind.STAMINA, 8, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.SINGLE,
		5, _Weights({ATTR_AGILITY: 1.0}),
		SkillDef.DamageType.PHYSICAL, 1.3, []), "res://data/class/skills/skl_ranger_piercing_arrow.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_ranger_set_trap", "布置陷阱", &"cls_ranger", 1,
		SkillDef.ResourceKind.STAMINA, 8, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.CELL,
		5, _Weights({}), SkillDef.DamageType.NONE, 0.0,
		[_EffectTileSpawn(&"tile_trap", "agility*1.0")]), "res://data/class/skills/skl_ranger_set_trap.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_arcanist_curse", "蚀命诅咒", &"cls_arcanist", 1,
		SkillDef.ResourceKind.MANA, 8, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.SINGLE,
		5, _Weights({ATTR_WILLPOWER: 1.0}),
		SkillDef.DamageType.NONE, 0.0,
		[_EffectStatus(&"DEBUFF_curse", 3, 0.0)]), "res://data/class/skills/skl_arcanist_curse.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_arcanist_bewitch", "蛊惑", &"cls_arcanist", 1,
		SkillDef.ResourceKind.MANA, 10, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.SINGLE,
		5, _Weights({}), SkillDef.DamageType.NONE, 0.0,
		[_EffectStatus(&"DEBUFF_bewitch", 1, 0.0)]), "res://data/class/skills/skl_arcanist_bewitch.tres") and ok
	# ---- 敌方技能（4 张，17 案 §3.8 敌方技能表 17-C12~C15）----
	ok = _SaveResource(_MakeSkill(&"skl_enemy_plague_bite", "疫病撕咬", &"en_m1_mutant_rat", 0,
		SkillDef.ResourceKind.STAMINA, 6, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.SINGLE,
		1, _Weights({ATTR_STRENGTH: 0.6, ATTR_CONSTITUTION: 0.4}),
		SkillDef.DamageType.PHYSICAL, 0.9,
		[_EffectStatus(&"DEBUFF_slow", 1, 0.0)]), "res://data/class/skills/skl_enemy_plague_bite.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_enemy_dirty_trick", "下流偷袭", &"en_m1_goblin_miner", 0,
		SkillDef.ResourceKind.STAMINA, 6, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.SINGLE,
		1, _Weights({ATTR_STRENGTH: 0.6, ATTR_AGILITY: 0.4}),
		SkillDef.DamageType.PHYSICAL, 0.9,
		[_EffectCombatMod(&"crit_bonus", 0.10)]), "res://data/class/skills/skl_enemy_dirty_trick.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_enemy_relentless", "穷追猛打", &"en_m1_elite_boss", 0,
		SkillDef.ResourceKind.STAMINA, 8, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.SINGLE,
		1, _Weights({ATTR_STRENGTH: 0.7, ATTR_CONSTITUTION: 0.3}),
		SkillDef.DamageType.PHYSICAL, 1.0,
		[_EffectStatus(&"DEBUFF_slow", 1, 0.0)]), "res://data/class/skills/skl_enemy_relentless.tres") and ok
	ok = _SaveResource(_MakeSkill(&"skl_enemy_intimidating_roar", "威吓怒吼", &"en_m1_elite_boss", 0,
		SkillDef.ResourceKind.STAMINA, 12, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.AURA_3X3,
		0, _Weights({}), SkillDef.DamageType.NONE, 0.0,
		[_EffectStatus(&"DEBUFF_slow", 1, 0.0)]), "res://data/class/skills/skl_enemy_intimidating_roar.tres") and ok
	# ---- 敌方通用普攻（17-C16 承接行：owner 空串=「敌方·通用」，全库唯一放行）----
	ok = _SaveResource(_MakeAttackSkill(&"skl_atk_enemy_common", "敌方普攻", &"",
		{ATTR_STRENGTH: 1.0}, SkillDef.DamageType.PHYSICAL), "res://data/class/skills/skl_atk_enemy_common.tres") and ok
	return ok

func _MakeAttackSkill(skill_id: StringName, display_name: String, owner_id: StringName,
		weights: Dictionary, damage_type: SkillDef.DamageType) -> SkillDef:
	## 构建普攻技能（tier=0 内置、无资源、射程 1、单体近战、系数 1.0）
	## 参数：技能 id / 中文名 / 所属者（敌方通用普攻为空串）/ 权重表 / 伤害类型
	## 返回：填充完成的 SkillDef
	return _MakeSkill(skill_id, display_name, owner_id, 0,
		SkillDef.ResourceKind.NONE, 0, SkillDef.TargetSide.ENEMY, SkillDef.TargetShape.SINGLE,
		1, _Weights(weights), damage_type, 1.0, [])

func _MakeSkill(skill_id: StringName, display_name: String, owner_id: StringName, tier: int,
		resource_type: SkillDef.ResourceKind, resource_cost: int,
		target_side: SkillDef.TargetSide, target_shape: SkillDef.TargetShape,
		skill_range: int, attr_weights: Dictionary[StringName, float],
		damage_type: SkillDef.DamageType, power_coefficient: float,
		effects: Array) -> SkillDef:
	## 构建 SkillDef 资源（effects 为 SkillEffect 数组字面量）
	## 参数：见 SkillDef 字段
	## 返回：填充完成的 SkillDef
	var skill := SkillDef.new()
	skill.id = skill_id
	skill.display_name = display_name
	# side 判定：owner 为敌人（en_ 前缀）或敌方通用普攻（owner 空）→ ENEMY；职业 → ALLY
	skill.side = SkillDef.SkillSide.ENEMY if String(owner_id).begins_with("en_") or owner_id == &"" else SkillDef.SkillSide.ALLY
	skill.owner_id = owner_id
	skill.tier = tier
	skill.resource_type = resource_type
	skill.resource_cost = resource_cost
	skill.target_side = target_side
	skill.target_shape = target_shape
	skill.range = skill_range
	skill.attr_weights = attr_weights
	skill.damage_type = damage_type
	skill.power_coefficient = power_coefficient
	var typed_effects: Array[SkillEffect] = []
	for effect: SkillEffect in effects:
		typed_effects.append(effect)
	skill.effects = typed_effects
	skill.comment = "【占位·试玩校准】参数来源：17 案 §3.4（DEMO 技能参数表）/§3.8（敌方技能表 17-C12~C16）"
	return skill

func _Weights(weights: Dictionary) -> Dictionary[StringName, float]:
	## 构建属性权重类型化字典（入参为 {StringName: float} 字面量）
	## 参数 weights：权重表字面量
	## 返回：Dictionary[StringName, float]
	var typed: Dictionary[StringName, float] = {}
	for attr_id: StringName in SEVEN_ATTRS:
		if weights.has(attr_id):
			typed[attr_id] = weights[attr_id]
	return typed

func _EffectStatus(status_id: StringName, duration: int, power: float) -> SkillEffect:
	## 构建 STATUS_APPLY 效果子资源
	## 参数：状态 id / 持续回合（0=用默认或即时）/ 强度参数
	## 返回：SkillEffect
	var effect := SkillEffect.new()
	effect.effect_kind = SkillEffect.EffectKind.STATUS_APPLY
	effect.status_id = status_id
	effect.duration = duration
	effect.power = power
	return effect

func _EffectHeal(source_attr: StringName, ratio: float, flat: int) -> SkillEffect:
	## 构建 HEAL 效果子资源（恢复 = 源属性 × ratio + flat）
	## 参数：换算源属性 / 比率 / 固定值
	## 返回：SkillEffect
	var effect := SkillEffect.new()
	effect.effect_kind = SkillEffect.EffectKind.HEAL
	effect.source_attr = source_attr
	effect.ratio = ratio
	effect.flat = flat
	return effect

func _EffectTileSpawn(tile_type_id: StringName, damage_expr: String) -> SkillEffect:
	## 构建 TILE_SPAWN 效果子资源（固定值直接结算、免两段判定与减免轨——D7 口径）
	## 参数：地格类型 id / 伤害表达式
	## 返回：SkillEffect
	var effect := SkillEffect.new()
	effect.effect_kind = SkillEffect.EffectKind.TILE_SPAWN
	effect.tile_type_id = tile_type_id
	effect.damage_expr = damage_expr
	return effect

func _EffectCombatMod(key: StringName, value: float) -> SkillEffect:
	## 构建 COMBAT_MOD 效果子资源（如 crit_bonus / race_undead_damage_mult）
	## 参数：修正键 / 修正值
	## 返回：SkillEffect
	var effect := SkillEffect.new()
	effect.effect_kind = SkillEffect.EffectKind.COMBAT_MOD
	effect.key = key
	effect.value = value
	return effect

# =========================================================================
# 状态域 status/stats（11 张，StatusDef；17 案 §3.9 + 案 11）
# =========================================================================

func _GenerateStatuses() -> bool:
	## 生成 11 张状态表（陷阱无状态条目——第九轮拍板，纯伤害地格）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	# ---- 技能来源（SKILL）8 条 ----
	ok = _SaveResource(_MakeStatus(&"BUFF_shield_wall", "盾墙",
		StatusDef.Category.STAT_MOD, StatusDef.Polarity.BUFF,
		{&"armor_physical": 4.0}, null, StatusDef.ControlKind.NONE,
		2, [&"SKILL"], &"", "物理护甲 +4（17 案 §3.4 盾墙行）"),
		"res://data/status/stats/BUFF_shield_wall.tres") and ok
	ok = _SaveResource(_MakeStatus(&"BUFF_sprint", "疾步",
		StatusDef.Category.STAT_MOD, StatusDef.Polarity.BUFF,
		{&"move_range": 2.0, &"dodge": 0.15}, null, StatusDef.ControlKind.NONE,
		0, [&"SKILL"], &"", "本回合移动力 +2、闪避 +15%（duration=0 即时生效）"),
		"res://data/status/stats/BUFF_sprint.tres") and ok
	ok = _SaveResource(_MakeStatus(&"DEBUFF_root", "定身",
		StatusDef.Category.CONTROL, StatusDef.Polarity.DEBUFF,
		{}, null, StatusDef.ControlKind.ROOT,
		1, [&"SKILL"], &"mgrp_control", "硬控制：无法移动，1 回合（17 案 §3.9）"),
		"res://data/status/stats/DEBUFF_root.tres") and ok
	ok = _SaveResource(_MakeStatus(&"DEBUFF_slow", "减速",
		StatusDef.Category.STAT_MOD, StatusDef.Polarity.DEBUFF,
		{&"move_range": -2.0}, null, StatusDef.ControlKind.NONE,
		2, [&"SKILL"], &"", "移动力 −2；我方施加 2 回合/敌方施加 1 回合（技能 effect duration 覆盖）；同名不叠加取较大（P-10）"),
		"res://data/status/stats/DEBUFF_slow.tres") and ok
	ok = _SaveResource(_MakeStatus(&"DEBUFF_curse", "蚀命诅咒",
		StatusDef.Category.DOT, StatusDef.Polarity.DEBUFF,
		{}, _MakeDot(DotParams.Mode.ATTR_RATIO, 0, ATTR_WILLPOWER, 0.5), StatusDef.ControlKind.NONE,
		3, [&"SKILL"], &"", "每跳 = 意志 × 0.5，持续 3 回合；跳伤不过减免轨（17 案 §3.4 已定稿）"),
		"res://data/status/stats/DEBUFF_curse.tres") and ok
	ok = _SaveResource(_MakeStatus(&"DEBUFF_bewitch", "蛊惑",
		StatusDef.Category.CONTROL, StatusDef.Polarity.DEBUFF,
		{}, null, StatusDef.ControlKind.BEWITCH,
		1, [&"SKILL"], &"mgrp_control", "延迟型控制：下回合行动异常，1 回合（案 10 §2.3）"),
		"res://data/status/stats/DEBUFF_bewitch.tres") and ok
	# ---- 检定带入（CHECKIN）2 条 ----
	ok = _SaveResource(_MakeStatus(&"DEBUFF_exposed", "暴露减益",
		StatusDef.Category.STAT_MOD, StatusDef.Polarity.DEBUFF,
		{&"dodge": -0.10}, null, StatusDef.ControlKind.NONE,
		1, [&"CHECKIN"], &"", "闪避 −10%、持续 1 回合（18 案链二被伏击出口/18-C7）【占位·试玩校准】"),
		"res://data/status/stats/DEBUFF_exposed.tres") and ok
	ok = _SaveResource(_MakeStatus(&"BUFF_ambush", "伏击增益",
		StatusDef.Category.STAT_MOD, StatusDef.Polarity.BUFF,
		{&"hit": 0.10}, null, StatusDef.ControlKind.NONE,
		1, [&"CHECKIN"], &"", "命中 +10%、持续 1 回合（参照 DEBUFF_exposed 式样，18 案伏击链）【占位·完整版启用时生效】"),
		"res://data/status/stats/BUFF_ambush.tres") and ok
	# ---- 地格来源（TILE）3 条（17 案 §3.9 地格效果）----
	ok = _SaveResource(_MakeStatus(&"BUFF_tile_grass", "草丛遮蔽",
		StatusDef.Category.STAT_MOD, StatusDef.Polarity.BUFF,
		{&"dodge": 0.15}, null, StatusDef.ControlKind.NONE,
		0, [&"TILE"], &"", "草丛格：闪避 +15%（站格期间持续，离格移除）"),
		"res://data/status/stats/BUFF_tile_grass.tres") and ok
	ok = _SaveResource(_MakeStatus(&"BUFF_tile_highground", "高地压制",
		StatusDef.Category.STAT_MOD, StatusDef.Polarity.BUFF,
		{&"damage_panel_mult": 1.2}, null, StatusDef.ControlKind.NONE,
		0, [&"TILE"], &"", "高地格：面板伤害 ×1.2（随技能系数同层乘算：(Σ权重×属性+武器)×系数×1.2，17 案 §3.9）"),
		"res://data/status/stats/BUFF_tile_highground.tres") and ok
	ok = _SaveResource(_MakeStatus(&"DEBUFF_tile_poison", "毒沼",
		StatusDef.Category.DOT, StatusDef.Polarity.DEBUFF,
		{}, _MakeDot(DotParams.Mode.FIXED, 6, &"", 0.0), StatusDef.ControlKind.NONE,
		0, [&"TILE"], &"", "毒沼格：回合末固定 6 伤，固定值直接结算、不走减免轨（§3.9，同陷阱 D7 口径）"),
		"res://data/status/stats/DEBUFF_tile_poison.tres") and ok
	return ok

func _MakeStatus(status_id: StringName, display_name: String,
		category: StatusDef.Category, polarity: StatusDef.Polarity,
		modifiers: Dictionary, dot: DotParams, control_kind: StatusDef.ControlKind,
		default_duration: int, allowed_sources: Array, mutex_group_id: StringName,
		comment: String) -> StatusDef:
	## 构建 StatusDef 资源（comment 落 remove_policy 之外的备注？——见 _MakeStatus 实现注）
	## 参数：见 StatusDef 字段；comment 为设计备注（写入 stack_rule 注释性 token 外的
	## 备查信息，实际存于生成器与命名登记表，不落 .tres 字段）
	## 返回：填充完成的 StatusDef
	var status := StatusDef.new()
	status.id = status_id
	status.display_name = display_name
	status.category = category
	status.polarity = polarity
	var typed_modifiers: Dictionary[StringName, float] = {}
	for key: StringName in modifiers:
		typed_modifiers[key] = modifiers[key]
	status.modifiers = typed_modifiers
	status.dot = dot
	status.control_kind = control_kind
	status.default_duration = default_duration
	status.duration_type = StatusDef.DurationType.BATTLE_ROUND
	status.stack_rule = &"no_stack_take_larger"
	status.mutex_group_id = mutex_group_id
	var typed_sources: Array[StringName] = []
	for source: StringName in allowed_sources:
		typed_sources.append(source)
	status.allowed_sources = typed_sources
	# 地格类状态：离格移除；其余回合流逝
	if allowed_sources.has(&"TILE"):
		status.remove_policy = &"on_leave_tile"
	status.icon_id = &""
	# 设计备注落 comment 字段（任务要求全部 .tres 标【占位·试玩校准】）
	status.comment = "【占位·试玩校准】" + comment
	return status

func _MakeDot(mode: DotParams.Mode, fixed: int, attr_id: StringName, ratio: float) -> DotParams:
	## 构建 DOT 参数子资源
	## 参数：模式 / 固定值 / 源属性 / 比率
	## 返回：DotParams
	var dot := DotParams.new()
	dot.mode = mode
	dot.fixed = fixed
	dot.attr_id = attr_id
	dot.ratio = ratio
	return dot

# =========================================================================
# 互斥组域 status/mutex_groups（1 张，MutexGroupDef）
# =========================================================================

func _GenerateMutexGroups() -> bool:
	## 生成互斥组（17 案 §3.9：定身/蛊惑互斥——已定示例）
	## 参数：无
	## 返回：true = 保存成功
	var group := MutexGroupDef.new()
	group.id = &"mgrp_control"
	var members: Array[StringName] = [&"DEBUFF_root", &"DEBUFF_bewitch"]
	group.members = members
	group.comment = "【占位·试玩校准】定身/蛊惑互斥（17 案 §3.9 已定示例）"
	return _SaveResource(group, "res://data/status/mutex_groups/mgrp_control.tres")

# =========================================================================
# 敌人域 battle/enemies（3 张，EnemyDef；17 案 §3.8 区间中值）
# =========================================================================

func _GenerateEnemies() -> bool:
	## 生成 3 张敌人表（杂兵 2 + 精英 1；区间中值，杂兵武器 2-3 取上值 3）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	ok = _SaveResource(_MakeEnemy(&"en_m1_mutant_rat", "变异鼠", &"trash",
		EnemyDef.RaceTag.BEAST, 9, 55, 3, 2, 0.0, 4, 12, [&"skl_enemy_plague_bite"]),
		"res://data/battle/enemies/en_m1_mutant_rat.tres") and ok
	ok = _SaveResource(_MakeEnemy(&"en_m1_goblin_miner", "哥布林矿工", &"trash",
		EnemyDef.RaceTag.HUMANOID, 9, 55, 3, 2, 0.0, 4, 12, [&"skl_enemy_dirty_trick"]),
		"res://data/battle/enemies/en_m1_goblin_miner.tres") and ok
	ok = _SaveResource(_MakeEnemy(&"en_m1_elite_boss", "矿洞祸首", &"elite",
		EnemyDef.RaceTag.HUMANOID, 11, 110, 4, 4, 0.05, 4, 32,
		[&"skl_enemy_relentless", &"skl_enemy_intimidating_roar"]),
		"res://data/battle/enemies/en_m1_elite_boss.tres") and ok
	return ok

func _MakeEnemy(enemy_id: StringName, display_name: String, role_tag: StringName,
		race_tag: EnemyDef.RaceTag, attr_value: int, hp: int, weapon_bonus: int,
		armor: int, resist_pct: float, move_range: int, resource_pool: int,
		skill_ids: Array) -> EnemyDef:
	## 构建 EnemyDef 资源（七属性同值填充——17 案 §3.8「全 8-10/全 10-12」中值 9/11）
	## 参数：见 EnemyDef 字段（attr_value 为七属性统一值）
	## 返回：填充完成的 EnemyDef
	var enemy := EnemyDef.new()
	enemy.id = enemy_id
	enemy.display_name = display_name
	enemy.role_tag = role_tag
	enemy.race_tag = race_tag
	var attrs: Dictionary[StringName, int] = {}
	for attr_id: StringName in SEVEN_ATTRS:
		attrs[attr_id] = attr_value
	enemy.attrs = attrs
	enemy.hp = hp
	enemy.weapon_bonus = weapon_bonus
	enemy.armor = armor
	enemy.resist_pct = resist_pct
	enemy.move_range = move_range
	enemy.resource_pool = resource_pool
	var typed_skills: Array[StringName] = []
	for skill_id: StringName in skill_ids:
		typed_skills.append(skill_id)
	enemy.skill_ids = typed_skills
	enemy.common_attack_skill_id = &"skl_atk_enemy_common"
	enemy.ai_level = 1
	enemy.drop_ref = &""
	enemy.portrait_id = &""
	enemy.comment = "【占位·试玩校准】区间中值来源 17 案 §3.8（杂兵武器加值区间 2-3 取上值 3，见完成报告偏差注）；护甲物理/法术双轨同值（§3.8 表注）"
	return enemy

# =========================================================================
# 敌方队伍域 battle/enemy_packs（3 张，EnemyPackDef；17 案 §3.8 配置 + 18 案 §4.1）
# =========================================================================

func _GenerateEnemyPacks() -> bool:
	## 生成 3 张敌方队伍表（battle_map_ref 留空——地图系统批 4 落地后回填）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	# 随机遭遇：池（鼠/哥布林）×3（17 案 §3.8 配置「随机遭遇 3 只」）
	var random_pack := EnemyPackDef.new()
	random_pack.id = &"enc_m1_random_pack"
	var random_entries: Array[PackEntry] = [_MakePackEntry([&"en_m1_mutant_rat", &"en_m1_goblin_miner"], 3, 3, false)]
	random_pack.entries = random_entries
	random_pack.comment = "【占位·试玩校准】随机遭遇：池（鼠/哥布林）×3（17 案 §3.8 配置）；battle_map_ref 批 4 地图系统落地后回填（随机图 8×8）"
	ok = _SaveResource(random_pack, "res://data/battle/enemy_packs/enc_m1_random_pack.tres") and ok
	# 必然遭遇：精英 ×1 + 池（鼠/哥布林）×2-3（17 案 §3.8「1 精英+2-3 杂兵」）
	var lair_pack := EnemyPackDef.new()
	lair_pack.id = &"enc_m1_lair_pack"
	var lair_entries: Array[PackEntry] = [
		_MakePackEntry([&"en_m1_elite_boss"], 1, 1, true),
		_MakePackEntry([&"en_m1_mutant_rat", &"en_m1_goblin_miner"], 2, 3, false),
	]
	lair_pack.entries = lair_entries
	lair_pack.comment = "【占位·试玩校准】必然遭遇：精英×1 + 池（鼠/哥布林）×2-3（17 案 §3.8 配置）；battle_map_ref 批 4 回填（必然图 10×10）"
	ok = _SaveResource(lair_pack, "res://data/battle/enemy_packs/enc_m1_lair_pack.tres") and ok
	# 事件 B 出口遭遇：鼠 ×2 + 哥布林 ×1（18 案 §4.1，复用矿道随机图 8×8）
	var wisp_pack := EnemyPackDef.new()
	wisp_pack.id = &"enc_m1_wisp_nest"
	var wisp_entries: Array[PackEntry] = [
		_MakePackEntry([&"en_m1_mutant_rat"], 2, 2, false),
		_MakePackEntry([&"en_m1_goblin_miner"], 1, 1, false),
	]
	wisp_pack.entries = wisp_entries
	wisp_pack.comment = "【占位·试玩校准】事件 B 出口遭遇：鼠×2 + 哥布林×1（18 案 §4.1）；battle_map_ref 批 4 回填（复用矿道随机图 8×8）"
	ok = _SaveResource(wisp_pack, "res://data/battle/enemy_packs/enc_m1_wisp_nest.tres") and ok
	return ok

func _MakePackEntry(enemy_ids: Array, count_min: int, count_max: int, is_elite: bool) -> PackEntry:
	## 构建队伍条目子资源
	## 参数：候选敌人 id 池 / 数量区间 / 精英位标记
	## 返回：PackEntry
	var entry := PackEntry.new()
	var typed_ids: Array[StringName] = []
	for enemy_id: StringName in enemy_ids:
		typed_ids.append(enemy_id)
	entry.enemy_ids = typed_ids
	entry.count_min = count_min
	entry.count_max = count_max
	entry.is_elite = is_elite
	return entry

# =========================================================================
# 资源命名登记表 data/core/naming_registry.tres（重写批 1 版，扩至全库 48 条）
# =========================================================================

func _GenerateNamingRegistry() -> bool:
	## 重写命名登记表（用户拍板②：全库资源命名信息集中登记，48 条 = 47 新表 + cfg_main）
	## 参数：无
	## 返回：true = 保存成功
	var registry := NamingRegistry.new()
	var entries: Array[NamingEntry] = []
	# ---- core 域（2 条登记：cfg_main；naming_registry 自身不登记）----
	entries.append(_MakeNamingEntry(&"cfg_main", &"core", "总控配置",
		"core 域固定主配置名：cfg_ 前缀 + main（全库唯一，不随内容扩展）；文件名与 id 同名"))
	# ---- class/classes 域（6 条）----
	var class_rules: Dictionary = {
		&"cls_warrior": ["战士", "cls_<英文职业名>：职业定义表；六职业英文名与案 20 用例一致（warrior/rogue/mage/priest/ranger/arcanist）"],
		&"cls_rogue": ["盗贼", "cls_<英文职业名>：职业定义表；文件名与 id 同名"],
		&"cls_mage": ["法师", "cls_<英文职业名>：职业定义表；文件名与 id 同名"],
		&"cls_priest": ["牧师", "cls_<英文职业名>：职业定义表；文件名与 id 同名"],
		&"cls_ranger": ["游侠", "cls_<英文职业名>：职业定义表；文件名与 id 同名"],
		&"cls_arcanist": ["奇术师", "cls_<英文职业名>：职业定义表；文件名与 id 同名"],
	}
	for class_id: StringName in class_rules:
		entries.append(_MakeNamingEntry(class_id, &"class/classes",
			class_rules[class_id][0], class_rules[class_id][1]))
	# ---- class/skills 域（23 条）----
	var skill_rules: Dictionary = {
		&"skl_atk_warrior": ["挥击（战士普攻）", "skl_atk_<职业>：职业内置普攻（tier=0 出生自带，D3 定细 2026-09-23）"],
		&"skl_atk_rogue": ["突刺（盗贼普攻）", "skl_atk_<职业>：职业内置普攻"],
		&"skl_atk_mage": ["魔弹（法师普攻）", "skl_atk_<职业>：职业内置普攻"],
		&"skl_atk_priest": ["圣击（牧师普攻）", "skl_atk_<职业>：职业内置普攻"],
		&"skl_atk_ranger": ["射击（游侠普攻）", "skl_atk_<职业>：职业内置普攻"],
		&"skl_atk_arcanist": ["咒击（奇术师普攻）", "skl_atk_<职业>：职业内置普攻"],
		&"skl_atk_enemy_common": ["敌方普攻", "skl_atk_enemy_common：敌方通用普攻（17-C16 承接行，owner 空=敌方·通用，全库唯一 owner 放行）"],
		&"skl_warrior_power_strike": ["痛击", "skl_<职业>_<英文>：职业主动技能，owner 归属 cls_warrior、tier=1 档"],
		&"skl_warrior_shield_wall": ["盾墙", "skl_<职业>_<英文>：职业主动技能，owner 归属 cls_warrior、tier=1 档"],
		&"skl_rogue_backstab": ["背刺", "skl_<职业>_<英文>：职业主动技能，owner 归属 cls_rogue、tier=1 档"],
		&"skl_rogue_sprint": ["疾步", "skl_<职业>_<英文>：职业主动技能，owner 归属 cls_rogue、tier=1 档"],
		&"skl_mage_fireball": ["火球术", "skl_<职业>_<英文>：职业主动技能，owner 归属 cls_mage、tier=1 档"],
		&"skl_mage_frost_chain": ["寒冰锁链", "skl_<职业>_<英文>：职业主动技能，owner 归属 cls_mage、tier=1 档"],
		&"skl_priest_heal": ["治愈术", "skl_<职业>_<英文>：职业主动技能，owner 归属 cls_priest、tier=1 档"],
		&"skl_priest_smite": ["圣光惩击", "skl_<职业>_<英文>：职业主动技能，owner 归属 cls_priest、tier=1 档"],
		&"skl_ranger_piercing_arrow": ["穿云箭", "skl_<职业>_<英文>：职业主动技能，owner 归属 cls_ranger、tier=1 档"],
		&"skl_ranger_set_trap": ["布置陷阱", "skl_<职业>_<英文>：职业主动技能，owner 归属 cls_ranger、tier=1 档"],
		&"skl_arcanist_curse": ["蚀命诅咒", "skl_<职业>_<英文>：职业主动技能，owner 归属 cls_arcanist、tier=1 档"],
		&"skl_arcanist_bewitch": ["蛊惑", "skl_<职业>_<英文>：职业主动技能，owner 归属 cls_arcanist、tier=1 档"],
		&"skl_enemy_plague_bite": ["疫病撕咬", "skl_enemy_<英文>：敌方技能（17-C12），owner 归属 en_m1_mutant_rat"],
		&"skl_enemy_dirty_trick": ["下流偷袭", "skl_enemy_<英文>：敌方技能（17-C13），owner 归属 en_m1_goblin_miner"],
		&"skl_enemy_relentless": ["穷追猛打", "skl_enemy_<英文>：敌方技能（17-C14），owner 归属 en_m1_elite_boss"],
		&"skl_enemy_intimidating_roar": ["威吓怒吼", "skl_enemy_<英文>：敌方技能（17-C15），owner 归属 en_m1_elite_boss"],
	}
	for skill_id: StringName in skill_rules:
		entries.append(_MakeNamingEntry(skill_id, &"class/skills",
			skill_rules[skill_id][0], skill_rules[skill_id][1]))
	# ---- status/stats 域（11 条）----
	var status_rules: Dictionary = {
		&"BUFF_shield_wall": ["盾墙", "BUFF_<英文>：增益状态（案 11 式样——大写极性前缀+小写语义）"],
		&"BUFF_sprint": ["疾步", "BUFF_<英文>：增益状态"],
		&"BUFF_ambush": ["伏击增益", "BUFF_<英文>：增益状态（检定带入 CHECKIN 来源）"],
		&"BUFF_tile_grass": ["草丛遮蔽", "BUFF_tile_<地格>：地格来源状态（TILE）"],
		&"BUFF_tile_highground": ["高地压制", "BUFF_tile_<地格>：地格来源状态（TILE）"],
		&"DEBUFF_root": ["定身", "DEBUFF_<英文>：减益/控制状态"],
		&"DEBUFF_slow": ["减速", "DEBUFF_<英文>：减益状态"],
		&"DEBUFF_curse": ["蚀命诅咒", "DEBUFF_<英文>：减益/DOT 状态"],
		&"DEBUFF_bewitch": ["蛊惑", "DEBUFF_<英文>：减益/控制状态"],
		&"DEBUFF_exposed": ["暴露减益", "DEBUFF_<英文>：减益状态（检定带入 CHECKIN 来源）"],
		&"DEBUFF_tile_poison": ["毒沼", "DEBUFF_tile_<地格>：地格来源状态（TILE）"],
	}
	for status_id: StringName in status_rules:
		entries.append(_MakeNamingEntry(status_id, &"status/stats",
			status_rules[status_id][0], status_rules[status_id][1]))
	# ---- status/mutex_groups 域（1 条）----
	entries.append(_MakeNamingEntry(&"mgrp_control", &"status/mutex_groups", "控制互斥组",
		"mgrp_<语义>：状态互斥组（成员=[DEBUFF_root, DEBUFF_bewitch]，17 案 §3.9 定身/蛊惑互斥）"))
	# ---- battle/enemies 域（3 条）----
	entries.append(_MakeNamingEntry(&"en_m1_mutant_rat", &"battle/enemies", "变异鼠",
		"en_<区域>_<英文>：敌人定义（m1=矿洞一层，18 案区域码）；杂兵 role=trash"))
	entries.append(_MakeNamingEntry(&"en_m1_goblin_miner", &"battle/enemies", "哥布林矿工",
		"en_<区域>_<英文>：敌人定义（m1=矿洞一层）；杂兵 role=trash"))
	entries.append(_MakeNamingEntry(&"en_m1_elite_boss", &"battle/enemies", "矿洞祸首",
		"en_<区域>_<英文>：敌人定义（m1=矿洞一层）；精英 role=elite"))
	# ---- battle/enemy_packs 域（3 条）----
	entries.append(_MakeNamingEntry(&"enc_m1_random_pack", &"battle/enemy_packs", "矿洞随机遭遇队",
		"enc_<区域>_<语义>：敌方队伍配置（随机遭遇：池×3，17 案 §3.8）"))
	entries.append(_MakeNamingEntry(&"enc_m1_lair_pack", &"battle/enemy_packs", "巢穴必然遭遇队",
		"enc_<区域>_<语义>：敌方队伍配置（必然遭遇：1 精英+2-3 杂兵）"))
	entries.append(_MakeNamingEntry(&"enc_m1_wisp_nest", &"battle/enemy_packs", "魔宠巢出口遭遇队",
		"enc_<区域>_<语义>：敌方队伍配置（事件 B 出口遭遇，18 案 §4.1）"))
	registry.entries = entries
	registry.comment = "全库资源命名登记表（用户拍板②·2026-09-23）：每条记录资源 id/域前缀/中文名/命名规则；条目随资源增删同步维护"
	print("gen_m0_batch2_data: naming_registry 登记条目数 = %d" % entries.size())
	return _SaveResource(registry, "res://data/core/naming_registry.tres")

func _MakeNamingEntry(resource_id: StringName, domain: StringName,
		display_name: String, rule_note: String) -> NamingEntry:
	## 构建命名登记条目子资源
	## 参数：资源 id / 所属域键 / 中文名 / 命名规则说明
	## 返回：NamingEntry
	var entry := NamingEntry.new()
	entry.resource_id = resource_id
	entry.domain = domain
	entry.display_name = display_name
	entry.rule_note = rule_note
	return entry
