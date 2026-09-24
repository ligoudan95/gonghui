## DerivedStats 单元测试（M1 批 1）
## 覆盖：14 项二级属性派生公式逐式对 17 案 §3.2——战士 1 级 HP 90、
## 法师法力 58、抗性双源取高（17-C20）、穿甲/抗性/护甲钳制 ≥0、
## 奇术师法穿=意志特例、速度=敏捷原始值边界（敏捷 16 移动加成归批 2 终值口径）。
extends GdUnitTestSuite

## cfg_main 真实数据路径（调整值换算 offset=10/divisor=2 参数注入）
const CFG_PATH: String = "res://data/core/cfg_main.tres"
## 职业表路径（HP 系数消费）
const WARRIOR_PATH: String = "res://data/class/classes/cls_warrior.tres"

## 套件级配置与职业表
var _cfg: CoreConfig
var _warrior: ClassDef

func before() -> void:
	## 套件前置：加载 cfg_main 与战士职业表（数值经参数注入，不触 autoload）
	## 参数：无
	## 返回：无
	_cfg = load(CFG_PATH) as CoreConfig
	_warrior = load(WARRIOR_PATH) as ClassDef

func test_calc_hp_warrior_level1() -> void:
	## 生命：战士体质 14、系数 8、1 级 → 20+14×5+8×0 = 90（§3.2 池量级示例）
	assert_int(DerivedStats.calc_hp(14, _warrior, 1)).is_equal(90)

func test_calc_hp_level3_growth() -> void:
	## 生命成长：3 级 → 20+70+8×2 = 106（职业系数随等级线性）
	assert_int(DerivedStats.calc_hp(14, _warrior, 3)).is_equal(106)

func test_calc_mana_and_stamina() -> void:
	## 资源池 = 10 + 换算源属性×3（法师法力 58 / 战士精力 58，§3.2）
	assert_int(DerivedStats.calc_mana(16)).is_equal(58)
	assert_int(DerivedStats.calc_stamina(16)).is_equal(58)
	assert_int(DerivedStats.calc_mana(10)).is_equal(40)

func test_calc_dodge() -> void:
	## 闪避 = 5% + 敏调×2%：敏 16（+3）→ 11%；敏 9（−1）→ 3%
	assert_float(DerivedStats.calc_dodge(16, _cfg)).is_equal_approx(0.11, 0.0001)
	assert_float(DerivedStats.calc_dodge(9, _cfg)).is_equal_approx(0.03, 0.0001)

func test_calc_hit() -> void:
	## 命中基准 = 85%（cfg.hit_base，2026-09-24 校准）+ 感调×2%：感 15（+2）→ 89%；感 10（0）→ 85%
	assert_float(DerivedStats.calc_hit(15, _cfg)).is_equal_approx(0.89, 0.0001)
	assert_float(DerivedStats.calc_hit(10, _cfg)).is_equal_approx(0.85, 0.0001)

func test_calc_status_resist_take_higher() -> void:
	## 异常状态抗性双源取高（17-C20）：max(体调, 意调)×3% + 5%
	assert_float(DerivedStats.calc_status_resist(8, 14, _cfg)).is_equal_approx(0.11, 0.0001)
	assert_float(DerivedStats.calc_status_resist(14, 8, _cfg)).is_equal_approx(0.11, 0.0001)

func test_calc_status_resist_clamped_non_negative() -> void:
	## 抗性钳制 ≥0：体/意双低（2/2，调 −4）→ 5%−12% 钳 0
	assert_float(DerivedStats.calc_status_resist(2, 2, _cfg)).is_equal(0.0)

func test_calc_speed_is_raw_agility() -> void:
	## 速度 = 敏捷原始值（排序用；敏捷 16 移动加成边界归批 2 移动力终值口径）
	assert_int(DerivedStats.calc_speed(16)).is_equal(16)
	assert_int(DerivedStats.calc_speed(15)).is_equal(15)
	assert_int(DerivedStats.calc_speed(9)).is_equal(9)

func test_calc_phys_pierce() -> void:
	## 物理穿甲 = 力调×1 钳 ≥0：力 16 → 3；力 4（调 −3）→ 0
	assert_int(DerivedStats.calc_phys_pierce(16, _cfg)).is_equal(3)
	assert_int(DerivedStats.calc_phys_pierce(4, _cfg)).is_equal(0)

func test_calc_mag_pierce_table_driven() -> void:
	## 法术穿甲表驱动（批 C M8：换算源经 ClassDef.mag_pierce_source_attr 表
	## 承载——原 cls_arcanist 代码特例删除；签名第一参 = 换算源属性值）：
	## 法师走智力（智 16 → 3）；奇术师表换算源 = 意志（意 16 → 3）；
	## 低属性钳 0
	var mage: ClassDef = load("res://data/class/classes/cls_mage.tres") as ClassDef
	var arcanist: ClassDef = load("res://data/class/classes/cls_arcanist.tres") as ClassDef
	assert_str(String(mage.mag_pierce_source_attr)).is_equal("intelligence")
	assert_str(String(arcanist.mag_pierce_source_attr)).is_equal("willpower")
	assert_int(DerivedStats.calc_mag_pierce(16, 10, &"cls_mage", _cfg)).is_equal(3)
	assert_int(DerivedStats.calc_mag_pierce(16, 10, &"cls_arcanist", _cfg)).is_equal(3)
	assert_int(DerivedStats.calc_mag_pierce(10, 16, &"cls_arcanist", _cfg)).is_equal(0)
	assert_int(DerivedStats.calc_mag_pierce(4, 4, &"cls_mage", _cfg)).is_equal(0)

func test_calc_resist_clamped() -> void:
	## 物理/法术抗性 = 调×2% 钳 ≥0：体 14（调 +2）→ 4%；感 15（调 +2）→ 4%；调 −4 → 钳 0
	assert_float(DerivedStats.calc_phys_resist(14, _cfg)).is_equal_approx(0.04, 0.0001)
	assert_float(DerivedStats.calc_phys_resist(2, _cfg)).is_equal(0.0)
	assert_float(DerivedStats.calc_mag_resist(15, _cfg)).is_equal_approx(0.04, 0.0001)
	assert_float(DerivedStats.calc_mag_resist(2, _cfg)).is_equal(0.0)

func test_calc_armor_dual_track() -> void:
	## 护甲 = 装备（双轨同计）+ 对应属性调×1 钳 ≥0：物理←体质、法术←感知
	assert_int(DerivedStats.calc_phys_armor(5, 14, _cfg)).is_equal(7)
	assert_int(DerivedStats.calc_mag_armor(2, 15, _cfg)).is_equal(4)
	assert_int(DerivedStats.calc_phys_armor(0, 2, _cfg)).is_equal(0)

func test_calc_crit_rate_single_source() -> void:
	## 暴击率单源（批 B M1：DerivedStats.calc_crit_rate 双份已删，全部走
	## BattleRules.crit_rate——无技能加成传 0.0）：5% + 幸调×2% + 敏调×1%
	## ——幸 14 敏 16 → 12%；幸 10 敏 10 → 5%；带加成 0.10 → 22%
	assert_float(BattleRules.crit_rate(14, 16, 0.0, _cfg)).is_equal_approx(0.12, 0.0001)
	assert_float(BattleRules.crit_rate(10, 10, 0.0, _cfg)).is_equal_approx(0.05, 0.0001)
	assert_float(BattleRules.crit_rate(14, 16, 0.10, _cfg)).is_equal_approx(0.22, 0.0001)
	assert_float(_cfg.crit_mult_base).is_equal(1.5)

func test_cfg_parameters_take_effect() -> void:
	## 「改表即生效」冒烟（批 B M1：公式参数入 cfg_main——改内存 cfg 值公式
	## 输出即时变化，恢复后归位）：hp_base 20→10 → calc_hp −10；
	## pool_mult 3→2 → 资源池缩比；crit_base 0.05→0.10 → 暴击率 +5pp
	var hp_original: int = _cfg.hp_base
	var pool_original: int = _cfg.pool_mult
	var crit_original: float = _cfg.crit_base
	var cls: ClassDef = load("res://data/class/classes/cls_warrior.tres") as ClassDef
	_cfg.hp_base = 10
	assert_int(DerivedStats.calc_hp(14, cls, 1, _cfg)).is_equal(80)
	_cfg.pool_mult = 2
	assert_int(DerivedStats.calc_mana(16, _cfg)).is_equal(42)
	_cfg.crit_base = 0.10
	assert_float(BattleRules.crit_rate(10, 10, 0.0, _cfg)).is_equal_approx(0.10, 0.0001)
	_cfg.hp_base = hp_original
	_cfg.pool_mult = pool_original
	_cfg.crit_base = crit_original
	assert_int(DerivedStats.calc_hp(14, cls, 1, _cfg)).is_equal(90)
	assert_int(DerivedStats.calc_mana(16, _cfg)).is_equal(58)

func test_mag_armor_uses_tabled_per_modifier() -> void:
	## 法术护甲表值推算（R1-1 补改核验）：护甲 = 装备 + 感知调整值 ×
	## cfg.armor_per_modifier（原 ×1 硬编码漏改位）；改表冒烟——乘数 2 时
	## 属性段翻倍（内存表改值即时生效，用例尾还原）
	var cfg: CoreConfig = load(CFG_PATH) as CoreConfig
	if cfg.armor_per_modifier <= 0:
		cfg.armor_per_modifier = 1
	# 感知 16 → 调整值 +3：护甲 = 5 + 3 × 表乘数
	var expected: int = 5 + 3 * cfg.armor_per_modifier
	assert_int(DerivedStats.calc_mag_armor(5, 16, cfg)).is_equal(expected)
	# 改表冒烟（R1-1）：乘数翻倍 → 属性段翻倍
	var original_per: int = cfg.armor_per_modifier
	cfg.armor_per_modifier = original_per * 2
	assert_int(DerivedStats.calc_mag_armor(5, 16, cfg)) \
			.is_equal(5 + 3 * original_per * 2)
	cfg.armor_per_modifier = original_per
