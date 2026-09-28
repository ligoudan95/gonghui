## 冒险者数据（AdventurerData，RefCounted 纯逻辑类）
## 职责：一名冒险者的完整持久数据——身份（实例/职业/姓名）、成长（等级/经验/
## 技能点/已学技能/倾向）、状态（健康/休养）、出征频次标记与暂缓字段位
## （装备槽/压力/怪癖——铁律⑧启用前不触达）；M1 期为战斗切片（create_debug），
## M4 起为公会名册的成员载体（GuildCore.roster / RecruitPool.candidates）。
## 数据来源：案 5《冒险者》§2/§3（实体全字段结构、状态机、预解锁标记）；
## 案 17 §3.6（成长域收口）。to_dict/from_dict 为存档快照 JSON 桥。
## 纯逻辑约束：不触任何 autoload——game_data 经参数注入。
class_name AdventurerData
extends RefCounted

## 状态机（案 5 §2.5：健康/重伤休养；普通损耗恢复 DEMO 当日全额、无独立态）
enum Status {
	HEALTHY,
	RESTING,
}

## 冒险者实例 id（战斗单位 unit_id 来源；种子=adv_*、招募=adv_recruit_N）
var unit_id: StringName = &""
## 职业 id（class/classes 域）
var class_id: StringName = &""
## 显示名
var display_name: String = ""
## 等级（1 起，上限 cfg.level_cap=5）
var level: int = 1
## 经验（当前级内累计；升级所需 = cfg.exp_per_level_base × 当前等级）
var exp: int = 0
## 七属性表：{StringName 属性 id: int 值}（出生掷值或养成定值）
var attrs: Dictionary = {}
## 已学技能 id 列表（不含普攻；初始 4 人=职业第 1 技预解锁、招募成员空——
## 档 1 全可学经技能点解锁，GrowthCore.unlock_skill）
var skill_ids: Array[StringName] = []
## 当前技能点（出生 cfg.skill_points_birth + 每级 cfg.skill_points_per_level）
var skill_points: int = 0
## 已选职业倾向 id（tend_ 域；空 = 未选——升级侧重成长记入悬置待选后补加）
var tendency_id: StringName = &""
## 状态（健康/休养）
var status: Status = Status.HEALTHY
## 重伤休养剩余天数（仅 RESTING 态有意义；日结算递减归 0 转健康）
var rest_days: int = 0
## 最近一次出征日（每日一次出征校验：last_expedition_day != day；日结算自然过期）
var last_expedition_day: int = 0
## 预解锁标记（初始 4 人 true / 招募成员 false——案 5 §3，17 案 §3.6 拍板）
var pre_unlocked: bool = false
## 装备槽（四槽：武器×1/护甲×1/饰品×2——案 4 #13 定版；DEMO 固定初始套装
## 不卸换，字段位预留，铁律⑧启用前不触达）
var equip_slots: Dictionary = {}
## 压力值（案 14 暂缓——字段位预留，DEMO 不启用）
var stress: int = 0
## 怪癖列表（案 14 暂缓——字段位预留，DEMO 不启用）
var quirks: Array[StringName] = []

## 序列化键集（to_dict 键与 from_dict 校验共用单源——结构变更只改此一处）
const SNAPSHOT_KEYS: Array[String] = [
	"unit_id", "class_id", "display_name", "level", "exp", "attrs",
	"skill_ids", "skill_points", "tendency_id", "status", "rest_days",
	"last_expedition_day", "pre_unlocked", "equip_slots", "stress", "quirks",
]

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
	# 显示名取职业表中文名（2026-09-24 七轮反馈：单位名中文化——敌方链路
	# 直读敌表本就中文，我方此前透传英文 unit_id 是断点；查无回退现状）
	var cls: ClassDef = game_data.get_record(class_id) as ClassDef
	adv.display_name = cls.display_name if cls != null and not cls.display_name.is_empty() \
			else String(unit_id)
	var skills: Array[StringName] = []
	for skill_id: StringName in game_data.get_domain_ids(&"class/skills"):
		var skill: SkillDef = game_data.get_record(skill_id) as SkillDef
		if skill != null and skill.owner_id == class_id and skill.tier == 1:
			skills.append(skill_id)
	adv.skill_ids = skills
	return adv

func to_dict() -> Dictionary:
	## 序列化为可 JSON 化的 Dictionary（键集 = SNAPSHOT_KEYS 单源；
	## StringName 统一转 String——JSON 桥无 StringName 键）
	## 参数：无
	## 返回：含全字段的 Dictionary（String 键）
	var plain_attrs: Dictionary = {}
	for attr_id: StringName in attrs:
		plain_attrs[String(attr_id)] = int(attrs[attr_id])
	var plain_skills: PackedStringArray = PackedStringArray()
	for skill_id: StringName in skill_ids:
		plain_skills.append(String(skill_id))
	var plain_quirks: PackedStringArray = PackedStringArray()
	for quirk_id: StringName in quirks:
		plain_quirks.append(String(quirk_id))
	return {
		"unit_id": String(unit_id),
		"class_id": String(class_id),
		"display_name": display_name,
		"level": level,
		"exp": exp,
		"attrs": plain_attrs,
		"skill_ids": plain_skills,
		"skill_points": skill_points,
		"tendency_id": String(tendency_id),
		"status": status,
		"rest_days": rest_days,
		"last_expedition_day": last_expedition_day,
		"pre_unlocked": pre_unlocked,
		"equip_slots": equip_slots,
		"stress": stress,
		"quirks": plain_quirks,
	}

static func from_dict(data: Dictionary) -> AdventurerData:
	## 反序列化（存档快照 JSON 桥）：键齐备 + 类型校验，任一异常返回 null
	## 参数 data：JSON.parse_string 产出的 Dictionary
	## 返回：AdventurerData；校验失败返回 null（调用方按损坏档处理）
	for key: String in SNAPSHOT_KEYS:
		if not data.has(key):
			return null
	for int_key: String in ["level", "exp", "skill_points", "status", "rest_days",
			"last_expedition_day", "stress"]:
		if not SaveData.IsIntLike(data[int_key]):
			return null
	if not (data["pre_unlocked"] is bool):
		return null
	if not (data["unit_id"] is String) or not (data["class_id"] is String):
		return null
	if not (data["tendency_id"] is String):
		return null
	if not (data["attrs"] is Dictionary) or not (data["equip_slots"] is Dictionary):
		return null
	if not (data["skill_ids"] is Array) and not (data["skill_ids"] is PackedStringArray):
		return null
	if not (data["quirks"] is Array) and not (data["quirks"] is PackedStringArray):
		return null
	var adv := AdventurerData.new()
	adv.unit_id = StringName(String(data["unit_id"]))
	adv.class_id = StringName(String(data["class_id"]))
	adv.display_name = String(data["display_name"])
	adv.level = int(data["level"])
	adv.exp = int(data["exp"])
	var typed_attrs: Dictionary = {}
	for attr_key: String in data["attrs"]:
		typed_attrs[StringName(attr_key)] = int(data["attrs"][attr_key])
	adv.attrs = typed_attrs
	var typed_skills: Array[StringName] = []
	for skill_key: String in data["skill_ids"]:
		typed_skills.append(StringName(skill_key))
	adv.skill_ids = typed_skills
	adv.skill_points = int(data["skill_points"])
	adv.tendency_id = StringName(String(data["tendency_id"]))
	var status_value: int = int(data["status"])
	if status_value < 0 or status_value >= Status.size():
		return null
	adv.status = status_value as Status
	adv.rest_days = int(data["rest_days"])
	adv.last_expedition_day = int(data["last_expedition_day"])
	adv.pre_unlocked = bool(data["pre_unlocked"])
	adv.equip_slots = data["equip_slots"]
	adv.stress = int(data["stress"])
	var typed_quirks: Array[StringName] = []
	for quirk_key: String in data["quirks"]:
		typed_quirks.append(StringName(quirk_key))
	adv.quirks = typed_quirks
	return adv
