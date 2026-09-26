## 区域定义（RegionDef）
## 职责：世界区域登记——区域名与描述；探索图（region_ids）与遭遇权重
## （encw.region_id）的区域归属单源。
## 数据来源：案 7《地图与探索》（区域划分）；M3 方案批 1（3 行：
## reg_city/reg_village/reg_mine）。
## id 命名规范：world/regions 域，reg_ 前缀 + 小写下划线语义，文件名与 id 同名。
class_name RegionDef
extends Resource

## 区域 id（如 &"reg_mine"）
@export var id: StringName = &""
## 中文名（如「矿洞一层」）
@export var display_name: String = ""
## 区域描述（UI 提示文案来源）
@export var description: String = ""

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
