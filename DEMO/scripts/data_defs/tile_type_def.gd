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

## 地格视觉样式（表驱动小集合——批 A H2：地格视觉入表，UI 只按样式分支）
enum Style {
	PLAIN,   ## 普通平色块
	RAISED,  ## 平台凸边（外层底色 + 内层强调色双层）
	BLOCK,   ## 障碍岩块（底色 + 深色内块 + 强调色描边）
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

## 地格底色（批 A H2：视觉表驱动——默认透明 = 未回填，V-A-tile-visual 拦截）
@export var fill_color: Color = Color(0, 0, 0, 0)
## 强调色（RAISED 内层色 / BLOCK 描边色；PLAIN 不消费）
@export var accent_color: Color = Color(0, 0, 0, 0)
## 动态地格标记色（S1-4 入表：ENEMY_ENTER_ONCE 陷阱落入战场的橙点标记色——
## UI 零硬编码口径延伸；默认透明 = 未回填，V-A-tile-visual 拦截）
@export var mark_color: Color = Color(0, 0, 0, 0)
## 视觉样式（PLAIN/RAISED/BLOCK——UI 渲染分支的唯一依据）
@export var style: Style = Style.PLAIN

## 玩家可读效果描述（hover tooltip 文案来源——UI 零硬编码文案，铁律①口径延伸；
## 2026-09-24 试玩反馈：特殊/障碍地格悬停显示描述页签）
@export var description: String = ""

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
