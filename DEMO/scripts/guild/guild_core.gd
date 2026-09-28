## 公会运行态核心（GuildCore，RefCounted 纯逻辑类）
## 职责：M4 经营层运行态容器+门面——经济（货币/声望）、名册（初始种子/招募）、
## 设施等级、日结算调度（五步 pipeline 表驱动消费）、回城结算（委托出口/经验
## 分配/授予转挂单/日历逐日补推）、委托编队校验（人力区间/占用/出征频次/
## 进行中上限）与公会快照序列化。
## 数据来源：案 2 §2.4（日结算五步顺序）/案 3（设施升级）/案 4（经济闭环）/
## 案 5 §2.4-§2.6（名册/状态/编队）/案 6 §2.2-§2.5（委托运转与五出口）/
## 案 17 §3.5-§3.7（数值收口）；拍板④（板凳分享基数=基础经验）。
## 纯逻辑约束：不触任何 autoload——cfg/game_data/rng 注入（铁律⑥）；
## 存档对接（provider 注册/autosave 时点/出征锁）由 GuildState 薄壳承载。
class_name GuildCore
extends RefCounted

## 回城结算出口（案 6 §2.4 五出口之前四——到期失败走日结算挂单通道，
## 不经回城结算）
enum ExpeditionOutcome {
	SUCCESS,
	DEFEAT,
	RETREAT,
	GOAL_FAILED,
}

## 日结算汇总（案 2 §2.4 第 10 步「汇总通知」的数据载荷——恢复完成/委托
## 到期明细/新候选；UI 批 2 消费）
class DaySummary:
	## 本日天数（day_advance 之后）
	var day: int = 0
	## 本日是否周刷新
	var week_refreshed: bool = false
	## 恢复完成成员 id（休养归零转健康）
	var recovered_ids: Array[StringName] = []
	## 板上到期移除的模板 id（三表现统一计）
	var board_removed: Array[String] = []
	## 刷新补位新上板模板 id
	var board_refreshed: Array[String] = []
	## 替换表现新实例模板 id（加急）
	var board_replaced: Array[String] = []
	## 挂单到期失败模板 id
	var accepted_failed: Array[String] = []
	## 新候选姓名
	var new_candidate_names: Array[String] = []

## 回城结算摘要（settle_expedition 返回——批 2 结算面板消费）
class ExpeditionSummary:
	## 出口（ExpeditionOutcome）
	var outcome: int = -1
	## 货币入账合计（委托+事件/宝箱）
	var gold_gained: int = 0
	## 声望入账合计（委托基础+事件；超额不加声望）
	var reputation_gained: int = 0
	## 委托基础经验（板凳分享基数——拍板④）
	var quest_exp_base: int = 0
	## 委托结算经验（出战者所得，含超额）
	var quest_exp_final: int = 0
	## 出战者经验入账明细（String(unit_id) -> int：委托+事件合计）
	var exp_gained: Dictionary = {}
	## 升级明细（String(unit_id) -> int 升级数——出战+板凳合并）
	var levels_gained: Dictionary = {}
	## 板凳经验明细（String(unit_id) -> int）
	var bench_exp: Dictionary = {}
	## 战败重伤休养天数（非战败为 0）
	var injury_rest_days: int = 0
	## 回城转挂单的新授予模板 id
	var quests_granted: Array[StringName] = []
	## 补结算天数（= run.total_days()）
	var days_settled: int = 0
	## 逐日补结算汇总（DaySummary 列表）
	var day_summaries: Array = []
	## RETURN_SETTLED 存档写入失败标志（M-3：GuildState.autosave 返回值消费——
	## 失败时结算面板追加警示行）
	var save_failed: bool = false

## 当日天数（新档从 1 起——开局日=周 1）
var day: int = 1
## 货币（案 4 单一货币）
var gold: int = 0
## 声望（DEMO 仅展示值——案 3）
var reputation: int = 0
## 设施等级表（StringName fac_id -> int 等级；初始全 1）
var facility_levels: Dictionary = {}
## 名册（初始种子成员+招募成员）
var roster: Array[AdventurerData] = []
## 招募池
var recruit_pool: RecruitPool = RecruitPool.new()
## 委托板（板+挂单）
var board: QuestBoard = QuestBoard.new()
## 沿用编队记忆（String(tpl_id) -> Array[StringName] 上次编队——案 5 §2.6 便捷操作）
var last_party_by_tpl: Dictionary = {}
## 未选倾向的悬置升级档数（String(unit_id) -> int——选倾向后补加）
var pending_tendency_levels: Dictionary = {}
## 未查看的新授予挂单标记（M4-1：回城授予委托置 true、进协会屏清除——
## 角标状态常驻核心层而非公会壳实例，规避「结算时壳已销毁、信号无监听」
## 的跨场景窗口；随公会快照持久）
var has_unseen_grants: bool = false
## 总控配置（注入）
var cfg: CoreConfig
## 数据源（注入）
var game_data: Node
## 随机源（注入——测试确定性）
var rng: RandomNumberGenerator
## 最近一次门面校验失败原因（批 2 UI 提示消费；成功操作清空）
var last_error: String = ""

func attach(cfg: CoreConfig, game_data: Node, rng: RandomNumberGenerator) -> void:
	## 依赖注入（setup 与 GuildState 读档恢复共用——restore_snapshot 前须先挂依赖）
	## 参数 cfg/game_data/rng：总控配置 / GameData / 随机源
	## 返回：无
	self.cfg = cfg
	self.game_data = game_data
	self.rng = rng
	recruit_pool.setup(cfg, game_data, rng)
	board.setup(cfg, game_data, rng)

func setup(cfg: CoreConfig, game_data: Node, rng: RandomNumberGenerator) -> void:
	## 新档初始化：初始资金/日历归 1/设施全 1 级/初始 4 人种子入册（属性
	## roll_fixed_four 中值偏上+第 1 技预解锁+出生技能点）/招募池首刷/委托板
	## 开局预生成（当日不触发周刷新）
	## 参数 cfg/game_data/rng：总控配置 / GameData / 随机源
	## 返回：无
	attach(cfg, game_data, rng)
	day = 1
	gold = cfg.initial_gold
	reputation = 0
	# G-1：同进程二开新档全量复位——挂单清空（防旧单 party_ids 泄入锁死新档
	# 成员/IN_PROGRESS 残留封锁出征）、未查看角标复位（防常亮）
	board.accepted.clear()
	has_unseen_grants = false
	facility_levels.clear()
	for fac_id: StringName in game_data.get_domain_ids(&"guild/facilities"):
		facility_levels[fac_id] = 1
	last_party_by_tpl.clear()
	pending_tendency_levels.clear()
	roster.clear()
	var seed_ids: Array[StringName] = game_data.get_domain_ids(&"adventurer/instances")
	# StringName 的 sort() 非字典序（Variant 比较——顺序不稳定）：转 String 排序
	# 保证名册序确定性（adv_erin/iron_peak/morris/night_song）
	var sorted_ids: Array[String] = []
	for seed_id: StringName in seed_ids:
		sorted_ids.append(String(seed_id))
	sorted_ids.sort()
	for seed_key: String in sorted_ids:
		var seed_def: AdventurerSeedDef = game_data.get_record(StringName(seed_key)) as AdventurerSeedDef
		if seed_def != null:
			roster.append(_BuildSeedMember(seed_def))
	recruit_pool.refresh(_RosterClassIds())
	board.initial_fill(day)

func _BuildSeedMember(seed_def: AdventurerSeedDef) -> AdventurerData:
	## 种子成员构建：属性=roll_fixed_four（中值偏上、豁免钳制——17-C7）、
	## 第 1 技预解锁（档 1 技能 id 字典序首位——不扣点）、出生技能点
	## 参数 seed_def：种子行
	## 返回：AdventurerData
	var cls: ClassDef = game_data.get_record(seed_def.class_id) as ClassDef
	var adv := AdventurerData.new()
	adv.unit_id = seed_def.id
	adv.class_id = seed_def.class_id
	adv.display_name = seed_def.display_name
	adv.level = 1
	adv.exp = 0
	if cls != null:
		adv.attrs = AttrRoller.roll_fixed_four(cls, rng)
	else:
		adv.attrs = {}
	var first_skill: StringName = _FirstTierOneSkill(seed_def.class_id)
	if first_skill != &"":
		adv.skill_ids = [first_skill]
	adv.skill_points = cfg.skill_points_birth
	adv.tendency_id = &""
	adv.status = AdventurerData.Status.HEALTHY
	adv.rest_days = 0
	adv.last_expedition_day = 0
	adv.pre_unlocked = seed_def.pre_unlocked
	return adv

func _FirstTierOneSkill(class_id: StringName) -> StringName:
	## 职业档 1 第 1 技能（id 字典序首位——预解锁口径的确定性取法；普攻
	## tier=0 不在列）
	## 参数 class_id：职业 id
	## 返回：技能 id；无档 1 技能返回空
	var skills: Array[StringName] = []
	for skill_id: StringName in game_data.get_domain_ids(&"class/skills"):
		var skill: SkillDef = game_data.get_record(skill_id) as SkillDef
		if skill != null and skill.owner_id == class_id and skill.tier == 1:
			skills.append(skill_id)
	skills.sort()
	return skills[0] if not skills.is_empty() else &""

func _RosterClassIds() -> Array[StringName]:
	## 名册职业集合（偏缺职业判定基数）
	## 参数：无
	## 返回：职业 id 列表（含重复无碍判定）
	var result: Array[StringName] = []
	for adv: AdventurerData in roster:
		result.append(adv.class_id)
	return result

# --------------------------------------------------------------------------
# 日结算（案 2 §2.4 五步 pipeline——顺序表驱动消费 cfg.day_settle_pipeline）
# --------------------------------------------------------------------------

func settle_one_day() -> DaySummary:
	## 单日结算：按 cfg.day_settle_pipeline 顺序消费步骤键——day_advance（天数+1）
	## / recovery（重伤休养倒计）/ recruit_refresh（整池刷新）/ quest_countdown
	##（周刷新或到期三表现+挂单到期失败）/ summary（汇总定稿）；未知键告警跳过
	## 参数：无
	## 返回：DaySummary（恢复完成/到期明细/新候选）
	var summary := DaySummary.new()
	for step_key: String in cfg.day_settle_pipeline:
		match step_key:
			"day_advance":
				day += 1
			"recovery":
				_SettleRecovery(summary)
			"recruit_refresh":
				_SettleRecruitRefresh(summary)
			"quest_countdown":
				_SettleQuestCountdown(summary)
			"summary":
				summary.day = day
			_:
				push_warning("GuildCore: 未知日结算步骤键 '%s'，跳过" % step_key)
	return summary

func _SettleRecovery(summary: DaySummary) -> void:
	## 恢复结算：全员重伤休养 rest_days-1，归 0 转健康（案 2 §2.4 第 3 步——
	## 普通损耗 DEMO 回城当日全额，无逐日项）
	## 参数 summary：汇总（恢复完成明细写入）
	## 返回：无
	for adv: AdventurerData in roster:
		if adv.status != AdventurerData.Status.RESTING:
			continue
		adv.rest_days -= 1
		if adv.rest_days <= 0:
			adv.rest_days = 0
			adv.status = AdventurerData.Status.HEALTHY
			summary.recovered_ids.append(adv.unit_id)

func _SettleRecruitRefresh(summary: DaySummary) -> void:
	## 招募池整池刷新（偏缺职业优先——案 2 第 5 步/案 5 §2.4）
	## 参数 summary：汇总（新候选姓名写入）
	## 返回：无
	recruit_pool.refresh(_RosterClassIds())
	for candidate: AdventurerData in recruit_pool.candidates:
		summary.new_candidate_names.append(candidate.display_name)

func _SettleQuestCountdown(summary: DaySummary) -> void:
	## 委托步：周刷新（清板重抽，跳过板上到期表现）或板上到期三表现；
	## 并行挂单到期自动失败（案 2 §2.4 第 7 步/§2.5）
	## 参数 summary：汇总（到期明细写入）
	## 返回：无
	var result: Dictionary = board.settle_expirations(day)
	summary.week_refreshed = bool(result[&"week_refreshed"])
	summary.board_removed = _ToStringArray(result[&"board_removed"])
	summary.board_refreshed = _ToStringArray(result[&"board_refreshed"])
	summary.board_replaced = _ToStringArray(result[&"board_replaced"])
	summary.accepted_failed = _ToStringArray(result[&"accepted_failed"])

static func _ToStringArray(values: Array) -> Array[String]:
	## 无类型数组 → Array[String]（汇总明细的类型化桥——Dictionary 取值无静态类型；
	## 模板 id 以 String 承载，展示载荷统一口径）
	## 参数 values：待转换数组
	## 返回：Array[String]
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value))
	return result

# --------------------------------------------------------------------------
# 委托门面（编队校验+状态迁移——案 6 §2.4）
# --------------------------------------------------------------------------

func accept_quest(serial_id: int, party_ids: Array[StringName]) -> bool:
	## 接取（编队确认——人力占用起点）：校验板上存在/**同模板挂单拦截**（G-2
	## 源头防并存——板不与挂单同模板，防结算按模板匹配删错实例）/人力区间/
	## 成员存在+健康+未被占用 → ACCEPTED（接取不补位）；记沿用编队记忆
	## 参数 serial_id：实例序号；party_ids：编队成员 id
	## 返回：true = 接取成功（失败原因写 last_error）
	last_error = ""
	var inst: QuestInstance = board.find_on_board(serial_id)
	if inst == null:
		last_error = "委托不在板上"
		return false
	if board.find_accepted_by_template(inst.template_id) != null:
		last_error = "同模板委托已在挂单——先完成或放弃再接"
		return false
	if not _ValidateParty(inst.template_id, party_ids, null):
		return false
	board.accept(inst, party_ids)
	last_party_by_tpl[String(inst.template_id)] = party_ids.duplicate()
	return true

func reassign_party(serial_id: int, party_ids: Array[StringName]) -> bool:
	## 重编队（挂单期可转移占用、进行中锁定）：校验挂单+ACCEPTED 态+编队合法
	##（排除自身旧编队占用）→ 占用随编队转移
	## 参数 serial_id：实例序号；party_ids：新编队成员 id
	## 返回：true = 转移成功
	last_error = ""
	var inst: QuestInstance = board.find_accepted(serial_id)
	if inst == null or inst.state != QuestInstance.State.ACCEPTED:
		last_error = "仅挂单委托可重编队（进行中锁定）"
		return false
	if not _ValidateParty(inst.template_id, party_ids, inst):
		return false
	board.reassign(inst, party_ids)
	last_party_by_tpl[String(inst.template_id)] = party_ids.duplicate()
	return true

func start_expedition(serial_id: int) -> bool:
	## 出征确认（ACCEPTED → IN_PROGRESS）：校验编队区间/无进行中战斗委托
	##（#23 同时 1 个）/每人每日一次（last_expedition_day != day）→ 锁定编队
	## 并落出征日标记
	## 参数 serial_id：实例序号
	## 返回：true = 出征确认成功
	last_error = ""
	var inst: QuestInstance = board.find_accepted(serial_id)
	if inst == null or inst.state != QuestInstance.State.ACCEPTED:
		last_error = "仅挂单委托可确认出征"
		return false
	var tpl: QuestTemplateDef = game_data.get_record(inst.template_id) as QuestTemplateDef
	if tpl == null:
		last_error = "委托模板缺失"
		return false
	if inst.party_ids.size() < tpl.party_min or inst.party_ids.size() > tpl.party_max:
		last_error = "编队人数不在需求区间"
		return false
	if board.in_progress_count() > 0:
		last_error = "已有进行中的战斗委托（同时 1 个）"
		return false
	for member_id: StringName in inst.party_ids:
		var member: AdventurerData = find_member(member_id)
		if member == null:
			last_error = "编队成员 '%s' 不在名册" % member_id
			return false
		if member.status != AdventurerData.Status.HEALTHY:
			last_error = "成员 '%s' 非健康态不可出征" % member_id
			return false
		if member.last_expedition_day == day:
			last_error = "成员 '%s' 今日已出征（每日一次）" % member_id
			return false
	board.start(inst)
	for member_id: StringName in inst.party_ids:
		find_member(member_id).last_expedition_day = day
	return true

func abandon_quest(serial_id: int) -> bool:
	## 主动放弃（ACCEPTED → 移除，P2 拍板：无惩罚无奖励、不回板、释放占用）：
	## 校验挂单+未出征（进行中锁定不可弃）+模板可弃
	## 参数 serial_id：实例序号
	## 返回：true = 放弃成功
	last_error = ""
	var inst: QuestInstance = board.find_accepted(serial_id)
	if inst == null:
		last_error = "委托不在挂单"
		return false
	if inst.state != QuestInstance.State.ACCEPTED:
		last_error = "出征进行中不可放弃（仅挂单可弃）"
		return false
	var tpl: QuestTemplateDef = game_data.get_record(inst.template_id) as QuestTemplateDef
	if tpl != null and not tpl.abandonable:
		last_error = "本委托不可放弃"
		return false
	board.remove(inst)
	return true

func _ValidateParty(template_id: StringName, party_ids: Array[StringName],
		exclude_inst: QuestInstance) -> bool:
	## 编队合法性校验（接取/重编队共用）：人力区间；成员存在+健康+未被其他
	## 委托占用（重编队排除自身）
	## 参数 template_id：模板 id；party_ids：编队；exclude_inst：占用排除实例
	## 返回：true = 合法（失败原因写 last_error）
	var tpl: QuestTemplateDef = game_data.get_record(template_id) as QuestTemplateDef
	if tpl == null:
		last_error = "委托模板缺失"
		return false
	if party_ids.is_empty() or party_ids.size() < tpl.party_min or party_ids.size() > tpl.party_max:
		last_error = "编队人数 %d 不在需求区间 [%d, %d]" % [
			party_ids.size(), tpl.party_min, tpl.party_max]
		return false
	var occupied: Array[StringName] = board.occupied_member_ids(exclude_inst)
	var seen_members: Dictionary = {}
	for member_id: StringName in party_ids:
		# D-1：编队去重（重复 id 会虚占席位并让 excess 计数失真）
		if seen_members.has(member_id):
			last_error = "编队成员 '%s' 重复" % member_id
			return false
		seen_members[member_id] = true
		var member: AdventurerData = find_member(member_id)
		if member == null:
			last_error = "编队成员 '%s' 不在名册" % member_id
			return false
		if member.status != AdventurerData.Status.HEALTHY:
			last_error = "成员 '%s' 非健康态" % member_id
			return false
		if occupied.has(member_id):
			last_error = "成员 '%s' 已被其他委托占用" % member_id
			return false
	return true

func abort_expedition(serial_id: int, previous_days: Dictionary = {}) -> bool:
	## 出征确认回退（M4：协会屏 go() 失败分支消费——释锁后回退 start_expedition
	## 的状态迁移）：IN_PROGRESS → ACCEPTED + 出征日标记按 previous_days 恢复
	##（{String(unit_id): int 原值}；缺键回 0）
	## 参数 serial_id：实例序号；previous_days：成员原 last_expedition_day 快照
	## 返回：true = 回退成功
	last_error = ""
	var inst: QuestInstance = board.find_accepted(serial_id)
	if inst == null or inst.state != QuestInstance.State.IN_PROGRESS:
		last_error = "仅进行中的出征可回退"
		return false
	inst.state = QuestInstance.State.ACCEPTED
	for member_id: StringName in inst.party_ids:
		var member: AdventurerData = find_member(member_id)
		if member != null:
			member.last_expedition_day = int(previous_days.get(String(member_id), 0))
	return true

func find_member(member_id: StringName) -> AdventurerData:
	## 按 id 查名册成员
	## 参数 member_id：实例 id
	## 返回：AdventurerData；查无返回 null
	for adv: AdventurerData in roster:
		if adv.unit_id == member_id:
			return adv
	return null

# --------------------------------------------------------------------------
# 回城结算（案 6 §2.4 时间结算/案 5 §2.3 经验分配——申报时点=回城批量）
# --------------------------------------------------------------------------

func settle_expedition(run: ExpeditionRun, outcome: ExpeditionOutcome) -> ExpeditionSummary:
	## 回城结算五步（批 1 纯逻辑；批 2 接 explore_screen 回城口）：
	## ①委托出口结算（成功=奖励×超额入账+声望；战败=全队重伤休养；撤退/判据
	## 失败=无奖励无重伤；实例移除+人力释放）②经验结算（出战者各得全额含超额；
	## 板凳健康成员=基础经验×训练场分享率——拍板④；事件累计奖励入账）
	## ③日历推进逐日补结算 ④granted_quests 逐个转挂单（18-C6 防重——
	## **置于补结算之后**：expire_day 以推进后终 day 起算，长途出征不再
	##「授予即到期」自动失败，M3/Z-2）⑤损耗恢复=DEMO 当日全额
	## 参数 run：出征会话；outcome：出口（四出口之一）
	## 返回：ExpeditionSummary；**幂等**（run 已结算——重复调用返回空摘要，
	## 不重复入账/推日历/转挂单，G-2）
	var summary := ExpeditionSummary.new()
	summary.outcome = outcome
	if run.settled:
		return summary
	run.settled = true
	_SettleQuestOutlet(run, outcome, summary)
	_SettleRunRewards(run, summary)
	for _settle_index: int in run.total_days():
		summary.day_summaries.append(settle_one_day())
	summary.days_settled = run.total_days()
	_ConvertGrantedQuests(run, summary)
	return summary

func _SettleQuestOutlet(run: ExpeditionRun, outcome: ExpeditionOutcome,
		summary: ExpeditionSummary) -> void:
	## 步骤①：委托出口结算——实例先行移除（补结算不再误判，案 2 §2.5）；
	## 结算目标匹配=run.quest_serial 精确匹配优先 → 同模板 IN_PROGRESS 优先
	## → 同模板首匹配（G-2 根修：同模板板上+挂单并存时按模板首匹配会删错
	## 实例——IN_PROGRESS 残留封锁出征）
	## 参数 run/outcome/summary：会话 / 出口 / 摘要
	## 返回：无
	if run.quest_template_id == &"":
		return
	var tpl: QuestTemplateDef = game_data.get_record(run.quest_template_id) as QuestTemplateDef
	var inst: QuestInstance = null
	if run.quest_serial > 0:
		inst = board.find_accepted(run.quest_serial)
	if inst == null:
		inst = board.find_in_progress_by_template(run.quest_template_id)
	if inst == null:
		inst = board.find_accepted_by_template(run.quest_template_id)
	if outcome == ExpeditionOutcome.SUCCESS:
		if tpl != null and tpl.reward != null:
			var excess: int = maxi(0, run.party.size() - tpl.party_min)
			var rate: float = tpl.excess_bonus_per_head if tpl.excess_bonus_per_head > 0.0 \
					else cfg.quest_excess_bonus_per_head
			var multiplier: float = 1.0 + rate * excess
			var gold_won: int = roundi(tpl.reward.gold * multiplier)
			var exp_base: int = tpl.reward.exp
			var exp_won: int = roundi(tpl.reward.exp * multiplier)
			gold += gold_won
			reputation += tpl.reward.reputation
			summary.gold_gained += gold_won
			summary.reputation_gained += tpl.reward.reputation
			summary.quest_exp_base = exp_base
			summary.quest_exp_final = exp_won
			for adv: AdventurerData in run.party:
				_GainExp(adv, exp_won, summary)
			_ShareBenchExp(exp_base, run, summary)
	elif outcome == ExpeditionOutcome.DEFEAT:
		var rest_days: int = injury_rest_days()
		summary.injury_rest_days = rest_days
		for adv: AdventurerData in run.party:
			adv.status = AdventurerData.Status.RESTING
			adv.rest_days = rest_days
	# RETREAT / GOAL_FAILED：无奖励无重伤（判据失败=案 6 §2.4 枚举口径）
	if inst != null:
		board.remove(inst)

func _SettleRunRewards(run: ExpeditionRun, summary: ExpeditionSummary) -> void:
	## 步骤②补充：事件/宝箱累计奖励入账（M3 起只累计、此处入账——案 4 收入表；
	## 不吃超额系数；事件经验出战者各得全额）
	## 参数 run/summary：会话 / 摘要
	## 返回：无
	var event_gold: int = int(run.rewards.get(&"gold", 0))
	var event_exp: int = int(run.rewards.get(&"exp", 0))
	var event_reputation: int = int(run.rewards.get(&"reputation", 0))
	gold += event_gold
	reputation += event_reputation
	summary.gold_gained += event_gold
	summary.reputation_gained += event_reputation
	if event_exp > 0:
		for adv: AdventurerData in run.party:
			_GainExp(adv, event_exp, summary)

func _GainExp(adv: AdventurerData, amount: int, summary: ExpeditionSummary) -> void:
	## 单成员经验入账（升级数并计入摘要——委托/事件经验统一走本口）
	## 参数 adv/amount/summary：成员 / 经验 / 摘要
	## 返回：无
	var unit_key: String = String(adv.unit_id)
	summary.exp_gained[unit_key] = int(summary.exp_gained.get(unit_key, 0)) + amount
	var gained: int = GrowthCore.apply_exp(adv, amount, cfg, game_data, pending_tendency_levels)
	if gained > 0:
		summary.levels_gained[unit_key] = int(summary.levels_gained.get(unit_key, 0)) + gained

func _ShareBenchExp(base_exp: int, run: ExpeditionRun, summary: ExpeditionSummary) -> void:
	## 板凳经验分享：板凳健康成员（不在出战队伍）得基础经验×训练场分享率
	##（拍板④：基数不含超额；休养成员不参与——板凳深度维持机制，案 5 §2.6）
	## 参数 base_exp/run/summary：基础经验 / 会话 / 摘要
	## 返回：无
	var party_ids: Array[StringName] = []
	for adv: AdventurerData in run.party:
		party_ids.append(adv.unit_id)
	var share_rate: float = bench_share_rate()
	for adv: AdventurerData in roster:
		if party_ids.has(adv.unit_id) or adv.status != AdventurerData.Status.HEALTHY:
			continue
		var gained: int = GrowthCore.bench_share_exp(base_exp, share_rate)
		if gained <= 0:
			continue
		summary.bench_exp[String(adv.unit_id)] = gained
		var levels: int = GrowthCore.apply_exp(adv, gained, cfg, game_data, pending_tendency_levels)
		if levels > 0:
			summary.levels_gained[String(adv.unit_id)] = \
					int(summary.levels_gained.get(String(adv.unit_id), 0)) + levels

func _ConvertGrantedQuests(run: ExpeditionRun, summary: ExpeditionSummary) -> void:
	## 步骤③：出征会话授予的委托转挂单（18-C6 防重：同模板已在挂单跳过；
	## 时限=当前 day+模板时限——出征中日历冻结、回城日即授予语义日）；
	## 有新授予即置未查看标记（M4-1——协会屏清除）
	## 参数 run/summary：会话 / 摘要
	## 返回：无
	for tpl_id: StringName in run.granted_quests:
		if board.find_accepted_by_template(tpl_id) != null:
			continue
		if game_data.get_record(tpl_id) as QuestTemplateDef == null:
			push_warning("GuildCore: 授予委托模板 '%s' 查无，跳过" % tpl_id)
			continue
		board.grant_to_accepted(tpl_id, day)
		summary.quests_granted.append(tpl_id)
		has_unseen_grants = true

# --------------------------------------------------------------------------
# 招募与设施（案 5 §2.4 / 案 3 §2.3）
# --------------------------------------------------------------------------

func recruit(index: int) -> AdventurerData:
	## 招募入册：校验候选在池/余额足额/宿舍未满员 → 扣款入册（不入池）
	## 参数 index：候选下标（0 起）
	## 返回：入册成员；失败返回 null（原因写 last_error）
	last_error = ""
	if index < 0 or index >= recruit_pool.candidates.size():
		last_error = "候选下标越界"
		return null
	var candidate: AdventurerData = recruit_pool.candidates[index]
	var cost: int = recruit_pool.cost_of(candidate)
	if gold < cost:
		last_error = "货币不足（需 %d，有 %d）" % [cost, gold]
		return null
	if roster.size() >= dorm_capacity():
		last_error = "宿舍已满（%d/%d）" % [roster.size(), dorm_capacity()]
		return null
	gold -= cost
	recruit_pool.candidates.remove_at(index)
	roster.append(candidate)
	return candidate

func upgrade_facility(facility_id: StringName) -> bool:
	## 设施升级（即时生效——案 3 §2.3 DEMO 口径）：校验等级<上限+余额足额 →
	## 扣款 → 等级+1
	## 参数 facility_id：设施 id（guild/facilities 域）
	## 返回：true = 升级成功
	last_error = ""
	var fac: FacilityDef = game_data.get_record(facility_id) as FacilityDef
	if fac == null:
		last_error = "设施定义缺失"
		return false
	var current_level: int = int(facility_levels.get(facility_id, 1))
	if current_level >= fac.max_level:
		last_error = "设施已满级（%d/%d）" % [current_level, fac.max_level]
		return false
	var cost: int = fac.levels[current_level].upgrade_cost
	if gold < cost:
		last_error = "货币不足（需 %d，有 %d）" % [cost, gold]
		return false
	gold -= cost
	facility_levels[facility_id] = current_level + 1
	return true

func facility_def(facility_id: StringName) -> FacilityDef:
	## 设施定义读取口（效果查询共用）
	## 参数 facility_id：设施 id
	## 返回：FacilityDef；查无返回 null
	return game_data.get_record(facility_id) as FacilityDef

func dorm_capacity() -> int:
	## 宿舍容量（当前等级效果——招募/名册上限约束；等级读值 clamp
	## [1, max_level]——D-2/Z2-12 防脏档越界）
	## 参数：无
	## 返回：容量值；表缺失回退 0（招募被拦截的保守口径）
	var fac: FacilityDef = facility_def(&"fac_dormitory")
	if fac == null:
		return 0
	var level: int = clampi(int(facility_levels.get(&"fac_dormitory", 1)), 1, fac.max_level)
	return fac.levels[level - 1].dorm_capacity

func injury_rest_days() -> int:
	## 重伤休养天数（基础 cfg − 宿舍当前级缩减，下限 1——案 17 §3.5；
	## 等级读值 clamp [1, max_level]——D-2/Z2-12）
	## 参数：无
	## 返回：天数
	var fac: FacilityDef = facility_def(&"fac_dormitory")
	var reduction: int = 0
	if fac != null:
		var level: int = clampi(int(facility_levels.get(&"fac_dormitory", 1)), 1, fac.max_level)
		reduction = fac.levels[level - 1].rest_days_reduction
	return maxi(1, cfg.injury_rest_days - reduction)

func bench_share_rate() -> float:
	## 训练场板凳经验分享率（当前等级效果——Lv1 0.3 / Lv2 0.4；
	## 等级读值 clamp [1, max_level]——D-2/Z2-12）
	## 参数：无
	## 返回：分享率；表缺失回退 0（板凳无分享的保守口径）
	var fac: FacilityDef = facility_def(&"fac_training_ground")
	if fac == null:
		return 0.0
	var level: int = clampi(int(facility_levels.get(&"fac_training_ground", 1)),
			1, fac.max_level)
	return fac.levels[level - 1].bench_share_rate

# --------------------------------------------------------------------------
# 快照序列化（GuildState provider 对接——payload[&"guild"]）
# --------------------------------------------------------------------------

func to_snapshot() -> Dictionary:
	## 公会快照序列化（SaveManager provider 收集；JSON 化——StringName 转_String）
	## 参数：无
	## 返回：含全运行态的 Dictionary（String 键）
	var plain_facilities: Dictionary = {}
	for fac_id: StringName in facility_levels:
		plain_facilities[String(fac_id)] = int(facility_levels[fac_id])
	var plain_roster: Array = []
	for adv: AdventurerData in roster:
		plain_roster.append(adv.to_dict())
	var plain_party_memory: Dictionary = {}
	for tpl_key: String in last_party_by_tpl:
		var member_ids: Array[StringName] = last_party_by_tpl[tpl_key]
		var plain_ids: PackedStringArray = PackedStringArray()
		for member_id: StringName in member_ids:
			plain_ids.append(String(member_id))
		plain_party_memory[tpl_key] = plain_ids
	var plain_pending: Dictionary = {}
	for unit_key: String in pending_tendency_levels:
		plain_pending[unit_key] = int(pending_tendency_levels[unit_key])
	return {
		"day": day,
		"gold": gold,
		"reputation": reputation,
		"board": board.to_snapshot(),
		"recruit_pool": recruit_pool.to_snapshot(),
		"facility_levels": plain_facilities,
		"roster": plain_roster,
		"last_party_by_tpl": plain_party_memory,
		"pending_tendency_levels": plain_pending,
		"has_unseen_grants": has_unseen_grants,
	}

func restore_snapshot(data: Dictionary) -> void:
	## 公会快照恢复（load_game provider 回放——全字段重建；结构问题由
	## schema_version 前置拦截，本口只做容错：缺键回退默认）
	## 参数 data：to_snapshot 产出的 Dictionary（JSON 桥数字为 float——统一 int 化）
	## 返回：无
	day = int(data.get("day", 1))
	gold = int(data.get("gold", 0))
	reputation = int(data.get("reputation", 0))
	board.restore_snapshot(data.get("board", {}))
	recruit_pool.restore_snapshot(data.get("recruit_pool", {}))
	facility_levels.clear()
	for fac_key: String in data.get("facility_levels", {}):
		facility_levels[StringName(fac_key)] = int(data["facility_levels"][fac_key])
	roster.clear()
	for member_data: Dictionary in data.get("roster", []):
		var adv: AdventurerData = AdventurerData.from_dict(member_data)
		if adv != null:
			roster.append(adv)
	last_party_by_tpl.clear()
	for tpl_key: String in data.get("last_party_by_tpl", {}):
		var member_ids: Array[StringName] = []
		for member_key: String in data["last_party_by_tpl"][tpl_key]:
			member_ids.append(StringName(member_key))
		last_party_by_tpl[tpl_key] = member_ids
	pending_tendency_levels.clear()
	for unit_key: String in data.get("pending_tendency_levels", {}):
		pending_tendency_levels[unit_key] = int(data["pending_tendency_levels"][unit_key])
	# M4-1：未查看挂单标记（v2 内加可选字段——旧档缺省 false，不升 schema）
	has_unseen_grants = bool(data.get("has_unseen_grants", false))
