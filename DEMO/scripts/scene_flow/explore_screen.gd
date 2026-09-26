## 探索场景根（explore_screen，Control）
## 职责：探索层宿主——装配探索会话（图态/迷雾/判据/事件引擎/板面）、
## 移动交互状态机（点格寻路→逐格步进演出→每格固定结算序 a 迷雾刷新/
## b 暗门 NEAR 中断/c 随机遭遇掷中断/d ENTER 交互点中断；点格直走无路径
## 预览——2026-09-25 拍板豁免）、TAP 点按交互（宝箱开箱入账/出口交付/
## 目标点判据）、事件引擎正式接线（ENTER 事件点 → EventPanel 内嵌驱动 →
## B 出口战前演出）、遭遇战路由（必然/随机 → BATTLE_SCREEN，return_to=本屏）、
## 战后续跑分叉（battle_node_id = B 出口战 post_battle 续跑（B 出口战=剧情战
## 不计入判据——2026-09-25 拍板）/ encounter_pack_id = 遭遇战原位继续 +
## CLEAR 判据）、判据达成→出口激活横幅、终结双通道（出口交付 = 成功（无委托
## 自由探索同走成功通道）/ 撤退·战败·全倒地 = 失败——占位结算面板回城，
## M4 接管）。
## 显示层级（2026-09-25 用户拍板）：UI 弹层（事件面板/结算面板，z=
## UI_POPUP_Z_INDEX）> 战争迷雾（board Z_FOG）> 已显示内容（board Z_TILE/
## Z_CONTENT）；例外：委托目标点常显（+衬底）与视野内小队图标浮于迷雾上
## （board Z_OVERLAY/Z_PARTY——恒低于 UI 弹层）。
## 弹层显隐契约（同日试玩反馈①）：PanelHost 初始隐藏，事件视图呈现时
## 显示、结算继续/路由战斗/会话终结时隐藏——弹窗会话结束即消失。
## 数据来源：M3 方案批 2/批 3；案 7《地图与探索》；案 8（事件引擎）；案 18。
## 单例访问：统一 get_node("/root/X")（gdUnit 测试环境惯例）。
## 出征锁：会话持锁；路由战斗期间锁移交 battle_screen 接管（离树不释放）。
extends Control

## SceneManager 脚本常量引用
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")

## UI 弹层 z 单源（2026-09-25 层级拍板：事件面板/结算面板等 UI 弹层压过
## board 全部绘制层——z_index 在 CanvasLayer 内跨子树全局生效，弹层留默认 0
## 会被迷雾(Z_FOG)/图标(Z_OVERLAY+)穿透；须恒大于 ExploreBoard.Z_PARTY）
const UI_POPUP_Z_INDEX: int = 100
## 事件面板弹窗宽度上限（设计 px——限宽居中，文字不裸浮全屏）
## （占位 UI 结构参数，2026-09-26 审计 V-6 拍板豁免登记，归口案 16 §2.7——
## 文档登记由 docs-updater 后续补；不入 CoreConfig）
const EVENT_PANEL_WIDTH: int = 720
## 提示行描边宽（占位视觉结构参数——X3-06 豁免先例同口径）
const HINT_OUTLINE_SIZE: int = 4

## UI 文案模板（逻辑层零文案——UI 层单源；tscn 占位文本运行时覆写 X3-08）
## W3-09 登记注：path_blocked/quest_granted/quest_grant_dup 等条目与
## event_screen.UI_TEXTS 重复（EventPanel 内嵌双宿主各自拼装所致）——
## M4 事件演示宿主退役时消重，勿在本屏扩新增重复条目
const UI_TEXTS: Dictionary = {
	&"no_quest": "自由探索（无委托）",
	&"free_status": "自由探索——出口随时可离开",
	&"goal_pending": "判据未达成",
	&"goal_done": "判据已达成——出口已激活",
	&"goal_banner": "委托目标已达成——从村口出口回去交付。",
	&"retreat_button": "撤退回城",
	&"settle_return": "回城",
	&"exit_not_ready": "委托还没完成——出口守卫拦住了你们。",
	&"target_other": "这是其他委托的目标点。",
	&"target_done": "目标已达成——回村口出口交付。",
	&"move_blocked": "那边过不去。",
	&"path_blocked": "（此路当前不通。）",
	&"quest_granted": "新委托『%s』已加入挂单列表。",
	&"quest_grant_dup": "这桩委托已经在挂单里了。",
	&"treasure_opened": "撬开矿箱——+%d 金。",
	&"treasure_empty": "空箱子——之前有人来过了。",
	&"encounter_won": "遭遇战胜利——原地整备，继续前进。",
	&"all_downed": "全员倒地——这次出征到此为止。（占位文本——M4 战败流程）",
	&"battle_defeat": "队伍败退/撤离——委托失败。（占位文本——M4 战败流程）",
	&"retreat_failed": "撤退——委托失败，出征进度不保留。（占位文本——M4 结算接管）",
	&"settle_success": "委托达成（占位结算——M4 接管）",
	&"settle_free_explore": "自由探索结束（占位结算——M4 接管）",
	&"settle_failed": "委托失败（占位结算——M4 接管）",
	&"settle_body": "%s｜收获申报：%d 经验 %d 金 %d 声望｜耗时 %d 天",
	&"route_failed": "进入战斗失败——请重试。",
	&"map_missing": "探索图数据缺失——无法开始探索。（占位提示——M4 出征层接管）",
	&"check_roll_detail": "掷出 %d ＋ %d ＝ %d（%s %d）",
}

## GameData 单例引用
var _game_data: Node = null
## 总控配置
var _cfg: CoreConfig = null
## 出征运行态（跨场景回传恢复或新建）
var _run: ExpeditionRun = null
## 探索图定义
var _map_def: ExploreMapDef = null
## 图运行态（通行/寻路/揭示）
var _state: ExploreMapState = null
## 判据追踪器
var _goal := GoalTracker.new()
## 随机源（遭遇掷/宝箱掷/检定掷——测试可注 seed）
var _rng := RandomNumberGenerator.new()
## 事件引擎（链/单点驱动）
var _runner: EventRunner = null
## 事件面板（可复用弹层——零修改内嵌）
var _panel: EventPanel = null
## 区域 -> 遭遇权重索引
var _encw_by_region: Dictionary = {}
## 图板组件
var _board: ExploreBoard = null
## 移动演出中标记（中断/点按门禁）
var _moving: bool = false
## 步进演出时长覆盖（< 0 = 走 cfg；测试注 0 加速）
var step_seconds_override: float = -1.0
## 当前活动事件 id（消耗标记/单点结算口径）
var _active_event_id: StringName = &""
## 当前活动节点 id（引擎视图单源回带——B 路由与战后续跑锚点）
var _active_node_id: StringName = &""
## B 出口战前演出待战出口（「进入战斗」点击消费——先播再战）
var _pending_battle_outcome: EventOutcomeDef = null
## 最近战前演出视图快照（路由失败回滚重呈——X3-09）
var _last_battle_intro_view: EventRunner.EventView = null
## 路由战斗中标记（_exit_tree 持锁判定——锁由 battle_screen 接管）
var _routing_battle: bool = false
## 事件面板占用标记（视图呈现期禁移动/点按）
var _event_open: bool = false
## 会话终结标记（占位结算面板呈现期禁全部输入）
var _finished: bool = false
## 战后续跑待处理标记（call_deferred 一帧窗内禁交互——L9）
var _resuming: bool = false

func _ready() -> void:
	## 引擎回调：装配探索会话（pending_params 携带 expedition_run 时恢复，
	## 否则默认演示队新建）；战后续跑分叉（battle_result 携带时——
	## battle_node_id = B 出口战 post_battle 续跑 / encounter_pack_id =
	## 遭遇战原位继续）；建图态/判据（含达成态回灌 H1）/事件面板/板面并刷新；
	## 暗门揭示态经 unlock_flags 重放（H2——揭示不随屏实例丢失）
	## 参数：无
	## 返回：无
	_game_data = get_node("/root/GameData")
	_cfg = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var scene_manager: Node = get_node("/root/SceneManager")
	var incoming: Dictionary = scene_manager.take_pending_params()
	_run = incoming.get(&"expedition_run", null) as ExpeditionRun
	if _run == null:
		_run = _MakeDefaultRun()
	_map_def = _game_data.get_record(_run.map_id) as ExploreMapDef
	_rng.randomize()
	_runner = EventRunner.new()
	_runner.setup(_cfg, _EventLookup(), _rng)
	# 判据装配 + 达成态回灌（H1：run.goal_done 持久快照恢复——跨战斗不丢）
	_goal.setup(_run.goal_kind, _run.goal_param)
	_goal.restore_done(_run.goal_done)
	for record: Resource in _game_data.get_domain(&"map/encounter_weights"):
		var weight := record as EncounterWeightDef
		_encw_by_region[weight.region_id] = weight
	_panel = EventPanel.new()
	_panel.setup(_cfg)
	_panel.set_cast_provider(_CastProvider())
	_panel.custom_minimum_size = Vector2(EVENT_PANEL_WIDTH, 0)
	%PanelHost.add_child(_panel)
	_panel.option_chosen.connect(_OnOptionChosen)
	_panel.continue_pressed.connect(_OnContinue)
	_panel.battle_pressed.connect(_OnBattleIntroPressed)
	%RetreatButton.text = UI_TEXTS[&"retreat_button"]
	# UI 弹层 z 单源落位（tscn 同值双保险——层级契约测试消费）
	%PanelHost.z_index = UI_POPUP_Z_INDEX
	%SettlementPanel.z_index = UI_POPUP_Z_INDEX
	%SettlementButton.text = UI_TEXTS[&"settle_return"]
	%GoalBanner.text = UI_TEXTS[&"goal_banner"]
	%RetreatButton.pressed.connect(_OnRetreatPressed)
	%RetreatConfirm.confirmed.connect(_OnRetreatConfirmConfirmed)
	%SettlementButton.pressed.connect(_OnSettleReturnPressed)
	gui_input.connect(_OnGuiInput)
	get_node("/root/SaveManager").set_expedition_lock(true)
	_ApplyFontTiers()
	# 图数据缺失降级（L8）：提示 + 回城出口——不废屏
	if _map_def == null:
		_FinishSession(true, UI_TEXTS[&"map_missing"])
		return
	_state = ExploreMapState.new()
	_state.setup(_map_def, _TileLookup())
	# 迷雾墙体遮挡挂接（2026-09-26 拍板：视野被墙遮挡）：迷雾在 run 侧建立时
	# 地图态未装配，此处挂接实时墙体查询（回调按次现查 tile_at——暗门 reveal
	# 后格变 etile_path，遮挡随之解除；不清探索记忆）
	if _run.fog != null:
		_run.fog.set_opaque_probe(_OpaqueProbe())
		# V-2（2026-09-26 审计）：初始视野揭示在此统一执行（挂接遮挡探针之后
		# ——开局视野含墙体遮挡，run 侧 start_explore 只建迷雾不首揭）；
		# 战后续跑（记忆集非空）不重复揭示
		if _run.fog.explored_count() == 0:
			_run.fog.on_moved(_run.party_pos)
	_board = ExploreBoard.new()
	_board.setup(_cfg, _map_def, _state, _game_data)
	%BoardHost.add_child(_board)
	_board.cell_pressed.connect(_OnCellPressed)
	# 板面适配（X3-02）：随宿主可用空间等比缩放（横幅出现/窗口变化重适配）
	%BoardHost.resized.connect(_FitBoard)
	_FitBoardInitial()
	# 暗门揭示重放（H2：unlock_flags 为揭示单源——会话恢复即重放 reveal_secret）
	_ApplySecretRevealIfNeeded()
	_RefreshBoard()
	_RefreshStatus()
	# 战后续跑分叉（payload 键区分）：B 出口战 vs 遭遇战
	var battle_result: BattleResult = incoming.get(&"battle_result", null) as BattleResult
	if battle_result != null:
		_resuming = true
		var battle_node_id: StringName = incoming.get(&"battle_node_id", &"") as StringName
		var encounter_pack_id: StringName = incoming.get(&"encounter_pack_id", &"") as StringName
		_ResumeAfterBattle.call_deferred(battle_result, battle_node_id, encounter_pack_id)

func _exit_tree() -> void:
	## 引擎回调：离树恢复出征锁（会话结束；路由战斗期间锁由 battle_screen
	## 接管持有——不释放）
	## 参数：无
	## 返回：无
	if _routing_battle:
		return
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager != null:
		save_manager.set_expedition_lock(false)

func _TileLookup() -> Callable:
	## 探索地格解析闭包（etile_ id -> ExploreTileDef）
	## 参数：无
	## 返回：Callable
	return func(tile_id: StringName) -> ExploreTileDef:
		return _game_data.get_record(tile_id) as ExploreTileDef

func _OpaqueProbe() -> Callable:
	## 迷雾遮蔽探针（实时墙体查询——非可通行格即遮挡视线：总图非可通行格
	## = 岩壁 etile_wall；经 _state.tile_at 现查，暗门 reveal 覆写后自然解除）
	## 参数：无
	## 返回：Callable（Vector2i -> bool）
	return func(cell: Vector2i) -> bool:
		return not _state.walkable(cell)

func _EventLookup() -> Callable:
	## 事件域解析闭包（chains/nodes/options/singles/status 五域合一）
	## 参数：无
	## 返回：Callable
	var table: Dictionary = {}
	for domain: StringName in [&"event/chains", &"event/nodes", &"event/options",
			&"event/singles", &"status/stats"]:
		for record_id: StringName in _game_data.get_domain_ids(domain):
			table[record_id] = _game_data.get_record(record_id)
	return func(record_id: StringName) -> Resource:
		return table.get(record_id, null)

func _CastProvider() -> Callable:
	## 改派候选供给闭包（按所点选项属性现算；倒地剔除经 candidates）
	## 参数：无
	## 返回：Callable（attr_id -> Array）
	return func(attr_id: StringName) -> Array:
		return CheckPicker.candidates(_run.party, attr_id, _cfg, _run.downed)

func _MakeDefaultRun() -> ExpeditionRun:
	## 默认演示会话（无跨场景参数直开时）：固定 4 人队 + 首图自由探索；
	## 图域空时返回未装配 run（_ready 走图缺失降级——L8）
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
	var maps: Array = _game_data.get_domain(&"map/maps")
	if maps.is_empty():
		return run
	var map_def: ExploreMapDef = maps[0] as ExploreMapDef
	run.start_explore(map_def, null, _cfg.vision_radius)
	return run

func _ApplyFontTiers() -> void:
	## tscn 内嵌字号档位覆写（对齐 guild_shell/event_screen 惯例；X3-07：
	## HintLabel 补齐）+ 判据横幅配色（cfg 表驱动）
	## 参数：无
	## 返回：无
	%TitleLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_heading", UiTheme.FONT_HEADING))
	%StatusLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	%HintLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	# 提示行深色描边（叠加板面边缘时的对比保障——2026-09-25 层级修复顺手项）
	%HintLabel.add_theme_color_override("font_outline_color", UiTheme.BADGE_OUTLINE)
	%HintLabel.add_theme_constant_override("outline_size", HINT_OUTLINE_SIZE)
	%GoalBanner.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	%GoalBanner.add_theme_color_override("font_color",
			UiTheme.color_of(_cfg, &"ui_explore_goal_banner_color",
					UiTheme.EXPLORE_GOAL_BANNER))
	%SettlementTitle.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_heading", UiTheme.FONT_HEADING))
	%SettlementBody.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	# W3-08：按钮字号补齐（撤退/回城——三屏按钮统一 normal 档收口）
	%RetreatButton.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	%SettlementButton.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))

# --------------------------------------------------------------------------
# 板面刷新与适配
# --------------------------------------------------------------------------

func _FitBoard() -> void:
	## 板面适配入口：按 BoardHost 当前可用空间缩放并手动居中（X3-02 + W3-01：
	## 宿主已改普通全伸展 Control——min 不随板面 design 膨胀，缩放机制真实
	## 介入，居中经 center_in_host 落位）
	## 参数：无
	## 返回：无
	if _board == null:
		return
	_board.fit_to(%BoardHost.size)
	_board.center_in_host(%BoardHost.size)

func _FitBoardInitial() -> void:
	## 首帧适配（布局落定后取实际可用空间；后续经 resized 信号重适配）
	## 参数：无
	## 返回：无（协程——fire-and-forget）
	await get_tree().process_frame
	_FitBoard()

func _RefreshBoard() -> void:
	## 板面全量刷新（迷雾/图标/小队/出口态）
	## 参数：无
	## 返回：无
	if _board == null:
		return
	_board.refresh(_run.party_pos, _run.fog, _run.consumed_events,
			_run.unlock_flags, _ActiveTargetId(), _ExitActive())

func _ActiveTargetId() -> StringName:
	## 本委托绑定目标点 id（EXPLORE 判据参数；非 EXPLORE/无判据为空）
	## 参数：无
	## 返回：目标点 id
	if _run.goal_kind == QuestTemplateDef.GoalType.EXPLORE:
		return _run.goal_param
	return &""

func _ExitActive() -> bool:
	## 出口激活判定：判据达成，或自由探索会话（无判据——直接可交付，
	## 2026-09-25 拍板）
	## 参数：无
	## 返回：true = 出口可交付
	return _goal.is_done() or _run.goal_kind == -1

func _RefreshStatus() -> void:
	## 顶部状态行（委托/判据/耗时/队伍 HP）
	## 参数：无
	## 返回：无
	var quest_name: String = UI_TEXTS[&"no_quest"]
	if _run.quest_template_id != &"":
		var quest: QuestTemplateDef = _game_data.get_record(
				_run.quest_template_id) as QuestTemplateDef
		if quest != null:
			quest_name = quest.display_name
		else:
			# L6（X3-10 同口径）：查无提示反馈——不静默
			quest_name = String(_run.quest_template_id)
			push_warning("explore_screen: 委托模板 '%s' 查无" % _run.quest_template_id)
	var hp_parts: PackedStringArray = []
	for adv: AdventurerData in _run.party:
		var tag: String = "倒地" if _run.downed.get(adv, false) else str(int(_run.hp.get(adv, 0)))
		hp_parts.append("%s:%s" % [adv.display_name, tag])
	# 状态行分组（2026-09-25 层级修复顺手项）：组间全角｜分隔、HP 组加前缀标签；
	# W3-06：自由探索会话（goal_kind == -1）状态段显专属文案（不再借用
	# 「判据已达成」——无判据会话谈达成语义错位）
	var status_segment: String = UI_TEXTS[&"free_status"] if _run.goal_kind == -1 \
			else (UI_TEXTS[&"goal_done"] if _ExitActive() else UI_TEXTS[&"goal_pending"])
	%StatusLabel.text = "委托『%s』｜%s｜耗时 %d 天｜HP：%s" % [quest_name,
			status_segment, _run.total_days(), " ".join(hp_parts)]
	%GoalBanner.visible = _goal.is_done()

# --------------------------------------------------------------------------
# 点按交互（移动 / TAP 点位）
# --------------------------------------------------------------------------

func _OnCellPressed(cell: Vector2i) -> void:
	## 板面点按入口：TAP 点位（邻接时优先交互）→ 否则可通行格寻路移动；
	## 移动演出/事件面板/会话终结/续跑待处理期忽略点按；W2-11：撤退确认
	## 弹窗期忽略（模态弹窗挂起时板面点格抢跑移动）
	## 参数 cell：命中格
	## 返回：无
	if _moving or _event_open or _finished or _resuming:
		return
	if %RetreatConfirm.visible:
		return
	var tap_point: InteractPointDef = _PointAt(cell, InteractPointDef.Trigger.TAP)
	if tap_point != null and _IsAdjacent(cell):
		_OnTapPoint(tap_point)
		return
	var target: TargetPointDef = _TargetAt(cell)
	if target != null and _IsAdjacent(cell):
		_OnTapTarget(target)
		return
	if _state.walkable(cell):
		_MoveTo(cell)
	else:
		_SetHint(UI_TEXTS[&"move_blocked"])

func _IsAdjacent(cell: Vector2i) -> bool:
	## 点按交互邻接判定（小队与点按格同格或八邻——格心欧氏 ≤ 1.5）
	## 参数 cell：点按格
	## 返回：true = 可交互邻接
	var delta: Vector2i = cell - _run.party_pos
	return float(delta.x) * float(delta.x) + float(delta.y) * float(delta.y) <= 2.25

func _PointAt(cell: Vector2i, trigger: int) -> InteractPointDef:
	## 按格与触发方式查交互点
	## 参数 cell：查询格；trigger：触发方式枚举值
	## 返回：交互点；无则 null
	for record: Resource in _game_data.get_domain(&"map/interact_points"):
		var point := record as InteractPointDef
		if point.cell == cell and point.trigger == trigger:
			return point
	return null

func _TargetAt(cell: Vector2i) -> TargetPointDef:
	## 按格查目标点
	## 参数 cell：查询格
	## 返回：目标点；无则 null
	for record: Resource in _game_data.get_domain(&"map/target_points"):
		var target := record as TargetPointDef
		if target.cell == cell:
			return target
	return null

func _OnTapPoint(point: InteractPointDef) -> void:
	## TAP 交互点点按（宝箱开箱入账 / 出口交付——按 kind 分派）
	## 参数 point：交互点
	## 返回：无
	match point.kind:
		InteractPointDef.Kind.TREASURE:
			if _IsPointConsumed(point):
				_SetHint(UI_TEXTS[&"treasure_empty"])
				return
			var gold: int = EncounterJudge.roll_treasure_gold(point, _rng)
			_run.add_reward(0, gold, 0)
			_run.consumed_events[point.id] = true
			_SetHint(UI_TEXTS[&"treasure_opened"] % gold)
			_RefreshBoard()
			_RefreshStatus()
		InteractPointDef.Kind.EXIT:
			if _ExitActive():
				_FinishSession(false)
			else:
				_SetHint(UI_TEXTS[&"exit_not_ready"])
		_:
			pass

func _OnTapTarget(target: TargetPointDef) -> void:
	## 目标点点按：绑定目标（判据交互）→ GoalTracker + 出口激活；已达成 →
	## 独立提示（不再落入「其他委托」文案——X3-03）；非绑定 → 提示
	## 参数 target：目标点
	## 返回：无
	if target.id == _ActiveTargetId():
		if _goal.is_done():
			_SetHint(UI_TEXTS[&"target_done"])
			return
		var done: bool = _goal.on_target_interacted(target.id)
		_run.goal_done = done or _run.goal_done
		if done:
			_RefreshStatus()
			_RefreshBoard()
			return
	_SetHint(UI_TEXTS[&"target_other"])

func _IsPointConsumed(point: InteractPointDef) -> bool:
	## 交互点消耗判定：链/单点/暗门 = ref 事件已消耗；宝箱/必然遭遇 = 点位
	## id 已消耗（触发即消耗——战败会话终结无重入）
	## 参数 point：交互点
	## 返回：true = 已消耗（不再触发）
	match point.kind:
		InteractPointDef.Kind.TREASURE, InteractPointDef.Kind.BATTLE:
			return _run.consumed_events.has(point.id)
		_:
			return _run.consumed_events.has(point.ref_id)

# --------------------------------------------------------------------------
# 移动状态机（逐格步进 + 固定结算序 a/b/c/d）
# --------------------------------------------------------------------------

func _MoveTo(target: Vector2i) -> void:
	## 寻路移动：BFS 最短路 → 逐格步进演出（点格直走无路径预览——
	## 2026-09-25 拍板豁免：探索层以流畅走格为先，预览交互留 M4 出征层评估）；
	## 每踏入一格按固定序结算——a 迷雾揭示+板刷新 → b 暗门 NEAR（未消耗
	## 未揭示 → 中断触发检定）→ c 随机遭遇掷（触发 → 中断路由战斗）→
	## d ENTER 交互点（未消耗 → 中断触发事件/遭遇）；中断后剩余路径作废
	## 参数 target：目标格（可含浓雾格——探索动力）
	## 返回：无（协程——步进演出）
	_SetHint("")
	var path: Array[Vector2i] = _state.find_path(_run.party_pos, target)
	if path.is_empty():
		_SetHint(UI_TEXTS[&"move_blocked"])
		return
	_moving = true
	for index: int in range(1, path.size()):
		var cell: Vector2i = path[index]
		var is_new_cell: bool = not _run.visited_cells.has(cell)
		_run.visited_cells[cell] = true
		_run.party_pos = cell
		# a. 迷雾揭示 + 板刷新（移动演出先行——图标落格后再等步进时长）
		_run.fog.on_moved(cell)
		_RefreshBoard()
		await _StepWait()
		# b. 暗门 NEAR（未消耗未揭示 + 格心欧氏 ≤ 触发半径 → 中断触发检定事件）
		var door_point: InteractPointDef = _SecretDoorPointAt(cell)
		if door_point != null:
			_moving = false
			_StartEvent(door_point.ref_id)
			return
		# c. 随机遭遇掷（新格才掷；触发 → 中断路由战斗——权重一次查表收口 L7）
		var weight: EncounterWeightDef = _EncounterWeightAt(cell)
		if weight != null and EncounterJudge.should_trigger(is_new_cell, weight,
				_run.random_encounters_fired, _rng):
			_moving = false
			_RunRandomEncounter(weight)
			return
		# d. ENTER 交互点（同格自动触发；已消耗不触发）
		var enter_point: InteractPointDef = _PointAt(cell, InteractPointDef.Trigger.ENTER)
		if enter_point != null and not _IsPointConsumed(enter_point):
			_moving = false
			_OnEnterPoint(enter_point)
			return
	_moving = false
	_RefreshStatus()

func _StepWait() -> void:
	## 单步演出等待（覆盖值 ≥ 0 直接生效——测试注 0 加速；负数走 cfg 表值，
	## 表值未回退回 UiTheme 兜底）
	## 参数：无
	## 返回：无（协程）
	var seconds: float = step_seconds_override
	if seconds < 0.0:
		seconds = _cfg.ui_explore_move_step_seconds if _cfg != null \
				and _cfg.ui_explore_move_step_seconds > 0.0 \
				else UiTheme.EXPLORE_MOVE_STEP_SECONDS
	await get_tree().create_timer(seconds).timeout

func _SecretDoorPointAt(cell: Vector2i) -> InteractPointDef:
	## 距离内可触发的暗门交互点查询（未消耗未揭示 + 半径内——遍历取首个）
	## 参数 cell：小队当前格
	## 返回：交互点；无则 null
	var radius: int = _cfg.secret_door_trigger_radius if _cfg != null else 0
	for record: Resource in _game_data.get_domain(&"map/interact_points"):
		var point := record as InteractPointDef
		if point.kind != InteractPointDef.Kind.SECRET_DOOR:
			continue
		if _run.consumed_events.has(point.ref_id):
			continue
		var single: SingleEventDef = _game_data.get_record(point.ref_id) as SingleEventDef
		if single == null or single.success_outcome == null:
			continue
		if _run.unlock_flags.has(single.success_outcome.unlock_flag):
			continue
		var delta: Vector2i = cell - point.cell
		if float(delta.x) * float(delta.x) + float(delta.y) * float(delta.y) \
				<= float(radius) * float(radius):
			return point
	return null

func _EncounterWeightAt(cell: Vector2i) -> EncounterWeightDef:
	## 区域遭遇权重查询（region_ids 惯例序一次查表——L7 收口；
	## 村子安全区 chance 0 经 EncounterJudge 拒掷）
	## 参数 cell：小队当前格
	## 返回：区域权重；区域未登记返 null
	if _map_def == null or _map_def.region_ids.is_empty():
		return null
	var region_id: StringName = _map_def.region_ids[_state.region_index_of(cell)]
	return _encw_by_region.get(region_id, null) as EncounterWeightDef

func _OnEnterPoint(point: InteractPointDef) -> void:
	## ENTER 交互点触发：链/单点 → 事件引擎；必然遭遇 → 遭遇战路由
	## （路由成功才落消耗账——X3-09 回滚保障）
	## 参数 point：交互点
	## 返回：无
	match point.kind:
		InteractPointDef.Kind.CHAIN, InteractPointDef.Kind.SINGLE:
			_StartEvent(point.ref_id)
		InteractPointDef.Kind.BATTLE:
			_RouteEncounter(point.ref_id, point.id)
		_:
			pass

func _RunRandomEncounter(weight: EncounterWeightDef) -> void:
	## 随机遭遇触发：路由成功后计数自增（战败不回退——账随 run 实例存续）
	## 参数 weight：命中区域的遭遇权重
	## 返回：无
	if weight == null:
		return
	if _RouteEncounter(weight.random_pack_id, &""):
		_run.random_encounters_fired += 1

# --------------------------------------------------------------------------
# 事件引擎接线（EventPanel 内嵌驱动）
# --------------------------------------------------------------------------

func _StartEvent(event_id: StringName) -> void:
	## 事件入口：start_event → 视图分流（已消耗返回空视图——板面静默恢复）
	## 参数 event_id：链/单点事件 id
	## 返回：无
	if _panel.is_busy() or _event_open:
		return
	_active_event_id = event_id
	var view: EventRunner.EventView = _runner.start_event(event_id, _run)
	_active_node_id = view.node_id
	_DispatchView(view)

func _DispatchView(view: EventRunner.EventView) -> void:
	## 视图分流：B 出口 → 战前演出视图（先播再战）；空选项 → 结算视图；
	## 选项视图 → 面板呈现；空视图（已终局/已消耗）→ 板面恢复
	## 参数 view：事件引擎视图
	## 返回：无
	if view.pending_outcome != null \
			and view.pending_outcome.exit_kind == EventOutcomeDef.ExitKind.B:
		_pending_battle_outcome = view.pending_outcome
		_last_battle_intro_view = view
		_event_open = true
		_ShowEventPanel()
		_panel.show_battle_intro(view, _RewardTextOf(view), _RollDetailOf(view))
		return
	if view.options.is_empty():
		if view.narrative.is_empty() and not view.intercepted:
			# V-3（2026-09-26 审计）：空视图统一清场——此前不动面板，选项派生链
			# 返回空视图时旧面板残留上一视图且 _event_open 悬置（输入被面板
			# 占用闸门拦截——软锁）；对 _StartEvent 入口零影响（面板本关）
			_panel.clear()
			_HideEventPanel()
			_event_open = false
			_RefreshBoard()
			_RefreshStatus()
			return
		_ShowSettledFromView(view)
		return
	_event_open = true
	_ShowEventPanel()
	_panel.show_view(view)

func _OnOptionChosen(option_id: StringName, actor: AdventurerData) -> void:
	## 面板选项选定：D20 演出（检定）→ choose_option → 分流呈现
	## 参数 option_id：选项 id；actor：施检者（纯选择 null）
	## 返回：无（协程——D20 演出）
	if actor != null:
		await _panel.play_d20_roll()
	var view: EventRunner.EventView = _runner.choose_option(_active_event_id,
			option_id, actor, _run)
	_active_node_id = view.node_id
	_DispatchView(view)

func _ShowSettledFromView(view: EventRunner.EventView) -> void:
	## 结算视图呈现：四档反馈条 + 结算文本 + 数值反馈行；授予委托固定句式；
	## 拦截文本模板承载
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
	_event_open = true
	_ShowEventPanel()
	_panel.show_settled(view.check_grade, text, _RewardTextOf(view), _RollDetailOf(view))

func _RollDetailOf(view: EventRunner.EventView) -> String:
	## 掷骰明细行拼装（2026-09-25 试玩反馈②：「掷出 N ＋ M ＝ T（难度档 线）」
	## ——检定视图消费骰面/调整值/难度，M2 单源档名与判定线直出；无检定空串）
	## 参数 view：事件视图
	## 返回：明细行文本（无检定 = 空串）
	if view.check_grade < 0:
		return ""
	return UI_TEXTS[&"check_roll_detail"] % [view.check_die, view.check_modifier,
			view.check_total, view.check_tier_label, view.check_tier_line]

func _RewardTextOf(view: EventRunner.EventView) -> String:
	## 数值反馈行拼装（+经验/+金/+声望/HP 增量——零增量不显行）
	## 参数 view：事件视图
	## 返回：数值反馈行文本
	var parts: PackedStringArray = []
	var exp: int = int(view.reward_gained.get(&"exp", 0))
	var gold: int = int(view.reward_gained.get(&"gold", 0))
	var reputation: int = int(view.reward_gained.get(&"reputation", 0))
	if exp != 0:
		parts.append("+%d 经验" % exp)
	if gold != 0:
		parts.append("+%d 金" % gold)
	if reputation != 0:
		parts.append("+%d 声望" % reputation)
	if view.hp_delta != 0:
		parts.append("%d HP" % view.hp_delta)
	return " ".join(parts)

func _OnContinue() -> void:
	## 结算继续：清面板并隐藏（事件占用解除——2026-09-25 试玩反馈①：弹层
	## 会话结束即消失，板面输入恢复）→ 暗门揭示应用 → 板面/状态刷新
	## 参数：无
	## 返回：无
	_panel.clear()
	_HideEventPanel()
	_event_open = false
	_ApplySecretRevealIfNeeded()
	_RefreshBoard()
	_RefreshStatus()

func _ShowEventPanel() -> void:
	## 事件弹层显示（呈现点统一入口——2026-09-25 试玩反馈①：tscn 初始隐藏，
	## 呈现视图时显式恢复）
	## 参数：无
	## 返回：无
	%PanelHost.visible = true

func _HideEventPanel() -> void:
	## 事件弹层隐藏（清空点统一入口——结算继续/路由战斗离屏/会话终结；
	## 战后续跑重呈经 _ShowEventPanel 恢复）
	## 参数：无
	## 返回：无
	%PanelHost.visible = false

func _ApplySecretRevealIfNeeded() -> void:
	## 暗门揭示应用（H2：unlock_flag 已入 run 即重放——_ready 会话恢复与
	## 事件继续双入口共用；幂等——重复应用同值覆写）
	## 参数：无
	## 返回：无
	if _state == null:
		return
	var applied: bool = false
	for record: Resource in _game_data.get_domain(&"map/interact_points"):
		var point := record as InteractPointDef
		if point.kind != InteractPointDef.Kind.SECRET_DOOR:
			continue
		var single: SingleEventDef = _game_data.get_record(point.ref_id) as SingleEventDef
		if single == null or single.success_outcome == null:
			continue
		if not _run.unlock_flags.has(single.success_outcome.unlock_flag):
			continue
		_state.reveal_secret(point.reveal_cells, point.reveal_tile_id)
		applied = true
	if applied and _board != null:
		_board.refresh_tiles()

# --------------------------------------------------------------------------
# 遭遇战路由与战后续跑
# --------------------------------------------------------------------------

func _OnBattleIntroPressed() -> void:
	## 战前演出「进入战斗」确认（先播再战——点击后才路由 B 出口战）
	## 参数：无
	## 返回：无
	if _pending_battle_outcome == null:
		return
	var outcome: EventOutcomeDef = _pending_battle_outcome
	_pending_battle_outcome = null
	_RouteBattle(outcome)

func _RouteBattle(outcome: EventOutcomeDef) -> void:
	## B 出口战路由：组装 BattleParams（倒地过滤）→ go(BATTLE_SCREEN,
	## {battle_params, return_to, expedition_run, event_id, battle_node_id})
	## ——战后经 pending_params 回传续跑；路由失败回滚战前演出（X3-09）
	## 参数 outcome：B 出口
	## 返回：无
	var params: BattleParams = _runner.build_battle_params(outcome, _run)
	if not _GoBattle(params, {
		&"event_id": _active_event_id,
		&"battle_node_id": _active_node_id,
	}):
		# 回滚：恢复待战出口 + 重呈战前演出视图（面板可再点「进入战斗」）
		_pending_battle_outcome = outcome
		_event_open = true
		_ShowEventPanel()
		if _last_battle_intro_view != null:
			_panel.show_battle_intro(_last_battle_intro_view,
					_RewardTextOf(_last_battle_intro_view),
					_RollDetailOf(_last_battle_intro_view))
		else:
			_event_open = false
			_SetHint(UI_TEXTS[&"route_failed"])

func _RouteEncounter(pack_id: StringName, consume_key: StringName) -> bool:
	## 遭遇战路由（必然/随机共用）：pack + 倒地过滤 party + HP 覆写单源
	## → go(BATTLE_SCREEN, {..., encounter_pack_id})；成功才落消耗账
	## （X3-09——失败零副作用）
	## 参数 pack_id：遭遇队伍 id；consume_key：路由成功后落账的消耗键
	## （必然遭遇 = 点位 id；随机传空）
	## 返回：true = 路由成功
	var params := BattleParams.new()
	params.pack_id = pack_id
	if not _GoBattle(params, {&"encounter_pack_id": pack_id}):
		return false
	if consume_key != &"":
		_run.consumed_events[consume_key] = true
	return true

func _GoBattle(params: BattleParams, extra_payload: Dictionary) -> bool:
	## 战斗路由共用口：全倒地前置拦截（占位终结）+ 倒地过滤出战名单 + 锁移交；
	## 双键并存防御（L1）；失败仅提示不落任何账
	## 参数 params：战斗参数（本函数补 party）；extra_payload：通道区分键
	## （battle_node_id / encounter_pack_id）
	## 返回：true = 路由成功
	if String(extra_payload.get(&"battle_node_id", &"")) != "" \
			and String(extra_payload.get(&"encounter_pack_id", &"")) != "":
		push_warning("explore_screen: battle_node_id 与 encounter_pack_id " \
				+ "双键并存——按遭遇通道处理")
	var alive_party: Array[AdventurerData] = []
	for adv: AdventurerData in _run.party:
		if not _run.downed.get(adv, false):
			alive_party.append(adv)
	if alive_party.is_empty():
		_event_open = false
		_panel.clear()
		_HideEventPanel()
		_FinishSession(true, UI_TEXTS[&"all_downed"])
		return false
	params.party = alive_party
	params.hp_overrides = _run.build_hp_overrides()
	_routing_battle = true
	# R4-15：关键入口消费 go 返回值（失败可感知 + 回滚）
	var err: Error = get_node("/root/SceneManager").go(SceneManagerScript.SceneId.BATTLE_SCREEN, {
		&"battle_params": params,
		&"return_to": SceneManagerScript.SceneId.EXPLORE_SCREEN,
		&"expedition_run": _run,
		&"event_id": extra_payload.get(&"event_id", &""),
		&"battle_node_id": extra_payload.get(&"battle_node_id", &""),
		&"encounter_pack_id": extra_payload.get(&"encounter_pack_id", &""),
	})
	if err != OK:
		_routing_battle = false
		push_warning("explore_screen: 路由战斗失败（错误码 %d）" % err)
		_SetHint(UI_TEXTS[&"route_failed"])
		return false
	_event_open = false
	_panel.clear()
	_HideEventPanel()
	return true

func _ResumeAfterBattle(result: BattleResult, battle_node_id: StringName,
		encounter_pack_id: StringName) -> void:
	## 战后续跑分叉（payload 键区分）：encounter_pack_id 非空 = 遭遇战
	## （胜利 → 原位继续 + CLEAR 判据通道）；battle_node_id 非空 = B 出口战
	## （胜利 → post_battle 结算续跑——B 出口战 = 剧情战不计入判据，
	## 2026-09-25 拍板）；DEFEAT/RETREAT / 全倒地 → 占位终结回城
	## 参数 result：战斗结果；battle_node_id：B 出口节点锚点；
	## encounter_pack_id：遭遇队伍 id
	## 返回：无
	_resuming = false
	if battle_node_id != &"" and encounter_pack_id != &"":
		push_warning("explore_screen: 回传 battle_node_id 与 encounter_pack_id " \
				+ "双键并存——按遭遇通道处理")
	_run.apply_battle_result(result.end_stats)
	var all_downed: bool = true
	for adv: AdventurerData in _run.party:
		if not _run.downed.get(adv, false):
			all_downed = false
			break
	if result.kind != BattleResult.ResultKind.VICTORY:
		_FinishSession(true, UI_TEXTS[&"battle_defeat"])
		return
	if all_downed:
		_FinishSession(true, UI_TEXTS[&"all_downed"])
		return
	if encounter_pack_id != &"":
		# 遭遇战胜利：原位继续（party_pos 不动）+ CLEAR 判据通道
		if _goal.on_battle_victory(encounter_pack_id):
			_run.goal_done = true
		_SetHint(UI_TEXTS[&"encounter_won"])
		_RefreshBoard()
		_RefreshStatus()
		return
	# B 出口战：post_battle 结算（锚点双形态——链节点 evn_ / 单点事件 sp_，
	# W2-2 单点 B 出口此前查 EventNodeDef 恒 null 即静默丢结算）
	var post_battle: EventOutcomeDef = _ResolvePostBattleOutcome(battle_node_id)
	if post_battle == null:
		# W2-14：锚点查无/缺 post_battle——跳过结算面板直接刷新（会话可继续，
		# 不软锁在「等一个不存在的结算视图」上）
		push_warning("explore_screen: B 出口锚点 '%s' 查无或缺 post_battle——跳过战后结算"
				% battle_node_id)
		_RefreshBoard()
		_RefreshStatus()
		return
	var view: EventRunner.EventView = _runner.resolve_outcome(post_battle, _run)
	_ShowSettledFromView(view)
	_RefreshBoard()
	_RefreshStatus()

func _ResolvePostBattleOutcome(anchor: StringName) -> EventOutcomeDef:
	## B 出口锚点 -> post_battle 出口解析（W2-2 双形态单源：evn_ 链节点走
	## node.outcome.battle；sp_ 单点走 success_outcome.battle——单点 B 出口
	## 无失败分支语义，检定失败时根本不路由战斗）
	## 参数 anchor：锚点 id（battle_node_id 回带）
	## 返回：post_battle 出口；查无/缺 battle/缺 post_battle 返回 null
	if String(anchor).begins_with("sp_"):
		var single: SingleEventDef = _game_data.get_record(anchor) as SingleEventDef
		if single == null or single.success_outcome == null \
				or single.success_outcome.battle == null:
			return null
		return single.success_outcome.battle.post_battle
	var node: EventNodeDef = _game_data.get_record(anchor) as EventNodeDef
	if node == null or node.outcome == null or node.outcome.battle == null:
		return null
	return node.outcome.battle.post_battle

# --------------------------------------------------------------------------
# 终结双通道（出口交付/自由探索结束 = 成功 / 撤退·战败·全倒地 = 失败）
# --------------------------------------------------------------------------

func _FinishSession(failed: bool, reason: String = "") -> void:
	## 会话终结：占位结算面板；失败通道不显示「收获申报」行（X3-04 拍板）；
	## run 由面板「回城」后的场景切换丢弃（实例销毁 = 进度不保留）
	## 参数 failed：通道类型（true = 失败——撤退/战败/全倒地/数据缺失；
	## false = 出口交付成功——含无委托自由探索）；reason：失败原因文本
	## 返回：无
	_finished = true
	_event_open = false
	if _panel != null:
		_panel.clear()
		_HideEventPanel()
	var title: String
	if failed:
		title = UI_TEXTS[&"settle_failed"]
	elif _run.goal_kind == -1:
		title = UI_TEXTS[&"settle_free_explore"]
	else:
		title = UI_TEXTS[&"settle_success"]
	%SettlementTitle.text = title
	if failed:
		%SettlementBody.text = reason
	else:
		var lead: String = reason if not reason.is_empty() else ""
		%SettlementBody.text = UI_TEXTS[&"settle_body"] % [lead,
				int(_run.rewards[&"exp"]), int(_run.rewards[&"gold"]),
				int(_run.rewards[&"reputation"]), _run.total_days()]
	%SettlementPanel.visible = true

func _OnSettleReturnPressed() -> void:
	## 结算面板「回城」：run 丢弃回公会壳（场景切换 = 实例销毁；_exit_tree
	## 恢复出征锁）；回城存档（RETURN_SETTLED 时点）接管归 M4 出征结算
	## （2026-09-25 拍板登记）
	## 参数：无
	## 返回：无
	var err: Error = get_node("/root/SceneManager").go(SceneManagerScript.SceneId.GUILD_SHELL)
	if err != OK:
		push_warning("explore_screen: 结算回城失败（错误码 %d）" % err)

func _OnRetreatPressed() -> void:
	## 撤退按钮：确认弹窗（撤退 = 委托失败——达成后撤退仍走失败通道）
	## 参数：无
	## 返回：无
	if _finished or _moving or _event_open or _resuming:
		return
	%RetreatConfirm.popup_centered()

func _OnRetreatConfirmConfirmed() -> void:
	## 撤退确认：失败通道终结（run 丢弃）
	## 参数：无
	## 返回：无
	_FinishSession(true, UI_TEXTS[&"retreat_failed"])

func _OnGuiInput(event: InputEvent) -> void:
	## 点按跳过 D20 演出
	## 参数 event：输入事件
	## 返回：无
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_panel.skip_d20()

func _SetHint(text: String) -> void:
	## 底部提示行
	## 参数 text：提示文本（空 = 清除）
	## 返回：无
	%HintLabel.text = text
