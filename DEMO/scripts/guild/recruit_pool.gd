## 招募池（RecruitPool，RefCounted 纯逻辑类）
## 职责：协会招募池的候选生成与刷新——容量（cfg）、整池替换刷新、偏缺职业
## 优先（未持有职业集合优先、不足补全职业随机）、候选属性掷值（AttrRoller.
## roll_recruit 钳制带注入）、三档花费落位与候选 id/姓名生成。
## 数据来源：案 5 §2.4（招募池细则：容量约束/每日刷新/偏缺职业/花费浮动）；
## 案 17 §3.7（三档 225/250/300、档界 74/78、池容量 3）。
## 纯逻辑约束：不触任何 autoload——cfg/game_data/rng 注入；余额与宿舍容量
## 校验及扣款入册在 GuildCore 门面层。
class_name RecruitPool
extends RefCounted

## 招募实例 id 前缀（adv_recruit_N 递增——与 adv_* 种子不冲突）
const RECRUIT_ID_PREFIX: String = "adv_recruit_"

## 当前候选列表（AdventurerData——pre_unlocked=false、技能清单空待解锁）
var candidates: Array[AdventurerData] = []
## 本轮刷新未用名袋（Z2-8：同批候选名不放回——防同名；袋空回退 id 派生名）
var _name_bag: Array[String] = []
## 候选序号发生器（持久于公会快照 recruit_serial）
var serial: int = 1
## 总控配置（注入）
var cfg: CoreConfig
## 数据源（注入）
var game_data: Node
## 随机源（注入——测试确定性）
var rng: RandomNumberGenerator

func setup(cfg: CoreConfig, game_data: Node, rng: RandomNumberGenerator) -> void:
	## 依赖注入（GuildCore.setup 装配；测试同入口）
	## 参数 cfg/game_data/rng：总控配置 / GameData / 随机源
	## 返回：无
	self.cfg = cfg
	self.game_data = game_data
	self.rng = rng

func refresh(roster_class_ids: Array[StringName]) -> void:
	## 整池替换刷新（每日日结算第 5 步口径）：候选职业=未持有职业集合优先
	##（不足容量补全职业随机——案 5「确保六职业在 DEMO 内均可体验」）
	## 参数 roster_class_ids：当前名册全部职业 id（去重与否不影响判定）
	## 返回：无
	candidates.clear()
	var all_class_ids: Array[StringName] = []
	for class_id: StringName in game_data.get_domain_ids(&"class/classes"):
		all_class_ids.append(class_id)
	var missing: Array[StringName] = []
	for class_id: StringName in all_class_ids:
		if not roster_class_ids.has(class_id):
			missing.append(class_id)
	_ShuffleInPlace(missing)
	_ShuffleInPlace(all_class_ids)
	_name_bag.clear()
	for pool_name: String in cfg.recruit_name_pool:
		_name_bag.append(pool_name)
	_ShuffleInPlace(_name_bag)
	var plan: Array[StringName] = []
	for class_id: StringName in missing:
		if plan.size() >= cfg.recruit_pool_capacity:
			break
		plan.append(class_id)
	for class_id: StringName in all_class_ids:
		if plan.size() >= cfg.recruit_pool_capacity:
			break
		plan.append(class_id)
	for class_id: StringName in plan:
		candidates.append(generate_candidate(class_id))

func _ShuffleInPlace(target: Array) -> void:
	## 注入随机源的洗牌（Fisher-Yates——确定性测试可控；参数降为无类型
	## Array——Z2-8 名袋 Array[String] 与职业表共用本口）
	## 参数 target：待洗数组（原地打乱）
	## 返回：无
	for index: int in range(target.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temp: Variant = target[index]
		target[index] = target[swap_index]
		target[swap_index] = temp

func generate_candidate(class_id: StringName) -> AdventurerData:
	## 生成单名候选：属性=AttrRoller.roll_recruit（钳制带 cfg 注入）、
	## 技能点=出生值、pre_unlocked=false（第 1 技须花点解锁——17 案 §3.6）、
	## id=adv_recruit_N 递增、姓名=cfg 占位名池随机
	## 参数 class_id：职业 id
	## 返回：新候选（未入池——refresh/测试装配决定）
	var cls: ClassDef = game_data.get_record(class_id) as ClassDef
	var adv := AdventurerData.new()
	var my_serial: int = serial
	serial += 1
	adv.unit_id = StringName("%s%d" % [RECRUIT_ID_PREFIX, my_serial])
	adv.class_id = class_id
	adv.display_name = _PickName(my_serial)
	adv.level = 1
	adv.exp = 0
	if cls != null:
		adv.attrs = AttrRoller.roll_recruit(cls, rng, cfg.recruit_band_min, cfg.recruit_band_max)
	else:
		adv.attrs = {}
	adv.skill_ids = []
	adv.skill_points = cfg.skill_points_birth
	adv.pre_unlocked = false
	return adv

func _PickName(my_serial: int) -> String:
	## 从本轮名袋不放回取名（Z2-8：同批候选不重名；袋空/池空回退 id 派生串
	##——D-3：派生串与 unit_id 序号一致，无 off-by-one）
	## 参数 my_serial：本候选序号（兜底名派生）
	## 返回：姓名
	if not _name_bag.is_empty():
		return _name_bag.pop_back()
	return RECRUIT_ID_PREFIX + str(my_serial)

func cost_of(candidate: AdventurerData) -> int:
	## 三档花费落位（案 17 §3.7）：属性总和 < line_low → low / < line_high → mid
	## / 其余 → high（74 归上段 250 档——档界归上口径）
	## 参数 candidate：候选
	## 返回：招募花费
	var total: int = total_attrs(candidate)
	if total < cfg.recruit_cost_line_low:
		return cfg.recruit_cost_low
	if total < cfg.recruit_cost_line_high:
		return cfg.recruit_cost_mid
	return cfg.recruit_cost_high

static func total_attrs(candidate: AdventurerData) -> int:
	## 属性总和（三档花费的判定基数）
	## 参数 candidate：候选
	## 返回：七属性值合计
	var total: int = 0
	for attr_id: StringName in candidate.attrs:
		total += int(candidate.attrs[attr_id])
	return total

func to_snapshot() -> Dictionary:
	## 快照序列化（GuildCore.to_snapshot 组装）
	## 参数：无
	## 返回：{serial, candidates: [dict]}
	var plain_candidates: Array = []
	for candidate: AdventurerData in candidates:
		plain_candidates.append(candidate.to_dict())
	return {
		"serial": serial,
		"candidates": plain_candidates,
	}

func restore_snapshot(data: Dictionary) -> void:
	## 快照恢复（实例损坏条目跳过——存档结构问题由 schema_version 前置拦截）
	## 参数 data：to_snapshot 产出的 Dictionary
	## 返回：无
	candidates.clear()
	serial = int(data.get("serial", 1))
	for candidate_data: Dictionary in data.get("candidates", []):
		var candidate: AdventurerData = AdventurerData.from_dict(candidate_data)
		if candidate != null:
			candidates.append(candidate)
