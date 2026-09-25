## 事件修饰定义（EventModifierDef，内嵌子资源）
## 职责：大成功/大失败修饰的实效载荷——额外奖励增量、队伍损耗与修饰
## 演出文本（挂选项侧，结算时按档叠加）。
## 数据来源：案 8 §2（四档修饰机制）；案 18 §3.3（修饰实效规范——链内
## 必须有实效、单点允许纯演出）。
## id 命名规范：内嵌子资源无独立 id、不落独立文件。
class_name EventModifierDef
extends Resource

## 修饰演出文本（大成功=额外发现型 / 大失败=雪上加霜但不断路型）
@export var text: String = ""
## 奖励增量（内嵌——叠加到出口 reward 之上）
@export var reward_delta: RewardDef
## 队伍生命损耗（负数；结算排除已倒地、扣至最低 1 止——案 18 §3.4）
@export var party_hp_delta: int = 0

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
