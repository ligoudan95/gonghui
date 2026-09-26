## 探索屏集成测试（M3 批 2/批 3：渲染 + 移动交互 + 中断接线）
## 覆盖：进图渲染（村子亮/矿洞雾/绑定目标高亮 5 灰显）/ 点格走格 /
## 三类移动中断（ENTER 事件点弹事件面板/暗门 NEAR 弹检定/随机遭遇路由战斗）
## 与恢复 / 公会壳出征按钮 → 探索屏 → 撤退往返 + 出征锁状态 / 触控热区 ≥48。
## 环境：gdUnit 帧内真 autoload（GameData/SaveManager/SceneManager）；
## 步进演出 override 0 加速；遭遇 rng 定种子（无概率窗）。
extends GdUnitTestSuite

## 场景路径
const GUILD_SCENE: String = "res://scenes/guild/guild_shell.tscn"
const EXPLORE_SCENE: String = "res://scenes/explore/explore_screen.tscn"

## 探索屏 SceneId（SceneManager.SceneId.EXPLORE_SCREEN）
const SCENE_EXPLORE: int = 4

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

func _WaitFrames(frames: int) -> void:
	## 帧等待助手
	## 参数 frames：帧数
	## 返回：无（协程）
	for _i: int in frames:
		await get_tree().process_frame

func _GameData() -> Node:
	## 取真 GameData 单例
	## 参数：无
	## 返回：GameData 节点
	return get_tree().root.get_node("GameData")

func _MakeQuestRun(quest_id: StringName) -> ExpeditionRun:
	## 构建单人有委托运行态（q_lost_miner_keepsake / q_lair_purge）
	## 参数 quest_id：委托模板 id
	## 返回：ExpeditionRun
	var game_data: Node = _GameData()
	var cfg: CoreConfig = game_data.get_record(&"cfg_main") as CoreConfig
	var run := ExpeditionRun.new()
	var adv: AdventurerData = AdventurerData.create_debug(&"t", &"cls_warrior", {
		&"strength": 14, &"agility": 10, &"constitution": 14,
		&"intelligence": 7, &"perception": 15, &"willpower": 9, &"luck": 9}, game_data)
	run.party.append(adv)
	run.hp[adv] = 30
	var map_def: ExploreMapDef = game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	run.start_explore(map_def, game_data.get_record(quest_id) as QuestTemplateDef,
			cfg.vision_radius)
	return run

func _SafeEncounterSeed() -> int:
	## 取「连续 12 次掷值均未中 4%」的种子（移动中断测试防遭遇抢断）
	## 参数：无
	## 返回：种子值
	for seed_value: int in range(10000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		var all_miss: bool = true
		for _i: int in 12:
			if probe.randf() < 0.04:
				all_miss = false
				break
		if all_miss:
			return seed_value
	return 0

func _HitEncounterSeed() -> int:
	## 取「首掷即命中 4%」的种子（遭遇触发/上限拦截测试——掷值必中语义）
	## 参数：无
	## 返回：种子值
	for seed_value: int in range(10000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() < 0.04:
			return seed_value
	return 0

func test_explore_screen_renders_fog_and_targets() -> void:
	## 进图渲染：委托会话（q_lost）——村子段全亮（迷雾遮罩隐藏）/ 矿洞未探
	## 浓雾（遮罩可见）/ 目标点 1 高亮（tp_old_well）+ 5 灰显
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	scene_manager.pending_params = {&"expedition_run": _MakeQuestRun(&"q_lost_miner_keepsake")}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	# 出征锁生效
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_true()
	# 村子段（全亮行）：迷雾遮罩隐藏；矿洞未探格：遮罩可见（浓雾）
	assert_bool(screen._board._fog_rects[Vector2i(0, 0)].visible).is_false()
	assert_bool(screen._board._fog_rects[Vector2i(7, 10)].visible).is_true()
	# 小队图标落出生格
	assert_bool(screen._board._party_icon.position == Vector2(7, 1) * float(ExploreBoard.CELL_SIZE)).is_true()
	# 目标点：绑定 tp_old_well 高亮金 / 其余 5 灰显
	var game_data: Node = _GameData()
	var cfg: CoreConfig = game_data.get_record(&"cfg_main") as CoreConfig
	var active: Color = UiTheme.color_of(cfg, &"ui_explore_target_active_color",
			UiTheme.EXPLORE_TARGET_ACTIVE)
	var dim: Color = UiTheme.color_of(cfg, &"ui_explore_target_dim_color",
			UiTheme.EXPLORE_TARGET_DIM)
	assert_bool(screen._board._target_icons[&"tp_old_well"].modulate.is_equal_approx(active)).is_true()
	for tp_id: StringName in [&"tp_mine_east_gallery", &"tp_mine_north_wall",
			&"tp_mine_south_shaft", &"tp_mine_west_camp", &"tp_mine_track_yard"]:
		assert_bool(screen._board._target_icons[tp_id].modulate.is_equal_approx(dim)) \
				.override_failure_message("%s 应灰显" % tp_id).is_true()
	# 暗门图标未揭示隐藏（隐藏内容不剧透）
	assert_bool(screen._board._point_icons[&"evp_mine_secret"].visible).is_false()

func test_fog_wall_occlusion_renders() -> void:
	## 视野穿透墙壁修复（2026-09-25 用户拍板：视野被墙遮挡）：矿洞 (7,7)
	## 视角——(5,9) 视野圆内但被 (6,8) 岩壁遮挡 → UNSEEN 浓雾遮罩可见；
	## (5,7) 同排无遮挡 → LIT 遮罩隐藏（真实图 + 探索屏装配链验证遮挡挂接）
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var run := _MakeQuestRun(&"q_lair_purge")
	scene_manager.pending_params = {&"expedition_run": run}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	# 小队移入矿洞开阔排 (7,7)——揭示后刷新板面
	run.party_pos = Vector2i(7, 7)
	run.fog.on_moved(Vector2i(7, 7))
	screen._RefreshBoard()
	assert_bool(screen._board._fog_rects[Vector2i(5, 9)].visible).is_true() \
			.override_failure_message("墙后格 (5,9) 应保持浓雾（被 (6,8) 遮挡）")
	assert_bool(screen._board._fog_rects[Vector2i(5, 7)].visible).is_false() \
			.override_failure_message("无遮挡格 (5,7) 应当前视野 LIT（遮罩隐藏）")

func test_move_by_cell_press() -> void:
	## 点格走格：点矿洞入口格 (7,3)——逐格步进抵达（演出加速 override 0）
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var run := _MakeQuestRun(&"q_lair_purge")
	scene_manager.pending_params = {&"expedition_run": run}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	screen._rng.seed = _SafeEncounterSeed()
	screen.step_seconds_override = 0.0
	screen._OnCellPressed(Vector2i(7, 3))
	await _WaitFrames(12)
	assert_bool(run.party_pos == Vector2i(7, 3)).is_true()
	assert_bool(screen._moving).is_false()
	# 途经格已入迷雾记忆（新格揭示）
	assert_bool(run.fog.is_explored(Vector2i(7, 2))).is_true()
	assert_bool(run.fog.is_explored(Vector2i(7, 3))).is_true()
	# 暗门不在路径近旁（北廊西段未及 (12,4) 半径 2）——未触发
	assert_bool(run.consumed_events.is_empty()).is_true()

func test_enter_point_interrupts_movement() -> void:
	## ENTER 中断：走向旅人事件点 (5,0)（无检定单点——立即结算）——踏入同格
	## 即中断并弹出事件面板结算视图；「继续」关闭面板后移动恢复
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var run := _MakeQuestRun(&"q_lair_purge")
	scene_manager.pending_params = {&"expedition_run": run}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	screen._rng.seed = _SafeEncounterSeed()
	screen.step_seconds_override = 0.0
	screen._OnCellPressed(Vector2i(5, 0))
	await _WaitFrames(12)
	assert_bool(run.party_pos == Vector2i(5, 0)).is_true()
	assert_bool(screen._moving).is_false()
	# 事件面板：无检定单点立即结算（叙述 + 继续钮可见；事件已消耗）
	assert_bool(screen._event_open).is_true()
	assert_bool(screen._panel._continue_button.visible).is_true()
	assert_bool(run.consumed_events.has(&"sp_village_traveler")).is_true()
	# 面板占用期点格不移动（门禁）
	screen._OnCellPressed(Vector2i(7, 1))
	await _WaitFrames(6)
	assert_bool(run.party_pos == Vector2i(5, 0)).is_true()
	# 「继续」关闭面板 → 恢复移动
	screen._panel._continue_button.pressed.emit()
	await _WaitFrames(2)
	assert_bool(screen._event_open).is_false()
	screen._OnCellPressed(Vector2i(7, 2))
	await _WaitFrames(10)
	assert_bool(run.party_pos == Vector2i(7, 2)).is_true()

func test_secret_door_near_interrupts_movement() -> void:
	## 暗门 NEAR 中断：走向北廊东端 (12,4)——踏入触发半径（(10,4) 距离恰 2）
	## 即中断弹出暗门检定事件面板（感知·极难——叙述「北壁」）；未抵达目标格
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var run := _MakeQuestRun(&"q_lair_purge")
	scene_manager.pending_params = {&"expedition_run": run}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	screen._rng.seed = _SafeEncounterSeed()
	screen.step_seconds_override = 0.0
	screen._OnCellPressed(Vector2i(12, 4))
	await _WaitFrames(20)
	assert_bool(run.party_pos == Vector2i(10, 4)).is_true()
	assert_bool(screen._moving).is_false()
	# 暗门检定事件面板（单点检定——1 个检定选项，叙述含「北壁」）
	assert_bool(screen._event_open).is_true()
	assert_int(screen._panel._options_box.get_child_count()).is_equal(1)
	assert_str(screen._panel._narrative_label.text).contains("北壁")
	assert_bool(run.consumed_events.has(&"sp_mine_secretdoor")).is_true()

func _ForceHitWeight() -> EncounterWeightDef:
	## 构造「每新格必掷且命中」的遭遇权重（机制回归锚专用——2026-09-25 用户
	## 拍板【DEMO 排除所有随机战斗】后真实表 encw_mine chance 已归 0，机制
	## 验证改为构造注入，真实数据「矿洞新格也不掷」另见锁定用例三）
	## 参数：无
	## 返回：EncounterWeightDef（chance 0.04 / 上限 1——掷值经种子强制命中）
	var weight := EncounterWeightDef.new()
	weight.id = &"encw_mine_mech_anchor"
	weight.region_id = &"reg_mine"
	weight.encounter_chance = 0.04
	weight.random_pack_id = &"enc_m1_random_pack"
	weight.random_max = 1
	return weight

func test_random_encounter_interrupts_movement() -> void:
	## 随机遭遇机制回归锚（构造权重注入）：定种子使首个矿洞新格掷值命中
	## 4%——踏入 (7,3) 即中断并路由战斗屏（遭遇计数自增 + return_to=
	## EXPLORE_SCREEN + 通道键回带）；真实数据侧已关随机战斗（锁定用例三）
	var hit_seed: int = -1
	for seed_value: int in range(10000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() < 0.04:
			hit_seed = seed_value
			break
	assert_int(hit_seed).is_not_equal(-1)
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var run := _MakeQuestRun(&"q_lair_purge")
	scene_manager.pending_params = {&"expedition_run": run}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	# 机制回归锚：真实表 chance 0（拍板关闭）——构造权重替换矿洞区查表结果
	screen._encw_by_region[&"reg_mine"] = _ForceHitWeight()
	screen._rng.seed = hit_seed
	screen.step_seconds_override = 0.0
	# 目标深入矿洞（必经 (7,3) 首个新矿洞格）
	screen._OnCellPressed(Vector2i(7, 6))
	await _WaitFrames(8)
	assert_bool(run.party_pos == Vector2i(7, 3)).is_true()
	assert_bool(screen._moving).is_false()
	assert_int(run.random_encounters_fired).is_equal(1)
	# 战斗屏挂载：遭遇通道（encounter_pack_id 回带 + return_to 探索屏 + 锁连续）
	await _WaitFrames(4)
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	assert_int(scene_manager.current_id).is_equal(2)
	assert_str(String(battle._return_payload[&"encounter_pack_id"])).is_equal("enc_m1_random_pack")
	assert_int(battle._return_to).is_equal(SCENE_EXPLORE)
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_true()
	(battle.get_node("%BoardLayer") as BattleBoard)  # 战斗板就绪（装配成立）
	battle.controller.abort_battle()

func test_guild_expedition_roundtrip_lock() -> void:
	## 公会壳 ↔ 探索屏往返：出征按钮（清剿）→ 探索屏挂载 + 出征锁置位 +
	## run 判据上下文（CLEAR/enc_m1_lair_pack）；撤退 → 回公会壳 + 锁释放
	var runner: GdUnitSceneRunner = scene_runner(GUILD_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	(runner.find_child("ExpeditionPurgeButton", true, false) as Button).pressed.emit()
	await _WaitFrames(4)
	var explore: Control = get_tree().root.find_child("ExploreScreen", true, false) as Control
	assert_object(explore).is_not_null()
	assert_int(get_tree().root.get_node("SceneManager").current_id).is_equal(SCENE_EXPLORE)
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_true()
	# 判据上下文经按钮链路正确注入
	assert_int(explore._run.goal_kind).is_equal(QuestTemplateDef.GoalType.CLEAR)
	assert_str(String(explore._run.goal_param)).is_equal("enc_m1_lair_pack")
	assert_bool(explore._run.party_pos == Vector2i(7, 1)).is_true()
	# 撤退回城（批 3：确认弹窗 → 失败结算 → 回城）：锁释放 + 回公会壳
	(explore.get_node("%RetreatButton") as Button).pressed.emit()
	(explore.get_node("%RetreatConfirm") as ConfirmationDialog).confirmed.emit()
	await _WaitFrames(2)
	assert_bool(explore.get_node("%SettlementPanel").visible).is_true()
	(explore.get_node("%SettlementButton") as Button).pressed.emit()
	await _WaitFrames(4)
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_false()
	assert_object(get_tree().root.find_child("GuildShell", true, false)).is_not_null()

func test_event_panel_hides_after_continue() -> void:
	## ①弹窗会话结束即消失（2026-09-25 试玩反馈）：进屏面板隐藏（tscn 初始
	## visible=false——空面板不常驻屏上）→ ENTER 事件弹出（显示+占用）→
	## 「继续」后隐藏 + 事件占用解除 + 板面点格移动恢复
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var run := _MakeQuestRun(&"q_lair_purge")
	scene_manager.pending_params = {&"expedition_run": run}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	assert_bool(screen.get_node("%PanelHost").visible).is_false()
	screen._rng.seed = _SafeEncounterSeed()
	screen.step_seconds_override = 0.0
	screen._OnCellPressed(Vector2i(5, 0))
	await _WaitFrames(12)
	# 事件弹出：面板显示 + 占用中（无检定单点立即结算——继续钮呈现）
	assert_bool(screen.get_node("%PanelHost").visible).is_true()
	assert_bool(screen._event_open).is_true()
	assert_bool(screen._panel._continue_button.visible).is_true()
	# 「继续」→ 面板隐藏 + 输入恢复（点格可再移动）
	screen._panel._continue_button.pressed.emit()
	await _WaitFrames(2)
	assert_bool(screen.get_node("%PanelHost").visible).is_false()
	assert_bool(screen._event_open).is_false()
	screen._OnCellPressed(Vector2i(7, 2))
	await _WaitFrames(10)
	assert_bool(run.party_pos == Vector2i(7, 2)).is_true()

func test_v3_empty_view_clears_stale_panel_and_input_gate() -> void:
	## V-3（2026-09-26 审计）：_DispatchView 空视图分支统一清场——面板占用态
	## （上一视图残留）下派发空视图（无选项/无叙述/非拦截）→ 面板清空隐藏 +
	## _event_open 解除（修复前不动面板——输入闸门悬置软锁）；对 _StartEvent
	## 入口零影响（面板本关）
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var run := _MakeQuestRun(&"q_lair_purge")
	scene_manager.pending_params = {&"expedition_run": run}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	# 模拟面板占用态（选项派生链返回空视图前的上一视图残留）
	screen._ShowEventPanel()
	screen._event_open = true
	assert_bool(screen.get_node("%PanelHost").visible).is_true()
	# 空视图派发 → 统一清场
	var view := EventRunner.EventView.new()
	assert_bool(view.options.is_empty() and view.narrative.is_empty()
			and not view.intercepted).is_true()
	screen._DispatchView(view)
	assert_bool(screen.get_node("%PanelHost").visible).is_false() \
			.override_failure_message("V-3：空视图应隐藏事件面板（清场）")
	assert_bool(screen._event_open).is_false() \
			.override_failure_message("V-3：空视图应解除输入闸门（_event_open）")
	# 清场后板面输入恢复（点格可移动）
	screen._rng.seed = _SafeEncounterSeed()
	screen.step_seconds_override = 0.0
	screen._OnCellPressed(Vector2i(7, 2))
	await _WaitFrames(10)
	assert_bool(run.party_pos == Vector2i(7, 2)).is_true()

func test_mine_new_cell_never_rolls_encounter_real_data() -> void:
	## 锁定用例三（2026-09-25 用户拍板【排除所有随机战斗】——真实数据侧）：
	## 矿洞区真实权重 encw_mine chance 已归 0——即便「首掷必中」种子，矿洞
	## 新格也不掷（前置拒掷）不路由战斗，正常走抵目标
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var run := _MakeQuestRun(&"q_lair_purge")
	scene_manager.pending_params = {&"expedition_run": run}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	# 真实表断言：encw_mine encounter_chance == 0（数据侧关闭的唯一权威）
	var weight: EncounterWeightDef = screen._encw_by_region[&"reg_mine"] as EncounterWeightDef
	assert_object(weight).is_not_null()
	assert_float(weight.encounter_chance).is_equal(0.0) \
			.override_failure_message("encw_mine.chance 应为 0（随机战斗已拍板关闭）")
	screen._rng.seed = _HitEncounterSeed()
	screen.step_seconds_override = 0.0
	screen._OnCellPressed(Vector2i(7, 6))
	await _WaitFrames(12)
	assert_int(run.random_encounters_fired).is_equal(0)
	assert_object(get_tree().root.find_child("BattleScreen", true, false)).is_null()
	assert_bool(run.party_pos == Vector2i(7, 6)).is_true()

func test_village_new_cell_never_routes_encounter() -> void:
	## ③随机遭遇排查·锁定用例一（调用链核验通过——设计内 4%）：村子全亮段
	## 新格不掷（encw_village encounter_chance 0 前置拒）——即便 rng 为
	## 「首掷必中 4%」种子也不路由（村子误掷回归锚）
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var run := _MakeQuestRun(&"q_lair_purge")
	scene_manager.pending_params = {&"expedition_run": run}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	screen._rng.seed = _HitEncounterSeed()
	screen.step_seconds_override = 0.0
	# 村段（全亮行 y=2）首个可通行非事件格——路径不经矿洞（y ≥ 1 行进）
	var target: Vector2i = Vector2i(-1, -1)
	for x: int in range(8):
		var cell: Vector2i = Vector2i(x, 2)
		if cell != run.party_pos and screen._state.walkable(cell):
			target = cell
			break
	assert_vector(target).is_not_equal(Vector2i(-1, -1))
	screen._OnCellPressed(target)
	await _WaitFrames(12)
	assert_int(run.random_encounters_fired).is_equal(0)
	assert_object(get_tree().root.find_child("BattleScreen", true, false)).is_null()
	assert_bool(run.party_pos == target).is_true()

func test_random_encounter_cap_one_blocks_further_rolls() -> void:
	## ③随机遭遇排查·锁定用例二（机制回归锚——构造权重注入）：同次出征上限
	## 1 场——已触发 1 场后矿洞新格（首掷必中种子）移动不再路由遭遇
	## （fired 保持 1 + 抵达目标格）
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var run := _MakeQuestRun(&"q_lair_purge")
	run.random_encounters_fired = 1
	scene_manager.pending_params = {&"expedition_run": run}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	# 机制锚：真实表 chance 0 会让上限拦截恒真——构造权重恢复上限判定路径
	screen._encw_by_region[&"reg_mine"] = _ForceHitWeight()
	screen._rng.seed = _HitEncounterSeed()
	screen.step_seconds_override = 0.0
	# (7,3) = 矿洞入口格（途经 (7,2) 首个矿洞新格——掷值被上限拦截）
	screen._OnCellPressed(Vector2i(7, 3))
	await _WaitFrames(12)
	assert_int(run.random_encounters_fired).is_equal(1)
	assert_object(get_tree().root.find_child("BattleScreen", true, false)).is_null()
	assert_bool(run.party_pos == Vector2i(7, 3)).is_true()

func test_touch_hotzone_at_least_48() -> void:
	## 触控热区：板面单格 ≥48px + 撤退钮高度 ≥48px
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	scene_manager.pending_params = {&"expedition_run": _MakeQuestRun(&"q_lair_purge")}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	assert_int(ExploreBoard.CELL_SIZE).is_greater_equal(48)
	assert_float((screen.get_node("%RetreatButton") as Button).custom_minimum_size.y) \
			.is_greater_equal(48.0)

# --------------------------------------------------------------------------
# 第四轮审计高危 W3-01（2026-09-26）：探索屏缩放机制真实介入契约
# --------------------------------------------------------------------------

func test_w301_board_scale_engages_and_bottom_stays_onscreen() -> void:
	## W3-01：1920×1080 布局下——①板面缩放真实介入（board.scale.y < 1.0：
	## 15×15 图设计高 900 > 宿主剩余高，修复前 CenterContainer 宿主 min 随
	## 板面膨胀到 900 → fit 恒 1.0 机制空转）；②底部操作区不出屏
	## （BottomBox 全局底边 ≤ 视口底边）。
	## 环境注：headless gdUnit 视口为 1920×1920（expand 长宽比无真窗）——
	## 显式设窗 1920×1080 复现设计布局口径（stretch canvas_items 同步生效）
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	scene_manager.pending_params = {&"expedition_run": _MakeQuestRun(&"q_lair_purge")}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	screen.get_window().size = Vector2i(1920, 1080)
	await _WaitFrames(4)
	assert_float(screen.get_viewport_rect().size.y).is_equal_approx(1080.0, 2.0)
	assert_float(screen._board.scale.y).is_less(1.0) \
			.override_failure_message("板面缩放未介入（scale.y 应 < 1.0——宿主可用高 < 设计高 900）")
	var viewport_end: float = screen.get_viewport_rect().size.y
	var bottom_box: Control = screen.get_node("Layout/BottomBox")
	assert_float(bottom_box.global_position.y + bottom_box.size.y) \
			.is_less_equal(viewport_end) \
			.override_failure_message("底部操作区被顶出屏幕（BoardHost min 膨胀未修复）")

func test_w301_refit_keeps_bottom_onscreen_with_banner() -> void:
	## W3-01 横幅出现态：1080 布局下判据达成横幅弹入 → BoardHost 可用空间
	## 再缩水 → resized 重算（fit + 手动居中）后底部操作区仍不出屏、板面仍
	## 居中于宿主
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	scene_manager.pending_params = {&"expedition_run": _MakeQuestRun(&"q_lair_purge")}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	await _WaitFrames(2)
	screen.get_window().size = Vector2i(1920, 1080)
	await _WaitFrames(4)
	# 横幅弹入（模拟判据达成后的 _RefreshStatus 布局变化）
	screen.get_node("%GoalBanner").visible = true
	await _WaitFrames(3)
	var viewport_end: float = screen.get_viewport_rect().size.y
	var bottom_box: Control = screen.get_node("Layout/BottomBox")
	assert_float(bottom_box.global_position.y + bottom_box.size.y) \
			.is_less_equal(viewport_end) \
			.override_failure_message("横幅出现态底部操作区出屏（resized 重算未生效）")
	assert_float(screen._board.scale.y).is_less(1.0)
	# 板面视觉区在宿主内居中（视觉中心 == 宿主中心——W3-01 手动居中落位）
	var host: Control = screen.get_node("%BoardHost")
	var visual: Rect2 = screen._board.visual_rect()
	var host_center_x: float = host.global_position.x + host.size.x * 0.5
	assert_float(visual.get_center().x).is_equal_approx(host_center_x, 1.0) \
			.override_failure_message("板面视觉区未在宿主内水平居中")
