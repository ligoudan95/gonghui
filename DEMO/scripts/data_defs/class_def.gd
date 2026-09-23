## 职业定义（ClassDef）
## 职责：承载六职业的属性倾向、属性区间、资源轨、生命系数、移动范围、
## 内置普攻与可选倾向分支，是职业系统（class_skill 域）的数据表。
## 数据来源：案 10《职业与技能》§2.1（六职业表）；案 17《数值专项案》
## §3.1（一级属性域）/§3.2（资源换算源）/§3.11 #2（六职业初始属性区间）。
## id 命名规范：class/classes 域，职业英文小写下划线（warrior/rogue/mage/
## priest/ranger/arcanist，与案 20 职业英文用例一致），文件名与 id 同名。
## 区间数值口径：Vector2i = (下限, 上限)，批 2 按「中值+【占位·试玩校准】」填充。
class_name ClassDef
extends Resource

## 战斗资源轨类型：法力或体力（案 10 §2.1）
enum ResourceType {
	MANA,
	STAMINA,
}

## 职业 id（如 &"warrior"）
@export var id: StringName = &""
## 中文名（如「战士」）
@export var display_name: String = ""
## 定位描述（案 10 §2.1 定位列，如「前排坦克/近战输出」）
@export var role_desc: String = ""
## 主属性列表（一级属性 id，如 [&"strength", &"constitution"]）
@export var main_attrs: Array[StringName] = []
## 初始属性区间：StringName 属性 id -> Vector2i(下限, 上限)（批 2 填中值口径）
@export var attr_ranges: Dictionary[StringName, Vector2i] = {}
## 战斗资源轨类型（法力/体力）
@export var resource_type: ResourceType = ResourceType.MANA
## 资源换算源属性 id（资源量由该属性换算，案 17 §3.2）
@export var resource_source_attr: StringName = &""
## 职业生命系数（生命上限 = 基础值 × 本系数，案 5/案 17 §3.11 #3）
@export var hp_coefficient: float = 1.0
## 战场移动范围（格）
@export var move_range: int = 1
## 内置普攻技能 id（skl_atk_ 前缀，案 10 §3；出生自带不占技能点）
@export var base_attack_skill_id: StringName = &""
## 可选倾向分支列表（TendencyDef 子资源数组）
@export var tendencies: Array[TendencyDef] = []

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
