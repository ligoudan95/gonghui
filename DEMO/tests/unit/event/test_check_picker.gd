## CheckPicker 检定改派候选单元测试（M2 批 1——测试先行）
## 覆盖：按调整值降序 / 同高队伍序在前 / 倒地剔除（D1）/ 空名单（全员倒地
## → 空；default_pick 返回 null——事件层走 FAILURE 分支防死锁）。
extends GdUnitTestSuite

## cfg_main 真实数据路径
const CFG_PATH: String = "res://data/core/cfg_main.tres"
## GameData 脚本路径（create_debug 消费）
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级配置与 GameData
var _cfg: CoreConfig
var _game_data: Node

func before() -> void:
	## 套件前置：加载 cfg_main 与 GameData（create_debug 职业表消费）
	## 参数：无
	## 返回：无
	_cfg = load(CFG_PATH) as CoreConfig
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()

func after() -> void:
	## 套件后置：释放 GameData
	## 参数：无
	## 返回：无
	_game_data.free()

func _MakeParty() -> Array:
	## 构建三人队伍（力 16/16/10——前两人同高，队伍序区分）
	## 参数：无
	## 返回：[AdventurerData] 三人
	var party: Array = []
	party.append(AdventurerData.create_debug(&"a_strong", &"cls_warrior", {
		&"strength": 16, &"agility": 10, &"constitution": 14,
		&"intelligence": 7, &"perception": 9, &"willpower": 9, &"luck": 9}, _game_data))
	party.append(AdventurerData.create_debug(&"b_equal", &"cls_warrior", {
		&"strength": 16, &"agility": 10, &"constitution": 10,
		&"intelligence": 9, &"perception": 11, &"willpower": 10, &"luck": 13}, _game_data))
	party.append(AdventurerData.create_debug(&"c_weak", &"cls_mage", {
		&"strength": 7, &"agility": 10, &"constitution": 9,
		&"intelligence": 16, &"perception": 11, &"willpower": 9, &"luck": 9}, _game_data))
	return party

func test_candidates_sorted_and_downed_excluded() -> void:
	## 排序 + 同高队伍序 + 倒地剔除：a/b 力 16 并列 → a 在前（队伍序）；
	## b downed → 剔除；c 力 7 殿后
	var party: Array = _MakeParty()
	var downed: Dictionary = {party[1]: true}
	var candidates: Array = CheckPicker.candidates(party, AttrKeys.STRENGTH, _cfg, downed)
	assert_int(candidates.size()).is_equal(2)
	assert_str(String(candidates[0]["adv"].unit_id)).is_equal("a_strong")
	assert_str(String(candidates[1]["adv"].unit_id)).is_equal("c_weak")
	assert_int(candidates[0]["modifier"]).is_equal(3)
	assert_int(candidates[1]["modifier"]).is_equal(-2)
	assert_bool(candidates[0]["downed"]).is_false()

func test_default_pick_first() -> void:
	## 默认改派：首名（排序后最高调整值）
	var party: Array = _MakeParty()
	var downed: Dictionary = {}
	var candidates: Array = CheckPicker.candidates(party, AttrKeys.STRENGTH, _cfg, downed)
	var picked: AdventurerData = CheckPicker.default_pick(candidates)
	assert_object(picked).is_not_null()
	assert_str(String(picked.unit_id)).is_equal("a_strong")

func test_default_pick_empty_returns_null() -> void:
	## 空名单（全员倒地/空队伍）：default_pick 返回 null——事件层据此走
	## FAILURE 分支防死锁
	assert_object(CheckPicker.default_pick([])).is_null()
	var empty_all_downed: Array = []
	assert_object(CheckPicker.default_pick(empty_all_downed)).is_null()
