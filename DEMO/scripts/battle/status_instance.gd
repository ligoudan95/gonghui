## 状态实例（StatusInstance，RefCounted 纯逻辑类）
## 职责：承载一个状态在某单位身上的运行时数据——剩余持续、递减锚点、
## 即时标记、控制锁与叠加层；由 StatusManager 生命周期管理。
## 数据来源：案 11《状态效果》§2.2/§2.3（叠加互斥/递减时序三锚点/
## 1 回合控制行动窗口/蛊惑 P3 例外）；案 17《数值专项案》§3.9。
## 纯逻辑约束：不触任何 autoload；定义侧数据（修正量/DOT 参数）经
## StatusManager 的 status_lookup 按需解析，实例只存 id。
class_name StatusInstance
extends RefCounted

## 状态来源类别（技能 / 地格 / 检定带入）
enum SourceKind {
	SKILL,
	TILE,
	CHECKIN,
}

## 状态 id（status/stats 域引用，如 &"DEBUFF_slow"）
var status_id: StringName = &""
## 来源类别（SKILL / TILE / CHECKIN）
var source_kind: SourceKind = SourceKind.SKILL
## 来源 id（施加技能 id / 地格类型 id / 检定事件 id）
var source_id: StringName = &""
## 剩余持续回合数
var remaining: int = 0
## 递减锚点 = 施加后首个完整回合号（施加回合末不递减；同名重施加仅新 ≥ 旧时重起算）
var first_tick_round: int = 0
## 即时标记（duration = 0：当回合末直接移除，不受递减时序约束——疾步/地格站格类）
var duration_zero: bool = false
## 控制锁剩余行动轮数（控制类 = 持续回合数；行动轮结束递减）
var control_locks: int = 0
## 锁定跳过施加回合（蛊惑 P3 固定 true；施加回合末由回合结算清除）
var from_next_turn_only: bool = false
## 叠加层数（异名同类入场计数；DEMO 单层入场，字段位预留完整版多层）
var layers: int = 1
