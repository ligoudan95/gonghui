## 技能效果（SkillEffect）
## 职责：承载技能的单一效果条目，内嵌于 SkillDef.effects；按 effect_kind
## 取对应参数组（其余参数组忽略），四类：状态施加 / 治疗 / 地格生成 / 战斗修正。
## 数据来源：案 10《职业与技能》§2.1（效果引用列：伤害系数/治疗量/状态施加→案 11/
## 地格生成→案 9）；案 11《状态效果》；案 17《数值专项案》§3.4/§3.8。
## id 命名规范：本类为内嵌子资源，无独立 id；引用的状态/地格 id 沿用各自域命名规范。
class_name SkillEffect
extends Resource

## 效果类型（状态施加 / 治疗 / 地格生成 / 战斗修正）
enum EffectKind {
	STATUS_APPLY,
	HEAL,
	TILE_SPAWN,
	COMBAT_MOD,
}

## 效果类型（决定读取哪组参数）
@export var effect_kind: EffectKind = EffectKind.STATUS_APPLY

# ---- STATUS_APPLY 参数组（状态施加）----
## 施加的状态 id（status/stats 域，案 11 命名）
@export var status_id: StringName = &""
## 状态持续回合数（0 = 用 StatusDef.default_duration）
@export var duration: int = 0
## 状态强度参数（如减速量、护盾量；具体含义由状态定义解释）
@export var power: float = 0.0

# ---- HEAL 参数组（治疗）----
## 治疗换算源属性 id（恢复数值 = 源属性 × ratio + flat，案 3/案 5 口径）
@export var source_attr: StringName = &""
## 治疗换算比率
@export var ratio: float = 0.0
## 治疗固定值部分
@export var flat: int = 0

# ---- TILE_SPAWN 参数组（地格生成）----
## 生成的地格类型 id（案 9 战场地格：毒沼/陷阱等，陷阱=纯伤害地格 DEMO 降级口径）
@export var tile_type_id: StringName = &""
## 地格伤害表达式（占位：批 2 与案 9 口径落细）
@export var damage_expr: String = ""

# ---- COMBAT_MOD 参数组（战斗修正）----
## 修正键（如 &"hit_bonus"、&"dodge_bonus" 等战斗上下文键）
@export var key: StringName = &""
## 修正值
@export var value: float = 0.0
