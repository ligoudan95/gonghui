## 战棋 UI 流集成测试（M1 批 3，GdUnitSceneRunner；B-22 后入口改直构参数）
## 覆盖：battle_screen 经直构参数加载（BattleParams 默认 4 职业 → 场景切换）、
## 信号流冒烟（round_started/turn_started 到达——轮询式驱动到回合 2 佐证）、
## request_move 走通（我方单位移动生效）、battle_screen 直开无参优雅降级、
## 地格 hover 描述契约（特殊/障碍格 PASS + tooltip 入表文案；普通格不显示）。
## UI 视觉细节（sprite/覆盖层/结算面板观感）不测——人工验收（编辑器五条清单）。
extends GdUnitTestSuite

## 场景路径
const BATTLE_SCENE: String = "res://scenes/battle/battle_screen.tscn"
## SceneId.BATTLE_SCREEN（B-22：调试入口拆除——测试直构参数进战斗屏）
const SCENE_BATTLE: int = 2
## 信号等待帧上限（超时防死等）
const MAX_WAIT_FRAMES: int = 300

func before_test() -> void:
	## 用例前置：复位 SceneManager 可变状态（autoload 归引擎管理不释放）
	## 参数：无
	## 返回：无
	var scene_manager: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_object(scene_manager).is_not_null()
	scene_manager.current_id = -1
	scene_manager.previous_id = -1
	var no_params: Dictionary = {}
	scene_manager.pending_params = no_params

func _EnterRandomBattle() -> void:
	## B-22：公会壳调试入口拆除——直构 BattleParams（默认 4 职业，等价原
	## 调试链路）经 SceneManager 进 BATTLE_SCREEN
	## 参数：无
	## 返回：无（协程——等场景切换落地）
	var game_data: Node = get_tree().root.get_node("GameData")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var party: Array[AdventurerData] = []
	for pair: Array in [[&"warrior", &"cls_warrior"], [&"rogue", &"cls_rogue"],
			[&"mage", &"cls_mage"], [&"priest", &"cls_priest"]]:
		var cls: ClassDef = game_data.get_record(pair[1]) as ClassDef
		var attrs: Dictionary[StringName, int] = AttrRoller.roll_fixed_four(cls, rng)
		party.append(AdventurerData.create_debug(pair[0], pair[1], attrs, game_data))
	var params := BattleParams.new()
	params.pack_id = &"enc_m1_random_pack"
	params.party = party
	get_tree().root.get_node("SceneManager").go(SCENE_BATTLE,
			{&"battle_params": params})
	await _AwaitSceneSwap()

func test_battle_entry_opens_battle_screen() -> void:
	## 入口全链路：直构参数（默认 4 职业）→ BATTLE_SCREEN 挂载 +
	## 战斗装配成立（徽章/上下文/控制器就绪）
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	assert_object(battle.controller).is_not_null()
	assert_object(battle.context).is_not_null()
	assert_int(battle.context.allies.size()).is_equal(4)
	assert_int(battle.context.enemies.size()).is_equal(3)
	# 徽章池已建（我方 4 + 敌方 3）
	battle.controller.delay_seconds = 0.0
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	assert_int(board.get_children().filter(func(child): return child is UnitBadge).size()).is_equal(7)
	battle.controller.abort_battle()

func test_signal_flow_and_request_move() -> void:
	## 信号流冒烟 + 指令走通：调试入口进战斗 → 轮询等首轮我方指令窗 →
	## 连接信号 → 自动打完整回合（我方全部结束行动轮）→ 回合 2 的
	## round_started 到达佐证信号流；随后 request_move 生效（单位位置变更）
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	# 轮询等首个我方指令窗（战斗在 _ready 同步开战——round 1 信号早于本处连接，
	# 以回合 2 的信号到达为冒烟断言）
	var waited: int = 0
	while (battle.controller.current_unit == null \
			or not battle.controller.awaiting_command) and waited < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
	assert_bool(battle.controller.awaiting_command).is_true()
	var events: Dictionary = {&"round2": false, &"turn": false}
	battle.controller.round_started.connect(func(round_no: int) -> void:
		if round_no >= 2:
			events[&"round2"] = true)
	battle.controller.turn_started.connect(func(_unit: BattleUnit) -> void:
		events[&"turn"] = true)
	# 自动打完回合 1 与回合 2 的我方轮（敌方轮自动推进），直到回合 2 信号到达
	waited = 0
	while not events[&"round2"] and waited < MAX_WAIT_FRAMES:
		if battle.controller.awaiting_command:
			battle.controller.request_end_unit_turn()
		await get_tree().process_frame
		waited += 1
	assert_bool(events[&"round2"]).is_true()
	assert_bool(events[&"turn"]).is_true()
	# 回合 2 首个我方指令窗：request_move 走通（可达格 → 位置变更）
	waited = 0
	while not battle.controller.awaiting_command and waited < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
	var unit: BattleUnit = battle.controller.current_unit
	assert_object(unit).is_not_null()
	var reachable: Array[Vector2i] = battle.context.grid.find_reachable(unit, unit.move_final())
	assert_int(reachable.size()).is_greater(0)
	var dest: Vector2i = reachable[0]
	assert_bool(battle.controller.request_move(dest)).is_true()
	assert_int(unit.grid_pos.x).is_equal(dest.x)
	assert_int(unit.grid_pos.y).is_equal(dest.y)
	battle.controller.abort_battle()

func test_degraded_run_interaction_guards() -> void:
	## 降级路径交互守卫（盲审批 1-6：无参直开 context 为 null——按钮 handler
	## 直调不崩、板面坐标换算返回界外哨兵、四钮统一禁用、板面不接鼠标；
	## S5-2：撤退钮改「返回公会壳」保留降级出口——不再禁用，文案对齐）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	assert_object(battle.context).is_null()
	battle._on_attack_button_pressed()
	battle._on_end_turn_button_pressed()
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	assert_vector(board.cell_from_local(Vector2(100, 100))).is_equal(Vector2i(-1, -1))
	assert_int(board.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	for button_name: String in ["%AttackButton", "%SkillButtonA", "%SkillButtonB",
			"%EndTurnButton"]:
		assert_bool((battle.get_node(button_name) as Button).disabled) \
				.override_failure_message("降级路径 %s 未禁用" % button_name).is_true()
	# S5-2：撤退钮保留可用且文案 = 返回公会壳（降级出口）
	var retreat_button: Button = battle.get_node("%RetreatButton") as Button
	assert_bool(retreat_button.disabled) \
			.override_failure_message("降级路径撤退钮应保留降级出口").is_false()
	assert_str(retreat_button.text).is_equal("返回公会壳")

func test_battle_screen_direct_load_smoke() -> void:
	## 直开冒烟：无跨场景参数 → 优雅降级（IdleLabel 提示、不开战不崩溃）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	assert_object(battle.context).is_null()
	var idle: Label = battle.get_node("%IdleLabel") as Label
	assert_object(idle).is_not_null()
	assert_bool(idle.visible).is_true()

func test_tile_tooltip_contract() -> void:
	## 地格 hover 描述契约（2026-09-24 试玩反馈）：特殊/障碍格 PASS + tooltip
	## （地格名 + 效果描述——文案取 tile 表 description，铁律①零硬编码）；
	## 普通格 IGNORE 不显示（避免打扰）
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	# 特殊/障碍格：PASS（参与命中冒泡回 BoardLayer）+ tooltip 含名与效果语义
	var expects: Dictionary = {
		Vector2i(5, 2): ["草丛", "闪避"],
		Vector2i(5, 3): ["高地", "×1.2"],
		Vector2i(4, 5): ["毒沼", "毒伤"],
		Vector2i(2, 2): ["障碍", "不可通行"],
	}
	for cell: Vector2i in expects:
		var visual: Control = board.cell_visual(cell)
		assert_object(visual).is_not_null()
		assert_int(visual.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
		assert_str(visual.tooltip_text).is_not_empty()
		assert_bool(visual.tooltip_text.contains(expects[cell][0])) \
				.override_failure_message("格 (%d,%d) tooltip 缺地格名" % [cell.x, cell.y]).is_true()
		assert_bool(visual.tooltip_text.contains(expects[cell][1])) \
				.override_failure_message("格 (%d,%d) tooltip 缺效果语义" % [cell.x, cell.y]).is_true()
	# 普通格：IGNORE + 无 tooltip（不显示，避免打扰）
	var plain: Control = board.cell_visual(Vector2i(0, 0))
	assert_object(plain).is_not_null()
	assert_int(plain.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_str(plain.tooltip_text).is_empty()
	battle.controller.abort_battle()

func test_skill_button_tooltip_contract() -> void:
	## 技能按钮 hover 描述契约（2026-09-24 二轮反馈）：首个我方指令窗内
	## 普攻钮 tooltip 含消耗/射程/预计伤害行（数值走 §3.4 同源公式，文案入表）
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var waited: int = 0
	while not battle.controller.awaiting_command and waited < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
	assert_bool(battle.controller.awaiting_command).is_true()
	var attack_button: Button = battle.get_node("%AttackButton") as Button
	assert_str(attack_button.tooltip_text).is_not_empty()
	assert_bool(attack_button.tooltip_text.contains("消耗：")) \
			.override_failure_message("普攻钮 tooltip 缺消耗行").is_true()
	assert_bool(attack_button.tooltip_text.contains("射程：")) \
			.override_failure_message("普攻钮 tooltip 缺射程行").is_true()
	assert_bool(attack_button.tooltip_text.contains("预计伤害：")) \
			.override_failure_message("普攻钮 tooltip 缺预计伤害行").is_true()
	battle.controller.abort_battle()

func test_action_bar_refresh_after_skill_executed() -> void:
	## 技能后按钮组重刷契约（2026-09-24 三轮反馈）：经 skill_executed 信号路径
	## （帧末 deferred——真实时序下信号发射时 has_acted 尚未置位）——行动权
	## 耗尽后普攻/技能钮置灰、行动结束/撤退保持可用（不写死全灰）；
	## 未行动时技能钮可用（防过度置灰回归）
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var waited: int = 0
	while not battle.controller.awaiting_command and waited < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
	assert_bool(battle.controller.awaiting_command).is_true()
	var unit: BattleUnit = battle.controller.current_unit
	assert_object(unit).is_not_null()
	var attack_button: Button = battle.get_node("%AttackButton") as Button
	var skill_a: Button = battle.get_node("%SkillButtonA") as Button
	var end_button: Button = battle.get_node("%EndTurnButton") as Button
	var retreat_button: Button = battle.get_node("%RetreatButton") as Button
	# 未行动：技能钮与结束/撤退全部可用（防过度置灰回归）
	assert_bool(attack_button.disabled).is_false()
	assert_bool(end_button.disabled).is_false()
	assert_bool(retreat_button.disabled).is_false()
	# 模拟技能成功路径（同 request_skill 内部时序：发射信号时 has_acted 手动
	# 先行置位仅为断言前置——刷新经 deferred 帧末落定）
	unit.has_acted = true
	var result := SkillExecutor.ExecutionResult.new()
	result.success = true
	battle.controller.skill_executed.emit(unit, result)
	await get_tree().process_frame
	await get_tree().process_frame
	# 行动权耗尽：普攻/技能钮置灰；行动结束/撤退保持可用（用户拍板口径）
	assert_bool(attack_button.disabled).is_true()
	assert_bool(skill_a.disabled).is_true()
	assert_bool((battle.get_node("%SkillButtonB") as Button).disabled).is_true()
	assert_bool(end_button.disabled).is_false()
	assert_bool(retreat_button.disabled).is_false()
	battle.controller.abort_battle()

func test_self_skill_tooltip_hides_range() -> void:
	## SELF 技能 tooltip 契约（2026-09-24 七轮反馈）：自身施法技（盾墙/疾步）
	## 不标「射程 1」防误导；ENEMY 攻击技（火球）保持射程显示——直调拼装
	## 函数喂真实技能表断言（直开降级路径，无需装配战斗）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	var unit := BattleUnit.new()
	unit.attrs = {&"intelligence": 16, &"perception": 11, &"agility": 16, &"luck": 13}
	unit.weapon_bonus = 2
	var shield_wall: SkillDef = load("res://data/class/skills/skl_warrior_shield_wall.tres") as SkillDef
	var sprint: SkillDef = load("res://data/class/skills/skl_rogue_sprint.tres") as SkillDef
	var fireball: SkillDef = load("res://data/class/skills/skl_mage_fireball.tres") as SkillDef
	assert_int(shield_wall.target_side).is_equal(SkillDef.TargetSide.SELF)
	assert_int(sprint.target_side).is_equal(SkillDef.TargetSide.SELF)
	assert_bool(battle._SkillTooltip(unit, shield_wall).contains("射程")) \
			.override_failure_message("SELF 技盾墙 tooltip 不应含射程").is_false()
	assert_bool(battle._SkillTooltip(unit, sprint).contains("射程")) \
			.override_failure_message("SELF 技疾步 tooltip 不应含射程").is_false()
	assert_bool(battle._SkillTooltip(unit, fireball).contains("射程：5")) \
			.override_failure_message("ENEMY 技火球 tooltip 应含射程：5").is_true()

func test_out_of_range_tap_keeps_selection() -> void:
	## 超射程点击契约（2026-09-24 八轮反馈）：技能模式下点射程外存活敌格
	## → 选择保留 + 日志提示（不再静默取消——「像没打中」的反馈缺失）；
	## 点纯空区域维持原取消语义
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var waited: int = 0
	while not battle.controller.awaiting_command and waited < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
	assert_bool(battle.controller.awaiting_command).is_true()
	# 进入技能模式（普攻 range 1）
	(battle.get_node("%AttackButton") as Button).pressed.emit()
	assert_str(String(battle._selected_skill_id)).is_not_empty()
	# 点射程外的存活敌格（出生区 y0/y7 分立，任意敌格必超 range 1）→ 选择保留
	var far_enemy: BattleUnit = null
	for enemy: BattleUnit in battle.context.enemies:
		if enemy.alive:
			far_enemy = enemy
			break
	assert_object(far_enemy).is_not_null()
	battle._HandleSkillTap(far_enemy.grid_pos)
	assert_str(String(battle._selected_skill_id)).is_not_empty() \
			.override_failure_message("超射程点击不应清技能选择")
	# 点纯空区域（无单位）→ 维持取消语义
	battle._HandleSkillTap(Vector2i(0, 3))
	assert_str(String(battle._selected_skill_id)).is_empty()
	battle.controller.abort_battle()

func test_target_tips_contract() -> void:
	## 目标确认 tips 契约（2026-09-24 九轮反馈）：点中射程内敌格 → tips 弹出
	## 含「预计伤害/命中率」（数值与 BattleRules 链同源复算一致——减免后
	## 伤害 + 含站位状态命中）；面板 IGNORE 不遮点击；点空格取消 → tips
	## 与选择态同步清理
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var waited: int = 0
	while not battle.controller.awaiting_command and waited < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
	assert_bool(battle.controller.awaiting_command).is_true()
	# 传送当前单位到存活敌方相邻空格（出生区分立，需贴身测普攻射程 1）
	var unit: BattleUnit = battle.controller.current_unit
	var enemy: BattleUnit = null
	for candidate: BattleUnit in battle.context.enemies:
		if candidate.alive:
			enemy = candidate
			break
	assert_object(enemy).is_not_null()
	var dest: Vector2i = Vector2i(-1, -1)
	for offset: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var near: Vector2i = enemy.grid_pos + offset
		if battle.context.grid.get_unit_at(near) == null:
			dest = near
			break
	assert_bool(dest != Vector2i(-1, -1)).is_true()
	battle.context.grid.remove_unit(unit.grid_pos)
	unit.grid_pos = dest
	battle.context.grid.place_unit(dest, unit)
	# 进入技能模式（普攻）→ 点敌方目标格
	(battle.get_node("%AttackButton") as Button).pressed.emit()
	battle._HandleSkillTap(enemy.grid_pos)
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	assert_bool(board.is_target_tips_visible()).is_true()
	var tips: String = board.target_tips_text()
	assert_bool(tips.contains("预计伤害")).is_true()
	assert_bool(tips.contains("命中率")).is_true()
	# 数值同源：tips 数字 == _ExpectedDamageOn（减免后链）== BattleRules 复算命中率
	var attack: SkillDef = battle.context.skill_lookup.call(unit.base_attack_id) as SkillDef
	assert_bool(tips.contains("预计伤害 %d" % battle._ExpectedDamageOn(unit, enemy, attack))) \
			.is_true()
	var hit_pct: int = roundi(BattleRules.hit_chance(unit.hit, enemy.dodge,
			attack.hit_mod, battle.context.cfg) * 100.0)
	assert_bool(tips.contains("命中率 %d%%" % hit_pct)).is_true()
	# 纯展示契约：面板 IGNORE（不遮目标格再次点击确认）
	assert_int(board.target_tips_panel().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	# z 序契约（九轮后修复）：tips 显示后触发覆盖层重建（confirm 进专用容器）
	# ——tips 仍恒高于覆盖层容器（容器内全部 holder 的 z 序随容器整体低于
	# tips；headless 下 z 序 = 子节点序可测）
	battle._HandleSkillTap(enemy.grid_pos)
	var overlay_layer: Control = board.get_node_or_null("OverlayLayer") as Control
	assert_object(overlay_layer).is_not_null()
	assert_int(overlay_layer.get_child_count()).is_greater(0)
	assert_int(board.target_tips_panel().get_index()).is_greater(overlay_layer.get_index()) \
			.override_failure_message("tips 未恒压覆盖层容器之上")
	# 取消路径：点纯空格 → tips 与技能选择态同步清理
	battle._HandleSkillTap(Vector2i(0, 3))
	assert_bool(board.is_target_tips_visible()).is_false()
	assert_str(String(battle._selected_skill_id)).is_empty()
	battle.controller.abort_battle()

func test_los_blocked_range_rendering_and_tap() -> void:
	## 视线阻断契约（2026-09-24 十四轮反馈）：①范围分组渲染——caster (0,2)
	## 视线通格红显（无标记）、断格（障碍 (2,2) 后方 (3-5,2)）带 los_blocked
	## 元标记 + 斜杠子节点；②点断格不进确认态（_pending_cell 保持哨兵）+
	## 选择态保留；点通格正常进确认
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var waited: int = 0
	while not battle.controller.awaiting_command and waited < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
	assert_bool(battle.controller.awaiting_command).is_true()
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	# caster 传送到 (0,2)（障碍 (2,2) 正西向视线阻断——同行路径必经）
	var unit: BattleUnit = battle.controller.current_unit
	battle.context.grid.remove_unit(unit.grid_pos)
	unit.grid_pos = Vector2i(0, 2)
	battle.context.grid.place_unit(Vector2i(0, 2), unit)
	# ①分组渲染：los_required = true（射程 > 1 口径；先清层对齐 _EnterSkillMode
	# 真实流程——行动轮开始的移动范围覆盖不参与本断言）
	var cells: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(3, 2),
			Vector2i(4, 2), Vector2i(5, 2)]
	board.clear_overlays()
	board.show_skill_range(cells, Vector2i(0, 2), true)
	var layer: Control = board.get_node("OverlayLayer") as Control
	var blocked_cells: Array[Vector2i] = []
	var visible_cells: Array[Vector2i] = []
	for holder: Node in layer.get_children():
		if holder.is_queued_for_deletion():
			continue
		var cell: Vector2i = board.cell_from_local((holder as Control).position)
		if holder.get_meta(&"los_blocked", false):
			blocked_cells.append(cell)
			# 斜杠标记存在（旋转子节点）
			var has_slash: bool = false
			for child: Node in holder.get_children():
				if child is ColorRect and (child as ColorRect).rotation != 0.0:
					has_slash = true
			assert_bool(has_slash) \
					.override_failure_message("断格 (%d,%d) 缺斜杠标记" % [cell.x, cell.y]).is_true()
		else:
			visible_cells.append(cell)
	assert_int(blocked_cells.size()).is_equal(3)
	assert_int(visible_cells.size()).is_equal(2)
	for blocked: Vector2i in [Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)]:
		assert_bool(blocked_cells.has(blocked)).is_true()
	for visible: Vector2i in [Vector2i(0, 2), Vector2i(1, 2)]:
		assert_bool(visible_cells.has(visible)).is_true()
	# ②点断格：不进确认态 + 选择保留（预置火球 range 5 技能模式）
	battle._selected_skill_id = &"skl_mage_fireball"
	battle._skill_range_cells = cells
	battle._HandleSkillTap(Vector2i(5, 2))
	assert_vector(battle._pending_cell).is_equal(battle.NO_CELL) \
			.override_failure_message("断格不应进入确认态")
	assert_str(String(battle._selected_skill_id)).is_not_empty()
	# 点通格：正常进确认态
	battle._HandleSkillTap(Vector2i(1, 2))
	assert_vector(battle._pending_cell).is_equal(Vector2i(1, 2))
	# M5 单源一致：UI 判定与 SkillExecutor.los_required 对同一技能恒一致
	var fireball: SkillDef = load("res://data/class/skills/skl_mage_fireball.tres") as SkillDef
	assert_bool(battle._LosRequiredOf(&"skl_mage_fireball") == SkillExecutor.los_required(fireball)) \
			.override_failure_message("UI 与执行器 LOS 口径应同源").is_true()
	var melee: SkillDef = load("res://data/class/skills/skl_atk_warrior.tres") as SkillDef
	assert_bool(battle._LosRequiredOf(&"skl_atk_warrior") == SkillExecutor.los_required(melee)) \
			.is_true()
	battle.controller.abort_battle()

func test_target_tips_hidden_on_target_switch() -> void:
	## 换目标 tips 不残留（盲审批 3 D-3）：进确认态（tips 显示）后点射程内
	## 空格（无可显示数据的新目标位）→ tips 立即隐藏且不残留旧目标数据；
	## 再点敌方目标格 → tips 重新显示（换目标 show 正常）；断格路径同理隐藏
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var waited: int = 0
	while not battle.controller.awaiting_command and waited < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
	assert_bool(battle.controller.awaiting_command).is_true()
	# 传送当前单位到存活敌方相邻空格（贴身测普攻射程 1）
	var unit: BattleUnit = battle.controller.current_unit
	var enemy: BattleUnit = null
	for candidate: BattleUnit in battle.context.enemies:
		if candidate.alive:
			enemy = candidate
			break
	assert_object(enemy).is_not_null()
	var dest: Vector2i = Vector2i(-1, -1)
	for offset: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var near: Vector2i = enemy.grid_pos + offset
		if battle.context.grid.get_unit_at(near) == null:
			dest = near
			break
	assert_bool(dest != Vector2i(-1, -1)).is_true()
	battle.context.grid.remove_unit(unit.grid_pos)
	unit.grid_pos = dest
	battle.context.grid.place_unit(dest, unit)
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	# ①进确认态：点敌方目标格 → tips 显示
	(battle.get_node("%AttackButton") as Button).pressed.emit()
	battle._HandleSkillTap(enemy.grid_pos)
	assert_bool(board.is_target_tips_visible()).is_true()
	# ②换目标点射程内空格（自身普攻射程 1 内、非目标格的空位）：无可显示
	## 数据 → tips 隐藏（D-3 前旧 tips 残留在旧目标格上）
	var empty_neighbor: Vector2i = Vector2i(-1, -1)
	for offset: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var near: Vector2i = dest + offset
		if near != enemy.grid_pos and battle.context.grid.get_unit_at(near) == null \
				and battle._skill_range_cells.has(near):
			empty_neighbor = near
			break
	assert_bool(empty_neighbor != Vector2i(-1, -1)).is_true()
	battle._HandleSkillTap(empty_neighbor)
	assert_bool(board.is_target_tips_visible()) \
			.override_failure_message("点射程内空格后旧目标 tips 不应残留").is_false()
	# ③再点敌方目标格：tips 重新显示（换目标 show 正常）
	battle._HandleSkillTap(enemy.grid_pos)
	assert_bool(board.is_target_tips_visible()).is_true()
	battle.controller.abort_battle()

func test_batch_a_table_driven_contract() -> void:
	## 批 A 表驱动链路契约（H1/H2/H3）：①地格渲染读表——改 fill_color 重建
	## 即变（表驱动零改码）；②sprite 读取链——_SpriteIdOf（查表）→ _TextureOf
	## （registry→load）非空；③UI 预计伤害与执行链同源同值（undead 惩击 ×1.5）
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var game_data: Node = get_tree().root.get_node("GameData")
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	# ①表驱动渲染：草丛表改红 → 重建 → 渲染色 == 表值；恢复再断回原色
	var grass_tile: TileTypeDef = game_data.get_record(&"tile_grass") as TileTypeDef
	var original_fill: Color = grass_tile.fill_color
	grass_tile.fill_color = Color(1.0, 0.2, 0.2, 1.0)
	board._BuildCells()
	var cell_rect: ColorRect = board.cell_visual(Vector2i(5, 2)) as ColorRect
	assert_bool(cell_rect != null).is_true()
	assert_bool(cell_rect.color.is_equal_approx(Color(1.0, 0.2, 0.2, 1.0))) \
			.override_failure_message("改表色后渲染未跟随：%s" % cell_rect.color).is_true()
	grass_tile.fill_color = original_fill
	board._BuildCells()
	assert_bool((board.cell_visual(Vector2i(5, 2)) as ColorRect).color \
			.is_equal_approx(original_fill)).is_true()
	# ②sprite 表驱动读取链（B-18：薄壳已删——直呼 SpriteResolver 单源）：
	# 查表 id → registry 路径 → load 纹理非空
	var ally: BattleUnit = battle.context.allies[0]
	var game_data_node: Node = get_tree().root.get_node("GameData")
	var texture: Texture2D = SpriteResolver.texture_of(
			SpriteResolver.sprite_id_of(ally, game_data_node), game_data_node)
	assert_object(texture).is_not_null()
	# ③UI/执行器同源同值（H1）：手造 undead 目标，UI 值 == 单源链复算
	var smite: SkillDef = game_data.get_record(&"skl_priest_smite") as SkillDef
	var fake_undead := BattleUnit.new()
	fake_undead.race_tag = &"undead"
	var race_mult: float = SkillExecutor.collect_race_mult(smite, &"undead")
	assert_float(race_mult).is_equal_approx(1.5, 0.001)
	var panel_mult: float = SkillExecutor.panel_mult_of(ally, battle.context.status_manager)
	var chain_value: int = BattleRules.mitigate(BattleRules.raw_panel_damage(ally.attrs,
			ally.weapon_bonus, smite, panel_mult, race_mult),
			fake_undead.mag_resist, fake_undead.mag_armor, ally.mag_pierce,
			battle.context.cfg)
	assert_int(battle._ExpectedDamageOn(ally, fake_undead, smite)).is_equal(chain_value)
	battle.controller.abort_battle()

func _AwaitSceneSwap() -> void:
	## 等待场景切换落地（change_scene_to_packed 延迟切换，让过两帧——M0 惯例）
	## 参数：无
	## 返回：无（协程）
	await get_tree().process_frame
	await get_tree().process_frame

func test_ally_skill_tap_on_enemy_rejected() -> void:
	## 治疗技点敌方格（S4-1）：ALLY 技点敌方单位格 → 不进确认态（pending
	## 保持哨兵）+ 日志「目标非法」提示；恒 false 死代码已删（敌方分支内
	## 直接拦截）
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var waited: int = 0
	while not battle.controller.awaiting_command and waited < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
	assert_bool(battle.controller.awaiting_command).is_true()
	# 牧师行动轮（等待到牧师回合——治疗技持有者）
	var priest_turn: bool = false
	waited = 0
	while not priest_turn and waited < MAX_WAIT_FRAMES * 4:
		if battle.controller.awaiting_command \
				and battle.controller.current_unit != null \
				and battle.controller.current_unit.skill_ids.has(&"skl_priest_heal"):
			priest_turn = true
			break
		if battle.controller.awaiting_command:
			battle.controller.request_end_unit_turn()
		await get_tree().process_frame
		waited += 1
	assert_bool(priest_turn).override_failure_message("未等到牧师行动轮").is_true()
	var priest: BattleUnit = battle.controller.current_unit
	# 传送牧师到敌方旁贴身（治疗射程 5 内直接点敌格亦可——用贴身保证射程内）
	var enemy: BattleUnit = null
	for candidate: BattleUnit in battle.context.enemies:
		if candidate.alive:
			enemy = candidate
			break
	assert_object(enemy).is_not_null()
	# 传送牧师贴身（保证敌格在治疗射程内——点敌格走射程内分支才可验证 S4-1）
	var near_cell: Vector2i = Vector2i(-1, -1)
	for offset: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var near: Vector2i = enemy.grid_pos + offset
		if battle.context.grid.get_unit_at(near) == null:
			near_cell = near
			break
	assert_bool(near_cell != Vector2i(-1, -1)).is_true()
	battle.context.grid.remove_unit(priest.grid_pos)
	priest.grid_pos = near_cell
	battle.context.grid.place_unit(near_cell, priest)
	# 进入治疗技选择模式（skill_ids[1] = 档 1 首技——按装配序含治疗）
	var heal_slot: int = -1
	for index: int in priest.skill_ids.size():
		var skill: SkillDef = battle.context.skill_lookup.call(priest.skill_ids[index]) as SkillDef
		if skill != null and skill.target_side == SkillDef.TargetSide.ALLY:
			heal_slot = index
			break
	assert_int(heal_slot).is_greater(0)
	battle._EnterSkillMode(priest.skill_ids[heal_slot])
	assert_str(String(battle._selected_skill_id)).is_not_empty()
	# 点敌方目标格：不进确认态（哨兵）——治疗技敌方格拦截
	battle._HandleSkillTap(enemy.grid_pos)
	assert_vector(battle._pending_cell).is_equal(battle.NO_CELL) \
			.override_failure_message("ALLY 技点敌格不应进确认态")
	assert_str(String(battle._selected_skill_id)).is_not_empty()
	battle.controller.abort_battle()

func test_attack_button_toggles_and_move_after_action() -> void:
	## 普攻钮 toggle（S4-7）+ 行动后仍可移动（S3-03 UI）：普攻钮再点取消
	## 回移动范围；已行动后移动范围照常显示（has_moved 短路才隐藏路径预览）
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var waited: int = 0
	while not battle.controller.awaiting_command and waited < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
	assert_bool(battle.controller.awaiting_command).is_true()
	var unit: BattleUnit = battle.controller.current_unit
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	# ①普攻钮 toggle：首点进技能模式、再点取消回移动范围
	(battle.get_node("%AttackButton") as Button).pressed.emit()
	assert_str(String(battle._selected_skill_id)).is_not_empty()
	(battle.get_node("%AttackButton") as Button).pressed.emit()
	assert_str(String(battle._selected_skill_id)).is_empty() \
			.override_failure_message("普攻钮再点应取消选择（S4-7）")
	# R5-07：取消后移动范围照常显示（_RestoreMoveRangeIfUsable 生效）
	assert_int(board._move_overlays.size()).is_greater(0) \
			.override_failure_message("取消选择后应回显移动范围（R3-05/R5-07）")
	# ②行动后仍可移动（S3-03）：置 has_acted 后 request_move 仍受理
	unit.has_acted = true
	var reachable: Array[Vector2i] = battle.context.grid.find_reachable(unit, unit.move_final())
	assert_int(reachable.size()).is_greater(0)
	assert_bool(battle.controller.request_move(reachable[0])).is_true() \
			.override_failure_message("行动后移动应受理（S3-03 顺序任意）")
	assert_bool(unit.has_moved).is_true()
	battle.controller.abort_battle()


func _AwaitFirstCommandWindow(battle: Control) -> BattleUnit:
	## 辅助：轮询等待首个我方指令窗（战斗 _ready 同步开战），返回行动单位
	## 参数 battle：战斗屏
	## 返回：当前行动单位（超时 null——由调用方断言）
	var waited: int = 0
	while (battle.controller.current_unit == null \
			or not battle.controller.awaiting_command) and waited < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		waited += 1
	return battle.controller.current_unit

func _FarEmptyCell(battle: Control, unit: BattleUnit) -> Vector2i:
	## 辅助：取界内「不可达且无占位」空格（取消路径测试的噪音点击目标）
	## 参数 battle：战斗屏；unit：行动单位
	## 返回：格坐标（找不到返回 (-1,-1)——由调用方断言）
	var reachable: Array[Vector2i] = battle.context.grid.find_reachable(unit, unit.move_final())
	for y: int in battle.context.grid.size.y:
		for x: int in battle.context.grid.size.x:
			var cell: Vector2i = Vector2i(x, y)
			if not reachable.has(cell) and battle.context.grid.get_unit_at(cell) == null:
				return cell
	return Vector2i(-1, -1)

func test_first_turn_move_range_shown_at_battle_start() -> void:
	## 反馈②③修复锚①（开局首单位显示断言）：进战斗 → 首个指令窗即盗贼
	## （敏捷 15-17 全场最快——速度排序排第一）→ 移动范围覆盖层已画且
	## 数量 == find_reachable（渲染链 _OnTurnStarted→show_move_range 无丢失）
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var unit: BattleUnit = await _AwaitFirstCommandWindow(battle)
	assert_object(unit).is_not_null()
	assert_str(String(unit.unit_id)).is_equal("rogue") \
			.override_failure_message("盗贼敏捷全场最高应排行动首位")
	assert_bool(unit.is_controllable()).is_true()
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	var reachable: Array[Vector2i] = battle.context.grid.find_reachable(unit, unit.move_final())
	assert_int(reachable.size()).is_greater(0)
	assert_int(board._move_overlays.size()).is_equal(reachable.size()) \
			.override_failure_message("开局首单位移动范围应完整显示")
	battle.controller.abort_battle()

func test_move_range_restored_after_cancel_taps() -> void:
	## 反馈②③修复锚②（取消后回显——R3-05 口径扩展）：指令窗内三类取消路径
	## （点不可达空格 / 出格点按 / 技能模式点空区域）均回显移动范围——
	## 「跳过演出」连点漏入指令窗不再永久隐藏范围层
	await _EnterRandomBattle()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var unit: BattleUnit = await _AwaitFirstCommandWindow(battle)
	assert_object(unit).is_not_null()
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	var far_cell: Vector2i = _FarEmptyCell(battle, unit)
	assert_vector(far_cell).is_not_equal(Vector2i(-1, -1))
	# ①点不可达空格 = 取消：范围层回显（修复前被单向清空）
	battle._HandleMoveTap(far_cell)
	assert_vector(battle._pending_cell).is_equal(battle.NO_CELL)
	assert_int(board._move_overlays.size()).is_greater(0) \
			.override_failure_message("点不可达空格取消后应回显移动范围")
	# ②路径预览后再点不可达空格 = 取消预览：范围层回显
	var reachable: Array[Vector2i] = battle.context.grid.find_reachable(unit, unit.move_final())
	battle._HandleMoveTap(reachable[0])
	assert_vector(battle._pending_cell).is_equal(reachable[0])
	battle._HandleMoveTap(far_cell)
	assert_vector(battle._pending_cell).is_equal(battle.NO_CELL)
	assert_int(board._move_overlays.size()).is_greater(0) \
			.override_failure_message("取消路径预览后应回显移动范围")
	# ③出格点按（跳过连点漏入指令窗的典型落点）= 取消：范围层回显
	var out_event := InputEventMouseButton.new()
	out_event.button_index = MOUSE_BUTTON_LEFT
	out_event.pressed = true
	out_event.position = Vector2(-64.0, -64.0)
	battle._on_board_gui_input(out_event)
	assert_int(board._move_overlays.size()).is_greater(0) \
			.override_failure_message("出格点按取消后应回显移动范围")
	# ④技能模式点纯空区域 = 取消技能：回移动范围（与按钮取消同口径）
	battle._EnterSkillMode(unit.base_attack_id)
	assert_str(String(battle._selected_skill_id)).is_not_empty()
	battle._HandleSkillTap(far_cell)
	assert_str(String(battle._selected_skill_id)).is_empty()
	assert_int(board._move_overlays.size()).is_greater(0) \
			.override_failure_message("技能模式取消后应回显移动范围")
	# ⑤技执行后（已行动未移动——S3-03 仍可移动）：帧末刷新回显范围
	unit.has_acted = true
	battle._RefreshActionBarForCurrentTurn()
	assert_int(board._move_overlays.size()).is_greater(0) \
			.override_failure_message("技执行后未移动应回显移动范围（S3-03）")
	battle.controller.abort_battle()


func test_degraded_exit_releases_expedition_lock() -> void:
	## X2-M1（M3 质检）：return_to=EVENT_SCREEN 但装配降级（无 battle_params）——
	## 「返回公会壳」前置 _return_to=-1，锁随 _exit_tree 释放
	## （防回会话口径跳过解锁——锁卡 true 跳过全部 autosave）
	var save_manager: Node = get_tree().root.get_node("SaveManager")
	save_manager.set_expedition_lock(true)
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	scene_manager.go(SCENE_BATTLE, {&"return_to": 3})
	await _AwaitSceneSwap()
	var battle: Control = get_tree().current_scene as Control
	assert_object(battle).is_not_null()
	assert_object(battle.context).is_null()
	# 降级路径已按回会话口径接管锁
	assert_bool(save_manager._expedition_lock).is_true()
	# 降级「返回公会壳」→ 锁释放（X2-M1 修复前此处卡 true）
	battle._on_retreat_button_pressed()
	await _AwaitSceneSwap()
	assert_bool(save_manager._expedition_lock).is_false()
