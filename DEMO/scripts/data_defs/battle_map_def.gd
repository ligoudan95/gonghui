## 战场地图定义（BattleMapDef）
## 职责：承载战场地图的字符阵列布局、图例映射与出生位坐标，
## 供 BattleGrid.setup 解析为运行时格子数据。
## 数据来源：案 9《战棋战斗》；案 17《数值专项案》§3.9（战场规模：
## 随机遭遇 8×8 / 必然遭遇 10×10 / 事件 B 出口遭遇复用 8×8）；
## 案 21《战棋专项案》。
## id 命名规范：battle/maps 域，btm_ 前缀 + 小写下划线（区域+规格语义），
## 文件名与 id 同名。
## rows 字符口径：'.'普通 'X'障碍 'g'草丛 'h'高地 'p'毒沼（经 legend 解析，
## 不直接硬编码语义）。
class_name BattleMapDef
extends Resource

## 地图 id（如 &"btm_m1_random_8x8"）
@export var id: StringName = &""
## 中文名（如「矿洞随机遭遇图」）
@export var display_name: String = ""
## 地图尺寸（格；size.x = 列数 / size.y = 行数）
@export var size: Vector2i = Vector2i.ZERO
## 布局字符阵列：每行 size.x 个字符、共 size.y 行（行序 = 自上而下 y 递增）
@export var rows: Array[String] = []
## 图例：布局字符 -> 地格类型 id（battle/tiles 域引用，表内只存 id）
@export var legend: Dictionary[String, StringName] = {}
## 我方出生位（底部 4 格）
@export var player_spawns: Array[Vector2i] = []
## 敌方出生位候选（顶部 4 格）
@export var enemy_spawns: Array[Vector2i] = []
## 撤退格坐标（字段位预留，DEMO 空——撤退机制完整版启用时回填）
@export var retreat_cells: Array[Vector2i] = []

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
