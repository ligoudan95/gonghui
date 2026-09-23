## 倾向定义（TendencyDef）
## 职责：承载职业的可选倾向分支（侧重属性与成长修正入口），内嵌于 ClassDef.tendencies。
## 数据来源：案 10《职业与技能》§2.1（倾向定义表：倾向 id、名称、成长修正、
## 可用技能池分支）；案 17《数值专项案》§3.11 #2（倾向侧重属性）。
## id 命名规范：随所属职业（如 warrior 的防御倾向可取 ten_warrior_guard 式），
## 小写下划线；文件名与 id 同名（批 2 定名落表）。
class_name TendencyDef
extends Resource

## 倾向 id
@export var id: StringName = &""
## 中文名（如「防御倾向」）
@export var display_name: String = ""
## 侧重属性列表（一级属性 id，倾向成长修正加权项）
@export var focus_attrs: Array[StringName] = []
