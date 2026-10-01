## UnitAnimState 动作状态机单元测试（M6 批 1）
## 覆盖：优先级抢占 / 幂等拒绝 / 回落语义 / 倒地锁定（D5=A）/ 循环回绕 /
## advance 边界（零 fps/零 delta/非法帧数）——纯逻辑 headless 直测。
extends GdUnitTestSuite

func _Make(frame_count: int = 1) -> UnitAnimState:
	## 构造状态机（指定初始帧数）
	## 参数 frame_count：初始帧数
	## 返回：新实例
	var state: UnitAnimState = UnitAnimState.new()
	state.frame_count = frame_count
	return state

# ---- 初始态与 request 基础契约 ----

func test_initial_state_is_idle_first_frame() -> void:
	## 初始态：IDLE 首帧
	var state: UnitAnimState = _Make(2)
	assert_int(state.current).is_equal(UnitAnimState.Action.IDLE)
	assert_int(state.frame_index).is_equal(0)
	assert_bool(state.is_downed_locked()).is_false()
	assert_bool(UnitAnimState.is_loop(state.current)).is_true()

func test_request_same_action_idempotent_false() -> void:
	## 同动作重请求幂等：不打断、返 false
	var state: UnitAnimState = _Make(2)
	state.advance(0.5, 100.0)
	var before: int = state.frame_index
	assert_bool(state.request(UnitAnimState.Action.IDLE, 4)).is_false()
	assert_int(state.frame_index).is_equal(before)
	assert_int(state.current).is_equal(UnitAnimState.Action.IDLE)

func test_request_switch_updates_frame_count_and_resets() -> void:
	## 受理切换：帧位复位 + 注入帧数生效
	var state: UnitAnimState = _Make(4)
	state.advance(0.5, 100.0)
	assert_bool(state.request(UnitAnimState.Action.HIT, 2)).is_true()
	assert_int(state.current).is_equal(UnitAnimState.Action.HIT)
	assert_int(state.frame_index).is_equal(0)
	assert_int(state.frame_count).is_equal(2)

func test_request_frames_nonpositive_keeps_count() -> void:
	## frames <= 0：保持现值帧数（调用方预置口径）
	var state: UnitAnimState = _Make(3)
	assert_bool(state.request(UnitAnimState.Action.MELEE_ATTACK, 0)).is_true()
	assert_int(state.frame_count).is_equal(3)
	assert_bool(state.request(UnitAnimState.Action.CAST_RANGED, -2)).is_true()
	assert_int(state.frame_count).is_equal(3)

# ---- 优先级仲裁 ----

func test_priority_hit_overrides_attack() -> void:
	## HIT > 攻击类：攻击中受击切 HIT
	var state: UnitAnimState = _Make(3)
	assert_bool(state.request(UnitAnimState.Action.MELEE_ATTACK, 3)).is_true()
	assert_bool(state.request(UnitAnimState.Action.HIT, 2)).is_true()
	assert_int(state.current).is_equal(UnitAnimState.Action.HIT)

func test_priority_attack_overrides_move() -> void:
	## 攻击类 > MOVE：移动中出招切攻击
	var state: UnitAnimState = _Make(4)
	assert_bool(state.request(UnitAnimState.Action.MOVE, 4)).is_true()
	assert_bool(state.request(UnitAnimState.Action.CAST_RANGED, 3)).is_true()
	assert_int(state.current).is_equal(UnitAnimState.Action.CAST_RANGED)

func test_priority_move_overrides_idle() -> void:
	## MOVE > IDLE
	var state: UnitAnimState = _Make(2)
	assert_bool(state.request(UnitAnimState.Action.MOVE, 4)).is_true()
	assert_int(state.current).is_equal(UnitAnimState.Action.MOVE)

func test_lower_priority_rejected() -> void:
	## 低优先级被压制：HIT 中请求 MOVE/IDLE 拒绝；攻击中请求 MOVE 拒绝
	var state: UnitAnimState = _Make(2)
	assert_bool(state.request(UnitAnimState.Action.HIT, 2)).is_true()
	assert_bool(state.request(UnitAnimState.Action.MOVE, 4)).is_false()
	assert_bool(state.request(UnitAnimState.Action.IDLE, 2)).is_false()
	assert_int(state.current).is_equal(UnitAnimState.Action.HIT)
	var attacker: UnitAnimState = _Make(2)
	assert_bool(attacker.request(UnitAnimState.Action.CAST_RANGED, 3)).is_true()
	assert_bool(attacker.request(UnitAnimState.Action.MOVE, 4)).is_false()
	assert_int(attacker.current).is_equal(UnitAnimState.Action.CAST_RANGED)

func test_attack_actions_same_tier_switch() -> void:
	## MELEE/CAST 同档：攻击间双向可换（连招场景；中2 盲审修复：补 CAST→MELEE
	## 反向断言锁定契约——此前只有 MELEE→CAST 单向，任何高优先实现都能假通过）
	var state: UnitAnimState = _Make(2)
	assert_bool(state.request(UnitAnimState.Action.MELEE_ATTACK, 3)).is_true()
	assert_bool(state.request(UnitAnimState.Action.CAST_RANGED, 3)).is_true()
	assert_int(state.current).is_equal(UnitAnimState.Action.CAST_RANGED)
	# 反向：CAST 演出未完时 request(MELEE) 亦受理（同档互不压制）
	assert_bool(state.request(UnitAnimState.Action.MELEE_ATTACK, 3)).is_true()
	assert_int(state.current).is_equal(UnitAnimState.Action.MELEE_ATTACK)

func test_idle_fallback_after_hit_finish_accepted() -> void:
	## 回落语义：HIT 播完（is_once_finished）后 request(IDLE) 受理——
	## 压制只作用于「未播完的单次动作」，播完即回落口放行
	var state: UnitAnimState = _Make(2)
	assert_bool(state.request(UnitAnimState.Action.HIT, 2)).is_true()
	assert_bool(state.is_once_finished()).is_false()
	assert_bool(state.request(UnitAnimState.Action.IDLE, 2)).is_false()
	state.advance(10.0, 1.0)
	assert_bool(state.is_once_finished()).is_true()
	assert_bool(state.request(UnitAnimState.Action.IDLE, 2)).is_true()
	assert_int(state.current).is_equal(UnitAnimState.Action.IDLE)

func test_move_yields_to_idle_request() -> void:
	## 循环基态不压制：MOVE（tween 完）→ IDLE 受理
	var state: UnitAnimState = _Make(4)
	assert_bool(state.request(UnitAnimState.Action.MOVE, 4)).is_true()
	assert_bool(state.request(UnitAnimState.Action.IDLE, 2)).is_true()
	assert_int(state.current).is_equal(UnitAnimState.Action.IDLE)

# ---- 倒地锁定（D5=A）----

func test_downed_absorbs_all_requests() -> void:
	## DOWNED 吸收一切：倒地后任何请求（含更高语义的 HIT）恒拒绝
	var state: UnitAnimState = _Make(2)
	assert_bool(state.request(UnitAnimState.Action.DOWNED, 3)).is_true()
	assert_bool(state.is_downed_locked()).is_true()
	assert_bool(state.request(UnitAnimState.Action.HIT, 2)).is_false()
	assert_bool(state.request(UnitAnimState.Action.MELEE_ATTACK, 3)).is_false()
	assert_bool(state.request(UnitAnimState.Action.MOVE, 4)).is_false()
	assert_bool(state.request(UnitAnimState.Action.IDLE, 2)).is_false()
	assert_bool(state.request(UnitAnimState.Action.DOWNED, 3)).is_false()
	assert_int(state.current).is_equal(UnitAnimState.Action.DOWNED)

func test_downed_locks_last_frame() -> void:
	## 尸态锁定：downed 播到末帧后 advance 不再动帧（尸体常驻）
	var state: UnitAnimState = _Make(2)
	assert_bool(state.request(UnitAnimState.Action.DOWNED, 3)).is_true()
	state.advance(1.0, 3.0)
	assert_int(state.frame_index).is_equal(2)
	assert_bool(state.is_once_finished()).is_true()
	state.advance(10.0, 3.0)
	assert_int(state.frame_index).is_equal(2)

func test_downed_replaces_hit_midway() -> void:
	## HIT 中被击倒：DOWNED 覆盖 HIT（跳伤致死由 unit_downed 天然统一）
	var state: UnitAnimState = _Make(2)
	assert_bool(state.request(UnitAnimState.Action.HIT, 2)).is_true()
	assert_bool(state.request(UnitAnimState.Action.DOWNED, 3)).is_true()
	assert_int(state.current).is_equal(UnitAnimState.Action.DOWNED)

# ---- advance 帧推进 ----

func test_loop_wraps_around() -> void:
	## 循环回绕：MOVE 2 帧 @2fps——半秒一帧；末帧（1）后回绕首帧（0）
	var state: UnitAnimState = _Make(2)
	state.request(UnitAnimState.Action.MOVE, 2)
	state.advance(0.5, 2.0)
	assert_int(state.frame_index).is_equal(1)
	state.advance(0.5, 2.0)
	assert_int(state.frame_index).is_equal(0)
	state.advance(0.5, 2.0)
	assert_int(state.frame_index).is_equal(1)
	assert_bool(state.is_once_finished()).is_false()

func test_once_stops_at_last_frame() -> void:
	## 单次动作到末帧停（攻击类）；溢出推进不再动帧
	var state: UnitAnimState = _Make(2)
	state.request(UnitAnimState.Action.MELEE_ATTACK, 3)
	state.advance(10.0, 1.0)
	assert_int(state.frame_index).is_equal(2)
	assert_bool(state.is_once_finished()).is_true()

func test_advance_guards_invalid_fps_delta_frames() -> void:
	## 边界防御：fps<=0 / delta<=0 / 帧数<=0 冻结不崩
	var state: UnitAnimState = _Make(2)
	state.request(UnitAnimState.Action.MOVE, 4)
	state.advance(1.0, 0.0)
	state.advance(1.0, -5.0)
	state.advance(-1.0, 10.0)
	assert_int(state.frame_index).is_equal(0)
	var broken: UnitAnimState = _Make(0)
	broken.frame_count = 0
	broken.advance(1.0, 10.0)
	assert_int(broken.frame_index).is_equal(0)

func test_single_frame_once_immediately_finished() -> void:
	## 单帧动作（hit 规格 [1,2] 下限）：请求即在末帧 = 已完成
	var state: UnitAnimState = _Make(1)
	state.request(UnitAnimState.Action.HIT, 1)
	assert_int(state.frame_index).is_equal(0)
	assert_bool(state.is_once_finished()).is_true()
