## 战斗规则结算器（BattleRules，纯静态工具类）
## 职责：伤害与战斗域的公式结算——调整值换算、毛面板伤害、减免轨
## （乘法抗性在前/减法护甲在后）、命中对抗与钳制、暴击率与期望、治疗与 DOT 跳伤。
## 数据来源：案 17《数值专项案》§3.3（调整值换算）/§3.4（伤害与战斗域：
## 减免公式/命中闪避对抗钳制 [5%,95%]/伤害下限 1/暴击 150%/治疗与跳伤口径）。
## 纯逻辑约束：不触任何 autoload——cfg 经参数注入；随机源 rng/forced 注入
## 保证测试确定性。
class_name BattleRules
extends RefCounted

## 调整值换算偏移基准（属性 10 = +0 的对齐点；cfg 未注入参数时的兜底常量，
## 正常路径一律走 cfg_main 显式值）
const ATTR_MODIFIER_OFFSET_FALLBACK: int = 10
## 调整值换算除数兜底常量（同上）
const ATTR_MODIFIER_DIVISOR_FALLBACK: int = 2

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
		weighted += weight * float(int(attrs.get(attr_id, 0)))
	return weighted * skill.power_coefficient * panel_mult * race_mult

static func mitigate(raw: float, resist: float, armor: int, pierce: int, cfg: CoreConfig) -> int:
	## 减免轨 = max(伤害下限, round(raw × (1 − 抗性) − max(0, 护甲 − 穿甲)))——
	## 乘法抗性在前、减法护甲在后、穿甲抵护甲、下限走 cfg.damage_floor（§3.4）
	## 参数 raw：毛面板伤害；resist：目标抗性（0-1）；armor：目标护甲（按物理/法术轨取值）；
	## pierce：施放者穿甲（同轨）；cfg：总控配置（伤害下限）
	## 返回：减免后伤害（int，≥ 伤害下限）
	var floor_value: int = cfg.damage_floor if cfg != null else 1
	var net_armor: int = maxi(0, armor - pierce)
	return maxi(floor_value, int(round(raw * (1.0 - resist))) - net_armor)

static func hit_chance(hit_stat: float, dodge_stat: float, skill_hit_mod: int, cfg: CoreConfig) -> float:
	## 实际命中概率 = 施放者命中率 − 目标闪避率 + 技能命中修正（百分点×0.01），
	## 钳制 [hit_clamp_min, hit_clamp_max]（§3.4 命中/闪避对抗；骰运保底双端）
	## 参数 hit_stat：施放者命中率（DerivedStats.calc_hit 基准）；dodge_stat：目标闪避率；
	## skill_hit_mod：技能命中修正（int 百分点，1 = +1%）；cfg：总控配置（钳制带）
	## 返回：钳制后命中概率
	var clamp_min: float = cfg.hit_clamp_min if cfg != null else 0.05
	var clamp_max: float = cfg.hit_clamp_max if cfg != null else 0.95
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

static func crit_rate(luck: int, agility: int, bonus_pct: float, cfg: CoreConfig) -> float:
	## 本次攻击暴击率 = 5% + 幸运调整值×2% + 敏捷调整值×1% + 技能本次加成（§3.2/§3.4 背刺行）
	## 参数 luck/agility：施放者幸运/敏捷；bonus_pct：技能 COMBAT_MOD 暴击加成（如 0.10）；cfg：总控配置
	## 返回：暴击率（未钳制——设计未定暴击钳制带）
	return 0.05 + attr_modifier(luck, cfg) * 0.02 + attr_modifier(agility, cfg) * 0.01 + bonus_pct

static func expected_damage(raw: float, hit: float, crit: float, crit_mult: float) -> float:
	## 期望伤害 = raw × 命中率 × (1 + 暴击率 × (暴击倍率 − 1))（§3.8 验算式）
	## 参数 raw：减免轨后单发伤害；hit：命中概率；crit：暴击率；crit_mult：暴击倍率（基础 1.5）
	## 返回：单发期望伤害（浮点）
	return raw * hit * (1.0 + crit * (crit_mult - 1.0))

static func heal_amount(attrs: Dictionary, effect: SkillEffect) -> int:
	## 治疗量 = round(换算源属性 × ratio + flat)（§3.4 治愈术行：感知×1.5+10）
	## 参数 attrs：施放者一级属性 {StringName: int}；effect：HEAL 效果参数组
	## 返回：治疗量（int）
	return int(round(int(attrs.get(effect.source_attr, 0)) * effect.ratio + effect.flat))

static func dot_tick(attrs: Dictionary, dot: DotParams) -> int:
	## DOT 跳伤：FIXED 直取固定值 / ATTR_RATIO = round(属性 × ratio)——
	## 跳伤不过减免轨（§3.4 已定稿；毒沼同陷阱 D7 口径）
	## 参数 attrs：跳伤结算源属性 {StringName: int}（通常为目标自身）；dot：DOT 参数子资源
	## 返回：单跳伤害（int）
	if dot.mode == DotParams.Mode.FIXED:
		return dot.fixed
	return int(round(int(attrs.get(dot.attr_id, 0)) * dot.ratio))
