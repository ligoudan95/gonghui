## 状态数据表单元测试（M0 批 2）
## 覆盖：11 条计数、互斥组双向一致（mgrp_control ↔ root/beWITCH）、
## exposed/ambush 来源 CHECKIN、地格类来源 TILE、DOT 参数与关键修正定值。
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

func test_status_count() -> void:
	## 状态池计数 11（17 案 §3.11 #6 的 10-15 带内）
	assert_int(_game_data.get_domain(&"status/stats").size()).is_equal(11)

func test_mutex_group_bidirectional() -> void:
	## 互斥组双向一致：mgrp_control 成员 = [定身, 蛊惑]，两状态指回该组（17 案 §3.9）
	var group: MutexGroupDef = _game_data.get_record(&"mgrp_control")
	assert_object(group).is_not_null()
	assert_int(group.members.size()).is_equal(2)
	assert_bool(group.members.has(&"DEBUFF_root")).is_true()
	assert_bool(group.members.has(&"DEBUFF_bewitch")).is_true()
	var root: StatusDef = _game_data.get_record(&"DEBUFF_root")
	var bewitch: StatusDef = _game_data.get_record(&"DEBUFF_bewitch")
	assert_str(String(root.mutex_group_id)).is_equal("mgrp_control")
	assert_str(String(bewitch.mutex_group_id)).is_equal("mgrp_control")
	# 其余状态不参与互斥组
	for record: Resource in _game_data.get_domain(&"status/stats"):
		var status := record as StatusDef
		if status.id != &"DEBUFF_root" and status.id != &"DEBUFF_bewitch":
			assert_str(String(status.mutex_group_id)).is_empty()

func test_checkin_sources() -> void:
	## 暴露减益/伏击增益来源 = CHECKIN（18 案检定带入）
	var exposed: StatusDef = _game_data.get_record(&"DEBUFF_exposed")
	var ambush: StatusDef = _game_data.get_record(&"BUFF_ambush")
	assert_int(exposed.allowed_sources.size()).is_equal(1)
	assert_str(String(exposed.allowed_sources[0])).is_equal("CHECKIN")
	assert_int(ambush.allowed_sources.size()).is_equal(1)
	assert_str(String(ambush.allowed_sources[0])).is_equal("CHECKIN")

func test_tile_sources_and_policies() -> void:
	## 地格三状态来源 = TILE 且离格移除（草丛/高地/毒沼，17 案 §3.9）
	var tile_ids: Array[StringName] = [&"BUFF_tile_grass", &"BUFF_tile_highground", &"DEBUFF_tile_poison"]
	for tile_id: StringName in tile_ids:
		var status: StatusDef = _game_data.get_record(tile_id)
		assert_bool(status.allowed_sources.has(&"TILE")) \
				.override_failure_message("地格状态 '%s' 来源缺 TILE" % tile_id).is_true()
		assert_str(String(status.remove_policy)).is_equal("on_leave_tile")

func test_dot_params() -> void:
	## DOT 参数：蚀命诅咒 = 意志×0.5（ATTR_RATIO）；毒沼 = 固定 6（FIXED，免减免轨）
	var curse: StatusDef = _game_data.get_record(&"DEBUFF_curse")
	assert_int(curse.category).is_equal(StatusDef.Category.DOT)
	assert_int(curse.dot.mode).is_equal(DotParams.Mode.ATTR_RATIO)
	assert_str(String(curse.dot.attr_id)).is_equal("willpower")
	assert_float(curse.dot.ratio).is_equal_approx(0.5, 0.001)
	assert_int(curse.default_duration).is_equal(3)
	var poison: StatusDef = _game_data.get_record(&"DEBUFF_tile_poison")
	assert_int(poison.dot.mode).is_equal(DotParams.Mode.FIXED)
	assert_int(poison.dot.fixed).is_equal(6)

func test_key_modifier_values() -> void:
	## 关键修正定值：盾墙物理护甲 +4；疾步移动 +2/闪避 +15%；减速移动 −2；
	## 暴露闪避 −10%；伏击命中 +10%；草丛闪避 +15%；高地面板伤害 ×1.2
	var shield_wall: StatusDef = _game_data.get_record(&"BUFF_shield_wall")
	assert_float(shield_wall.modifiers[&"armor_physical"]).is_equal_approx(4.0, 0.001)
	assert_int(shield_wall.default_duration).is_equal(2)
	var sprint: StatusDef = _game_data.get_record(&"BUFF_sprint")
	assert_float(sprint.modifiers[&"move_range"]).is_equal_approx(2.0, 0.001)
	assert_float(sprint.modifiers[&"dodge"]).is_equal_approx(0.15, 0.001)
	var slow: StatusDef = _game_data.get_record(&"DEBUFF_slow")
	assert_float(slow.modifiers[&"move_range"]).is_equal_approx(-2.0, 0.001)
	assert_int(slow.default_duration).is_equal(2)
	var exposed: StatusDef = _game_data.get_record(&"DEBUFF_exposed")
	assert_float(exposed.modifiers[&"dodge"]).is_equal_approx(-0.10, 0.001)
	var ambush: StatusDef = _game_data.get_record(&"BUFF_ambush")
	assert_float(ambush.modifiers[&"hit"]).is_equal_approx(0.10, 0.001)
	var grass: StatusDef = _game_data.get_record(&"BUFF_tile_grass")
	assert_float(grass.modifiers[&"dodge"]).is_equal_approx(0.15, 0.001)
	var highground: StatusDef = _game_data.get_record(&"BUFF_tile_highground")
	assert_float(highground.modifiers[&"damage_panel_mult"]).is_equal_approx(1.2, 0.001)

func test_control_kinds() -> void:
	## 控制类：定身 = ROOT、蛊惑 = BEWITCH，默认持续 1 回合（17 案 §3.9）
	var root: StatusDef = _game_data.get_record(&"DEBUFF_root")
	assert_int(root.category).is_equal(StatusDef.Category.CONTROL)
	assert_int(root.control_kind).is_equal(StatusDef.ControlKind.ROOT)
	assert_int(root.default_duration).is_equal(1)
	var bewitch: StatusDef = _game_data.get_record(&"DEBUFF_bewitch")
	assert_int(bewitch.control_kind).is_equal(StatusDef.ControlKind.BEWITCH)
	assert_int(bewitch.default_duration).is_equal(1)
