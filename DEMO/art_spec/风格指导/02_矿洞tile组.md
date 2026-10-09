# 02_矿洞tile组（14 件 = 方形 9〔探索层·源 128×128〕+ 战棋菱形 5〔源 256×128〕）

> 状态：v1.0 定稿（2026-09-30 用户审核通过；D1=A 团队规格书+用户执行生图入库、D2=B tile 全 AI 生成、暗门件=128×128 tile 已拍板）
> v0.1 草案→v1.0 定稿：2026-09-30 拍板（D2=B，来源通道改「全 AI 生成+人工修整」）
> v1.0→v1.1 修订：2026-10-01 双席审计——战棋地格逻辑位勘正（5→6，v1.0 漏计 `tile_trap`）+ 陷阱件扩 1（tile_battle_trap，用户拍板补）+ 逻辑渲染口径勘注
> v1.1→v1.2 修订：2026-10-01 M6 批 3.5a 占位入册口径回填——本组 9 件已全部占位入册（registry 118 键实况）；tile 渲染接线归批 3.5b
> v1.2→v1.3 修订：2026-10-01 M6 批 3.5b 接线实况回填——组 2/组 3 消费点接线完成（探索 etile 贴图分支+战棋 tile 满格贴图，asset_variants 坐标稳定哈希混铺+陷阱贴图态）
> v1.3→v2.0 修订：2026-10-09 战棋等距改造 E1 批（用户拍板 Q1=2:1 等距路线 A/Q2=仅战斗屏/Q3=tile 源 256×128）——「同一 tile 集双服务」破裂：**战棋消费键全部转菱形**（bush/highground/trap 三键同 id 重制 256×128+`_iso` 新键 5 件占位入册，战棋地格表 asset_id 改指 `_iso` 键）；方形 9 件回归**探索层专用**（`tile_mine_wall` 探索专用豁免菱形——V-M6-iso-asset-geometry 不列）；件目尺寸与提示词 top-down→isometric 成批修订
> 依据：M6 方案 §3.1；案 20 §3.1（场景 4/5·E1 破裂修订 2026-10-09）/§3.3（战棋菱形 256×128 行）/§4.3（矿洞 tile 8 = 地面×2、岩壁、障碍×2、状态地格 3 草丛/高地/毒沼）；v1.1 陷阱件 +1——战棋 `tile_trap` 动态生成格现由程序角标顶位（RefreshDynamicMarks），2026-10-01 用户拍板补正式件。
> 风格与提示词单源：[00_全局风格约束.md](00_全局风格约束.md)（下称「00」；**菱形件通用规格=00 §六-8**：256×128、菱形四顶点=画布四边中点、菱形满幅、画布四角透明）。
> 盘点口径（v2.0 更新·E1 批后）：本组 14 件**已全部占位入册且消费点已接线**（registry `tile_` 资产键 29 = 本组 14〔方形 9+菱形 `_iso` 5〕+03 组 14〔7+7〕+05 组暗门 1；data 域 `tile_normal` 等为逻辑地格类型 id，防撞说明见 00 §九）——占位=程序纹样（tools/gen_asset_placeholders.gd：方形 128×128/菱形 256×128 `_DiamondMask` 菱形裁剪），正式件到位同 id 原位替换；tile 纹理渲染已接线（ExploreTileDef/TileTypeDef `asset_id`/`asset_variants` → AssetTex.pick_variant 格坐标稳定哈希混铺〔D2 口径：同格恒同图、邻格打散〕；战棋侧 E1 等距投影满盒贴图 STRETCH_SCALE、缺件降级菱形色面 `_MakeDiamondFill`；陷阱标记贴图态整盒半透明——战棋 normal 复用 tile_mine_floor_01/02_iso、obstacle 复用 tile_mine_rock/cart_iso）。本表 id 即盘点源。
> 组级通用条款：方形 9 件源 128×128、逻辑渲染 96×96（案 20 §3.3 设计口径，源向下缩放无损；现行探索格实况=60——explore_board `CELL_SIZE`）；**战棋菱形 5 件源 256×128（2:1 等距）**、逻辑渲染=菱形全宽 cfg 钳制带 [72,176] 自适应（E1 等距投影、案 20 §3.3）；调性=蓝灰冷色+火把橙点光（#5A6472/#3E4550/#E07B39）；~~本组同一 tile 集同时服务探索层（矿洞段）与战棋图~~ **E1 破裂注记（2026-10-09）：案 20 §3.1 场景 5「复用矿洞 tile 集」条款废止——战棋消费位另制菱形套（本组 `_iso` 5+战棋状态 3 同 id 重制+09 组 fx 2），方形套回归探索层专用（`tile_mine_wall` 无战棋消费、豁免菱形规格）**；来源通道=**全 AI 生成+人工修整**（D2=B 已拍板单轨、零采购预算；00 §七）。

---

## 件目清单（14 件 = 方形 9 + 战棋菱形 5）

| 资源 id | 类别·尺寸 | 内容描述 | 服务逻辑位 |
|---|---|---|---|
| `tile_mine_floor_01`【新增】 | tile 128×128·可平铺 | 矿洞地面·基岩：蓝灰岩面平铺底纹，暗面裂缝（#5A6472 主、#3E4550 裂纹） | 探索 `etile_floor`（E1 起**探索专用**——战棋 normal 消费改指 `_iso` 键） |
| `tile_mine_floor_02`【新增】 | tile 128×128·可平铺 | 矿洞地面·碎石变体：同 01 色系，散落细碎石与少许矿渣 | 同上（变体混铺打破重复感） |
| `tile_mine_wall`【新增】 | tile 128×128·可平铺 | 岩壁：竖向岩壁剖面、深灰冷阴影，顶视图「不可通行」剪影明确（案 20 §3.3 障碍辨识原则） | 探索 `etile_wall`（**探索专用·豁免菱形**——E1 批无战棋消费点，V-M6-iso-asset-geometry 17 键清单不列、维持 128×128 方形） |
| `tile_mine_rock`【新增】 | tile 128×128·物件件 | 障碍·塌方碎石堆：整块凸起乱石堆，轮廓不越画布、底缘对齐格界 | E1 起**无现行消费点**（战棋 `tile_obstacle` 改指 `tile_mine_rock_iso`；键在册备用——探索层如后续需矿洞段障碍装饰可复用） |
| `tile_mine_cart`【新增】 | tile 128×128·物件件 | 障碍·废弃矿车：翻倒木斗矿车+轨道残段（案 20 §3.1「废弃矿车轨道」意象） | E1 起**无现行消费点**（战棋改指 `tile_mine_cart_iso`；键在册备用，同上） |
| `tile_battle_bush`【新增·v2.0 同 id 重制菱形】 | **tile 256×128·菱形覆盖件**（2:1 等距·菱形满幅） | 战棋草丛：菱形地面底+手绘草丛覆盖、绿系（#7CA85A），色彩+形状双编码（案 20 §3.3） | 战棋 `tile_grass`（草丛·闪避+）——E1 同 id 重制 256×128（原 128×128 方形版已被替换、无方形版存续） |
| `tile_battle_highground`【新增·v2.0 同 id 重制菱形】 | **tile 256×128·菱形物件件** | 战棋高地：等距抬升台面+侧壁明暗差，高度差可读 | 战棋 `tile_highground`（伤害+）——E1 同 id 重制 256×128（同上） |
| `tile_battle_poison_swamp`【新增】 | tile 128×128·可平铺 | 毒沼：紫绿冒泡质感静态纹理（紫 `#7A2E35` 系+绿 `#4C9A5F` 泡点，动效占位为静态） | 探索层 `etile_poison_swamp`（毒瘴地格，M4 试玩反馈批新增）——E1 起**探索专用**（战棋 `tile_poison_swamp` 改指新键 `tile_battle_poison_swamp_iso`） |
| `tile_battle_trap`【新增·v1.1 扩件·v2.0 同 id 重制菱形】 | **tile 256×128·菱形覆盖件** | 战棋陷阱：尖刺/捕兽夹菱形格面（金属包边 #A8843C 机械件+警示橙点 #E07B39 系，底为矿洞地面同系），色彩+形状双编码（危险剪影独立可辨） | 战棋 `tile_trap`（**动态生成格**：运行时叠加于底格之上的陷阱盒面——E1 满盒菱形半透明；正式件到位后程序角标退役） |
| `tile_mine_floor_01_iso`【新增·v2.0 战棋菱形】 | **tile 256×128·菱形满幅** | 矿洞地面·基岩（战棋菱形）：蓝灰岩面菱形底纹+暗面裂缝，菱形四顶点=画布四边中点、四角透明 | 战棋 `tile_normal` 底图（变体混铺，E1 改指） |
| `tile_mine_floor_02_iso`【新增·v2.0 战棋菱形】 | **tile 256×128·菱形满幅** | 矿洞地面·碎石变体（战棋菱形）：同上色系，菱形内散落细碎石 | 同上（变体混铺） |
| `tile_mine_rock_iso`【新增·v2.0 战棋菱形】 | **tile 256×128·菱形物件件** | 障碍·塌方碎石堆（战棋菱形）：母题完整落于菱形内、底缘对齐菱形下缘 | 战棋 `tile_obstacle` 表现 1（E1 改指） |
| `tile_mine_cart_iso`【新增·v2.0 战棋菱形】 | **tile 256×128·菱形物件件** | 障碍·废弃矿车（战棋菱形）：翻倒木斗矿车+轨道残段 | 战棋 `tile_obstacle` 表现 2（E1 改指） |
| `tile_battle_poison_swamp_iso`【新增·v2.0 战棋菱形】 | **tile 256×128·菱形满幅** | 战棋毒沼（菱形）：紫绿冒泡质感静态纹理（色板同方形版） | 战棋 `tile_poison_swamp`（E1 改指新键） |

## 提示词与负面（按 00 §五拼装；菱形件视角词 top-down→isometric、几何约束见 00 §六-8）

| 资源 id | 提示词内容短语（=00 前缀 A + 本列） | 负面 |
|---|---|---|
| `tile_mine_floor_01` | `seamless tileable cave stone floor texture, blue-gray rock, dark cracks, top-down view, dungeon mine theme` | +00 通用负面 |
| `tile_mine_floor_02` | `seamless tileable cave stone floor with scattered rubble and ore debris, blue-gray rock, top-down view` | +00 通用负面 |
| `tile_mine_wall` | `seamless tileable mine cavern rock wall, vertical stone face, deep cold shadow, top-down game tile, impassable silhouette` | +00 通用负面 |
| `tile_mine_rock` | `rockslide rubble pile on cave floor, single game tile, top-down view, clear impassable silhouette, bottom edge aligned` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_mine_cart` | `overturned broken mine cart with rail fragment on cave floor, single game tile, top-down view, wooden cart with metal parts` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_battle_bush` | `grass bush cluster on isometric diamond tile, rhombus cave floor base, lush green tufts, motif fully inside the diamond, shape and color clearly distinct` | +00 通用负面 |
| `tile_battle_highground` | `raised stone platform on isometric diamond tile, rhombus base, elevated terrace with visible side wall shading, height difference readable` | +00 通用负面 |
| `tile_battle_poison_swamp` | `seamless tileable poisonous swamp pool, purple-green bubbling toxic slime texture, top-down game tile` | +00 通用负面 |
| `tile_battle_trap` | `bear trap with metal spikes on isometric diamond tile, rhombus cave floor base, mechanical trap face with warning orange accent, motif fully inside the diamond, danger clearly readable` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_mine_floor_01_iso` | `isometric 2:1 diamond floor tile, rhombus-shaped cave stone texture, blue-gray rock with dark cracks, diamond filling the full frame, corners transparent, dungeon mine theme` | +00 通用负面 |
| `tile_mine_floor_02_iso` | `isometric 2:1 diamond floor tile, rhombus-shaped cave stone with scattered rubble and ore debris, blue-gray rock, diamond filling the full frame, corners transparent` | +00 通用负面 |
| `tile_mine_rock_iso` | `rockslide rubble pile on isometric diamond tile, rhombus cave floor base, clear impassable silhouette, motif fully inside the diamond, bottom edge aligned to diamond lower edge` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_mine_cart_iso` | `overturned broken mine cart with rail fragment on isometric diamond tile, rhombus cave floor base, wooden cart with metal parts, motif fully inside the diamond` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_battle_poison_swamp_iso` | `isometric 2:1 diamond tile, rhombus-shaped poisonous swamp pool, purple-green bubbling toxic slime texture filling the full diamond, corners transparent` | +00 通用负面 |

## 验收标准

- 通用：00 §六全款（色板一致/描边规范）；**方形 9 件 128×128**、**菱形 5 件及同 id 重制 3 键 256×128**（00 §六-8 菱形几何：四顶点=画布四边中点、菱形满幅、四角透明——过 V-M6-iso-asset-geometry）；方形标注「可平铺」四件须四边无缝（2×2 平铺目检无接缝）；物件件轮廓不越画布（菱形件=不越菱形）、底缘对齐格界（菱形件=菱形下缘）；覆盖件（bush/trap）覆盖图案完整落于菱形内。
- 色觉无障碍：状态地格四类（bush/highground/poison_swamp（方形+菱形两版）/**trap**）为「颜色+形状」双重编码（案 20 §3.3），形状单独剪影即可区分。
- AI 修整要求：全组按「全 AI 生成+人工修整」单轨执行（D2=B 已拍板、零采购预算）——可平铺件的接缝、菱形件四边中点对位与全组批量色差由人工修整收敛；色板/描边按 00 §三统一；来源一律登记 `art_source_log.md` AI 分区。
- 服务映射核对（v2.0·E1 后）：**战棋 6 个逻辑位全菱形消费**（normal→`tile_mine_floor_01/02_iso`、obstacle→`tile_mine_rock/cart_iso`、grass→bush〔同 id 菱形〕、highground→〔同 id 菱形〕、poison_swamp→`tile_battle_poison_swamp_iso`、trap→〔同 id 菱形〕）+**探索层 4 个矿洞系逻辑位方形消费**（floor×2/wall/poison）——案 20 §3.1 场景 4/5「同一 tile 集双服务」条款已于 E1 批废止破裂（2026-10-09）；v1.1 勘正行（战棋 6 逻辑位/`tile_trap` 漏计勘正）沿革保留可溯。

## 来源留档

本组 14 件均待回填 → `art_source_log.md`（D2=B 全 AI 生成，统一登记 AI 分区；E1 批占位件 5 件系程序生成非 AI 出图、正式件到位时再行留档）。

（本组 14 件：方形 9（新增 id·批 3.5a 占位入册·组 2 探索消费接线——rock/cart 两键 E1 起无现行消费点在册备用）+战棋菱形 `_iso` 5（E1 批 2026-10-09 占位入册·战棋组 3 消费改指）+同 id 重制菱形 3 键（bush/highground/trap——E1 同批重制、键与消费位不变）；合计 14 件 = 原 9 + `_iso` 新键 5（v2.0））
