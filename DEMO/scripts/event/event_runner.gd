## 事件引擎（EventRunner，RefCounted 纯逻辑类）
## 职责：事件会话驱动——链入口/单点视图构建、选项结算（检定掷骰/PURE 直进/
## 四档修饰叠加/耗时）、出口解析（A 奖励+授予+解锁、B 战斗参数组装、C/D
## 拦截）、敌方分布映射（clustered/spread → 槽位序列）。
## 数据来源：案 8《事件与检定》（引擎机制）；案 18（DEMO 内容消费）。
## 纯逻辑约束：不触任何 autoload——cfg/lookup/rng 全注入；C/D 拦截经
## enabled_flags 注入（解锁标记/消耗状态由宿主提供，不查单例）；
## 逻辑层零文案（拦截/授予等反馈语义经视图标记回带，文本由 UI 层拼接）。
class_name EventRunner
extends RefCounted

## 事件视图（纯数据快照——UI 呈现层消费）
class EventView:
	extends RefCounted
	## 当前叙述文本（终端节点 = 叙述 + 换行 + 结算文本追加——E2）
	var narrative: String = ""
	## 可选项清单：[{id/text/attr_label/tier_label/tier_line/cost_days}]
	var options: Array = []
	## 视图携带出口（单点无检定=直接结算视图 null；B 出口战前演出）
	var pending_outcome: EventOutcomeDef = null
	## 检定档位（CheckResult.Grade 快照；-1 = 无检定——UI 四档反馈条消费 E5）
	var check_grade: int = -1
	## 本次结算奖励增量（&"exp"/&"gold"/&"reputation"——UI 数值行拼装；
	## B 出口战前不计入（奖励战后 post_battle 入账——E2-8））
	var reward_gained: Dictionary = {}
	## 本次结算队伍 HP 变化（负 = 损耗——UI 数值行；B 战前演出视图同带 E5）
	var hp_delta: int = 0
	## 当前去向节点 id（引擎单源回带——宿主战后续跑锚点消费；
	## 非节点视图（直接出口/单点）为空——E6）
	var node_id: StringName = &""
	## 授予委托标记（E8：UI 固定句式反馈行消费；granted_is_new = false 时
	## 播补叙文本——18-C6 防重）
	var granted_quest_id: StringName = &""
	var granted_is_new: bool = true
	## C/D 出口拦截标记（E3-11：拦截文本由 UI 层模板承载——逻辑层零文案）
	var intercepted: bool = false

## 总控配置（setup 注入）
var _cfg: CoreConfig = null
## 三域 lookup（setup 注入：chains/nodes+options+singles 合一闭包）
var _lookup: Callable = Callable()
## 随机源（setup 注入）
var _rng: RandomNumberGenerator = null
## 已终局事件集（E7：choose_option 结算视图已产出——同 run 同事件重复调用
## 拒绝，防重复入账；键 = ExpeditionRun 实例 → {event_id: true}——按 run
## 隔离，同 runner 驱动多 run（测试/并行会话）互不串扰）
var _finalized_events: Dictionary = {}

func setup(cfg: CoreConfig, lookup: Callable, rng: RandomNumberGenerator) -> void:
	## 装配引擎（依赖注入——headless 可测）
	## 参数 cfg：总控配置；lookup：事件资源 id -> Resource 闭包
	## （chains/nodes/options/singles 四域合一）；rng：随机源
	## 返回：无
	_cfg = cfg
	_lookup = lookup
	_rng = rng

func start_event(event_id: StringName, run: ExpeditionRun) -> EventView:
	## 事件入口：chain_ → 入口节点视图；sp_ → 单点视图（已消耗返回空视图）
	## 参数 event_id：链/单点事件 id；run：出征运行态（消耗标记读写）
	## 返回：EventView（narrative 为空且无 pending = 已消耗或不存在）
	var view := EventView.new()
	if run.consumed_events.has(event_id):
		return view
	if String(event_id).begins_with("chain_"):
		var chain: EventChainDef = _Lookup(event_id) as EventChainDef
		if chain == null:
			return view
		_FillNodeView(view, chain.entry_node_id, run)
	elif String(event_id).begins_with("sp_"):
		var single: SingleEventDef = _Lookup(event_id) as SingleEventDef
		if single == null:
			return view
		view.narrative = single.narrative_text
		view.pending_outcome = null
		# 单点视图：无检定事件挂单档出口（UI 直接结算）；有检定挂虚拟检定选项
		if String(single.check_attr_id).is_empty():
			# 无检定单档：立即结算（叙述+出口奖励一并落账）
			_ResolveOutcome(view, single.success_outcome, false, false, null, run)
		else:
			view.options.append(_CheckOptionView(&"", single.display_name,
					single.check_attr_id, single.difficulty_tier, 0))
		run.consumed_events[event_id] = true
		return view
	else:
		_FillNodeView(view, event_id, run)
	if not view.narrative.is_empty():
		run.consumed_events[event_id] = true
	return view

func choose_option(event_id: StringName, option_id: StringName, actor: AdventurerData,
		run: ExpeditionRun) -> EventView:
	## 选项结算：PURE 直进 → CHECK 掷骰 → 四档修饰叠加 → 耗时 → 去向解析。
	## 单点事件（option_id 空）走 actor 检定分流。四档档位与修饰经节点去向
	## 透传（E1：去向=下一节点型检定选项的 crit 修饰在终端节点结算时叠加）。
	## 参数 event_id：事件 id；option_id：选项 id（单点为空）；actor：施检者
	## （可空=空名单——检定走 FAILURE 分支防死锁）；run：运行态
	## 返回：去向视图（B 出口视图 pending_outcome 带 battle——宿主路由战斗）；
	## 已终局事件（E7）或查无配置返回空视图
	var view := EventView.new()
	if _IsFinalized(run, event_id):
		# E7 会话防重：终局后同 run 同事件重复调用拒绝（防重复入账）
		return view
	var option: EventOptionDef = null
	var single: SingleEventDef = null
	if option_id != &"":
		option = _Lookup(option_id) as EventOptionDef
		if option == null:
			return view
	else:
		single = _Lookup(event_id) as SingleEventDef
		if single == null:
			return view
	# 耗时（选项侧申报）
	if option != null and option.cost_days > 0:
		run.extra_days += option.cost_days
	# 检定分流
	var is_success: bool = true
	var is_crit_success: bool = false
	var is_crit_failure: bool = false
	if option != null and option.kind == EventOptionDef.OptionKind.PURE:
		is_success = true
	elif single == null and option.kind == EventOptionDef.OptionKind.CHECK:
		var check: CheckResult = _RollCheck(actor, option.check_attr_id, option.difficulty_tier)
		is_success = check.grade == CheckResult.Grade.SUCCESS \
				or check.grade == CheckResult.Grade.CRIT_SUCCESS
		is_crit_success = check.grade == CheckResult.Grade.CRIT_SUCCESS
		is_crit_failure = check.grade == CheckResult.Grade.CRIT_FAILURE
		view.check_grade = check.grade
	elif single != null and not String(single.check_attr_id).is_empty():
		var check: CheckResult = _RollCheck(actor, single.check_attr_id, single.difficulty_tier)
		is_success = check.grade == CheckResult.Grade.SUCCESS \
				or check.grade == CheckResult.Grade.CRIT_SUCCESS
		is_crit_success = check.grade == CheckResult.Grade.CRIT_SUCCESS
		is_crit_failure = check.grade == CheckResult.Grade.CRIT_FAILURE
		view.check_grade = check.grade
	# 四档修饰（按档取：crit 成功/失败侧；success/failure 侧无修饰）
	var modifier: EventModifierDef = null
	var modifier_owner: Resource = option if option != null else single
	if modifier_owner != null:
		if is_crit_success:
			modifier = modifier_owner.crit_modifier
		elif is_crit_failure:
			modifier = modifier_owner.crit_fail_modifier
	# 单点事件：直接出口结算（无节点去向）
	if single != null:
		var single_outcome: EventOutcomeDef = single.success_outcome if is_success \
				else single.failure_outcome
		_ResolveOutcome(view, single_outcome, is_crit_success, is_crit_failure,
				modifier, run)
		_MarkFinalized(run, event_id)
		return view
	# 链内选项：去向出口（四档修饰在 resolve/终端节点结算时按档叠加）
	var outcome: EventOutcomeDef = null
	var next_node_id: StringName = &""
	if is_success:
		next_node_id = option.success_to
		outcome = option.success_outcome
	else:
		next_node_id = option.failure_to
		outcome = option.failure_outcome
	if outcome != null:
		_ResolveOutcome(view, outcome, is_crit_success, is_crit_failure,
				modifier, run)
	elif next_node_id != &"":
		# E1：去向=下一节点型——档位与修饰三参透传（终端节点结算时叠加）
		_FillNodeView(view, next_node_id, run, is_crit_success, is_crit_failure,
				modifier)
	if view.options.is_empty():
		_MarkFinalized(run, event_id)
	return view

func resolve_outcome(outcome: EventOutcomeDef, run: ExpeditionRun) -> EventView:
	## 出口直解（战后 post_battle 消费口）：A 结算 + 文本视图
	## 参数 outcome：出口（通常 post_battle）；run：运行态
	## 返回：结算视图（narrative = 结算文本）
	var view := EventView.new()
	_ResolveOutcome(view, outcome, false, false, null, run)
	return view

func build_battle_params(outcome: EventOutcomeDef, run: ExpeditionRun) -> BattleParams:
	## B 出口 → BattleParams 组装：pack/先手映射/分布序列/初始状态（未倒地
	## 全员 CHECKIN 开局载入链）/HP 覆写（倒地成员跳过——案 18「倒地保持
	## 至回城」，不带入战斗避免 clamp 把 0 血拉 1 复活）
	## 参数 outcome：B 出口（battle 必填）；run：运行态
	## 返回：BattleParams（宿主补 party 后路由战斗屏）
	var params := BattleParams.new()
	params.pack_id = outcome.battle.pack_id
	params.first_strike = _FirstStrikeOf(outcome.battle.first_strike_token)
	params.enemy_spawn_override = _LayoutSlotsOf(outcome.battle.enemy_layout_token)
	if not String(outcome.battle.initial_status_id).is_empty():
		var status: StatusDef = _Lookup(outcome.battle.initial_status_id) as StatusDef
		var duration: int = status.default_duration if status != null else 1
		for adv: AdventurerData in run.party:
			if run.downed.get(adv, false):
				continue
			params.initial_statuses.append({
				&"status_id": outcome.battle.initial_status_id,
				&"target": adv.unit_id,
				&"duration": duration,
			})
	# HP 覆写键转换：运行态内部以 AdventurerData 对象为键——战斗参数侧
	# 统一 unit_id 字符串键（BattleSetup 按 unit_id 查）；倒地成员不带入
	var hp_map: Dictionary = {}
	for adv: AdventurerData in run.party:
		if run.downed.get(adv, false):
			continue
		if not run.hp.has(adv):
			# E2-11 护栏：缺键告警（按 1 兜底——宿主漏初始化可感知）
			push_warning("EventRunner: run.hp 缺键（%s）——按 1 兜底" % adv.unit_id)
		hp_map[adv.unit_id] = run.hp.get(adv, 1)
	params.hp_overrides = hp_map
	return params

func _RollCheck(actor: AdventurerData, attr_id: StringName,
		tier_name: String) -> CheckResult:
	## 检定掷骰（actor 可空——空名单走大失败档防死锁）
	## 参数 actor：施检者（null = 空名单）；attr_id/tier_name：检定配置
	## 返回：CheckResult
	if actor == null:
		var failed := CheckResult.new()
		failed.grade = CheckResult.Grade.CRIT_FAILURE
		return failed
	return CheckRoller.roll(actor.attrs, attr_id, tier_name, _cfg, _rng)

func _IsFinalized(run: ExpeditionRun, event_id: StringName) -> bool:
	## 终局标记查询（E7 内部口——run 隔离）
	## 参数 run：出征运行态；event_id：事件 id
	## 返回：true = 该 run 内该事件已终局
	return _finalized_events.has(run) and _finalized_events[run].has(event_id)

func _MarkFinalized(run: ExpeditionRun, event_id: StringName) -> void:
	## 终局标记写入（E7 内部口——结算视图产出后调用）
	## 参数 run：出征运行态；event_id：事件 id
	## 返回：无
	if not _finalized_events.has(run):
		_finalized_events[run] = {}
	_finalized_events[run][event_id] = true

func _ResolveOutcome(view: EventView, outcome: EventOutcomeDef, is_crit_success: bool,
		is_crit_failure: bool, modifier: EventModifierDef, run: ExpeditionRun) -> void:
	## 出口结算：C/D 拦截（enabled_flags 缺注入时按未启用处理=拦截——仅置
	## intercepted 标记，文本由 UI 层模板承载）；A → 奖励+授予+解锁；B → 战前
	## 演出视图（宿主路由，奖励战后 post_battle 入账——E2-8）；修饰叠加与损耗
	## 参数 view：目标视图；outcome：出口；is_crit_success/is_crit_failure：档位；
	## modifier：本档修饰；run：运行态
	## 返回：无（view 回写文本/反馈增量）
	if outcome == null:
		return
	# C/D 拦截（DEMO 零数据实例——引擎通路：解锁标记/消耗状态未满足即拦截）
	if outcome.exit_kind == EventOutcomeDef.ExitKind.C or outcome.exit_kind == EventOutcomeDef.ExitKind.D:
		view.intercepted = true
		view.pending_outcome = outcome
		return
	# 基础结算文本（按档取：plain → success/failure → crit 档）；终端节点
	# 叙述已先行入 view——结算文本**追加**不覆写（E2：叙述+结算均可见）
	var text_key: StringName = &"plain"
	if is_crit_success:
		text_key = &"crit_success"
	elif is_crit_failure:
		text_key = &"crit_failure"
	elif not outcome.texts.get(&"plain", "").is_empty() and outcome.reward == null:
		text_key = &"plain"
	var settle_text: String = outcome.texts.get(text_key, outcome.texts.get(
			&"success" if not is_crit_failure else &"failure", ""))
	if not settle_text.is_empty():
		if view.narrative.is_empty():
			view.narrative = settle_text
		else:
			view.narrative += "\n" + settle_text
	# 奖励 + 修饰叠加
	var exp: int = outcome.reward.exp if outcome.reward != null else 0
	var gold: int = outcome.reward.gold if outcome.reward != null else 0
	var reputation: int = outcome.reward.reputation if outcome.reward != null else 0
	if modifier != null and modifier.reward_delta != null:
		exp += modifier.reward_delta.exp
		gold += modifier.reward_delta.gold
		reputation += modifier.reward_delta.reputation
		if not modifier.text.is_empty():
			view.narrative += "\n" + modifier.text
	if modifier != null and modifier.party_hp_delta != 0:
		view.hp_delta = modifier.party_hp_delta
		run.apply_party_damage(modifier.party_hp_delta)
	# B 出口：战前演出视图（宿主路由 build_battle_params → 战斗 → 战后
	# resolve_outcome(post_battle)）；奖励不入账（战后 post_battle 结算——E2-8：
	# 战败/撤退不拿）
	if outcome.exit_kind == EventOutcomeDef.ExitKind.B:
		view.pending_outcome = outcome
		return
	# A：奖励累计（反馈增量回带——UI 数值行）+ 授予（防重）+ 解锁
	run.add_reward(exp, gold, reputation)
	view.reward_gained = {&"exp": exp, &"gold": gold, &"reputation": reputation}
	if not String(outcome.grant_quest_id).is_empty():
		view.granted_quest_id = outcome.grant_quest_id
		view.granted_is_new = run.grant_quest(outcome.grant_quest_id)
	if not String(outcome.unlock_flag).is_empty():
		run.unlock_flags[outcome.unlock_flag] = true

func _FillNodeView(view: EventView, node_id: StringName, run: ExpeditionRun,
		is_crit_success: bool = false, is_crit_failure: bool = false,
		modifier: EventModifierDef = null) -> void:
	## 节点视图填充：叙述 + 选项清单（检定选项带属性·难度(线)标注）/ 终端
	## 节点立即结算（A/C/D 落账、B 挂 pending 宿主路由）；去向节点 id 单源
	## 回带（E6）；终端结算透传四档档位与修饰（E1）
	## 参数 view：目标视图；node_id：节点 id；run：运行态（终端结算落账）；
	## is_crit_success/is_crit_failure：到达档位（CHECK 选项去向透传）；
	## modifier：本档修饰（终端节点结算时叠加）
	## 返回：无
	var node: EventNodeDef = _Lookup(node_id) as EventNodeDef
	if node == null:
		return
	view.narrative = node.narrative_text
	view.node_id = node_id
	if node.outcome != null:
		if node.outcome.exit_kind == EventOutcomeDef.ExitKind.B:
			# B 出口：播叙述+战前结算（初始损耗）后由宿主路由战斗
			_ResolveOutcome(view, node.outcome, is_crit_success, is_crit_failure,
					modifier, run)
		else:
			# A/C/D 终端：到达即结算（叙述+奖励/拦截——档位透传 E1）
			_ResolveOutcome(view, node.outcome, is_crit_success, is_crit_failure,
					modifier, run)
		return
	for option_id: StringName in node.option_ids:
		var option: EventOptionDef = _Lookup(option_id) as EventOptionDef
		if option == null:
			continue
		if option.kind == EventOptionDef.OptionKind.PURE:
			var entry: Dictionary = {
				&"id": option.id,
				&"text": option.display_name,
				&"attr_label": "",
				&"tier_label": "",
				&"tier_line": 0,
				&"cost_days": option.cost_days,
			}
			view.options.append(entry)
		else:
			view.options.append(_CheckOptionView(option.id, option.display_name,
					option.check_attr_id, option.difficulty_tier, option.cost_days))

func _CheckOptionView(option_id: StringName, text: String, attr_id: StringName,
		tier_name: String, cost_days: int) -> Dictionary:
	## 检定选项视图条目（属性/难度标注——tier_line 运行时查表）
	## 参数 option_id/text/attr_id/tier_name/cost_days：选项要素
	## 返回：视图条目字典
	return {
		&"id": option_id,
		&"text": text,
		&"attr_label": String(attr_id),
		&"tier_label": tier_name,
		&"tier_line": CheckRoller.tier_line_of(tier_name, _cfg),
		&"cost_days": cost_days,
	}

func _FirstStrikeOf(token: StringName) -> int:
	## 先手权 token → BattleParams.FirstStrike（&"ally_first"/&"enemy_first"）
	## 参数 token：先手权 token
	## 返回：FirstStrike 枚举值
	if token == &"ally_first":
		return BattleParams.FirstStrike.ALLY_FIRST
	if token == &"enemy_first":
		return BattleParams.FirstStrike.ENEMY_FIRST
	return BattleParams.FirstStrike.NORMAL

func _LayoutSlotsOf(token: StringName) -> Array[int]:
	## 敌方分布 token → 槽位序列（行为语义豁免 match 先例）：
	## clustered = 前 k 相邻槽 [0..k-1]；spread = 间隔 [0,2,4…] 环回；
	## 空 token = 默认分配（空序列）
	## 参数 token：分布 token
	## 返回：槽位序列（空 = 默认）
	## 备注（E2-9 登记）：spread 映射正确——8×8 图 4 出生位下首排覆盖
	## 偏窄属地图出生位配合问题，M3 地图层再调
	if token == &"clustered":
		return [0, 1, 2, 3]
	if token == &"spread":
		return [0, 2, 4, 1, 3, 5, 6, 7]
	return []

func _Lookup(record_id: StringName) -> Resource:
	## 注入 lookup 调用（失败 null）
	## 参数 record_id：资源 id
	## 返回：Resource；未登记 null
	if not _lookup.is_valid():
		return null
	return _lookup.call(record_id) as Resource
