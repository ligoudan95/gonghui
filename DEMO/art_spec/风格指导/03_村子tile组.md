# 03_村子tile组（14 件 = 方形 7〔探索层·源 128×128〕+ 战棋菱形 7〔完整版预备·源 256×128〕）

> 状态：v1.0 定稿（2026-09-30 用户审核通过；D1=A 团队规格书+用户执行生图入库、D2=B tile 全 AI 生成、暗门件=128×128 tile 已拍板）
> v0.1 草案→v1.0 定稿：2026-09-30 拍板（D2=B，来源通道改「全 AI 生成+人工修整」）
> v1.0→v1.1 修订：2026-10-01 双席审计——逻辑渲染口径勘注 + 装饰件 4 件前置机制标注 + `tile_village_path` 挂 etile_path 高危标记
> v1.1→v1.2 修订：2026-10-01 M6 批 3.5a 状态回填——高危①解除（槽位 X2 定稿：etile_path 勘正回土路并挂本组 tile_village_path）+ 装饰件 4 件机制已建（etile 障碍表+村图 5 格）+ 本组 7 件占位入册（registry 118 键实况）
> v1.2→v1.3 修订：2026-10-01 M6 批 3.5b 接线实况回填——组 2 消费点接线完成（探索底格层贴图分支在前+asset_variants 坐标稳定哈希混铺，缺件降级 Style 三样式色块）
> v1.3→v2.0 修订：2026-10-09 战棋等距改造 E1 批——**战棋菱形 `_iso` 7 键扩件入册**（**战棋菱形·完整版预备**：占位在册、无战斗消费点——村子图战斗化时启用，正式素材同 id 原位替换）；方形 7 件维持探索层专用（探索屏不改造——等距拍板 Q2）；菱形通用规格=00 §六-8
> 依据：M6 方案 §3.1；案 20 §3.1（场景 3/场景 5 村子 `_iso` 完整版预备注记·2026-10-09）/§4.3（村子 tile 7 = 草地×2、土路、水井、农舍、树木×2）。
> 风格与提示词单源：[00_全局风格约束.md](00_全局风格约束.md)（下称「00」；菱形件通用规格=00 §六-8）。
> 盘点口径（v2.0 更新·E1 批后）：本组 14 件**已全部占位入册**（registry `tile_` 资产键 29 = 本组 14〔方形 7+菱形 `_iso` 7〕+02 组 14+05 组暗门 1；data 域 `etile_village_ground`/`etile_path` 为逻辑探索地格 id，防撞说明见 00 §九）——方形 7 件消费点已接线（探索底格层，缺件降级现状零回归；etile_path 现村图无 path 格零渲染、M7 村图加格生效——槽位 X2 口径维持）；**菱形 `_iso` 7 件无现行消费点（完整版预备）**。占位=程序纹样/物件母题（tools/gen_asset_placeholders.gd：方形 128×128/菱形 256×128 `_DiamondMask`）；正式件到位同 id 原位替换。本表 id 即盘点源。
> 组级通用条款：方形 7 件源 128×128、逻辑渲染 96×96（勘注·v1.1：现行探索格实况=60（explore_board `CELL_SIZE`）——「96」为案 20 §3.3 设计口径，源 128 向下缩放无损、**源规格 128 不受影响**）；**战棋菱形 7 件源 256×128（2:1 等距·00 §六-8）**；调性=田园（草绿 #7CA85A + 土黄 #C9A66B）、**明亮少阴影 = 安全区视觉信号**（案 20 §2.4）；来源通道=**全 AI 生成+人工修整**（D2=B 已拍板单轨、零采购预算；00 §七）。

---

## 件目清单（14 件 = 方形 7 + 战棋菱形 7〔完整版预备〕）

| 资源 id | 类别·尺寸 | 内容描述 | 服务逻辑位 |
|---|---|---|---|
| `tile_village_grass_01`【新增】 | tile 128×128·可平铺 | 草地·基色：明亮草绿平铺底纹、少量草簇点缀 | 探索 `etile_village_ground` 底图 |
| `tile_village_grass_02`【新增】 | tile 128×128·可平铺 | 草地·野花变体：同 01 色系，点缀野花与深浅草簇 | 同上（变体混铺） |
| `tile_village_path`【新增】 | tile 128×128·可平铺 | 土路：土黄压实路面、两侧草缘过渡 | 探索 `etile_path`【高危①已解除·槽位 X2 定稿（M6 批 3.5a，2026-10-01 拍板）：etile_path 勘正回「土路」本义并挂本件（`asset_id` 已回填）——村图现无 path 格=零渲染，M7 村图重做加格即生效；原「隐秘通道」双语义拆分给新表 `etile_secret_passage`（挂 05 组 `tile_secret_passage`）】 |
| `tile_village_well`【新增】 | tile 128×128·物件件 | 水井：石砌井台+木架辘轳（案 18 单点事件舞台物件） | 探索装饰格 `etile_well`（障碍）※机制已建（见下注） |
| `tile_village_house`【新增】 | tile 128×128·物件件 | 农舍：土黄墙面+暖木梁小屋顶视造型 | 探索装饰格 `etile_house`（障碍）※机制已建（见下注） |
| `tile_village_tree_01`【新增】 | tile 128×128·物件件 | 树木·阔叶单株：圆润树冠+暖棕树干 | 探索装饰格 `etile_tree_01`（障碍）※机制已建（见下注） |
| `tile_village_tree_02`【新增】 | tile 128×128·物件件 | 树木·双株变体：两株小树错落 | 探索装饰格 `etile_tree_02`（障碍）※机制已建（见下注） |
| `tile_village_grass_01_iso`【新增·v2.0 战棋菱形·**完整版预备**】 | **tile 256×128·菱形满幅** | 草地·基色（战棋菱形）：同方形版色系，菱形四顶点=画布四边中点、四角透明 | **无现行战斗消费点**（村子图战斗化时作战棋地面底图——完整版预备，E1 批占位入册） |
| `tile_village_grass_02_iso`【新增·v2.0 战棋菱形·完整版预备】 | **tile 256×128·菱形满幅** | 草地·野花变体（战棋菱形）：同上色系，菱形内点缀野花 | 同上（变体混铺预备） |
| `tile_village_path_iso`【新增·v2.0 战棋菱形·完整版预备】 | **tile 256×128·菱形满幅** | 土路（战棋菱形）：土黄压实路面 | 完整版预备（同上） |
| `tile_village_well_iso`【新增·v2.0 战棋菱形·完整版预备】 | **tile 256×128·菱形物件件** | 水井（战棋菱形）：母题完整落于菱形内、底缘对齐菱形下缘 | 完整版预备（同上） |
| `tile_village_house_iso`【新增·v2.0 战棋菱形·完整版预备】 | **tile 256×128·菱形物件件** | 农舍（战棋菱形）：同方形版造型等距化 | 完整版预备（同上） |
| `tile_village_tree_01_iso`【新增·v2.0 战棋菱形·完整版预备】 | **tile 256×128·菱形物件件** | 树木·阔叶单株（战棋菱形） | 完整版预备（同上） |
| `tile_village_tree_02_iso`【新增·v2.0 战棋菱形·完整版预备】 | **tile 256×128·菱形物件件** | 树木·双株变体（战棋菱形） | 完整版预备（同上） |

> ※装饰件机制标注（v1.2 更新·M6 批 3.5a；v1.3 接线完成）：水井/农舍/树木×2 共 4 件——装饰格机制**已落地**（`etile_well`/`etile_house`/`etile_tree_01`/`etile_tree_02` 四张 ExploreTileDef 障碍表+村图 legend 增 W/H/T/t 四图例、村段点缀 5 格〔避开出生/出口/事件点/主廊，连通性校验通过〕；`asset_id` 数据位已回填、占位程序纹样已入册）——正式件到位原位替换即达；tile 纹理渲染**批 3.5b 组 2 已接线**。（v1.1 原注「探索层现无装饰格机制、正式件入库后暂不可达」为批 3.5a 前时点口径，已解除。）

## 提示词与负面（按 00 §五拼装；菱形件视角词 isometric、几何约束见 00 §六-8）

| 资源 id | 提示词内容短语（=00 前缀 A + 本列） | 负面 |
|---|---|---|
| `tile_village_grass_01` | `seamless tileable bright meadow grass texture, soft green with small grass tufts, top-down game tile, sunny countryside` | +00 通用负面 |
| `tile_village_grass_02` | `seamless tileable meadow grass with tiny wildflowers and varied tufts, bright and lively, top-down game tile` | +00 通用负面 |
| `tile_village_path` | `seamless tileable dirt path texture, packed yellow-brown earth with grass edges, top-down game tile` | +00 通用负面 |
| `tile_village_well` | `stone water well with wooden frame and rope winch on grass, single game tile, top-down view, bottom edge aligned` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_village_house` | `small countryside farm house, yellow-brown wall with wooden beams and rustic roof, single game tile, top-down view` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_village_tree_01` | `round-canopy broadleaf tree with warm brown trunk on grass, single game tile, top-down view` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_village_tree_02` | `two small broadleaf trees clustered on grass, slight height variety, single game tile, top-down view` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_village_grass_01_iso` | `isometric 2:1 diamond floor tile, rhombus-shaped bright meadow grass texture, soft green with small tufts, diamond filling the full frame, corners transparent` | +00 通用负面 |
| `tile_village_grass_02_iso` | `isometric 2:1 diamond floor tile, rhombus-shaped meadow grass with tiny wildflowers, diamond filling the full frame, corners transparent` | +00 通用负面 |
| `tile_village_path_iso` | `isometric 2:1 diamond floor tile, rhombus-shaped packed dirt path texture with grass edges, diamond filling the full frame, corners transparent` | +00 通用负面 |
| `tile_village_well_iso` | `stone water well with wooden frame on isometric diamond tile, rhombus grass floor base, motif fully inside the diamond, bottom edge aligned to diamond lower edge` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_village_house_iso` | `small countryside farm house on isometric diamond tile, yellow-brown wall with wooden beams, motif fully inside the diamond` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_village_tree_01_iso` | `round-canopy broadleaf tree on isometric diamond tile, rhombus grass floor base, motif fully inside the diamond` | +00 通用负面（另加：`overlapping tile edges`） |
| `tile_village_tree_02_iso` | `two small broadleaf trees clustered on isometric diamond tile, rhombus grass floor base, motif fully inside the diamond` | +00 通用负面（另加：`overlapping tile edges`） |

## 验收标准

- 通用：00 §六全款；**方形 7 件 128×128、菱形 7 件 256×128**（00 §六-8 菱形几何——完整版预备件同规验收，过 V-M6-iso-asset-geometry）；方形标注「可平铺」三件（grass×2/path）四边无缝；物件件轮廓不越画布（菱形件=不越菱形）、底缘对齐格界（菱形件=菱形下缘）。
- 调性检查：与 02 矿洞组并排时「村子=明亮田园、矿洞=冷暗岩穴」反差成立（案 20 三支柱情绪切换的视觉承载）；本组阴影量显著少于矿洞组（安全区信号）；菱形版与方形版同件同色系（同套题材两视角）。
- AI 修整要求：全组按「全 AI 生成+人工修整」单轨执行（D2=B 已拍板、零采购预算）——可平铺件的接缝、菱形件四边中点对位与物件件同批一致性由人工修整收敛；色板/描边按 00 §三统一；来源一律登记 `art_source_log.md` AI 分区。
- 服务映射核对：草地×2/土路对应探索层 `etile_village_ground`/`etile_path`（etile_path 槽位 X2 已定稿、见清单行内注；**etile_village_ground 名称-资产错位注记**：display_name「村中土路」vs 资产 tile_village_grass_01/02——挂 M7 村图重做一并勘正）；水井/农舍/树木为探索图装饰件（案 20 §3.1 场景 3：陷泥板车不在 DEMO 必备清单、不产出；装饰格机制已建、见清单下※注记）；**菱形 `_iso` 7 件=完整版预备**（无现行战斗消费点——村子图战斗化时启用，DEMO 内不参与服务映射核对）。

## 来源留档

本组 14 件均待回填 → `art_source_log.md`（D2=B 全 AI 生成，统一登记 AI 分区；E1 批 `_iso` 占位件 7 件系程序生成非 AI 出图、正式件到位时再行留档）。

（本组 14 件：方形 7（新增 id·批 3.5a 占位入册·组 2 探索消费接线）+战棋菱形 `_iso` 7（**完整版预备**·E1 批 2026-10-09 占位入册·无战斗消费点）；合计 14 件 = 原 7 + `_iso` 新键 7（v2.0））
