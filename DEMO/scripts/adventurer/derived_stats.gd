## 二级属性派生（DerivedStats，纯静态工具类）
## 职责：14 项二级属性的实时派生公式——生命/资源池线性式 + 百分比类
## 统一式（基准值 + 换算源属性调整值 × 系数 + 装备词条）。
## 数据来源：案 17《数值专项案》§3.2（二级属性换算域全表）；
## 调整值换算基准 = floor((属性 − 10) / 2)，offset/divisor 参数经 cfg_main 注入；
## **批 B M1：公式参数全部入 cfg_main 表（纯搬家数值不变）**——铁律①
## （公式形态代码化、参数表化）；暴击公式单源归 BattleRules.crit_rate
## （本类原 calc_crit_rate/CRIT_MULT_BASE 双份实现已删，调用方统一走单源）。
## 纯逻辑约束：不触任何 autoload——cfg 经参数注入；掷骰类不涉本类。
## 兜底常量策略：cfg 未注入时回退常量，**常量值与 cfg_main 表值一致**
## （表改值时须同步此处——声明锚定）。
## 速度口径：速度 = 敏捷原始值（本类 calc_speed）；速度 ±N 的排序专用修正
## 不修改敏捷本身（17-C19），归批 2 行动排序接口，不在本类。
## 移动加成口径：敏捷 ≥16 时移动力 +1（上限 6）为终值口径，归批 2
## BattleUnit 移动力预算，不在本类。
class_name DerivedStats
extends RefCounted

## 调整值换算偏移兜底（= cfg_main.attr_modifier_offset）
const ATTR_MODIFIER_OFFSET_FALLBACK: int = 10
## 调整值换算除数兜底（= cfg_main.attr_modifier_divisor）
const ATTR_MODIFIER_DIVISOR_FALLBACK: int = 2
## 生命基础值兜底（= cfg_main.hp_base）
const HP_BASE_FALLBACK: int = 20
## 生命体质乘数兜底（= cfg_main.hp_con_mult）
const HP_CON_MULT_FALLBACK: int = 5
## 资源池基础值兜底（= cfg_main.pool_base）
const POOL_BASE_FALLBACK: int = 10
## 资源池属性乘数兜底（= cfg_main.pool_mult）
const POOL_MULT_FALLBACK: int = 3
## 命中感知权重兜底（= cfg_main.attr_hit_weight）
const ATTR_HIT_WEIGHT_FALLBACK: float = 0.02
## 闪避敏捷权重兜底（= cfg_main.attr_dodge_weight）
const ATTR_DODGE_WEIGHT_FALLBACK: float = 0.02
## 状态抗性基准兜底（= cfg_main.status_resist_base）
const STATUS_RESIST_BASE_FALLBACK: float = 0.05
## 状态抗性权重兜底（= cfg_main.status_resist_weight）
const STATUS_RESIST_WEIGHT_FALLBACK: float = 0.03
## 双抗性权重兜底（= cfg_main.resist_weight）
const RESIST_WEIGHT_FALLBACK: float = 0.02
## 命中率基准兜底（= cfg_main.hit_base——2026-09-24 校准 0.85）
const HIT_BASE_FALLBACK: float = 0.85
## 闪避率基准兜底（= cfg_main.dodge_base）
const DODGE_BASE_FALLBACK: float = 0.05

## 奇术师职业 id（法术穿甲特例 = 意志调整值，§3.2 #17）
const ARCANIST_CLASS_ID: StringName = &"cls_arcanist"

static func calc_hp(constitution: int, cls: ClassDef, level: int,
		cfg: CoreConfig = null) -> int:
	## 生命值 = hp_base + 体质×hp_con_mult + 职业生命系数×(等级−1)（§3.2 生命行；
	## 批 B M1 参数入 cfg_main——前两项经 cfg 读，职业系数在职业表）
	## 参数 constitution：体质值；cls：职业表（hp_coefficient 系数）；level：等级；
	## cfg：总控配置（缺省回退兜底常量）
	## 返回：生命上限（1 级战士体质 14 → 20+70+8×0 = 90）
	var base: int = cfg.hp_base if cfg != null and cfg.hp_base > 0 else HP_BASE_FALLBACK
	var con_mult: int = cfg.hp_con_mult if cfg != null and cfg.hp_con_mult > 0 \
			else HP_CON_MULT_FALLBACK
	return base + constitution * con_mult + int(round(cls.hp_coefficient * float(level - 1)))

static func calc_mana(source_attr_value: int, cfg: CoreConfig = null) -> int:
	## 法力值 = pool_base + 换算源属性×pool_mult（法师=智力/牧师=感知/奇术师=意志，§3.2；
	## 批 B M1 参数入 cfg_main）
	## 参数 source_attr_value：职业法力换算源属性值；cfg：总控配置（缺省回退）
	## 返回：法力上限（智力 16 → 58）
	var base: int = cfg.pool_base if cfg != null and cfg.pool_base > 0 else POOL_BASE_FALLBACK
	var mult: int = cfg.pool_mult if cfg != null and cfg.pool_mult > 0 else POOL_MULT_FALLBACK
	return base + source_attr_value * mult

static func calc_stamina(source_attr_value: int, cfg: CoreConfig = null) -> int:
	## 精力值 = pool_base + 换算源属性×pool_mult（战士=力量/盗贼=敏捷/游侠=敏捷，§3.2；
	## 批 B M1 参数入 cfg_main）
	## 参数 source_attr_value：职业精力换算源属性值；cfg：总控配置（缺省回退）
	## 返回：精力上限（力量 16 → 58）
	var base: int = cfg.pool_base if cfg != null and cfg.pool_base > 0 else POOL_BASE_FALLBACK
	var mult: int = cfg.pool_mult if cfg != null and cfg.pool_mult > 0 else POOL_MULT_FALLBACK
	return base + source_attr_value * mult

static func calc_dodge(agility: int, cfg: CoreConfig) -> float:
	## 闪避率 = 基准（cfg.dodge_base）+ 敏捷调整值×attr_dodge_weight（§3.2）
	## 参数 agility：敏捷值；cfg：总控配置（基准值与调整值换算参数）
	## 返回：闪避率（0-1 浮点）
	var base: float = cfg.dodge_base if cfg != null else DODGE_BASE_FALLBACK
	var weight: float = cfg.attr_dodge_weight if cfg != null else ATTR_DODGE_WEIGHT_FALLBACK
	return base + BattleRules.attr_modifier(agility, cfg) * weight

static func calc_hit(perception: int, cfg: CoreConfig) -> float:
	## 命中率基准 = 基准（cfg.hit_base，2026-09-24 校准 0.85）+ 感知调整值×
	## attr_hit_weight（技能命中修正在 BattleRules.hit_chance 加入，§3.2 #4）
	## 参数 perception：感知值；cfg：总控配置
	## 返回：命中率基准（0-1 浮点，未经钳制）
	var base: float = cfg.hit_base if cfg != null else HIT_BASE_FALLBACK
	var weight: float = cfg.attr_hit_weight if cfg != null else ATTR_HIT_WEIGHT_FALLBACK
	return base + BattleRules.attr_modifier(perception, cfg) * weight

static func calc_status_resist(constitution: int, willpower: int, cfg: CoreConfig) -> float:
	## 异常状态抗性 = 基准（cfg.status_resist_base）+ max(体质, 意志)调整值×
	## status_resist_weight，钳制 ≥0（17-C20 双源取高 + 第八轮盲审钳制）
	## 参数 constitution：体质值；willpower：意志值；cfg：总控配置
	## 返回：异常状态抗性（≥0 浮点）
	var base: float = cfg.status_resist_base if cfg != null else STATUS_RESIST_BASE_FALLBACK
	var weight: float = cfg.status_resist_weight if cfg != null else STATUS_RESIST_WEIGHT_FALLBACK
	var modifier: int = maxi(BattleRules.attr_modifier(constitution, cfg),
			BattleRules.attr_modifier(willpower, cfg))
	return maxf(0.0, base + modifier * weight)

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

static func calc_mag_pierce(source_attr_value: int, _unused_willpower: int,
		_class_id: StringName, cfg: CoreConfig) -> int:
	## 法术穿甲 = 换算源属性调整值×1（换算源经 ClassDef.mag_pierce_source_attr
	## 表驱动——批 C M8：原 cls_arcanist 意志特例分支删除改读表，五职业智力/
	## 奇术师意志由表承载；签名保留兼容既有调用方，第二/三参数已不消费）
	## 参数 source_attr_value：换算源属性值（调用方按表取）；cfg：总控配置
	## 返回：法术穿甲点数（≥0）
	return maxi(0, BattleRules.attr_modifier(source_attr_value, cfg) * 1)

static func calc_phys_resist(constitution: int, cfg: CoreConfig) -> float:
	## 物理抗性 = 体质调整值×resist_weight（+ 装备词条，装备项由调用方并入），钳制 ≥0
	## 参数 constitution：体质值；cfg：总控配置
	## 返回：物理抗性（≥0 浮点）
	var weight: float = cfg.resist_weight if cfg != null else RESIST_WEIGHT_FALLBACK
	return maxf(0.0, BattleRules.attr_modifier(constitution, cfg) * weight)

static func calc_mag_resist(perception: int, cfg: CoreConfig) -> float:
	## 法术抗性 = 感知调整值×resist_weight（精神抗性口径；+ 装备词条），钳制 ≥0
	## 参数 perception：感知值；cfg：总控配置
	## 返回：法术抗性（≥0 浮点）
	var weight: float = cfg.resist_weight if cfg != null else RESIST_WEIGHT_FALLBACK
	return maxf(0.0, BattleRules.attr_modifier(perception, cfg) * weight)

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
