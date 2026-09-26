## 遭遇权重定义（EncounterWeightDef）
## 职责：按区域承载随机遭遇参数——触发概率、遭遇队伍 id 与单次出征上限；
## 小队每踏入新格经 EncounterJudge.should_trigger 掷值。
## 数据来源：案 7《地图与探索》（随机遭遇口径）；案 17 §3.10（概率域）；
## M3 方案批 1（2 行：矿洞 0.04 上限 1 / 村子 0）。
## id 命名规范：map/encounter_weights 域，encw_ 前缀 + 小写下划线语义
## （enc_ 已被敌方队伍域占用），文件名与 id 同名。
class_name EncounterWeightDef
extends Resource

## 权重 id（如 &"encw_mine"）
@export var id: StringName = &""
## 所属区域 id（world/regions 域）
@export var region_id: StringName = &""
## 每新格触发概率（[0,1]——0 = 区域安全，V-M3-encw-domain 拦截越界）
@export var encounter_chance: float = 0.0
## 随机遭遇队伍 id（battle/enemy_packs 域）
@export var random_pack_id: StringName = &""
## 单次出征随机遭遇上限（已触发次数 ≥ 本值即不再掷）
@export var random_max: int = 1

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
