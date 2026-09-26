## 事件演示宿主（event_screen，M3 后退役）
## 职责：M2 事件原型演示——固定 4 人队（初始满血按装配口径派生）→ 6 事件
## 入口（3 链+2 单点+1 暗门）→ 事件面板驱动（改派候选按所点选项属性现算；
## 单点检定同播 D20）→ B 出口战前演出视图（「进入战斗」确认后再路由）→
## 战斗屏（return_to + run/事件/节点锚点回传）→ 战后返回续跑（VICTORY→
## resolve_outcome(post_battle)；败退/撤离→占位文本终结）→ 运行态汇总。
## 出征锁：会话持锁；路由战斗期间锁移交 battle_screen 接管（离树不释放）。
## 数据来源：M2 方案批 3（拍板①新建演示宿主）+ M2 质检 40 项修复。
## 单例访问：统一 get_node("/root/X")（gdUnit 环境惯例）。
extends Control

## SceneManager 脚本常量引用
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")

## UI 文案模板（E3-11/E8：逻辑层零文案——拦截/授予/终局文本集中 UI 层单源）
## W3-09 登记注：path_blocked/quest_granted/quest_grant_dup/all_downed 等条目
## 与 explore_screen.UI_TEXTS 重复（EventPanel 内嵌双宿主各自拼装所致）——
## M4 事件演示宿主退役时随本屏消重，勿在本屏扩新增重复条目
const UI_TEXTS: Dictionary = {
	&"path_blocked": "（此路当前不通。）",
	&"quest_granted": "新委托『%s』已加入挂单列表。",
	&"quest_grant_dup": "这桩委托已经在挂单里了。",
	&"all_downed": "全员倒地——这次探查到此为止。（占位文本——M4 战败流程）",
	&"battle_defeat": "队伍败退/撤离——这次探查到此为止。（占位文本——M4 战败流程）",
}
## 数值反馈行模板（E5：奖励/HP 增量——UI 层拼装，逻辑层只回带数值）
const REWARD_TEXTS: Dictionary = {
	&"exp": "+%d 经验",
	&"gold": "+%d 金",
	&"reputation": "+%d 声望",
	&"hp": "%d HP",
}

## 总控配置
var _cfg: CoreConfig = null
## GameData 单例引用
var _game_data: Node = null
## 事件引擎
var _runner: EventRunner = null
## 出征运行态
var _run: ExpeditionRun = null
## 事件面板
var _panel: EventPanel = null
## 当前活动事件 id（消耗标记/单点结算口径）
var _active_event_id: StringName = &""
## 当前活动节点 id（引擎视图单源回带——B 路由与战后续跑锚点）
var _active_node_id: StringName = &""
## 最近路由战斗的 B 出口节点 id（战后 post_battle 结算锚点——跨场景经
## battle_node_id payload 回带恢复，E2-2）
var _last_battle_node_id: StringName = &""
## B 出口战前演出待战出口（「进入战斗」点击消费——E3-06 先播再战）
var _pending_battle_outcome: EventOutcomeDef = null
## 最近战前演出视图快照（W3-02：路由失败回滚重呈——对齐 explore 口径）
var _last_battle_intro_view: EventRunner.EventView = null
## 路由战斗中标记（E2-4：_exit_tree 持锁判定——路由期间锁由 battle_screen
## 接管持有，本屏离树不释放）
var _routing_battle: bool = false

func _ready() -> void:
	## 引擎回调：装配演示会话；**会话恢复**——pending_params 携带
	## expedition_run（战斗返回）时恢复运行态与锚点并结算 post_battle，
	## 否则新建
	## 参数：无
	## 返回：无
	_game_data = get_node("/root/GameData")
	_cfg = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var table: Dictionary = {}
	for domain: StringName in [&"event/chains", &"event/nodes", &"event/options",
			&"event/singles", &"status/stats"]:
		for record_id: StringName in _game_data.get_domain_ids(domain):
			table[record_id] = _game_data.get_record(record_id)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_runner = EventRunner.new()
	_runner.setup(_cfg, func(record_id: StringName) -> Resource:
		return table.get(record_id, null), rng)
	# 会话分叉：战斗返回（expedition_run 回传）恢复；否则新建
	var scene_manager: Node = get_node("/root/SceneManager")
	var incoming: Dictionary = scene_manager.take_pending_params()
	var resumed_run: ExpeditionRun = incoming.get(&"expedition_run", null) as ExpeditionRun
	var battle_result: BattleResult = incoming.get(&"battle_result", null) as BattleResult
	_run = resumed_run if resumed_run != null else _MakeRun()
	# 战后续跑锚点恢复（E2-2：实例态跨场景归零——payload 原样回带）
	_active_event_id = incoming.get(&"event_id", &"") as StringName
	_active_node_id = incoming.get(&"battle_node_id", &"") as StringName
	_last_battle_node_id = _active_node_id
	_panel = EventPanel.new()
	_panel.setup(_cfg)
	_panel.set_cast_provider(_CastProvider())
	%EventPanelHost.add_child(_panel)
	_panel.option_chosen.connect(_OnOptionChosen)
	_panel.continue_pressed.connect(_OnContinue)
	_panel.battle_pressed.connect(_OnBattleIntroPressed)
	%BackButton.pressed.connect(_OnBack)
	gui_input.connect(_OnGuiInput)
	get_node("/root/SaveManager").set_expedition_lock(true)
	_ApplyFontTiers()
	_BuildMenu()
	# 战后续跑：胜利 → post_battle 结算；败退/撤离 → 占位文本终结（M4 接管）
	if battle_result != null and resumed_run != null:
		_ResumeAfterBattle(battle_result)

func _exit_tree() -> void:
	## 引擎回调：离树恢复出征锁（演示会话结束）；路由战斗期间锁由
	## battle_screen 接管持有——不释放（E2-4 消除路由空窗）
	## 参数：无
	## 返回：无
	if _routing_battle:
		return
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager != null:
		save_manager.set_expedition_lock(false)

func _CastProvider() -> Callable:
	## 改派候选供给闭包（E4：按**所点选项**的属性现算 CheckPicker.candidates
	## ——多属性节点各按其属性取候选；倒地剔除由 candidates 内处理）
	## 参数：无
	## 返回：Callable（attr_id -> Array）
	return func(attr_id: StringName) -> Array:
		return CheckPicker.candidates(_run.party, attr_id, _cfg, _run.downed)

func _MakeRun() -> ExpeditionRun:
	## 固定 4 人演示队（17-C7 中值）+ 初始满血（E2-7：HP 上限按装配口径
	## DerivedStats.calc_hp 派生——勿硬编码数值）
	## 参数：无
	## 返回：ExpeditionRun
	var run := ExpeditionRun.new()
	var roster: Array = [
		[&"warrior", &"cls_warrior"], [&"rogue", &"cls_rogue"],
		[&"mage", &"cls_mage"], [&"priest", &"cls_priest"],
	]
	for entry: Array in roster:
		var attrs: Dictionary = {
			&"strength": 10, &"agility": 10, &"constitution": 10,
			&"intelligence": 10, &"perception": 10, &"willpower": 10, &"luck": 10,
		}
		var adv: AdventurerData = AdventurerData.create_debug(entry[0], entry[1],
				attrs, _game_data)
		run.party.append(adv)
		var cls: ClassDef = _game_data.get_record(entry[1]) as ClassDef
		run.hp[adv] = DerivedStats.calc_hp(
				int(attrs[&"constitution"]), cls, adv.level, _cfg)
	return run

func _ApplyFontTiers() -> void:
	## tscn 内嵌字号档位覆写（E3-12：TitleLabel/StatusLabel——tscn 值留占位，
	## 运行时以 cfg 档位为准，对齐 guild_shell/battle_screen 惯例）；
	## W3-08：BackButton 补齐（按钮统一 normal 档——三屏按钮字号覆写收口）
	## 参数：无
	## 返回：无
	%TitleLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_heading", UiTheme.FONT_HEADING))
	%StatusLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	%BackButton.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))

func _BuildMenu() -> void:
	## 重建 6 事件入口菜单 + 运行态汇总行（已消耗事件置灰）
	## 参数：无
	## 返回：无
	_RefreshStatus()
	for child: Node in %MenuBox.get_children():
		child.queue_free()
	var entries: Array = [
		[&"chain_mine_collapse", "塌方救援（链）"],
		[&"chain_mine_wisp", "矿道鬼火（链·可战斗）"],
		[&"chain_mine_camp", "废弃矿工营地（链）"],
		[&"sp_village_cart", "陷进泥里的板车（单点）"],
		[&"sp_village_traveler", "井边的旅人（单点）"],
		[&"sp_mine_secretdoor", "北壁的风（暗门·感知 17）"],
	]
	for entry: Array in entries:
		var button := Button.new()
		button.text = entry[1]
		button.custom_minimum_size = Vector2(0, 48)
		button.disabled = _run.consumed_events.has(entry[0])
		button.pressed.connect(_OnEventPressed.bind(entry[0]))
		%MenuBox.add_child(button)

func _RefreshStatus() -> void:
	## 运行态汇总行（HP/耗时/累计奖励/挂单/解锁）
	## 参数：无
	## 返回：无
	var hp_parts: PackedStringArray = []
	for adv: AdventurerData in _run.party:
		var tag: String = "倒地" if _run.downed.get(adv, false) else str(int(_run.hp.get(adv, 0)))
		hp_parts.append("%s:%s" % [adv.display_name, tag])
	%StatusLabel.text = "队伍 %s｜耗时 %d 天｜累计 %d经验 %d金 %d声望｜挂单 %d｜解锁 %d" % [
		" ".join(hp_parts), _run.total_days(),
		int(_run.rewards[&"exp"]), int(_run.rewards[&"gold"]), int(_run.rewards[&"reputation"]),
		_run.granted_quests.size(), _run.unlock_flags.size(),
	]

func _OnEventPressed(event_id: StringName) -> void:
	## 事件入口：start_event → 视图分流（B 出口直路由 / 结算视图 / 选项视图）
	## D20 演出期拦截（E3-03 外延——防演出中切事件跨流串扰）
	## 参数 event_id：事件 id
	## 返回：无
	if _panel != null and _panel.is_busy():
		return
	_active_event_id = event_id
	var view: EventRunner.EventView = _runner.start_event(event_id, _run)
	_active_node_id = view.node_id
	_DispatchView(view)

func _DispatchView(view: EventRunner.EventView) -> void:
	## 视图分流：B 出口 → 战前演出视图（E3-06 先播再战）；空选项 → 结算
	## 视图（四档反馈+数值行透传真值 E5）；选项视图 → 面板呈现；空视图
	## （已终局/已消耗）→ 回菜单
	## 参数 view：事件引擎视图
	## 返回：无
	if view.pending_outcome != null \
			and view.pending_outcome.exit_kind == EventOutcomeDef.ExitKind.B:
		_pending_battle_outcome = view.pending_outcome
		_last_battle_intro_view = view
		_panel.show_battle_intro(view, _RewardTextOf(view))
		return
	if view.options.is_empty():
		if view.narrative.is_empty() and not view.intercepted:
			_BuildMenu()
			return
		_ShowSettledFromView(view)
		return
	_panel.show_view(view)

func _OnOptionChosen(option_id: StringName, actor: AdventurerData) -> void:
	## 面板选项选定：D20 演出（检定——单点检定同播，E3-04）→ choose_option
	## → 分流呈现
	## 参数 option_id：选项 id；actor：施检者（纯选择/空名单 null）
	## 返回：无（协程——D20 演出）
	if actor != null:
		await _panel.play_d20_roll()
	var view: EventRunner.EventView = _runner.choose_option(_active_event_id,
			option_id, actor, _run)
	# E6：去向锚点引擎单源回带（掷前预写启发式已删——见 M2 质检 E6/E2-5）
	_active_node_id = view.node_id
	_DispatchView(view)

func _ShowSettledFromView(view: EventRunner.EventView) -> void:
	## 结算视图呈现（E5：四档档位标签+数值反馈行透传真值——文本 UI 层拼装；
	## E8：授予委托固定句式追加行 / 防重补叙；E3-11：拦截文本模板承载）
	## 参数 view：结算视图
	## 返回：无
	var text: String = view.narrative
	if view.intercepted:
		text = UI_TEXTS[&"path_blocked"]
	if view.granted_quest_id != &"":
		var quest: QuestTemplateDef = _game_data.get_record(
				view.granted_quest_id) as QuestTemplateDef
		var quest_name: String = quest.display_name if quest != null \
				else String(view.granted_quest_id)
		text += "\n" + (UI_TEXTS[&"quest_granted"] % quest_name
				if view.granted_is_new else UI_TEXTS[&"quest_grant_dup"])
	_panel.show_settled(view.check_grade, text, _RewardTextOf(view))

func _RewardTextOf(view: EventRunner.EventView) -> String:
	## 数值反馈行拼装（E5：+经验/+金/+声望/HP 增量——零增量不显行）
	## 参数 view：事件视图（reward_gained/hp_delta）
	## 返回：数值反馈行文本（空 = 无增量）
	var parts: PackedStringArray = []
	var exp: int = int(view.reward_gained.get(&"exp", 0))
	var gold: int = int(view.reward_gained.get(&"gold", 0))
	var reputation: int = int(view.reward_gained.get(&"reputation", 0))
	if exp != 0:
		parts.append(REWARD_TEXTS[&"exp"] % exp)
	if gold != 0:
		parts.append(REWARD_TEXTS[&"gold"] % gold)
	if reputation != 0:
		parts.append(REWARD_TEXTS[&"reputation"] % reputation)
	if view.hp_delta != 0:
		parts.append(REWARD_TEXTS[&"hp"] % view.hp_delta)
	return " ".join(parts)

func _OnContinue() -> void:
	## 结算继续：清面板残留（E3-15）回菜单（刷新消耗态与汇总）
	## 参数：无
	## 返回：无
	_panel.clear()
	_BuildMenu()

func _OnBattleIntroPressed() -> void:
	## 战前演出「进入战斗」确认（E3-06 拍板 A：先播再战——点击后才路由）
	## 参数：无
	## 返回：无
	if _pending_battle_outcome == null:
		return
	var outcome: EventOutcomeDef = _pending_battle_outcome
	_pending_battle_outcome = null
	_RouteBattle(outcome)

func _RouteBattle(outcome: EventOutcomeDef) -> void:
	## B 出口路由：组装 BattleParams（倒地过滤，E2-3）→ go(BATTLE_SCREEN,
	## {battle_params, return_to, expedition_run, event_id, battle_node_id})
	## ——战后经 pending_params 回传续跑（锚点原样回带，E3-01②）；
	## W3-02：对齐 explore 口径——消费 go 返回值（失败可感知），失败时复位
	## _routing_battle 并回滚 _pending_battle_outcome 重呈战前演出（可再点）
	## 参数 outcome：B 出口（归属节点经 _active_node_id 锚定）
	## 返回：无
	_last_battle_node_id = _active_node_id
	var alive_party: Array[AdventurerData] = []
	for adv: AdventurerData in _run.party:
		if not _run.downed.get(adv, false):
			alive_party.append(adv)
	if alive_party.is_empty():
		# E2-3：全倒地前置拦截（空名单拒绝装配——占位文本终结会话）
		_panel.show_settled(-1, UI_TEXTS[&"all_downed"], "")
		_BuildMenu()
		return
	var params: BattleParams = _runner.build_battle_params(outcome, _run)
	params.party = alive_party
	_routing_battle = true
	var err: Error = get_node("/root/SceneManager").go(SceneManagerScript.SceneId.BATTLE_SCREEN, {
		&"battle_params": params,
		&"return_to": SceneManagerScript.SceneId.EVENT_SCREEN,
		&"expedition_run": _run,
		&"event_id": _active_event_id,
		&"battle_node_id": _active_node_id,
	})
	if err != OK:
		# W3-02 回滚：路由标记复位 + 恢复待战出口 + 重呈战前演出（可再点
		# 「进入战斗」重试；快照缺失时仅恢复出口位待再点）
		_routing_battle = false
		push_warning("event_screen: 路由战斗失败（错误码 %d）" % err)
		_pending_battle_outcome = outcome
		if _last_battle_intro_view != null:
			_panel.show_battle_intro(_last_battle_intro_view,
					_RewardTextOf(_last_battle_intro_view))
		else:
			push_warning("event_screen: 战前演出视图快照缺失——仅恢复待战出口位")

func _ResumeAfterBattle(result: BattleResult) -> void:
	## 战后续跑：回写 end_stats → 胜利结算 post_battle（15/15 入 run）；
	## 败退/撤离播占位文本终结（M4 战败流程接管）
	## 参数 result：战斗结果
	## 返回：无
	_run.apply_battle_result(result.end_stats)
	var node: EventNodeDef = _game_data.get_record(_last_battle_node_id) as EventNodeDef
	if node != null and node.outcome != null and node.outcome.battle != null:
		if result.kind == BattleResult.ResultKind.VICTORY:
			var view: EventRunner.EventView = _runner.resolve_outcome(
					node.outcome.battle.post_battle, _run)
			_ShowSettledFromView(view)
		else:
			_panel.show_settled(-1, UI_TEXTS[&"battle_defeat"], "")
	_BuildMenu()

func _OnBack() -> void:
	## 返回公会（演示会话结束——_exit_tree 恢复出征锁）
	## 参数：无
	## 返回：无
	get_node("/root/SceneManager").go(SceneManagerScript.SceneId.GUILD_SHELL)

func _OnGuiInput(event: InputEvent) -> void:
	## 点按跳过 D20 演出
	## 参数 event：输入事件
	## 返回：无
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_panel.skip_d20()
