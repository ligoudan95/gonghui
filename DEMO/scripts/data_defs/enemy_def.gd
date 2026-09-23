## 敌人定义（EnemyDef）
## 职责：承载敌方单位的完整参数：属性表、生命、武器加值、护甲（物理/法术
## 双轨同值口径）、抗性、移动、资源池、技能列表、通用普攻、AI 档位、
## 掉落引用与头像。
## 数据来源：案 9《战棋战斗》；案 17《数值专项案》§3.8（敌人表：2 杂兵 + 1 精英
## 全参数；敌人护甲值同计物理/法术两轨——同玩家装备口径 §3.11 #7）/§3.11 #8。
## id 命名规范：battle/enemies 域，小写下划线、带出没区域语义前缀
## （批 2 与 17 案 §3.8 敌人表定名锁定），文件名与 id 同名。
class_name EnemyDef
extends Resource

## 种族系标签（野兽系 / 人形系，用于种族克制与文案口径）
enum RaceTag {
	BEAST,
	HUMANOID,
}

## 敌人 id
@export var id: StringName = &""
## 中文名（如「矿道魔宠」）
@export var display_name: String = ""
## 角色标签（杂兵/精英 等职能标记，语义 token）
@export var role_tag: StringName = &""
## 种族系（野兽系 / 人形系）
@export var race_tag: RaceTag = RaceTag.BEAST
## 属性表：StringName 一级属性 id -> int 属性值
@export var attrs: Dictionary[StringName, int] = {}
## 生命上限
@export var hp: int = 1
## 武器加值（进入伤害公式的攻击加值）
@export var weapon_bonus: int = 0
## 护甲值（物理/法术两轨同值，案 17 §3.8/§3.11 #7）
@export var armor: int = 0
## 抗性百分比（乘法减免轨，0.0-1.0）
@export var resist_pct: float = 0.0
## 战场移动范围（格）
@export var move_range: int = 1
## 资源池（敌方技能消耗的资源上限，0 = 无资源轨）
@export var resource_pool: int = 0
## 主动技能 id 列表（class/skills 域，skl_ 前缀敌方技能）
@export var skill_ids: Array[StringName] = []
## 通用普攻技能 id（skl_atk_enemy_common，17-C16 承接行）
@export var common_attack_skill_id: StringName = &"skl_atk_enemy_common"
## AI 档位（行为复杂度标记，批 3+ 战斗 AI 消费）
@export var ai_level: int = 1
## 掉落表引用 id（经济域资源引用，批 2 落表）
@export var drop_ref: StringName = &""
## 头像资源 id（路径经 assets 域 AssetRegistry 映射）
@export var portrait_id: StringName = &""

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
