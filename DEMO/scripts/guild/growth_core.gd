## 成长核心（GrowthCore，纯静态工具类）
## 职责：经验曲线/升级结算（连升+全属性成长+倾向侧重+悬置补加）/技能点/
## 板凳经验分享/技能解锁——名册成长规则的单源。
## 数据来源：案 5 §2.3（等级与成长）；案 17 §3.6（成长域收口：100×L 曲线、
## 出战各得全额、板凳分享 30%/40%、出生 1 点+每级 1 点、上限 5、17-C3 全额
## 成长口径）；拍板④（板凳分享基数=基础经验，不含超额）。
## 纯逻辑约束：不触任何 autoload——cfg/game_data 经参数注入。
class_name GrowthCore
extends RefCounted

static func exp_to_next(level: int, cfg: CoreConfig) -> int:
	## 升级所需经验曲线：exp_per_level_base × 当前等级（17-C5：100×L）
	## 参数 level：当前等级；cfg：总控配置
	## 返回：本级升下一级所需经验
	return cfg.exp_per_level_base * level

static func apply_exp(adv: AdventurerData, amount: int, cfg: CoreConfig,
		game_data: Node, pending: Dictionary) -> int:
	## 经验结算与连升处理：累加→循环升级（全属性+levelup_all_attrs；已选倾向者
	## 侧重属性再+levelup_tendency_bonus；未选倾向者记入 pending 待选后补加；
	## 技能点+skill_points_per_level）；等级上限封顶（经验滞留展示）
	## 参数 adv：目标成员；amount：本次经验；cfg/game_data：配置与数据源；
	## pending：悬置倾向档数表（String(unit_id) -> int——GuildCore 持有）
	## 返回：本次升级数
	adv.exp += amount
	var levels_gained: int = 0
	while adv.level < cfg.level_cap and adv.exp >= exp_to_next(adv.level, cfg):
		adv.exp -= exp_to_next(adv.level, cfg)
		adv.level += 1
		levels_gained += 1
		_ApplyLevelupGrowth(adv, cfg, game_data, pending)
		adv.skill_points += cfg.skill_points_per_level
	return levels_gained

static func _ApplyLevelupGrowth(adv: AdventurerData, cfg: CoreConfig,
		game_data: Node, pending: Dictionary) -> void:
	## 单级成长结算：全属性+1 段；倾向段——已选者侧重属性+bonus、未选者
	## 悬置计数（set_tendency 时按积压档数补加）
	## 参数 adv/cfg/game_data/pending：成员 / 配置 / 数据源 / 悬置表
	## 返回：无
	for attr_id: StringName in adv.attrs:
		adv.attrs[attr_id] = int(adv.attrs[attr_id]) + cfg.levelup_all_attrs
	var tendency: TendencyDef = resolve_tendency(adv, game_data)
	if tendency == null:
		pending[String(adv.unit_id)] = int(pending.get(String(adv.unit_id), 0)) + 1
		return
	for attr_id: StringName in tendency.focus_attrs:
		adv.attrs[attr_id] = int(adv.attrs.get(attr_id, AttrKeys.DEFAULT_ATTR_VALUE)) \
				+ cfg.levelup_tendency_bonus

static func resolve_tendency(adv: AdventurerData, game_data: Node) -> TendencyDef:
	## 解析成员已选倾向（tendency_id -> 所属职业 tendencies 查找）
	## 参数 adv：成员；game_data：数据源
	## 返回：TendencyDef；未选/职业查无/倾向不属于本职业返回 null
	if adv.tendency_id == &"":
		return null
	var cls: ClassDef = game_data.get_record(adv.class_id) as ClassDef
	if cls == null:
		return null
	for tendency: TendencyDef in cls.tendencies:
		if tendency.id == adv.tendency_id:
			return tendency
	return null

static func set_tendency(adv: AdventurerData, tendency_id: StringName, cfg: CoreConfig,
		game_data: Node, pending: Dictionary) -> bool:
	## 选择职业倾向并补加悬置成长：按 pending 积压档数对侧重属性补
	## levelup_tendency_bonus×积压（全属性段已在升级时即时加过），补后清零悬置
	## 参数 adv：成员；tendency_id：倾向 id（须属于本职业）；cfg/game_data/pending
	## 返回：true = 生效；倾向不属于本职业返回 false（不改状态）
	var cls: ClassDef = game_data.get_record(adv.class_id) as ClassDef
	var valid: bool = false
	if cls != null:
		for tendency: TendencyDef in cls.tendencies:
			if tendency.id == tendency_id:
				valid = true
				break
	if not valid:
		return false
	var backlog: int = int(pending.get(String(adv.unit_id), 0))
	adv.tendency_id = tendency_id
	if backlog > 0:
		var chosen: TendencyDef = resolve_tendency(adv, game_data)
		if chosen != null:
			for attr_id: StringName in chosen.focus_attrs:
				adv.attrs[attr_id] = int(adv.attrs.get(attr_id, AttrKeys.DEFAULT_ATTR_VALUE)) \
						+ cfg.levelup_tendency_bonus * backlog
	pending.erase(String(adv.unit_id))
	return true

static func bench_share_exp(base_exp: int, share_rate: float) -> int:
	## 板凳经验分享额（拍板④：基数=委托基础经验，不含超额；四舍五入取整）
	## 参数 base_exp：基础经验；share_rate：训练场分享率（fac_ 表当前级）
	## 返回：板凳所得经验
	return roundi(base_exp * share_rate)

static func unlock_skill(adv: AdventurerData, skill_id: StringName, cfg: CoreConfig,
		game_data: Node) -> bool:
	## 技能解锁（档 1 全可学 #14——不分倾向）：校验技能点足额、技能属本职业
	## 档 1、未重复学——扣点入列
	## 参数 adv：成员；skill_id：技能 id；cfg/game_data：配置与数据源
	## 返回：true = 解锁成功
	if adv.skill_points < cfg.skill_unlock_cost:
		return false
	if adv.skill_ids.has(skill_id):
		return false
	var skill: SkillDef = game_data.get_record(skill_id) as SkillDef
	if skill == null or skill.owner_id != adv.class_id or skill.tier != 1:
		return false
	adv.skill_points -= cfg.skill_unlock_cost
	adv.skill_ids.append(skill_id)
	return true
