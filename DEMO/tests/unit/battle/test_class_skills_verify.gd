## 六职业技能系统性验证套件（M3 后专项 · 2026-09-26）
## 覆盖：六职业（战士/盗贼/法师/牧师/游侠/奇术师）全部 18 技能
## （6 普攻 + 12 职业技）的四层验证——
## ①触发条件：射程边界（含 effective_range）/LOS（射程>1）/目标合法性
##   （target_side/倒地/空格）/资源（不足拒绝 + 足额扣减）；
## ②伤害/治疗数值：固定属性 + forced 掷口，按案 17 §3.4 公式独立手算对照
##   （伤害 =(Σ权重×属性+武器)×系数 → 减免轨（物/法选对）→ 暴击 ×1.5；
##   治疗 = 感知×1.5+10 免命中）；
## ③附加效果：状态施加（两段判定：命中掷→抗性掷；己方免判定）/DOT 施方
##   快照（17-C24）/陷阱预结算 + 触发链口径/控制窗口（定身锁本回合、蛊惑
##   P3 固定下回合）/状态修正入派生（盾墙护甲、疾步移动闪避）；
## ④数据↔文档一致：技能表字段（权重/系数/消耗/射程/伤害类型/效果结构）
##   vs 案 17 §3.4 技能表逐格核对 + §3.11 #7 装备武器加值 + 职业表接线。
## 手算基准（17-C7 区间中值偏上，§3.8 验算带）：杂兵目标全属性 9/甲 2 双轨/
## 抗 0/闪避 4%； caster 属性见各 _Make* 构造器注释。
## 技能/状态/地图/地格全部用 data/ 真实表；forced/forced_crit 注入保证确定性。
extends GdUnitTestSuite

## 真实数据路径
const CFG_PATH: String = "res://data/core/cfg_main.tres"
const MAP_PATH: String = "res://data/battle/maps/btm_m1_random_8x8.tres"
const TILE_DIR: String = "res://data/battle/tiles/"
const STATUS_DIR: String = "res://data/status/stats/"
const SKILL_DIR: String = "res://data/class/skills/"
const CLASS_DIR: String = "res://data/class/classes/"
const EQUIP_DIR: String = "res://data/equip/"

## 套件级组件
var _cfg: CoreConfig
var _grid: BattleGrid
var _manager: StatusManager
var _executor: SkillExecutor
var _tiles: Dictionary = {}
var _statuses: Dictionary = {}
var _rng: RandomNumberGenerator

## 测试替身单位（完整鸭子契约——skill_executor.gd 头注释；派生字段直取
## 定值，保证伤害断言只依赖被测公式而非派生层）
class FakeUnit:
	extends RefCounted
	var id: StringName = &"unit"
	var side: int = 0
	var alive: bool = true
	var grid_pos: Vector2i = Vector2i.ZERO
	var attrs: Dictionary = {}
	var weapon_bonus: int = 0
	var race_tag: StringName = &""
	var class_id: StringName = &""
	var hit: float = 0.80
	var dodge: float = 0.0
	var status_resist: float = 0.0
	var phys_pierce: int = 0
	var mag_pierce: int = 0
	var phys_resist: float = 0.0
	var mag_resist: float = 0.0
	var phys_armor: int = 0
	var mag_armor: int = 0
	var resource_mana: int = 100
	var resource_stamina: int = 100
	var hp: int = 100
	var downed_count: int = 0
	var healed_amount: int = 0
	var damage_taken: Array[int] = []

	func has_resource(kind: int, amount: int) -> bool:
		## 资源余量检查（法力/精力双轨）
		if kind == 1:
			return resource_mana >= amount
		if kind == 2:
			return resource_stamina >= amount
		return true

	func consume_resource(kind: int, amount: int) -> void:
		## 资源扣减
		if kind == 1:
			resource_mana -= amount
		elif kind == 2:
			resource_stamina -= amount

	func take_damage(amount: int) -> void:
		## 承伤（减免轨已在上游结算，此处直扣并记账）
		damage_taken.append(amount)
		hp -= amount
		if hp <= 0:
			alive = false

	func heal(amount: int) -> void:
		## 治疗
		healed_amount += amount
		hp += amount

	func on_downed() -> void:
		## 倒地回调
		downed_count += 1

func before() -> void:
	## 套件前置：加载真实数据、构建组件
	## 参数：无
	## 返回：无
	_cfg = load(CFG_PATH) as CoreConfig
	_tiles = {}
	for tile_id: StringName in [&"tile_normal", &"tile_obstacle", &"tile_grass",
			&"tile_highground", &"tile_poison_swamp", &"tile_trap"]:
		_tiles[tile_id] = load(TILE_DIR + String(tile_id) + ".tres")
	_statuses = {}
	for status_id: StringName in [&"DEBUFF_slow", &"DEBUFF_root", &"DEBUFF_curse",
			&"DEBUFF_bewitch", &"BUFF_shield_wall", &"BUFF_sprint",
			&"BUFF_tile_highground", &"DEBUFF_tile_poison"]:
		_statuses[status_id] = load(STATUS_DIR + String(status_id) + ".tres")
	_executor = SkillExecutor.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 42

func before_test() -> void:
	## 用例前置：重建战场与状态管理器（可变状态逐用例隔离）
	## 参数：无
	## 返回：无
	_grid = BattleGrid.new()
	_grid.setup(load(MAP_PATH) as BattleMapDef, _LookupTile)
	_manager = StatusManager.new()
	_manager.setup(_cfg, _LookupStatus)

func _LookupTile(tile_id: StringName) -> TileTypeDef:
	## 地格定义解析闭包
	## 参数 tile_id：地格 id
	## 返回：TileTypeDef（未登记返回 null）
	return _tiles.get(tile_id, null)

func _LookupStatus(status_id: StringName) -> StatusDef:
	## 状态定义解析闭包
	## 参数 status_id：状态 id
	## 返回：StatusDef（未登记返回 null）
	return _statuses.get(status_id, null)

func _LoadSkill(skill_id: StringName) -> SkillDef:
	## 加载真实技能表
	## 参数 skill_id：技能 id
	## 返回：SkillDef
	return load(SKILL_DIR + String(skill_id) + ".tres") as SkillDef

func _MakeUnit(id: StringName, side_value: int, pos: Vector2i) -> FakeUnit:
	## 构建并放置单位
	## 参数 id/side_value/pos：单位 id / 阵营 / 所在格
	## 返回：已放置单位
	var unit := FakeUnit.new()
	unit.id = id
	unit.side = side_value
	unit.grid_pos = pos
	_grid.place_unit(pos, unit)
	return unit

func _MakeWarrior(pos: Vector2i) -> FakeUnit:
	## 构建战士（17-C7 中值偏上：力16 体14 敏10 感9 智7 幸10 意9；
	## 武器 4（重甲套）；命中率 = 85%+感9调整值(−1)×2% = 83%；物穿 3）
	var unit := _MakeUnit(&"warrior", 0, pos)
	unit.class_id = &"cls_warrior"
	unit.attrs = {&"strength": 16, &"constitution": 14, &"agility": 10,
			&"perception": 9, &"intelligence": 7, &"luck": 10, &"willpower": 9}
	unit.weapon_bonus = 4
	unit.hit = DerivedStats.calc_hit(9, _cfg)
	unit.phys_pierce = DerivedStats.calc_phys_pierce(16, _cfg)
	return unit

func _MakeRogue(pos: Vector2i) -> FakeUnit:
	## 构建盗贼（敏16 幸13 力10 体10 感11 智9 意10；武器 3（皮甲套）；
	## 命中率 = 85%+感11调整值×2%——调整值 = floor((11−10)/2) = +0 → 0.85；
	## 物穿 0（力 10 调整值 +0）；§3.8 验算带「盗贼感知 11→+0 为 80-82%」同源）
	var unit := _MakeUnit(&"rogue", 0, pos)
	unit.class_id = &"cls_rogue"
	unit.attrs = {&"agility": 16, &"luck": 13, &"strength": 10, &"constitution": 10,
			&"perception": 11, &"intelligence": 9, &"willpower": 10}
	unit.weapon_bonus = 3
	unit.hit = DerivedStats.calc_hit(11, _cfg)
	unit.phys_pierce = DerivedStats.calc_phys_pierce(10, _cfg)
	return unit

func _MakeMage(pos: Vector2i) -> FakeUnit:
	## 构建法师（智16 感11 敏10 幸10 力7 体9 意9；武器 2（布甲套）；
	## 命中 0.85（感 11 → +0）；法穿 3（智 16 → +3））
	var unit := _MakeUnit(&"mage", 0, pos)
	unit.class_id = &"cls_mage"
	unit.attrs = {&"intelligence": 16, &"perception": 11, &"agility": 10,
			&"luck": 10, &"strength": 7, &"constitution": 9, &"willpower": 9}
	unit.weapon_bonus = 2
	unit.hit = DerivedStats.calc_hit(11, _cfg)
	unit.mag_pierce = DerivedStats.calc_mag_pierce(16, 9, &"cls_mage", _cfg)
	return unit

func _MakePriest(pos: Vector2i) -> FakeUnit:
	## 构建牧师（感15 智10 意13 体11 敏10 幸10 力10；武器 2（布甲套）；
	## 命中 = 85%+感15调整值(+2)×2% = 89%→0.89；法穿 0（智 10 → +0，M2 智力口径））
	var unit := _MakeUnit(&"priest", 0, pos)
	unit.class_id = &"cls_priest"
	unit.attrs = {&"perception": 15, &"intelligence": 10, &"willpower": 13,
			&"constitution": 11, &"agility": 10, &"luck": 10, &"strength": 10}
	unit.weapon_bonus = 2
	unit.hit = DerivedStats.calc_hit(15, _cfg)
	unit.mag_pierce = DerivedStats.calc_mag_pierce(10, 13, &"cls_priest", _cfg)
	return unit

func _MakeRanger(pos: Vector2i) -> FakeUnit:
	## 构建游侠（敏16 感13 力11 体11 幸10 智9 意9；武器 3（游侠皮甲套）；
	## 命中 = 85%+感13调整值(+1)×2% = 87%；物穿 0（力 11 → +0））
	var unit := _MakeUnit(&"ranger", 0, pos)
	unit.class_id = &"cls_ranger"
	unit.attrs = {&"agility": 16, &"perception": 13, &"strength": 11,
			&"constitution": 11, &"luck": 10, &"intelligence": 9, &"willpower": 9}
	unit.weapon_bonus = 3
	unit.hit = DerivedStats.calc_hit(13, _cfg)
	unit.phys_pierce = DerivedStats.calc_phys_pierce(11, _cfg)
	return unit

func _MakeArcanist(pos: Vector2i) -> FakeUnit:
	## 构建奇术师（意16 感13 智11 敏10 力7 体9 幸9；武器 2（布甲套）；
	## 命中 87%（感 13 → +1）；法穿 3（意志特例——意 16 → +3））
	var unit := _MakeUnit(&"arcanist", 0, pos)
	unit.class_id = &"cls_arcanist"
	unit.attrs = {&"willpower": 16, &"perception": 13, &"intelligence": 11,
			&"agility": 10, &"strength": 7, &"constitution": 9, &"luck": 9}
	unit.weapon_bonus = 2
	unit.hit = DerivedStats.calc_hit(13, _cfg)
	unit.mag_pierce = 3
	return unit

func _MakeTrash(pos: Vector2i) -> FakeUnit:
	## 构建杂兵目标（案 17 §3.8：全属性 9 / 护甲 2 双轨 / 抗性 0 / 闪避 4%）
	var unit := _MakeUnit(&"rat", 1, pos)
	unit.attrs = {&"strength": 9, &"agility": 9, &"constitution": 9,
			&"intelligence": 9, &"perception": 9, &"willpower": 9, &"luck": 9}
	unit.weapon_bonus = 3
	unit.phys_armor = 2
	unit.mag_armor = 2
	unit.dodge = 0.04
	return unit

func _Ctx(forced: int = -1, forced_crit: int = -1) -> Dictionary:
	## 构建执行上下文
	## 参数 forced/forced_crit：命中/暴击强制口
	## 返回：ctx 字典
	return {
		&"grid": _grid,
		&"status_manager": _manager,
		&"cfg": _cfg,
		&"rng": _rng,
		&"forced": forced,
		&"forced_crit": forced_crit,
		&"status_lookup": _LookupStatus,
	}

# ====================================================================
# A. 数据↔文档一致性（案 17 §3.4 技能表逐格 + §3.11 #7 装备表 + 接线）
# ====================================================================

## 案 17 §3.4 技能参数表期望值（18 技全量；kinds = 效果结构（EffectKind 序列）；
## coef = -1.0 表示非伤害技不校验系数（damage_type = NONE 时系数不参与结算））。
## W5-7 登记注：蚀命诅咒（skl_arcanist_curse）的 attr_weights 为**异形映射**——
## damage_type NONE 伤害公式不消费权重，但表内保留 willpower 1.0 全额权重
## （文档口径标注换算源）；实际 DOT 换算走 dot.attr_id（=willpower）独立通路，
## 与 weights 字段非同一消费链——改表时勿按「非伤害技权重应为空」想当然清空
const DOC_SKILLS: Array[Dictionary] = [
	{ id = &"skl_atk_warrior", owner = &"cls_warrior", tier = 0,
			weights = {&"strength": 1.0}, coef = 1.0,
			res_kind = SkillDef.ResourceKind.NONE, res_cost = 0, range = 1,
			dmg = SkillDef.DamageType.PHYSICAL,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [] },
	{ id = &"skl_warrior_power_strike", owner = &"cls_warrior", tier = 1,
			weights = {&"strength": 0.6, &"constitution": 0.4}, coef = 1.3,
			res_kind = SkillDef.ResourceKind.STAMINA, res_cost = 8, range = 1,
			dmg = SkillDef.DamageType.PHYSICAL,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [] },
	{ id = &"skl_warrior_shield_wall", owner = &"cls_warrior", tier = 1,
			weights = {}, coef = -1.0,
			res_kind = SkillDef.ResourceKind.STAMINA, res_cost = 6, range = 0,
			dmg = SkillDef.DamageType.NONE,
			side = SkillDef.TargetSide.SELF, shape = SkillDef.TargetShape.SINGLE,
			kinds = [SkillEffect.EffectKind.STATUS_APPLY] },
	{ id = &"skl_atk_rogue", owner = &"cls_rogue", tier = 0,
			weights = {&"agility": 1.0}, coef = 1.0,
			res_kind = SkillDef.ResourceKind.NONE, res_cost = 0, range = 1,
			dmg = SkillDef.DamageType.PHYSICAL,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [] },
	{ id = &"skl_rogue_backstab", owner = &"cls_rogue", tier = 1,
			weights = {&"agility": 0.8, &"luck": 0.2}, coef = 1.6,
			res_kind = SkillDef.ResourceKind.STAMINA, res_cost = 10, range = 1,
			dmg = SkillDef.DamageType.PHYSICAL,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [SkillEffect.EffectKind.COMBAT_MOD] },
	{ id = &"skl_rogue_sprint", owner = &"cls_rogue", tier = 1,
			weights = {}, coef = -1.0,
			res_kind = SkillDef.ResourceKind.STAMINA, res_cost = 8, range = 0,
			dmg = SkillDef.DamageType.NONE,
			side = SkillDef.TargetSide.SELF, shape = SkillDef.TargetShape.SINGLE,
			kinds = [SkillEffect.EffectKind.STATUS_APPLY] },
	{ id = &"skl_atk_mage", owner = &"cls_mage", tier = 0,
			weights = {&"intelligence": 1.0}, coef = 1.0,
			res_kind = SkillDef.ResourceKind.NONE, res_cost = 0, range = 1,
			dmg = SkillDef.DamageType.MAGICAL,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [] },
	{ id = &"skl_mage_fireball", owner = &"cls_mage", tier = 1,
			weights = {&"intelligence": 1.0}, coef = 1.4,
			res_kind = SkillDef.ResourceKind.MANA, res_cost = 12, range = 5,
			dmg = SkillDef.DamageType.MAGICAL,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [] },
	{ id = &"skl_mage_frost_chain", owner = &"cls_mage", tier = 1,
			weights = {&"intelligence": 1.0}, coef = 0.6,
			res_kind = SkillDef.ResourceKind.MANA, res_cost = 10, range = 5,
			dmg = SkillDef.DamageType.MAGICAL,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [SkillEffect.EffectKind.STATUS_APPLY, SkillEffect.EffectKind.STATUS_APPLY] },
	{ id = &"skl_atk_priest", owner = &"cls_priest", tier = 0,
			weights = {&"perception": 1.0}, coef = 1.0,
			res_kind = SkillDef.ResourceKind.NONE, res_cost = 0, range = 1,
			dmg = SkillDef.DamageType.MAGICAL,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [] },
	{ id = &"skl_priest_smite", owner = &"cls_priest", tier = 1,
			weights = {&"perception": 1.0}, coef = 1.2,
			res_kind = SkillDef.ResourceKind.MANA, res_cost = 8, range = 5,
			dmg = SkillDef.DamageType.MAGICAL,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [SkillEffect.EffectKind.COMBAT_MOD] },
	{ id = &"skl_priest_heal", owner = &"cls_priest", tier = 1,
			weights = {}, coef = -1.0,
			res_kind = SkillDef.ResourceKind.MANA, res_cost = 10, range = 5,
			dmg = SkillDef.DamageType.NONE,
			side = SkillDef.TargetSide.ALLY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [SkillEffect.EffectKind.HEAL] },
	{ id = &"skl_atk_ranger", owner = &"cls_ranger", tier = 0,
			weights = {&"agility": 1.0}, coef = 1.0,
			res_kind = SkillDef.ResourceKind.NONE, res_cost = 0, range = 1,
			dmg = SkillDef.DamageType.PHYSICAL,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [] },
	{ id = &"skl_ranger_piercing_arrow", owner = &"cls_ranger", tier = 1,
			weights = {&"agility": 1.0}, coef = 1.3,
			res_kind = SkillDef.ResourceKind.STAMINA, res_cost = 8, range = 5,
			dmg = SkillDef.DamageType.PHYSICAL,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [] },
	{ id = &"skl_ranger_set_trap", owner = &"cls_ranger", tier = 1,
			weights = {}, coef = -1.0,
			res_kind = SkillDef.ResourceKind.STAMINA, res_cost = 8, range = 5,
			dmg = SkillDef.DamageType.NONE,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.CELL,
			kinds = [SkillEffect.EffectKind.TILE_SPAWN] },
	{ id = &"skl_atk_arcanist", owner = &"cls_arcanist", tier = 0,
			weights = {&"willpower": 1.0}, coef = 1.0,
			res_kind = SkillDef.ResourceKind.NONE, res_cost = 0, range = 1,
			dmg = SkillDef.DamageType.MAGICAL,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [] },
	{ id = &"skl_arcanist_curse", owner = &"cls_arcanist", tier = 1,
			weights = {&"willpower": 1.0}, coef = -1.0,
			res_kind = SkillDef.ResourceKind.MANA, res_cost = 8, range = 5,
			dmg = SkillDef.DamageType.NONE,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [SkillEffect.EffectKind.STATUS_APPLY] },
	{ id = &"skl_arcanist_bewitch", owner = &"cls_arcanist", tier = 1,
			weights = {}, coef = -1.0,
			res_kind = SkillDef.ResourceKind.MANA, res_cost = 10, range = 5,
			dmg = SkillDef.DamageType.NONE,
			side = SkillDef.TargetSide.ENEMY, shape = SkillDef.TargetShape.SINGLE,
			kinds = [SkillEffect.EffectKind.STATUS_APPLY] },
]

func test_doc_skill_fields_match_case17() -> void:
	## ④数据↔文档：18 技全量字段 vs 案 17 §3.4 表逐格核对（权重/系数/资源/
	## 射程/伤害类型/目标侧形/命中修正/效果结构）——字段漂移在此全量拦截
	for row: Dictionary in DOC_SKILLS:
		var skill: SkillDef = _LoadSkill(row.id)
		assert_that(skill != null) \
				.override_failure_message("%s 表缺失" % row.id).is_true()
		assert_str(String(skill.id)).is_equal(String(row.id))
		assert_str(String(skill.owner_id)).is_equal(String(row.owner))
		assert_int(skill.tier).override_failure_message("%s tier" % row.id) \
				.is_equal(row.tier)
		assert_int(skill.side).override_failure_message("%s side" % row.id) \
				.is_equal(SkillDef.SkillSide.ALLY)
		assert_int(skill.resource_type).override_failure_message("%s 资源类型" % row.id) \
				.is_equal(row.res_kind)
		assert_int(skill.resource_cost).override_failure_message("%s 资源消耗" % row.id) \
				.is_equal(row.res_cost)
		assert_int(skill.range).override_failure_message("%s 射程" % row.id) \
				.is_equal(row.range)
		assert_int(skill.damage_type).override_failure_message("%s 伤害类型" % row.id) \
				.is_equal(row.dmg)
		assert_int(skill.target_side).override_failure_message("%s 目标阵营" % row.id) \
				.is_equal(row.side)
		assert_int(skill.target_shape).override_failure_message("%s 目标形状" % row.id) \
				.is_equal(row.shape)
		assert_int(skill.hit_mod).override_failure_message("%s 命中修正" % row.id) \
				.is_equal(0)
		# 权重表逐键逐值（空表 = 无伤害权重）
		var weights: Dictionary = row.weights
		assert_int(skill.attr_weights.size()) \
				.override_failure_message("%s 权重键数" % row.id).is_equal(weights.size())
		for attr_id: StringName in weights:
			assert_float(float(skill.attr_weights.get(attr_id, -1.0))) \
					.override_failure_message("%s 权重 %s" % [row.id, attr_id]) \
					.is_equal_approx(float(weights[attr_id]), 0.0001)
		# 系数（非伤害技 -1.0 跳过——NONE 伤害无结算消费）
		if float(row.coef) >= 0.0:
			assert_float(skill.power_coefficient) \
					.override_failure_message("%s 系数" % row.id) \
					.is_equal_approx(float(row.coef), 0.0001)
		# 效果结构（EffectKind 序列）
		var kinds: Array = row.kinds
		assert_int(skill.effects.size()) \
				.override_failure_message("%s 效果数" % row.id).is_equal(kinds.size())
		for index: int in kinds.size():
			assert_int(skill.effects[index].effect_kind) \
					.override_failure_message("%s 效果[%d]类型" % [row.id, index]) \
					.is_equal(kinds[index])

func test_doc_equip_weapon_bonus_and_armor() -> void:
	## ④数据↔文档：§3.11 #7 初始装备（武器加值 §3.4 行 + 护甲重甲5/皮甲3/
	## 游侠皮甲2/布甲1）——六套全量
	var expected: Dictionary = {
		&"eqp_init_warrior": [4, 5],
		&"eqp_init_rogue": [3, 3],
		&"eqp_init_ranger": [3, 2],
		&"eqp_init_mage": [2, 1],
		&"eqp_init_priest": [2, 1],
		&"eqp_init_arcanist": [2, 1],
	}
	for equip_id: StringName in expected:
		var equip: EquipDef = load(EQUIP_DIR + String(equip_id) + ".tres") as EquipDef
		assert_that(equip != null).override_failure_message("%s 缺失" % equip_id).is_true()
		assert_int(equip.weapon_bonus).override_failure_message("%s 武器加值" % equip_id) \
				.is_equal(expected[equip_id][0])
		assert_int(equip.armor_value).override_failure_message("%s 护甲值" % equip_id) \
				.is_equal(expected[equip_id][1])

func test_class_base_attack_wiring() -> void:
	## ④接线：六职业 base_attack_skill_id ↔ skl_atk_* owner_id 双向一致
	## （普攻出生自带不占技能点——案 10 §2.5；资源换算源与普攻权重同列对齐 D3）
	var expected: Dictionary = {
		&"cls_warrior": &"skl_atk_warrior",
		&"cls_rogue": &"skl_atk_rogue",
		&"cls_mage": &"skl_atk_mage",
		&"cls_priest": &"skl_atk_priest",
		&"cls_ranger": &"skl_atk_ranger",
		&"cls_arcanist": &"skl_atk_arcanist",
	}
	for class_id: StringName in expected:
		var cls: ClassDef = load(CLASS_DIR + String(class_id) + ".tres") as ClassDef
		assert_str(String(cls.base_attack_skill_id)).is_equal(String(expected[class_id]))
		var atk: SkillDef = _LoadSkill(expected[class_id])
		assert_str(String(atk.owner_id)).is_equal(String(class_id))

func test_status_defs_match_case17() -> void:
	## ④状态定义↔案 17 §3.9/#6：职业技能引用的六个状态全量核对（修正值/
	## 默认持续/控制种类/DOT 参数）
	var root_def: StatusDef = _statuses[&"DEBUFF_root"] as StatusDef
	assert_int(root_def.category).is_equal(StatusDef.Category.CONTROL)
	assert_int(root_def.control_kind).is_equal(StatusDef.ControlKind.ROOT)
	assert_int(root_def.default_duration).is_equal(1)
	var slow_def: StatusDef = _statuses[&"DEBUFF_slow"] as StatusDef
	assert_float(slow_def.modifiers[&"move_range"]).is_equal_approx(-2.0, 0.0001)
	assert_int(slow_def.default_duration).is_equal(2)
	var curse_def: StatusDef = _statuses[&"DEBUFF_curse"] as StatusDef
	assert_int(curse_def.category).is_equal(StatusDef.Category.DOT)
	assert_int(curse_def.default_duration).is_equal(3)
	assert_int(curse_def.dot.mode).is_equal(DotParams.Mode.ATTR_RATIO)
	assert_str(String(curse_def.dot.attr_id)).is_equal("willpower")
	assert_float(curse_def.dot.ratio).is_equal_approx(0.5, 0.0001)
	var bewitch_def: StatusDef = _statuses[&"DEBUFF_bewitch"] as StatusDef
	assert_int(bewitch_def.category).is_equal(StatusDef.Category.CONTROL)
	assert_int(bewitch_def.control_kind).is_equal(StatusDef.ControlKind.BEWITCH)
	var wall_def: StatusDef = _statuses[&"BUFF_shield_wall"] as StatusDef
	assert_float(wall_def.modifiers[&"armor_physical"]).is_equal_approx(4.0, 0.0001)
	assert_int(wall_def.default_duration).is_equal(2)
	var sprint_def: StatusDef = _statuses[&"BUFF_sprint"] as StatusDef
	assert_float(sprint_def.modifiers[&"dodge"]).is_equal_approx(0.15, 0.0001)
	assert_float(sprint_def.modifiers[&"move_range"]).is_equal_approx(2.0, 0.0001)
	assert_int(sprint_def.default_duration).is_equal(0)

# ====================================================================
# B. 战士（挥击 / 痛击 / 盾墙）
# ====================================================================

func test_warrior_slash_damage_value() -> void:
	## ②挥击（普攻）：毛 =(力16×1.0+武器4)×1.0 = 20.0 → 物理轨
	## round(20×1)−max(0, 甲2−穿3) = 20；命中率 = 0.83−闪避0.04 = 0.79；
	## 普攻零资源消耗
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_atk_warrior"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_bool(result.hit).is_true()
	assert_float(result.hit_chance).is_equal_approx(0.79, 0.0001)
	assert_float(result.raw_damage).is_equal_approx(20.0, 0.01)
	assert_int(result.damage).is_equal(20)
	assert_int(rat.damage_taken.size()).is_equal(1)
	assert_int(rat.damage_taken[0]).is_equal(20)
	assert_int(warrior.resource_stamina).is_equal(100)

func test_warrior_slash_trigger_guards() -> void:
	## ①挥击触发件：距 2 超射程/空格/己方/倒地敌 → 拒绝且零消耗
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var far := _MakeTrash(Vector2i(3, 4))
	var out_range: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_atk_warrior"), far.grid_pos, _Ctx(1, 0))
	assert_bool(out_range.success).is_false()
	assert_str(String(out_range.error)).is_equal("out_of_range")
	var empty_cell: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_atk_warrior"), Vector2i(4, 6), _Ctx(1, 0))
	assert_str(String(empty_cell.error)).is_equal("invalid_target")
	var ally := _MakeUnit(&"ally", 0, Vector2i(3, 5))
	var on_ally: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_atk_warrior"), ally.grid_pos, _Ctx(1, 0))
	assert_str(String(on_ally.error)).is_equal("invalid_target")
	ally.alive = false
	var on_downed: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_atk_warrior"), ally.grid_pos, _Ctx(1, 0))
	assert_str(String(on_downed.error)).is_equal("invalid_target")
	assert_int(warrior.resource_stamina).is_equal(100)

func test_warrior_power_strike_damage_and_resource() -> void:
	## ②痛击：毛 =(0.6×16+0.4×14+4)×1.3 = 24.96 → 物理轨 round(24.96)−0 = 25；
	## 精力 100−8 = 92；①精力不足（7 < 8）→ no_resource 且不扣
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_float(result.raw_damage).is_equal_approx(24.96, 0.01)
	assert_int(result.damage).is_equal(25)
	assert_float(result.hit_chance).is_equal_approx(0.79, 0.0001)
	assert_int(warrior.resource_stamina).is_equal(92)
	warrior.resource_stamina = 7
	var short: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(short.success).is_false()
	assert_str(String(short.error)).is_equal("no_resource")
	assert_int(warrior.resource_stamina).is_equal(7)

func test_warrior_power_strike_crit_value() -> void:
	## ②痛击暴击：减免后 25 ×1.5 = 37.5 → round 38；暴击率 = 5%（幸10/敏10 均 +0）
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), rat.grid_pos, _Ctx(1, 1))
	assert_bool(result.crit).is_true()
	assert_float(float(result.trace[&"damage_chain"][&"crit_chance"])) \
			.is_equal_approx(0.05, 0.0001)
	assert_int(result.damage).is_equal(38)

func test_warrior_shield_wall_buff_and_lifecycle() -> void:
	## ③盾墙：SELF 免判定直施加（持续 2 回合锚点：施加回合末不递减，经 2 个
	## 递减周期）；修正入派生——真实 BattleUnit 物理护甲 7（装备5+体14调整2）
	## → 11（+4），法术轨不受影响（5+感9调整−1 = 4）；精力 100−6 = 94；
	## ①距 2 超射程（effective_range 1）/精力不足拒绝
	var warrior := BattleUnit.new()
	warrior.unit_id = &"warrior_real"
	warrior.side = 0
	warrior.class_id = &"cls_warrior"
	warrior.attrs = {&"strength": 16, &"constitution": 14, &"agility": 10,
			&"perception": 9, &"intelligence": 7, &"luck": 10, &"willpower": 9}
	warrior.weapon_bonus = 4
	warrior.armor_equip = 5
	warrior.max_stamina = 100
	warrior.current_stamina = 100
	warrior.grid_pos = Vector2i(3, 6)
	_grid.place_unit(Vector2i(3, 6), warrior)
	warrior.bind_battle(_cfg, _manager)
	assert_int(warrior.phys_armor).is_equal(7)
	assert_int(warrior.mag_armor).is_equal(4)
	var result: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_shield_wall"), warrior.grid_pos, _Ctx(1, 1))
	assert_bool(result.success).is_true()
	assert_int(result.applied_statuses.size()).is_equal(1)
	assert_str(String(result.applied_statuses[0])).is_equal("warrior_real|BUFF_shield_wall")
	assert_int(warrior.current_stamina).is_equal(94)
	assert_int(warrior.phys_armor).is_equal(11)
	assert_int(warrior.mag_armor).is_equal(4)
	# 生命周期：回合末 1（施加回合不递减）/2（remaining 1）/3（归零移除）
	_manager.end_of_round_tick(1, [warrior], _rng)
	assert_int(warrior.phys_armor).is_equal(11)
	_manager.end_of_round_tick(2, [warrior], _rng)
	assert_int(warrior.phys_armor).is_equal(11)
	_manager.end_of_round_tick(3, [warrior], _rng)
	assert_int(warrior.phys_armor).is_equal(7)
	# 触发件：距 2 超射程 / 精力不足
	var too_far: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_shield_wall"), Vector2i(3, 4), _Ctx(1, 1))
	assert_bool(too_far.success).is_false()
	assert_str(String(too_far.error)).is_equal("out_of_range")
	warrior.current_stamina = 5
	var short: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_shield_wall"), warrior.grid_pos, _Ctx(1, 1))
	assert_bool(short.success).is_false()
	assert_str(String(short.error)).is_equal("no_resource")
	assert_int(warrior.current_stamina).is_equal(5)

# ====================================================================
# C. 盗贼（突刺 / 背刺 / 疾步）
# ====================================================================

func test_rogue_thrust_damage_value() -> void:
	## ②突刺（普攻）：毛 =(敏16×1.0+武器3)×1.0 = 19.0 → 物理轨
	## round(19)−max(0, 甲2−穿0) = 17；命中率 = 0.85−0.04 = 0.81
	var rogue := _MakeRogue(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(rogue,
			_LoadSkill(&"skl_atk_rogue"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_float(result.hit_chance).is_equal_approx(0.81, 0.0001)
	assert_float(result.raw_damage).is_equal_approx(19.0, 0.01)
	assert_int(result.damage).is_equal(17)
	assert_int(rogue.resource_stamina).is_equal(100)

func test_rogue_backstab_damage_and_crit_bonus() -> void:
	## ②背刺：毛 =(0.8×16+0.2×13+3)×1.6 = 29.44 → 物理轨 round(29.44)−2 = 27；
	## ③暴击加成 +10%：暴击率 = 5%+幸13调整1×2%+敏16调整3×1%+10% = 20%；
	## 暴击 = round(27×1.5) = 41；精力 100−10 = 90；①精力不足拒绝
	var rogue := _MakeRogue(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(rogue,
			_LoadSkill(&"skl_rogue_backstab"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_float(result.raw_damage).is_equal_approx(29.44, 0.01)
	assert_int(result.damage).is_equal(27)
	assert_float(float(result.trace[&"damage_chain"][&"crit_chance"])) \
			.is_equal_approx(0.20, 0.0001)
	assert_int(rogue.resource_stamina).is_equal(90)
	var crit_result: SkillExecutor.ExecutionResult = _executor.execute(rogue,
			_LoadSkill(&"skl_rogue_backstab"), rat.grid_pos, _Ctx(1, 1))
	assert_bool(crit_result.crit).is_true()
	assert_int(crit_result.damage).is_equal(41)
	rogue.resource_stamina = 9
	var short: SkillExecutor.ExecutionResult = _executor.execute(rogue,
			_LoadSkill(&"skl_rogue_backstab"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(short.success).is_false()
	assert_str(String(short.error)).is_equal("no_resource")
	assert_int(rogue.resource_stamina).is_equal(9)

func test_rogue_sprint_effect_and_lifecycle() -> void:
	## ③疾步：SELF 即时增益（duration 0 当回合末移除）——真实 BattleUnit
	## 移动力 = min(6, 5+敏16加成1)+2 = 8；闪避 = 5%+3×2%+15% = 26%；
	## 精力 100−8 = 92；回合末移除后移动力 6 / 闪避 11%
	var rogue := BattleUnit.new()
	rogue.unit_id = &"rogue_real"
	rogue.side = 0
	rogue.class_id = &"cls_rogue"
	rogue.attrs = {&"agility": 16, &"luck": 13, &"strength": 10, &"constitution": 10,
			&"perception": 11, &"intelligence": 9, &"willpower": 10}
	rogue.weapon_bonus = 3
	rogue.armor_equip = 3
	rogue.base_move_range = 5
	rogue.max_stamina = 100
	rogue.current_stamina = 100
	rogue.grid_pos = Vector2i(3, 6)
	_grid.place_unit(Vector2i(3, 6), rogue)
	rogue.bind_battle(_cfg, _manager)
	assert_int(rogue.move_final()).is_equal(6)
	assert_float(rogue.dodge).is_equal_approx(0.11, 0.0001)
	var result: SkillExecutor.ExecutionResult = _executor.execute(rogue,
			_LoadSkill(&"skl_rogue_sprint"), rogue.grid_pos, _Ctx(1, 1))
	assert_bool(result.success).is_true()
	assert_int(result.applied_statuses.size()).is_equal(1)
	assert_int(rogue.current_stamina).is_equal(92)
	assert_int(rogue.move_final()).is_equal(8)
	assert_float(rogue.dodge).is_equal_approx(0.26, 0.0001)
	# 即时类：当回合末移除（duration_zero 非站位类）
	_manager.end_of_round_tick(1, [rogue], _rng)
	assert_int(_manager.get_statuses(rogue).size()).is_equal(0)
	assert_int(rogue.move_final()).is_equal(6)
	assert_float(rogue.dodge).is_equal_approx(0.11, 0.0001)
	# 精力不足拒绝
	rogue.current_stamina = 7
	var short: SkillExecutor.ExecutionResult = _executor.execute(rogue,
			_LoadSkill(&"skl_rogue_sprint"), rogue.grid_pos, _Ctx(1, 1))
	assert_bool(short.success).is_false()
	assert_str(String(short.error)).is_equal("no_resource")

# ====================================================================
# D. 法师（魔弹 / 火球术 / 寒冰锁链）
# ====================================================================

func test_mage_bolt_damage_value() -> void:
	## ②魔弹（普攻）：毛 =(智16×1.0+武器2)×1.0 = 18.0 → 法术轨
	## round(18)−max(0, 甲2−法穿3) = 18；命中率 = 0.85−0.04 = 0.81
	var mage := _MakeMage(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(mage,
			_LoadSkill(&"skl_atk_mage"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_float(result.hit_chance).is_equal_approx(0.81, 0.0001)
	assert_float(result.raw_damage).is_equal_approx(18.0, 0.01)
	assert_int(result.damage).is_equal(18)

func test_damage_track_routing_physical_vs_magical() -> void:
	## ②减免轨选对（伤害类型路由）：同一目标（物甲 6/法甲 1/法抗 30%）——
	## 挥击走物理轨 round(20×1)−max(0, 6−物穿3) = 17；魔弹走法术轨
	## round(18×0.7)−max(0, 1−法穿3) = 13；trace 的 resist/armor/pierce 按轨取值
	var target := _MakeTrash(Vector2i(3, 5))
	target.phys_armor = 6
	target.mag_armor = 1
	target.mag_resist = 0.3
	var warrior := _MakeWarrior(Vector2i(3, 6))
	var phys: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_atk_warrior"), target.grid_pos, _Ctx(1, 0))
	assert_int(phys.damage).is_equal(17)
	assert_int(int(phys.trace[&"damage_chain"][&"armor"])).is_equal(6)
	assert_int(int(phys.trace[&"damage_chain"][&"pierce"])).is_equal(3)
	assert_float(float(phys.trace[&"damage_chain"][&"resist"])) \
			.is_equal_approx(0.0, 0.0001)
	var mage := _MakeMage(Vector2i(3, 4))
	var magic: SkillExecutor.ExecutionResult = _executor.execute(mage,
			_LoadSkill(&"skl_atk_mage"), target.grid_pos, _Ctx(1, 0))
	assert_int(magic.damage).is_equal(13)
	assert_int(int(magic.trace[&"damage_chain"][&"armor"])).is_equal(1)
	assert_int(int(magic.trace[&"damage_chain"][&"pierce"])).is_equal(3)
	assert_float(float(magic.trace[&"damage_chain"][&"resist"])) \
			.is_equal_approx(0.3, 0.0001)

func test_mage_fireball_damage_range_and_los() -> void:
	## ②火球：毛 =(16×1.0+2)×1.4 = 25.2 → 法术轨 round(25.2)−0 = 25；
	## 法力 100−12 = 88；①射程 5 内成功/距 6 超射程/障碍阻断 LOS；
	## 法力不足拒绝
	var mage := _MakeMage(Vector2i(0, 0))
	var rat := _MakeTrash(Vector2i(5, 0))
	var result: SkillExecutor.ExecutionResult = _executor.execute(mage,
			_LoadSkill(&"skl_mage_fireball"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_float(result.raw_damage).is_equal_approx(25.2, 0.01)
	assert_int(result.damage).is_equal(25)
	assert_float(result.hit_chance).is_equal_approx(0.81, 0.0001)
	assert_int(mage.resource_mana).is_equal(88)
	var far := _MakeTrash(Vector2i(6, 0))
	var out_range: SkillExecutor.ExecutionResult = _executor.execute(mage,
			_LoadSkill(&"skl_mage_fireball"), far.grid_pos, _Ctx(1, 0))
	assert_bool(out_range.success).is_false()
	assert_str(String(out_range.error)).is_equal("out_of_range")
	assert_int(mage.resource_mana).is_equal(88)
	mage.resource_mana = 11
	var short: SkillExecutor.ExecutionResult = _executor.execute(mage,
			_LoadSkill(&"skl_mage_fireball"), rat.grid_pos, _Ctx(1, 0))
	assert_str(String(short.error)).is_equal("no_resource")

func test_mage_frost_chain_damage_and_statuses() -> void:
	## ②③寒冰锁链：毛 =(16+2)×0.6 = 10.8 → 法术轨 round = 11；法力 −10；
	## 命中后附加定身 1 回合 + 减速 2 回合（两段判定 forced=1 全过）；
	## 定身未行动锁本回合（on_unit_turn_locked）；减速修正移动力 −2
	var mage := _MakeMage(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(mage,
			_LoadSkill(&"skl_mage_frost_chain"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_float(result.raw_damage).is_equal_approx(10.8, 0.01)
	assert_int(result.damage).is_equal(11)
	assert_int(result.applied_statuses.size()).is_equal(2)
	assert_int(mage.resource_mana).is_equal(90)
	var root_found: bool = false
	var slow_found: bool = false
	for instance: StatusInstance in _manager.get_statuses(rat):
		if instance.status_id == &"DEBUFF_root":
			root_found = true
			assert_int(instance.remaining).is_equal(1)
		if instance.status_id == &"DEBUFF_slow":
			slow_found = true
			assert_int(instance.remaining).is_equal(2)
	assert_bool(root_found).is_true()
	assert_bool(slow_found).is_true()
	assert_bool(_manager.on_unit_turn_locked(rat)).is_true()
	assert_int(_manager.get_active_control(rat)).is_equal(StatusDef.ControlKind.ROOT)
	assert_float(_manager.get_stat_mod(rat, ModKeys.MOVE_RANGE)) \
			.is_equal_approx(-2.0, 0.0001)

func test_mage_frost_chain_miss_consumes() -> void:
	## ①③未中链：命中掷败（forced=0）→ 零伤害零施加、法力照扣不返还
	var mage := _MakeMage(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(mage,
			_LoadSkill(&"skl_mage_frost_chain"), rat.grid_pos, _Ctx(0, 0))
	assert_bool(result.success).is_true()
	assert_bool(result.hit).is_false()
	assert_int(result.damage).is_equal(0)
	assert_int(result.applied_statuses.size()).is_equal(0)
	assert_int(rat.damage_taken.size()).is_equal(0)
	assert_int(mage.resource_mana).is_equal(90)

# ====================================================================
# E. 牧师（圣击 / 圣光惩击 / 治愈术）
# ====================================================================

func test_priest_holy_attack_damage_value() -> void:
	## ②圣击（普攻）：毛 =(感15×1.0+武器2)×1.0 = 17.0 → 法术轨
	## round(17)−max(0, 甲2−法穿0) = 15；命中率 = 0.89−0.04 = 0.85
	var priest := _MakePriest(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(priest,
			_LoadSkill(&"skl_atk_priest"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_float(result.hit_chance).is_equal_approx(0.85, 0.0001)
	assert_float(result.raw_damage).is_equal_approx(17.0, 0.01)
	assert_int(result.damage).is_equal(15)

func test_priest_smite_normal_and_undead() -> void:
	## ②③圣光惩击：普通目标毛 =(15+2)×1.2 = 20.4 → 法术轨 round−2 = 18；
	## 亡灵目标 COMBAT_MOD 种族乘算 ×1.5 → 30.6 → round(30.6)−2 = 29；
	## 法力 100−8 = 92；非亡灵不触发（race_mult = 1.0）
	var priest := _MakePriest(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(priest,
			_LoadSkill(&"skl_priest_smite"), rat.grid_pos, _Ctx(1, 0))
	assert_float(result.raw_damage).is_equal_approx(20.4, 0.01)
	assert_int(result.damage).is_equal(18)
	assert_float(float(result.trace[&"damage_chain"][&"race_mult"])) \
			.is_equal_approx(1.0, 0.0001)
	assert_int(priest.resource_mana).is_equal(92)
	var undead := _MakeTrash(Vector2i(4, 5))
	undead.race_tag = &"undead"
	var undead_result: SkillExecutor.ExecutionResult = _executor.execute(priest,
			_LoadSkill(&"skl_priest_smite"), undead.grid_pos, _Ctx(1, 0))
	assert_float(undead_result.raw_damage).is_equal_approx(30.6, 0.01)
	assert_int(undead_result.damage).is_equal(29)
	assert_float(float(undead_result.trace[&"damage_chain"][&"race_mult"])) \
			.is_equal_approx(1.5, 0.0001)

func test_priest_heal_amount_and_guards() -> void:
	## ②治愈术：治疗 = round(感15×1.5+10) = 33，免命中免判定；
	## 法力 100−10 = 90；①目标合法域：仅己方未倒地（敌方/空格/倒地分码）；
	## 射程 5 边界；法力不足拒绝
	var priest := _MakePriest(Vector2i(0, 0))
	var ally := _MakeUnit(&"ally", 0, Vector2i(5, 0))
	ally.hp = 40
	var result: SkillExecutor.ExecutionResult = _executor.execute(priest,
			_LoadSkill(&"skl_priest_heal"), ally.grid_pos, _Ctx(1, 1))
	assert_bool(result.success).is_true()
	assert_bool(result.hit).is_false()
	assert_int(result.heal).is_equal(33)
	assert_int(ally.healed_amount).is_equal(33)
	assert_int(ally.hp).is_equal(73)
	assert_int(priest.resource_mana).is_equal(90)
	# 敌方目标 → invalid_target（阵营校验镜像）
	var rat := _MakeTrash(Vector2i(1, 0))
	var on_enemy: SkillExecutor.ExecutionResult = _executor.execute(priest,
			_LoadSkill(&"skl_priest_heal"), rat.grid_pos, _Ctx(1, 1))
	assert_str(String(on_enemy.error)).is_equal("invalid_target")
	# 空格 → invalid_target
	var on_empty: SkillExecutor.ExecutionResult = _executor.execute(priest,
			_LoadSkill(&"skl_priest_heal"), Vector2i(2, 0), _Ctx(1, 1))
	assert_str(String(on_empty.error)).is_equal("invalid_target")
	# 倒地 → target_downed
	ally.alive = false
	var on_downed: SkillExecutor.ExecutionResult = _executor.execute(priest,
			_LoadSkill(&"skl_priest_heal"), ally.grid_pos, _Ctx(1, 1))
	assert_str(String(on_downed.error)).is_equal("target_downed")
	# 距 6 超射程
	ally.alive = true
	var far_ally := _MakeUnit(&"far_ally", 0, Vector2i(6, 0))
	var out_range: SkillExecutor.ExecutionResult = _executor.execute(priest,
			_LoadSkill(&"skl_priest_heal"), far_ally.grid_pos, _Ctx(1, 1))
	assert_str(String(out_range.error)).is_equal("out_of_range")
	# 法力不足
	priest.resource_mana = 9
	var short: SkillExecutor.ExecutionResult = _executor.execute(priest,
			_LoadSkill(&"skl_priest_heal"), ally.grid_pos, _Ctx(1, 1))
	assert_str(String(short.error)).is_equal("no_resource")
	assert_int(priest.resource_mana).is_equal(9)

# ====================================================================
# F. 游侠（射击 / 穿云箭 / 布置陷阱）
# ====================================================================

func test_ranger_shoot_damage_value() -> void:
	## ②射击（普攻）：毛 =(敏16×1.0+武器3)×1.0 = 19.0 → 物理轨 round−2 = 17；
	## 命中率 = 0.87−0.04 = 0.83
	var ranger := _MakeRanger(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(ranger,
			_LoadSkill(&"skl_atk_ranger"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_float(result.hit_chance).is_equal_approx(0.83, 0.0001)
	assert_float(result.raw_damage).is_equal_approx(19.0, 0.01)
	assert_int(result.damage).is_equal(17)

func test_ranger_piercing_arrow_damage_range_and_los() -> void:
	## ②穿云箭：毛 =(16×1.0+3)×1.3 = 24.7 → 物理轨 round(24.7)−2 = 23；
	## 精力 100−8 = 92；①射程 5 边界/LOS 阻断/精力不足
	var ranger := _MakeRanger(Vector2i(0, 0))
	var rat := _MakeTrash(Vector2i(5, 0))
	var result: SkillExecutor.ExecutionResult = _executor.execute(ranger,
			_LoadSkill(&"skl_ranger_piercing_arrow"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_float(result.raw_damage).is_equal_approx(24.7, 0.01)
	assert_int(result.damage).is_equal(23)
	assert_int(ranger.resource_stamina).is_equal(92)
	var far := _MakeTrash(Vector2i(6, 0))
	var out_range: SkillExecutor.ExecutionResult = _executor.execute(ranger,
			_LoadSkill(&"skl_ranger_piercing_arrow"), far.grid_pos, _Ctx(1, 0))
	assert_str(String(out_range.error)).is_equal("out_of_range")
	assert_int(ranger.resource_stamina).is_equal(92)
	ranger.resource_stamina = 7
	var short: SkillExecutor.ExecutionResult = _executor.execute(ranger,
			_LoadSkill(&"skl_ranger_piercing_arrow"), rat.grid_pos, _Ctx(1, 0))
	assert_str(String(short.error)).is_equal("no_resource")

func test_ranger_set_trap_presolve_and_guards() -> void:
	## ③布置陷阱：预结算 = round(敏16×1.0) = 16（施放时定格，D7 免判定免减免）；
	## 动态地格落格 tile_trap + 伤害 + 施放者；精力 100−8 = 92；
	## ①射程 5 边界/状态格禁布（R1-7 草丛）/占位格拒绝（S3-09）/
	## 同格唯一（R2-5）/精力不足
	var ranger := _MakeRanger(Vector2i(0, 0))
	var result: SkillExecutor.ExecutionResult = _executor.execute(ranger,
			_LoadSkill(&"skl_ranger_set_trap"), Vector2i(5, 0), _Ctx(1, 1))
	assert_bool(result.success).is_true()
	assert_int(result.spawned_tile_damage).is_equal(16)
	assert_int(ranger.resource_stamina).is_equal(92)
	var trap_data: Dictionary = _grid.dynamic_tile_at(Vector2i(5, 0))
	assert_str(String(trap_data[&"tile_id"])).is_equal("tile_trap")
	assert_int(int(trap_data[&"damage"])).is_equal(16)
	assert_str(String(trap_data[&"source_id"])).is_equal("ranger")
	# 陷阱地格定义：一次性敌方踏入触发（触发链消费口径——运行时链在
	# test_battle_flow.test_trap_triggers_on_enemy_enter 覆盖）
	var trap_tile: TileTypeDef = _tiles[&"tile_trap"] as TileTypeDef
	assert_int(trap_tile.trigger).is_equal(TileTypeDef.Trigger.ENEMY_ENTER_ONCE)
	# 距 6 超射程
	var out_range: SkillExecutor.ExecutionResult = _executor.execute(ranger,
			_LoadSkill(&"skl_ranger_set_trap"), Vector2i(6, 0), _Ctx(1, 1))
	assert_str(String(out_range.error)).is_equal("out_of_range")
	# 后续边界用例换位 (4,1)：草丛 (5,2) 距 2 在射程内（LOS 经 (5,1) 无阻挡）
	ranger.grid_pos = Vector2i(4, 1)
	# 状态格禁布（(5,2) 为草丛）
	var on_grass: SkillExecutor.ExecutionResult = _executor.execute(ranger,
			_LoadSkill(&"skl_ranger_set_trap"), Vector2i(5, 2), _Ctx(1, 1))
	assert_str(String(on_grass.error)).is_equal("blocked_cell")
	# 存活单位占位格拒绝
	var rat := _MakeTrash(Vector2i(4, 0))
	var on_unit: SkillExecutor.ExecutionResult = _executor.execute(ranger,
			_LoadSkill(&"skl_ranger_set_trap"), rat.grid_pos, _Ctx(1, 1))
	assert_str(String(on_unit.error)).is_equal("blocked_cell")
	# 同格唯一（已有动态地格拒绝、资源不扣）
	var same_cell: SkillExecutor.ExecutionResult = _executor.execute(ranger,
			_LoadSkill(&"skl_ranger_set_trap"), Vector2i(5, 0), _Ctx(1, 1))
	assert_str(String(same_cell.error)).is_equal("blocked_cell")
	assert_int(ranger.resource_stamina).is_equal(92)
	# 精力不足
	ranger.resource_stamina = 7
	var short: SkillExecutor.ExecutionResult = _executor.execute(ranger,
			_LoadSkill(&"skl_ranger_set_trap"), Vector2i(1, 0), _Ctx(1, 1))
	assert_str(String(short.error)).is_equal("no_resource")

# ====================================================================
# G. 奇术师（咒击 / 蚀命诅咒 / 蛊惑）
# ====================================================================

func test_arcanist_hex_damage_value() -> void:
	## ②咒击（普攻）：毛 =(意16×1.0+武器2)×1.0 = 18.0 → 法术轨
	## round−max(0, 甲2−法穿3) = 18；命中率 = 0.87−0.04 = 0.83
	var arcanist := _MakeArcanist(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(arcanist,
			_LoadSkill(&"skl_atk_arcanist"), rat.grid_pos, _Ctx(1, 0))
	assert_bool(result.success).is_true()
	assert_float(result.hit_chance).is_equal_approx(0.83, 0.0001)
	assert_float(result.raw_damage).is_equal_approx(18.0, 0.01)
	assert_int(result.damage).is_equal(18)

func test_arcanist_curse_apply_and_dot_ticks() -> void:
	## ③蚀命诅咒：无伤害段（damage_type NONE → result.damage 0）；
	## 两段判定过（forced=1）施加 DEBUFF_curse 3 回合，DOT 施方快照 = 意志16；
	## 跳伤 = round(16×0.5) = 8/跳 ×3 跳 = 24（案 17 §3.4「意志16→8/跳×3 跳」）；
	## 施加回合末不跳（first_tick = 施加回合+1）；法力 100−8 = 92
	var arcanist := _MakeArcanist(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(arcanist,
			_LoadSkill(&"skl_arcanist_curse"), rat.grid_pos, _Ctx(1, -1))
	assert_bool(result.success).is_true()
	assert_int(result.damage).is_equal(0)
	assert_int(result.applied_statuses.size()).is_equal(1)
	assert_int(arcanist.resource_mana).is_equal(92)
	var instances: Array[StatusInstance] = _manager.get_statuses(rat)
	assert_int(instances.size()).is_equal(1)
	assert_str(String(instances[0].status_id)).is_equal("DEBUFF_curse")
	assert_int(instances[0].remaining).is_equal(3)
	assert_float(instances[0].dot_source_snapshot).is_equal_approx(16.0, 0.0001)
	# 回合末序列：R1 施加回合不跳 → R2/R3/R4 各跳 8 → R4 末状态归零移除
	var round1: Array = _manager.end_of_round_tick(1, [rat], _rng)
	assert_int(round1.size()).is_equal(0)
	var round2: Array = _manager.end_of_round_tick(2, [rat], _rng)
	assert_int(round2.size()).is_equal(1)
	assert_int(int(round2[0][&"damage"])).is_equal(8)
	var round3: Array = _manager.end_of_round_tick(3, [rat], _rng)
	assert_int(int(round3[0][&"damage"])).is_equal(8)
	var round4: Array = _manager.end_of_round_tick(4, [rat], _rng)
	assert_int(int(round4[0][&"damage"])).is_equal(8)
	assert_int(_manager.get_statuses(rat).size()).is_equal(0)
	assert_int(rat.damage_taken.size()).is_equal(3)
	assert_int(rat.hp).is_equal(100 - 24)

func test_arcanist_curse_snapshot_refresh() -> void:
	## ③DOT 快照刷新（17-C24：快照定格于施加时、随重施加刷新）：
	## 首施加意志 16（快照 16）→ 意志改 20 后重施加（同名取大重起算）→
	## 快照 20，后续跳伤 round(20×0.5) = 10
	var arcanist := _MakeArcanist(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	_executor.execute(arcanist, _LoadSkill(&"skl_arcanist_curse"),
			rat.grid_pos, _Ctx(1, -1))
	arcanist.attrs[&"willpower"] = 20
	var refresh: SkillExecutor.ExecutionResult = _executor.execute(arcanist,
			_LoadSkill(&"skl_arcanist_curse"), rat.grid_pos, _Ctx(1, -1))
	assert_int(refresh.applied_statuses.size()).is_equal(1)
	assert_int(arcanist.resource_mana).is_equal(84)
	var instances: Array[StatusInstance] = _manager.get_statuses(rat)
	assert_int(instances.size()).is_equal(1)
	assert_float(instances[0].dot_source_snapshot).is_equal_approx(20.0, 0.0001)
	_manager.end_of_round_tick(1, [rat], _rng)
	var round2: Array = _manager.end_of_round_tick(2, [rat], _rng)
	assert_int(int(round2[0][&"damage"])).is_equal(10)

func test_arcanist_curse_miss_and_resist() -> void:
	## ①③两段判定失败路径：命中掷败（forced=0）→ miss、法力照扣零施加；
	## 抗性掷败（种子探针构造：命中掷过 + 抗性掷败）→ resisted、法力照扣
	var arcanist := _MakeArcanist(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var miss: SkillExecutor.ExecutionResult = _executor.execute(arcanist,
			_LoadSkill(&"skl_arcanist_curse"), rat.grid_pos, _Ctx(0, -1))
	assert_bool(miss.success).is_true()
	assert_int(miss.applied_statuses.size()).is_equal(0)
	assert_str(String(_manager.last_reject_reason())).is_equal("miss")
	assert_int(arcanist.resource_mana).is_equal(92)
	assert_int(_manager.get_statuses(rat).size()).is_equal(0)
	# 抗性掷独立第二段：固定种子探针先取两次 randf 序列值，反推
	# 命中率（首掷必过）与抗性（次掷必败）——保持掷链真实随机路径
	const PROBE_SEED: int = 926
	var probe := RandomNumberGenerator.new()
	probe.seed = PROBE_SEED
	var roll_hit: float = probe.randf()
	var roll_resist: float = probe.randf()
	var caster_two := _MakeArcanist(Vector2i(4, 6))
	caster_two.hit = clampf(roll_hit + 0.02, 0.06, 0.95)
	var rat_two := _MakeTrash(Vector2i(4, 5))
	rat_two.dodge = 0.0
	rat_two.status_resist = 1.0 - roll_resist * 0.5
	_rng.seed = PROBE_SEED
	var resisted: SkillExecutor.ExecutionResult = _executor.execute(caster_two,
			_LoadSkill(&"skl_arcanist_curse"), rat_two.grid_pos, _Ctx(-1, -1))
	assert_bool(resisted.success).is_true()
	assert_int(resisted.applied_statuses.size()).is_equal(0)
	assert_str(String(_manager.last_reject_reason())).is_equal("resisted")
	assert_int(caster_two.resource_mana).is_equal(92)

func test_arcanist_bewitch_control_window() -> void:
	## ③蛊惑：P3 固定下回合——施加回合不锁（from_next_turn_only），
	## 回合末清标记后下回合锁定（BEWITCH 控制种类）→ 行动轮结束解锁；
	## 持续 1 回合（R2 末移除）；法力 100−10 = 90；
	## ①命中掷败 → 零施加、法力照扣
	var arcanist := _MakeArcanist(Vector2i(3, 6))
	var rat := _MakeTrash(Vector2i(3, 5))
	var result: SkillExecutor.ExecutionResult = _executor.execute(arcanist,
			_LoadSkill(&"skl_arcanist_bewitch"), rat.grid_pos, _Ctx(1, -1))
	assert_bool(result.success).is_true()
	assert_int(result.damage).is_equal(0)
	assert_int(result.applied_statuses.size()).is_equal(1)
	assert_int(arcanist.resource_mana).is_equal(90)
	var instances: Array[StatusInstance] = _manager.get_statuses(rat)
	assert_str(String(instances[0].status_id)).is_equal("DEBUFF_bewitch")
	assert_int(instances[0].remaining).is_equal(1)
	assert_int(instances[0].control_locks).is_equal(1)
	# P3：施加回合不锁（即使目标未行动）
	assert_bool(_manager.on_unit_turn_locked(rat)).is_false()
	assert_int(_manager.get_active_control(rat)).is_equal(StatusDef.ControlKind.NONE)
	# 回合末清跳过标记 → 下回合起锁定
	_manager.end_of_round_tick(1, [rat], _rng)
	assert_bool(_manager.on_unit_turn_locked(rat)).is_true()
	assert_int(_manager.get_active_control(rat)).is_equal(StatusDef.ControlKind.BEWITCH)
	# 行动轮结束：锁递减归零
	_manager.on_unit_turn_finished(rat)
	assert_bool(_manager.on_unit_turn_locked(rat)).is_false()
	# 持续 1 回合：R2 末移除
	_manager.end_of_round_tick(2, [rat], _rng)
	assert_int(_manager.get_statuses(rat).size()).is_equal(0)
	# 命中掷败路径
	var miss: SkillExecutor.ExecutionResult = _executor.execute(arcanist,
			_LoadSkill(&"skl_arcanist_bewitch"), rat.grid_pos, _Ctx(0, -1))
	assert_int(miss.applied_statuses.size()).is_equal(0)
	assert_int(arcanist.resource_mana).is_equal(80)

# ====================================================================
# H. 横切触发件（远程 LOS 表 / 近战射程表 / 施放者倒地）
# ====================================================================

func test_ranged_skills_los_blocked_table() -> void:
	## ①远程技 LOS 表（射程 >1 需视线）：(0,2)→(5,2) 被 (2,2) 障碍阻断——
	## 8 远程技（火球/寒冰锁链/惩击/治愈术/穿云箭/陷阱/诅咒/蛊惑）全量
	## 拒绝码 no_line_of_sight（LOS 先于目标/地格校验）
	var ranged_ids: Array[StringName] = [&"skl_mage_fireball", &"skl_mage_frost_chain",
			&"skl_priest_smite", &"skl_priest_heal", &"skl_ranger_piercing_arrow",
			&"skl_ranger_set_trap", &"skl_arcanist_curse", &"skl_arcanist_bewitch"]
	for skill_id: StringName in ranged_ids:
		var caster := _MakeUnit(skill_id, 0, Vector2i(0, 2))
		caster.hit = 0.85
		var skill: SkillDef = _LoadSkill(skill_id)
		var target_cell: Vector2i = Vector2i(5, 2)
		if skill.target_side == SkillDef.TargetSide.ALLY:
			_MakeUnit(&"ally_far", 0, target_cell)
		var result: SkillExecutor.ExecutionResult = _executor.execute(caster,
				skill, target_cell, _Ctx(1, 1))
		assert_bool(result.success) \
				.override_failure_message("%s 应被 LOS 拦截" % skill_id).is_false()
		assert_str(String(result.error)) \
				.override_failure_message("%s 失败码" % skill_id) \
				.is_equal("no_line_of_sight")

func test_melee_skills_range_table() -> void:
	## ①近战射程表（range 1）：距 2 → out_of_range——六普攻 + 痛击 + 背刺
	## 全量（(3,6)→(3,4) 曼哈顿距 2）
	var melee_ids: Array[StringName] = [&"skl_atk_warrior", &"skl_atk_rogue",
			&"skl_atk_mage", &"skl_atk_priest", &"skl_atk_ranger",
			&"skl_atk_arcanist", &"skl_warrior_power_strike", &"skl_rogue_backstab"]
	var caster := _MakeUnit(&"melee_caster", 0, Vector2i(3, 6))
	caster.hit = 0.85
	var rat := _MakeTrash(Vector2i(3, 4))
	for skill_id: StringName in melee_ids:
		var result: SkillExecutor.ExecutionResult = _executor.execute(caster,
				_LoadSkill(skill_id), rat.grid_pos, _Ctx(1, 0))
		assert_bool(result.success) \
				.override_failure_message("%s 距 2 应超射程" % skill_id).is_false()
		assert_str(String(result.error)) \
				.override_failure_message("%s 失败码" % skill_id) \
				.is_equal("out_of_range")

func test_caster_downed_blocks_representatives() -> void:
	## ①施放者倒地（S3-01）：近战/远程/自身增益三路径全拦截 caster_downed，
	## 资源不扣、目标无伤
	var warrior := _MakeWarrior(Vector2i(3, 6))
	warrior.alive = false
	var rat := _MakeTrash(Vector2i(3, 5))
	var melee: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_atk_warrior"), rat.grid_pos, _Ctx(1, 0))
	assert_str(String(melee.error)).is_equal("caster_downed")
	var power: SkillExecutor.ExecutionResult = _executor.execute(warrior,
			_LoadSkill(&"skl_warrior_power_strike"), rat.grid_pos, _Ctx(1, 0))
	assert_str(String(power.error)).is_equal("caster_downed")
	assert_int(warrior.resource_stamina).is_equal(100)
	var mage := _MakeMage(Vector2i(0, 0))
	mage.alive = false
	var ranged: SkillExecutor.ExecutionResult = _executor.execute(mage,
			_LoadSkill(&"skl_mage_fireball"), rat.grid_pos, _Ctx(1, 0))
	assert_str(String(ranged.error)).is_equal("caster_downed")
	assert_int(mage.resource_mana).is_equal(100)
	assert_int(rat.damage_taken.size()).is_equal(0)
	assert_int(rat.hp).is_equal(100)
