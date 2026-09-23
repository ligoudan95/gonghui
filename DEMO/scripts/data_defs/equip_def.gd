## 装备定义（EquipDef）
## 职责：承载装备套件的战斗数值加成（武器加值 / 护甲值）与归属职业引用，
## 供二级属性派生（物理/法术护甲轨）与伤害公式（武器加值项）消费。
## 数据来源：案 17《数值专项案》§3.4（武器加值：战士 4 / 盗贼 3 / 游侠 3 /
## 法师 2 / 牧师 2 / 奇术师 2）+ §3.11 #7（DEMO 初始装备·普通档）。
## id 命名规范：equip 域，eqp_init_ 前缀 = DEMO 初始装备（不可卸下），
## 文件名与 id 同名。
class_name EquipDef
extends Resource

## 装备 id（如 &"eqp_init_warrior"）
@export var id: StringName = &""
## 中文名（如「战士初始装备（重甲套）」）
@export var display_name: String = ""
## 归属职业 id（class/classes 域引用；DEMO 初始装备按职业绑定不可卸下）
@export var class_ref: StringName = &""
## 武器加值（伤害公式（Σ权重×属性+武器加值）×系数 中的加值项）
@export var weapon_bonus: int = 0
## 护甲值（物理/法术双轨同计——17 案 §3.8 表注口径，同敌方护甲）
@export var armor_value: int = 0

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
