## CheckRoller 检定掷骰单元测试（M2 批 1——测试先行）
## 覆盖：四档全覆盖（固定 rng 注入）/ 骰 1 优先 CRIT_FAILURE（不兜底不看线）/
## 幸运降线三锚点（14→19、18→18、<10→20）/ 判定线钳 16 下限 / Z 兜底公式
## （幸运 14-17 骰 2 垫 3、下限 2）/ 大样本频率带（各档占比粗带）。
## 口径：案 17 §3.3（D20 检定域——幸运降线 X=3、判定线钳 16、幸运兜底 Y/Z）。
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

func _Rig(die_value: int) -> RandomNumberGenerator:
	## 固定骰值 rng（randi_range(1,20) 恒返回 die_value——种子后首掷不可控，
	## 故用子类化不可行、改为直接构造后覆写：GDScript 无法覆写内建——
	## 改由 CheckRoller 预留 die 注入口 _RollDie 测试子类化）
	## 参数 die_value：骰值
	## 返回：rng（未被本用例消费——保留参数注入形态）
	var rng := RandomNumberGenerator.new()
	rng.seed = die_value
	return rng

func test_grades_full_coverage() -> void:
	## 四档全覆盖（子类注入骰值）：大成功（骰 ≥ 线）/ 成功（和 ≥ 判定线）/
	## 失败 / 大失败（骰 1 恒大失败）
	var attrs_luck18: Dictionary = {&"luck": 18, &"strength": 10}
	# 幸运 18 → 线 18：骰 18 = 大成功
	assert_int(CheckRoller.roll_with_die(attrs_luck18, AttrKeys.STRENGTH, "普通",
			_cfg, 18).grade).is_equal(CheckResult.Grade.CRIT_SUCCESS)
	# 骰 1 恒大失败（不看线不看属性）
	assert_int(CheckRoller.roll_with_die(attrs_luck18, AttrKeys.STRENGTH, "极易",
			_cfg, 1).grade).is_equal(CheckResult.Grade.CRIT_FAILURE)
	# 力量 10（调整值 0）普通 11：骰 12（Z=2 兜底不抬）→ 0+12 ≥ 11 成功
	assert_int(CheckRoller.roll_with_die(attrs_luck18, AttrKeys.STRENGTH, "普通",
			_cfg, 12).grade).is_equal(CheckResult.Grade.SUCCESS)
	# 骰 10 → 10 < 11 失败
	assert_int(CheckRoller.roll_with_die(attrs_luck18, AttrKeys.STRENGTH, "普通",
			_cfg, 10).grade).is_equal(CheckResult.Grade.FAILURE)

func test_die_one_priority_over_line() -> void:
	## 骰 1 优先：幸运 18（线 18）+ 极易 5 + 骰 1 → 大失败（不兜底不看线，
	## 即便 modifier+Z ≥ 判定线也高大失败）
	var result: CheckResult = CheckRoller.roll_with_die({&"luck": 18, &"strength": 20},
			AttrKeys.STRENGTH, "极易", _cfg, 1)
	assert_int(result.grade).is_equal(CheckResult.Grade.CRIT_FAILURE)
	assert_int(result.die).is_equal(1)

func test_crit_line_by_luck() -> void:
	## 幸运降线三锚点（X=3、钳 16）：幸运 14 → 线 19；18 → 线 18；<10 → 线 20
	assert_int(CheckRoller.crit_line_of(14, _cfg)).is_equal(19)
	assert_int(CheckRoller.crit_line_of(18, _cfg)).is_equal(18)
	assert_int(CheckRoller.crit_line_of(8, _cfg)).is_equal(20)
	# 判定线钳 16：幸运 24 → 降 20 − floor(14/3)=4 → 16（钳住不再降）
	assert_int(CheckRoller.crit_line_of(24, _cfg)).is_equal(16)

func test_z_floor_formula() -> void:
	## 幸运兜底 Z（Y/Z 同除数 4、基 2）：幸运 14-17 → Z=2+floor((luck−10)/4)=3；
	## 幸运 10 → Z=2；幸运 <10 → Z=max(2, 2+负)=2 下限
	assert_int(CheckRoller.z_of(14, _cfg)).is_equal(3)
	assert_int(CheckRoller.z_of(17, _cfg)).is_equal(3)
	assert_int(CheckRoller.z_of(10, _cfg)).is_equal(2)
	assert_int(CheckRoller.z_of(6, _cfg)).is_equal(2)

func test_z_lifts_low_die() -> void:
	## Z 垫骰：幸运 16（Z=3）骰 2 → effective_die=3（骰 1 除外不垫）；
	## 结果档位受抬升影响（普通 11：力量 10 调 0 + 3 = 3 < 11 仍失败——
	## 但 effective_die 断言锚定抬升本身）
	var result: CheckResult = CheckRoller.roll_with_die({&"luck": 16, &"strength": 10},
			AttrKeys.STRENGTH, "普通", _cfg, 2)
	assert_int(result.effective_die).is_equal(3)
	assert_int(result.die).is_equal(2)

func test_frequency_bands() -> void:
	## 大样本频率带（真随机 rng）：力量 10 普通 11 一万掷——成功（含大成功）
	## 约 50%（(11+9×0.05)/20 + Z 微抬）；大失败恒 5%；失败为余量
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260924
	var crit_success: int = 0
	var success: int = 0
	var failure: int = 0
	var crit_failure: int = 0
	var attrs: Dictionary = {&"strength": 10, &"luck": 10}
	var samples: int = 10000
	for index: int in samples:
		var grade: int = CheckRoller.roll(attrs, AttrKeys.STRENGTH, "普通", _cfg, rng).grade
		match grade:
			CheckResult.Grade.CRIT_SUCCESS:
				crit_success += 1
			CheckResult.Grade.SUCCESS:
				success += 1
			CheckResult.Grade.FAILURE:
				failure += 1
			_:
				crit_failure += 1
	# 带：大失败 ≈ 5%（4.5-5.5）；成功+大成功 ≈ 50%（45-58 宽带含 Z/线边界）
	assert_float(float(crit_failure) / float(samples)).is_between(0.045, 0.055)
	assert_float(float(success + crit_success) / float(samples)).is_between(0.45, 0.58)
	assert_int(crit_success + success + failure + crit_failure).is_equal(samples)

func test_result_fields() -> void:
	## 结果字段完整性：die/effective_die/modifier/total/grade/crit_line 全落位
	var result: CheckResult = CheckRoller.roll_with_die({&"strength": 16, &"luck": 10},
			AttrKeys.STRENGTH, "困难", _cfg, 11)
	assert_int(result.die).is_equal(11)
	assert_int(result.effective_die).is_equal(11)
	assert_int(result.modifier).is_equal(3)
	assert_int(result.total).is_equal(14)
	assert_int(result.grade).is_equal(CheckResult.Grade.SUCCESS)
	assert_int(result.crit_line).is_equal(20)
