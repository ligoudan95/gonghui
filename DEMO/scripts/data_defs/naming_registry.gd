## 资源命名登记表（NamingRegistry）
## 职责：全库资源命名信息的独立登记表（用户拍板新增），集中记录每个资源 id
## 的域前缀、中文名与命名规则注释；批 2 扩到全库 48+ 资源，
## 批 2 校验器以本表为命名一致性基准。
## 数据来源：用户拍板附加要求（2026-09-23，M0 方案审核）；
## 命名规范权威定义分散于案 10（skl_ 前缀技能 id）/案 16（资源引用规范）/
## 案 11（状态 id 式样）等，本表负责收口登记。
## id 命名规范：status 之外的 core 域辅助表；本表自身无业务 id，
## 以文件名作为加载索引（naming_registry.tres）。
class_name NamingRegistry
extends Resource

## 登记条目列表（NamingEntry 子资源数组，每条对应一个库内资源 id）
@export var entries: Array[NamingEntry] = []

## 设计备注（登记表维护说明）
@export var comment: String = ""
