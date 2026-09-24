## 状态定义（StatusDef）
## 职责：承载状态效果池（属性修正/持续伤害/控制/标记四类）的完整定义：
## 修正量表、DOT 参数、控制种类、持续时间与类型、叠加规则、互斥组、
## 允许来源、移除策略与图标。
## 数据来源：案 11《状态效果》（状态定义表全列）；案 17《数值专项案》
## §3.9（DEMO 状态池基准）/§3.11 #6（状态数值清单）。
## id 命名规范：status/stats 域沿用案 11/17 现行式样——大写类别前缀 + 小写
## 语义（如 DEBUFF_exposed、BUFF_ambush、DEBUFF_slow 式），文件名与 id 同名；
## 允许字符以定名表为准（批 2 落表时统一复核）。
class_name StatusDef
extends Resource

## 状态类别（属性修正 / 持续伤害 / 控制 / 标记）
enum Category {
	STAT_MOD,
	DOT,
	CONTROL,
	MARK,
}

## 状态极性（增益 / 减益）
enum Polarity {
	BUFF,
	DEBUFF,
}

## 控制种类（无 / 定身 / 蛊惑）
enum ControlKind {
	NONE,
	ROOT,
	BEWITCH,
}

## 持续时间类型（战斗内按回合 / 战斗结束移除 / 持久跨战斗）
enum DurationType {
	BATTLE_ROUND,
	BATTLE_OUT,
	PERSISTENT,
}

## 状态 id（如 &"DEBUFF_exposed"）
@export var id: StringName = &""
## 中文名（如「暴露减益」）
@export var display_name: String = ""
## 状态类别
@export var category: Category = Category.STAT_MOD
## 极性（增益/减益）
@export var polarity: Polarity = Polarity.DEBUFF
## 属性修正量表：StringName 属性/派生键 id -> float 修正值（如 &"dodge" -> -0.10）
@export var modifiers: Dictionary[StringName, float] = {}
## DOT 参数（category = DOT 时生效；跳伤不过减免轨，案 17 §3.4）
@export var dot: DotParams
## 控制种类（category = CONTROL 时生效）
@export var control_kind: ControlKind = ControlKind.NONE
## 默认持续回合数（技能效果 duration=0 时回退到此值）
@export var default_duration: int = 1
## 持续时间类型（战斗回合 / 战斗结束 / 持久）
@export var duration_type: DurationType = DurationType.BATTLE_ROUND
## 叠加规则标记（如 &"no_stack_take_larger" 同名不叠加取较大；批 2 与案 11 口径定名）
@export var stack_rule: StringName = &""
## 互斥组 id（同组状态互斥，见 status/mutex_groups 域；空 = 不参与互斥）
@export var mutex_group_id: StringName = &""
## 允许来源列表（**来源类别** token——S2-5 语义统一：元素取
## allowed_source_tokens() 全集之一（&"SKILL"/&"CHECKIN"/&"TILE"，
## 对应 StatusInstance.SourceKind 枚举），空数组 = 不限来源；
## 施加入口越类拒收）
@export var allowed_sources: Array[StringName] = []
## 移除策略标记（如回合结束/战斗结束/检定通过移除；批 2 与案 11 口径定名）；
## 合法值 = remove_policies() 全集之一（A-8 单源：StatusManager 消费口径与
## DataValidator 值域校验共引此处——常量提数据定义层避免 data→battle 反向依赖）
@export var remove_policy: StringName = &""
## 图标资源 id（路径经 assets 域 AssetRegistry 映射）
@export var icon_id: StringName = &""

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""

## 来源类别 -> 允许来源 token 映射（S2-5 + C-2 单源：allowed_sources 元素与
## StatusInstance.SourceKind 枚举的字符串契约——token 字面量只在 match 出现
## 一处，列表由 match 派生；新增来源类别只改本 match 一行）
static func source_kind_token(kind: int) -> StringName:
	## 参数 kind：StatusInstance.SourceKind 枚举值
	## 返回：对应 token；未知枚举返回空 StringName
	match kind:
		StatusInstance.SourceKind.SKILL:
			return &"SKILL"
		StatusInstance.SourceKind.TILE:
			return &"TILE"
		StatusInstance.SourceKind.CHECKIN:
			return &"CHECKIN"
		_:
			return &""

## 允许来源 token 全集（C-2：由 source_kind_token 派生——三处对齐单源）
static func allowed_source_tokens() -> Array[StringName]:
	## 参数：无
	## 返回：合法来源类别 token 全集
	var tokens: Array[StringName] = []
	for kind: int in [StatusInstance.SourceKind.SKILL, StatusInstance.SourceKind.TILE,
			StatusInstance.SourceKind.CHECKIN]:
		tokens.append(source_kind_token(kind))
	return tokens

## 离格移除策略 token（A-8 单源定义点：站位状态离格移除判据——
## StatusManager 消费 / DataValidator 值域校验共引）
const REMOVE_ON_LEAVE_TILE: StringName = &"on_leave_tile"

## 移除策略 token 值域（A-8：DataValidator REMOVE_POLICIES 同源取值）
static func remove_policies() -> Array[StringName]:
	## 参数：无
	## 返回：合法移除策略 token 全集
	return [REMOVE_ON_LEAVE_TILE]
