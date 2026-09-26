## EventPanel 面板单元测试（M2 质检修复批）
## 覆盖：D20 演出期输入门禁（E3-03——演出起禁用、呈结果止恢复、busy 期
## 点选拦截不发射）、空改派名单提示+取消路径（E3-13）、B 出口战前演出
## 视图（E3-06——「进入战斗」钮发信）、clear 清面板（E3-15）。
extends GdUnitTestSuite

## cfg 路径
const CFG_PATH: String = "res://data/core/cfg_main.tres"

func _MakeCfg(roll_seconds: float) -> CoreConfig:
	## 装配测试 cfg（duplicate 隔离——不污染共享缓存资源）
	## 参数 roll_seconds：D20 演出时长（秒）
	## 返回：CoreConfig 副本
	var cfg: CoreConfig = (load(CFG_PATH) as CoreConfig).duplicate() as CoreConfig
	cfg.ui_d20_roll_seconds = roll_seconds
	return cfg

func _MakeView() -> EventRunner.EventView:
	## 构造检定选项视图（体质·容易单选项）
	## 参数：无
	## 返回：EventView
	var view := EventRunner.EventView.new()
	view.narrative = "叙述文本。"
	view.options.append({
		&"id": &"opt_test_1",
		&"text": "检定选项甲",
		&"attr_label": "constitution",
		&"tier_label": "容易",
		&"tier_line": 8,
		&"cost_days": 0,
	})
	return view

func test_d20_roll_gates_input() -> void:
	## E3-03：演出起禁用全部交互钮、呈结果止恢复——无双结算窗口
	var cfg: CoreConfig = _MakeCfg(0.15)
	var panel := EventPanel.new()
	panel.setup(cfg)
	add_child(panel)
	auto_free(panel)
	panel.show_view(_MakeView())
	var option_button: Button = panel._options_box.get_child(0) as Button
	assert_bool(option_button.disabled).is_false()
	# 协程启动（不 await——同帧断言门禁即时生效）
	panel.play_d20_roll()
	assert_bool(panel._busy).is_true()
	assert_bool(option_button.disabled).is_true()
	assert_bool(panel._continue_button.disabled).is_true()
	await get_tree().create_timer(0.4).timeout
	assert_bool(panel._busy).is_false()
	assert_bool(option_button.disabled).is_false()

func test_d20_busy_blocks_pick_signal() -> void:
	## E3-03：busy 期改派点选拦截——option_chosen 不发射
	var cfg: CoreConfig = _MakeCfg(0.05)
	var panel := EventPanel.new()
	panel.setup(cfg)
	add_child(panel)
	auto_free(panel)
	var emitted: Array = []
	panel.option_chosen.connect(
			func(_option_id: StringName, _actor: AdventurerData) -> void: emitted.append(1))
	panel._busy = true
	panel._OnCastPicked(null)
	panel._OnOptionPressed(&"opt_test_1", {&"attr_label": "constitution"})
	assert_int(emitted.size()).override_failure_message("busy 期点选必须拦截").is_equal(0)
	panel._busy = false
	panel._OnOptionPressed(&"opt_test_1", {&"attr_label": "constitution"})
	assert_int(emitted.size()).is_equal(0)
	panel._OnOptionPressed(&"opt_test_1", {&"attr_label": ""})
	assert_int(emitted.size()).is_equal(1)

func test_empty_cast_hint_and_cancel() -> void:
	## E3-13：空改派名单（全员倒地）——提示文本 + 返回钮恢复选项视图
	var cfg: CoreConfig = _MakeCfg(0.05)
	var panel := EventPanel.new()
	panel.setup(cfg)
	panel.set_cast_provider(func(_attr_id: StringName) -> Array: return [])
	add_child(panel)
	auto_free(panel)
	panel.show_view(_MakeView())
	(panel._options_box.get_child(0) as Button).pressed.emit()
	await get_tree().process_frame
	assert_bool(panel._cast_box.visible).is_true()
	var hint: Label = panel._cast_box.get_child(0) as Label
	assert_str(hint.text).is_equal(EventPanel.NO_CAST_TEXT)
	# 取消路径：返回钮恢复选项视图
	var cancel: Button = panel._cast_box.get_child(1) as Button
	assert_str(cancel.text).is_equal("返回")
	cancel.pressed.emit()
	await get_tree().process_frame
	assert_bool(panel._options_box.visible).is_true()
	assert_int(panel._options_box.get_child_count()).is_equal(1)

func test_settled_roll_detail_line() -> void:
	## ②掷骰明细行（2026-09-25 试玩反馈）：show_settled / show_battle_intro
	## 传入 roll_text 时置首行呈现（「掷出 N ＋ M ＝ T（档 线）」）；
	## 默认不传（M2 既有调用）零变化无明细行
	var cfg: CoreConfig = _MakeCfg(0.05)
	var panel := EventPanel.new()
	panel.setup(cfg)
	add_child(panel)
	auto_free(panel)
	panel.show_settled(CheckResult.Grade.SUCCESS, "结算文本。", "+10 金",
			"掷出 14 ＋ 2 ＝ 16（容易 8）")
	assert_bool(panel._result_label.text.begins_with("掷出 14 ＋ 2 ＝ 16（容易 8）")) \
			.override_failure_message("明细行应置首行").is_true()
	assert_str(panel._result_label.text).contains("结算文本。")
	assert_str(panel._result_label.text).contains("+10 金")
	# 默认参数（M2 既有调用零变化——无明细行）
	panel.show_settled(CheckResult.Grade.SUCCESS, "二次结算。", "")
	assert_bool(panel._result_label.text.begins_with("二次结算")) \
			.override_failure_message("不传 roll_text 不应有明细行").is_true()
	# B 出口战前演出视图同带明细行（战前经检定进入时难度与骰面可见）
	var view := EventRunner.EventView.new()
	view.narrative = "战前叙述。"
	view.check_grade = CheckResult.Grade.CRIT_FAILURE
	panel.show_battle_intro(view, "-5 HP", "掷出 1 ＋ 0 ＝ 1（极难 17）")
	assert_bool(panel._result_label.text.begins_with("掷出 1 ＋ 0 ＝ 1（极难 17）")) \
			.is_true()
	assert_str(panel._result_label.text).contains("战前叙述")
	assert_str(panel._result_label.text).contains("-5 HP")

func test_battle_intro_shows_confirm_button() -> void:
	## E3-06：B 出口战前演出视图——「进入战斗」钮 + 四档反馈呈现 + 发信
	var cfg: CoreConfig = _MakeCfg(0.05)
	var panel := EventPanel.new()
	panel.setup(cfg)
	add_child(panel)
	auto_free(panel)
	var view := EventRunner.EventView.new()
	view.narrative = "战前叙述。"
	view.check_grade = CheckResult.Grade.CRIT_FAILURE
	view.hp_delta = -5
	panel.show_battle_intro(view, "-5 HP")
	assert_bool(panel._battle_button.visible).is_true()
	assert_str(panel._result_label.text).contains("战前叙述")
	assert_str(panel._grade_label.text).contains("大失败")
	assert_str(panel._result_label.text).contains("-5 HP")
	var fired: Array = []
	panel.battle_pressed.connect(func() -> void: fired.append(1))
	panel._battle_button.pressed.emit()
	assert_int(fired.size()).is_equal(1)
	# clear 清面板（E3-15）
	panel.clear()
	assert_bool(panel._battle_button.visible).is_false()
	assert_str(panel._result_label.text).is_empty()

func test_w303_panel_area_is_skip_hotzone_during_roll() -> void:
	## W3-03（2026-09-26 拍板 a）：D20 演出期面板置 STOP——面板区点按即跳过
	## （_gui_input 路由 skip_d20；修复前板面 STOP 吞掉面板区域点击、宿主根
	## gui_input 的跳过链不可达）；演出结束恢复 IGNORE（常态不挡板面输入）
	var cfg: CoreConfig = _MakeCfg(0.4)
	var panel := EventPanel.new()
	panel.setup(cfg)
	add_child(panel)
	auto_free(panel)
	assert_int(panel.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	# 协程启动（不 await——同帧断言热区即时生效）
	panel.play_d20_roll()
	assert_bool(panel._busy).is_true()
	assert_int(panel.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	# 面板内点按 → 跳过置位 → 演出协程提前退出（0.4s 时长远超等待窗）
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(10, 10)
	panel._gui_input(event)
	assert_bool(panel._d20_skip).is_true()
	await get_tree().create_timer(0.1).timeout
	assert_bool(panel._busy).is_false()
	assert_int(panel.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
