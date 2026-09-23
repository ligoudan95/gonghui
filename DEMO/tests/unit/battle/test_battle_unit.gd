## BattleUnit/UnitBuilder 单元测试（M1 批 2）
## 覆盖：我方装配（HP/双资源池对 17 案 §3.1-§3.2 数值、装备与技能清单）、
## 敌方装配（表定值直读：flat 护甲/抗性/精力池）、move_final（减速/疾步修正 +
## 负钳 0 + 敏捷 ≥16 加成）、take_damage 倒地即时、派生合并（盾墙修正）、
## 资源扣减、治疗钳上限。
extends GdUnitTestSuite

## 真实数据路径
const CFG_PATH: String = "res://data/core/cfg_main.tres"
const CLS_DIR: String = "res://data/class/classes/"
const EQP_DIR: String = "res://data/equip/"
const ENEMY_DIR: String = "res://data/battle/enemies/"
const STATUS_DIR: String = "res://data/status/stats/"
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级组件
var _cfg: CoreConfig
var _status_manager: StatusManager
var _statuses: Dictionary = {}

func before() -> void:
	## 套件前置：加载 cfg_main 与状态池（重资源一次）
	## 参数：无
	## 返回：无
	_cfg = load(CFG_PATH) as CoreConfig
	for status_id: StringName in [&"BUFF_shield_wall", &"BUFF_sprint", &"DEBUFF_slow"]:
		_statuses[status_id] = load(STATUS_DIR + String(status_id) + ".tres")

func before_test() -> void:
	## 用例前置：重建状态管理器（施加状态为可变态，逐用例隔离）
	## 参数：无
	## 返回：无
	_status_manager = StatusManager.new()
	_status_manager.setup(_cfg, _LookupStatus)

func _LookupStatus(status_id: StringName) -> StatusDef:
	## 状态定义解析闭包
	## 参数 status_id：状态 id
	## 返回：StatusDef
	return _statuses.get(status_id, null)

func _MakeAdv(unit_id: StringName, class_id: StringName, attrs: Dictionary) -> AdventurerData:
	## 构建冒险者出战数据（显式技能清单）
	## 参数 unit_id/class_id/attrs：标识与属性
	## 返回：AdventurerData
	var adv := AdventurerData.new()
	adv.unit_id = unit_id
	adv.class_id = class_id
	adv.attrs = attrs
	adv.skill_ids = []
	return adv

func _WarriorAttrs() -> Dictionary:
	## 战士 17-C7 中值偏上属性（力16/敏10/体14/智7/感9/意9/幸9）
	return {&"strength": 16, &"agility": 10, &"constitution": 14,
			&"intelligence": 7, &"perception": 9, &"willpower": 9, &"luck": 9}

func test_build_ally_warrior() -> void:
	## 我方装配：HP 90（20+14×5+8×0）、双资源池 58（10+力16×3）、
	## 武器 4/护甲 5、技能 = 普攻 + 出战清单
	var adv := _MakeAdv(&"warrior", &"cls_warrior", _WarriorAttrs())
	adv.skill_ids = [&"skl_warrior_power_strike", &"skl_warrior_shield_wall"]
	var unit := UnitBuilder.build_ally(adv, load(CLS_DIR + "cls_warrior.tres") as ClassDef,
			load(EQP_DIR + "eqp_init_warrior.tres") as EquipDef)
	assert_str(String(unit.unit_id)).is_equal("warrior")
	assert_int(unit.side).is_equal(SkillDef.SkillSide.ALLY)
	assert_int(unit.max_hp).is_equal(90)
	assert_int(unit.current_hp).is_equal(90)
	assert_int(unit.max_mana).is_equal(58)
	assert_int(unit.max_stamina).is_equal(58)
	assert_int(unit.weapon_bonus).is_equal(4)
	assert_int(unit.armor_equip).is_equal(5)
	assert_int(unit.base_move_range).is_equal(3)
	assert_str(String(unit.base_attack_id)).is_equal("skl_atk_warrior")
	assert_int(unit.skill_ids.size()).is_equal(3)
	assert_bool(unit.skill_ids.has(&"skl_warrior_power_strike")).is_true()

func test_build_ally_resource_source_by_class() -> void:
	## 资源双轨同源：盗贼源=敏捷 16 → 58；法师源=智力 16 → 58（双池同值，
	## 非本系资源仅供面板显示——§3.2）
	var rogue := UnitBuilder.build_ally(_MakeAdv(&"rogue", &"cls_rogue",
			{&"strength": 10, &"agility": 16, &"constitution": 10, &"intelligence": 9,
			&"perception": 11, &"willpower": 10, &"luck": 13}),
			load(CLS_DIR + "cls_rogue.tres") as ClassDef,
			load(EQP_DIR + "eqp_init_rogue.tres") as EquipDef)
	assert_int(rogue.max_stamina).is_equal(58)
	assert_int(rogue.max_mana).is_equal(58)
	assert_int(rogue.base_move_range).is_equal(5)
	var mage := UnitBuilder.build_ally(_MakeAdv(&"mage", &"cls_mage",
			{&"strength": 7, &"agility": 10, &"constitution": 9, &"intelligence": 16,
			&"perception": 11, &"willpower": 9, &"luck": 9}),
			load(CLS_DIR + "cls_mage.tres") as ClassDef,
			load(EQP_DIR + "eqp_init_mage.tres") as EquipDef)
	assert_int(mage.max_mana).is_equal(58)

func test_build_enemy_flat_defense() -> void:
	## 敌方装配：表定值直读——HP 55/武器 3/精力池 12（法力 0）/flat 护甲 2
	## （不叠属性调：体 9 调 −1 也不减）/抗性 0
	var rat := UnitBuilder.build_enemy(load(ENEMY_DIR + "en_m1_mutant_rat.tres") as EnemyDef, 0)
	assert_int(rat.side).is_equal(SkillDef.SkillSide.ENEMY)
	assert_int(rat.max_hp).is_equal(55)
	assert_int(rat.current_stamina).is_equal(12)
	assert_int(rat.current_mana).is_equal(0)
	assert_int(rat.weapon_bonus).is_equal(3)
	assert_int(rat.phys_armor).is_equal(2)
	assert_int(rat.mag_armor).is_equal(2)
	assert_float(rat.phys_resist).is_equal(0.0)
	var elite := UnitBuilder.build_enemy(load(ENEMY_DIR + "en_m1_elite_boss.tres") as EnemyDef, 0)
	assert_int(elite.phys_armor).is_equal(4)
	assert_float(elite.mag_resist).is_equal_approx(0.05, 0.0001)
	assert_str(String(elite.role_tag)).is_equal("elite")
	assert_str(String(elite.race_tag)).is_equal("humanoid")
	assert_str(String(rat.race_tag)).is_equal("beast")

func test_enemy_unit_id_unique_by_slot() -> void:
	## 敌方 unit_id 唯一化：<enemy_id>_<槽序>（同型多只不撞 id）
	var first := UnitBuilder.build_enemy(load(ENEMY_DIR + "en_m1_mutant_rat.tres") as EnemyDef, 0)
	var second := UnitBuilder.build_enemy(load(ENEMY_DIR + "en_m1_mutant_rat.tres") as EnemyDef, 2)
	assert_str(String(first.unit_id)).is_equal("en_m1_mutant_rat_0")
	assert_str(String(second.unit_id)).is_equal("en_m1_mutant_rat_2")
	assert_str(String(first.id)).is_equal("en_m1_mutant_rat_0")

func test_move_final_modifiers_and_clamp() -> void:
	## 移动力终值：战士 3（敏 10 无加成）；盗贼 5+1=6（敏 16）；减速 −2 → 战士 1；
	## 双减速钳 0；疾步 +2 在基准段（封顶 6）后叠加
	var warrior := UnitBuilder.build_ally(_MakeAdv(&"w", &"cls_warrior", _WarriorAttrs()),
			load(CLS_DIR + "cls_warrior.tres") as ClassDef,
			load(EQP_DIR + "eqp_init_warrior.tres") as EquipDef)
	warrior.bind_battle(_cfg, _status_manager)
	assert_int(warrior.move_final()).is_equal(3)
	var rogue := UnitBuilder.build_ally(_MakeAdv(&"r", &"cls_rogue",
			{&"strength": 10, &"agility": 16, &"constitution": 10, &"intelligence": 9,
			&"perception": 11, &"willpower": 10, &"luck": 13}),
			load(CLS_DIR + "cls_rogue.tres") as ClassDef,
			load(EQP_DIR + "eqp_init_rogue.tres") as EquipDef)
	rogue.bind_battle(_cfg, _status_manager)
	assert_int(rogue.move_final()).is_equal(6)
	_status_manager.apply(warrior, _statuses[&"DEBUFF_slow"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 2, 1, false)
	assert_int(warrior.move_final()).is_equal(1)
	_status_manager.apply(warrior, _statuses[&"DEBUFF_slow"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 2, 1, false)
	# 同名取大不叠加：仍 −2 → 1（叠加走异名同类上限；此处验证不重复扣减）
	assert_int(warrior.move_final()).is_equal(1)
	_status_manager.apply(rogue, _statuses[&"BUFF_sprint"],
			StatusInstance.SourceKind.SKILL, &"skl_rogue_sprint", 0, 1, false)
	assert_int(rogue.move_final()).is_equal(8)

func test_move_final_clamped_zero_when_heavy_slow() -> void:
	## 负钳 0：本地重减速状态（move_range −5）下战士 3−5 → 钳 0（DEMO 池减速
	## 仅 −2 不足以触底，用注入状态验证钳位路径）
	var warrior := UnitBuilder.build_ally(_MakeAdv(&"w", &"cls_warrior", _WarriorAttrs()),
			load(CLS_DIR + "cls_warrior.tres") as ClassDef, null)
	warrior.bind_battle(_cfg, _status_manager)
	var heavy := StatusDef.new()
	heavy.id = &"DEBUFF_heavy_test"
	heavy.category = StatusDef.Category.STAT_MOD
	var mods: Dictionary[StringName, float] = {&"move_range": -5.0}
	heavy.modifiers = mods
	heavy.default_duration = 1
	_statuses[heavy.id] = heavy
	_status_manager.apply(warrior, heavy, StatusInstance.SourceKind.SKILL, &"skl_x", 1, 1, false)
	assert_int(warrior.move_final()).is_equal(0)

func test_take_damage_down_immediate() -> void:
	## 承伤：≤0 即 alive=false（即时退场标记）；返回值标记是否本次倒地
	var warrior := UnitBuilder.build_ally(_MakeAdv(&"w", &"cls_warrior", _WarriorAttrs()),
			load(CLS_DIR + "cls_warrior.tres") as ClassDef, null)
	assert_bool(warrior.take_damage(89)).is_false()
	assert_bool(warrior.alive).is_true()
	assert_int(warrior.current_hp).is_equal(1)
	assert_bool(warrior.take_damage(1)).is_true()
	assert_bool(warrior.alive).is_false()
	assert_int(warrior.current_hp).is_equal(0)

func test_derived_merge_with_status() -> void:
	## 派生合并：盾墙（armor_physical +4）并入物理护甲——5+体调 2+4 = 11；
	## 未施加时 7；敌方 flat 护甲不受盾墙外属性调影响（体 9 调 −1 不减）
	var warrior := UnitBuilder.build_ally(_MakeAdv(&"w", &"cls_warrior", _WarriorAttrs()),
			load(CLS_DIR + "cls_warrior.tres") as ClassDef,
			load(EQP_DIR + "eqp_init_warrior.tres") as EquipDef)
	warrior.bind_battle(_cfg, _status_manager)
	assert_int(warrior.phys_armor).is_equal(7)
	_status_manager.apply(warrior, _statuses[&"BUFF_shield_wall"],
			StatusInstance.SourceKind.SKILL, &"skl_warrior_shield_wall", 2, 1, false)
	assert_int(warrior.phys_armor).is_equal(11)
	assert_float(warrior.hit).is_equal_approx(0.78, 0.0001)
	assert_float(warrior.dodge).is_equal_approx(0.05, 0.0001)

func test_speed_for_order() -> void:
	## 排序速度 = 敏捷原始值（速度 ±N 排序修正 DEMO 池无数据——回归敏捷值）
	var warrior := UnitBuilder.build_ally(_MakeAdv(&"w", &"cls_warrior", _WarriorAttrs()),
			load(CLS_DIR + "cls_warrior.tres") as ClassDef, null)
	assert_int(warrior.speed_for_order()).is_equal(10)

func test_spend_resource_atomic() -> void:
	## 资源扣减：充足扣减返回 true；不足返回 false 不扣（原子口径）
	var warrior := UnitBuilder.build_ally(_MakeAdv(&"w", &"cls_warrior", _WarriorAttrs()),
			load(CLS_DIR + "cls_warrior.tres") as ClassDef, null)
	assert_bool(warrior.spend_resource(SkillDef.ResourceKind.STAMINA, 8)).is_true()
	assert_int(warrior.current_stamina).is_equal(50)
	assert_bool(warrior.spend_resource(SkillDef.ResourceKind.STAMINA, 100)).is_false()
	assert_int(warrior.current_stamina).is_equal(50)
	assert_bool(warrior.has_resource(SkillDef.ResourceKind.MANA, 58)).is_true()

func test_heal_caps_and_dead_reject() -> void:
	## 治疗：上限钳 max_hp；倒地者拒绝治疗
	var warrior := UnitBuilder.build_ally(_MakeAdv(&"w", &"cls_warrior", _WarriorAttrs()),
			load(CLS_DIR + "cls_warrior.tres") as ClassDef, null)
	warrior.current_hp = 85
	warrior.heal(10)
	assert_int(warrior.current_hp).is_equal(90)
	warrior.take_damage(90)
	warrior.heal(10)
	assert_int(warrior.current_hp).is_equal(0)

func test_adventurer_data_create_debug() -> void:
	## M1 调试口径工厂：技能清单 = 该职业全部档 1 技能（战士 = 痛击+盾墙）
	var game_data: Node = auto_free(load(GAME_DATA_SCRIPT).new())
	game_data.initialize_data()
	var adv := AdventurerData.create_debug(&"warrior", &"cls_warrior", _WarriorAttrs(), game_data)
	assert_str(String(adv.class_id)).is_equal("cls_warrior")
	assert_bool(adv.pre_unlocked).is_true()
	assert_int(adv.skill_ids.size()).is_equal(2)
	assert_bool(adv.skill_ids.has(&"skl_warrior_power_strike")).is_true()
	assert_bool(adv.skill_ids.has(&"skl_warrior_shield_wall")).is_true()
