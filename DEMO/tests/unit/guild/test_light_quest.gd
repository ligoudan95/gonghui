## 轻度委托单元测试（M4 增补批 1——测试先行）
## 覆盖：板刷池 11/一步开工状态迁移/门面校验五组/G-2 同模板拦截/战斗名额
## 互不影响/占用互斥/工期推进+自动结算（数值精度 69/35/声望不吃超额）/周刷新
## 照常推进/**挂单到期不误伤 LIGHT_RUNNING**/放弃三态/出征补结算跨日推进+幂等/
## 锁定（reassign/start 拒）/板凳分享（拍板①：Lv1=9、Lv2=12、基数不含超额）/
## v3 roundtrip（work_days_left 必填反转）。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 与 GuildCore
var _game_data: Node
var _core: GuildCore

func before_test() -> void:
	## 用例级前置：GameData 实例 + 固定种子核心
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()
	_core = GuildCore.new()
	_core.setup(_Cfg(), _game_data, _MakeRng(301))

func after_test() -> void:
	## 用例级后置：释放 GameData
	_game_data.free()

func _Cfg() -> CoreConfig:
	## 总控配置读取口
	return _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig

func _MakeRng(seed_value: int) -> RandomNumberGenerator:
	## 固定种子随机源
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _RosterIds(count: int) -> Array[StringName]:
	## 名册前 N 人 id
	var ids: Array[StringName] = []
	for index: int in count:
		ids.append(_core.roster[index].unit_id)
	return ids

func _StartLight(template_id: StringName, party_count: int) -> QuestInstance:
	## 定点生成并开工一个轻度委托（板清空后生成——确定性）
	_core.board.board.clear()
	var inst: QuestInstance = _core.board.spawn_on_board(template_id, _core.day)
	assert_bool(_core.start_light_quest(inst.serial, _RosterIds(party_count))).is_true()
	return inst

func test_board_pool_contains_eleven() -> void:
	## ①板刷池 11（8 战斗+3 轻度混刷）
	var board_ids: Array[StringName] = _core.board.board_template_ids()
	assert_int(board_ids.size()).is_equal(11)
	var light_ids: Array[StringName] = [
			&"q_chore_supply_run",
			&"q_chore_tavern_help",
			&"q_chore_messenger",
	]
	for light_id: StringName in light_ids:
		assert_bool(board_ids.has(light_id)).is_true()

func test_start_light_state_migration() -> void:
	## ②一步开工：ACCEPTED→LIGHT_RUNNING、work_days_left=工期、占用就位、
	## 沿用编队记忆、板上移除、不落 last_expedition_day（不占出征额度）
	var inst: QuestInstance = _StartLight(&"q_chore_supply_run", 1)
	assert_int(inst.state).is_equal(QuestInstance.State.LIGHT_RUNNING)
	assert_int(inst.work_days_left).is_equal(2)
	assert_int(_core.board.find_on_board(inst.serial) != null).is_equal(false) \
			if false else assert_bool(_core.board.find_on_board(inst.serial) == null).is_true()
	assert_int(_core.board.occupied_member_ids().size()).is_equal(1)
	assert_int(_core.board.in_progress_count()).is_equal(0)
	assert_int(_core.last_party_by_tpl.size()).is_equal(1)
	assert_int(_core.roster[0].last_expedition_day).is_equal(0)
	# 不消耗每日一次：成员当日仍可出征（战斗通道照常受理）
	var battle: QuestInstance = _core.board.spawn_on_board(&"q_lair_purge", _core.day)
	var party: Array[StringName] = [_core.roster[1].unit_id, _core.roster[2].unit_id,
			_core.roster[3].unit_id]
	assert_bool(_core.accept_quest(battle.serial, party)).is_true()
	assert_bool(_core.start_expedition(battle.serial)).is_true()

func test_start_light_guards() -> void:
	## ③门面校验：人数 0 拒/人数 3 拒/休养拒/占用拒/战斗模板走本口拒/
	## accept_quest 轻度模板拒（防误路由滞留 ACCEPTED）
	_core.board.board.clear()
	var inst: QuestInstance = _core.board.spawn_on_board(&"q_chore_supply_run", _core.day)
	assert_bool(_core.start_light_quest(inst.serial, [])).is_false()
	assert_str(_core.last_error).contains("区间")
	assert_bool(_core.start_light_quest(inst.serial, _RosterIds(3))).is_false()
	assert_str(_core.last_error).contains("区间")
	# 休养拒
	_core.roster[0].status = AdventurerData.Status.RESTING
	_core.roster[0].rest_days = 1
	assert_bool(_core.start_light_quest(inst.serial, [_core.roster[0].unit_id])).is_false()
	assert_str(_core.last_error).contains("非健康态")
	_core.roster[0].status = AdventurerData.Status.HEALTHY
	_core.roster[0].rest_days = 0
	# 占用拒（先开工一个再用其成员）
	var first: QuestInstance = _StartLight(&"q_chore_tavern_help", 1)
	_core.board.board.clear()
	var second: QuestInstance = _core.board.spawn_on_board(&"q_chore_supply_run", _core.day)
	assert_bool(_core.start_light_quest(second.serial, [_core.roster[0].unit_id])).is_false()
	assert_str(_core.last_error).contains("占用")
	# 战斗模板走本口拒
	var battle: QuestInstance = _core.board.spawn_on_board(&"q_lair_purge", _core.day)
	assert_bool(_core.start_light_quest(battle.serial, [_core.roster[1].unit_id])).is_false()
	assert_str(_core.last_error).contains("战斗委托")
	# accept_quest 轻度模板拒
	assert_bool(_core.accept_quest(second.serial, [_core.roster[1].unit_id])).is_false()
	assert_str(_core.last_error).contains("轻度")
	assert_int(second.state).is_equal(QuestInstance.State.ON_BOARD)
	# 轻度成员不可编入其他委托（占用互斥⑥）
	var other: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", _core.day)
	assert_bool(_core.accept_quest(other.serial, [_core.roster[0].unit_id,
			_core.roster[1].unit_id])).is_false()
	assert_str(_core.last_error).contains("占用")
	# 战斗名额不受轻度影响（⑤：in_progress_count 不计轻度）
	assert_int(_core.board.in_progress_count()).is_equal(0)
	assert_bool(first != null).is_true()

func test_g2_same_template_blocked() -> void:
	## ④G-2 同模板拦截：轻度开工后同模板板上实例再开工拒
	var first: QuestInstance = _StartLight(&"q_chore_supply_run", 1)
	_core.board.board.clear()
	var copy: QuestInstance = _core.board.spawn_on_board(&"q_chore_supply_run", _core.day)
	assert_bool(_core.start_light_quest(copy.serial, [_core.roster[1].unit_id])).is_false()
	assert_str(_core.last_error).contains("同模板")
	assert_int(copy.state).is_equal(QuestInstance.State.ON_BOARD)
	assert_bool(first != null).is_true()

func test_work_days_advance_and_settle() -> void:
	## ⑦工期推进+自动结算（q_chore_supply_run 工期 2）：day1 开工（day 推进到
	## 2 时 work=1）→ day3 归零结算——60 金/30 经验各得全额/声望 1/实例移除/
	## 占用释放/light_completed 载荷
	var inst: QuestInstance = _StartLight(&"q_chore_supply_run", 1)
	var gold_before: int = _core.gold
	var summary: GuildCore.DaySummary = _core.settle_one_day()
	assert_int(inst.work_days_left).is_equal(1)
	assert_int(summary.light_completed.size()).is_equal(0)
	var summary2: GuildCore.DaySummary = _core.settle_one_day()
	assert_int(inst.work_days_left).is_equal(0)
	assert_int(summary2.light_completed.size()).is_equal(1)
	var result: GuildCore.LightQuestResult = summary2.light_completed[0]
	assert_str(String(result.template_id)).is_equal("q_chore_supply_run")
	assert_str(result.display_name).contains("轻度·")
	assert_int(result.gold).is_equal(60)
	assert_int(result.exp).is_equal(30)
	assert_int(result.reputation).is_equal(1)
	assert_int(_core.gold - gold_before).is_equal(60)
	assert_int(_core.reputation).is_equal(1)
	assert_int(_core.roster[0].exp).is_equal(30)
	assert_bool(_core.board.find_accepted(inst.serial) == null).is_true()
	assert_int(_core.board.occupied_member_ids().size()).is_equal(0)
	# 板凳分享（拍板①）：Lv1 训练场 30×0.3=9/人；编队成员（roster[0]）无份
	assert_int(result.bench_member_count).is_equal(3)
	assert_int(result.bench_exp_per_member).is_equal(9)
	assert_int(_core.roster[1].exp).is_equal(9)
	assert_int(_core.roster[2].exp).is_equal(9)
	assert_int(_core.roster[3].exp).is_equal(9)

func test_two_member_excess_precision() -> void:
	## ⑬数值精度：二人档超额 1 → ×1.15 → 69 金（60×1.15=69）/35 经验
	##（30×1.15=34.5 roundi=35）；声望不吃超额恒 1；板凳基数不含超额仍 9
	var inst: QuestInstance = _StartLight(&"q_chore_supply_run", 2)
	var summary: GuildCore.DaySummary = _core.settle_one_day()
	assert_int(summary.light_completed.size()).is_equal(0)
	var summary2: GuildCore.DaySummary = _core.settle_one_day()
	var result: GuildCore.LightQuestResult = summary2.light_completed[0]
	assert_int(result.gold).is_equal(69)
	assert_int(result.exp).is_equal(35)
	assert_int(result.reputation).is_equal(1)
	assert_int(_core.roster[0].exp).is_equal(35)
	assert_int(_core.roster[1].exp).is_equal(35)
	assert_int(result.bench_exp_per_member).is_equal(9)
	assert_int(_core.roster[2].exp).is_equal(9)
	assert_int(_core.roster[3].exp).is_equal(9)
	assert_bool(inst != null).is_true()

func test_week_refresh_day_advances_light() -> void:
	## ⑧周刷新日照常推进：推到 day8（周刷新日）开工 → 工期照常递减
	for _i: int in 7:
		_core.settle_one_day()
	assert_int(_core.day).is_equal(8)
	var inst: QuestInstance = _StartLight(&"q_chore_supply_run", 1)
	_core.settle_one_day()
	assert_int(_core.day).is_equal(9)
	assert_int(inst.work_days_left).is_equal(1)

func test_expiration_skips_light_running() -> void:
	## ⑨挂单到期不误伤 LIGHT_RUNNING（最高风险点）：板上滞留 3 天后开工——
	## 工期归零日 == 板上到期线日（quest_countdown 先行扫到期，LIGHT_RUNNING
	## 须跳过、随后 advance 步正常结算——不误杀不漏结算）
	_core.board.board.clear()
	var inst: QuestInstance = _core.board.spawn_on_board(&"q_chore_supply_run", 1)
	assert_int(inst.expire_day).is_equal(6)
	# 滞留 3 天（day 1 → 4）
	_core.settle_one_day()
	_core.settle_one_day()
	_core.settle_one_day()
	assert_int(_core.day).is_equal(4)
	assert_bool(_core.start_light_quest(inst.serial, [_core.roster[0].unit_id])).is_true()
	assert_int(inst.work_days_left).is_equal(2)
	# day5：未到期+工期 1
	_core.settle_one_day()
	assert_int(inst.work_days_left).is_equal(1)
	assert_bool(_core.board.find_accepted(inst.serial) != null).is_true()
	# day6 == expire_day：到期线命中 LIGHT_RUNNING——跳过不被移除；advance 步
	# 归零自动结算（同日完成）
	var summary: GuildCore.DaySummary = _core.settle_one_day()
	assert_int(summary.accepted_failed.size()).is_equal(0)
	assert_int(summary.light_completed.size()).is_equal(1)
	assert_str(String(summary.light_completed[0].template_id)).is_equal("q_chore_supply_run")

func test_abandon_light_running() -> void:
	## ⑩放弃：LIGHT_RUNNING 可弃（无惩罚无奖励工期作废立即释放）+弃后成员
	## 当日可出征；战斗 IN_PROGRESS 维持拒绝
	var inst: QuestInstance = _StartLight(&"q_chore_supply_run", 1)
	var gold_before: int = _core.gold
	assert_bool(_core.abandon_quest(inst.serial)).is_true()
	assert_int(_core.gold).is_equal(gold_before)
	assert_int(_core.board.occupied_member_ids().size()).is_equal(0)
	# 弃后当日可出征（轻度不占出征额度+释放即编）
	var battle: QuestInstance = _core.board.spawn_on_board(&"q_lair_purge", _core.day)
	assert_bool(_core.accept_quest(battle.serial, _RosterIds(3))).is_true()
	assert_bool(_core.start_expedition(battle.serial)).is_true()
	# 战斗 IN_PROGRESS 不可弃
	assert_bool(_core.abandon_quest(battle.serial)).is_false()
	assert_str(_core.last_error).contains("出征进行中")

func test_catchup_drives_light_and_idempotent() -> void:
	## ⑪出征补结算期间轻度跨日推进：A 出征 3 天、B 轻度工期 3 同日开工——
	## 回城补结算逐日驱动 B 在补结算期归零并入 day_summaries；run.settled
	## 幂等（二次结算不再推进）
	var light: QuestInstance = _StartLight(&"q_chore_tavern_help", 1)
	_core.board.board.clear()
	var battle: QuestInstance = _core.board.spawn_on_board(&"q_vein_survey", _core.day)
	assert_bool(_core.accept_quest(battle.serial, [_core.roster[1].unit_id,
			_core.roster[2].unit_id])).is_true()
	assert_bool(_core.start_expedition(battle.serial)).is_true()
	var run := ExpeditionRun.new()
	run.base_days = 3
	run.party = [_core.roster[1], _core.roster[2]]
	run.quest_template_id = &"q_vein_survey"
	run.quest_serial = battle.serial
	var gold_before: int = _core.gold
	_core.settle_expedition(run, GuildCore.ExpeditionOutcome.SUCCESS)
	# 补结算 3 日驱动轻度（工期 3）归零结算
	assert_bool(_core.board.find_accepted(light.serial) == null).is_true()
	# 轻度 60 金 + 委托 150 金（2 人无超额）
	assert_int(_core.gold - gold_before).is_equal(210)
	# 幂等：二次结算不重复推进/入账
	var day_after: int = _core.day
	_core.settle_expedition(run, GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(_core.day).is_equal(day_after)
	assert_int(_core.gold).is_equal(gold_before + 210)

func test_light_locked_from_reassign_and_start() -> void:
	## ⑫锁定：LIGHT_RUNNING 拒 reassign_party / 拒 start_expedition
	var inst: QuestInstance = _StartLight(&"q_chore_supply_run", 1)
	assert_bool(_core.reassign_party(inst.serial, [_core.roster[1].unit_id])).is_false()
	assert_str(_core.last_error).contains("仅挂单委托可重编队")
	assert_bool(_core.start_expedition(inst.serial)).is_false()
	assert_str(_core.last_error).contains("仅挂单委托可确认出征")

func test_bench_share_lv2() -> void:
	## ⑭板凳分享 Lv2：训练场升 2 级（0.4）→ 30×0.4=12/人；休养不参与
	_core.gold = 1000
	assert_bool(_core.upgrade_facility(&"fac_training_ground")).is_true()
	_core.roster[3].status = AdventurerData.Status.RESTING
	_core.roster[3].rest_days = 5
	var inst: QuestInstance = _StartLight(&"q_chore_supply_run", 1)
	_core.settle_one_day()
	var summary: GuildCore.DaySummary = _core.settle_one_day()
	var result: GuildCore.LightQuestResult = summary.light_completed[0]
	# 板凳=健康且不在编队：roster[1]/roster[2]（roster[3] 休养不参与）
	assert_int(result.bench_member_count).is_equal(2)
	assert_int(result.bench_exp_per_member).is_equal(12)
	assert_int(_core.roster[1].exp).is_equal(12)
	assert_int(_core.roster[2].exp).is_equal(12)
	assert_int(_core.roster[3].exp).is_equal(0)
	assert_bool(inst != null).is_true()

func test_v3_roundtrip_work_days() -> void:
	## ⑮v3 roundtrip：LIGHT_RUNNING state+work_days_left 往返；缺
	## work_days_left 键 → from_dict null（必填反转断言）
	var inst: QuestInstance = _StartLight(&"q_chore_supply_run", 1)
	var snapshot: Dictionary = inst.to_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(snapshot))
	assert_object(parsed).is_not_null()
	var restored: QuestInstance = QuestInstance.from_dict(parsed)
	assert_object(restored).is_not_null()
	assert_int(restored.state).is_equal(QuestInstance.State.LIGHT_RUNNING)
	assert_int(restored.work_days_left).is_equal(2)
	# 必填反转：删 work_days_left 键 → null
	var missing: Dictionary = (parsed as Dictionary).duplicate()
	missing.erase("work_days_left")
	assert_object(QuestInstance.from_dict(missing)).is_null()
	# 非法值（负数）→ null
	var negative: Dictionary = (parsed as Dictionary).duplicate()
	negative["work_days_left"] = -1
	assert_object(QuestInstance.from_dict(negative)).is_null()
	# 板凳升级经 pending 驱动不进 DaySummary：板凳得 9 经验不升级（<100）
	var summary: GuildCore.DaySummary = _core.settle_one_day()
	assert_int(summary.recovered_ids.size()).is_equal(0)
