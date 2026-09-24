## BattleSetup 单元测试（M1 批 2）
## 覆盖：两种 pack 装配（随机 3 只 / 巢穴精英首位 + 2-3 杂兵）、出生位分配
## （随机位洗牌 / 精英槽 0 / override 直用）、我方队形与技能清单、
## 开局载入状态锚点（first_tick_round=1、CHECKIN 来源）。
## GameData 用手动实例（单元级口径，不依赖 autoload）。
extends GdUnitTestSuite

## GameData 自动加载脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## 地图表路径（出生位断言消费）
const RANDOM_MAP_PATH: String = "res://data/battle/maps/btm_m1_random_8x8.tres"
const LAIR_MAP_PATH: String = "res://data/battle/maps/btm_m1_lair_10x10.tres"

## 用例级 GameData 实例（每用例重建——状态施加隔离）
var _game_data: Node

func before_test() -> void:
	## 用例前置：实例化 GameData 并显式初始化
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

func _MakeParty() -> Array[AdventurerData]:
	## 构建 4 人调试队伍（17-C7 中值偏上属性，职业 = 初始固定 4 人）
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

func _MakeParams(pack_id: StringName, seed_value: int) -> BattleParams:
	## 构建开局参数包（固定种子 rng 注入）
	## 参数 pack_id：队伍 id；seed_value：随机种子
	## 返回：BattleParams
	var params := BattleParams.new()
	params.pack_id = pack_id
	params.party = _MakeParty()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	params.rng = rng
	return params

func test_random_pack_assembly() -> void:
	## 随机遭遇装配：3 只敌方（池内取）、出生位 = 4 候选中 3 个不重复位、
	## 我方 4 人入 player_spawns、单位全部在格
	var context := BattleSetup.build(_MakeParams(&"enc_m1_random_pack", 20260923), _game_data)
	assert_object(context).is_not_null()
	assert_int(context.allies.size()).is_equal(4)
	assert_int(context.enemies.size()).is_equal(3)
	assert_int(context.units.size()).is_equal(7)
	var map_def: BattleMapDef = load(RANDOM_MAP_PATH) as BattleMapDef
	# 我方：player_spawns 顺排
	for slot: int in 4:
		assert_int(context.allies[slot].grid_pos.x).is_equal(map_def.player_spawns[slot].x)
		assert_int(context.allies[slot].grid_pos.y).is_equal(map_def.player_spawns[slot].y)
	# 敌方：enemy_spawns 的 3 个不重复位；id 均在池内
	var used_slots: Array[int] = []
	for enemy: BattleUnit in context.enemies:
		var matched: bool = false
		for slot: int in map_def.enemy_spawns.size():
			if enemy.grid_pos == map_def.enemy_spawns[slot]:
				assert_bool(used_slots.has(slot)) \
						.override_failure_message("出生位槽 %d 重复占用" % slot).is_false()
				used_slots.append(slot)
				matched = true
				break
		assert_bool(matched).is_true()
		assert_bool(enemy.enemy_id == &"en_m1_mutant_rat" or enemy.enemy_id == &"en_m1_goblin_miner").is_true()
	# 全员占位索引与 grid_pos 一致
	for unit: BattleUnit in context.units:
		assert_object(context.grid.get_unit_at(unit.grid_pos)) \
				.override_failure_message("单位 %s 不在占位索引" % unit.unit_id).is_not_null()

func test_lair_pack_assembly() -> void:
	## 巢穴必然遭遇装配：精英在 enemy_spawns[0]（首位）、总数 = 1 精英 + 2-3 杂兵
	var context := BattleSetup.build(_MakeParams(&"enc_m1_lair_pack", 7), _game_data)
	assert_object(context).is_not_null()
	assert_int(context.enemies.size()).is_between(3, 4)
	var map_def: BattleMapDef = load(LAIR_MAP_PATH) as BattleMapDef
	var elite: BattleUnit = context.enemies[0]
	assert_str(String(elite.role_tag)).is_equal("elite")
	assert_int(elite.grid_pos.x).is_equal(map_def.enemy_spawns[0].x)
	assert_int(elite.grid_pos.y).is_equal(map_def.enemy_spawns[0].y)
	var trash_count: int = 0
	for enemy: BattleUnit in context.enemies.slice(1):
		assert_str(String(enemy.role_tag)).is_equal("trash")
		trash_count += 1
	assert_int(trash_count).is_between(2, 3)

func test_seed_reproducibility() -> void:
	## 同种子复现：两次装配的敌方构成与出生位完全一致
	var first := BattleSetup.build(_MakeParams(&"enc_m1_random_pack", 99), _game_data)
	var second := BattleSetup.build(_MakeParams(&"enc_m1_random_pack", 99), _game_data)
	assert_int(first.enemies.size()).is_equal(second.enemies.size())
	for index: int in first.enemies.size():
		assert_str(String(first.enemies[index].unit_id)).is_equal(String(second.enemies[index].unit_id))
		assert_int(first.enemies[index].grid_pos.x).is_equal(second.enemies[index].grid_pos.x)
		assert_int(first.enemies[index].grid_pos.y).is_equal(second.enemies[index].grid_pos.y)

func test_create_debug_display_name_chinese() -> void:
	## create_debug 显示名中文化（2026-09-24 七轮反馈）：六职业取职业表
	## display_name（cls_warrior → 战士……）；查无职业表回退 unit_id 原文
	var expects: Dictionary = {
		&"cls_warrior": "战士", &"cls_rogue": "盗贼", &"cls_mage": "法师",
		&"cls_priest": "牧师", &"cls_ranger": "游侠", &"cls_arcanist": "奇术师",
	}
	for class_id: StringName in expects:
		var adv: AdventurerData = AdventurerData.create_debug(class_id, class_id, {}, _game_data)
		assert_str(adv.display_name) \
				.override_failure_message("职业 %s 显示名未中文化" % class_id) \
				.is_equal(expects[class_id])
	var fallback: AdventurerData = AdventurerData.create_debug(&"mystery", &"cls_nope",
			{}, _game_data)
	assert_str(fallback.display_name).is_equal("mystery")

func test_enemy_display_name_suffix_rule() -> void:
	## 同名敌方序号规则（2026-09-24 七轮反馈）：按 enemy_id 分组，组内首个
	## 显示敌表中文名无后缀、其余「中文名 N」按装配序递增；显示名绝不为
	## 英文 id（构建链中文化断点防回归）
	var context := BattleSetup.build(_MakeParams(&"enc_m1_random_pack", 20260923), _game_data)
	var counts: Dictionary = {}
	for enemy: BattleUnit in context.enemies:
		var base: String = (_game_data.get_record(enemy.enemy_id) as EnemyDef).display_name
		var expected_count: int = int(counts.get(enemy.enemy_id, 0)) + 1
		counts[enemy.enemy_id] = expected_count
		var expected_name: String = base if expected_count == 1 else "%s %d" % [base, expected_count]
		assert_str(enemy.display_name) \
				.override_failure_message("敌方 %s 显示名序号规则不符" % enemy.unit_id) \
				.is_equal(expected_name)
		assert_bool(enemy.display_name.begins_with("en_")).is_false()
	# 我方四职业显示名全部中文（经 create_debug → build_ally 透传链）
	for ally: BattleUnit in context.allies:
		assert_bool(ally.display_name.begins_with("warrior")) \
				.override_failure_message("我方 %s 仍显示英文 unit_id" % ally.unit_id).is_false()

func test_ally_skills_and_formation() -> void:
	## 我方技能清单（M1 调试口径：普攻 + 档 1 全部 2 技）与 formation 覆盖
	var params := _MakeParams(&"enc_m1_random_pack", 1)
	params.formation = [Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7)]
	var context := BattleSetup.build(params, _game_data)
	var warrior: BattleUnit = context.allies[0]
	assert_int(warrior.skill_ids.size()).is_equal(3)
	assert_bool(warrior.skill_ids.has(&"skl_atk_warrior")).is_true()
	assert_bool(warrior.skill_ids.has(&"skl_warrior_power_strike")).is_true()
	assert_bool(warrior.skill_ids.has(&"skl_warrior_shield_wall")).is_true()
	assert_int(warrior.grid_pos.x).is_equal(2)
	assert_int(warrior.grid_pos.y).is_equal(7)

func test_initial_statuses_battle_load_anchor() -> void:
	## 开局载入状态：施加走 CHECKIN 来源 + first_tick_round=1（回合 1 末照常
	## 递减——案 11 §2.3 边界锚点 1）
	var params := _MakeParams(&"enc_m1_random_pack", 1)
	var entry: Dictionary = {&"status_id": &"DEBUFF_exposed", &"target": &"rogue", &"duration": 1}
	params.initial_statuses = [entry]
	var context := BattleSetup.build(params, _game_data)
	var rogue: BattleUnit = context.find_unit(&"rogue")
	var statuses: Array[StatusInstance] = context.status_manager.get_statuses(rogue)
	assert_int(statuses.size()).is_equal(1)
	assert_str(String(statuses[0].status_id)).is_equal("DEBUFF_exposed")
	assert_int(statuses[0].first_tick_round).is_equal(1)
	assert_int(statuses[0].source_kind).is_equal(StatusInstance.SourceKind.CHECKIN)

func test_enemy_spawn_override() -> void:
	## 出生位覆盖：override 序列直用（跳过默认分配）
	var params := _MakeParams(&"enc_m1_random_pack", 5)
	params.enemy_spawn_override = [3, 1, 0]
	var context := BattleSetup.build(params, _game_data)
	var map_def: BattleMapDef = load(RANDOM_MAP_PATH) as BattleMapDef
	assert_int(context.enemies.size()).is_equal(3)
	for index: int in 3:
		var expected: Vector2i = map_def.enemy_spawns[params.enemy_spawn_override[index]]
		assert_int(context.enemies[index].grid_pos.x).is_equal(expected.x)
		assert_int(context.enemies[index].grid_pos.y).is_equal(expected.y)

func test_validate_skill_resources_green_on_real_data() -> void:
	## 资源预校验绿路径（盲审批 3 D-1）：真实全量数据装配的战斗上下文——
	## 全部单位技能/效果引用可解析，问题清单为空
	var context := BattleSetup.build(_MakeParams(&"enc_m1_random_pack", 7), _game_data)
	assert_object(context).is_not_null()
	var issues: Array[String] = BattleSetup.validate_skill_resources(context)
	for issue: String in issues:
		print("unexpected issue: %s" % issue)
	assert_int(issues.size()).is_equal(0)

func test_validate_skill_resources_detects_missing_refs() -> void:
	## 资源预校验检出路径（盲审批 3 D-1）：技能不可解析 / 可解析技能的
	## STATUS_APPLY 引用状态缺失、TILE_SPAWN 引用地格缺失逐条入清单——
	## 不等执行中才 push_error 空转（AURA 怒吼的施加链同 STATUS_APPLY 覆盖）
	var context := BattleSetup.build(_MakeParams(&"enc_m1_random_pack", 8), _game_data)
	assert_object(context).is_not_null()
	var warrior: BattleUnit = context.find_unit(&"warrior")
	# 坏 1：技能 id 本身不可解析（skill_lookup 查无）
	warrior.skill_ids.append(&"skl_broken_missing")
	# 坏 2/3：可解析的假技能（闭包补登）挂坏状态引用 + 坏地格引用
	var fake_skill: SkillDef = SkillDef.new()
	fake_skill.id = &"skl_fake_bad_refs"
	var bad_status_effect: SkillEffect = SkillEffect.new()
	bad_status_effect.effect_kind = SkillEffect.EffectKind.STATUS_APPLY
	bad_status_effect.status_id = &"DEBUFF_missing_status"
	bad_status_effect.duration = 2
	var bad_tile_effect: SkillEffect = SkillEffect.new()
	bad_tile_effect.effect_kind = SkillEffect.EffectKind.TILE_SPAWN
	bad_tile_effect.tile_type_id = &"tile_missing_type"
	fake_skill.effects = [bad_status_effect, bad_tile_effect]
	var base_lookup: Callable = context.skill_lookup
	context.skill_lookup = func(skill_id: StringName) -> Resource:
		if skill_id == &"skl_fake_bad_refs":
			return fake_skill
		return base_lookup.call(skill_id)
	warrior.skill_ids.append(&"skl_fake_bad_refs")
	var issues: Array[String] = BattleSetup.validate_skill_resources(context)
	assert_int(issues.size()).is_equal(3)
	assert_bool(issues[0].contains("skl_broken_missing")).is_true()
	assert_bool(issues[1].contains("DEBUFF_missing_status")).is_true()
	assert_bool(issues[2].contains("tile_missing_type")).is_true()

func test_display_name_of_single_source() -> void:
	## 显示名单源（批 4 C 组 M4）：查得则显示名、查无/空显示名回退 id 原文
	var context := BattleSetup.build(_MakeParams(&"enc_m1_random_pack", 9), _game_data)
	assert_object(context).is_not_null()
	# 查得：我方单位带显示名
	var warrior: BattleUnit = context.find_unit(&"warrior")
	assert_bool(warrior.display_name.is_empty()).is_false()
	assert_str(context.display_name_of(&"warrior")).is_equal(warrior.display_name)
	# 查无：回退 id 原文
	assert_str(context.display_name_of(&"nobody")).is_equal("nobody")
	# 空显示名：回退 id 原文
	var enemy: BattleUnit = context.enemies[0]
	var original_name: String = enemy.display_name
	enemy.display_name = ""
	assert_str(context.display_name_of(enemy.unit_id)).is_equal(String(enemy.unit_id))
	enemy.display_name = original_name

func test_unit_tags_and_attr_keys_anchor_real_tables() -> void:
	## 常量类与实表锚定（批 4 C 组）：UnitTags token 值 == EnemyDef 表实值
	## （role_tag/race_tag 值域经 DataValidator 单源校验一致）；AttrKeys 七属性
	## 与校验器全集等长同集
	var rat: EnemyDef = _game_data.get_record(&"en_m1_mutant_rat") as EnemyDef
	assert_str(String(rat.role_tag)).is_equal(String(UnitTags.ROLE_TRASH))
	var boss: EnemyDef = _game_data.get_record(&"en_m1_elite_boss") as EnemyDef
	assert_str(String(boss.role_tag)).is_equal(String(UnitTags.ROLE_ELITE))
	assert_str(String(UnitTags.RACE_UNDEAD)).is_equal("undead")
	assert_str(String(UnitTags.RACE_BEAST)).is_equal("beast")
	assert_str(String(UnitTags.RACE_HUMANOID)).is_equal("humanoid")
	assert_int(AttrKeys.seven_attrs().size()).is_equal(7)
	assert_bool(AttrKeys.seven_attrs().has(AttrKeys.INTELLIGENCE)).is_true()
	assert_bool(AttrKeys.seven_attrs().has(AttrKeys.WILLPOWER)).is_true()

func test_party_overload_rejected_and_exact_fit_ok() -> void:
	## 超编拒绝（R2-1）：party 5 人 + 地图 4 出生位 → build 返回 null；
	## 恰好 4 人正常装配
	var params_over := _MakeParams(&"enc_m1_random_pack", 31)
	params_over.party.append(AdventurerData.create_debug(&"extra", &"cls_ranger", {
		&"strength": 10, &"agility": 16, &"constitution": 10,
		&"intelligence": 9, &"perception": 11, &"willpower": 10, &"luck": 13,
	}, _game_data))
	assert_int(params_over.party.size()).is_equal(5)
	assert_object(BattleSetup.build(params_over, _game_data)).is_null()
	var params_exact := _MakeParams(&"enc_m1_random_pack", 31)
	assert_object(BattleSetup.build(params_exact, _game_data)).is_not_null()
	assert_int(params_exact.party.size()).is_equal(4)

func test_empty_party_rejected() -> void:
	## 空出战名单（R2-8）：build 拒绝返回 null
	var params := BattleParams.new()
	params.pack_id = &"enc_m1_random_pack"
	params.party = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 32
	params.rng = rng
	assert_object(BattleSetup.build(params, _game_data)).is_null()

func test_spawn_override_deduplicates() -> void:
	## 敌槽覆盖去重（R2-4）：重复槽 [1,1,3,3] → 去重 [1,3]——两敌不叠格
	var params := _MakeParams(&"enc_m1_lair_pack", 33)
	params.enemy_spawn_override = [1, 1, 3, 3]
	var context := BattleSetup.build(params, _game_data)
	assert_object(context).is_not_null()
	var used: Array[Vector2i] = []
	for enemy: BattleUnit in context.enemies:
		assert_bool(used.has(enemy.grid_pos)) \
				.override_failure_message("敌槽去重失效——叠格 %s" % enemy.grid_pos).is_false()
		used.append(enemy.grid_pos)

func test_formation_invalid_falls_back_to_spawns() -> void:
	## 队形覆盖校验（R2-3）：非法条目（障碍格 (2,2)）push_error 回退顺排位；
	## 合法条目生效
	var params := _MakeParams(&"enc_m1_random_pack", 34)
	params.formation = [Vector2i(2, 2), Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7)]
	var context := BattleSetup.build(params, _game_data)
	assert_object(context).is_not_null()
	var map_def: BattleMapDef = load("res://data/battle/maps/btm_m1_random_8x8.tres") as BattleMapDef
	var first: BattleUnit = context.allies[0]
	assert_vector(first.grid_pos).is_equal(map_def.player_spawns[0]) \
			.override_failure_message("非法 formation 条目应回退顺排位")
	assert_vector(context.allies[1].grid_pos).is_equal(Vector2i(1, 7))
