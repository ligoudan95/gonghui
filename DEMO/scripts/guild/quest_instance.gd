## 委托实例（QuestInstance，RefCounted 纯逻辑类）
## 职责：单份委托的运行态——模板引用、执行状态机（板上/已接/进行中）、
## 到期线、编队人力占用与「加急·」前缀标记；快照序列化桥 to_dict/from_dict。
## 数据来源：案 6 §2.2/§2.4（运转规则、执行状态机、占用起点=编队确认 D6）；
## 案 18 §2.6（替换表现：加急前缀+时限 3+奖励不变）。
## 纯逻辑约束：不触任何 autoload——game_data 经参数注入。
class_name QuestInstance
extends RefCounted

## 执行状态机（案 6 §2.4：板上可接 → 已接（未出征）→ 出征进行中 → 结算移除；
## 已接 →(到期/放弃) 移除；M4 增补批尾追加 LIGHT_RUNNING 轻度进行中——
## 派人即开工、工期挂日结算推进，0-2 原序号不动）
enum State {
	ON_BOARD,
	ACCEPTED,
	IN_PROGRESS,
	LIGHT_RUNNING,
}

## 实例序号（全板唯一，QuestBoard.serial 递增发放；持久于公会快照）
var serial: int = 0
## 模板 id（quest/templates 域）
var template_id: StringName = &""
## 执行状态
var state: State = State.ON_BOARD
## 到期线（CalendarCore.expire_day 口径——上板/授予日 + 时限，不含当日）
var expire_day: int = 0
## 编队成员 id 列表（人力占用起点=编队确认——挂单期即占用、随重编队转移、
## 进行中锁定，案 6 D6；事件授予直入挂单时空编队、经重编队口指派）
var party_ids: Array[StringName] = []
## 加急前缀标记（到期表现=替换时生成的新实例——「加急·」前缀+时限走
## cfg.quest_replace_time_limit+奖励不变）
var urgent: bool = false
## 轻度委托剩余工期（LIGHT_RUNNING 态——start_light 初始化为模板 duration_days，
## 日结算 quest_noncombat_advance 步递减、归零自动结算移除；v3 快照必填键）
var work_days_left: int = 0

func display_name(game_data: Node) -> String:
	## 展示名（加急实例带「加急·」前缀；轻度（exec_class==NON_COMBAT）带
	## 「轻度·」前缀——两前缀可叠加；模板查无回退 id 字面量）
	## 参数 game_data：GameData（参数注入）
	## 返回：展示名
	var tpl: QuestTemplateDef = game_data.get_record(template_id) as QuestTemplateDef
	var base_name: String = tpl.display_name if tpl != null else String(template_id)
	var is_light: bool = tpl != null and tpl.exec_class == QuestTemplateDef.ExecClass.NON_COMBAT
	var prefix: String = ("加急·" if urgent else "") + ("轻度·" if is_light else "")
	return prefix + base_name

func remaining_days(current_day: int) -> int:
	## 剩余天数（正数=未到期；0 及以下=已到期——UI 倒计时展示）
	## 参数 current_day：当日天数
	## 返回：剩余天数
	return expire_day - current_day

func to_dict() -> Dictionary:
	## 序列化为可 JSON 化的 Dictionary（StringName 统一转 String）
	## 参数：无
	## 返回：含全字段的 Dictionary（String 键）
	var plain_party: PackedStringArray = PackedStringArray()
	for member_id: StringName in party_ids:
		plain_party.append(String(member_id))
	return {
		"serial": serial,
		"template_id": String(template_id),
		"state": state,
		"expire_day": expire_day,
		"party_ids": plain_party,
		"urgent": urgent,
		"work_days_left": work_days_left,
	}

static func from_dict(data: Dictionary) -> QuestInstance:
	## 反序列化（存档快照 JSON 桥）：键齐备 + 类型校验，异常返回 null
	## 参数 data：JSON.parse_string 产出的 Dictionary
	## 返回：QuestInstance；校验失败返回 null
	for key: String in ["serial", "template_id", "state", "expire_day", "party_ids", "urgent",
			"work_days_left"]:
		if not data.has(key):
			return null
	if not SaveData.IsIntLike(data["serial"]) or not SaveData.IsIntLike(data["state"]) \
			or not SaveData.IsIntLike(data["expire_day"]) \
			or not SaveData.IsIntLike(data["work_days_left"]) \
			or int(data["work_days_left"]) < 0:
		# v3 必填口径：work_days_left 缺键/非整数/负值 → null（容错跳过不崩）
		return null
	if not (data["party_ids"] is Array) and not (data["party_ids"] is PackedStringArray):
		return null
	if not (data["urgent"] is bool):
		return null
	# S3-R3-01：template_id 类型校验（六必填键中唯一漏网——脏档拒载）
	if not (data["template_id"] is String):
		return null
	var state_value: int = int(data["state"])
	if state_value < 0 or state_value >= State.size():
		return null
	var inst := QuestInstance.new()
	inst.serial = int(data["serial"])
	inst.template_id = StringName(String(data["template_id"]))
	inst.state = state_value as State
	inst.expire_day = int(data["expire_day"])
	# S3-05：元素级容错——无类型迭代 + is String 过滤跳过坏元素（手改档
	# party_ids 混入非串不再中断整条 restore 链；与实例损坏条目跳过口径对齐）
	var typed_party: Array[StringName] = []
	for member_key: Variant in data["party_ids"]:
		if member_key is String:
			typed_party.append(StringName(member_key))
	inst.party_ids = typed_party
	inst.urgent = bool(data["urgent"])
	inst.work_days_left = int(data["work_days_left"])
	return inst
