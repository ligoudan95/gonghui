## 资源注册表（AssetRegistry）
## 职责：承载「资源 id -> 资源路径」的集中映射，落实案 16 资源引用规范：
## 数据表内只存资源 id，路径映射集中管理一处，禁止表内写死路径。
## 数据来源：案 16《内容数据与配置化》§2（资源引用规范）；
## 案 20《视觉专项案》（视觉资源 id 体系）。
## id 命名规范：assets 域（core 域亦允许）；本表自身无业务 id，
## 以文件名作为加载索引（如 asset_registry.tres）。
class_name AssetRegistry
extends Resource

## 资源路径映射：StringName 资源 id -> String res:// 路径
@export var mapping: Dictionary[StringName, String] = {}

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
