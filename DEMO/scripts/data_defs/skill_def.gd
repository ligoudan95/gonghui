## 技能定义（SkillDef）
## 职责：承载我方职业技能与敌方技能的完整参数（所属方、档位、资源消耗、
## 目标类型、射程、命中修正、属性权重、伤害类型、系数、效果列表、演出资源）。
## 数据来源：案 10《职业与技能》§2.1（技能定义表）；案 9《战棋战斗》；
## 案 17《数值专项案》§3.4（DEMO 技能参数表）/§3.8（敌方技能表）；
## 案 21《战棋专项案》（目标形状与战棋口径）。
## id 命名规范：class/skills 域统一 skl_ 前缀 + 小写下划线【占位·架构期可调】
## （D3 落细 2026-09-23）：六职业普攻 = skl_atk_warrior/rogue/mage/priest/
## ranger/arcanist，敌方通用普攻 = skl_atk_enemy_common，其余技能同前缀规则，
## 文件名与 id 同名。权重和约束 = 1.0（±0.01 容差，案 16 校验规则回填）。
class_name SkillDef
extends Resource

## 技能所属方（我方=职业 / 敌方=敌人）
## 注：枚举名用 SkillSide 而非 Side——Godot 4.7 原生已占用 Side 类型名
enum SkillSide {
	ALLY,
	ENEMY,
}

## 资源消耗类型（无 / 法力 / 体力）
enum ResourceKind {
	NONE,
	MANA,
	STAMINA,
}

## 目标阵营（敌方 / 己方 / 自身）
enum TargetSide {
	ENEMY,
	ALLY,
	SELF,
}

## 目标形状（单体 / 范围 / 指定格 / 3x3 光环）
enum TargetShape {
	SINGLE,
	AOE,
	CELL,
	AURA_3X3,
}

## 伤害类型（物理 / 法术，决定减免轨；非伤害技能为 NONE）
enum DamageType {
	PHYSICAL,
	MAGICAL,
	NONE,
}

## 技能 id（skl_ 前缀，如 &"skl_atk_warrior"）
@export var id: StringName = &""
## 中文名（如「挥击」）
@export var display_name: String = ""
## 所属方（我方 / 敌方；敌方通用普攻按「敌方·通用」口径）
@export var side: SkillSide = SkillSide.ALLY
## 所属者 id（我方=职业 id；敌方=敌人 id）
@export var owner_id: StringName = &""
## 档位（普攻不入档位，填 0 表示「内置」——出生自带不占技能点，案 10 §2.5 D3 口径）
@export var tier: int = 0
## 资源消耗类型
@export var resource_type: ResourceKind = ResourceKind.NONE
## 资源消耗量
@export var resource_cost: int = 0
## 目标阵营
@export var target_side: TargetSide = TargetSide.ENEMY
## 目标形状
@export var target_shape: TargetShape = TargetShape.SINGLE
## 射程（格）
@export var range: int = 1
## 命中修正值（施加类与攻击类技能均可用：对命中率/攻击命中的修正，案 9/11）
@export var hit_mod: int = 0
## 属性权重表：StringName 一级属性 id -> float 权重（权重和 = 1.0 ±0.01，案 17 §3.4）
@export var attr_weights: Dictionary[StringName, float] = {}
## 伤害类型（决定物理/法术减免轨；非伤害技能填 NONE）
@export var damage_type: DamageType = DamageType.NONE
## 技能强度系数（伤害 =（Σ 权重×属性 + 武器加值）× 系数，再走减免轨，案 17 §3.4）
@export var power_coefficient: float = 1.0
## 效果列表（SkillEffect 子资源数组：状态施加/治疗/地格生成/战斗修正）
@export var effects: Array[SkillEffect] = []
## 玩家可读效果描述（按钮 hover tooltip 文案来源——UI 零硬编码文案，铁律①
## 口径延伸；2026-09-24 二轮试玩反馈：敌方技能不进玩家按钮可不回填）
@export var description: String = ""
## 演出资源 id（路径经 assets 域 AssetRegistry 映射，表内不写死路径）
@export var vfx_id: StringName = &""

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
