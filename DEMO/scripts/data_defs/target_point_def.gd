## 目标点定义（TargetPointDef）
## 职责：探索图上的勘查目标点——委托（EXPLORE 类）判据的到达与交互目标；
## 小队交互后经 GoalTracker.on_target_interacted 判定判据达成。
## 数据来源：案 6《委托与声望》（探索类判据）；案 18 §2.6（DEMO 六目标点：
## 矿洞五勘查点 + 村子老井）；M3 方案批 1。
## id 命名规范：map/target_points 域，tp_ 前缀 + 小写下划线语义，
## 文件名与 id 同名。
class_name TargetPointDef
extends Resource

## 目标点 id（如 &"tp_mine_east_gallery"）
@export var id: StringName = &""
## 中文名（如「东岔道矿脉」）
@export var display_name: String = ""
## 所在格坐标
@export var cell: Vector2i = Vector2i.ZERO

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
