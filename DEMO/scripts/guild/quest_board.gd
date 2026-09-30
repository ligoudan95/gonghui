## 委托板（QuestBoard，RefCounted 纯逻辑类）
## 职责：委托板运转与实例状态机——开局预生成/周刷新抽池（板刷池 11 不放回抽 3
##（M4 增补批 8 战斗+3 轻度混刷）、
## 同批不重复、跨周重置）、板上到期三表现（刷新补位/消失/替换）、挂单到期自动
## 失败、接取/重编队/出征/放弃的状态迁移与人力占用口径。
## 数据来源：案 6 §2.2（运转规则定稿）/§2.4（执行结构与占用 D6）；
## 案 2 §2.4 第 7 步（周刷新日跳过板上到期处理）/§2.5（挂单到期失败）；
## 案 18 §2.6（板刷 8 模板与三表现配比）。
## 纯逻辑约束：不触任何 autoload——cfg/game_data/rng 注入；编队合法性校验
## （成员存在/健康/占用）在 GuildCore 门面层，本类只管状态迁移与抽池。
class_name QuestBoard
extends RefCounted

## 板上实例（ON_BOARD）
var board: Array[QuestInstance] = []
## 挂单实例（ACCEPTED + IN_PROGRESS——事件授予直入挂单）
var accepted: Array[QuestInstance] = []
## 实例序号发生器（持久于公会快照 quest_serial）
var serial: int = 1
## 总控配置（注入）
var cfg: CoreConfig
## 数据源（注入）
var game_data: Node
## 随机源（注入——测试确定性）
var rng: RandomNumberGenerator

func setup(cfg: CoreConfig, game_data: Node, rng: RandomNumberGenerator) -> void:
	## 依赖注入（GuildCore.setup 装配；测试同入口）
	## 参数 cfg/game_data/rng：总控配置 / GameData / 随机源
	## 返回：无
	self.cfg = cfg
	self.game_data = game_data
	self.rng = rng

func board_template_ids() -> Array[StringName]:
	## 板刷池全集（quest/templates 域 acquire_channel == BOARD 的模板——
	## 事件授予专用不入池，18-C3）
	## 参数：无
	## 返回：板刷模板 id 列表
	var result: Array[StringName] = []
	for tpl_id: StringName in game_data.get_domain_ids(&"quest/templates"):
		var tpl: QuestTemplateDef = game_data.get_record(tpl_id) as QuestTemplateDef
		if tpl != null and tpl.acquire_channel == QuestTemplateDef.AcquireChannel.BOARD:
			result.append(tpl_id)
	return result

func draw_unique(count: int, exclude: Array[StringName] = []) -> Array[StringName]:
	## 板刷池不放回抽取：抽 count 个互不重复且不在 exclude 内的模板
	##（同批不重复/不与在板重复共用本口；每次抽取自全池重洗——跨周重置口径）
	## 参数 count：抽取数；exclude：排除模板（如在板模板 id）
	## 返回：抽中的模板 id 列表（池不足时取到为止）
	var pool: Array[StringName] = []
	for tpl_id: StringName in board_template_ids():
		if not exclude.has(tpl_id):
			pool.append(tpl_id)
	# Array.shuffle 走全局随机源不可注入——注入 rng 的确定性洗牌经 _Shuffle 承载
	_ShufflePool(pool)
	var drawn: Array[StringName] = []
	for tpl_id: StringName in pool:
		if drawn.size() >= count:
			break
		drawn.append(tpl_id)
	return drawn

func _ShufflePool(pool: Array[StringName]) -> void:
	## 注入随机源的洗牌（Fisher-Yates——Array.shuffle 走全局源不可注入，
	## 确定性测试须经本口）
	## 参数 pool：待洗模板池（原地打乱）
	## 返回：无
	for index: int in range(pool.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temp: StringName = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = temp

func spawn_on_board(template_id: StringName, day: int, urgent: bool = false,
		time_limit_override: int = -1) -> QuestInstance:
	## 生成板上实例（到期线=上板日+模板时限；urgent 替换实例走 override 时限）
	## 参数 template_id：模板 id；day：上板日；urgent：加急前缀标记；
	## time_limit_override：替换实例时限（-1=走模板时限）
	## 返回：新 QuestInstance（已入 board）
	var tpl: QuestTemplateDef = game_data.get_record(template_id) as QuestTemplateDef
	var time_limit: int = tpl.time_limit_days if tpl != null else 1
	if time_limit_override > 0:
		time_limit = time_limit_override
	var inst := QuestInstance.new()
	inst.serial = serial
	serial += 1
	inst.template_id = template_id
	inst.state = QuestInstance.State.ON_BOARD
	inst.expire_day = CalendarCore.expire_day(day, time_limit)
	inst.urgent = urgent
	board.append(inst)
	return inst

func initial_fill(day: int) -> void:
	## 开局预生成（案 6 §2.2 第四轮拍板组方案 A）：不依赖周刷新、开局日=周 1、
	## 当日不触发周刷新；抽 quest_week_draw 个上板（与周刷新同池同规则）
	## 参数 day：开局日（=1）
	## 返回：无
	board.clear()
	for tpl_id: StringName in draw_unique(cfg.quest_week_draw):
		spawn_on_board(tpl_id, day)

func accepted_template_ids() -> Array[StringName]:
	## 挂单模板集合（G-2 源头防并存——抽池排除项：板不与挂单同模板，
	## 「同批不重复」精神的延伸）
	## 参数：无
	## 返回：挂单实例的模板 id 列表
	var result: Array[StringName] = []
	for inst: QuestInstance in accepted:
		if not result.has(inst.template_id):
			result.append(inst.template_id)
	return result

func week_refresh(day: int) -> Array[QuestInstance]:
	## 周刷新（每周第 1 天日结算）：清板上全部未接、生成新一批（整池重抽、
	## 同批不重复、跨周重置；**排除挂单模板**——G-2 板不与挂单同模板并存）
	## 参数 day：当日天数
	## 返回：被清下的旧板上实例
	var cleared: Array[QuestInstance] = board.duplicate()
	board.clear()
	for tpl_id: StringName in draw_unique(cfg.quest_week_draw, accepted_template_ids()):
		spawn_on_board(tpl_id, day)
	return cleared

func settle_expirations(day: int) -> Dictionary:
	## 日结算委托步：周刷新日→整板重抽（跳过板上到期表现处理）；否则板上到期
	## 者按模板 expire_behavior 三表现处理；**并行**挂单到期→自动失败（移除+释放
	## 人力——party_ids 随实例移除即释放）
	## 参数 day：当日天数（day_advance 之后的值）
	## 返回：{week_refreshed: bool, board_removed: [String], board_refreshed: [String],
	##	board_replaced: [String], accepted_failed: [String]}（明细模板 id）
	var result: Dictionary = {
		&"week_refreshed": false,
		&"board_removed": [],
		&"board_refreshed": [],
		&"board_replaced": [],
		&"accepted_failed": [],
	}
	if CalendarCore.is_week_refresh_day(day, cfg.calendar_week_days):
		week_refresh(day)
		result[&"week_refreshed"] = true
	else:
		_SettleBoardExpirations(day, result)
	# 挂单到期失败照常（周刷新日不跳过——案 2 §2.5 口径）；LIGHT_RUNNING 轻度
	# 进行中**跳过**（最高风险拦截点：防原板上 5 天时限线误杀进行中轻度——
	# 轻度生命周期唯一权威=work_days_left 归零自动结算，不经到期线）
	for inst: QuestInstance in accepted.duplicate():
		if inst.state == QuestInstance.State.LIGHT_RUNNING:
			continue
		if CalendarCore.is_expired(day, inst.expire_day):
			accepted.erase(inst)
			result[&"accepted_failed"].append(String(inst.template_id))
	return result

func _SettleBoardExpirations(day: int, result: Dictionary) -> void:
	## 板上到期三表现处理（周刷新日不进入本口）
	## 参数 day：当日天数；result：settle_expirations 汇总字典（原地写明细）
	## 返回：无
	for inst: QuestInstance in board.duplicate():
		if not CalendarCore.is_expired(day, inst.expire_day):
			continue
		var tpl: QuestTemplateDef = game_data.get_record(inst.template_id) as QuestTemplateDef
		var behavior: int = tpl.expire_behavior if tpl != null \
				else QuestTemplateDef.ExpireBehavior.VANISH
		board.erase(inst)
		result[&"board_removed"].append(String(inst.template_id))
		match behavior:
			QuestTemplateDef.ExpireBehavior.REFRESH:
				# 刷新：移除+板刷池重抽补位、不与在板**及挂单**模板重复（同批不重复
				# 规则——G-2 源头防并存：排除项并入挂单模板）
				var on_board: Array[StringName] = []
				for staying: QuestInstance in board:
					on_board.append(staying.template_id)
				for accepted_tpl: StringName in accepted_template_ids():
					if not on_board.has(accepted_tpl):
						on_board.append(accepted_tpl)
				for tpl_id: StringName in draw_unique(1, on_board):
					spawn_on_board(tpl_id, day)
					result[&"board_refreshed"].append(String(tpl_id))
			QuestTemplateDef.ExpireBehavior.REPLACE:
				# 替换：同模板新实例「加急·」前缀+时限走 cfg+奖励不变（同模板即同奖励）
				spawn_on_board(inst.template_id, day, true, cfg.quest_replace_time_limit)
				result[&"board_replaced"].append(String(inst.template_id))
			QuestTemplateDef.ExpireBehavior.VANISH:
				# 消失：仅移除（允许板空——#10）
				pass

func accept(inst: QuestInstance, party_ids: Array[StringName]) -> bool:
	## 接取（编队确认）：ON_BOARD → ACCEPTED，占用起点即本次编队
	##（合法性校验在 GuildCore 门面；接取不补位——案 6 §2.2）
	## 参数 inst：板上实例；party_ids：编队成员 id
	## 返回：true = 迁移成功
	if inst.state != QuestInstance.State.ON_BOARD or not board.has(inst):
		return false
	board.erase(inst)
	inst.state = QuestInstance.State.ACCEPTED
	inst.party_ids = party_ids.duplicate()
	accepted.append(inst)
	return true

func reassign(inst: QuestInstance, party_ids: Array[StringName]) -> bool:
	## 重编队（挂单期可重编队、占用随编队转移；进行中锁定不可换——案 6 D6）
	## 参数 inst：挂单实例；party_ids：新编队成员 id
	## 返回：true = 转移成功
	if inst.state != QuestInstance.State.ACCEPTED or not accepted.has(inst):
		return false
	inst.party_ids = party_ids.duplicate()
	return true

func start(inst: QuestInstance) -> bool:
	## 出征确认：ACCEPTED → IN_PROGRESS（进行中锁定；出征频次/进行中上限
	## 校验在 GuildCore 门面）
	## 参数 inst：挂单实例
	## 返回：true = 迁移成功
	if inst.state != QuestInstance.State.ACCEPTED or not accepted.has(inst):
		return false
	inst.state = QuestInstance.State.IN_PROGRESS
	return true

func start_light(inst: QuestInstance) -> bool:
	## 轻度开工（M4 增补批）：ACCEPTED → LIGHT_RUNNING + work_days_left 初始化
	## 为模板 duration_days（一步开工——校验在 GuildCore 门面 start_light_quest）
	## 参数 inst：挂单实例
	## 返回：true = 迁移成功；模板查无/态不符返回 false
	if inst.state != QuestInstance.State.ACCEPTED or not accepted.has(inst):
		return false
	var tpl: QuestTemplateDef = game_data.get_record(inst.template_id) as QuestTemplateDef
	if tpl == null or tpl.duration_days < 1:
		return false
	inst.state = QuestInstance.State.LIGHT_RUNNING
	inst.work_days_left = tpl.duration_days
	return true

func remove(inst: QuestInstance) -> void:
	## 结算/放弃移除（五出口终态统一口：成功/战败/撤退/判据失败/到期/放弃——
	## 移除即释放人力占用）
	## 参数 inst：目标实例
	## 返回：无
	board.erase(inst)
	accepted.erase(inst)

func find_on_board(serial_id: int) -> QuestInstance:
	## 按序号取板上实例
	## 参数 serial_id：实例序号
	## 返回：QuestInstance；不在板返回 null
	for inst: QuestInstance in board:
		if inst.serial == serial_id:
			return inst
	return null

func find_accepted(serial_id: int) -> QuestInstance:
	## 按序号取挂单实例（ACCEPTED + IN_PROGRESS）
	## 参数 serial_id：实例序号
	## 返回：QuestInstance；不在挂单返回 null
	for inst: QuestInstance in accepted:
		if inst.serial == serial_id:
			return inst
	return null

func find_accepted_by_template(template_id: StringName) -> QuestInstance:
	## 按模板 id 取挂单实例（回城结算与授予防重消费——同模板同时至多一份挂单）
	## 参数 template_id：模板 id
	## 返回：QuestInstance；无返回 null
	for inst: QuestInstance in accepted:
		if inst.template_id == template_id:
			return inst
	return null

func find_in_progress_by_template(template_id: StringName) -> QuestInstance:
	## 按模板 id 取 **IN_PROGRESS** 挂单实例（G-2 结算匹配第二优先级——
	## 同模板 ACCEPTED+IN_PROGRESS 并存时结算应命中出征中实例）
	## 参数 template_id：模板 id
	## 返回：QuestInstance；无返回 null
	for inst: QuestInstance in accepted:
		if inst.template_id == template_id \
				and inst.state == QuestInstance.State.IN_PROGRESS:
			return inst
	return null

func grant_to_accepted(template_id: StringName, day: int) -> QuestInstance:
	## 事件授予直入挂单（C8 端口——不占板上槽位、不走上板；时限=授予日+模板时限，
	## 出征中日历冻结、回城日即授予语义日）
	## 参数 template_id：模板 id；day：授予日（回城结算日）
	## 返回：新 QuestInstance（ACCEPTED、空编队——经重编队口指派）
	var tpl: QuestTemplateDef = game_data.get_record(template_id) as QuestTemplateDef
	var inst := QuestInstance.new()
	inst.serial = serial
	serial += 1
	inst.template_id = template_id
	inst.state = QuestInstance.State.ACCEPTED
	inst.expire_day = CalendarCore.expire_day(day, tpl.time_limit_days if tpl != null else 7)
	accepted.append(inst)
	return inst

func in_progress_count() -> int:
	## 进行中实例数（战斗委托同时 1 个上限的判定口——#23）
	## 参数：无
	## 返回：IN_PROGRESS 实例数
	var count: int = 0
	for inst: QuestInstance in accepted:
		if inst.state == QuestInstance.State.IN_PROGRESS:
			count += 1
	return count

func occupied_member_ids(exclude_inst: QuestInstance = null) -> Array[StringName]:
	## 人力占用查询（挂单+进行中全部实例的编队并集——占用起点=编队确认 D6）
	## 参数 exclude_inst：排除实例（重编队校验时排除自身旧编队）
	## 返回：被占用成员 id 列表
	var result: Array[StringName] = []
	for inst: QuestInstance in accepted:
		if inst == exclude_inst:
			continue
		for member_id: StringName in inst.party_ids:
			if not result.has(member_id):
				result.append(member_id)
	return result

func to_snapshot() -> Dictionary:
	## 快照序列化（GuildCore.to_snapshot 组装）
	## 参数：无
	## 返回：{serial, board: [dict], accepted: [dict]}
	var plain_board: Array = []
	for inst: QuestInstance in board:
		plain_board.append(inst.to_dict())
	var plain_accepted: Array = []
	for inst: QuestInstance in accepted:
		plain_accepted.append(inst.to_dict())
	return {
		"serial": serial,
		"board": plain_board,
		"accepted": plain_accepted,
	}

func restore_snapshot(data: Dictionary) -> void:
	## 快照恢复（键缺失或实例损坏时保守清空对应槽——存档结构问题在
	## SaveManager 层已由 schema_version 拦截，此处只做容错重建；
	## **容器类型不符保守清空**（S3-M2 拍板——board/accepted 被破坏成
	## Dictionary/标量时不再 SCRIPT ERROR，清空重建、读档可继续）；
	## S3-05：serial 跨容器查重（board+accepted 共用 seen 集——同 serial 双
	## 实例会让 find_on_board/find_accepted 首匹配定位歧义，重复按损坏条目
	## 跳过，对齐 guild_core roster 口径）
	## 参数 data：to_snapshot 产出的 Dictionary
	## 返回：无
	board.clear()
	accepted.clear()
	# S3-R4-02：serial 裸 int() 前置门卫（容器脏值中止 restore 链——回退默认 1）
	var raw_serial: Variant = data.get("serial", 1)
	var serial_value: int = int(raw_serial) if SaveData.IsIntLike(raw_serial) else 1
	var seen_serials: Dictionary = {}
	var board_data: Variant = data.get("board", [])
	if board_data is Array:
		for inst_data: Variant in board_data:
			if not (inst_data is Dictionary):
				continue
			var inst: QuestInstance = QuestInstance.from_dict(inst_data)
			if inst != null and not seen_serials.has(inst.serial):
				seen_serials[inst.serial] = true
				board.append(inst)
	var accepted_data: Variant = data.get("accepted", [])
	if accepted_data is Array:
		for inst_data: Variant in accepted_data:
			if not (inst_data is Dictionary):
				continue
			var inst: QuestInstance = QuestInstance.from_dict(inst_data)
			if inst != null and not seen_serials.has(inst.serial):
				seen_serials[inst.serial] = true
				accepted.append(inst)
	# S3-R5-01：serial 追平已恢复实例最大号 +1——脏 serial 回退 1 后发号会
	# 追平既有存活实例（find_on_board/find_accepted 首匹配定位歧义——
	# 玩家点新单接到旧实例、错单出征/放弃）
	var max_serial: int = 0
	for inst: QuestInstance in board:
		max_serial = maxi(max_serial, inst.serial)
	for inst: QuestInstance in accepted:
		max_serial = maxi(max_serial, inst.serial)
	serial = maxi(serial_value, max_serial + 1)
