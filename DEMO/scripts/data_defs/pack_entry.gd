## 队伍条目（PackEntry）
## 职责：承载敌方队伍（EnemyPackDef）中的单条生成条目：候选敌人池、
## 生成数量区间与精英标记；内嵌于 EnemyPackDef.entries。
## 数据来源：案 9《战棋战斗》（敌方队伍配置）；案 17《数值专项案》
## §3.8（敌方队伍构成）/§3.11 #8（敌方队伍配置表）。
## id 命名规范：本类为内嵌子资源，无独立 id；enemy_ids 引用 battle/enemies 域定名。
## （方案许可：PackEntry 内嵌或独立类——取独立类，便于 .tres 文本编辑与类型化数组序列化。）
class_name PackEntry
extends Resource

## 候选敌人 id 池（battle/enemies 域；生成时按权重/随机取用，批 3 战斗装配消费）
@export var enemy_ids: Array[StringName] = []
## 生成数量下限
@export var count_min: int = 1
## 生成数量上限
@export var count_max: int = 1
## 是否精英位（精英标记，影响生成与掉落口径）
@export var is_elite: bool = false
