## 敌方队伍定义（EnemyPackDef）
## 职责：承载遭遇战敌方队伍的编成（条目列表）与战场地图引用，
## 供随机遭遇/必然遭遇装配消费。
## 数据来源：案 9《战棋战斗》；案 17《数值专项案》§3.8（敌方队伍构成）/
## §3.11 #8；战场规模口径（随机 8×8 / 必然 10×10，§3.9 附表）。
## id 命名规范：battle/enemy_packs 域，小写下划线 + 出没区域语义
## （批 2 与遭遇配置定名锁定），文件名与 id 同名。
class_name EnemyPackDef
extends Resource

## 队伍 id
@export var id: StringName = &""
## 队伍条目列表（PackEntry 子资源数组）
@export var entries: Array[PackEntry] = []
## 战场地图资源引用 id（地图域资源引用，批 4+ 地图系统消费）
@export var battle_map_ref: StringName = &""

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
