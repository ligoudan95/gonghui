## 公会经营流集成测试（M4 批 2 + 批 3）
## 覆盖：接单→编队（弹层选人）→出征锁→模拟 run 回城→结算（GuildState 接管：
## 货币/经验/板凳/日历推进/RETURN_SETTLED）→回城 HUD→等待一天→招募→
## 升设施全链；出征中等待禁用；「关游戏→继续」（新会话模拟 restore）回最近
## 城内时点；四新屏 1080p 布局契约（W3-01 口径——真实视口不溢出）；
## 批 3：到期失败/放弃/重编队（占用转移）/等待推进日历完整结算（HUD 可感知）/
## 升级连升+倾向悬置补加+技能解锁 UI 链/三预览/新挂单角标/弹层布局契约。
## 环境：gdUnit 帧内真 autoload（GameData/SaveManager/SceneManager/GuildState）。
extends GdUnitTestSuite

## 场景路径
const GUILD_SCENE: String = "res://scenes/guild/guild_shell.tscn"
const ASSOC_SCENE: String = "res://scenes/guild/association_screen.tscn"
const DORM_SCENE: String = "res://scenes/guild/guild_dormitory.tscn"
const TRAIN_SCENE: String = "res://scenes/guild/guild_training_ground.tscn"
## 场景 id（M4 批 2 枚举序：GUILD_SHELL=1/EXPLORE=3/DORM=5/TRAIN=6/ASSOC=4）
const SCENE_GUILD_SHELL: int = 1
const SCENE_EXPLORE: int = 3
const SCENE_DORM: int = 5
const SCENE_TRAIN: int = 6
const SCENE_ASSOC: int = 4

func before_test() -> void:
	## 用例级前置：复位 SceneManager/SaveManager/GuildState 可变状态；清存档目录
	## 参数：无
	## 返回：无
	_CleanSaveDir()
	var root: Node = get_tree().root
	var scene_manager: Node = root.get_node("SceneManager")
	scene_manager.current_id = -1
	scene_manager.previous_id = -1
	var no_params: Dictionary = {}
	scene_manager.pending_params = no_params
	root.get_node("SaveManager").set_expedition_lock(false)
	root.get_node("GuildState").core = GuildCore.new()

func after_test() -> void:
	## 用例级后置：清理存档目录
	## 参数：无
	## 返回：无
	_CleanSaveDir()

func _CleanSaveDir() -> void:
	## 清理 user://saves（批 3 惯例）
	## 参数：无
	## 返回：无
	var dir: DirAccess = DirAccess.open("user://saves")
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while not entry_name.is_empty():
		if not dir.current_is_dir():
			dir.remove(entry_name)
		entry_name = dir.get_next()
	dir.list_dir_end()

func _WaitFrames(frames: int) -> void:
	## 帧等待助手
	## 参数 frames：帧数
	## 返回：无（协程）
	for _i: int in frames:
		await get_tree().process_frame

func _GuildState() -> Node:
	## 取 GuildState autoload
	## 参数：无
	## 返回：GuildState 节点
	return get_tree().root.get_node("GuildState")

func _Core() -> GuildCore:
	## 取公会核心
	## 参数：无
	## 返回：GuildCore
	return _GuildState().core

func _NewGame() -> void:
	## 建新档（GuildState 入口——生产口径）
	## 参数：无
	## 返回：无
	_GuildState().new_game()

func _SpawnClearQuest() -> QuestInstance:
	## 定点生成清剿委托（板上唯一——确定性接单目标）
	## 参数：无
	## 返回：QuestInstance
	var core: GuildCore = _Core()
	core.board.board.clear()
	return core.board.spawn_on_board(&"q_lair_purge", core.day)

func test_full_chain_accept_to_settle() -> void:
	## 全链：接单（弹层选人确认）→挂单→出征（锁+探索屏）→出口交付结算→
	## 回城 HUD→等待一天→招募→升设施
	_NewGame()
	var core: GuildCore = _Core()
	# --- 协会屏：接单（板上定点 q_lair_purge → 接单钮 → 编队弹层选 3 人确认）---
	var assoc: GdUnitSceneRunner = scene_runner(ASSOC_SCENE)
	_SpawnClearQuest()
	(assoc.scene() as Control).RefreshAll()
	await _WaitFrames(1)
	(assoc.find_child("AcceptButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	var screen: Control = assoc.scene() as Control
	assert_bool(screen.get_node("%OrganizeHost").visible).is_true()
	var checks: Array = screen._organize_panel._checks.values()
	assert_int(checks.size()).is_equal(4)
	var picked: int = 0
	for check: CheckBox in checks:
		if picked < 3:
			check.button_pressed = true
			picked += 1
	(assoc.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	assert_int(core.board.accepted.size()).is_equal(1)
	var inst: QuestInstance = core.board.accepted[0]
	assert_int(inst.state).is_equal(QuestInstance.State.ACCEPTED)
	assert_int(inst.party_ids.size()).is_equal(3)
	# 接取不补位：板空（清板后仅此一单，已接走）
	assert_int(core.board.board.size()).is_equal(0)
	# --- 出征：StartButton → 同步段落锁（M4-3：确认成功即置锁——go() 切换
	# 帧窗内等待按钮已禁用）→ 探索屏挂载 + run 判据上下文 ---
	(assoc.find_child("StartButton", true, false) as Button).pressed.emit()
	assert_bool(get_tree().root.get_node("SaveManager").is_expedition_locked()).is_true()
	await _WaitFrames(4)
	var explore: Control = get_tree().root.find_child("ExploreScreen", true, false) as Control
	assert_object(explore).is_not_null()
	assert_int(get_tree().root.get_node("SceneManager").current_id).is_equal(SCENE_EXPLORE)
	assert_bool(get_tree().root.get_node("SaveManager").is_expedition_locked()).is_true()
	assert_str(String(explore._run.quest_template_id)).is_equal("q_lair_purge")
	assert_int(explore._run.party.size()).is_equal(3)
	# --- 回城结算（出口交付模拟）：释锁先行 + 结算面板（summary 驱动）---
	var gold_before: int = core.gold
	explore._FinishSession(GuildCore.ExpeditionOutcome.SUCCESS)
	assert_bool(get_tree().root.get_node("SaveManager").is_expedition_locked()).is_false()
	assert_bool(explore.get_node("%SettlementPanel").visible).is_true()
	assert_str(explore.get_node("%SettlementBody").text).contains("150")
	# 3 人下限编队无超额：+150 金/+5 声望；板凳（第 4 人）24 经验；日历 1→2
	assert_int(core.gold - gold_before).is_equal(150)
	assert_int(core.reputation).is_equal(5)
	assert_int(core.roster[3].exp).is_equal(24)
	assert_int(core.day).is_equal(2)
	assert_int(get_tree().root.get_node("SaveManager").current.save_point)\
			.is_equal(SaveData.SavePoint.RETURN_SETTLED)
	assert_int(core.board.accepted.size()).is_equal(0)
	# --- 回城按钮 → 公会壳 HUD 反映结算后状态 ---
	(explore.get_node("%SettlementButton") as Button).pressed.emit()
	await _WaitFrames(4)
	var shell: Control = get_tree().root.find_child("GuildShell", true, false) as Control
	assert_object(shell).is_not_null()
	assert_str((shell.get_node("%DayLabel") as Label).text).contains("第 2 天")
	assert_str((shell.get_node("%GoldLabel") as Label).text).contains("650")
	# --- 等待一天（DAY_END）→ 招募（RECRUIT_DONE）---
	(shell.get_node("%WaitButton") as Button).pressed.emit()
	await _WaitFrames(2)
	assert_int(core.day).is_equal(3)
	var assoc2: GdUnitSceneRunner = scene_runner(ASSOC_SCENE)
	await _WaitFrames(1)
	var cost: int = _Core().recruit_pool.cost_of(_Core().recruit_pool.candidates[0])
	var gold_at_recruit: int = _Core().gold
	(assoc2.find_child("RecruitButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	assert_int(_Core().roster.size()).is_equal(5)
	assert_int(_Core().gold).is_equal(gold_at_recruit - cost)
	assert_int(get_tree().root.get_node("SaveManager").current.save_point)\
			.is_equal(SaveData.SavePoint.RECRUIT_DONE)
	# --- 升设施（FACILITY_UPGRADED）：训练场 Lv2 600 金 ---
	_Core().gold = 1000
	get_tree().root.get_node("SceneManager").go(SCENE_TRAIN)
	await _WaitFrames(4)
	var train: Control = get_tree().root.find_child("TrainingGroundScreen", true, false) as Control
	assert_object(train).is_not_null()
	assert_str((train.find_child("TitleLabel", true, false) as Label).text).contains("训练场")
	(train.find_child("UpgradeButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	assert_int(int(_Core().facility_levels[&"fac_training_ground"])).is_equal(2)
	assert_int(_Core().gold).is_equal(400)
	assert_float(_Core().bench_share_rate()).is_equal(0.4)

func test_wait_disabled_while_expedition_locked() -> void:
	## 出征中等待禁用（日历冻结口径——guild_shell 刷新口）
	_NewGame()
	var runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	await _WaitFrames(2)
	var shell: Control = runner.scene() as Control
	assert_bool((shell.get_node("%WaitButton") as Button).disabled).is_false()
	get_tree().root.get_node("SaveManager").set_expedition_lock(true)
	shell.RefreshAll()
	assert_bool((shell.get_node("%WaitButton") as Button).disabled).is_true()

func test_shutdown_and_continue_restores_city_point() -> void:
	## 关游戏→继续（新会话模拟 restore）：RETURN_SETTLED 存档 → current/core
	## 置空重建 → load_game → 公会快照恢复回最近城内时点（天数/货币/名册一致）
	_NewGame()
	var core: GuildCore = _Core()
	core.gold = 888
	core.settle_one_day()
	get_tree().root.get_node("SaveManager").autosave(
			SaveData.SavePoint.RETURN_SETTLED)
	var saved_day: int = core.day
	var saved_gold: int = core.gold
	# 模拟新会话：运行态与核心全部丢弃
	get_tree().root.get_node("SaveManager").current = null
	_GuildState().core = GuildCore.new()
	var loaded: SaveData = get_tree().root.get_node("SaveManager").load_game()
	assert_object(loaded).is_not_null()
	assert_int(_Core().day).is_equal(saved_day)
	assert_int(_Core().gold).is_equal(saved_gold)
	assert_int(_Core().roster.size()).is_equal(4)
	# 存档场景锚 = 公会壳（回城时点语义——title 继续回最近城内点）
	assert_str(String(loaded.scene_id)).is_equal("guild_shell")

func test_expire_abandon_reassign_flow() -> void:
	## 挂单三操作与到期（批 3）：接 A/B 两单 → 放弃 B（释放占用）→ 重编队 A
	##（占用随编队转移）→ 等待推进至到期线 → 挂单到期自动失败（HUD 轻提示）
	_NewGame()
	var core: GuildCore = _Core()
	core.board.board.clear()
	core.board.spawn_on_board(&"q_vein_survey", core.day)
	core.board.spawn_on_board(&"q_north_survey", core.day)
	var assoc: GdUnitSceneRunner = scene_runner(ASSOC_SCENE)
	await _WaitFrames(1)
	var screen: Control = assoc.scene() as Control
	# 接 A（前 2 人）
	(assoc.find_child("AcceptButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	_CheckFirstN(screen._organize_panel, 2)
	(assoc.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	# 接 B（后 2 人——A 接走后板上首卡即 B）
	(assoc.find_child("AcceptButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	_CheckLastN(screen._organize_panel, 2)
	(assoc.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	assert_int(core.board.accepted.size()).is_equal(2)
	assert_int(core.board.occupied_member_ids().size()).is_equal(4)
	# 放弃 B（第二行的 AbandonButton——树序 [A 行, B 行]）
	var abandon_buttons: Array = screen.find_children("AbandonButton", "Button", true, false)
	assert_int(abandon_buttons.size()).is_equal(2)
	(abandon_buttons[1] as Button).pressed.emit()
	await _WaitFrames(1)
	assert_int(core.board.accepted.size()).is_equal(1)
	assert_int(core.board.occupied_member_ids().size()).is_equal(2)
	# 重编队 A → 改为后 2 人（占用转移：原 2 人释放、新 2 人占用）
	var reassign_buttons: Array = screen.find_children("ReassignButton", "Button", true, false)
	(reassign_buttons[0] as Button).pressed.emit()
	await _WaitFrames(1)
	assert_bool(screen.get_node("%OrganizeHost").visible).is_true()
	for check: CheckBox in screen._organize_panel._checks.values():
		check.button_pressed = false
	_CheckLastN(screen._organize_panel, 2)
	(assoc.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	var quest_a: QuestInstance = core.board.accepted[0]
	assert_int(quest_a.party_ids.size()).is_equal(2)
	assert_str(String(quest_a.party_ids[0])).is_equal(String(core.roster[2].unit_id))
	assert_int(core.board.occupied_member_ids().size()).is_equal(2)
	# 等待推进至到期线（上板日 1 + 时限 5 = 第 6 天结算到期）：HUD 轻提示可见
	var shell_runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	await _WaitFrames(2)
	var shell: Control = shell_runner.scene() as Control
	for _day_index: int in 5:
		(shell.get_node("%WaitButton") as Button).pressed.emit()
		await _WaitFrames(1)
	assert_int(core.day).is_equal(6)
	assert_int(core.board.accepted.size()).is_equal(0)
	assert_str((shell.get_node("%SettleInfoLabel") as Label).text).contains("挂单到期失败")

func _CheckFirstN(panel: OrganizePanel, count: int) -> void:
	## 编队弹层勾选前 count 名可用成员（测试助手）
	## 参数 panel：编队弹层；count：勾选数
	## 返回：无
	var picked: int = 0
	for check: CheckBox in panel._checks.values():
		check.button_pressed = not check.disabled and picked < count
		if not check.disabled:
			picked += 1

func _CheckLastN(panel: OrganizePanel, count: int) -> void:
	## 编队弹层勾选末 count 名可用成员（测试助手）
	## 参数 panel：编队弹层；count：勾选数
	## 返回：无
	var enabled: Array = []
	for check: CheckBox in panel._checks.values():
		if not check.disabled:
			enabled.append(check)
	for index: int in enabled.size():
		(enabled[index] as CheckBox).button_pressed = index >= enabled.size() - count

func test_wait_day_full_settlement_hud_visible() -> void:
	## 等待推进日历完整结算（HUD 可感知）：休养倒计归零转健康进轻提示行 +
	## 天数/星期前进
	_NewGame()
	var core: GuildCore = _Core()
	core.roster[0].status = AdventurerData.Status.RESTING
	core.roster[0].rest_days = 1
	var runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	await _WaitFrames(2)
	var shell: Control = runner.scene() as Control
	(shell.get_node("%WaitButton") as Button).pressed.emit()
	await _WaitFrames(1)
	assert_int(core.day).is_equal(2)
	assert_int(core.roster[0].status).is_equal(AdventurerData.Status.HEALTHY)
	var info: String = (shell.get_node("%SettleInfoLabel") as Label).text
	assert_str(info).contains("恢复 1 人")
	assert_str(info).contains("新候选")
	assert_str((shell.get_node("%DayLabel") as Label).text).contains("第 2 天·周二")

func test_growth_tendency_skill_unlock_ui_chain() -> void:
	## 养成 UI 链（批 3）：升级连升（exp 250 → Lv3 悬置 2 级）→ 详情弹层
	##（普攻常驻条目/技能点/解锁按钮）→ 花点解锁技能 → 倾向入口 → 升级面板
	## 悬置提示 → 选倾向按积压补加侧重属性（+2）并清悬置
	_NewGame()
	var core: GuildCore = _Core()
	var cfg: CoreConfig = get_tree().root.get_node("GameData").get_record(
			CoreConfig.CFG_MAIN_ID) as CoreConfig
	# 名册确定性序（批 3 修正：String 字典序 erin/iron_peak/morris/night_song）
	#——取战士位成员驱动（倾向=狂战/侧重力量、两技可验解锁链）
	var member: AdventurerData = core.roster[0]
	var member_row_index: int = 0
	for index: int in core.roster.size():
		if core.roster[index].class_id == &"cls_warrior":
			member = core.roster[index]
			member_row_index = index
	var gained: int = GrowthCore.apply_exp(member, 350, cfg, core.game_data,
			core.pending_tendency_levels)
	assert_int(gained).is_equal(2)
	assert_int(member.level).is_equal(3)
	assert_int(member.skill_points).is_equal(3)
	var strength_before: int = int(member.attrs[AttrKeys.STRENGTH])
	var runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	await _WaitFrames(2)
	var shell: Control = runner.scene() as Control
	# 行点击 → 详情弹层（标题含成员名；普攻常驻条目）——总览行按钮序 = 名册序
	##（同名自动改名限制：非首行经 _row_buttons 序号驱动）
	(shell._roster_overview._row_buttons[member_row_index] as Button).pressed.emit()
	await _WaitFrames(1)
	assert_bool(shell.get_node("%DetailHost").visible).is_true()
	var detail_text: String = _PanelText(shell.get_node("%DetailHost"))
	assert_str(detail_text).contains(member.display_name)
	assert_str(detail_text).contains("普攻·常驻不占点")
	assert_str(detail_text).contains("技能点 3")
	# 花点解锁：战士第 2 技（第 1 技预解锁）——解锁后 2 点
	assert_str(detail_text).contains("未解锁")
	(runner.find_child("UnlockButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	assert_int(member.skill_ids.size()).is_equal(2)
	assert_int(member.skill_points).is_equal(2)
	# 倾向入口 → 升级面板（悬置 2 级提示）→ 选「狂战」（侧重力量）→ +2 补加
	##（选定即自动关闭——面板任务完成）
	(runner.find_child("ChooseTendencyButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	assert_bool(shell.get_node("%LevelupHost").visible).is_true()
	assert_str(_PanelText(shell.get_node("%LevelupHost"))).contains("悬置 2 级")
	(shell.find_children("TendencyOptionButton", "Button", true, false)[0] as Button).pressed.emit()
	await _WaitFrames(1)
	assert_int(int(member.attrs[AttrKeys.STRENGTH])).is_equal(strength_before + 2)
	assert_bool(core.pending_tendency_levels.has(String(member.unit_id))).is_false()
	assert_str(String(member.tendency_id)).is_equal("tend_warrior_a")
	# 选定即自动关闭（总览经 member_changed 刷新）
	assert_bool(shell.get_node("%LevelupHost").visible).is_false()

func _PanelText(host: Node) -> String:
	## 弹层内全部 Label 文本拼接（断言助手）
	## 参数 host：弹层宿主
	## 返回：拼接文本
	var parts: PackedStringArray = []
	for label: Label in host.find_children("*", "Label", true, false):
		parts.append(label.text)
	return "\n".join(parts)

func test_organize_three_previews() -> void:
	## 编队三预览（批 3 + Z2-4）：检定预览（推荐属性+短板△）/超额预览（勾选
	## 联动倍率与预计奖励；**超上限警示非金色**）/沿用上次编队一键
	_NewGame()
	var core: GuildCore = _Core()
	core.board.board.clear()
	core.board.spawn_on_board(&"q_vein_survey", core.day)
	var assoc: GdUnitSceneRunner = scene_runner(ASSOC_SCENE)
	(assoc.scene() as Control).RefreshAll()
	await _WaitFrames(1)
	(assoc.find_child("AcceptButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	var screen: Control = assoc.scene() as Control
	var panel: OrganizePanel = screen._organize_panel
	# 检定预览：推荐属性汇总（q_vein_survey 推荐智力/感知）+ 超额预览行就位
	var preview_text: String = _PreviewText(panel)
	assert_str(preview_text).contains("检定预览")
	assert_str(preview_text).contains("智力")
	assert_str(preview_text).contains("超额预览")
	# 超额预览勾选联动：q_vein_survey 2-4 人——选 4 人 → 超额 2 → ×1.30 → 195/104
	_CheckFirstN(panel, 4)
	var preview: String = _PreviewText(panel)
	assert_str(preview).contains("已选 4 人（超额 2）")
	assert_str(preview).contains("195 金 / 104 经验")
	_CheckFirstN(panel, 2)
	preview = _PreviewText(panel)
	assert_str(preview).contains("已选 2 人（超额 0）")
	assert_str(preview).contains("150 金 / 80 经验")
	# Z2-4：超上限警示（非金色诱导）——招募 1 人至 5 名册后重开弹层勾满 5
	##（5 > 上限 4 → 警示文案，无法确认）
	assert_object(_GuildState().recruit(0)).is_not_null()
	assert_int(core.roster.size()).is_equal(5)
	panel.cancelled.emit()
	await _WaitFrames(1)
	(assoc.find_child("AcceptButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	_CheckFirstN(panel, 5)
	assert_str(_PreviewText(panel)).contains("超出上限 4，无法确认")
	# 回到合法 3 人确认 → 沿用上次编队：重编队入口清选 1 人 → 一键恢复该 3 人
	_CheckFirstN(panel, 3)
	(assoc.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	var quest: QuestInstance = core.board.accepted[0]
	assert_int(quest.party_ids.size()).is_equal(3)
	(screen.find_children("ReassignButton", "Button", true, false)[0] as Button).pressed.emit()
	await _WaitFrames(1)
	for check: CheckBox in panel._checks.values():
		check.button_pressed = false
	_CheckFirstN(panel, 1)
	(assoc.find_child("UseLastPartyButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	assert_str(_PreviewText(panel)).contains("已选 3 人")

func test_tendency_queue_multi_member_flow() -> void:
	## Z2-3：悬置倾向链路——两名成员悬置 → 公会壳「待选倾向」直入入口（人数
	## 后缀）→ 行标记「待选倾向」→ 队列面板选一人**不关面板续选** → 全部
	## 选完自动关闭；pending 清空后直入入口隐藏
	_NewGame()
	var core: GuildCore = _Core()
	var cfg: CoreConfig = get_tree().root.get_node("GameData").get_record(
			CoreConfig.CFG_MAIN_ID) as CoreConfig
	GrowthCore.apply_exp(core.roster[0], 150, cfg, core.game_data,
			core.pending_tendency_levels)
	GrowthCore.apply_exp(core.roster[1], 150, cfg, core.game_data,
			core.pending_tendency_levels)
	assert_int(core.pending_tendency_levels.size()).is_equal(2)
	var runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	await _WaitFrames(2)
	var shell: Control = runner.scene() as Control
	var pending_button: Button = shell.get_node("%PendingButton") as Button
	assert_bool(pending_button.visible).is_true()
	assert_str(pending_button.text).contains("2")
	assert_str((shell._roster_overview._row_buttons[0] as Button).text).contains("待选倾向")
	# 直入入口 → 队列面板（两名成员区块齐列）
	pending_button.pressed.emit()
	await _WaitFrames(1)
	assert_bool(shell.get_node("%LevelupHost").visible).is_true()
	var queue_text: String = _PanelText(shell.get_node("%LevelupHost"))
	assert_str(queue_text).contains(core.roster[0].display_name)
	assert_str(queue_text).contains(core.roster[1].display_name)
	# 选第一人（首区块首选项）——面板不关（队列仍有未选成员）
	var option_buttons: Array = shell.find_children("TendencyOptionButton", "Button", true, false)
	(option_buttons[0] as Button).pressed.emit()
	await _WaitFrames(1)
	assert_bool(shell.get_node("%LevelupHost").visible).is_true()
	assert_int(core.pending_tendency_levels.size()).is_equal(1)
	# 选第二人——全部选完自动关闭 + 直入入口隐藏
	option_buttons = shell.find_children("TendencyOptionButton", "Button", true, false)
	(option_buttons[0] as Button).pressed.emit()
	await _WaitFrames(1)
	assert_bool(shell.get_node("%LevelupHost").visible).is_false()
	assert_int(core.pending_tendency_levels.size()).is_equal(0)
	assert_bool((shell.get_node("%PendingButton") as Button).visible).is_false()

func _PreviewText(panel: OrganizePanel) -> String:
	## 编队弹层预览行文本（检定+超额两行拼接——断言助手）
	## 参数 panel：编队弹层
	## 返回：拼接文本
	var parts: PackedStringArray = []
	for label: Label in panel.find_children("*", "Label", true, false):
		parts.append(label.text)
	return "\n".join(parts)

func test_new_grants_badge_on_association_entry() -> void:
	## 新挂单角标（M4-1 修复口径——**生产顺序**）：回城结算（此刻公会壳未挂树/
	## 已销毁——状态走核心层标志）→ 回城挂新公会壳 → 角标可见；进协会即清、
	## 挂单在册；标志随公会快照持久（模拟关游戏→继续后角标仍在）
	_NewGame()
	var run := ExpeditionRun.new()
	run.base_days = 1
	run.granted_quests.append(&"q_lost_miner_keepsake")
	_GuildState().settle_expedition(run, GuildCore.ExpeditionOutcome.SUCCESS)
	# 结算时无任何公会壳监听——标志落在核心层
	assert_bool(_Core().has_unseen_grants).is_true()
	# 回城 → 新公会壳 _ready 读标志渲染角标
	var runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	await _WaitFrames(2)
	var shell: Control = runner.scene() as Control
	assert_str((shell.get_node("%AssociationButton") as Button).text).contains("新挂单")
	# 标志随快照持久：模拟关游戏→继续（新会话 restore）
	var saved_day: int = _Core().day
	get_tree().root.get_node("SaveManager").current = null
	_GuildState().core = GuildCore.new()
	get_tree().root.get_node("SaveManager").load_game()
	assert_bool(_Core().has_unseen_grants).is_true()
	assert_int(_Core().day).is_equal(saved_day)
	# 进协会：标志清除 + 授予委托在挂单册
	(shell.get_node("%AssociationButton") as Button).pressed.emit()
	await _WaitFrames(2)
	assert_bool(_Core().has_unseen_grants).is_false()
	assert_str(_Core().board.find_accepted_by_template(&"q_lost_miner_keepsake") \
			.display_name(get_tree().root.get_node("GameData"))).is_equal("没能回家的托米")

func test_popup_panels_layout_contract_1080p() -> void:
	## 弹层布局契约（批 3——W3-01 口径）：详情/升级/编队三弹层 1080p 不溢出
	_NewGame()
	var shell_runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	var shell: Control = shell_runner.scene() as Control
	shell.get_window().size = Vector2i(1920, 1080)
	await _WaitFrames(2)
	var viewport: Vector2 = shell.get_viewport_rect().size
	# 详情弹层
	(shell.find_children("MemberRow", "Button", true, false)[0] as Button).pressed.emit()
	await _WaitFrames(1)
	_AssertWithinViewport(shell.get_node("%DetailHost"), viewport, "member_detail")
	(shell_runner.find_child("ChooseTendencyButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	_AssertWithinViewport(shell.get_node("%LevelupHost"), viewport, "levelup_panel")
	# 编队弹层（协会屏）
	_Core().board.board.clear()
	_Core().board.spawn_on_board(&"q_lair_purge", _Core().day)
	var assoc_runner: GdUnitSceneRunner = scene_runner(ASSOC_SCENE)
	var assoc_screen: Control = assoc_runner.scene() as Control
	assoc_screen.get_window().size = Vector2i(1920, 1080)
	assoc_screen.RefreshAll()
	await _WaitFrames(2)
	(assoc_runner.find_child("AcceptButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	_AssertWithinViewport(assoc_screen.get_node("%OrganizeHost"),
			assoc_screen.get_viewport_rect().size, "organize_panel")

func _AssertWithinViewport(host: Control, viewport: Vector2, label: String) -> void:
	## 弹层宿主全局矩形界内断言助手
	## 参数 host：弹层宿主；viewport：视口尺寸；label：失败文案标签
	## 返回：无
	var rect: Rect2 = host.get_global_rect()
	assert_bool(rect.end.y <= viewport.y + 2.0 and rect.end.x <= viewport.x + 2.0
			and rect.position.y >= -2.0 and rect.position.x >= -2.0) \
			.override_failure_message("%s 弹层溢出视口：%s" % [label, str(rect)]).is_true()

func test_guild_screens_layout_contract_1080p() -> void:
	## W3-01 口径：四新屏 1920×1080 窗口不溢出（普通容器+手动布局——
	## 关键分区 global 矩形下缘 ≤ 视口高、右缘 ≤ 视口宽）。
	## 断言口径（修复批次 5 环境适配）：stretch canvas_items/expand 下视口画布
	## =窗口÷缩放系数（基准 1440×900 时 1080p 窗画布=1600×900，绝对值随基准
	## 配置漂移）——改锁窗口实值+画布宽高比+根矩形铺满画布；历史失败模式
	## （headless 无真窗默认 1920×1922=设窗被绕过）由窗口实值断言捕获
	_NewGame()
	for scene_path: String in [GUILD_SCENE, ASSOC_SCENE, DORM_SCENE, TRAIN_SCENE]:
		var runner: GdUnitSceneRunner = scene_runner(scene_path)
		var screen: Control = runner.scene() as Control
		screen.get_window().size = Vector2i(1920, 1080)
		await _WaitFrames(2)
		# 设窗生效断言（锁窗口实值——设窗被绕过时此断言失败）
		assert_int(screen.get_window().size.x).is_equal(1920)
		assert_int(screen.get_window().size.y).is_equal(1080)
		var viewport: Vector2 = screen.get_viewport_rect().size
		# 画布宽高比 = 窗口宽高比（expand 铺满无黑边；1920×1922 类假窗 1:1 可捕获）
		assert_float(viewport.x / viewport.y).is_equal_approx(1920.0 / 1080.0, 0.01)
		# 全屏根：铺满画布（四角锚定生效）
		var root_rect: Rect2 = screen.get_global_rect()
		assert_float(root_rect.size.y).is_equal_approx(viewport.y, 2.0)
		assert_float(root_rect.size.x).is_equal_approx(viewport.x, 2.0)
		# 关键分区不溢出（逐屏具名分区——find_child 按节点名，含 unique 名）
		var probe_names: Array[String] = []
		match scene_path:
			GUILD_SCENE:
				probe_names = ["RosterPanel", "SideBox"]
			ASSOC_SCENE:
				probe_names = ["BoardHost", "AcceptedHost", "RecruitHost"]
			_:
				probe_names = ["UpgradeButton"]
		for probe_name: String in probe_names:
			var probe: Control = screen.find_child(probe_name, true, false) as Control
			assert_object(probe).is_not_null()
			var rect: Rect2 = probe.get_global_rect()
			assert_bool(rect.end.y <= viewport.y + 2.0 and rect.end.x <= viewport.x + 2.0 \
					and rect.position.y >= -2.0 and rect.position.x >= -2.0) \
					.override_failure_message("%s 分区溢出视口：%s" % [
							scene_path.get_file(), str(rect)]).is_true()
		await _WaitFrames(1)

func test_light_quest_full_chain() -> void:
	## M4 增补批：轻度全链——接卡（轻度信息行）→弹层（1-2 人+开工文案）→
	## 开工（LIGHT_RUNNING+占用）→等待推进（工期递减）→汇总行文案含板凳
	## 后缀（拍板①）→实例移除释放
	_NewGame()
	var core: GuildCore = _Core()
	core.board.board.clear()
	core.board.spawn_on_board(&"q_chore_supply_run", core.day)
	var assoc: GdUnitSceneRunner = scene_runner(ASSOC_SCENE)
	(assoc.scene() as Control).RefreshAll()
	await _WaitFrames(1)
	# 委托卡轻度分支：标题「轻度·」前缀+工期信息行
	var card: QuestCard = (assoc.scene() as Control)._board_panel._cards[0]
	assert_object(card).is_not_null()
	assert_str(card._title_label.text).contains("轻度·")
	assert_str(card._info_label.text).contains("工期 2 天")
	# 弹层：选 1 人确认——按钮文案「派出开工」
	(assoc.find_child("AcceptButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	var screen: Control = assoc.scene() as Control
	var checks: Array = screen._organize_panel._checks.values()
	(checks[0] as CheckBox).button_pressed = true
	assert_str((assoc.find_child("ConfirmButton", true, false) as Button).text).is_equal("派出开工")
	(assoc.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	# 开工就位：LIGHT_RUNNING+work_days_left+占用+开工提示行
	assert_int(core.board.accepted.size()).is_equal(1)
	var inst: QuestInstance = core.board.accepted[0]
	assert_int(inst.state).is_equal(QuestInstance.State.LIGHT_RUNNING)
	assert_int(inst.work_days_left).is_equal(2)
	assert_int(core.board.occupied_member_ids().size()).is_equal(1)
	assert_str((screen.get_node("%HintLabel") as Label).text).contains("工期 2 天")
	# --- 等待推进：day+1 工期 1；day+2 归零结算（板凳 3 人各 9 经验后缀）---
	var shell: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	(shell.scene() as Control).RefreshAll()
	await _WaitFrames(1)
	(shell.find_child("WaitButton", true, false) as Button).pressed.emit()
	await _WaitFrames(2)
	assert_int(inst.work_days_left).is_equal(1)
	(shell.find_child("WaitButton", true, false) as Button).pressed.emit()
	await _WaitFrames(2)
	assert_int(core.board.accepted.size()).is_equal(0)
	assert_int(core.board.occupied_member_ids().size()).is_equal(0)
	# 汇总轻提示行：轻度完成条目+板凳后缀（3 人各 9——拍板①）
	var info: Label = (shell.scene() as Control).get_node("%SettleInfoLabel") as Label
	assert_str(info.text).contains("轻度委托完成")
	assert_str(info.text).contains("+60 金")
	assert_str(info.text).contains("板凳 3 人各得 9 经验")
