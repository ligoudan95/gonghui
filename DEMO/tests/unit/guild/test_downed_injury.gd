## 倒地者回城转重伤测试（功能二批 3——Q-A 拍板：单漏斗四出口统一 +
## 恒弹增强文案）
## 覆盖：四出口矩阵（SUCCESS 带倒地转换+经验照入账 / RETREAT 战斗撤退带
## 倒地 / RETREAT 自由探索撤退带倒地 / DEFEAT 全员等价回归）、无倒地
## RETREAT 零重伤（P1 回归）、宿舍 Lv2 缩减、幂等重复 settle、补结算期
## 恢复 remaining 归 0、演示会话门、result_panel 文案分流、撤退弹窗
## 动态文案（有倒地增强/无倒地原文案不变）。
## 环境：逻辑组本地 GameData 实例；UI 组真 autoload + 场景挂载。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## 探索场景路径（UI 组挂载）
const EXPLORE_SCENE: String = "res://scenes/explore/explore_screen.tscn"
## 场景 id（SceneManager：GUILD_SHELL=1 / EXPLORE_SCREEN=3）
const SCENE_GUILD_SHELL: int = 1
const SCENE_EXPLORE: int = 3
## RetreatConfirm tscn 静态文案（无倒地「完全不变」锚定——与
## explore_screen.tscn 逐字一致）
const RETREAT_CONFIRM_STATIC: String = "撤退 = 委托失败（本次出征进度不保留、队伍不会重伤，途中所得将丢弃）。确定撤退吗？"

## 用例级 GameData / GuildCore
var _game_data: Node
var _core: GuildCore

func before_test() -> void:
	## 用例前置：GameData 实例 + 公会核心建档
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()
	_core = GuildCore.new()
	_core.setup(_Cfg(), _game_data, _MakeRng(303))

func _Cfg() -> CoreConfig:
	## 总控配置读取口
	## 参数：无
	## 返回：CoreConfig
	return _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig

func _MakeRng(seed_value: int) -> RandomNumberGenerator:
	## 固定种子随机源
	## 参数 seed_value：种子
	## 返回：RandomNumberGenerator
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _SpawnAndStart(template_id: StringName, party_count: int) -> QuestInstance:
	## 装配并出征指定模板委托（板清空后定点生成）
	## 参数 template_id/party_count：模板 / 人数
	## 返回：QuestInstance
	var inst: QuestInstance = _core.board.spawn_on_board(template_id, 1)
	var party: Array[StringName] = []
	for index: int in party_count:
		party.append(_core.roster[index].unit_id)
	assert_bool(_core.accept_quest(inst.serial, party)).is_true()
	assert_bool(_core.start_expedition(inst.serial)).is_true()
	return inst

func _MakeRun(template_id: StringName, party_count: int,
		mark_downed_indexes: Array[int] = []) -> ExpeditionRun:
	## 构建出征会话（mark_downed_indexes 指定倒地成员下标）
	## 参数 template_id/party_count/mark_downed_indexes：模板 / 人数 / 倒地下标
	## 返回：ExpeditionRun
	var run := ExpeditionRun.new()
	run.base_days = 1
	for index: int in party_count:
		run.party.append(_core.roster[index])
	run.quest_template_id = template_id
	if template_id != &"":
		var tpl: QuestTemplateDef = _game_data.get_record(template_id) as QuestTemplateDef
		if tpl != null:
			run.goal_kind = tpl.goal_type
			run.goal_param = tpl.goal_param
	for index: int in mark_downed_indexes:
		run.downed[run.party[index]] = true
	return run

# --------------------------------------------------------------------------
# 四出口矩阵（逻辑层）
# --------------------------------------------------------------------------

func test_success_with_downed_converts_and_pays_exp() -> void:
	## SUCCESS 带倒地：倒地者 → RESTING 3 天（宿舍 Lv1 基础）；存活者
	## HEALTHY；倒地者经验照常入账（奖励不受转换影响）
	_SpawnAndStart(&"q_lair_purge", 3)
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(
			_MakeRun(&"q_lair_purge", 3, [0]), GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(summary.injury_member_count).is_equal(1)
	assert_int(summary.injury_rest_days).is_equal(3)
	assert_int(_core.roster[0].status).is_equal(AdventurerData.Status.RESTING)
	assert_int(_core.roster[0].rest_days).is_equal(2)
	assert_int(_core.roster[1].status).is_equal(AdventurerData.Status.HEALTHY)
	assert_int(_core.roster[2].status).is_equal(AdventurerData.Status.HEALTHY)
	# 倒地者经验照入账（与存活者同额）
	assert_int(_core.roster[0].exp).is_equal(_core.roster[1].exp)
	assert_int(_core.roster[0].exp).is_greater(0)

func test_battle_retreat_with_downed_converts() -> void:
	## RETREAT（战斗撤退）带倒地：倒地者转换（P1 修订 Q8 表述——有倒地
	## 必转）、无倒地者不动、零奖励
	_SpawnAndStart(&"q_lair_purge", 3)
	var gold_before: int = _core.gold
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(
			_MakeRun(&"q_lair_purge", 3, [1, 2]), GuildCore.ExpeditionOutcome.RETREAT)
	assert_int(_core.gold).is_equal(gold_before)
	assert_int(summary.injury_member_count).is_equal(2)
	assert_int(_core.roster[0].status).is_equal(AdventurerData.Status.HEALTHY)
	assert_int(_core.roster[1].status).is_equal(AdventurerData.Status.RESTING)
	assert_int(_core.roster[2].status).is_equal(AdventurerData.Status.RESTING)

func test_free_retreat_with_downed_converts() -> void:
	## RETREAT（自由探索撤退——无委托会话）带倒地：同漏斗转换
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(
			_MakeRun(&"", 2, [0]), GuildCore.ExpeditionOutcome.RETREAT)
	assert_int(summary.injury_member_count).is_equal(1)
	assert_int(_core.roster[0].status).is_equal(AdventurerData.Status.RESTING)
	assert_int(_core.roster[1].status).is_equal(AdventurerData.Status.HEALTHY)

func test_defeat_all_downed_equivalence() -> void:
	## DEFEAT 全员倒地：逐位转换 == 原全队口径（等价现状回归）
	_SpawnAndStart(&"q_lair_purge", 3)
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(
			_MakeRun(&"q_lair_purge", 3, [0, 1, 2]), GuildCore.ExpeditionOutcome.DEFEAT)
	assert_int(summary.injury_member_count).is_equal(3)
	for index: int in 3:
		assert_int(_core.roster[index].status).is_equal(AdventurerData.Status.RESTING)

func test_retreat_no_downed_zero_injury() -> void:
	## P1 回归锚定：无倒地 RETREAT 零重伤——无人 RESTING、摘要不出行
	_SpawnAndStart(&"q_lair_purge", 3)
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(
			_MakeRun(&"q_lair_purge", 3), GuildCore.ExpeditionOutcome.RETREAT)
	assert_int(summary.injury_member_count).is_equal(0)
	assert_int(summary.injury_rest_days).is_equal(0)
	assert_int(summary.injury_rest_days_remaining).is_equal(0)
	for index: int in 3:
		assert_int(_core.roster[index].status).is_equal(AdventurerData.Status.HEALTHY)

func test_dormitory_lv2_shortens_injury() -> void:
	## 宿舍 Lv2 缩减通道：升级 → injury_rest_days 2 → 倒地者休养 2 天
	_core.gold = 1000
	assert_bool(_core.upgrade_facility(&"fac_dormitory")).is_true()
	_SpawnAndStart(&"q_lair_purge", 3)
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(
			_MakeRun(&"q_lair_purge", 2, [0]), GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(summary.injury_rest_days).is_equal(2)
	assert_int(_core.roster[0].rest_days).is_equal(1)

func test_idempotent_resettle_no_side_effects() -> void:
	## 幂等：run.settled 早退在转换前——二次 settle（核心层直调）返回空摘要
	## 且零副作用（GuildState 层缓存口径由 test_guild_save_roundtrip 的 S5-05
	## 用例锚定；本套件测核心层语义）
	_SpawnAndStart(&"q_lair_purge", 3)
	var run := _MakeRun(&"q_lair_purge", 3, [0])
	var first: GuildCore.ExpeditionSummary = _core.settle_expedition(run,
			GuildCore.ExpeditionOutcome.RETREAT)
	assert_int(first.injury_member_count).is_equal(1)
	var rest_after_first: int = _core.roster[0].rest_days
	var second: GuildCore.ExpeditionSummary = _core.settle_expedition(run,
			GuildCore.ExpeditionOutcome.SUCCESS)
	# 核心层幂等：空摘要（不重复转换/入账）+ 名册零副作用
	assert_int(second.injury_member_count).is_equal(0)
	assert_int(second.gold_gained).is_equal(0)
	assert_int(_core.roster[0].rest_days).is_equal(rest_after_first)

func test_remaining_zero_when_recovered_during_catchup() -> void:
	## M-1 口径：长途出征补结算期恢复归 0——remaining 不出行（逻辑不变）
	_SpawnAndStart(&"q_lair_purge", 3)
	var run := _MakeRun(&"q_lair_purge", 3, [0, 1, 2])
	run.base_days = 3
	var summary: GuildCore.ExpeditionSummary = _core.settle_expedition(run,
			GuildCore.ExpeditionOutcome.DEFEAT)
	assert_int(summary.injury_rest_days).is_equal(3)
	assert_int(summary.injury_rest_days_remaining).is_equal(0)

func test_demo_session_gate_unchanged() -> void:
	## 演示会话门回归：quest_serial=0 且队长不在名册 → is_demo_session true
	##（探索层 _SettleWithDemoSession 占位回退跳过公会结算不转换——现状维持）
	var game_data: Node = get_tree().root.get_node("GameData")
	var demo_run := ExpeditionRun.new()
	var stranger: AdventurerData = AdventurerData.create_debug(&"t",
			&"cls_warrior", {}, game_data)
	demo_run.party.append(stranger)
	assert_bool(GuildCore.is_demo_session(demo_run, _core)).is_true()

# --------------------------------------------------------------------------
# UI 组：result_panel 文案分流 + 撤退弹窗动态文案
# --------------------------------------------------------------------------

func _MakeResult(kind: int) -> BattleResult:
	## 构造战斗结果（无倒地名单——面板名单走第 4 参）
	## 参数 kind：ResultKind
	## 返回：BattleResult
	var result := BattleResult.new()
	result.kind = kind
	result.rounds_used = 3
	return result

func test_result_panel_copy_branching() -> void:
	## result_panel 文案分流：RETREAT 0 人=现状「不会重伤」；RETREAT >0 人=
	## 转重伤分流；VICTORY 追加倒地行
	var panel := ResultPanel.new()
	add_child(panel)
	auto_free(panel)
	var names_two: Array[String] = ["甲", "乙"]
	panel.show_result(_MakeResult(BattleResult.ResultKind.RETREAT))
	assert_str(panel._detail_label.text).contains("委托按失败结算，队伍不会重伤。")
	panel.show_result(_MakeResult(BattleResult.ResultKind.RETREAT), Callable(),
			null, names_two)
	assert_str(panel._detail_label.text).contains("倒地的 2 名队员回城将转重伤休养")
	assert_bool(panel._detail_label.text.contains("不会重伤")).is_false()
	panel.show_result(_MakeResult(BattleResult.ResultKind.VICTORY))
	assert_bool(panel._detail_label.text.contains("倒地——回城将转重伤休养")).is_false()
	panel.show_result(_MakeResult(BattleResult.ResultKind.VICTORY), Callable(),
			null, ["甲"])
	assert_str(panel._detail_label.text).contains("1 名队员倒地——回城将转重伤休养。")

func test_retreat_confirm_dynamic_text_with_and_without_downed() -> void:
	## 撤退弹窗动态文案：有倒地=增强（名单+天数）；无倒地=tscn 静态文案
	## 完全不变（逐字锚定）
	var guild_state: Node = get_tree().root.get_node("GuildState")
	guild_state.core = GuildCore.new()
	guild_state.new_game()
	var run := ExpeditionRun.new()
	run.base_days = 1
	var adv: AdventurerData = guild_state.core.roster[0]
	run.party.append(adv)
	run.hp[adv] = 30
	var map_def: ExploreMapDef = get_tree().root.get_node("GameData").get_record(
			&"map_m1_village_mine") as ExploreMapDef
	run.start_explore(map_def, null, 3)
	var scene_manager: Node = get_tree().root.get_node("SceneManager")
	assert_int(scene_manager.go(SCENE_EXPLORE, {&"expedition_run": run})).is_equal(OK)
	for _i: int in 4:
		await get_tree().process_frame
	var screen: Control = get_tree().current_scene as Control
	# 无倒地：静态文案逐字不变
	screen._OnRetreatPressed()
	assert_str(String(screen.get_node("%RetreatConfirm").dialog_text)) \
			.is_equal(RETREAT_CONFIRM_STATIC)
	# 有倒地：动态注入名单+天数（Lv1 基础 3 天）
	run.downed[adv] = true
	screen._OnRetreatPressed()
	var dynamic_text: String = String(screen.get_node("%RetreatConfirm").dialog_text)
	assert_str(dynamic_text).contains("1 名队员倒地")
	assert_str(dynamic_text).contains(adv.display_name)
	assert_str(dynamic_text).contains("休养 3 天")
	assert_bool(dynamic_text == RETREAT_CONFIRM_STATIC).is_false()
