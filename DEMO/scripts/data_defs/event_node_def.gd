## 事件节点定义（EventNodeDef）
## 职责：事件链内单个节点的叙述与选项挂载——入口/中间节点带 option_ids，
## 终端节点带内嵌 outcome（出口结算）；直接出口（选项直接挂出口）不在本表。
## 数据来源：案 8 §2（节点结构）；案 18 §2.1-2.3。
## id 命名规范：event/nodes 域，evn_ 前缀，文件名与 id 同名。
class_name EventNodeDef
extends Resource

## 节点 id（如 &"evn_collapse_n1"）
@export var id: StringName = &""
## 中文短名（如「塌方现场」——UI 标题/日志用）
@export var display_name: String = ""
## 所属链 id（chain_ 前缀——V-M2-ref-graph 校验归属一致）
@export var chain_id: StringName = &""
## 叙述文本（第二人称复数白描——案 18 §3.1 口径，机制词禁入）
@export var narrative_text: String = ""
## 选项 id 清单（event/options 域 opt_ 前缀；终端节点为空——走 outcome）
@export var option_ids: Array[StringName] = []
## 内嵌出口结算（可空——中间/入口节点为 null，终端节点必填或选项直接出口）
@export var outcome: EventOutcomeDef

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
