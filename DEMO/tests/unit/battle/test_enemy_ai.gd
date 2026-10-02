## EnemyAI 单元测试（M1 批 2）
## 覆盖：目标四级链逐级构造（可击杀优先 / 追击记忆 / 血量最低 + 距离裁决），
## 技能选择（杂兵资源优先 / 耗尽转普攻 / 怒吼首次必用（决策即关闭义务）+
## 精力不足作废不顺延 / 之后穷追优先），移动裁决（射程内不移动 / 贴近目标）。
## 地图与敌我定义用 data/ 真实表；战场逐用例重建隔离布置。
extends GdUnitTestSuite

## 真实数据路径
const CFG_PATH: String = "res://data/core/cfg_main.tres"
const MAP_PATH: String = "res://data/battle/maps/btm_m1_random_8x8.tres"
const TILE_DIR: String = "res://data/battle/tiles/"
const ENEMY_DIR: String = "res://data/battle/enemies/"
const CLS_DIR: String = "res://data/class/classes/"
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级组件（重资源只载一次）
var _cfg: CoreConfig
var _skill_lookup: Callable
var _tiles: Dictionary = {}
var _rng: RandomNumberGenerator
## 用例级战场（逐用例重建——单位布置隔离）
var _grid: BattleGrid
## 用例级状态管理器（绑定用）
var _status_manager: StatusManager

func before() -> void:
	## 套件前置：加载 cfg_main、技能域 lookup、地格表
	## 参数：无
	## 返回：无
	_cfg = load(CFG_PATH) as CoreConfig
	var game_data: Node = load(GAME_DATA_SCRIPT).new()
	game_data.initialize_data()
	var skill_table: Dictionary = {}
	for skill_id: StringName in game_data.get_domain_ids(&"class/skills"):
		skill_table[skill_id] = game_data.get_record(skill_id)
	_skill_lookup = func(skill_id: StringName) -> Resource:
		return skill_table.get(skill_id, null)
	game_data.free()
	_tiles = {}
	for tile_id: StringName in [&"tile_normal", &"tile_obstacle", &"tile_grass",
			&"tile_highground", &"tile_poison_swamp", &"tile_trap"]:
		_tiles[tile_id] = load(TILE_DIR + String(tile_id) + ".tres")
	_rng = RandomNumberGenerator.new()
	_rng.seed = 42

func before_test() -> void:
	## 用例前置：重建战场与状态管理器（布置隔离）
	## 参数：无
	## 返回：无
	_grid = BattleGrid.new()
	_grid.setup(load(MAP_PATH) as BattleMapDef,
			func(tile_id: StringName) -> Resource:
				return _tiles.get(tile_id, null))
	_status_manager = StatusManager.new()
	_status_manager.setup(_cfg, func(_status_id: StringName) -> Resource:
				return null)

func _Bind(unit: BattleUnit) -> void:
	## 挂接战斗上下文（派生读取）
	## 参数 unit：单位
	## 返回：无
	unit.bind_battle(_cfg, _status_manager)

func _MakeAlly(unit_id: StringName, pos: Vector2i, hp: int) -> BattleUnit:
	## 构建并放置我方单位（战士职业、固定属性；hp 注入剩余生命）
	## 参数 unit_id/pos/hp：标识 / 所在格 / 当前生命
	## 返回：已放置单位
	var adv := AdventurerData.new()
	adv.unit_id = unit_id
	adv.class_id = &"cls_warrior"
	adv.attrs = {&"strength": 16, &"agility": 10, &"constitution": 14,
			&"intelligence": 7, &"perception": 9, &"willpower": 9, &"luck": 9}
	var unit := UnitBuilder.build_ally(adv, load(CLS_DIR + "cls_warrior.tres") as ClassDef, null)
	_Bind(unit)
	unit.current_hp = hp
	unit.grid_pos = pos
	_grid.place_unit(pos, unit)
	return unit

func _MakeEnemy(unit_id: StringName, enemy_file: String, pos: Vector2i,
		stamina: int = 100) -> BattleUnit:
	## 构建并放置敌方单位（精力注入——技能选择分支用）
	## 参数 unit_id/enemy_file/pos/stamina：标识 / 敌表文件 / 所在格 / 当前精力
	## 返回：已放置单位
	var unit := UnitBuilder.build_enemy(load(ENEMY_DIR + enemy_file) as EnemyDef, 0)
	_Bind(unit)
	unit.current_stamina = stamina
	unit.grid_pos = pos
	_grid.place_unit(pos, unit)
	return unit

func _Ctx() -> Dictionary:
	## 决策上下文（cfg + skill_lookup）
	## 参数：无
	## 返回：ctx 字典
	return {&"cfg": _cfg, &"skill_lookup": _skill_lookup}

## 用例级远程技包装 lookup（_RangedRat 装配时置——单远程鼠/用例）
var _ranged_lookup: Callable = Callable()

func _RangedRat(unit_id: StringName, pos: Vector2i, range: int) -> BattleUnit:
	## 构建远程技敌人（自定义射程注入——兜底用例的射程控制；包装 lookup
	## 覆写技能解析，普攻位同技保证被选中）
	## 参数 unit_id/pos/range：标识 / 所在格 / 注入射程
	## 返回：已放置单位
	var rat := _MakeEnemy(unit_id, "en_m1_mutant_rat.tres", pos)
	var ranged := SkillDef.new()
	ranged.id = &"skl_test_ranged_fb"
	ranged.range = range
	ranged.damage_type = SkillDef.DamageType.PHYSICAL
	ranged.target_shape = SkillDef.TargetShape.SINGLE
	_ranged_lookup = func(skill_id: StringName) -> Resource:
		if skill_id == &"skl_test_ranged_fb":
			return ranged
		return _skill_lookup.call(skill_id)
	rat.skill_ids = [&"skl_test_ranged_fb"]
	rat.base_attack_id = &"skl_test_ranged_fb"
	return rat

func _RangedCtx() -> Dictionary:
	## 远程技决策上下文（取 _RangedRat 装配的包装 lookup）
	## 参数：无
	## 返回：ctx 字典
	return {&"cfg": _cfg, &"skill_lookup": _ranged_lookup}

func _PlacedAllies() -> Array:
	## 收集场上全部存活我方单位（怒吼门槛用）
	## 参数：无
	## 返回：我方单位数组
	var allies: Array = []
	for y: int in _grid.size.y:
		for x: int in _grid.size.x:
			var unit: Object = _grid.get_unit_at(Vector2i(x, y))
			if unit != null and unit.alive and unit.side == SkillDef.SkillSide.ALLY:
				allies.append(unit)
	return allies

func test_tier1_killable_target_priority() -> void:
	## 四级链①可击杀：低血目标（期望伤害 ≥ 剩余 HP）优先于更近的高血目标
	var rat := _MakeEnemy(&"rat", "en_m1_mutant_rat.tres", Vector2i(3, 4))
	var far_wounded := _MakeAlly(&"far_wounded", Vector2i(1, 6), 3)
	var near_healthy := _MakeAlly(&"near_healthy", Vector2i(4, 5), 90)
	var action := EnemyAI.decide(rat, _grid, _PlacedAllies(), _Ctx())
	assert_object(action.target_unit).is_not_null()
	assert_str(String(action.target_unit.id)).is_equal("far_wounded")
	assert_int(action.attack_cell.x).is_equal(1)
	assert_int(action.attack_cell.y).is_equal(6)

func test_tier2_memory_persistence() -> void:
	## 四级链②追击记忆：首择目标即使后续不再是最低血仍被追击
	var rat := _MakeEnemy(&"rat", "en_m1_mutant_rat.tres", Vector2i(3, 4))
	var target_a := _MakeAlly(&"target_a", Vector2i(3, 6), 20)
	var target_b := _MakeAlly(&"target_b", Vector2i(2, 6), 80)
	var first := EnemyAI.decide(rat, _grid, [target_a, target_b], _Ctx())
	assert_str(String(first.target_unit.id)).is_equal("target_a")
	# 局势反转：A 满血、B 中度伤（低于 A 但不可击杀）——无记忆应转 B（血量最低），
	# 有记忆仍追 A
	target_a.current_hp = 90
	target_b.current_hp = 50
	var second := EnemyAI.decide(rat, _grid, [target_a, target_b], _Ctx())
	assert_str(String(second.target_unit.id)).is_equal("target_a")

func test_tier3_lowest_hp_tie_by_distance() -> void:
	## 四级链③血量最低（持平按距离最近）：同血取近者
	var rat := _MakeEnemy(&"rat", "en_m1_mutant_rat.tres", Vector2i(3, 4))
	_MakeAlly(&"far", Vector2i(0, 6), 50)
	_MakeAlly(&"near", Vector2i(3, 6), 50)
	var action := EnemyAI.decide(rat, _grid, _PlacedAllies(), _Ctx())
	assert_str(String(action.target_unit.id)).is_equal("near")

func test_movement_when_out_of_range() -> void:
	## 移动裁决：目标在射程外 → 移动至距目标曼哈顿最近格且随后可攻击（贴近）
	var rat := _MakeEnemy(&"rat", "en_m1_mutant_rat.tres", Vector2i(3, 6))
	var target := _MakeAlly(&"target", Vector2i(3, 4), 90)
	var action := EnemyAI.decide(rat, _grid, [target], _Ctx())
	assert_int(action.move_dest.x).is_not_equal(-1)
	var after: int = absi(action.move_dest.x - target.grid_pos.x) \
			+ absi(action.move_dest.y - target.grid_pos.y)
	assert_int(after).is_equal(1)
	assert_int(action.attack_cell.x).is_equal(3)
	assert_int(action.attack_cell.y).is_equal(4)

func test_no_move_when_in_range() -> void:
	## 移动裁决：已在射程内不移动，直接攻击
	var rat := _MakeEnemy(&"rat", "en_m1_mutant_rat.tres", Vector2i(3, 4))
	var target := _MakeAlly(&"target", Vector2i(3, 5), 90)
	var action := EnemyAI.decide(rat, _grid, [target], _Ctx())
	assert_int(action.move_dest.x).is_equal(-1)
	assert_int(action.attack_cell.x).is_equal(3)
	assert_int(action.attack_cell.y).is_equal(5)

func test_trash_skill_when_affordable() -> void:
	## 杂兵技能：精力足够（12 ≥ 耗 6）→ 主动技（疫病撕咬）
	var rat := _MakeEnemy(&"rat", "en_m1_mutant_rat.tres", Vector2i(3, 4), 12)
	var target := _MakeAlly(&"target", Vector2i(3, 5), 90)
	var action := EnemyAI.decide(rat, _grid, [target], _Ctx())
	assert_str(String(action.skill_id)).is_equal("skl_enemy_plague_bite")

func test_trash_common_attack_when_exhausted() -> void:
	## 杂兵技能：精力耗尽（5 < 耗 6）→ 通用普攻
	var rat := _MakeEnemy(&"rat", "en_m1_mutant_rat.tres", Vector2i(3, 4), 5)
	var target := _MakeAlly(&"target", Vector2i(3, 5), 90)
	var action := EnemyAI.decide(rat, _grid, [target], _Ctx())
	assert_str(String(action.skill_id)).is_equal("skl_atk_enemy_common")

func test_elite_roar_first_use_when_condition_met() -> void:
	## 精英怒吼（17-C16 P1）：3×3 内我方 ≥2 且精力 ≥12 → 首次必用
	## （决策即置 roar_used 关闭义务——每场一次；怒吼无目标无移动）
	var elite := _MakeEnemy(&"boss", "en_m1_elite_boss.tres", Vector2i(3, 5), 32)
	_MakeAlly(&"a1", Vector2i(3, 4), 90)
	_MakeAlly(&"a2", Vector2i(4, 5), 90)
	var action := EnemyAI.decide(elite, _grid, _PlacedAllies(), _Ctx())
	assert_str(String(action.skill_id)).is_equal("skl_enemy_intimidating_roar")
	assert_object(action.target_unit).is_null()
	assert_int(action.move_dest.x).is_equal(-1)
	assert_bool(elite.ai_context.get(&"roar_used", false)).is_true()

func test_elite_roar_voided_when_stamina_short() -> void:
	## 怒吼义务作废：条件首次满足但精力 <12 → 义务关闭不顺延（精力回满也不再吼）
	var elite := _MakeEnemy(&"boss", "en_m1_elite_boss.tres", Vector2i(3, 5), 5)
	_MakeAlly(&"a1", Vector2i(3, 4), 90)
	_MakeAlly(&"a2", Vector2i(4, 5), 90)
	var voided := EnemyAI.decide(elite, _grid, _PlacedAllies(), _Ctx())
	# 精力 5 < 穷追耗 8 → 通用普攻；roar_used 已置（义务作废）
	assert_str(String(voided.skill_id)).is_equal("skl_atk_enemy_common")
	assert_bool(elite.ai_context.get(&"roar_used", false)).is_true()
	elite.current_stamina = 32
	var later := EnemyAI.decide(elite, _grid, _PlacedAllies(), _Ctx())
	assert_str(String(later.skill_id)).is_not_equal("skl_enemy_intimidating_roar")

func test_elite_relentless_priority_after_roar() -> void:
	## 精英技能序：roar_used 后穷追猛打优先（精力 ≥8）；精力不足转普攻
	var elite := _MakeEnemy(&"boss", "en_m1_elite_boss.tres", Vector2i(3, 5), 20)
	elite.ai_context[&"roar_used"] = true
	var target := _MakeAlly(&"target", Vector2i(3, 6), 90)
	var action := EnemyAI.decide(elite, _grid, [target], _Ctx())
	assert_str(String(action.skill_id)).is_equal("skl_enemy_relentless")
	elite.current_stamina = 5
	var exhausted := EnemyAI.decide(elite, _grid, [target], _Ctx())
	assert_str(String(exhausted.skill_id)).is_equal("skl_atk_enemy_common")

func test_ranged_attack_respects_line_of_sight() -> void:
	## 攻击位候选 LOS 过滤（盲审批 3 D-4）：远程技（射程 >1 需视线——与执行器
	## SkillExecutor.los_required 同口径）原位射程内但被障碍挡视线 → 不原地
	## 攻击，移动到视线通畅格再攻击（不再白耗一回合吃 no_line_of_sight）
	var rat := _MakeEnemy(&"archer", "en_m1_mutant_rat.tres", Vector2i(0, 2))
	var target := _MakeAlly(&"los_target", Vector2i(4, 2), 90)
	# 前提锚点：(0,2)→(4,2) 同行水平视线必经障碍 (2,2) → 阻断
	assert_bool(_grid.has_line_of_sight(rat.grid_pos, target.grid_pos)).is_false()
	# 假远程技射程 5（射程内但视线断）；包装 lookup 注入
	var ranged := SkillDef.new()
	ranged.id = &"skl_test_ranged"
	ranged.range = 5
	ranged.damage_type = SkillDef.DamageType.PHYSICAL
	ranged.target_shape = SkillDef.TargetShape.SINGLE
	var wrapped_lookup: Callable = func(skill_id: StringName) -> Resource:
		if skill_id == &"skl_test_ranged":
			return ranged
		return _skill_lookup.call(skill_id)
	rat.skill_ids = [&"skl_test_ranged"]
	rat.base_attack_id = &"skl_test_ranged"
	var action := EnemyAI.decide(rat, _grid, [target],
			{&"cfg": _cfg, &"skill_lookup": wrapped_lookup})
	# 移动目的地视线通畅 + 随后可攻击目标
	assert_vector(action.move_dest).is_not_equal(EnemyAI.NO_CELL)
	assert_bool(_grid.has_line_of_sight(action.move_dest, target.grid_pos)).is_true()
	assert_vector(action.attack_cell).is_equal(target.grid_pos)

func test_ranged_los_matches_executor_rule() -> void:
	## D-4 口径锚点：AI 消费的 LOS 需求判定与执行器单源（los_required）一致
	## ——近战射程 1 免视线、远程 >1 需视线（测试侧用真表技能双锚定）
	var melee: SkillDef = _skill_lookup.call(&"skl_atk_enemy_common") as SkillDef
	assert_int(melee.range).is_equal(1)
	assert_bool(SkillExecutor.los_required(melee)).is_false()
	var fireball: SkillDef = _skill_lookup.call(&"skl_mage_fireball") as SkillDef
	assert_int(fireball.range).is_greater(1)
	assert_bool(SkillExecutor.los_required(fireball)).is_true()

func test_fallback_attack_adjacent_when_primary_walled() -> void:
	## 移动裁决兜底 2（M2 试玩修复·场景①）：追击目标被友军围死（存活单位
	## 互为障碍不可入、无更近可达格）→ 不干站，原地攻击旁边射程内其他目标
	## （追击记忆随实际攻击对象更新——下回合四级链序直达）
	var rat := _MakeEnemy(&"rat", "en_m1_mutant_rat.tres", Vector2i(4, 6))
	var primary := _MakeAlly(&"primary", Vector2i(4, 4), 90)
	_MakeAlly(&"wall_a", Vector2i(4, 5), 90)
	_MakeAlly(&"wall_b", Vector2i(3, 4), 90)
	_MakeAlly(&"wall_c", Vector2i(5, 4), 90)
	var bystander := _MakeAlly(&"bystander", Vector2i(3, 6), 60)
	rat.ai_context[&"last_target_id"] = primary.id
	var action := EnemyAI.decide(rat, _grid, _PlacedAllies(), _Ctx())
	assert_str(String(action.skill_id)).is_equal("skl_enemy_plague_bite")
	assert_str(String(action.target_unit.id)).is_equal("bystander")
	assert_vector(action.move_dest).is_equal(EnemyAI.NO_CELL)
	assert_vector(action.attack_cell).is_equal(Vector2i(3, 6))
	assert_str(String(rat.ai_context.get(&"last_target_id", &""))) \
			.is_equal("bystander")

func test_fallback_sidestep_restores_los() -> void:
	## 移动裁决兜底 1（M2 试玩修复·场景②）：目标射程内但障碍断 LOS，且无
	## 严格更近格（更近且有视线的格被友军占位）→ 等距侧移一格恢复视线并
	## 攻击（白耗移动力换回攻击资格，优于干站）
	var rat := _RangedRat(&"archer", Vector2i(0, 2), 5)
	var target := _MakeAlly(&"los_target", Vector2i(4, 2), 50)
	_MakeAlly(&"wall_x", Vector2i(2, 1), 90)
	_MakeAlly(&"wall_y", Vector2i(3, 1), 90)
	# 前提锚点：射程内（4 ≤ 5）但视线必经障碍 (2,2) 阻断；更近格 (2,1)/(3,1)
	# 已被友军占位不可入
	assert_bool(_grid.has_line_of_sight(rat.grid_pos, target.grid_pos)).is_false()
	var reachable: Array[Vector2i] = _grid.find_reachable(rat, rat.move_final())
	assert_bool(reachable.has(Vector2i(2, 1))).is_false()
	assert_bool(reachable.has(Vector2i(3, 1))).is_false()
	var action := EnemyAI.decide(rat, _grid, _PlacedAllies(), _RangedCtx())
	assert_str(String(action.skill_id)).is_equal("skl_test_ranged_fb")
	assert_str(String(action.target_unit.id)).is_equal("los_target")
	# 等距侧移（(1,1)：与目标等距 4、视线通——reachable 序首个合格等距格）
	assert_vector(action.move_dest).is_equal(Vector2i(1, 1))
	assert_bool(_grid.has_line_of_sight(action.move_dest, target.grid_pos)).is_true()
	assert_vector(action.attack_cell).is_equal(Vector2i(4, 2))

func test_true_idle_when_no_attackable_target() -> void:
	## 移动裁决兜底 3（M2 试玩修复·场景③）：锁定目标不可达（口袋地形零
	## 可达格）且无任何射程内视线通目标 → 真待机（无移动无攻击——合理
	## 终态保持，既有行为回归锚）
	var rat := _RangedRat(&"archer", Vector2i(2, 3), 5)
	var target := _MakeAlly(&"far", Vector2i(6, 3), 90)
	# 前提锚点：(2,3) 四邻皆障碍 → 零可达格；目标射程内（4 ≤ 5）但视线
	# 必经障碍 (3,3) 阻断
	assert_int(_grid.find_reachable(rat, rat.move_final()).size()).is_equal(0)
	assert_bool(_grid.has_line_of_sight(rat.grid_pos, target.grid_pos)).is_false()
	var action := EnemyAI.decide(rat, _grid, [target], _RangedCtx())
	assert_str(String(action.skill_id)).is_equal("skl_test_ranged_fb")
	assert_str(String(action.target_unit.id)).is_equal("far")
	assert_vector(action.move_dest).is_equal(EnemyAI.NO_CELL)
	assert_vector(action.attack_cell).is_equal(EnemyAI.NO_CELL)

func test_fallback4_forces_attack_when_closer_cell_exists() -> void:
	## 移动裁决兜底 4（M3 试玩修复·用户场景复现）：主目标（追击记忆·远处）
	## 存在严格更近可达格——此前版本走到「移动+待机」直接返回，**跳过换打
	## 检查**（兜底 2 仅在完全不可达时触发），贴身可及目标被无视干站着——
	## 用户观察「有能攻击的人却不去攻击」的根因。修复后：移动后位置无可及
	## 目标时，放弃移动原地攻击当前位置可及目标（追击记忆随实际攻击对象更新）
	var rat := _MakeEnemy(&"rat", "en_m1_mutant_rat.tres", Vector2i(3, 4), 5)
	var primary := _MakeAlly(&"primary", Vector2i(0, 0), 90)
	var adjacent := _MakeAlly(&"adjacent", Vector2i(3, 5), 90)
	rat.ai_context[&"last_target_id"] = primary.id
	# 前提锚点：主目标 (0,0) 西北侧——西向接近路被固有障碍 (2,4)/(3,3)/(1,3)
	# 封死（可达集全在东侧），range 1 攻击位不可入；但存在严格更近可达格
	# (4,1)（距主目标 5 > range 1——移动后仍不可及，旧版在此「移动+待机」）
	_MakeAlly(&"wall", Vector2i(1, 0), 90)
	var reachable: Array[Vector2i] = _grid.find_reachable(rat, rat.move_final())
	assert_bool(reachable.has(Vector2i(4, 1))).is_true()
	var action := EnemyAI.decide(rat, _grid, _PlacedAllies(), _Ctx())
	# 精力 5 → 普攻（射程 1）；贴身 adjacent 当前位置可及 → 原地攻击不移动
	assert_str(String(action.skill_id)).is_equal("skl_atk_enemy_common")
	assert_str(String(action.target_unit.id)).is_equal("adjacent")
	assert_vector(action.move_dest).is_equal(EnemyAI.NO_CELL)
	assert_vector(action.attack_cell).is_equal(Vector2i(3, 5))
	assert_str(String(rat.ai_context.get(&"last_target_id", &""))) \
			.is_equal("adjacent")

func test_fallback4_ranged_variant_same_contract() -> void:
	## 兜底 4·远程变体：同构契约（射程 2 远程技 + 主目标远处有更近格）——
	## 移动后位置（(1,2) 视角）无可及目标 → 原地攻击贴身目标（射程内 + 相邻
	## LOS 通），不绕开可打目标纯走位
	var rat := _RangedRat(&"archer", Vector2i(3, 4), 2)
	var primary := _MakeAlly(&"primary", Vector2i(0, 0), 90)
	var adjacent := _MakeAlly(&"adjacent", Vector2i(3, 5), 90)
	rat.ai_context[&"last_target_id"] = primary.id
	var action := EnemyAI.decide(rat, _grid, _PlacedAllies(), _RangedCtx())
	assert_str(String(action.skill_id)).is_equal("skl_test_ranged_fb")
	assert_str(String(action.target_unit.id)).is_equal("adjacent")
	assert_vector(action.move_dest).is_equal(EnemyAI.NO_CELL)
	assert_vector(action.attack_cell).is_equal(Vector2i(3, 5))

func test_attackable_at_filters_by_view_cell() -> void:
	## _AttackableAt 单源单测（兜底 2/4 共用）：指定视角格过滤「射程内且视线
	## 通（近战免）」候选并按四级链序取；视角格无可及目标返 null
	var rat := _MakeEnemy(&"rat", "en_m1_mutant_rat.tres", Vector2i(3, 4))
	var near := _MakeAlly(&"near", Vector2i(3, 5), 90)
	var far := _MakeAlly(&"far", Vector2i(0, 0), 90)
	var melee: SkillDef = _skill_lookup.call(&"skl_atk_enemy_common") as SkillDef
	# 当前位置视角：near 距 1 可及（四级链序单选）
	var picked: Object = EnemyAI._AttackableAt(rat, rat.grid_pos, melee,
			[near, far], _grid, _cfg, null)
	assert_str(String(picked.id)).is_equal("near")
	# 远视角格 (5,4)：near 距 3 / far 距 9 均超射程 → null
	assert_object(EnemyAI._AttackableAt(rat, Vector2i(5, 4), melee,
			[near, far], _grid, _cfg, null)).is_null()

func test_expected_damage_uses_standing_panel_mult() -> void:
	## AI 期望伤害消费站位面板层（S3-06）：ctx 注入 status_manager 后——
	## 敌站高地（面板 ×1.2）期望伤害高于平地；缺省（null）回退 1.0
	var rat := _MakeEnemy(&"rat", "en_m1_mutant_rat.tres", Vector2i(3, 4))
	var target := _MakeAlly(&"target", Vector2i(3, 5), 90)
	var skill: SkillDef = _skill_lookup.call(&"skl_atk_enemy_common") as SkillDef
	# 平地基线（ctx 无 status_manager——回退 1.0）
	var baseline: float = EnemyAI._ExpectedDamage(rat, skill, target, _cfg, null)
	# 高地：独立建带状态 lookup 的管理器（套件 _status_manager 的 lookup 为
	# 空解析，站格状态施加需要真状态表）施加 BUFF_tile_highground
	var highground_tile: TileTypeDef = _tiles.get(&"tile_highground", null) as TileTypeDef
	assert_object(highground_tile).is_not_null()
	var hg_status: StatusDef = load("res://data/status/stats/BUFF_tile_highground.tres") as StatusDef
	assert_object(hg_status).is_not_null()
	var sm := StatusManager.new()
	sm.setup(_cfg, func(status_id: StringName) -> Resource:
		if status_id == hg_status.id:
			return hg_status
		return null)
	assert_bool(sm.apply_tile_standing(rat, highground_tile, 1)).is_true()
	var boosted: float = EnemyAI._ExpectedDamage(rat, skill, target, _cfg, sm)
	assert_float(boosted).is_greater(baseline)

func test_expected_damage_applies_race_mult() -> void:
	## 种族克制镜像对齐（A-14）：AI 期望伤害经 collect_race_mult 单源——
	## 对亡灵目标（技能带种族键）期望 > 同面板人形目标
	var rat := _MakeEnemy(&"rat", "en_m1_mutant_rat.tres", Vector2i(3, 4))
	var humanoid := _MakeAlly(&"human", Vector2i(3, 5), 90)
	var undead := _MakeAlly(&"undead", Vector2i(3, 6), 90)
	undead.race_tag = &"undead"
	# 手造带种族克制键的技能（×1.5——同圣光惩击口径）
	var smite := SkillDef.new()
	smite.id = &"skl_test_smite"
	smite.range = 1
	smite.damage_type = SkillDef.DamageType.MAGICAL
	smite.target_shape = SkillDef.TargetShape.SINGLE
	smite.power_coefficient = 1.0
	var typed_weights: Dictionary[StringName, float] = {&"intelligence": 1.0}
	smite.attr_weights = typed_weights
	var effect := SkillEffect.new()
	effect.effect_kind = SkillEffect.EffectKind.COMBAT_MOD
	effect.key = ModKeys.RACE_UNDEAD_MULT
	effect.value = 1.5
	smite.effects = [effect]
	var vs_undead: float = EnemyAI._ExpectedDamage(rat, smite, undead, _cfg)
	var vs_humanoid: float = EnemyAI._ExpectedDamage(rat, smite, humanoid, _cfg)
	assert_float(vs_undead).is_greater(vs_humanoid)
	# 比值带（减免轨减法项使精确比偏离 1.5——带内断言）
	assert_float(vs_undead / maxi(0.0001, vs_humanoid)).is_between(1.4, 1.7)

## 10×10 lair 图路径（兜底 2.5 用例——套件默认 8×8，用例内切换）
const LAIR_MAP_PATH: String = "res://data/battle/maps/btm_m1_lair_10x10.tres"

func _SetupLairGrid() -> void:
	## 用例内切换 10×10 巢穴图（用户几何死锁复现——凹帽障碍 (3,4)(4,3)(2,5)
	## 使 (3,3) 南向截断、曼哈顿贪心不可达严格更近格；套件默认 8×8 不动）
	## 参数：无
	## 返回：无
	_grid = BattleGrid.new()
	_grid.setup(load(LAIR_MAP_PATH) as BattleMapDef,
			func(tile_id: StringName) -> Resource:
				return _tiles.get(tile_id, null))

func _PlaceUserGeometry() -> Array:
	## 摆出用户现场几何（ai_repro3 复现）：我方默认出生排 (3,9)-(6,9)、
	## 敌列 (3,1)(3,2)(3,3)——三敌互为障碍连锁冻结蓝本
	## 参数：无
	## 返回：我方单位数组（candidates）
	var allies: Array = []
	for index: int in range(4):
		allies.append(_MakeAlly(StringName("ua_%d" % index),
				Vector2i(3 + index, 9), 90))
	_MakeEnemy(&"ur_1", "en_m1_mutant_rat.tres", Vector2i(3, 1))
	_MakeEnemy(&"ur_2", "en_m1_mutant_rat.tres", Vector2i(3, 2))
	_MakeEnemy(&"ur_3", "en_m1_mutant_rat.tres", Vector2i(3, 3))
	return allies

func test_fallback25_concave_deadlock_routes_globally() -> void:
	## 兜底 2.5（M5 后用户几何死锁修复）：凹帽障碍前「严格更近」（曼哈顿）
	## 可达格不存在（绕行真实距离 11 > 移动力 4）且兜底 1/2 双空——修复前
	## 真待机稳态冻结；修复后沿全场距离场严格降格绕行（(3,3)→(0,4)：全局
	## 11→7，西侧走廊），移动后不在射程不攻击
	_SetupLairGrid()
	var allies: Array = _PlaceUserGeometry()
	var rat: BattleUnit = _grid.get_unit_at(Vector2i(3, 3))
	# 前提锚点：贪心死锁成立——可达格 5 个且到锁定目标 (3,9) 曼哈顿全部 ≥6
	##（当前距离 6，无严格更近）
	var reachable: Array[Vector2i] = _grid.find_reachable(rat, rat.move_final())
	assert_int(reachable.size()).is_equal(5)
	for cell: Vector2i in reachable:
		assert_int(BattleGrid.manhattan(cell, Vector2i(3, 9))) \
				.override_failure_message("前提锚点破坏：可达格存在严格更近 %s" % str(cell)) \
				.is_greater_equal(6)
	var action := EnemyAI.decide(rat, _grid, allies, _Ctx())
	assert_vector(action.move_dest) \
			.override_failure_message("凹帽死锁应产出绕行移动而非待机") \
			.is_equal(Vector2i(0, 4))
	# 全局距离严格降（距离场单源断言——11 → 7），且非贪心方向（曼哈顿不减）
	var field: Dictionary = _grid.distance_field_to_reach(rat, Vector2i(3, 9), 1)
	assert_int(field.get(Vector2i(3, 3), -1)).is_equal(11)
	assert_int(field.get(action.move_dest, -1)).is_equal(7)
	assert_vector(action.attack_cell).is_equal(EnemyAI.NO_CELL)

func test_fallback25_column_queue_all_move() -> void:
	## 兜底 2.5 列队堵塞（用户几何）：三敌一列互为障碍——前位 (3,3) 走西廊
	## (0,4)、中位 (3,2) 与后位 (3,1) 距离场含前位占位自然分流东廊 (5,4)(5,3)
	## ——三敌全部产出非空移动决策（修复前连锁冻结全体空决策）
	_SetupLairGrid()
	var allies: Array = _PlaceUserGeometry()
	var spawns: Dictionary = {
		Vector2i(3, 3): Vector2i(0, 4),
		Vector2i(3, 2): Vector2i(5, 4),
		Vector2i(3, 1): Vector2i(5, 3),
	}
	for spawn: Vector2i in spawns:
		var rat: BattleUnit = _grid.get_unit_at(spawn)
		var action := EnemyAI.decide(rat, _grid, allies, _Ctx())
		assert_vector(action.move_dest) \
				.override_failure_message("列队敌 %s 应分流绕行非待机" % str(spawn)) \
				.is_equal(spawns[spawn])

func test_fallback25_true_idle_when_target_fully_enclosed() -> void:
	## 兜底 2.5 真无路语义保留（兜底 3 回归锚）：锁定目标被完全围死（射程格
	## 集全被占 → 距离场空）且贪心死锁——兜底 2.5 无候选落真待机（无移动
	## 无攻击），不产出幻影绕行
	_SetupLairGrid()
	var target := _MakeAlly(&"walled", Vector2i(3, 9), 90)
	# 围位（敌方单位占位——占位对称，敌我皆障）：射程 1 格集 (2,9)(4,9)(3,8)
	## 全占 + (3,10) 越界 → 距离场空
	_MakeEnemy(&"w1", "en_m1_mutant_rat.tres", Vector2i(2, 9))
	_MakeEnemy(&"w2", "en_m1_mutant_rat.tres", Vector2i(4, 9))
	_MakeEnemy(&"w3", "en_m1_mutant_rat.tres", Vector2i(3, 8))
	var rat := _MakeEnemy(&"rat", "en_m1_mutant_rat.tres", Vector2i(3, 3))
	assert_bool(_grid.distance_field_to_reach(rat, target.grid_pos, 1).is_empty()) \
			.override_failure_message("前提锚点破坏：目标未围死").is_true()
	var action := EnemyAI.decide(rat, _grid, [target], _Ctx())
	assert_str(String(action.skill_id)).is_equal("skl_enemy_plague_bite")
	assert_str(String(action.target_unit.id)).is_equal("walled")
	assert_vector(action.move_dest).is_equal(EnemyAI.NO_CELL)
	assert_vector(action.attack_cell).is_equal(EnemyAI.NO_CELL)

func test_fallback25_no_oscillation_monotonic_field_descent() -> void:
	## 兜底 2.5 防振荡：连续多轮决策+移位——每步全场距离严格降（单调收敛，
	## 无来回震荡），有限轮内抵达攻击位（距离场 0 值）
	_SetupLairGrid()
	var allies: Array = _PlaceUserGeometry()
	var grid_enemy: BattleUnit = _grid.get_unit_at(Vector2i(3, 1))
	_grid.remove_unit(grid_enemy.grid_pos)
	var queue_mid: BattleUnit = _grid.get_unit_at(Vector2i(3, 2))
	_grid.remove_unit(queue_mid.grid_pos)
	# 仅保留列尾敌 (3,3)（单敌推进——我方满血静立，追击记忆锁 (3,9)）
	var rat: BattleUnit = _grid.get_unit_at(Vector2i(3, 3))
	var moved_count: int = 0
	var last_fd: int = 11
	for round_index: int in range(6):
		var field: Dictionary = _grid.distance_field_to_reach(rat,
				Vector2i(3, 9), 1)
		var action := EnemyAI.decide(rat, _grid, allies, _Ctx())
		if action.move_dest == EnemyAI.NO_CELL:
			break
		var dest_fd: int = field.get(action.move_dest, -1)
		assert_int(dest_fd).override_failure_message(
				"绕行目的格应在距离场内").is_greater_equal(0)
		assert_int(dest_fd).override_failure_message(
				"第 %d 轮全局距离未严格降（振荡/回归）" % [round_index + 1]) \
				.is_less(last_fd)
		last_fd = dest_fd
		_grid.remove_unit(rat.grid_pos)
		rat.grid_pos = action.move_dest
		_grid.place_unit(rat.grid_pos, rat)
		moved_count += 1
	# 实测 11→7→3→0 三步抵攻击位（宽容下限 2——防几何微调碎步退化）
	assert_int(moved_count).is_greater_equal(2)
	assert_int(last_fd).is_equal(0)
