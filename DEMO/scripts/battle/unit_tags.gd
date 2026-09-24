## 单位标记常量（UnitTags，纯常量类）
## 职责：集中承载 BattleUnit 的 role_tag（职能标记）与 race_tag（种族标记）
## token——批 4 C 组单源化：原散布于 unit_builder（生产）/ skill_executor、
## enemy_ai、unit_badge（消费）/ data_validator（值域校验）的字符串字面量
## 全部收敛到此（口径第二处出现即单源化）。
## 数据来源：EnemyDef.role_tag/race_tag 域值（en_ 表）+ 17 案 §3.8（亡灵克制）。
## 纯逻辑约束：无状态纯常量；新增 token 先加此处再消费。
class_name UnitTags
extends RefCounted

# ---- 职能标记（EnemyDef.role_tag → BattleUnit.role_tag；敌方 AI 分支 +
# UI 精英放大消费）----
## 杂兵
const ROLE_TRASH: StringName = &"trash"
## 精英（穷追/怒吼决策分支 + 徽章 ×1.3 放大）
const ROLE_ELITE: StringName = &"elite"

# ---- 种族标记（EnemyDef.RaceTag 枚举 → StringName 化；种族克制消费）----
## 野兽
const RACE_BEAST: StringName = &"beast"
## 人形
const RACE_HUMANOID: StringName = &"humanoid"
## 亡灵（种族克制触发标记——圣光惩击 ×1.5）
const RACE_UNDEAD: StringName = &"undead"

## EnemyDef.role_tag 值域（DataValidator V-B2 校验消费——表值必须可被消费）
static func role_tags() -> Array[StringName]:
	## 参数：无
	## 返回：合法职能标记全集
	return [ROLE_TRASH, ROLE_ELITE]
