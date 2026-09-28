## 日结算汇总弹窗 UI 契约测试（M5 批 2）
## 覆盖：DaySummaryPanel 骨架契约（结构/z_index/深底/字号档位/WORD_SMART
## autowrap/限宽）、open 明细行与无事占位、关闭钮信号链、BuildDetailLines
## 全分组/空分组、文案表防双源（弹窗表 vs explore_screen 表 vs guild_shell
## 轻提示行同值）、explore 结算正文「外出期间汇总」段（有事出行/无事与
## 空数组不出行）、guild_shell 等待一天→弹窗开合+1080p 布局（W3-01 真实
## 视口口径——显式设窗）。
extends GdUnitTestSuite

## GameData 脚本路径（组件级用例局部实例）
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## explore_screen 场景路径（正文段用例直构——不进树只调纯拼装口）
const EXPLORE_SCENE: String = "res://scenes/explore/explore_screen.tscn"
## guild_shell 场景路径（集成布局用例）
const GUILD_SCENE: String = "res://scenes/guild/guild_shell.tscn"
## explore_screen 脚本常量引用（UI_TEXTS 防双源断言）
const ExploreScript: GDScript = preload("res://scripts/scene_flow/explore_screen.gd")
## guild_shell 脚本常量引用（轻提示行同值语义断言）
const GuildShellScript: GDScript = preload("res://scripts/scene_flow/guild_shell.gd")

## 套件级 GameData
var _game_data: Node

func before_test() -> void:
	## 用例级前置：GameData 实例 + 真 autoload 复位 + 清存档目录
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()
	_CleanSaveDir()
	var root: Node = get_tree().root
	var scene_manager: Node = root.get_node_or_null("SceneManager")
	if scene_manager != null:
		scene_manager.current_id = -1
		scene_manager.previous_id = -1
		var no_params: Dictionary = {}
		scene_manager.pending_params = no_params
	var save_manager: Node = root.get_node_or_null("SaveManager")
	if save_manager != null:
		save_manager.current = null
		save_manager.set_expedition_lock(false)
	var guild_state: Node = root.get_node_or_null("GuildState")
	if guild_state != null:
		guild_state.core = GuildCore.new()

func after_test() -> void:
	## 用例级后置：释放 GameData + 清存档目录 + 真 autoload 锁复位
	_game_data.free()
	_CleanSaveDir()
	var save_manager: Node = get_tree().root.get_node_or_null("SaveManager")
	if save_manager != null:
		save_manager.set_expedition_lock(false)

func _Cfg() -> CoreConfig:
	## 总控配置读取口
	return _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig

func _CleanSaveDir() -> void:
	## 清理 user://saves 全部文件
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

func _MakePanel() -> DaySummaryPanel:
	## 装配弹窗组件（add_child+auto_free——find_child 需在树内）
	var panel := DaySummaryPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.setup(_Cfg())
	return panel

func _MakeLightResult(template_id: StringName) -> GuildCore.LightQuestResult:
	## 轻度完成条目构造（含板凳后缀数据）
	var result := GuildCore.LightQuestResult.new()
	result.template_id = template_id
	result.display_name = "轻度·%s" % String(template_id)
	result.gold = 60
	result.exp = 30
	result.reputation = 1
	result.bench_member_count = 3
	result.bench_exp_per_member = 9
	return result

func test_panel_skeleton_contract() -> void:
	## 骨架契约：PanelContainer+VBox（标题/正文/关闭钮三节点）、z=100 置顶、
	## 初始隐藏、深底 stylebox、字号档位=cfg 表值、正文 WORD_SMART+限宽
	var panel: DaySummaryPanel = _MakePanel()
	assert_bool(panel.visible).is_false()
	assert_int(panel.z_index).is_equal(100)
	assert_object(panel.get_theme_stylebox("panel")).is_not_null()
	var title: Label = panel.find_child("TitleLabel", true, false) as Label
	var body: Label = panel.find_child("BodyLabel", true, false) as Label
	var close_button: Button = panel.find_child("CloseSummaryButton", true, false) as Button
	assert_object(title).is_not_null()
	assert_object(body).is_not_null()
	assert_object(close_button).is_not_null()
	assert_str(close_button.text).is_equal("关闭")
	# 字号档位（tscn 无内嵌——setup 覆写即终值，与 cfg 表值一致）
	var cfg: CoreConfig = _Cfg()
	assert_int(title.get_theme_font_size("font_size")).is_equal(
			UiTheme.font_of(cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	assert_int(body.get_theme_font_size("font_size")).is_equal(
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	assert_int(close_button.get_theme_font_size("font_size")).is_equal(
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	# 正文智能换行（M5 批 2 实测枚举值=3）+ 限宽（autowrap 生效前提）
	assert_int(body.autowrap_mode).is_equal(TextServer.AUTOWRAP_WORD_SMART)
	assert_int(int(body.custom_minimum_size.x)).is_greater_equal(640)

func test_open_builds_title_and_detail_lines() -> void:
	## open：单组有事 DaySummary → 标题「第 N 天·结算汇总」+ 正文含全部
	## 在场分组行（恢复/周刷新/挂单失败/新候选/轻度含板凳后缀）
	var panel: DaySummaryPanel = _MakePanel()
	var summary := GuildCore.DaySummary.new()
	summary.day = 5
	summary.recovered_ids = [&"adv_erin"]
	summary.week_refreshed = true
	summary.accepted_failed = ["q_north_survey", "q_vein_survey"]
	summary.new_candidate_names = ["甲", "乙"]
	summary.light_completed = [_MakeLightResult(&"q_chore_supply_run")]
	panel.open([summary])
	assert_bool(panel.visible).is_true()
	assert_str((panel.find_child("TitleLabel", true, false) as Label).text) \
			.is_equal("第 5 天·结算汇总")
	var body_text: String = (panel.find_child("BodyLabel", true, false) as Label).text
	assert_str(body_text).contains("恢复 1 人")
	assert_str(body_text).contains("委托板周刷新")
	assert_str(body_text).contains("挂单到期失败 2 单")
	assert_str(body_text).contains("新候选：甲、乙")
	assert_str(body_text).contains("轻度·q_chore_supply_run +60 金 +30 经验 +1 声望")
	assert_str(body_text).contains("（板凳 3 人各得 9 经验）")

func test_open_quiet_day_shows_placeholder() -> void:
	## open：无事 DaySummary → 正文=「无事发生。」占位（不出空行）
	var panel: DaySummaryPanel = _MakePanel()
	var summary := GuildCore.DaySummary.new()
	summary.day = 2
	panel.open([summary])
	assert_str((panel.find_child("BodyLabel", true, false) as Label).text).is_equal("无事发生。")
	# 多组皆无事（跨日补结算无事件）同为占位
	panel.open([summary, summary])
	assert_str((panel.find_child("BodyLabel", true, false) as Label).text).is_equal("无事发生。")

func test_close_button_emits_closed_and_close_hides() -> void:
	## 关闭钮 → closed 信号；close() → 隐藏（宿主隐藏链由 guild_shell 消费）
	var panel: DaySummaryPanel = _MakePanel()
	var summary := GuildCore.DaySummary.new()
	summary.day = 2
	panel.open([summary])
	assert_bool(panel.visible).is_true()
	var closed_count: Array[int] = [0]
	panel.closed.connect(func() -> void: closed_count[0] += 1)
	(panel.find_child("CloseSummaryButton", true, false) as Button).pressed.emit()
	assert_int(closed_count[0]).is_equal(1)
	panel.close()
	assert_bool(panel.visible).is_false()

func test_build_detail_lines_full_groups() -> void:
	## BuildDetailLines 静态：全分组行齐备（恢复/周刷新/三表现依序/挂单失败/
	## 新候选/轻度含后缀）——顺序=行序
	var agg := GuildCore.DaySummary.new()
	agg.day = 6
	agg.recovered_ids = [&"adv_erin", &"adv_iron_peak"]
	agg.week_refreshed = true
	agg.board_removed = ["q_a"]
	agg.board_refreshed = ["q_b"]
	agg.board_replaced = ["q_c"]
	agg.accepted_failed = ["q_d"]
	agg.new_candidate_names = ["甲"]
	agg.light_completed = [_MakeLightResult(&"q_chore_tavern_help")]
	var lines: PackedStringArray = DaySummaryPanel.BuildDetailLines(
			agg, DaySummaryPanel.UI_TEXTS)
	assert_int(lines.size()).is_equal(8)
	assert_str(lines[0]).is_equal("恢复 2 人")
	assert_str(lines[1]).is_equal("委托板周刷新")
	assert_str(lines[2]).is_equal("板上到期 1 单")
	assert_str(lines[3]).is_equal("刷新补位 1 单")
	assert_str(lines[4]).is_equal("替换加急 1 单")
	assert_str(lines[5]).is_equal("挂单到期失败 1 单")
	assert_str(lines[6]).is_equal("新候选：甲")
	assert_bool(lines[7].contains("板凳 3 人各得 9 经验")).is_true()

func test_build_detail_lines_empty_returns_empty() -> void:
	## BuildDetailLines 静态：全空聚合 → 空数组（调用方判空不出行/不冗余）
	var agg := GuildCore.DaySummary.new()
	agg.day = 2
	var lines: PackedStringArray = DaySummaryPanel.BuildDetailLines(
			agg, DaySummaryPanel.UI_TEXTS)
	assert_int(lines.size()).is_equal(0)

func test_text_tables_same_semantics_no_drift() -> void:
	## 文案表防双源：弹窗 UI_TEXTS 与 explore_screen UI_TEXTS 的 summary_*
	## 分组键集同键同值；与 guild_shell 轻提示行共有的分组键同值
	##（「同值语义、独立常量表」拍板口径的契约化）
	var panel_keys: Array[String] = [
			"summary_recovered_format", "summary_week_refresh",
			"summary_board_removed_format", "summary_board_refreshed_format",
			"summary_board_replaced_format", "summary_accepted_failed_format",
			"summary_candidates_format", "summary_light_done_format",
			"summary_light_done_bench_suffix",
	]
	var explore_texts: Dictionary = ExploreScript.UI_TEXTS
	for key: String in panel_keys:
		assert_str(String(DaySummaryPanel.UI_TEXTS[key])).is_equal(
				String(explore_texts[key])) \
				.override_failure_message("explore 文案表分组键漂移：%s" % key)
	# guild_shell 轻提示行共有键（无 refreshed/replaced 两键——轻提示行不细分）
	var shell_texts: Dictionary = GuildShellScript.UI_TEXTS
	for key: String in ["summary_recovered_format", "summary_week_refresh",
			"summary_board_removed_format", "summary_accepted_failed_format",
			"summary_candidates_format", "summary_light_done_format",
			"summary_light_done_bench_suffix"]:
		assert_str(String(DaySummaryPanel.UI_TEXTS[key])).is_equal(
				String(shell_texts[key])) \
				.override_failure_message("guild_shell 轻提示行文案键漂移：%s" % key)

func test_explore_body_appends_period_summary() -> void:
	## explore 结算正文「外出期间汇总」段（拍板②并入正文）：成功/失败正文各
	## 追加一行（settle_days 之后、save_failed 之前）；无事或空数组不出行
	##（单日且无事维持现状防冗余）
	var screen: Control = (load(EXPLORE_SCENE) as PackedScene).instantiate()
	auto_free(screen)
	screen._game_data = _game_data
	var summary := GuildCore.ExpeditionSummary.new()
	summary.days_settled = 3
	var day2 := GuildCore.DaySummary.new()
	day2.day = 2
	var day3 := GuildCore.DaySummary.new()
	day3.day = 3
	day3.accepted_failed = ["q_north_survey"]
	var day4 := GuildCore.DaySummary.new()
	day4.day = 4
	day4.new_candidate_names = ["甲"]
	summary.day_summaries = [day2, day3, day4]
	var success_body: String = screen._BuildSuccessBody(summary)
	assert_str(success_body).contains("日历已推进 3 天")
	assert_str(success_body).contains("外出期间汇总：")
	assert_str(success_body).contains("挂单到期失败 1 单")
	assert_str(success_body).contains("新候选：甲")
	var failure_body: String = screen._BuildFailureBody(summary, "撤退回城")
	assert_str(failure_body).contains("外出期间汇总：")
	assert_str(failure_body).contains("挂单到期失败 1 单")
	# 无事单日：不出行（正文维持既有行集）
	var quiet := GuildCore.ExpeditionSummary.new()
	quiet.days_settled = 1
	var quiet_day := GuildCore.DaySummary.new()
	quiet_day.day = 2
	quiet.day_summaries = [quiet_day]
	assert_bool(screen._BuildSuccessBody(quiet).contains("外出期间汇总")).is_false()
	assert_bool(screen._BuildFailureBody(quiet, "").contains("外出期间汇总")).is_false()
	# 空数组（防御口径）：不出行
	var no_days := GuildCore.ExpeditionSummary.new()
	no_days.days_settled = 1
	no_days.day_summaries = []
	assert_bool(screen._BuildSuccessBody(no_days).contains("外出期间汇总")).is_false()

func test_wait_day_popup_open_and_layout_1080p() -> void:
	## guild_shell 集成链（W3-01 真实视口口径）：等待一天成功 → 弹窗开
	##（标题/明细行正确+宿主可见）→ 1080p 不溢出 → 关闭钮 → 宿主隐藏 +
	## 轻提示行仍持当日摘要（双保险）
	get_tree().root.get_node("GuildState").new_game()
	var core: GuildCore = get_tree().root.get_node("GuildState").core
	core.roster[0].status = AdventurerData.Status.RESTING
	core.roster[0].rest_days = 1
	var runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	var shell: Control = runner.scene() as Control
	shell.get_window().size = Vector2i(1920, 1080)
	await _WaitFrames(2)
	# 设窗生效断言（headless 假窗 1920×1922 可捕获）
	assert_int(shell.get_window().size.x).is_equal(1920)
	assert_int(shell.get_window().size.y).is_equal(1080)
	var host: Control = shell.get_node("%DaySummaryHost") as Control
	assert_bool(host.visible).is_false()
	(shell.get_node("%WaitButton") as Button).pressed.emit()
	await _WaitFrames(2)
	assert_bool(host.visible).is_true()
	var panel: DaySummaryPanel = host.get_child(0) as DaySummaryPanel
	assert_str((panel.find_child("TitleLabel", true, false) as Label).text) \
			.is_equal("第 2 天·结算汇总")
	assert_str((panel.find_child("BodyLabel", true, false) as Label).text).contains("恢复 1 人")
	# 弹窗矩形界内（真实视口）
	var viewport: Vector2 = shell.get_viewport_rect().size
	var rect: Rect2 = host.get_global_rect()
	assert_bool(rect.end.y <= viewport.y + 2.0 and rect.end.x <= viewport.x + 2.0
			and rect.position.y >= -2.0 and rect.position.x >= -2.0) \
			.override_failure_message("day_summary_panel 弹窗溢出视口：%s" % str(rect)) \
			.is_true()
	# 关闭钮 → 宿主隐藏 + 轻提示行双保险
	(panel.find_child("CloseSummaryButton", true, false) as Button).pressed.emit()
	await _WaitFrames(1)
	assert_bool(host.visible).is_false()
	assert_str((shell.get_node("%SettleInfoLabel") as Label).text) \
			.contains("恢复 1 人")

func _WaitFrames(frames: int) -> void:
	## 帧等待助手
	## 参数 frames：帧数
	## 返回：无（协程）
	for _i: int in frames:
		await get_tree().process_frame
