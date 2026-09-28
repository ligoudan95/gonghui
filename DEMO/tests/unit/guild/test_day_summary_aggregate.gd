## 日结算汇总聚合单元测试（M5 批 2——测试先行，铁律⑥）
## 覆盖：GuildCore.aggregate_day_summaries 静态聚合口——空数组空摘要（day=0）、
## day/新候选取末组、周刷新任一真、恢复完成依序并集去重、板上三表现与挂单
## 失败依序拼接、轻度完成全拼接、单组透传（弹窗单日链路）、真实回城补结算
## 逐日 day_summaries 的聚合消费（跨用例一致性）。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData
var _game_data: Node

func before_test() -> void:
	## 用例级前置：GameData 实例
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()

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

func _MakeSummary(day: int) -> GuildCore.DaySummary:
	## 空白 DaySummary 构造（day 定值——测试确定性）
	var summary := GuildCore.DaySummary.new()
	summary.day = day
	return summary

func _MakeLightResult(template_id: StringName, gold: int) -> GuildCore.LightQuestResult:
	## 轻度完成条目构造
	var result := GuildCore.LightQuestResult.new()
	result.template_id = template_id
	result.display_name = "轻度·%s" % String(template_id)
	result.gold = gold
	result.exp = 30
	result.reputation = 1
	result.bench_member_count = 3
	result.bench_exp_per_member = 9
	return result

func test_empty_array_returns_empty_summary() -> void:
	## 空数组 → 空 DaySummary（day=0——调用方判空不出行/不弹窗）
	var agg: GuildCore.DaySummary = GuildCore.aggregate_day_summaries([])
	assert_int(agg.day).is_equal(0)
	assert_bool(agg.week_refreshed).is_false()
	assert_int(agg.recovered_ids.size()).is_equal(0)
	assert_int(agg.board_removed.size()).is_equal(0)
	assert_int(agg.board_refreshed.size()).is_equal(0)
	assert_int(agg.board_replaced.size()).is_equal(0)
	assert_int(agg.accepted_failed.size()).is_equal(0)
	assert_int(agg.new_candidate_names.size()).is_equal(0)
	assert_int(agg.light_completed.size()).is_equal(0)

func test_day_and_candidates_take_last_group() -> void:
	## day 取末组；new_candidate_names 取末组（逐日池整刷——历史候选名
	## 无展示价值，不拼接）
	var first: GuildCore.DaySummary = _MakeSummary(2)
	first.new_candidate_names = ["甲", "乙"]
	var last: GuildCore.DaySummary = _MakeSummary(3)
	last.new_candidate_names = ["丙", "丁"]
	var agg: GuildCore.DaySummary = GuildCore.aggregate_day_summaries([first, last])
	assert_int(agg.day).is_equal(3)
	assert_int(agg.new_candidate_names.size()).is_equal(2)
	assert_str(agg.new_candidate_names[0]).is_equal("丙")
	assert_str(agg.new_candidate_names[1]).is_equal("丁")

func test_week_refreshed_any_true() -> void:
	## 周刷新：任一 true → true；全 false → false
	var plain_a: GuildCore.DaySummary = _MakeSummary(6)
	var refresh: GuildCore.DaySummary = _MakeSummary(7)
	refresh.week_refreshed = true
	var plain_b: GuildCore.DaySummary = _MakeSummary(8)
	var agg: GuildCore.DaySummary = GuildCore.aggregate_day_summaries(
			[plain_a, refresh, plain_b])
	assert_bool(agg.week_refreshed).is_true()
	var all_plain: GuildCore.DaySummary = GuildCore.aggregate_day_summaries(
			[plain_a, plain_b])
	assert_bool(all_plain.week_refreshed).is_false()

func test_recovered_ids_union_in_order_dedup() -> void:
	## 恢复完成：依序并集去重（day2 [a,b] + day3 [b,c] → [a,b,c]——
	## 同人跨日不重复计数，顺序保持首现序）
	var first: GuildCore.DaySummary = _MakeSummary(2)
	first.recovered_ids = [&"adv_erin", &"adv_iron_peak"]
	var second: GuildCore.DaySummary = _MakeSummary(3)
	second.recovered_ids = [&"adv_iron_peak", &"adv_morris"]
	var agg: GuildCore.DaySummary = GuildCore.aggregate_day_summaries([first, second])
	assert_int(agg.recovered_ids.size()).is_equal(3)
	assert_str(String(agg.recovered_ids[0])).is_equal("adv_erin")
	assert_str(String(agg.recovered_ids[1])).is_equal("adv_iron_peak")
	assert_str(String(agg.recovered_ids[2])).is_equal("adv_morris")

func test_board_and_accepted_lists_concat_in_order() -> void:
	## 板上三表现与挂单到期失败：依序拼接不去重（同模板跨日可重复出现——
	## 逐日如实累计）
	var first: GuildCore.DaySummary = _MakeSummary(2)
	first.board_removed = ["q_a"]
	first.board_refreshed = ["q_b"]
	first.board_replaced = ["q_c"]
	first.accepted_failed = ["q_d"]
	var second: GuildCore.DaySummary = _MakeSummary(3)
	second.board_removed = ["q_e"]
	second.board_refreshed = []
	second.board_replaced = ["q_f"]
	second.accepted_failed = ["q_d", "q_g"]
	var agg: GuildCore.DaySummary = GuildCore.aggregate_day_summaries([first, second])
	assert_int(agg.board_removed.size()).is_equal(2)
	assert_str(agg.board_removed[0]).is_equal("q_a")
	assert_str(agg.board_removed[1]).is_equal("q_e")
	assert_int(agg.board_refreshed.size()).is_equal(1)
	assert_int(agg.board_replaced.size()).is_equal(2)
	assert_str(agg.board_replaced[1]).is_equal("q_f")
	assert_int(agg.accepted_failed.size()).is_equal(3)
	assert_str(agg.accepted_failed[1]).is_equal("q_d")

func test_light_completed_all_appended() -> void:
	## 轻度完成：全拼接（逐日多条如实累计，含板凳后缀数据原样保留）
	var first: GuildCore.DaySummary = _MakeSummary(2)
	first.light_completed = [_MakeLightResult(&"q_chore_supply_run", 60)]
	var second: GuildCore.DaySummary = _MakeSummary(3)
	second.light_completed = [_MakeLightResult(&"q_chore_tavern_help", 69)]
	var agg: GuildCore.DaySummary = GuildCore.aggregate_day_summaries([first, second])
	assert_int(agg.light_completed.size()).is_equal(2)
	assert_str(String(agg.light_completed[0].template_id)).is_equal("q_chore_supply_run")
	assert_str(String(agg.light_completed[1].template_id)).is_equal("q_chore_tavern_help")
	assert_int(agg.light_completed[0].bench_member_count).is_equal(3)

func test_single_summary_passthrough() -> void:
	## 单组透传（弹窗单日链路——等待一天 open([summary])）：聚合=自身全部内容
	var solo: GuildCore.DaySummary = _MakeSummary(5)
	solo.week_refreshed = true
	solo.recovered_ids = [&"adv_erin"]
	solo.board_removed = ["q_a"]
	solo.board_refreshed = ["q_b"]
	solo.board_replaced = ["q_c"]
	solo.accepted_failed = ["q_d"]
	solo.new_candidate_names = ["甲"]
	solo.light_completed = [_MakeLightResult(&"q_chore_supply_run", 60)]
	var agg: GuildCore.DaySummary = GuildCore.aggregate_day_summaries([solo])
	assert_int(agg.day).is_equal(5)
	assert_bool(agg.week_refreshed).is_true()
	assert_int(agg.recovered_ids.size()).is_equal(1)
	assert_int(agg.board_removed.size()).is_equal(1)
	assert_int(agg.board_refreshed.size()).is_equal(1)
	assert_int(agg.board_replaced.size()).is_equal(1)
	assert_int(agg.accepted_failed.size()).is_equal(1)
	assert_int(agg.new_candidate_names.size()).is_equal(1)
	assert_int(agg.light_completed.size()).is_equal(1)

func test_aggregate_real_catchup_day_summaries() -> void:
	## 真实链路消费：出发日 4、出征 3 天 + 挂单（上板日 1、到期线 6）补结算
	## 内到期失败——settle_expedition 的 day_summaries 聚合后 accepted_failed
	## 拼接、day=末组（回城日 7）
	var core := GuildCore.new()
	core.setup(_Cfg(), _game_data, _MakeRng(621))
	for _day_index: int in 3:
		core.settle_one_day()
	assert_int(core.day).is_equal(4)
	var inst_a: QuestInstance = core.board.spawn_on_board(&"q_vein_survey", core.day)
	assert_bool(core.accept_quest(inst_a.serial,
			[core.roster[0].unit_id, core.roster[1].unit_id])).is_true()
	var inst_b: QuestInstance = core.board.spawn_on_board(&"q_north_survey", 1)
	assert_bool(core.accept_quest(inst_b.serial,
			[core.roster[2].unit_id, core.roster[3].unit_id])).is_true()
	assert_bool(core.start_expedition(inst_a.serial)).is_true()
	var run := ExpeditionRun.new()
	run.base_days = 3
	run.party = [core.roster[0], core.roster[1]]
	run.quest_template_id = &"q_vein_survey"
	var summary: GuildCore.ExpeditionSummary = core.settle_expedition(run,
			GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(summary.day_summaries.size()).is_equal(3)
	var agg: GuildCore.DaySummary = GuildCore.aggregate_day_summaries(
			summary.day_summaries)
	assert_int(agg.day).is_equal(7)
	assert_bool(agg.accepted_failed.has("q_north_survey")).is_true()
	assert_int(agg.accepted_failed.size()).is_equal(1)
