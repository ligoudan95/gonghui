## 探索地图定义（ExploreMapDef）
## 职责：承载探索层总图的字符阵列布局、图例映射、区域归属、出生格与
## 迷雾口径（全亮行段）、探索耗时基准，供 ExploreMapState.setup 解析为
## 运行时格子数据、ExpeditionRun.start_explore 建立出征会话。
## 数据来源：案 7《地图与探索》；案 17 §3.10/§3.11（视野/暗门半径/时间域）；
## M3 方案批 1（P3=A 总图 ≤15×15：村子南段 3 行 + 矿洞 12 行）。
## id 命名规范：map/maps 域，map_ 前缀 + 小写下划线语义，文件名与 id 同名。
## rows 字符口径：经 legend 解析（不直接硬编码语义），legend 必含 '.' 空格图例；
## region_ids 惯例序：[0] = fog_lit_rows 全亮行段所属区域（村子），
## [1] = 其余行段所属区域（矿洞）——遭遇权重按此序查 encw 表。
## base_expedition_days 为探索耗时基准唯一权威（落表后 ExpeditionRun
## 基础耗时由本字段注入——M3 批 1 起单源）。
class_name ExploreMapDef
extends Resource

## 地图 id（如 &"map_m1_village_mine"）
@export var id: StringName = &""
## 中文名（如「村口矿道·总图」）
@export var display_name: String = ""
## 地图尺寸（格；size.x = 列数 / size.y = 行数）
@export var size: Vector2i = Vector2i.ZERO
## 布局字符阵列：每行 size.x 个字符、共 size.y 行（行序 = 自上而下 y 递增）
@export var rows: Array[String] = []
## 图例：布局字符 -> 探索地格 id（map/tiles 域引用，表内只存 id；必含 '.'）
@export var legend: Dictionary[StringName, StringName] = {}
## 覆盖区域 id 序（world/regions 域；惯例序见类头注释）
@export var region_ids: Array[StringName] = []
## 小队出生格
@export var start_cell: Vector2i = Vector2i.ZERO
## 迷雾启用（false = 全图常亮——DEMO 恒 true）
@export var fog_enabled: bool = true
## 迷雾全亮行号（村子段——全亮行不随距离退暗；越界值由 V-M3-fog-lit 拦截）
@export var fog_lit_rows: Array[int] = []
## 探索耗时基准（天——ExpeditionRun.base_days 的唯一权威来源）
@export var base_expedition_days: int = 1

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
