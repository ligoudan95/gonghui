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
const KEY_RACE_UNDEAD_MULT: StringName = ModKeys.RACE_UNDEAD_MULT
## 种族标记：亡灵（种族克制消费的目标标记）
const RACE_UNDEAD: StringName = &"undead"
## 本次暴击加成 COMBAT_MOD 键
const KEY_CRIT_BONUS: StringName = ModKeys.CRIT_BONUS
## 面板乘算修正键（高地 ×1.2——StatusDef.modifiers 键，经 get_stat_mod 求和）
const KEY_PANEL_MULT: StringName = ModKeys.DAMAGE_PANEL_MULT

## 单源收集公开口（批 A H1：执行链与 battle_screen._ExpectedDamageOn 共用同一
## 函数——此前 UI 侧 race_mult 从 1.0 起加 Σ 与执行侧 Σ 直接覆盖口径分叉，
## 且执行侧「技能没带种族键时乘 0」语义脆弱，均收敛到此处：无键回 1.0）
static func los_required(skill: SkillDef) -> bool:
	## 技能是否需视线前置校验（射程 > 1——批 C M5 单源口径：执行器前置校验
	## 与 battle_screen 范围渲染/点选拦截共用同一判定，UI 展示与实际可执行
	## 恒一致；近战射程 1 免视线）
	## 参数 skill：技能定义
	## 返回：true = 射程 > 1 需视线
	return skill != null and skill.range > 1

static func collect_combat_mod(skill: SkillDef, key: StringName) -> float:
	## 求和技能 COMBAT_MOD 效果中同 key 的修正值（如 crit_bonus +0.10）
	## 参数 skill：技能；key：修正键（ModKeys.COMBAT_MOD 域）
	## 返回：Σ修正值（无匹配 0.0；调用方按键语义决定回退值）
	var total: float = 0.0
	for effect: SkillEffect in skill.effects:
		if effect.effect_kind == SkillEffect.EffectKind.COMBAT_MOD and effect.key == key:
			total += effect.value
	return total

static func collect_race_mult(skill: SkillDef, target_race_tag: StringName) -> float:
	## 种族克制乘算（单源）：目标为亡灵 = Σ技能种族键系数（无键回 1.0——
	## 修正键缺失 = 不克制，非乘 0）；非亡灵目标恒 1.0
	## 参数 skill：技能；target_race_tag：目标种族标记
	## 返回：乘算系数
	if target_race_tag != RACE_UNDEAD:
		return 1.0
	var total: float = collect_combat_mod(skill, KEY_RACE_UNDEAD_MULT)
	return total if total > 0.0 else 1.0

static func panel_mult_of(caster: Object, status_manager: StatusManager) -> float:
	## 面板乘算层（单源）：施放者 damage_panel_mult 修正求和（无修正 1.0；
	## DEMO 高地单源 ×1.2 求和口径——多乘算源引入时改乘算链，见批 2 注）
	## 参数 caster：施放单位；status_manager：状态管理器
	## 返回：乘算系数
	var value: float = status_manager.get_stat_mod(caster, KEY_PANEL_MULT)
	return value if not is_zero_approx(value) else 1.0

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
	## 结构化执行明细（战斗日志消费——2026-09-24 五轮反馈；键 = 英文
	## StringName 数据契约，中文模板在 UI 层；全部取自执行链既有输入与
	## 返回值，不含预格式化文案）：
	## - &"skill"/&"caster"/&"target"/&"fail_reason"：标识与失败码
	## - &"hit_chain"：{base/mod/dodge/final/passed}（构成均来自执行器持有的输入）
	## - &"damage_chain"：{raw/panel_mult/race_mult/resist/armor/pierce/
	##   mitigated/crit_chance/crit/final}
	## - &"statuses"：[{id/duration/applied}]（施加链逐条）
	## - &"heal"：治疗量；&"trap"：{cell/damage}
	var trace: Dictionary = {}

func execute(caster: Object, skill: SkillDef, target_cell: Vector2i, ctx: Dictionary) -> ExecutionResult:
	## 技能执行主入口（流程见类头注释；AURA_3X3 走怒吼特化分支）
	## 参数 caster：施放单位；skill：技能定义；target_cell：目标格；ctx：执行上下文
	## 返回：ExecutionResult（success=false 时带失败码，资源未扣）
	var result := ExecutionResult.new()
	result.trace[&"skill"] = skill.id
	result.trace[&"caster"] = caster.id
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
		result.trace[&"fail_reason"] = result.error
		return result
	if los_required(skill) and not grid.has_line_of_sight(caster.grid_pos, target_cell):
		result.error = &"no_line_of_sight"
		result.trace[&"fail_reason"] = result.error
		return result
	# ①前置校验：目标解析（单体敌/友/自身；治疗仅未倒地；CELL 指定格无单位目标）
	var target: Object = _ResolveTarget(caster, skill, target_cell, grid, result)
	if result.error != &"":
		return result
	# ①前置校验：资源充足（不足即失败，未扣减）
	if skill.resource_type != SkillDef.ResourceKind.NONE \
			and not caster.has_resource(skill.resource_type, skill.resource_cost):
		result.error = &"no_resource"
		result.trace[&"fail_reason"] = result.error
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
				result.trace[&"fail_reason"] = result.error
			elif not ally.alive:
				result.error = &"target_downed"
				result.trace[&"fail_reason"] = result.error
			elif ally.side != caster.side:
				# 阵营校验（盲审批 1-1：ALLY 技不可作用于敌方——治疗技点敌格
				# 此前直接放行，与 ENEMY 分支的镜像校验对齐）
				result.error = &"invalid_target"
				result.trace[&"fail_reason"] = result.error
			if ally == null or not ally.alive or ally.side != caster.side:
				return null
			return ally
		_:
			var enemy: Object = grid.get_unit_at(target_cell)
			if enemy == null or not enemy.alive or enemy.side == caster.side:
				result.error = &"invalid_target"
				result.trace[&"fail_reason"] = result.error
				return null
			return enemy

func _ExecuteAttack(caster: Object, target: Object, skill: SkillDef, cfg: CoreConfig,
		status_manager: StatusManager, rng: RandomNumberGenerator, forced: int,
		forced_crit: int, result: ExecutionResult) -> bool:
	## 攻击段结算：命中掷 → 毛面板（COMBAT_MOD panel/crit/race 修正）→ 减免轨
	## （按 PHYSICAL/MAGICAL 选护甲穿甲对）→ 暴击掷 ×cfg.crit_mult_base →
	## take_damage → 倒地回调
	## 参数：见调用侧（result 回写命中/伤害明细）
	## 返回：true = 攻击命中（效果段 STATUS_APPLY 的门条件）
	result.target_id = target.id
	result.trace[&"target"] = target.id
	result.hit_chance = BattleRules.hit_chance(caster.hit, target.dodge, skill.hit_mod, cfg)
	result.hit = BattleRules.roll_hit(result.hit_chance, rng, forced)
	result.trace[&"hit_chain"] = {
		&"base": caster.hit,
		&"mod": skill.hit_mod,
		&"dodge": target.dodge,
		&"final": result.hit_chance,
		&"passed": result.hit,
	}
	if not result.hit:
		return false
	# COMBAT_MOD 收集（单源静态口——批 A H1）：暴击加成 + 种族克制乘算
	var crit_bonus: float = collect_combat_mod(skill, KEY_CRIT_BONUS)
	var race_mult: float = collect_race_mult(skill, target.race_tag)
	# 毛面板（panel_mult = 状态乘算层，如高地 ×1.2；单源静态口）
	var panel_mult: float = panel_mult_of(caster, status_manager)
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
	var mitigated_value: int = damage
	# 暴击掷 ×1.5（减免后值乘算取整）
	var crit_chance: float = BattleRules.crit_rate(int(caster.attrs.get(&"luck", 0)),
			int(caster.attrs.get(&"agility", 0)), crit_bonus, cfg)
	if BattleRules.roll_hit(crit_chance, rng, forced_crit):
		result.crit = true
		damage = int(round(damage * cfg.crit_mult_base))
	result.trace[&"damage_chain"] = {
		&"raw": result.raw_damage,
		&"panel_mult": panel_mult,
		&"race_mult": race_mult,
		&"resist": resist,
		&"armor": armor,
		&"pierce": pierce,
		&"mitigated": mitigated_value,
		&"crit_chance": crit_chance,
		&"crit": result.crit,
		&"final": damage,
	}
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
				var applied: bool = status_manager.try_apply_with_judgement(caster, target, skill,
						status, effect.duration, rng, forced)
				if not result.trace.has(&"statuses"):
					result.trace[&"statuses"] = []
				(result.trace[&"statuses"] as Array).append({
					&"id": status.id,
					&"duration": effect.duration,
					&"applied": applied,
				})
				if applied:
					result.applied_statuses.append(StringName("%s|%s" % [target.id, status.id]))
			SkillEffect.EffectKind.HEAL:
				if target == null:
					push_error("SkillExecutor: HEAL 效果无目标单位（%s）" % skill.id)
					continue
				var amount: int = BattleRules.heal_amount(caster.attrs, effect)
				target.heal(amount)
				result.heal = amount
				result.trace[&"heal"] = amount
			SkillEffect.EffectKind.TILE_SPAWN:
				var trap_damage: int = _ResolveTrapDamage(effect, caster)
				grid.spawn_dynamic_tile(target_cell, effect.tile_type_id, trap_damage, caster.id)
				result.spawned_tile = target_cell
				result.spawned_tile_damage = trap_damage
				result.trace[&"trap"] = {
					&"cell": target_cell,
					&"damage": trap_damage,
				}
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
			var aura_applied: bool = status_manager.try_apply_with_judgement(caster, unit, skill,
					status, effect.duration, rng, forced)
			if not result.trace.has(&"statuses"):
				result.trace[&"statuses"] = []
			(result.trace[&"statuses"] as Array).append({
				&"id": status.id,
				&"duration": effect.duration,
				&"applied": aura_applied,
				&"target": unit.id,
			})
			if aura_applied:
				result.applied_statuses.append(StringName("%s|%s" % [unit.id, status.id]))

func _ResolveTrapDamage(effect: SkillEffect, caster: Object) -> int:
	## 陷阱伤害预结算 = round(施放者 dot_attr_id 属性值 × dot_coefficient)
	## （盲审批 2 A-8：原 damage_expr 字符串公式已拆结构化字段——纯搬家）
	## 参数 effect：TILE_SPAWN 效果参数组；caster：施放单位
	## 返回：预结算伤害
	var attr_value: int = int(caster.attrs.get(effect.dot_attr_id, 0))
	return int(round(attr_value * effect.dot_coefficient))
