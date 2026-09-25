## 事件出口定义（EventOutcomeDef，内嵌子资源）
## 职责：事件结算的出口配置——出口类型（A/B/C/D）、奖励、授予委托、
## 解锁标记、B 类开局参数包（战斗引用+战后递归出口）与四档结算文本。
## 数据来源：案 8 §2（A/B/C/D 出口机制）；案 18 §2（出口内容）。
## id 命名规范：内嵌子资源无独立 id、不落独立文件（铁律②表内零路径口径）。
class_name EventOutcomeDef
extends Resource

## 出口类型（案 8 §2：A=常规奖励出口；B=战斗出口（开局参数包）；C/D=条件
## 拦截出口——启用标记/消耗状态判定，DEMO 不配实例仅留通路）
enum ExitKind {
	A,
	B,
	C,
	D,
}

## 出口类型
@export var exit_kind: ExitKind = ExitKind.A
## 奖励（可空——纯文本出口如 E1 绕行无奖励）
@export var reward: RewardDef
## 授予委托 id（可空——q_ 前缀，C8 端口；V-M2 校验 ∈ quest/templates 且
## 模板 acquire_channel == EVENT_GRANT）
@export var grant_quest_id: StringName = &""
## 解锁标记 id（可空——unlock_flags 字典键，如暗门 &"secret_door_mine_north"）
@export var unlock_flag: StringName = &""
## 战斗开局引用（B 类出口必填——V-M2-ref-exit 校验）
@export var battle: BattleOpeningDef
## 四档结算文本（键 &"success"/&"crit_success"/&"failure"/&"crit_failure"/
## &"plain"——success/failure 非空、链内 crit 必填，V-M2-four-texts 校验）
@export var texts: Dictionary[StringName, String] = {}

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
