## M2 事件数据单元测试（批 1）
## 覆盖：链图完备（入口/去向/归属）、四档文案（检定选项直接出口）、数值域
## （奖励/耗时/修饰）、B 出口开局参数、暗门 unlock_flag。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData 并初始化
	## 参数：无
	## 返回：无
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()

func after() -> void:
	## 套件后置：释放 GameData
	## 参数：无
	## 返回：无
	_game_data.free()

func _Node(node_id: StringName) -> EventNodeDef:
	## 取节点表
	## 参数 node_id：节点 id
	## 返回：EventNodeDef
	return _game_data.get_record(node_id) as EventNodeDef

func _Option(option_id: StringName) -> EventOptionDef:
	## 取选项表
	## 参数 option_id：选项 id
	## 返回：EventOptionDef
	return _game_data.get_record(option_id) as EventOptionDef

func test_chain_graph_completeness() -> void:
	## 链图完备：三链入口正确；塌方链 4 选项 5 节点；鬼火/营地链 3 选项 3 节点；
	## 全部去向节点存在（零死路）
	var chains: Dictionary = {
		&"chain_mine_collapse": &"evn_collapse_n1",
		&"chain_mine_wisp": &"evn_wisp_n1",
		&"chain_mine_camp": &"evn_camp_n1",
	}
	for chain_id: StringName in chains:
		var chain: EventChainDef = _game_data.get_record(chain_id) as EventChainDef
		assert_object(chain).is_not_null()
		assert_str(String(chain.entry_node_id)).is_equal(String(chains[chain_id]))
	var n1: EventNodeDef = _Node(&"evn_collapse_n1")
	assert_int(n1.option_ids.size()).is_equal(4)
	# 塌方链去向：o1→n2/n4；o2→n3/n4；o3→n5；o4→直接出口
	assert_str(String(_Option(&"opt_collapse_1").success_to)).is_equal("evn_collapse_n2")
	assert_str(String(_Option(&"opt_collapse_1").failure_to)).is_equal("evn_collapse_n4")
	assert_str(String(_Option(&"opt_collapse_3").success_to)).is_equal("evn_collapse_n5")
	assert_int(_Option(&"opt_collapse_3").cost_days).is_equal(1)
	assert_object(_Option(&"opt_collapse_4").success_outcome).is_not_null()
	# 节点总数（域级）
	assert_int(_game_data.get_domain_ids(&"event/nodes").size()).is_equal(11)
	assert_int(_game_data.get_domain_ids(&"event/options").size()).is_equal(10)
	assert_int(_game_data.get_domain_ids(&"event/chains").size()).is_equal(3)

func test_check_options_four_texts() -> void:
	## 检定选项直接出口四档文案（代表抽验）：opt_wisp_1 成功出口四档齐
	var outcome: EventOutcomeDef = _Option(&"opt_wisp_1").success_outcome
	for key: StringName in [&"success", &"crit_success", &"failure", &"crit_failure"]:
		assert_bool(not String(outcome.texts.get(key, "")).is_empty()) \
				.override_failure_message("opt_wisp_1 成功出口缺 %s 档" % key).is_true()

func test_numeric_domains() -> void:
	## 数值域：奖励（E2a 15/20；E3a 10/30 大额）、耗时（o3 = 1）、修饰（−5 HP）
	var e2a: EventOutcomeDef = _Option(&"opt_wisp_1").success_outcome
	assert_int(e2a.reward.exp).is_equal(15)
	assert_int(e2a.reward.gold).is_equal(20)
	var e3a: EventOutcomeDef = _Option(&"opt_camp_2").success_outcome
	assert_int(e3a.reward.gold).is_equal(30)
	assert_int(_Option(&"opt_camp_1").crit_fail_modifier.party_hp_delta).is_equal(-5)
	assert_int(_Option(&"opt_collapse_3").cost_days).is_equal(1)
	# 塌方链奖励分层：n3(20/15) > n2(15/10) > n4(10/5)——风险收益递增
	assert_int(_Node(&"evn_collapse_n3").outcome.reward.exp).is_equal(20)
	assert_int(_Node(&"evn_collapse_n2").outcome.reward.exp).is_equal(15)
	assert_int(_Node(&"evn_collapse_n4").outcome.reward.exp).is_equal(10)

func test_battle_opening_params() -> void:
	## B 出口开局参数：n2=敌先手+集结+DEBUFF_exposed；n3=我先手+分散+无初始状态；
	## pack 统一 enc_m1_wisp_nest；post_battle 奖励 15/15
	var ambushed: BattleOpeningDef = _Node(&"evn_wisp_n2").outcome.battle
	assert_str(String(ambushed.pack_id)).is_equal("enc_m1_wisp_nest")
	assert_str(String(ambushed.first_strike_token)).is_equal("enemy_first")
	assert_str(String(ambushed.enemy_layout_token)).is_equal("clustered")
	assert_str(String(ambushed.initial_status_id)).is_equal("DEBUFF_exposed")
	assert_int(ambushed.post_battle.reward.exp).is_equal(15)
	assert_int(ambushed.post_battle.reward.gold).is_equal(15)
	var formation: BattleOpeningDef = _Node(&"evn_wisp_n3").outcome.battle
	assert_str(String(formation.first_strike_token)).is_equal("ally_first")
	assert_str(String(formation.enemy_layout_token)).is_equal("spread")
	assert_str(String(formation.initial_status_id)).is_empty()

func test_secret_door_unlock_flag() -> void:
	## 暗门：感知·极难 + unlock_flag
	var door: SingleEventDef = _game_data.get_record(&"sp_mine_secretdoor") as SingleEventDef
	assert_str(String(door.check_attr_id)).is_equal("perception")
	assert_str(door.difficulty_tier).is_equal("极难")
	assert_str(String(door.success_outcome.unlock_flag)).is_equal("secret_door_mine_north")

func test_c8_grant_outcome() -> void:
	## C8 授予：camp_n2 出口 grant_quest_id 指向 keepsake 模板（渠道校验在 V-M2）
	var outcome: EventOutcomeDef = _Node(&"evn_camp_n2").outcome
	assert_str(String(outcome.grant_quest_id)).is_equal("q_lost_miner_keepsake")
	assert_int(outcome.reward.exp).is_equal(20)

func test_crit_modifier_text_single_source() -> void:
	## E3 双载体定论（M2 质检 #12）：crit 文案单源 outcome.texts.crit_*——
	## 六处 crit_modifier.text 清空只留实效（reward_delta/party_hp_delta）
	var owners: Array = [
		_Option(&"opt_camp_2"), _Option(&"opt_camp_3"),
		_Option(&"opt_wisp_1"), _Option(&"opt_wisp_2"),
	]
	for option: EventOptionDef in owners:
		assert_str(option.crit_modifier.text) \
				.override_failure_message("%s crit_modifier 文案应清空（单源 crit_success 档）" % option.id) \
				.is_empty()
		assert_object(option.crit_modifier.reward_delta).is_not_null()
	# 单点同口径：板车（+1 声望）/暗门（+15 金）实效保留
	var cart: SingleEventDef = _game_data.get_record(&"sp_village_cart") as SingleEventDef
	assert_str(cart.crit_modifier.text).is_empty()
	assert_int(cart.crit_modifier.reward_delta.reputation).is_equal(1)
	var door: SingleEventDef = _game_data.get_record(&"sp_mine_secretdoor") as SingleEventDef
	assert_str(door.crit_modifier.text).is_empty()
	assert_int(door.crit_modifier.reward_delta.gold).is_equal(15)

func test_dead_crit_keys_cleaned() -> void:
	## E12 死键清理（M2 质检 #26）：不可达 crit 档清键——成功侧节点的
	## crit_failure / 失败侧节点的 crit_success / 纯选择去向节点全 crit 档
	assert_bool(_Node(&"evn_camp_n2").outcome.texts.has(&"crit_failure")) \
			.override_failure_message("camp_n2（成功去向）crit_failure 为死键应清").is_false()
	assert_bool(_Node(&"evn_camp_n3").outcome.texts.has(&"crit_success")) \
			.override_failure_message("camp_n3「北」自创铺垫应删（案 18 铺垫三处口径外）").is_false()
	assert_bool(_Node(&"evn_collapse_n2").outcome.texts.has(&"crit_failure")).is_false()
	assert_bool(_Node(&"evn_collapse_n3").outcome.texts.has(&"crit_failure")).is_false()
	assert_bool(_Node(&"evn_collapse_n4").outcome.texts.has(&"crit_success")).is_false()
	# n5 = 纯选择去向（无检定档语义）——crit 档全清
	assert_bool(_Node(&"evn_collapse_n5").outcome.texts.has(&"crit_success")) \
			.override_failure_message("collapse_n5 存钱点文案不可答应清").is_false()
	assert_bool(_Node(&"evn_collapse_n5").outcome.texts.has(&"crit_failure")).is_false()

func test_reachable_crit_sides_kept() -> void:
	## E10③ 对侧样本：检定链可达侧 crit 档保留非空（删的只是不可达侧）
	assert_str(String(_Node(&"evn_camp_n2").outcome.texts.get(&"crit_success", ""))).is_not_empty()
	assert_str(String(_Node(&"evn_camp_n3").outcome.texts.get(&"crit_failure", ""))).is_not_empty()
	assert_str(String(_Node(&"evn_collapse_n4").outcome.texts.get(&"crit_failure", ""))).is_not_empty()
	assert_str(String(_Node(&"evn_wisp_n2").outcome.texts.get(&"crit_failure", ""))).is_not_empty()

func test_design_notes_moved_to_comment() -> void:
	## E3-14 文案卫生（M2 质检 #32）：玩家向 text 键不再携带设计备注
	## （括注/「此路无失败」占位），设计口径移入 comment 字段
	var door_fail: EventOutcomeDef = _game_data.get_record(
			&"sp_mine_secretdoor").failure_outcome
	assert_bool(door_fail.texts[&"failure"].contains("（")) \
			.override_failure_message("暗门失败文案应剥离设计括注").is_false()
	assert_str(door_fail.comment).contains("暗门保持隐藏")
	# 成功侧防御位文案对齐失败侧（不再「此路无失败」直出）
	var door_success: EventOutcomeDef = _game_data.get_record(
			&"sp_mine_secretdoor").success_outcome
	assert_bool(door_success.texts[&"failure"].contains("此路无失败")).is_false()
	assert_str(door_success.comment).contains("不可达防御位")
	var camp2_success: EventOutcomeDef = _Option(&"opt_camp_2").success_outcome
	assert_bool(camp2_success.texts[&"failure"].contains("此路无失败")).is_false()
	var camp3_success: EventOutcomeDef = _Option(&"opt_camp_3").success_outcome
	assert_bool(camp3_success.texts[&"failure"].contains("火光无碍")).is_false()
