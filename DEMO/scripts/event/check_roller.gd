## 检定掷骰器（CheckRoller，纯静态工具类）
## 职责：D20 检定的一次完整结算——骰值 → 幸运兜底 Z 垫骰（骰 1 除外）→
## 四档判定（骰 1 优先大失败 / 骰 ≥ 大成功线大成功 / 合计 ≥ 判定线成功 / 余失败）。
## 数据来源：案 17 §3.3（检定域全表：幸运降线 X、判定线钳 16、幸运兜底 Y/Z、
## D2 大成功自动成功）；调整值换算复用 BattleRules.attr_modifier（单源勿新写）。
## 纯逻辑约束：不触任何 autoload——cfg/rng 经参数注入；roll_with_die 为
## 测试注入口（固定骰值），生产走 roll。
class_name CheckRoller
extends RefCounted

## 大成功判定线（= max(crit_success_line_min, 20 − max(0, floor((幸运 − 偏移) /
## 降线除数 X)))——幸运越高线越低、钳 16 下限不再降；骰 1 优先不看本线）
static func crit_line_of(luck: int, cfg: CoreConfig) -> int:
	## 参数 luck：施检者幸运值；cfg：总控配置（crit_success_line_min/
	## crit_success_drop_divisor/attr_modifier_offset）
	## 返回：大成功判定线
	var offset: int = cfg.attr_modifier_offset if cfg != null \
			else DerivedStats.ATTR_MODIFIER_OFFSET_FALLBACK
	var divisor: int = cfg.crit_success_drop_divisor if cfg != null and cfg.crit_success_drop_divisor > 0 \
			else 3
	var line_min: int = cfg.crit_success_line_min if cfg != null and cfg.crit_success_line_min > 0 \
			else 16
	var drop: int = maxi(0, int(floor((luck - offset) / float(divisor))))
	return maxi(line_min, 20 - drop)

## 幸运兜底 Z（= max(z_base, z_base + floor((幸运 − 偏移) / z_divisor))——
## 骰点低于 Z 时按 Z 计（骰 1 仍大失败不兜）；单源拆口供 UI 提示/测试）
static func z_of(luck: int, cfg: CoreConfig) -> int:
	## 参数 luck：施检者幸运值；cfg：总控配置（luck_floor_z_base/divisor）
	## 返回：幸运兜底骰值 Z
	var offset: int = cfg.attr_modifier_offset if cfg != null \
			else DerivedStats.ATTR_MODIFIER_OFFSET_FALLBACK
	var z_base: int = cfg.luck_floor_z_base if cfg != null and cfg.luck_floor_z_base > 0 \
			else 2
	var z_divisor: int = cfg.luck_floor_z_divisor if cfg != null and cfg.luck_floor_z_divisor > 0 \
			else 4
	return maxi(z_base, z_base + int(floor((luck - offset) / float(z_divisor))))

## 判定线查表（难度档名 → cfg.difficulty_tiers 值；未知档名报错回退 20）
static func tier_line_of(tier_name: String, cfg: CoreConfig) -> int:
	## 参数 tier_name：难度档名（极易/容易/普通/困难/极难）；cfg：总控配置
	## 返回：判定线；未知档 push_warning 回退 20
	if cfg != null and cfg.difficulty_tiers.has(tier_name):
		return int(cfg.difficulty_tiers[tier_name])
	push_warning("CheckRoller: 未知难度档 '%s'——回退判定线 20" % tier_name)
	return 20

static func roll(attrs: Dictionary, attr_id: StringName, tier_name: String,
		cfg: CoreConfig, rng: RandomNumberGenerator) -> CheckResult:
	## 检定主入口（随机骰）：掷 1-20 → 判定
	## 参数 attrs：施检者属性表 {StringName: int}；attr_id：检定属性；
	## tier_name：难度档名；cfg：总控配置；rng：随机源（注入）
	## 返回：CheckResult
	return roll_with_die(attrs, attr_id, tier_name, cfg, rng.randi_range(1, 20))

static func roll_with_die(attrs: Dictionary, attr_id: StringName, tier_name: String,
		cfg: CoreConfig, die: int) -> CheckResult:
	## 检定结算（测试注入口——固定骰值驱动四档确定断言）：
	## ①骰 1 → 大失败（优先一切，不兜底不看线）；②Z 垫骰（effective_die）；
	## ③骰 ≥ 大成功线 → 大成功（D2 自动成功）；④合计 ≥ 判定线 → 成功；余失败
	## 参数 attrs/attr_id/tier_name/cfg：同 roll；die：注入骰值（1-20）
	## 返回：CheckResult（die/effective_die/modifier/total/grade/crit_line 全落位）
	var result := CheckResult.new()
	result.die = die
	var luck: int = int(attrs.get(AttrKeys.LUCK, AttrKeys.DEFAULT_ATTR_VALUE))
	result.crit_line = crit_line_of(luck, cfg)
	# ①骰 1 优先：大失败（幸运兜底与线判定均不参与）
	if die == 1:
		result.effective_die = 1
		result.modifier = BattleRules.attr_modifier(
				int(attrs.get(attr_id, AttrKeys.DEFAULT_ATTR_VALUE)), cfg)
		result.total = result.modifier + 1
		result.grade = CheckResult.Grade.CRIT_FAILURE
		return result
	# ②幸运兜底 Z 垫骰
	result.effective_die = maxi(die, z_of(luck, cfg))
	# ③调整值（复用 BattleRules 单源）
	result.modifier = BattleRules.attr_modifier(
			int(attrs.get(attr_id, AttrKeys.DEFAULT_ATTR_VALUE)), cfg)
	result.total = result.modifier + result.effective_die
	# ④四档判定（骰 ≥ 线大成功 → 合计 ≥ 判定线成功 → 余失败）
	if result.effective_die >= result.crit_line:
		result.grade = CheckResult.Grade.CRIT_SUCCESS
	elif result.total >= tier_line_of(tier_name, cfg):
		result.grade = CheckResult.Grade.SUCCESS
	else:
		result.grade = CheckResult.Grade.FAILURE
	return result
