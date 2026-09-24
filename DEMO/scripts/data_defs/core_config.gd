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
## 命中率基准（命中率 = 基准 + 感知调整值×2% + 技能修正 − 目标闪避，案 17 §3.2；
## 2026-09-24 用户拍板校准 0.80 → 0.85，铁律①数值入表）
@export var hit_base: float = 0.0
## 闪避率基准（闪避 = 基准 + 敏捷调整值×2%，案 17 §3.2；本次校准保持 0.05，
## 顺手参数化与 hit_base 同构，报备口径）
@export var dodge_base: float = 0.0
## 命中率钳制下限（实际命中概率钳制 [min, max]，案 17 §3.4）
@export var hit_clamp_min: float = 0.0
## 命中率钳制上限（同上）
@export var hit_clamp_max: float = 0.0
## 伤害下限（最终伤害 max(1, ...)，案 17 §3.4）
@export var damage_floor: int = 0

# ---- 二级属性派生公式参数（批 B M1：DerivedStats 公式参数入表，纯搬家）----
## 生命基础值（生命 = base + 体质×con_mult + 职业系数×(等级−1)，§3.2）
@export var hp_base: int = 0
## 生命体质乘数（同上式）
@export var hp_con_mult: int = 0
## 资源池基础值（法力/精力 = base + 换算源属性×mult，§3.2）
@export var pool_base: int = 0
## 资源池属性乘数（同上式）
@export var pool_mult: int = 0
## 命中率感知调整值权重（基准 + 感调×本值，§3.2 #4）
@export var attr_hit_weight: float = 0.0
## 闪避率敏捷调整值权重（§3.2）
@export var attr_dodge_weight: float = 0.0
## 异常状态抗性基础值（§3.2）
@export var status_resist_base: float = 0.0
## 异常状态抗性调整值权重（max(体调,意调)×本值，§3.2）
@export var status_resist_weight: float = 0.0
## 物理/法术抗性调整值权重（体质/感知轨同值，§3.2）
@export var resist_weight: float = 0.0
## 暴击率基础值（§3.2/§3.4）
@export var crit_base: float = 0.0
## 暴击率幸运调整值权重（§3.2）
@export var crit_luck_weight: float = 0.0
## 暴击率敏捷调整值权重（§3.2）
@export var crit_agility_weight: float = 0.0
## 暴击伤害倍率基础值（150% 基础 + 词条加成，§3.2）
@export var crit_mult_base: float = 0.0

# ---- 移动力/行动参数（批 B M2/M3）----
## 移动力基准段上限（职业 + 敏捷加成合计封顶；状态修正不封顶——17-C8）
@export var move_base_cap: int = 0
## 敏捷移动加成门槛（敏捷 ≥ 本值时移动力 +1，17-C8）
@export var agility_move_bonus_line: int = 0
## 敌方 AI 怒吼义务门槛（3×3 内我方数 ≥ 本值才考虑怒吼——AI 行为可调参数）
@export var ai_roar_ally_count_line: int = 0

# ---- 招募参数（批 B M4）----
## 招募属性钳制带下限（百分位）
@export var recruit_band_min: int = 0
## 招募属性钳制带上限（百分位）
@export var recruit_band_max: int = 0

# ---- 内容计数基线（批 C M6：校验器计数带参数化——M2 加内容改表即可，
## 基线值随内容扩展同表维护；min/max 同值 = 恒定断言）----
## 技能计数带（六职业普攻 / 职业档 1 技 / 敌方技 / 敌方通用普攻）
@export var content_skill_attacks_min: int = 0
@export var content_skill_attacks_max: int = 0
@export var content_class_skills_min: int = 0
@export var content_class_skills_max: int = 0
@export var content_enemy_skills_min: int = 0
@export var content_enemy_skills_max: int = 0
@export var content_enemy_common_min: int = 0
@export var content_enemy_common_max: int = 0
## 状态表计数带
@export var content_status_min: int = 0
@export var content_status_max: int = 0
## 敌人 / 敌方队伍计数带
@export var content_enemies_min: int = 0
@export var content_enemies_max: int = 0
@export var content_packs_min: int = 0
@export var content_packs_max: int = 0
## 地图 / 地格 / 装备计数带
@export var content_maps_min: int = 0
@export var content_maps_max: int = 0
@export var content_tiles_min: int = 0
@export var content_tiles_max: int = 0
@export var content_equip_min: int = 0
@export var content_equip_max: int = 0

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
