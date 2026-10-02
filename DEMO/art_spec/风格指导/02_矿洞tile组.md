# 02_矿洞tile组（9 件·源 128×128）

> 状态：v1.0 定稿（2026-09-30 用户审核通过；D1=A 团队规格书+用户执行生图入库、D2=B tile 全 AI 生成、暗门件=128×128 tile 已拍板）
> v0.1 草案→v1.0 定稿：2026-09-30 拍板（D2=B，来源通道改「全 AI 生成+人工修整」）
> v1.0→v1.1 修订：2026-10-01 双席审计——战棋地格逻辑位勘正（5→6，v1.0 漏计 `tile_trap`）+ 陷阱件扩 1（tile_battle_trap，用户拍板补）+ 逻辑渲染口径勘注
> v1.1→v1.2 修订：2026-10-01 M6 批 3.5a 占位入册口径回填——本组 9 件已全部占位入册（registry 118 键实况）；tile 渲染接线归批 3.5b
> v1.2→v1.3 修订：2026-10-01 M6 批 3.5b 接线实况回填——组 2/组 3 消费点接线完成（探索 etile 贴图分支+战棋 tile 满格贴图，asset_variants 坐标稳定哈希混铺+陷阱贴图态）
> 依据：M6 方案 §3.1；案 20 §3.1（场景 4/5）/§3.3/§4.3（矿洞 tile 8 = 地面×2、岩壁、障碍×2、状态地格 3 草丛/高地/毒沼）；v1.1 陷阱件 +1——战棋 `tile_trap` 动态生成格现由程序角标顶位（RefreshDynamicMarks），2026-10-01 用户拍板补正式件。
> 风格与提示词单源：[00_全局风格约束.md](00_全局风格约束.md)（下称「00」）。
> 盘点口径（v1.3 更新·批 3.5b 后）：本组 9 件**已全部占位入册且消费点已接线**（registry `tile_` 资产键 17 = 本组 9〔矿洞 5+战棋 4〕+03 组 7+05 组暗门 1；data 域 `tile_normal` 等为逻辑地格类型 id，防撞说明见 00 §九）——占位=128×128 程序纹样（tools/gen_asset_placeholders.gd），正式件到位同 id 原位替换；tile 纹理渲染已接线（ExploreTileDef/TileTypeDef `asset_id`/`asset_variants` → AssetTex.pick_variant 格坐标稳定哈希混铺〔D2 口径：同格恒同图、邻格打散〕；战棋侧 Control 根+满格贴图 gap=0、缺件降级色块池现状零回归；陷阱标记贴图态整格半透明——战棋 normal 复用 tile_mine_floor_01/02、obstacle 复用 tile_mine_rock+cart 变体）。本表 id 即盘点源。
> 组级通用条款：源 128×128、逻辑渲染 96×96（案 20 §3.3，缩放无损；勘注·v1.1：现行运行时实况=战棋格 40-88 动态钳制（battle_board `CELL_SIZE_MIN/MAX`）、探索格 60（explore_board `CELL_SIZE`）——「96」为案 20 设计口径，源 128 向下缩放无损、**源规格 128 不受影响**）；调性=蓝灰冷色+火把橙点光（#5A6472/#3E4550/#E07B39）；**本组同一 tile 集同时服务探索层（矿洞段）与战棋图**（案 20 §3.1 场景 5「复用矿洞 tile 集」）；来源通道=**全 AI 生成+人工修整**（D2=B 已拍板单轨、零采购预算；00 §七）。

---

## 件目清单（9 件）

| 资源 id | 类别·尺寸 | 内容描述 | 服务逻辑位 |
|---|---|---|---|
| `tile_mine_floor_01`【新增】 | tile 128×128·可平铺 | 矿洞地面·基岩：蓝灰岩面平铺底纹，暗面裂缝（#5A6472 主、#3E4550 裂纹） | 探索 `etile_floor` / 战棋 `tile_normal` 底图 |
| `tile_mine_floor_02`【新增】 | tile 128×128·可平铺 | 矿洞地面·碎石变体：同 01 色系，散落细碎石与少许矿渣 | 同上（变体混铺打破重复感） |
| `tile_mine_wall`【新增】 | tile 128×128·可平铺 | 岩壁：竖向岩壁剖面、深灰冷阴影，顶视图「不可通行」剪影明确（案 20 §3.3 障碍辨识原则） | 探索 `etile_wall` |
| `tile_mine_rock`【新增】 | tile 128×128·物件件 | 障碍·塌方碎石堆：整块凸起乱石堆，轮廓不越画布、底缘对齐格界 | 战棋 `tile_obstacle` 表现 1 |
| `tile_mine_cart`【新增】 | tile 128×128·物件件 | 障碍·废弃矿车：翻倒木斗矿车+轨道残段（案 20 §3.1「废弃矿车轨道」意象） | 战棋 `tile_obstacle` 表现 2 |
| `tile_battle_bush`【新增】 | tile 128×128·覆盖件 | 战棋草丛：地面底+手绘草丛覆盖、绿系（#7CA85A），色彩+形状双编码（案 20 §3.3） | 战棋 `tile_grass`（草丛·闪避+） |
| `tile_battle_highground`【新增】 | tile 128×128·物件件 | 战棋高地：抬升台面+侧壁明暗差，高度差顶视可读 | 战棋 `tile_highground`（伤害+） |
| `tile_battle_poison_swamp`【新增】 | tile 128×128·可平铺 | 战棋毒沼：紫绿冒泡质感静态纹理（紫 `#7A2E35` 系+绿 `#4C9A5F` 泡点，动效占位为静态） | 战棋 `tile_poison_swamp`；兼作探索层 `etile_poison_swamp`（毒瘴地格，M4 试玩反馈批新增） |
| `tile_battle_trap`【新增·v1.1 扩件】 | tile 128×128·覆盖件 | 战棋陷阱：尖刺/捕兽夹格面（金属包边 #A8843C 机械件+警示橙点 #E07B39 系，底为矿洞地面同系），色彩+形状双编码（危险剪影独立可辨） | 战棋 `tile_trap`（**动态生成格**：运行时叠加于底格之上的陷阱格面；现行由 RefreshDynamicMarks 程序角标（12px 色块）顶位，正式件到位后**程序角标退役**——同 id 原位替换口径） |

## 提示词与负面（按 00 §五拼装）

| 资源 id | 提示词内容短语（=00 前缀 A + 本列） | 负面 |
|---|---|---|
| `tile_mine_floor_01` | `seamless tileable cave stone floor texture, blue-gray rock, dark cracks, top-down view, dungeon mine theme` | +00 通用负面 |
| `tile_mine_floor_02` | `seamless tileable cave stone floor with scattered rubble and ore debris, blue-gray rock, top-down view` | +00 通用负面 |
| `tile_mine_wall` | `seamless tileable mine cavern rock wall, vertical stone face, deep cold shadow, top-down game tile, impassable silhouette` | +00 通用负面 |
| `tile_mine_rock` | `rockslide rubble pile on cave floor, single game tile, top-down view, clear impassable silhouette, bottom edge aligned` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_mine_cart` | `overturned broken mine cart with rail fragment on cave floor, single game tile, top-down view, wooden cart with metal parts` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_battle_bush` | `grass bush cluster overlay on dungeon floor tile, lush green tufts, top-down game tile, shape and color clearly distinct` | +00 通用负面 |
| `tile_battle_highground` | `raised stone platform tile, elevated terrace with visible side wall shading, top-down game tile, height difference readable` | +00 通用负面 |
| `tile_battle_poison_swamp` | `seamless tileable poisonous swamp pool, purple-green bubbling toxic slime texture, top-down game tile` | +00 通用负面 |
| `tile_battle_trap` | `bear trap with metal spikes hazard on dungeon floor, mechanical trap face with warning orange accent, top-down game tile, danger clearly readable` | +00 通用负面（另加：`overlapping tile edges`） |

## 验收标准

- 通用：00 §六全款（色板一致/描边规范/128×128）；标注「可平铺」四件须四边无缝（2×2 平铺目检无接缝）；物件三件轮廓不越画布、底缘对齐格界；覆盖件两件（bush/trap）覆盖图案完整落于画布内、不遮底格四角定位。
- 色觉无障碍：状态地格四件（bush/highground/poison_swamp/**trap**）为「颜色+形状」双重编码（案 20 §3.3），形状单独剪影即可区分。
- AI 修整要求：全组按「全 AI 生成+人工修整」单轨执行（D2=B 已拍板、零采购预算）——可平铺四件的接缝与全组批量色差由人工修整收敛；色板/描边按 00 §三统一；来源一律登记 `art_source_log.md` AI 分区。
- 服务映射核对（v1.1 勘正）：9 件覆盖探索层 4 个矿洞系逻辑位（floor×2/wall/poison）+ 战棋 **6 个逻辑位**（normal 底图复用 floor/obstacle×2/grass/highground/poison/**trap**）——与案 20 §3.1 场景 4/5「同一 tile 集双服务」一致；v1.0「战棋 5 个逻辑位」漏计 `tile_trap`（data/battle/tiles/ 六类地格实况：normal/obstacle/grass/highground/poison_swamp/trap）。

## 来源留档

本组 9 件均待回填 → `art_source_log.md`（D2=B 全 AI 生成，统一登记 AI 分区）。

（本组 9 件全部为新增 id、批 3.5a 已全部占位入册、批 3.5b 组 2/组 3 消费点已接线；合计 9 件 = 矿洞/战棋 tile 8 + 陷阱件 1（v1.1 扩件））
