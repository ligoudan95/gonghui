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
	## 命中基准 = 80% + 感调×2%：感 15（+2）→ 84%；感 10（0）→ 80%
	assert_float(DerivedStats.calc_hit(15, _cfg)).is_equal_approx(0.84, 0.0001)
	assert_float(DerivedStats.calc_hit(10, _cfg)).is_equal_approx(0.80, 0.0001)

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

func test_calc_mag_pierce_arcanist_exception() -> void:
	## 法术穿甲 = 智调×1；奇术师特例 = 意调×1（§3.2 #17）；钳 ≥0
	assert_int(DerivedStats.calc_mag_pierce(16, 10, &"cls_mage", _cfg)).is_equal(3)
	assert_int(DerivedStats.calc_mag_pierce(10, 16, &"cls_arcanist", _cfg)).is_equal(3)
	assert_int(DerivedStats.calc_mag_pierce(10, 16, &"cls_priest", _cfg)).is_equal(0)
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

func test_calc_crit_rate_and_base_mult() -> void:
	## 暴击率 = 5% + 幸调×2% + 敏调×1%：幸 14 敏 16 → 12%；幸 10 敏 10 → 5%
	assert_float(DerivedStats.calc_crit_rate(14, 16, _cfg)).is_equal_approx(0.12, 0.0001)
	assert_float(DerivedStats.calc_crit_rate(10, 10, _cfg)).is_equal_approx(0.05, 0.0001)
	assert_float(DerivedStats.CRIT_MULT_BASE).is_equal(1.5)
