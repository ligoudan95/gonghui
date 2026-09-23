## 技能执行器（SkillExecutor，RefCounted 纯逻辑类）
## 职责：技能的一次完整执行——前置校验（射程曼哈顿 + 视线（射程 0/近战 1
## 免视线）+ 资源 + 治疗仅未倒地）→ 扣资源 → 攻击段（命中掷 → 毛面板
## （含 COMBAT_MOD panel/crit 修正与种族克制乘算）→ 减免轨（按物理/法术选
## 护甲穿甲对）→ 暴击掷 ×1.5 → take_damage → 倒地回调）→ 效果遍历
## （STATUS_APPLY 独立两段判定 / HEAL 免判定 / TILE_SPAWN 预结算 / AURA_3X3
## 怒吼逐格独立两段）→ 返回 ExecutionResult。
## 数据来源：案 9《战棋战斗》；案 10《职业与技能》；案 11 §2.2（两段判定）；
## 案 17 §3.4（公式与技能参数）/§3.8（验算基准）；陷阱 D7 口径（免判定免减免）。
## 纯逻辑约束：不触任何 autoload——全部依赖经 ctx 注入。
## ctx 字典键（执行上下文）：
## - &"grid": BattleGrid（目标解析/视线/动态地格）
## - &"status_manager": StatusManager（状态施加与修正读取）
## - &"cfg": CoreConfig（钳制带/伤害下限/调整值参数）
## - &"rng": RandomNumberGenerator（掷骰源）
## - &"forced": int（命中/判定强制口，-1 掷随机/0 强制失败/1 强制成功；默认 -1）
## - &"forced_crit": int（暴击独立强制口，默认 -1；与 &"forced" 分离以保证
##   「命中不暴击」等测试确定性——批 1 测试注入口）
## - &"status_lookup": Callable（StringName 状态 id -> StatusDef）
## 单位鸭子契约（批 2 BattleUnit 实现同契约；本类只读消费）：
## - id: StringName / side: int（0 我方 1 敌方，与 SkillDef.SkillSide 对齐）/
##   alive: bool / grid_pos: Vector2i
## - attrs: Dictionary（{StringName 属性 id: int}）/ weapon_bonus: int /
##   race_tag: StringName（种族标记，&"undead" 触发种族克制）/ class_id: StringName
## - hit: float / dodge: float / status_resist: float
## - phys_pierce: int / mag_pierce: int / phys_resist: float / mag_resist: float /
##   phys_armor: int / mag_armor: int（批 2 由 DerivedStats + 装备预算）
## - has_resource(kind: int, amount: int) -> bool / consume_resource(kind: int, amount: int) -> void
##   （kind = SkillDef.ResourceKind；职业轨映射（法力/精力）与敌方单池归单位侧实现）
## - take_damage(amount: int) -> void / heal(amount: int) -> void / on_downed() -> void
class_name SkillExecutor
extends RefCounted

## 种族克制乘算 COMBAT_MOD 键（值 = 乘算系数；目标 race_tag = undead 才生效）
const KEY_RACE_UNDEAD_MULT: StringName = &"race_undead_damage_mult"
## 种族标记：亡灵（种族克制消费的目标标记）
const RACE_UNDEAD: StringName = &"undead"
## 本次暴击加成 COMBAT_MOD 键
const KEY_CRIT_BONUS: StringName = &"crit_bonus"
## 面板乘算修正键（高地 ×1.2——StatusDef.modifiers 键，经 get_stat_mod 求和）
const KEY_PANEL_MULT: StringName = &"damage_panel_mult"

## 单次执行结果（轻类：供 UI 演出与测试断言消费）
class ExecutionResult:
	extends RefCounted
	## 执行是否成功通过前置校验并完成结算
	var success: bool = false
	## 失败码（成功时为空）：out_of_range / no_line_of_sight / no_resource /
	## invalid_target / target_downed
	var error: StringName = &""
	## 攻击命中掷结果（无攻击段为 false）
	var hit: bool = false
	## 暴击掷结果
	var crit: bool = false
	## 钳制后命中概率（攻击段）
	var hit_chance: float = 0.0
	## 毛面板伤害（减免轨前；攻击段）
	var raw_damage: float = 0.0
	## 最终造成伤害（暴击已乘；攻击段）
	var damage: int = 0
	## 治疗量（HEAL 效果）
	var heal: int = 0
	## 主目标 id（单体攻击/治疗目标）
	var target_id: StringName = &""
	## 施加成功清单（"单位id|状态id"——怒吼多目标逐格记录）
	var applied_statuses: Array[StringName] = []
	## 倒地单位 id 清单（本次执行内击倒）
	var downed_units: Array[StringName] = []
	## 动态地格生成位（TILE_SPAWN；未生成为 (-1, -1)）
	var spawned_tile: Vector2i = Vector2i(-1, -1)
	## 动态地格预结算伤害（TILE_SPAWN）
	var spawned_tile_damage: int = 0

func execute(caster: Object, skill: SkillDef, target_cell: Vector2i, ctx: Dictionary) -> ExecutionResult:
	## 技能执行主入口（流程见类头注释；AURA_3X3 走怒吼特化分支）
	## 参数 caster：施放单位；skill：技能定义；target_cell：目标格；ctx：执行上下文
	## 返回：ExecutionResult（success=false 时带失败码，资源未扣）
	var result := ExecutionResult.new()
	var grid: BattleGrid = ctx.get(&"grid") as BattleGrid
	var status_manager: StatusManager = ctx.get(&"status_manager") as StatusManager
	var cfg: CoreConfig = ctx.get(&"cfg") as CoreConfig
	var rng: RandomNumberGenerator = ctx.get(&"rng") as RandomNumberGenerator
	var status_lookup: Callable = ctx.get(&"status_lookup") as Callable
	var forced: int = ctx.get(&"forced", -1)
	var forced_crit: int = ctx.get(&"forced_crit", -1)
	# ①前置校验 + 怒吼特化（AURA_3X3 自中心 3×3，免射程/视线检查）
	if skill.target_shape == SkillDef.TargetShape.AURA_3X3:
		_ExecuteAura(caster, skill, grid, status_manager, rng, forced, status_lookup, result)
		result.success = true
		return result
	var distance: int = absi(caster.grid_pos.x - target_cell.x) + absi(caster.grid_pos.y - target_cell.y)
	if distance > skill.range:
		result.error = &"out_of_range"
		return result
	if skill.range > 1 and not grid.has_line_of_sight(caster.grid_pos, target_cell):
		result.error = &"no_line_of_sight"
		return result
	# ①前置校验：目标解析（单体敌/友/自身；治疗仅未倒地；CELL 指定格无单位目标）
	var target: Object = _ResolveTarget(caster, skill, target_cell, grid, result)
	if result.error != &"":
		return result
	# ①前置校验：资源充足（不足即失败，未扣减）
	if skill.resource_type != SkillDef.ResourceKind.NONE \
			and not caster.has_resource(skill.resource_type, skill.resource_cost):
		result.error = &"no_resource"
		return result
	# ②扣资源（校验全过才扣；攻击未中/施加失败均不返还）
	if skill.resource_type != SkillDef.ResourceKind.NONE:
		caster.consume_resource(skill.resource_type, skill.resource_cost)
	# ③攻击段（damage_type ≠ NONE；DEMO 的 CELL 指定格技无伤害段）
	var attack_ok: bool = true
	if skill.damage_type != SkillDef.DamageType.NONE and target != null:
		attack_ok = _ExecuteAttack(caster, target, skill, cfg, status_manager, rng,
				forced, forced_crit, result)
	# ④效果遍历（STATUS_APPLY 仅攻击命中后处理；HEAL 免判定；TILE_SPAWN 预结算）
	_ExecuteEffects(caster, skill, target, target_cell, attack_ok, grid, status_manager,
			rng, forced, status_lookup, result)
	result.success = true
	return result

func _ResolveTarget(caster: Object, skill: SkillDef, target_cell: Vector2i,
		grid: BattleGrid, result: ExecutionResult) -> Object:
	## 目标解析：SELF → 施放者；敌侧单体 → 目标格敌方单位（空格/己方 = invalid）；
	## 友侧单体 → 目标格己方存活单位（治疗仅未倒地——空格/倒地分码）；
	## CELL（指定格）无单位目标（地格生成消费 target_cell）
	## 参数：见调用侧（result 回写失败码）
	## 返回：目标单位；CELL 返回 null 且不写失败码；失败返回 null 并已写码
	if skill.target_shape == SkillDef.TargetShape.CELL:
		return null
	match skill.target_side:
		SkillDef.TargetSide.SELF:
			return caster
		SkillDef.TargetSide.ALLY:
			var ally: Object = grid.get_unit_at(target_cell)
			if ally == null:
				result.error = &"invalid_target"
			elif not ally.alive:
				result.error = &"target_downed"
			if ally == null or not ally.alive:
				return null
			return ally
		_:
			var enemy: Object = grid.get_unit_at(target_cell)
			if enemy == null or not enemy.alive or enemy.side == caster.side:
				result.error = &"invalid_target"
				return null
			return enemy

func _ExecuteAttack(caster: Object, target: Object, skill: SkillDef, cfg: CoreConfig,
		status_manager: StatusManager, rng: RandomNumberGenerator, forced: int,
		forced_crit: int, result: ExecutionResult) -> bool:
	## 攻击段结算：命中掷 → 毛面板（COMBAT_MOD panel/crit/race 修正）→ 减免轨
	## （按 PHYSICAL/MAGICAL 选护甲穿甲对）→ 暴击掷 ×CRIT_MULT_BASE →
	## take_damage → 倒地回调
	## 参数：见调用侧（result 回写命中/伤害明细）
	## 返回：true = 攻击命中（效果段 STATUS_APPLY 的门条件）
	result.target_id = target.id
	result.hit_chance = BattleRules.hit_chance(caster.hit, target.dodge, skill.hit_mod, cfg)
	result.hit = BattleRules.roll_hit(result.hit_chance, rng, forced)
	if not result.hit:
		return false
	# COMBAT_MOD 收集（本次修正：暴击加成求和 + 种族克制乘算）
	var crit_bonus: float = _CollectCombatMods(skill, KEY_CRIT_BONUS)
	var race_mult: float = 1.0
	if target.race_tag == RACE_UNDEAD:
		race_mult = _CollectCombatMods(skill, KEY_RACE_UNDEAD_MULT)
	# 毛面板（panel_mult = 状态乘算层，如高地 ×1.2；DEMO 单源求和口径）
	var panel_mult: float = _StatusPanelMult(caster, status_manager)
	result.raw_damage = BattleRules.raw_panel_damage(caster.attrs, caster.weapon_bonus,
			skill, panel_mult, race_mult)
	# 减免轨：按伤害类型选抗性/护甲/穿甲对
	var resist: float = 0.0
	var armor: int = 0
	var pierce: int = 0
	if skill.damage_type == SkillDef.DamageType.PHYSICAL:
		resist = target.phys_resist
		armor = target.phys_armor
		pierce = caster.phys_pierce
	else:
		resist = target.mag_resist
		armor = target.mag_armor
		pierce = caster.mag_pierce
	var damage: int = BattleRules.mitigate(result.raw_damage, resist, armor, pierce, cfg)
	# 暴击掷 ×1.5（减免后值乘算取整）
	var crit_chance: float = BattleRules.crit_rate(int(caster.attrs.get(&"luck", 0)),
			int(caster.attrs.get(&"agility", 0)), crit_bonus, cfg)
	if BattleRules.roll_hit(crit_chance, rng, forced_crit):
		result.crit = true
		damage = int(round(damage * DerivedStats.CRIT_MULT_BASE))
	# 结算与倒地回调
	target.take_damage(damage)
	result.damage = damage
	if not target.alive:
		target.on_downed()
		result.downed_units.append(target.id)
	return true

func _ExecuteEffects(caster: Object, skill: SkillDef, target: Object, target_cell: Vector2i,
		attack_ok: bool, grid: BattleGrid, status_manager: StatusManager,
		rng: RandomNumberGenerator, forced: int, status_lookup: Callable,
		result: ExecutionResult) -> void:
	## 效果遍历：STATUS_APPLY（attack_ok 门）→ try_apply_with_judgement（独立
	## 第二掷链）；HEAL 免判定直取；TILE_SPAWN 生成动态地格（伤害预结算
	## = damage_expr「属性id*系数」按施放者属性折算，免判定免减免 D7）；
	## COMBAT_MOD 已在攻击段收集消费，此处跳过
	## 参数：见调用侧（result 回写施加/治疗/地格明细）
	## 返回：无
	for effect: SkillEffect in skill.effects:
		match effect.effect_kind:
			SkillEffect.EffectKind.STATUS_APPLY:
				if not attack_ok or target == null:
					continue
				var status: StatusDef = status_lookup.call(effect.status_id) as StatusDef
				if status == null:
					push_error("SkillExecutor: 状态 '%s' 无法解析（%s）" % [
						effect.status_id, skill.id,
					])
					continue
				if status_manager.try_apply_with_judgement(caster, target, skill, status,
						effect.duration, rng, forced):
					result.applied_statuses.append(StringName("%s|%s" % [target.id, status.id]))
			SkillEffect.EffectKind.HEAL:
				if target == null:
					push_error("SkillExecutor: HEAL 效果无目标单位（%s）" % skill.id)
					continue
				var amount: int = BattleRules.heal_amount(caster.attrs, effect)
				target.heal(amount)
				result.heal = amount
			SkillEffect.EffectKind.TILE_SPAWN:
				var trap_damage: int = _ResolveTrapDamage(effect, caster)
				grid.spawn_dynamic_tile(target_cell, effect.tile_type_id, trap_damage, caster.id)
				result.spawned_tile = target_cell
				result.spawned_tile_damage = trap_damage
			_:
				continue

func _ExecuteAura(caster: Object, skill: SkillDef, grid: BattleGrid,
		status_manager: StatusManager, rng: RandomNumberGenerator, forced: int,
		status_lookup: Callable, result: ExecutionResult) -> void:
	## AURA_3X3 怒吼特化：以施放者为中心 3×3（切比雪夫 ≤1 含中心）逐格——
	## 敌对存活单位独立两段判定施加状态（每格独立掷）；DEMO 怒吼无伤害段
	## （damage_type = NONE），伤害型光环批 2+ 需求出现时再扩展
	## 参数：见调用侧（result 回写逐格施加清单）
	## 返回：无
	for cell: Vector2i in grid.cells_aura_3x3(caster.grid_pos):
		var unit: Object = grid.get_unit_at(cell)
		if unit == null or not unit.alive or unit.side == caster.side:
			continue
		for effect: SkillEffect in skill.effects:
			if effect.effect_kind != SkillEffect.EffectKind.STATUS_APPLY:
				continue
			var status: StatusDef = status_lookup.call(effect.status_id) as StatusDef
			if status == null:
				push_error("SkillExecutor: 怒吼状态 '%s' 无法解析（%s）" % [
					effect.status_id, skill.id,
				])
				continue
			if status_manager.try_apply_with_judgement(caster, unit, skill, status,
					effect.duration, rng, forced):
				result.applied_statuses.append(StringName("%s|%s" % [unit.id, status.id]))

func _CollectCombatMods(skill: SkillDef, key: StringName) -> float:
	## 求和技能 COMBAT_MOD 效果中同 key 的修正值（如 crit_bonus +0.10）
	## 参数 skill：技能；key：修正键
	## 返回：Σ修正值（无匹配返回 0.0；种族乘算键无匹配时调用方保持基准 1.0 语义——
	## DEMO 数据侧约定种族乘算键必带显式系数值，求和即为该系数）
	var total: float = 0.0
	for effect: SkillEffect in skill.effects:
		if effect.effect_kind == SkillEffect.EffectKind.COMBAT_MOD and effect.key == key:
			total += effect.value
	return total

func _StatusPanelMult(caster: Object, status_manager: StatusManager) -> float:
	## 面板乘算层：施放者 damage_panel_mult 修正求和（无修正时 1.0；
	## DEMO 高地单源 ×1.2 求和口径——多乘算源引入时改乘算链，见批 2 注）
	## 参数 caster：施放单位；status_manager：状态管理器
	## 返回：乘算系数
	var value: float = status_manager.get_stat_mod(caster, KEY_PANEL_MULT)
	return value if not is_zero_approx(value) else 1.0

func _ResolveTrapDamage(effect: SkillEffect, caster: Object) -> int:
	## 陷阱伤害预结算：解析 damage_expr「属性id*系数」（如 "agility*1.0"），
	## 按施放者属性折算取整；格式非法 push_error 返回 0
	## 参数 effect：TILE_SPAWN 效果参数组；caster：施放单位
	## 返回：预结算伤害
	var parts: PackedStringArray = effect.damage_expr.split("*", false)
	if parts.size() != 2:
		push_error("SkillExecutor: 伤害表达式 '%s' 非法（应如 agility*1.0）" % effect.damage_expr)
		return 0
	var attr_value: int = int(caster.attrs.get(StringName(parts[0]), 0))
	var multiplier: float = parts[1].to_float()
	return int(round(attr_value * multiplier))
