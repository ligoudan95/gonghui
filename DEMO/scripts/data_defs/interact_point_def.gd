## 交互点定义（InteractPointDef）
## 职责：探索图上的可交互点位——事件链入口/单点事件/宝箱/暗门/必然遭遇/
## 出口；承载触发方式（踏入自动/点按/接近）与引用目标（chain_/sp_/enc_）。
## 数据来源：案 7《地图与探索》（点位与触发口径）；案 18 §2（DEMO 内容）；
## M3 方案批 1（10 行：链三 ENTER + 村子单点二 ENTER + 暗门 NEAR +
## 必然遭遇 ENTER + 宝箱三 TAP + 出口 TAP）。
## id 命名规范：map/interact_points 域，evp_ 前缀 + 小写下划线语义，
## 文件名与 id 同名。
## ref_id 取义（按 kind）：CHAIN -> chain_；SINGLE/SECRET_DOOR -> sp_；
## BATTLE -> enc_（敌方队伍）；TREASURE/EXIT 空。
class_name InteractPointDef
extends Resource

## 点位类别
enum Kind {
	CHAIN,        ## 事件链入口（ref -> chain_）
	SINGLE,       ## 单点事件（ref -> sp_）
	TREASURE,     ## 宝箱（金域掷值；ref 空）
	SECRET_DOOR,  ## 暗门检定点（ref -> sp_；成功出口 unlock_flag 揭示捷径）
	BATTLE,       ## 必然遭遇（ref -> enc_）
	EXIT,         ## 出口（判据达成后交付；ref 空）
}

## 触发方式
enum Trigger {
	ENTER,  ## 小队踏入同格自动触发
	TAP,    ## 点按触发（小队须在同格或邻格）
	NEAR,   ## 接近触发（格心欧氏距离 ≤ cfg.secret_door_trigger_radius）
}

## 点位 id（如 &"evp_mine_01"）
@export var id: StringName = &""
## 中文名（如「塌方救援」）
@export var display_name: String = ""
## 所在格坐标
@export var cell: Vector2i = Vector2i.ZERO
## 点位类别
@export var kind: Kind = Kind.CHAIN
## 触发方式
@export var trigger: Trigger = Trigger.ENTER
## 引用目标 id（取义见类头注释）
@export var ref_id: StringName = &""
## 宝箱金域下限（TREASURE 生效；DEMO 带宽 [20,40] 由 V-M3-treasure-domain 拦截）
@export var gold_min: int = 0
## 宝箱金域上限
@export var gold_max: int = 0
## 暗门揭示格（SECRET_DOOR 生效——揭示为 reveal_tile_id 的捷径地格）
@export var reveal_cells: Array[Vector2i] = []
## 暗门揭示目标地格 id（map/tiles 域；须可通行——V-M3-secret-reveal 拦截）
@export var reveal_tile_id: StringName = &""
## 点位归属图 id（W3-05 登记注：字段**未加**——2026-09-26 拍板归 M4 多图时
## 与 target_points 同步补 map_ref 字段并收紧 V-M3-map-points 多图分支，勿提前）

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
