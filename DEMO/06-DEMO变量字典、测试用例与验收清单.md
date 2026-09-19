# DEMO-06 变量字典、测试用例与验收清单

> 文档版本：D1.1
> 状态：变量与验收框架冻结；测试尚未执行
> 关联：[`00-DEMO总览、范围与文档索引.md`](./00-DEMO总览、范围与文档索引.md) 至 [`05-DEMO冒险者状态、失败恢复与难度案.md`](./05-DEMO冒险者状态、失败恢复与难度案.md)、正式版 [`zhengshi/09-反漏洞测试、验收标准与制作里程碑策划案.md`](../zhengshi/09-反漏洞测试、验收标准与制作里程碑策划案.md)

---

## 1. 使用说明

本文件是 DEMO 的单一变量、状态依赖和验收入口。它不声称任何功能已经实现或测试通过；“预期”表示交付门槛。

- 变量名稳定后，内容脚本、UI、存档和测试都引用变量名，不引用中文显示名。
- 变量分为持久化、远征快照、临时战斗、配置和日志五类。
- 任何新增变量必须说明写入者、读取者、保存级别、重置时机和幂等键。
- DEMO 数值以 `02`、状态以 `05`、节点和结果以 `04`、支援以 `03` 为唯一来源；本文只索引它们。

---

## 2. 状态枚举

### 2.1 全局阶段

```text
DEMO_OPENING
PREPARING
PREP_LOCKED
EXPEDITION_NODE
EXPEDITION_COMBAT
RESULT_PENDING
SETTLED
ECHO
CYCLE_CLOSED
DEMO_EPILOGUE
```

### 2.2 任务结果

```text
FULL_SUCCESS
COST_SUCCESS
PARTIAL_SUCCESS
WITHDRAWAL
FAILURE_CONTINUES
```

### 2.3 支援状态

```text
LOCKED
AVAILABLE
RESERVED
USED
COOLDOWN
```

### 2.4 节点正交字段

```text
information_state: rumor / identified / mastered
 event_progress: unstarted / active / resolved / abandoned / failed_forward
 entry_open: bool
 exit_open: bool
 route_flags: set
 reward_claim_state: unclaimed / reserved / claimed / retired
```

### 2.5 冒险者状态

```text
injury_level: 0 / 1 / 2
fatigue: 0..100
pressure: 0..100
morale: 0..100
party_mood: derived text
```

---

## 3. 全量变量字典

### 3.1 运行、周期、存档变量

| 变量 | 类型/初值 | 写入者 | 读取者 | 保存级别 | 重置规则 |
|---|---|---|---|---|---|
| `demo_run_id` | string/新运行生成 | 运行初始化 | 所有 claim、日志 | 持久化 | 新建 DEMO 才变 |
| `demo_version` | string/D1.0 | 构建配置 | 加载/迁移 | 持久化 | 版本迁移更新 |
| `cycle_id` | int/1 | 周期服务 | 所有周期操作 | 持久化 | CYCLE_CLOSED 后 +1 |
| `world_cycle` | int/1 | 周期关闭 | 任务期限/日志 | 持久化 | 关闭事务 +1 一次 |
| `settlement_epoch` | int/0 | 结算提交 | 存档/读档 | 持久化 | 每次成功结算 +1 |
| `global_phase` | enum/DEMO_OPENING | 状态机 | UI/存档/内容 | 持久化 | 合法状态转换 |
| `current_quest_instance_id` | string/null | 任务服务 | 地图/结果 | 持久化/快照 | 任务关闭后 null |
| `current_expedition_id` | string/null | 出发事务 | 远征/战棋 | 持久化/快照 | 周期结算清理 |
| `current_result_id` | string/null | 结果服务 | 结算/存档 | 持久化 | 提交后标记历史 |
| `last_commit_id` | string/null | 事务服务 | 幂等检查 | 持久化 | 只追加更新 |
| `local_tick` | int/0 | 远征服务 | 地图/风险/UI | 远征快照 | 新远征归零 |
| `demo_expedition_seed` | string/出发生成 | 随机服务 | 节点/战棋/重试 | 远征快照 | 新远征生成 |
| `random_stream_cursors` | map/0 | 随机服务 | 战斗/节点 | 快照 | 重试回 COMBAT_START |
| `difficulty_id` | enum/standard | 设置/准备 | 战斗/结算 | 持久化+锁定快照 | 下周期可改 |
| `difficulty_locked` | bool/false | 出发锁定 | UI/状态机 | 远征快照 | 周期结束清除 |
| `prep_actions_remaining` | int/2 | 准备服务 | UI/任务 | 持久化 | 周期关闭重置 2 |
| `current_node_id` | string/null | 地图服务 | UI/路线/存档 | 远征快照 | 新远征归零，回城清理 |
| `cycle_close_commit_id` | string/null | 周期关闭事务 | 幂等检查/存档 | 持久化 | 每次关闭更新，同 ID 不重复执行 |

### 3.2 资源和奖励变量

| 变量 | 类型/初值 | 写入者 | 读取者 | 保存级别 | 重置规则 |
|---|---|---|---|---|---|
| `funds_committed` | int/100 | 经济事务 | UI/任务/支援 | 持久化 | 结算/维护改变 |
| `funds_reserved` | int/0 | 预留服务 | UI/出发 | 持久化 | 取消或提交释放 |
| `debt` | int/0 | 维护/恢复 | UI/恢复 | 持久化 | 新事件偿还，不自动清零 |
| `supply_committed` | int/5 | 经济事务 | 地图/战棋 | 持久化 | 结算按消耗改变 |
| `supply_reserved` | int/0 | 出发/物品 | UI/携带 | 远征快照 | 取消出发释放 |
| `supply_capacity` | int/8 | 配置 | 采购/携带 | 配置 | DEMO 固定 |
| `facts_seen` | set/空 | 节点/委托/支援 | 地图/日志 | 持久化 | 不因撤退/读 UI 清除 |
| `reputation` | int/0 | 结果/政策 | UI/任务 | 持久化 | 结果改变，不当货币消费 |
| `contact_slots_total` | int/1 | 配置 | 支援 | 持久化 | DEMO 固定 |
| `contact_slots_reserved` | int/0 | 支援服务 | UI/出发 | 持久化 | 取消/回城释放 |
| `reward_claim_keys` | set/空 | 结算事务 | 奖励/回访 | 持久化 | 同 key 永不清除，废弃标记 retired |
| `consumed_echo_ids` | set/空 | 回响服务 | UI/回响 | 持久化 | 同 ID 不重播 |

### 3.3 任务、地图和支援变量

| 变量 | 类型/初值 | 写入者 | 读取者 | 保存级别 | 重置规则 |
|---|---|---|---|---|---|
| `quest_state` | enum/VISIBLE | 任务服务 | UI/结果 | 持久化 | 结果提交关闭 |
| `quest_instance_id` | string | 任务刷新 | 结果/claim | 持久化 | 新实例生成 |
| `quest_deadline` | cycle/null | 任务配置 | 周期关闭 | 持久化 | 结果/转化后更新 |
| `node_states` | map | 地图服务 | UI/快通 | 持久化+远征快照 | 新运行清空 |
| `node_visit_ids` | set/list | 地图服务 | 日志/测试 | 持久化 | 不参与奖励唯一性 |
| `event_version` | string | 内容配置 | 节点/claim | 持久化 | 迁移只增新版本 |
| `route_flags` | set | 地图/支援 | 路线计算 | 持久化+远征快照 | 世界/支援按规则失效 |
| `evidence_carried` | bool | 携带/结果 | 结算 | 远征快照 | 新远征归零 |
| `npc_support_states` | map | 支援服务 | 准备/地图/战棋 | 持久化+快照 | 使用后次数/冷却更新 |
| `support_reservation_id` | string/null | 支援预留 | UI/出发 | 持久化 | 取消/回城释放 |
| `support_usage_id` | string/null | 支援调用 | 结算/日志 | 持久化 | 每次合法调用唯一 |
| `high_impact_used` | bool/false | 支援服务 | 远征 | 远征快照 | 新远征归零 |

注：`npc_support_states` 的值结构包含 `unlock_stage`、`uses_remaining`、`cooldown_until`、各费用字段和 `high_impact`（模板见 DEMO-03 §3），不作为独立变量逐条登记；`combat_snapshot` 不是独立变量，对应 `AUTO_COMBAT_START` 存档（见 DEMO-01 §5）。

### 3.4 冒险者变量

| 变量 | 类型/初值 | 写入者 | 读取者 | 保存级别 | 重置规则 |
|---|---|---|---|---|---|
| `selected_party_ids` | list/空 | 组队 | 出发/战棋 | 远征快照 | 新周期清空 |
| `deployed_this_cycle` | bool/false | 出发 | 恢复服务 | 持久化 | 周期关闭清空 |
| `injury_level[adv_id]` | 0..2/0 | 结果/恢复 | 组队/战棋 | 持久化+快照 | 恢复按周期 |
| `fatigue[adv_id]` | 0..100/按D05 | 远征/恢复 | 组队/战棋 | 持久化+快照 | 按D05规则 |
| `pressure[adv_id]` | 0..100/按D05 | 事件/回响 | UI/协作 | 持久化+快照 | 周期/事件下降 |
| `morale[adv_id]` | 0..100/60 | 结果/回响 | UI/协作 | 持久化+快照 | 向60恢复/事件改变 |
| `pair_tags` | 有限集合/空 | 回响 | UI/协作 | 持久化 | 周期后消退/覆盖 |
| `party_mood` | 派生文字 | UI服务 | UI/结算 | 不独立保存或缓存 | 由状态重算 |

### 3.5 结果待结算对象（DemoResult）

对应 DEMO-01 §4.1 的结果对象，随 `AUTO_RESULT_PENDING` 保存；接受提交或重试丢弃后清理，不进入长期持久层。

| 字段 | 类型 | 说明 |
|---|---|---|
| `result_id` / `expedition_id` | string | 结果与远征标识，`result_id` 幂等 |
| `result_type` | enum（§2.2 五值） | 结果等级 |
| `objective_flags` | set | 救援/取证/追敌等目标完成位 |
| `evidence_carried` | bool | 物证是否合法带出 |
| `retry_allowed` | bool | 是否允许免费重试 |
| `cause_factors[]` | list | 结果原因，用于结算解释 |
| `pending_resource_delta` / `pending_party_delta` / `pending_map_delta` / `pending_npc_delta` | delta | 接受时按 DEMO-01 §4.3 事务一次性提交 |

---

## 4. 依赖和不变量矩阵

| 不变量 | 相关变量 | 违反时的处理 |
|---|---|---|
| 结果只提交一次 | `current_result_id`、`last_commit_id`、`settlement_epoch` | 阻断重复事务，恢复完整快照 |
| 奖励只领取一次 | `reward_claim_keys` | 返回已领取，不增量 |
| 世界周期只关闭+1 | `cycle_id`、`world_cycle`、`cycle_close_commit_id` | 幂等关闭，禁止二次维护 |
| 战棋重试只回战斗开始 | `combat_snapshot`、`random_stream_cursors` | 丢弃未接受结果，保留战前地图代价 |
| 资金不负数 | `funds_committed`、`debt` | 先扣可用资金，余额写债务 |
| facts 不消耗 | `facts_seen` | 禁止扣除；重复事实去重 |
| 联络位不等于 NPC 次数 | `contact_slots_reserved`、`uses_remaining` | 分别校验，不能互相补偿 |
| 3人出战 | `selected_party_ids`、`injury_level`、`fatigue` | 不足3人转恢复，不允许主角补位 |
| 主线不被状态硬锁 | 任务/节点/队伍字段 | 必须存在基础路线或恢复路径 |
| 难度锁定 | `difficulty_id`、`difficulty_locked` | PREP_LOCKED 后拒绝改动 |
| 节点奖励不重置 | `event_version`、`reward_claim_keys` | 新版本只新 reward ID |

---

## 5. 反漏洞测试用例

以下用例均为验收定义，尚未执行；每条执行时必须保存前置存档、操作日志、资源差异和结果截图/文本。

### 5.1 存档、结算与重试

| ID | 场景 | 预期 |
|---|---|---|
| TC-D06-01 | 结果接受按钮连点 10 次 | 只提交一次 `result_id` |
| TC-D06-02 | 结算事务中强退 | 重载不重复奖励/扣费 |
| TC-D06-03 | 战棋中强退 | 回 COMBAT_START 完整快照 |
| TC-D06-04 | 免费重试后改战术 | 只有最终接受结果写入永久账本 |
| TC-D06-05 | 重试后读取旧手动档 | 整包替换，不 merge 两条时间线 |
| TC-D06-06 | 结算后打开待结算档 | 显示已结算，不重复领取 |
| TC-D06-07 | 读取损坏自动档 | 回退最近完整档并提示 |
| TC-D06-08 | 同周期重复关闭 | 维护和 world_cycle 只执行一次 |

### 5.2 经济和时间

| ID | 场景 | 预期 |
|---|---|---|
| TC-D06-09 | 查看任务板/日志 20 次 | 任务、资源、动作、周期不变 |
| TC-D06-10 | 同周期重复完成准备委托 | 第二次不可领取旧 reward |
| TC-D06-11 | 连续 5 次低风险委托 | 必须每次关闭周期并承担维护/机会成本 |
| TC-D06-12 | 资金归零、补给归零、全员重伤 | 桌面恢复可用，不 game over |
| TC-D06-13 | 主动破产后使用恢复服务 | 不产生净正可支配资产 |
| TC-D06-14 | 补给已达 8 再采购 | 拒绝或显式丢弃，不静默增加 |
| TC-D06-15 | local_tick 增加 10 | world_cycle 不变 |
| TC-D06-16 | 任务期限边界完成主线 | 先结算完成，再处理其他期限 |

### 5.3 支援和地图

| ID | 场景 | 预期 |
|---|---|---|
| TC-D06-17 | NPC 预留后取消 | 费用/次数/冷却/联络位释放 |
| TC-D06-18 | 一次远征申请两项高影响支援 | 第二项拒绝，不重复扣费 |
| TC-D06-19 | 支援校验失败 | 无账本字段变化 |
| TC-D06-20 | 同一节点访问五次 | 旧 reward 只领取一次，visit 可多次 |
| TC-D06-21 | 撤退后回访 | facts 保留，物证按携带判定 |
| TC-D06-22 | 节点版本 v1→v2 | 旧 reward 不重发，新 reward 独立 |
| TC-D06-23 | 无 NPC无推荐职业 | 基础路线到主战棋和结果 |
| TC-D06-24 | 快通遇到新节点 | 暂停交还选择权，保留成本摘要 |

### 5.4 队伍、难度和公平性

| ID | 场景 | 预期 |
|---|---|---|
| TC-D06-25 | 疲劳 79/80 边界 | 79可确认，80不可新出战 |
| TC-D06-26 | 出战者本周期回城 | 不享当周期留守恢复 |
| TC-D06-27 | 轻伤/重伤连续留守 | 轻伤一周期，重伤两阶段恢复 |
| TC-D06-28 | 士气 0 执行护送/撤退 | 操作可执行，软修正不超上限 |
| TC-D06-29 | PREP_LOCKED 后切难度 | 被拒；奖励不重算 |
| TC-D06-30 | 三档难度完成同一目标 | 基础报酬相同，后果按档位 |
| TC-D06-31 | 查看日志/跳过动画 | 不消耗随机流 |
| TC-D06-32 | 关键线索来源 A 禁用 | 来源 B 仍能完成基础路线 |

共 32 条 DEMO 反漏洞/路径测试，覆盖：重复领奖、节点刷取、无限准备、支援叠加、主动破产、政策/难度切换、全员受伤、重试、崩溃、三种以上结果和可读性边界。

---

## 6. 主路径验收

### 6.1 完全成功

准备阶段使用测绘/访谈之一或不使用，进入至少两个调查节点；主战棋完成救援和取证；回城显示完全成功、资源奖励、队伍状态、NPC 反馈和下一钩子；周期能关闭。

### 6.2 代价成功/部分成功

玩家选择救援优先，物证丢失或一人重伤；结果在 2 分钟内可读，旧证据 claim 不发，补救任务出现；周期能关闭。

### 6.3 撤退/失败继续

玩家从撤退点离开或战棋失败；facts 和已付成本保留，物证未带回，债务/压力/声望后果可见；桌面恢复或补救路径可继续，不能停在失败画面。

### 6.4 无支援路径

不推进任何 NPC 支线、不调用任何支援，仍能：

- 得到失踪目标的固定事实。
- 进入主战棋。
- 完成救援、取证、部分成功或撤退中至少一种结果。

---

## 7. M0–M4 DEMO 验收门槛

### M0：范围和变量

- [ ] DEMO-00 范围冻结。
- [ ] 本文件变量字典与实现字段对齐。
- [ ] 所有 P0 风险有对应测试 ID。
- [ ] 不再新增系统而不砍项。

### M1：灰盒闭环

- [ ] 开场→准备→节点→主战棋→结果→回城可走通。
- [ ] 结果至少三种可达。
- [ ] 战棋重试、接受失败和回城恢复可走通。
- [ ] TC-D06-01 至 08 的状态/存档核心用例执行完成。

### M2：内容接入

- [ ] 8 节点和三名 NPC 接入。
- [ ] 四名冒险者状态对远征产生可见但低影响差异。
- [ ] 无支援基础路线完成。
- [ ] 节点回访、一次性奖励和补救任务接入。

### M3：体验打磨

- [ ] 首次玩家中位 60–70 分钟，最长不超过 75 分钟。
- [ ] 玩家能说明至少一项支援的作用和代价。
- [ ] 玩家能解释自己为什么得到当前结果。
- [ ] 失败/撤退两分钟内进入可读结算。

### M4：稳定和交付

- [ ] TC-D06-01 至 32 全部执行并记录。
- [ ] P0 无开放缺陷，P1 有关闭或明确不阻断说明。
- [ ] 连续 5 次成功/失败/撤退路径无阻断、无重复奖励、无软锁。
- [ ] 发布构建不包含调试重置、变量修改和隐藏跳转入口。
- [ ] 有已知问题和版本说明。

---

## 8. 玩家观察指标

| 玩家 | 记录项 | 合格方向 |
|---|---|---|
| 首次玩家 | 第一次做出资源取舍的时间 | 前 10 分钟内 |
| 首次玩家 | 首次看到 NPC 独特能力 | 前 20 分钟内 |
| 首次玩家 | 能否解释结果原因 | 结算后 2 分钟内 |
| 熟练玩家 | 核心闭环时长 | 40–55 分钟（下限 35） |
| 失败玩家 | 是否接受结果继续 | 不以读档为唯一选择 |
| 所有玩家 | 是否误以为普通冒险者有好感度 | 不应出现普遍误解 |
| 所有玩家 | 是否尝试刷任务/节点/支援 | 发现后系统应阻止且提示 |

测试人员应同时记录“玩家实际查看了哪些信息”，不能只问玩家是否喜欢；这用于判断规则是否可读。

---

## 9. 交付前变量和文件检查

- [ ] DEMO-01、02、03、04、05 中引用的变量均在本文有条目。
- [ ] 所有 `reward_id` 都能组成稳定 `reward_claim_keys`。
- [ ] 所有支援都有 reservation、usage、cooldown 和费用字段。
- [ ] 所有节点都有 information、event、traversal、reward 四组字段。
- [ ] 所有状态变化都有 source_id、cycle_id、transaction_id。
- [ ] 所有失败/撤退结果都有回城和下一步出口。
- [ ] 所有测试写“预期”而非“已通过”。
- [ ] 文档未把历史 DEMO 原文的估算数字误当成冻结数值。
