## 技能数据表单元测试（M0 批 2）
## 覆盖：23 条分类计数（6 普攻 + 12 职业技 + 4 敌方技 + 1 敌方通用普攻）、
## 权重和抽查、六普攻权重唯一键 == 职业资源换算源属性（17 案 §3.4 D3 定稿口径）、
## 关键定值抽查（火球/怒吼/治愈术/陷阱）。
extends GdUnitTestSuite

## GameData 自动加载脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 实例
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData 并显式初始化
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

func _skills() -> Array:
	## 取技能域全部记录
	## 参数：无
	## 返回：SkillDef 记录数组
	return _game_data.get_domain(&"class/skills")

func test_skill_counts_by_category() -> void:
	## 23 条分类计数：普攻 6 / 职业档 1 技 12 / 敌方技 4 / 敌方通用普攻 1
	var basic_attacks: int = 0
	var class_skills: int = 0
	var enemy_skills: int = 0
	var enemy_common: int = 0
	for record: Resource in _skills():
		var skill := record as SkillDef
		if skill.id == &"skl_atk_enemy_common":
			enemy_common += 1
		elif String(skill.id).begins_with("skl_atk_"):
			basic_attacks += 1
		elif String(skill.id).begins_with("skl_enemy_"):
			enemy_skills += 1
		else:
			class_skills += 1
	assert_int(_skills().size()).is_equal(23)
	assert_int(basic_attacks).is_equal(6)
	assert_int(class_skills).is_equal(12)
	assert_int(enemy_skills).is_equal(4)
	assert_int(enemy_common).is_equal(1)

func test_damage_skill_weight_sums() -> void:
	## 伤害技权重和 = 1.0±0.01（抽查背刺/痛击/穷追猛打）
	var backstab: SkillDef = _game_data.get_record(&"skl_rogue_backstab")
	var power_strike: SkillDef = _game_data.get_record(&"skl_warrior_power_strike")
	var relentless: SkillDef = _game_data.get_record(&"skl_enemy_relentless")
	for skill: SkillDef in [backstab, power_strike, relentless]:
		var weight_sum: float = 0.0
		for attr_id: StringName in skill.attr_weights:
			weight_sum += skill.attr_weights[attr_id]
		assert_float(weight_sum).is_equal_approx(1.0, 0.01)

func test_basic_attack_weight_matches_class_resource_source() -> void:
	## 六普攻权重唯一键 == 所属职业资源换算源属性（17 案 §3.4 D3：力/敏/智/感/敏/意）
	var pairs: Array = [
		[&"cls_warrior", &"skl_atk_warrior"],
		[&"cls_rogue", &"skl_atk_rogue"],
		[&"cls_mage", &"skl_atk_mage"],
		[&"cls_priest", &"skl_atk_priest"],
		[&"cls_ranger", &"skl_atk_ranger"],
		[&"cls_arcanist", &"skl_atk_arcanist"],
	]
	for pair: Array in pairs:
		var cls: ClassDef = _game_data.get_record(pair[0])
		var attack: SkillDef = _game_data.get_record(pair[1])
		assert_int(attack.attr_weights.size()).is_equal(1)
		assert_bool(attack.attr_weights.has(cls.resource_source_attr)) \
				.override_failure_message("普攻 '%s' 权重键 != '%s' 换算源" % [attack.id, cls.resource_source_attr]).is_true()
		assert_float(attack.attr_weights[cls.resource_source_attr]).is_equal_approx(1.0, 0.001)

func test_key_skill_values() -> void:
	## 关键定值抽查：火球（法力12/射程5/系数1.4）、怒吼（AURA_3X3/精力12）、
	## 治愈术（HEAL 感知×1.5+10）、陷阱（TILE_SPAWN tile_trap）
	var fireball: SkillDef = _game_data.get_record(&"skl_mage_fireball")
	assert_int(fireball.resource_cost).is_equal(12)
	assert_int(fireball.range).is_equal(5)
	assert_float(fireball.power_coefficient).is_equal_approx(1.4, 0.001)
	var roar: SkillDef = _game_data.get_record(&"skl_enemy_intimidating_roar")
	assert_int(roar.target_shape).is_equal(SkillDef.TargetShape.AURA_3X3)
	assert_int(roar.resource_cost).is_equal(12)
	assert_int(roar.range).is_equal(0)
	var heal: SkillDef = _game_data.get_record(&"skl_priest_heal")
	assert_int(heal.target_side).is_equal(SkillDef.TargetSide.ALLY)
	assert_int(heal.effects.size()).is_equal(1)
	assert_int(heal.effects[0].effect_kind).is_equal(SkillEffect.EffectKind.HEAL)
	assert_str(String(heal.effects[0].source_attr)).is_equal("perception")
	assert_float(heal.effects[0].ratio).is_equal_approx(1.5, 0.001)
	assert_int(heal.effects[0].flat).is_equal(10)
	var trap: SkillDef = _game_data.get_record(&"skl_ranger_set_trap")
	assert_int(trap.target_shape).is_equal(SkillDef.TargetShape.CELL)
	assert_int(trap.effects[0].effect_kind).is_equal(SkillEffect.EffectKind.TILE_SPAWN)
	assert_str(String(trap.effects[0].tile_type_id)).is_equal("tile_trap")

func test_ally_skill_descriptions_filled() -> void:
	## 我方技能 description 全回填（按钮 hover tooltip 文案入表——2026-09-24
	## 二轮试玩反馈，铁律①零硬编码文案）；敌方技能不进玩家按钮不强制
	for skill: SkillDef in _skills():
		if skill.side != SkillDef.SkillSide.ALLY:
			continue
		assert_str(skill.description) \
				.override_failure_message("我方技能 %s 缺 description（tooltip 文案入表）" % skill.id) \
				.is_not_empty()

func test_enemy_skills_side() -> void:
	## 敌方技能（owner 为敌人或通用普攻）side 必须 ENEMY（含 skl_atk_enemy_common）
	var enemy_skill_ids: Array[StringName] = [
		&"skl_enemy_plague_bite", &"skl_enemy_dirty_trick",
		&"skl_enemy_relentless", &"skl_enemy_intimidating_roar",
		&"skl_atk_enemy_common",
	]
	for skill_id: StringName in enemy_skill_ids:
		var skill: SkillDef = _game_data.get_record(skill_id)
		assert_int(skill.side).is_equal(SkillDef.SkillSide.ENEMY)
