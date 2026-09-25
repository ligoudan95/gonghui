## 事件奖励（RewardDef，独立内嵌子资源）
## 职责：事件/委托出口的三货币载荷——经验/金币/声望展示值。
## 数据来源：案 18 §3.4（DEMO 奖励域：exp 10-20 / gold 5-30 / rep 0-2）。
## id 命名规范：内嵌子资源无独立 id、不落独立文件（铁律②表内零路径口径）。
## 注：独立脚本文件（非内部类）——内部类无法跨 .tres 序列化（M2 批 1 实测）。
class_name RewardDef
extends Resource

## 经验（DEMO 事件 10-20/次——案 18 §3.4）
@export var exp: int = 0
## 金币（常规 5-20、箱柜大额 30——案 18 §3.4）
@export var gold: int = 0
## 声望展示值（1-2/次，DEMO 仅展示）
@export var reputation: int = 0
