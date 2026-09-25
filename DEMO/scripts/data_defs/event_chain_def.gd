## 事件链定义（EventChainDef）
## 职责：承载一条事件链的骨架——入口节点、关联委托与触发点（M3 地图层
## 接线）；节点/选项/出口内容分别在 event/nodes、event/options 域。
## 数据来源：案 8《事件与检定》；案 18 §2.1-2.3（DEMO 三链内容）。
## id 命名规范：event/chains 域，chain_ 前缀 + 小写下划线语义，文件名与 id 同名。
class_name EventChainDef
extends Resource

## 链 id（如 &"chain_mine_collapse"）
@export var id: StringName = &""
## 中文名（如「塌方救援」）
@export var display_name: String = ""
## 入口节点 id（event/nodes 域 evn_ 前缀）
@export var entry_node_id: StringName = &""
## 关联委托模板 id（可空——地图固定事件无关联；q_ 前缀）
@export var quest_ref_id: StringName = &""
## 触发点 id（可空——M3 地图层交互点接线后校验；evp_ 前缀）
@export var trigger_point_id: StringName = &""

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
