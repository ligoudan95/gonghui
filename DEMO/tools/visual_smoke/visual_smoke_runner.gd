## 临时视觉冒烟驱动主体（M6 批 1+2 表现层视觉验证——非生产代码，不入 selfcheck）
## 职责：真窗口 1280×720 下装配真实战斗（enc_m1_lair_pack：精英 + 杂兵×2-3，
## 巢穴 10×10 图——含障碍/草丛/高地/毒沼），按脚本序列自动驱动出招/移动/陷阱/
## DOT/致死，关键时点连拍截图到 res://reports/visual_smoke/，供视觉模型逐张
## 核验盲审修复后的表现。
## 覆盖验证点：
##   中4 矮窗右缘（1280×720 竖滚动条出现，BattleLog/UnitInfoCard 右缘不裁切）
##   中1 连招哑火（敌方 CAST 演出中紧接 MELEE——同档攻击互切不压制）
##   低9 拐点链移动（真实 request_move → find_path 拐点序 → 徽章逐格 tween）
##   低7 白闪（技能命中 / 陷阱触发 / DOT 跳伤三承伤路径——0.25s 连拍捕捉）
##   倒地尸态（downed 末帧锁定 + 血条/资源条/高亮环隐藏 + 灰度 + 序条灰显）
##   我方六动作（idle/move/melee_attack/cast_ranged/hit/downed 全触发）
##   敌方动作（精英 MELEE+CAST 双形态 / 杂兵 MELEE 普攻与职业技）
##   MISS（hit_clamp 双注 0 必闪避——目标不播受击 + 「闪避」飘字）
## 驱动口径：live 阶段走真实指令链（request_move/request_skill/敌方 AI 自动）；
## 中止状态机后用 controller._execute_skill / _move_unit（生产方法直调，与
## 集成测试 test_battle_anim_flow 同口径）补确定性镜头。
## 保护：序列走完自动退出；180s 总超时兜底 quit(2) 防挂死。
extends Node

## SceneManager 脚本类引用（SceneId 常量——autoload 枚举不可经实例属性访问）
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")
## 截图输出目录（源码运行 res:// 可写——绝对落点 DEMO/reports/visual_smoke/）
const OUT_DIR: String = "res://reports/visual_smoke/"
## 我方队伍（职业覆盖：战士 MELEE / 游侠 CAST 弓姿 / 法师+牧师 CAST）
const PARTY: Array = [
	[&"warrior", &"cls_warrior"],
	[&"ranger", &"cls_ranger"],
	[&"mage", &"cls_mage"],
	[&"priest", &"cls_priest"],
]
## 动作枚举名（UnitAnimState.Action 序——stdout 姿态证据用）
const ACTION_NAMES: PackedStringArray = ["IDLE", "MOVE", "MELEE_ATTACK",
	"CAST_RANGED", "HIT", "DOWNED"]
## 精英连招技能（中1：CAST 怒吼 ↔ MELEE 穷追/普攻）
const SKILL_ROAR: StringName = &"skl_enemy_intimidating_roar"
const SKILL_RELENTLESS: StringName = &"skl_enemy_relentless"
## 总超时（秒——防挂死兜底）
const WATCHDOG_SECONDS: float = 180.0

## 战斗屏根（装配后供各相位消费）
var _battle: Control = null
## 战斗上下文（装配后缓存）
var _ctx: BattleSetup.BattleContext = null
## 战斗控制器（装配后缓存）
var _controller: BattleController = null
## 截图序号（文件名前缀）
var _shot_no: int = 0
## 序列完成标记（watchdog 判据）
var _done: bool = false
## 命中钳制带原值（相位内注入后还原）
var _clamp_min_bak: float = -1.0
var _clamp_max_bak: float = -1.0
## 战士拐点移动说明（stdout 证据）
var _warrior_move_note: String = ""

func _ready() -> void:
	## 引擎回调：清输出目录 → 挂 watchdog → 启动驱动协程（fire-and-forget）
	## 参数：无
	## 返回：无
	get_tree().root.title = "gonghui-visual-smoke（临时验证窗口）"
	_PrepareOutDir()
	get_tree().create_timer(WATCHDOG_SECONDS).timeout.connect(
		func() -> void:
			if not _done:
				_Print("watchdog", "总超时 %.0f 秒——强制退出（防挂死）" % WATCHDOG_SECONDS)
				get_tree().quit(2)
	)
	_Run()

# --------------------------------------------------------------------------
# 主序列
# --------------------------------------------------------------------------

func _Run() -> void:
	## 驱动主序列：进战斗 → 右栏矮窗 → 我方六动作（live）→ MISS（live）→
	## 中止状态机 → 敌方连招 → 陷阱白闪 → 倒地尸态 → 终局面板 → 退出
	## 参数：无
	## 返回：无（协程）
	var t0: int = Time.get_ticks_msec()
	_Print("boot", "视觉冒烟驱动启动（真窗口 1280×720，非 headless）")
	await _EnterBattle()
	if _battle == null or _ctx == null:
		_Print("boot", "战斗装配失败——退出")
		get_tree().quit(3)
		return
	_clamp_min_bak = _ctx.cfg.hit_clamp_min
	_clamp_max_bak = _ctx.cfg.hit_clamp_max
	_HookSignals()
	await _PhaseRightPanel()
	await _PhaseAllyActions()
	await _PhaseMiss()
	_Print("abort", "中止战局状态机——转确定性直调驱动（生产方法直调口径）")
	_controller.abort_battle()
	await _PhaseEnemyCombo()
	await _PhaseTrapFlash()
	await _PhaseDowns()
	_Finish(t0)

func _EnterBattle() -> void:
	## 直构 BattleParams（4 职业）经 SceneManager 进 BATTLE_SCREEN 并等挂载
	## 参数：无
	## 返回：无（协程——等场景切换落地）
	var game_data: Node = get_tree().root.get_node("GameData")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var party: Array[AdventurerData] = []
	for pair: Array in PARTY:
		var cls: ClassDef = game_data.get_record(pair[1]) as ClassDef
		var attrs: Dictionary[StringName, int] = AttrRoller.roll_fixed_four(cls, rng)
		party.append(AdventurerData.create_debug(pair[0], pair[1], attrs, game_data))
	var params := BattleParams.new()
	params.pack_id = &"enc_m1_lair_pack"
	params.party = party
	var err: Error = get_tree().root.get_node("SceneManager").go(
			SceneManagerScript.SceneId.BATTLE_SCREEN, {&"battle_params": params})
	if err != OK:
		_Print("enter", "SceneManager.go 失败（错误码 %d）" % err)
		return
	for i: int in range(6):
		await get_tree().process_frame
	_battle = get_tree().root.find_child("BattleScreen", true, false) as Control
	if _battle == null or _battle.context == null:
		_Print("enter", "BattleScreen 未挂载或装配降级")
		return
	_ctx = _battle.context
	_controller = _battle.controller
	_Print("enter", "战斗装配成立：我方 %d + 敌方 %d" % [
			_ctx.allies.size(), _ctx.enemies.size()])
	_Print("enter", "敌方站位：%s" % _EnemyRosterText())
	_Print("enter", "我方站位：%s" % _AllyRosterText())

func _EnemyRosterText() -> String:
	## 敌方名册文本（stdout 证据——含精英标记与格位）
	## 参数：无
	## 返回：拼接文本
	var parts: PackedStringArray = []
	for unit: BattleUnit in _ctx.enemies:
		parts.append("%s@(%d,%d)%s" % [unit.display_name, unit.grid_pos.x,
				unit.grid_pos.y, " 精英" if unit.role_tag == UnitTags.ROLE_ELITE else ""])
	return ", ".join(parts)

func _AllyRosterText() -> String:
	## 我方名册文本（stdout 证据——含格位）
	## 参数：无
	## 返回：拼接文本
	var parts: PackedStringArray = []
	for unit: BattleUnit in _ctx.allies:
		parts.append("%s@(%d,%d)" % [unit.display_name, unit.grid_pos.x, unit.grid_pos.y])
	return ", ".join(parts)

func _HookSignals() -> void:
	## 信号钩子：瞬时表现（DOT 白闪/陷阱白闪/倒地）在信号到达瞬间自动连拍
	## —— 与显式相位互补，保证捕捉到 0.25s 白闪的中间帧
	## 参数：无
	## 返回：无
	_controller.round_settled.connect(_OnRoundSettledHook)
	_controller.trap_triggered.connect(_OnTrapTriggeredHook)
	_controller.unit_downed.connect(_OnUnitDownedHook)
	# 技能执行审计：每次执行打一行（施放者/技能/命中/伤害/目标）——截图外的
	# 行为层证据（MISS/白闪时序核对用）
	_controller.skill_executed.connect(_OnSkillAudit)

func _OnSkillAudit(caster: BattleUnit, result: SkillExecutor.ExecutionResult) -> void:
	## 技能执行审计钩子：全量执行结果单行打印（含 AI 与直调）；攻击掷未命中
	## （真实闪避）时自动连拍——MISS 飘字 + 目标不播受击的截图素材
	## 参数 caster：施放单位；result：执行结果
	## 返回：无
	if result == null:
		_Print("audit", "%s 执行结果为空" % caster.display_name)
		return
	var chain: Dictionary = result.trace.get(&"hit_chain", {}) as Dictionary
	var final_chance: float = float(chain.get(&"final", -1.0)) if not chain.is_empty() else -1.0
	_Print("audit", "%s → %s 命中=%s 伤害=%d 暴击=%s 目标=%s 终值命中率=%.4f%s" % [
			caster.display_name, result.trace.get(&"skill", &"?"), result.hit,
			result.damage, result.crit, result.target_id, final_chance,
			"（闪避——不播受击）" if not chain.is_empty() and not result.hit else ""])
	if not chain.is_empty() and not result.hit:
		_Burst("hook_natural_miss_dodge_text_%s" % _SafeTag(caster.display_name), 3, 0.08)

func _SafeTag(text: String) -> String:
	## 截图文件名安全化（中文/空白转下划线）
	## 参数 text：原始文本
	## 返回：安全片段
	var tag: String = text.validate_filename().strip_edges()
	return tag.replace(" ", "_") if not tag.is_empty() else "unit"

func _OnRoundSettledHook(round_no: int, dot_damage: Array) -> void:
	## 回合末结算钩子：DOT 跳伤非空 → 连拍承伤白闪（低7）
	## 参数 round_no：回合号；dot_damage：跳伤清单
	## 返回：无
	if dot_damage.is_empty():
		return
	var parts: PackedStringArray = []
	for entry: Dictionary in dot_damage:
		var unit: BattleUnit = entry.get(&"unit", null)
		parts.append(unit.display_name if unit != null else "?")
	_Print("hook-dot", "回合 %d DOT 跳伤：%s——连拍白闪" % [round_no, ", ".join(parts)])
	_Burst("hook_dot_poison_flash_r%d" % round_no, 3, 0.07)

func _OnTrapTriggeredHook(unit: BattleUnit, damage: int) -> void:
	## 陷阱触发钩子：连拍承伤白闪 + 伤害飘字（低7）
	## 参数 unit：承伤单位；damage：预结算伤害
	## 返回：无
	_Print("hook-trap", "%s 踩陷阱 -%d——连拍白闪" % [unit.display_name, damage])
	_Burst("hook_trap_flash_%s" % String(unit.unit_id).replace("en_m1_", ""), 3, 0.07)

func _OnUnitDownedHook(unit: BattleUnit) -> void:
	## 倒地钩子：连拍倒地动画（末帧锁定前后的帧）
	## 参数 unit：倒地单位
	## 返回：无
	_Print("hook-downed", "%s 倒地——连拍尸态" % unit.display_name)
	_Burst("hook_downed_%s" % String(unit.unit_id).replace("en_m1_", ""), 2, 0.15)

# --------------------------------------------------------------------------
# 相位一：矮窗右栏（中4）
# --------------------------------------------------------------------------

func _PhaseRightPanel() -> void:
	## 中4：1280×720 下右栏竖滚动条出现 + BattleLog/UnitInfoCard 右缘不被裁切。
	## 关键：project 拉伸为 canvas_items+expand（基准 1440×900）——1280×720 窗口
	## 下内容布局实际为 1600×900（右栏高 708 不超高→滚动条不出现）；矮窗契约态
	## 须临时禁用 content scale（内容按窗口像素布局 = 真 1280×720，等价集成测试
	## battle.size=1280×720 口径），拍完恢复标准拉伸
	## 参数：无
	## 返回：无（协程）
	var waited: int = 0
	while (_controller.current_unit == null or not _controller.awaiting_command) \
			and waited < 600:
		await get_tree().process_frame
		waited += 1
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	await _WaitFrames(3)
	var right_panel: ScrollContainer = _battle.get_node("%RightPanel") as ScrollContainer
	var bar: VScrollBar = right_panel.get_v_scroll_bar()
	var card: PanelContainer = _battle.get_node("%UnitInfoCard") as PanelContainer
	var log_panel: PanelContainer = _battle.get_node("%BattleLog") as PanelContainer
	_Print("zhong4", "矮窗档（拉伸禁用）：视口=%s 右栏rect=%s 竖滚动条可见=%s 条宽=%s" % [
			get_viewport().get_visible_rect().size, right_panel.get_global_rect(),
			bar.is_visible_in_tree(), bar.size.x])
	_Print("zhong4", "UnitInfoCard rect=%s（右缘 x=%.0f）/ BattleLog rect=%s（右缘 x=%.0f ≤ 可视右缘 %.0f）" % [
			card.get_global_rect(), card.get_global_rect().end.x,
			log_panel.get_global_rect(), log_panel.get_global_rect().end.x,
			right_panel.get_global_rect().end.x - bar.size.x])
	await _Shot("short_window_1280x720_right_panel_full")
	await _CropShot("right_panel_right_edge_crop", right_panel.get_global_rect().grow(10.0))
	# 滚动到底：日志底部 + 滚动条可操作证据
	right_panel.scroll_vertical = 999999
	await _WaitFrames(2)
	await _Shot("short_window_right_panel_scrolled_bottom")
	right_panel.scroll_vertical = 0
	# 恢复标准拉伸（后续相位正常视觉比例）
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	await _WaitFrames(3)

# --------------------------------------------------------------------------
# 相位二：我方六动作（live 真实指令链）
# --------------------------------------------------------------------------

func _PhaseAllyActions() -> void:
	## 我方动作调度：按真实行动序（速度排序）逐个消费计划动作——
	## 战士=拐点移动+痛击 / 游侠=布置陷阱（CAST 弓姿）/ 法师=火球 /
	## 牧师=惩击；敌方 AI 自动回合自然穿插（真实敌方动作素材）
	## 参数：无
	## 返回：无（协程）
	var pending: Array[StringName] = [&"warrior", &"ranger", &"mage", &"priest"]
	var guard: int = 0
	while not pending.is_empty() and not _controller.is_battle_over() and guard < 4000:
		if _controller.awaiting_command and _controller.current_unit != null:
			var cur: BattleUnit = _controller.current_unit
			if pending.has(cur.unit_id):
				pending.erase(cur.unit_id)
				match cur.unit_id:
					&"warrior":
						await _AllyWarrior(cur)
					&"ranger":
						await _AllyRanger(cur)
					&"mage":
						await _AllyMage(cur)
					_:
						await _AllyPriest(cur)
			else:
				_controller.request_end_unit_turn()
		await get_tree().process_frame
		guard += 1
	if not pending.is_empty():
		_Print("ally", "计划动作未全部消费（剩余 %s）——战局提前收束或超帧" % str(pending))
	# 等回合 1 收尾（敌方自动行动 + 回合末 DOT 钩子自然触发）
	await _WaitRoundStart(2)

func _AllyWarrior(warrior: BattleUnit) -> void:
	## 战士行动轮：①真实 request_move（拐点链移动——低9）②贴身痛击（MELEE 大招）
	## 参数 warrior：战士单位
	## 返回：无（协程）
	_TopUp(warrior)
	var dest: Vector2i = _PickBentDest(warrior)
	if dest != Vector2i(-1, -1):
		var moved: bool = _controller.request_move(dest)
		_Print("warrior", "真实移动 →(%d,%d) 受理=%s｜%s" % [dest.x, dest.y, moved,
				_warrior_move_note])
		await _Burst("warrior_move_waypoint_slide", 9, 0.09)
	else:
		_Print("warrior", "无拐点可达格——跳过移动相位")
	var enemy: BattleUnit = _TargetTrash()
	if enemy != null:
		var adj: Vector2i = _AdjacentCellOf(enemy.grid_pos)
		if adj != enemy.grid_pos and adj != warrior.grid_pos:
			_Teleport(warrior, adj)
			await _WaitSec(0.3)
		_TopUp(warrior)
		_TopUp(enemy)
		_SetClamp(1.0)
		var skill_id: StringName = _SkillIn(warrior, [&"skl_warrior_power_strike"])
		var ok: bool = _controller.request_skill(skill_id, enemy.grid_pos)
		_Print("warrior", "痛击受理=%s 战士姿态=%s（应 MELEE_ATTACK）" % [ok, _PoseOf(warrior)])
		await _Burst("warrior_power_strike_melee_and_hit_flash", 4, 0.07)
		_RestoreClamp()
	if not _controller.is_battle_over():
		_controller.request_end_unit_turn()

func _AllyRanger(ranger: BattleUnit) -> void:
	## 游侠行动轮：布置陷阱（CAST 弓姿 + 陷阱橙点标记）
	## 参数 ranger：游侠单位
	## 返回：无（协程）
	_TopUp(ranger)
	var trap_cell: Vector2i = _PickTrapCell(ranger)
	if trap_cell != Vector2i(-1, -1):
		var ok: bool = _controller.request_skill(
				_SkillIn(ranger, [&"skl_ranger_set_trap"]), trap_cell)
		_Print("ranger", "布置陷阱 →(%d,%d) 受理=%s 姿态=%s（应 CAST_RANGED 弓姿）" % [
				trap_cell.x, trap_cell.y, ok, _PoseOf(ranger)])
		await _Burst("ranger_set_trap_cast_pose", 4, 0.08)
		await _WaitSec(0.5)
		await _Shot("ranger_trap_mark_visible")
	else:
		_Print("ranger", "无可放置陷阱格——跳过")
	# 行动后再移动（S3-03 顺序任意）：走上毒沼——回合末 DOT 跳伤白闪素材
	var poison_dest: Vector2i = _PickPoisonDest(ranger)
	if poison_dest != Vector2i(-1, -1) and not _controller.is_battle_over():
		if _controller.request_move(poison_dest):
			_Print("ranger", "行动后移动上毒沼 →(%d,%d)（回合末 DOT 素材）" % [
					poison_dest.x, poison_dest.y])
			await _Burst("ranger_move_onto_poison", 4, 0.09)
	if not _controller.is_battle_over():
		_controller.request_end_unit_turn()

func _AllyMage(mage: BattleUnit) -> void:
	## 法师行动轮：传送入射程 → 火球（CAST 施法 + 目标 HIT+白闪+伤害飘字）
	## 参数 mage：法师单位
	## 返回：无（协程）
	_TopUp(mage)
	var enemy: BattleUnit = _TargetTrash()
	if enemy != null:
		var cell: Vector2i = _CastCellNear(enemy, &"skl_mage_fireball")
		if cell != Vector2i(-1, -1) and cell != mage.grid_pos:
			_Teleport(mage, cell)
			await _WaitSec(0.35)
		_TopUp(mage)
		_TopUp(enemy)
		_SetClamp(1.0)
		var ok: bool = _controller.request_skill(
				_SkillIn(mage, [&"skl_mage_fireball"]), enemy.grid_pos)
		_Print("mage", "火球受理=%s 法师姿态=%s（应 CAST_RANGED）/ 目标姿态=%s（应 HIT）" % [
				ok, _PoseOf(mage), _PoseOf(enemy)])
		await _Burst("mage_fireball_cast_hit_flash", 5, 0.07)
		_RestoreClamp()
	if not _controller.is_battle_over():
		_controller.request_end_unit_turn()

func _AllyPriest(priest: BattleUnit) -> void:
	## 牧师行动轮：传送入射程 → 惩击（CAST 施法）
	## 参数 priest：牧师单位
	## 返回：无（协程）
	_TopUp(priest)
	var enemy: BattleUnit = _TargetTrash()
	if enemy != null:
		var cell: Vector2i = _CastCellNear(enemy, &"skl_priest_smite")
		if cell != Vector2i(-1, -1) and cell != priest.grid_pos:
			_Teleport(priest, cell)
			await _WaitSec(0.35)
		_TopUp(priest)
		_TopUp(enemy)
		_SetClamp(1.0)
		var ok: bool = _controller.request_skill(
				_SkillIn(priest, [&"skl_priest_smite"]), enemy.grid_pos)
		_Print("priest", "惩击受理=%s 牧师姿态=%s（应 CAST_RANGED）" % [ok, _PoseOf(priest)])
		await _Burst("priest_smite_cast_pose", 4, 0.08)
		_RestoreClamp()
	if not _controller.is_battle_over():
		_controller.request_end_unit_turn()

# --------------------------------------------------------------------------
# 相位三：MISS 必闪避（live 真实指令链）
# --------------------------------------------------------------------------

func _PhaseMiss() -> void:
	## MISS：hit_clamp 双注极小正值（注 0 会回退默认带）→ 战士普攻必闪避
	## ——目标不播受击 + 「闪避」飘字；另审计钩子对自然闪避自动连拍
	## 参数：无
	## 返回：无（协程）
	await _WaitRoundStart(2)
	var warrior: BattleUnit = await _WaitAllyTurn(&"warrior")
	if warrior == null:
		_Print("miss", "未等到战士回合 2——跳过 MISS 相位")
		return
	var enemy: BattleUnit = _TargetTrash()
	if enemy == null:
		enemy = _AnyAliveEnemy()
	if enemy == null:
		_Print("miss", "无存活敌方——跳过")
		_controller.request_end_unit_turn()
		return
	var adj: Vector2i = _AdjacentCellOf(enemy.grid_pos)
	if adj != enemy.grid_pos and adj != warrior.grid_pos:
		_Teleport(warrior, adj)
		await _WaitSec(0.3)
	# 命中钳制带双注极小正值：注 0 会被 BattleRules 回退默认带（读取口带
	# >0 判定）——1e-4 生效且 randf < 1e-4 概率命中，实践必闪避
	_SetClamp(0.0001)
	var ok: bool = _controller.request_skill(warrior.base_attack_id, enemy.grid_pos)
	var miss_note: String = "普攻受理=%s 目标=%s 目标姿态=%s（应非 HIT——闪避不播受击；审计行应见 闪避 标记）" % [
			ok, enemy.display_name, _PoseOf(enemy)]
	_Print("miss", miss_note)
	await _Burst("warrior_attack_miss_dodge_text", 4, 0.1)
	await _CropShot("miss_dodge_text_crop", _CellRectGrow(enemy.grid_pos, 2.4))
	_RestoreClamp()
	if not _controller.is_battle_over():
		_controller.request_end_unit_turn()

# --------------------------------------------------------------------------
# 相位四：敌方连招交替（中1）+ 敌方动作
# --------------------------------------------------------------------------

func _PhaseEnemyCombo() -> void:
	## 中1 连招哑火验证：精英 CAST（威吓怒吼）演出中段紧接 MELEE（普攻）——
	## 修复前 MELEE 被优先级压制哑火；两轮循环 + 穷追 MELEE + 杂兵技
	## 参数：无
	## 返回：无（协程）
	var elite: BattleUnit = _EliteUnit()
	if elite == null:
		_Print("combo", "无存活精英——跳过连招相位")
		return
	var dummy: BattleUnit = _UnitOf(&"warrior")
	if dummy == null or not dummy.alive:
		dummy = _FirstAliveAlly()
	if dummy == null:
		_Print("combo", "无存活我方肉靶——跳过连招相位")
		return
	var adj: Vector2i = _AdjacentCellOf(elite.grid_pos)
	if adj != elite.grid_pos and adj != dummy.grid_pos:
		_Teleport(dummy, adj)
		await _WaitSec(0.35)
	_TopUp(dummy)
	_SetClamp(1.0)
	for cycle: int in range(2):
		elite.current_stamina = elite.max_stamina
		_controller._execute_skill(elite, SKILL_ROAR, elite.grid_pos)
		_Print("combo", "周期 %d 怒吼后精英姿态=%s（应 CAST_RANGED）" % [
				cycle + 1, _PoseOf(elite)])
		# 怒吼 CAST 姿态单拍（快拍不破坏下方 CAST 中紧接 MELEE 的时序窗——
		# CAST 动画 3 帧@8fps≈0.375s）
		await _Shot("enemy_roar_cast_pose_c%d" % (cycle + 1))
		await _WaitSec(0.12)
		elite.current_stamina = elite.max_stamina
		var result: SkillExecutor.ExecutionResult = _controller._execute_skill(
				elite, elite.base_attack_id, dummy.grid_pos)
		var combo_note: String = "周期 %d CAST 中紧接 MELEE → 精英姿态=%s（应 MELEE_ATTACK；修复前被压制保持 CAST 即哑火）命中=%s" % [
				cycle + 1, _PoseOf(elite), result.hit if result != null else false]
		_Print("combo", combo_note)
		await _Burst("enemy_cast_then_melee_combo_c%d" % (cycle + 1), 3, 0.07)
		dummy.heal(999)
		_TopUp(dummy)
		await _WaitSec(0.35)
	elite.current_stamina = elite.max_stamina
	_controller._execute_skill(elite, SKILL_RELENTLESS, dummy.grid_pos)
	_Print("combo", "穷追猛打后精英姿态=%s（应 MELEE_ATTACK）" % _PoseOf(elite))
	await _Burst("enemy_relentless_melee", 3, 0.08)
	dummy.heal(999)
	_TopUp(dummy)
	_RestoreClamp()
	# 杂兵：MELEE 普攻（我方 HIT+白闪——低7 技能命中路径）+ 全部存活杂兵职业技
	#（连拍标签按单位唯一——同名标签会覆盖前一只杂兵的截图文件）
	var dummies_tried: int = 0
	for trash: BattleUnit in _ctx.enemies:
		if not trash.alive or trash.role_tag == UnitTags.ROLE_ELITE:
			continue
		var move_adj: Vector2i = _AdjacentCellOf(dummy.grid_pos, true)
		if move_adj == dummy.grid_pos:
			_Print("trash", "%s 无严格四邻接空格——跳过该杂兵驱动" % trash.display_name)
			continue
		if move_adj != trash.grid_pos:
			_Teleport(trash, move_adj)
			await _WaitSec(0.35)
		_TopUp(trash)
		if dummies_tried == 0:
			_SetClamp(1.0)
			_controller._execute_skill(trash, trash.base_attack_id, dummy.grid_pos)
			_Print("trash", "%s 普攻后姿态=%s（应 MELEE_ATTACK）/ 我方姿态=%s（应 HIT）" % [
					trash.display_name, _PoseOf(trash), _PoseOf(dummy)])
			await _Burst("enemy_common_melee_ally_hit_flash", 4, 0.07)
			dummy.heal(999)
			_TopUp(dummy)
		var trash_tag: String = _SafeTag(trash.display_name)
		var trash_skills: Array[StringName] = []
		for skill_id: StringName in trash.skill_ids:
			if skill_id != trash.base_attack_id \
					and skill_id != SKILL_ROAR and skill_id != SKILL_RELENTLESS:
				trash_skills.append(skill_id)
		for skill_id: StringName in trash_skills:
			_TopUp(trash)
			var job_result: SkillExecutor.ExecutionResult = _controller._execute_skill(
					trash, skill_id, dummy.grid_pos)
			_Print("trash", "%s 职业技 %s → 姿态=%s 受理=%s" % [trash.display_name,
					skill_id, _PoseOf(trash),
					job_result != null and job_result.success])
			await _Burst("enemy_job_skill_%s_%s" % [
					String(skill_id).replace("skl_enemy_", ""), trash_tag], 3, 0.08)
			dummy.heal(999)
			_TopUp(dummy)
		# 驱动完挪远：释放肉靶四邻空格给下一只杂兵贴身
		var far_cell: Vector2i = _FarEmptyCell(dummy)
		if far_cell != Vector2i(-1, -1):
			_Teleport(trash, far_cell)
			await _WaitSec(0.2)
		dummies_tried += 1
	_RestoreClamp()

# --------------------------------------------------------------------------
# 相位五：陷阱触发白闪（低7——真实 _move_unit 踏入链）
# --------------------------------------------------------------------------

func _PhaseTrapFlash() -> void:
	## 陷阱白闪：确保场上有我方陷阱（敌 AI 可能已踩掉——补布）→ 驱动敌方
	## 单位真实 _move_unit 走入触发格（途经扫描 → 伤害直扣 → trap_triggered
	## → HIT+白闪+伤害飘字）
	## 参数：无
	## 返回：无（协程）
	if _ctx.grid.dynamic_tiles.is_empty():
		var ranger: BattleUnit = _UnitOf(&"ranger")
		if ranger != null and ranger.alive:
			_TopUp(ranger)
			var cell: Vector2i = _PickTrapCell(ranger)
			if cell != Vector2i(-1, -1):
				var result: SkillExecutor.ExecutionResult = _controller._execute_skill(
						ranger, _SkillIn(ranger, [&"skl_ranger_set_trap"]), cell)
				_Print("trap", "补布陷阱 →(%d,%d) 受理=%s" % [cell.x, cell.y,
						result != null and result.success])
				await _WaitSec(0.4)
	if _ctx.grid.dynamic_tiles.is_empty():
		_Print("trap", "场上无陷阱可触发——跳过（钩子路径已覆盖则无碍）")
		return
	var trap_cell: Vector2i = _ctx.grid.dynamic_tiles.keys()[0] as Vector2i
	var walker: BattleUnit = _AnyAliveEnemy()
	if walker == null:
		_Print("trap", "无存活敌方Walker——跳过")
		return
	_Print("trap", "驱动 %s 真实 _move_unit 走入陷阱格 (%d,%d)" % [
			walker.display_name, trap_cell.x, trap_cell.y])
	_controller._move_unit(walker, trap_cell)
	await _Burst("enemy_walk_into_trap_flash", 4, 0.07)
	walker.heal(999)

# --------------------------------------------------------------------------
# 相位六：倒地尸态 + 终局（真实执行链致死）
# --------------------------------------------------------------------------

func _PhaseDowns() -> void:
	## 倒地尸态：①敌方被痛击致死（真实执行链）②我方被敌方普攻致死
	## ③battle_ended——尸体常驻 + 结算面板
	## 参数：无
	## 返回：无（协程）
	var victim: BattleUnit = _TargetTrash()
	if victim != null:
		victim.take_damage(victim.current_hp - 1)
		var slayer: BattleUnit = _UnitOf(&"warrior")
		if slayer == null or not slayer.alive:
			slayer = _FirstAliveAlly()
		if slayer != null:
			var adj: Vector2i = _AdjacentCellOf(victim.grid_pos)
			if adj != victim.grid_pos and adj != slayer.grid_pos:
				_Teleport(slayer, adj)
				await _WaitSec(0.3)
			_TopUp(slayer)
			_SetClamp(1.0)
			var result: SkillExecutor.ExecutionResult = _controller._execute_skill(
					slayer, _SkillIn(slayer, [&"skl_warrior_power_strike"]), victim.grid_pos)
			_Print("kill-enemy", "致死链 result=%s 倒地=%s 敌尸姿态=%s（应 DOWNED）" % [
					result != null and result.success,
					result != null and result.downed_units.has(victim.unit_id),
					_PoseOf(victim)])
			await _Burst("enemy_downed_by_strike", 3, 0.12)
			await _WaitSec(0.8)
			await _Shot("enemy_corpse_locked_gray_bars_hidden")
			await _CropShot("enemy_corpse_crop", _UnitRectGrow(victim, 1.7))
			_RestoreClamp()
	var fallen: BattleUnit = _UnitOf(&"mage")
	if fallen == null or not fallen.alive:
		fallen = _FirstAliveAlly()
	if fallen != null:
		fallen.take_damage(fallen.current_hp - 1)
		var killer: BattleUnit = _AnyAliveEnemy()
		if killer != null:
			var adj2: Vector2i = _AdjacentCellOf(fallen.grid_pos)
			if adj2 != fallen.grid_pos and adj2 != killer.grid_pos:
				_Teleport(killer, adj2)
				await _WaitSec(0.3)
			_TopUp(killer)
			_SetClamp(1.0)
			var result2: SkillExecutor.ExecutionResult = _controller._execute_skill(
					killer, killer.base_attack_id, fallen.grid_pos)
			_Print("kill-ally", "我方致死链 result=%s 倒地=%s 我方尸姿态=%s（应 DOWNED）" % [
					result2 != null and result2.success,
					result2 != null and result2.downed_units.has(fallen.unit_id),
					_PoseOf(fallen)])
			await _Burst("ally_downed_by_enemy_attack", 3, 0.12)
			await _WaitSec(0.8)
			await _Shot("ally_corpse_locked_gray_bars_hidden")
			await _CropShot("ally_corpse_crop", _UnitRectGrow(fallen, 1.7))
			_RestoreClamp()
	var result := BattleResult.new()
	result.kind = BattleResult.ResultKind.VICTORY
	result.rounds_used = _ctx.round_no
	_controller.battle_ended.emit(result)
	await _WaitSec(0.9)
	await _Shot("battle_ended_result_panel_corpses_persist")

# --------------------------------------------------------------------------
# 截图与等待工具
# --------------------------------------------------------------------------

func _PrepareOutDir() -> void:
	## 输出目录就绪（建目录 + 清旧 png——重复运行不混批）
	## 参数：无
	## 返回：无
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var dir: DirAccess = DirAccess.open(OUT_DIR)
	if dir == null:
		push_error("[SMOKE] 输出目录不可用 %s" % OUT_DIR)
		return
	for file_name: String in dir.get_files():
		if file_name.ends_with(".png"):
			dir.remove(file_name)

func _Shot(tag: String) -> void:
	## 单帧截图：等本帧绘制完成后取视口纹理存盘（真窗口渲染帧）
	## 参数 tag：验证点标记（文件名组成部分）
	## 返回：无（协程）
	await RenderingServer.frame_post_draw
	_shot_no += 1
	var path: String = "%s%02d_%s.png" % [OUT_DIR, _shot_no, tag]
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(path)
	print("[SHOT] #%02d %s  %dx%d err=%d" % [_shot_no, tag, img.get_width(),
			img.get_height(), err])

func _CropShot(tag: String, rect: Rect2) -> void:
	## 区域特写截图：全帧渲染后按屏幕矩形裁切存盘（右栏/飘字/尸态特写）。
	## rect 为内容坐标（Control.global_rect 系）——canvas_items 拉伸下内容坐标
	## ≠ 窗口像素，须按 内容尺寸→截图尺寸 比例换算后再裁
	## 参数 tag：验证点标记；rect：内容坐标裁切区（自动与视口求交）
	## 返回：无（协程）
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var content_size: Vector2 = get_viewport().get_visible_rect().size
	if content_size.x <= 0.0 or content_size.y <= 0.0:
		return
	var scale: Vector2 = Vector2(img.get_width() / content_size.x,
			img.get_height() / content_size.y)
	var pixel_rect: Rect2 = Rect2(rect.position * scale, rect.size * scale)
	var region: Rect2 = pixel_rect.intersection(Rect2(Vector2.ZERO, img.get_size()))
	if not region.has_area():
		_Print("crop", "裁切区无效 %s——跳过" % rect)
		return
	_shot_no += 1
	var path: String = "%s%02d_%s.png" % [OUT_DIR, _shot_no, tag]
	var crop: Image = img.get_region(region)
	crop.save_png(path)
	print("[SHOT] #%02d %s  crop=%s" % [_shot_no, tag, region])

func _Burst(tag: String, count: int, interval: float) -> void:
	## 短间隔连拍：捕捉白闪（0.25s）/移动中间帧/动作切换等瞬时表现
	## 参数 tag：验证点标记；count：张数；interval：间隔秒
	## 返回：无（协程）
	for i: int in range(1, count + 1):
		await _Shot("%s_%d" % [tag, i])
		if i < count:
			await _WaitSec(interval)

func _WaitFrames(frame_count: int) -> void:
	## 帧级等待（布局重排落定用）
	## 参数 frame_count：帧数
	## 返回：无（协程）
	for i: int in range(frame_count):
		await get_tree().process_frame

func _WaitSec(seconds: float) -> void:
	## 秒级等待（SceneTreeTimer）
	## 参数 seconds：时长
	## 返回：无（协程）
	await get_tree().create_timer(seconds).timeout

func _WaitRoundStart(target_round: int) -> void:
	## 等目标回合开始（期间我方指令窗自动结束行动——敌方 AI 自动推进；
	## 回合末 DOT/陷阱等钩子自然触发）
	## 参数 target_round：目标回合号
	## 返回：无（协程）
	var waited: int = 0
	while _ctx.round_no < target_round and waited < 3600 \
			and not _controller.is_battle_over():
		if _controller.awaiting_command and _controller.current_unit != null:
			_controller.request_end_unit_turn()
		await get_tree().process_frame
		waited += 1
	_Print("round", "当前回合 %d（目标 %d）" % [_ctx.round_no, target_round])

func _WaitAllyTurn(unit_id: StringName) -> BattleUnit:
	## 轮询等指定我方单位行动轮（其余我方自动结束行动；敌方自动推进）
	## 参数 unit_id：单位 id
	## 返回：行动单位（超时/战局收束返回 null）
	var waited: int = 0
	while waited < 3600:
		if _controller.is_battle_over():
			return null
		if _controller.awaiting_command and _controller.current_unit != null:
			var cur: BattleUnit = _controller.current_unit
			if cur.unit_id == unit_id:
				return cur
			_controller.request_end_unit_turn()
		await get_tree().process_frame
		waited += 1
	return null

# --------------------------------------------------------------------------
# 单位/格子查询与夹具
# --------------------------------------------------------------------------

func _UnitOf(unit_id: StringName) -> BattleUnit:
	## 按 id 查我方存活单位
	## 参数 unit_id：单位 id
	## 返回：单位（无存活返回 null）
	for unit: BattleUnit in _ctx.allies:
		if unit.unit_id == unit_id and unit.alive:
			return unit
	return null

func _FirstAliveAlly() -> BattleUnit:
	## 首个存活我方单位
	## 参数：无
	## 返回：单位（无返回 null）
	for unit: BattleUnit in _ctx.allies:
		if unit.alive:
			return unit
	return null

func _EliteUnit() -> BattleUnit:
	## 存活精英（连招相位主角）
	## 参数：无
	## 返回：单位（无返回 null）
	for unit: BattleUnit in _ctx.enemies:
		if unit.alive and unit.role_tag == UnitTags.ROLE_ELITE:
			return unit
	return null

func _TargetTrash() -> BattleUnit:
	## 首个存活非精英敌方（我方集火目标——保精英给连招相位）
	## 参数：无
	## 返回：单位（无返回 null）
	for unit: BattleUnit in _ctx.enemies:
		if unit.alive and unit.role_tag != UnitTags.ROLE_ELITE:
			return unit
	return null

func _AnyAliveEnemy() -> BattleUnit:
	## 首个存活敌方
	## 参数：无
	## 返回：单位（无返回 null）
	for unit: BattleUnit in _ctx.enemies:
		if unit.alive:
			return unit
	return null

func _AdjacentCellOf(center: Vector2i, strict: bool = false) -> Vector2i:
	## 邻接可落格（界内可通行无存活占位优先；全堵回 center）。strict=true 仅
	## 四向 1 格（射程 1 技能贴身驱动用——含 2 格兜底会 out_of_range）
	## 参数 center：目标格；strict：严格四邻接
	## 返回：邻接格
	var deltas: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
			Vector2i(0, -1)]
	if not strict:
		deltas.append_array([Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 0),
				Vector2i(-2, 0)])
	for delta: Vector2i in deltas:
		var cell: Vector2i = center + delta
		if cell.x < 0 or cell.y < 0 or cell.x >= _ctx.grid.size.x \
				or cell.y >= _ctx.grid.size.y:
			continue
		var tile: TileTypeDef = _ctx.grid.tile_at(cell)
		var occupant: Object = _ctx.grid.get_unit_at(cell)
		if tile != null and tile.walkable and occupant == null:
			return cell
	return center

func _PickBentDest(unit: BattleUnit) -> Vector2i:
	## 拐点移动目的地挑选（低9）：可达格中选路径 ≥3 步且方向有拐弯的格
	##（毒沼终点加权——顺带制造回合末 DOT 白闪素材）
	## 参数 unit：移动单位
	## 返回：目的地（无合适返回 (-1,-1)）
	var reachable: Array[Vector2i] = _ctx.grid.find_reachable(unit, unit.move_final())
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: int = -1
	for dest: Vector2i in reachable:
		if dest == unit.grid_pos:
			continue
		var path: Array[Vector2i] = _ctx.grid.find_path(unit, unit.grid_pos, dest,
				unit.move_final())
		if path.size() < 3:
			continue
		var bends: int = 0
		var dir: Vector2i = Vector2i.ZERO
		var prev: Vector2i = unit.grid_pos
		for cell: Vector2i in path:
			var step_dir: Vector2i = cell - prev
			if dir != Vector2i.ZERO and step_dir != dir:
				bends += 1
			dir = step_dir
			prev = cell
		var tile: TileTypeDef = _ctx.grid.tile_at(dest)
		var on_poison: bool = tile != null and tile.status_id == &"DEBUFF_tile_poison"
		# 拐点优先（低9 证据主体），毒沼次之（DOT 素材另有游侠相位兜底）
		var score: int = bends * 100 + path.size() * 10 + (30 if on_poison else 0)
		if score > best_score:
			best_score = score
			best = dest
			_warrior_move_note = "路径=%s 拐点=%d 终点地格=%s" % [str(path), bends,
					tile.display_name if tile != null else "?"]
	return best

func _PickPoisonDest(unit: BattleUnit) -> Vector2i:
	## 毒沼目的地挑选（DOT 白闪素材）：可达格中站位地格为毒沼者
	## 参数 unit：移动单位
	## 返回：目的地（无返回 (-1,-1)）
	var reachable: Array[Vector2i] = _ctx.grid.find_reachable(unit, unit.move_final())
	for dest: Vector2i in reachable:
		var tile: TileTypeDef = _ctx.grid.tile_at(dest)
		if tile != null and tile.status_id == &"DEBUFF_tile_poison":
			return dest
	return Vector2i(-1, -1)

func _FarEmptyCell(anchor: BattleUnit) -> Vector2i:
	## 远位空格挑选（杂兵驱动后挪位释放贴身格用）：可通行、无占位、
	## 与锚点曼哈顿距离 ≥5，偏地图上半优先
	## 参数 anchor：锚点单位（远离谁）
	## 返回：格（无返回 (-1,-1)）
	for y: int in _ctx.grid.size.y:
		for x: int in _ctx.grid.size.x:
			var cell: Vector2i = Vector2i(x, y)
			var tile: TileTypeDef = _ctx.grid.tile_at(cell)
			if tile == null or not tile.walkable:
				continue
			if _ctx.grid.get_unit_at(cell) != null:
				continue
			if BattleGrid.manhattan(cell, anchor.grid_pos) < 5:
				continue
			return cell
	return Vector2i(-1, -1)

func _PickTrapCell(unit: BattleUnit) -> Vector2i:
	## 陷阱放置格挑选：射程内普通可通行空格 + 视线通 + 无既有动态地格
	##（偏北优先——贴近敌方来路）
	## 参数 unit：游侠
	## 返回：格（无合适返回 (-1,-1)）
	var skill: SkillDef = _ctx.skill_lookup.call(&"skl_ranger_set_trap") as SkillDef
	var candidates: Array[Vector2i] = SkillExecutor.range_cells_of(skill,
			unit.grid_pos, _ctx.grid)
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: int = 1000000
	for cell: Vector2i in candidates:
		var tile: TileTypeDef = _ctx.grid.tile_at(cell)
		if tile == null or not tile.walkable or tile.kind != TileTypeDef.Kind.NORMAL:
			continue
		if _ctx.grid.get_unit_at(cell) != null:
			continue
		if not _ctx.grid.dynamic_tile_at(cell).is_empty():
			continue
		if SkillExecutor.los_required(skill) \
				and not _ctx.grid.has_line_of_sight(unit.grid_pos, cell):
			continue
		var score: int = cell.y * 10 + absi(cell.x - unit.grid_pos.x)
		if score < best_score:
			best_score = score
			best = cell
	return best

func _CastCellNear(enemy: BattleUnit, skill_id: StringName) -> Vector2i:
	## 施法落位挑选：技能射程内（含视线通）的空格——远离目标且偏我方侧
	##（远程职业传送入位用）
	## 参数 enemy：集火目标；skill_id：施放技能
	## 返回：格（无合适返回 (-1,-1)）
	var skill: SkillDef = _ctx.skill_lookup.call(skill_id) as SkillDef
	var max_range: int = SkillExecutor.effective_range(skill)
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: int = -1000000
	for y: int in _ctx.grid.size.y:
		for x: int in _ctx.grid.size.x:
			var cell: Vector2i = Vector2i(x, y)
			var tile: TileTypeDef = _ctx.grid.tile_at(cell)
			if tile == null or not tile.walkable:
				continue
			if _ctx.grid.get_unit_at(cell) != null:
				continue
			var dist: int = BattleGrid.manhattan(cell, enemy.grid_pos)
			if dist > max_range or dist < 2:
				continue
			if SkillExecutor.los_required(skill) \
					and not _ctx.grid.has_line_of_sight(cell, enemy.grid_pos):
				continue
			var score: int = -dist * 10 + y
			if score > best_score:
				best_score = score
				best = cell
	return best

func _SkillIn(unit: BattleUnit, preferred: Array[StringName]) -> StringName:
	## 技能可用性挑选：优先表内首选，单位未持有回退普攻
	## 参数 unit：施放单位；preferred：首选技能列表
	## 返回：技能 id
	for skill_id: StringName in preferred:
		if unit.skill_ids.has(skill_id):
			return skill_id
	return unit.base_attack_id

func _Teleport(unit: BattleUnit, cell: Vector2i) -> void:
	## 传送夹具：复用生产 _move_unit（remove/place/站位状态/unit_moved 信号
	## ——徽章随信号同步移动；与集成测试同口径，不新增生产口）
	## 参数 unit：单位；cell：目的地
	## 返回：无
	_controller._move_unit(unit, cell)

func _TopUp(unit: BattleUnit) -> void:
	## 资源回满夹具：HP/法力/精力顶满（多轮驱动的视觉稳定性）
	## 参数 unit：单位
	## 返回：无
	unit.current_hp = unit.max_hp
	unit.current_mana = unit.max_mana
	unit.current_stamina = unit.max_stamina
	var board: BattleBoard = _battle.get_node("%BoardLayer") as BattleBoard
	board.refresh_badge(unit)

func _SetClamp(value: float) -> void:
	## 命中钳制带注入：双注同值（1.0 必命中；闪避须注极小正值如 1e-4——
	## BattleRules 读取口带 >0 判定，注 0 会回退默认带 0.05/0.95 不生效）
	## 参数 value：钳制值
	## 返回：无
	_ctx.cfg.hit_clamp_min = value
	_ctx.cfg.hit_clamp_max = value

func _RestoreClamp() -> void:
	## 命中钳制带还原（相位后必达——不污染后续运行）
	## 参数：无
	## 返回：无
	_ctx.cfg.hit_clamp_min = _clamp_min_bak
	_ctx.cfg.hit_clamp_max = _clamp_max_bak

func _BadgeOf(unit: BattleUnit) -> UnitBadge:
	## 单位徽章查询（板面子节点扫描——姿态/矩形证据）
	## 参数 unit：单位
	## 返回：徽章（无返回 null）
	var board: BattleBoard = _battle.get_node("%BoardLayer") as BattleBoard
	for child: Node in board.get_children():
		if child is UnitBadge and (child as UnitBadge).unit == unit:
			return child as UnitBadge
	return null

func _PoseOf(unit: BattleUnit) -> String:
	## 单位当前姿态名（stdout 证据——截图外的行为层核验）
	## 参数 unit：单位
	## 返回：动作名（无徽章返回 "?"）
	var badge: UnitBadge = _BadgeOf(unit)
	return ACTION_NAMES[badge.anim.current] if badge != null else "?"

func _UnitRectGrow(unit: BattleUnit, grow_scale: float) -> Rect2:
	## 单位所在格屏幕矩形放大（尸态特写裁切区——徽章锚定全板面，其
	## global_rect 恒为整板，改按单位格位取真实小矩形）
	## 参数 unit：单位；grow_scale：放大倍数
	## 返回：屏幕矩形（内容坐标）
	return _CellRectGrow(unit.grid_pos, grow_scale)

func _CellRectGrow(cell: Vector2i, grow_scale: float) -> Rect2:
	## 格子屏幕矩形放大（飘字特写裁切区）
	## 参数 cell：格坐标；grow_scale：放大倍数
	## 返回：屏幕矩形
	var board: BattleBoard = _battle.get_node("%BoardLayer") as BattleBoard
	var rect: Rect2 = board.cell_rect(cell)
	var size: Vector2 = rect.size * grow_scale
	return Rect2(board.global_position + rect.get_center() - size * 0.5, size)

func _Print(tag: String, msg: String) -> void:
	## 统一时序日志（stdout——供人工比对截图时刻）
	## 参数 tag：相位标记；msg：内容
	## 返回：无
	print("[SMOKE][%s] %s" % [tag, msg])

func _Finish(t0: int) -> void:
	## 收尾：还原钳制带 → 输出截图清单与耗时 → 退出
	## 参数 t0：启动毫秒时间戳
	## 返回：无（协程）
	_done = true
	_RestoreClamp()
	var dir: DirAccess = DirAccess.open(OUT_DIR)
	var count: int = 0
	var bytes: int = 0
	if dir != null:
		for file_name: String in dir.get_files():
			if file_name.ends_with(".png"):
				var file: FileAccess = FileAccess.open(OUT_DIR + file_name,
						FileAccess.READ)
				if file != null:
					count += 1
					bytes += file.get_length()
	_Print("done", "驱动序列完成：截图 %d 张 / 共 %.1f MB / 耗时 %.1f s——自动退出" % [
			count, bytes / 1048576.0, (Time.get_ticks_msec() - t0) / 1000.0])
	await _WaitSec(0.5)
	get_tree().quit(0)
