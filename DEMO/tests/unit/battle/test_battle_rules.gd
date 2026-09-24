## BattleRules 单元测试（M1 批 1）
## 覆盖：命中钳制 5%/95% 双边界、伤害下限 1、mitigate 乘前减后/穿甲抵扣/取整、
## 暴击 150% 口径、heal 感知×1.5+10、DOT 两模式、raw_panel 权重和+双层乘算、
## roll_hit forced 注入与随机统计带。
extends GdUnitTestSuite

## cfg_main 真实数据路径
const CFG_PATH: String = "res://data/core/cfg_main.tres"

## 套件级配置
var _cfg: CoreConfig

func before() -> void:
	## 套件前置：加载 cfg_main（参数注入，不触 autoload）
	## 参数：无
	## 返回：无
	_cfg = load(CFG_PATH) as CoreConfig

func _MakeSkill(weights: Dictionary, power: float) -> SkillDef:
	## 构建测试用伤害技能（权重表字面量 -> 类型化字典）
	## 参数 weights：{StringName: float} 权重；power：技能系数
	## 返回：SkillDef
	var skill := SkillDef.new()
	var typed: Dictionary[StringName, float] = {}
	for attr_id: StringName in weights:
		typed[attr_id] = weights[attr_id]
	skill.attr_weights = typed
	skill.power_coefficient = power
	return skill

func test_attr_modifier() -> void:
	## 调整值换算速查（§3.3）：6→−2 / 9→−1 / 10→0 / 11→0 / 16→+3 / 17→+3
	assert_int(BattleRules.attr_modifier(6, _cfg)).is_equal(-2)
	assert_int(BattleRules.attr_modifier(9, _cfg)).is_equal(-1)
	assert_int(BattleRules.attr_modifier(10, _cfg)).is_equal(0)
	assert_int(BattleRules.attr_modifier(11, _cfg)).is_equal(0)
	assert_int(BattleRules.attr_modifier(16, _cfg)).is_equal(3)
	assert_int(BattleRules.attr_modifier(17, _cfg)).is_equal(3)

func test_hit_chance_clamp_both_ends() -> void:
	## 命中钳制 [5%, 95%]：超高 → 95%；超低 → 5%（骰运保底双端，§3.4）
	assert_float(BattleRules.hit_chance(1.20, 0.0, 0, _cfg)).is_equal_approx(0.95, 0.0001)
	assert_float(BattleRules.hit_chance(0.0, 0.10, 0, _cfg)).is_equal_approx(0.05, 0.0001)

func test_hit_chance_with_skill_mod() -> void:
	## 技能命中修正（百分点）：80% − 10% 闪避 − 10% 修正 = 60%
	assert_float(BattleRules.hit_chance(0.80, 0.10, -10, _cfg)).is_equal_approx(0.60, 0.0001)

func test_mitigate_damage_floor() -> void:
	## 伤害下限：raw 0.3 护甲 10 → 取整 −10 钳下限 1（§3.4 max(1, ...)）
	assert_int(BattleRules.mitigate(0.3, 0.0, 10, 0, _cfg)).is_equal(1)

func test_mitigate_multiplicative_first_subtractive_after() -> void:
	## 乘前减后：100×(1−20%)−10 = 70（乘法抗性在前、减法护甲在后）
	assert_int(BattleRules.mitigate(100.0, 0.2, 10, 0, _cfg)).is_equal(70)

func test_mitigate_pierce_offset() -> void:
	## 穿甲抵护甲：护甲 10 穿 4 → 减 6（94）；穿甲超护甲不反向加伤（100）
	assert_int(BattleRules.mitigate(100.0, 0.0, 10, 4, _cfg)).is_equal(94)
	assert_int(BattleRules.mitigate(100.0, 0.0, 2, 5, _cfg)).is_equal(100)

func test_mitigate_rounding() -> void:
	## 取整：24.96 → 25（round）；29.44−2 → 27
	assert_int(BattleRules.mitigate(24.96, 0.0, 2, 3, _cfg)).is_equal(25)
	assert_int(BattleRules.mitigate(29.44, 0.0, 2, 0, _cfg)).is_equal(27)

func test_crit_rate_with_bonus() -> void:
	## 暴击率 = 5% + 幸调×2% + 敏调×1% + 技能加成：基础 5%；背刺口径 5+4+3+10 = 22%
	assert_float(BattleRules.crit_rate(10, 10, 0.0, _cfg)).is_equal_approx(0.05, 0.0001)
	assert_float(BattleRules.crit_rate(14, 16, 0.10, _cfg)).is_equal_approx(0.22, 0.0001)

func test_expected_damage_crit_multiplier() -> void:
	## 期望伤害 = raw × hit × (1 + crit×(mult−1))：100×0.8×1.05 = 84；未命中 → 0
	assert_float(BattleRules.expected_damage(100.0, 0.8, 0.1, 1.5)).is_equal_approx(84.0, 0.0001)
	assert_float(BattleRules.expected_damage(100.0, 0.0, 1.0, 1.5)).is_equal(0.0)

func test_heal_amount() -> void:
	## 治疗 = round(源属性 × ratio + flat)：感知 15×1.5+10 = 32.5 → 33（§3.8 牧师治疗 33）
	var effect := SkillEffect.new()
	effect.effect_kind = SkillEffect.EffectKind.HEAL
	effect.source_attr = &"perception"
	effect.ratio = 1.5
	effect.flat = 10
	assert_int(BattleRules.heal_amount({&"perception": 15}, effect)).is_equal(33)

func test_dot_tick_modes() -> void:
	## DOT 两模式：FIXED 直取（毒沼 6）；ATTR_RATIO = 意志 16×0.5 = 8（诅咒）
	var fixed := DotParams.new()
	fixed.mode = DotParams.Mode.FIXED
	fixed.fixed = 6
	assert_int(BattleRules.dot_tick({}, fixed)).is_equal(6)
	var ratio := DotParams.new()
	ratio.mode = DotParams.Mode.ATTR_RATIO
	ratio.attr_id = &"willpower"
	ratio.ratio = 0.5
	assert_int(BattleRules.dot_tick({&"willpower": 16}, ratio)).is_equal(8)

func test_raw_panel_weighted_formula() -> void:
	## 毛面板 =（Σ 权重×属性 + 武器加值）× 系数：痛击 (16×0.6+14×0.4+4)×1.3 = 24.96
	var skill := _MakeSkill({&"strength": 0.6, &"constitution": 0.4}, 1.3)
	var attrs: Dictionary = {&"strength": 16, &"constitution": 14}
	assert_float(BattleRules.raw_panel_damage(attrs, 4, skill, 1.0, 1.0)).is_equal_approx(24.96, 0.001)

func test_raw_panel_mult_layers() -> void:
	## 双层乘算（毛面板阶段非最终后乘）：高地 ×1.2 → 24.96×1.2；对亡灵 ×1.5；
	## 双层叠乘 ×1.8（§3.9 乘算序：(Σ权重×属性+武器)×系数×1.2×1.5）
	var skill := _MakeSkill({&"strength": 0.6, &"constitution": 0.4}, 1.3)
	var attrs: Dictionary = {&"strength": 16, &"constitution": 14}
	assert_float(BattleRules.raw_panel_damage(attrs, 4, skill, 1.2, 1.0)).is_equal_approx(29.952, 0.001)
	assert_float(BattleRules.raw_panel_damage(attrs, 4, skill, 1.0, 1.5)).is_equal_approx(37.44, 0.001)
	assert_float(BattleRules.raw_panel_damage(attrs, 4, skill, 1.2, 1.5)).is_equal_approx(44.928, 0.001)

func test_roll_hit_forced_injection() -> void:
	## forced 强制口：0 强制失败（必中概率也败）；1 强制成功（零概率也成）
	var rng := RandomNumberGenerator.new()
	assert_bool(BattleRules.roll_hit(1.0, rng, 0)).is_false()
	assert_bool(BattleRules.roll_hit(0.0, rng, 1)).is_true()

func test_roll_hit_random_band() -> void:
	## 随机模式统计带：50% 概率 100 掷落 [20, 80]（固定种子复现）
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var hits: int = 0
	for index: int in 100:
		if BattleRules.roll_hit(0.5, rng, -1):
			hits += 1
	assert_int(hits).is_between(20, 80)
	assert_bool(BattleRules.roll_hit(0.0, rng, -1)).is_false()
	assert_bool(BattleRules.roll_hit(1.0, rng, -1)).is_true()

func test_mitigate_by_damage_type_selects_track_pair() -> void:
	## 减免轨选对单源（批 4 C 组 H2）：物理/法术各取对应抗性/护甲/穿甲对——
	## 物理轨 100×(1−20%)−(10−4)=74（不看法术面）；法术轨 100×(1−10%)−(8−2)=84
	## 鸭子契约分量注入（物理穿 4/法术穿 2；物理抗 20%/法术抗 10%；
	## 物理甲 10/法术甲 8）
	var fake := UnitDouble.new()
	fake.phys_pierce = 4
	fake.mag_pierce = 2
	fake.phys_resist = 0.2
	fake.mag_resist = 0.1
	fake.phys_armor = 10
	fake.mag_armor = 8
	assert_int(BattleRules.mitigate_by_damage_type(100.0, SkillDef.DamageType.PHYSICAL,
			fake, fake, _cfg)).is_equal(74)
	assert_int(BattleRules.mitigate_by_damage_type(100.0, SkillDef.DamageType.MAGICAL,
			fake, fake, _cfg)).is_equal(84)
	# 分量口各自取对（trace 明细消费）
	assert_float(BattleRules.resist_of(SkillDef.DamageType.PHYSICAL, fake)).is_equal_approx(0.2, 0.0001)
	assert_float(BattleRules.resist_of(SkillDef.DamageType.MAGICAL, fake)).is_equal_approx(0.1, 0.0001)
	assert_int(BattleRules.armor_of(SkillDef.DamageType.PHYSICAL, fake)).is_equal(10)
	assert_int(BattleRules.armor_of(SkillDef.DamageType.MAGICAL, fake)).is_equal(8)
	assert_int(BattleRules.pierce_of(SkillDef.DamageType.PHYSICAL, fake)).is_equal(4)
	assert_int(BattleRules.pierce_of(SkillDef.DamageType.MAGICAL, fake)).is_equal(2)

## 减免轨选对测试替身（抗性/护甲/穿甲双轨分量）
class UnitDouble:
	extends RefCounted
	var phys_pierce: int = 0
	var mag_pierce: int = 0
	var phys_resist: float = 0.0
	var mag_resist: float = 0.0
	var phys_armor: int = 0
	var mag_armor: int = 0
