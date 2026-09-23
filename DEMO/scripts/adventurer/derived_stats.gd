## 二级属性派生（DerivedStats，纯静态工具类）
## 职责：14 项二级属性的实时派生公式——生命/资源池线性式 + 百分比类
## 统一式（基准值 + 换算源属性调整值 × 系数 + 装备词条）。
## 数据来源：案 17《数值专项案》§3.2（二级属性换算域全表）；
## 调整值换算基准 = floor((属性 − 10) / 2)，offset/divisor 参数经 cfg_main 注入
## （铁律①：公式形态代码化、参数表化）。
## 纯逻辑约束：不触任何 autoload——cfg 经参数注入；掷骰类不涉本类。
## 速度口径：速度 = 敏捷原始值（本类 calc_speed）；速度 ±N 的排序专用修正
## 不修改敏捷本身（17-C19），归批 2 行动排序接口，不在本类。
## 移动加成口径：敏捷 ≥16 时移动力 +1（上限 6）为终值口径，归批 2
## BattleUnit 移动力预算，不在本类。
class_name DerivedStats
extends RefCounted

## 暴击伤害倍率基础值（150% 基础 + 技能/装备词条加成；属性微调留完整版，17 案 §3.2）
const CRIT_MULT_BASE: float = 1.5

## 奇术师职业 id（法术穿甲特例 = 意志调整值，§3.2 #17）
const ARCANIST_CLASS_ID: StringName = &"cls_arcanist"

static func calc_hp(constitution: int, cls: ClassDef, level: int) -> int:
	## 生命值 = 20 + 体质×5 + 职业生命系数×(等级−1)（§3.2 生命行）
	## 参数 constitution：体质值；cls：职业表（hp_coefficient 系数）；level：等级
	## 返回：生命上限（1 级战士体质 14 → 20+70+8×0 = 90）
	return 20 + constitution * 5 + int(round(cls.hp_coefficient * float(level - 1)))

static func calc_mana(source_attr_value: int) -> int:
	## 法力值 = 10 + 换算源属性×3（法师=智力/牧师=感知/奇术师=意志，§3.2）
	## 参数 source_attr_value：职业法力换算源属性值
	## 返回：法力上限（智力 16 → 58）
	return 10 + source_attr_value * 3

static func calc_stamina(source_attr_value: int) -> int:
	## 精力值 = 10 + 换算源属性×3（战士=力量/盗贼=敏捷/游侠=敏捷，§3.2）
	## 参数 source_attr_value：职业精力换算源属性值
	## 返回：精力上限（力量 16 → 58）
	return 10 + source_attr_value * 3

static func calc_dodge(agility: int, cfg: CoreConfig) -> float:
	## 闪避率 = 5% + 敏捷调整值×2%（§3.2）
	## 参数 agility：敏捷值；cfg：总控配置（调整值换算参数）
	## 返回：闪避率（0-1 浮点）
	return 0.05 + BattleRules.attr_modifier(agility, cfg) * 0.02

static func calc_hit(perception: int, cfg: CoreConfig) -> float:
	## 命中率基准 = 80% + 感知调整值×2%（技能命中修正在 BattleRules.hit_chance 加入，§3.2 #4）
	## 参数 perception：感知值；cfg：总控配置
	## 返回：命中率基准（0-1 浮点，未经钳制）
	return 0.80 + BattleRules.attr_modifier(perception, cfg) * 0.02

static func calc_status_resist(constitution: int, willpower: int, cfg: CoreConfig) -> float:
	## 异常状态抗性 = 5% + max(体质, 意志)调整值×3%，钳制 ≥0（17-C20 双源取高 + 第八轮盲审钳制）
	## 参数 constitution：体质值；willpower：意志值；cfg：总控配置
	## 返回：异常状态抗性（≥0 浮点）
	var modifier: int = maxi(BattleRules.attr_modifier(constitution, cfg),
			BattleRules.attr_modifier(willpower, cfg))
	return maxf(0.0, 0.05 + modifier * 0.03)

static func calc_speed(agility: int) -> int:
	## 速度 = 敏捷原始值（直接排序，同速打破平；速度类 BUFF 为排序专用修正、
	## 不连带敏捷派生——17-C19，归批 2 行动排序接口）
	## 参数 agility：敏捷值
	## 返回：速度值（= 敏捷原始值）
	return agility

static func calc_phys_pierce(strength: int, cfg: CoreConfig) -> int:
	## 物理穿甲 = 力量调整值×1（点数直接抵消护甲），钳制 ≥0（第十轮盲审）
	## 参数 strength：力量值；cfg：总控配置
	## 返回：物理穿甲点数（≥0）
	return maxi(0, BattleRules.attr_modifier(strength, cfg) * 1)

static func calc_mag_pierce(intelligence: int, willpower: int, class_id: StringName, cfg: CoreConfig) -> int:
	## 法术穿甲 = 智力调整值×1；奇术师特例 = 意志调整值×1（§3.2 #17）；钳制 ≥0
	## 参数 intelligence：智力值；willpower：意志值；class_id：职业 id（奇术师特例判定）；cfg：总控配置
	## 返回：法术穿甲点数（≥0）
	var source: int = willpower if class_id == ARCANIST_CLASS_ID else intelligence
	return maxi(0, BattleRules.attr_modifier(source, cfg) * 1)

static func calc_phys_resist(constitution: int, cfg: CoreConfig) -> float:
	## 物理抗性 = 体质调整值×2%（+ 装备词条，装备项由调用方并入），钳制 ≥0
	## 参数 constitution：体质值；cfg：总控配置
	## 返回：物理抗性（≥0 浮点）
	return maxf(0.0, BattleRules.attr_modifier(constitution, cfg) * 0.02)

static func calc_mag_resist(perception: int, cfg: CoreConfig) -> float:
	## 法术抗性 = 感知调整值×2%（精神抗性口径；+ 装备词条），钳制 ≥0
	## 参数 perception：感知值；cfg：总控配置
	## 返回：法术抗性（≥0 浮点）
	return maxf(0.0, BattleRules.attr_modifier(perception, cfg) * 0.02)

static func calc_phys_armor(equip_armor: int, constitution: int, cfg: CoreConfig) -> int:
	## 物理护甲 = 装备护甲值（主导）+ 体质调整值×1，钳制 ≥0（§3.2 物理←体质）
	## 参数 equip_armor：装备护甲值（物理/法术双轨同计）；constitution：体质值；cfg：总控配置
	## 返回：物理护甲（≥0）
	return maxi(0, equip_armor + BattleRules.attr_modifier(constitution, cfg) * 1)

static func calc_mag_armor(equip_armor: int, perception: int, cfg: CoreConfig) -> int:
	## 法术护甲 = 装备护甲值（双轨同计）+ 感知调整值×1，钳制 ≥0（§3.2 法术←感知）
	## 参数 equip_armor：装备护甲值；perception：感知值；cfg：总控配置
	## 返回：法术护甲（≥0）
	return maxi(0, equip_armor + BattleRules.attr_modifier(perception, cfg) * 1)

static func calc_crit_rate(luck: int, agility: int, cfg: CoreConfig) -> float:
	## 暴击率 = 5% + 幸运调整值×2% + 敏捷调整值×1%（幸运主导、敏捷微调；技能本次加成由 BattleRules.crit_rate 并入）
	## 参数 luck：幸运值；agility：敏捷值；cfg：总控配置
	## 返回：暴击率（浮点，未钳制——设计未定暴击钳制带）
	return 0.05 + BattleRules.attr_modifier(luck, cfg) * 0.02 \
			+ BattleRules.attr_modifier(agility, cfg) * 0.01
