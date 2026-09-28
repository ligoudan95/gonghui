## M2 委托模板数据单元测试（批 1；M4 扩板刷全量校验）
## 覆盖：q_lost_miner_keepsake 字段逐项（目标/人力/时限/奖励/渠道）；
## 域计数 9（板刷 8+事件授予 1——M4 批 1 全量落地）；q_lair_purge 字段锁；
## 板刷 8 模板公共字段与三表现配比逐行（案 18 §2.6 定稿表）。
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

func test_keepsake_template_fields() -> void:
	## keepsake 模板字段逐项（案 18 §2.3 模板表）
	var quest: QuestTemplateDef = _game_data.get_record(&"q_lost_miner_keepsake") as QuestTemplateDef
	assert_object(quest).is_not_null()
	assert_str(quest.display_name).is_equal("没能回家的托米")
	assert_int(quest.quest_type).is_equal(QuestTemplateDef.QuestType.NORMAL)
	assert_int(quest.exec_class).is_equal(QuestTemplateDef.ExecClass.COMBAT)
	assert_int(quest.goal_type).is_equal(QuestTemplateDef.GoalType.EXPLORE)
	assert_str(String(quest.goal_param)).is_equal("tp_old_well")
	assert_str(String(quest.region_id)).is_equal("reg_mine")
	assert_int(quest.party_min).is_equal(2)
	assert_int(quest.party_max).is_equal(4)
	assert_int(quest.time_limit_days).is_equal(7)
	assert_int(quest.reward.gold).is_equal(150)
	assert_int(quest.reward.exp).is_equal(80)
	assert_int(quest.reward.reputation).is_equal(5)
	assert_int(quest.acquire_channel).is_equal(QuestTemplateDef.AcquireChannel.EVENT_GRANT)
	assert_bool(quest.abandonable).is_true()
	assert_bool(quest.retry_on_fail).is_false()
	assert_int(quest.rare_weight).is_equal(0)
	# M4 文案钩子（C8 三要素）
	assert_str(quest.issuer).is_equal("托米的日记")
	assert_bool(quest.description.is_empty()).is_false()

func test_quest_domain_count() -> void:
	## 委托域计数恰 12（板刷 11=8 战斗+3 轻度 + 事件授予 1——M4 增补批；18 案 §4.1 登记行）
	assert_int(_game_data.get_domain_ids(&"quest/templates").size()).is_equal(12)
	## 暗门标记域 M3 落首行（hm_mine_secret_door——M2 先建后空期结束）
	assert_int(_game_data.get_domain_ids(&"event/hidden_marks").size()).is_equal(1)

func test_purge_template_fields_locked() -> void:
	## W5-2（2026-09-26 审计）：q_lair_purge 字段锁——对照案 18 §2.6 定稿行：
	## CLEAR 判据 enc_m1_lair_pack / 人力 3-4 / 时限 5 天 / 奖励 150金·80经验·5声望
	var quest: QuestTemplateDef = _game_data.get_record(&"q_lair_purge") as QuestTemplateDef
	assert_object(quest).is_not_null()
	assert_str(quest.display_name).is_equal("清剿哥布林营地")
	assert_int(quest.goal_type).is_equal(QuestTemplateDef.GoalType.CLEAR)
	assert_str(String(quest.goal_param)).is_equal("enc_m1_lair_pack")
	assert_str(String(quest.region_id)).is_equal("reg_mine")
	assert_str(String(quest.map_id)).is_equal("map_m1_village_mine")
	assert_int(quest.party_min).is_equal(3)
	assert_int(quest.party_max).is_equal(4)
	assert_int(quest.time_limit_days).is_equal(5)
	assert_int(quest.reward.gold).is_equal(150)
	assert_int(quest.reward.exp).is_equal(80)
	assert_int(quest.reward.reputation).is_equal(5)
	assert_int(quest.acquire_channel).is_equal(QuestTemplateDef.AcquireChannel.BOARD)
	assert_bool(quest.abandonable).is_true()
	assert_bool(quest.retry_on_fail).is_false()

func test_board_templates_common_fields() -> void:
	## 板刷 8 模板公共字段（案 18 §2.6 定稿表逐行）：奖励 150/80/5、时限 5、
	## 人力区间、到期表现配比（刷新×3/替换×3/消失×2）、推荐属性对、发布人/描述
	var spec: Dictionary = {
		&"q_lair_purge": [0, "enc_m1_lair_pack", 3, 4, 0, [&"strength", &"constitution"], "矿工代表"],
		&"q_road_reclaim": [0, "enc_m1_lair_pack", 3, 4, 0, [&"strength", &"agility"], "村长"],
		&"q_bounty_boss": [0, "enc_m1_lair_pack", 3, 4, 0, [&"strength", &"intelligence"], "协会·悬赏告示"],
		&"q_vein_survey": [1, "tp_mine_east_gallery", 2, 4, 2, [&"intelligence", &"perception"], "矿监·协会登记"],
		&"q_north_survey": [1, "tp_mine_north_wall", 2, 4, 2, [&"perception", &"intelligence"], "协会"],
		&"q_shaft_echo": [1, "tp_mine_south_shaft", 2, 4, 1, [&"perception", &"constitution"], "守夜人"],
		&"q_west_patrol": [1, "tp_mine_west_camp", 2, 4, 1, [&"agility", &"perception"], "村长"],
		&"q_track_survey": [1, "tp_mine_track_yard", 2, 4, 2, [&"agility", &"intelligence"], "光辉城商会"],
	}
	assert_int(spec.size()).is_equal(8)
	var behavior_count: Dictionary = {0: 0, 1: 0, 2: 0}
	for tpl_id: StringName in spec:
		var quest: QuestTemplateDef = _game_data.get_record(tpl_id) as QuestTemplateDef
		assert_object(quest).is_not_null()
		var row: Array = spec[tpl_id]
		assert_int(quest.goal_type).is_equal(row[0])
		assert_str(String(quest.goal_param)).is_equal(row[1])
		assert_int(quest.party_min).is_equal(row[2])
		assert_int(quest.party_max).is_equal(row[3])
		assert_int(quest.time_limit_days).is_equal(5)
		assert_int(quest.reward.gold).is_equal(150)
		assert_int(quest.reward.exp).is_equal(80)
		assert_int(quest.reward.reputation).is_equal(5)
		assert_int(quest.acquire_channel).is_equal(QuestTemplateDef.AcquireChannel.BOARD)
		assert_bool(quest.abandonable).is_true()
		assert_int(quest.expire_behavior).is_equal(row[4])
		assert_float(quest.excess_bonus_per_head).is_equal(0.0)
		assert_str(String(quest.issuer)).is_equal(row[6])
		assert_bool(quest.description.is_empty()).is_false()
		var recommend_spec: Array = row[5]
		assert_int(quest.recommend_attrs.size()).is_equal(recommend_spec.size())
		for attr_index: int in recommend_spec.size():
			assert_str(String(quest.recommend_attrs[attr_index])).is_equal(
					String(recommend_spec[attr_index]))
		behavior_count[int(row[4])] = int(behavior_count[int(row[4])]) + 1
	# 三表现配比=刷新×3/替换×3/消失×2（案 18 §2.6 自洽注）
	assert_int(int(behavior_count[0])).is_equal(3)
	assert_int(int(behavior_count[1])).is_equal(2)
	assert_int(int(behavior_count[2])).is_equal(3)
