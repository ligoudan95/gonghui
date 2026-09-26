## 探索地格定义（ExploreTileDef）
## 职责：承载探索层地格的类型与视觉——通行性、底色/强调色与视觉样式，
## 供 ExploreMapState 解析通行、ExploreBoard 表驱动渲染色块。
## 数据来源：案 7《地图与探索》（地格通行口径）；M3 方案批 1（程序化占位
## 视觉：色块 + 图标，DEMO 4 行——floor/wall/path/village_ground）。
## id 命名规范：map/tiles 域，etile_ 前缀 + 小写下划线语义，文件名与 id 同名。
## 与战场地格（battle/tiles 域 tile_）分域：探索层无站位状态/触发语义，
## 仅承载通行性与视觉。
class_name ExploreTileDef
extends Resource

## 地格视觉样式（沿用战场地格 Style 语义——UI 渲染分支的唯一依据）
enum Style {
	PLAIN,   ## 普通平色块
	RAISED,  ## 平台凸边（底色 + 强调色双层）
	BLOCK,   ## 障碍岩块（底色 + 深色内块 + 强调色描边）
}

## 地格 id（如 &"etile_floor"）
@export var id: StringName = &""
## 中文名（如「矿洞地面」）
@export var display_name: String = ""
## 可通行（false = 障碍：寻路绕行、点按无移动）
@export var walkable: bool = true
## 地格底色（程序化占位视觉——默认透明 = 未回填，运行时回退 UiTheme 兜底）
@export var fill_color: Color = Color(0, 0, 0, 0)
## 强调色（RAISED 内层色 / BLOCK 描边色；PLAIN 不消费）
@export var accent_color: Color = Color(0, 0, 0, 0)
## 视觉样式（PLAIN/RAISED/BLOCK）
@export var style: Style = Style.PLAIN

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
