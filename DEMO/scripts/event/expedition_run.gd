## 出征运行态（ExpeditionRun，RefCounted 纯逻辑类）
## 职责：一次事件会话（M2 演示=一次出征）的队伍状态与累计产出——HP/倒地/
## 耗时/奖励累计/已授予委托/已消耗事件/解锁标记；战斗结果回写；
## M3 扩展：探索会话上下文（地图/小队格位/迷雾/随机遭遇计数/委托判据）。
## 数据来源：案 8 §2（事件消耗/耗时口径）；案 18 §3.4（损耗排除倒地+下限 1）；
## 案 17 §3.10（base_days——M3 起唯一权威 = ExploreMapDef.base_expedition_days）。
## 纯逻辑约束：不触任何 autoload；**不入存档**（演示会话态——M4 出征层
## 落地时随 schema 升版，当前 schema_version 不动）。
## M2 兼容：新增字段全默认值（fog 为 null / party_pos 哨兵 (-1,-1) /
## goal_kind -1）——事件演示宿主等 M2 用例零感知。
class_name ExpeditionRun
extends RefCounted

## 探索耗时基准（天——M2 无图会话默认；有图会话由 map_def 注入覆盖）
const BASE_DAYS: int = 1
## 未进入探索图的小队格位哨兵
const NO_CELL: Vector2i = Vector2i(-1, -1)

## 出战队伍（AdventurerData 列表——顺序即队伍序）
var party: Array = []
## 队员当前 HP（AdventurerData -> int；键拷贝自 build 时快照）
var hp: Dictionary = {}
## 倒地成员集合（AdventurerData -> true；D14 排除后续损耗）
var downed: Dictionary = {}
## 基准耗时（天，默认 1；探索会话 = map_def.base_expedition_days）
var base_days: int = BASE_DAYS
## 事件累计额外耗时（天）
var extra_days: int = 0
## 累计奖励（exp/gold/reputation 三键）
var rewards: Dictionary = {&"exp": 0, &"gold": 0, &"reputation": 0}
## 已授予委托 id 列表（防重——18-C6）
var granted_quests: Array[StringName] = []
## 已消耗事件 id 集合（单次出征单次消耗）
var consumed_events: Dictionary = {}
## 解锁标记（id -> true；C/D 出口拦截与暗门 unlock_flag 消费）
var unlock_flags: Dictionary = {}

# ---- M3 探索会话扩展（全默认值——M2 旧用例零感知）----
## 探索图 id（map/maps 域；空 = M2 无图事件会话）
var map_id: StringName = &""
## 小队所在格（NO_CELL = 未进入探索图）
var party_pos: Vector2i = NO_CELL
## 战争迷雾（已探索集合单源在 fog 内——run 不重复存；null = 未进入探索图）
var fog: FogOfWar = null
## 本出征随机遭遇已触发次数（战败不回退——EncounterJudge 上限拦截消费）；
## W2-12 登记注：计数为**全图单值不分区**——多区域（各 encw_ 独立上限/独立
## 计数）需求出现时须改为 {region_id: int}，DEMO 单矿洞区 + chance 0 未触达，归 M4
var random_encounters_fired: int = 0
## 本次出征承接的委托模板 id（空 = 无委托自由探索）
var quest_template_id: StringName = &""
## 判据类型（QuestTemplateDef.GoalType 快照；-1 = 无判据）
var goal_kind: int = -1
## 判据参数（tp_ / enc_——按 goal_kind 取义）
var goal_param: StringName = &""
## 判据达成标记（会话终局口径：出口交付=成功/撤退战败=失败——通道类型判定）
var goal_done: bool = false
## 本会话已踏入格集合（Vector2i -> true——随机遭遇「新格」判定单源）
var visited_cells: Dictionary = {}

func total_days() -> int:
	## 总耗时申报（M4 出征结算预埋口）：基准 + 事件累计
	## 参数：无
	## 返回：天数
	return base_days + extra_days

func add_reward(exp: int, gold: int, reputation: int) -> void:
	## 累计奖励
	## 参数 exp/gold/reputation：本次增量
	## 返回：无
	rewards[&"exp"] = int(rewards[&"exp"]) + exp
	rewards[&"gold"] = int(rewards[&"gold"]) + gold
	rewards[&"reputation"] = int(rewards[&"reputation"]) + reputation

func apply_party_damage(delta: int) -> void:
	## 队伍损耗（案 18 §3.4）：负 delta 直扣——**排除已倒地成员（D14）**、
	## 未倒地扣至最低 1 止不归零（探索层无倒地口径——案 9/5）
	## 参数 delta：HP 变化（负数=损耗）
	## 返回：无
	if delta >= 0:
		return
	for adv: AdventurerData in party:
		if downed.get(adv, false):
			continue
		var current: int = int(hp.get(adv, 1))
		hp[adv] = maxi(1, current + delta)

func apply_battle_result(end_stats: Array) -> void:
	## 战斗结果回写（B 出口战后）：按 end_stats 的 end_hp/downed 回写 HP 与
	## 倒地集合——战斗层 0 血倒地口径如实带回（区别于探索层损耗下限 1）
	## 参数 end_stats：BattleResult.end_stats（{unit_id/end_hp/downed} 列表）
	## 返回：无
	var by_id: Dictionary = {}
	for adv: AdventurerData in party:
		by_id[adv.unit_id] = adv
	for entry: Dictionary in end_stats:
		var adv: AdventurerData = by_id.get(StringName(str(entry.get(&"unit_id", ""))), null)
		if adv == null:
			continue
		var end_hp: int = int(entry.get(&"end_hp", 1))
		var is_downed: bool = bool(entry.get(&"downed", false))
		if is_downed or end_hp <= 0:
			downed[adv] = true
			hp[adv] = 0
		else:
			hp[adv] = end_hp

func grant_quest(quest_id: StringName) -> bool:
	## 授予委托（防重——18-C6：同模板已挂单不重复授予）
	## 参数 quest_id：委托模板 id
	## 返回：true = 本次授予；false = 已在挂单（调用方播补叙文本）
	if granted_quests.has(quest_id):
		return false
	granted_quests.append(quest_id)
	return true

func start_explore(map_def: ExploreMapDef, quest_tpl: QuestTemplateDef,
		vision_radius: int) -> void:
	## 探索会话装配（M3）：建立迷雾（半径注入——cfg.vision_radius 表值由
	## 宿主传入）、小队落出生格、耗时基准改由 map_def.base_expedition_days
	## 注入（表值唯一权威）、判据上下文读模板；暗门揭示状态不新增字段
	## （一次性 = consumed_events、揭示态经 ExploreMapState._revealed +
	## unlock_flags 防双源）。
	## V-2（2026-09-26 审计）：**不做初始视野揭示**——run 侧建迷雾时墙体
	## 遮挡探针（is_opaque）尚未装配，此处 on_moved 会以纯圆揭示白得墙后格
	## DIM；初始揭示移至 explore_screen 挂接 set_opaque_probe 之后统一执行
	## （两条入口 guild_shell._StartExpedition / _MakeDefaultRun 均经屏 _ready
	## 覆盖）；visited_cells 首格登记与视野分离不受影响
	## 参数 map_def：探索图定义；quest_tpl：承接委托模板（null = 无委托
	## 自由探索）；vision_radius：视野半径（格——cfg.vision_radius）
	## 返回：无
	map_id = map_def.id
	base_days = map_def.base_expedition_days
	fog = FogOfWar.new()
	fog.setup(vision_radius, map_def.fog_lit_rows, map_def.size)
	party_pos = map_def.start_cell
	visited_cells.clear()
	visited_cells[party_pos] = true
	random_encounters_fired = 0
	goal_done = false
	if quest_tpl != null:
		quest_template_id = quest_tpl.id
		goal_kind = quest_tpl.goal_type
		goal_param = quest_tpl.goal_param
	else:
		quest_template_id = &""
		goal_kind = -1
		goal_param = &""

func build_hp_overrides() -> Dictionary:
	## 我方 HP 覆写表构建（单源方法——M3 收口：倒地过滤 + 对象键 → unit_id
	## 键 + 缺键 push_warning 按 1 兜底；EventRunner.build_battle_params 与
	## 遭遇战路由共用本口，M2 行为等价）
	## 参数：无
	## 返回：{unit_id: int}（倒地成员不带入——案 18「倒地保持至回城」）
	var hp_map: Dictionary = {}
	for adv: AdventurerData in party:
		if downed.get(adv, false):
			continue
		if not hp.has(adv):
			# E2-11 护栏：缺键告警（按 1 兜底——宿主漏初始化可感知）
			push_warning("ExpeditionRun: run.hp 缺键（%s）——按 1 兜底" % adv.unit_id)
		hp_map[adv.unit_id] = hp.get(adv, 1)
	return hp_map
