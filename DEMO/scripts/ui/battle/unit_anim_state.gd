## 单位动作状态机（UnitAnimState，纯逻辑类——RefCounted）
## 职责：单位徽章帧动画的帧推进与动作切换仲裁（M6 批 1）——六动作
## （idle/move/melee_attack/cast_ranged/hit/downed）的循环/单次语义、
## 优先级抢占（DOWNED 吸收一切 > HIT > 攻击类 > MOVE > IDLE）、
## 同动作幂等拒绝、倒地末帧锁定（尸体常驻——D5=A 拍板）。
## 纯逻辑约束：不触节点树/纹理——帧数由调用方按竖条图高推导注入，
## advance(delta, fps) headless 可测；帧渲染由 UnitBadge 消费 frame_index。
## 循环性按动作语义固定：idle/move 循环回绕；melee_attack/cast_ranged/hit
## 单次播到末帧停（HIT/攻击类停末帧由调用方查 is_once_finished 后回落
## idle）；downed 单次播完锁末帧（吸收一切后续请求）。
class_name UnitAnimState
extends RefCounted

## 动作枚举（序 = SpriteResolver.ANIM_ACTIONS 后缀序一一对应——消费方按
## int 索引；优先级档独立映射见 priority_of：攻击类（MELEE/CAST）同档）
enum Action {
	IDLE,
	MOVE,
	MELEE_ATTACK,
	CAST_RANGED,
	HIT,
	DOWNED,
}

## 循环动作集（advance 回绕；其余单次到末帧停）
const LOOP_ACTIONS: Array[Action] = [Action.IDLE, Action.MOVE]

## 当前动作
var current: Action = Action.IDLE
## 当前帧下标（0 起；单次动作播完 == frame_count - 1）
var frame_index: int = 0
## 当前动作帧数（由竖条图高推导，request 时注入）
var frame_count: int = 1
## 帧推进时间累积（秒——advance 消费，溢出按帧时长逐帧扣减）
var _accum: float = 0.0

static func is_loop(action: Action) -> bool:
	## 动作循环性判定（LOOP_ACTIONS 单源）
	## 参数 action：动作
	## 返回：true = 循环回绕
	return LOOP_ACTIONS.has(action)

static func priority_of(action: Action) -> int:
	## 动作优先级（档位映射——DOWNED 吸收一切 > HIT > 攻击类 > MOVE > IDLE；
	## MELEE_ATTACK/CAST_RANGED **同档**互可切换（中1 盲审修复：此前直接返回
	## 枚举序致 CAST 演出中 request(MELEE) 被压制动作哑火——敌方 AI 交替
	## skl_atk_enemy_common 与 skl_enemy_dirty_trick/plague_bite 即触发；
	## 同档攻击间 request 受理不压制）；DOWNED 经 is_downed_locked 单独
	## 吸收，不入优先级轨
	## 参数 action：动作
	## 返回：优先级（越大越高）
	match action:
		Action.MELEE_ATTACK, Action.CAST_RANGED:
			return 2
		Action.HIT:
			return 3
		Action.DOWNED:
			return 4
		Action.MOVE:
			return 1
		_:
			return 0

func request(action: Action, frames: int = -1) -> bool:
	## 动作切换请求（优先级仲裁）：已倒地恒拒绝（DOWNED 吸收一切）；
	## 同动作重请求幂等返 false（不打断重播）；当前为**未播完的单次动作**
	## （HIT/攻击类演出中）时低优先级请求被压制；循环基态（IDLE/MOVE）与
	## 已播完待回落的单次动作不压制（MOVE 完回落 IDLE / HIT 完回落 IDLE
	## 均经本口受理）；受理时复位帧位并按注入帧数刷新 frame_count
	## 参数 action：目标动作；frames：该动作帧数（> 0 生效；<= 0 保持现值）
	## 返回：true = 受理切换；false = 拒绝（倒地锁/幂等/低优先级压制）
	if is_downed_locked():
		return false
	if action == current:
		return false
	var transient_playing: bool = not is_loop(current) and not is_once_finished()
	if transient_playing and priority_of(action) < priority_of(current):
		return false
	current = action
	frame_index = 0
	_accum = 0.0
	if frames > 0:
		frame_count = frames
	return true

func advance(delta: float, fps: float) -> void:
	## 帧推进：按 fps 换算帧时长逐帧扣减累积——循环动作回绕（末帧→首帧）；
	## 单次动作到末帧停（DOWNED 末帧 = 尸态锁定；HIT/攻击类末帧 =
	## is_once_finished 待调用方回落）；fps <= 0 / 帧数非法时冻结（测试注 0 口径）
	## 参数 delta：帧间隔（秒）；fps：动作帧率（帧/秒）
	## 返回：无
	if fps <= 0.0 or delta <= 0.0 or frame_count <= 0:
		return
	_accum += delta
	var frame_time: float = 1.0 / fps
	while _accum >= frame_time:
		_accum -= frame_time
		if frame_index < frame_count - 1:
			frame_index += 1
		elif is_loop(current):
			frame_index = 0
		else:
			# 单次动作末帧：停（停止扣减——溢出累积清零防长时间后跳变）
			_accum = 0.0
			break

func is_once_finished() -> bool:
	## 单次动作播完判定（调用方消费：HIT/攻击类回落 idle 的时机；
	## 循环动作恒 false；DOWNED 末帧 = 尸态）
	## 参数：无
	## 返回：true = 单次动作已停在末帧
	return not is_loop(current) and frame_index >= frame_count - 1

func is_downed_locked() -> bool:
	## 倒地锁定判定（D5=A：downed 播完锁末帧=尸体常驻至战斗结束——
	## 进入 DOWNED 即锁定，吸收一切后续请求）
	## 参数：无
	## 返回：true = 已倒地锁定
	return current == Action.DOWNED
