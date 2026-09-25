## 单点事件定义（SingleEventDef）
## 职责：无节点图、触发即结算的事件——村子轻事件与暗门检定事件
## （案 8 §3 已定稿结构）；检定可选（无检定=单档纯结算）。
## 数据来源：案 8 §3；案 18 §2.4-2.5（DEMO 三个单点内容）。
## id 命名规范：event/singles 域，sp_ 前缀，文件名与 id 同名。
class_name SingleEventDef
extends Resource

## 事件 id（如 &"sp_village_cart"）
@export var id: StringName = &""
## 中文名（如「陷进泥里的板车」）
@export var display_name: String = ""
## 叙述文本（触发即播——案 18 §3.1 口径）
@export var narrative_text: String = ""

# ---- 检定配置（可空——无检定单档结算，如井边的旅人）----
## 检定属性 id（可空 = 无检定）
@export var check_attr_id: StringName = &""
## 难度档名（有检定必填——档名口径同选项）
@export var difficulty_tier: String = ""
## 大成功修饰（可空——单点允许从简，案 18 §2.4 放宽）
@export var crit_modifier: EventModifierDef
## 大失败修饰（可空——同上）
@export var crit_fail_modifier: EventModifierDef

## 成功出口（无检定事件 = 单档出口）
@export var success_outcome: EventOutcomeDef
## 失败出口（可空——无检定事件无失败档）
@export var failure_outcome: EventOutcomeDef

## 演出资源引用 id（可空——DEMO 留空）
@export var perform_resource_id: StringName = &""

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
