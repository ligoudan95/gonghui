## UnitBadge 伤害预览契约单元测试（2026-09-24 二轮试玩反馈）+ E1 等距
## 锚定组（sprite 比例锚定/条锚定 sprite 顶/椭圆底圈存在性·阵营双色·倒地隐藏）。
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

func test_once_action_last_frame_visible_then_fallback_swaps_atlas() -> void:
	## M6 修复契约：单次动作末帧可见性——advance 推到末帧的当帧末帧 region
	## 落位（修复前推到末帧与回落同帧发生，末帧被吞：frame_index 净变化 0 →
	## region 不重设，两帧动作的挥砍帧从未渲染）；末帧停留满一个动画帧时长
	## 才回落 IDLE，且回落时 atlas 切回 idle 竖条（修复前 region 残留上一动作
	## 首帧、竖条不切）
	var badge: UnitBadge = _MakeAnimBadge()
	assert_bool(badge.play_action(UnitAnimState.Action.MELEE_ATTACK)).is_true()
	var atlas: AtlasTexture = badge.get("_anim_atlas") as AtlasTexture
	# 逐半帧步推进直到末帧落位（cfg 未注入 → fps 兜底 UiTheme.ANIM_IDLE_FPS）
	var frame_time: float = 1.0 / UiTheme.ANIM_IDLE_FPS
	for i: int in 20:
		badge.call("_AdvanceAnim", frame_time * 0.5)
		if int(badge.get("_last_frame_index")) == 1:
			break
	assert_int(badge.anim.frame_index).is_equal(1) \
			.override_failure_message("未推进到末帧")
	assert_float(atlas.region.position.y).is_equal(128.0) \
			.override_failure_message("末帧未落位（挥砍帧被吞）")
	assert_int(atlas.atlas.get_height()).is_equal(256)
	# 末帧停留期间不回落（半帧 < 帧时长）
	badge.call("_AdvanceAnim", frame_time * 0.5)
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.MELEE_ATTACK) \
			.override_failure_message("末帧停留期提前回落")
	# 停满一个帧时长 → 回落 IDLE：帧位归零 + atlas 切回 idle 竖条
	badge.call("_AdvanceAnim", frame_time)
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.IDLE)
	assert_int(badge.anim.frame_index).is_equal(0)
	assert_float(atlas.region.position.y).is_equal(0.0)
	assert_int(atlas.atlas.get_height()).is_equal(256)

func test_once_hold_window_blocks_low_priority_external_request() -> void:
	## M6 修复二段契约：末帧保护窗——单次动作末帧停留未满一个动画帧时长时，
	## 低优先级外部请求（移动 tween 完成回调/回合流转的 IDLE——末帧停住后
	## is_once_finished 使 transient_playing=false 失去压制）被拒；高优先级
	## （HIT 受击）照常打断；自然回落仍按停留计时走（保护窗拒后停留满即回落）
	var badge: UnitBadge = _MakeAnimBadge()
	assert_bool(badge.play_action(UnitAnimState.Action.MELEE_ATTACK)).is_true()
	var frame_time: float = 1.0 / UiTheme.ANIM_IDLE_FPS
	for i: int in 20:
		badge.call("_AdvanceAnim", frame_time * 0.5)
		if int(badge.get("_last_frame_index")) == 1:
			break
	assert_int(badge.anim.frame_index).is_equal(1)
	# 保护窗内（停留仅半帧时长）：外部 IDLE（移动 tween 回调）被拒
	badge.call("_AdvanceAnim", frame_time * 0.5)  # 停留累计 0.5 帧时长（推进计时）
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.MELEE_ATTACK)
	assert_bool(badge.play_action(UnitAnimState.Action.IDLE)).is_false() \
			.override_failure_message("保护窗内低优先级请求未被拦截——末帧会被外部回调吞帧")
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.MELEE_ATTACK)
	# 保护窗内高优先级（HIT prio 3 > MELEE 2）照常打断
	assert_bool(badge.play_action(UnitAnimState.Action.HIT)).is_true()
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.HIT)
	# HIT 播完回落前 IDLE 同受保护窗（同一收口对 HIT 亦生效）
	for i: int in 20:
		badge.call("_AdvanceAnim", frame_time * 0.5)
		if int(badge.get("_last_frame_index")) == 1:
			break
	badge.call("_AdvanceAnim", frame_time * 0.5)
	assert_bool(badge.play_action(UnitAnimState.Action.IDLE)).is_false()
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.HIT)
	# 停留满一个帧时长后自然回落（不被保护窗无限拦——回落走 _AdvanceAnim）
	badge.call("_AdvanceAnim", frame_time)
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.IDLE)

func _MakeAnimBadge() -> UnitBadge:
	## 构建带六动作假竖条纹理的挂树徽章（128×256 两帧竖条 ×2——动画链路
	## 用例夹具；非空纹理表走 sprite 分支建 _anim_atlas）
	## 参数：无
	## 返回：已 setup 的徽章（auto_free 释放）
	var unit := BattleUnit.new()
	unit.unit_id = &"test_anim_unit"
	unit.current_hp = 50
	unit.max_hp = 100
	var badge := UnitBadge.new()
	add_child(badge)
	auto_free(badge)
	var strip: ImageTexture = ImageTexture.create_from_image(Image.create(
			SpriteResolver.ANIM_FRAME_SIZE, SpriteResolver.ANIM_FRAME_SIZE * 2,
			false, Image.FORMAT_RGBA8))
	var textures: Dictionary = {
		UnitAnimState.Action.IDLE: strip,
		UnitAnimState.Action.MELEE_ATTACK: strip,
	}
	badge.setup(unit, 72.0, null, textures)
	return badge

# ---- E1 等距锚定组（sprite 比例/条锚定 sprite 顶/椭圆底圈）----

func _MakeIsoBadge(cell_width: float, side: int, cfg: CoreConfig = null) -> UnitBadge:
	## 构建等距锚定测试徽章（cfg 可注入——空 = 纯兜底模式）
	## 参数 cell_width：格菱形全宽；side：阵营（SkillDef.SkillSide）；
	## cfg：总控配置（可空）
	## 返回：已 setup 的徽章（auto_free 释放）
	var unit := BattleUnit.new()
	unit.unit_id = &"test_iso_unit"
	unit.current_hp = 50
	unit.max_hp = 100
	unit.side = side
	var badge := UnitBadge.new()
	add_child(badge)
	auto_free(badge)
	badge.setup(unit, cell_width, cfg)
	return badge

func test_sprite_iso_ratio_anchoring() -> void:
	## sprite 比例锚定：显示宽 = cell_width × sprite_width_ratio（兜底 0.9）、
	## 水平居中、底边踩 feet 线（兜底 0.5 = 菱形中心——cell_height = 100×0.5）
	##（无纹理装配走 _fallback 占位色块——与 sprite 同锚定几何）
	var badge: UnitBadge = _MakeIsoBadge(100.0, SkillDef.SkillSide.ALLY)
	var sprite: ColorRect = badge._fallback
	assert_object(sprite).is_not_null()
	var expected_width: float = 100.0 * UiTheme.ISO_SPRITE_WIDTH_RATIO * 0.7
	assert_float(sprite.size.x).is_equal_approx(expected_width, 0.001)
	assert_float(sprite.size.y).is_equal_approx(expected_width, 0.001)
	assert_float(sprite.position.x).is_equal_approx((100.0 - expected_width) * 0.5, 0.001)
	# 底边 = cell_height(50) × feet_y_ratio(0.5) = 25
	assert_float(sprite.position.y + sprite.size.y).is_equal_approx(
			50.0 * UiTheme.ISO_FEET_Y_RATIO, 0.001)
	assert_float(badge.cell_width).is_equal(100.0)
	assert_float(badge._cell_height).is_equal_approx(50.0, 0.001)

func test_bars_anchor_at_sprite_top() -> void:
	## 条锚定 sprite 顶：HP/资源条 y = sprite 顶 + BAR_*_Y 偏移、条宽 =
	## cell_width − BAR_X_MARGIN×2（E1：原格顶锚定改 sprite 顶——sprite 顶 =
	## feet 线 − sprite 显示宽，无纹理态条仍锚 sprite 几何位（占位色块是
	## sprite 的缩小呈现，非条锚基准））
	var badge: UnitBadge = _MakeIsoBadge(100.0, SkillDef.SkillSide.ALLY)
	var feet_y: float = 50.0 * UiTheme.ISO_FEET_Y_RATIO
	var sprite_width: float = 100.0 * UiTheme.ISO_SPRITE_WIDTH_RATIO
	var sprite_top: float = feet_y - sprite_width
	assert_float(badge._hp_back.position.y).is_equal_approx(
			sprite_top + UnitBadge.BAR_HP_Y, 0.001)
	assert_float(badge._res_back.position.y).is_equal_approx(
			sprite_top + UnitBadge.BAR_RES_Y, 0.001)
	assert_float(badge._hp_back.size.x).is_equal_approx(
			100.0 - UnitBadge.BAR_X_MARGIN * 2.0, 0.001)
	assert_float(badge._hp_back.position.x).is_equal(UnitBadge.BAR_X_MARGIN)

func test_base_ring_visible_with_side_colors() -> void:
	## 椭圆底圈：存活可见 + 阵营双色（ALLY 蓝 / ENEMY 红——cfg 空走 UiTheme
	## 兜底；cfg 注入走表值）
	var ally: UnitBadge = _MakeIsoBadge(100.0, SkillDef.SkillSide.ALLY)
	assert_bool(ally._base_ring_visible).is_true()
	assert_bool(ally._base_ring_color.is_equal_approx(UiTheme.BADGE_BASE_RING_ALLY)).is_true()
	var enemy: UnitBadge = _MakeIsoBadge(100.0, SkillDef.SkillSide.ENEMY)
	assert_bool(enemy._base_ring_color.is_equal_approx(UiTheme.BADGE_BASE_RING_ENEMY)).is_true()
	var cfg: CoreConfig = auto_free(CoreConfig.new())
	cfg.ui_battle_iso_ratio = 0.5
	cfg.ui_badge_base_ring_ally_color = Color(0.1, 0.2, 0.3, 1.0)
	var tuned: UnitBadge = _MakeIsoBadge(100.0, SkillDef.SkillSide.ALLY, cfg)
	assert_bool(tuned._base_ring_color.is_equal_approx(Color(0.1, 0.2, 0.3, 1.0))).is_true()

func test_base_ring_hidden_on_downed() -> void:
	## 倒地底圈隐藏：refresh 倒地 → _base_ring_visible=false（尸态只留 sprite）
	var badge: UnitBadge = _MakeIsoBadge(100.0, SkillDef.SkillSide.ALLY)
	assert_bool(badge._base_ring_visible).is_true()
	badge.unit.current_hp = 0
	badge.unit.alive = false
	badge.refresh()
	assert_bool(badge._base_ring_visible) \
			.override_failure_message("倒地态底圈应随条一并隐藏").is_false()
