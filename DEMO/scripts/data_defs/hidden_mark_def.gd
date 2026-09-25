## 隐藏标记定义（HiddenMarkDef）
## 职责：地图隐藏元素的标记位（暗门/隐藏内容的状态承载）——M2 先建后空
## 0 行（铁律⑧暂缓系统启用清单隔离：域注册与代码路径就位、数据零实例、
## 运行时不触达）；M3 地图层接线后落内容。
## 数据来源：案 7 §2.3（暗门机制）；案 8（标记口径）。
## id 命名规范：event/hidden_marks 域，hm_ 前缀，文件名与 id 同名。
class_name HiddenMarkDef
extends Resource

## 标记 id（如 &"hm_xxx"——M3 落内容）
@export var id: StringName = &""
## 中文短名
@export var display_name: String = ""
## 关联解锁标记 id（unlock_flags 字典键）
@export var unlock_flag: StringName = &""

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
