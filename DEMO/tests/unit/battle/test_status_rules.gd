## StatusManager/StatusInstance 单元测试（M1 批 1）
## 覆盖：两段判定（敌走双掷/己方免/地格直接入口免）、同名取大 + 重施加锚点
## （新 ≥ 旧才重起算）、叠层 2 上限、互斥覆盖（定身↔蛊惑）、递减三锚点
## （施加回合末不递减/开局载入回合 1 末递减/3 回合诅咒恰 3 跳）、即时增益
## duration=0 当回合末移除、控制窗口（未行动锁本回合/已行动锁下回合/蛊惑固定
## 下回合不锁本回合 P3）、DOT 免减免、修正求和、clear_all。
## 状态定义经字典闭包注入（带真实 DEMO 数值），不触 autoload。
extends GdUnitTestSuite

## cfg_main 真实数据路径
const CFG_PATH: String = "res://data/core/cfg_main.tres"

## 套件级组件
var _cfg: CoreConfig
var _manager: StatusManager
var _statuses: Dictionary = {}
var _rng: RandomNumberGenerator

## 测试替身单位（鸭子契约：side/alive/attrs/hit/dodge/status_resist/take_damage）
class FakeUnit:
	extends RefCounted
	var id: StringName = &"unit"
	var side: int = 0
	var alive: bool = true
	var attrs: Dictionary = {&"willpower": 16}
	var hit: float = 0.80
	var dodge: float = 0.04
	var status_resist: float = 0.0
	var hp: int = 100
	var damage_log: Array[int] = []

	func take_damage(amount: int) -> void:
		## 直扣伤害（DOT 免减免轨——护甲/抗性不参与）
		damage_log.append(amount)
		hp -= amount
		if hp <= 0:
			alive = false

func before() -> void:
	## 套件前置：加载 cfg_main、构建状态字典（before 为套件级钩子，重资源只载一次）
	## 参数：无
	## 返回：无
	_cfg = load(CFG_PATH) as CoreConfig
	_statuses = {}
	_Register(_MakeStatMod(&"DEBUFF_slow", {&"move_range": -2.0}, 2))
	_Register(_MakeStatMod(&"DEBUFF_exposed", {&"dodge": -0.10}, 1))
	_Register(_MakeStatMod(&"DEBUFF_third", {&"hit": -0.05}, 1))
	_Register(_MakeControl(&"DEBUFF_root", StatusDef.ControlKind.ROOT, 1, &"mgrp_control"))
	_Register(_MakeControl(&"DEBUFF_bewitch", StatusDef.ControlKind.BEWITCH, 1, &"mgrp_control"))
	_Register(_MakeInstant(&"BUFF_sprint", {&"move_range": 2.0, &"dodge": 0.15}))
	_Register(_MakeCurse(&"DEBUFF_curse", 3))
	_Register(_MakePoison(&"DEBUFF_tile_poison"))
	_rng = RandomNumberGenerator.new()
	_rng.seed = 42

func before_test() -> void:
	## 用例前置：重建 StatusManager（状态/回合号/行动标记为可变状态，逐用例隔离——
	## gdUnit before() 系套件级钩子，用例级须用 before_test）
	## 参数：无
	## 返回：无
	_manager = StatusManager.new()
	_manager.setup(_cfg, _LookupStatus)

func _LookupStatus(status_id: StringName) -> StatusDef:
	## 状态定义解析闭包（字典查找）
	## 参数 status_id：状态 id
	## 返回：StatusDef（未登记返回 null）
	return _statuses.get(status_id, null)

func _Register(status: StatusDef) -> void:
	## 登记状态定义到字典
	## 参数 status：状态定义
	## 返回：无
	_statuses[status.id] = status

func _MakeStatMod(status_id: StringName, modifiers: Dictionary, duration: int) -> StatusDef:
	## 构建属性修正类状态
	## 参数：状态 id / 修正量表 / 默认持续
	## 返回：StatusDef
	var status := StatusDef.new()
	status.id = status_id
	status.category = StatusDef.Category.STAT_MOD
	status.modifiers = _TypedMods(modifiers)
	status.default_duration = duration
	return status

func _MakeInstant(status_id: StringName, modifiers: Dictionary) -> StatusDef:
	## 构建即时增益（default_duration = 0 → 当回合末移除）
	## 参数：状态 id / 修正量表
	## 返回：StatusDef
	var status := StatusDef.new()
	status.id = status_id
	status.category = StatusDef.Category.STAT_MOD
	status.polarity = StatusDef.Polarity.BUFF
	status.modifiers = _TypedMods(modifiers)
	status.default_duration = 0
	status.remove_policy = &""
	return status

func _MakeControl(status_id: StringName, kind: StatusDef.ControlKind,
		duration: int, mutex_group: StringName) -> StatusDef:
	## 构建控制类状态（定身/蛊惑，同互斥组）
	## 参数：状态 id / 控制种类 / 持续 / 互斥组 id
	## 返回：StatusDef
	var status := StatusDef.new()
	status.id = status_id
	status.category = StatusDef.Category.CONTROL
	status.control_kind = kind
	status.default_duration = duration
	status.mutex_group_id = mutex_group
	return status

func _MakeCurse(status_id: StringName, duration: int) -> StatusDef:
	## 构建 DOT 状态（诅咒 = 意志×0.5）
	## 参数：状态 id / 持续
	## 返回：StatusDef
	var status := StatusDef.new()
	status.id = status_id
	status.category = StatusDef.Category.DOT
	var dot := DotParams.new()
	dot.mode = DotParams.Mode.ATTR_RATIO
	dot.attr_id = &"willpower"
	dot.ratio = 0.5
	status.dot = dot
	status.default_duration = duration
	return status

func _MakePoison(status_id: StringName) -> StatusDef:
	## 构建地格毒沼状态（固定 6 伤/离格移除/即时类）
	## 参数：状态 id
	## 返回：StatusDef
	var status := StatusDef.new()
	status.id = status_id
	status.category = StatusDef.Category.DOT
	var dot := DotParams.new()
	dot.mode = DotParams.Mode.FIXED
	dot.fixed = 6
	status.dot = dot
	status.default_duration = 0
	status.allowed_sources = [&"TILE"]
	status.remove_policy = &"on_leave_tile"
	return status

func _TypedMods(modifiers: Dictionary) -> Dictionary[StringName, float]:
	## 修正量表字面量 -> 类型化字典
	## 参数 modifiers：{StringName: float}
	## 返回：Dictionary[StringName, float]
	var typed: Dictionary[StringName, float] = {}
	for key: StringName in modifiers:
		typed[key] = modifiers[key]
	return typed

func _IdsOf(unit: FakeUnit) -> Array[StringName]:
	## 取单位在场状态 id 列表
	## 参数 unit：单位
	## 返回：状态 id 列表
	var ids: Array[StringName] = []
	for instance: StatusInstance in _manager.get_statuses(unit):
		ids.append(instance.status_id)
	return ids

func test_two_stage_enemy_requires_both_rolls() -> void:
	## 敌方目标走两段：forced=1（双掷强制成功）→ 施加；forced=0（首掷强制失败）→ 不施加
	var caster := FakeUnit.new()
	var target := FakeUnit.new()
	target.side = 1
	var skill := SkillDef.new()
	assert_bool(_manager.try_apply_with_judgement(caster, target, skill,
			_statuses[&"DEBUFF_slow"], 2, _rng, 1)).is_true()
	assert_int(_IdsOf(target).size()).is_equal(1)
	assert_bool(_manager.try_apply_with_judgement(caster, target, skill,
			_statuses[&"DEBUFF_root"], 1, _rng, 0)).is_false()

func test_resist_roll_rejects() -> void:
	## 抗性掷：状态抗性 100% + forced=-1 → 第二掷必失败（乘法口径 17-C1）
	var caster := FakeUnit.new()
	var target := FakeUnit.new()
	target.side = 1
	target.status_resist = 1.0
	var skill := SkillDef.new()
	assert_bool(_manager.try_apply_with_judgement(caster, target, skill,
			_statuses[&"DEBUFF_slow"], 2, _rng, -1)).is_false()

func test_ally_apply_skips_judgement() -> void:
	## 己方增益免判定：forced=0（必败强制口）仍直接施加
	var caster := FakeUnit.new()
	var ally := FakeUnit.new()
	var skill := SkillDef.new()
	assert_bool(_manager.try_apply_with_judgement(caster, ally, skill,
			_statuses[&"BUFF_sprint"], 0, _rng, 0)).is_true()
	assert_bool(_IdsOf(ally).has(&"BUFF_sprint")).is_true()

func test_tile_source_direct_apply_free_of_judgement() -> void:
	## 地格来源走 apply 直接入口（天然免两段判定——站位毒沼无任何掷骰）
	var unit := FakeUnit.new()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_tile_poison"],
			StatusInstance.SourceKind.TILE, &"tile_poison_swamp", 0, 1, false)).is_true()
	assert_bool(_IdsOf(unit).has(&"DEBUFF_tile_poison")).is_true()

func test_same_name_take_larger_and_anchor() -> void:
	## 同名取大 + 锚点 2：新 ≥ 旧才重起算 first_tick_round；旧大维持原锚点
	var unit := FakeUnit.new()
	# 回合 1 施加 slow 1 回合：锚点 = 2
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_slow"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 1, 1, false)).is_true()
	var instance: StatusInstance = _manager.get_statuses(unit)[0]
	assert_int(instance.remaining).is_equal(1)
	assert_int(instance.first_tick_round).is_equal(2)
	# 同回合重施加 3 回合（新 ≥ 旧）：取 3、锚点重起算仍 = 2
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_slow"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 3, 1, false)).is_true()
	instance = _manager.get_statuses(unit)[0]
	assert_int(instance.remaining).is_equal(3)
	assert_int(instance.first_tick_round).is_equal(2)
	# 回合 2 末递减后（剩 2），回合 3 重施加 1 回合（旧 2 > 新 1）：remaining 维持 2、锚点维持 2
	_manager.end_of_round_tick(2, [unit], _rng)
	assert_int(_manager.get_statuses(unit)[0].remaining).is_equal(2)
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_slow"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 1, 3, false)).is_true()
	instance = _manager.get_statuses(unit)[0]
	assert_int(instance.remaining).is_equal(2)
	assert_int(instance.first_tick_round).is_equal(2)

func test_stack_limit_two_same_category() -> void:
	## 异名同类叠层 2 上限：两个 STAT_MOD 减益可共存，第三个拒收
	var unit := FakeUnit.new()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_slow"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 2, 1, false)).is_true()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_exposed"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 1, 1, false)).is_true()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_third"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 1, 1, false)).is_false()
	assert_int(_IdsOf(unit).size()).is_equal(2)

func test_mutex_group_later_overrides() -> void:
	## 互斥组：定身后施加蛊惑 → 前者移除后者在场（同组后施加覆盖前者）
	var unit := FakeUnit.new()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_root"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 1, 1, false)).is_true()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_bewitch"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 1, 1, false)).is_true()
	var ids: Array[StringName] = _IdsOf(unit)
	assert_bool(ids.has(&"DEBUFF_root")).is_false()
	assert_bool(ids.has(&"DEBUFF_bewitch")).is_true()

func test_curse_exactly_three_ticks() -> void:
	## 3 回合诅咒恰 3 跳（锚点：施加回合末不跳不减）：回合 1 施加 →
	## 回合 2/3/4 末各跳 8（意志 16×0.5）→ 回合 4 末移除
	var unit := FakeUnit.new()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_curse"],
			StatusInstance.SourceKind.SKILL, &"skl_arcanist_curse", 3, 1, false)).is_true()
	_manager.end_of_round_tick(1, [unit], _rng)
	assert_int(unit.damage_log.size()).is_equal(0)
	_manager.end_of_round_tick(2, [unit], _rng)
	assert_int(unit.damage_log.size()).is_equal(1)
	assert_int(unit.damage_log[0]).is_equal(8)
	_manager.end_of_round_tick(3, [unit], _rng)
	_manager.end_of_round_tick(4, [unit], _rng)
	assert_int(unit.damage_log.size()).is_equal(3)
	assert_int(_IdsOf(unit).size()).is_equal(0)

func test_battle_load_anchor_ticks_at_round1_end() -> void:
	## 开局载入锚点：current_round=0 施加（视为回合 1 前）→ 回合 1 末照常递减
	var unit := FakeUnit.new()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_exposed"],
			StatusInstance.SourceKind.CHECKIN, &"checkin_x", 1, 0, false)).is_true()
	assert_int(_manager.get_statuses(unit)[0].first_tick_round).is_equal(1)
	_manager.end_of_round_tick(1, [unit], _rng)
	assert_int(_IdsOf(unit).size()).is_equal(0)

func test_instant_duration_zero_removed_same_round_end() -> void:
	## 即时增益（duration=0）：当回合生效（施加即生效）、当回合末直接移除
	var unit := FakeUnit.new()
	assert_bool(_manager.apply(unit, _statuses[&"BUFF_sprint"],
			StatusInstance.SourceKind.SKILL, &"skl_rogue_sprint", 0, 1, false)).is_true()
	assert_float(_manager.get_stat_mod(unit, &"move_range")).is_equal_approx(2.0, 0.0001)
	assert_float(_manager.get_stat_mod(unit, &"dodge")).is_equal_approx(0.15, 0.0001)
	_manager.end_of_round_tick(1, [unit], _rng)
	assert_int(_IdsOf(unit).size()).is_equal(0)

func test_root_locks_current_round_when_not_acted() -> void:
	## 控制窗口（未行动）：回合 1 施加定身（目标未行动）→ 锁本回合；行动轮结束递减解锁
	var unit := FakeUnit.new()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_root"],
			StatusInstance.SourceKind.SKILL, &"skl_frost_chain", 1, 1, false)).is_true()
	assert_bool(_manager.on_unit_turn_locked(unit)).is_true()
	_manager.on_unit_turn_finished(unit)
	assert_bool(_manager.on_unit_turn_locked(unit)).is_false()

func test_root_locks_next_round_when_already_acted() -> void:
	## 控制窗口（已行动）：施加时目标已行动 → 本回合查询不锁，回合末后锁下回合
	var unit := FakeUnit.new()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_root"],
			StatusInstance.SourceKind.SKILL, &"skl_frost_chain", 1, 1, true)).is_true()
	assert_bool(_manager.on_unit_turn_locked(unit)).is_false()
	_manager.end_of_round_tick(1, [unit], _rng)
	assert_bool(_manager.on_unit_turn_locked(unit)).is_true()

func test_bewitch_locks_only_next_round() -> void:
	## 蛊惑 P3：固定「下回合」起算——本回合不锁（即使未行动）、回合末后锁下回合；
	## 下回合行动轮结束递减 + 回合末持续递减清零
	var unit := FakeUnit.new()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_bewitch"],
			StatusInstance.SourceKind.SKILL, &"skl_arcanist_bewitch", 1, 1, false)).is_true()
	assert_bool(_manager.on_unit_turn_locked(unit)).is_false()
	_manager.end_of_round_tick(1, [unit], _rng)
	assert_bool(_manager.on_unit_turn_locked(unit)).is_true()
	_manager.on_unit_turn_finished(unit)
	assert_bool(_manager.on_unit_turn_locked(unit)).is_false()
	_manager.end_of_round_tick(2, [unit], _rng)
	assert_int(_IdsOf(unit).size()).is_equal(0)

func test_bewitch_lock_survives_apply_round_turn() -> void:
	## 蛊惑锁施加回合时序（盲审批 1-2：施放者先手 + 目标同回合后续行动——
	## 目标施加回合行动轮结束不得消耗锁（from_next_turn_only 跳过递减），
	## 回合末清标记后下回合仍锁定生效；旧代码此处锁 1→0 蛊惑从未生效——
	## 既有用例缺施加回合行动轮这一步，正是 S1 指出的盲区时序）
	var unit := FakeUnit.new()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_bewitch"],
			StatusInstance.SourceKind.SKILL, &"skl_arcanist_bewitch", 1, 1, false)).is_true()
	# 施加回合目标行动轮照常走完（旧代码在此把 control_locks 1→0）
	_manager.on_unit_turn_finished(unit)
	# 回合末：清 from_next 标记（持续 1 回合不递减——first_tick=2）
	_manager.end_of_round_tick(1, [unit], _rng)
	# 下回合：蛊惑仍生效（旧代码此处为 NONE——锁已被施加回合行动轮耗尽）
	assert_int(_manager.get_active_control(unit)).is_equal(StatusDef.ControlKind.BEWITCH)
	# 锁定行动轮结束消耗锁；回合末持续递减移除
	_manager.on_unit_turn_finished(unit)
	assert_int(_manager.get_active_control(unit)).is_equal(StatusDef.ControlKind.NONE)
	_manager.end_of_round_tick(2, [unit], _rng)
	assert_int(_IdsOf(unit).size()).is_equal(0)

func test_curse_dot_uses_caster_snapshot() -> void:
	## 诅咒 DOT 施方快照（盲审批 1-5【用户拍板：施方快照】）：奇术师意志 16
	## 施加 → 8/跳 ×3 = 24（旧受方口径 4-6/跳）；施方不在场（模拟倒地）仍按
	## 快照跳——17 案定稿口径「施方意志×0.5」
	var caster := FakeUnit.new()
	caster.side = 0
	caster.attrs = {&"willpower": 16}
	var target := FakeUnit.new()
	target.side = 1
	target.attrs = {&"willpower": 6}
	var skill := SkillDef.new()
	skill.id = &"skl_arcanist_curse"
	assert_bool(_manager.try_apply_with_judgement(caster, target, skill,
			_statuses[&"DEBUFF_curse"], 3, _rng, 1)).is_true()
	# 回合 2/3/4 末各一跳（first_tick=2；units 只含受方——施方离场快照仍生效）
	_manager.end_of_round_tick(2, [target], _rng)
	_manager.end_of_round_tick(3, [target], _rng)
	_manager.end_of_round_tick(4, [target], _rng)
	assert_int(target.damage_log.size()).is_equal(3)
	for entry: int in target.damage_log:
		assert_int(entry).is_equal(8)
	assert_int(target.hp).is_equal(100 - 24)

func test_poison_dot_bypasses_mitigation() -> void:
	## 站位地格 DOT 免减免：毒沼固定 6 直扣（单位护甲/抗性字段不参与——直取 damage_log）
	var unit := FakeUnit.new()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_tile_poison"],
			StatusInstance.SourceKind.TILE, &"tile_poison_swamp", 0, 1, false)).is_true()
	_manager.end_of_round_tick(1, [unit], _rng)
	assert_int(unit.damage_log.size()).is_equal(1)
	assert_int(unit.damage_log[0]).is_equal(6)

func test_tile_dot_ticks_before_status_dot() -> void:
	## 结算顺序：站位地格 DOT 先跳、状态 DOT 后跳（damage_log 顺序断言）
	var unit := FakeUnit.new()
	_manager.apply(unit, _statuses[&"DEBUFF_tile_poison"],
			StatusInstance.SourceKind.TILE, &"tile_poison_swamp", 0, 1, false)
	_manager.apply(unit, _statuses[&"DEBUFF_curse"],
			StatusInstance.SourceKind.SKILL, &"skl_arcanist_curse", 3, 0, false)
	_manager.end_of_round_tick(1, [unit], _rng)
	assert_int(unit.damage_log.size()).is_equal(2)
	assert_int(unit.damage_log[0]).is_equal(6)
	assert_int(unit.damage_log[1]).is_equal(8)

func test_on_unit_moved_removes_standing_statuses() -> void:
	## 离格移除：on_leave_tile 类（毒沼）移除、常规回合流逝类（slow）保留
	var unit := FakeUnit.new()
	_manager.apply(unit, _statuses[&"DEBUFF_tile_poison"],
			StatusInstance.SourceKind.TILE, &"tile_poison_swamp", 0, 1, false)
	_manager.apply(unit, _statuses[&"DEBUFF_slow"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 2, 1, false)
	_manager.on_unit_moved(unit)
	var ids: Array[StringName] = _IdsOf(unit)
	assert_bool(ids.has(&"DEBUFF_tile_poison")).is_false()
	assert_bool(ids.has(&"DEBUFF_slow")).is_true()

func test_get_stat_mod_sums_same_key() -> void:
	## 修正求和：同 key 修正 Σ（slow −2 + sprint +2 = 0）
	var unit := FakeUnit.new()
	_manager.apply(unit, _statuses[&"DEBUFF_slow"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 2, 1, false)
	_manager.apply(unit, _statuses[&"BUFF_sprint"],
			StatusInstance.SourceKind.SKILL, &"skl_y", 0, 1, false)
	assert_float(_manager.get_stat_mod(unit, &"move_range")).is_equal(0.0)

func test_clear_all() -> void:
	## 清空：全部状态与行动标记归零
	var unit := FakeUnit.new()
	_manager.apply(unit, _statuses[&"DEBUFF_slow"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 2, 1, false)
	_manager.on_unit_turn_finished(unit)
	_manager.clear_all()
	assert_int(_manager.get_statuses(unit).size()).is_equal(0)

func test_end_of_round_tick_returns_dot_report() -> void:
	## 回合末结算返回 DOT 跳伤清单（盲审批 3 D-2）：逐跳一条 {&"unit",
	## &"damage"}——地格来源在先状态来源在后（与结算时序一致）、施加回合
	## 未到首跳回合的不计、无跳返回空数组
	var unit_a := FakeUnit.new()
	unit_a.id = &"unit_a"
	var unit_b := FakeUnit.new()
	unit_b.id = &"unit_b"
	# unit_a：毒沼（TILE 即时类，回合 1 末即跳 6）+ 诅咒（施加回合 0 → 回合 1 末跳 8）
	_manager.apply(unit_a, _statuses[&"DEBUFF_tile_poison"],
			StatusInstance.SourceKind.TILE, &"tile_poison_swamp", 0, 1, false)
	_manager.apply(unit_a, _statuses[&"DEBUFF_curse"],
			StatusInstance.SourceKind.SKILL, &"skl_arcanist_curse", 3, 0, false)
	# unit_b：诅咒当回合施加（回合 1）→ 回合 1 末不跳（施加回合末不递减口径）
	_manager.apply(unit_b, _statuses[&"DEBUFF_curse"],
			StatusInstance.SourceKind.SKILL, &"skl_arcanist_curse", 3, 1, false)
	var report: Array = _manager.end_of_round_tick(1, [unit_a, unit_b], _rng)
	assert_int(report.size()).is_equal(2)
	assert_object(report[0][&"unit"]).is_same(unit_a)
	assert_int(report[0][&"damage"]).is_equal(6)
	assert_object(report[1][&"unit"]).is_same(unit_a)
	assert_int(report[1][&"damage"]).is_equal(8)
	# unit_b 回合 1 无跳；回合 2 末起跳并进入清单（unit_a 毒沼在格常驻
	# 持续跳 + 诅咒双单位各一跳 = 3 条）
	var report2: Array = _manager.end_of_round_tick(2, [unit_a, unit_b], _rng)
	assert_int(report2.size()).is_equal(3)
	assert_object(report2[1][&"unit"]).is_same(unit_a)
	assert_int(report2[1][&"damage"]).is_equal(8)
	assert_object(report2[2][&"unit"]).is_same(unit_b)
	assert_int(report2[2][&"damage"]).is_equal(8)
	# 无任何 DOT 的回合：空清单
	var unit_c := FakeUnit.new()
	var report3: Array = _manager.end_of_round_tick(3, [unit_c], _rng)
	assert_int(report3.size()).is_equal(0)

func test_stack_limit_counts_by_polarity() -> void:
	## 叠层按极性计数（S2-2 拍板 A）：同 category 同 polarity 才互挤上限 2——
	## 草丛（BUFF）+减速（DEBUFF）占位后疾步（BUFF）仍可施加（BUFF 轨 1/2）；
	## 盾墙+草丛双 BUFF 满轨时减速（DEBUFF 轨）不受挤仍可施加
	var unit := FakeUnit.new()
	# 草丛位（BUFF STAT_MOD，本地假状态——本套件不载真表）+ 减速（DEBUFF STAT_MOD）
	var grass_buff := _MakeStatMod(&"BUFF_grass_like", {&"dodge": 0.15}, 2)
	grass_buff.polarity = StatusDef.Polarity.BUFF
	_Register(grass_buff)
	assert_bool(_manager.apply(unit, grass_buff,
			StatusInstance.SourceKind.TILE, &"tile_grass", 2, 1, false)).is_true()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_slow"],
			StatusInstance.SourceKind.SKILL, &"skl_x", 2, 1, false)).is_true()
	# 常规第二 BUFF（R1-8 后即时类不占位——用常规假 BUFF 占满 BUFF 轨 2/2）
	var second_buff := _MakeStatMod(&"BUFF_second_like", {&"hit": 0.05}, 2)
	second_buff.polarity = StatusDef.Polarity.BUFF
	_Register(second_buff)
	assert_bool(_manager.apply(unit, second_buff,
			StatusInstance.SourceKind.SKILL, &"skl_y2", 2, 1, false)).is_true()
	# 第三个常规 BUFF：BUFF 轨 2/2 满 → 拒收 + reason
	var third_buff := _MakeStatMod(&"BUFF_third_buff", {&"hit": 0.06}, 1)
	third_buff.polarity = StatusDef.Polarity.BUFF
	_Register(third_buff)
	assert_bool(_manager.apply(unit, third_buff,
			StatusInstance.SourceKind.SKILL, &"skl_z", 1, 1, false)).is_false()
	assert_str(String(_manager.last_reject_reason())).is_equal("stack_limit")
	# R1-8 拍板 A：常规 BUFF 轨满时即时类（疾步 duration 0）仍可施加——豁免计数
	assert_bool(_manager.apply(unit, _statuses[&"BUFF_sprint"],
			StatusInstance.SourceKind.SKILL, &"skl_y", 0, 1, false)).is_true()
	# 双 BUFF 满（草丛+疾步）时 DEBUFF 轨仍可施加（异向混计不再互挤）
	var exposed := _MakeStatMod(&"DEBUFF_exposed2", {&"dodge": -0.10}, 1)
	exposed.polarity = StatusDef.Polarity.DEBUFF
	_Register(exposed)
	assert_bool(_manager.apply(unit, exposed,
			StatusInstance.SourceKind.SKILL, &"skl_w", 1, 1, false)).is_true()

func test_equal_refresh_reanchors_first_tick() -> void:
	## 等值重施加重锚点（S2-3：> 改 >=）：同名等值 duration 重施加 →
	## first_tick_round 重起算（施加回合+1）且 control_locks 同门控刷新
	var unit := FakeUnit.new()
	# 2 回合诅咒施加于回合 1（first_tick=2、回合 1 末不递减）；回合 2 等值
	# 重施加 2 回合——旧口径（>）不刷新锚点；新口径（>=）重锚：
	# first_tick = 2+1 = 3（本回合末起重新计满 2 回合）
	_manager.apply(unit, _statuses[&"DEBUFF_curse"],
			StatusInstance.SourceKind.SKILL, &"skl_curse", 2, 1, false)
	_manager.end_of_round_tick(1, [unit], _rng)
	var instance: StatusInstance = _manager.get_statuses(unit)[0]
	assert_int(instance.remaining).is_equal(2)
	assert_int(instance.first_tick_round).is_equal(2)
	_manager.apply(unit, _statuses[&"DEBUFF_curse"],
			StatusInstance.SourceKind.SKILL, &"skl_curse", 2, 2, false)
	instance = _manager.get_statuses(unit)[0]
	assert_int(instance.remaining).is_equal(2)
	assert_int(instance.first_tick_round).is_equal(3)
	# 控制锁同门控：定身剩余 1 时等值重施加 1 → 锁窗刷新为 1（>= 门控内）
	var target := FakeUnit.new()
	_manager.apply(target, _statuses[&"DEBUFF_root"],
			StatusInstance.SourceKind.SKILL, &"skl_root", 1, 1, false)
	_manager.on_unit_turn_finished(target)
	var root_instance: StatusInstance = _manager.get_statuses(target)[0]
	assert_int(root_instance.control_locks).is_equal(0)
	_manager.apply(target, _statuses[&"DEBUFF_root"],
			StatusInstance.SourceKind.SKILL, &"skl_root", 1, 1, false)
	root_instance = _manager.get_statuses(target)[0]
	# 同名刷新：remaining 1 >= 1 → 锁窗重刷为 1（旧口径不刷新则为 0 态不可达——
	# 施加被同名分支吞并后锁保持旧值）
	assert_int(root_instance.control_locks).is_equal(1)

func test_allowed_sources_rejects_foreign_kind() -> void:
	## 来源类别拒收（S2-5）：allowed_sources = [TILE] 的毒沼状态经 SKILL 来源
	## 施加 → 拒收（reason source_not_allowed）；TILE 来源照常
	var unit := FakeUnit.new()
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_tile_poison"],
			StatusInstance.SourceKind.SKILL, &"skl_bad", 0, 1, false)).is_false()
	assert_str(String(_manager.last_reject_reason())).is_equal("source_not_allowed")
	assert_int(_manager.get_statuses(unit).size()).is_equal(0)
	assert_bool(_manager.apply(unit, _statuses[&"DEBUFF_tile_poison"],
			StatusInstance.SourceKind.TILE, &"tile_poison_swamp", 0, 1, false)).is_true()
