## 公会壳 UI 契约测试（修复批次 4 S4-M4-3-m；修复批次 5 补右栏布局顺序契约）
## 覆盖：三个弹层宿主（DetailHost/LevelupHost）全屏 CenterContainer + STOP
## 遮罩契约（准模态——对齐 explore test_explore_layering 的 PanelHost 先例）；
## 弹层初始隐藏；右栏 SideBox 子节点顺序（设施协会区块置顶——日志区殿后撑满）。
## 环境口径：gdUnit 帧内真 autoload（对齐集成套件惯例）。
extends GdUnitTestSuite

## 公会壳场景路径
const GUILD_SCENE: String = "res://scenes/guild/guild_shell.tscn"

func before_test() -> void:
	## 用例前置：复位 SceneManager 可变状态（autoload 归引擎管理不释放）
	## 参数：无
	## 返回：无
	var scene_manager: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_object(scene_manager).is_not_null()
	scene_manager.current_id = -1
	scene_manager.previous_id = -1
	var no_params: Dictionary = {}
	scene_manager.pending_params = no_params
	# S5-R3-01：复位切换重入锁（用例中断残留 _switch_pending=true 会连锁假失败）
	scene_manager._switch_pending = false
	for entry_name: String in ["main_save.json", "main_save.json.bak",
			"main_save.json.tmp"]:
		DirAccess.remove_absolute("user://saves/" + entry_name)
	var save_manager: Node = get_tree().root.get_node_or_null("SaveManager")
	if save_manager != null:
		save_manager.current = null
		save_manager.set_expedition_lock(false)
	var guild_state: Node = get_tree().root.get_node_or_null("GuildState")
	if guild_state != null:
		guild_state.core = GuildCore.new()

func _OpenGuildShell() -> Control:
	## 挂载公会壳（经 SceneManager——占 current_scene 位）
	## 参数：无
	## 返回：公会壳根节点
	assert_int(get_tree().root.get_node("SceneManager").go(1, {})).is_equal(OK)
	await get_tree().process_frame
	await get_tree().process_frame
	return get_tree().current_scene as Control

func test_popup_hosts_fullscreen_pass_mask_contract() -> void:
	## S4-M4-3-m：弹层宿主遮罩契约——DetailHost/LevelupHost 为全屏
	## CenterContainer 且 mouse_filter = STOP（PASS 容器遮罩：容器消费事件
	## 冒泡不穿透兄弟按钮——M4-2 审计降级准模态口径的布局前提）+ 初始隐藏
	var shell: Control = await _OpenGuildShell()
	assert_object(shell).is_not_null()
	for host_path: String in ["%DetailHost", "%LevelupHost"]:
		var host: Control = shell.get_node(host_path) as Control
		assert_object(host).is_not_null()
		assert_bool(host is CenterContainer).is_true()
		# 全屏伸展（anchors_preset 15——遮罩覆盖设计屏全域）
		assert_float(host.anchor_right).is_equal(1.0)
		assert_float(host.anchor_bottom).is_equal(1.0)
		# PASS 遮罩（mouse_filter = 1——M4-2 审计实测口径：PASS 容器消费事件
		# 冒泡父级不穿透兄弟按钮=安全准模态）
		assert_int(host.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS) \
				.override_failure_message("%s 遮罩应为 PASS（准模态前提）" % host_path)
		assert_bool(host.visible).is_false()

func test_side_box_layout_order_contract() -> void:
	## 修复批次 5（M4 试玩验收第 1 轮 UI 反馈）：右栏顺序契约——设施协会
	## 区块置顶（EntryTitle→宿舍→训练场→协会）→「等待一天」「待选倾向」→
	## SettleInfoLabel 殿后垂直撑满（日志区下移，空白不再堆积中段）
	var shell: Control = await _OpenGuildShell()
	assert_object(shell).is_not_null()
	var side_box: VBoxContainer = shell.get_node("%SideBox") as VBoxContainer
	assert_object(side_box).is_not_null()
	# VBox 子节点顺序 = 视觉上下序（逐节点断言 get_index）
	var expected_order: Array[String] = ["EntryTitle", "DormitoryButton", "TrainingButton",
			"AssociationButton", "WaitButton", "PendingButton", "SettleInfoLabel"]
	for index: int in expected_order.size():
		var child: Control = side_box.get_node("%" + expected_order[index]) as Control
		assert_object(child).is_not_null()
		assert_int(child.get_index()).is_equal(index) \
				.override_failure_message("SideBox 顺序违约：%s 应为第 %d 位" % [
						expected_order[index], index])
	# 设施区块标题位于「等待一天」上方（顺序→几何的落地校验）
	var entry_title: Control = shell.get_node("%EntryTitle") as Control
	var wait_button: Control = shell.get_node("%WaitButton") as Control
	assert_float(entry_title.get_global_rect().position.y).is_less(
			wait_button.get_global_rect().position.y)
	# 日志区殿后且垂直撑满剩余空间（expand+fill——占位而非留白在中段）
	var settle_label: Label = shell.get_node("%SettleInfoLabel") as Label
	assert_int(settle_label.size_flags_vertical).is_equal(Control.SIZE_EXPAND_FILL)

func test_retreat_confirm_dialogs_copy_contract() -> void:
	## S4-M4-3-m：两处 RetreatConfirm 文案契约——battle 版含「不会重伤」+
	## 「途中所得将丢弃」（P1/M-7 口径）、explore 版含「不会重伤」+「途中
	## 所得将丢弃」（S4-M4-3-b 对齐）；文案改措辞须同步本契约
	for scene_path: String in ["res://scenes/battle/battle_screen.tscn",
			"res://scenes/explore/explore_screen.tscn"]:
		var packed: PackedScene = load(scene_path) as PackedScene
		assert_object(packed).is_not_null()
		var root: Node = packed.instantiate()
		auto_free(root)
		var dialog: ConfirmationDialog = root.find_child("RetreatConfirm",
				true, false) as ConfirmationDialog
		assert_object(dialog).is_not_null()
		assert_str(dialog.dialog_text).contains("不会重伤")
		assert_str(dialog.dialog_text).contains("途中所得将丢弃")

func test_summarize_day_light_entries() -> void:
	## M4 增补批：_SummarizeDay 轻度条目拼装——完成行格式+板凳后缀（拍板①）
	## 多条顿号连接并入轻提示行（纯函数级——不经场景）
	var shell: Control = await _OpenGuildShell()
	var summary := GuildCore.DaySummary.new()
	var result := GuildCore.LightQuestResult.new()
	result.display_name = "轻度·补给跑腿"
	result.gold = 60
	result.exp = 30
	result.reputation = 1
	result.bench_member_count = 3
	result.bench_exp_per_member = 9
	summary.light_completed.append(result)
	var text: String = shell._SummarizeDay(summary)
	assert_str(text).contains("轻度委托完成：轻度·补给跑腿 +60 金 +30 经验 +1 声望")
	assert_str(text).contains("板凳 3 人各得 9 经验")
	# 无板凳：不出后缀
	var result2 := GuildCore.LightQuestResult.new()
	result2.display_name = "轻度·酒馆帮工"
	result2.gold = 69
	result2.exp = 35
	result2.reputation = 1
	var summary2 := GuildCore.DaySummary.new()
	summary2.light_completed.append(result2)
	assert_bool(shell._SummarizeDay(summary2).contains("板凳")).is_false()

func test_summarize_day_board_three_behaviors() -> void:
	## S4-02：轻提示行板刷三表现补齐——「板上到期/刷新补位/替换加急」三组
	## 均入行（此前双源拼装漏后两组）；单源 = DaySummaryPanel.BuildDetailLines
	var shell: Control = await _OpenGuildShell()
	var summary := GuildCore.DaySummary.new()
	summary.day = 7
	summary.board_removed.append("q_clean_mine")
	summary.board_refreshed.append("q_supply_run")
	summary.board_refreshed.append("q_hunt_rats")
	summary.board_replaced.append("q_escort")
	var text: String = shell._SummarizeDay(summary)
	assert_str(text).contains("板上到期 1 单")
	assert_str(text).contains("刷新补位 2 单")
	assert_str(text).contains("替换加急 1 单")
	assert_str(text).contains("第 7 天")

func test_wait_pressed_blocked_while_summary_popup_open() -> void:
	## S5-02：日结算汇总弹窗打开期间「等待一天」守卫——不再推一天/不再写
	## 存档/不再覆盖前日明细（关闭即解锁）
	var save_manager: Node = get_tree().root.get_node("SaveManager")
	var guild_state: Node = get_tree().root.get_node("GuildState")
	guild_state.new_game()
	assert_int(save_manager.current.game_day).is_equal(1)
	var shell: Control = await _OpenGuildShell()
	(shell.get_node("%DaySummaryHost") as Control).visible = true
	shell._on_wait_pressed()
	await get_tree().process_frame
	assert_int(guild_state.core.day).is_equal(1)
	assert_int(save_manager.current.game_day).is_equal(1)
	assert_int(save_manager.current.save_point).is_equal(SaveData.SavePoint.NEW_GAME)

func test_s4r205_autosave_warning_appends_not_overwrites() -> void:
	## S4-R2-05：autosave 失败警示经 RefreshAll 呈现时**拼接**当日摘要行
	##（不覆写——「弹窗关闭后轻提示行可查」契约）；恢复正常后剥离警示行
	var guild_state: Node = get_tree().root.get_node("GuildState")
	guild_state.new_game()
	var shell: Control = await _OpenGuildShell()
	(shell.get_node("%WaitButton") as Button).pressed.emit()
	await get_tree().process_frame
	shell._OnDaySummaryClosed()
	var label: Label = shell.get_node("%SettleInfoLabel") as Label
	assert_str(label.text).contains("第 2 天")
	# 失败警示：摘要保留 + 警示拼接（幂等——二次刷新不重复追加）
	guild_state.last_autosave_failed = true
	shell.RefreshAll()
	shell.RefreshAll()
	assert_str(label.text).contains("第 2 天")
	assert_str(label.text).contains("自动存档写入失败")
	assert_int(label.text.count("自动存档写入失败")).is_equal(1)
	# 恢复正常：警示行剥离、摘要保留
	guild_state.last_autosave_failed = false
	shell.RefreshAll()
	assert_str(label.text).contains("第 2 天")
	assert_bool(label.text.contains("自动存档写入失败")).is_false()
