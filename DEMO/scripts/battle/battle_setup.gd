## 战斗装配器（BattleSetup，纯静态工具类）
## 职责：按 BattleParams 开局参数包装配一场战斗——载地图、建格子、装配
## 双方单位（我方入 player_spawns；敌方按 pack 条目从 enemy_spawns 分配：
## 精英首位 + 其余洗位，随机位由注入 rng 驱动）、施加开局载入状态、
## 组装 BattleContext 交 BattleController。
## 数据来源：案 9《战棋战斗》；案 11 §2.3（开局载入锚点——current_round=0
## 施加 → first_tick_round=1）；17 案 §3.8（队伍编成：随机 3 只 / 必然 1+2-3）。
## 纯逻辑约束：不触任何 autoload——game_data 经参数注入（headless 测试传
## get_tree().root.get_node_or_null("GameData")，生产侧传 GameData 单例本体）。
class_name BattleSetup
extends RefCounted

## 装配消费的数据域键（批 D L2：集中常量——与 GameData 域注册键一致，
## 原散布字面量删除；改域结构时只动此处）
const DOMAIN_TILES: StringName = &"battle/tiles"
const DOMAIN_STATUSES: StringName = &"status/stats"
const DOMAIN_SKILLS: StringName = &"class/skills"
const DOMAIN_EQUIP: StringName = &"equip"

## 战斗上下文（装配产物：战场/单位/状态管理器/随机源/回合号与三个 lookup）
class BattleContext:
	extends RefCounted
	## 战场格子
	var grid: BattleGrid = null
	## 状态管理器（本场一个）
	var status_manager: StatusManager = null
	## 参战单位全集（我方在前、敌方在后；含倒地单位——终局快照消费）
	var units: Array = []
	## 我方单位列表
	var allies: Array = []
	## 敌方单位列表
	var enemies: Array = []
	## 行动序列（BattleController 每回合初重算）
	var turn_order: Array = []
	## 随机源（params 注入或现场随机）
	var rng: RandomNumberGenerator = null
	## 回合号（0 = 未开始；ROUND_START 递增）
	var round_no: int = 0
	## 开局参数包（回查用）
	var params: BattleParams = null
	## 总控配置
	var cfg: CoreConfig = null
	## 地格定义解析回调（StringName -> TileTypeDef）
	var tile_lookup: Callable = Callable()
	## 状态定义解析回调（StringName -> StatusDef）
	var status_lookup: Callable = Callable()
	## 技能定义解析回调（StringName -> SkillDef）
	var skill_lookup: Callable = Callable()

	func find_unit(unit_id: StringName) -> BattleUnit:
		## 按 id 查参战单位
		## 参数 unit_id：单位实例 id
		## 返回：BattleUnit；未找到返回 null
		for unit: BattleUnit in units:
			if unit.unit_id == unit_id:
				return unit
		return null

static func build(params: BattleParams, game_data: Node) -> BattleContext:
	## 装配主入口：地图 → 双方单位 → 开局载入状态 → BattleContext
	## 参数 params：开局参数包；game_data：GameData（autoload 本体或手动实例）
	## 返回：BattleContext（装配失败 push_error 并返回 null）
	var context := BattleContext.new()
	context.params = params
	context.cfg = game_data.get_record(&"cfg_main") as CoreConfig
	if context.cfg == null:
		push_error("BattleSetup: cfg_main 无法解析")
		return null
	# 随机源：注入优先，缺省现场随机
	if params.rng != null:
		context.rng = params.rng
	else:
		context.rng = RandomNumberGenerator.new()
		context.rng.randomize()
	# 三个域 lookup（闭包捕获 id -> record 字典）
	context.tile_lookup = _MakeLookup(game_data, DOMAIN_TILES)
	context.status_lookup = _MakeLookup(game_data, DOMAIN_STATUSES)
	context.skill_lookup = _MakeLookup(game_data, DOMAIN_SKILLS)
	# 队伍与地图
	var pack: EnemyPackDef = game_data.get_record(params.pack_id) as EnemyPackDef
	if pack == null:
		push_error("BattleSetup: 遭遇队伍 '%s' 无法解析" % params.pack_id)
		return null
	var map_def: BattleMapDef = game_data.get_record(pack.battle_map_ref) as BattleMapDef
	if map_def == null:
		push_error("BattleSetup: 战场地图 '%s' 无法解析" % pack.battle_map_ref)
		return null
	context.grid = BattleGrid.new()
	if not context.grid.setup(map_def, context.tile_lookup):
		push_error("BattleSetup: 地图 '%s' 解析存在问题（见 setup_issues）" % map_def.id)
	# 状态管理器
	context.status_manager = StatusManager.new()
	context.status_manager.setup(context.cfg, context.status_lookup)
	# 我方装配（player_spawns 顺排 / formation 覆盖）
	for slot: int in params.party.size():
		var adv: AdventurerData = params.party[slot]
		var cls: ClassDef = game_data.get_record(adv.class_id) as ClassDef
		if cls == null:
			push_error("BattleSetup: 职业 '%s' 无法解析（%s）" % [adv.class_id, adv.unit_id])
			continue
		var equip: EquipDef = _FindEquipForClass(game_data, adv.class_id)
		var unit := UnitBuilder.build_ally(adv, cls, equip, context.cfg)
		unit.slot_index = slot
		unit.bind_battle(context.cfg, context.status_manager)
		var spawn: Vector2i = params.formation[slot] if slot < params.formation.size() \
				else map_def.player_spawns[slot]
		unit.grid_pos = spawn
		context.grid.place_unit(spawn, unit)
		# 开局站位地格状态（M1 批 2 缺口补线 2026-09-24 八轮）：出生位在状态格
		# 上即开局挂状态（current_round=0 = 回合 1 前锚点，毒沼回合 1 末即跳）
		context.status_manager.apply_tile_standing(unit, context.grid.tile_at(spawn), 0)
		context.units.append(unit)
		context.allies.append(unit)
	# 敌方装配（槽位分配：覆盖序列优先；默认 = 精英首位 + 其余洗位）
	var spawn_slots: Array[int] = _AllocateSpawnSlots(pack, map_def.enemy_spawns.size(),
			params.enemy_spawn_override, context.rng)
	var slot_cursor: int = 0
	var enemy_order: int = 0
	# 同名敌方序号计数（2026-09-24 七轮反馈：3 只「变异鼠」在日志/信息卡
	# 无法区分——同 enemy_id 第 2 个起显示名追加序号，首个不加）
	var enemy_name_counts: Dictionary = {}
	for entry: PackEntry in pack.entries:
		var count: int = mini(context.rng.randi_range(entry.count_min, entry.count_max),
				spawn_slots.size() - slot_cursor)
		for spawn_index: int in count:
			if slot_cursor >= spawn_slots.size():
				break
			var enemy_id: StringName = entry.enemy_ids[
					context.rng.randi_range(0, entry.enemy_ids.size() - 1)]
			var enemy_def: EnemyDef = game_data.get_record(enemy_id) as EnemyDef
			if enemy_def == null:
				push_error("BattleSetup: 敌人 '%s' 无法解析" % enemy_id)
				slot_cursor += 1
				continue
			var enemy := UnitBuilder.build_enemy(enemy_def, enemy_order)
			var name_count: int = int(enemy_name_counts.get(enemy_id, 0)) + 1
			enemy_name_counts[enemy_id] = name_count
			if name_count > 1:
				enemy.display_name = "%s %d" % [enemy.display_name, name_count]
			enemy.bind_battle(context.cfg, context.status_manager)
			enemy.grid_pos = map_def.enemy_spawns[spawn_slots[slot_cursor]]
			context.grid.place_unit(enemy.grid_pos, enemy)
			# 开局站位地格状态（同我方口径——敌我同权）
			context.status_manager.apply_tile_standing(enemy,
					context.grid.tile_at(enemy.grid_pos), 0)
			context.units.append(enemy)
			context.enemies.append(enemy)
			enemy_order += 1
			slot_cursor += 1
	# 开局载入状态（current_round=0 → first_tick_round=1 开局载入锚点）
	for entry: Dictionary in params.initial_statuses:
		var status_id: StringName = entry.get(&"status_id", &"")
		var target_id: StringName = entry.get(&"target", &"")
		var duration: int = int(entry.get(&"duration", 0))
		var target: BattleUnit = context.find_unit(target_id)
		var status: StatusDef = context.status_lookup.call(status_id) as StatusDef
		if target == null or status == null:
			push_error("BattleSetup: 开局状态 '%s'（目标 '%s'）无法施加" % [status_id, target_id])
			continue
		context.status_manager.apply(target, status, StatusInstance.SourceKind.CHECKIN,
				&"battle_init", duration, 0, true)
	# M2 挂点提示（M1 默认空不消费）
	if not params.terrain_override.is_empty():
		push_warning("BattleSetup: terrain_override 非空——M2 场景联调挂点，M1 未实现")
	return context

static func _MakeLookup(game_data: Node, domain: StringName) -> Callable:
	## 域 lookup 闭包（id -> Resource 字典捕获；懒建一次）
	## 参数 game_data：GameData；domain：域键
	## 返回：Callable（StringName -> Resource）
	var table: Dictionary = {}
	for record_id: StringName in game_data.get_domain_ids(domain):
		table[record_id] = game_data.get_record(record_id)
	return func(record_id: StringName) -> Resource:
		return table.get(record_id, null)

static func _FindEquipForClass(game_data: Node, class_id: StringName) -> EquipDef:
	## 按职业查初始装备（equip 域 class_ref 匹配；未配置返回 null + warning）
	## 参数 game_data：GameData；class_id：职业 id
	## 返回：EquipDef；无匹配返回 null
	for record_id: StringName in game_data.get_domain_ids(DOMAIN_EQUIP):
		var equip: EquipDef = game_data.get_record(record_id) as EquipDef
		if equip != null and equip.class_ref == class_id:
			return equip
	push_warning("BattleSetup: 职业 '%s' 无初始装备登记（按零装备装配）" % class_id)
	return null

static func _AllocateSpawnSlots(pack: EnemyPackDef, spawn_count: int,
		override: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	## 敌方出生位分配：override 非空 = 覆盖序列直用；默认 = 精英首位（槽 0）+
	## 其余槽位洗牌（随机遭遇 3 只从 4 位随机取 3 的通式）；越界槽位剔除
	## 参数 pack：队伍表（判精英位）；spawn_count：出生位总数；override：覆盖序列；rng：随机源
	## 返回：槽位下标序列（按分配顺序）
	if not override.is_empty():
		var result: Array[int] = []
		for slot: int in override:
			if slot >= 0 and slot < spawn_count:
				result.append(slot)
		return result
	var slots: Array[int] = []
	var has_elite: bool = false
	for entry: PackEntry in pack.entries:
		if entry.is_elite:
			has_elite = true
			break
	var start: int = 1 if has_elite else 0
	if has_elite and spawn_count > 0:
		slots.append(0)
	var rest: Array[int] = []
	for slot: int in range(start, spawn_count):
		rest.append(slot)
	# Fisher-Yates 洗牌（注入 rng 驱动）
	for index: int in range(rest.size() - 1, 0, -1):
		var swap: int = rng.randi_range(0, index)
		var temp: int = rest[index]
		rest[index] = rest[swap]
		rest[swap] = temp
	slots.append_array(rest)
	return slots
