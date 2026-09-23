## 总控配置（CoreConfig）
## 职责：承载全局运行口径——运行模式（DEMO/完整版）、系统启用清单、检定与战斗
## 公式参数、探索视野等总控数值，是 GameConfig 自动加载单例的唯一数据源。
## 数据来源：案 16《内容数据与配置化》§2（配置化原则）；案 17《数值专项案》
## §3.1（属性域）/§3.3（D20 检定域）/§3.10（时间与探索域）/§3.11（DEMO 最小数值集）。
## id 命名规范：core 域固定主配置文件 cfg_main（文件名与 id 同名，全库唯一）。
## 数值性质：全部为【占位·试玩校准】（案 17 口径，DEMO 试玩后回调）。
class_name CoreConfig
extends Resource

## 运行模式：DEMO 阶段或完整版
enum Mode {
	DEMO,
	FULL,
}

## 资源 id（core 域固定为 cfg_main，与文件名一致）
## 注：数值字段默认值一律中性（0/空），真实定值由 data/core/cfg_main.tres 显式承载
## （数据表与 schema 分离：改数据不改脚本）
@export var id: StringName = &""
## 运行模式
@export var mode: Mode = Mode.DEMO
## 系统启用清单：StringName 系统键 -> bool 是否启用
## （真键 13 个 / 假键 9 个，清单以案 16 启用隔离原则为准；合法键集合见 GameConfig.SYSTEM_KEYS）
@export var enabled_systems: Dictionary[StringName, bool] = {}
## 调整值换算偏移：调整值 = floor((属性 - attr_modifier_offset) / attr_modifier_divisor)（案 17 §3.3）
@export var attr_modifier_offset: int = 0
## 调整值换算除数（同上式；属性 10 = +0）
@export var attr_modifier_divisor: int = 0
## 难度五档判定线：String 档名（极易/容易/普通/困难/极难）-> int 判定线（案 17 §3.3）
@export var difficulty_tiers: Dictionary[String, int] = {}
## 大成功降线除数 X：降线数 = max(0, floor((幸运 - 10) / X))（案 17 §3.3）
@export var crit_success_drop_divisor: int = 0
## 大成功判定线下限（案 17 §3.3：X=3 下 DEMO 极限幸运触不到，长期护栏）
@export var crit_success_line_min: int = 0
## 幸运兜底 Y：骰点低于 Y 时按 Y 计（骰 1 仍大失败，案 17 §3.3）
@export var luck_floor_y: int = 0
## 幸运兜底 Z 基值：Z = max(z_base, z_base + floor((幸运 - 10) / z_divisor))（案 17 §3.3）
@export var luck_floor_z_base: int = 0
## 幸运兜底 Z 除数（同上式）
@export var luck_floor_z_divisor: int = 0
## 探索视野半径 R（欧氏圆形度量，全员固定值，案 17 §3.10/§3.11 #17）
@export var vision_radius: int = 0
## 暗门检定触发半径（小队所在格与暗门格的格间欧氏距离阈值，案 17 §3.10/§3.11 #17）
@export var secret_door_trigger_radius: int = 0
## 状态叠加上限（同名状态叠加层数上限，案 11 口径）
@export var status_stack_limit: int = 0
## 命中率钳制下限（实际命中概率钳制 [min, max]，案 17 §3.4）
@export var hit_clamp_min: float = 0.0
## 命中率钳制上限（同上）
@export var hit_clamp_max: float = 0.0
## 伤害下限（最终伤害 max(1, ...)，案 17 §3.4）
@export var damage_floor: int = 0

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
