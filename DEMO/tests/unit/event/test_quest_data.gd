## M2 委托模板数据单元测试（批 1）
## 覆盖：q_lost_miner_keepsake 字段逐项（目标/人力/时限/奖励/渠道）；
## 域计数恰 1（M2 拍板③只落此行）。
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
	assert_str(String(quest.region_id)).is_equal("mine")
	assert_int(quest.party_min).is_equal(2)
	assert_int(quest.party_max).is_equal(4)
	assert_int(quest.time_limit_days).is_equal(7)
	assert_int(quest.reward.gold).is_equal(150)
	assert_int(quest.reward.exp).is_equal(80)
	assert_int(quest.reward.reputation).is_equal(5)
	assert_int(quest.acquire_channel).is_equal(QuestTemplateDef.AcquireChannel.EVENT_GRANT)
	assert_bool(quest.abandonable).is_false()
	assert_bool(quest.retry_on_fail).is_false()
	assert_int(quest.rare_weight).is_equal(0)

func test_quest_domain_count() -> void:
	## 委托域计数恰 1（M2 拍板③：板刷 8 行 M3 补）
	assert_int(_game_data.get_domain_ids(&"quest/templates").size()).is_equal(1)
	## 暗门标记域先建后空 0 行（铁律⑧）
	assert_int(_game_data.get_domain_ids(&"event/hidden_marks").size()).is_equal(0)
