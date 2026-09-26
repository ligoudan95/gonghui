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
## 本次暴击加成 COMBAT_MOD 键
const KEY_CRIT_BONUS: StringName = ModKeys.CRIT_BONUS
## 面板乘算修正键（高地 ×1.2——StatusDef.modifiers 键，经 get_stat_mod 求和）
const KEY_PANEL_MULT: StringName = ModKeys.DAMAGE_PANEL_MULT
## 施加状态条目管道分隔符（批 4 C 组 M2：applied_statuses 的 "单位id|状态id"
## 编解码契约单源——生产（本类两处拼接）与消费（BattleController 解析）共用）
const STATUS_ENTRY_PIPE: String = "|"
# ---- 失败码常量（A-5 单源：本类生产、BattleLog 键、测试断言共引）----
## 施放者已倒地（S3-01）
const ERROR_CASTER_DOWNED: StringName = &"caster_downed"
## 射程外
const ERROR_OUT_OF_RANGE: StringName = &"out_of_range"
## 视线阻断
const ERROR_NO_LINE_OF_SIGHT: StringName = &"no_line_of_sight"
## 资源不足
const ERROR_NO_RESOURCE: StringName = &"no_resource"
## 目标非法
const ERROR_INVALID_TARGET: StringName = &"invalid_target"
## 目标已倒地
const ERROR_TARGET_DOWNED: StringName = &"target_downed"
## 目标格不可放置（S3-09 陷阱）
const ERROR_BLOCKED_CELL: StringName = &"blocked_cell"

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

static func effective_range(skill: SkillDef) -> int:
	## 攻击/选格有效射程（单源——批 4 C 组 M6）：max(1, skill.range)——射程 0
	## 自身施法技在攻击位计算/范围显示时按 1 格口径（蛊惑随机攻击的目标池
	## 半径与技能范围红显共用，原两处复刻收敛）
	## 参数 skill：技能定义
	## 返回：有效射程（≥1）
	return maxi(1, skill.range if skill != null else 1)

static func range_cells_of(skill: SkillDef, origin: Vector2i,
		grid: BattleGrid) -> Array[Vector2i]:
	## 技能选格范围（单源——S4-8）：AURA_3X3 走切比雪夫 3×3（自中心光环）、
	## 其余走曼哈顿 effective_range——UI 范围红显与执行度量共用同一口径，
	## 未来我方光环技零改码即正确显示
	## 参数 skill：技能定义；origin：施放者格；grid：战场（界内裁剪）
	## 返回：范围格集（按 y/x 排序）
	if skill == null or grid == null:
		return []
	if skill.target_shape == SkillDef.TargetShape.AURA_3X3:
		return grid.cells_aura_3x3(origin)
	if skill.target_side == SkillDef.TargetSide.SELF:
		# R1-6：SELF 施法技红显仅施放者格（自身技无选格语义——原按有效射程
		# 展开邻格误导可点）
		return [origin]
	return grid.cells_in_range(origin, effective_range(skill))

static func make_status_entry(unit_id: StringName, status_id: StringName) -> StringName:
	## 施加状态条目编码（批 4 C 组 M2 管道符契约单源）："单位id|状态id"
	## ——生产端（攻击链/怒吼链）与消费端（BattleController 解析发信号）共用
	## 参数 unit_id：目标单位 id；status_id：状态 id
	## 返回：编码条目
	return StringName("%s%s%s" % [unit_id, STATUS_ENTRY_PIPE, status_id])

static func parse_status_entry(entry: StringName) -> PackedStringArray:
	## 施加状态条目解码（M2 契约单源）：按管道符拆两段——段数 != 2 视为
	## 非法条目（调用方跳过）
	## 参数 entry：编码条目
	## 返回：[单位id, 状态id]；非法返回空/短数组
	return String(entry).split(STATUS_ENTRY_PIPE)

static func collect_combat_mod(skill: SkillDef, key: StringName) -> float:
	## 求和技能 COMBAT_MOD 效果中同 key 的修正值（如 crit_bonus +0.10）
	## 参数 skill：技能；key：修正键（ModKeys.COMBAT_MOD 域）
	## 返回：Σ修正值（无匹配 0.0；调用方按键语义决定回退值）
	var total: float = 0.0
	for effect: SkillEffect in skill.effects:
		if effect.effect_kind == SkillEffect.EffectKind.COMBAT_MOD and effect.key == key:
			total += effect.value
	return total

## 种族克制映射（A-3 收口：种族 token -> COMBAT_MOD 克制键——新增种族
## 只加一行；消费遍历查表，不再 per 种族硬编码分支）
const RACE_MULT_KEYS: Dictionary = {
	UnitTags.RACE_UNDEAD: ModKeys.RACE_UNDEAD_MULT,
}

static func collect_race_mult(skill: SkillDef, target_race_tag: StringName) -> float:
	## 种族克制乘算（单源 + A-3 查表）：目标种族在克制映射中 = Σ技能对应键
	## 系数（无键回 1.0——修正键缺失 = 不克制，非乘 0）；未登记种族恒 1.0
	## 参数 skill：技能；target_race_tag：目标种族标记
	## 返回：乘算系数
	if not RACE_MULT_KEYS.has(target_race_tag):
		return 1.0
	var total: float = collect_combat_mod(skill, RACE_MULT_KEYS[target_race_tag])
	return total if total > 0.0 else 1.0

static func panel_mult_of(caster: Object, status_manager: StatusManager) -> float:
	## 面板乘算层（单源）：施放者 damage_panel_mult 修正求和（无修正 1.0；
	## DEMO 高地单源 ×1.2 求和口径）。
	## W1-4 债务登记（2026-09-26 审计）：加法近似仅在**单乘算源**时正确——
	## 多乘算源（高地 + 背刺等同时引入）时 Σ(x−1) ≠ Πx，届时须改乘算链；
	## M4+ 新增乘算类站位/状态前必须回收本注（消费面：执行链/AI 期望/UI 预览三处同源）
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
	## 技能执行主入口（流程见类头注释；AURA_3X3 走怒吼特化分支——S2-1/S3-02
	## 整改：怒吼与常规技同走资源校验与扣减，仅免射程/视线/目标解析）
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
	# ①前置校验：施放者存活（S3-01：踩陷阱致死后残留攻击链拦截——
	# 死人不放技能，含蛊惑/AI/玩家全路径）
	if not caster.alive:
		result.error = ERROR_CASTER_DOWNED
		result.trace[&"fail_reason"] = result.error
		return result
	# ①前置校验 + 怒吼特化标记（AURA_3X3 自中心 3×3，免射程/视线/目标解析——
	# 资源校验/扣减不豁免，S2-1/S3-02）
	var is_aura: bool = skill.target_shape == SkillDef.TargetShape.AURA_3X3
	var target: Object = null
	if not is_aura:
		var distance: int = BattleGrid.manhattan(caster.grid_pos, target_cell)
		if distance > effective_range(skill):
			result.error = ERROR_OUT_OF_RANGE
			result.trace[&"fail_reason"] = result.error
			return result
		if los_required(skill) and not grid.has_line_of_sight(caster.grid_pos, target_cell):
			result.error = ERROR_NO_LINE_OF_SIGHT
			result.trace[&"fail_reason"] = result.error
			return result
		# ①前置校验：目标解析（单体敌/友/自身；治疗仅未倒地；CELL 指定格无单位目标）
		target = _ResolveTarget(caster, skill, target_cell, grid, result)
		if result.error != &"":
			return result
		# ①前置校验：陷阱目标格可放置（S3-09 + R2-5 + R1-7——须可通行、无存活
		# 单位占位、无既有动态地格（R2-5 同格拒绝布设）、非状态地格（R1-7
		# 草丛/高地/毒沼不可覆布））
		if _HasTileSpawn(skill):
			var spawn_tile: TileTypeDef = grid.tile_at(target_cell)
			var occupant: Object = grid.get_unit_at(target_cell)
			if spawn_tile == null or not spawn_tile.walkable \
					or (occupant != null and occupant.alive) \
					or not grid.dynamic_tile_at(target_cell).is_empty() \
					or spawn_tile.kind == TileTypeDef.Kind.STATUS:
				result.error = ERROR_BLOCKED_CELL
				result.trace[&"fail_reason"] = result.error
				return result
	# ①前置校验：资源充足（不足即失败，未扣减——怒吼同口径，S2-1/S3-02）
	if skill.resource_type != SkillDef.ResourceKind.NONE \
			and not caster.has_resource(skill.resource_type, skill.resource_cost):
		result.error = ERROR_NO_RESOURCE
		result.trace[&"fail_reason"] = result.error
		return result
	# ②扣资源（校验全过才扣；攻击未中/施加失败均不返还——怒吼同扣，S2-1/S3-02）
	if skill.resource_type != SkillDef.ResourceKind.NONE:
		caster.consume_resource(skill.resource_type, skill.resource_cost)
	# ③怒吼特化分支（S2-1/S3-02：移到资源扣减之后执行）
	if is_aura:
		_ExecuteAura(caster, skill, grid, status_manager, rng, forced, status_lookup, result)
		result.success = true
		return result
	# ④攻击段（damage_type ≠ NONE；DEMO 的 CELL 指定格技无伤害段）
	var attack_ok: bool = true
	if skill.damage_type != SkillDef.DamageType.NONE and target != null:
		attack_ok = _ExecuteAttack(caster, target, skill, cfg, status_manager, rng,
				forced, forced_crit, result)
	# ⑤效果遍历（STATUS_APPLY 仅攻击命中后处理；HEAL 免判定；TILE_SPAWN 预结算）
	_ExecuteEffects(caster, skill, target, target_cell, attack_ok, grid, status_manager,
			rng, forced, status_lookup, result)
	result.success = true
	return result

static func _HasTileSpawn(skill: SkillDef) -> bool:
	## 技能是否携带 TILE_SPAWN 效果（S3-09 陷阱目标格前置校验的门条件）
	## 参数 skill：技能定义
	## 返回：true = 含地格生成效果
	for effect: SkillEffect in skill.effects:
		if effect.effect_kind == SkillEffect.EffectKind.TILE_SPAWN:
			return true
	return false

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
				result.error = ERROR_INVALID_TARGET
				result.trace[&"fail_reason"] = result.error
			elif not ally.alive:
				result.error = ERROR_TARGET_DOWNED
				result.trace[&"fail_reason"] = result.error
			elif ally.side != caster.side:
				# 阵营校验（盲审批 1-1：ALLY 技不可作用于敌方——治疗技点敌格
				# 此前直接放行，与 ENEMY 分支的镜像校验对齐）
				result.error = ERROR_INVALID_TARGET
				result.trace[&"fail_reason"] = result.error
			if ally == null or not ally.alive or ally.side != caster.side:
				return null
			return ally
		_:
			var enemy: Object = grid.get_unit_at(target_cell)
			if enemy == null or not enemy.alive or enemy.side == caster.side:
				result.error = ERROR_INVALID_TARGET
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
	# 减免轨（选对单源——批 4 H2：物理/法术轨经 BattleRules.mitigate_by_damage_type）
	var damage: int = BattleRules.mitigate_by_damage_type(result.raw_damage,
			skill.damage_type, caster, target, cfg)
	var mitigated_value: int = damage
	# 暴击掷 ×1.5（减免后值乘算取整）
	var crit_chance: float = BattleRules.crit_rate(int(caster.attrs.get(AttrKeys.LUCK, AttrKeys.DEFAULT_ATTR_VALUE)),
			int(caster.attrs.get(AttrKeys.AGILITY, AttrKeys.DEFAULT_ATTR_VALUE)), crit_bonus, cfg)
	if BattleRules.roll_hit(crit_chance, rng, forced_crit):
		result.crit = true
		damage = int(round(damage * BattleRules.crit_mult_base_of(cfg)))
	result.trace[&"damage_chain"] = {
		&"raw": result.raw_damage,
		&"panel_mult": panel_mult,
		&"race_mult": race_mult,
		&"resist": BattleRules.resist_of(skill.damage_type, target),
		&"armor": BattleRules.armor_of(skill.damage_type, target),
		&"pierce": BattleRules.pierce_of(skill.damage_type, caster),
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
				# S2-2：施加失败原因入 trace（miss/resisted/stack_limit/
				# source_not_allowed——日志/UI 反馈「资源白扣」的可见性）
				(result.trace[&"statuses"] as Array).append({
					&"id": status.id,
					&"duration": effect.duration,
					&"applied": applied,
					&"reason": status_manager.last_reject_reason() if not applied else &"",
				})
				if applied:
					result.applied_statuses.append(make_status_entry(target.id, status.id))
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
				&"reason": status_manager.last_reject_reason() if not aura_applied else &"",
				&"target": unit.id,
			})
			if aura_applied:
				result.applied_statuses.append(make_status_entry(unit.id, status.id))

func _ResolveTrapDamage(effect: SkillEffect, caster: Object) -> int:
	## 陷阱伤害预结算 = round(施放者 dot_attr_id 属性值 × dot_coefficient)
	## （盲审批 2 A-8：原 damage_expr 字符串公式已拆结构化字段——纯搬家）
	## 参数 effect：TILE_SPAWN 效果参数组；caster：施放单位
	## 返回：预结算伤害
	var attr_value: int = int(caster.attrs.get(effect.dot_attr_id,
			AttrKeys.DEFAULT_ATTR_VALUE))
	return int(round(attr_value * effect.dot_coefficient))
