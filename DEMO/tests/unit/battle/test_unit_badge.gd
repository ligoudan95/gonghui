## UnitBadge 伤害预览契约单元测试（2026-09-24 二轮试玩反馈）
## 覆盖：血条伤害预览开关状态契约（show 激活 / clear 清除幂等 / 无效输入不激活 /
## 倒地 refresh 防御清理）。headless 无法测闪烁视觉——只测状态契约。
## 徽章需挂树（show 内 create_tween 要求节点在场景树内）。
extends GdUnitTestSuite

func _MakeBadge(hp: int, max_hp: int) -> UnitBadge:
	## 构建挂树徽章（手填 BattleUnit——不依赖装配链）
	## 参数 hp/max_hp：当前与最大生命
	## 返回：已 setup 的徽章（auto_free 释放）
	var unit := BattleUnit.new()
	unit.unit_id = &"test_unit"
	unit.current_hp = hp
	unit.max_hp = max_hp
	var badge := UnitBadge.new()
	add_child(badge)
	auto_free(badge)
	badge.setup(unit, 72.0)
	return badge

func test_show_activates_preview() -> void:
	## 预览激活：有效伤害 → 激活态 true
	var badge: UnitBadge = _MakeBadge(50, 100)
	assert_bool(badge.is_damage_preview_active()).is_false()
	badge.show_damage_preview(20)
	assert_bool(badge.is_damage_preview_active()).is_true()

func test_clear_deactivates_and_idempotent() -> void:
	## 清除契约：clear 后无预览；重复 clear 幂等不报错
	var badge: UnitBadge = _MakeBadge(50, 100)
	badge.show_damage_preview(20)
	badge.clear_damage_preview()
	assert_bool(badge.is_damage_preview_active()).is_false()
	badge.clear_damage_preview()
	assert_bool(badge.is_damage_preview_active()).is_false()

func test_invalid_amounts_do_not_activate() -> void:
	## 无效输入防御：非正伤害 / 无 HP 单位 → 不激活（内部已清）
	var badge: UnitBadge = _MakeBadge(50, 100)
	badge.show_damage_preview(0)
	assert_bool(badge.is_damage_preview_active()).is_false()
	badge.show_damage_preview(-5)
	assert_bool(badge.is_damage_preview_active()).is_false()
	var downed: UnitBadge = _MakeBadge(0, 100)
	downed.show_damage_preview(10)
	assert_bool(downed.is_damage_preview_active()).is_false()

func test_oversized_amount_clamped_not_crash() -> void:
	## 超额伤害（超过当前 HP）钳制在血条内——仍激活不崩溃
	var badge: UnitBadge = _MakeBadge(10, 100)
	badge.show_damage_preview(999)
	assert_bool(badge.is_damage_preview_active()).is_true()

func test_refresh_on_downed_clears_preview() -> void:
	## 防御路径：预览中倒地（refresh）→ 自动清理
	var badge: UnitBadge = _MakeBadge(50, 100)
	badge.show_damage_preview(20)
	assert_bool(badge.is_damage_preview_active()).is_true()
	badge.unit.current_hp = 0
	badge.unit.alive = false
	badge.refresh()
	assert_bool(badge.is_damage_preview_active()).is_false()

func test_repeated_show_replaces_preview() -> void:
	## 重复 show = 换目标值：先清旧再建新（单激活态，不叠加）
	var badge: UnitBadge = _MakeBadge(50, 100)
	badge.show_damage_preview(20)
	badge.show_damage_preview(35)
	assert_bool(badge.is_damage_preview_active()).is_true()

# ---- 动作播放（M6 批 1 / 盲审低12：逻辑进态、视觉缺省一致性）----

func test_play_action_without_texture_still_transitions_state() -> void:
	## 低12：纹理缺失（无 anim_textures 装配的占位回退态）——状态机仍进态：
	## DOWNED 进态后 is_downed_pose 为 true（逻辑尸态不因缺件失效——已死
	## 单位不再站立带血条）；后续请求照常被倒地锁吸收
	var badge: UnitBadge = _MakeBadge(50, 100)
	assert_bool(badge.play_action(UnitAnimState.Action.DOWNED)).is_true()
	assert_bool(badge.is_downed_pose()).is_true()
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.DOWNED)
	assert_bool(badge.play_action(UnitAnimState.Action.HIT)).is_false()
	assert_bool(badge.play_action(UnitAnimState.Action.IDLE)).is_false()

func test_play_action_without_texture_hit_priority_arbitration() -> void:
	## 低12 推及：缺纹理下状态机优先级仲裁照常（手置帧数复现多帧 HIT
	## 「演出中」态——MOVE/攻击类被压制、DOWNED 覆盖；缺件只影响视觉帧）
	var badge: UnitBadge = _MakeBadge(50, 100)
	assert_bool(badge.play_action(UnitAnimState.Action.HIT)).is_true()
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.HIT)
	badge.anim.frame_count = 3
	assert_bool(badge.play_action(UnitAnimState.Action.MOVE)).is_false()
	assert_bool(badge.play_action(UnitAnimState.Action.MELEE_ATTACK)).is_false()
	assert_bool(badge.play_action(UnitAnimState.Action.DOWNED)).is_true()
	assert_bool(badge.is_downed_pose()).is_true()
