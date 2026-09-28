## 招募池单元测试（M4 批 1）
## 覆盖：偏缺职业优先（初始 4 人后池必含游侠/奇术师）/钳制带（roll_recruit
## 扩测——掷值总和恒入带）/三档花费落位（73→225、74→250、77→250、78→300）/
## 满员+余额校验/刷新整池替换。
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

func _CandidateWithTotal(total: int) -> AdventurerData:
	## 手造指定属性总和的候选（三档落位判定用——7 属性填 10、余量灌首键）
	var adv := AdventurerData.new()
	adv.attrs = {}
	var remaining: int = total - 70
	for attr_id: StringName in AttrKeys.seven_attrs():
		adv.attrs[attr_id] = 10
	var first: StringName = AttrKeys.seven_attrs()[0]
	adv.attrs[first] = int(adv.attrs[first]) + remaining
	return adv

func test_refresh_prefers_missing_classes() -> void:
	## 偏缺职业优先：名册战士/盗贼/法师/牧师 → 池容量 3 中前两席必为缺失的
	## 游侠/奇术师（确保六职业 DEMO 内可体验——案 5 §2.4）
	assert_int(_core.recruit_pool.candidates.size()).is_equal(3)
	var class_ids: Array[StringName] = []
	for candidate: AdventurerData in _core.recruit_pool.candidates:
		class_ids.append(candidate.class_id)
	assert_bool(class_ids.has(&"cls_ranger")).is_true()
	assert_bool(class_ids.has(&"cls_arcanist")).is_true()

func test_candidate_attrs_within_band() -> void:
	## 钳制带：生成的候选七属性总和恒 ∈ [70, 80]（17-C17 整组重掷入带）
	for candidate: AdventurerData in _core.recruit_pool.candidates:
		var total: int = RecruitPool.total_attrs(candidate)
		assert_bool(total >= 70 and total <= 80).is_true()

func test_roll_recruit_band_extended() -> void:
	## AttrRoller.roll_recruit 扩测：真实职业表连续掷 50 组，总和恒入带
	var cls: ClassDef = _game_data.get_record(&"cls_warrior") as ClassDef
	var rng := _MakeRng(302)
	for _roll_index: int in 50:
		var attrs: Dictionary[StringName, int] = AttrRoller.roll_recruit(
				cls, rng, _Cfg().recruit_band_min, _Cfg().recruit_band_max)
		var total: int = 0
		for attr_id: StringName in attrs:
			total += int(attrs[attr_id])
		assert_bool(total >= 70 and total <= 80).is_true()

func test_cost_three_tiers() -> void:
	## 三档花费落位（案 17 §3.7：<74→225 / 74-77→250（74 骑界归上段）/ ≥78→300）
	assert_int(_core.recruit_pool.cost_of(_CandidateWithTotal(73))).is_equal(225)
	assert_int(_core.recruit_pool.cost_of(_CandidateWithTotal(74))).is_equal(250)
	assert_int(_core.recruit_pool.cost_of(_CandidateWithTotal(77))).is_equal(250)
	assert_int(_core.recruit_pool.cost_of(_CandidateWithTotal(78))).is_equal(300)

func test_recruit_blocked_by_gold() -> void:
	## 余额校验：货币不足拦截（候选档价 ≥225 > 余 100）
	_core.gold = 100
	var recruited: AdventurerData = _core.recruit(0)
	assert_object(recruited).is_null()
	assert_str(_core.last_error).contains("货币不足")
	assert_int(_core.roster.size()).is_equal(4)

func test_recruit_blocked_by_dorm_capacity() -> void:
	## 宿舍容量校验：Lv1 容量 6——招至 6 人后再招拦截（宿舍已满）
	_core.gold = 5000
	assert_object(_core.recruit(0)).is_not_null()
	assert_object(_core.recruit(0)).is_not_null()
	assert_int(_core.roster.size()).is_equal(6)
	assert_object(_core.recruit(0)).is_null()
	assert_str(_core.last_error).contains("宿舍已满")

func test_recruit_deducts_and_enrolls() -> void:
	## 招募入册：扣款+入册+出池+id 递增（adv_recruit_N）
	_core.gold = 5000
	var candidate: AdventurerData = _core.recruit_pool.candidates[0]
	var cost: int = _core.recruit_pool.cost_of(candidate)
	var member: AdventurerData = _core.recruit(0)
	assert_object(member).is_not_null()
	assert_int(_core.gold).is_equal(5000 - cost)
	assert_int(_core.roster.size()).is_equal(5)
	assert_int(_core.recruit_pool.candidates.size()).is_equal(2)
	assert_str(String(member.unit_id)).contains("adv_recruit_")
	# 招募成员无预解锁、出生技能点 1、技能清单空（第 1 技花点解锁）
	assert_bool(member.pre_unlocked).is_false()
	assert_int(member.skill_points).is_equal(1)
	assert_int(member.skill_ids.size()).is_equal(0)

func test_refresh_replaces_pool() -> void:
	## 刷新=整池替换：日结算后候选全换新实例
	var old_ids: Array[StringName] = []
	for candidate: AdventurerData in _core.recruit_pool.candidates:
		old_ids.append(candidate.unit_id)
	_core.settle_one_day()
	var new_ids: Array[StringName] = []
	for candidate: AdventurerData in _core.recruit_pool.candidates:
		new_ids.append(candidate.unit_id)
	assert_int(new_ids.size()).is_equal(3)
	for old_id: StringName in old_ids:
		assert_bool(new_ids.has(old_id)).is_false()
