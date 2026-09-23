## 地格类型定义（TileTypeDef）
## 职责：承载战场地格的类型参数——通行性、移动成本、绑定的站位状态与
## 触发方式（常驻站位生效 / 敌方踏入一次性触发），是 battle/tiles 域的数据表。
## 数据来源：案 9《战棋战斗》（地格机制）；案 17《数值专项案》§3.9
## （地格效果：草丛/高地/毒沼/陷阱）；陷阱=纯伤害地格（第九轮拍板 DEMO 降级，
## 无状态绑定）。
## id 命名规范：battle/tiles 域，tile_ 前缀 + 小写下划线语义，文件名与 id 同名。
class_name TileTypeDef
extends Resource

## 地格类别（普通 / 障碍 / 带状态效果）
enum Kind {
	NORMAL,
	OBSTACLE,
	STATUS,
}

## 触发方式（站位常驻生效 / 敌方踏入一次性触发——陷阱类）
enum Trigger {
	STANDING,
	ENEMY_ENTER_ONCE,
}

## 地格 id（如 &"tile_grass"）
@export var id: StringName = &""
## 中文名（如「草丛」）
@export var display_name: String = ""
## 地格类别
@export var kind: Kind = Kind.NORMAL
## 可通行（障碍为 false；阻挡移动与视线）
@export var walkable: bool = true
## 移动成本（进入该格消耗的移动力；障碍格不参与寻路）
@export var move_cost: int = 1
## 绑定的状态 id（kind = STATUS 时生效；陷阱纯伤害地格留空——第九轮拍板）
@export var status_id: StringName = &""
## 触发方式（STANDING = 站位期间常驻；ENEMY_ENTER_ONCE = 敌方踏入一次性触发）
@export var trigger: Trigger = Trigger.STANDING

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
