## 判据追踪器（GoalTracker，RefCounted 纯逻辑类）
## 职责：委托判据达成的双通道判定——EXPLORE 类（目标点交互）/ CLEAR 类
## （指定队伍战斗胜利）；达成一次即锁定（幂等）。
## 数据来源：案 6《委托与声望》（判据口径：clear/explore 两类）；
## M3 方案批 1。
## 纯逻辑约束：不触任何 autoload；goal 上下文（kind/param）setup 注入
## （来源 QuestTemplateDef，由宿主读表传参）。
class_name GoalTracker
extends RefCounted

## 判据类型（= QuestTemplateDef.GoalType 快照；-1 = 无判据会话）
var _goal_kind: int = -1
## 判据参数（tp_ 目标点 id / enc_ 队伍 id——按 kind 取义）
var _goal_param: StringName = &""
## 达成标记（一次锁定）
var _done: bool = false

func setup(goal_kind: int, goal_param: StringName) -> void:
	## 装配判据上下文（重复 setup 重置达成态）
	## 参数 goal_kind：QuestTemplateDef.GoalType（-1 = 无判据）；
	## goal_param：判据参数
	## 返回：无
	_goal_kind = goal_kind
	_goal_param = goal_param
	_done = false

func restore_done(done: bool) -> void:
	## 达成态回灌（M3 质检 H1）：跨战斗会话恢复——run.goal_done 为持久侧
	## 快照，宿主 _ready 经本口回灌（判定逻辑仍单源在本类，run 只存快照）
	## 参数 done：持久侧达成快照
	## 返回：无
	_done = done

func on_target_interacted(tp_id: StringName) -> bool:
	## 目标点交互通道：EXPLORE 类且 id 匹配 → 达成
	## 参数 tp_id：本次交互的目标点 id
	## 返回：true = 本次交互令判据达成
	if _done or _goal_kind != QuestTemplateDef.GoalType.EXPLORE:
		return false
	if tp_id != _goal_param:
		return false
	_done = true
	return true

func on_battle_victory(pack_id: StringName) -> bool:
	## 战斗胜利通道：CLEAR 类且队伍 id 匹配 → 达成
	## 参数 pack_id：本次战胜的敌方队伍 id
	## 返回：true = 本次胜利令判据达成
	if _done or _goal_kind != QuestTemplateDef.GoalType.CLEAR:
		return false
	if pack_id != _goal_param:
		return false
	_done = true
	return true

func is_done() -> bool:
	## 判据完成查询
	## 参数：无
	## 返回：true = 已达成（出口激活口径）
	return _done
