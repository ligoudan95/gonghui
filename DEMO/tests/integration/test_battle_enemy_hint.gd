## 敌方行动提示行集成测试（拍板 C 2026-10-01）
## 覆盖：敌方单位 turn_started → 日志栏上方提示行可见且文案正确；轮到我方
## 单位 → 隐藏；battle_ended → 隐藏（提示亮起态直接以真实信号触发终局——
## 确证清除来自 battle_ended 处理而非上一轮次翻转）。
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
## 提示行文案锚点（与 battle_screen.UI_TEXTS.enemy_turn_hint 同值——改文案
## 两处同步）
const HINT_TEXT: String = "敌方行动中…（点按战场可跳过演出）"

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
	## _EnterRandomBattle 的定种子口径——提示行断言不依赖具体单位，仅求
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

func test_enemy_turn_hint_shows_and_clears_by_turn_owner() -> void:
	## 提示行随行动单位切换：敌方轮可见 + 文案正确；我方轮隐藏（快照在
	## turn_started 监听内读取——连接时序保证读到刷新后状态）
	await _EnterBattle()
	var battle: Control = _FindBattleScreen()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var hint: Label = battle.get_node("%EnemyTurnHint") as Label
	assert_object(hint).is_not_null()
	var snap: Dictionary = {}
	battle.controller.turn_started.connect(func(unit: BattleUnit) -> void:
		if unit.side == SkillDef.SkillSide.ENEMY:
			snap[&"enemy_visible"] = hint.visible
			snap[&"enemy_text"] = hint.text
		elif unit.is_controllable():
			snap[&"ally_visible"] = hint.visible)
	var waited: int = 0
	while (not snap.has(&"enemy_visible") or not snap.has(&"ally_visible")) \
			and waited < MAX_WAIT_FRAMES:
		if battle.controller.awaiting_command:
			battle.controller.request_end_unit_turn()
		await get_tree().process_frame
		waited += 1
	assert_bool(snap.has(&"enemy_visible")) \
			.override_failure_message("未等到敌方行动轮").is_true()
	assert_bool(snap.has(&"ally_visible")) \
			.override_failure_message("未等到我方行动轮").is_true()
	assert_bool(snap[&"enemy_visible"]).is_true()
	assert_str(snap[&"enemy_text"]).is_equal(HINT_TEXT)
	assert_bool(snap[&"ally_visible"]).is_false()
	battle.controller.abort_battle()

func test_enemy_turn_hint_cleared_on_battle_end() -> void:
	## 终局清除：敌方提示亮起态下以真实 battle_ended 信号触发终局（撤退口径
	## 最小 BattleResult）→ 提示行立即隐藏——确证清除来自 battle_ended 处理；
	## 先 abort_battle 停状态机防后续轮次翻转提示干扰判定
	await _EnterBattle()
	var battle: Control = _FindBattleScreen()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var hint: Label = battle.get_node("%EnemyTurnHint") as Label
	var snap: Dictionary = {}
	battle.controller.turn_started.connect(func(unit: BattleUnit) -> void:
		if unit.side != SkillDef.SkillSide.ENEMY or snap.has(&"done"):
			return
		snap[&"visible_before_end"] = hint.visible
		snap[&"done"] = true
		battle.controller.abort_battle()
		var result := BattleResult.new()
		result.kind = BattleResult.ResultKind.RETREAT
		result.rounds_used = 1
		battle.controller.battle_ended.emit(result)
		snap[&"visible_after_end"] = hint.visible)
	var waited: int = 0
	while not snap.has(&"done") and waited < MAX_WAIT_FRAMES:
		if battle.controller.awaiting_command:
			battle.controller.request_end_unit_turn()
		await get_tree().process_frame
		waited += 1
	assert_bool(snap.has(&"done")).override_failure_message("未等到敌方行动轮").is_true()
	assert_bool(snap[&"visible_before_end"]).is_true()
	assert_bool(snap[&"visible_after_end"]).is_false()
