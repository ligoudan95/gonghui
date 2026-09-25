## 出征运行态（ExpeditionRun，RefCounted 纯逻辑类）
## 职责：一次事件会话（M2 演示=一次出征）的队伍状态与累计产出——HP/倒地/
## 耗时/奖励累计/已授予委托/已消耗事件/解锁标记；战斗结果回写。
## 数据来源：案 8 §2（事件消耗/耗时口径）；案 18 §3.4（损耗排除倒地+下限 1）；
## 案 17 §3.10（base_days 默认 1）。
## 纯逻辑约束：不触任何 autoload；**不入存档**（M2 演示会话态——M4 出征层
## 落地时随 schema 升版，当前 schema_version 不动）。
class_name ExpeditionRun
extends RefCounted

## 探索耗时基准（天——案 17 §3.10：出征 1 天起计）
const BASE_DAYS: int = 1

## 出战队伍（AdventurerData 列表——顺序即队伍序）
var party: Array = []
## 队员当前 HP（AdventurerData -> int；键拷贝自 build 时快照）
var hp: Dictionary = {}
## 倒地成员集合（AdventurerData -> true；D14 排除后续损耗）
var downed: Dictionary = {}
## 基准耗时（天，默认 1）
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
