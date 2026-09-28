## 成长核心单元测试（M4 批 1）
## 覆盖：100×L 曲线连升/全属性+1+倾向+1/未选倾向悬置补加/技能点出生+每级/
## 等级上限 5 封顶/板凳分享 30%/40%（基数=基础经验）/技能解锁校验。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 与配置
var _game_data: Node
var _cfg: CoreConfig

func before_test() -> void:
	## 用例级前置：GameData 实例 + cfg
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()
	_cfg = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig

func after_test() -> void:
	## 用例级后置：释放 GameData
	_game_data.free()

func _MakeWarrior(tendency: StringName = &"") -> AdventurerData:
	## 手造战士成员（七属性 10 基线）
	var adv := AdventurerData.new()
	adv.unit_id = &"adv_test_warrior"
	adv.class_id = &"cls_warrior"
	adv.attrs = {}
	for attr_id: StringName in AttrKeys.seven_attrs():
		adv.attrs[attr_id] = 10
	adv.skill_points = _cfg.skill_points_birth
	adv.tendency_id = tendency
	return adv

func test_exp_curve_100x() -> void:
	## 升级经验曲线 100×L（17-C5）：L1→2 需 100、L2→3 需 200、L3→4 需 300
	assert_int(GrowthCore.exp_to_next(1, _cfg)).is_equal(100)
	assert_int(GrowthCore.exp_to_next(2, _cfg)).is_equal(200)
	assert_int(GrowthCore.exp_to_next(3, _cfg)).is_equal(300)

func test_multi_levelup_chain() -> void:
	## 连升：350 经验 → L1(耗100)→L2(耗200)→L3，余 50；升级数 2
	var adv := _MakeWarrior()
	var gained: int = GrowthCore.apply_exp(adv, 350, _cfg, _game_data, {})
	assert_int(gained).is_equal(2)
	assert_int(adv.level).is_equal(3)
	assert_int(adv.exp).is_equal(50)
	# 全属性+1×2 级（未选倾向——悬置走 pending 不加侧重）
	assert_int(int(adv.attrs[AttrKeys.STRENGTH])).is_equal(12)
	# 技能点 = 出生 1 + 每级 1×2
	assert_int(adv.skill_points).is_equal(3)

func test_tendency_focus_extra_growth() -> void:
	## 已选倾向：侧重属性每级再+1（tend_warrior_a 焦点=力量——升级 1 级力量 12、
	## 其余 11）
	var adv := _MakeWarrior(&"tend_warrior_a")
	GrowthCore.apply_exp(adv, 100, _cfg, _game_data, {})
	assert_int(adv.level).is_equal(2)
	assert_int(int(adv.attrs[AttrKeys.STRENGTH])).is_equal(12)
	assert_int(int(adv.attrs[AttrKeys.AGILITY])).is_equal(11)

func test_pending_tendency_backfill() -> void:
	## 未选倾向悬置：升级记入 pending；选倾向后按积压档数补加侧重成长并清零
	var pending: Dictionary = {}
	var adv := _MakeWarrior()
	GrowthCore.apply_exp(adv, 100, _cfg, _game_data, pending)
	GrowthCore.apply_exp(adv, 200, _cfg, _game_data, pending)
	assert_int(adv.level).is_equal(3)
	assert_int(int(pending[String(adv.unit_id)])).is_equal(2)
	assert_int(int(adv.attrs[AttrKeys.STRENGTH])).is_equal(12)
	# 选倾向（补加 2 档 ×1）→ 力量 14
	assert_bool(GrowthCore.set_tendency(adv, &"tend_warrior_a", _cfg, _game_data, pending)).is_true()
	assert_int(int(adv.attrs[AttrKeys.STRENGTH])).is_equal(14)
	assert_bool(pending.has(String(adv.unit_id))).is_false()

func test_set_tendency_rejects_foreign() -> void:
	## 倾向归属校验：不属于本职业的倾向拒绝（不改状态）
	var pending: Dictionary = {}
	var adv := _MakeWarrior()
	assert_bool(GrowthCore.set_tendency(adv, &"tend_mage_a", _cfg, _game_data, pending)).is_false()
	assert_str(String(adv.tendency_id)).is_equal("")

func test_level_cap_five() -> void:
	## 等级上限 5 封顶：巨额经验升至 5 级即停（技能点=出生+4；经验滞留）
	var adv := _MakeWarrior()
	var gained: int = GrowthCore.apply_exp(adv, 100000, _cfg, _game_data, {})
	assert_int(adv.level).is_equal(5)
	assert_int(gained).is_equal(4)
	assert_int(adv.skill_points).is_equal(1 + 4)

func test_bench_share_rates() -> void:
	## 板凳分享：80×0.3=24（Lv1）/ 80×0.4=32（Lv2）——基数=基础经验（拍板④）
	assert_int(GrowthCore.bench_share_exp(80, 0.3)).is_equal(24)
	assert_int(GrowthCore.bench_share_exp(80, 0.4)).is_equal(32)

func test_unlock_skill_rules() -> void:
	## 技能解锁：本职业档 1 技能耗点解锁；重复/他职业技能/点不足均拒绝
	var adv := _MakeWarrior()
	assert_bool(GrowthCore.unlock_skill(adv, &"skl_warrior_power_strike", _cfg, _game_data)).is_true()
	assert_int(adv.skill_points).is_equal(0)
	assert_bool(adv.skill_ids.has(&"skl_warrior_power_strike")).is_true()
	# 点不足（0 < 1）
	assert_bool(GrowthCore.unlock_skill(adv, &"skl_warrior_shield_wall", _cfg, _game_data)).is_false()
	# 重复拒绝
	adv.skill_points = 1
	assert_bool(GrowthCore.unlock_skill(adv, &"skl_warrior_power_strike", _cfg, _game_data)).is_false()
	# 他职业技能拒绝（普攻 tier=0 也拒绝）
	assert_bool(GrowthCore.unlock_skill(adv, &"skl_priest_heal", _cfg, _game_data)).is_false()
	assert_bool(GrowthCore.unlock_skill(adv, &"skl_atk_warrior", _cfg, _game_data)).is_false()
