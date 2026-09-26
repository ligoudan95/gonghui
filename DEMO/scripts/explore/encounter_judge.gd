## 遭遇判定器（EncounterJudge，纯静态工具类）
## 职责：随机遭遇掷值（新格才掷/概率域/单次出征上限拦截）与宝箱金域掷值。
## 数据来源：案 7《地图与探索》（随机遭遇与宝箱口径）；案 17 §3.10
## （概率域）；M3 方案批 1（原设计矿洞 4% 上限 1 / 宝箱金域 [20,40]——
## 2026-09-25 用户拍板【DEMO 排除所有随机战斗】后真实表 encw_mine.chance
## 已归 0：机制保留、数据侧关闭，权重/上限/概率全表驱动——W4-12 漂移同步）。
## 纯逻辑约束：不触任何 autoload——weight/point/rng 全参数注入。
class_name EncounterJudge
extends RefCounted

static func should_trigger(is_new_cell: bool, weight: EncounterWeightDef,
		fired: int, rng: RandomNumberGenerator) -> bool:
	## 随机遭遇掷值：非新格不掷（旧格往返免掷）；权重空/概率 ≤ 0 不掷；
	## 已触发次数 ≥ random_max 拒；否则 randf < encounter_chance
	## 参数 is_new_cell：本格是否本会话首次踏入；weight：区域遭遇权重；
	## fired：本出征已触发次数（run.random_encounters_fired）；
	## rng：随机源（注入——headless 可测）
	## 返回：true = 触发遭遇（调用方中断移动路由战斗）
	if not is_new_cell or weight == null:
		return false
	if weight.encounter_chance <= 0.0:
		return false
	if fired >= weight.random_max:
		return false
	return rng.randf() < weight.encounter_chance

static func roll_treasure_gold(point: InteractPointDef,
		rng: RandomNumberGenerator) -> int:
	## 宝箱金域掷值：[gold_min, gold_max] 闭区间均匀掷值
	## 参数 point：宝箱交互点；rng：随机源
	## 返回：金币量（域非法时返回 0——V-M3-treasure-domain 数据侧拦截）
	if point == null or point.gold_min > point.gold_max:
		return 0
	return rng.randi_range(point.gold_min, point.gold_max)
