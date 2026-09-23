## 战斗场景根（battle_screen，Control）
## 职责：战棋 UI 主控——读跨场景参数装配战斗（BattleSetup → BattleController）、
## 单向数据流（玩家输入 → controller.request_* → controller 信号 → UI 刷新）、
## 两段式确认交互（选中→高亮→点目标预览→再点确认；取消=点其他区域/再点钮）、
## 技能按钮态（资源不足灰显）、蛊惑紫边提示、敌方延时点按跳过、撤退确认弹窗、
## 结算面板路由回公会壳。
## 数据来源：M1 批 3 方案 §7.1/§7.3（交互模型拍板口径）。
## 单例访问：统一 get_node("/root/X")（gdUnit 测试环境不注册 autoload 标识符）。
extends Control

## SceneManager 脚本常量引用（枚举常量不可经实例属性访问，见 title_screen.gd 注）
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")
## 二段式确认「无待确认」哨兵
const NO_CELL: Vector2i = Vector2i(-9, -9)

## 战斗上下文（装配后供测试/UI 查询）
var context: BattleSetup.BattleContext = null
## 控制器（场景内 BattleController 节点）
var controller: BattleController = null
## GameData 单例引用
var _game_data: Node = null
## 当前技能选择（&"" = 移动模式）
var _selected_skill_id: StringName = &""
## 技能选择模式下的范围格集
var _skill_range_cells: Array[Vector2i] = []
## 两段式确认待定格
var _pending_cell: Vector2i = NO_CELL

func _ready() -> void:
	## 引擎回调：取跨场景参数 → 无参优雅降级（直开冒烟）；有参装配战斗并开战
	## 参数：无
	## 返回：无
	var scene_manager: Node = get_node("/root/SceneManager")
	var params: Dictionary = scene_manager.take_pending_params()
	var battle_params: BattleParams = params.get(&"battle_params", null) as BattleParams
	controller = %BattleController as BattleController
	%UnitInfoCard.setup(_StatusLookupOf())
	if battle_params == null:
		push_warning("battle_screen: 无战斗参数（直开冒烟口径——显示待机提示）")
		%IdleLabel.visible = true
		return
	_game_data = get_node("/root/GameData")
	context = BattleSetup.build(battle_params, _game_data)
	if context == null:
		push_error("battle_screen: 战斗装配失败")
		%IdleLabel.visible = true
		return
	controller.delay_seconds = 0.4
	%BoardLayer.setup(context, _game_data)
	%TurnOrderBar.setup(_game_data)
	_ConnectController()
	controller.start_battle(context)

func _StatusLookupOf() -> Callable:
	## 状态解析闭包（信息卡消费；上下文未建时返回空解析）
	## 参数：无
	## 返回：Callable
	return func(status_id: StringName) -> StatusDef:
		if context == null:
			return null
		return context.status_lookup.call(status_id) as StatusDef

func _ConnectController() -> void:
	## 连接控制器信号 → UI 刷新（单向数据流的信号侧）
	## 参数：无
	## 返回：无
	controller.battle_started.connect(func() -> void: %BoardLayer.refresh_all_badges())
	controller.round_started.connect(_OnRoundStarted)
	controller.turn_started.connect(_OnTurnStarted)
	controller.unit_moved.connect(func(unit: BattleUnit, _from_pos: Vector2i, _to_pos: Vector2i) -> void:
		%BoardLayer.move_badge(unit)
		%BoardLayer.refresh_badge(unit)
		%BoardLayer.clear_overlays()
		%BoardLayer.RefreshDynamicMarks()
	)
	controller.skill_executed.connect(_OnSkillExecuted)
	controller.status_changed.connect(_OnStatusChanged)
	controller.unit_downed.connect(func(unit: BattleUnit) -> void:
		%BoardLayer.refresh_badge(unit)
		%UnitInfoCard.show_unit(unit)
	)
	controller.battle_ended.connect(_OnBattleEnded)
	%ResultPanel.return_pressed.connect(func() -> void:
		get_node("/root/SceneManager").go(SceneManagerScript.SceneId.GUILD_SHELL)
	)

# --------------------------------------------------------------------------
# 信号驱动的 UI 刷新
# --------------------------------------------------------------------------

func _OnRoundStarted(round_no: int) -> void:
	## 回合开始：回合标签 + 序条重建
	## 参数 round_no：回合号
	## 返回：无
	%RoundLabel.text = "回合 %d" % round_no
	%TurnOrderBar.rebuild(context.turn_order)

func _OnTurnStarted(unit: BattleUnit) -> void:
	## 行动轮开始：清选择态、当前位高亮、按钮组刷新、蛊惑紫边提示
	## 参数 unit：行动单位
	## 返回：无
	_ClearSelection()
	%BoardLayer.set_current_unit(unit)
	%TurnOrderBar.set_current(unit)
	%UnitInfoCard.show_unit(unit)
	var is_bewitched: bool = context.status_manager.get_active_control(unit) \
			== StatusDef.ControlKind.BEWITCH
	for badge_unit: BattleUnit in context.units:
		%BoardLayer.set_bewitched(badge_unit,
				badge_unit == unit and is_bewitched)
	_RefreshActionBar(unit)
	if unit.is_controllable() and not is_bewitched:
		%BoardLayer.show_move_range(context.grid.find_reachable(unit, unit.move_final()))

func _OnSkillExecuted(caster, result) -> void:
	## 技能执行后：伤害飘字 + 徽章刷新 + 动态地格标记
	## 参数 caster：施放单位；result：ExecutionResult
	## 返回：无
	if result.success and result.damage > 0:
		var target: BattleUnit = context.find_unit(result.target_id)
		if target != null:
			%BoardLayer.show_damage_number(target.grid_pos, result.damage, result.crit)
	%BoardLayer.refresh_all_badges()
	%BoardLayer.RefreshDynamicMarks()
	if result.success:
		%BoardLayer.clear_overlays()

func _OnStatusChanged(unit: BattleUnit, _status_id: StringName) -> void:
	## 状态变化：信息卡与徽章刷新
	## 参数 unit：目标单位
	## 返回：无
	%UnitInfoCard.show_unit(unit)

func _OnBattleEnded(result: BattleResult) -> void:
	## 终局：结算面板弹出（延迟一帧等待倒地演出落定）
	## 参数 result：战斗结果
	## 返回：无
	%ResultPanel.show_result.call_deferred(result)

# --------------------------------------------------------------------------
# 玩家输入（板面点按 → 两段式确认）
# --------------------------------------------------------------------------

func _on_board_gui_input(event: InputEvent) -> void:
	## 板面点按入口：左键点按 → 格命中 → 分发（我方指令窗 = 移动/技能两段式；
	## 非指令窗 = 点按跳过演出延迟——拍板 D）
	## 参数 event：输入事件
	## 返回：无
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var cell: Vector2i = %BoardLayer.cell_from_local(mouse_event.position)
	if cell == Vector2i(-1, -1):
		_ClearSelection()
		return
	if controller == null or not controller.awaiting_command:
		if controller != null:
			controller.skip_current_delay()
		return
	var unit: BattleUnit = controller.current_unit
	if unit == null:
		return
	if _selected_skill_id != &"":
		_HandleSkillTap(cell)
	else:
		_HandleMoveTap(cell)

func _HandleMoveTap(cell: Vector2i) -> void:
	## 移动模式两段式：首点目标格 = 路径预览；再点同格 = 确认执行；
	## 点单位 = 查看详情；点其他区域 = 取消
	## 参数 cell：命中格
	## 返回：无
	var unit: BattleUnit = controller.current_unit
	var occupant: Object = context.grid.get_unit_at(cell)
	if occupant != null:
		%UnitInfoCard.show_unit(occupant)
	if cell == _pending_cell:
		if controller.request_move(cell):
			_ClearSelection()
		return
	var reachable: Array[Vector2i] = context.grid.find_reachable(unit, unit.move_final())
	if reachable.has(cell):
		_pending_cell = cell
		%BoardLayer.show_path_preview(unit.grid_pos, cell)
		return
	if occupant == null:
		_ClearSelection()

func _HandleSkillTap(cell: Vector2i) -> void:
	## 技能模式两段式：首点射程内目标格 = 确认提示；再点同格 = 释放；
	## 点其他区域 = 取消（保留技能钮重选入口）
	## 参数 cell：命中格
	## 返回：无
	if cell == _pending_cell:
		if controller.request_skill(_selected_skill_id, cell):
			_ClearSelection()
		else:
			# 执行失败（视线/目标非法等）——回范围重选态
			_pending_cell = NO_CELL
			%BoardLayer.clear_overlays()
			%BoardLayer.show_skill_range(_skill_range_cells)
		return
	if _skill_range_cells.has(cell):
		_pending_cell = cell
		%BoardLayer.show_target_confirm(cell)
		return
	_ClearSelection()

func _ClearSelection() -> void:
	## 清空选择态（技能/待定格/覆盖层）
	## 参数：无
	## 返回：无
	_selected_skill_id = &""
	_skill_range_cells = []
	_pending_cell = NO_CELL
	%BoardLayer.clear_overlays()

# --------------------------------------------------------------------------
# 按钮组（BottomBar）
# --------------------------------------------------------------------------

func _RefreshActionBar(unit: BattleUnit) -> void:
	## 按钮组刷新：我方指令窗 → 普攻常驻 + 两技能钮（资源不足灰显）+ 结束/撤退；
	## 非我方轮 → 全灰
	## 参数 unit：当前行动单位
	## 返回：无
	var active: bool = controller.awaiting_command and unit.is_controllable()
	%AttackButton.disabled = not active or unit.has_acted
	%SkillButtonA.disabled = not active or unit.has_acted
	%SkillButtonB.disabled = not active or unit.has_acted
	%EndTurnButton.disabled = not active
	%RetreatButton.disabled = not active
	if not active:
		return
	# 普攻常驻（D3）：标签取技能名
	var attack: SkillDef = context.skill_lookup.call(unit.base_attack_id) as SkillDef
	%AttackButton.text = attack.display_name if attack != null else "普攻"
	# 两个主动技钮（skill_ids 第 2/3 项 = 档 1 技能；不足则隐藏）
	var skill_slots: Array = [%SkillButtonA, %SkillButtonB]
	for index: int in skill_slots.size():
		var button: Button = skill_slots[index]
		var skill_index: int = index + 1
		if skill_index >= unit.skill_ids.size():
			button.visible = false
			continue
		button.visible = true
		var skill: SkillDef = context.skill_lookup.call(unit.skill_ids[skill_index]) as SkillDef
		if skill == null:
			button.visible = false
			continue
		button.text = skill.display_name
		button.disabled = unit.has_acted or not unit.has_resource(skill.resource_type,
				skill.resource_cost)

func _on_attack_button_pressed() -> void:
	## 普攻钮：进入技能选择模式（范围红显；再点取消）
	## 参数：无
	## 返回：无
	_EnterSkillMode(controller.current_unit.base_attack_id)

func _on_skill_button_a_pressed() -> void:
	## 技能钮 A：进入/取消技能选择模式
	## 参数：无
	## 返回：无
	_ToggleSkillSlot(1)

func _on_skill_button_b_pressed() -> void:
	## 技能钮 B：进入/取消技能选择模式
	## 参数：无
	## 返回：无
	_ToggleSkillSlot(2)

func _ToggleSkillSlot(skill_index: int) -> void:
	## 技能钮切换：同钮再点 = 取消选择
	## 参数 skill_index：unit.skill_ids 下标（1/2 = 两档 1 技能）
	## 返回：无
	var unit: BattleUnit = controller.current_unit
	if unit == null or skill_index >= unit.skill_ids.size():
		return
	if _selected_skill_id == unit.skill_ids[skill_index]:
		_ClearSelection()
		%BoardLayer.show_move_range(context.grid.find_reachable(unit, unit.move_final()))
		return
	_EnterSkillMode(unit.skill_ids[skill_index])

func _EnterSkillMode(skill_id: StringName) -> void:
	## 进入技能选择模式：范围红显（射程内全部格）
	## 参数 skill_id：技能 id
	## 返回：无
	var unit: BattleUnit = controller.current_unit
	if unit == null or unit.has_acted:
		return
	var skill: SkillDef = context.skill_lookup.call(skill_id) as SkillDef
	if skill == null:
		return
	_selected_skill_id = skill_id
	_pending_cell = NO_CELL
	_skill_range_cells = context.grid.cells_in_range(unit.grid_pos, maxi(1, skill.range))
	%BoardLayer.clear_overlays()
	%BoardLayer.show_skill_range(_skill_range_cells)

func _on_end_turn_button_pressed() -> void:
	## 行动结束钮
	## 参数：无
	## 返回：无
	_ClearSelection()
	controller.request_end_unit_turn()

func _on_retreat_button_pressed() -> void:
	## 撤退钮：确认弹窗（撤退 = 委托失败警示）
	## 参数：无
	## 返回：无
	%RetreatConfirm.popup_centered()

func _on_retreat_confirm_confirmed() -> void:
	## 撤退确认：发起撤退（RETREAT = 委托失败口径占位）
	## 参数：无
	## 返回：无
	_ClearSelection()
	controller.request_retreat()
