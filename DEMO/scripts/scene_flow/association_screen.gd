## 协会屏（association_screen）场景脚本——M4 批 2
## 职责：三分区——委托板（QuestBoardPanel：卡片含名称/等级档/剩余天数/推荐
## 属性/奖励预览/目标区域/人力区间）/ 挂单管理（AcceptedPanel：查看/放弃/
## 出征/重编队——消费 GuildCore.accept/reassign/start/abandon 门面）/
## 招募池（RecruitPanel：候选卡+刷新提示）；编队派遣为屏内弹层 OrganizePanel
##（选人带占用/休养/当日已出征标记；检定/超额/沿用三预览归批 3）。
## 出征链路：挂单「出征」→ GuildState.build_expedition_run → EXPLORE_SCREEN。
## 数据来源：案 6（委托运转）/案 5 §2.4（招募）；UI 规范=案 15 + UiTheme。
## 单例访问：统一 get_node("/root/X")（gdUnit 测试环境惯例）。
extends Control

## SceneManager 脚本常量引用
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")

## GameData 单例引用
var _game_data: Node = null
## 总控配置
var _cfg: CoreConfig = null
## 委托板面板
var _board_panel: QuestBoardPanel = null
## 挂单管理面板
var _accepted_panel: AcceptedPanel = null
## 招募池面板
var _recruit_panel: RecruitPanel = null
## 编队弹层
var _organize_panel: OrganizePanel = null

func _ready() -> void:
	## 引擎回调：装配三分区与编队弹层 → 信号接线 → 清未查看挂单标记
	##（M4-1：角标进协会即消费）→ 刷新
	## 参数：无
	## 返回：无
	_game_data = get_node("/root/GameData")
	_cfg = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	get_node("/root/SceneManager").take_pending_params()
	_core().has_unseen_grants = false
	_board_panel = QuestBoardPanel.new()
	_board_panel.setup(_cfg)
	%BoardHost.add_child(_board_panel)
	_board_panel.quest_picked.connect(_OnQuestPicked)
	_accepted_panel = AcceptedPanel.new()
	_accepted_panel.setup(_cfg)
	%AcceptedHost.add_child(_accepted_panel)
	_accepted_panel.start_requested.connect(_OnStartRequested)
	_accepted_panel.reassign_requested.connect(_OnReassignRequested)
	_accepted_panel.abandon_requested.connect(_OnAbandonRequested)
	_recruit_panel = RecruitPanel.new()
	_recruit_panel.setup(_cfg)
	%RecruitHost.add_child(_recruit_panel)
	_recruit_panel.recruit_requested.connect(_OnRecruitRequested)
	_organize_panel = OrganizePanel.new()
	_organize_panel.setup(_cfg)
	%OrganizeHost.add_child(_organize_panel)
	_organize_panel.confirmed.connect(_OnOrganizeConfirmed)
	_organize_panel.cancelled.connect(_OnOrganizeCancelled)
	_ApplyFontTiers()
	RefreshAll()

func _ApplyFontTiers() -> void:
	## tscn 内嵌字号档位覆写（B-7 惯例）；W3-08：按钮统一 normal 档
	## 参数：无
	## 返回：无
	%TitleLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_heading", UiTheme.FONT_HEADING))
	%GoldLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_large", UiTheme.FONT_LARGE))
	%HintLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	%BackButton.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))

func _core() -> GuildCore:
	## 公会核心读取口
	## 参数：无
	## 返回：GuildCore
	return get_node("/root/GuildState").core

func _guild_state() -> Node:
	## 取 GuildState 自动加载单例
	## 参数：无
	## 返回：GuildState 节点
	return get_node("/root/GuildState")

func RefreshAll() -> void:
	## 三分区全量刷新（顶栏货币+板+挂单+招募）
	## 参数：无
	## 返回：无
	var core: GuildCore = _core()
	%GoldLabel.text = "%d 金｜第 %d 天" % [core.gold, core.day]
	_board_panel.refresh(core.board.board, _game_data, core.day)
	_accepted_panel.refresh(core.board.accepted, core)
	_recruit_panel.refresh(core)

func _SetHint(text: String) -> void:
	## 顶栏下方提示行（门面校验失败原因呈现）
	## 参数 text：提示文本（空 = 清除）
	## 返回：无
	%HintLabel.text = text

# --------------------------------------------------------------------------
# 接单 / 重编队（OrganizePanel 弹层）
# --------------------------------------------------------------------------

func _OnQuestPicked(serial: int) -> void:
	## 委托板「接单」：编队弹层（接单模式——预选沿用上次编队）
	## 参数 serial：板上实例序号
	## 返回：无
	var inst: QuestInstance = _core().board.find_on_board(serial)
	if inst == null:
		RefreshAll()
		return
	%OrganizeHost.visible = true
	_organize_panel.open(inst, _core())

func _OnReassignRequested(serial: int) -> void:
	## 挂单「重编队」：编队弹层（重编队模式——预选当前编队，占用转移校验）
	## 参数 serial：挂单实例序号
	## 返回：无
	var inst: QuestInstance = _core().board.find_accepted(serial)
	if inst == null or inst.state != QuestInstance.State.ACCEPTED:
		RefreshAll()
		return
	%OrganizeHost.visible = true
	_organize_panel.open(inst, _core())

func _OnOrganizeConfirmed(serial: int, member_ids: Array[StringName]) -> void:
	## 编队确认：板上实例走 accept_quest（接单=编队确认）、挂单实例走
	## reassign_party（占用转移）；失败原因呈现在弹层提示行（弹层不关）
	## 参数 serial：实例序号；member_ids：选中成员 id 列表
	## 返回：无
	var core: GuildCore = _core()
	var is_accept: bool = core.board.find_on_board(serial) != null
	var ok: bool = core.accept_quest(serial, member_ids) if is_accept \
			else core.reassign_party(serial, member_ids)
	if not ok:
		_organize_panel.show_hint(core.last_error)
		return
	_CloseOrganize()
	_SetHint("")
	RefreshAll()

func _OnOrganizeCancelled() -> void:
	## 编队取消
	## 参数：无
	## 返回：无
	_CloseOrganize()

func _CloseOrganize() -> void:
	## 关闭编队弹层
	## 参数：无
	## 返回：无
	_organize_panel.close()
	%OrganizeHost.visible = false

# --------------------------------------------------------------------------
# 挂单三操作（出征 / 放弃）与招募
# --------------------------------------------------------------------------

func _OnStartRequested(serial: int) -> void:
	## 挂单「出征」：GuildState.begin_expedition（装配+确认+**同段置锁**——
	## M4-3 无帧窗）→ EXPLORE_SCREEN；装配或校验失败仅提示不迁移状态不置锁；
	## go 失败**完整回退**（M4 软锁修复：释锁+委托回 ACCEPTED+出征日标记恢复
	## ——三路不再全堵）
	## 参数 serial：挂单实例序号
	## 返回：无
	var core: GuildCore = _core()
	var inst: QuestInstance = core.board.find_accepted(serial)
	if inst == null or inst.state != QuestInstance.State.ACCEPTED:
		RefreshAll()
		return
	# 出征日标记快照（go 失败回退用——begin 成功会覆写为当前 day）
	var previous_days: Dictionary = {}
	for member_id: StringName in inst.party_ids:
		var member: AdventurerData = core.find_member(member_id)
		if member != null:
			previous_days[String(member_id)] = member.last_expedition_day
	var run: ExpeditionRun = _guild_state().begin_expedition(inst)
	if run == null:
		# 装配失败（数据缺失）或确认失败（core.last_error——进行中上限/每日一次）
		_SetHint("出征装配失败——队伍或地图数据缺失。" if core.last_error.is_empty() \
				else core.last_error)
		return
	_SetHint("")
	var err: Error = get_node("/root/SceneManager").go(
			SceneManagerScript.SceneId.EXPLORE_SCREEN, {&"expedition_run": run})
	if err != OK:
		# M4：go 失败完整回退（释锁→委托回挂单→出征日标记恢复）——不出征
		get_node("/root/SaveManager").set_expedition_lock(false)
		core.abort_expedition(serial, previous_days)
		_SetHint("进入探索屏失败——出征已取消（%s），请重试。" % core.last_error)
		push_error("association_screen: 进入探索屏失败（错误码 %d）——已回退出征登记" % err)
		RefreshAll()

func _OnAbandonRequested(serial: int) -> void:
	## 挂单「放弃」（P2 拍板：无惩罚无奖励、释放占用）
	## 参数 serial：挂单实例序号
	## 返回：无
	var core: GuildCore = _core()
	if not core.abandon_quest(serial):
		_SetHint(core.last_error)
		return
	_SetHint("")
	RefreshAll()

func _OnRecruitRequested(index: int) -> void:
	## 招募（GuildState.recruit——余额/宿舍校验+扣款入册+RECRUIT_DONE 存档）
	## 参数 index：候选下标
	## 返回：无
	var member: AdventurerData = _guild_state().recruit(index)
	if member == null:
		_SetHint(_core().last_error)
		return
	_SetHint("%s 入会（当前 %d/%d 人）" % [member.display_name,
			_core().roster.size(), _core().dorm_capacity()])
	RefreshAll()

func _on_back_pressed() -> void:
	## 返回公会主界面
	## 参数：无
	## 返回：无
	var err: Error = get_node("/root/SceneManager").go(SceneManagerScript.SceneId.GUILD_SHELL)
	if err != OK:
		push_warning("association_screen: 返回公会失败（错误码 %d）" % err)
