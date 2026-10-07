## 属性掷值器（AttrRoller，纯静态工具类）
## 职责：冒险者一级属性生成——初始固定 4 人（区间中值偏上，豁免钳制）
## 与招募候选（区间内随机 + 七属性总和带钳制 70-80，越界整组重掷）。
## 数据来源：案 17《数值专项案》§3.1（六职业初始属性区间 + 钳制带）；
## 17-C7（初始 4 人中值偏上、豁免钳制）/17-C17（钳制带上界 80 + 越界整组重掷）。
## 纯逻辑约束：不触任何 autoload——随机源 rng 注入保证测试确定性。
class_name AttrRoller
extends RefCounted

## 招募重掷循环上限（保护带不可达时的退出；超限回退区间中值定值组并
## push_warning——漏洞7：不再返回带外随机掷值）
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
	## 保护——超限回退区间中值定值组（2026-10-03 审计·漏洞7：不再返回末次
	## 带外掷值——职业区间与钳制带不兼容的数据回归错误会静默携带越界属性
	## 入场；回退组构造与收敛规则见 _MidpointGroupInBand）并 push_warning
	## 参数 cls：职业表；rng：随机源；band_min/band_max：总和钳制带——**默认值与
	## cfg_main.recruit_band_min/recruit_band_max 同源声明**（批 B M4：参数已入表，
	## 产品调用点（M4 招募流程）落地时须传 cfg 值；默认保留 70/80 保签名可注入
	## 的测试友好性）
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
	push_warning("AttrRoller: 招募掷值 %d 次未入带 [%d, %d]，回退区间中值定值组" % [
		MAX_REROLL, band_min, band_max,
	])
	return _MidpointGroupInBand(cls, band_min, band_max)

static func _MidpointGroupInBand(cls: ClassDef, band_min: int,
		band_max: int) -> Dictionary[StringName, int]:
	## 超限回退组（漏洞7 内部口）：每属性取职业区间中值构造定值组——中值组
	## 已在带内直接返回；带外时按带中心比例缩放并逐属性钳回区间（区间为硬
	## 边界），再逐点微调逼近带（以能进带为准——区间总和与带有交集时必收敛
	## 入带；结构性不可达（如区间上限总和 < 带下限）时止步于最接近带的
	## 区间内组，确定性输出——同表同带同结果，不再携带随机带外掷值）
	## 参数 cls：职业表；band_min/band_max：总和钳制带
	## 返回：{StringName 属性 id: int 掷值}
	var result: Dictionary[StringName, int] = {}
	var total: int = 0
	for attr_id: StringName in cls.attr_ranges:
		var bounds: Vector2i = cls.attr_ranges[attr_id]
		var mid: int = int(floor((bounds.x + bounds.y) / 2.0))
		result[attr_id] = mid
		total += mid
	if total >= band_min and total <= band_max:
		return result
	# 按带中心比例缩放（中值组带外——总和偏高缩低/偏低缩高），逐属性钳回区间
	var band_center: int = int(floor((band_min + band_max) / 2.0))
	var scale: float = float(band_center) / float(maxi(1, total))
	total = 0
	for attr_id: StringName in result:
		var bounds: Vector2i = cls.attr_ranges[attr_id]
		result[attr_id] = clampi(roundi(result[attr_id] * scale), bounds.x, bounds.y)
		total += result[attr_id]
	# 逐点微调（以能进带为准）：钳制/舍入残留带外时每次挪 1 点可动属性逼近；
	# 无可动属性（区间全锁死）= 结构性不可达，止步
	while total < band_min or total > band_max:
		var adjusted: bool = false
		for attr_id: StringName in result:
			var bounds: Vector2i = cls.attr_ranges[attr_id]
			if total < band_min and result[attr_id] < bounds.y:
				result[attr_id] += 1
				total += 1
				adjusted = true
			elif total > band_max and result[attr_id] > bounds.x:
				result[attr_id] -= 1
				total -= 1
				adjusted = true
			if total >= band_min and total <= band_max:
				break
		if not adjusted:
			break
	return result
