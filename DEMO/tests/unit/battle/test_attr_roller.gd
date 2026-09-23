## AttrRoller 单元测试（M1 批 1）
## 覆盖：初始 4 人固定掷值域 ∈ [区间中值, 区间上限]（17-C7 中值偏上、固定种子）；
## 招募钳制带 70-80 越界整组重掷（17-C17 固定种子复现 + 总和入带断言）；
## 不可达带循环上限保护（1000 次后返回末次掷值不死循环）。
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
	## 不可达带循环保护：带 [1000, 1001] 永不命中 → 1000 次上限后返回末次掷值
	## （带外值、不越界区间、不死循环）
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var attrs: Dictionary[StringName, int] = AttrRoller.roll_recruit(_warrior, rng, 1000, 1001)
	var total: int = 0
	for attr_id: StringName in _warrior.attr_ranges:
		var bounds: Vector2i = _warrior.attr_ranges[attr_id]
		assert_int(attrs[attr_id]).is_between(bounds.x, bounds.y)
		total += attrs[attr_id]
	assert_int(total).is_less(1000)
