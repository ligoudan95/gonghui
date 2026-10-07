## AttrRoller 单元测试（M1 批 1）
## 覆盖：初始 4 人固定掷值域 ∈ [区间中值, 区间上限]（17-C7 中值偏上、固定种子）；
## 招募钳制带 70-80 越界整组重掷（17-C17 固定种子复现 + 总和入带断言）；
## 不可达带循环上限保护（1000 次后回退区间中值定值组不死循环——2026-10-03
## 审计·漏洞7：兼容带回退组收敛入带/结构性不可达止步区间内组）。
extends GdUnitTestSuite

## 职业表路径
const WARRIOR_PATH: String = "res://data/class/classes/cls_warrior.tres"
const MAGE_PATH: String = "res://data/class/classes/cls_mage.tres"

## 套件级职业表
var _warrior: ClassDef
var _mage: ClassDef

func before() -> void:
	## 套件前置：加载职业表（真实数据，不触 autoload）
	## 参数：无
	## 返回：无
	_warrior = load(WARRIOR_PATH) as ClassDef
	_mage = load(MAGE_PATH) as ClassDef

func test_roll_fixed_four_value_band() -> void:
	## 初始 4 人：每属性 ∈ [区间中值, 区间上限]（战士：力 [16,17] 体 [14,15]
	## 敏 [10,11] 智 [7,8] 感/意/幸 [9,10]——固定种子，七属性全查）
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var attrs: Dictionary[StringName, int] = AttrRoller.roll_fixed_four(_warrior, rng)
	assert_int(attrs.size()).is_equal(7)
	for attr_id: StringName in _warrior.attr_ranges:
		var bounds: Vector2i = _warrior.attr_ranges[attr_id]
		var mid: int = int(floor((bounds.x + bounds.y) / 2.0))
		assert_int(attrs[attr_id]).is_between(mid, bounds.y)

func test_roll_fixed_four_multiple_seeds() -> void:
	## 多种子复检：20 个种子全部落带（战士 + 法师）
	for seed_value: int in range(1, 21):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for cls: ClassDef in [_warrior, _mage]:
			var attrs: Dictionary[StringName, int] = AttrRoller.roll_fixed_four(cls, rng)
			for attr_id: StringName in cls.attr_ranges:
				var bounds: Vector2i = cls.attr_ranges[attr_id]
				var mid: int = int(floor((bounds.x + bounds.y) / 2.0))
				assert_int(attrs[attr_id]).is_between(mid, bounds.y)

func test_roll_recruit_band_inclusion() -> void:
	## 招募候选：区间内掷值 + 总和 ∈ [70, 80]（固定种子复现；越界整组重掷直至入带）
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var attrs: Dictionary[StringName, int] = AttrRoller.roll_recruit(_warrior, rng)
	var total: int = 0
	for attr_id: StringName in _warrior.attr_ranges:
		var bounds: Vector2i = _warrior.attr_ranges[attr_id]
		assert_int(attrs[attr_id]).is_between(bounds.x, bounds.y)
		total += attrs[attr_id]
	assert_int(total).is_between(70, 80)

func test_roll_recruit_custom_band() -> void:
	## 自定义钳制带：[72, 74] 窄带入带断言（重掷路径复现）
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260923
	var attrs: Dictionary[StringName, int] = AttrRoller.roll_recruit(_mage, rng, 72, 74)
	var total: int = 0
	for attr_id: StringName in _mage.attr_ranges:
		total += attrs[attr_id]
	assert_int(total).is_between(72, 74)

func test_roll_recruit_impossible_band_loop_guard() -> void:
	## 不可达带循环保护：带 [1000, 1001] 永不命中 → 1000 次上限后回退区间
	## 中值定值组（2026-10-03 审计·漏洞7：不再返回末次带外随机掷值——回退组
	## 按带中心缩放后钳回区间；结构性不可达（区间上限总和 81 < 带下限 1000）
	## 止步于最接近带的区间内组：不越界区间、不死循环、确定性输出）
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var attrs: Dictionary[StringName, int] = AttrRoller.roll_recruit(_warrior, rng, 1000, 1001)
	var total: int = 0
	for attr_id: StringName in _warrior.attr_ranges:
		var bounds: Vector2i = _warrior.attr_ranges[attr_id]
		assert_int(attrs[attr_id]).is_between(bounds.x, bounds.y)
		total += attrs[attr_id]
	assert_int(total).is_less(1000)

func test_roll_recruit_unreachable_band_falls_back_in_band() -> void:
	## 漏洞7 主用例：注入与钳制带不兼容的职业区间（全属性 [10,99]——七属性
	## 掷值随机落 [70,80] 带概率 ~1e-9，1000 次必超限）→ 回退区间中值定值组：
	## 比例缩放 + 逐点微调收敛入带，各属性仍在职业区间内（中值 54×7=378 →
	## 缩放向带心 75 → 各 11 → 总 77 ∈ [70,80]）；确定性输出（同表同带同结果）
	var cls := ClassDef.new()
	cls.id = &"cls_test_wide"
	var ranges: Dictionary[StringName, Vector2i] = {}
	for attr_id: StringName in _warrior.attr_ranges:
		ranges[attr_id] = Vector2i(10, 99)
	cls.attr_ranges = ranges
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var attrs: Dictionary[StringName, int] = AttrRoller.roll_recruit(cls, rng)
	var total: int = 0
	for attr_id: StringName in cls.attr_ranges:
		assert_int(attrs[attr_id]).is_between(10, 99)
		total += attrs[attr_id]
	assert_int(total).is_between(70, 80) \
			.override_failure_message("超限回退组总和须收敛入带 [70,80]")
	# 确定性：同表同带重跑同结果（不携带随机掷值）
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 999
	var attrs2: Dictionary[StringName, int] = AttrRoller.roll_recruit(cls, rng2)
	for attr_id: StringName in cls.attr_ranges:
		assert_int(attrs2[attr_id]).is_equal(attrs[attr_id])
