## 事件选项定义（EventOptionDef）
## 职责：单个节点的可选项——检定（CHECK）或纯选择（PURE）；去向 = 中间/
## 终端节点（*_to）或直接出口（*_outcome），两族互斥（V-M2-ref-graph 校验）。
## 数据来源：案 8 §2（检定骨架/两段式结构与纯选择）；案 18 §2.1-2.3（选项内容）。
## id 命名规范：event/options 域，opt_ 前缀，文件名与 id 同名。
class_name EventOptionDef
extends Resource

## 选项类别（检定 / 纯选择）
enum OptionKind {
	CHECK,
	PURE,
}

## 选项 id（如 &"opt_collapse_1"）
@export var id: StringName = &""
## 选项文本（动词开头 4-15 字——案 18 §3.2；UI 尾部自动拼检定标注）
@export var display_name: String = ""
## 类别（CHECK 走掷骰分流 / PURE 直进去向）
@export var kind: OptionKind = OptionKind.CHECK

# ---- 检定参数组（kind = CHECK 时生效）----
## 检定属性 id（七属性之一——V-M2 校验 ∈ AttrKeys）
@export var check_attr_id: StringName = &""
## 难度档名（存档名不存判定线——「极易/容易/普通/困难/极难」，运行时查
## cfg.difficulty_tiers；V-M2 校验 ∈ cfg 键集）
@export var difficulty_tier: String = ""

# ---- 去向（节点 *_to 与出口 *_outcome 两族互斥——同侧成对非空）----
## 成功去向节点 id（可空——与 success_outcome 互斥）
@export var success_to: StringName = &""
## 失败去向节点 id（可空——与 failure_outcome 互斥；PURE 选项只填 success_to）
@export var failure_to: StringName = &""
## 成功直接出口（可空——与 success_to 互斥）
@export var success_outcome: EventOutcomeDef
## 失败直接出口（可空——与 failure_to 互斥）
@export var failure_outcome: EventOutcomeDef

# ---- 四档修饰（可空——挂选项侧，结算时叠加）----
## 大成功修饰（额外发现型——案 18 §3.3）
@export var crit_modifier: EventModifierDef
## 大失败修饰（雪上加霜但不断路型）
@export var crit_fail_modifier: EventModifierDef

## 耗时代价（天——0 = 无；案 8 §2.6 耗时申报）
@export var cost_days: int = 0

## 显示条件（DEMO 空 = 恒显示；完整版条件表达式挂点）
@export var display_condition: String = ""

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
