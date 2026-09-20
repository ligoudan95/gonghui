# ZCode 多 Agent 团队配置（由 opencode 版 AGENTS_CONFIG 转换）

本文件定义一套可复用的 6 人 AI Agent 团队工作流在 **ZCode 环境**下的实现。团队规则由两处承载：

- **根 `AGENTS.md`**：Team Lead（主代理）规则。ZCode 每次会话自动加载，等价于 opencode 的 `default_agent: "team-lead"` + `team-lead.md`
- **`.zcode/agents/<role>.md`**：5 个子角色提示词。主代理派工时将文件全文注入子代理提示词开头

---

## 与 opencode 版的机制对照（转换核心）

| opencode 机制 | ZCode 等价实现 |
|---|---|
| `.opencode/agents/team-lead.md`（mode: primary）+ `opencode.json` 的 `default_agent` | 根 `AGENTS.md`（自动加载）。主代理即 Team Lead，**无需任何配置文件** |
| `.opencode/agents/<role>.md`（mode: subagent；frontmatter 定义 mode/model/permission） | `.zcode/agents/<role>.md` **自定义子代理类型定义**（frontmatter：`name` / `description` / `readOnly` / `tools` / `color` / `thoughtLevel`）→ 主代理以 `subagent_type: <角色名>` 直接派工，工具权限**硬性生效**（planner/architect 只读、git-admin 仅 Read+Bash 等）；模型跟随会话模型 |
| `task` 工具派工 | Agent 工具（subagent_type 直接填角色名，见上），提示词 = 任务 + **累计完整方案**（角色规则在类型定义中；子代理每次全新会话，任务上下文必须自包含） |
| `task_id` 复用同一子代理会话 | 记录 spawn 返回的 **agentId**；同角色多轮讨论用 **SendMessage** 发同一 agentId 续聊，绝不重开新代理 |
| 子代理产物经对话回 main | 子代理最终消息只回主代理、用户看不到；主代理必须在自己的回复中**完整呈现**阶段产物 |
| 用户审核闸门 | 主代理呈现产物后**结束回合等用户**；拍板项用 AskUserQuestion；「用户未答复=冻结」红线（防线 hooks 插件 `gonghui-defense` 加固：`ask_gate`/`ask_timeout_gate` 随仓库 `plugins/` 分发，各机安装本地插件「工会防线 Hooks」即启用，勿删；0.3.0 已实弹闭环——hooks 必须 process 型 node，勿改 command 型 `shell:"bash"`（桌面进程 PATH 无 bash 必秒败，详见「后续补充」第 5 条）；配置文件注册已被实测否决） |
| `.opencode/memory/`（MEMORY.md + logs/，opencode.json instructions 自动加载） | `.zcode/memory/`。ZCode **不会自动加载**它 → 根 AGENTS.md「会话启动检查」指示主代理会话开始先读 |
| `permission: edit/bash: deny`（配置层硬禁） | frontmatter `tools:` 白名单**硬性限制**（等价 opencode permission；2026-09-20 实测：`tools:` 生效，`readOnly` 单独**不**生效——每个角色都必须写 tools 列表）；角色文内「行为权限」节作补充约束（如 planner 不读源码——工具层拦不住，靠规则） |

### 派工实测补登（2026-09-20，新会话全量实测）

1. **"Agent type not found" 系克隆中间态，配置本身有效**：删空重克隆后，五个自定义子代理类型（planner/architect/programmer/docs-updater/git-admin）在全新会话中**全部注册成功**——证实此前个别会话报错系克隆中间态导致注册失效；general-purpose 回退方案保留作保险
2. **tools 白名单语义为"上限限权"**：各角色实际注入的工具 ⊆ frontmatter 白名单，无一越权（git-admin 无 Write/Edit 依旧成立）；各角色统一额外内置 **RespondToCoordinator**（子代理→协调者通信工具，非白名单声明项，无文件操作能力）
3. **Glob/Grep 注入不完整（共性现象）**：实测**不按角色稳定复现**——第五批 programmer / docs-updater / git-admin 三个角色未注入（planner 到位）；第六批复测 architect 亦未注入（其白名单含 Read/Glob/Grep/Bash，实际仅注入 Read/Bash/RespondToCoordinator），planner 亦不保证到位；因缺失角色白名单均含 Bash，可用只读 shell 命令替代，实际使用无碍——后续若 ZCode 版本修复自动补齐，**无需改动配置**

---

## 团队结构

```
Team Lead（主代理 = ZCode 本体，规则见根 AGENTS.md）— 唯一持久角色
  ├─ @planner（策划）        — 需求→策划案
  ├─ @architect（架构师）    — 策划案→程序方案
  ├─ @programmer（程序员）   — 程序方案→代码
  ├─ @docs-updater（文档）   — 代码变更→文档同步
  └─ @git-admin（Git管理）   — 所有 Git 操作
```

## 工作流铁律（详见根 AGENTS.md）

1. **严格顺序，步步审核**：planner → 用户审 → architect → 用户审 → programmer → **用户明确"同意"** → docs-updater → 主代理更新日志 → git-admin
2. **同角色多轮复用 agentId**（SendMessage），不开新代理
3. **一轮结束标志**：docs-updater 完成文档 + 主代理更新工作日志
4. **传递累计完整方案**，不只传最后一条增量
5. **三条事故红线**：用户未答复=冻结 / 转达必标来源 / 追认≠预授权

## Agent 间通信规则

所有 Agent 之间的信息传递必须通过对话完成（主代理转发），**严禁用文件作为通信媒介**：

- 策划案/架构方案作为对话文本输出，不写成长文档存盘传递
- `.zcode/agents/*.md` 是**自定义子代理类型定义**（frontmatter 硬限工具），不是通信产物
- 除 @docs-updater 外任何角色不得写文档目录；`.zcode/memory/` 只归 Team Lead

## 文件结构

```
项目根目录/
├── AGENTS.md                      # Team Lead 规则（ZCode 每次会话自动加载）
├── 新的规划/                      # 项目文档目录（通用模板为 docs/，按项目实际）
├── plugins/                       # 本地插件市场（防线 hooks 插件化，见「后续补充」第 5 条）
│   ├── marketplace.json           # 市场清单（name=dev-gonghui，条目 gonghui-defense）
│   └── gonghui-defense/           # 插件「工会防线 Hooks」（中文 displayName/description）
│       ├── .zcode-plugin/
│       │   └── plugin.json        # 插件清单（name/version，hooks 指向 ./hooks/hooks.json）
│       └── hooks/
│           ├── hooks.json         # 插件格式注册（${CLAUDE_PLUGIN_ROOT} 定位脚本）
│           ├── ask_gate.cjs
│           └── ask_timeout_gate.cjs
└── .zcode/
    ├── config.json                # 项目级 MCP 配置（godot-ai 编辑器桥接待装插件启用；防线 hooks 已转插件化、不再注册于本文件，见「后续补充」第 5 条）
    ├── docs/
    │   └── AGENTS_CONFIG.md       # 本文件（团队规程 + 机制对照）
    ├── agents/                    # 5 个自定义子代理类型定义（frontmatter 硬限工具）
    │   ├── planner.md
    │   ├── architect.md
    │   ├── programmer.md
    │   ├── docs-updater.md
    │   └── git-admin.md
    └── memory/
        ├── MEMORY.md              # 永久记忆（项目架构、规则、约定）
        └── logs/                  # 每日工作日志
            └── YYYY-MM-DD.md
```

## 记忆系统

- **永久记忆**：`.zcode/memory/MEMORY.md` — 主代理会话开始必读（根 AGENTS.md「会话启动检查」）；阶段性关键事实与决策追加（新条目放最上面）
- **工作日志**：`.zcode/memory/logs/YYYY-MM-DD.md` — 由 Team Lead 在 @docs-updater 完成后、@git-admin 提交前更新
- **Team Lead 唯一直改**记忆文件，其余项目文件修改全部通过子代理

## 套用到新项目

1. 复制根 `AGENTS.md` 与整个 `.zcode/` 目录（agents/、docs/、memory/）到新项目
2. 修改根 AGENTS.md：头部项目名 + 「项目速查」节（仓库、文档体系、编码规范、自查命令）
3. 重新初始化 `.zcode/memory/MEMORY.md`（新项目的架构、规则、约定）
4. 回填各角色文件中的【按项目回填】槽位（architect 的项目铁律、docs-updater 的文档映射、git-admin 的代码目录与提交格式、programmer 的自查命令）
5. **无需配置文件、无需重启**——新会话自动加载根 AGENTS.md 即生效

## 后续补充（2026-09-20，吸收 feitu `.zcode/` 实战配置）

1. **角色文件升级为自定义子代理类型**：`.zcode/agents/*.md` 增加 frontmatter（`readOnly` / `tools` / `color` / `thoughtLevel`），工具权限硬性生效；主代理派工 subagent_type 直接填角色名（**若会话未加载类型则回退 general-purpose + 注入角色文件全文**，见根 AGENTS.md「派工」）。两条 feitu 实战经验同步写入根 AGENTS.md 与角色文件：子代理内 AskUserQuestion 会被权限层自动放行（答复非用户本意，确认一律经 Team Lead 转达）；拍板类管线禁跑 yolo 权限模式
2. **godot-ai MCP**：新建 `.zcode/config.json`（uvx godot-ai==3.2.4 attach 8000/9500，自 feitu 复制）。待 gonghui 建 Godot 工程并安装 `addons/godot_ai` 插件（可从 feitu 复制）后即可用编辑器桥接
3. **防线 hooks 实体迁移**：`ask_gate.cjs` / `ask_timeout_gate.cjs` 自 feitu 项目复制到用户级 `C:\Users\liangqihang\.zcode\hooks\`，用户级 config 路径已更新并冒烟测试通过（2026-09-20 补录完成；早前记录误写为 `C:\Users\A\` 且 config 实际仍指 feitu 目录，已纠正）——消除对 feitu 目录的跨项目依赖（**已于同日两度迁移：先按方案 A 入工作区仓库（第 4 条，已否决），终转插件化（第 5 条）**；本条原注"注册保持用户级；工作区 hooks 有信任门且信任不持久化，勿移回工作区"方向正确、实况更糟——配置文件 hooks 在本平台从未执行，详见第 5 条）
4. **防线 hooks 随仓库走（2026-09-20 方案 A，用户拍板）**【已否决：配置 hooks 在本平台从未执行，被第 5 条插件化取代】：脚本实体迁入仓库 `.zcode/hooks/ask_gate.cjs` / `ask_timeout_gate.cjs`（与用户级原副本逐字节一致，已确认不被 .gitignore 忽略、随 git 入库），用户级 `C:\Users\liangqihang\.zcode\hooks\` 原副本保留为闲置备份（同 feitu 先例）；注册迁至工作区 `.zcode/config.json`（与既有 mcp.servers 并列）：`hooks.enabled: true` + PreToolUse/PostToolUse 两个 process 类型 hook（matcher 仍为 `^AskUserQuestion$`），`command: "node"`（走 PATH，免疫各机 node 安装路径差异）、`args: ["${ZCODE_PROJECT_DIR}/.zcode/hooks/<脚本名>"]`（模板变量展开为仓库实际克隆路径，免疫用户名差异）；用户级 `~/.zcode/cli/config.json` 已清空为 `{}` 停用旧注册（避免双重触发）。跨机语义变为 **clone 即生效**，前置条件仅"机器装有 node"。机制依据（官方 diagnosing-hooks 文档）：工作区 `<repo>/.zcode/config.json` 支持 hooks 注册（需 `hooks.enabled: true`），`${ZCODE_PROJECT_DIR}` 在 command/args 中展开并注入环境变量，**非插件配置 hooks（含工作区）无信任门、enabled 即跑**。验证：脚本自仓库位置用 PATH node 冒烟测试三场景全过（ask 输出 / 超时特征注入冻结文案 / 无特征空输出），两处 config JSON 合法；**工作区 hooks 的实弹触发与变量展开待实弹验证**（本会话末尾或新会话确认）

5. **防线 hooks 插件化（2026-09-20，用户在线拍板「转插件化」，取代第 4 条方案 A）**：
   - **方案 A 否决证据**：工作区 hooks 注册在本平台（0.16.9）从未被 runner 执行——用户已点信任且持久化于 `~/.zcode/security/workspace-hook-trust-v1.json`（两条记录 decision:trusted），二次重启后启动日志仍报 `config.project_hooks.pending_trust`，实弹提问仍被 yolo 自动裁决（decision:"modify"）、零 hook 执行记录；当日 16 次启动 hookCount:0，用户级注册存活期的两次提问（08:58/09:09）亦无任何 hook 迹象——**用户级与工作区配置文件 hooks 均为装饰性**。推论：feitu 时代至今防线 hooks 在 ZCode 上一直未真正生效，实际防线是根 AGENTS.md 的「用户未答复=冻结」纪律（feitu 旧记忆"工作区 hooks 信任门且信任不持久化"方向正确，实况更糟）
   - **方案 A 实施物清理**：`.zcode/hooks/` 目录已删；工作区 `.zcode/config.json` 回退为仅 mcp 配置（与已提交版本一致）；用户级 `~/.zcode/cli/config.json` 保持 `{}`（原用户级注册内容已存档于 `.zcode/memory/logs/2026-09-20.md`）
   - **插件结构**：源码在仓库 `plugins/gonghui-defense/`——`.zcode-plugin/plugin.json`（name=gonghui-defense、version=0.3.0、hooks 指向 `./hooks/hooks.json`）；`hooks/hooks.json` 为插件格式（外层 `hooks` 包装），两个 hook 仍 matcher `^AskUserQuestion$`、type process、`command: "node"`（走 PATH，免疫各机 node 安装路径差异）、`args: ["${CLAUDE_PLUGIN_ROOT}/hooks/<脚本名>"]`（插件根变量，免疫各机克隆路径差异；ZCode 3.14.0 源码证实 process 型 command 与每个 args 元素均展开该变量）；`hooks/ask_gate.cjs` 与 `ask_timeout_gate.cjs` 与原脚本逐字节一致。本地市场 `plugins/marketplace.json`（name=dev-gonghui，条目 gonghui-defense，source `./gonghui-defense`，含中文 displayName「工会防线 Hooks」与 description）。⚠️ **hook 必须保持 process 型，勿改 command 型 `shell:"bash"`**：spawn 靠 PATH 裸名解析 bash，而 Windows Git 安装器默认只把 `<Git>\cmd` 加入系统 PATH（该目录无 bash.exe），ZCode 桌面进程 PATH 无 bash → spawn ENOENT 30ms 级秒败——与 ZCode 版本、Git 安装位置无关（0.16.9/3.14.0 同症），godot-prompter 插件同败同理；历批「冒烟全过」系盲区（终端会话 PATH 含 `usr\bin` 可解析 bash，与桌面进程不同）。中间版本 0.2.0 曾改 command+bash 范式即死于此，0.3.0 回归 process 型
   - **分发语义**：每台电脑 clone 后手动两步——插件市场添加本地目录 `<仓库>/plugins`，安装「工会防线 Hooks」。插件 hooks 按官方文档自动启用（无信任门、无需 enabled 标志，任何插件贡献 hook 即启用 runner）；前置条件仍是机器装有 node。**0.3.0 已实弹终局闭环**（本机双 hook 零失败，2026-09-20）。两个运维坑（实测）：① 本地 directory 市场在「添加」时把 `plugins/` 复制为快照、市场读快照非源目录——改源文件后刷新无效，须**移除市场重新添加**强制重建快照才能识别新版本；② 插件更新后必须**完整重启 ZCode**——热注册钩表会残留旧版 hook 配置，致「装了新版却按旧版失败」的假象

---

### 转换来源备注

由 `feitu` 项目 `.opencode/docs/AGENTS_CONFIG.md`（通用模板）+ `.opencode/agents/` 六角色文件（含 feitu 沉淀的事故红线：2026-08-21「未经允许全自动推进」事故后的 冻结/来源标注/代定不可信 协议）转换而来。feitu 专属内容（分层铁律、doc/ea 范围、check_all.ps1、里程碑提交格式等）已抽为【按项目回填】槽位。
