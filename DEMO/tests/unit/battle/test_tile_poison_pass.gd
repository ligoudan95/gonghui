## 毒沼踏入染毒链单元/集成测试（功能一试玩批 1——途经附加 DEBUFF_poison）
## 覆盖十组：①途经我方敌方对称（共享 _move_unit 三路归一——request_move/
## AI/蛊惑同口）②停格双状态并存（站位 6 伤 + 途经染毒）③同名取大不叠加
## ④到期链 2 伤×2 回合（免减免直扣）⑤跳伤致死回归 ⑥陷阱截断后毒沼不染
## ⑦开局摆位出生毒沼双状态 + 起跳格排除（离格站位移除/染毒保留）
## ⑧叠层满位拒收（poison+curse 同轨占满）⑨CHECKIN 带入（探索层战斗通道）
## ⑩V-P1-tile-pass 负反（enter_status_id 坏引用/非 STATUS 地格挂载）。
## 环境口径：真 GameData autoload；毒沼摆位经动态地格覆写（tile_at 动态
## 优先——任意格摆毒沼，不动地图表）。
extends GdUnitTestSuite

## 毒沼地格表路径（apply_tile_pass 直调消费）
const SWAMP_TILE_PATH: String = "res://data/battle/tiles/tile_poison_swamp.tres"

## 用例级真实 GameData
var _game_data: Node

func before_test() -> void:
	## 用例前置：取真 GameData autoload 本体
	## 参数：无
	## 返回：无
	_game_data = get_tree().root.get_node_or_null("GameData")
	assert_object(_game_data).is_not_null()

func _MakeParty() -> Array[AdventurerData]:
	## 初始固定 4 人（17-C7 中值偏上——test_battle_flow 同口径）
	## 参数：无
	## 返回：AdventurerData 数组
	return [
		AdventurerData.create_debug(&"warrior", &"cls_warrior", {
			&"strength": 16, &"agility": 10, &"constitution": 14,
			&"intelligence": 7, &"perception": 9, &"willpower": 9, &"luck": 9,
		}, _game_data),
		AdventurerData.create_debug(&"rogue", &"cls_rogue", {
			&"strength": 10, &"agility": 16, &"constitution": 10,
			&"intelligence": 9, &"perception": 11, &"willpower": 10, &"luck": 13,
		}, _game_data),
		AdventurerData.create_debug(&"mage", &"cls_mage", {
			&"strength": 7, &"agility": 10, &"constitution": 9,
			&"intelligence": 16, &"perception": 11, &"willpower": 9, &"luck": 9,
		}, _game_data),
		AdventurerData.create_debug(&"priest", &"cls_priest", {
			&"strength": 10, &"agility": 10, &"constitution": 11,
			&"intelligence": 10, &"perception": 15, &"willpower": 13, &"luck": 9,
		}, _game_data),
	]

func _MakeContext(seed_value: int) -> BattleSetup.BattleContext:
	## 装配随机遭遇战斗上下文（固定种子）
	## 参数 seed_value：随机种子
	## 返回：BattleContext
	var params := BattleParams.new()
	params.pack_id = &"enc_m1_random_pack"
	params.party = _MakeParty()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	params.rng = rng
	return BattleSetup.build(params, _game_data)

func _MakeController(context: BattleSetup.BattleContext) -> BattleController:
	## 构建控制器（delay 0——headless 快进；auto_free 释放）
	## 参数 context：战斗上下文
	## 返回：已挂树控制器
	var controller := BattleController.new()
	controller.delay_seconds = 0.0
	controller.prepare(context)
	auto_free(controller)
	return controller

func _PlaceSwamp(context: BattleSetup.BattleContext, cell: Vector2i) -> void:
	## 摆毒沼（动态地格覆写——tile_at 动态优先，任意格可摆；伤害位不消费）
	## 参数 context：战斗上下文；cell：摆位格
	## 返回：无
	context.grid.spawn_dynamic_tile(cell, &"tile_poison_swamp", 0, &"")

func _HasStatus(context: BattleSetup.BattleContext, unit: BattleUnit,
		status_id: StringName) -> bool:
	## 单位是否持有指定状态
	## 参数 context/unit/status_id：上下文 / 单位 / 状态 id
	## 返回：true = 在场
	for instance: StatusInstance in context.status_manager.get_statuses(unit):
		if instance.status_id == status_id:
			return true
	return false

func test_pass_through_poisons_both_sides() -> void:
	## ①途经对称：我方与敌方单位途经毒沼格（起终点都不在毒沼上）均染
	## DEBUFF_poison（地格无归属——敌我同染；三路移动共用 _move_unit）
	var context := _MakeContext(77)
	var controller := _MakeController(context)
	var warrior: BattleUnit = context.find_unit(&"warrior")
	_PlaceSwamp(context, Vector2i(3, 6))
	controller._move_unit(warrior, Vector2i(4, 6))
	assert_bool(_HasStatus(context, warrior, &"DEBUFF_poison")) \
			.override_failure_message("我方途经毒沼应染毒").is_true()
	assert_bool(warrior.grid_pos == Vector2i(4, 6)).is_true()
	var enemy: BattleUnit = context.enemies[0]
	_PlaceSwamp(context, Vector2i(enemy.grid_pos + Vector2i(0, 1)))
	controller._move_unit(enemy, enemy.grid_pos + Vector2i(0, 2))
	assert_bool(_HasStatus(context, enemy, &"DEBUFF_poison")) \
			.override_failure_message("敌方途经毒沼应染毒（对称）").is_true()

func test_stop_on_swamp_dual_status() -> void:
	## ②停格双状态并存：停在毒沼格 → 站位 DEBUFF_tile_poison（6 伤站）+
	## 途经 DEBUFF_poison（2 伤×2 回合）同时在场
	var context := _MakeContext(77)
	var controller := _MakeController(context)
	var warrior: BattleUnit = context.find_unit(&"warrior")
	_PlaceSwamp(context, Vector2i(3, 6))
	controller._move_unit(warrior, Vector2i(3, 6))
	assert_bool(_HasStatus(context, warrior, &"DEBUFF_tile_poison")).is_true()
	assert_bool(_HasStatus(context, warrior, &"DEBUFF_poison")).is_true()

func test_same_name_refresh_no_stack() -> void:
	## ③同名取大：两次途经毒沼 → 单一 DEBUFF_poison 实例（不叠加不重锚定
	## 减损——apply ①同名分支），持续维持 default_duration
	var context := _MakeContext(77)
	var controller := _MakeController(context)
	var warrior: BattleUnit = context.find_unit(&"warrior")
	_PlaceSwamp(context, Vector2i(3, 6))
	controller._move_unit(warrior, Vector2i(4, 6))
	controller._move_unit(warrior, Vector2i(2, 6))
	var count: int = 0
	for instance: StatusInstance in context.status_manager.get_statuses(warrior):
		if instance.status_id == &"DEBUFF_poison":
			count += 1
	assert_int(count).is_equal(1)

func test_poison_expiry_2_damage_x_2_rounds() -> void:
	## ④到期链：round 1 染毒（first_tick=2）→ 回合 1 末不跳、2/3 末各 2 伤
	## （FIXED 直扣免减免）、4 末起状态移除无伤；总伤恰 4
	var context := _MakeContext(77)
	_MakeController(context)
	var warrior: BattleUnit = context.find_unit(&"warrior")
	var swamp: TileTypeDef = load(SWAMP_TILE_PATH) as TileTypeDef
	assert_bool(context.status_manager.apply_tile_pass(warrior, swamp, 1)).is_true()
	var hp_start: int = warrior.current_hp
	context.status_manager.end_of_round_tick(1, context.units, context.rng)
	assert_int(warrior.current_hp).is_equal(hp_start)
	context.status_manager.end_of_round_tick(2, context.units, context.rng)
	assert_int(warrior.current_hp).is_equal(hp_start - 2)
	context.status_manager.end_of_round_tick(3, context.units, context.rng)
	assert_int(warrior.current_hp).is_equal(hp_start - 4)
	context.status_manager.end_of_round_tick(4, context.units, context.rng)
	assert_int(warrior.current_hp).is_equal(hp_start - 4)
	assert_bool(_HasStatus(context, warrior, &"DEBUFF_poison")).is_false()

func test_poison_dot_can_kill() -> void:
	## ⑤跳伤致死回归：低血单位染毒 → 回合末跳伤归零倒地（on_downed 回调
	## 对齐技能击杀路径——W1-2 同口径）
	var context := _MakeContext(77)
	_MakeController(context)
	var warrior: BattleUnit = context.find_unit(&"warrior")
	warrior.current_hp = 3
	var swamp: TileTypeDef = load(SWAMP_TILE_PATH) as TileTypeDef
	assert_bool(context.status_manager.apply_tile_pass(warrior, swamp, 1)).is_true()
	context.status_manager.end_of_round_tick(2, context.units, context.rng)
	assert_int(warrior.current_hp).is_equal(1)
	assert_bool(warrior.alive).is_true()
	context.status_manager.end_of_round_tick(3, context.units, context.rng)
	assert_bool(warrior.alive).is_false()
	assert_int(warrior.current_hp).is_equal(0)

func test_trap_truncation_skips_swamp_beyond() -> void:
	## ⑥陷阱截断后毒沼不染：路径上陷阱格先触发截断，陷阱后方的毒沼格
	## 未踏入不染毒（(2,7)→(4,6) 路径 (2,6)(3,6)(4,6)：陷阱 (3,6) 截停、
	## 毒沼 (4,6) 未达）
	var context := _MakeContext(77)
	var controller := _MakeController(context)
	var warrior: BattleUnit = context.find_unit(&"warrior")
	var enemy: BattleUnit = context.enemies[0]
	context.grid.spawn_dynamic_tile(Vector2i(3, 6), &"tile_trap", 10, enemy.unit_id)
	_PlaceSwamp(context, Vector2i(4, 6))
	controller._move_unit(warrior, Vector2i(4, 6))
	assert_bool(warrior.grid_pos == Vector2i(3, 6)).is_true()
	assert_int(warrior.current_hp).is_equal(warrior.max_hp - 10)
	assert_bool(_HasStatus(context, warrior, &"DEBUFF_poison")) \
			.override_failure_message("截断后未达毒沼格不应染毒").is_false()

func test_spawn_on_swamp_dual_status_and_enemies_clean() -> void:
	## ⑦开局摆位：出生位在毒沼（表静态 'p' 格 (4,5)）→ 站位+染毒双状态
	## 同挂（battle_setup 两口齐调）；敌方出生行无地格效果零沾染
	var map_def: BattleMapDef = _game_data.get_record(&"btm_m1_random_8x8") as BattleMapDef
	var original_spawn: Vector2i = map_def.player_spawns[0]
	map_def.player_spawns[0] = Vector2i(4, 5)
	var context: BattleSetup.BattleContext = _MakeContext(77)
	map_def.player_spawns[0] = original_spawn
	assert_object(context).is_not_null()
	var warrior: BattleUnit = context.allies[0]
	assert_bool(warrior.grid_pos == Vector2i(4, 5)).is_true()
	assert_bool(_HasStatus(context, warrior, &"DEBUFF_tile_poison")).is_true()
	assert_bool(_HasStatus(context, warrior, &"DEBUFF_poison")).is_true()
	assert_bool(_HasStatus(context, context.enemies[0], &"DEBUFF_poison")).is_false()

func test_leave_swamp_pass_retained_standing_removed() -> void:
	## ⑦b 起跳格排除：站毒沼起跳移动 → 站位状态离格移除（on_leave_tile）、
	## 染毒保留（不随离格移除）且起跳格不重复施加（单实例维持）
	var context := _MakeContext(77)
	var controller := _MakeController(context)
	var warrior: BattleUnit = context.find_unit(&"warrior")
	controller._move_unit(warrior, Vector2i(4, 5))
	assert_bool(_HasStatus(context, warrior, &"DEBUFF_tile_poison")).is_true()
	controller._move_unit(warrior, Vector2i(4, 6))
	assert_bool(_HasStatus(context, warrior, &"DEBUFF_tile_poison")).is_false()
	assert_bool(_HasStatus(context, warrior, &"DEBUFF_poison")).is_true()
	var count: int = 0
	for instance: StatusInstance in context.status_manager.get_statuses(warrior):
		if instance.status_id == &"DEBUFF_poison":
			count += 1
	assert_int(count).is_equal(1)

func test_stack_full_rejects_pass() -> void:
	## ⑧叠层满位：DOT×DEBUFF 同轨已占 2（curse + 手构第二 DOT——DEBUFF_
	## tile_poison 为即时类不占轨，故本地管理器构型）→ 途经染毒被叠层拒收
	## （apply_tile_pass false，既有状态不受影响）
	var poison: StatusDef = _game_data.get_record(&"DEBUFF_poison") as StatusDef
	var curse: StatusDef = _game_data.get_record(&"DEBUFF_curse") as StatusDef
	var dot_b := StatusDef.new()
	dot_b.id = &"DEBUFF_dot_b"
	dot_b.category = StatusDef.Category.DOT
	dot_b.polarity = StatusDef.Polarity.DEBUFF
	dot_b.default_duration = 2
	var table: Dictionary = {poison.id: poison, curse.id: curse, dot_b.id: dot_b}
	var manager := StatusManager.new()
	manager.setup(load("res://data/core/cfg_main.tres") as CoreConfig,
			func(status_id: StringName) -> StatusDef: return table.get(status_id, null))
	var unit := BattleUnit.new()
	assert_bool(manager.apply(unit, curse, StatusInstance.SourceKind.SKILL, &"t",
			3, 1, false)).is_true()
	assert_bool(manager.apply(unit, dot_b, StatusInstance.SourceKind.SKILL, &"t",
			2, 1, false)).is_true()
	var swamp: TileTypeDef = load(SWAMP_TILE_PATH) as TileTypeDef
	assert_bool(manager.apply_tile_pass(unit, swamp, 1)).is_false()
	var has_poison: bool = false
	var has_curse: bool = false
	var has_dot_b: bool = false
	for instance: StatusInstance in manager.get_statuses(unit):
		if instance.status_id == &"DEBUFF_poison":
			has_poison = true
		elif instance.status_id == &"DEBUFF_curse":
			has_curse = true
		elif instance.status_id == &"DEBUFF_dot_b":
			has_dot_b = true
	assert_bool(has_poison).is_false()
	assert_bool(has_curse).is_true()
	assert_bool(has_dot_b).is_true()

func test_checkin_bring_in_applies_poison() -> void:
	## ⑨CHECKIN 带入：开局载入状态清单携带 DEBUFF_poison（探索层战斗通道
	## ——allowed_sources 含 CHECKIN）→ 施加成功且来源 KIND 正确
	var params := BattleParams.new()
	params.pack_id = &"enc_m1_random_pack"
	params.party = _MakeParty()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	params.rng = rng
	params.initial_statuses = [
		{&"status_id": &"DEBUFF_poison", &"target": &"rogue", &"duration": 0},
	]
	var context := BattleSetup.build(params, _game_data)
	assert_object(context).is_not_null()
	var rogue: BattleUnit = context.find_unit(&"rogue")
	var found: StatusInstance = null
	for instance: StatusInstance in context.status_manager.get_statuses(rogue):
		if instance.status_id == &"DEBUFF_poison":
			found = instance
	assert_object(found).is_not_null()
	assert_int(found.remaining).is_equal(2)
	assert_int(found.source_kind).is_equal(StatusInstance.SourceKind.CHECKIN)

func test_v_p1_tile_pass_negative() -> void:
	## ⑩V-P1-tile-pass 负反：enter_status_id 坏引用 / 非 STATUS 地格挂载
	## 均报错；恢复归零（正反=全库零错误见 test_run_all_clean）
	var swamp: TileTypeDef = _game_data.get_record(&"tile_poison_swamp") as TileTypeDef
	var original_enter: StringName = swamp.enter_status_id
	swamp.enter_status_id = &"DEBUFF_nope"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	assert_bool(_HasError(report, "V-P1-tile-pass", "DEBUFF_nope")) \
			.override_failure_message("enter_status_id 坏引用应报错").is_true()
	var normal: TileTypeDef = _game_data.get_record(&"tile_normal") as TileTypeDef
	var original_kind: int = normal.kind
	swamp.enter_status_id = original_enter
	normal.kind = TileTypeDef.Kind.NORMAL
	normal.enter_status_id = &"DEBUFF_poison"
	var kind_report: ValidationReport = DataValidator.run_all(_game_data)
	normal.enter_status_id = &""
	normal.kind = original_kind
	assert_bool(_HasError(kind_report, "V-P1-tile-pass", "STATUS")) \
			.override_failure_message("非 STATUS 地格挂 enter_status_id 应报错").is_true()
	var report_after: ValidationReport = DataValidator.run_all(_game_data)
	assert_int(report_after.errors.size()).is_equal(0)

func _HasError(report: ValidationReport, prefix: String, needle: String) -> bool:
	## 报告内按前缀+关键字匹配错误（本套件复刻口径）
	## 参数 report/prefix/needle：报告 / 规则前缀 / 关键字
	## 返回：true = 命中
	for entry: String in report.errors:
		if entry.begins_with(prefix) and entry.contains(needle):
			return true
	return false
