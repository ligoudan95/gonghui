## 状态/战斗修正键全集（ModKeys，纯常量类）
## 职责：集中承载全部状态修正键与技能 COMBAT_MOD 效果键——代码消费点
## 统一引常量（批 A H4：原散布于 skill_executor/enemy_ai/battle_unit 的
## 字面量与映射），并为 DataValidator 提供合法键集（状态表 modifiers 拼错
## 键 = get_stat_mod 静默返 0，校验侧拦截）。
## 数据来源：battle_unit._StatusKeyOf 映射 + skill_executor KEY_* +
## data/status/stats 全部状态表实扫汇总（2026-09-24）。
## 纯逻辑约束：无状态纯常量；新增修正键先加此处再消费。
class_name ModKeys
extends RefCounted

# ---- 派生属性同名修正键（BattleUnit.get_derived 同键合并读取）----
## 命中率修正（加算百分点 0-1 域）
const HIT: StringName = &"hit"
## 闪避率修正（加算 0-1 域）
const DODGE: StringName = &"dodge"
## 异常状态抗性修正（加算 0-1 域）
const STATUS_RESIST: StringName = &"status_resist"
## 物理抗性修正（加算 0-1 域）
const PHYS_RESIST: StringName = &"phys_resist"
## 法术抗性修正（加算 0-1 域）
const MAG_RESIST: StringName = &"mag_resist"
## 物理穿甲修正（点数）
const PHYS_PIERCE: StringName = &"phys_pierce"
## 法术穿甲修正（点数）
const MAG_PIERCE: StringName = &"mag_pierce"
## 移动力修正（点数——move_final 终值段叠加）
const MOVE_RANGE: StringName = &"move_range"
## 行动排序速度修正（点数——17-C19 排序专用，不连带敏捷派生）
const SPEED: StringName = &"speed"

# ---- 带前缀映射键（battle_unit._StatusKeyOf：phys_armor←armor_physical 等）----
## 物理护甲修正（点数——盾墙）
const ARMOR_PHYSICAL: StringName = &"armor_physical"
## 法术护甲修正（点数）
const ARMOR_MAGICAL: StringName = &"armor_magical"

# ---- 乘算/加算专键（StatusManager.get_stat_mod 直查）----
## 面板伤害乘算层（高地 ×1.2——DEMO 单源求和口径）
const DAMAGE_PANEL_MULT: StringName = &"damage_panel_mult"

# ---- 技能 COMBAT_MOD 效果键（SkillEffect.key；非 StatusDef.modifiers 域）----
## 本次暴击率加成（背刺 +10% / 敌方下流偷袭 +10%）
const CRIT_BONUS: StringName = &"crit_bonus"
## 种族克制乘算（对亡灵 ×1.5——圣光惩击）
const RACE_UNDEAD_MULT: StringName = &"race_undead_damage_mult"

## StatusDef.modifiers 合法键集（V-A-mod-keys 校验消费——表内键必须可被消费）
static func status_keys() -> Array[StringName]:
	## 参数：无
	## 返回：合法 modifiers 键全集
	return [
		HIT, DODGE, STATUS_RESIST, PHYS_RESIST, MAG_RESIST,
		PHYS_PIERCE, MAG_PIERCE, MOVE_RANGE, SPEED,
		ARMOR_PHYSICAL, ARMOR_MAGICAL, DAMAGE_PANEL_MULT,
	]

## SkillEffect COMBAT_MOD 的 key 合法集（V-A-mod-keys 校验消费）
static func combat_mod_keys() -> Array[StringName]:
	## 参数：无
	## 返回：合法 COMBAT_MOD 键全集
	return [CRIT_BONUS, RACE_UNDEAD_MULT]
