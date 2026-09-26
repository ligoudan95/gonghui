## 探索层全链集成测试（M3 批 3——验收 5 条全链 + 锁全通道遍历）
## 覆盖：①进图→迷雾揭示→事件→必然战→判据→出口交付全链；②暗门成功揭示
## 捷径 / 失败可绕双分支（定种子检定——无概率窗）；③非绑定目标点灰显不可
## 交互；④撤退（含达成后撤退仍失败）/宝箱消耗后新出征实例重置；⑤随机遭遇
## 上限 1（战后续走不再触发）；锁通道遍历：交付/撤退/战败/全倒地四通道
## 解锁断言。
## 环境：gdUnit 帧内真 autoload；步进演出 override 0 加速；检定/遭遇全定种子。
extends GdUnitTestSuite

## SceneId 数值（SceneManager：GUILD_SHELL=1 / BATTLE_SCREEN=2 / EXPLORE_SCREEN=4）
const SCENE_GUILD: int = 1
const SCENE_BATTLE: int = 2
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

func _MakeQuestRun(quest_id: StringName, perception: int = 15) -> ExpeditionRun:
	## 构建单人有委托运行态（感知可调——暗门检定分支用）
	## 参数 quest_id：委托模板 id；perception：队员感知值
	## 返回：ExpeditionRun
	var game_data: Node = _GameData()
	var cfg: CoreConfig = game_data.get_record(&"cfg_main") as CoreConfig
	var run := ExpeditionRun.new()
	var adv: AdventurerData = AdventurerData.create_debug(&"t", &"cls_warrior", {
		&"strength": 14, &"agility": 10, &"constitution": 14,
		&"intelligence": 7, &"perception": perception, &"willpower": 9, &"luck": 10}, game_data)
	run.party.append(adv)
	run.hp[adv] = 30
	var map_def: ExploreMapDef = game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	run.start_explore(map_def, game_data.get_record(quest_id) as QuestTemplateDef,
			cfg.vision_radius)
	return run

func _OpenExplore(run: ExpeditionRun) -> Control:
	## 按出征运行态挂载探索屏（经 SceneManager——scene_runner 挂载不占
	## current_scene 位，路由离场后残留树内干扰按名查找；演出加速 + 安全种子）
	## 参数 run：出征运行态
	## 返回：探索屏根节点（current_scene）
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	assert_int(scene_manager.go(SCENE_EXPLORE, {&"expedition_run": run})).is_equal(OK)
	await _WaitFrames(4)
	var screen: Control = get_tree().current_scene as Control
	assert_object(screen).is_not_null()
	screen.step_seconds_override = 0.0
	screen._rng.seed = _SafeEncounterSeed()
	return screen

func _SafeEncounterSeed() -> int:
	## 取「连续 16 次掷值均未中 4%」的种子（长穿行防遭遇抢断）
	## 参数：无
	## 返回：种子值
	for seed_value: int in range(20000):
			var probe := RandomNumberGenerator.new()
			probe.seed = seed_value
			var all_miss: bool = true
			for _i: int in 16:
				if probe.randf() < 0.04:
					all_miss = false
					break
			if all_miss:
				return seed_value
	return 0

func _ForceHitWeight() -> EncounterWeightDef:
	## 构造「4% 掷值可命中」的遭遇权重（机制回归锚专用——2026-09-25 用户
	## 拍板【DEMO 排除所有随机战斗】后真实表 encw_mine chance 已归 0，需
	## 遭遇路由/上限拦截机制的用例改为构造注入；注意 _ResumeExplore 重挂
	## 探索屏会按真实表重建 _encw_by_region，续屏后需重注入）
	## 参数：无
	## 返回：EncounterWeightDef（chance 0.04 / 上限 1——掷值经种子控制）
	var weight := EncounterWeightDef.new()
	weight.id = &"encw_mine_mech_anchor"
	weight.region_id = &"reg_mine"
	weight.encounter_chance = 0.04
	weight.random_pack_id = &"enc_m1_random_pack"
	weight.random_max = 1
	return weight

func _MakeResult(kind: int, end_hp: int, downed: bool) -> BattleResult:
	## 构造单成员战斗结果
	## 参数 kind：ResultKind；end_hp：终局 HP；downed：倒地标记
	## 返回：BattleResult
	var result := BattleResult.new()
	result.kind = kind
	var stats: Array[Dictionary] = []
	stats.append({&"unit_id": &"t", &"end_hp": end_hp, &"downed": downed})
	result.end_stats = stats
	return result

func _ResumeExplore(run: ExpeditionRun, result: BattleResult,
		encounter_pack_id: StringName = &"") -> Control:
	## 以战斗回传 payload 挂载探索屏（战后续跑分叉入口）
	## 参数 run：出征运行态；result：战斗结果；encounter_pack_id：遭遇通道键
	## 返回：探索屏根节点
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var payload: Dictionary = {
		&"expedition_run": run,
		&"battle_result": result,
		&"event_id": &"",
		&"battle_node_id": &"",
		&"encounter_pack_id": encounter_pack_id,
	}
	assert_int(scene_manager.go(SCENE_EXPLORE, payload)).is_equal(OK)
	await _WaitFrames(4)
	var screen: Control = get_tree().current_scene as Control
	assert_object(screen).is_not_null()
	screen.step_seconds_override = 0.0
	screen._rng.seed = _SafeEncounterSeed()
	return screen

# --------------------------------------------------------------------------
# 验收链
# --------------------------------------------------------------------------

func test_chain1_full_clear_quest_to_delivery() -> void:
	## 验收①全链：进图→走格→必然遭遇（巢穴）路由战斗→胜利续跑判据达成→
	## 出口激活→回村点按出口交付→占位结算→回城解锁
	var run := _MakeQuestRun(&"q_lair_purge")
	var screen: Control = await _OpenExplore(run)
	# 走到巢穴 (7,14)——ENTER 必然遭遇中断并路由战斗
	screen._OnCellPressed(Vector2i(7, 14))
	await _WaitFrames(30)
	assert_bool(run.party_pos == Vector2i(7, 14)).is_true()
	assert_bool(run.consumed_events.has(&"evp_mine_lair")).is_true()
	await _WaitFrames(4)
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	assert_int(get_tree().root.get_node("SceneManager").current_id).is_equal(SCENE_BATTLE)
	assert_str(String(battle._return_payload[&"encounter_pack_id"])).is_equal("enc_m1_lair_pack")
	assert_int(battle._return_to).is_equal(SCENE_EXPLORE)
	battle.controller.abort_battle()
	# 胜利续跑：遭遇通道 → 原位继续 + CLEAR 判据达成 + 出口激活横幅
	screen = await _ResumeExplore(run, _MakeResult(BattleResult.ResultKind.VICTORY, 20, false),
			&"enc_m1_lair_pack")
	assert_bool(run.goal_done).is_true()
	assert_bool(screen._goal.is_done()).is_true()
	assert_bool(screen.get_node("%GoalBanner").visible).is_true()
	assert_bool(run.party_pos == Vector2i(7, 14)).is_true()
	# 回村出口交付（点按出口格 (7,0)——走到 (7,1) 后邻接交互）
	screen._OnCellPressed(Vector2i(7, 1))
	await _WaitFrames(40)
	assert_bool(run.party_pos == Vector2i(7, 1)).is_true()
	screen._OnCellPressed(Vector2i(7, 0))
	await _WaitFrames(2)
	# 占位结算面板：成功通道（奖励/耗时申报）
	assert_bool(screen.get_node("%SettlementPanel").visible).is_true()
	assert_str(screen.get_node("%SettlementTitle").text).contains("委托达成")
	assert_str(screen.get_node("%SettlementBody").text).contains("耗时")
	# 回城 → 锁释放（通道①交付）
	(screen.get_node("%SettlementButton") as Button).pressed.emit()
	await _WaitFrames(4)
	assert_object(get_tree().root.find_child("GuildShell", true, false)).is_not_null()
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_false()

func test_chain2_secret_door_success_and_failure_branches() -> void:
	## 验收②暗门双分支：感知 20 队（调整值 +5·除数 2，极难线 17）——
	## 成功种子（首骰 ≥12 → 合计 ≥17）→ unlock_flag 入 run + 捷径格揭示通行；
	## 失败种子（首骰 2..11 → 合计 <17 且非骰 1）→ 不揭示、主路可绕（东竖井）
	# 成功分支
	var success_seed: int = -1
	var fail_seed: int = -1
	for seed_value: int in range(10000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		var die: int = probe.randi_range(1, 20)
		if die >= 12 and success_seed < 0:
			success_seed = seed_value
		if die >= 2 and die <= 11 and fail_seed < 0:
			fail_seed = seed_value
		if success_seed >= 0 and fail_seed >= 0:
			break
	var run := _MakeQuestRun(&"q_lair_purge", 20)
	var screen: Control = await _OpenExplore(run)
	# 站位北廊 (9,4)——一步踏入暗门半径即中断（无前置遭遇掷）
	run.party_pos = Vector2i(9, 4)
	run.visited_cells[Vector2i(9, 4)] = true
	screen._RefreshBoard()
	screen._rng.seed = success_seed
	screen._OnCellPressed(Vector2i(12, 4))
	await _WaitFrames(6)
	assert_bool(run.party_pos == Vector2i(10, 4)).is_true()
	# 检定流：选项 → 改派（唯一候选）→ D20（点按跳过）→ 结算成功
	(screen._panel._options_box.get_child(0) as Button).pressed.emit()
	await _WaitFrames(2)
	var cast_buttons: Array = screen._panel._cast_box.get_children().filter(
			func(child: Node) -> bool: return child is Button)
	assert_int(cast_buttons.size()).is_equal(1)
	(cast_buttons[0] as Button).pressed.emit()
	screen._panel.skip_d20()
	await _WaitFrames(4)
	assert_bool(run.unlock_flags.has(&"secret_door_mine_north")).is_true()
	# 继续 → 揭示捷径：墙格可通行 + (12,4)→(12,7) 直通（主路 5 步 → 捷径 3 格）
	screen._panel._continue_button.pressed.emit()
	await _WaitFrames(2)
	assert_bool(screen._state.walkable(Vector2i(12, 5))).is_true()
	assert_bool(screen._state.walkable(Vector2i(12, 6))).is_true()
	var shortcut: Array[Vector2i] = screen._state.find_path(Vector2i(12, 4), Vector2i(12, 7))
	assert_int(shortcut.size()).is_equal(4)
	# 失败分支（新会话）：同一暗门——不揭示、可绕主路
	var fail_run := _MakeQuestRun(&"q_lair_purge", 20)
	var fail_screen: Control = await _OpenExplore(fail_run)
	fail_run.party_pos = Vector2i(9, 4)
	fail_run.visited_cells[Vector2i(9, 4)] = true
	fail_screen._RefreshBoard()
	fail_screen._rng.seed = fail_seed
	fail_screen._OnCellPressed(Vector2i(12, 4))
	await _WaitFrames(6)
	(fail_screen._panel._options_box.get_child(0) as Button).pressed.emit()
	await _WaitFrames(2)
	var fail_cast: Array = fail_screen._panel._cast_box.get_children().filter(
			func(child: Node) -> bool: return child is Button)
	(fail_cast[0] as Button).pressed.emit()
	fail_screen._panel.skip_d20()
	await _WaitFrames(4)
	assert_bool(fail_run.unlock_flags.has(&"secret_door_mine_north")).is_false()
	fail_screen._panel._continue_button.pressed.emit()
	await _WaitFrames(2)
	assert_bool(fail_screen._state.walkable(Vector2i(12, 5))).is_false()
	# 主路可绕：东竖井 (12,4)→(13,4)→(13,5)→(13,6)→(13,7)→(12,7)
	var detour: Array[Vector2i] = fail_screen._state.find_path(Vector2i(12, 4), Vector2i(12, 7))
	assert_int(detour.size()).is_equal(6)

func test_chain3_unbound_target_dim_and_not_interactable() -> void:
	## 验收③非绑定目标点：CLEAR 委托会话——六目标点全灰显；走到北壁勘查点
	## (9,4)（M1 拍板 B 后老井暗窖已移位——就近取矿洞目标点）点按 → 提示
	## 「其他委托的目标点」且判据不达成
	var game_data: Node = _GameData()
	var cfg: CoreConfig = game_data.get_record(&"cfg_main") as CoreConfig
	var dim: Color = UiTheme.color_of(cfg, &"ui_explore_target_dim_color",
			UiTheme.EXPLORE_TARGET_DIM)
	var run := _MakeQuestRun(&"q_lair_purge")
	var screen: Control = await _OpenExplore(run)
	for tp_id: StringName in screen._board._target_icons:
		assert_bool(screen._board._target_icons[tp_id].modulate.is_equal_approx(dim)) 				.override_failure_message("%s 应灰显" % tp_id).is_true()
	# 就位北廊西段（距勘查点 (9,4) 四格——邻接判定外）→ 点按走入目标格 → 再点按交互
	run.party_pos = Vector2i(5, 4)
	run.visited_cells[Vector2i(5, 4)] = true
	screen._RefreshBoard()
	screen._OnCellPressed(Vector2i(9, 4))
	await _WaitFrames(8)
	assert_bool(run.party_pos == Vector2i(9, 4)).is_true()
	screen._OnCellPressed(Vector2i(9, 4))
	await _WaitFrames(2)
	assert_str(screen.get_node("%HintLabel").text).contains("其他委托")
	assert_bool(screen._goal.is_done()).is_false()

func test_chain4_retreat_discards_and_new_session_resets() -> void:
	## 验收④撤退与实例重置：宝箱开箱入账消耗 → 达成后撤退仍走失败通道 →
	## 回城解锁 → 新出征实例全重置（消耗/奖励/迷雾/格位）
	var run := _MakeQuestRun(&"q_lair_purge")
	var screen: Control = await _OpenExplore(run)
	# 走到北廊西端开箱 (1,4)（TAP——站在箱上点按）
	screen._OnCellPressed(Vector2i(1, 4))
	await _WaitFrames(30)
	assert_bool(run.party_pos == Vector2i(1, 4)).is_true()
	screen._OnCellPressed(Vector2i(1, 4))
	await _WaitFrames(2)
	assert_bool(run.consumed_events.has(&"evp_mine_chest_01")).is_true()
	assert_int(int(run.rewards[&"gold"])).is_greater_equal(20)
	assert_int(int(run.rewards[&"gold"])).is_less_equal(40)
	# 达成后撤退仍 = 失败（通道类型判定——非达成状态）
	screen._goal.setup(QuestTemplateDef.GoalType.CLEAR, &"enc_m1_lair_pack")
	screen._goal.on_battle_victory(&"enc_m1_lair_pack")
	run.goal_done = true
	(screen.get_node("%RetreatConfirm") as ConfirmationDialog).confirmed.emit()
	await _WaitFrames(2)
	assert_bool(screen.get_node("%SettlementPanel").visible).is_true()
	assert_str(screen.get_node("%SettlementTitle").text).contains("委托失败")
	# 回城（通道②撤退解锁）→ 新出征：实例重置
	(screen.get_node("%SettlementButton") as Button).pressed.emit()
	await _WaitFrames(4)
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_false()
	var guild: Control = get_tree().root.find_child("GuildShell", true, false) as Control
	assert_object(guild).is_not_null()
	(guild.find_child("ExpeditionExploreButton", true, false) as Button).pressed.emit()
	await _WaitFrames(4)
	var fresh: Control = get_tree().current_scene as Control
	assert_object(fresh).is_not_null()
	assert_bool(fresh._run.consumed_events.is_empty()).is_true()
	assert_int(int(fresh._run.rewards[&"gold"])).is_equal(0)
	assert_bool(fresh._run.party_pos == Vector2i(7, 1)).is_true()
	assert_bool(fresh._run.goal_done).is_false()
	# 迷雾重置：初始视野 = 出生格 (7,1) 半径 3 圆形（顶边裁剪后 23 格）
	assert_int(fresh._run.fog.explored_count()).is_equal(23)

func test_chain5_random_encounter_cap_once() -> void:
	## 验收⑤随机遭遇 ≤1（机制锚——构造权重注入）：已触发 1 次后（fired=1
	## ——战败不回退），命中种子再走新矿洞格也不再触发（上限拦截——正常
	## 走抵目标）；真实表 chance 已归 0（拍板关闭），上限判定路径经构造权重保持
	var hit_seed: int = -1
	for seed_value: int in range(10000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() < 0.04:
			hit_seed = seed_value
			break
	var run := _MakeQuestRun(&"q_lair_purge")
	run.random_encounters_fired = 1
	var screen: Control = await _OpenExplore(run)
	screen._encw_by_region[&"reg_mine"] = _ForceHitWeight()
	screen._rng.seed = hit_seed
	screen._OnCellPressed(Vector2i(7, 4))
	await _WaitFrames(12)
	# 上限拦截：不中断、不路由战斗、计数不增
	assert_bool(run.party_pos == Vector2i(7, 4)).is_true()
	assert_int(run.random_encounters_fired).is_equal(1)
	assert_object(get_tree().root.find_child("BattleScreen", true, false)).is_null()

func test_lock_channel_defeat_terminates_and_unlocks() -> void:
	## 锁通道③战败：回传 DEFEAT → 占位终结（委托失败）→ 回城解锁
	var run := _MakeQuestRun(&"q_lair_purge")
	var screen: Control = await _ResumeExplore(run, _MakeResult(BattleResult.ResultKind.DEFEAT, 0, true))
	assert_bool(screen.get_node("%SettlementPanel").visible).is_true()
	assert_str(screen.get_node("%SettlementTitle").text).contains("委托失败")
	# X3-04（拍板）：失败通道不显示「收获申报」行
	assert_bool(screen.get_node("%SettlementBody").text.contains("收获申报")).is_false()
	(screen.get_node("%SettlementButton") as Button).pressed.emit()
	await _WaitFrames(4)
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_false()

func test_lock_channel_all_downed_after_victory_terminates() -> void:
	## 锁通道④全倒地：胜利但全队倒地回传 → 占位终结（委托失败）→ 回城解锁
	var run := _MakeQuestRun(&"q_lair_purge")
	var screen: Control = await _ResumeExplore(run, _MakeResult(BattleResult.ResultKind.VICTORY, 0, true))
	assert_bool(screen.get_node("%SettlementPanel").visible).is_true()
	assert_str(screen.get_node("%SettlementTitle").text).contains("委托失败")
	assert_str(screen.get_node("%SettlementBody").text).contains("全员倒地")
	(screen.get_node("%SettlementButton") as Button).pressed.emit()
	await _WaitFrames(4)
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_false()

# --------------------------------------------------------------------------
# M3 质检修复批（43 项——高危/中危补测）
# --------------------------------------------------------------------------

func test_h1_goal_done_survives_battle_and_exit_deliverable() -> void:
	## H1（席1=席3X3-01）：EXPLORE 判据达成 → 随机遭遇路由战斗 → 胜利回屏——
	## 达成态回灌（run.goal_done 恢复进 GoalTracker）+ 出口仍可交付全链
	var run := _MakeQuestRun(&"q_lost_miner_keepsake")
	var screen: Control = await _OpenExplore(run)
	# 机制锚：遭遇路由经构造权重（真实表 chance 0——拍板关闭随机战斗）
	screen._encw_by_region[&"reg_mine"] = _ForceHitWeight()
	# 站老井暗窖格（M1 拍板 B 移位后 (5,13)）点按判据达成
	run.party_pos = Vector2i(5, 13)
	run.visited_cells[Vector2i(5, 13)] = true
	screen._RefreshBoard()
	screen._OnCellPressed(Vector2i(5, 13))
	await _WaitFrames(2)
	assert_bool(run.goal_done).is_true()
	assert_bool(screen._goal.is_done()).is_true()
	assert_bool(screen.get_node("%GoalBanner").visible).is_true()
	# X3-03：达成后再点绑定目标点——独立提示（不再落入「其他委托」文案）
	screen._OnCellPressed(Vector2i(5, 13))
	await _WaitFrames(2)
	assert_str(screen.get_node("%HintLabel").text).contains("目标已达成")
	# 踏新矿洞格触发定种子随机遭遇 → 路由战斗
	var hit_seed: int = -1
	for seed_value: int in range(10000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() < 0.04:
			hit_seed = seed_value
			break
	screen._rng.seed = hit_seed
	screen._OnCellPressed(Vector2i(4, 13))
	await _WaitFrames(8)
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.abort_battle()
	# 胜利回屏：达成态恢复（H1 核心——_ready 回灌）+ 出口激活
	screen = await _ResumeExplore(run, _MakeResult(BattleResult.ResultKind.VICTORY, 20, false),
			&"enc_m1_random_pack")
	assert_bool(screen._goal.is_done()).override_failure_message(
			"判据达成态跨战斗丢失（H1）").is_true()
	assert_bool(screen.get_node("%GoalBanner").visible).is_true()
	# 出口仍可交付（模拟回到村口——run 引用同屏）
	run.party_pos = Vector2i(7, 1)
	run.visited_cells[Vector2i(7, 1)] = true
	screen._RefreshBoard()
	screen._OnCellPressed(Vector2i(7, 0))
	await _WaitFrames(2)
	assert_bool(screen.get_node("%SettlementPanel").visible).is_true()
	assert_str(screen.get_node("%SettlementTitle").text).contains("委托达成")

func test_h2_secret_reveal_survives_battle_softlock_variant() -> void:
	## H2（席2X2-H1）：暗门成功揭示 → 小队站捷径格 (12,5) 遭遇路由 → 胜利回屏
	## ——揭示重放（walkable 保持 + 站捷径格软锁变体恢复移动可用）
	var run := _MakeQuestRun(&"q_lair_purge", 20)
	var screen: Control = await _OpenExplore(run)
	# 机制锚：遭遇路由经构造权重（真实表 chance 0——拍板关闭随机战斗）
	screen._encw_by_region[&"reg_mine"] = _ForceHitWeight()
	# 成功检定（首骰 ≥12——感知 20 调值 +5 ≥ 极难线 17）
	var success_seed: int = -1
	for seed_value: int in range(10000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randi_range(1, 20) >= 12:
			success_seed = seed_value
			break
	run.party_pos = Vector2i(9, 4)
	run.visited_cells[Vector2i(9, 4)] = true
	screen._RefreshBoard()
	screen._rng.seed = success_seed
	screen._OnCellPressed(Vector2i(12, 4))
	await _WaitFrames(6)
	(screen._panel._options_box.get_child(0) as Button).pressed.emit()
	await _WaitFrames(2)
	var cast_buttons: Array = screen._panel._cast_box.get_children().filter(
			func(child: Node) -> bool: return child is Button)
	(cast_buttons[0] as Button).pressed.emit()
	screen._panel.skip_d20()
	await _WaitFrames(4)
	assert_bool(run.unlock_flags.has(&"secret_door_mine_north")).is_true()
	screen._panel._continue_button.pressed.emit()
	await _WaitFrames(2)
	assert_bool(screen._state.walkable(Vector2i(12, 5))).is_true()
	# 走捷径：新格 (11,4)(12,4) 未中、(12,5) 命中 → 站捷径格遭遇路由（软锁变体）
	var walk_seed: int = -1
	for seed_value: int in range(30000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() >= 0.04 and probe.randf() >= 0.04 and probe.randf() < 0.04:
			walk_seed = seed_value
			break
	screen._rng.seed = walk_seed
	screen._OnCellPressed(Vector2i(12, 7))
	await _WaitFrames(10)
	assert_bool(run.party_pos == Vector2i(12, 5)).is_true()
	var battle: Control = get_tree().root.find_child("BattleScreen", true, false) as Control
	assert_object(battle).is_not_null()
	battle.controller.abort_battle()
	# 胜利回屏：揭示重放（H2 核心）——站捷径格仍可通行 + 移动恢复
	screen = await _ResumeExplore(run, _MakeResult(BattleResult.ResultKind.VICTORY, 20, false),
			&"enc_m1_random_pack")
	assert_bool(screen._state.walkable(Vector2i(12, 5))).override_failure_message(
			"暗门捷径跨战斗丢失（H2）").is_true()
	assert_bool(run.party_pos == Vector2i(12, 5)).is_true()
	screen._OnCellPressed(Vector2i(12, 7))
	await _WaitFrames(8)
	assert_bool(run.party_pos == Vector2i(12, 7)).override_failure_message(
			"站捷径格软锁——回屏后移动不可用").is_true()

func test_m5_b_exit_chain_roundtrip_real_return_button() -> void:
	## M2/M3 缺口（X2-M2 + X2-M3）：链二 B 出口探索链端到端 + 真实返回按钮
	## 往返——ENTER 鬼火链 → 纯选择「列阵」→ 战前演出 → 进入战斗 → 路由
	## （battle_node_id 通道）→ 强制胜利 → battle._OnReturnPressed() → 回屏
	## post_battle 续跑（15/15 入账）
	var run := _MakeQuestRun(&"q_lair_purge")
	var screen: Control = await _OpenExplore(run)
	run.party_pos = Vector2i(3, 7)
	run.visited_cells[Vector2i(3, 7)] = true
	screen._RefreshBoard()
	screen._OnCellPressed(Vector2i(3, 8))
	await _WaitFrames(6)
	# 链入口选项视图 → 点「列阵戒备」（纯选择——无检定确定性）
	var formation_button: Button = null
	for child: Node in screen._panel._options_box.get_children():
		if child is Button and (child as Button).text.contains("列阵戒备"):
			formation_button = child
			break
	assert_object(formation_button).is_not_null()
	formation_button.pressed.emit()
	await _WaitFrames(2)
	# B 出口战前演出（先播再战）→ 路由战斗（battle_node_id 通道键）
	assert_bool(screen._panel._battle_button.visible).is_true()
	screen._panel._battle_button.pressed.emit()
	await _WaitFrames(4)
	var battle: Control = get_tree().current_scene as Control
	assert_object(battle).is_not_null()
	assert_str(String(battle._return_payload[&"battle_node_id"])).is_equal("evn_wisp_n3")
	assert_int(battle._return_to).is_equal(SCENE_EXPLORE)
	# 强制胜利（敌方预置全灭 + 我方自动结束行动轮 → 回合末判 VICTORY）
	battle.controller.delay_seconds = 0.0
	for enemy: BattleUnit in battle.context.enemies:
		enemy.current_hp = 0
		enemy.alive = false
	var waited: int = 0
	while not (battle.get_node("%ResultPanel") as Control).visible and waited < 300:
		# 敌方全灭后仅剩我方行动轮——指令窗即推进（连接时序无关的轮询驱动）
		if battle.controller.awaiting_command and battle.controller.current_unit != null \
				and battle.controller.current_unit.is_controllable():
			battle.controller.request_end_unit_turn()
		await get_tree().process_frame
		waited += 1
	assert_bool((battle.get_node("%ResultPanel") as Control).visible) \
			.override_failure_message("强制胜利未达结算面板（等 %d 帧）" % waited).is_true()
	# 真实返回按钮（X2-M3）：_OnReturnPressed → EXPLORE 回传续跑
	battle._OnReturnPressed()
	await _WaitFrames(6)
	var resumed: Control = get_tree().current_scene as Control
	assert_object(resumed).is_not_null()
	await _WaitFrames(4)
	assert_int(int(run.rewards[&"exp"])).is_equal(15)
	assert_int(int(run.rewards[&"gold"])).is_equal(15)
	# post_battle 结算视图回事件面板（继续钮可见——续跑）
	assert_bool(resumed._panel._continue_button.visible).is_true()
	# W5-4：B 出口战 = 剧情战不计入判据——战后 run.goal_done 保持 false
	assert_bool(run.goal_done).is_false()

func test_m5_all_downed_preintercept_no_side_effects() -> void:
	## X2-M2 缺口：全倒地前置拦截——路由拒绝即占位终结，无战斗挂载、
	## 消耗账零副作用（X3-09 回滚口径）
	var run := _MakeQuestRun(&"q_lair_purge")
	var screen: Control = await _OpenExplore(run)
	run.downed[run.party[0]] = true
	var routed: bool = screen._RouteEncounter(&"enc_m1_lair_pack", &"evp_mine_lair")
	assert_bool(routed).is_false()
	await _WaitFrames(2)
	assert_bool(screen.get_node("%SettlementPanel").visible).is_true()
	assert_str(screen.get_node("%SettlementBody").text).contains("全员倒地")
	assert_object(get_tree().root.find_child("BattleScreen", true, false)).is_null()
	assert_bool(run.consumed_events.has(&"evp_mine_lair")).is_false()

func test_m5_retreat_cancelled_does_not_finish() -> void:
	## X2-M2 缺口：撤退确认弹窗「继续探索」（cancelled）——会话不终结；
	## W2-11 注：真实交互点「继续探索」会先关窗再发 canceled——直发信号
	## 不关窗会撞板面点格闸门，此处同步关窗模拟完整取消链
	var run := _MakeQuestRun(&"q_lair_purge")
	var screen: Control = await _OpenExplore(run)
	(screen.get_node("%RetreatButton") as Button).pressed.emit()
	var dialog: ConfirmationDialog = screen.get_node("%RetreatConfirm") as ConfirmationDialog
	dialog.visible = false
	dialog.canceled.emit()
	await _WaitFrames(2)
	assert_bool(screen._finished).is_false()
	assert_bool(screen.get_node("%SettlementPanel").visible).is_false()
	# 会话仍可交互（移动可用）
	screen._OnCellPressed(Vector2i(7, 2))
	await _WaitFrames(8)
	assert_bool(run.party_pos == Vector2i(7, 2)).is_true()

func test_m5_exit_not_ready_hint() -> void:
	## X2-M2 缺口：出口未达成点按——提示「委托还没完成」且不弹结算
	var run := _MakeQuestRun(&"q_lair_purge")
	var screen: Control = await _OpenExplore(run)
	screen._OnCellPressed(Vector2i(7, 0))
	await _WaitFrames(2)
	assert_str(screen.get_node("%HintLabel").text).contains("委托还没完成")
	assert_bool(screen.get_node("%SettlementPanel").visible).is_false()

func test_l7_free_explore_session_deliverable() -> void:
	## L7（拍板）：自由探索（无委托）——出口直接可交付（成功通道文案
	## 「自由探索结束」；收获申报行保留——成功通道口径）
	var game_data: Node = _GameData()
	var cfg: CoreConfig = game_data.get_record(&"cfg_main") as CoreConfig
	var run := ExpeditionRun.new()
	var adv: AdventurerData = AdventurerData.create_debug(&"t", &"cls_warrior", {
		&"strength": 14, &"agility": 10, &"constitution": 14,
		&"intelligence": 7, &"perception": 15, &"willpower": 9, &"luck": 10}, game_data)
	run.party.append(adv)
	run.hp[adv] = 30
	run.start_explore(game_data.get_record(&"map_m1_village_mine") as ExploreMapDef,
			null, cfg.vision_radius)
	var screen: Control = await _OpenExplore(run)
	assert_bool(screen._ExitActive()).is_true()
	screen._OnCellPressed(Vector2i(7, 0))
	await _WaitFrames(2)
	assert_bool(screen.get_node("%SettlementPanel").visible).is_true()
	assert_str(screen.get_node("%SettlementTitle").text).contains("自由探索结束")
	assert_str(screen.get_node("%SettlementBody").text).contains("收获申报")
	(screen.get_node("%SettlementButton") as Button).pressed.emit()
	await _WaitFrames(4)
	assert_bool(get_tree().root.get_node("SaveManager")._expedition_lock).is_false()

func test_x3_02_board_fits_design_space_with_banner() -> void:
	## X3-02/X3-16：设计空间 1920×1080 下板面完整可见（含横幅出现重适配），
	## 缩放后热区实际 px ≥ 48；完整可见按 V-1 视觉占位矩形断言（visual_rect
	## ——rect 恒 design，实际画布 = rect × scale）
	var run := _MakeQuestRun(&"q_lost_miner_keepsake")
	var screen: Control = await _OpenExplore(run)
	await _WaitFrames(2)
	var board: ExploreBoard = screen._board
	var view_rect: Rect2 = get_viewport().get_visible_rect()
	var board_rect: Rect2 = board.visual_rect()
	assert_float(board_rect.end.y).is_less_equal(view_rect.end.y + 0.5)
	assert_float(board_rect.position.y).is_greater_equal(-0.5)
	assert_float(board_rect.end.x).is_less_equal(view_rect.end.x + 0.5)
	assert_float(board.effective_cell_size()).is_greater_equal(48.0)
	# 判据达成 → 横幅出现 → 宿主收窄重适配后仍完整可见
	run.goal_done = true
	screen._goal.restore_done(true)
	screen._RefreshStatus()
	await _WaitFrames(4)
	var refit_rect: Rect2 = board.visual_rect()
	assert_float(refit_rect.end.y).is_less_equal(view_rect.end.y + 0.5)
	assert_float(board.effective_cell_size()).is_greater_equal(48.0)

func test_x3_02_board_fit_math_reduced_and_capped() -> void:
	## X3-02 适配数学：窄空间等比恰好放入（不溢出）；超大空间上限 1.0 不放大
	## （720p 窗口语义 = 项目级 canvas_items stretch 全局等比——板面同口径，
	## 不单独承担窗口级 48px 保底——类头注释登记）；V-1 起「放入」按视觉
	## 占位（= rect × scale）断言，min 恒 design 不随 fit 收缩
	var run := _MakeQuestRun(&"q_lair_purge")
	var screen: Control = await _OpenExplore(run)
	await _WaitFrames(2)
	var board: ExploreBoard = screen._board
	board.fit_to(Vector2(1280, 508))
	assert_float(board.scale.y).is_equal_approx(508.0 / 900.0, 0.001)
	assert_float(board.custom_minimum_size.y).is_equal(900.0) \
			.override_failure_message("V-1：custom_minimum_size 应恒为 design 不随 fit 收缩")
	var visual: Rect2 = board.visual_rect()
	assert_float(visual.size.y).is_less_equal(508.5)
	assert_float(visual.size.x).is_less_equal(508.5)
	board.fit_to(Vector2(4096, 4096))
	assert_float(board.scale.x).is_equal(1.0)
	assert_float(board.effective_cell_size()).is_equal(60.0)

func test_v1_fit_scaled_bottom_row_click_hits_cell() -> void:
	## V-1（2026-09-26 审计①修复回归锚）：fit<1 强制缩放下命中区 == 视觉区
	## ——修复前 custom_minimum_size 随 fit 同缩，命中区 = 视觉 × fit，板面
	## 底/右缘视觉带点击穿透；三重断言：命中矩形恒等视觉矩形（矩形级）+
	## 底部行末格视觉中心点在命中区内且反解命中该格（坐标级）+ gui_input
	## 派发 cell_pressed 正确上报（信号级）
	var run := _MakeQuestRun(&"q_lair_purge")
	var screen: Control = await _OpenExplore(run)
	await _WaitFrames(2)
	var board: ExploreBoard = screen._board
	board.fit_to(Vector2(600.0, 360.0))
	assert_float(board.scale.x).is_less(1.0)
	# 契约一（矩形级）：命中矩形（全局变换 × 控件 rect）恒等视觉矩形
	# （全局变换 × 设计内容矩形）——修复前 rect 被缩至 design×fit 故不等
	var visual: Rect2 = board.visual_rect()
	var hit: Rect2 = board.get_global_transform() * Rect2(Vector2.ZERO, board.size)
	assert_bool(hit.size.is_equal_approx(visual.size)).is_true() \
			.override_failure_message("V-1：命中区应与视觉区严格一致")
	# 契约二（坐标级）：底部行末格视觉中心点落命中区内且反解命中该格
	var last_cell: Vector2i = board._map_def.size - Vector2i.ONE
	var point: Vector2 = visual.position \
			+ (Vector2(last_cell) + Vector2.ONE * 0.5) * board.effective_cell_size()
	assert_bool(hit.has_point(point)).is_true() \
			.override_failure_message("V-1：底部行末格视觉中心应可命中（不穿透）")
	var local: Vector2 = board.get_global_transform().affine_inverse() * point
	assert_vector(board.cell_from_local(local)).is_equal(last_cell)
	# 契约三（信号级）：gui_input 派发（本地坐标）→ cell_pressed 上报底部行格
	var emitted: Array[Vector2i] = []
	var collector: Callable = func(cell: Vector2i) -> void: emitted.append(cell)
	board.cell_pressed.connect(collector)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = local
	board._gui_input(event)
	board.cell_pressed.disconnect(collector)
	assert_int(emitted.size()).is_equal(1)
	assert_vector(emitted[0]).is_equal(last_cell)

# --------------------------------------------------------------------------
# 第四轮审计中危补测（2026-09-26：W2-2 单点 B 出口锚点 / W2-14 空 post_battle）
# --------------------------------------------------------------------------

func _ResumeExploreWithNode(run: ExpeditionRun, result: BattleResult,
		battle_node_id: StringName, event_id: StringName) -> Control:
	## 以 B 出口锚点通道挂载探索屏（W2-2 单点锚点测试专用——battle_node_id
	## 直传 sp_/evn_ 锚，事件 id 同步回带）
	## 参数 run：出征运行态；result：战斗结果；battle_node_id/event_id：锚点
	## 返回：探索屏根节点
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	var payload: Dictionary = {
		&"expedition_run": run,
		&"battle_result": result,
		&"event_id": event_id,
		&"battle_node_id": battle_node_id,
		&"encounter_pack_id": &"",
	}
	assert_int(scene_manager.go(SCENE_EXPLORE, payload)).is_equal(OK)
	await _WaitFrames(6)
	var screen: Control = get_tree().current_scene as Control
	assert_object(screen).is_not_null()
	screen.step_seconds_override = 0.0
	screen._rng.seed = _SafeEncounterSeed()
	return screen

func test_w22_single_point_b_exit_settles_post_battle() -> void:
	## W2-2：单点 B 出口战胜回屏——锚点 sp_ id 解析 SingleEventDef 的
	## success_outcome.battle.post_battle 结算入账（修复前按 EventNodeDef 查
	## 恒 null 即静默丢结算）；数据构造 + 测后还原
	var game_data: Node = _GameData()
	var single: SingleEventDef = game_data.get_record(&"sp_village_traveler") as SingleEventDef
	var original_outcome: EventOutcomeDef = single.success_outcome
	# 构造单点 B 出口：battle（pack 引用闭环）+ post_battle（A 型 7/8/1 奖励）
	var post := EventOutcomeDef.new()
	post.exit_kind = EventOutcomeDef.ExitKind.A
	post.reward = RewardDef.new()
	post.reward.exp = 7
	post.reward.gold = 8
	post.reward.reputation = 1
	post.texts = {&"success": "旅人目送你们离开。", &"failure": ""}
	var opening := BattleOpeningDef.new()
	opening.pack_id = &"enc_m1_random_pack"
	opening.post_battle = post
	var outcome_b := EventOutcomeDef.new()
	outcome_b.exit_kind = EventOutcomeDef.ExitKind.B
	outcome_b.battle = opening
	outcome_b.texts = {&"success": "旅人拦住了去路。", &"failure": ""}
	single.success_outcome = outcome_b
	var run := _MakeQuestRun(&"q_lair_purge")
	var screen: Control = await _ResumeExploreWithNode(run,
			_MakeResult(BattleResult.ResultKind.VICTORY, 20, false),
			&"sp_village_traveler", &"sp_village_traveler")
	# 立即还原注入（gdUnit 断言失败不中断——还原代码必达，不污染共享缓存）
	single.success_outcome = original_outcome
	assert_int(int(run.rewards[&"exp"])).is_equal(7)
	assert_int(int(run.rewards[&"gold"])).is_equal(8)
	assert_int(int(run.rewards[&"reputation"])).is_equal(1)
	# 结算视图回事件面板（继续钮呈现——续跑可继续）
	assert_bool(screen._panel._continue_button.visible).is_true()
	assert_bool(screen._event_open).is_true()
	assert_bool(screen._finished).is_false()
	# B 出口战 = 剧情战不计入判据（CLEAR 判据参数 enc_m1_lair_pack ≠ 战斗 pack）
	assert_bool(run.goal_done).is_false()

func test_w214_missing_post_battle_skips_panel_and_continues() -> void:
	## W2-14：B 出口锚点缺 post_battle（含单点构造与链查无）——跳过结算面板
	## 直接刷新（可继续操作不软锁），仅 push_warning 可感知
	var game_data: Node = _GameData()
	var single: SingleEventDef = game_data.get_record(&"sp_village_traveler") as SingleEventDef
	var original_outcome: EventOutcomeDef = single.success_outcome
	var opening := BattleOpeningDef.new()
	opening.pack_id = &"enc_m1_random_pack"
	var outcome_b := EventOutcomeDef.new()
	outcome_b.exit_kind = EventOutcomeDef.ExitKind.B
	outcome_b.battle = opening
	outcome_b.texts = {&"success": "旅人拦住了去路。", &"failure": ""}
	single.success_outcome = outcome_b
	var run := _MakeQuestRun(&"q_lair_purge")
	var screen: Control = await _ResumeExploreWithNode(run,
			_MakeResult(BattleResult.ResultKind.VICTORY, 20, false),
			&"sp_village_traveler", &"sp_village_traveler")
	single.success_outcome = original_outcome
	# 无结算面板弹出、无事件占用、会话未终结——板面输入闸门全开
	assert_bool(screen._panel._continue_button.visible).is_false()
	assert_bool(screen._event_open).is_false()
	assert_bool(screen._finished).is_false()
	assert_bool(screen.get_node("%SettlementPanel").visible).is_false()
	# 会话可继续（点格移动可用——不软锁）
	screen._OnCellPressed(Vector2i(7, 2))
	await _WaitFrames(8)
	assert_bool(run.party_pos == Vector2i(7, 2)).is_true()
