## DOT 参数（DotParams）
## 职责：承载持续伤害类状态的每跳伤害参数（固定值或属性比率两种模式），
## 内嵌于 StatusDef.dot；DOT 跳伤不过减免轨（案 17 §3.4 已定稿口径）。
## 数据来源：案 11《状态效果》；案 17《数值专项案》§3.4
## （持续伤害类：每跳固定值 = 主导属性 × 0.5，如蚀命诅咒 = 意志 × 0.5）。
## id 命名规范：本类为内嵌子资源，无独立 id。
class_name DotParams
extends Resource

## DOT 计算模式（固定值 / 属性比率）
enum Mode {
	FIXED,
	ATTR_RATIO,
}

## 计算模式（FIXED 用 fixed；ATTR_RATIO 用 attr_id × ratio）
@export var mode: Mode = Mode.FIXED
## 固定每跳伤害（mode = FIXED 时生效）
@export var fixed: int = 0
## 比率换算源属性 id（mode = ATTR_RATIO 时生效）
@export var attr_id: StringName = &""
## 属性换算比率（如 0.5 = 主导属性 × 0.5；批 C M7：schema 默认中性 0.0，真值由 .tres 显式承载）
@export var ratio: float = 0.0
