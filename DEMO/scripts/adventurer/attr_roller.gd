## 属性掷值器（AttrRoller，纯静态工具类）
## 职责：冒险者一级属性生成——初始固定 4 人（区间中值偏上，豁免钳制）
## 与招募候选（区间内随机 + 七属性总和带钳制 70-80，越界整组重掷）。
## 数据来源：案 17《数值专项案》§3.1（六职业初始属性区间 + 钳制带）；
## 17-C7（初始 4 人中值偏上、豁免钳制）/17-C17（钳制带上界 80 + 越界整组重掷）。
## 纯逻辑约束：不触任何 autoload——随机源 rng 注入保证测试确定性。
class_name AttrRoller
extends RefCounted

## 招募重掷循环上限（保护带不可达时的退出；超限返回末次掷值并 push_warning）
const MAX_REROLL: int = 1000

static func roll_fixed_four(cls: ClassDef, rng: RandomNumberGenerator) -> Dictionary[StringName, int]:
	## 初始固定 4 人掷值：每属性 [区间中值, 区间上限] 均匀掷值（中值偏上，17-C7）
	## 参数 cls：职业表（attr_ranges 七属性区间）；rng：随机源（注入）
	## 返回：{StringName 属性 id: int 掷值}（七属性全集）
	var result: Dictionary[StringName, int] = {}
	for attr_id: StringName in cls.attr_ranges:
		var bounds: Vector2i = cls.attr_ranges[attr_id]
		var mid: int = int(floor((bounds.x + bounds.y) / 2.0))
		result[attr_id] = rng.randi_range(mid, bounds.y)
	return result

static func roll_recruit(cls: ClassDef, rng: RandomNumberGenerator,
		band_min: int = 70, band_max: int = 80) -> Dictionary[StringName, int]:
	## 招募候选掷值：每属性 [区间下限, 区间上限] 均匀掷值；七属性总和越界整组重掷
	## 直至入带 [band_min, band_max]（17-C17；不作单项修剪）；循环上限 MAX_REROLL
	## 保护——超限返回末次掷值（带外）并 push_warning
	## 参数 cls：职业表；rng：随机源；band_min/band_max：总和钳制带（默认 70/80）
	## 返回：{StringName 属性 id: int 掷值}
	var result: Dictionary[StringName, int] = {}
	var attempts: int = 0
	while attempts < MAX_REROLL:
		result.clear()
		var total: int = 0
		for attr_id: StringName in cls.attr_ranges:
			var bounds: Vector2i = cls.attr_ranges[attr_id]
			var value: int = rng.randi_range(bounds.x, bounds.y)
			result[attr_id] = value
			total += value
		if total >= band_min and total <= band_max:
			return result
		attempts += 1
	push_warning("AttrRoller: 招募掷值 %d 次未入带 [%d, %d]，返回末次掷值" % [
		MAX_REROLL, band_min, band_max,
	])
	return result
