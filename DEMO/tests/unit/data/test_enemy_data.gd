## 敌人与队伍数据表单元测试（M0 批 2）
## 覆盖：3 敌 + 3 配计数、技能引用闭合、通用普攻统一、种族系别、
## 区间中值定值抽查（17 案 §3.8）、队伍编成结构（配置行）。
extends GdUnitTestSuite

## GameData 自动加载脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 实例
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData 并显式初始化
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

func test_enemy_and_pack_counts() -> void:
	## 敌人 3（2 杂兵 + 1 精英）、敌方队伍 3（17 案 §3.11 #8）
	assert_int(_game_data.get_domain(&"battle/enemies").size()).is_equal(3)
	assert_int(_game_data.get_domain(&"battle/enemy_packs").size()).is_equal(3)

func test_enemy_skill_references_closed() -> void:
	## 敌人技能引用闭合：skill_ids 与通用普攻均存在；通用普攻统一 skl_atk_enemy_common
	for record: Resource in _game_data.get_domain(&"battle/enemies"):
		var enemy := record as EnemyDef
		assert_str(String(enemy.common_attack_skill_id)).is_equal("skl_atk_enemy_common")
		for skill_id: StringName in enemy.skill_ids:
			var skill: SkillDef = _game_data.get_record(skill_id)
			assert_object(skill) \
					.override_failure_message("敌人 '%s' 技能 '%s' 不存在" % [enemy.id, skill_id]).is_not_null()

func test_race_tags_and_roles() -> void:
	## 种族系别：变异鼠 = 野兽系；哥布林矿工/矿洞祸首 = 人形系；角色标签杂兵/精英
	var rat: EnemyDef = _game_data.get_record(&"en_m1_mutant_rat")
	var goblin: EnemyDef = _game_data.get_record(&"en_m1_goblin_miner")
	var elite: EnemyDef = _game_data.get_record(&"en_m1_elite_boss")
	assert_int(rat.race_tag).is_equal(EnemyDef.RaceTag.BEAST)
	assert_int(goblin.race_tag).is_equal(EnemyDef.RaceTag.HUMANOID)
	assert_int(elite.race_tag).is_equal(EnemyDef.RaceTag.HUMANOID)
	assert_str(String(rat.role_tag)).is_equal("trash")
	assert_str(String(elite.role_tag)).is_equal("elite")
	assert_str(String(rat.display_name)).is_equal("变异鼠")
	assert_str(String(elite.display_name)).is_equal("矿洞祸首")

func test_enemy_stat_values() -> void:
	## 区间中值定值（17 案 §3.8）：杂兵全 9/hp55/护甲2/移动4/精力12；
	## 精英全 11/hp110/武器4/护甲4/抗性5%/精力32（杂兵武器区间 2-3 取上值 3）
	var rat: EnemyDef = _game_data.get_record(&"en_m1_mutant_rat")
	for attr_id: StringName in rat.attrs:
		assert_int(rat.attrs[attr_id]).is_equal(9)
	assert_int(rat.hp).is_equal(55)
	assert_int(rat.weapon_bonus).is_equal(3)
	assert_int(rat.armor).is_equal(2)
	assert_float(rat.resist_pct).is_equal_approx(0.0, 0.001)
	assert_int(rat.move_range).is_equal(4)
	assert_int(rat.resource_pool).is_equal(12)
	var elite: EnemyDef = _game_data.get_record(&"en_m1_elite_boss")
	for attr_id: StringName in elite.attrs:
		assert_int(elite.attrs[attr_id]).is_equal(11)
	assert_int(elite.hp).is_equal(110)
	assert_int(elite.weapon_bonus).is_equal(4)
	assert_int(elite.armor).is_equal(4)
	assert_float(elite.resist_pct).is_equal_approx(0.05, 0.001)
	assert_int(elite.move_range).is_equal(4)
	assert_int(elite.resource_pool).is_equal(32)

func test_pack_compositions() -> void:
	## 队伍编成：随机=池×3；巢穴=精英1+池2-3；魔宠巢=鼠2+哥布林1；
	## battle_map_ref 已回填（M1 批 1：随机→8×8 / 巢穴→10×10 / 魔宠巢→复用 8×8）
	var random_pack: EnemyPackDef = _game_data.get_record(&"enc_m1_random_pack")
	assert_int(random_pack.entries.size()).is_equal(1)
	assert_bool(random_pack.entries[0].enemy_ids.has(&"en_m1_mutant_rat")).is_true()
	assert_bool(random_pack.entries[0].enemy_ids.has(&"en_m1_goblin_miner")).is_true()
	assert_int(random_pack.entries[0].count_min).is_equal(3)
	assert_int(random_pack.entries[0].count_max).is_equal(3)
	assert_bool(random_pack.entries[0].is_elite).is_false()
	assert_str(String(random_pack.battle_map_ref)).is_equal("btm_m1_random_8x8")
	var lair_pack: EnemyPackDef = _game_data.get_record(&"enc_m1_lair_pack")
	assert_int(lair_pack.entries.size()).is_equal(2)
	assert_str(String(lair_pack.entries[0].enemy_ids[0])).is_equal("en_m1_elite_boss")
	assert_bool(lair_pack.entries[0].is_elite).is_true()
	assert_int(lair_pack.entries[1].count_min).is_equal(2)
	assert_int(lair_pack.entries[1].count_max).is_equal(3)
	assert_str(String(lair_pack.battle_map_ref)).is_equal("btm_m1_lair_10x10")
	var wisp_pack: EnemyPackDef = _game_data.get_record(&"enc_m1_wisp_nest")
	assert_int(wisp_pack.entries.size()).is_equal(2)
	assert_str(String(wisp_pack.entries[0].enemy_ids[0])).is_equal("en_m1_mutant_rat")
	assert_int(wisp_pack.entries[0].count_min).is_equal(2)
	assert_int(wisp_pack.entries[1].count_min).is_equal(1)
	assert_str(String(wisp_pack.battle_map_ref)).is_equal("btm_m1_random_8x8")
