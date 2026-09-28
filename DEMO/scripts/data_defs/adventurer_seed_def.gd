## 冒险者初始种子（AdventurerSeedDef）
## 职责：开局固定 4 人名册的种子行——姓名/职业/来源/预解锁标记；属性不落表
## （开局掷值走 AttrRoller.roll_fixed_four 中值偏上，17-C7 豁免钳制）；
## 招募成员为运行态生成（adv_recruit_N 递增 id），不入本表。
## 数据来源：案 5《冒险者》§2.4（初始 4 人构成已转正定稿——战士/盗贼/法师/
## 牧师，17-C7）；案 17 §3.6（预解锁标记=初始 4 人 true、第 1 技出生预解锁不扣点）。
## id 命名规范：adventurer/instances 域，adv_ 前缀，文件名与 id 同名。
class_name AdventurerSeedDef
extends Resource

## 来源标记（初始=INITIAL；招募/剧情 NPC 为运行态生成不入本表——枚举留完整版扩展位）
enum Source {
	INITIAL,
}

## 冒险者实例 id（如 &"adv_iron_peak"；招募递增 id 前缀 adv_recruit_ 不与种子冲突）
@export var id: StringName = &""
## 姓名（【占位·试玩校准】）
@export var display_name: String = ""
## 职业 id（class/classes 域）
@export var class_id: StringName = &""
## 来源
@export var source: Source = Source.INITIAL
## 预解锁标记（初始 4 人恒 true——V-M4-adv-seed 校验；第 1 技出生预解锁不扣点）
@export var pre_unlocked: bool = true

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
