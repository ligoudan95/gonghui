## 协会屏（association_screen）场景脚本——M4 批 2
## 职责：三分区——委托板（QuestBoardPanel：卡片含名称/等级档/剩余天数/推荐
## 属性/奖励预览/目标区域/人力区间）/ 挂单管理（AcceptedPanel：查看/放弃/
## 出征/重编队——消费 GuildCore.accept/reassign/start/abandon 门面）/
## 招募池（RecruitPanel：候选卡+刷新提示）；编队派遣为屏内弹层 OrganizePanel
##（选人带占用/休养/当日已出征标记；检定/超额/沿用三预览归批 3）。
## 出征链路：挂单「出征」→ GuildState.build_expedition_run → EXPLORE_SCREEN。
## M5 批 3（拍板③）：顶栏提示行增最近一次自动存档失败感知（guild_shell
## 同款文案口径——RefreshAll 读 GuildState.last_autosave_failed）。
## 数据来源：案 6（委托运转）/案 5 §2.4（招募）；UI 规范=案 15 + UiTheme。
## 单例访问：统一 get_node("/root/X")（gdUnit 测试环境惯例）。
extends Control

## SceneManager 脚本常量引用
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")

## 场景背景资源 id（M6 批 3.5b 组 1：bg_association_hall——AssetRegistry
## 单源路径映射，铁律②）
const BACKGROUND_ASSET_ID: StringName = &"bg_association_hall"

## UI 文案模板（逻辑层零文案——UI 层单源；S4-M4-4：本屏内联提示收编单源）
const UI_TEXTS: Dictionary = {
	&"start_fail_no_data": "出征装配失败——队伍或地图数据缺失。",
	&"go_fail_rollback_format": "进入探索屏失败——出征已取消（%s），请重试。",
	## S5-10：go 失败回退提示的括号参数固定走错误码（core.last_error 在回退
	## 链后为空串会产出「出征已取消（）」）
	&"go_fail_err_format": "错误码 %d",
	&"recruit_ok_format": "%s 入会（当前 %d/%d 人）",
	&"light_start_ok_format": "已派出开工——工期 %d 天",
	&"light_abandon_confirm_text": "放弃进行中的轻度委托？工期作废、无奖励，成员立即释放。",
	&"light_abandon_confirm_ok": "确认放弃",
	&"light_abandon_confirm_cancel": "再想想",
	&"autosave_failed_hint": "⚠ 最近一次自动存档写入失败——进度可能未落盘，请重试操作。",
	## S5-R5-03：返回 go 失败提示（%d = SceneManager 错误码）
	&"go_fail_hint_format": "页面跳转失败（错误码 %d）——请重试。",
	## M6 批 2 挂账 4.2：顶栏资源行（%d 金 / %d 天）
	&"gold_line_format": "%d 金｜第 %d 天",
}

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
## 轻度放弃二次确认弹窗（M4 增补批——代码构建+UiTheme 档位）
var _light_abandon_confirm: ConfirmationDialog = null
## 待确认放弃的轻度实例序号（弹窗确认消费）
var _pending_light_abandon_serial: int = 0

func _ready() -> void:
	## 引擎回调：装配三分区与编队弹层 → 信号接线 → 清未查看挂单标记
	##（M4-1：角标进协会即消费）→ 刷新
	## 参数：无
	## 返回：无
	_game_data = get_node("/root/GameData")
	_cfg = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	_ApplyBackgroundTexture()
	get_node("/root/SceneManager").take_pending_params()
	_core().has_unseen_grants = false
	_board_panel = QuestBoardPanel.new()
	_board_panel.setup(_cfg)
	# S4-02：板刷稳态 11 单卡片高度超出可视区——BoardHost 改 ScrollContainer
	# （对齐 AcceptedHost 先例），面板撑满滚动区宽度防卡片塌缩
	_board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_organize_panel.setup(_cfg, _game_data)
	%OrganizeHost.add_child(_organize_panel)
	_organize_panel.confirmed.connect(_OnOrganizeConfirmed)
	_organize_panel.cancelled.connect(_OnOrganizeCancelled)
	# M4 增补批：轻度放弃二次确认弹窗（LIGHT_RUNNING 工期作废警示）
	_light_abandon_confirm = ConfirmationDialog.new()
	_light_abandon_confirm.dialog_text = UI_TEXTS[&"light_abandon_confirm_text"]
	_light_abandon_confirm.ok_button_text = UI_TEXTS[&"light_abandon_confirm_ok"]
	_light_abandon_confirm.cancel_button_text = UI_TEXTS[&"light_abandon_confirm_cancel"]
	_light_abandon_confirm.confirmed.connect(_OnLightAbandonConfirmed)
	add_child(_light_abandon_confirm)
	_ApplyFontTiers()
	RefreshAll()

func _ApplyBackgroundTexture() -> void:
	## 场景背景接线（M6 批 3.5b 组 1）：AssetTex.apply_to 单源装配
	## bg_association_hall（KEEP_ASPECT_COVERED 铺满全屏——guild_shell 同构）；
	## 缺件/缺登记返回 false——Background ColorRect 纯色兜底原样可见
	## 参数：无
	## 返回：无
	AssetTex.apply_to(%BackgroundTexture, BACKGROUND_ASSET_ID, _game_data)

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
	%GoldLabel.text = UI_TEXTS[&"gold_line_format"] % [core.gold, core.day]
	_board_panel.refresh(core.board.board, _game_data, core.day)
	_accepted_panel.refresh(core.board.accepted, core)
	_recruit_panel.refresh(core)
	# M5 批 3（拍板③顺手补）：最近一次自动存档失败感知——guild_shell 同款
	## 文案口径与语义（RefreshAll 读标志呈现；标志由 GuildState 业务口每次
	## 入口复位——本轮成功即清除，不覆写操作成功文案）
	if _guild_state().last_autosave_failed:
		%HintLabel.text = UI_TEXTS[&"autosave_failed_hint"]

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
	## 编队确认（M4 增补批路由分流）：板上轻度模板走 start_light_quest
	##（一步开工）、板上战斗模板走 accept_quest（接单=编队确认）、挂单实例走
	## reassign_party（占用转移）；失败原因呈现在弹层提示行（弹层不关）
	## 参数 serial：实例序号；member_ids：选中成员 id 列表
	## 返回：无
	var core: GuildCore = _core()
	var target: QuestInstance = core.board.find_on_board(serial)
	var ok: bool = false
	var is_light: bool = false
	if target != null:
		var tpl: QuestTemplateDef = _game_data.get_record(target.template_id) as QuestTemplateDef
		is_light = tpl != null and tpl.exec_class == QuestTemplateDef.ExecClass.NON_COMBAT
		ok = core.start_light_quest(serial, member_ids) if is_light \
				else core.accept_quest(serial, member_ids)
	else:
		ok = core.reassign_party(serial, member_ids)
	if not ok:
		_organize_panel.show_hint(core.last_error)
		return
	_CloseOrganize()
	# 轻度开工成功提示（工期天数；战斗通道维持清空提示行）
	if is_light:
		var tpl2: QuestTemplateDef = _game_data.get_record(target.template_id) as QuestTemplateDef
		if tpl2 != null:
			_SetHint(String(UI_TEXTS[&"light_start_ok_format"]) % tpl2.duration_days)
	else:
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
		_SetHint(String(UI_TEXTS[&"start_fail_no_data"]) if core.last_error.is_empty() \
				else core.last_error)
		return
	_SetHint("")
	var err: Error = get_node("/root/SceneManager").go(
			SceneManagerScript.SceneId.EXPLORE_SCREEN, {&"expedition_run": run})
	if err != OK:
		# M4：go 失败完整回退（释锁→委托回挂单→出征日标记恢复）——不出征；
		# S5-10：括号参数改用 err 错误码（回退链后 core.last_error 为空串会
		## 产出「出征已取消（）」空括号）
		get_node("/root/SaveManager").set_expedition_lock(false)
		core.abort_expedition(serial, previous_days)
		_SetHint(String(UI_TEXTS[&"go_fail_rollback_format"])
				% String(UI_TEXTS[&"go_fail_err_format"]) % err)
		push_error("association_screen: 进入探索屏失败（错误码 %d）——已回退出征登记" % err)
		RefreshAll()

func _OnAbandonRequested(serial: int) -> void:
	## 挂单「放弃」（P2 拍板：无惩罚无奖励、释放占用）；M4 增补批：
	## LIGHT_RUNNING 轻度进行中先弹二次确认（工期作废警示）——战斗挂单
	## ACCEPTED 态维持直通
	## 参数 serial：挂单实例序号
	## 返回：无
	var core: GuildCore = _core()
	var inst: QuestInstance = core.board.find_accepted(serial)
	if inst != null and inst.state == QuestInstance.State.LIGHT_RUNNING:
		_pending_light_abandon_serial = serial
		_light_abandon_confirm.popup_centered()
		return
	if not core.abandon_quest(serial):
		_SetHint(core.last_error)
		return
	_SetHint("")
	RefreshAll()

func _OnLightAbandonConfirmed() -> void:
	## 轻度放弃确认（工期作废、成员立即释放——Q5 拍板口径）；S4-04：成败两路
	## 均复位待确认序号（失败分支残留会在下次确认窗口错杀新实例）
	## 参数：无
	## 返回：无
	var core: GuildCore = _core()
	var confirmed_serial: int = _pending_light_abandon_serial
	_pending_light_abandon_serial = 0
	if not core.abandon_quest(confirmed_serial):
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
	_SetHint(String(UI_TEXTS[&"recruit_ok_format"]) % [member.display_name,
			_core().roster.size(), _core().dorm_capacity()])
	RefreshAll()

func _on_back_pressed() -> void:
	## 返回公会主界面
	## 参数：无
	## 返回：无
	var err: Error = get_node("/root/SceneManager").go(SceneManagerScript.SceneId.GUILD_SHELL)
	if err != OK:
		push_warning("association_screen: 返回公会失败（错误码 %d）" % err)
		# S5-R5-03：go 失败可见提示（hint 通道——不再仅静默 push_warning）
		_SetHint(String(UI_TEXTS[&"go_fail_hint_format"]) % err)
