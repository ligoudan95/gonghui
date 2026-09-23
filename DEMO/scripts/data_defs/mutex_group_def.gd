## 互斥组定义（MutexGroupDef）
## 职责：承载状态互斥组（同组状态不能共存，后到顶替或拒绝的裁决依据），
## 组成员为状态 id 列表，与 StatusDef.mutex_group_id 双向对应。
## 数据来源：案 11《状态效果》（互斥组规则）。
## id 命名规范：status/mutex_groups 域，小写下划线 + 语义组名
## （如 &"mutex_move_control" 移动类控制组式样，批 2 定名落表），文件名与 id 同名。
class_name MutexGroupDef
extends Resource

## 互斥组 id（与 StatusDef.mutex_group_id 对应）
@export var id: StringName = &""
## 组成员状态 id 列表（status/stats 域的状态 id）
@export var members: Array[StringName] = []

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
