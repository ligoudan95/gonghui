## 命名登记条目（NamingEntry）
## 职责：资源命名登记表的单条记录——记录一个资源 id 的所属域前缀、
## 中文名与命名规则注释；全库资源的命名信息集中登记于 NamingRegistry，
## 供命名一致性校验（批 2 校验器）与人工查阅。
## 数据来源：用户拍板附加要求（2026-09-23，M0 方案审核：每个 id 须有命名规则
## 注释 + 中文名注释，并建独立「资源命名登记表」记录全库资源命名信息）；
## 各域命名规范见对应 data_defs 类头注释与案 16 §2 资源引用规范。
## id 命名规范：本类为内嵌子资源，无独立文件 id；resource_id 沿用被登记资源
## 自身所在域的命名规范。
class_name NamingEntry
extends Resource

## 被登记资源的 id（与该资源所在域命名规范一致）
@export var resource_id: StringName = &""
## 所属域前缀（GameData.DOMAIN_SCHEMA 的域键，如 &"core"、&"class/skills"）
@export var domain: StringName = &""
## 中文名（资源中文注释，如「总控配置」）
@export var display_name: String = ""
## 命名规则注释（该 id 的命名规则说明，含【占位·架构期可调】等标记）
@export var rule_note: String = ""
