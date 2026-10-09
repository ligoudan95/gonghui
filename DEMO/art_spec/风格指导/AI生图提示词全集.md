# AI 生图提示词全集（生产辅助交付版）

> 依据：`DEMO/art_spec/风格指导/` 规格书 v1.3 各组（01-09）+ `00_全局风格约束.md` §五（提示词通用前缀与通用负面词**单源**）
> 生成日期：2026-10-02
> 定位：**生产辅助交付版**——将规格书「（00 前缀）+ 专属串」引用式写法拼装为**逐件完整提示词**，用户复制即用、全程零加工；不占 00-10 编号、非规格书体系成员、不改变 119 件总量口径
> 覆盖范围：119 件中生图待产 **116 件** = 01 背景 6 + 02 矿洞 tile 9 + 03 村子 tile 7 + 04 单位动作集 54 + 05 小队与交互图标 7 + 06 迷雾 2 + 07 系统图标 19 + 08 UI 基础件 8 + 09 战棋叠加与 D20 4；`bg_guild_hall` 已正式入库不重出；字体 2 件（font_cn_body/font_cn_title）非 AI 生图通道，文末单列说明
> 口径勘注：派工口径「62 件」= registry 批 3.5a 新增占位键数（不含批 1 已入册的 54 个 `spr_*` 单位件键）；按规格书 v1.3 逐组核对后的生图覆盖范围实为 **116 件**（含 04 组 54 件，与派工分组清单一致），本文档按 116 件全量交付
> 快照注记 2026-10-03：本全集为 2026-10-02 时点快照（116 件生图口径）；批 3 后半 5 件背景+bg_association_hall 重导出（2026-10-03 入库、错件拦截闭环）6 件+小队交互图标 7 件（2026-10-03 图标批入库、**05 组收官**——《小队交互七个图标合集》一次出图后拆分，两处图与规格偏差注记见 05 组 v1.5（2026-10-03 勘误：原三处中「深蓝叹号」系拆分脚本通道对调 bug 误报、当日修复重入库销项））合计 13 件已正式入库、实际待产 103 件；bg_dormitory 书名瑕疵经用户 2026-10-03 审核接受现状（维持已入库件、原「待重生成」拍板撤销）；bg_title/bg_explore 条目内旧「待拍板」注已由实际出件落地。状态以规格书+art_source_log 状态总表为准。
> 快照注记 2026-10-09：**战棋等距改造 E1 批**——战棋消费键破裂为菱形另制：①5 件同 id 重制 **256×128 菱形**（`tile_battle_bush`/`tile_battle_highground`/`tile_battle_trap`+`fx_battle_select`/`fx_battle_range`——条目规格与提示词已就地修订 top-down→isometric）；②**12 件 `_iso` 新键条目并入**（02 矿洞组 5+03 村子组 7〔**战棋菱形·完整版预备**——无战斗消费点，村子图战斗化时启用〕）；③覆盖范围 116→**128 件**（总盘 119→131，registry 118→130 键）；④`tile_mine_rock`/`tile_mine_cart`（方形）与 `tile_battle_poison_swamp`（方形）条目保留——E1 起无战棋消费（rock/cart 无现行消费点备用、poison_swamp 转探索专用），提示词维持方形口径不删。菱形件通用规格与几何约束见 `00_全局风格约束.md` §六-8；⑤tile 层正式件产出归 **M6 后专项批 E2 素材波**（M6 批 4 收窄为动作件/图标验收——见 M6 方案），各组「生产顺序建议 P1-P6」维持相对次序参考。

---

## 使用总说明（复制前必读）

1. **提示词构成**：每件完整正向提示词 = 00 §五前缀（A=非单位件 / B=单位件）+ 该件专属串 + 必要技术补充（透明底/比例词），已拼装润色为语法连贯的完整英文串——**直接复制使用，无「（00 前缀）+」类占位引用**。
2. **负面词**：以 00 §五通用负面词单源为基串（全卷逐字节一致）；规格书个别件「另加」项已并入该件负面串尾（与基串逗号分隔）；完全冗余的另加项（如 text/letters 已在基串内）不重复追加、在件条目下注明。
3. **透明底**：多数 AI 工具不直接输出 alpha 通道——提示词中 transparent background 用于压制背景场景出现，出图后**白底/纯色底扣图为标准流程**（各件「出图后处理」栏已注明）。
4. **尺寸**：AI 工具通常不支持任意分辨率——按目标比例出图后裁切/缩放（各件「出图后处理」栏已注明目标尺寸与切片要点）。
5. **风格锁定**：全项目赛璐璐平涂 + Q 版二头身（单位）+ 统一色板（00 §一/§二/§三）；工具/模型/LoRA 选择须以 00 总纲为准，不得引入色板外新色相；**每组首件产出后作为该组风格样张回填 00 §四，组内后续件以样张对齐优先于文字描述**。
6. **商用合规**：AI 生成件按 `art_source_log.md` AI 分区留档（工具+版本+日期+提示词摘要，完整提示词可直接引用本文档条目）；Steam 发布须披露 AI 生成内容（00 §七）。
7. **中文参考**：各条目代码块下方附「中文参考」整句中文翻译，仅供理解提示词语义；复制使用时请**只复制代码块内的英文串**，切勿把中文参考行带入提示词。

---

## 全量总表（128 件 = 116＋E1 批 `_iso` 新键 12·2026-10-09）

| 资源 id | 中文名 | 组 | 尺寸·帧带 | 优先级 |
|---|---|---|---|---|
| bg_association_hall | 冒险者协会入口 | 01 背景 | 1920×1080 | P3 背景 |
| bg_dormitory | 宿舍设施场景 | 01 背景 | 1920×1080 | P3 背景 |
| bg_training_ground | 训练场设施场景 | 01 背景 | 1920×1080 | P3 背景 |
| bg_title | 标题屏背景 | 01 背景 | 1920×1080 | P3 背景 |
| bg_battle_mine | 战斗屏矿洞环境 | 01 背景 | 1920×1080 | P3 背景 |
| bg_explore | 探索屏环境 | 01 背景 | 1920×1080 | P3 背景 |
| tile_mine_floor_01 | 矿洞地面·基岩 | 02 矿洞tile | 128×128 | P2 tile |
| tile_mine_floor_02 | 矿洞地面·碎石变体 | 02 矿洞tile | 128×128 | P2 tile |
| tile_mine_wall | 矿洞岩壁 | 02 矿洞tile | 128×128 | P2 tile |
| tile_mine_rock | 障碍·塌方碎石堆 | 02 矿洞tile | 128×128 | P2 tile |
| tile_mine_cart | 障碍·废弃矿车 | 02 矿洞tile | 128×128 | P2 tile |
| tile_battle_bush | 战棋草丛 | 02 矿洞tile | **256×128·菱形** | P2 tile |
| tile_battle_highground | 战棋高地 | 02 矿洞tile | **256×128·菱形** | P2 tile |
| tile_battle_poison_swamp | 战棋毒沼 | 02 矿洞tile | 128×128（探索专用） | P2 tile |
| tile_battle_trap | 战棋陷阱（v1.1 扩件） | 02 矿洞tile | **256×128·菱形** | P2 tile |
| tile_mine_floor_01_iso | 矿洞地面·基岩（战棋菱形） | 02 矿洞tile | 256×128 | P2 tile |
| tile_mine_floor_02_iso | 矿洞地面·碎石变体（战棋菱形） | 02 矿洞tile | 256×128 | P2 tile |
| tile_mine_rock_iso | 障碍·塌方碎石堆（战棋菱形） | 02 矿洞tile | 256×128 | P2 tile |
| tile_mine_cart_iso | 障碍·废弃矿车（战棋菱形） | 02 矿洞tile | 256×128 | P2 tile |
| tile_battle_poison_swamp_iso | 战棋毒沼（菱形） | 02 矿洞tile | 256×128 | P2 tile |
| tile_village_grass_01 | 草地·基色 | 03 村子tile | 128×128 | P2 tile |
| tile_village_grass_02 | 草地·野花变体 | 03 村子tile | 128×128 | P2 tile |
| tile_village_path | 土路 | 03 村子tile | 128×128 | P2 tile |
| tile_village_well | 水井 | 03 村子tile | 128×128 | P2 tile |
| tile_village_house | 农舍 | 03 村子tile | 128×128 | P2 tile |
| tile_village_tree_01 | 树木·阔叶单株 | 03 村子tile | 128×128 | P2 tile |
| tile_village_tree_02 | 树木·双株变体 | 03 村子tile | 128×128 | P2 tile |
| tile_village_grass_01_iso | 草地·基色（战棋菱形·完整版预备） | 03 村子tile | 256×128 | P2 tile |
| tile_village_grass_02_iso | 草地·野花变体（战棋菱形·完整版预备） | 03 村子tile | 256×128 | P2 tile |
| tile_village_path_iso | 土路（战棋菱形·完整版预备） | 03 村子tile | 256×128 | P2 tile |
| tile_village_well_iso | 水井（战棋菱形·完整版预备） | 03 村子tile | 256×128 | P2 tile |
| tile_village_house_iso | 农舍（战棋菱形·完整版预备） | 03 村子tile | 256×128 | P2 tile |
| tile_village_tree_01_iso | 树木·阔叶单株（战棋菱形·完整版预备） | 03 村子tile | 256×128 | P2 tile |
| tile_village_tree_02_iso | 树木·双株变体（战棋菱形·完整版预备） | 03 村子tile | 256×128 | P2 tile |
| spr_cls_warrior_idle | 战士·待机 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_cls_warrior_move | 战士·移动 | 04 单位动作 | 128×512·4 帧 | P1 单位动作 |
| spr_cls_warrior_melee_attack | 战士·近战攻击 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_warrior_cast_ranged | 战士·远程施放 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_warrior_hit | 战士·受击 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_cls_warrior_downed | 战士·倒地 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_rogue_idle | 盗贼·待机 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_cls_rogue_move | 盗贼·移动 | 04 单位动作 | 128×512·4 帧 | P1 单位动作 |
| spr_cls_rogue_melee_attack | 盗贼·近战攻击 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_rogue_cast_ranged | 盗贼·远程施放 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_rogue_hit | 盗贼·受击 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_cls_rogue_downed | 盗贼·倒地 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_mage_idle | 法师·待机 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_cls_mage_move | 法师·移动 | 04 单位动作 | 128×512·4 帧 | P1 单位动作 |
| spr_cls_mage_melee_attack | 法师·近战攻击 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_mage_cast_ranged | 法师·远程施放 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_mage_hit | 法师·受击 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_cls_mage_downed | 法师·倒地 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_priest_idle | 牧师·待机 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_cls_priest_move | 牧师·移动 | 04 单位动作 | 128×512·4 帧 | P1 单位动作 |
| spr_cls_priest_melee_attack | 牧师·近战攻击 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_priest_cast_ranged | 牧师·远程施放 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_priest_hit | 牧师·受击 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_cls_priest_downed | 牧师·倒地 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_ranger_idle | 游侠·待机 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_cls_ranger_move | 游侠·移动 | 04 单位动作 | 128×512·4 帧 | P1 单位动作 |
| spr_cls_ranger_melee_attack | 游侠·近战攻击 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_ranger_cast_ranged | 游侠·远程施放 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_ranger_hit | 游侠·受击 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_cls_ranger_downed | 游侠·倒地 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_arcanist_idle | 奇术师·待机 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_cls_arcanist_move | 奇术师·移动 | 04 单位动作 | 128×512·4 帧 | P1 单位动作 |
| spr_cls_arcanist_melee_attack | 奇术师·近战攻击 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_arcanist_cast_ranged | 奇术师·远程施放 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_cls_arcanist_hit | 奇术师·受击 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_cls_arcanist_downed | 奇术师·倒地 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_en_mutant_rat_idle | 变异鼠·待机 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_en_mutant_rat_move | 变异鼠·移动 | 04 单位动作 | 128×512·4 帧 | P1 单位动作 |
| spr_en_mutant_rat_melee_attack | 变异鼠·近战攻击 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_en_mutant_rat_cast_ranged | 变异鼠·远程施放 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_en_mutant_rat_hit | 变异鼠·受击 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_en_mutant_rat_downed | 变异鼠·倒地 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_en_goblin_miner_idle | 哥布林矿工·待机 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_en_goblin_miner_move | 哥布林矿工·移动 | 04 单位动作 | 128×512·4 帧 | P1 单位动作 |
| spr_en_goblin_miner_melee_attack | 哥布林矿工·近战攻击 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_en_goblin_miner_cast_ranged | 哥布林矿工·远程施放 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_en_goblin_miner_hit | 哥布林矿工·受击 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_en_goblin_miner_downed | 哥布林矿工·倒地 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_en_elite_boss_idle | 矿洞祸首（精英）·待机 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_en_elite_boss_move | 矿洞祸首（精英）·移动 | 04 单位动作 | 128×512·4 帧 | P1 单位动作 |
| spr_en_elite_boss_melee_attack | 矿洞祸首（精英）·近战攻击 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_en_elite_boss_cast_ranged | 矿洞祸首（精英）·远程施放 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| spr_en_elite_boss_hit | 矿洞祸首（精英）·受击 | 04 单位动作 | 128×256·2 帧 | P1 单位动作 |
| spr_en_elite_boss_downed | 矿洞祸首（精英）·倒地 | 04 单位动作 | 128×384·3 帧 | P1 单位动作 |
| icon_explore_party | 探索小队标记 | 05 小队交互 | 64×64 | P4 图标 |
| icon_pt_event | 事件点 | 05 小队交互 | 64×64 | P4 图标 |
| icon_pt_treasure | 宝箱 | 05 小队交互 | 64×64 | P4 图标 |
| icon_pt_target | 委托目标点 | 05 小队交互 | 64×64 | P4 图标 |
| icon_pt_exit | 出口 | 05 小队交互 | 64×64 | P4 图标 |
| icon_pt_battle | 必然遭遇点 | 05 小队交互 | 64×64 | P4 图标 |
| tile_secret_passage | 暗门开启窄道 | 05 小队交互 | 128×128 | P2 tile |
| fx_fog_unseen | 未探索浓雾 | 06 迷雾 | 512×512 | P6 迷雾·叠加 |
| fx_fog_dim | 已探索暗态滤镜 | 06 迷雾 | 512×512 | P6 迷雾·叠加 |
| icon_res_gold | 货币 | 07 系统图标 | 64×64 | P4 图标 |
| icon_res_exp | 经验 | 07 系统图标 | 64×64 | P4 图标 |
| icon_res_repu | 声望 | 07 系统图标 | 64×64 | P4 图标 |
| icon_attr_str | 力量 | 07 系统图标 | 64×64 | P4 图标 |
| icon_attr_agi | 敏捷 | 07 系统图标 | 64×64 | P4 图标 |
| icon_attr_con | 体质 | 07 系统图标 | 64×64 | P4 图标 |
| icon_attr_int | 智力 | 07 系统图标 | 64×64 | P4 图标 |
| icon_attr_wis | 感知 | 07 系统图标 | 64×64 | P4 图标 |
| icon_attr_wil | 意志 | 07 系统图标 | 64×64 | P4 图标 |
| icon_attr_luk | 幸运 | 07 系统图标 | 64×64 | P4 图标 |
| icon_res_hp | 生命 | 07 系统图标 | 64×64 | P4 图标 |
| icon_res_mp | 法力 | 07 系统图标 | 64×64 | P4 图标 |
| icon_res_sp | 精力 | 07 系统图标 | 64×64 | P4 图标 |
| icon_class_warrior | 职业·战士 | 07 系统图标 | 64×64 | P4 图标 |
| icon_class_rogue | 职业·盗贼 | 07 系统图标 | 64×64 | P4 图标 |
| icon_class_mage | 职业·法师 | 07 系统图标 | 64×64 | P4 图标 |
| icon_class_priest | 职业·牧师 | 07 系统图标 | 64×64 | P4 图标 |
| icon_class_ranger | 职业·游侠 | 07 系统图标 | 64×64 | P4 图标 |
| icon_class_arcanist | 职业·奇术师 | 07 系统图标 | 64×64 | P4 图标 |
| ui_panel_ninepatch | 面板九宫格母图 | 08 UI基础 | 96×96 | P5 UI 件 |
| ui_button_normal | 主按钮·常态 | 08 UI基础 | 128×64 | P5 UI 件 |
| ui_button_hover | 主按钮·悬停 | 08 UI基础 | 128×64 | P5 UI 件 |
| ui_button_disabled | 主按钮·禁用 | 08 UI基础 | 128×64 | P5 UI 件 |
| ui_label_result_crit_success | 大成功标签底 | 08 UI基础 | 96×48 | P5 UI 件 |
| ui_label_result_success | 成功标签底 | 08 UI基础 | 96×48 | P5 UI 件 |
| ui_label_result_failure | 失败标签底 | 08 UI基础 | 96×48 | P5 UI 件 |
| ui_label_result_crit_failure | 大失败标签底 | 08 UI基础 | 96×48 | P5 UI 件 |
| fx_battle_select | 选中框 | 09 叠加·D20 | **256×128·菱形** | P6 迷雾·叠加 |
| fx_battle_range | 范围指示格面 | 09 叠加·D20 | **256×128·菱形** | P6 迷雾·叠加 |
| fx_battle_path_arrow | 路径箭头 | 09 叠加·D20 | 128×128 | P6 迷雾·叠加 |
| fx_d20 | D20 骰面 | 09 叠加·D20 | 256×256 | P6 迷雾·叠加 |

> 优先级 = 批 4 替换次序建议（P1 单位动作集 54 → P2 tile 17 → P3 背景 6 → P4 图标 25 → P5 UI 件 8 → P6 迷雾·叠加·D20 6）；正式件一律按同 id 原位替换占位件、配置零改动。

---

## 01 背景组（6 件）

- 生产顺序建议：**P3**（批 4 替换次序第 3 位·背景层）；六张建议同批产出或同批调色校准——公会系暖底色温一致（暖木 #8B5A3C/炉火橙 #E07B39/灯火黄 #F5C869），矿洞环境两张冷蓝灰调与 02 组矿洞 tile 一致，跨张并排无明显风格跳变
- 组级公共说明：不透明底；构图预留 UI 安全区（四角/下边条为状态条与按钮位，不压主体细节）；**无人物、无文字**（人物归 04 组单位、文案归 UI 层程序渲染）；16:9 出图后裁切/缩放至 1920×1080；验收细则见 `01_背景组.md`

### bg_association_hall（冒险者协会入口）

- 目标规格：1920×1080（16:9）·不透明底（PNG-24 无损或 WebP）
- 出图后处理：16:9 出图（1920×1080 或等比更高分辨率）→ 裁切/缩放至 1920×1080；告示板区域保持空净（委托板为 UI 覆盖层叠放位）；四角/下边条 UI 安全区无主体细节
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, fantasy adventurer association entrance facade, wooden notice board with blank paper sheets, reception counter silhouette, cozy medieval street corner in the distance, warm lamp glow, no people, 16:9 wide composition
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、奇幻冒险者协会入口门面、贴着空白纸页的木质告示板、接待柜台剪影、远处温馨的中世纪街角、温暖的灯光光晕、无人物、16:9 宽幅构图

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, characters, readable letters on papers
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、人物、纸上可读字迹

### bg_dormitory（宿舍设施场景）

- 目标规格：1920×1080（16:9）·不透明底（PNG-24 无损或 WebP）
- 出图后处理：16:9 出图后裁切/缩放至 1920×1080；床位构图居中（床位=设施 1→2 级差异小物件锚位，不另出图）；四角/下边条 UI 安全区无主体细节
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, small fantasy guild dormitory room, several wooden beds with neat blankets, bedside cabinets, small window with warm light, cozy quiet atmosphere, no people, 16:9 wide composition
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、小型奇幻公会宿舍房间、数张铺着整齐被毯的木床、床头柜、透进暖光的小窗、温馨安静的气氛、无人物、16:9 宽幅构图

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, characters
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、人物

### bg_training_ground（训练场设施场景）

- 目标规格：1920×1080（16:9）·不透明底（PNG-24 无损或 WebP）
- 出图后处理：16:9 出图后裁切/缩放至 1920×1080；器械架/木人桩不遮挡四角 UI 安全区（器械可点缀钢蓝 #4A7BA6 金属件；器械数量=设施等级小物件锚位）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, small fantasy training ground, wooden practice dummies, weapon racks, sandy yard with wooden fence, warm daylight, no people, 16:9 wide composition
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、小型奇幻训练场、木质练功桩、武器架、围木栅栏的沙土场地、温暖日光、无人物、16:9 宽幅构图

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, characters, gore, blood
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、人物、血腥、血液

### bg_title（标题屏背景）

- 目标规格：1920×1080（16:9）·不透明底（PNG-24 无损或 WebP）
- 出图后处理：16:9 出图后裁切/缩放至 1920×1080；中央留净区供标题文字与菜单按钮（程序渲染层）。⚠ 规格书 v1.3 本件带【待拍板】标记（或复用 bg_guild_hall 作标题底、不出新件）——生成前建议先确认拍板结果
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, cozy fantasy guild building exterior at dusk, warm glowing windows, wooden sign, distant town silhouette, inviting first impression, no people, 16:9 wide composition
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、黄昏时温馨的奇幻公会建筑外观、透出暖光的窗户、木质招牌、远处小镇剪影、引人入胜的第一印象、无人物、16:9 宽幅构图

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, characters, readable letters on sign
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、人物、招牌上可读字迹

### bg_battle_mine（战斗屏矿洞环境）

- 目标规格：1920×1080（16:9）·不透明底（PNG-24 无损或 WebP）
- 出图后处理：16:9 出图后裁切/缩放至 1920×1080；中央棋盘区保持低频纹理（不抢棋盘格与单位辨识）；与 02 组矿洞 tile 并排调性一致
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, cave mine interior environment backdrop, dark blue-gray rock walls with orange torch lights, depth perspective, atmospheric dungeon mood, no people, 16:9 wide composition
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、矿洞内景环境背景、缀着橙色火把光的深蓝灰岩壁、纵深透视、地牢氛围、无人物、16:9 宽幅构图

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, characters, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、人物、网格线

### bg_explore（探索屏环境）

- 目标规格：1920×1080（16:9）·不透明底（PNG-24 无损或 WebP）
- 出图后处理：16:9 出图后裁切/缩放至 1920×1080；四周暗角不过重（不压探索板可读性）、与迷雾两态（06 组）叠加无彩偏冲突。⚠ 规格书 v1.3 本件带【待接线方案定】标记（或与 bg_battle_mine 共用一件）——生成前建议先确认裁定结果
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, dim neutral dark backdrop with subtle vignette, soft edge darkening, exploration mood, no objects, no people, 16:9 wide composition
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、带轻柔暗角的昏暗中性深色背景、边缘柔和压暗、探索氛围、无物体、无人物、16:9 宽幅构图

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, characters
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、人物

---

## 02 矿洞 tile 组（14 件 = 方形 9 + 战棋菱形 5·E1 增补）

- 生产顺序建议：**P2**（tile 层·正式件产出归 E2 素材波）；建议先出 `tile_mine_floor_01`（方形）与 `tile_mine_floor_01_iso`（菱形）定组内两种几何的风格样张（回填 00 §四）再铺全组
- 组级公共说明：方形 9 件源 128×128（AI 工具按 512/1024 正方形出图后缩放，向下缩放无损）、**探索层专用**（rock/cart 两键 E1 起无现行消费点在册备用）；**战棋菱形 5 件源 256×128（2:1 等距·00 §六-8）**：菱形四顶点=画布四边中点、菱形满幅、四角透明（AI 工具按 2:1 比例出图〔如 1024×512〕后缩放，必要时人工修整顶点对位）；物件件轮廓不越菱形、底缘对齐菱形下缘；状态地格（bush/highground/poison_swamp 两版/trap）颜色+形状双编码；调性=蓝灰冷色+火把橙点光（#5A6472/#3E4550/#E07B39）；验收细则见 `02_矿洞tile组.md`（v2.0）

### tile_mine_floor_01（矿洞地面·基岩）

- 目标规格：128×128（源）·可平铺（四边无缝）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；2×2 平铺目检接缝、必要时人工修整四边无缝（D2=B 全 AI 生成+人工修整单轨）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, seamless tileable cave stone floor texture, blue-gray rock, dark cracks, top-down view, dungeon mine theme
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、无缝可平铺的洞穴石地纹理、蓝灰岩石、深色裂缝、顶视角、地牢矿洞主题

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_mine_floor_02（矿洞地面·碎石变体）

- 目标规格：128×128（源）·可平铺（四边无缝）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；2×2 平铺目检接缝、必要时人工修整四边无缝（D2=B 全 AI 生成+人工修整单轨）；与 floor_01 同色系（变体混铺打破重复感）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, seamless tileable cave stone floor with scattered rubble and ore debris, blue-gray rock, top-down view
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、无缝可平铺的散落着碎石与矿渣的洞穴石地、蓝灰岩石、顶视角

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_mine_wall（矿洞岩壁）

- 目标规格：128×128（源）·可平铺（四边无缝）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；2×2 平铺目检接缝、必要时人工修整四边无缝（D2=B 全 AI 生成+人工修整单轨）；顶视「不可通行」剪影明确（障碍辨识原则）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, seamless tileable mine cavern rock wall, vertical stone face, deep cold shadow, top-down game tile, impassable silhouette
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、无缝可平铺的矿洞岩壁、竖直岩面、深冷阴影、顶视游戏地格、不可通行剪影

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_mine_rock（障碍·塌方碎石堆）

- 目标规格：128×128（源）·物件件（轮廓不越画布、底缘对齐格界）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；确认轮廓不越画布、底缘对齐格界、不可通行剪影清晰
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, rockslide rubble pile on cave floor, single game tile, top-down view, clear impassable silhouette, bottom edge aligned
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、洞穴地面上的塌方碎石堆、单格游戏地格、顶视角、清晰的不可通行剪影、底缘对齐

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

### tile_mine_cart（障碍·废弃矿车）

- 目标规格：128×128（源）·物件件（轮廓不越画布、底缘对齐格界）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；确认轮廓不越画布、底缘对齐格界
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, overturned broken mine cart with rail fragment on cave floor, single game tile, top-down view, wooden cart with metal parts
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、洞穴地面上连着铁轨残段的翻倒破损矿车、单格游戏地格、顶视角、带金属部件的木质矿车

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

### tile_battle_bush（战棋草丛·v2.0 同 id 重制菱形）

- 目标规格：**256×128（源）·菱形覆盖件**（菱形地面底+手绘草丛覆盖——E1 等距批重制，00 §六-8）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位画布四边中点、四角透明（必要时人工修整对位）；草丛图案完整落于菱形内；绿系 #7CA85A、颜色+形状双编码
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, grass bush cluster on isometric diamond tile, rhombus cave floor base, lush green tufts, motif fully inside the diamond, shape and color clearly distinct
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、等距菱形地格上的草丛簇、菱形地牢地面底、茂盛的绿色草簇、母题完整落于菱形内、形状与颜色清晰可辨

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_battle_highground（战棋高地·v2.0 同 id 重制菱形）

- 目标规格：**256×128（源）·菱形物件件**（等距抬升台面+侧壁明暗差——E1 等距批重制，00 §六-8）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位画布四边中点、四角透明；高度差可读（等距台面+侧壁阴影）；颜色+形状双编码
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, raised stone platform on isometric diamond tile, rhombus base, elevated terrace with visible side wall shading, height difference readable
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、等距菱形地格上的抬升石质平台、菱形底座、带可见侧壁明暗的高台面、高度差可读

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_battle_poison_swamp（战棋毒沼·方形——E1 起探索专用）

- 目标规格：128×128（源）·可平铺（四边无缝）——E1 等距批起**探索层毒瘴格专用**（战棋消费改指菱形新键 `tile_battle_poison_swamp_iso`）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；2×2 平铺目检接缝、必要时人工修整四边无缝（D2=B 全 AI 生成+人工修整单轨）；静态纹理（动效占位为静态）；紫 #7A2E35 系+绿 #4C9A5F 泡点
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, seamless tileable poisonous swamp pool, purple-green bubbling toxic slime texture, top-down game tile
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、无缝可平铺的毒沼洼池、紫绿相间冒泡的毒液纹理、顶视游戏地格

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_battle_trap（战棋陷阱（v1.1 扩件）·v2.0 同 id 重制菱形）

- 目标规格：**256×128（源）·菱形覆盖件**（运行时叠加于底格之上的菱形陷阱盒面——E1 等距批重制，00 §六-8）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位画布四边中点、四角透明；警示剪影独立可辨（金属包边 #A8843C 机械件+警示橙点 #E07B39 系、底为矿洞地面同系）；颜色+形状双编码；正式件到位后程序角标退役
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, bear trap with metal spikes on isometric diamond tile, rhombus cave floor base, mechanical trap face with warning orange accent, motif fully inside the diamond, danger clearly readable
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、等距菱形地格上带金属尖刺的熊夹陷阱、菱形地牢地面底、带警示橙色点缀的机械陷阱格面、母题完整落于菱形内、危险清晰可读

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

### tile_mine_floor_01_iso（矿洞地面·基岩（战棋菱形）·E1 新键）

- 目标规格：256×128（源）·菱形满幅（菱形四顶点=画布四边中点、四角透明——00 §六-8；战棋 `tile_normal` 底图）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位画布四边中点（必要时人工修整对位）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, isometric 2:1 diamond floor tile, rhombus-shaped cave stone texture, blue-gray rock with dark cracks, diamond filling the full frame, corners transparent, dungeon mine theme
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、2:1 等距菱形地面格、菱形的洞穴岩石纹理、带深色裂缝的蓝灰岩石、菱形铺满全画幅、四角透明、地牢矿洞主题

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_mine_floor_02_iso（矿洞地面·碎石变体（战棋菱形）·E1 新键）

- 目标规格：256×128（源）·菱形满幅（同上；战棋 `tile_normal` 变体混铺）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位；与 floor_01_iso 同色系（变体混铺打破重复感）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, isometric 2:1 diamond floor tile, rhombus-shaped cave stone with scattered rubble and ore debris, blue-gray rock, diamond filling the full frame, corners transparent
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、2:1 等距菱形地面格、菱形的散落着碎石与矿渣的洞穴石地、蓝灰岩石、菱形铺满全画幅、四角透明

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_mine_rock_iso（障碍·塌方碎石堆（战棋菱形）·E1 新键）

- 目标规格：256×128（源）·菱形物件件（母题完整落于菱形内、底缘对齐菱形下缘；战棋 `tile_obstacle` 表现 1）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位、母题不越菱形、不可通行剪影清晰
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, rockslide rubble pile on isometric diamond tile, rhombus cave floor base, clear impassable silhouette, motif fully inside the diamond, bottom edge aligned to diamond lower edge
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、等距菱形地格上的塌方碎石堆、菱形洞穴地面底、清晰的不可通行剪影、母题完整落于菱形内、底缘对齐菱形下缘

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

### tile_mine_cart_iso（障碍·废弃矿车（战棋菱形）·E1 新键）

- 目标规格：256×128（源）·菱形物件件（母题完整落于菱形内；战棋 `tile_obstacle` 表现 2）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位、母题不越菱形
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, overturned broken mine cart with rail fragment on isometric diamond tile, rhombus cave floor base, wooden cart with metal parts, motif fully inside the diamond
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、等距菱形地格上连着铁轨残段的翻倒破损矿车、菱形洞穴地面底、带金属部件的木质矿车、母题完整落于菱形内

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

### tile_battle_poison_swamp_iso（战棋毒沼（菱形）·E1 新键）

- 目标规格：256×128（源）·菱形满幅（战棋 `tile_poison_swamp` E1 改指本键；色板同方形版）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位；静态纹理（动效占位为静态）；紫 #7A2E35 系+绿 #4C9A5F 泡点
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, isometric 2:1 diamond tile, rhombus-shaped poisonous swamp pool, purple-green bubbling toxic slime texture filling the full diamond, corners transparent
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、2:1 等距菱形地格、菱形的毒沼洼池、紫绿相间冒泡的毒液纹理铺满菱形、四角透明

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

---

## 03 村子 tile 组（14 件 = 方形 7 + 战棋菱形 7〔完整版预备〕·E1 增补）

- 生产顺序建议：**P2**（tile 层·正式件产出归 E2 素材波）；建议先出 `tile_village_grass_01`（方形）定组内风格样张再铺全组；菱形 7 件为完整版预备、无战斗消费点（随 E2/完整版节奏产出）
- 组级公共说明：方形 7 件源 128×128（512/1024 出图后缩放）；**菱形 7 件源 256×128（2:1 等距·00 §六-8）**：菱形四顶点=画布四边中点、菱形满幅、四角透明、物件母题不越菱形；调性=田园明亮少阴影（草绿 #7CA85A+土黄 #C9A66B，明亮少阴影=安全区视觉信号）——与 02 矿洞组并排「村子明亮田园 vs 矿洞冷暗岩穴」反差成立；菱形版与方形版同件同色系（同套题材两视角）；验收细则见 `03_村子tile组.md`（v2.0）

### tile_village_grass_01（草地·基色）

- 目标规格：128×128（源）·可平铺（四边无缝）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；2×2 平铺目检接缝、必要时人工修整四边无缝（D2=B 全 AI 生成+人工修整单轨）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, seamless tileable bright meadow grass texture, soft green with small grass tufts, top-down game tile, sunny countryside
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、无缝可平铺的明亮草甸草地纹理、缀着小草簇的柔和绿色、顶视游戏地格、晴朗乡村

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_village_grass_02（草地·野花变体）

- 目标规格：128×128（源）·可平铺（四边无缝）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；2×2 平铺目检接缝、必要时人工修整四边无缝（D2=B 全 AI 生成+人工修整单轨）；与 grass_01 同色系（变体混铺）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, seamless tileable meadow grass with tiny wildflowers and varied tufts, bright and lively, top-down game tile
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、无缝可平铺的缀着细小野花与错落草簇的草甸草地、明快活泼、顶视游戏地格

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_village_path（土路）

- 目标规格：128×128（源）·可平铺（四边无缝）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；2×2 平铺目检接缝、必要时人工修整四边无缝（D2=B 全 AI 生成+人工修整单轨）；土黄压实路面、两侧草缘过渡（村图加 path 格后生效——槽位 X2）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, seamless tileable dirt path texture, packed yellow-brown earth with grass edges, top-down game tile
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、无缝可平铺的土路纹理、两侧带草缘的压实黄褐泥土、顶视游戏地格

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_village_well（水井）

- 目标规格：128×128（源）·物件件（轮廓不越画布、底缘对齐格界）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；确认轮廓不越画布、底缘对齐格界
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, stone water well with wooden frame and rope winch on grass, single game tile, top-down view, bottom edge aligned
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、草地上带木质支架与绳索辘轳的石砌水井、单格游戏地格、顶视角、底缘对齐

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

### tile_village_house（农舍）

- 目标规格：128×128（源）·物件件（轮廓不越画布、底缘对齐格界）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；确认轮廓不越画布、底缘对齐格界；土黄墙面+暖木梁小屋顶视造型
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, small countryside farm house, yellow-brown wall with wooden beams and rustic roof, single game tile, top-down view
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、小型乡村农舍、带木梁与质朴屋顶的黄褐墙面、单格游戏地格、顶视角

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

### tile_village_tree_01（树木·阔叶单株）

- 目标规格：128×128（源）·物件件（轮廓不越画布、底缘对齐格界）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；确认轮廓不越画布、底缘对齐格界
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, round-canopy broadleaf tree with warm brown trunk on grass, single game tile, top-down view
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、草地上带暖棕树干的圆冠阔叶树、单格游戏地格、顶视角

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

### tile_village_tree_02（树木·双株变体）

- 目标规格：128×128（源）·物件件（轮廓不越画布、底缘对齐格界）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；确认轮廓不越画布、底缘对齐格界
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, two small broadleaf trees clustered on grass, slight height variety, single game tile, top-down view
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、草地上簇生的两棵小阔叶树、略有高差变化、单格游戏地格、顶视角

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

### tile_village_grass_01_iso（草地·基色（战棋菱形·完整版预备）·E1 新键）

- 目标规格：256×128（源）·菱形满幅（00 §六-8；**无现行战斗消费点**——村子图战斗化时启用）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位画布四边中点（必要时人工修整对位）；色系同方形版 grass_01
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, isometric 2:1 diamond floor tile, rhombus-shaped bright meadow grass texture, soft green with small tufts, diamond filling the full frame, corners transparent
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、2:1 等距菱形地面格、菱形的明亮草甸草地纹理、缀着小草簇的柔和绿色、菱形铺满全画幅、四角透明

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_village_grass_02_iso（草地·野花变体（战棋菱形·完整版预备）·E1 新键）

- 目标规格：256×128（源）·菱形满幅（完整版预备，同上）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位；与 grass_01_iso 同色系（变体混铺预备）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, isometric 2:1 diamond floor tile, rhombus-shaped meadow grass with tiny wildflowers, diamond filling the full frame, corners transparent
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、2:1 等距菱形地面格、菱形的缀着细小野花的草甸草地、菱形铺满全画幅、四角透明

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_village_path_iso（土路（战棋菱形·完整版预备）·E1 新键）

- 目标规格：256×128（源）·菱形满幅（完整版预备）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, isometric 2:1 diamond floor tile, rhombus-shaped packed dirt path texture with grass edges, diamond filling the full frame, corners transparent
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、2:1 等距菱形地面格、菱形的压实土路纹理带草缘、菱形铺满全画幅、四角透明

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_village_well_iso（水井（战棋菱形·完整版预备）·E1 新键）

- 目标规格：256×128（源）·菱形物件件（母题完整落于菱形内、底缘对齐菱形下缘）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位、母题不越菱形
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, stone water well with wooden frame on isometric diamond tile, rhombus grass floor base, motif fully inside the diamond, bottom edge aligned to diamond lower edge
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、等距菱形地格上的石砌木架水井、菱形草地底、母题完整落于菱形内、底缘对齐菱形下缘

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

### tile_village_house_iso（农舍（战棋菱形·完整版预备）·E1 新键）

- 目标规格：256×128（源）·菱形物件件（母题完整落于菱形内）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位、母题不越菱形
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, small countryside farm house on isometric diamond tile, yellow-brown wall with wooden beams, motif fully inside the diamond
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、等距菱形地格上的乡间小农舍、黄褐墙面配木梁、母题完整落于菱形内

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

### tile_village_tree_01_iso（树木·阔叶单株（战棋菱形·完整版预备）·E1 新键）

- 目标规格：256×128（源）·菱形物件件（母题完整落于菱形内）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位、母题不越菱形
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, round-canopy broadleaf tree on isometric diamond tile, rhombus grass floor base, motif fully inside the diamond
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、等距菱形地格上的圆润树冠阔叶树、菱形草地底、母题完整落于菱形内

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

### tile_village_tree_02_iso（树木·双株变体（战棋菱形·完整版预备）·E1 新键）

- 目标规格：256×128（源）·菱形物件件（母题完整落于菱形内）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；菱形四顶点对位、母题不越菱形
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, two small broadleaf trees clustered on isometric diamond tile, rhombus grass floor base, motif fully inside the diamond
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、等距菱形地格上簇生的两棵小阔叶树、菱形草地底、母题完整落于菱形内

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

---

## 04 单位动作集组（54 件·9 单位×6 动作竖条）

- 生产顺序建议：**P1（最高优先·批 4 替换次序第 1 位）**；先出 9 张单位锚图定稿，再按单位逐动作连作（同单位 6 件一组产出，保证同人同装）
- **锚串流程（同单位同人同装——本组核心生产纪律）**：
  1. 每单位先出一张「锚图」：用该单位小节「锚图提示词」生成单帧全身立绘，对照设定卡（体型/服装/武器/主色）确认定稿——**9 张锚图为生产辅助件，不入库、不计 119 件**；
  2. 该单位全部 6 个动作件以锚图为参考图生成（img2img 低重绘幅度或工具的角色一致性参考功能），**idle 首帧 = 锚图常态站姿**；
  3. 同一单位 6 件间「同人同装」：设定卡逐项一致（体型/服装/武器/主色不变，仅运动部位变化）。
- 竖条规格：宽 128、高 = 帧数×128、透明底、帧格自上而下按播放序、无间隔线无帧边框；推荐帧数 idle 2 / move 4 / melee_attack 3 / cast_ranged 3 / hit 2 / downed 3（帧带硬约束 idle[2,4] / move[4,6] / melee_attack[2,4] / cast_ranged[2,4] / hit[1,2] / downed[2,3]，本卷推荐值均在带内）。
- 防抖锚定：idle/attack/cast/hit 仅运动部位变化、**脚部锚定逐像素不动**（帧间抖动是 AI 产最大风险点）；move 允许腿部摆动但全身剪影包络稳定；downed 为全身位移（唯一例外）。
- 主用/备用路由（全部 54 件均须产出）：战士/盗贼/变异鼠/哥布林矿工 melee_attack 主用；法师/牧师/游侠/奇术师 cast_ranged 主用；矿洞祸首双主用；备用件防后续新增技能缺件。
- 组级验收：过 V-M6-anim-geometry（宽 128/高=帧数×128/帧数∈带）；缩至 48px 高职业或种类可辨；赛璐璐二分光影、描边 #2E2620 线宽 3-4px；验收细则见 `04_单位动作集组.md`

### spr_cls_warrior 战士（单位设定卡与锚图）

- 设定卡（同人同装锚定源）：Q 版二头身·六职业中最壮（肩宽体厚、重心低）；银灰重板甲+钢蓝罩袍（主色 #4A7BA6）+棕色腰带；右手宽刃大剑（银灰刃+钢蓝柄）、左臂圆盾（银灰底+钢蓝纹章）；暖棕短发+金属护额；剪影锚点=大盾+宽剑+重盔轮廓
- 主用/备用路由：melee_attack 主用（cast_ranged 备用·语义=盾击冲击波）
- 锚图提示词（生产辅助件·非入库·先出锚图定稿，六动作件均以此为参考图）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, transparent background, chibi knight in heavy silver armor with steel-blue tabard, round shield on left arm, wide greatsword in right hand, short brown hair, metal headband, standing idle pose, single full body character, one frame only
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、透明背景、身穿厚重银甲配钢蓝罩袍的 Q 版骑士、左臂圆盾、右手宽刃大剑、棕色短发、金属护额、站立待机姿势、单个全身角色、仅一帧

### spr_cls_warrior_idle（战士·待机）

- 目标规格：宽 128 竖条·透明底·idle 2 帧（128×256）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi knight in heavy silver armor with steel-blue tabard, round shield on left arm, wide greatsword in right hand, short brown hair, metal headband, standing idle pose, subtle breathing motion, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身穿厚重银甲配钢蓝罩袍的 Q 版骑士、左臂圆盾、右手宽刃大剑、棕色短发、金属护额、站立待机姿势、轻微呼吸起伏、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_warrior_move（战士·移动）

- 目标规格：宽 128 竖条·透明底·move 4 帧（128×512）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×512 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身剪影包络稳定）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi knight in heavy silver armor with steel-blue tabard, round shield on left arm, wide greatsword in right hand, short brown hair, metal headband, heavy armored walking cycle, steady steps, four frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身穿厚重银甲配钢蓝罩袍的 Q 版骑士、左臂圆盾、右手宽刃大剑、棕色短发、金属护额、重甲行走循环、步伐沉稳、四帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_warrior_melee_attack（战士·近战攻击）

- 目标规格：宽 128 竖条·透明底·melee_attack 3 帧（128×384）·单次播完停末帧·主用
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi knight in heavy silver armor with steel-blue tabard, round shield on left arm, wide greatsword in right hand, short brown hair, metal headband, swinging greatsword overhead, anticipation, slash arc with speed lines, recovery, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身穿厚重银甲配钢蓝罩袍的 Q 版骑士、左臂圆盾、右手宽刃大剑、棕色短发、金属护额、双手举剑过头挥砍、预备蓄势、带速度线的斩击弧光、收势回位、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_warrior_cast_ranged（战士·远程施放）

- 目标规格：宽 128 竖条·透明底·cast_ranged 3 帧（128×384）·单次播完停末帧·备用·语义=盾击冲击波（盾前推蓄力→冲击波纹→收势）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi knight in heavy silver armor with steel-blue tabard, round shield on left arm, wide greatsword in right hand, short brown hair, metal headband, shield bash, shockwave burst from shield, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身穿厚重银甲配钢蓝罩袍的 Q 版骑士、左臂圆盾、右手宽刃大剑、棕色短发、金属护额、盾击、自盾面迸发的冲击波、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_warrior_hit（战士·受击）

- 目标规格：宽 128 竖条·透明底·hit 2 帧（128×256）·单次·受击白闪为程序叠加不画入帧
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi knight in heavy silver armor with steel-blue tabard, round shield on left arm, wide greatsword in right hand, short brown hair, metal headband, flinching backward, hurt expression, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身穿厚重银甲配钢蓝罩袍的 Q 版骑士、左臂圆盾、右手宽刃大剑、棕色短发、金属护额、后仰受击退缩、痛苦表情、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_warrior_downed（战士·倒地）

- 目标规格：宽 128 竖条·透明底·downed 3 帧（128×384）·单次播完锁末帧（尸态闭合剪影常驻）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身位移动作·末帧闭合剪影躺平态）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi knight in heavy silver armor with steel-blue tabard, round shield on left arm, wide greatsword in right hand, short brown hair, metal headband, collapsing, kneeling, falling sideways, lying defeated with sword and shield dropped, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身穿厚重银甲配钢蓝罩袍的 Q 版骑士、左臂圆盾、右手宽刃大剑、棕色短发、金属护额、身体垮倒、跪倒、侧身倒下、剑与盾脱手掉落的战败躺卧、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_rogue 盗贼（单位设定卡与锚图）

- 设定卡（同人同装锚定源）：Q 版二头身·六职业中最瘦小灵巧；深紫兜帽紧身劲装（主色 #5E3F82）+腰带暗袋、软底靴；双手各持一柄匕首（银刃短柄）；兜帽阴影罩上半脸、仅露下颌与亮色双眼（灯火黄 #F5C869 点色）；剪影锚点=兜帽轮廓+双匕
- 主用/备用路由：melee_attack 主用（cast_ranged 备用·语义=飞刀投掷）
- 锚图提示词（生产辅助件·非入库·先出锚图定稿，六动作件均以此为参考图）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, transparent background, chibi rogue in deep-purple hooded tight suit, dual daggers in both hands, small agile build, sharp eyes glowing under hood, standing idle pose, single full body character, one frame only
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、透明背景、身穿深紫兜帽紧身劲装、双手各持一柄匕首的 Q 版盗贼、瘦小灵巧体型、兜帽下发光的锐利双眼、站立待机姿势、单个全身角色、仅一帧

### spr_cls_rogue_idle（盗贼·待机）

- 目标规格：宽 128 竖条·透明底·idle 2 帧（128×256）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi rogue in deep-purple hooded tight suit, dual daggers in both hands, small agile build, sharp eyes glowing under hood, crouching idle stance, subtle shoulder motion, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身穿深紫兜帽紧身劲装、双手各持一柄匕首的 Q 版盗贼、瘦小灵巧体型、兜帽下发光的锐利双眼、蹲伏待机姿态、肩部细微动作、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_rogue_move（盗贼·移动）

- 目标规格：宽 128 竖条·透明底·move 4 帧（128×512）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×512 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身剪影包络稳定）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi rogue in deep-purple hooded tight suit, dual daggers in both hands, small agile build, sharp eyes glowing under hood, agile quick stepping run cycle, light on feet, four frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身穿深紫兜帽紧身劲装、双手各持一柄匕首的 Q 版盗贼、瘦小灵巧体型、兜帽下发光的锐利双眼、灵巧疾步的奔跑循环、脚步轻快、四帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_rogue_melee_attack（盗贼·近战攻击）

- 目标规格：宽 128 竖条·透明底·melee_attack 3 帧（128×384）·单次播完停末帧·主用
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi rogue in deep-purple hooded tight suit, dual daggers in both hands, small agile build, sharp eyes glowing under hood, dual dagger thrust attack, lunge forward, speed lines, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身穿深紫兜帽紧身劲装、双手各持一柄匕首的 Q 版盗贼、瘦小灵巧体型、兜帽下发光的锐利双眼、双匕突刺攻击、向前突进、速度线、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_rogue_cast_ranged（盗贼·远程施放）

- 目标规格：宽 128 竖条·透明底·cast_ranged 3 帧（128×384）·单次播完停末帧·备用·语义=飞刀投掷（举刀后引→掷出+轨迹线→回位）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi rogue in deep-purple hooded tight suit, dual daggers in both hands, small agile build, sharp eyes glowing under hood, throwing dagger, throwing pose with motion trail, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身穿深紫兜帽紧身劲装、双手各持一柄匕首的 Q 版盗贼、瘦小灵巧体型、兜帽下发光的锐利双眼、投掷飞刀、带运动轨迹的投掷姿势、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_rogue_hit（盗贼·受击）

- 目标规格：宽 128 竖条·透明底·hit 2 帧（128×256）·单次·受击白闪为程序叠加不画入帧
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi rogue in deep-purple hooded tight suit, dual daggers in both hands, small agile build, sharp eyes glowing under hood, knocked back flinch, hurt expression, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身穿深紫兜帽紧身劲装、双手各持一柄匕首的 Q 版盗贼、瘦小灵巧体型、兜帽下发光的锐利双眼、被击退的后仰受击、痛苦表情、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_rogue_downed（盗贼·倒地）

- 目标规格：宽 128 竖条·透明底·downed 3 帧（128×384）·单次播完锁末帧（尸态闭合剪影常驻）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身位移动作·末帧闭合剪影躺平态）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi rogue in deep-purple hooded tight suit, dual daggers in both hands, small agile build, sharp eyes glowing under hood, stumbling, collapsing sideways, lying defeated with daggers dropped, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身穿深紫兜帽紧身劲装、双手各持一柄匕首的 Q 版盗贼、瘦小灵巧体型、兜帽下发光的锐利双眼、踉跄、侧身倒下、匕首掉落的战败躺卧、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_mage 法师（单位设定卡与锚图）

- 设定卡（同人同装锚定源）：Q 版二头身·中等偏瘦、袍摆宽大；藏青尖顶宽檐帽+藏青长袍（主色 #2B3A67）、袍摆遮脚、腰带垂绳；木质长杖、顶端暖橙发光宝珠（#E07B39）；帽下露浅银长发一束；剪影锚点=尖帽+长杖宝珠
- 主用/备用路由：cast_ranged 主用（melee_attack 备用·语义=杖端敲击）
- 锚图提示词（生产辅助件·非入库·先出锚图定稿，六动作件均以此为参考图）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, transparent background, chibi mage in navy pointed hat and long robe, wooden staff with glowing orange orb, strand of silver hair, standing idle pose, single full body character, one frame only
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、透明背景、头戴藏青尖帽身着长袍的 Q 版法师、带发光橙色宝珠的木杖、一束银发、站立待机姿势、单个全身角色、仅一帧

### spr_cls_mage_idle（法师·待机）

- 目标规格：宽 128 竖条·透明底·idle 2 帧（128×256）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mage in navy pointed hat and long robe, wooden staff with glowing orange orb, strand of silver hair, standing idle, robe and hat swaying subtly, orb glowing, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、头戴藏青尖帽身着长袍的 Q 版法师、带发光橙色宝珠的木杖、一束银发、站立待机、长袍与尖帽轻轻摆动、宝珠发光、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_mage_move（法师·移动）

- 目标规格：宽 128 竖条·透明底·move 4 帧（128×512）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×512 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身剪影包络稳定）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mage in navy pointed hat and long robe, wooden staff with glowing orange orb, strand of silver hair, floating light walking cycle, robe swinging, four frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、头戴藏青尖帽身着长袍的 Q 版法师、带发光橙色宝珠的木杖、一束银发、轻盈飘逸的行走循环、袍摆摇曳、四帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_mage_melee_attack（法师·近战攻击）

- 目标规格：宽 128 竖条·透明底·melee_attack 3 帧（128×384）·单次播完停末帧·备用·语义=杖端敲击
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mage in navy pointed hat and long robe, wooden staff with glowing orange orb, strand of silver hair, staff bonk melee strike, overhead swing, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、头戴藏青尖帽身着长袍的 Q 版法师、带发光橙色宝珠的木杖、一束银发、法杖敲击的近战打击、举杖过头挥下、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_mage_cast_ranged（法师·远程施放）

- 目标规格：宽 128 竖条·透明底·cast_ranged 3 帧（128×384）·单次播完停末帧·主用（宝珠亮度帧间递变）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mage in navy pointed hat and long robe, wooden staff with glowing orange orb, strand of silver hair, casting spell, staff raised gathering light then releasing firebolt with trail, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、头戴藏青尖帽身着长袍的 Q 版法师、带发光橙色宝珠的木杖、一束银发、施放法术、举杖聚光后释放带轨迹的火焰箭、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_mage_hit（法师·受击）

- 目标规格：宽 128 竖条·透明底·hit 2 帧（128×256）·单次·受击白闪为程序叠加不画入帧
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mage in navy pointed hat and long robe, wooden staff with glowing orange orb, strand of silver hair, flinching backward, hat tilting, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、头戴藏青尖帽身着长袍的 Q 版法师、带发光橙色宝珠的木杖、一束银发、后仰受击、帽子歪斜、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_mage_downed（法师·倒地）

- 目标规格：宽 128 竖条·透明底·downed 3 帧（128×384）·单次播完锁末帧（尸态闭合剪影常驻）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身位移动作·末帧闭合剪影躺平态）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mage in navy pointed hat and long robe, wooden staff with glowing orange orb, strand of silver hair, collapsing, falling sideways, lying defeated with staff dropped and hat fallen off, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、头戴藏青尖帽身着长袍的 Q 版法师、带发光橙色宝珠的木杖、一束银发、身体垮倒、侧身倒下、法杖掉落帽子脱落的战败躺卧、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_priest 牧师（单位设定卡与锚图）

- 设定卡（同人同装锚定源）：Q 版二头身·中等、柔和圆润；白金长袍（主色 #F2EAD8、金饰 #D4AF37）+白底金纹头巾、金边腰带；圣徽杖（顶端金色太阳圣徽圆盘）；头巾包发、温和表情；剪影锚点=头巾轮廓+太阳圣徽杖
- 主用/备用路由：cast_ranged 主用（melee_attack 备用·语义=圣徽杖击打）
- 锚图提示词（生产辅助件·非入库·先出锚图定稿，六动作件均以此为参考图）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, transparent background, chibi priest in white robe with golden trim, white-gold hood, holding holy staff with golden sun symbol on top, standing idle pose, single full body character, one frame only
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、透明背景、身着金饰白袍、戴白金头巾、手持顶端金色太阳圣徽圣杖的 Q 版牧师、站立待机姿势、单个全身角色、仅一帧

### spr_cls_priest_idle（牧师·待机）

- 目标规格：宽 128 竖条·透明底·idle 2 帧（128×256）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi priest in white robe with golden trim, white-gold hood, holding holy staff with golden sun symbol on top, standing idle, hands on staff, gentle praying motion, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身着金饰白袍、戴白金头巾、手持顶端金色太阳圣徽圣杖的 Q 版牧师、站立待机、双手扶杖、轻柔的祈祷动作、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_priest_move（牧师·移动）

- 目标规格：宽 128 竖条·透明底·move 4 帧（128×512）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×512 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身剪影包络稳定）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi priest in white robe with golden trim, white-gold hood, holding holy staff with golden sun symbol on top, calm walking cycle, long skirt hem swaying, four frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身着金饰白袍、戴白金头巾、手持顶端金色太阳圣徽圣杖的 Q 版牧师、从容安详的行走循环、长袍下摆摇曳、四帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_priest_melee_attack（牧师·近战攻击）

- 目标规格：宽 128 竖条·透明底·melee_attack 3 帧（128×384）·单次播完停末帧·备用·语义=圣徽杖击打
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi priest in white robe with golden trim, white-gold hood, holding holy staff with golden sun symbol on top, holy staff swing strike, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身着金饰白袍、戴白金头巾、手持顶端金色太阳圣徽圣杖的 Q 版牧师、圣杖挥击、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_priest_cast_ranged（牧师·远程施放）

- 目标规格：宽 128 竖条·透明底·cast_ranged 3 帧（128×384）·单次播完停末帧·主用（施法不闭眼、表情安宁）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi priest in white robe with golden trim, white-gold hood, holding holy staff with golden sun symbol on top, channeling holy light, raising staff with gathering light then releasing light wave, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身着金饰白袍、戴白金头巾、手持顶端金色太阳圣徽圣杖的 Q 版牧师、引导圣光、举杖聚光后释放光波、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_priest_hit（牧师·受击）

- 目标规格：宽 128 竖条·透明底·hit 2 帧（128×256）·单次·受击白闪为程序叠加不画入帧
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi priest in white robe with golden trim, white-gold hood, holding holy staff with golden sun symbol on top, flinching backward, hood fluttering, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身着金饰白袍、戴白金头巾、手持顶端金色太阳圣徽圣杖的 Q 版牧师、后仰受击、头巾飘动、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_priest_downed（牧师·倒地）

- 目标规格：宽 128 竖条·透明底·downed 3 帧（128×384）·单次播完锁末帧（尸态闭合剪影常驻）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身位移动作·末帧闭合剪影躺平态）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi priest in white robe with golden trim, white-gold hood, holding holy staff with golden sun symbol on top, kneeling down, collapsing sideways, lying defeated with holy staff dropped, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身着金饰白袍、戴白金头巾、手持顶端金色太阳圣徽圣杖的 Q 版牧师、跪倒在地、侧身倒下、圣杖掉落的战败躺卧、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_ranger 游侠（单位设定卡与锚图）

- 设定卡（同人同装锚定源）：Q 版二头身·修长矫健；墨绿披肩（主色 #43604A）+棕色皮甲护腿、背负箭袋；长弓（左手持弓、右手搭弦）；深棕短发束尾+护额；剪影锚点=长弓弧线+披肩
- 主用/备用路由：cast_ranged 主用（弓姿泛用——普攻/穿甲箭/布陷共用；melee_attack 备用·语义=弓端近身敲击）
- 锚图提示词（生产辅助件·非入库·先出锚图定稿，六动作件均以此为参考图）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, transparent background, chibi ranger in dark-green cape and brown leather armor, longbow in left hand, quiver on back, brown ponytail, standing idle pose, single full body character, one frame only
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、透明背景、披墨绿披肩穿棕色皮甲的 Q 版游侠、左手长弓、背负箭袋、棕色马尾、站立待机姿势、单个全身角色、仅一帧

### spr_cls_ranger_idle（游侠·待机）

- 目标规格：宽 128 竖条·透明底·idle 2 帧（128×256）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi ranger in dark-green cape and brown leather armor, longbow in left hand, quiver on back, brown ponytail, standing idle with bow, cape fluttering slightly, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、披墨绿披肩穿棕色皮甲的 Q 版游侠、左手长弓、背负箭袋、棕色马尾、持弓站立待机、披肩轻轻飘动、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_ranger_move（游侠·移动）

- 目标规格：宽 128 竖条·透明底·move 4 帧（128×512）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×512 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身剪影包络稳定）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi ranger in dark-green cape and brown leather armor, longbow in left hand, quiver on back, brown ponytail, swift walking cycle, cape flowing behind, four frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、披墨绿披肩穿棕色皮甲的 Q 版游侠、左手长弓、背负箭袋、棕色马尾、轻快疾行的行走循环、披肩向后飘扬、四帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_ranger_melee_attack（游侠·近战攻击）

- 目标规格：宽 128 竖条·透明底·melee_attack 3 帧（128×384）·单次播完停末帧·备用·语义=弓端近身敲击
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi ranger in dark-green cape and brown leather armor, longbow in left hand, quiver on back, brown ponytail, bow melee bash strike, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、披墨绿披肩穿棕色皮甲的 Q 版游侠、左手长弓、背负箭袋、棕色马尾、以弓身近身敲击、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_ranger_cast_ranged（游侠·远程施放）

- 目标规格：宽 128 竖条·透明底·cast_ranged 3 帧（128×384）·单次播完停末帧·主用·弓姿泛用（满弓→撒放+残影→收势）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi ranger in dark-green cape and brown leather armor, longbow in left hand, quiver on back, brown ponytail, drawing longbow fully then releasing arrow with motion trail, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、披墨绿披肩穿棕色皮甲的 Q 版游侠、左手长弓、背负箭袋、棕色马尾、将长弓拉满后放箭并带运动轨迹、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_ranger_hit（游侠·受击）

- 目标规格：宽 128 竖条·透明底·hit 2 帧（128×256）·单次·受击白闪为程序叠加不画入帧
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi ranger in dark-green cape and brown leather armor, longbow in left hand, quiver on back, brown ponytail, flinching backward while holding bow, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、披墨绿披肩穿棕色皮甲的 Q 版游侠、左手长弓、背负箭袋、棕色马尾、持弓后仰受击、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_ranger_downed（游侠·倒地）

- 目标规格：宽 128 竖条·透明底·downed 3 帧（128×384）·单次播完锁末帧（尸态闭合剪影常驻）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身位移动作·末帧闭合剪影躺平态）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi ranger in dark-green cape and brown leather armor, longbow in left hand, quiver on back, brown ponytail, collapsing forward, falling sideways, lying defeated with bow dropped and arrows scattered, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、披墨绿披肩穿棕色皮甲的 Q 版游侠、左手长弓、背负箭袋、棕色马尾、向前倾倒、侧身倒下、长弓掉落箭支散落的战败躺卧、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_arcanist 奇术师（单位设定卡与锚图）

- 设定卡（同人同装锚定源）：Q 版二头身·中等、袍身宽大遮体；暗红宽袍（主色 #7A2E35）+黑色符文纹样（#26202A）、垂地袍摆；环形符环法器（双手捧持、环上小符纹发微光）；灰白长发+宽檐软帽（帽檐压低）；剪影锚点=宽袍垂摆+环形法器
- 主用/备用路由：cast_ranged 主用（melee_attack 备用·语义=符环敲击）
- 锚图提示词（生产辅助件·非入库·先出锚图定稿，六动作件均以此为参考图）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, transparent background, chibi warlock in dark-red wide robe with black occult patterns, holding glowing ring-shaped talisman with both hands, pale hair under wide-brim hat, standing idle pose, single full body character, one frame only
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、透明背景、身着带黑色玄秘纹样暗红宽袍、双手捧持发光环形符环法器的 Q 版奇术师、宽檐帽下的灰白头发、站立待机姿势、单个全身角色、仅一帧

### spr_cls_arcanist_idle（奇术师·待机）

- 目标规格：宽 128 竖条·透明底·idle 2 帧（128×256）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi warlock in dark-red wide robe with black occult patterns, holding glowing ring-shaped talisman with both hands, pale hair under wide-brim hat, standing idle holding glowing ring talisman, soft light pulsing, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身着带黑色玄秘纹样暗红宽袍、双手捧持发光环形符环法器的 Q 版奇术师、宽檐帽下的灰白头发、持发光符环站立待机、柔光脉动、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_arcanist_move（奇术师·移动）

- 目标规格：宽 128 竖条·透明底·move 4 帧（128×512）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×512 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身剪影包络稳定）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi warlock in dark-red wide robe with black occult patterns, holding glowing ring-shaped talisman with both hands, pale hair under wide-brim hat, gliding walking cycle, wide robe swinging, four frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身着带黑色玄秘纹样暗红宽袍、双手捧持发光环形符环法器的 Q 版奇术师、宽檐帽下的灰白头发、滑行般的行走循环、宽袍摆动、四帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_arcanist_melee_attack（奇术师·近战攻击）

- 目标规格：宽 128 竖条·透明底·melee_attack 3 帧（128×384）·单次播完停末帧·备用·语义=符环敲击
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi warlock in dark-red wide robe with black occult patterns, holding glowing ring-shaped talisman with both hands, pale hair under wide-brim hat, ring talisman melee strike, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身着带黑色玄秘纹样暗红宽袍、双手捧持发光环形符环法器的 Q 版奇术师、宽檐帽下的灰白头发、符环近战敲击、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_arcanist_cast_ranged（奇术师·远程施放）

- 目标规格：宽 128 竖条·透明底·cast_ranged 3 帧（128×384）·单次播完停末帧·主用（咒波用暗红紫系、禁用阵营红 #C0392B）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi warlock in dark-red wide robe with black occult patterns, holding glowing ring-shaped talisman with both hands, pale hair under wide-brim hat, channeling curse, ring talisman glowing then releasing dark purple wave with thread trails, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身着带黑色玄秘纹样暗红宽袍、双手捧持发光环形符环法器的 Q 版奇术师、宽檐帽下的灰白头发、引导诅咒、符环发光后释放带丝线轨迹的暗紫色波、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_arcanist_hit（奇术师·受击）

- 目标规格：宽 128 竖条·透明底·hit 2 帧（128×256）·单次·受击白闪为程序叠加不画入帧
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi warlock in dark-red wide robe with black occult patterns, holding glowing ring-shaped talisman with both hands, pale hair under wide-brim hat, flinching backward, hat lifting, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身着带黑色玄秘纹样暗红宽袍、双手捧持发光环形符环法器的 Q 版奇术师、宽檐帽下的灰白头发、后仰受击、帽子掀起、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_cls_arcanist_downed（奇术师·倒地）

- 目标规格：宽 128 竖条·透明底·downed 3 帧（128×384）·单次播完锁末帧（尸态闭合剪影常驻）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身位移动作·末帧闭合剪影躺平态）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi warlock in dark-red wide robe with black occult patterns, holding glowing ring-shaped talisman with both hands, pale hair under wide-brim hat, stumbling, collapsing forward, lying defeated with ring talisman rolled away, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、身着带黑色玄秘纹样暗红宽袍、双手捧持发光环形符环法器的 Q 版奇术师、宽檐帽下的灰白头发、踉跄、向前倾倒、符环滚落一旁的战败躺卧、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_mutant_rat 变异鼠（单位设定卡与锚图）

- 设定卡（同人同装锚定源）：Q 版二头身·圆滚低伏、四足兽姿（非直立）、无器械；灰紫皮（主色 #8A7F96）、背脊更深，红眼 #D84A3E 发光；细长裸尾、豁耳、突出门牙；剪影锚点=圆滚低伏体块+长尾
- 主用/备用路由：melee_attack 主用（撕咬/疫咬；cast_ranged 备用·语义=毒液喷吐）
- 锚图提示词（生产辅助件·非入库·先出锚图定稿，六动作件均以此为参考图）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, transparent background, chibi mutant rat creature, round hunched gray-purple body with darker back, glowing red eyes, long bare tail, notched ears, quadruped stance, no clothes, no weapon, standing idle pose, single full body character, one frame only
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、透明背景、Q 版变异鼠生物、背部更深色的圆滚弓背灰紫身体、发光红眼、细长裸尾、豁耳、四足站姿、无衣着、无武器、站立待机姿势、单个全身角色、仅一帧

### spr_en_mutant_rat_idle（变异鼠·待机）

- 目标规格：宽 128 竖条·透明底·idle 2 帧（128×256）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mutant rat creature, round hunched gray-purple body with darker back, glowing red eyes, long bare tail, notched ears, quadruped stance, no clothes, no weapon, crouching rat idle, sniffing motion, back slightly rising, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版变异鼠生物、背部更深色的圆滚弓背灰紫身体、发光红眼、细长裸尾、豁耳、四足站姿、无衣着、无武器、蹲伏的鼠类待机、嗅探动作、背部微微起伏、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_mutant_rat_move（变异鼠·移动）

- 目标规格：宽 128 竖条·透明底·move 4 帧（128×512）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×512 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身剪影包络稳定）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mutant rat creature, round hunched gray-purple body with darker back, glowing red eyes, long bare tail, notched ears, quadruped stance, no clothes, no weapon, scurrying rat run cycle, low to ground, four frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版变异鼠生物、背部更深色的圆滚弓背灰紫身体、发光红眼、细长裸尾、豁耳、四足站姿、无衣着、无武器、贴地疾窜的鼠类奔跑循环、贴近地面、四帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_mutant_rat_melee_attack（变异鼠·近战攻击）

- 目标规格：宽 128 竖条·透明底·melee_attack 3 帧（128×384）·单次播完停末帧·主用（后蹲蓄力→前扑张口咬→回位，仅前半身弹出）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mutant rat creature, round hunched gray-purple body with darker back, glowing red eyes, long bare tail, notched ears, quadruped stance, no clothes, no weapon, rat pouncing bite attack, lunging forward with open jaws, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版变异鼠生物、背部更深色的圆滚弓背灰紫身体、发光红眼、细长裸尾、豁耳、四足站姿、无衣着、无武器、鼠类前扑咬击、张口向前的扑咬、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_mutant_rat_cast_ranged（变异鼠·远程施放）

- 目标规格：宽 128 竖条·透明底·cast_ranged 3 帧（128×384）·单次播完停末帧·备用·语义=毒液喷吐（毒沫用毒沼紫绿系）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mutant rat creature, round hunched gray-purple body with darker back, glowing red eyes, long bare tail, notched ears, quadruped stance, no clothes, no weapon, rat spitting venom spray, purple poison cone, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版变异鼠生物、背部更深色的圆滚弓背灰紫身体、发光红眼、细长裸尾、豁耳、四足站姿、无衣着、无武器、鼠类喷吐毒液、紫色毒锥、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_mutant_rat_hit（变异鼠·受击）

- 目标规格：宽 128 竖条·透明底·hit 2 帧（128×256）·单次·受击白闪为程序叠加不画入帧
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mutant rat creature, round hunched gray-purple body with darker back, glowing red eyes, long bare tail, notched ears, quadruped stance, no clothes, no weapon, rat flinching, back arching, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版变异鼠生物、背部更深色的圆滚弓背灰紫身体、发光红眼、细长裸尾、豁耳、四足站姿、无衣着、无武器、鼠类受击瑟缩、背部弓起、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_mutant_rat_downed（变异鼠·倒地）

- 目标规格：宽 128 竖条·透明底·downed 3 帧（128×384）·单次播完锁末帧（尸态闭合剪影常驻）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身位移动作·末帧闭合剪影躺平态）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mutant rat creature, round hunched gray-purple body with darker back, glowing red eyes, long bare tail, notched ears, quadruped stance, no clothes, no weapon, rat collapsing, rolling over, lying defeated flat with legs splayed, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版变异鼠生物、背部更深色的圆滚弓背灰紫身体、发光红眼、细长裸尾、豁耳、四足站姿、无衣着、无武器、鼠类倒下、翻身滚倒、四肢摊开的战败平躺、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_goblin_miner 哥布林矿工（单位设定卡与锚图）

- 设定卡（同人同装锚定源）：Q 版二头身·矮壮弓背；哥布林绿皮肤（#6FA050）、破旧棕色矿工服+腰带；黄色矿工帽（#E0B84B）带头灯、肩扛铁镐；剪影锚点=矿工帽+铁镐
- 主用/备用路由：melee_attack 主用（挥镐；cast_ranged 备用·语义=投掷碎石）
- 锚图提示词（生产辅助件·非入库·先出锚图定稿，六动作件均以此为参考图）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, transparent background, chibi goblin miner, green skin, yellow miner helmet with headlamp, ragged brown work clothes, iron pickaxe held in both hands, standing idle pose, single full body character, one frame only
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、透明背景、Q 版哥布林矿工、绿色皮肤、带头灯的黄色矿工帽、破旧棕色工作服、双手紧握铁镐、站立待机姿势、单个全身角色、仅一帧

### spr_en_goblin_miner_idle（哥布林矿工·待机）

- 目标规格：宽 128 竖条·透明底·idle 2 帧（128×256）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi goblin miner, green skin, yellow miner helmet with headlamp, ragged brown work clothes, iron pickaxe held in both hands, goblin idle leaning on pickaxe, looking around with headlamp glow, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版哥布林矿工、绿色皮肤、带头灯的黄色矿工帽、破旧棕色工作服、双手紧握铁镐、哥布林拄镐待机、头灯微光下环顾四周、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_goblin_miner_move（哥布林矿工·移动）

- 目标规格：宽 128 竖条·透明底·move 4 帧（128×512）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×512 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身剪影包络稳定）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi goblin miner, green skin, yellow miner helmet with headlamp, ragged brown work clothes, iron pickaxe held in both hands, goblin hunched scurrying walk cycle, pickaxe on shoulder, four frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版哥布林矿工、绿色皮肤、带头灯的黄色矿工帽、破旧棕色工作服、双手紧握铁镐、哥布林弓背疾行的行走循环、铁镐扛在肩上、四帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_goblin_miner_melee_attack（哥布林矿工·近战攻击）

- 目标规格：宽 128 竖条·透明底·melee_attack 3 帧（128×384）·单次播完停末帧·主用（举镐过头→猛挥下砸+速度线→回位）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi goblin miner, green skin, yellow miner helmet with headlamp, ragged brown work clothes, iron pickaxe held in both hands, goblin swinging pickaxe overhead strike, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版哥布林矿工、绿色皮肤、带头灯的黄色矿工帽、破旧棕色工作服、双手紧握铁镐、哥布林抡镐过头猛砸、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_goblin_miner_cast_ranged（哥布林矿工·远程施放）

- 目标规格：宽 128 竖条·透明底·cast_ranged 3 帧（128×384）·单次播完停末帧·备用·语义=投掷碎石
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi goblin miner, green skin, yellow miner helmet with headlamp, ragged brown work clothes, iron pickaxe held in both hands, goblin throwing rock, wind-up and throw with motion trail, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版哥布林矿工、绿色皮肤、带头灯的黄色矿工帽、破旧棕色工作服、双手紧握铁镐、哥布林投掷石块、蓄力挥臂后带轨迹掷出、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_goblin_miner_hit（哥布林矿工·受击）

- 目标规格：宽 128 竖条·透明底·hit 2 帧（128×256）·单次·受击白闪为程序叠加不画入帧
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi goblin miner, green skin, yellow miner helmet with headlamp, ragged brown work clothes, iron pickaxe held in both hands, goblin flinching backward, helmet tilting, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版哥布林矿工、绿色皮肤、带头灯的黄色矿工帽、破旧棕色工作服、双手紧握铁镐、哥布林后仰受击、矿帽歪斜、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_goblin_miner_downed（哥布林矿工·倒地）

- 目标规格：宽 128 竖条·透明底·downed 3 帧（128×384）·单次播完锁末帧（尸态闭合剪影常驻）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身位移动作·末帧闭合剪影躺平态）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi goblin miner, green skin, yellow miner helmet with headlamp, ragged brown work clothes, iron pickaxe held in both hands, goblin collapsing sideways, lying defeated with pickaxe dropped and helmet fallen off, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版哥布林矿工、绿色皮肤、带头灯的黄色矿工帽、破旧棕色工作服、双手紧握铁镐、哥布林侧身倒下、铁镐掉落矿帽脱落的战败躺卧、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_elite_boss 矿洞祸首（精英）（单位设定卡与锚图）

- 设定卡（同人同装锚定源）：Q 版二头身·熊罴状巨兽、宽厚低伏（同一 128 画布内占幅更满；运行时放大 1.3 倍为程序渲染口径，素材不放大绘制）；皮毛阴郁冷色（岩蓝灰 #5A6472 加深基调）；身覆黑苔异变纹路（#2A2432，「黑苔=异变」视觉语言首次登场）、眼窝冷光（灯火黄 #F5C869）；金色描边框不画入素材（UI 层程序化）；剪影锚点=宽厚巨躯+黑苔纹+冷光眼窝
- 主用/备用路由：melee_attack 与 cast_ranged 双主用（穷追重击+威慑怒吼）
- 锚图提示词（生产辅助件·非入库·先出锚图定稿，六动作件均以此为参考图）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, transparent background, chibi mutated cave boss beast, bear-like bulky low body in gloomy cold blue-gray fur, black moss veins covering body, glowing cold yellow eyes, no golden frame, no weapon, standing idle pose, single full body character, one frame only
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、透明背景、Q 版变异洞穴首领巨兽、阴郁冷蓝灰皮毛的熊状宽厚低伏躯体、覆满全身的黑苔纹路、发冷光的黄色双眼、无金色边框、无武器、站立待机姿势、单个全身角色、仅一帧

### spr_en_elite_boss_idle（矿洞祸首（精英）·待机）

- 目标规格：宽 128 竖条·透明底·idle 2 帧（128×256）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mutated cave boss beast, bear-like bulky low body in gloomy cold blue-gray fur, black moss veins covering body, glowing cold yellow eyes, no golden frame, no weapon, monstrous boss idle, heavy shoulder breathing, black veins faintly pulsing, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版变异洞穴首领巨兽、阴郁冷蓝灰皮毛的熊状宽厚低伏躯体、覆满全身的黑苔纹路、发冷光的黄色双眼、无金色边框、无武器、巨怪首领待机、肩部沉重起伏呼吸、黑苔纹微微搏动、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_elite_boss_move（矿洞祸首（精英）·移动）

- 目标规格：宽 128 竖条·透明底·move 4 帧（128×512）·循环
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×512 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身剪影包络稳定）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mutated cave boss beast, bear-like bulky low body in gloomy cold blue-gray fur, black moss veins covering body, glowing cold yellow eyes, no golden frame, no weapon, heavy lumbering boss walk cycle, four frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版变异洞穴首领巨兽、阴郁冷蓝灰皮毛的熊状宽厚低伏躯体、覆满全身的黑苔纹路、发冷光的黄色双眼、无金色边框、无武器、沉重迟缓的首领行走循环、四帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_elite_boss_melee_attack（矿洞祸首（精英）·近战攻击）

- 目标规格：宽 128 竖条·透明底·melee_attack 3 帧（128×384）·单次播完停末帧·主用·穷追（爪后收蓄力→巨爪横扫+速度线→收势）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mutated cave boss beast, bear-like bulky low body in gloomy cold blue-gray fur, black moss veins covering body, glowing cold yellow eyes, no golden frame, no weapon, boss massive claw swipe attack, wind-up then sweeping slash with speed lines, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版变异洞穴首领巨兽、阴郁冷蓝灰皮毛的熊状宽厚低伏躯体、覆满全身的黑苔纹路、发冷光的黄色双眼、无金色边框、无武器、首领巨爪横扫攻击、蓄力后带速度线的横扫劈砍、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_elite_boss_cast_ranged（矿洞祸首（精英）·远程施放）

- 目标规格：宽 128 竖条·透明底·cast_ranged 3 帧（128×384）·单次播完停末帧·主用·威慑怒吼（仰头吸气→张口怒吼+环形冲击波+黑苔纹亮起→收势）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mutated cave boss beast, bear-like bulky low body in gloomy cold blue-gray fur, black moss veins covering body, glowing cold yellow eyes, no golden frame, no weapon, boss roaring, open jaws with circular shockwave, black veins glowing, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版变异洞穴首领巨兽、阴郁冷蓝灰皮毛的熊状宽厚低伏躯体、覆满全身的黑苔纹路、发冷光的黄色双眼、无金色边框、无武器、首领怒吼、张口伴随环形冲击波、黑苔纹发亮、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_elite_boss_hit（矿洞祸首（精英）·受击）

- 目标规格：宽 128 竖条·透明底·hit 2 帧（128×256）·单次·受击白闪为程序叠加不画入帧
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×256 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（脚部锚定逐像素不动）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mutated cave boss beast, bear-like bulky low body in gloomy cold blue-gray fur, black moss veins covering body, glowing cold yellow eyes, no golden frame, no weapon, boss flinching slightly, two frames
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版变异洞穴首领巨兽、阴郁冷蓝灰皮毛的熊状宽厚低伏躯体、覆满全身的黑苔纹路、发冷光的黄色双眼、无金色边框、无武器、首领轻微受击瑟缩、两帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### spr_en_elite_boss_downed（矿洞祸首（精英）·倒地）

- 目标规格：宽 128 竖条·透明底·downed 3 帧（128×384）·单次播完锁末帧（尸态闭合剪影常驻）
- 出图后处理：出图（竖条或网格）→ 切片重排为 128×384 竖条（帧格自上而下按播放序、无间隔线无帧边框）→ 透明底扣图 → 帧间脚部锚定校准（全身位移动作·末帧闭合剪影躺平态）→ 缩至 48px 高职业/种类可辨走查
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, chibi character with 2-head-tall proportion, big head, oversized weapon, side view, vertical sprite strip with frames stacked top to bottom, transparent background, chibi mutated cave boss beast, bear-like bulky low body in gloomy cold blue-gray fur, black moss veins covering body, glowing cold yellow eyes, no golden frame, no weapon, boss collapsing heavily, falling sideways, lying defeated with black veins faded, three keyframes
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、Q 版二头身角色、大脑袋、夸张大武器、侧面视角、帧格自上而下堆叠的竖版精灵长条、透明背景、Q 版变异洞穴首领巨兽、阴郁冷蓝灰皮毛的熊状宽厚低伏躯体、覆满全身的黑苔纹路、发冷光的黄色双眼、无金色边框、无武器、首领沉重倒下、侧身倒地、黑苔纹黯淡的战败躺卧、三个关键帧

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

---

## 05 小队与交互图标组（7 件）

- 生产顺序建议：图标 6 件 **P4**（批 4 替换次序第 4 位·图标层）；`tile_secret_passage` 为 tile 类随 **P2** tile 批次产出
- 组级公共说明：图标 64×64 透明底、主体居中约占画布 80%、48×48 渲染可辨；图标须在明亮（村子）与冷暗（矿洞）两种底色上均可辨（必要时靠描边 #2E2620 保证对比）；暗门检定点无专属图标（换格即揭示——tile_secret_passage 为暗门主视觉）；验收细则见 `05_小队与交互图标组.md`

### icon_explore_party（探索小队标记）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；蓝底与我方阵营色 #3D7DC8 一致
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, party banner marker icon, blue round badge with white marching flag, game ui icon, centered, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、小队旗帜标记图标、带白色行军旗的蓝色圆形徽章、游戏 UI 图标、居中、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### icon_pt_event（事件点）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64；叹号符号语义清晰；置灰后（消耗态由运行时置灰）轮廓仍可辨
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, unrolled parchment scroll with golden exclamation mark, quest event icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、展开的羊皮卷轴与金色叹号、任务事件图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, question mark
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、问号

### icon_pt_treasure（宝箱）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64；宝箱剪影一眼可辨（棕木 #8B5A3C+金属包边 #A8843C+金光 #D4AF37）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, closed fantasy treasure chest with golden trim, faint light from lid gap, game ui icon, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、带金色镶边的闭合奇幻宝箱、盖缝透出微光、游戏 UI 图标、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### icon_pt_target（委托目标点）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64；常显件——迷雾压暗 0.55 基准下目标旗仍清晰（对比度走查）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, small blue pennant flag on wooden pole, objective marker icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、木杆上的小型蓝色燕尾旗、目标点标记图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### icon_pt_exit（出口）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64；「门=离开」语义直观（岩蓝灰门框+灯火黄内透）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, stone archway gate with warm glowing light inside, exit portal icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、内透暖光的石砌拱门、出口传送门图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### icon_pt_battle（必然遭遇点）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64；X 剪影远观可辨（银灰刃+暖棕柄交叉）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, two crossed swords forming X shape, battle encounter icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、两柄交叉成 X 形的剑、战斗遭遇图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

### tile_secret_passage（暗门开启窄道）

- 目标规格：128×128（源）·物件件（替换岩壁格的 tile）
- 出图后处理：正方形出图（512 或 1024）→ 缩放至 128×128；确认轮廓不越画布、底缘对齐格界；与 `tile_mine_wall` 同色系并排时「裂开+透光」差异明显（岩蓝灰壁 #3E4550+灯火黄内透 #F5C869）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, cracked rock wall opening into narrow glowing passage, warm light leaking from crevice, single game tile, top-down view, bottom edge aligned
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、裂开通往狭窄发光通道的岩壁、缝隙间漏出暖光、单格游戏地格、顶视角、底缘对齐

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, overlapping tile edges
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、tile 边缘交叠

---

## 06 迷雾组（2 件）

- 生产顺序建议：**P6**（批 4 替换次序末位）
- 组级公共说明：512×512 可平铺无缝、灰白雾纹单色系（禁彩色雾）；**α 承载口径（06 组 v1.3）——贴图自身不携带 α（全不透明基准），净透明度由运行时 cfg modulate 承载**（带 α 会与兜底层双绘叠加过暗）；出图后整图压全不透明；验收细则见 `06_迷雾组.md`

### fx_fog_unseen（未探索浓雾）

- 目标规格：512×512·可平铺（四边无缝）·全不透明基准（净 α=cfg 0.92 由 modulate 承载）
- 出图后处理：正方形出图（≥1024）→ 缩放至 512×512；**整图压全不透明（去 α）**；2×2 平铺目检接缝；遮盖任意 tile 后不可透见地形轮廓（全遮罩语义）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, seamless tileable thick rolling fog texture, layered gray-white mist on dark blue-gray base, fully obscuring, soft volumetric cloud shapes, no objects visible
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、无缝可平铺的厚重翻滚雾气纹理、深蓝灰底色上层叠的灰白雾、完全遮蔽、柔和的体积云形态、无可见物体

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, silhouettes, hidden objects, colored fog
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、剪影、隐藏物体、彩色雾

### fx_fog_dim（已探索暗态滤镜）

- 目标规格：512×512·可平铺（四边无缝）·全不透明基准（净 α=cfg 0.55 由 modulate 承载）
- 出图后处理：缩放至 512×512；**整图压全不透明（去 α）**；压暗后 tile 轮廓与交互图标仍可透见（半透明记忆态语义由 modulate 呈现）；雾丝不形成明显图案
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, seamless tileable thin mist overlay texture, sparse faint fog wisps on semi-transparent dark gradient, subtle and uniform, memory state dimming layer
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、无缝可平铺的薄雾叠加纹理、半透明深色渐变上稀疏淡薄的雾丝、细腻均匀、记忆态压暗层

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, heavy clouds, dense fog
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、厚重云层、浓密雾气

---

## 07 系统图标组（19 件）

- 生产顺序建议：**P4**（批 4 替换次序第 4 位·图标层）；19 件同批次产出保证风格一致；建议先出一件（如 `icon_res_gold`）定组内样张再铺全组
- 组级公共说明：64×64 透明底、主体居中约占 80%、48×48 渲染可辨；六职业图标与其 04 组对应单位武器形状一致（同人同装跨组延伸——图标=职业剪影小样）；七属性七件等尺寸构图节奏一致；三资源条三件体量一致；验收细则见 `07_系统图标组.md`

### icon_res_gold（货币）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查（金 #D4AF37+暖棕袋）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, small pouch of gold coins with rope tie, currency icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、绳结系口的一小袋金币、货币图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_res_exp（经验）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查（藏青 #2B3A67 底光）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, glowing blue five-pointed star badge, experience points icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、发光的蓝色五角星徽章、经验值图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_res_repu（声望）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查（绶带我方蓝+徽面金）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, golden round medal with blue ribbon, reputation icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、配蓝色绶带的金色圆形奖章、声望图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_attr_str（力量）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；七属性系列等尺寸构图节奏一致
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, raised armored fist with power lines, strength icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、带力量线条的高举铠甲拳头、力量图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_attr_agi（敏捷）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；七属性系列一致
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, swift boot with wind swirl lines, agility icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、带旋风流线的迅捷之靴、敏捷图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_attr_con（体质）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；七属性系列一致
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, thick oak shield with rivets, constitution icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、带铆钉的厚实橡木盾、体质图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_attr_int（智力）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；七属性系列一致
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, open book with floating star sparkles, intelligence icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、漂浮着星光点点的摊开书卷、智力图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_attr_wis（感知）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；七属性系列一致
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, open eye with golden iris and sight lines, perception icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、金色虹膜带视线线条的睁开眼睛、感知图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_attr_wil（意志）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；七属性系列一致（深紫 #5E3F82 系）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, upright scepter with gem on top, willpower icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、顶端镶宝石的直立权杖、意志图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_attr_luk（幸运）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；七属性系列一致（草绿 #7CA85A）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, four-leaf clover with dewdrop highlight, luck icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、带露珠高光的四叶草、幸运图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_res_hp（生命）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；三资源条体量一致（红 #C0392B 系液体）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, round potion bottle with red heart-shaped liquid, health icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、盛着红色心形液体的圆药水瓶、生命图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_res_mp（法力）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；三资源条体量一致（#3D7DC8 系）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, blue faceted crystal gem with glow, mana icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、带光晕的蓝色切面水晶宝石、法力图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_res_sp（精力）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；三资源条体量一致（#E0B84B）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, yellow lightning bolt with small wing, stamina energy icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、带小翅膀的黄色闪电、精力能量图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_class_warrior（职业·战士）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；与 spr_cls_warrior 武器形状一致（银灰+钢蓝纹章）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, crossed greatsword and round shield with blue crest, warrior class icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、交叉的宽刃大剑与带蓝色纹章的圆盾、战士职业图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_class_rogue（职业·盗贼）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；与 spr_cls_rogue 武器形状一致（银刃+深紫柄）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, two crossed daggers with purple grips, rogue class icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、两柄带紫色握柄的交叉匕首、盗贼职业图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_class_mage（职业·法师）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；与 spr_cls_mage 锚点一致（藏青帽+橙光宝珠杖）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, pointed wizard hat with staff and glowing orange orb, mage class icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、尖顶法师帽与带发光橙色宝珠的法杖、法师职业图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_class_priest（职业·牧师）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；与 spr_cls_priest 锚点一致（金徽+白辉光环）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, golden sun holy symbol disc with halo, priest class icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、带光环的金色太阳圣徽圆盘、牧师职业图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_class_ranger（职业·游侠）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；与 spr_cls_ranger 武器形状一致（墨绿弓身+羽箭）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, longbow with nocked arrow, ranger class icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、搭箭上弦的长弓、游侠职业图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

### icon_class_arcanist（职业·奇术师）

- 目标规格：64×64·透明底
- 出图后处理：扣图至透明底 → 缩放至 64×64（主体居中约 80%）；48×48 渲染可辨走查；与 spr_cls_arcanist 锚点一致（暗红环+黑符纹）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, glowing ring-shaped talisman with occult runes, arcanist class icon, game ui, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、带玄秘符文的发光环形符环、奇术师职业图标、游戏 UI、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple objects, border frame
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多物体、外框

---

## 08 UI 基础件组（8 件）

- 生产顺序建议：**P5**（批 4 替换次序第 5 位·UI 件层）；建议先出 `ui_button_normal` 与 `ui_panel_ninepatch` 母图定组内样张
- 组级公共说明：**同构变体产出**（同一造型文件改明暗/色相，避免独立生成导致轮廓漂移）——按钮三态优先「常态母图后处理派生（提亮=hover / 压灰=disabled）」、四档标签优先「同一造型改色相+角饰」；九宫格/三宫格拉伸走查（面板拉伸至 400×300、按钮至 240×64 无接缝断裂与角变形）；素材内禁止文字/字母（字体文字一律程序渲染）；验收细则见 `08_UI基础件组.md`

### ui_panel_ninepatch（面板九宫格母图）

- 目标规格：96×96·透明底（圆角外透明）·四角 24px 九宫格切角
- 出图后处理：扣图（圆角外清透明）→ 缩放至 96×96；四角 24×24 区域完整自包含（拉伸后四角不变形）、中段上下/左右拉伸无纹理断裂；面底不透明度基准 85%（后处理设定）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, fantasy game ui panel base, dark semi-transparent rounded rectangle, golden corner brackets and trim border, parchment inner lining, nine-patch corners, no text, no symbols, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、奇幻游戏 UI 面板底、深色半透明圆角矩形、金色角括与镶边、羊皮纸内衬、九宫格四角、无文字、无符号、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, icons inside
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、内部图标

  > 规格书负面另加项为「text, icons inside」——text 已含于通用负面基串，此处仅并入 icons inside。

### ui_button_normal（主按钮·常态）

- 目标规格：128×64·透明底·三宫格（左右端帽 24px+中段横向拉伸）
- 出图后处理：扣图 → 128×64；建议以本件为母图，hover/disabled 由母图后处理派生（提亮/压灰）保证逐像素同构；中段横向拉伸无断裂
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, fantasy game button, parchment face with golden trim and wooden end caps, rounded rectangle, normal state, no text, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、奇幻游戏按钮、羊皮纸按钮面配金色镶边与木质端帽、圆角矩形、常态、无文字、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

  > 规格书负面另加项「text」已含于通用负面基串，未重复追加。

### ui_button_hover（主按钮·悬停）

- 目标规格：128×64·透明底·三宫格（同常态结构）
- 出图后处理：优先由 ui_button_normal 母图后处理派生（提亮+顶部高光条+包边微光·灯火黄 #F5C869 点光）；如 AI 直出须垫图（img2img 低重绘幅度）并叠放对齐校验轮廓逐像素一致
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, same fantasy button in highlighted hover state, brighter face, top gloss highlight line, glowing trim, no text, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、同一奇幻按钮的高亮悬停态、更明亮的按钮面、顶部光泽高光条、发光镶边、无文字、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

  > 规格书负面另加项「text」已含于通用负面基串，未重复追加。

### ui_button_disabled（主按钮·禁用）

- 目标规格：128×64·透明底·三宫格（同常态结构）
- 出图后处理：优先由母图后处理派生（降饱和压灰·灰蓝 #7A8BA0 系罩层、无高光）；灰态仍可辨按钮轮廓与包边
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, same fantasy button in disabled state, desaturated gray tint, dim, no highlight, no text, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、同一奇幻按钮的禁用态、去饱和的灰色调、暗淡、无高光、无文字、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

  > 规格书负面另加项「text」已含于通用负面基串，未重复追加。

### ui_label_result_crit_success（大成功标签底）

- 目标规格：96×48·透明底
- 出图后处理：扣图 → 96×48；中部约 70% 面积低纹理留净（程序文字叠印）；四档并排仅色相+角饰不同、造型同构（建议同母图改色相派生）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, golden result banner ribbon, rounded label base with small star sparkles at corners, no text, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、金色的结算横幅绶带、四角缀着细小星光的圆角标签底、无文字、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

  > 规格书负面另加项「text, letters」均已含于通用负面基串，未重复追加。

### ui_label_result_success（成功标签底）

- 目标规格：96×48·透明底
- 出图后处理：同 crit_success（绿底 #4C9A5F+对勾角饰；四档同构变体）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, green result banner ribbon, rounded label base with small check mark at corners, no text, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、绿色的结算横幅绶带、四角缀着细小对勾的圆角标签底、无文字、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

  > 规格书负面另加项「text, letters」均已含于通用负面基串，未重复追加。

### ui_label_result_failure（失败标签底）

- 目标规格：96×48·透明底
- 出图后处理：同 crit_success（灰蓝底 #7A8BA0+短横线角饰；四档同构变体）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, gray-blue result banner ribbon, rounded label base with small dash marks at corners, no text, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、灰蓝色的结算横幅绶带、四角缀着细小短横线的圆角标签底、无文字、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

  > 规格书负面另加项「text, letters」均已含于通用负面基串，未重复追加。

### ui_label_result_crit_failure（大失败标签底）

- 目标规格：96×48·透明底
- 出图后处理：同 crit_success（红底 #B03A3A+裂纹角饰；四档同构变体）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, red result banner ribbon, rounded label base with small crack marks at corners, no text, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、红色的结算横幅绶带、四角缀着细小裂纹的圆角标签底、无文字、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线

  > 规格书负面另加项「text, letters」均已含于通用负面基串，未重复追加。

---

## 09 战棋叠加件与 D20 组（4 件）

- 生产顺序建议：**P6**（替换次序末位·正式件产出归 E2 素材波）
- 组级公共说明：叠加件叠于战棋格面之上、不得遮挡单位/地形辨识（半透明/角框化设计）；色觉无障碍沿用「颜色+形状」双编码；**`fx_battle_select`/`fx_battle_range` 为 256×128 菱形（E1 同 id 重制·00 §六-8）**；`fx_battle_range` 全不透明基准（禁自带 α、染蓝=移动/染红=攻击由运行时 modulate 承载、语义禁换）；验收细则见 `09_战棋叠加件与D20组.md`（v2.0）

### fx_battle_select（选中框·v2.0 同 id 重制菱形）

- 目标规格：**256×128·菱形透明底（中央镂空）·半透明角框**（菱形四顶点=画布四边中点、四角透明——E1 等距批重制）
- 出图后处理：2:1 比例出图（如 1024×512）→ 扣图（菱形角括外与中央均清透明，中央镂空≥60%、单位完整可见）→ 256×128；菱形四角括号在矿洞冷底上可辨（灯火黄 #F5C869 角括+细边线）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, isometric 2:1 diamond selection frame, rhombus corner brackets glowing warm yellow, hollow center, semi-transparent, no fill, diamond corners at frame edge midpoints, canvas corners transparent
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、2:1 等距菱形选中框、泛着暖黄光的菱形角括、中央镂空、半透明、无填充、菱形顶点位于画布四边中点、画布四角透明

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, solid fill, covering character
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、实心填充、遮挡角色

### fx_battle_range（范围指示格面·v2.0 同 id 重制菱形）

- 目标规格：**256×128·菱形全不透明基准**（净 α 由运行时 modulate 承载；菱形内像素全不透明、菱形外透明属正常裁剪——E1 等距批重制）
- 出图后处理：2:1 比例出图（如 1024×512）→ 缩放至 256×128；**菱形内压全不透明中性格面（禁自带 α**——与运行时染色 modulate 会 α 双乘失控）；菱形四顶点=画布四边中点；染蓝=移动/染红=攻击技能由 cfg 承载；叠加后底面 tile 纹理仍隐约可辨
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, isometric 2:1 diamond game tile range overlay, rhombus plain neutral cell fill with thin diamond border, uniform, no symbols, diamond corners at frame edge midpoints, canvas corners transparent
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、2:1 等距菱形地格范围叠加件、带细菱形边的素净中性格面填充、均匀一致、无符号、菱形顶点位于画布四边中点、画布四角透明

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, arrows, icons, strong colors
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、箭头、图标、浓烈色彩

### fx_battle_path_arrow（路径箭头·**备用**——消费点已拆除、维持 128×128 方形口径）

- 目标规格：128×128·透明底·半透明（**v2.0 等距备用注记 2026-10-09**：E1 后棋盘为菱形网格，如恢复箭头表现需按当时几何重订规格，本方形条目仅历史备用参考）
- 出图后处理：扣图 → 128×128；箭身左右对称设计（上/下/左朝向由运行时旋转 ±90°/180° 复用、不出多朝向素材）；渲染尺寸=格内适配不溢出（灯火黄箭身+描边）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, game path arrow pointing right, warm yellow translucent arrow with outline, single direction, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、朝右指的游戏路径箭头、带描边的暖黄色半透明箭头、单一朝向、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, multiple arrows, pointing left
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、多个箭头、朝左

### fx_d20（D20 骰面）

- 目标规格：256×256·透明底·单帧静姿
- 出图后处理：扣图 → 256×256；骰面留净供程序数字叠印（数字不入素材——本地化与数值变更零素材重产）；放大至 ≥200px 检定演出特写棱面清晰（冷光蓝灰晶体质感 #5A6472 系+灯火黄高光棱线）
- 正向提示词（完整版，直接复制）：

  ```text
  anime style, cel shading, clean bold lineart, flat color blocks with soft highlights, japanese fantasy, high saturation with balanced brightness, stylized twenty-sided dice d20, faceted crystal die in cold blue-gray with warm yellow edge highlights, centered single object, no numbers on faces, transparent background
  ```

  中文参考：动画风格、赛璐璐上色、干净粗犷线稿、带柔和高光的平涂色块、日式奇幻、高饱和度且明度均衡、风格化的二十面骰 D20、冷蓝灰色带暖黄棱线高光的切面水晶骰、居中单个物体、骰面无数字、透明背景

- 负面提示词（完整版，直接复制）：

  ```text
  pixel art, pixelated, 3d render, photorealistic, realistic photo, blurry, jpeg artifacts, watermark, signature, username, text, letters, numbers, logo, extra limbs, extra fingers, deformed body, mutated anatomy, lowres, sketch, unfinished lineart, messy lines, harsh gradients, gradient banding, noisy texture, colored background, drop shadow, frame borders, grid lines, numbers on faces
  ```

  中文参考：像素画、像素化、3D 渲染、照片级写实、写实照片、模糊、JPEG 压缩伪影、水印、签名、用户名、文字、字母、数字、徽标、多余肢体、多余手指、躯体变形、变异解剖、低分辨率、草稿、未完成线稿、杂乱线条、生硬渐变、渐变条带、噪点纹理、彩色背景、投影、边框、网格线、骰面数字

---

## 字体组说明（2 件·非 AI 生图通道——本全集不出提示词）

ttf/otf 字体文件无法用 AI 生图获得，`font_cn_body` / `font_cn_title` 排除出提示词全集，按 `10_字体组.md` 采购要点执行（许可覆盖 Steam+TapTap 商用）。建议方向（免费商用，供参考——通道仍以用户拍板为准）：

- **font_cn_body 正文字体**：思源黑体（Source Han Sans，OFL 授权）或阿里巴巴普惠体方向——字形端正易读、GB2312 或以上字集覆盖，与赛璐璐日式奇幻画风不冲突（黑体/圆体类优先）。
- **font_cn_title 标题装饰字体**：霞鹜文楷（LXGW WenKai，OFL 授权）或思源宋体（加粗档）方向——衬线/笔触装饰类，用于标题屏与各屏大标题（须含项目标题字）。
- 获取渠道：字体官网 / GitHub 开源发布页 / 免费商用字体站；入库前按 10 组验收条款走查（九档字号渲染、UI 文案字符缺字清零、授权文件留档 `art_source_log.md`）；**入库登记前须先扩 ASSET_ID_PREFIXES 合法集加 `font_` 前缀**（00 §九注，否则命名校验拦截）。

---

## 本全集对账

| 组 | 件数 | 说明 |
|---|---|---|
| 01 背景 | 6 | bg_guild_hall 已正式入库不重出 |
| 02 矿洞 tile | 14 | 方形 9（探索专用；rock/cart 备用）+ 战棋菱形 `_iso` 5（E1 增补）；含 tile_battle_trap（v1.1 扩件·v2.0 菱形重制） |
| 03 村子 tile | 14 | 方形 7 + 战棋菱形 `_iso` 7（完整版预备·E1 增补） |
| 04 单位动作集 | 54 | 9 单位×6 动作 |
| 05 小队与交互图标 | 7 | 图标 6 + 暗门 tile 1 |
| 06 迷雾 | 2 | |
| 07 系统图标 | 19 | 资源 3 + 属性 7 + 资源条 3 + 职业 6 |
| 08 UI 基础件 | 8 | 面板 1 + 按钮三态 3 + 四档标签 4 |
| 09 战棋叠加与 D20 | 4 | 叠加 3（select/range·v2.0 菱形重制 + path_arrow 备用）+ D20 面 1 |
| **合计** | **128** | = 131 − bg_guild_hall（已正式）− 字体 2（非生图通道）；116＋E1 批 `_iso` 新键 12（2026-10-09） |

（全文完）
