## 委托模板定义（QuestTemplateDef）
## 职责：委托板的模板行——目标（类型+参数）、人力区间、时限、奖励与
## 获取渠道；M2 落事件授予 1 行（q_lost_miner_keepsake），板刷 8 行 M4 补。
## 数据来源：案 6《委托与声望》（模板字段）；案 18 §2.3/§2.6（DEMO 内容）。
## id 命名规范：quest/templates 域，q_ 前缀，文件名与 id 同名。
## M4 扩字段预留（E13 勘正——P-9 核心）：到期行为（到期表现/自动失败口径——
## 事件授予挂单不走板上到期表现）、关联链（委托与事件链/地图域关联引用）、
## 推荐编队（人力区间之外的属性/职业倾向提示）——落地时随案 6 增补+校验。
class_name QuestTemplateDef
extends Resource

## 委托类型（普通/稀有/主线/评估——稀有与主线走板刷权重和放弃限制差异）
enum QuestType {
	NORMAL,
	RARE,
	MAINLINE,
	ASSESS,
}

## 执行大类（战斗类/非战斗类——决定目标交互形态）
enum ExecClass {
	COMBAT,
	NON_COMBAT,
}

## 目标类型（清剿/探索/护送/收集——DEMO 用 clear/explore 两类）
enum GoalType {
	CLEAR,
	EXPLORE,
	ESCORT,
	COLLECT,
}

## 获取渠道（板刷/事件授予/剧情——18-C3：事件授予专用不入周刷新池）
enum AcquireChannel {
	BOARD,
	EVENT_GRANT,
	STORY,
}

## 委托 id（如 &"q_lost_miner_keepsake"）
@export var id: StringName = &""
## 中文名（如「没能回家的托米」）
@export var display_name: String = ""
## 委托类型
@export var quest_type: QuestType = QuestType.NORMAL
## 执行大类
@export var exec_class: ExecClass = ExecClass.COMBAT
## 等级档（DEMO 唯一档 1）
@export var level_tier: int = 1
## 目标类型
@export var goal_type: GoalType = GoalType.EXPLORE
## 目标参数（tp_ 交互点 id / enc_ 队伍 id——按 goal_type 取义；挂起规则：
## M3 地图域有记录后才校验存在性）
@export var goal_param: StringName = &""
## 目标区域 id（M3 地图层接线后校验；DEMO mine）
@export var region_id: StringName = &""
## 目标地图 id（可空=当前探索图；挂起规则同 goal_param）
@export var map_id: StringName = &""
## 需求人力下限
@export var party_min: int = 2
## 需求人力上限
@export var party_max: int = 4
## 时限（天——事件授予挂单时限不走板上到期表现）
@export var time_limit_days: int = 7
## 奖励（内嵌——金/经验/声望展示值）
@export var reward: RewardDef
## 获取渠道
@export var acquire_channel: AcquireChannel = AcquireChannel.BOARD
## 可放弃（普通=false 板刷口径反之；主线恒不可弃）
@export var abandonable: bool = false
## 失败可重试
@export var retry_on_fail: bool = false
## 稀有权重（0=常规——板刷稀有池权重）
@export var rare_weight: int = 0

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
