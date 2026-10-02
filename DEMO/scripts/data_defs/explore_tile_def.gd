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

## 踏入效果类型（功能一试玩批 2——DEMO 唯一语义 = 踏入/途经即触发，
## 不建独立触发方式枚举；NONE = 无效果）
enum EffectKind {
	NONE,
	POISON,
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
## 踏入效果类型（功能一批 2：NONE = 无——既有地格零感知；POISON = 踏入/
## 途经即触发扣血+染毒标记+战斗带入）
@export var effect_kind: EffectKind = EffectKind.NONE
## 踏入效果附加状态 id（POISON 生效——status/stats 域，战斗带入经 CHECKIN
## 施加通道；allowed_sources 须含 CHECKIN，V-P1-etile-effect 拦截）
@export var effect_status_id: StringName = &""
## 踏入效果单格损耗值（POISON 生效——探索层直扣 apply_party_damage 口径：
## 排除已倒地、下限 1 止；≥1，V-P1-etile-effect 拦截）【占位·试玩校准】
@export var effect_damage: int = 0
## 主纹理资产 id（M6 批 3.5a：tile 渲染接线的数据位——路径经 assets 域
## AssetRegistry 映射，表内不写死路径；空 = 占位合法（3.5b 接线前的过渡态，
## V-M6-tile-asset 不收紧空值）；批 3.5b 起 ExploreBoard 按此键取纹理）
@export var asset_id: StringName = &""
## 变体纹理资产 id 列表（AssetTex.pick_variant 按格坐标稳定哈希混铺——
## 打破大面积同纹重复感；空 = 恒用主件）
@export var asset_variants: Array[StringName] = []

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
