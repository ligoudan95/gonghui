## SkillExecutor 单元测试（M1 批 1）
## 覆盖：前置校验（射程/视线/资源/治疗仅未倒地/目标合法性）、攻击链（命中/
## 未中资源照扣/暴击 ×1.5/减免轨选对/倒地回调）、HEAL 免判定、TILE_SPAWN
## 预结算（敏捷×1.0）、STATUS_APPLY 两段门（命中才施加）、种族克制（对亡灵
## ×1.5）、高地面板乘算、AURA_3X3 怒吼逐格独立两段、自身增益直取。
## 技能/状态/地图/地格全部用 data/ 真实表；forced/forced_crit 注入保证确定性。
extends GdUnitTestSuite

## 真实数据路径
const CFG_PATH: String = "res://data/core/cfg_main.tres"
const MAP_PATH: String = "res://data/battle/maps/btm_m1_random_8x8.tres"
const TILE_DIR: String = "res://data/battle/tiles/"
const STATUS_DIR: String = "res://data/status/stats/"
const SKILL_DIR: String = "res://data/class/skills/"

## 套件级组件
var _cfg: CoreConfig
var _grid: BattleGrid
var _manager: StatusManager
var _executor: SkillExecutor
var _tiles: Dictionary = {}
var _statuses: Dictionary = {}
var _rng: RandomNumberGenerator

## 测试替身单位（完整鸭子契约，见 skill_executor.gd 头注释）
class FakeUnit:
	extends RefCounted
	var id: StringName = &"unit"
	var side: int = 0
	var alive: bool = true
	var grid_pos: Vector2i = Vector2i.ZERO
	var attrs: Dictionary = {}
	var weapon_bonus: int = 0
	var race_tag: StringName = &""
	var class_id: StringName = &""
	var hit: float = 0.80
	var dodge: float = 0.0
	var status_resist: float = 0.0
	var phys_pierce: int = 0
	var mag_pierce: int = 0
	var phys_resist: float = 0.0
	var mag_resist: float = 0.0
	var phys_armor: int = 0
	var mag_armor: int = 0
	var resource_mana: int = 100
	var resource_stamina: int = 100
	var hp: int = 100
	var downed_count: int = 0
	var healed_amount: int = 0
	var damage_taken: Array[int] = []

	func has_resource(kind: int, amount: int) -> bool:
		## 资源余量检查（法力/精力双轨；DEMO 敌方单池由批 2 单位侧实现）
		if kind == 1:
			return resource_mana >= amount
		if kind == 2:
			return resource_stamina >= amount
		return true

	func consume_resource(kind: int, amount: int) -> void:
		## 资源扣减
		if kind == 1:
			resource_mana -= amount
		elif kind == 2:
			resource_stamina -= amount

	func take_damage(amount: int) -> void:
		## 承伤（护甲/抗性已在减免轨结算，此处直扣）
		damage_taken.append(amount)
		hp -= amount
		if hp <= 0:
			alive = false

	func heal(amount: int) -> void:
		## 治疗
		healed_amount += amount
		hp += amount

	func on_downed() -> void:
		## 倒地回调
		downed_count += 1

func before() -> void:
	## 套件前置：加载真实数据、构建战场/状态管理器/执行器
	## 参数：无
	## 返回：无
	_cfg = load(CFG_PATH) as CoreConfig
	_tiles = {}
	for tile_id: StringName in [&"tile_normal", &"tile_obstacle", &"tile_grass",
			&"tile_highground", &"tile_poison_swamp", &"tile_trap"]:
		_tiles[tile_id] = load(TILE_DIR + String(tile_id) + ".tres")
	_statuses = {}
	for status_id: StringName in [&"DEBUFF_slow", &"DEBUFF_root", &"DEBUFF_curse",
			&"DEBUFF_bewitch", &"BUFF_shield_wall", &"BUFF_sprint",
			&"BUFF_tile_highground", &"DEBUFF_tile_poison"]:
		_statuses[status_id] = load(STATUS_DIR + String(status_id) + ".tres")
	_grid = BattleGrid.new()
	_grid.setup(load(MAP_PATH) as BattleMapDef, _LookupTile)
	_executor = SkillExecutor.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 42

func before_test() -> void:
	## 用例前置：重建战场与状态管理器（单格占位/施加状态为可变状态，逐用例隔离——
	## gdUnit before() 系套件级钩子，用例级须用 before_test）
	## 参数：无
	## 返回：无
	_grid = BattleGrid.new()
	_grid.setup(load(MAP_PATH) as BattleMapDef, _LookupTile)
	_manager = StatusManager.new()
	_manager.setup(_cfg, _LookupStatus)

func _LookupTile(tile_id: StringName) -> TileTypeDef:
	## 地格定义解析闭包
	## 参数 tile_id：地格 id
	## 返回：TileTypeDef（未登记返回 null）
	return _tiles.get(tile_id, null)

func _LookupStatus(status_id: StringName) -> StatusDef:
	## 状态定义解析闭包
	## 参数 status_id：状态 id
	## 返回：StatusDef（未登记返回 null）
	return _statuses.get(status_id, null)

func _LoadSkill(skill_id: StringName) -> SkillDef:
	## 加载真实技能表
	## 参数 skill_id：技能 id
	## 返回：SkillDef
	return load(SKILL_DIR + String(skill_id) + ".tres") as SkillDef

func _MakeUnit(id: StringName, side_value: int, pos: Vector2i) -> FakeUnit:
	## 构建并放置单位
	## 参数 id/side_value/pos：单位 id / 阵营 / 所在格
	## 返回：已放置单位
	var unit := FakeUnit.new()
	unit.id = id
	unit.side = side_value
	unit.grid_pos = pos
	_grid.place_unit(pos, unit)
	return unit

func _MakeWarrior(pos: Vector2i) -> FakeUnit:
	## 构建战士（17-C7 中值偏上 + 初始装备；命中按感 9 折算 −2%）
	var unit := _MakeUnit(&"warrior", 0, pos)
	unit.class_id = &"cls_warrior"
	unit.attrs = {&"strength": 16, &"constitution": 14, &"agility": 10,
			&"perception": 9, &"luck": 10}
	unit.weapon_bonus = 4
	unit.hit = DerivedStats.calc_hit(9, _cfg)
	unit.phys_pierce = DerivedStats.calc_phys_pierce(16, _cfg)
	unit.mag_pierce = DerivedStats.calc_mag_pierce(7, 10, &"cls_warrior", _cfg)
	return unit

func _MakeMage(pos: Vector2i) -> FakeUnit:
	## 构建法师（智 16 感 11；法穿 3）
	var unit := _MakeUnit(&"mage", 0, pos)
	unit.class_id = &"cls_mage"
	unit.attrs = {&"intelligence": 16, &"perception": 11, &"agility": 10, &"luck": 10}
	unit.weapon_bonus = 2
	unit.hit = DerivedStats.calc_hit(11, _cfg)
	unit.mag_pierce = DerivedStats.calc_mag_pierce(16, 8, &"cls_mage", _cfg)
	return unit

func _MakePriest(pos: Vector2i) -> FakeUnit:
	## 构建牧师（感 15 智 10；法穿 0——M2 智力口径）
	var unit := _MakeUnit(&"priest", 0, pos)
	unit.class_id = &"cls_priest"
	unit.attrs = {&"perception": 15, &"intelligence": 10, &"agility": 10, &"luck": 10}
	unit.weapon_bonus = 2
	unit.hit = DerivedStats.calc_hit(15, _cfg)
	unit.mag_pierce = DerivedStats.calc_mag_pierce(10, 13, &"cls_priest", _cfg)
	return unit

func _MakeTrash(pos: Vector2i) -> FakeUnit:
	## 构建杂兵（17 案 §3.8：全 9 / 甲 2 / 抗 0；闪避带 3-5% 取 4%）
	var unit := _MakeUnit(&"rat", 1, pos)
	unit.attrs = {&"strength": 9, &"agility": 9, &"constitution": 9,
			&"intelligence": 9, &"perception": 9, &"willpower": 9, &"luck": 9}
	unit.weapon_bonus = 3
	unit.phys_armor = 2
	unit.mag_armor = 2
	unit.dodge = 0.04
	return unit

func _Ctx(forced: int = -1, forced_crit: int = -1) -> Dictionary:
	## 构建执行上下文
	## 参数 forced/forced_crit：命中/暴击强制口
	## 返回：ctx 字典
	return {
		&"grid": _grid,
		&"status_manager": _manager,
		&"cfg": _cfg,
		&"rng": _rng,
		&"forced": forced,
		&"forced_crit": forced_crit,
		&"status_lookup": _LookupStatus,
	}

func test_power_strike_hits_and_damages() -> void:
	## 痛击命中链：毛 24.96 → 减免（甲 2 穿 3 抵净）25；命中/伤害明细入结果
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_bool(result.hit).is_true()
	assert_bool(result.crit).is_false()
	assert_float(result.raw_damage).is_equal_approx(24.96, 0.01)
	assert_int(result.damage).is_equal(25)
	assert_int(rat.damage_taken.size()).is_equal(1)
	assert_int(rat.damage_taken[0]).is_equal(25)
	assert_int(warrior.resource_stamina).is_equal(92)

func test_highground_tile_standing_multiplies_panel() -> void:
	## 高地站位 ×1.2（2026-09-24 八轮·M1 批 2 缺口补线）：apply_tile_standing
	## 站上高地 → 毛面板乘算层生效（普攻 (16+4)×1.0 = 20 → ×1.2 = 24.0）
	var warrior := _MakeWarrior(Vector2i(3, 6))
	assert_bool(_manager.apply_tile_standing(warrior,
			_tiles[&"tile_highground"] as TileTypeDef, 1)).is_true()
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_atk_warrior"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_float(result.raw_damage).is_equal_approx(24.0, 0.01)

func test_heal_rejects_enemy_target() -> void:
	## 治疗技阵营校验（盲审批 1-1：ALLY 技不可作用于敌方——原 ALLY 分支
	## 缺阵营校验，治疗可直接打给敌人）：点敌格失败 invalid_target、资源未扣
	var priest := _MakePriest(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(priest,
			_LoadSkill(&"skl_priest_heal"), rat.grid_pos, _Ctx(1, 1))
	assert_bool(result.success).is_false()
	assert_str(String(result.error)).is_equal("invalid_target")
	assert_str(String(result.trace[&"fail_reason"])).is_equal("invalid_target")
	assert_int(priest.resource_mana).is_equal(100)

func test_los_required_single_source() -> void:
	## 视线口径单源（批 C M5）：SkillExecutor.los_required 为唯一语义——
	## 射程 1 免视线、射程 >1 需视线（执行器前置校验与 UI 范围渲染/点选
	## 拦截同函数）
	assert_bool(SkillExecutor.los_required(_LoadSkill(&"skl_atk_warrior"))).is_false()
	assert_bool(SkillExecutor.los_required(_LoadSkill(&"skl_warrior_power_strike"))).is_false()
	assert_bool(SkillExecutor.los_required(_LoadSkill(&"skl_mage_fireball"))).is_true()
	assert_bool(SkillExecutor.los_required(null)).is_false()

func test_race_mult_single_source() -> void:
	## 种族克制乘算单源契约（批 A H1：UI 与执行链同函数，无键回 1.0——
	## 修正原执行侧「技能没带种族键时乘 0」脆弱语义）：
	## 惩击对亡灵 ×1.5 / 非亡灵 ×1.0；无种族键技（火球）打亡灵 ×1.0
	var smite: SkillDef = _LoadSkill(&"skl_priest_smite")
	assert_float(SkillExecutor.collect_race_mult(smite, &"undead")).is_equal_approx(1.5, 0.001)
	assert_float(SkillExecutor.collect_race_mult(smite, &"beast")).is_equal_approx(1.0, 0.001)
	assert_float(SkillExecutor.collect_race_mult(smite, &"")).is_equal_approx(1.0, 0.001)
	var fireball: SkillDef = _LoadSkill(&"skl_mage_fireball")
	assert_float(SkillExecutor.collect_race_mult(fireball, &"undead")).is_equal_approx(1.0, 0.001)
	# 执行链消费同一函数：亡灵目标惩击毛面板 = 基准 ×1.5（20.4 × 1.5 = 30.6）
	var priest := _MakePriest(Vector2i(3, 6))
	var undead := _MakeTrash(Vector2i(3, 5))
	undead.race_tag = &"undead"
	var result: SkillExecutor.ExecutionResult = _executor.execute(priest, smite,
			undead.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_float(result.raw_damage).is_equal_approx(30.6, 0.01)
	assert_float(float(result.trace[&"damage_chain"][&"race_mult"])).is_equal_approx(1.5, 0.001)

func test_trace_contract_hit_and_damage_chain() -> void:
	## trace 契约（2026-09-24 五轮反馈·战斗日志）：命中技执行后含标识键与
	## 命中链/伤害链全键，值与既有断言路径同源（raw 24.96 / final 25——
	## 不改变现有结算行为，纯增量字段）
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_str(String(result.trace[&"skill"])).is_equal("skl_warrior_power_strike")
	assert_str(String(result.trace[&"caster"])).is_equal("warrior")
	assert_str(String(result.trace[&"target"])).is_equal("rat")
	var hit_chain: Dictionary = result.trace[&"hit_chain"]
	for key: StringName in [&"base", &"mod", &"dodge", &"final", &"passed"]:
		assert_bool(hit_chain.has(key)) \
				.override_failure_message("hit_chain 缺键 %s" % key).is_true()
	assert_bool(hit_chain[&"passed"]).is_true()
	var damage_chain: Dictionary = result.trace[&"damage_chain"]
	for key: StringName in [&"raw", &"panel_mult", &"race_mult", &"resist", &"armor",
			&"pierce", &"mitigated", &"crit_chance", &"crit", &"final"]:
		assert_bool(damage_chain.has(key)) \
				.override_failure_message("damage_chain 缺键 %s" % key).is_true()
	assert_float(float(damage_chain[&"raw"])).is_equal_approx(24.96, 0.01)
	assert_int(int(damage_chain[&"final"])).is_equal(25)
	assert_bool(damage_chain[&"crit"]).is_false()

func test_trace_contract_fail_reason() -> void:
	## trace 失败契约：前置校验失败时 fail_reason 记录失败码（与 error 同源）
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 4))
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), rat.grid_pos, _Ctx(1, 1))
	assert_bool(result.success).is_false()
	assert_str(String(result.trace[&"fail_reason"])).is_equal("out_of_range")
	assert_bool(result.trace.has(&"hit_chain")).is_false()

func test_trace_contract_status_chain() -> void:
	## trace 状态链契约：命中复合技（寒冰锁链）statuses 数组逐条含
	## id/duration/applied 键
	var mage := _MakeMage(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 4))
	var result: SkillExecutor.ExecutionResult = _executor.execute(mage,
			_LoadSkill(&"skl_mage_frost_chain"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	var statuses: Array = result.trace[&"statuses"]
	assert_int(statuses.size()).is_equal(2)
	for entry: Dictionary in statuses:
		for key: StringName in [&"id", &"duration", &"applied"]:
			assert_bool(entry.has(key)) \
					.override_failure_message("statuses 条目缺键 %s" % key).is_true()

func test_power_strike_crit_multiplies() -> void:
	## 暴击：减免后 25 × 1.5 = 37.5 → round 38（暴击掷 forced_crit=1）
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), rat.grid_pos, _Ctx(1, 1))
	assert_bool(result.crit).is_true()
	assert_int(result.damage).is_equal(38)

func test_crit_mult_base_cfg_takes_effect() -> void:
	## 「改表即生效」冒烟（批 B M1：暴击倍率入 cfg_main.crit_mult_base——
	## 改 2.0 后暴击伤害翻倍 38→50，恢复归位）
	var original_mult: float = _cfg.crit_mult_base
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	_cfg.crit_mult_base = 2.0
	var boosted: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), rat.grid_pos, _Ctx(1, 1))
	_cfg.crit_mult_base = original_mult
	assert_bool(boosted.crit).is_true()
	assert_int(boosted.damage).is_equal(50)

func test_miss_consumes_resource_but_no_status() -> void:
	## 未中：伤害 0、无施加、资源照扣（寒冰锁链：法力 10）
	var mage := _MakeMage(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 4))
	var result: SkillExecutor.ExecutionResult = _executor.execute(mage,
			_LoadSkill(&"skl_mage_frost_chain"), rat.grid_pos, _Ctx(0, 0))
	assert_bool(result.success).is_true()
	assert_bool(result.hit).is_false()
	assert_int(result.damage).is_equal(0)
	assert_int(result.applied_statuses.size()).is_equal(0)
	assert_int(mage.resource_mana).is_equal(90)
	assert_int(rat.damage_taken.size()).is_equal(0)

func test_frost_chain_applies_status_on_hit() -> void:
	## 命中复合技：伤害 + 定身/减速独立两段（forced=1 全过）
	var mage := _MakeMage(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 4))
	var result: SkillExecutor.ExecutionResult = _executor.execute(mage,
			_LoadSkill(&"skl_mage_frost_chain"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.hit).is_true()
	# 毛面板 (16+2)×0.6 = 10.8 → 减免（甲 2 穿 3 抵净）round 11
	assert_int(result.damage).is_equal(11)
	assert_int(result.applied_statuses.size()).is_equal(2)
	var ids: Array[StringName] = []
	for instance: StatusInstance in _manager.get_statuses(rat):
		ids.append(instance.status_id)
	assert_bool(ids.has(&"DEBUFF_root")).is_true()
	assert_bool(ids.has(&"DEBUFF_slow")).is_true()

func test_out_of_range_fails_without_resource() -> void:
	## 射程校验：超出曼哈顿射程失败且资源未扣（痛击射程 1，目标距 2）
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 4))
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), rat.grid_pos, _Ctx(1, 1))
	assert_bool(result.success).is_false()
	assert_str(String(result.error)).is_equal("out_of_range")
	assert_int(warrior.resource_stamina).is_equal(100)

func test_line_of_sight_required_beyond_melee() -> void:
	## 视线校验：射程 > 1 被障碍阻断 → 失败（(0,2)→(5,2) 距 5，(2,2) 障碍拦截）
	var mage := _MakeMage(Vector2i(0, 2))
	var rat := _MakeTrash(Vector2i(5, 2))
	var result: SkillExecutor.ExecutionResult = _executor.execute(mage,
			_LoadSkill(&"skl_mage_fireball"), rat.grid_pos, _Ctx(1, 1))
	assert_bool(result.success).is_false()
	assert_str(String(result.error)).is_equal("no_line_of_sight")

func test_melee_range_one_skips_los() -> void:
	## 近战射程 1 免视线：贴脸攻击成功（(3,6)→(3,5) 相邻）
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_atk_warrior"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	# 普攻 (16×1.0+4)×1.0 = 20 → 减免（甲 2 穿 3 抵净）20
	assert_int(result.damage).is_equal(20)

func test_no_resource_fails() -> void:
	## 资源校验：精力不足 → 失败 no_resource
	var warrior := _MakeWarrior(Vector2i(3, 6))
	warrior.resource_stamina = 4
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), rat.grid_pos, _Ctx(1, 1))
	assert_bool(result.success).is_false()
	assert_str(String(result.error)).is_equal("no_resource")

func test_invalid_target_fails() -> void:
	## 目标校验：敌方单体技打射程内空格 / 打己方 → invalid_target（资源均未扣）
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var ally := _MakeUnit(&"ally", 0, Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), Vector2i(4, 6), _Ctx(1, 1))
	assert_bool(result.success).is_false()
	assert_str(String(result.error)).is_equal("invalid_target")
	assert_int(warrior.resource_stamina).is_equal(100)
	var result_two: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), ally.grid_pos, _Ctx(1, 1))
	assert_bool(result_two.success).is_false()
	assert_str(String(result_two.error)).is_equal("invalid_target")

func test_heal_alive_ally_only() -> void:
	## 治疗：感知 15×1.5+10 = 33；目标倒地 → target_downed；目标缺失 → invalid_target
	var priest := _MakePriest(Vector2i(3, 6))
	var ally := _MakeUnit(&"ally", 0, Vector2i(3, 5))
	ally.hp = 40
	var heal_skill: SkillDef = _LoadSkill(&"skl_priest_heal")
	var result: SkillExecutor.ExecutionResult = _executor.execute(priest, heal_skill,
			ally.grid_pos, _Ctx(1, 1))
	assert_bool(result.success).is_true()
	assert_int(result.heal).is_equal(33)
	assert_int(ally.healed_amount).is_equal(33)
	assert_int(ally.hp).is_equal(73)
	ally.alive = false
	var result_downed: SkillExecutor.ExecutionResult = _executor.execute(priest, heal_skill,
			ally.grid_pos, _Ctx(1, 1))
	assert_bool(result_downed.success).is_false()
	assert_str(String(result_downed.error)).is_equal("target_downed")
	var result_empty: SkillExecutor.ExecutionResult = _executor.execute(priest, heal_skill,
			Vector2i(3, 4), _Ctx(1, 1))
	assert_bool(result_empty.success).is_false()
	assert_str(String(result_empty.error)).is_equal("invalid_target")

func test_trap_spawn_presolved_damage() -> void:
	## 布置陷阱：预结算 = 敏捷×1.0（16）入格、免判定免减免（D7）；触发即消费由批 2 接线
	var ranger := _MakeUnit(&"ranger", 0, Vector2i(3, 6))
	ranger.attrs = {&"agility": 16, &"perception": 13}
	ranger.weapon_bonus = 3
	var result: SkillExecutor.ExecutionResult = _executor.execute(ranger,
			_LoadSkill(&"skl_ranger_set_trap"), Vector2i(3, 4), _Ctx(1, 1))
	assert_bool(result.success).is_true()
	assert_int(result.spawned_tile.x).is_equal(3)
	assert_int(result.spawned_tile.y).is_equal(4)
	assert_int(result.spawned_tile_damage).is_equal(16)
	var trap_data: Dictionary = _grid.dynamic_tile_at(Vector2i(3, 4))
	assert_str(String(trap_data[&"tile_id"])).is_equal("tile_trap")
	assert_int(trap_data[&"damage"]).is_equal(16)

func test_smite_race_bonus_vs_undead() -> void:
	## 圣光惩击种族克制：对亡灵（race_tag=undead）毛面板 ×1.5（COMBAT_MOD）→
	## 20.4×1.5 = 30.6 → 减免（甲 2 穿 0）round 28.6 = 29；对普通杂兵 = 18
	var priest := _MakePriest(Vector2i(3, 6))
	var undead := _MakeTrash(Vector2i(3, 4))
	undead.race_tag = &"undead"
	var result_undead: SkillExecutor.ExecutionResult = _executor.execute(priest,
			_LoadSkill(&"skl_priest_smite"), undead.grid_pos, _Ctx(1, 0))
	assert_float(result_undead.raw_damage).is_equal_approx(30.6, 0.01)
	assert_int(result_undead.damage).is_equal(29)
	var mortal := _MakeTrash(Vector2i(4, 5))
	var result_mortal: SkillExecutor.ExecutionResult = _executor.execute(priest,
			_LoadSkill(&"skl_priest_smite"), mortal.grid_pos, _Ctx(1, 0))
	assert_float(result_mortal.raw_damage).is_equal_approx(20.4, 0.01)
	assert_int(result_mortal.damage).is_equal(18)

func test_highground_panel_mult() -> void:
	## 高地乘算层：施放者站高地（BUFF_tile_highground damage_panel_mult=1.2）→
	## 火球毛面板 25.2×1.2 = 30.24 → 减免（甲 2 穿 3 抵净）30（毛面板阶段非最终后乘）
	var mage := _MakeMage(Vector2i(5, 3))
	_manager.apply(mage, _statuses[&"BUFF_tile_highground"],
			StatusInstance.SourceKind.TILE, &"tile_highground", 0, 1, false)
	var rat := _MakeTrash(Vector2i(3, 3))
	var result: SkillExecutor.ExecutionResult = _executor.execute(mage,
			_LoadSkill(&"skl_mage_fireball"), rat.grid_pos, _Ctx(1, 0))
	assert_float(result.raw_damage).is_equal_approx(30.24, 0.01)
	assert_int(result.damage).is_equal(30)

func test_backstab_crit_bonus() -> void:
	## 背刺暴击加成（COMBAT_MOD crit_bonus +10%）：敏 16 幸 13 → 暴击率 20%；
	## forced_crit=1 强制暴击 → 减免后 27 × 1.5 = 40.5 → round 41
	var rogue := _MakeUnit(&"rogue", 0, Vector2i(3, 6))
	rogue.class_id = &"cls_rogue"
	rogue.attrs = {&"agility": 16, &"luck": 13, &"strength": 10, &"perception": 11}
	rogue.weapon_bonus = 3
	rogue.hit = DerivedStats.calc_hit(11, _cfg)
	rogue.phys_pierce = DerivedStats.calc_phys_pierce(10, _cfg)
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(rogue,
			_LoadSkill(&"skl_rogue_backstab"), rat.grid_pos, _Ctx(1, 1))
	assert_bool(result.crit).is_true()
	# 毛面板 29.44 → 减免（甲 2 穿 0）27 → ×1.5 = 40.5 → 41
	assert_int(result.damage).is_equal(41)

func test_downed_callback_and_result() -> void:
	## 倒地：伤害 ≥ HP → on_downed 回调 + 结果倒地名单
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	rat.hp = 10
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(rat.alive).is_false()
	assert_int(rat.downed_count).is_equal(1)
	assert_int(result.downed_units.size()).is_equal(1)
	assert_str(String(result.downed_units[0])).is_equal("rat")

func test_shield_wall_self_buff() -> void:
	## 自身增益（SELF 目标）：盾墙直接施加（免判定）、物理护甲修正 +4
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_shield_wall"), warrior.grid_pos, _Ctx(1, 1))
	assert_bool(result.success).is_true()
	assert_float(_manager.get_stat_mod(warrior, &"armor_physical")).is_equal_approx(4.0, 0.0001)
	assert_int(warrior.resource_stamina).is_equal(94)

func test_roar_aura_applies_per_cell() -> void:
	## 怒吼 AURA_3X3：中心 (4,3) 逐格——区内两我方各独立两段（forced=1 施加成功）、
	## 区外我方与施放者同侧敌方不受影响
	var boss := _MakeUnit(&"boss", 1, Vector2i(4, 3))
	boss.attrs = {&"strength": 11}
	var ally_a := _MakeUnit(&"ally_a", 0, Vector2i(4, 2))
	var ally_b := _MakeUnit(&"ally_b", 0, Vector2i(4, 4))
	var ally_far := _MakeUnit(&"ally_far", 0, Vector2i(3, 0))
	var minion := _MakeUnit(&"minion", 1, Vector2i(3, 4))
	var result: SkillExecutor.ExecutionResult = _executor.execute(boss,
			_LoadSkill(&"skl_enemy_intimidating_roar"), boss.grid_pos, _Ctx(1, 1))
	assert_bool(result.success).is_true()
	assert_int(result.applied_statuses.size()).is_equal(2)
	assert_float(_manager.get_stat_mod(ally_a, &"move_range")).is_equal_approx(-2.0, 0.0001)
	assert_float(_manager.get_stat_mod(ally_b, &"move_range")).is_equal_approx(-2.0, 0.0001)
	assert_int(_manager.get_statuses(ally_far).size()).is_equal(0)
	assert_int(_manager.get_statuses(minion).size()).is_equal(0)
	assert_int(_manager.get_statuses(boss).size()).is_equal(0)
