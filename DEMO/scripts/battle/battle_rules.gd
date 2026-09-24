## 战斗规则结算器（BattleRules，纯静态工具类）
## 职责：伤害与战斗域的公式结算——调整值换算、毛面板伤害、减免轨
## （乘法抗性在前/减法护甲在后）、命中对抗与钳制、暴击率与期望、治疗与 DOT 跳伤。
## 数据来源：案 17《数值专项案》§3.3（调整值换算）/§3.4（伤害与战斗域：
## 减免公式/命中闪避对抗钳制 [5%,95%]/伤害下限 1/暴击 150%/治疗与跳伤口径）。
## 纯逻辑约束：不触任何 autoload——cfg 经参数注入；随机源 rng/forced 注入
## 保证测试确定性。
class_name BattleRules
extends RefCounted

## 调整值换算兜底（C-3 单源收敛：offset/divisor 常量唯一定义点在
## DerivedStats——battle→adventurer 合向引用，三重出现收敛为一）
const ATTR_MODIFIER_OFFSET_FALLBACK: int = DerivedStats.ATTR_MODIFIER_OFFSET_FALLBACK
const ATTR_MODIFIER_DIVISOR_FALLBACK: int = DerivedStats.ATTR_MODIFIER_DIVISOR_FALLBACK
## 伤害下限兜底（= cfg_main.damage_floor——A-4 提名）
const DAMAGE_FLOOR_FALLBACK: int = 1
## 命中钳制带下限兜底（= cfg_main.hit_clamp_min——A-4 提名）
const HIT_CLAMP_MIN_FALLBACK: float = 0.05
## 命中钳制带上限兜底（= cfg_main.hit_clamp_max——A-4 提名）
const HIT_CLAMP_MAX_FALLBACK: float = 0.95
## 暴击伤害倍率兜底（= cfg_main.crit_mult_base——R1-3 提名；执行链与 AI 期望共用）
const CRIT_MULT_BASE_FALLBACK: float = 1.5

static func crit_mult_base_of(cfg: CoreConfig) -> float:
	## 暴击伤害倍率读取（R1-3 单源口：cfg 值优先、兜底回退——执行链暴击乘算
	## 与 AI 期望伤害共引，cfg 空保护两处同口径）
	## 参数 cfg：总控配置（可空）
	## 返回：倍率（>0）
	return cfg.crit_mult_base if cfg != null and cfg.crit_mult_base > 0.0 			else CRIT_MULT_BASE_FALLBACK

static func attr_modifier(attr: int, cfg: CoreConfig) -> int:
	## 属性调整值 = floor((属性 − offset) / divisor)（§3.3 全局换算式；速查 6→−2/9→−1/10→0/16→+3）
	## 参数 attr：一级属性值；cfg：总控配置（attr_modifier_offset/divisor 注入）
	## 返回：调整值（可为负）
	var offset: int = cfg.attr_modifier_offset if cfg != null else ATTR_MODIFIER_OFFSET_FALLBACK
	var divisor: int = cfg.attr_modifier_divisor if cfg != null else ATTR_MODIFIER_DIVISOR_FALLBACK
	return int(floor((attr - offset) / float(divisor)))

static func raw_panel_damage(attrs: Dictionary, weapon_bonus: int, skill: SkillDef,
		panel_mult: float, race_mult: float) -> float:
	## 毛面板伤害 =（Σ 权重×属性 + 武器加值）× 技能系数 × panel_mult × race_mult（§3.4）
	## panel_mult = 状态乘算层（高地 ×1.2 等，作用层=面板阶段随技能系数同层乘算，非最终后乘）；
	## race_mult = 种族克制乘算（对亡灵 ×1.5 等）
	## 参数 attrs：施放者一级属性 {StringName: int}；weapon_bonus：武器加值；skill：技能表；
	## panel_mult/race_mult：两层乘算系数（无则传 1.0）
	## 返回：毛面板伤害（减免轨前浮点，不取整）
	var weighted: float = float(weapon_bonus)
	for attr_id: StringName in skill.attr_weights:
		var weight: float = skill.attr_weights[attr_id]
		weighted += weight * float(int(attrs.get(attr_id,
				AttrKeys.DEFAULT_ATTR_VALUE)))
	return weighted * skill.power_coefficient * panel_mult * race_mult

static func mitigate(raw: float, resist: float, armor: int, pierce: int, cfg: CoreConfig) -> int:
	## 减免轨 = max(伤害下限, round(raw × (1 − 抗性) − max(0, 护甲 − 穿甲)))——
	## 乘法抗性在前、减法护甲在后、穿甲抵护甲、下限走 cfg.damage_floor（§3.4）
	## 参数 raw：毛面板伤害；resist：目标抗性（0-1）；armor：目标护甲（按物理/法术轨取值）；
	## pierce：施放者穿甲（同轨）；cfg：总控配置（伤害下限）
	## 返回：减免后伤害（int，≥ 伤害下限）
	var floor_value: int = cfg.damage_floor if cfg != null and cfg.damage_floor > 0  \
			else DAMAGE_FLOOR_FALLBACK
	var net_armor: int = maxi(0, armor - pierce)
	return maxi(floor_value, int(round(raw * (1.0 - resist))) - net_armor)

static func mitigate_by_damage_type(raw: float, damage_type: int, caster: Object,
		target: Object, cfg: CoreConfig) -> int:
	## 减免轨选对（单源——批 4 C 组 H2）：按伤害类型物理/法术选抗性/护甲/
	## 穿甲对后走 mitigate——原 SkillExecutor 攻击链、EnemyAI 期望伤害、
	## battle_screen 目标预览三处复刻的选对逻辑收敛于此，换轨口径只动一处。
	## 单位鸭子契约（target.phys_resist 等 / caster.phys_pierce 等——
	## 与 SkillExecutor 执行链同契约）
	## 参数 raw：毛面板伤害；damage_type：SkillDef.DamageType（PHYSICAL 走物理对，
	## 其余走法术对——与执行链分支对齐）；caster：施放单位（穿甲）；
	## target：目标单位（抗性/护甲）；cfg：总控配置
	## 返回：减免后伤害（int，≥ 伤害下限）
	return mitigate(raw, resist_of(damage_type, target), armor_of(damage_type, target),
			pierce_of(damage_type, caster), cfg)

static func resist_of(damage_type: int, target: Object) -> float:
	## 减免轨抗性分量（H2 单源选对的分量口——trace 明细/日志消费）
	## 参数 damage_type：SkillDef.DamageType；target：目标单位
	## 返回：该轨抗性（0-1）
	return target.phys_resist if damage_type == SkillDef.DamageType.PHYSICAL \
			else target.mag_resist

static func armor_of(damage_type: int, target: Object) -> int:
	## 减免轨护甲分量（H2 单源选对的分量口）
	## 参数 damage_type：SkillDef.DamageType；target：目标单位
	## 返回：该轨护甲
	return target.phys_armor if damage_type == SkillDef.DamageType.PHYSICAL \
			else target.mag_armor

static func pierce_of(damage_type: int, caster: Object) -> int:
	## 减免轨穿甲分量（H2 单源选对的分量口）
	## 参数 damage_type：SkillDef.DamageType；caster：施放单位
	## 返回：该轨穿甲
	return caster.phys_pierce if damage_type == SkillDef.DamageType.PHYSICAL \
			else caster.mag_pierce

static func hit_chance(hit_stat: float, dodge_stat: float, skill_hit_mod: int, cfg: CoreConfig) -> float:
	## 实际命中概率 = 施放者命中率 − 目标闪避率 + 技能命中修正（百分点×0.01），
	## 钳制 [hit_clamp_min, hit_clamp_max]（§3.4 命中/闪避对抗；骰运保底双端）
	## 参数 hit_stat：施放者命中率（DerivedStats.calc_hit 基准）；dodge_stat：目标闪避率；
	## skill_hit_mod：技能命中修正（int 百分点，1 = +1%）；cfg：总控配置（钳制带）
	## 返回：钳制后命中概率
	var clamp_min: float = cfg.hit_clamp_min if cfg != null and cfg.hit_clamp_min > 0.0  \
			else HIT_CLAMP_MIN_FALLBACK
	var clamp_max: float = cfg.hit_clamp_max if cfg != null and cfg.hit_clamp_max > 0.0  \
			else HIT_CLAMP_MAX_FALLBACK
	return clampf(hit_stat - dodge_stat + skill_hit_mod * 0.01, clamp_min, clamp_max)

static func roll_hit(chance: float, rng: RandomNumberGenerator, forced: int = -1) -> bool:
	## 命中掷：forced = -1 掷随机（randf < chance）；0 强制失败；1 强制成功
	## 参数 chance：命中概率；rng：随机源（注入）；forced：强制口（测试确定性）
	## 返回：true = 命中/生效
	if forced == 0:
		return false
	if forced == 1:
		return true
	return rng.randf() < chance

## 暴击率基础值兜底（= cfg_main.crit_base）
const CRIT_BASE_FALLBACK: float = 0.05
## 暴击幸运权重兜底（= cfg_main.crit_luck_weight）
const CRIT_LUCK_WEIGHT_FALLBACK: float = 0.02
## 暴击敏捷权重兜底（= cfg_main.crit_agility_weight）
const CRIT_AGILITY_WEIGHT_FALLBACK: float = 0.01

static func crit_rate(luck: int, agility: int, bonus_pct: float, cfg: CoreConfig) -> float:
	## 本次攻击暴击率 = crit_base + 幸运调整值×crit_luck_weight + 敏捷调整值×
	## crit_agility_weight + 技能本次加成（§3.2/§3.4 背刺行）——**单源实现**
	## （批 B M1：DerivedStats.calc_crit_rate 双份已删，全部调用方走本函数；
	## 参数经 cfg_main 注入，无技能加成传 bonus_pct=0.0）
	## 参数 luck/agility：施放者幸运/敏捷；bonus_pct：技能 COMBAT_MOD 暴击加成（如 0.10）；cfg：总控配置
	## 返回：暴击率（未钳制——设计未定暴击钳制带）
	var base: float = cfg.crit_base if cfg != null else CRIT_BASE_FALLBACK
	var luck_weight: float = cfg.crit_luck_weight if cfg != null else CRIT_LUCK_WEIGHT_FALLBACK
	var agility_weight: float = cfg.crit_agility_weight if cfg != null \
			else CRIT_AGILITY_WEIGHT_FALLBACK
	return base + attr_modifier(luck, cfg) * luck_weight \
			+ attr_modifier(agility, cfg) * agility_weight + bonus_pct

static func expected_damage(raw: float, hit: float, crit: float, crit_mult: float) -> float:
	## 期望伤害 = raw × 命中率 × (1 + 暴击率 × (暴击倍率 − 1))（§3.8 验算式）
	## 参数 raw：减免轨后单发伤害；hit：命中概率；crit：暴击率；crit_mult：暴击倍率（基础 1.5）
	## 返回：单发期望伤害（浮点）
	return raw * hit * (1.0 + crit * (crit_mult - 1.0))

static func heal_amount(attrs: Dictionary, effect: SkillEffect) -> int:
	## 治疗量 = round(换算源属性 × ratio + flat)（§3.4 治愈术行：感知×1.5+10）
	## 参数 attrs：施放者一级属性 {StringName: int}；effect：HEAL 效果参数组
	## 返回：治疗量（int）
	return int(round(int(attrs.get(effect.source_attr,
			AttrKeys.DEFAULT_ATTR_VALUE)) * effect.ratio + effect.flat))

static func dot_tick(attrs: Dictionary, dot: DotParams) -> int:
	## DOT 跳伤：FIXED 直取固定值 / ATTR_RATIO = round(属性 × ratio)——
	## 跳伤不过减免轨（§3.4 已定稿；毒沼同陷阱 D7 口径）
	## 参数 attrs：跳伤结算源属性 {StringName: int}（通常为目标自身）；dot：DOT 参数子资源
	## 返回：单跳伤害（int）
	if dot.mode == DotParams.Mode.FIXED:
		return dot.fixed
	return dot_tick_from_value(int(attrs.get(dot.attr_id, AttrKeys.DEFAULT_ATTR_VALUE)), dot)

static func dot_tick_from_value(value: int, dot: DotParams) -> int:
	## DOT 跳伤换算单源（A-9）：round(数值 × ratio)——attrs 口径（受方属性回退）
	## 与施方快照口径（status_manager 定格值）两路共用同一换算式
	## 参数 value：换算源数值（属性值或快照值）；dot：DOT 参数子资源
	## 返回：单跳伤害（int）
	return int(round(float(value) * dot.ratio))
