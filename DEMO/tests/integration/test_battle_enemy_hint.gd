## 敌方行动提示集成测试（拍板 C 2026-10-01；布局三改批 2026-10-09 断言目标
## 改日志卷轴锚点条——敌方提示随右栏退役并入 BattleLogScroller）
## 覆盖：敌方单位 turn_started → 卷轴锚点条文案切提示语；轮到我方单位 →
## 恢复「战斗日志 (N)」格式；battle_ended → 恢复（提示语亮起态直接以真实
## 信号触发终局——确证恢复来自 battle_ended 处理而非上一轮次翻转）。
## 环境口径：test_battle_ui_flow 同式——SceneManager 直构参数进战斗屏，
## 快照在 turn_started 监听内读取（战斗屏 _OnTurnStarted 于 _ready 先连接，
## 本套件后连接——读到的是刷新后状态）。
extends GdUnitTestSuite

## 场景路径
const BATTLE_SCENE: String = "res://scenes/battle/battle_screen.tscn"
## SceneId.BATTLE_SCREEN（B-22：直构参数进战斗屏）
const SCENE_BATTLE: int = 2
## 信号等待帧上限（超时防死等）
const MAX_WAIT_FRAMES: int = 300
## 提示语文案锚点（与 BattleLogScroller.UI_TEXTS.enemy_turn_hint 同值——
## 改文案两处同步）
const HINT_TEXT: String = "敌方行动中…（点按战场可跳过演出）"
## 常态锚点文案前缀（「战斗日志 (N)」格式——N = 未读计数）
const LOG_PREFIX: String = "战斗日志 ("

func before_test() -> void:
	## 用例前置：复位 SceneManager 可变状态（autoload 归引擎管理不释放——
	## test_battle_ui_flow 同式）
	## 参数：无
	## 返回：无
	var scene_manager: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_object(scene_manager).is_not_null()
	scene_manager.current_id = -1
	scene_manager.previous_id = -1
	scene_manager.pending_params = {}
	scene_manager._switch_pending = false

func _EnterBattle() -> void:
	## 直构固定种子参数经 SceneManager 进 BATTLE_SCREEN（ui_flow.
	## _EnterRandomBattle 的定种子口径——锚点文案断言不依赖具体单位，仅求
	## 稳定推进）
	## 参数：无
	## 返回：无（协程——等场景切换落地）
	var game_data: Node = get_tree().root.get_node("GameData")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261001
	var party: Array[AdventurerData] = []
	for pair: Array in [[&"warrior", &"cls_warrior"], [&"rogue", &"cls_rogue"],
			[&"mage", &"cls_mage"], [&"priest", &"cls_priest"]]:
		var cls: ClassDef = game_data.get_record(pair[1]) as ClassDef
		var attrs: Dictionary[StringName, int] = AttrRoller.roll_fixed_four(cls, rng)
		party.append(AdventurerData.create_debug(pair[0], pair[1], attrs, game_data))
	var params := BattleParams.new()
	params.pack_id = &"enc_m1_random_pack"
	params.party = party
	params.rng = rng
	get_tree().root.get_node("SceneManager").go(SCENE_BATTLE,
			{&"battle_params": params})
	await get_tree().process_frame
	await get_tree().process_frame

func _FindBattleScreen() -> Control:
	## 取当前挂载的战斗屏根节点
	## 参数：无
	## 返回：BattleScreen（找不到为 null——由调用方断言）
	return get_tree().root.find_child("BattleScreen", true, false) as Control

func _AnchorTextOf(battle: Control) -> String:
	## 卷轴锚点条文案读取（布局三改批：敌方提示并入锚点条——断言目标）
	## 参数 battle：战斗屏根
	## 返回：AnchorLabel 当前文案
	return (battle.get_node("%AnchorLabel") as Label).text

func _IsLogFormat(text: String) -> bool:
	## 「战斗日志 (N)」格式判据（前缀 + 数字 + 右括号收尾）
	## 参数 text：待检文案
	## 返回：true = 常态日志文案
	return text.begins_with(LOG_PREFIX) and text.ends_with(")")

func test_enemy_turn_hint_shows_and_clears_by_turn_owner() -> void:
	## 锚点文案随行动单位切换：敌方轮显提示语；我方轮恢复「战斗日志 (N)」
	## 格式（快照在 turn_started 监听内读取——连接时序保证读到刷新后状态）
	await _EnterBattle()
	var battle: Control = _FindBattleScreen()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	assert_object(battle.get_node_or_null("%LogScroller")).is_not_null()
	var snap: Dictionary = {}
	battle.controller.turn_started.connect(func(unit: BattleUnit) -> void:
		if unit.side == SkillDef.SkillSide.ENEMY:
			snap[&"enemy_text"] = _AnchorTextOf(battle)
		elif unit.is_controllable():
			snap[&"ally_text"] = _AnchorTextOf(battle))
	var waited: int = 0
	while (not snap.has(&"enemy_text") or not snap.has(&"ally_text")) \
			and waited < MAX_WAIT_FRAMES:
		if battle.controller.awaiting_command:
			battle.controller.request_end_unit_turn()
		await get_tree().process_frame
		waited += 1
	assert_bool(snap.has(&"enemy_text")) \
			.override_failure_message("未等到敌方行动轮").is_true()
	assert_bool(snap.has(&"ally_text")) \
			.override_failure_message("未等到我方行动轮").is_true()
	assert_str(snap[&"enemy_text"]).is_equal(HINT_TEXT)
	assert_bool(_IsLogFormat(snap[&"ally_text"])) \
			.override_failure_message("我方轮锚点应恢复「战斗日志 (N)」格式（实际 %s）" % snap[&"ally_text"]).is_true()
	battle.controller.abort_battle()

func test_enemy_turn_hint_cleared_on_battle_end() -> void:
	## 终局恢复：提示语亮起态下以真实 battle_ended 信号触发终局（撤退口径
	## 最小 BattleResult）→ 锚点恢复「战斗日志 (N)」格式——确证恢复来自
	## battle_ended 处理；先 abort_battle 停状态机防后续轮次翻转提示干扰判定
	await _EnterBattle()
	var battle: Control = _FindBattleScreen()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var snap: Dictionary = {}
	battle.controller.turn_started.connect(func(unit: BattleUnit) -> void:
		if unit.side != SkillDef.SkillSide.ENEMY or snap.has(&"done"):
			return
		snap[&"text_before_end"] = _AnchorTextOf(battle)
		snap[&"done"] = true
		battle.controller.abort_battle()
		var result := BattleResult.new()
		result.kind = BattleResult.ResultKind.RETREAT
		result.rounds_used = 1
		battle.controller.battle_ended.emit(result)
		snap[&"text_after_end"] = _AnchorTextOf(battle))
	var waited: int = 0
	while not snap.has(&"done") and waited < MAX_WAIT_FRAMES:
		if battle.controller.awaiting_command:
			battle.controller.request_end_unit_turn()
		await get_tree().process_frame
		waited += 1
	assert_bool(snap.has(&"done")).override_failure_message("未等到敌方行动轮").is_true()
	assert_str(snap[&"text_before_end"]).is_equal(HINT_TEXT)
	assert_bool(_IsLogFormat(snap[&"text_after_end"])) \
			.override_failure_message("终局锚点应恢复「战斗日志 (N)」格式（实际 %s）" % snap[&"text_after_end"]).is_true()
