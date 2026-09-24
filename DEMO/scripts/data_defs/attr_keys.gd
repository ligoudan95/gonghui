## 一级属性 id 常量（AttrKeys，纯常量类）
## 职责：集中承载七属性 id（17 案 §3.1 一级属性域）——批 4 C 组单源化：
## 原散布于 battle_unit（派生读取）/ unit_builder / skill_executor /
## enemy_ai 的字符串字面量与 DataValidator.SEVEN_ATTRS 的重复全集全部
## 收敛到此（属性 id 口径第二处出现即单源化）。
## 纯逻辑约束：无状态纯常量；新增属性 id 先加此处再消费。
class_name AttrKeys
extends RefCounted

## 力量（物理穿甲换算源）
const STRENGTH: StringName = &"strength"
## 敏捷（闪避/暴击/移动力加成/行动排序源）
const AGILITY: StringName = &"agility"
## 体质（生命/异常抗性/物理抗性/物理护甲换算源）
const CONSTITUTION: StringName = &"constitution"
## 智力（法力池/法术穿甲默认换算源）
const INTELLIGENCE: StringName = &"intelligence"
## 感知（命中/法术抗性/法术护甲换算源）
const PERCEPTION: StringName = &"perception"
## 意志（异常抗性/诅咒 ATTR_RATIO 跳伤换算源）
const WILLPOWER: StringName = &"willpower"
## 幸运（暴击率权重源）
const LUCK: StringName = &"luck"

## 属性缺省值（A-6 单源：attrs.get 回退统一口径——未填 = 中性 10
## 【调整值 +0、无派生加成语义】；DEMO 数据全带七属性行为不变）
const DEFAULT_ATTR_VALUE: int = 10

## 七属性 id 全集（DataValidator V-M0-ref-skill-attr 校验消费——技能权重键
## 必须落在七属性域内）
static func seven_attrs() -> Array[StringName]:
	## 参数：无
	## 返回：七属性 id 全集
	return [
		STRENGTH, AGILITY, CONSTITUTION,
		INTELLIGENCE, PERCEPTION, WILLPOWER, LUCK,
	]
