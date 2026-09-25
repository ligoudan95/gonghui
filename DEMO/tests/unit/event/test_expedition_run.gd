## ExpeditionRun 出征运行态单元测试（M2 批 2）
## 覆盖：损耗排除倒地+下限 1（D14/案 18 §3.4）/ 奖励累计 / 耗时申报 /
## 授予防重 / 战斗结果回写（倒地带回）。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData
	## 参数：无
	## 返回：无
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()

func after() -> void:
	## 套件后置：释放 GameData
	## 参数：无
	## 返回：无
	_game_data.free()

func _MakeRun() -> ExpeditionRun:
	## 构建三人运行态（HP 40/50/30——第二人倒地）
	## 参数：无
	## 返回：ExpeditionRun
	var run := ExpeditionRun.new()
	run.party = [
		AdventurerData.create_debug(&"a", &"cls_warrior", {
			&"strength": 16, &"agility": 10, &"constitution": 14,
			&"intelligence": 7, &"perception": 9, &"willpower": 9, &"luck": 9}, _game_data),
		AdventurerData.create_debug(&"b", &"cls_mage", {
			&"strength": 7, &"agility": 10, &"constitution": 9,
			&"intelligence": 16, &"perception": 11, &"willpower": 9, &"luck": 9}, _game_data),
		AdventurerData.create_debug(&"c", &"cls_priest", {
			&"strength": 10, &"agility": 10, &"constitution": 11,
			&"intelligence": 10, &"perception": 15, &"willpower": 13, &"luck": 9}, _game_data),
	]
	run.hp = {run.party[0]: 40, run.party[1]: 50, run.party[2]: 30}
	run.downed = {run.party[1]: true}
	return run

func test_party_damage_excludes_downed_and_floors_at_one() -> void:
	## 损耗：倒地者（b，50）不动；未倒地扣至最低 1 止不归零（a 40−5=35；
	## c 30−45=1 钳住）
	var run := _MakeRun()
	run.apply_party_damage(-5)
	assert_int(int(run.hp[run.party[0]])).is_equal(35)
	assert_int(int(run.hp[run.party[1]])).is_equal(50)
	assert_int(int(run.hp[run.party[2]])).is_equal(25)
	run.apply_party_damage(-45)
	assert_int(int(run.hp[run.party[0]])).is_equal(1)
	assert_int(int(run.hp[run.party[2]])).is_equal(1)
	assert_bool(run.downed.has(run.party[2])).is_false()

func test_rewards_accumulate() -> void:
	## 奖励累计三键独立
	var run := _MakeRun()
	run.add_reward(15, 10, 1)
	run.add_reward(10, 20, 0)
	assert_int(int(run.rewards[&"exp"])).is_equal(25)
	assert_int(int(run.rewards[&"gold"])).is_equal(30)
	assert_int(int(run.rewards[&"reputation"])).is_equal(1)

func test_total_days() -> void:
	## 耗时申报：基准 1 + 事件累计（+1 = 2）
	var run := _MakeRun()
	assert_int(run.total_days()).is_equal(1)
	run.extra_days += 1
	assert_int(run.total_days()).is_equal(2)

func test_grant_quest_dedup() -> void:
	## 授予防重：首授 true、再授 false（18-C6 补叙口径）
	var run := _MakeRun()
	assert_bool(run.grant_quest(&"q_lost_miner_keepsake")).is_true()
	assert_bool(run.grant_quest(&"q_lost_miner_keepsake")).is_false()
	assert_int(run.granted_quests.size()).is_equal(1)

func test_battle_result_writeback() -> void:
	## 战斗回写：a 存活 end_hp=12 → 12；b 倒地 → downed + HP 0；
	## c 倒地（downed=true）→ 带回
	var run := _MakeRun()
	run.apply_battle_result([
		{&"unit_id": &"a", &"end_hp": 12, &"downed": false},
		{&"unit_id": &"b", &"end_hp": 0, &"downed": true},
		{&"unit_id": &"c", &"end_hp": 0, &"downed": true},
	])
	assert_int(int(run.hp[run.party[0]])).is_equal(12)
	assert_int(int(run.hp[run.party[1]])).is_equal(0)
	assert_bool(run.downed.has(run.party[2])).is_true()
