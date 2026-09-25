## 战斗控制器（BattleController，Node——战棋场景子节点；M1 批 2 headless 可独立 add_child 驱动）
## 职责：战局状态机驱动——BATTLE_INIT→ROUND_START（速度排序 + 同速打破平：
## 我方优先→槽位序）→TURN_LOOP（我方等玩家指令；敌方 EnemyAI.decide 执行；
## 被定身完全跳过；被蛊惑自动随机行动）→ROUND_END（批 1 回合末结算 + 兜底
## 胜负判定）→BATTLE_END；伤害结算后即时全灭判定（同时全灭按战败）。
## 数据来源：案 9《战棋战斗》（回合流程/撤退 = 委托失败口径占位）；
## 案 11 §2.3（蛊惑 = 延迟型控制下回合行动异常——P3：随机移动 + 射程内
## 随机敌方普攻，否则待机）。
## 纯逻辑约束：不触任何 autoload——全部依赖经 BattleContext 注入；
## 玩家指令经 request_* 公开接口（等待循环轮询标记，规避信号竞态）；
## battle_ended 以 call_deferred 发出（保证 await 挂接方不漏接）。
class_name BattleController
extends Node

## 战局状态（BATTLE_INIT → ROUND_START → TURN_LOOP → ROUND_END 循环 → BATTLE_END）
enum BattleState {
	BATTLE_INIT,
	ROUND_START,
	TURN_LOOP,
	ROUND_END,
	BATTLE_END,
}

## 回合数护栏（超出按战败收束并 push_warning——防异常局面死循环）。
## 工程护栏非玩法参数（批 B M3 架构师裁定：不入 cfg 表，留代码）
const MAX_ROUNDS: int = 50

## 战斗开始（装配完成后发出一次）
signal battle_started
## 回合开始（参数 = 回合号）
signal round_started(round_no: int)
## 单位行动轮开始（参数 = 行动单位）
signal turn_started(unit: BattleUnit)
## 单位移动完成（参数 = 单位 / 起格 / 终格）
signal unit_moved(unit: BattleUnit, from_pos: Vector2i, to_pos: Vector2i)
## 技能执行完成（参数 = 施放单位 / 执行结果——S4-10/S5-7 全量类型标注）
signal skill_executed(caster: BattleUnit, result: SkillExecutor.ExecutionResult)
## 状态变化（参数 = 目标单位 / 状态 id）
signal status_changed(unit: BattleUnit, status_id: StringName)
## 单位倒地（参数 = 倒地单位）
signal unit_downed(unit: BattleUnit)
## 回合末结算完成（盲审批 3 D-2：参数 = 回合号 / DOT 跳伤清单——逐跳一条
## {&"unit": 承伤单位, &"damage": 跳伤值}，供战斗日志与飘字消费；无跳空数组）
signal round_settled(round_no: int, dot_damage: Array)
## 陷阱触发（参数 = 踏入单位 / 预结算伤害——盲审批 1-3：动态地格运行时
## 触发链的日志/UI 可观测口）
signal trap_triggered(unit: BattleUnit, damage: int)
## 战斗终局（参数 = BattleResult；call_deferred 发出——R2-2 类型补全）
signal battle_ended(result: BattleResult)

## 敌方行动演出延时（秒；默认 0.4，headless 测试注入 0）
@export var delay_seconds: float = 0.4
## 当前战局状态
var state: BattleState = BattleState.BATTLE_INIT
## 当前行动单位
var current_unit: BattleUnit = null
## 是否正在等待玩家指令（request_* 的受理窗口）
var awaiting_command: bool = false

## 战斗上下文（start_battle 注入）
var _context: BattleSetup.BattleContext = null
## 技能执行器（纯逻辑，无状态可复用）
var _executor := SkillExecutor.new()
## 当前行动轮完成标记（玩家指令轮询）
var _turn_done: bool = false
## 终局结果（发出前暂存）
var _result: BattleResult = null
## 战局收束标记
var _battle_over: bool = false
## 倒地单位 id 时序记录（终局快照 + 事件去重）
var _downed_ids: Array[StringName] = []
## 演出延时跳过请求（skip_current_delay 置位，_wait_delay 轮询消费）
var _delay_skip_requested: bool = false

func prepare(context: BattleSetup.BattleContext) -> void:
	## 挂接上下文（不启动状态机——单元/集成测试直调分项行动口用）
	## 参数 context：BattleSetup.build 装配产物
	## 返回：无
	_context = context

func abort_battle() -> void:
	## 中止战局（不清结果不发信号——场景离树/测试收尾停机用，防僵尸协程）
	## 参数：无
	## 返回：无
	_battle_over = true
	_turn_done = true
	_delay_skip_requested = true
	state = BattleState.BATTLE_END

func _exit_tree() -> void:
	## 引擎回调：离树即中止战局（场景切换/释放时停机——离开战斗屏必须停止
	## 状态机，避免协程在游离节点上继续等待刷错误）
	## 参数：无
	## 返回：无
	abort_battle()

func start_battle(context: BattleSetup.BattleContext) -> void:
	## 开战入口：挂接上下文并启动状态机协程（fire-and-forget——战斗随帧推进）。
	## R2-9 实例契约：**本实例不可复用开第二场**——收束/中止后 _battle_over/
	## _downed_ids/_result 为终态残留；连战需求须重建 BattleController
	## （或自行复位上述三态 + 重新 prepare）
	## 参数 context：BattleSetup.build 装配产物
	## 返回：无
	prepare(context)
	_run()

func request_move(dest: Vector2i) -> bool:
	## 玩家指令：当前我方单位移动至可达格（**已移动**后不可再移——盲审批 1-7；
	## S3-03 拍板 A：行动顺序任意——去掉 has_acted 前置（先攻击后移动同轮成立，
	## _auto_end_turn 双标记收束口径不变）
	## 参数 dest：目的地
	## 返回：true = 受理执行
	if not _can_command() or current_unit.has_moved:
		return false
	var reachable: Array[Vector2i] = _context.grid.find_reachable(current_unit,
			current_unit.move_final())
	if not reachable.has(dest):
		return false
	_move_unit(current_unit, dest)
	_auto_end_turn()
	return true

func request_skill(skill_id: StringName, target_cell: Vector2i) -> bool:
	## 玩家指令：当前我方单位释放技能（执行失败不消耗行动——行动轮继续等待）
	## 参数 skill_id：技能 id；target_cell：目标格
	## 返回：true = 受理执行（失败 false 不置 has_acted；S3-05：技能解析失败
	## result 为 null 直接拒绝，不触 .success 成员访问）
	if not _can_command() or current_unit.has_acted:
		return false
	if not current_unit.skill_ids.has(skill_id):
		return false
	var result = _execute_skill(current_unit, skill_id, target_cell)
	if result == null or not result.success:
		return false
	current_unit.has_acted = true
	_auto_end_turn()
	return true

func request_end_unit_turn() -> bool:
	## 玩家指令：结束当前单位行动轮
	## 参数：无
	## 返回：true = 受理执行
	if not _can_command():
		return false
	_turn_done = true
	return true

func request_retreat() -> bool:
	## 玩家指令：撤退（委托失败口径占位——立即按 RETREAT 收束战局）
	## 参数：无
	## 返回：true = 受理执行
	if not _can_command():
		return false
	_finish_battle(BattleResult.ResultKind.RETREAT)
	return true

func run_bewitched_action(unit: BattleUnit) -> void:
	## 蛊惑自动随机行动（公开口——控制器内部分派，亦供集成测试直调验证）：
	## 随机移动至可达格 + 对射程内随机敌方普攻，否则待机；移动后单位死亡
	## （踩陷阱）即终止（S3-01——死人不攻击）；攻击目标池过滤视线
	## （S3-08：los_required 口径，与执行器前置校验一致）
	## 参数 unit：被蛊惑单位
	## 返回：无
	var reachable: Array[Vector2i] = _context.grid.find_reachable(unit, unit.move_final())
	if not reachable.is_empty():
		var dest: Vector2i = reachable[_context.rng.randi_range(0, reachable.size() - 1)]
		_move_unit(unit, dest)
	if not unit.alive or _battle_over:
		return
	var attack: SkillDef = _context.skill_lookup.call(unit.base_attack_id) as SkillDef
	if attack == null:
		return
	var attack_range: int = _executor.effective_range(attack)
	var needs_los: bool = _executor.los_required(attack)
	var in_range: Array = []
	for enemy: BattleUnit in _hostiles_of(unit):
		if not enemy.alive or BattleGrid.manhattan(unit.grid_pos, enemy.grid_pos) > attack_range:
			continue
		if needs_los and not _context.grid.has_line_of_sight(unit.grid_pos, enemy.grid_pos):
			continue
		in_range.append(enemy)
	if not in_range.is_empty():
		var target: BattleUnit = in_range[_context.rng.randi_range(0, in_range.size() - 1)]
		_execute_skill(unit, unit.base_attack_id, target.grid_pos)
		unit.has_acted = true

# --------------------------------------------------------------------------
# 状态机主循环
# --------------------------------------------------------------------------

func _run() -> void:
	## 状态机协程：ROUND_START → TURN_LOOP → ROUND_END 循环至 BATTLE_END
	## 参数：无
	## 返回：无（协程——随帧推进）
	state = BattleState.ROUND_START
	battle_started.emit()
	while not _battle_over:
		_do_round_start()
		state = BattleState.TURN_LOOP
		for unit: BattleUnit in _context.turn_order:
			if _battle_over:
				break
			if not unit.alive:
				continue
			await _run_unit_turn(unit)
			if _battle_over:
				break
		if _battle_over:
			break
		state = BattleState.ROUND_END
		_do_round_end()
	state = BattleState.BATTLE_END

func _do_round_start() -> void:
	## 回合开始：回合号递增、重算行动序列（速度降序；同速我方优先→槽位序）。
	## M2 批 2 first_strike 消费（案 8 §2.5）：回合 1 且开局先手口径非 NORMAL
	## 时按阵营分组拼接（先手方全前、组内仍速度序）；回合 ≥2 维持全量重排
	## 参数：无
	## 返回：无
	_context.round_no += 1
	_context.turn_order = _context.units.filter(func(unit): return unit.alive)
	_context.turn_order.sort_custom(_CompareTurnOrder)
	if _context.round_no == 1 and _context.params != null 			and _context.params.first_strike != BattleParams.FirstStrike.NORMAL:
		var allies: Array = []
		var enemies: Array = []
		for unit: BattleUnit in _context.turn_order:
			if unit.side == SkillDef.SkillSide.ALLY:
				allies.append(unit)
			else:
				enemies.append(unit)
		_context.turn_order = enemies + allies 				if _context.params.first_strike == BattleParams.FirstStrike.ENEMY_FIRST 				else allies + enemies
	round_started.emit(_context.round_no)

func _run_unit_turn(unit: BattleUnit) -> void:
	## 单个单位行动轮：复位标记 → 控制分派（定身跳过 / 蛊惑随机 / 敌方 AI /
	## 我方等指令）→ 行动轮结束（控制锁递减 + 已行动标记）
	## 参数 unit：行动单位
	## 返回：无（协程——含等待）
	unit.reset_turn_flags()
	current_unit = unit
	_turn_done = false
	var control: int = _context.status_manager.get_active_control(unit)
	if unit.side == SkillDef.SkillSide.ALLY and control == StatusDef.ControlKind.NONE:
		awaiting_command = true
	turn_started.emit(unit)
	if control == StatusDef.ControlKind.ROOT:
		# 定身 = 完全跳过（行动轮照常结束递减控制锁）
		await _wait_delay()
	elif control == StatusDef.ControlKind.BEWITCH:
		# 蛊惑 = 自动随机行动（P3：下回合行动异常）
		run_bewitched_action(unit)
		await _wait_delay()
	elif unit.side == SkillDef.SkillSide.ENEMY:
		await _run_enemy_turn(unit)
	else:
		await _run_player_turn(unit)
	awaiting_command = false
	current_unit = null
	_context.status_manager.on_unit_turn_finished(unit)

func _run_player_turn(unit: BattleUnit) -> void:
	## 我方行动轮：等待玩家指令（request_* 轮询标记；撤退/终局即时解锁）。
	## 注意：_turn_done 在行动轮开始（turn_started 发出前）复位——信号监听方
	## （UI/测试策略）可在同步回调内直接完成指令并结束行动轮
	## 参数 unit：行动单位
	## 返回：无（协程——逐帧轮询）
	while not _turn_done and not _battle_over and is_inside_tree():
		await get_tree().process_frame

func _run_enemy_turn(unit: BattleUnit) -> void:
	## 敌方行动轮：AI 决策 → 移动 → 技能（含演出延时）；移动后单位死亡
	## （踩陷阱）即终止不再攻击（S3-01——尸体不攻击）；ctx 注入
	## status_manager 供 AI 期望伤害消费站位面板层（S3-06）
	## 参数 unit：行动单位
	## 返回：无（协程——含延时）
	var ctx: Dictionary = {
		&"cfg": _context.cfg,
		&"skill_lookup": _context.skill_lookup,
		&"status_manager": _context.status_manager,
	}
	var action := EnemyAI.decide(unit, _context.grid, _context.allies, ctx)
	if action.move_dest != EnemyAI.NO_CELL:
		_move_unit(unit, action.move_dest)
	if not unit.alive or _battle_over:
		return
	if action.skill_id != &"" and action.attack_cell != EnemyAI.NO_CELL:
		_execute_skill(unit, action.skill_id, action.attack_cell)
	unit.has_acted = true
	await _wait_delay()

# --------------------------------------------------------------------------
# 结算与判定
# --------------------------------------------------------------------------

func _move_unit(unit: BattleUnit, dest: Vector2i) -> void:
	## 单位移动：格子占位索引同步 + 标记 + 站位地格状态换格 + 信号
	## 参数 unit：单位；dest：目的地
	## 返回：无
	var from_pos: Vector2i = unit.grid_pos
	_context.grid.remove_unit(from_pos)
	unit.grid_pos = dest
	_context.grid.place_unit(dest, unit)
	unit.has_moved = true
	# 站位地格状态换格（M1 批 2 缺口补线 2026-09-24 八轮）：离格移除旧站位
	# 状态 → 新格状态施加（草丛闪避/高地面板/毒沼 DOT——敌我同权）；
	# 蛊惑随机移动走本口天然覆盖
	_context.status_manager.on_unit_moved(unit)
	var dest_tile: TileTypeDef = _context.grid.tile_at(dest)
	if _context.status_manager.apply_tile_standing(unit, dest_tile, _context.round_no):
		status_changed.emit(unit, dest_tile.status_id)
	# 陷阱触发（盲审批 1-3：ENEMY_ENTER_ONCE 动态地格踏入链——预结算伤害
	# 直扣免判定免减免 D7；仅敌对踏入触发（我方陷阱敌方踩、敌方陷阱我方踩），
	# 我方踩自家陷阱消耗与否不触发只留格（对位语义）；开局摆位不经本口不触发）
	var trap_data: Dictionary = _context.grid.dynamic_tile_at(dest)
	if not trap_data.is_empty() and dest_tile != null \
			and dest_tile.trigger == TileTypeDef.Trigger.ENEMY_ENTER_ONCE:
		var trap_source: BattleUnit = _context.find_unit(trap_data.get(&"source_id", &""))
		if trap_source != null and trap_source.side != unit.side:
			_context.grid.consume_dynamic_tile(dest)
			var trap_damage: int = int(trap_data.get(&"damage", 0))
			unit.take_damage(trap_damage)
			trap_triggered.emit(unit, trap_damage)
			if not unit.alive:
				_mark_downed(unit.unit_id)
			_check_battle_end()
	unit_moved.emit(unit, from_pos, dest)

func _execute_skill(unit: BattleUnit, skill_id: StringName, target_cell: Vector2i) -> SkillExecutor.ExecutionResult:
	## 技能执行：组装 ctx（批 1 SkillExecutor）→ 执行 → 发信号（施加/倒地）→
	## 即时全灭判定
	## 参数 unit：施放单位；skill_id：技能 id；target_cell：目标格
	## 返回：ExecutionResult
	var skill: SkillDef = _context.skill_lookup.call(skill_id) as SkillDef
	if skill == null:
		push_error("BattleController: 技能 '%s' 无法解析（%s）" % [skill_id, unit.unit_id])
		return null
	var ctx: Dictionary = {
		&"grid": _context.grid,
		&"status_manager": _context.status_manager,
		&"cfg": _context.cfg,
		&"rng": _context.rng,
		&"forced": -1,
		&"forced_crit": -1,
		&"status_lookup": _context.status_lookup,
	}
	var result = _executor.execute(unit, skill, target_cell, ctx)
	skill_executed.emit(unit, result)
	if result != null:
		for entry: StringName in result.applied_statuses:
			# 管道符契约单源解码（批 4 C 组 M2——与 SkillExecutor 生产端同源）
			var parts: PackedStringArray = _executor.parse_status_entry(entry)
			if parts.size() == 2:
				var status_target: BattleUnit = _context.find_unit(StringName(parts[0]))
				if status_target != null:
					status_changed.emit(status_target, StringName(parts[1]))
		for downed_id: StringName in result.downed_units:
			_mark_downed(downed_id)
	_check_battle_end()
	return result

func _mark_downed(unit_id: StringName) -> void:
	## 倒地处理：时序记录 + 撤出格子占位 + 信号（幂等）
	## 参数 unit_id：倒地单位 id
	## 返回：无
	if _downed_ids.has(unit_id):
		return
	_downed_ids.append(unit_id)
	var unit: BattleUnit = _context.find_unit(unit_id)
	if unit != null:
		_context.grid.remove_unit(unit.grid_pos)
		unit_downed.emit(unit)

func _do_round_end() -> void:
	## 回合末结算：批 1 StatusManager.end_of_round_tick（DOT → 递减 → 控制窗口
	## 推进，D-2 起返回 DOT 跳伤清单）→ 发 round_settled（日志/飘字消费）→
	## DOT 致倒地的占位清理与信号 → 兜底全灭判定 → 回合数护栏
	## 参数：无
	## 返回：无
	var dot_events: Array = _context.status_manager.end_of_round_tick(
			_context.round_no, _context.units, _context.rng)
	round_settled.emit(_context.round_no, dot_events)
	for unit: BattleUnit in _context.units:
		if not unit.alive:
			_mark_downed(unit.unit_id)
	_check_battle_end()
	if not _battle_over and _context.round_no >= MAX_ROUNDS:
		push_warning("BattleController: 回合数达护栏 %d，按战败收束" % MAX_ROUNDS)
		_finish_battle(BattleResult.ResultKind.DEFEAT)

func _check_battle_end() -> bool:
	## 即时全灭判定：我方全灭 → DEFEAT（同时全灭按战败）；敌方全灭 → VICTORY
	## 参数：无
	## 返回：true = 战局已收束
	if _battle_over:
		return true
	var allies_alive: bool = false
	var enemies_alive: bool = false
	for unit: BattleUnit in _context.units:
		if unit.alive:
			if unit.side == SkillDef.SkillSide.ALLY:
				allies_alive = true
			else:
				enemies_alive = true
	if not allies_alive:
		_finish_battle(BattleResult.ResultKind.DEFEAT)
		return true
	if not enemies_alive:
		_finish_battle(BattleResult.ResultKind.VICTORY)
		return true
	return false

func _finish_battle(kind: int) -> void:
	## 战局收束：组 BattleResult（回合数/终局快照/倒地名单）→ 置收束标记
	## （解锁等待循环）→ battle_ended 延迟发出
	## 参数 kind：BattleResult.ResultKind
	## 返回：无
	if _battle_over:
		return
	_battle_over = true
	_turn_done = true
	state = BattleState.BATTLE_END
	_result = BattleResult.new()
	_result.kind = kind
	_result.rounds_used = _context.round_no
	_result.downed_units = _downed_ids.duplicate()
	for unit: BattleUnit in _context.units:
		_result.end_stats.append({
			&"unit_id": unit.unit_id,
			&"end_hp": unit.current_hp,
			&"end_mana": unit.current_mana,
			&"end_stamina": unit.current_stamina,
			&"downed": not unit.alive,
		})
	battle_ended.emit.call_deferred(_result)

# --------------------------------------------------------------------------
# 辅助
# --------------------------------------------------------------------------

func _can_command() -> bool:
	## 玩家指令受理窗口判定：等待中 + 未收束 + 当前单位为我方存活
	## 参数：无
	## 返回：true = request_* 受理
	return awaiting_command and not _battle_over and current_unit != null \
			and current_unit.is_controllable()

func _auto_end_turn() -> void:
	## 行动轮自动结束（已移动 + 已行动 → 完成；玩家也可显式 request_end_unit_turn）
	## 参数：无
	## 返回：无
	if current_unit != null and current_unit.has_moved and current_unit.has_acted:
		_turn_done = true

func _hostiles_of(unit: BattleUnit) -> Array:
	## 单位的敌对单位列表（蛊惑随机攻击目标池）
	## 参数 unit：基准单位
	## 返回：敌对单位数组
	if unit.side == SkillDef.SkillSide.ALLY:
		return _context.enemies
	return _context.allies

func skip_current_delay() -> void:
	## 跳过当前演出延时（屏幕点按即跳过本段延迟——批 3 拍板 D 口径；
	## 只影响敌方/受控行动的延时等待，不改变结算）
	## 参数：无
	## 返回：无
	_delay_skip_requested = true

func _wait_delay() -> void:
	## 演出延时（delay_seconds ≤0 跳过——headless 测试注入 0；逐帧累计 + 点按跳过；
	## 离树即退——游离节点不再等待）
	## 参数：无
	## 返回：无（协程）
	if delay_seconds <= 0.0:
		return
	_delay_skip_requested = false
	var elapsed: float = 0.0
	while elapsed < delay_seconds and not _delay_skip_requested and is_inside_tree():
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_delay_skip_requested = false

func _CompareTurnOrder(a: BattleUnit, b: BattleUnit) -> bool:
	## 行动序列比较器：速度降序 → 同速我方优先 → 同阵营槽位序
	## 参数 a/b：两单位
	## 返回：true = a 排前
	var speed_a: int = a.speed_for_order()
	var speed_b: int = b.speed_for_order()
	if speed_a != speed_b:
		return speed_a > speed_b
	if a.side != b.side:
		return a.side < b.side
	return a.slot_index < b.slot_index
