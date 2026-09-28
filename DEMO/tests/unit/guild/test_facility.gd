## 设施单元测试（M4 批 1）
## 覆盖：升级扣款即时生效/容量约束 6→8/休养缩减 3→2/分享率 0.3→0.4/
## 上限拦截/余额不足拦截。
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 401
	_core.setup(_game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig,
			_game_data, rng)

func after_test() -> void:
	## 用例级后置：释放 GameData
	_game_data.free()

func test_initial_facility_state() -> void:
	## 初始态：两设施 Lv1（容量 6/分享 0.3/休养基础 3 不减）
	assert_int(int(_core.facility_levels[&"fac_dormitory"])).is_equal(1)
	assert_int(int(_core.facility_levels[&"fac_training_ground"])).is_equal(1)
	assert_int(_core.dorm_capacity()).is_equal(6)
	assert_float(_core.bench_share_rate()).is_equal(0.3)
	assert_int(_core.injury_rest_days()).is_equal(3)

func test_upgrade_deducts_and_applies_immediately() -> void:
	## 升级扣款即时生效：训练场 600 → 分享率 0.4；宿舍 800 → 容量 8/休养 2
	_core.gold = 1500
	assert_bool(_core.upgrade_facility(&"fac_training_ground")).is_true()
	assert_int(_core.gold).is_equal(900)
	assert_int(int(_core.facility_levels[&"fac_training_ground"])).is_equal(2)
	assert_float(_core.bench_share_rate()).is_equal(0.4)
	assert_bool(_core.upgrade_facility(&"fac_dormitory")).is_true()
	assert_int(_core.gold).is_equal(100)
	assert_int(_core.dorm_capacity()).is_equal(8)
	assert_int(_core.injury_rest_days()).is_equal(2)

func test_capacity_gate_opens_at_lv2() -> void:
	## 容量约束 6→8：Lv1 招至 6 满员拦截；升宿舍后 7/8 号可入册
	_core.gold = 9999
	_core.recruit(0)
	_core.recruit(0)
	assert_int(_core.roster.size()).is_equal(6)
	assert_object(_core.recruit(0)).is_null()
	assert_str(_core.last_error).contains("宿舍已满")
	assert_bool(_core.upgrade_facility(&"fac_dormitory")).is_true()
	assert_object(_core.recruit(0)).is_not_null()
	assert_int(_core.roster.size()).is_equal(7)

func test_max_level_gate() -> void:
	## 上限拦截：DEMO 上限 2 级，二次升级拒绝
	_core.gold = 9999
	assert_bool(_core.upgrade_facility(&"fac_dormitory")).is_true()
	assert_bool(_core.upgrade_facility(&"fac_dormitory")).is_false()
	assert_str(_core.last_error).contains("已满级")

func test_insufficient_gold_gate() -> void:
	## 余额不足拦截：初始 500 < 宿舍 800——拒绝且等级/余额不变
	assert_bool(_core.upgrade_facility(&"fac_dormitory")).is_false()
	assert_str(_core.last_error).contains("货币不足")
	assert_int(_core.gold).is_equal(500)
	assert_int(int(_core.facility_levels[&"fac_dormitory"])).is_equal(1)
