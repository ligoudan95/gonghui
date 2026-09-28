## 设施等级效果（FacilityLevelDef，独立内嵌子资源）
## 职责：设施单级参数行——升级花费与该级效果值（宿舍：容量/休养缩减天数；
## 训练场：板凳经验分享率）；按所属设施 kind 只消费对应效果字段，其余为 0 占位。
## 数据来源：案 3《公会等级与设施》§2.2（宿舍/训练场效果曲线占位）；
## 案 17 §3.5/§3.7/§3.11 #10（宿舍 800·容量 6→8·休养 −1；训练场 600·分享 0.3→0.4）。
## id 命名规范：内嵌子资源无独立 id、不落独立文件（铁律②表内零路径口径）。
## 注：独立脚本文件（非内部类）——内部类无法跨 .tres 序列化（M2 批 1 实测，
## RewardDef 先例）。
class_name FacilityLevelDef
extends Resource

## 等级序号（从 1 起，与所属 FacilityDef.levels 下标 + 1 恒一致——V-M4-fac-domain 校验）
@export var level: int = 1
## 升级到本级的花费（Lv1 = 0 初始级无升级语义；Lv ≥ 2 为正数——V-M4-fac-domain 校验）
@export var upgrade_cost: int = 0
## 宿舍容量（本级冒险者上限；仅 facility_kind == DORMITORY 消费）
@export var dorm_capacity: int = 0
## 重伤休养缩减天数（宿舍效果：基础天数 − 本值、下限 1；仅 DORMITORY 消费）
@export var rest_days_reduction: int = 0
## 板凳经验分享率（训练场效果：板凳成员经验 = 基础经验 × 本值；仅 TRAINING 消费）
@export var bench_share_rate: float = 0.0
