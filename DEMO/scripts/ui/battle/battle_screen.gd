## 战斗场景根（battle_screen，Control）
## 职责：战棋 UI 主控——读跨场景参数装配战斗（BattleSetup → BattleController）、
## 单向数据流（玩家输入 → controller.request_* → controller 信号 → UI 刷新）、
## 两段式确认交互（选中→高亮→点目标预览→再点确认；取消=点其他区域/再点钮；
## 技能确认带血条伤害预览——2026-09-24 二轮反馈）、技能按钮态（资源不足灰显、
## hover 描述与预计伤害——二轮反馈）、蛊惑紫边提示、敌方延时点按跳过、
## 撤退确认弹窗、结算面板路由回公会壳。
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
		_DisableInteractionForDegradedRun()
		return
	_game_data = get_node("/root/GameData")
	context = BattleSetup.build(battle_params, _game_data)
	if context == null:
		push_error("battle_screen: 战斗装配失败")
		%IdleLabel.visible = true
		_DisableInteractionForDegradedRun()
		return
	# 敌方演出延时走 controller 的 export 默认（批 D L6：删显式覆盖——单源）
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

func _DisableInteractionForDegradedRun() -> void:
	## 降级路径交互禁用（盲审批 1-6：无参/装配失败直开时 context 为 null——
	## 板面坐标换算与按钮 handler 均不可用，统一禁用五钮 + 板面不接鼠标，
	## 配合 handler 侧空守卫双保险）
	## 参数：无
	## 返回：无
	%AttackButton.disabled = true
	%SkillButtonA.disabled = true
	%SkillButtonB.disabled = true
	%EndTurnButton.disabled = true
	%RetreatButton.disabled = true
	%BoardLayer.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	%BattleLog.setup(controller, context)
	%ResultPanel.return_pressed.connect(func() -> void:
		get_node("/root/SceneManager").go(SceneManagerScript.SceneId.GUILD_SHELL)
	)

# --------------------------------------------------------------------------
# 信号驱动的 UI 刷新
# --------------------------------------------------------------------------

func _OnRoundStarted(round_no: int) -> void:
	## 回合开始：回合标签 + 序条重建 + 徽章全刷（盲审顺带 D 最小项：回合末
	## DOT 跳伤后徽章 HP 跨回合旧值显示盲区——完整信号方案留 D 组批）
	## 参数 round_no：回合号
	## 返回：无
	%RoundLabel.text = "回合 %d" % round_no
	%TurnOrderBar.rebuild(context.turn_order)
	%BoardLayer.refresh_all_badges()

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
	## 技能执行后：伤害飘字 + 徽章刷新 + 动态地格标记 + 按钮组按真实可用性
	## 重刷（2026-09-24 三轮反馈：行动权耗尽后技能钮置灰、行动结束/撤退不灰）
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
	# 信号时序：skill_executed 发射时 has_acted 尚未置位（request_skill 先执行
	# 后置标记），deferred 到帧末行动轮状态已落定再刷；敌方/蛊惑技能同信号
	# 触发，刷新函数按指令窗状态分派，勿特判 side
	_RefreshActionBarForCurrentTurn.call_deferred()

func _OnStatusChanged(unit: BattleUnit, _status_id: StringName) -> void:
	## 状态变化：信息卡与徽章刷新
	## 参数 unit：目标单位
	## 返回：无
	%UnitInfoCard.show_unit(unit)

func _OnBattleEnded(result: BattleResult) -> void:
	## 终局：结算面板弹出（延迟一帧等待倒地演出落定；倒地名单经显示名
	## 解析——2026-09-24 七轮反馈中文化）
	## 参数 result：战斗结果
	## 返回：无
	%ResultPanel.show_result.call_deferred(result, func(unit_id: StringName) -> String:
		var unit: BattleUnit = context.find_unit(unit_id)
		return unit.display_name if unit != null and not unit.display_name.is_empty() \
				else String(unit_id))

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
	## 技能模式两段式（2026-09-24 二轮反馈升级）：首点射程内目标格 = 确认提示，
	## 目标格有存活敌方且为伤害技时同步血条伤害预览（闪烁 −N）；再点同格 = 释放；
	## 点其他区域 = 取消（保留技能钮重选入口）
	## 参数 cell：命中格
	## 返回：无
	var unit: BattleUnit = controller.current_unit
	if cell == _pending_cell:
		if controller.request_skill(_selected_skill_id, cell):
			_ClearSelection()
		else:
			# 执行失败（目标非法等）——回范围重选态
			_pending_cell = NO_CELL
			%BoardLayer.clear_overlays()
			%BoardLayer.show_skill_range(_skill_range_cells, unit.grid_pos,
					_LosRequiredOf(_selected_skill_id))
		return
	if _skill_range_cells.has(cell):
		# 视线拦截（2026-09-24 十四轮反馈）：射程内但被障碍挡视线的格——
		# 不进确认态（不弹 tips/不闪血条），日志提示原因，选择态保留
		# （同超射程口径；射程 1 免视线与 executor 校验一致）
		if _LosRequiredOf(_selected_skill_id) \
				and not context.grid.has_line_of_sight(unit.grid_pos, cell):
			%BattleLog.push_line("视线被障碍阻断——请选择可直视的目标",
					BattleLog.LineKind.SYSTEM)
			return
		# 换目标：先清上一目标的血条预览（不动范围覆盖层；tips 由新 show 覆盖）
		%BoardLayer.clear_damage_previews()
		_pending_cell = cell
		var skill: SkillDef = context.skill_lookup.call(_selected_skill_id) as SkillDef
		var target: BattleUnit = context.grid.get_unit_at(cell) as BattleUnit
		if skill != null and target != null and target.alive:
			if target.side != unit.side:
				# 敌方目标（2026-09-24 九轮反馈）：伤害技 = 血条预扣 + tips
				# （减免后预计伤害 + 含站位状态的真实命中率，两处数字同源同值）；
				# 纯状态技 = 技能名 + 表内效果描述
				if skill.damage_type != SkillDef.DamageType.NONE:
					var damage: int = _ExpectedDamageOn(unit, target, skill)
					%BoardLayer.show_damage_preview(target, damage)
					var hit_pct: int = roundi(BattleRules.hit_chance(unit.hit, target.dodge,
							skill.hit_mod, context.cfg) * 100.0)
					%BoardLayer.show_target_tips(cell, "预计伤害 %d" % damage,
							"命中率 %d%%" % hit_pct)
				else:
					%BoardLayer.show_target_tips(cell, skill.display_name, skill.description)
			elif skill.target_side == SkillDef.TargetSide.ALLY:
				# 治疗技点友方：预计治疗（免判定不显命中行）；点敌方格 =
				# 目标非法提示（盲审批 1-1 UI 顺带：执行器已拒绝，日志同步反馈）
				if target.side != unit.side:
					%BattleLog.push_line("目标非法——该技能只能作用于友方单位",
							BattleLog.LineKind.SYSTEM)
					return
				for effect: SkillEffect in skill.effects:
					if effect.effect_kind == SkillEffect.EffectKind.HEAL:
						%BoardLayer.show_target_tips(cell,
								"预计治疗 %d" % BattleRules.heal_amount(unit.attrs, effect), "")
						break
		%BoardLayer.show_target_confirm(cell)
		return
	# 射程外有存活单位的格：保留技能选择态 + 日志提示（2026-09-24 八轮反馈：
	# 静默取消无反馈，像「点了没打中」）；点纯空区域维持原取消语义
	var occupant: Object = context.grid.get_unit_at(cell)
	if occupant != null and occupant.alive:
		%BattleLog.push_line("目标超出射程——请选择射程内目标", BattleLog.LineKind.SYSTEM)
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

func _RefreshActionBarForCurrentTurn() -> void:
	## 按当前行动轮状态重刷按钮组（skill_executed 帧末延迟调用）：
	## 非指令窗或行动轮已收束（current_unit 为 null——双完成自动结束/非我方轮）
	## → 全灰（现行行动轮外语义）；指令窗内 → 复用 _RefreshActionBar 按真实
	## 可用性逐钮判断（has_acted 置灰技能钮、行动结束/撤退保持可用——
	## 2026-09-24 三轮反馈用户口径：不写死全灰）
	## 参数：无
	## 返回：无
	var unit: BattleUnit = null if controller == null else controller.current_unit
	if unit == null or not controller.awaiting_command:
		%AttackButton.disabled = true
		%SkillButtonA.disabled = true
		%SkillButtonB.disabled = true
		%EndTurnButton.disabled = true
		%RetreatButton.disabled = true
		return
	_RefreshActionBar(unit)

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
	# 普攻常驻（D3）：标签取技能名 + hover 描述（2026-09-24 二轮反馈）
	var attack: SkillDef = context.skill_lookup.call(unit.base_attack_id) as SkillDef
	%AttackButton.text = attack.display_name if attack != null else "普攻"
	%AttackButton.tooltip_text = _SkillTooltip(unit, attack)
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
		button.tooltip_text = _SkillTooltip(unit, skill)
		button.disabled = unit.has_acted or not unit.has_resource(skill.resource_type,
				skill.resource_cost)

func _SkillTooltip(caster: BattleUnit, skill: SkillDef) -> String:
	## 技能按钮 hover 描述（2026-09-24 二轮反馈）：技能名 + 消耗/射程 +
	## 预计伤害/治疗 + 效果描述；预计伤害复用 BattleRules.raw_panel_damage
	## （§3.4 同源，panel/race 传 1.0 = 不含状态与种族层的稳定锚点，含系数层、
	## 四舍五入取整，不含暴击期望与命中折算）；治疗复用 heal_amount
	## 参数 caster：当前行动单位；skill：技能定义
	## 返回：tooltip 多行文本（skill 为 null 返回空）
	if skill == null:
		return ""
	var lines: Array[String] = [skill.display_name]
	# 自身为目标的施法技不标射程（2026-09-24 七轮反馈——「射程 1」误导；
	# ENEMY 攻击技/ALLY 治疗技的射程有实际意义保持显示）
	var meta_line: String = "消耗：%s" % _ResourceCostText(skill)
	if skill.target_side != SkillDef.TargetSide.SELF:
		meta_line += "　射程：%s" % _RangeText(skill)
	lines.append(meta_line)
	if skill.damage_type != SkillDef.DamageType.NONE:
		lines.append("预计伤害：%d" % _ExpectedDamage(caster, skill))
	for effect: SkillEffect in skill.effects:
		if effect.effect_kind == SkillEffect.EffectKind.HEAL:
			lines.append("预计治疗：%d" % BattleRules.heal_amount(caster.attrs, effect))
			break
	if skill.hit_mod != 0:
		lines.append("命中修正：%+d%%" % skill.hit_mod)
	if not skill.description.is_empty():
		lines.append(skill.description)
	return "\n".join(lines)

func _ExpectedDamage(caster: BattleUnit, skill: SkillDef) -> int:
	## 预计伤害（面板口径——按钮 tooltip 消费）= round(raw_panel_damage(
	## attrs, 武器, 技能, 1.0, 1.0))——与 17 案 §3.4 / §3.8 验算带同源同值
	## （函数内已乘 power_coefficient，不再二次乘算）
	## 参数 caster：施放单位；skill：技能定义
	## 返回：预计伤害（int）
	return int(round(BattleRules.raw_panel_damage(caster.attrs, caster.weapon_bonus,
			skill, 1.0, 1.0)))

func _ExpectedDamageOn(caster: BattleUnit, target: BattleUnit, skill: SkillDef) -> int:
	## 对具体目标的预计伤害（减免后口径——目标确认 tips 与血条预览数字同源
	## 同值，2026-09-24 九轮）：raw_panel_damage（乘算层经 SkillExecutor 单源
	## 静态口收集——批 A H1：与执行链同一函数，消除 UI/执行口径分叉）→
	## mitigate 按物理/法术轨选抗性/护甲/穿甲对；不含暴击期望与命中折算
	## 参数 caster/target：施放与目标单位；skill：技能定义
	## 返回：减免后预计伤害（int）
	var panel_mult: float = SkillExecutor.panel_mult_of(caster, context.status_manager)
	var race_mult: float = SkillExecutor.collect_race_mult(skill, target.race_tag)
	var raw: float = BattleRules.raw_panel_damage(caster.attrs, caster.weapon_bonus,
			skill, panel_mult, race_mult)
	var is_physical: bool = skill.damage_type == SkillDef.DamageType.PHYSICAL
	var resist: float = target.phys_resist if is_physical else target.mag_resist
	var armor: int = target.phys_armor if is_physical else target.mag_armor
	var pierce: int = caster.phys_pierce if is_physical else caster.mag_pierce
	return BattleRules.mitigate(raw, resist, armor, pierce, context.cfg)

func _ResourceCostText(skill: SkillDef) -> String:
	## 资源消耗文本（无 / 法力 N / 精力 N）
	## 参数 skill：技能定义
	## 返回：消耗描述
	if skill.resource_type == SkillDef.ResourceKind.NONE or skill.resource_cost <= 0:
		return "无"
	match skill.resource_type:
		SkillDef.ResourceKind.MANA:
			return "法力 %d" % skill.resource_cost
		_:
			return "精力 %d" % skill.resource_cost

func _RangeText(skill: SkillDef) -> String:
	## 射程文本（0 = 自身）
	## 参数 skill：技能定义
	## 返回：射程描述
	if skill.range <= 0:
		return "自身"
	return str(skill.range)

func _on_attack_button_pressed() -> void:
	## 普攻钮：进入技能选择模式（范围红显；再点取消）；降级路径空守卫
	## （盲审批 1-6：无参直开 current_unit 为 null——按钮已禁用，此处双保险）
	## 参数：无
	## 返回：无
	if controller == null or controller.current_unit == null:
		return
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
	%BoardLayer.show_skill_range(_skill_range_cells, unit.grid_pos, SkillExecutor.los_required(skill))

func _LosRequiredOf(skill_id: StringName) -> bool:
	## 技能是否需视线（批 C M5：语义经 SkillExecutor.los_required 单源——
	## UI 展示与执行器前置校验恒一致；十四轮反馈：范围分组渲染与点选拦截共用）
	## 参数 skill_id：技能 id
	## 返回：true = 射程 > 1 需视线
	var skill: SkillDef = context.skill_lookup.call(skill_id) as SkillDef
	return SkillExecutor.los_required(skill)

func _on_end_turn_button_pressed() -> void:
	## 行动结束钮（降级路径空守卫——盲审批 1-6 双保险）
	## 参数：无
	## 返回：无
	if controller == null:
		return
	_ClearSelection()
	controller.request_end_unit_turn()

func _on_retreat_button_pressed() -> void:
	## 撤退钮：确认弹窗（撤退 = 委托失败警示；降级路径空守卫双保险）
	## 参数：无
	## 返回：无
	if controller == null:
		return
	%RetreatConfirm.popup_centered()

func _on_retreat_confirm_confirmed() -> void:
	## 撤退确认：发起撤退（RETREAT = 委托失败口径占位）
	## 参数：无
	## 返回：无
	_ClearSelection()
	controller.request_retreat()
