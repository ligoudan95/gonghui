## 战斗日志栏（BattleLog，PanelContainer——右侧栏 UnitInfoCard 正下方）
## 职责：实时滚动展示战斗全过程——回合/行动轮/移动/技能执行明细（消费
## ExecutionResult.trace 结构化键值，中文模板在 UI 层——逻辑层零文案）、
## 状态变化/倒地/终局。数值链路可视化 = 17 案验算带的玩家侧呈现
## （2026-09-24 五轮试玩反馈）。
## 行为：新条目自动滚到底；条目上限 500 裁旧（防无限增长）。
## 输入口径：自身 STOP（要滚动）且不越出自身 rect——绝不复刻 ResultLayer
## 全屏遮挡事故；订阅 controller 现有信号（round/turn/moved/skill/status/
## downed/ended），无新信号。
class_name BattleLog
extends PanelContainer

## 条目类型（着色分派）
enum LineKind {
	SYSTEM,
	DAMAGE,
	HEAL,
	STATUS,
	MOVE,
}

## 条目上限（超出裁最旧，防无限增长）
const MAX_LINES: int = 500
## 失败码 → 中文（UI 模板层文案映射；键 = SkillExecutor 失败码常量——A-5 单源）
const FAIL_TEXTS: Dictionary = {
	SkillExecutor.ERROR_OUT_OF_RANGE: "射程外",
	SkillExecutor.ERROR_NO_LINE_OF_SIGHT: "视线阻断",
	SkillExecutor.ERROR_INVALID_TARGET: "目标非法",
	SkillExecutor.ERROR_TARGET_DOWNED: "目标已倒地",
	SkillExecutor.ERROR_NO_RESOURCE: "资源不足",
	SkillExecutor.ERROR_CASTER_DOWNED: "施放者已倒地",
	SkillExecutor.ERROR_BLOCKED_CELL: "目标格不可放置",
}
## 通用提示模板（B-8：battle_screen 直写文案收口到模板常量层——
## UI 文案单源，改口吻只动此处）
const MSG_LOS_BLOCKED: String = "视线被障碍阻断——请选择可直视的目标"
const MSG_TARGET_INVALID_ALLY: String = "目标非法——该技能只能作用于友方单位"
const MSG_TARGET_OUT_OF_RANGE: String = "目标超出射程——请选择射程内目标"
const MSG_MOVE_REJECTED: String = "无法移动到该格——请重新选择"

## 施加失败原因 → 中文（S2-2：stack_limit 等拒收原因可感知，资源白扣
## 不再无反馈；键 = StatusManager 拒收原因契约）
const APPLY_FAIL_TEXTS: Dictionary = {
	&"miss": "未命中",
	&"resisted": "被抵抗",
	&"stack_limit": "叠层已满",
	&"source_not_allowed": "来源不符",
}

## 战斗上下文（单位名解析；可空）
var context: BattleSetup.BattleContext = null

## 行色档（B-6：LineKind -> cfg 字段名 + UiTheme 兜底——setup 后按表驱动取色）
const LINE_COLOR_FIELDS: Dictionary = {
	LineKind.SYSTEM: [&"ui_log_system_color", UiTheme.LOG_SYSTEM],
	LineKind.DAMAGE: [&"ui_log_damage_color", UiTheme.LOG_DAMAGE],
	LineKind.HEAL: [&"ui_log_heal_color", UiTheme.LOG_HEAL],
	LineKind.STATUS: [&"ui_log_status_color", UiTheme.LOG_STATUS],
	LineKind.MOVE: [&"ui_log_move_color", UiTheme.LOG_MOVE],
}

## 行色读取（B-6：cfg 优先、UiTheme 兜底）
func _Line_color(kind: int) -> Color:
	## 参数 kind：LineKind
	## 返回：生效颜色
	var field: Array = LINE_COLOR_FIELDS.get(kind, LINE_COLOR_FIELDS[LineKind.SYSTEM])
	return UiTheme.color_of(context.cfg if context != null else null, field[0], field[1])
## 条目容器
var _entries: VBoxContainer = null
## 滚动容器
var _scroll: ScrollContainer = null

func _ready() -> void:
	## 引擎回调：半透明深底 + 滚动区 + 条目容器（子节点自建——参照 ResultPanel）
	## 参数：无
	## 返回：无
	# B-4：深底面板样式单源（UiTheme.make_dark_panel_style——与 tips 共用，
	# 原 alpha 0.86/0.92 漂移统一 0.9）
	add_theme_stylebox_override("panel",
			UiTheme.make_dark_panel_style(context.cfg if context != null else null))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_entries = VBoxContainer.new()
	_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries.add_theme_constant_override("separation", 2)
	_scroll.add_child(_entries)

func setup(log_controller: BattleController, log_context: BattleSetup.BattleContext) -> void:
	## 订阅控制器信号（信号自带参数即日志数据——trace 经 skill_executed 携带）
	## 参数 log_controller：战斗控制器；log_context：战斗上下文（单位名解析，可空）
	## 返回：无
	context = log_context
	log_controller.round_started.connect(func(round_no: int) -> void:
		push_line("—— 回合 %d ——" % round_no, LineKind.SYSTEM))
	log_controller.turn_started.connect(func(unit: BattleUnit) -> void:
		push_line("▶ %s 行动" % _NameOf(unit.unit_id), LineKind.SYSTEM))
	log_controller.unit_moved.connect(
			func(unit: BattleUnit, from_pos: Vector2i, to_pos: Vector2i) -> void:
		push_line("%s 移动 (%d,%d)→(%d,%d)" % [
			_NameOf(unit.unit_id), from_pos.x, from_pos.y, to_pos.x, to_pos.y,
		], LineKind.MOVE))
	log_controller.skill_executed.connect(
			func(caster: BattleUnit, result: SkillExecutor.ExecutionResult) -> void:
		push_skill_trace(_NameOf(caster.unit_id), result))
	log_controller.round_settled.connect(func(_round_no: int, dot_damage: Array) -> void:
		# DOT 跳伤逐条成行（盲审批 3 D-2：回合末结算可见化——地格来源在先、
		# 状态来源在后，与结算时序一致；无跳不打占位行——回合头行已有分隔）
		for entry: Dictionary in dot_damage:
			var unit: BattleUnit = entry.get(&"unit", null) as BattleUnit
			if unit != null:
				push_line("%s 跳伤 −%d" % [_NameOf(unit.unit_id), int(entry.get(&"damage", 0))],
						LineKind.DAMAGE))
	log_controller.status_changed.connect(
			func(unit: BattleUnit, status_id: StringName) -> void:
		push_line("%s 状态变化：%s" % [_NameOf(unit.unit_id), _StatusNameOf(status_id)],
				LineKind.STATUS))
	log_controller.unit_downed.connect(func(unit: BattleUnit) -> void:
		push_line("%s 倒地" % _NameOf(unit.unit_id), LineKind.DAMAGE))
	log_controller.trap_triggered.connect(func(unit: BattleUnit, damage: int) -> void:
		push_line("%s 踩中陷阱 −%d" % [_NameOf(unit.unit_id), damage], LineKind.DAMAGE))
	log_controller.battle_ended.connect(func(result: BattleResult) -> void:
		push_line("◆ %s（%d 回合）" % [result.kind_text(), result.rounds_used],
				LineKind.SYSTEM))
	# R3-01：setup 时 context 就绪——按表值重建面板样式（_ready 期 context
	# 为空只能用兜底色，表驱动的深底色自此生效）
	add_theme_stylebox_override("panel",
			UiTheme.make_dark_panel_style(context.cfg if context != null else null))

func push_line(text: String, kind: int) -> void:
	## 追加一条日志（公开口——信号回调与测试消费）；自动滚底、超限裁旧
	## 参数 text：行文本；kind：LineKind 着色类型
	## 返回：无
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",
			UiTheme.font_of(context.cfg if context != null else null,
					&"ui_font_size_minor", UiTheme.FONT_MINOR))
	label.add_theme_color_override("font_color", _Line_color(kind))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entries.add_child(label)
	while _entries.get_child_count() > MAX_LINES:
		var oldest: Node = _entries.get_child(0)
		oldest.queue_free()
		_entries.remove_child(oldest)
	_ScrollToBottom.call_deferred()

func push_skill_trace(caster_name: String, result: SkillExecutor.ExecutionResult) -> void:
	## 技能执行条目（消费 trace 结构化键值套中文模板；失败/命中/伤害/治疗/
	## 状态/陷阱链按存在性渲染——headless 渲染冒烟的测试入口）
	## 参数 caster_name：施放者显示名；result：执行结果（含 trace）
	## 返回：无
	var trace: Dictionary = result.trace
	var skill_name: String = _SkillNameOf(trace.get(&"skill", &""))
	# 失败：失败码中文映射（无后续链）
	if trace.has(&"fail_reason"):
		var reason: StringName = trace[&"fail_reason"]
		push_line("%s · %s → 失败：%s" % [caster_name, skill_name,
				FAIL_TEXTS.get(reason, String(reason))], LineKind.SYSTEM)
		return
	# 主行：施放者 · 技能 → 目标
	var target_name: String = _NameOf(trace.get(&"target", &""))
	var header: String = "%s · %s" % [caster_name, skill_name]
	if not target_name.is_empty():
		header += " → %s" % target_name
	var header_kind: int = LineKind.SYSTEM
	if trace.has(&"damage_chain"):
		header_kind = LineKind.DAMAGE
	elif trace.has(&"heal"):
		header_kind = LineKind.HEAL
	elif trace.has(&"statuses"):
		header_kind = LineKind.STATUS
	push_line(header, header_kind)
	# 命中链：构成（基础+修正−闪避）→ 掷骰结果
	if trace.has(&"hit_chain"):
		var hit_chain: Dictionary = trace[&"hit_chain"]
		var hit_line: String = "  命中 %d%%（基准 %d +修正 %d −闪避 %d）→ %s" % [
			UiTheme.pct(float(hit_chain[&"final"])),
			UiTheme.pct(float(hit_chain[&"base"])),
			int(hit_chain[&"mod"]),
			UiTheme.pct(float(hit_chain[&"dodge"])),
			"命中" if hit_chain[&"passed"] else "失手",
		]
		push_line(hit_line, LineKind.SYSTEM)
		if not hit_chain[&"passed"]:
			return
	# 伤害链：面板输出 → 减免轨 → 暴击 → 最终
	if trace.has(&"damage_chain"):
		var chain: Dictionary = trace[&"damage_chain"]
		var crit_text: String = "未暴击"
		if chain[&"crit"]:
			crit_text = "暴击 %d%%" % UiTheme.pct(float(chain[&"crit_chance"]))
		push_line("  输出 %.1f（站位×%.1f 克制×%.1f）→ 减免（抗 %d%% 甲 %d 穿 %d）%d → %s → 最终 %d" % [
			float(chain[&"raw"]),
			float(chain[&"panel_mult"]),
			float(chain[&"race_mult"]),
			roundi(float(chain[&"resist"]) * 100.0),
			int(chain[&"armor"]),
			int(chain[&"pierce"]),
			int(chain[&"mitigated"]),
			crit_text,
			int(chain[&"final"]),
		], LineKind.DAMAGE)
	# 倒地
	for unit_id: StringName in result.downed_units:
		push_line("  %s 倒地" % _NameOf(unit_id), LineKind.DAMAGE)
	# 治疗链
	if trace.has(&"heal"):
		push_line("  治疗 %d" % int(trace[&"heal"]), LineKind.HEAL)
	# 状态链：逐条施加成败（状态名中文——批 D L7；S2-2：失败原因区分——
	# 未命中/被抵抗/叠层已满/来源不符，资源白扣可感知）
	if trace.has(&"statuses"):
		for entry: Dictionary in trace[&"statuses"]:
			var applied_text: String = "✓"
			if not entry[&"applied"]:
				var reason: StringName = entry.get(&"reason", &"resisted")
				applied_text = "✗（%s）" % APPLY_FAIL_TEXTS.get(reason, String(reason))
			push_line("  施加 %s %d 回合 %s" % [
					_StatusNameOf(entry[&"id"]), int(entry[&"duration"]), applied_text],
					LineKind.STATUS)
	# 陷阱链
	if trace.has(&"trap"):
		var trap: Dictionary = trace[&"trap"]
		var cell: Vector2i = trap[&"cell"]
		push_line("  布置于 (%d,%d)｜预结算伤害 %d" % [
				cell.x, cell.y, int(trap[&"damage"])], LineKind.STATUS)

func get_entries() -> VBoxContainer:
	## 条目容器查询（测试与 UI 自动化消费）
	## 参数：无
	## 返回：条目 VBox；未就绪返回 null
	return _entries

func _NameOf(unit_id: StringName) -> String:
	## 单位 id → 显示名（单源薄转发——批 4 C 组 M4：口径集中
	## BattleContext.display_name_of；空 context 回退 id 原文）
	## 参数 unit_id：单位 id
	## 返回：显示名
	if context != null:
		return context.display_name_of(unit_id)
	return String(unit_id)

func _SkillNameOf(skill_id: StringName) -> String:
	## 技能 id → 中文名（批 D L7：经 context.skill_lookup 查表；
	## 查无/空 context 回退 id 原文）
	## 参数 skill_id：技能 id
	## 返回：显示名
	if context != null and not String(skill_id).is_empty():
		var skill: SkillDef = context.skill_lookup.call(skill_id) as SkillDef
		if skill != null and not skill.display_name.is_empty():
			return skill.display_name
	return String(skill_id)

func _StatusNameOf(status_id: StringName) -> String:
	## 状态 id → 中文名（批 D L7：经 context.status_lookup 查表；
	## 查无/空 context 回退 id 原文）
	## 参数 status_id：状态 id
	## 返回：显示名
	if context != null and not String(status_id).is_empty():
		var status: StatusDef = context.status_lookup.call(status_id) as StatusDef
		if status != null and not status.display_name.is_empty():
			return status.display_name
	return String(status_id)

func _ScrollToBottom() -> void:
	## 滚到底部（deferred——条目布局落定后执行）
	## 参数：无
	## 返回：无
	if _scroll != null:
		_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value
