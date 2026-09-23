## 战斗单位（BattleUnit，RefCounted 纯逻辑类）
## 职责：承载一名参战单位（我方冒险者 / 敌方）的全部战斗态——标识、属性、
## 资源双轨、装备数值、技能清单、战场位置、行动标记与 AI 上下文；提供
## 二级属性合并读取（DerivedStats 基础 + StatusManager 修正）、移动力终值、
## 排序速度、资源扣减与承伤/治疗。
## 数据来源：案 9《战棋战斗》；案 17 §3.2（二级属性）/§3.8（敌方护甲抗性为
## 表定值不走属性派生——flat 口径）/§3.9（移动力终值：职业 + 敏捷 ≥16 +1，
## 基准段上限 6）；17-C19（速度排序专用修正）。
## 纯逻辑约束：不触任何 autoload——cfg 与 StatusManager 经 bind_battle 注入；
## 完整满足批 1 SkillExecutor/BattleGrid/StatusManager 的单位鸭子契约
## （id/side/alive/grid_pos/attrs/weapon_bonus/race_tag/class_id/派生属性/
## has_resource/consume_resource/take_damage/heal/on_downed）。
## 敌方口径：armor/resist 为 EnemyDef 表定值（flat_defense=true，不叠加属性调整）；
## 我方：护甲 = 装备 + 属性调、抗性 = 属性派生。
class_name BattleUnit
extends RefCounted

## 敏捷移动加成门槛（≥16 时移动力 +1，17-C8）
const AGILITY_MOVE_BONUS_LINE: int = 16
## 移动力基准段上限（职业移动力 + 敏捷加成合计封顶；状态修正不封顶——17-C8 口径，
## 上限作用于「职业 + 敏捷」段，疾步等状态修正在其后叠加）
const MOVE_BASE_CAP: int = 6

## 单位实例 id（我方 = 冒险者 unit_id；敌方 = "<enemy_id>_<序号>" 唯一化）
var unit_id: StringName = &""
## 显示名
var display_name: String = ""
## 阵营（0 = 我方 ALLY / 1 = 敌方 ENEMY——与 SkillDef.SkillSide 对齐）
var side: int = 0
## 职业 id（我方；敌方位为空——法术穿甲按智力派生）
var class_id: StringName = &""
## 敌人定义 id（敌方；我方位为空）
var enemy_id: StringName = &""
## 槽位序（我方 = 队伍序 / 敌方 = 配置序——同速打破平的次级排序键）
var slot_index: int = 0
## 等级（我方；HP 换算消费）
var level: int = 1

# ---- 数值面 ----
## 七属性表：{StringName 属性 id: int 值}
var attrs: Dictionary = {}
## 生命上限 / 当前生命
var max_hp: int = 1
var current_hp: int = 1
## 法力上限 / 当前法力（敌方法力 0——敌方技能走精力池）
var max_mana: int = 0
var current_mana: int = 0
## 精力上限 / 当前精力（敌方资源池挂精力轨）
var max_stamina: int = 0
var current_stamina: int = 0
## 武器加值（伤害公式加值项）
var weapon_bonus: int = 0
## 装备护甲值（我方 = 装备表；敌方 = EnemyDef.armor 表定值）
var armor_equip: int = 0
## 基础移动力（我方 = 职业移动力；敌方 = 敌表移动力）
var base_move_range: int = 1
## 技能 id 清单（含普攻；敌方含主动技 + 通用普攻）
var skill_ids: Array[StringName] = []
## 普攻技能 id（敌方 = skl_atk_enemy_common）
var base_attack_id: StringName = &""
## 本系资源轨（SkillDef.ResourceKind——UI 资源条显示用；我方 = 职业轨、
## 敌方 = 精力轨；批 3 增）
var resource_kind: int = 2
## 种族标记（StringName 化：&"beast"/&"humanoid"/&"undead"——种族克制消费）
var race_tag: StringName = &""
## 职能标记（&"trash"/&"elite"——敌方 AI 分支 + UI 精英放大消费）
var role_tag: StringName = &""

# ---- 敌方表定防御（flat 口径）----
## 敌方 flat 防御标记：true 时护甲不叠属性调、抗性直取 fixed_resist（17 案 §3.8）
var flat_defense: bool = false
## 表定抗性（flat_defense=true 时生效；-1 = 未设）
var fixed_resist: float = -1.0

# ---- 战斗态 ----
## 所在格
var grid_pos: Vector2i = Vector2i(-1, -1)
## 本行动轮已移动 / 已行动标记（行动轮开始复位）
var has_moved: bool = false
var has_acted: bool = false
## 存活（false = 倒地退场）
var alive: bool = true
## AI 上下文（roar_used / last_target_id 等——AI 记忆挂单位实例）
var ai_context: Dictionary = {}

# ---- 注入依赖（bind_battle 挂接）----
## 总控配置（派生公式参数；空时 BattleRules 用兜底常量）
var _cfg: CoreConfig = null
## 状态管理器（修正合并读取；空时状态修正按 0）
var _status_manager: StatusManager = null

## 单位在场状态实例列表（转发 StatusManager——单一事实源，副本只读）
var statuses: Array[StatusInstance]:
	get:
		if _status_manager != null:
			return _status_manager.get_statuses(self)
		var empty: Array[StatusInstance] = []
		return empty

## 鸭子契约别名（批 1 SkillExecutor 读 target.id 作目标标识/陷阱施放者）
var id: StringName:
	get:
		return unit_id

func bind_battle(cfg: CoreConfig, status_manager: StatusManager) -> void:
	## 挂接战斗上下文（BattleSetup 装配后调用）：派生参数与状态修正来源
	## 参数 cfg：总控配置；status_manager：本场状态管理器
	## 返回：无
	_cfg = cfg
	_status_manager = status_manager

func reset_turn_flags() -> void:
	## 行动轮开始：复位移动/行动标记
	## 参数：无
	## 返回：无
	has_moved = false
	has_acted = false

func is_controllable() -> bool:
	## 是否受玩家指令控制（我方存活单位）
	## 参数：无
	## 返回：true = 玩家可下达指令
	return alive and side == SkillDef.SkillSide.ALLY

func get_derived(key: StringName) -> float:
	## 二级属性合并读取：DerivedStats 基础值 + StatusManager 同键修正 Σ
	## （状态修正键映射：phys_armor←armor_physical / mag_armor←armor_magical，
	## 其余键同名——M0 状态数据侧键名口径）
	## 参数 key：派生键（hit/dodge/status_resist/phys_pierce/mag_pierce/
	## phys_resist/mag_resist/phys_armor/mag_armor/move_range/speed）
	## 返回：合并值（float；点数类由调用方取整消费）
	var base: float = _DerivedBase(key)
	return base + _StatusMod(_StatusKeyOf(key))

func move_final() -> int:
	## 移动力终值 =（基础 + 敏捷 ≥16 加成，基准段封顶 6）+ Σ状态移动修正，负钳 0
	## （17-C8：上限 6 作用于职业+敏捷段；疾步 +2 / 减速 −2 等状态修正其后叠加）
	## 参数：无
	## 返回：移动力终值（≥0；0 = 定身级不可移动）
	var agility: int = int(attrs.get(&"agility", 0))
	var base: int = mini(MOVE_BASE_CAP, base_move_range + (1 if agility >= AGILITY_MOVE_BONUS_LINE else 0))
	return maxi(0, base + roundi(_StatusMod(&"move_range")))

func speed_for_order() -> int:
	## 行动排序速度 = 敏捷原始值 + Σ速度排序专用修正（17-C19：速度 ±N 仅作用
	## 行动排序、不连带闪避/暴击等敏捷派生）
	## 参数：无
	## 返回：排序速度
	return int(attrs.get(&"agility", 0)) + roundi(_StatusMod(&"speed"))

func has_resource(kind: int, amount: int) -> bool:
	## 资源余量检查（kind = SkillDef.ResourceKind；敌方技能走精力轨）
	## 参数 kind：资源类别；amount：需求量
	## 返回：true = 足够
	if kind == SkillDef.ResourceKind.MANA:
		return current_mana >= amount
	if kind == SkillDef.ResourceKind.STAMINA:
		return current_stamina >= amount
	return true

func consume_resource(kind: int, amount: int) -> void:
	## 资源扣减（调用方已过 has_resource 检查；下限钳 0）
	## 参数 kind：资源类别；amount：扣减量
	## 返回：无
	if kind == SkillDef.ResourceKind.MANA:
		current_mana = maxi(0, current_mana - amount)
	elif kind == SkillDef.ResourceKind.STAMINA:
		current_stamina = maxi(0, current_stamina - amount)

func spend_resource(kind: int, amount: int) -> bool:
	## 资源检查 + 扣减（原子口径：不足即败不扣）
	## 参数 kind：资源类别；amount：消耗量
	## 返回：true = 已扣减；false = 余量不足
	if not has_resource(kind, amount):
		return false
	consume_resource(kind, amount)
	return true

func take_damage(amount: int) -> bool:
	## 承伤（减免轨已在 BattleRules 结算，此处直扣）：生命 ≤0 置 alive=false
	## 即时退场标记（倒地者从目标选择/治疗对象中剔除）
	## 参数 amount：最终伤害
	## 返回：true = 本次承伤致倒地
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		alive = false
		return true
	return false

func heal(amount: int) -> void:
	## 治疗（倒地者不可治疗——调用方前置校验，此处双保险直接拒绝）
	## 参数 amount：治疗量（上限钳 max_hp）
	## 返回：无
	if not alive:
		return
	current_hp = mini(max_hp, current_hp + amount)

func on_downed() -> void:
	## 倒地回调（批 1 鸭子契约占位实现——战斗侧全灭判定走 alive 轮询，
	## 演出层挂点批 3 接线）
	## 参数：无
	## 返回：无
	pass

func _DerivedBase(key: StringName) -> float:
	## 二级属性基础值（DerivedStats 派生；敌方 flat 防御走表定值）
	## 参数 key：派生键
	## 返回：基础值
	match key:
		&"hit":
			return DerivedStats.calc_hit(int(attrs.get(&"perception", 10)), _cfg)
		&"dodge":
			return DerivedStats.calc_dodge(int(attrs.get(&"agility", 10)), _cfg)
		&"status_resist":
			if flat_defense and fixed_resist >= 0.0:
				return fixed_resist
			return DerivedStats.calc_status_resist(int(attrs.get(&"constitution", 10)),
					int(attrs.get(&"willpower", 10)), _cfg)
		&"phys_pierce":
			return float(DerivedStats.calc_phys_pierce(int(attrs.get(&"strength", 10)), _cfg))
		&"mag_pierce":
			return float(DerivedStats.calc_mag_pierce(int(attrs.get(&"intelligence", 10)),
					int(attrs.get(&"willpower", 10)), class_id, _cfg))
		&"phys_resist":
			if flat_defense and fixed_resist >= 0.0:
				return fixed_resist
			return DerivedStats.calc_phys_resist(int(attrs.get(&"constitution", 10)), _cfg)
		&"mag_resist":
			if flat_defense and fixed_resist >= 0.0:
				return fixed_resist
			return DerivedStats.calc_mag_resist(int(attrs.get(&"perception", 10)), _cfg)
		&"phys_armor":
			if flat_defense:
				return float(armor_equip)
			return float(DerivedStats.calc_phys_armor(armor_equip,
					int(attrs.get(&"constitution", 10)), _cfg))
		&"mag_armor":
			if flat_defense:
				return float(armor_equip)
			return float(DerivedStats.calc_mag_armor(armor_equip,
					int(attrs.get(&"perception", 10)), _cfg))
		_:
			return 0.0

func _StatusKeyOf(derived_key: StringName) -> StringName:
	## 派生键 -> 状态修正键映射（M0 状态数据侧键名：护甲双轨带 armor_ 前缀）
	## 参数 derived_key：派生键
	## 返回：状态修正键
	if derived_key == &"phys_armor":
		return &"armor_physical"
	if derived_key == &"mag_armor":
		return &"armor_magical"
	return derived_key

func _StatusMod(mod_key: StringName) -> float:
	## 状态修正求和（无管理器挂接时按 0）
	## 参数 mod_key：状态修正键
	## 返回：Σ修正
	if _status_manager == null:
		return 0.0
	return _status_manager.get_stat_mod(self, mod_key)

# ---- 派生属性只读属性（批 1 鸭子契约消费：SkillExecutor 直读字段）----

## 命中率基准（含状态修正）
var hit: float:
	get:
		return get_derived(&"hit")
## 闪避率（含状态修正）
var dodge: float:
	get:
		return get_derived(&"dodge")
## 异常状态抗性
var status_resist: float:
	get:
		return get_derived(&"status_resist")
## 物理穿甲
var phys_pierce: int:
	get:
		return roundi(get_derived(&"phys_pierce"))
## 法术穿甲
var mag_pierce: int:
	get:
		return roundi(get_derived(&"mag_pierce"))
## 物理抗性
var phys_resist: float:
	get:
		return get_derived(&"phys_resist")
## 法术抗性
var mag_resist: float:
	get:
		return get_derived(&"mag_resist")
## 物理护甲（装备 + 属性调/表定 + 盾墙类修正）
var phys_armor: int:
	get:
		return roundi(get_derived(&"phys_armor"))
## 法术护甲
var mag_armor: int:
	get:
		return roundi(get_derived(&"mag_armor"))
