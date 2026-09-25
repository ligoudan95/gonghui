## 战斗开局引用（BattleOpeningDef，独立内嵌子资源）
## 职责：B 类出口的战斗挂点——敌方队伍、先手权/分布 token、初始状态与
## 战后递归出口（EventRunner 侧组装 BattleParams 消费）。
## 数据来源：案 8 §2（开局参数包）；案 9（默认值）；案 18 §2.2（DEMO 两实例）。
## id 命名规范：内嵌子资源无独立 id、不落独立文件。
## 注：独立脚本文件（非内部类）——内部类无法跨 .tres 序列化（M2 批 1 实测）。
class_name BattleOpeningDef
extends Resource

## 敌方队伍配置 id（battle/enemy_packs 域 enc_ 前缀）
@export var pack_id: StringName = &""
## 先手权 token（&"ally_first" / &"enemy_first"——V-M2-ref-battle 值域）
@export var first_strike_token: StringName = &""
## 敌方初始分布 token（&"clustered" / &"spread"——EventRunner 侧映射序列）
@export var enemy_layout_token: StringName = &""
## 初始状态 id（可空——status/stats 域，allowed_sources 须含 CHECKIN）
@export var initial_status_id: StringName = &""
## 战后出口（胜利返回续跑的递归内嵌——通常为 A 类奖励出口）
@export var post_battle: EventOutcomeDef
