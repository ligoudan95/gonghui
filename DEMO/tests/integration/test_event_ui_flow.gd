## 事件 UI 流集成测试（M2 批 3 + M2 质检修复批）
## 覆盖：event_screen 装配（菜单/汇总行/初始满血派生）、面板选项分流
## （纯选择直发/检定进改派）、改派默认高亮（属性差队伍真锁「最高调整值」
## +色值经 cfg 单源解耦常量耦合）、无检定单点立即结算、B 出口战前演出
## （先播再战）+ 场景往返参数（return_to/expedition_run/锚点回传链）、
## 战后续跑端到端（run 引用延续 + post_battle 入账 + HP 回写 + 出征锁连续）。
extends GdUnitTestSuite

## 场景路径
const GUILD_SCENE: String = "res://scenes/guild/guild_shell.tscn"
const EVENT_SCENE: String = "res://scenes/event/event_screen.tscn"
## cfg 路径（满血派生断言用）
const CFG_PATH: String = "res://data/core/cfg_main.tres"

func before_test() -> void:
	## 用例前置：复位 SceneManager 可变状态 + 出征锁
	## 参数：无
	## 返回：无
	var scene_manager: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_object(scene_manager).is_not_null()
	scene_manager.current_id = -1
	scene_manager.previous_id = -1
	var no_params: Dictionary = {}
	scene_manager.pending_params = no_params
	get_tree().root.get_node("SaveManager").set_expedition_lock(false)

func test_event_screen_assembles() -> void:
	## 装配：直开 event_screen → 菜单 6 入口 + 汇总行非空 + 出征锁生效 +
	## 初始满血（E2-7：DerivedStats.calc_hp 派生——勿硬编码）
	var runner: GdUnitSceneRunner = scene_runner(EVENT_SCENE)
	var screen: Control = runner.scene() as Control
	assert_object(screen).is_not_null()
	await get_tree().process_frame
	assert_int(screen.get_node("%MenuBox").get_child_count()).is_equal(6)
	assert_str(screen.get_node("%StatusLabel").text).contains("耗时 1 天")
	# 出征锁预演：演示会话期间生效
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_true()
	# 初始满血：四人 HP = 装配口径上限（体质 10 · 等级 1 · 职业系数 0 期）
	var cfg: CoreConfig = load(CFG_PATH) as CoreConfig
	var game_data: Node = get_tree().root.get_node("GameData")
	var expected_hp: int = DerivedStats.calc_hp(10,
			game_data.get_record(&"cls_warrior") as ClassDef, 1, cfg)
	for adv: AdventurerData in screen._run.party:
		assert_int(int(screen._run.hp[adv])).is_equal(expected_hp)

func test_single_no_check_event_settles_immediately() -> void:
	## 无检定单点（井边的旅人）：点击 → 立即结算视图（+10 经验入账 + 继续钮）
	var runner: GdUnitSceneRunner = scene_runner(EVENT_SCENE)
	var screen: Control = runner.scene() as Control
	await get_tree().process_frame
	var traveler_button: Button = screen.get_node("%MenuBox").get_child(4) as Button
	assert_str(traveler_button.text).contains("井边的旅人")
	traveler_button.pressed.emit()
	await get_tree().process_frame
	assert_int(int(screen._run.rewards[&"exp"])).is_equal(10)
	assert_bool(screen._panel._continue_button.visible).is_true()
	# 数值反馈行（E5）：+10 经验回带（UI 层拼装）
	assert_str(screen._panel._result_label.text).contains("+10 经验")
	# 继续回菜单：入口置灰（已消耗）+ 面板清空（E3-15）
	screen._panel._continue_button.pressed.emit()
	await get_tree().process_frame
	assert_bool((screen.get_node("%MenuBox").get_child(4) as Button).disabled).is_true()
	assert_str(screen._panel._result_label.text).is_empty()

func test_check_event_enters_cast_with_default_highlight() -> void:
	## 检定事件：点击入口 → 叙述+选项；点检定选项 → 改派面板——默认最高
	## 高亮（构造属性差队伍真锁「最高调整值」：盗贼体质调 20 应排首）；
	## 高亮色经 cfg 单源取值（解耦 UiTheme 常量色耦合）
	var runner: GdUnitSceneRunner = scene_runner(EVENT_SCENE)
	var screen: Control = runner.scene() as Control
	await get_tree().process_frame
	# 构造属性差：盗贼（party[1]）体质 20 → 体质检定候选首名
	screen._run.party[1].attrs[&"constitution"] = 20
	(screen.get_node("%MenuBox").get_child(0) as Button).pressed.emit()
	await get_tree().process_frame
	# 4 选项视图
	assert_int(screen._panel._options_box.get_child_count()).is_equal(4)
	# 点首个检定选项（徒手扒开碎石——体质·容易）→ 改派面板
	var first_option: Button = screen._panel._options_box.get_child(0) as Button
	first_option.pressed.emit()
	await get_tree().process_frame
	assert_bool(screen._panel._cast_box.visible).is_true()
	var cast_buttons: Array = screen._panel._cast_box.get_children().filter(
			func(child: Node) -> bool: return child is Button)
	assert_int(cast_buttons.size()).is_equal(4)
	# 默认最高 = 属性差首名（盗贼）+ 金色高亮（cfg 表驱动色单源）
	var first_cast: Button = cast_buttons[0] as Button
	assert_str(first_cast.text).contains("盗贼")
	var expected_gold: Color = UiTheme.color_of(screen._panel._cfg,
			&"ui_highlight_gold_color", UiTheme.HIGHLIGHT_GOLD)
	assert_bool(first_cast.modulate.is_equal_approx(expected_gold)) \
			.override_failure_message("改派首名应金色高亮（默认最高）").is_true()

func test_b_exit_routes_battle_with_return_params() -> void:
	## B 出口路由（E3-06 先播再战）：鬼火链纯选择「列阵」→ 战前演出视图
	## （「进入战斗」钮）→ 点击 → 战斗屏挂载 + return_to=EVENT_SCREEN +
	## expedition_run/锚点透传
	var runner: GdUnitSceneRunner = scene_runner(EVENT_SCENE)
	var screen: Control = runner.scene() as Control
	await get_tree().process_frame
	(screen.get_node("%MenuBox").get_child(1) as Button).pressed.emit()
	await get_tree().process_frame
	# 列阵戒备（第 3 选项，纯选择）
	var options: Array = screen._panel._options_box.get_children()
	var formation_button: Button = null
	for child: Node in options:
		if child is Button and (child as Button).text.contains("列阵戒备"):
			formation_button = child
			break
	assert_object(formation_button).is_not_null()
	formation_button.pressed.emit()
	await get_tree().process_frame
	# E3-06：先播再战——战前演出视图（叙述可见 +「进入战斗」钮），未切场景
	assert_bool(screen._panel._battle_button.visible).is_true()
	assert_str(screen._panel._result_label.text).contains("巢穴")
	var scene_before: Node = get_tree().current_scene
	screen._panel._battle_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	# 战斗屏挂载（B 路由成功——经 SceneManager 切换的 current_scene 精确定位，
	# 不受 SceneRunner 挂载的旧屏/其他套件残留干扰）+ return_to 口径 + 回传包锚点
	var battle: Control = get_tree().current_scene as Control
	assert_object(battle).is_not_null()
	assert_str(battle.name).is_equal("BattleScreen")
	assert_bool(battle != scene_before).is_true()
	assert_int(battle._return_to).is_equal(preload("res://scripts/autoload/scene_manager.gd").SceneId.EVENT_SCREEN)
	assert_object(battle._return_payload.get(&"expedition_run", null)).is_not_null()
	assert_int((battle._return_payload.get(&"expedition_run", null) as ExpeditionRun).party.size()).is_equal(4)
	assert_str(String(battle._return_payload.get(&"battle_node_id", &""))).is_equal("evn_wisp_n3")
	# E2-4：路由战斗期间锁由 battle_screen 接管持有
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_true()
	battle.controller.abort_battle()

func test_battle_round_trip_run_continues() -> void:
	## E2-6/E3-01 端到端往返：列阵 → 战斗屏 → 注入 VICTORY → 返回 →
	## event_screen 恢复**原 run 引用**（hp/consumed 延续 + post_battle 15/15
	## 入账 + 锚点恢复 + 回传包合并不丢 run）
	var runner: GdUnitSceneRunner = scene_runner(EVENT_SCENE)
	var screen: Control = runner.scene() as Control
	await get_tree().process_frame
	var original_run: ExpeditionRun = screen._run
	(screen.get_node("%MenuBox").get_child(1) as Button).pressed.emit()
	await get_tree().process_frame
	var options: Array = screen._panel._options_box.get_children()
	for child: Node in options:
		if child is Button and (child as Button).text.contains("列阵戒备"):
			(child as Button).pressed.emit()
			break
	await get_tree().process_frame
	screen._panel._battle_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var battle: Control = get_tree().current_scene as Control
	assert_object(battle).is_not_null()
	assert_str(battle.name).is_equal("BattleScreen")
	assert_bool(battle != screen).is_true()
	# 注入战斗结果（VICTORY + 终局快照——战后续跑数据源）
	var result := BattleResult.new()
	result.kind = BattleResult.ResultKind.VICTORY
	result.end_stats = [
		{&"unit_id": &"warrior", &"end_hp": 33, &"end_mana": 0, &"end_stamina": 0, &"downed": false},
		{&"unit_id": &"rogue", &"end_hp": 44, &"end_mana": 0, &"end_stamina": 0, &"downed": false},
		{&"unit_id": &"mage", &"end_hp": 0, &"end_mana": 0, &"end_stamina": 0, &"downed": true},
		{&"unit_id": &"priest", &"end_hp": 55, &"end_mana": 0, &"end_stamina": 0, &"downed": false},
	]
	battle._OnBattleEnded(result)
	await get_tree().process_frame
	# E3-01①：回传包合并键——battle_result 并入且 expedition_run 不丢
	assert_object(battle._return_payload.get(&"battle_result", null) as BattleResult).is_not_null()
	assert_object(battle._return_payload.get(&"expedition_run", null)).is_not_null()
	# 点返回 → event_screen 续跑（current_scene = 新挂载的 EventScreen——
	# SceneRunner 挂载的旧屏不参与定位）
	battle._OnReturnPressed()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var resumed: Control = get_tree().current_scene as Control
	assert_object(resumed).is_not_null()
	# SceneRunner 挂载的旧屏仍在树（change_scene 只换 current_scene）——新屏
	# 同名冲突会被 Godot 重命名为「@Control@N」，按脚本路径+非旧实例判定
	assert_bool(resumed != screen).is_true()
	assert_str(String((resumed.get_script() as GDScript).resource_path)) \
			.contains("event_screen.gd")
	# E3-01②：恢复**原 run 引用**（非重建）——hp/consumed 延续
	assert_bool(resumed._run == original_run) \
			.override_failure_message("战后续跑应恢复原 run 引用").is_true()
	assert_int(int(resumed._run.hp[original_run.party[0]])).is_equal(33)
	assert_bool(resumed._run.downed.get(original_run.party[2], false)) \
			.override_failure_message("战斗倒地应带回运行态").is_true()
	assert_bool(resumed._run.consumed_events.has(&"chain_mine_wisp")).is_true()
	# post_battle 入账：15/15（战前 B 分支已不入账——E2-8）
	assert_int(int(resumed._run.rewards[&"exp"])).is_equal(15)
	assert_int(int(resumed._run.rewards[&"gold"])).is_equal(15)
	# E3-01②锚点恢复：post_battle 结算锚 = n3；结算视图可见
	assert_str(String(resumed._last_battle_node_id)).is_equal("evn_wisp_n3")
	assert_bool(resumed._panel._continue_button.visible).is_true()
	assert_str(resumed._panel._result_label.text).contains("亮闪闪")
	# E2-4：续跑会话锁连续
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_true()
	# 返回公会：会话结束释放锁
	resumed._OnBack()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_false()

func test_all_downed_intercepts_battle_route() -> void:
	## E2-3：全倒地前置拦截——B 出口路由前全员倒地 → 占位文本终结会话
	## （不路由战斗——空名单拒绝装配），出征锁保持
	var runner: GdUnitSceneRunner = scene_runner(EVENT_SCENE)
	var screen: Control = runner.scene() as Control
	await get_tree().process_frame
	for adv: AdventurerData in screen._run.party:
		screen._run.downed[adv] = true
	(screen.get_node("%MenuBox").get_child(1) as Button).pressed.emit()
	await get_tree().process_frame
	var options: Array = screen._panel._options_box.get_children()
	for child: Node in options:
		if child is Button and (child as Button).text.contains("列阵戒备"):
			(child as Button).pressed.emit()
			break
	await get_tree().process_frame
	var scene_before: Node = get_tree().current_scene
	screen._panel._battle_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	# 未路由战斗（current_scene 未换）+ 占位文本 + 会话仍在（锁保持）
	assert_bool(get_tree().current_scene == scene_before) \
			.override_failure_message("全倒地不得路由战斗").is_true()
	assert_str(screen._panel._result_label.text).contains("全员倒地")
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_true()

func test_scene_flow_regression_guild_entry() -> void:
	## 场景流转回归：公会壳 → 事件入口 → event_screen 挂载（SceneManager
	## 注册表扩行不破既有流转）
	var runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	var button: Button = runner.find_child("EventEntryButton", true, false) as Button
	assert_object(button).is_not_null()
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(get_tree().root.find_child("EventScreen", true, false)).is_not_null()
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	assert_int(scene_manager.current_id).is_equal(preload("res://scripts/autoload/scene_manager.gd").SceneId.EVENT_SCREEN)
