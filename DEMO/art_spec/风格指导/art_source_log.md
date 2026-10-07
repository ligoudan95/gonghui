# art_source_log（美术素材来源留档表·骨架）

> 状态：v1.0 定稿（2026-09-30 用户审核通过；D1=A 团队规格书+用户执行生图入库、D2=B tile 全 AI 生成、暗门件=128×128 tile 已拍板）
> v1.0→v1.1 修订：2026-10-01 双席审计——「许可类型」值域补 AI 侧定义（`AI 工具条款`）+ 参考图防误入库注记（维护规则第 5 条）
> v1.1→v1.2 修订：2026-10-01 四席盲审 S4 席勘正——存放路径补「风格指导/」子目录+盘点口径 00-09 组勘正为 00-10 组（M6 方案 §3.2/§3.3 同步勘正）
> v1.2→v1.3 修订：2026-10-03 首批数据回填——AI 分区 6 行（批 3 试运行首件 bg_guild_hall+批 3 后半 5 件；来源工具经用户拍板统一=grsai/nano-banana-2）+汇总节 AI 披露件数 0→6+bg_association_hall 待入库注记
> v1.3→v1.4 修订：2026-10-03 美术资源全局审查批（两席 architect 并行）——新增「三、件×状态总表」（119 件逐件入库状态，解决「分不清哪件已入库」痛点；每次素材入库批由 @docs-updater 随变更集同步）+维护规则第 6 条
> v1.4→v1.5 修订：2026-10-03 协会背景重导出入库批——`bg_association_hall` 重导出原位替换入库（AI 分区补登 1 行，错件拦截闭环）+`bg_dormitory` 书名瑕疵经用户审核接受现状（撤销「待重生成」拍板）+件×状态总表快照更新（**7 正式+110 占位+2 未入册**，01 组背景组 7 件收官）
> v1.5→v1.6 修订：2026-10-03 小队交互图标七件入库批——AI 分区 +7 行（05 组收官·继 01 组后第二个收官素材组；来源经用户同日拍板=AI 生图·grsai/nano-banana-2，与背景批同源同口径）+件×状态总表 05 组 7 行转正（**14 正式+103 占位+2 未入册**）+汇总节 AI 披露件数 7→14；同日勘误：icon_pt_event「深蓝叹号」偏差销项（拆分脚本红蓝通道对调 bug 当日修复重入库、实测叹号暖金符合规格「金色」——05 组 v1.5）
> v1.6→v1.7 修订：2026-10-07 战士首两件动作资源入库批——AI 分区 +2 行（**04 单位动作集组首批**：spr_cls_warrior_idle〔角色参考锚图单帧复制 2 帧=用户拍板 2026-10-07 方案A，idle 帧带 [2,4]〕+spr_cls_warrior_melee_attack〔2 帧带内、两帧朝向相反原样导入待试玩观感反馈〕；来源=用户提供的 AI 生图·**工具拍板 grsai/nano-banana-2（2026-10-07，同日就地补正——与背景/图标批同源）**）+件×状态总表 04 组 2 行转正（**16 正式+101 占位+2 未入册**）+汇总节 AI 披露件数 14→16；同批动画显示链路存量 bug 两段修复登记见 M6 方案（unit_badge 末帧保护窗契约）
> 定位：DEMO 全部美术资产的来源与许可留档**单源**（M6 方案 §3.3）——AI 分区与购买分区**分别留档**（混用通道不得合并登记）；发布前披露清单见文末汇总节。
> 流程位置：M6 方案 §3.2 入库八步之**第⑦步回填本表**；第⑧步提交时「素材+registry+本表」同变更集（第①-⑥步见 [00_全局风格约束.md](00_全局风格约束.md) §六-7）。
> 存放口径：本表在文档侧 `DEMO/art_spec/风格指导/`（**路径勘正 2026-10-01 S4 席·低4**：与 11 份规格书同置「风格指导/」子目录，M6 方案 §3.3 原记 art_spec/ 根已同步勘正），不入 `data/` 域、不进 DataValidator 计数带（M6 方案 §3.3 已定）。
> 盘点口径：规格书 id 清单（00-10 组——**勘正 2026-10-01**：原记 00-09 组漏 10_字体组）即总盘点源；本表逐件回填后须与规格书可对账（每件一行、无遗漏）。
> **当前状态：AI 分区已回填 14 件（2026-10-03）**——背景 7 件：首批 6 件 `bg_guild_hall`（批 3 试运行首件·2026-10-01 生成）+ 批 3 后半 5 件（`bg_title`/`bg_battle_mine`/`bg_explore`/`bg_dormitory`/`bg_training_ground`·2026-10-02 生成、2026-10-03 同 id 原位替换入库）+ 第 7 件 `bg_association_hall`（2026-10-03 晨重导出原位替换入库——原 2026-10-01 错件拦截闭环，**01 组背景组 7 件全部转正**）；背景批来源通道与工具版本经用户拍板（2026-10-03 在线答复）统一=AI 生图·grsai/nano-banana-2（2026-10-01 挂账的 BG_2 来源问题一并闭环）。**图标 7 件（2026-10-03 小队交互图标批——05 组 7 件全部转正收官，继 01 组后第二个收官素材组）**：用户合集出图《小队交互七个图标合集.png》（5504×3072、7 枚金框徽章横排）经临时脚本拆分（连通域泛洪去底+边缘软过渡去污染+预乘缩放）导出 7 件透明底母版同 id 原位替换入库（icons 6 件 64×64+tile_secret_passage 128×128）；本批来源通道经用户拍板（2026-10-03 在线答复「grsai nano-banana-2」）统一=AI 生图·grsai/nano-banana-2——与背景批同源，全库 14 件 AI 生成件来源归一。`bg_dormitory` 左下角书名瑕疵经用户 2026-10-03 审核接受现状（原「待重生成」拍板同日撤销）；购买分区维持零数据；占位件按维护规则第 3 条不登记本表。**角色组首两件（2026-10-07）**：04 单位动作集组首批 2 件正式入库——`spr_cls_warrior_idle`（角色参考锚图单帧站姿 3392×5056→128×256 两帧，帧 1=帧 0 上移 1px 浮动〔**用户拍板 2026-10-07 方案A**：锚点单帧越出 idle 帧数带 [2,4]，复制出 2 帧〕）+`spr_cls_warrior_melee_attack`（AI 生图 5504×3072 两帧并排→128×256 两帧竖条：上=蓄力、下=挥砍+弧光特效；2 帧带 [2,4] 内低于推荐 3，**两帧朝向相反系原样导入**——用户已知悉、待试玩观感反馈）；经 tools/process_warrior_anim.py 处理入库（白底软键转 alpha+不触边界白连通域孔洞回填+列统计两帧自适应分割+脚底基线对齐+像素实证断言，可重复执行产出最终态）；registry/naming 已有键零改动；像素实证全过（无 BGR 对调、三态截图 mean-diff 28.22/19.01/23.31）。**逐件入库状态一览见下方「三、件×状态总表」（v1.4 起）。**

---

## 〇、公共字段说明（两分区同构字段）

| 字段 | 填写说明 |
|---|---|
| 资源 id | 与规格书及 registry 键一致（文件名 == 资源 id） |
| 中文名 | 规格书内中文名 |
| 来源通道 | `AI 生图` 或 `素材库购买`（决定登记到哪个分区） |
| 许可类型 | `CC0` / `付费商用` / `署名原文` / `AI 工具条款`——前三值适用**购买分区**；**AI 生图分区适用 `AI 工具条款`**（v1.1 补 AI 侧定义·2026-10-01）：按生成工具的用户条款确认商用授权，「工具+版本」字段即为此备，须附工具条款链接；署名类须原文摘录许可条款，附商店页/工具条款链接 |
| 商用范围 | 本项目商用范围 = `Steam+TapTap`（超出/受限须在此列注明） |
| 披露标记 | `需披露（AI 生成）` / `无需披露（购买·CC0）` / `需署名` 三值之一——汇总节按此列过滤 |
| 用途场景 | 该件在游戏中的使用位置（如「战棋单位动作」「公会屏背景」） |

## 一、AI 生图分区（工具+版本+日期+提示词摘要）

> 每件一行；提示词摘要取实际使用的完整提示词核心短语（完整版可引规格书条目 id）。

| 资源 id | 中文名 | 来源通道 | 工具+版本 | 生成日期 | 提示词摘要 | 许可类型 | 商用范围 | 披露标记 | 用途场景 |
|---|---|---|---|---|---|---|---|---|---|
| bg_guild_hall | 公会主场景 | AI 生图 | grsai / nano-banana-2 | 2026-10-01 | cozy rundown fantasy guild hall interior, exposed wooden beams, stone fireplace with warm fire, empty banner hook（01 组条目） | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 公会主屏背景（guild_shell 接线） |
| bg_title | 标题屏背景 | AI 生图 | grsai / nano-banana-2 | 2026-10-02 | cozy fantasy guild building exterior at dusk, warm glowing windows, wooden sign, distant town silhouette（01 组条目） | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 标题屏背景 |
| bg_battle_mine | 战斗屏矿洞环境 | AI 生图 | grsai / nano-banana-2 | 2026-10-02 | cave mine interior environment backdrop, dark blue-gray rock walls with orange torch lights, depth perspective（01 组条目） | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 战斗屏环境衬底 |
| bg_explore | 探索屏环境 | AI 生图 | grsai / nano-banana-2 | 2026-10-02 | dim neutral dark backdrop with subtle vignette, soft edge darkening, exploration mood（01 组条目） | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 探索屏环境衬底 |
| bg_dormitory | 宿舍设施场景 | AI 生图 | grsai / nano-banana-2 | 2026-10-02 | small fantasy guild dormitory room, several wooden beds with neat blankets, bedside cabinets, small window with warm light（01 组条目）。左下角书名瑕疵（Adventurer's Guide/Guild Tales 可读英文字样）经用户 2026-10-03 审核接受现状——原「待重生成」拍板同日撤销、维持本件 | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 宿舍设施屏背景 |
| bg_training_ground | 训练场设施场景 | AI 生图 | grsai / nano-banana-2 | 2026-10-02 | small fantasy training ground, wooden practice dummies, weapon racks, sandy yard with wooden fence, warm daylight（01 组条目） | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 训练场设施屏背景 |
| bg_association_hall | 冒险者协会入口 | AI 生图 | grsai / nano-banana-2 | 2026-10-03 | fantasy adventurer association entrance facade, wooden notice board with blank paper sheets, reception counter silhouette, warm lamp glow（01 组条目·重导出替代错件） | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 协会屏背景 |
| icon_explore_party | 探索小队标记 | AI 生图 | grsai / nano-banana-2 | 2026-10-03 | 05 组条目·《小队交互七个图标合集》一次出图后拆分；实际产图=**提灯**（规格「白色行进旗帜」偏差——用户预定拍板「以提灯为准」，05 组 v1.4 注记） | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 探索屏小队所在格标记 |
| icon_pt_event | 事件点 | AI 生图 | grsai / nano-banana-2 | 2026-10-03 | 05 组条目·合集拆分；叹号暖金/琥珀色、符合规格「金色」（v1.4 曾误记「深蓝」——系拆分脚本红蓝通道对调 bug 误报、当日修复重入库后销项，05 组 v1.5 勘误） | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 探索屏事件点图标（链入口与单点共用） |
| icon_pt_treasure | 宝箱 | AI 生图 | grsai / nano-banana-2 | 2026-10-03 | 05 组条目·合集拆分 | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 探索屏宝箱点图标 |
| icon_pt_target | 委托目标点 | AI 生图 | grsai / nano-banana-2 | 2026-10-03 | 05 组条目·合集拆分 | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 探索屏委托目标点图标（常显） |
| icon_pt_exit | 出口 | AI 生图 | grsai / nano-banana-2 | 2026-10-03 | 05 组条目·合集拆分 | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 探索屏出口点图标 |
| icon_pt_battle | 必然遭遇点 | AI 生图 | grsai / nano-banana-2 | 2026-10-03 | 05 组条目·合集拆分 | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 探索屏必然遭遇点图标 |
| tile_secret_passage | 暗门开启窄道 | AI 生图 | grsai / nano-banana-2 | 2026-10-03 | 05 组条目·合集拆分；实际产图=**圆形徽章**（金框徽章风格、非规格「俯视满幅 tile」——用户拍板接受注记，如需满幅 tile 后续单独生图；05 组 v1.4 注记） | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 探索屏暗门揭示换格（etile_secret_passage·reveal_tile_id） |
| spr_cls_warrior_idle | 战士·待机 | AI 生图 | grsai / nano-banana-2（用户拍板 2026-10-07） | 2026-10-07 入库（生图日未留档） | 04 组 §5.1 锚串·角色参考锚图（art_spec/角色参考/anchor_spr_cls_warrior.png 3392×5056 单帧站姿）；**用户拍板 2026-10-07 方案A**：锚点单帧越出 idle 帧数带 [2,4]，复制出 2 帧（帧 1=帧 0 上移 1px 浮动，占位 idle 先例同款）；处理见 tools/process_warrior_anim.py | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 战棋战士待机动画竖条（UnitBadge idle·128×256 两帧） |
| spr_cls_warrior_melee_attack | 战士·近战攻击 | AI 生图 | grsai / nano-banana-2（用户拍板 2026-10-07） | 2026-10-07 入库（生图日未留档） | 04 组 §5.1 锚串+动作短语·AI 生图（art_spec/act/spr_cls_warrior_melee_attack.png 5504×3072 左右并排两帧：蓄力+挥砍带弧光）；实际 2 帧带 [2,4] 内、低于推荐 3；**两帧朝向相反系原样导入**（用户已知悉、待试玩观感反馈，观感不佳按动作级替换粒度单件重产）；处理见 tools/process_warrior_anim.py | AI 工具条款 | Steam+TapTap | 需披露（AI 生成） | 战棋战士近战攻击动画竖条（UnitBadge melee_attack·128×256 两帧） |

> 工具条款链接待补：公共字段说明要求「AI 工具条款」须附工具条款链接——grsai（nano-banana-2）条款链接待用户提供后补登于本注记（发布前披露核验前补齐即可）。
> 图标批注记（2026-10-03·v1.6）：本批 7 件来源通道经用户拍板（2026-10-03 在线答复「grsai nano-banana-2」）=grsai/nano-banana-2，与背景批 7 件同源同口径（工具条款链接随下方待补注记一并核验补齐）；合集原图《小队交互七个图标合集.png》（5504×3072）与 7 件透明底母版（约 770px 方形）留档 `art_spec/icon/`（参照 `art_spec/background/` 批次留档先例——留档件不入 `assets/`、不登记 registry）。同日勘误：拆分脚本红蓝通道对调 bug（cv2 BGR 序导出 PIL 未转回 RGB）曾致整套图标红蓝互换入库（用户游戏内见紫蓝色图标后报告），当日修复——7 件母版+游戏件重出重入库（`--import` 已重跑、资产接线测试 32+3+6 全绿）、视觉复核整套恢复暖色系（金环+红底+暖黄橙光）；icon_pt_event「深蓝叹号」偏差系该 bug 误报、销项（05 组 v1.5）。
> 角色批注记（2026-10-07·v1.7）：本批 2 件（04 单位动作集组首批正式资源）为**用户提供的 AI 生图**——源图留档 `art_spec/act/spr_cls_warrior_melee_attack.png`（5504×3072）+`art_spec/角色参考/anchor_spr_cls_warrior.png`（3392×5056）；**工具+版本=grsai/nano-banana-2（用户在线答复原文 2026-10-07「grsai nano-banana-2（推荐）」）**——与背景批/图标批同源同口径，全库 16 件 AI 生成件来源归一（许可条款链接随上方待补注记一并核验补齐）。处理管线=tools/process_warrior_anim.py（白底软键转 alpha+不触边界白连通域孔洞回填+列统计两帧自适应分割+脚底基线 y=123 对齐+**像素实证断言退出码把关**：四角 alpha=0/主体内部点 alpha=255/高饱和点逐通道色差 <35 防 BGR 对调/半透明占比 0.2%-15%，可重复执行产出最终态）；像素实证全过、三态截图 mean-diff 28.22/19.01/23.31（独立复算一致）。同批修复动画显示链路存量 bug（unit_badge 末帧吞帧+低优先级回调打断——契约登记见 M6 方案 §2.2 末帧保护窗）。临时验证产物（art_spec/probe_*、m6_warrior_*、_verify_*、_strike_bottom* 等）保留待清理。

## 二、素材库购买分区（商店+包名+订单号）

> 每件一行；同一素材包多件可逐件登记并注明同订单号（逐件对账优先）。

| 资源 id | 中文名 | 来源通道 | 商店 | 包名 | 订单号 | 许可类型 | 商用范围 | 披露标记 | 用途场景 |
|---|---|---|---|---|---|---|---|---|---|
| （待回填） | | | | | | | | | |

## 三、件×状态总表（119 件逐件入库状态·快照 2026-10-07）

> **维护规则**：本表为 00-10 组规格书 119 件清单的**逐件入库状态快照**——每次素材入库批（入库/替换/拦截/重生成等状态变更）由 @docs-updater 随变更集同步更新（与第 1 条同变更集）；状态权威=各规格书盘点口径+registry 实况，本表提供「哪件已入库」的一览检索。
> **快照时点**：2026-10-07（战士首两件动作资源入库批后；registry 118 键/naming 274 条维持）。
> **状态速览**：**已正式 16**（背景 7=bg_guild_hall+批 3 后半 5 件+bg_association_hall 重导出；小队交互图标 7=2026-10-03 图标批——**05 组收官**；单位动作 2=2026-10-07 战士 idle/melee——**04 组首批**）/ **占位待生成 101** / **未入册 2**（字体）——合计 119。特殊状态注记 2 件：`bg_dormitory`（正式桶·左下角书名瑕疵经用户 2026-10-03 审核接受——原「待重生成」拍板同日撤销）、`tile_secret_passage`（正式桶·圆形徽章与「俯视满幅 tile」规格偏差经用户 2026-10-03 拍板接受注记——如需满幅 tile 后续单独生图，05 组 v1.4）；另观察注记 1 件：`spr_cls_warrior_melee_attack`（正式桶·两帧朝向相反原样导入，用户已知悉、**待试玩观感反馈**，观感不佳按动作级替换粒度单件重产）；registry 另含 `ui_main_theme` 登记键（theme 非生图件、不在 119 计数，故不列入下表）。
> 「占位待生成」释义：程序占位件在册顶位、正式件未到位——04 组=批 1 程序竖条（gen_unit_anim_frames）、其余组=批 3.5a 程序件（gen_asset_placeholders）。

### 01 背景组（7 件·全部已正式·本组收官 2026-10-03）

| 资源 id | 中文名 | 状态 |
|---|---|---|
| bg_guild_hall | 公会主场景 | **已正式**（批 3 试运行首件·2026-10-01；AI 分区已留档） |
| bg_title | 标题屏背景 | **已正式**（批 3 后半·2026-10-03；AI 分区已留档） |
| bg_battle_mine | 战斗屏矿洞环境 | **已正式**（批 3 后半·2026-10-03；AI 分区已留档） |
| bg_explore | 探索屏环境 | **已正式**（批 3 后半·2026-10-03；AI 分区已留档） |
| bg_dormitory | 宿舍设施场景 | **已正式**（批 3 后半·2026-10-03；AI 分区已留档；左下角书名瑕疵经用户 2026-10-03 审核接受、原「待重生成」拍板同日撤销） |
| bg_training_ground | 训练场设施场景 | **已正式**（批 3 后半·2026-10-03；AI 分区已留档） |
| bg_association_hall | 冒险者协会入口 | **已正式**（2026-10-03 重导出原位替换入库；原 2026-10-01 错件拦截闭环；AI 分区已留档） |

### 02 矿洞 tile 组（9 件）

| 资源 id | 中文名 | 状态 |
|---|---|---|
| tile_mine_floor_01 | 矿洞地面·基岩 | 占位待生成（消费点已接线） |
| tile_mine_floor_02 | 矿洞地面·碎石变体 | 占位待生成（消费点已接线） |
| tile_mine_wall | 矿洞岩壁 | 占位待生成（消费点已接线） |
| tile_mine_rock | 障碍·塌方碎石堆 | 占位待生成 |
| tile_mine_cart | 障碍·废弃矿车 | 占位待生成 |
| tile_battle_bush | 战棋草丛 | 占位待生成（消费点已接线） |
| tile_battle_highground | 战棋高地 | 占位待生成（消费点已接线） |
| tile_battle_poison_swamp | 战棋毒沼 | 占位待生成（消费点已接线） |
| tile_battle_trap | 战棋陷阱（v1.1 扩件） | 占位待生成（消费点已接线） |

### 03 村子 tile 组（7 件）

| 资源 id | 中文名 | 状态 |
|---|---|---|
| tile_village_grass_01 | 草地·基色 | 占位待生成（消费点已接线） |
| tile_village_grass_02 | 草地·野花变体 | 占位待生成（消费点已接线） |
| tile_village_path | 土路 | 占位待生成（村图现无 path 格零渲染，M7 加格生效） |
| tile_village_well | 水井 | 占位待生成（装饰格障碍已接线） |
| tile_village_house | 农舍 | 占位待生成（装饰格障碍已接线） |
| tile_village_tree_01 | 树木·阔叶单株 | 占位待生成（装饰格障碍已接线） |
| tile_village_tree_02 | 树木·双株变体 | 占位待生成（装饰格障碍已接线） |

### 04 单位动作集组（54 件·批 1 程序占位竖条·2026-10-07 首批 2 件转正）

| 资源 id | 中文名 | 状态 |
|---|---|---|
| spr_cls_warrior_idle | 战士·待机 | **已正式**（2026-10-07 角色批·AI 分区已留档；锚点单帧复制 2 帧=用户拍板方案A〔帧带 [2,4]〕） |
| spr_cls_warrior_move | 战士·移动 | 占位待生成（消费点已接线） |
| spr_cls_warrior_melee_attack | 战士·近战攻击 | **已正式**（2026-10-07 角色批·AI 分区已留档；2 帧带内〔推荐 3〕、两帧朝向相反原样导入待试玩观感反馈） |
| spr_cls_warrior_cast_ranged | 战士·远程施放 | 占位待生成（消费点已接线） |
| spr_cls_warrior_hit | 战士·受击 | 占位待生成（消费点已接线） |
| spr_cls_warrior_downed | 战士·倒地 | 占位待生成（消费点已接线） |
| spr_cls_rogue_idle | 盗贼·待机 | 占位待生成（消费点已接线） |
| spr_cls_rogue_move | 盗贼·移动 | 占位待生成（消费点已接线） |
| spr_cls_rogue_melee_attack | 盗贼·近战攻击 | 占位待生成（消费点已接线） |
| spr_cls_rogue_cast_ranged | 盗贼·远程施放 | 占位待生成（消费点已接线） |
| spr_cls_rogue_hit | 盗贼·受击 | 占位待生成（消费点已接线） |
| spr_cls_rogue_downed | 盗贼·倒地 | 占位待生成（消费点已接线） |
| spr_cls_mage_idle | 法师·待机 | 占位待生成（消费点已接线） |
| spr_cls_mage_move | 法师·移动 | 占位待生成（消费点已接线） |
| spr_cls_mage_melee_attack | 法师·近战攻击 | 占位待生成（消费点已接线） |
| spr_cls_mage_cast_ranged | 法师·远程施放 | 占位待生成（消费点已接线） |
| spr_cls_mage_hit | 法师·受击 | 占位待生成（消费点已接线） |
| spr_cls_mage_downed | 法师·倒地 | 占位待生成（消费点已接线） |
| spr_cls_priest_idle | 牧师·待机 | 占位待生成（消费点已接线） |
| spr_cls_priest_move | 牧师·移动 | 占位待生成（消费点已接线） |
| spr_cls_priest_melee_attack | 牧师·近战攻击 | 占位待生成（消费点已接线） |
| spr_cls_priest_cast_ranged | 牧师·远程施放 | 占位待生成（消费点已接线） |
| spr_cls_priest_hit | 牧师·受击 | 占位待生成（消费点已接线） |
| spr_cls_priest_downed | 牧师·倒地 | 占位待生成（消费点已接线） |
| spr_cls_ranger_idle | 游侠·待机 | 占位待生成（消费点已接线） |
| spr_cls_ranger_move | 游侠·移动 | 占位待生成（消费点已接线） |
| spr_cls_ranger_melee_attack | 游侠·近战攻击 | 占位待生成（消费点已接线） |
| spr_cls_ranger_cast_ranged | 游侠·远程施放 | 占位待生成（消费点已接线） |
| spr_cls_ranger_hit | 游侠·受击 | 占位待生成（消费点已接线） |
| spr_cls_ranger_downed | 游侠·倒地 | 占位待生成（消费点已接线） |
| spr_cls_arcanist_idle | 奇术师·待机 | 占位待生成（消费点已接线） |
| spr_cls_arcanist_move | 奇术师·移动 | 占位待生成（消费点已接线） |
| spr_cls_arcanist_melee_attack | 奇术师·近战攻击 | 占位待生成（消费点已接线） |
| spr_cls_arcanist_cast_ranged | 奇术师·远程施放 | 占位待生成（消费点已接线） |
| spr_cls_arcanist_hit | 奇术师·受击 | 占位待生成（消费点已接线） |
| spr_cls_arcanist_downed | 奇术师·倒地 | 占位待生成（消费点已接线） |
| spr_en_mutant_rat_idle | 变异鼠·待机 | 占位待生成（消费点已接线） |
| spr_en_mutant_rat_move | 变异鼠·移动 | 占位待生成（消费点已接线） |
| spr_en_mutant_rat_melee_attack | 变异鼠·近战攻击 | 占位待生成（消费点已接线） |
| spr_en_mutant_rat_cast_ranged | 变异鼠·远程施放 | 占位待生成（消费点已接线） |
| spr_en_mutant_rat_hit | 变异鼠·受击 | 占位待生成（消费点已接线） |
| spr_en_mutant_rat_downed | 变异鼠·倒地 | 占位待生成（消费点已接线） |
| spr_en_goblin_miner_idle | 哥布林矿工·待机 | 占位待生成（消费点已接线） |
| spr_en_goblin_miner_move | 哥布林矿工·移动 | 占位待生成（消费点已接线） |
| spr_en_goblin_miner_melee_attack | 哥布林矿工·近战攻击 | 占位待生成（消费点已接线） |
| spr_en_goblin_miner_cast_ranged | 哥布林矿工·远程施放 | 占位待生成（消费点已接线） |
| spr_en_goblin_miner_hit | 哥布林矿工·受击 | 占位待生成（消费点已接线） |
| spr_en_goblin_miner_downed | 哥布林矿工·倒地 | 占位待生成（消费点已接线） |
| spr_en_elite_boss_idle | 矿洞祸首（精英）·待机 | 占位待生成（消费点已接线） |
| spr_en_elite_boss_move | 矿洞祸首（精英）·移动 | 占位待生成（消费点已接线） |
| spr_en_elite_boss_melee_attack | 矿洞祸首（精英）·近战攻击 | 占位待生成（消费点已接线） |
| spr_en_elite_boss_cast_ranged | 矿洞祸首（精英）·远程施放 | 占位待生成（消费点已接线） |
| spr_en_elite_boss_hit | 矿洞祸首（精英）·受击 | 占位待生成（消费点已接线） |
| spr_en_elite_boss_downed | 矿洞祸首（精英）·倒地 | 占位待生成（消费点已接线） |

### 05 小队与交互图标组（7 件·全部已正式·本组收官 2026-10-03）

| 资源 id | 中文名 | 状态 |
|---|---|---|
| icon_explore_party | 探索小队标记 | **已正式**（2026-10-03 图标批·AI 分区已留档；实际=提灯，用户拍板「以提灯为准」） |
| icon_pt_event | 事件点 | **已正式**（2026-10-03 图标批·AI 分区已留档；同日通道对调 bug 修复重入库后叹号暖金符合规格——05 组 v1.5 勘误） |
| icon_pt_treasure | 宝箱 | **已正式**（2026-10-03 图标批·AI 分区已留档） |
| icon_pt_target | 委托目标点 | **已正式**（2026-10-03 图标批·AI 分区已留档） |
| icon_pt_exit | 出口 | **已正式**（2026-10-03 图标批·AI 分区已留档） |
| icon_pt_battle | 必然遭遇点 | **已正式**（2026-10-03 图标批·AI 分区已留档） |
| tile_secret_passage | 暗门开启窄道 | **已正式**（2026-10-03 图标批·AI 分区已留档；圆形徽章与满幅 tile 规格偏差经用户拍板接受注记——05 组 v1.4） |

### 06 迷雾组（2 件）

| 资源 id | 中文名 | 状态 |
|---|---|---|
| fx_fog_unseen | 未探索浓雾 | 占位待生成（2026-10-01 重生成全不透明；消费点已接线） |
| fx_fog_dim | 已探索暗态滤镜 | 占位待生成（2026-10-01 重生成全不透明；消费点已接线） |

### 07 系统图标组（19 件）

| 资源 id | 中文名 | 状态 |
|---|---|---|
| icon_res_gold | 货币 | 占位待生成（消费点已接线） |
| icon_res_exp | 经验 | 占位待生成（消费点已接线） |
| icon_res_repu | 声望 | 占位待生成（键已在库；guild_shell 顶栏声望行接线=批 4 顺手项〔2026-10-03 拍板登记〕） |
| icon_attr_str | 力量 | 占位待生成（消费点已接线） |
| icon_attr_agi | 敏捷 | 占位待生成（消费点已接线） |
| icon_attr_con | 体质 | 占位待生成（消费点已接线） |
| icon_attr_int | 智力 | 占位待生成（消费点已接线） |
| icon_attr_wis | 感知 | 占位待生成（消费点已接线） |
| icon_attr_wil | 意志 | 占位待生成（消费点已接线） |
| icon_attr_luk | 幸运 | 占位待生成（消费点已接线） |
| icon_res_hp | 生命 | 占位待生成（消费点已接线） |
| icon_res_mp | 法力 | 占位待生成（消费点已接线） |
| icon_res_sp | 精力 | 占位待生成（消费点已接线） |
| icon_class_warrior | 职业·战士 | 占位待生成（消费点已接线） |
| icon_class_rogue | 职业·盗贼 | 占位待生成（消费点已接线） |
| icon_class_mage | 职业·法师 | 占位待生成（消费点已接线） |
| icon_class_priest | 职业·牧师 | 占位待生成（消费点已接线） |
| icon_class_ranger | 职业·游侠 | 占位待生成（消费点已接线） |
| icon_class_arcanist | 职业·奇术师 | 占位待生成（消费点已接线） |

### 08 UI 基础件组（8 件）

| 资源 id | 中文名 | 状态 |
|---|---|---|
| ui_panel_ninepatch | 面板九宫格母图 | 占位待生成（消费点已接线） |
| ui_button_normal | 主按钮·常态 | 占位待生成（**按钮三态延批 4 切换**——D1 口径，main_theme 头注） |
| ui_button_hover | 主按钮·悬停 | 占位待生成（**按钮三态延批 4 切换**——D1 口径） |
| ui_button_disabled | 主按钮·禁用 | 占位待生成（**按钮三态延批 4 切换**——D1 口径） |
| ui_label_result_crit_success | 大成功标签底 | 占位待生成（消费点已接线） |
| ui_label_result_success | 成功标签底 | 占位待生成（消费点已接线） |
| ui_label_result_failure | 失败标签底 | 占位待生成（消费点已接线） |
| ui_label_result_crit_failure | 大失败标签底 | 占位待生成（消费点已接线） |

### 09 战棋叠加件与 D20 组（4 件）

| 资源 id | 中文名 | 状态 |
|---|---|---|
| fx_battle_select | 选中框 | 占位待生成（消费点已接线） |
| fx_battle_range | 范围指示格面 | 占位待生成（2026-10-01 重生成全不透明；消费点已接线） |
| fx_battle_path_arrow | 路径箭头 | 占位待生成（**消费点已拆除 2026-10-03·D4 修订**——路径表现改路径格金色闪烁高光；registry 键保留备用未删，09 组 v1.4） |
| fx_d20 | D20 骰面 | 占位待生成（消费点已接线） |

### 10 字体组（2 件）

| 资源 id | 中文名 | 状态 |
|---|---|---|
| font_cn_body | 正文中文字体 | **未入册**（ttf 无法程序造、批 3.5a 跳过占位与登记；素材到位登记前须先扩 ASSET_ID_PREFIXES 合法集加 font_） |
| font_cn_title | 标题装饰字 | **未入册**（同上） |

> 本表不含：`ui_main_theme`（registry theme 登记键、非生图件、不在 119 计数）；风格参考图 BG_1.jpg/BG_2.png（非资产件，见维护规则第 5 条）；预留与不适用项（公会旗帜/徽记、标题 LOGO、结局画面、加载画面、光标、进度条底图、分隔线与头像框——见 00_全局风格约束 §八·五）。

## 四、汇总节：发布前 Steam/TapTap 披露清单

> 发布前按「披露标记」列过滤生成：①AI 生成件 → Steam 商店页 AI 内容披露（Steam 2024 年起强制）；②署名类 → 制作人员名单/商店页致谢原文摘录；③TapTap 政策发布前查证（案 20 §4.4 合规注意）。当前 AI 生成件 16 件待发布前披露（随入库批次滚动更新）。

| 披露类别 | 件数 | 披露位置 | 状态 |
|---|---|---|---|
| AI 生成内容披露（Steam） | 16（bg_* 背景件 7+小队交互图标 7+单位动作件 2〔2026-10-07〕，随入库滚动更新） | Steam 商店页 AI 内容声明 | 未开始（发布前动作） |
| 署名致谢（如适用） | 0（待回填） | 制作人员名单/商店页 | 未开始 |
| TapTap 披露（政策确认后） | 0（待回填） | TapTap 商店页（政策发布前查证） | 未开始 |

## 五、维护规则

1. 每入库批次同步回填对应分区行，**不得事后补登**（提交时素材+registry+本表同变更集，M6 方案 §3.2 第⑧步）。
2. 购买件逐包核对商用许可原文（CC0/付费商用/署名条款各异——案 20 §4.4），许可原文摘录或链接附于「许可类型」列。
3. 占位件（程序化生成顶位）不登记本表——本表只登**正式件**来源；占位→正式的替换动作按规格书 id 原位进行。
4. 三方盘点（规格书↔registry↔assets/，M6 方案 §五 批 4）时以本表为来源侧核对件。
5. **参考图防误入库**（v1.1·2026-10-01 双席审计）：`art_spec/background/` 下 `BG_1.jpg`/`BG_2.png` 为**风格参考图非资产件**（BG_2 已按用户执行生图流程转 `bg_guild_hall` 正式入库——该件来源行已随 2026-10-03 来源拍板统一回填 AI 分区）——参考图不入 `assets/`、不登记 registry、不回填本表。
6. **件×状态总表随每入库批同步**（v1.4·2026-10-03）：第三节逐件状态（入库/替换/拦截/重生成）随素材变更集由 @docs-updater 更新——正式件入库时对应行改「已正式」并注明批次；本表（一/二分区）仍只登正式件来源、与状态总表互为明细与一览。

（已回填 2026-10-07：AI 分区 16 件〔背景批 7=首批 6+协会重导出 1；图标批 7=小队交互图标·05 组收官；角色批 2=战士 idle/melee·04 组首批——来源拍板 grsai/nano-banana-2（2026-10-07，与前两批同源）〕；购买分区待入库后补登；件×状态总表快照 2026-10-07·v1.7 更新）
