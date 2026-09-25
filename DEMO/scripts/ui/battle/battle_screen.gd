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

## tooltip/文案格式串模板（B-8：拼装口径单源——改措辞只动此处）
const TOOLTIP_TEMPLATES: Dictionary = {
	&"meta_line": "消耗：%s",
	&"meta_range": "　射程：%s",
	&"expect_damage": "预计伤害：%d",
	&"expect_heal": "预计治疗：%d",
	&"hit_mod": "命中修正：%+d%%",
	&"tips_damage": "预计伤害 %d",
	&"tips_hit": "命中率 %d%%",
	&"tips_heal": "预计治疗 %d",
}
## 普攻钮 fallback 文案（B-9：技能查无时的共享常量——tscn 占位留）
const COMMON_ATTACK_NAME: String = "普攻"
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
	# M2 批 3：返回路由参数化（return_to 缺省公会壳保持 M1 行为；回传包
	# 供 event_screen 战后续跑——expedition_run 引用+事件/节点锚点透传回带，
	# 战后 battle_result 以**合并键**写入不整体替换（E3-01①断链修复））
	_return_to = int(params.get(&"return_to", -1))
	_return_payload = {
		&"expedition_run": params.get(&"expedition_run", null),
		&"event_id": params.get(&"event_id", &""),
		&"battle_node_id": params.get(&"battle_node_id", &""),
	}
	# E2-4：回事件屏时出征锁由本屏接管持有（event_screen 路由战斗离树不
	# 释放——锁随会话连续，消除路由空窗）
	if _return_to == SceneManagerScript.SceneId.EVENT_SCREEN:
		var save_manager: Node = get_node_or_null("/root/SaveManager")
		if save_manager != null:
			save_manager.set_expedition_lock(true)
	controller = %BattleController as BattleController
	%UnitInfoCard.setup(_StatusLookupOf(), _NameLookupOf())
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
	# 敌方演出延时（A-10：表侧权威——cfg.ui_battle_delay_seconds 回填
	# controller；@export 默认保留为测试注入口，测试赋 0 在此后仍生效）
	controller.delay_seconds = context.cfg.ui_battle_delay_seconds
	# B-7：tscn 内嵌字号按档位覆写（tscn 值留占位——字号体系只动 cfg）
	_ApplyFontTiers()
	%UnitInfoCard.apply_cfg(context.cfg)
	%BoardLayer.setup(context, _game_data)
	%TurnOrderBar.setup(_game_data, context.cfg)
	_ConnectController()
	controller.start_battle(context)

func _ApplyFontTiers() -> void:
	## tscn 内嵌字号档位覆写（B-7）：RoundLabel（26→large）/ OrderTitle（16→
	## normal）/ IdleLabel（18→normal）——tscn 值留占位，运行时以 cfg 档位为准
	## 参数：无
	## 返回：无
	var cfg: CoreConfig = context.cfg if context != null else null
	%RoundLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_large", UiTheme.FONT_LARGE))
	%TurnOrderBar.get_parent().get_node("OrderTitle").add_theme_font_size_override(
			"font_size", UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	%IdleLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))

func _StatusLookupOf() -> Callable:
	## 状态解析闭包（信息卡消费；上下文未建时返回空解析）
	## 参数：无
	## 返回：Callable
	return func(status_id: StringName) -> StatusDef:
		if context == null:
			return null
		return context.status_lookup.call(status_id) as StatusDef

func _NameLookupOf() -> Callable:
	## 显示名解析闭包（S4-9：信息卡名单源——经 BattleContext.display_name_of；
	## 上下文未建时返回无效 Callable，信息卡回退直读 unit.display_name）
	## 参数：无
	## 返回：Callable（unit_id -> String）
	return func(unit_id: StringName) -> String:
		if context == null:
			return String(unit_id)
		return context.display_name_of(unit_id)

func _DisableInteractionForDegradedRun() -> void:
	## 降级路径交互禁用（盲审批 1-6：无参/装配失败直开时 context 为 null——
	## 板面坐标换算与按钮 handler 均不可用，禁用四钮 + 板面不接鼠标，配合
	## handler 侧空守卫双保险；S5-2：撤退钮改「返回公会壳」直连 SceneManager
	## 保留降级出口，不再一并禁用）
	## 参数：无
	## 返回：无
	%AttackButton.disabled = true
	%SkillButtonA.disabled = true
	%SkillButtonB.disabled = true
	%EndTurnButton.disabled = true
	%RetreatButton.disabled = false
	%RetreatButton.text = "返回公会壳"
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
	controller.round_settled.connect(_OnRoundSettled)
	controller.status_changed.connect(_OnStatusChanged)
	controller.unit_downed.connect(func(unit: BattleUnit) -> void:
		%BoardLayer.refresh_badge(unit)
		%UnitInfoCard.show_unit(unit)
		# S4-6：序条同回合即时灰显（此前倒地灰显只在回合初 rebuild 生效）
		%TurnOrderBar.set_downed(unit)
	)
	# S4-5：陷阱触发飘字 + 徽章刷新（伤害直扣此前无 UI 反馈）
	controller.trap_triggered.connect(func(unit: BattleUnit, damage: int) -> void:
		%BoardLayer.show_damage_number(unit.grid_pos, damage, false)
		%BoardLayer.refresh_badge(unit)
	)
	controller.battle_ended.connect(_OnBattleEnded)
	%BattleLog.setup(controller, context)
	%ResultPanel.return_pressed.connect(_OnReturnPressed)

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
	## 行动轮开始：清选择态、当前位高亮、按钮组刷新、蛊惑紫边提示；定身
	## （ROOT——S3-07）与蛊惑同权不显示移动范围（被锁单位无移动可预览）
	## 参数 unit：行动单位
	## 返回：无
	_ClearSelection()
	%BoardLayer.set_current_unit(unit)
	%TurnOrderBar.set_current(unit)
	%UnitInfoCard.show_unit(unit)
	var control: int = context.status_manager.get_active_control(unit)
	var is_bewitched: bool = control == StatusDef.ControlKind.BEWITCH
	for badge_unit: BattleUnit in context.units:
		%BoardLayer.set_bewitched(badge_unit,
				badge_unit == unit and is_bewitched)
	_RefreshActionBar(unit)
	if unit.is_controllable() and control == StatusDef.ControlKind.NONE:
		%BoardLayer.show_move_range(context.grid.find_reachable(unit, unit.move_final()))

func _OnSkillExecuted(caster: BattleUnit, result: SkillExecutor.ExecutionResult) -> void:
	## 技能执行后：伤害飘字 + 徽章刷新 + 动态地格标记 + 按钮组按真实可用性
	## 重刷（2026-09-24 三轮反馈：行动权耗尽后技能钮置灰、行动结束/撤退不灰）
	## 参数 caster：施放单位；result：ExecutionResult（S4-10 全量类型）
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

func _OnRoundSettled(_round_no: int, dot_damage: Array) -> void:
	## 回合末结算完成（盲审批 3 D-2）：DOT 跳伤飘字（承伤单位格 −N）+
	## 徽章全刷（HP 直扣发生在回合末，此前跨回合显示旧值的盲区自此消除）
	## 参数 _round_no：回合号；dot_damage：跳伤清单（{&"unit", &"damage"}）
	## 返回：无
	for entry: Dictionary in dot_damage:
		var unit: BattleUnit = entry.get(&"unit", null) as BattleUnit
		var damage: int = int(entry.get(&"damage", 0))
		if unit != null and damage > 0:
			%BoardLayer.show_damage_number(unit.grid_pos, damage, false)
	%BoardLayer.refresh_all_badges()

func _OnBattleEnded(result: BattleResult) -> void:
	## 终局：结算面板弹出（延迟一帧等待倒地演出落定；倒地名单经显示名
	## 解析——单源 BattleContext.display_name_of，批 4 C 组 M4）
	## 参数 result：战斗结果
	## 返回：无
	# M2 批 3+E3-01①：回传包**合并键**写入（战斗结果并入既有 expedition_run/
	# 锚点——整体替换会丢 run 引用断续跑链）
	_return_payload[&"battle_result"] = result
	%ResultPanel.show_result.call_deferred(result,
			func(unit_id: StringName) -> String: return context.display_name_of(unit_id),
			context.cfg)

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
	## 点单位 = 查看详情；点其他区域 = 取消。S3-03：已移动（has_moved）后
	## 点格 = 查看/取消语义（不再预览路径）；确认执行被拒（如不可达）清预览
	## 并日志提示
	## 参数 cell：命中格
	## 返回：无
	var unit: BattleUnit = controller.current_unit
	var occupant: Object = context.grid.get_unit_at(cell)
	if occupant != null:
		%UnitInfoCard.show_unit(occupant)
	if unit.has_moved:
		# S3-03：本行动轮已移动——点格仅查看（occupant 已处理）+ 取消选择
		_ClearSelection()
		return
	if cell == _pending_cell:
		if controller.request_move(cell):
			_ClearSelection()
		else:
			# 执行被拒（可达性竞态等）：清路径预览 + 日志反馈，选择态复位
			_pending_cell = NO_CELL
			%BoardLayer.clear_overlays()
			%BattleLog.push_line(BattleLog.MSG_MOVE_REJECTED, BattleLog.LineKind.SYSTEM)
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
		# 换目标入口统一清理（盲审批 3 D-3 + S4-2）：先隐藏旧目标 tips 并清
		# 血条预览（均在 LOS 检查之前——拦截/空格等不进确认路径零残留），
		# 新目标满足条件时由 show_target_tips/show_damage_preview 重新显示
		%BoardLayer.hide_target_tips()
		%BoardLayer.clear_damage_previews()
		# 视线拦截（2026-09-24 十四轮反馈）：射程内但被障碍挡视线的格——
		# 不进确认态（不弹 tips/不闪血条），日志提示原因，选择态保留
		# （同超射程口径；射程 1 免视线与 executor 校验一致）
		if _LosRequiredOf(_selected_skill_id) \
				and not context.grid.has_line_of_sight(unit.grid_pos, cell):
			%BattleLog.push_line(BattleLog.MSG_LOS_BLOCKED,
					BattleLog.LineKind.SYSTEM)
			_pending_cell = NO_CELL
			return
		_pending_cell = cell
		var skill: SkillDef = context.skill_lookup.call(_selected_skill_id) as SkillDef
		var target: BattleUnit = context.grid.get_unit_at(cell) as BattleUnit
		if skill != null and target != null and target.alive:
			if target.side != unit.side:
				# S4-1：友方技点敌方格 = 目标非法（不进确认态，日志反馈——
				# 与执行器 ALLY 镜像校验对齐；原内层恒 false 死代码已删）
				if skill.target_side == SkillDef.TargetSide.ALLY:
					%BattleLog.push_line(BattleLog.MSG_TARGET_INVALID_ALLY,
							BattleLog.LineKind.SYSTEM)
					_pending_cell = NO_CELL
					return
				# 敌方目标（2026-09-24 九轮反馈）：伤害技 = 血条预扣 + tips
				# （减免后预计伤害 + 含站位状态的真实命中率，两处数字同源同值）；
				# 纯状态技 = 技能名 + 表内效果描述
				if skill.damage_type != SkillDef.DamageType.NONE:
					var damage: int = _ExpectedDamageOn(unit, target, skill)
					%BoardLayer.show_damage_preview(target, damage)
					var hit_pct: int = UiTheme.pct(BattleRules.hit_chance(unit.hit,
							target.dodge, skill.hit_mod, context.cfg))
					%BoardLayer.show_target_tips(cell,
							TOOLTIP_TEMPLATES[&"tips_damage"] % damage,
							TOOLTIP_TEMPLATES[&"tips_hit"] % hit_pct)
				else:
					%BoardLayer.show_target_tips(cell, skill.display_name, skill.description)
			elif skill.target_side == SkillDef.TargetSide.ALLY:
				# 治疗技点友方：预计治疗（免判定不显命中行）
				for effect: SkillEffect in skill.effects:
					if effect.effect_kind == SkillEffect.EffectKind.HEAL:
						%BoardLayer.show_target_tips(cell, TOOLTIP_TEMPLATES[&"tips_heal"]
								% BattleRules.heal_amount(unit.attrs, effect), "")
						break
		%BoardLayer.show_target_confirm(cell)
		return
	# 射程外有存活单位的格：保留技能选择态 + 日志提示（2026-09-24 八轮反馈：
	# 静默取消无反馈，像「点了没打中」）；点纯空区域维持原取消语义
	var occupant: Object = context.grid.get_unit_at(cell)
	if occupant != null and occupant.alive:
		# R3-10：射程外提示分支同步清确认态（tips/预览不残留）
		%BoardLayer.hide_target_tips()
		%BoardLayer.clear_damage_previews()
		_pending_cell = NO_CELL
		%BattleLog.push_line(BattleLog.MSG_TARGET_OUT_OF_RANGE, BattleLog.LineKind.SYSTEM)
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
	var meta_line: String = TOOLTIP_TEMPLATES[&"meta_line"] % _ResourceCostText(skill)
	if skill.target_side != SkillDef.TargetSide.SELF:
		meta_line += TOOLTIP_TEMPLATES[&"meta_range"] % _RangeText(skill)
	lines.append(meta_line)
	if skill.damage_type != SkillDef.DamageType.NONE:
		lines.append(TOOLTIP_TEMPLATES[&"expect_damage"] % _ExpectedDamage(caster, skill))
	for effect: SkillEffect in skill.effects:
		if effect.effect_kind == SkillEffect.EffectKind.HEAL:
			lines.append(TOOLTIP_TEMPLATES[&"expect_heal"]
					% BattleRules.heal_amount(caster.attrs, effect))
			break
	if skill.hit_mod != 0:
		lines.append(TOOLTIP_TEMPLATES[&"hit_mod"] % skill.hit_mod)
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
	## 静态口收集——批 A H1）→ 减免轨选对经 BattleRules.mitigate_by_damage_type
	## 单源（批 4 H2：与执行链/AI 期望三处同源）；不含暴击期望与命中折算
	## 参数 caster/target：施放与目标单位；skill：技能定义
	## 返回：减免后预计伤害（int）
	var panel_mult: float = SkillExecutor.panel_mult_of(caster, context.status_manager)
	var race_mult: float = SkillExecutor.collect_race_mult(skill, target.race_tag)
	var raw: float = BattleRules.raw_panel_damage(caster.attrs, caster.weapon_bonus,
			skill, panel_mult, race_mult)
	return BattleRules.mitigate_by_damage_type(raw, skill.damage_type, caster, target,
			context.cfg)

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
	## 普攻钮：进入/取消技能选择模式（S4-7：再点取消——与 _ToggleSkillSlot
	## 对称，取消后回显移动范围）；降级路径空守卫（盲审批 1-6 双保险）
	## 参数：无
	## 返回：无
	if controller == null or controller.current_unit == null:
		return
	var unit: BattleUnit = controller.current_unit
	if _selected_skill_id == unit.base_attack_id:
		_ClearSelection()
		_RestoreMoveRangeIfUsable(unit)
		return
	_EnterSkillMode(unit.base_attack_id)

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
		_RestoreMoveRangeIfUsable(unit)
		return
	_EnterSkillMode(unit.skill_ids[skill_index])

func _EnterSkillMode(skill_id: StringName) -> void:
	## 进入技能选择模式：范围红显（S4-8：范围格集经 SkillExecutor.range_cells_of
	## 单源——AURA 切比雪夫 / 其余曼哈顿 effective_range，与执行度量同口径）
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
	_skill_range_cells = SkillExecutor.range_cells_of(skill, unit.grid_pos, context.grid)
	%BoardLayer.clear_overlays()
	%BoardLayer.show_skill_range(_skill_range_cells, unit.grid_pos, SkillExecutor.los_required(skill))

func _LosRequiredOf(skill_id: StringName) -> bool:
	## 技能是否需视线（批 C M5：语义经 SkillExecutor.los_required 单源——
	## UI 展示与执行器前置校验恒一致；十四轮反馈：范围分组渲染与点选拦截共用）
	## 参数 skill_id：技能 id
	## 返回：true = 射程 > 1 需视线
	var skill: SkillDef = context.skill_lookup.call(skill_id) as SkillDef
	return SkillExecutor.los_required(skill)

## 返回目的地（return_to 参数注入；缺省 GUILD_SHELL——M1 行为不变）
var _return_to: int = -1
## 回传数据（战后 run 状态+锚点+战斗结果——event_screen 续跑消费）
var _return_payload: Dictionary = {}

func _exit_tree() -> void:
	## 引擎回调：离树释放出征锁（E2-4：回事件屏时锁由 event_screen._ready
	## 接管持有——本屏不释放，帧内连续无空窗；其余去向 = 会话结束释放）
	## 参数：无
	## 返回：无
	if _return_to == SceneManagerScript.SceneId.EVENT_SCREEN:
		return
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager != null:
		save_manager.set_expedition_lock(false)

func _OnReturnPressed() -> void:
	## 返回按钮：路由 return_to（缺省公会壳）并回传战斗结果与运行态
	## 参数：无
	## 返回：无
	# R4-15：关键入口消费 go 返回值——切换失败可感知（日志层反馈）
	var target: int = _return_to if _return_to >= 0 else SceneManagerScript.SceneId.GUILD_SHELL
	var err: Error = get_node("/root/SceneManager").go(target, _return_payload)
	if err != OK:
		push_warning("battle_screen: 返回目标场景失败（错误码 %d）" % err)

func _RestoreMoveRangeIfUsable(unit: BattleUnit) -> void:
	## 取消选择后回显移动范围（R3-05 拍板：仅未移动且未被控制时回显——
	## 已移动/被定身/被蛊惑的取消不再重显范围）
	## 参数 unit：当前行动单位
	## 返回：无
	if unit == null or unit.has_moved:
		return
	if context.status_manager.get_active_control(unit) != StatusDef.ControlKind.NONE:
		return
	%BoardLayer.show_move_range(context.grid.find_reachable(unit, unit.move_final()))

func _on_end_turn_button_pressed() -> void:
	## 行动结束钮（降级路径空守卫——盲审批 1-6 双保险）
	## 参数：无
	## 返回：无
	if controller == null:
		return
	_ClearSelection()
	controller.request_end_unit_turn()

func _on_retreat_button_pressed() -> void:
	## 撤退钮：确认弹窗（撤退 = 委托失败警示）；S5-2：降级路径（context 为
	## null，钮文案已改「返回公会壳」）直连 SceneManager 回公会壳——降级
	## 出口不经撤退语义与弹窗（_switch_pending 已防重入）
	## 参数：无
	## 返回：无
	if controller == null or context == null:
		get_node("/root/SceneManager").go(SceneManagerScript.SceneId.GUILD_SHELL)
		return
	%RetreatConfirm.popup_centered()

func _on_retreat_confirm_confirmed() -> void:
	## 撤退确认：发起撤退（RETREAT = 委托失败口径占位）
	## 参数：无
	## 返回：无
	_ClearSelection()
	controller.request_retreat()
