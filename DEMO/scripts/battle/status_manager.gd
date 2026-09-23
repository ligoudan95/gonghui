## 状态管理器（StatusManager，RefCounted 纯逻辑类，每场战斗一个）
## 职责：状态的施加（同名取大 + 互斥覆盖 + 同类叠层 2 上限 + 控制窗口/
## 蛊惑 P3 例外）、两段判定入口（敌方才走命中掷 × 抗性掷）、回合末结算
## （站位地格 DOT → 状态 DOT → 递减三锚点）、控制锁与离格移除、修正量求和。
## 数据来源：案 11《状态效果》§2.2（叠加互斥）/§2.3（递减时序三锚点 + 边界
## 锚点 1 开局载入视为回合 1 前施加 / 锚点 2 同名重施加仅新 ≥ 旧重起算 /
## 锚点 3 即时增益当回合末移除 + 1 回合控制行动窗口 + 蛊惑固定下回合 P3）；
## 案 17《数值专项案》§3.9（叠加上限 2、抗性减免 = 乘法 17-C1）、
## §3.4（跳伤免减免轨）。
## 纯逻辑约束：不触任何 autoload——cfg 与 status_lookup（StringName 状态 id ->
## StatusDef）经 setup 注入；随机源 rng/forced 注入保证测试确定性。
## 单位鸭子契约（批 2 BattleUnit 实现同契约）：
## - side: int（0 = 我方 / 1 = 敌方，与 SkillDef.SkillSide 对齐）
## - alive: bool（倒地跳过 DOT 与递减结算）
## - attrs: Dictionary（{StringName 属性 id: int}，ATTR_RATIO 跳伤换算源）
## - hit: float / dodge: float / status_resist: float（两段判定消费）
## - take_damage(amount: int) -> void（DOT 直扣，不走减免轨）
class_name StatusManager
extends RefCounted

## 离格移除策略 token（判据：StatusDef.remove_policy == 本值——M0 数据侧仅
## 地格三类站位状态（草丛/高地/毒沼）标注该 token；不叠加 source_kind == TILE
## 判定，避免新增站位状态需双标记）
const REMOVE_ON_LEAVE_TILE: StringName = &"on_leave_tile"

## 总控配置（叠加上限/钳制带/调整值换算；setup 注入）
var _cfg: CoreConfig = null
## 状态定义解析回调（StringName 状态 id -> StatusDef；setup 注入）
var _status_lookup: Callable = Callable()
## 单位 -> Array[StatusInstance]（内层为非类型化数组，Godot 4.7 不支持嵌套类型化集合）
var _statuses: Dictionary = {}
## 当前回合号（战斗从 1 起；end_of_round_tick 后推进——施加锚点推算用）
var _current_round: int = 1
## 本回合已行动标记：单位 -> bool（try_apply 的控制窗口口径推算用）
var _acted_this_round: Dictionary = {}

func setup(cfg: CoreConfig, status_lookup: Callable) -> void:
	## 初始化管理器（战斗开始时一次）：注入配置与状态定义解析回调，清空全部状态
	## 参数 cfg：总控配置；status_lookup：StringName -> StatusDef 回调
	## 返回：无
	_cfg = cfg
	_status_lookup = status_lookup
	_statuses = {}
	_acted_this_round = {}
	_current_round = 1

func apply(target: Object, status: StatusDef, source_kind: int, source_id: StringName,
		duration: int, current_round: int, target_acted_this_round: bool) -> bool:
	## 施加状态（直接入口，不走两段判定——己方增益/地格/检定带入路径）：
	## ①同名存在 → remaining = max(旧, 新)，仅新 ≥ 旧时 first_tick_round 重起算
	## （锚点 2，防取大却重起算的反向续时）②互斥组同组 → 后施加覆盖前者
	## ③异名同类 → 现存同类数 < 叠加上限才入场 ④控制类 control_locks = 持续：
	## 未行动锁本回合/已行动锁下回合；蛊惑（BEWITCH）强制 from_next_turn_only
	## 不锁本回合（P3）⑤施加即生效（first_tick_round = 施加回合 + 1，施加回合末
	## 不递减；duration=0 即时类 first_tick_round = 施加回合——当回合末移除且
	## 站位地格 DOT 当回合末可跳）
	## 参数 target：目标单位；status：状态定义；source_kind：StatusInstance.SourceKind；
	## source_id：来源 id；duration：持续回合（≤0 回退 default_duration；仍 ≤0 = 即时类）；
	## current_round：施加回合号（开局载入传 0 = 视为回合 1 前施加，锚点 1）；
	## target_acted_this_round：目标本回合是否已行动（控制窗口判定）
	## 返回：true = 施加/刷新成功（false = 同类叠层超限拒收）
	var effective: int = duration if duration > 0 else status.default_duration
	var target_statuses: Array = _GetUnitStatuses(target)
	# ①同名刷新（取大 + 条件重起算）
	for instance: StatusInstance in target_statuses:
		if instance.status_id != status.id:
			continue
		if effective > instance.remaining:
			instance.remaining = effective
			instance.first_tick_round = _CalcFirstTick(effective, current_round)
		if status.control_kind != StatusDef.ControlKind.NONE:
			instance.control_locks = maxi(instance.control_locks, effective)
		return true
	# ②互斥组覆盖：同组前者移除（17 案 §3.9 同组后施加覆盖前者）
	if not String(status.mutex_group_id).is_empty():
		for instance: StatusInstance in target_statuses.duplicate():
			var existing: StatusDef = _LookupStatus(instance.status_id)
			if existing != null and existing.mutex_group_id == status.mutex_group_id:
				target_statuses.erase(instance)
	# ③异名同类叠层上限（现存同类数 ≥ 上限 → 拒收）
	var same_category: int = 0
	for instance: StatusInstance in target_statuses:
		var existing: StatusDef = _LookupStatus(instance.status_id)
		if existing != null and existing.category == status.category:
			same_category += 1
	if same_category >= _StackLimit():
		return false
	# 新实例入场
	var instance := StatusInstance.new()
	instance.status_id = status.id
	instance.source_kind = source_kind
	instance.source_id = source_id
	instance.remaining = maxi(0, effective)
	instance.duration_zero = effective <= 0
	instance.first_tick_round = _CalcFirstTick(effective, current_round)
	instance.layers = 1
	# ④控制窗口（案 11 §2.3：未行动锁本回合/已行动锁下回合；蛊惑固定下回合 P3）
	if status.control_kind != StatusDef.ControlKind.NONE:
		instance.control_locks = maxi(0, effective)
		if status.control_kind == StatusDef.ControlKind.BEWITCH or target_acted_this_round:
			instance.from_next_turn_only = true
	target_statuses.append(instance)
	return true

func try_apply_with_judgement(caster: Object, target: Object, skill: SkillDef, status: StatusDef,
		duration: int, rng: RandomNumberGenerator, forced: int = -1) -> bool:
	## 两段判定施加入口（技能 STATUS_APPLY 消费）：敌方目标才走两段——
	## 命中掷（未中 = 施加失败，资源照扣不返还）→ 抗性掷（成功率 ×(1 − 异常状态
	## 抗性)，乘法口径 17-C1）；己方增益（同侧目标）直接 apply 免判定
	## （地格/检定带入走 apply 直接入口，天然免判定）
	## 参数 caster：施放者；target：目标单位；skill：施加技能（hit_mod 入命中式）；
	## status：状态定义；duration：持续回合；rng：随机源；forced：强制口
	## （-1 掷随机 / 0 强制失败 / 1 强制成功——两段同口，测试确定性）
	## 返回：true = 施加成功
	var acted: bool = _acted_this_round.get(target, false)
	if caster.side == target.side:
		return apply(target, status, StatusInstance.SourceKind.SKILL, skill.id,
				duration, _current_round, acted)
	var chance: float = BattleRules.hit_chance(caster.hit, target.dodge, skill.hit_mod, _cfg)
	if not BattleRules.roll_hit(chance, rng, forced):
		return false
	var resist_chance: float = maxf(0.0, 1.0 - target.status_resist)
	if not BattleRules.roll_hit(resist_chance, rng, forced):
		return false
	return apply(target, status, StatusInstance.SourceKind.SKILL, skill.id,
			duration, _current_round, acted)

func end_of_round_tick(round: int, units: Array, rng: RandomNumberGenerator) -> void:
	## 回合末结算（案 9 回合末流程收口）：①DOT 跳伤——站位地格来源（毒沼固定
	## 6 免减免）先跳、其余状态 DOT（dot_tick）后跳，直扣不过减免轨；②持续遍历：
	## 即时类（duration_zero）移除、round ≥ first_tick_round 递减归零移除；
	## ③清除 from_next_turn_only（施加回合结束，蛊惑/已行动锁自下回合生效）；
	## ④重置已行动标记、推进内部回合号
	## 参数 round：刚结束的回合号；units：参战单位全集（含倒地，倒地跳过 DOT）；rng：随机源（预留）
	## 返回：无
	# ①DOT 跳伤（地格来源优先）
	for tile_source: bool in [true, false]:
		for unit: Object in units:
			if not unit.alive:
				continue
			for instance: StatusInstance in _GetUnitStatuses(unit).duplicate():
				if (instance.source_kind == StatusInstance.SourceKind.TILE) != tile_source:
					continue
				if round < instance.first_tick_round:
					continue
				var status: StatusDef = _LookupStatus(instance.status_id)
				if status == null or status.category != StatusDef.Category.DOT or status.dot == null:
					continue
				unit.take_damage(BattleRules.dot_tick(unit.attrs, status.dot))
	# ②持续递减与移除
	for unit: Object in units:
		for instance: StatusInstance in _GetUnitStatuses(unit).duplicate():
			if instance.duration_zero:
				_GetUnitStatuses(unit).erase(instance)
				continue
			if round >= instance.first_tick_round:
				instance.remaining -= 1
				if instance.remaining <= 0:
					_GetUnitStatuses(unit).erase(instance)
	# ③施加回合结束：锁定跳过标记失效（蛊惑/已行动锁自下回合生效）
	for unit: Object in units:
		for instance: StatusInstance in _GetUnitStatuses(unit):
			instance.from_next_turn_only = false
	# ④回合推进与已行动标记重置
	_acted_this_round = {}
	_current_round = round + 1

func on_unit_turn_locked(unit: Object) -> bool:
	## 行动轮开始锁定查询：存在控制锁 > 0 且未标记跳过施加回合 → 锁定
	## （定身类未行动 = 施加回合即锁；蛊惑/已行动施加经 from_next_turn_only
	## 跳过施加回合，回合末清除后下回合起锁）
	## 参数 unit：待行动单位
	## 返回：true = 本行动轮被控制锁定（跳过行动）
	for instance: StatusInstance in _GetUnitStatuses(unit):
		if instance.control_locks > 0 and not instance.from_next_turn_only:
			return true
	return false

func get_active_control(unit: Object) -> int:
	## 行动轮生效的控制种类（M1 批 2 增）：定身 = 完全跳过行动轮、蛊惑 = 自动
	## 随机行动——BattleController 分派消费；返回首个生效控制实例的种类
	## 参数 unit：待行动单位
	## 返回：StatusDef.ControlKind（NONE = 未被控制）
	for instance: StatusInstance in _GetUnitStatuses(unit):
		if instance.control_locks > 0 and not instance.from_next_turn_only:
			var status: StatusDef = _LookupStatus(instance.status_id)
			if status != null and status.control_kind != StatusDef.ControlKind.NONE:
				return status.control_kind
	return StatusDef.ControlKind.NONE

func on_unit_turn_finished(unit: Object) -> void:
	## 行动轮结束（被锁或正常行动同口径）：标记已行动 + 控制锁递减
	## （锁定到期即解锁，持续时间照常回合末递减清零——两轨并行不冲突）
	## 参数 unit：结束行动轮的单位
	## 返回：无
	_acted_this_round[unit] = true
	for instance: StatusInstance in _GetUnitStatuses(unit):
		if instance.control_locks > 0:
			instance.control_locks -= 1

func on_unit_moved(unit: Object) -> void:
	## 单位移动后：移除离格移除类站位状态（草丛/高地/毒沼——判据 =
	## StatusDef.remove_policy == on_leave_tile，站上地格期间的再施加归
	## 批 2 战斗流程：入格/站位时调 apply(TILE) 重建）
	## 参数 unit：移动单位
	## 返回：无
	for instance: StatusInstance in _GetUnitStatuses(unit).duplicate():
		var status: StatusDef = _LookupStatus(instance.status_id)
		if status != null and status.remove_policy == REMOVE_ON_LEAVE_TILE:
			_GetUnitStatuses(unit).erase(instance)

func get_stat_mod(unit: Object, key: StringName) -> float:
	## 修正量求和：单位全部在场状态同 key 修正的 Σ（如 &"dodge"/&"move_range"/
	## &"damage_panel_mult"——乘算类键 DEMO 单源口径，多源时为加法近似）
	## 参数 unit：单位；key：修正键
	## 返回：Σ修正值（无状态返回 0.0）
	var total: float = 0.0
	for instance: StatusInstance in _GetUnitStatuses(unit):
		var status: StatusDef = _LookupStatus(instance.status_id)
		if status != null and status.modifiers.has(key):
			total += status.modifiers[key]
	return total

func get_statuses(unit: Object) -> Array[StatusInstance]:
	## 取单位在场状态实例列表（副本，外部不可借引用改内部数组）
	## 参数 unit：单位
	## 返回：StatusInstance 列表副本
	var result: Array[StatusInstance] = []
	result.append_array(_GetUnitStatuses(unit))
	return result

func clear_all() -> void:
	## 清空全部状态（战斗结束/重置）
	## 参数：无
	## 返回：无
	_statuses = {}
	_acted_this_round = {}

func _GetUnitStatuses(unit: Object) -> Array:
	## 取单位状态数组（懒建，内部可变引用）
	## 参数 unit：单位
	## 返回：该单位的状态实例数组
	if not _statuses.has(unit):
		var fresh: Array[StatusInstance] = []
		_statuses[unit] = fresh
	return _statuses[unit]

func _LookupStatus(status_id: StringName) -> StatusDef:
	## 经注入回调解析状态定义（解析失败 push_warning 并返回 null）
	## 参数 status_id：状态 id
	## 返回：StatusDef；未知 id 返回 null
	var status: StatusDef = _status_lookup.call(status_id) as StatusDef
	if status == null:
		push_warning("StatusManager: 状态 '%s' 无法解析（lookup 未登记）" % status_id)
	return status

func _StackLimit() -> int:
	## 同类叠层上限（cfg.status_stack_limit，DEMO = 2）
	## 参数：无
	## 返回：上限值（cfg 缺省回退 2）
	return _cfg.status_stack_limit if _cfg != null else 2

func _CalcFirstTick(effective: int, current_round: int) -> int:
	## 递减锚点计算：即时类（≤0）= 施加回合（当回合末移除/可跳）；
	## 常规 = 施加回合 + 1（施加回合末不递减，施加即生效不受影响）
	## 参数 effective：生效持续回合；current_round：施加回合号（开局载入传 0）
	## 返回：首个递减回合号
	return current_round if effective <= 0 else current_round + 1
