## 委托模板定义（QuestTemplateDef）
## 职责：委托板的模板行——目标（类型+参数）、人力区间、时限、奖励、获取渠道、
## 到期表现与推荐编队提示；M2 落事件授予 1 行（q_lost_miner_keepsake），
## M3 提前落板刷首行（q_lair_purge），M4 补齐板刷 8 行全量（案 18 §2.6 定稿）。
## 数据来源：案 6《委托与声望》（模板字段）；案 18 §2.3/§2.6（DEMO 内容）；
## 案 17 §3.7（超额加成口径——模板字段位，0=走 cfg 统一值，M4 主批拍板③）。
## id 命名规范：quest/templates 域，q_ 前缀，文件名与 id 同名。
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

## 板上到期表现（案 6 §2.2 三表现：刷新补位/移除/替换——挂单委托不适用本字段）
enum ExpireBehavior {
	REFRESH,
	VANISH,
	REPLACE,
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
## 可放弃（普通/事件授予=true 可弃；主线恒不可弃——案 6 §2.4 P2 拍板：
## 挂单可主动放弃、无惩罚无奖励；原注释「普通=false」系 M2 未启用期误注，
## M4 随放弃通道落地更正）
@export var abandonable: bool = false
## 失败可重试
@export var retry_on_fail: bool = false
## 稀有权重（0=常规——板刷稀有池权重）
@export var rare_weight: int = 0
## 板上到期表现（刷新=移除+板刷池补位不与在板重复 / 消失=仅移除 /
## 替换=同模板新实例「加急·」前缀+时限走 cfg quest_replace_time_limit+奖励不变；
## 事件授予模板不适用——挂单到期走自动失败通道）
@export var expire_behavior: ExpireBehavior = ExpireBehavior.REFRESH
## 推荐属性对（推荐编队提示——非强制；V-M4-quest-template 校验 ∈ 七属性）
@export var recommend_attrs: Array[StringName] = []
## 发布人（文案钩子——案 18 §2.6「谁托」；UI 委托卡展示）
@export var issuer: String = ""
## 委托描述（文案钩子——案 18 §2.6；UI 委托卡展示）
@export var description: String = ""
## 超额人数奖励加成率（每人 +本值；0 = 走 cfg 统一值 quest_excess_bonus_per_head
## ——M4 主批拍板③：模板字段位承载，仅货币+经验适用、声望不加；「M4 增补批
## 拍板③」另指设置界面双档分辨率——两轮拍板各自轮内序号）
@export var excess_bonus_per_head: float = 0.0
## 工期天数（M4 增补批：轻度委托——NON_COMBAT 派人即开工，工期挂日结算
## quest_noncombat_advance 步自动推进、期满自动结算；0 = 战斗模板未配置，
## ≥1 为轻度模板必配——V-M4-quest-template 执行大类互斥校验）
@export var duration_days: int = 0

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
