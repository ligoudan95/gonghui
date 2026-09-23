## 冒险者出战数据（AdventurerData，RefCounted 纯逻辑类）
## 职责：承载一名冒险者进入战斗所需的最小数据切片——职业、等级、七属性、
## 技能清单与预解锁标记；为 UnitBuilder.build_ally 的输入（M1 出战装配口径）。
## 数据来源：案 5《冒险者》（属性/等级/技能点）；案 17 §3.1（属性区间）；
## M1 调试口径（用户拍板）：出战单位技能 = 普攻 + 该职业全部 2 技（档 1 全可学，
## 技能点流程 M4）；完整版由公会侧养成数据（存档）填充本结构。
## 纯逻辑约束：不触任何 autoload——game_data 经参数注入。
class_name AdventurerData
extends RefCounted

## 冒险者实例 id（战斗单位 unit_id 来源）
var unit_id: StringName = &""
## 职业 id（class/classes 域）
var class_id: StringName = &""
## 等级（M1 固定 1 级；HP 换算消费）
var level: int = 1
## 七属性表：{StringName 属性 id: int 值}（出生掷值或养成定值）
var attrs: Dictionary = {}
## 已学技能 id 列表（不含普攻；M1 调试口径 = 职业档 1 全部技能）
var skill_ids: Array[StringName] = []
## 预解锁标记（初始 4 人 true / 招募成员 false——案 5 §3，17 案 §3.6 第十轮拍板；
## M1 调试口径下技能全开、本标记仅随结构携带）
var pre_unlocked: bool = false
## 显示名（UI 演出消费）
var display_name: String = ""

static func create_debug(unit_id: StringName, class_id: StringName, attrs: Dictionary,
		game_data: Node) -> AdventurerData:
	## M1 调试口径工厂：技能清单 = 该职业全部档 1（tier=1）技能（普攻另由职业表带出）
	## 参数 unit_id/class_id：实例与职业 id；attrs：七属性表；game_data：GameData（参数注入）
	## 返回：AdventurerData（skill_ids 已按域扫描填充）
	var adv := AdventurerData.new()
	adv.unit_id = unit_id
	adv.class_id = class_id
	adv.attrs = attrs
	adv.pre_unlocked = true
	adv.display_name = String(unit_id)
	var skills: Array[StringName] = []
	for skill_id: StringName in game_data.get_domain_ids(&"class/skills"):
		var skill: SkillDef = game_data.get_record(skill_id) as SkillDef
		if skill != null and skill.owner_id == class_id and skill.tier == 1:
			skills.append(skill_id)
	adv.skill_ids = skills
	return adv
