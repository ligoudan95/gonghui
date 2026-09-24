## 敌方 AI（EnemyAI，纯静态工具类）
## 职责：敌方单位的单回合决策——目标四级链（可击杀 > 追击记忆 > 血量最低
## （持平最近）> 兜底最近）、技能选择（精英怒吼首用义务/穷追优先；杂兵资源
## 优先耗尽转普攻）、移动（距目标曼哈顿最近的可达可停留格，已在射程不移动）。
## 数据来源：案 9 §2.5（目标链第七轮口径）；17 案 §3.8 敌方技能表 +
## 17-C16 P1（怒吼每场首次条件满足必用 1 次、此后穷追猛打优先；条件首次
## 满足但精力不足 → 义务作废不顺延）。
## 纯逻辑约束：不触任何 autoload——cfg/skill_lookup 经 ctx 注入；
## 决策记忆（roar_used/last_target_id）挂 self_unit.ai_context（跨回合随单位实例存续）。
## ctx 字典键：&"cfg"（CoreConfig）/ &"skill_lookup"（Callable：StringName -> SkillDef）。
class_name EnemyAI
extends RefCounted

## 移动/攻击「无目标」哨兵（地图坐标 ≥0，-1 安全）
const NO_CELL: Vector2i = Vector2i(-1, -1)
## 怒吼义务的 3×3 我方数量门槛（案 9 §2.5 / 17-C16 P1）
## 怒吼义务门槛兜底（= cfg_main.ai_roar_ally_count_line——批 B M3：AI 行为
## 可调参数入表；3×3 内我方数 ≥ 门槛精英才考虑怒吼）
const ROAR_ALLY_COUNT_LINE_FALLBACK: int = 2

static func _RoarAllyCountLine(cfg: CoreConfig) -> int:
	## 怒吼义务门槛读取（cfg 注入优先，缺省回退兜底——与表值一致声明锚定）
	## 参数 cfg：注入配置
	## 返回：门槛值
	return cfg.ai_roar_ally_count_line if cfg != null and cfg.ai_roar_ally_count_line > 0 \
			else ROAR_ALLY_COUNT_LINE_FALLBACK

## 单回合决策产物
class AIAction:
	extends RefCounted
	## 锁定目标单位（怒吼/待机为 null）
	var target_unit: Object = null
	## 使用技能 id（待机为空）
	var skill_id: StringName = &""
	## 移动目的地（NO_CELL = 不移动）
	var move_dest: Vector2i = NO_CELL
	## 攻击目标格（NO_CELL = 只移动待机/待机）
	var attack_cell: Vector2i = NO_CELL

static func decide(self_unit: Object, grid: BattleGrid, player_units: Array,
		ctx: Dictionary) -> AIAction:
	## 敌方单回合决策主入口：技能选择 →（非怒吼）目标四级链 → 移动裁决
	## 参数 self_unit：决策单位（BattleUnit）；grid：战场；player_units：我方单位全集；
	## ctx：{cfg, skill_lookup}
	## 返回：AIAction（执行由 BattleController 消费）
	var action := AIAction.new()
	var cfg: CoreConfig = ctx.get(&"cfg") as CoreConfig
	var skill_lookup: Callable = ctx.get(&"skill_lookup") as Callable
	var candidates: Array = player_units.filter(func(unit): return unit.alive)
	if candidates.is_empty():
		return action
	# ---- 技能选择（17-C16 P1 + 资源优先）----
	var skill_id: StringName = _ChooseSkill(self_unit, grid, candidates, cfg, skill_lookup)
	var skill: SkillDef = skill_lookup.call(skill_id) as SkillDef
	if skill == null:
		return action
	action.skill_id = skill_id
	# 怒吼：自中心光环，无目标无移动（执行器走 AURA 分支）
	if skill.target_shape == SkillDef.TargetShape.AURA_3X3:
		action.attack_cell = self_unit.grid_pos
		return action
	# ---- 目标四级链 ----
	var target: Object = _ChooseTarget(self_unit, skill, candidates, cfg)
	if target == null:
		return action
	action.target_unit = target
	self_unit.ai_context[&"last_target_id"] = target.id
	# ---- 移动裁决 ----
	var distance: int = _Manhattan(self_unit.grid_pos, target.grid_pos)
	if distance <= skill.range:
		action.attack_cell = target.grid_pos
		return action
	var reachable: Array[Vector2i] = grid.find_reachable(self_unit, self_unit.move_final())
	var best: Vector2i = NO_CELL
	var best_distance: int = distance
	for cell: Vector2i in reachable:
		var cell_distance: int = _Manhattan(cell, target.grid_pos)
		if cell_distance < best_distance:
			best = cell
			best_distance = cell_distance
	if best == NO_CELL:
		return action
	action.move_dest = best
	# 移动后目标进入射程才攻击，否则只移动待机
	if best_distance <= skill.range:
		action.attack_cell = target.grid_pos
	return action

static func _ChooseSkill(self_unit: Object, grid: BattleGrid, candidates: Array,
		cfg: CoreConfig, skill_lookup: Callable) -> StringName:
	## 技能选择：精英——怒吼义务（每场首次「3×3 内我方 ≥2」：精力足必用、
	## 不足义务作废不顺延，均置 roar_used）；此后穷追猛打类优先（精力足够）；
	## 杂兵——首个精力足够的主动技，耗尽转通用普攻
	## 参数 self_unit/grid/candidates：决策上下文；cfg/skill_lookup：注入依赖
	## 返回：技能 id
	var common: StringName = self_unit.base_attack_id
	var roar_id: StringName = &""
	var damage_skills: Array[StringName] = []
	for skill_id: StringName in self_unit.skill_ids:
		var skill: SkillDef = skill_lookup.call(skill_id) as SkillDef
		if skill == null or skill_id == common:
			continue
		if skill.target_shape == SkillDef.TargetShape.AURA_3X3:
			roar_id = skill_id
		elif skill.damage_type != SkillDef.DamageType.NONE:
			damage_skills.append(skill_id)
	# 精英分支（role_tag=elite）
	if self_unit.role_tag == &"elite":
		if roar_id != &"" and not self_unit.ai_context.get(&"roar_used", false):
			var roar_skill: SkillDef = skill_lookup.call(roar_id) as SkillDef
			if _AlliesInAura3x3(self_unit, candidates, grid) >= _RoarAllyCountLine(cfg):
				# 首次满足：精力足 → 必用（决策即置 roar_used 关闭义务——每场一次）；
				# 不足 → 义务作废（不顺延）——两态均关闭义务
				self_unit.ai_context[&"roar_used"] = true
				if self_unit.has_resource(roar_skill.resource_type, roar_skill.resource_cost):
					return roar_id
		# 穷追优先：首个精力足够的伤害技（DEMO 精英技能表序 = 穷追在前）
		for skill_id: StringName in damage_skills:
			var skill: SkillDef = skill_lookup.call(skill_id) as SkillDef
			if self_unit.has_resource(skill.resource_type, skill.resource_cost):
				return skill_id
		return common
	# 杂兵分支：首个精力足够的主动技，耗尽转普攻
	for skill_id: StringName in damage_skills:
		var skill: SkillDef = skill_lookup.call(skill_id) as SkillDef
		if self_unit.has_resource(skill.resource_type, skill.resource_cost):
			return skill_id
	return common

static func _ChooseTarget(self_unit: Object, skill: SkillDef, candidates: Array,
		cfg: CoreConfig) -> Object:
	## 目标四级链：①期望伤害 ≥ 目标剩余 HP（可击杀，多个取最近）②追击记忆
	## （last_target_id 存活即在）③血量最低（持平按距离最近）④兜底距离最近
	## 参数 self_unit/skill/candidates：决策上下文；cfg：注入配置
	## 返回：目标单位（空候选由调用方前置拦截）
	# ①可击杀（最近优先）
	var killable: Array = candidates.filter(func(unit):
		return _ExpectedDamage(self_unit, skill, unit, cfg) >= float(unit.current_hp))
	if not killable.is_empty():
		return _NearestOf(self_unit, killable)
	# ②追击记忆
	var last_id: StringName = self_unit.ai_context.get(&"last_target_id", &"")
	if last_id != &"":
		for unit: Object in candidates:
			if unit.id == last_id:
				return unit
	# ③血量最低（持平最近）→ ④兜底最近（比较器自然覆盖）
	var best: Object = null
	for unit: Object in candidates:
		if best == null:
			best = unit
			continue
		var hp_less: bool = unit.current_hp < best.current_hp
		var hp_equal: bool = unit.current_hp == best.current_hp
		var distance: int = _Manhattan(self_unit.grid_pos, unit.grid_pos)
		var best_distance: int = _Manhattan(self_unit.grid_pos, best.grid_pos)
		if hp_less or (hp_equal and distance < best_distance):
			best = unit
	return best

static func _ExpectedDamage(self_unit: Object, skill: SkillDef, target: Object,
		cfg: CoreConfig) -> float:
	## 对目标单发期望伤害（镜像 SkillExecutor 攻击链：毛面板 → 减免轨 →
	## 命中 × 暴击期望）
	## 参数 self_unit/skill/target：决策三角；cfg：注入配置
	## 返回：期望伤害（float）
	var raw: float = BattleRules.raw_panel_damage(self_unit.attrs, self_unit.weapon_bonus,
			skill, 1.0, 1.0)
	var resist: float = 0.0
	var armor: int = 0
	var pierce: int = 0
	if skill.damage_type == SkillDef.DamageType.PHYSICAL:
		resist = target.phys_resist
		armor = target.phys_armor
		pierce = self_unit.phys_pierce
	else:
		resist = target.mag_resist
		armor = target.mag_armor
		pierce = self_unit.mag_pierce
	var mitigated: int = BattleRules.mitigate(raw, resist, armor, pierce, cfg)
	var chance: float = BattleRules.hit_chance(self_unit.hit, target.dodge, skill.hit_mod, cfg)
	var crit: float = BattleRules.crit_rate(int(self_unit.attrs.get(&"luck", 0)),
			int(self_unit.attrs.get(&"agility", 0)),
			SkillExecutor.collect_combat_mod(skill, SkillExecutor.KEY_CRIT_BONUS), cfg)
	return BattleRules.expected_damage(mitigated, chance, crit, cfg.crit_mult_base)

static func _AlliesInAura3x3(self_unit: Object, candidates: Array, grid: BattleGrid) -> int:
	## 自中心 3×3（切比雪夫 ≤1）内存活我方数（怒吼义务门槛）
	## 参数 self_unit/candidates/grid：决策上下文
	## 返回：数量
	var count: int = 0
	for cell: Vector2i in grid.cells_aura_3x3(self_unit.grid_pos):
		var unit: Object = grid.get_unit_at(cell)
		if unit != null and unit.alive and unit.side != self_unit.side:
			count += 1
	return count

static func _NearestOf(self_unit: Object, units: Array) -> Object:
	## 距离最近者（平局取遍历首——候选序即配置序）
	## 参数 self_unit/units：决策上下文
	## 返回：最近单位
	var best: Object = null
	var best_distance: int = 0
	for unit: Object in units:
		var distance: int = _Manhattan(self_unit.grid_pos, unit.grid_pos)
		if best == null or distance < best_distance:
			best = unit
			best_distance = distance
	return best

static func _Manhattan(a: Vector2i, b: Vector2i) -> int:
	## 曼哈顿距离
	## 参数 a/b：两坐标
	## 返回：|dx| + |dy|
	return absi(a.x - b.x) + absi(a.y - b.y)
