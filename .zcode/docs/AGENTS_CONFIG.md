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
| 用户审核闸门 | 主代理呈现产物后**结束回合等用户**；拍板项用 AskUserQuestion；「用户未答复=冻结」红线（用户级 hooks `ask_gate`/`ask_timeout_gate` 加固，注册于 `~/.zcode/cli/config.json`，勿删） |
| `.opencode/memory/`（MEMORY.md + logs/，opencode.json instructions 自动加载） | `.zcode/memory/`。ZCode **不会自动加载**它 → 根 AGENTS.md「会话启动检查」指示主代理会话开始先读 |
| `permission: edit/bash: deny`（配置层硬禁） | frontmatter `tools:` 白名单**硬性限制**（等价 opencode permission；2026-09-20 实测：`tools:` 生效，`readOnly` 单独**不**生效——每个角色都必须写 tools 列表）；角色文内「行为权限」节作补充约束（如 planner 不读源码——工具层拦不住，靠规则） |

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
└── .zcode/
    ├── config.json                # 项目级 MCP 配置（godot-ai 编辑器桥接，待装插件启用）
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
3. **防线 hooks 实体迁移**：`ask_gate.cjs` / `ask_timeout_gate.cjs` 自 feitu 项目复制到用户级 `C:\Users\A\.zcode\hooks\`，用户级 config 路径已更新——消除对 feitu 目录的跨项目依赖（注册保持用户级；工作区 hooks 有信任门且信任不持久化，勿移回工作区；feitu 目录内原副本转为闲置备份）

---

### 转换来源备注

由 `feitu` 项目 `.opencode/docs/AGENTS_CONFIG.md`（通用模板）+ `.opencode/agents/` 六角色文件（含 feitu 沉淀的事故红线：2026-08-21「未经允许全自动推进」事故后的 冻结/来源标注/代定不可信 协议）转换而来。feitu 专属内容（分层铁律、doc/ea 范围、check_all.ps1、里程碑提交格式等）已抽为【按项目回填】槽位。
