## 17 案 §3.8 金标准验算测试（M1 批 1·全断言，浮点容差 ±0.5）
## 基准 = 17-C7 区间中值偏上：战士 力16/体14/感9/敏10/幸10 武器 4；
## 盗贼 力10/敏16/幸13/感11 武器 3；法师 智16/感11/敏10/幸10 武器 2；
## 牧师 感15/智10/敏10/幸10 武器 2（M2 拍板：法穿=智力口径）。
## 技能权重取 data/ 真实表（§3.4 DEMO 技能参数表定稿值）。
## 敌方基准：杂兵 护甲 2/抗性 0%/闪避带 3-5%；精英 护甲 4/抗性 5%
## （对精英命中乘数沿用杂兵闪避带为近似口径——§3.8 表注）。
extends GdUnitTestSuite

## cfg_main 真实数据路径
const CFG_PATH: String = "res://data/core/cfg_main.tres"
## 技能表路径（真实数据：§3.4 定稿值）
const POWER_STRIKE_PATH: String = "res://data/class/skills/skl_warrior_power_strike.tres"
const BACKSTAB_PATH: String = "res://data/class/skills/skl_rogue_backstab.tres"
const FIREBALL_PATH: String = "res://data/class/skills/skl_mage_fireball.tres"
const SMITE_PATH: String = "res://data/class/skills/skl_priest_smite.tres"
## 浮点容差（任务口径 ±0.5）
const TOLERANCE: float = 0.5

## 套件级配置与技能表
var _cfg: CoreConfig
var _power_strike: SkillDef
var _backstab: SkillDef
var _fireball: SkillDef
var _smite: SkillDef

func before() -> void:
	## 套件前置：加载 cfg_main 与四技能表（真实数据，不触 autoload）
	## 参数：无
	## 返回：无
	_cfg = load(CFG_PATH) as CoreConfig
	_power_strike = load(POWER_STRIKE_PATH) as SkillDef
	_backstab = load(BACKSTAB_PATH) as SkillDef
	_fireball = load(FIREBALL_PATH) as SkillDef
	_smite = load(SMITE_PATH) as SkillDef

func _TrashPerHit(skill: SkillDef, attrs: Dictionary, weapon: int, pierce: int,
		hit_stat: float, crit: float) -> float:
	## 对杂兵每击期望：毛面板 → 减免轨（甲 2/抗 0）→ ×命中 ×暴击期望
	## 参数 skill/attrs/weapon/pierce：施放侧；hit_stat：含闪避后的实际命中；crit：本次暴击率
	## 返回：每击期望伤害
	var raw: float = BattleRules.raw_panel_damage(attrs, weapon, skill, 1.0, 1.0)
	var mitigated: int = BattleRules.mitigate(raw, 0.0, 2, pierce, _cfg)
	return BattleRules.expected_damage(mitigated, hit_stat, crit, DerivedStats.CRIT_MULT_BASE)

func test_raw_panel_gross_values() -> void:
	## 毛面板可复算（§3.8 定稿值）：痛击 24.96 / 背刺 29.44（敏16幸13 下界组）/ 火球 25.2 / 惩击 20.4
	var warrior: Dictionary = {&"strength": 16, &"constitution": 14}
	var rogue: Dictionary = {&"agility": 16, &"luck": 13}
	var mage: Dictionary = {&"intelligence": 16}
	var priest: Dictionary = {&"perception": 15}
	assert_float(BattleRules.raw_panel_damage(warrior, 4, _power_strike, 1.0, 1.0)).is_equal_approx(24.96, 0.01)
	assert_float(BattleRules.raw_panel_damage(rogue, 3, _backstab, 1.0, 1.0)).is_equal_approx(29.44, 0.01)
	assert_float(BattleRules.raw_panel_damage(mage, 2, _fireball, 1.0, 1.0)).is_equal_approx(25.2, 0.01)
	assert_float(BattleRules.raw_panel_damage(priest, 2, _smite, 1.0, 1.0)).is_equal_approx(20.4, 0.01)

func test_per_hit_expectation_vs_trash() -> void:
	## 对杂兵（甲 2/抗 0）每击期望（§3.8：痛 ≈19 / 背 ≈23 / 火 ≈20 / 惩 ≈15）：
	## 命中 = 80% + 感调×2% − 闪避（感带 9-15，闪避带 3-5% 取各行复算值）
	# 战士：感 9（−1）→ 78% − 4% = 74%；穿甲 力16→3 抵净护甲；暴击 5%（幸10敏10）
	var warrior: Dictionary = {&"strength": 16, &"constitution": 14, &"luck": 10, &"agility": 10}
	var warrior_hit: float = BattleRules.hit_chance(DerivedStats.calc_hit(9, _cfg), 0.04, 0, _cfg)
	assert_float(warrior_hit).is_equal_approx(0.74, 0.0001)
	var power_expected: float = _TrashPerHit(_power_strike, warrior, 4, 3, warrior_hit, 0.05)
	assert_float(power_expected).is_equal_approx(19.0, TOLERANCE)
	# 盗贼：感 11（0）→ 80% − 4% = 76%；穿甲 力10→0 抵后护甲 2；暴击 = 5+2+3+10 = 20%
	var rogue: Dictionary = {&"agility": 16, &"luck": 13, &"strength": 10}
	var rogue_hit: float = BattleRules.hit_chance(DerivedStats.calc_hit(11, _cfg), 0.04, 0, _cfg)
	assert_float(rogue_hit).is_equal_approx(0.76, 0.0001)
	var backstab_crit: float = BattleRules.crit_rate(13, 16, 0.10, _cfg)
	assert_float(backstab_crit).is_equal_approx(0.20, 0.0001)
	var backstab_expected: float = _TrashPerHit(_backstab, rogue, 3, 0, rogue_hit, backstab_crit)
	assert_float(backstab_expected).is_equal_approx(23.0, TOLERANCE)
	# 法师：感 11（0）→ 80% − 3% = 77%；法穿 智16→3；暴击 5%
	var mage: Dictionary = {&"intelligence": 16, &"luck": 10, &"agility": 10}
	var mage_hit: float = BattleRules.hit_chance(DerivedStats.calc_hit(11, _cfg), 0.03, 0, _cfg)
	assert_float(mage_hit).is_equal_approx(0.77, 0.0001)
	var fireball_expected: float = _TrashPerHit(_fireball, mage, 2, 3, mage_hit, 0.05)
	assert_float(fireball_expected).is_equal_approx(20.0, TOLERANCE)
	# 牧师：感 15（+2）→ 84% − 4% = 80%；法穿 智10→0（M2 口径）抵后护甲 2；暴击 5%
	var priest: Dictionary = {&"perception": 15, &"intelligence": 10, &"luck": 10, &"agility": 10}
	var priest_hit: float = BattleRules.hit_chance(DerivedStats.calc_hit(15, _cfg), 0.04, 0, _cfg)
	assert_float(priest_hit).is_equal_approx(0.80, 0.0001)
	var smite_expected: float = _TrashPerHit(_smite, priest, 2, 0, priest_hit, 0.05)
	assert_float(smite_expected).is_equal_approx(15.0, TOLERANCE)

func test_team_output_per_round() -> void:
	## 3 输出位有效输出 ≈62/回合（逐技能四舍五入后合计）；牧师参与合计 ≈77
	var warrior: Dictionary = {&"strength": 16, &"constitution": 14, &"luck": 10, &"agility": 10}
	var rogue: Dictionary = {&"agility": 16, &"luck": 13, &"strength": 10}
	var mage: Dictionary = {&"intelligence": 16, &"luck": 10, &"agility": 10}
	var priest: Dictionary = {&"perception": 15, &"intelligence": 10, &"luck": 10, &"agility": 10}
	var power: int = roundi(_TrashPerHit(_power_strike, warrior, 4, 3,
			BattleRules.hit_chance(DerivedStats.calc_hit(9, _cfg), 0.04, 0, _cfg), 0.05))
	var backstab: int = roundi(_TrashPerHit(_backstab, rogue, 3, 0,
			BattleRules.hit_chance(DerivedStats.calc_hit(11, _cfg), 0.04, 0, _cfg), 0.20))
	var fireball: int = roundi(_TrashPerHit(_fireball, mage, 2, 3,
			BattleRules.hit_chance(DerivedStats.calc_hit(11, _cfg), 0.03, 0, _cfg), 0.05))
	assert_int(power + backstab + fireball).is_equal(62)
	var smite: int = roundi(_TrashPerHit(_smite, priest, 2, 0,
			BattleRules.hit_chance(DerivedStats.calc_hit(15, _cfg), 0.04, 0, _cfg), 0.05))
	assert_int(power + backstab + fireball + smite).is_equal(77)

func test_elite_expectation() -> void:
	## 对精英（甲 4/抗 5%）每击期望（§3.8 第七轮实算）：痛 ≈17 / 背 ≈20 / 火 ≈18；3 输出 ≈55
	var warrior: Dictionary = {&"strength": 16, &"constitution": 14, &"luck": 10, &"agility": 10}
	var rogue: Dictionary = {&"agility": 16, &"luck": 13, &"strength": 10}
	var mage: Dictionary = {&"intelligence": 16, &"luck": 10, &"agility": 10}
	var power: float = _ElitePerHit(_power_strike, warrior, 4, 3, 0.74, 0.05)
	var backstab: float = _ElitePerHit(_backstab, rogue, 3, 0, 0.76, 0.20)
	var fireball: float = _ElitePerHit(_fireball, mage, 2, 3, 0.77, 0.05)
	assert_float(power).is_equal_approx(17.0, TOLERANCE)
	assert_float(backstab).is_equal_approx(20.0, TOLERANCE)
	assert_float(fireball).is_equal_approx(18.0, TOLERANCE)
	assert_int(roundi(power) + roundi(backstab) + roundi(fireball)).is_equal(55)

func _ElitePerHit(skill: SkillDef, attrs: Dictionary, weapon: int, pierce: int,
		hit_stat: float, crit: float) -> float:
	## 对精英每击期望：毛面板 → 减免轨（甲 4/抗 5%）→ ×命中 ×暴击期望
	## 参数：同 _TrashPerHit（减免轨参数不同）
	## 返回：每击期望伤害
	var raw: float = BattleRules.raw_panel_damage(attrs, weapon, skill, 1.0, 1.0)
	var mitigated: int = BattleRules.mitigate(raw, 0.05, 4, pierce, _cfg)
	return BattleRules.expected_damage(mitigated, hit_stat, crit, DerivedStats.CRIT_MULT_BASE)

func test_battle_round_conclusions() -> void:
	## 回合数结论（§3.8）：随机遭遇 165 血 ÷ 62 ≈ 3 回合；必然遭遇 220-275 ÷ 55-62 → 4-5 回合
	assert_int(roundi(165.0 / 62.0)).is_equal(3)
	var fastest: int = ceili(220.0 / 62.0)
	var slowest: int = ceili(275.0 / 55.0)
	assert_int(fastest).is_equal(4)
	assert_int(slowest).is_equal(5)
	assert_int(fastest).is_between(4, 5)
	assert_int(slowest).is_between(4, 5)
