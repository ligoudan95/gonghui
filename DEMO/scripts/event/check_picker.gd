## 检定改派候选器（CheckPicker，纯静态工具类）
## 职责：按检定属性生成候选人列表——调整值降序、同高队伍序在前、倒地剔除
## （D1）；默认改派取首名，空名单返回 null（事件层走 FAILURE 分支防死锁）。
## 数据来源：案 8 §2（自动取最高可改派+倒地排除）；案 17 §3.3（调整值口径）。
## 纯逻辑约束：不触任何 autoload——cfg 经参数注入。
class_name CheckPicker
extends RefCounted

static func candidates(party: Array, attr_id: StringName, cfg: CoreConfig,
		downed: Dictionary) -> Array:
	## 候选人生成：存活成员按「调整值降序 → 队伍序」排列
	## 参数 party：队伍 AdventurerData 列表；attr_id：检定属性；cfg：总控配置；
	## downed：倒地成员集合（Dictionary[AdventurerData, bool]——D1 剔除）
	## 返回：[{&"adv": AdventurerData, &"modifier": int, &"downed": bool}]（空队伍/全员倒地为空）
	var pool: Array = []
	for index: int in party.size():
		var adv: AdventurerData = party[index]
		if downed.get(adv, false):
			continue
		var entry: Dictionary = {
			&"adv": adv,
			&"modifier": BattleRules.attr_modifier(
					int(adv.attrs.get(attr_id, AttrKeys.DEFAULT_ATTR_VALUE)), cfg),
			&"downed": false,
			&"order": index,
		}
		pool.append(entry)
	pool.sort_custom(_CompareCandidates)
	return pool

static func default_pick(candidates: Array) -> AdventurerData:
	## 默认改派：候选首名（即最高调整值、同高队伍序最前）
	## 参数 candidates：candidates() 产物
	## 返回：默认人选；空名单返回 null（调用方走 FAILURE 分支防死锁）
	if candidates.is_empty():
		return null
	return candidates[0][&"adv"]

static func _CompareCandidates(a: Dictionary, b: Dictionary) -> bool:
	## 候选比较器：调整值降序 → 同高队伍序在前（稳定序由 order 键承载）
	## 参数 a/b：候选条目
	## 返回：true = a 排前
	if a[&"modifier"] != b[&"modifier"]:
		return a[&"modifier"] > b[&"modifier"]
	return a[&"order"] < b[&"order"]
