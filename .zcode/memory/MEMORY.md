# MEMORY.md — gonghui 项目跨会话工作记忆

> 每次会话开始由 Team Lead 先读本文件（根 `AGENTS.md`「会话启动检查」）。注意：ZCode 只自动加载根 AGENTS.md，本文件需主动读取。
> 完成阶段性工作后在「近期关键记录」追加（新条目放最上面）；只保留关键事实与决策，过时条目及时清理。
> 团队工作流：Team Lead 规则见根 `AGENTS.md`；角色定义见 `.zcode/agents/`；团队规程与机制对照见 `.zcode/docs/AGENTS_CONFIG.md`；与项目规范冲突时以根 AGENTS.md 为准。

## 环境

- 仓库：https://github.com/ligoudan95/gonghui.git（origin，main 分支）
- 平台：Windows；ZCode 命令行环境 Git Bash（路径含空格须引号）
- 项目：冒险者工会（游戏）——当前处于**策划/规划阶段，尚无代码**
- 防线 hooks（用户级 `~/.zcode/cli/config.json` 注册，脚本实体在 `C:\Users\A\.zcode\hooks\`——2026-09-20 自 feitu 迁入，勿删、勿移回工作区）：AskUserQuestion 前后拦截超时特征，支撑「用户未答复=冻结」红线

## 项目速查【随推进回填】

- 总体规划：`新的规划/总体规划.md`
- 文档体系：`新的规划/`（PROJECT_OVERVIEW / SYSTEM_FRAMEWORK / SCRIPT_FRAMEWORK / CODE_STANDARDS 四文档体系尚未建立；建立后由 @docs-updater 登记，并同步 `.zcode/agents/docs-updater.md` 文档映射表与 `architect.md` 阅读优先级）
- 编码规范：未建立（建立后在根 AGENTS.md「项目速查」登记，覆盖 programmer.md 通用模板）
- 程序员自查命令：未建立
- godot-ai MCP：已配置于 `.zcode/config.json`（uvx godot-ai==3.2.4 attach 8000/9500，编辑器桥接）——待建 Godot 工程并安装 `addons/godot_ai` 插件（可从 feitu `addons/godot_ai` 复制）后启用

## 近期关键记录

- 2026-09-20（第二批）：吸收 feitu `.zcode/` 实战配置三项——①五角色文件升级为自定义子代理类型（frontmatter `readOnly`/`tools` 硬性限权，主代理 `subagent_type: <角色名>` 直接派工，未加载则回退 general-purpose+注入全文；新增红线：子代理内 AskUserQuestion 无效须 Team Lead 转达、拍板管线禁跑 yolo 模式）；②`.zcode/config.json` 配置 godot-ai MCP（待装插件启用）；③防线 hooks 实体迁至 `C:\Users\A\.zcode\hooks\` 并更新用户级 config 路径（两脚本功能测试通过；feitu 目录内原副本转为闲置备份）。
- 2026-09-20（第三批·重启验证）：`.zcode/agents` 自定义子代理类型**已随会话启动加载并生效**（planner / architect 实弹派工成功）。工具限权实测结论：**`tools:` 白名单硬性生效**（architect 工具集中无 Write，写入被工具层拦截）；**`readOnly: true` 单独不生效**（planner 当时无 tools 字段，Write 成功执行了——已修正：planner 补 `tools: Read, Glob, Grep`，下次会话生效）。AGENTS_CONFIG.md 机制对照表已登记该实测结论；派工回退方案（not found 时 general-purpose+注入全文）保留作保险。

- 2026-09-20：建立 ZCode 版 6 角色多 Agent 团队工作流（由 feitu 项目 opencode 版转换）——根 `AGENTS.md`（Team Lead 规则）+ `.zcode/agents/` 五子角色 + `.zcode/memory/` 记忆系统；保留 feitu 沉淀的事故红线（用户未答复=冻结 / 转达必标来源 / 代定不可信）。ZCode 机制映射：Agent 工具派工（注入角色提示词全文）、SendMessage 按 agentId 复用同角色会话、审核闸门=呈现产物后结束回合等用户。
