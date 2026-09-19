# DEMO-01 流程状态与存档结算案

> 文档版本：D1.1
> 状态：状态与结算冻结；存档实现待开发
> 关联：[`00-DEMO总览、范围与文档索引.md`](./00-DEMO总览、范围与文档索引.md)、正式版 [`zhengshi/01-核心状态机与结算提交策划案.md`](../zhengshi/01-核心状态机与结算提交策划案.md)、[`zhengshi/02-存档、重试与数据一致性策划案.md`](../zhengshi/02-存档、重试与数据一致性策划案.md)

---

## 1. DEMO 状态链

```text
DEMO_OPENING
  -> PREPARING
  -> PREP_LOCKED
  -> EXPEDITION/NODE
  -> EXPEDITION/COMBAT
  -> RESULT_PENDING
  -> SETTLED
  -> ECHO
  -> CYCLE_CLOSED
  -> DEMO_EPILOGUE
```

允许的替代出口：

- `EXPEDITION/NODE -> RESULT_PENDING`：玩家在节点选择撤退或调查直接产生部分结果。
- `EXPEDITION/COMBAT -> RESULT_PENDING`：完全成功、代价成功、部分成功、撤退或失败继续。
- `PREPARING -> CYCLE_CLOSED`：玩家选择休整/最低恢复，不出发也能继续，但 DEMO 结尾钩子不能因此提前完成。
- `CYCLE_CLOSED -> PREPARING`：同一 `demo_run_id` 内继续下一周期（`cycle_id +1`），用于失败补救、伤病恢复和后续推进；准备动作恢复 2、准备委托按 DEMO-02 §7 刷新。
- `CYCLE_CLOSED -> DEMO_EPILOGUE`：主线到达终态（结果已接受并生成章节钩子）或玩家主动结束本次 DEMO。

同一运行最多 3 个周期；第 3 个周期关闭时必须进入 `DEMO_EPILOGUE`，不得开出第 4 个周期。该上限防止无限刷周期，DEMO 不验证长期经济曲线。

### 1.1 状态表

| 状态 | 玩家可做 | 禁止 | 存档/时间 |
|---|---|---|---|
| `DEMO_OPENING` | 阅读摘要、确认教程 | 跳过初始变量写入 | 写一次开场档；不推进 world cycle |
| `PREPARING` | 查看、执行 2 次准备动作、接任务、推进 NPC、组队 | 重复刷委托/奖励 | `cycle_id=当前周期（首周期为 1）`；阅读不耗时 |
| `PREP_LOCKED` | 查看确认摘要、取消并回准备（未出发） | 改已锁定队伍/难度/支援 | 写 `AUTO_LOCK`；不增加 world cycle |
| `EXPEDITION/NODE` | 移动、调查、营地、节点支援、撤退 | 回工会重配、换 NPC | 增加 local_tick；关键节点可自动存档 |
| `EXPEDITION/COMBAT` | 战棋行动、合法支援、撤退 | 手动存档、改难度、换队 | 建立 COMBAT_START；不增加 world cycle |
| `RESULT_PENDING` | 查看结果、重试或接受结果 | 接受一部分后再重试 | 写待结算档；不增加 world cycle |
| `SETTLED` | 查看资源/队伍/地图/NPC 变化 | 重复领奖、改胜负 | `settlement_epoch +1`；写结算档 |
| `ECHO` | 处理最多 3 段短回响、选择下一钩子 | 重复回响奖励 | 不额外推进周期 |
| `CYCLE_CLOSED` | 维护、恢复、继续下一周期或结束 DEMO | 再次维护同一周期、第 3 个周期后继续开出新周期 | `world_cycle +1`、`cycle_id +1` 各恰好一次 |
| `DEMO_EPILOGUE` | 查看本次路径摘要、重开新运行 | 修改已结算结果 | 只读终局档 |

---

## 2. 最小变量

```text
DemoState
  demo_run_id
  demo_version
  cycle_id
  world_cycle
  settlement_epoch
  global_phase
  current_quest_instance_id
  current_expedition_id
  current_result_id
  current_node_id
  local_tick
  demo_expedition_seed
  difficulty_locked
  selected_party_ids[3]
  support_reservation_id
  resources
  facts_seen[]
  reward_claim_keys[]
  node_states{}
  adventurer_states{}
  npc_support_states{}
  consumed_echo_ids[]
  last_commit_id
```

所有变量的写入者、保存级别和重置规则在 [`06-DEMO变量字典、测试用例与验收清单.md`](./06-DEMO变量字典、测试用例与验收清单.md) 统一定义。本文件只规定状态机语义。

---

## 3. 筹备与出发锁定

### 3.1 筹备

DEMO 开始：资金 100、补给 5、补给/携带上限 8、事实情报为空、声望 0、联络位 1、准备动作 2。具体数值由 DEMO-02 维护。

筹备界面必须同时显示：

- 主线目标和已知信息。
- 4 名可选冒险者、3 个出战槽、伤病/疲劳/压力/士气。
- 当前资金、补给、carry、准备动作、联络位。
- 已选难度、已预留 NPC 支援及其代价。
- 无助力基础路线提示。

查看内容不消耗动作。执行准备委托、购买一组信息、治疗或正式推进 NPC 首阶段通常消耗一个准备动作；具体表见 DEMO-02/03。

### 3.2 出发锁定事务

点击出发时按顺序：

1. 校验主线任务实例仍可用。
2. 校验正好三名普通冒险者且无重伤/疲劳 ≥80。
3. 校验出发成本、携带量和联络位。
4. 生成 `current_expedition_id`、`demo_expedition_seed`。
5. 写入队伍、补给、难度、政策/支援和 facts 快照。
6. 将可退费用标记为 `reserved`，出发后按结果提交。
7. 写 `AUTO_LOCK`。
8. 进入 `EXPEDITION/NODE`。

校验失败不改变资源、任务或 NPC 状态；界面显示一个明确原因并回到准备。

### 3.3 出发后锁定

- 不能换三人队伍、改难度、换联络 NPC 或追加补给。
- 可以在节点合法调用已锁定的支援。
- 可以消耗已携带物品、补给、战棋资源和已锁定支援的资金版调用费用（按 DEMO-03 §3.1 基线提交）。
- 可以选择撤退，撤退会生成结果，不回滚为“从未出发”。

---

## 4. 战棋结果与重试

### 4.1 结果对象

主战棋结束后先生成：

```text
DemoResult
  result_id
  expedition_id
  result_type
  objective_flags
  evidence_carried
  pending_resource_delta
  pending_party_delta
  pending_map_delta
  pending_npc_delta
  retry_allowed
  cause_factors[]
```

结果枚举与 DEMO-06 §2.2 一致，五类中至少三类可达（交付门槛见 DEMO-00 §8）：

- `FULL_SUCCESS`：救出目标并带回关键证据。
- `COST_SUCCESS`：完成主目标，但失去证据、受伤或消耗更多资源。
- `PARTIAL_SUCCESS`：救人或取证其中一项完成，另一项转为后续钩子。
- `WITHDRAWAL`：队伍经合法出口撤离，保留事实与已付成本，放弃未完成目标。
- `FAILURE_CONTINUES`：证人和证据都未保住或战斗失败，保住队伍/部分事实，敌方获得先机，进入补救。

### 4.2 免费战棋重试

重试是无收费容错：

- 仅在 `RESULT_PENDING` 选择；完全成功也可以按产品决定隐藏重试，但失败/不满意结果必须可重试。
- 恢复 `COMBAT_START` 的完整战斗状态、随机流游标、战斗支援配额、敌我位置、目标进度和临时状态。
- 战前已经完成的地图调查、购买情报、已使用地图支援、出发成本不恢复。
- 第一次尝试掉落、经验、伤病、物品和支援调用不写入永久账本。
- 换策略可以产生不同结果；不能通过 UI 开关改变难度或换 NPC。
- 重试不增加 `world_cycle`、`settlement_epoch` 或奖励 claim。

### 4.3 接受结果

接受后：

1. 使用同一 `result_id` 调用结算事务。
2. 依次提交资源、队伍、任务、节点、NPC、世界和 claim key。
3. 任何失败整体回滚并保留待结算对象。
4. 成功后写 `AUTO_SETTLED`，清理战斗重试快照。
5. 进入 `SETTLED` 结算页；2 分钟内展示原因和后果。

同一 `result_id` 重复接受只返回第一次提交结果，不重复发放。

---

## 5. 存档策略

| 存档 | 写入时机 | 是否可读 | 用途 |
|---|---|---:|---|
| `AUTO_OPENING` | 开场变量初始化 | 是 | 重新开始本次 DEMO |
| `AUTO_LOCK` | 出发锁定 | 是 | 恢复远征入口 |
| `AUTO_NODE` | 关键节点进入前 | 是 | 恢复节点选择 |
| `AUTO_COMBAT_START` | 主战棋初始化 | 是 | 合法战棋重试/崩溃恢复 |
| `AUTO_RESULT_PENDING` | 结果生成后 | 是 | 继续选择重试/接受 |
| `AUTO_SETTLED` | 结果事务成功 | 是 | 查看已结算结果 |
| `MANUAL_1` | 准备/节点安全点 | 是 | 一个手动槽完整快照 |

限制：

- 战棋行动中不能手动存档。
- 普通加载整包替换同一 `settlement_epoch` 的状态，不合并资源、claim 或 NPC 变化。
- 读取旧手动档代表放弃该档之后的进度，显示确认提示。
- 已正式结算的旧档可查看为历史，但不能将旧档奖励合入当前档。
- 加载损坏档时回退最近完整自动档，并显示恢复提示。

---

## 6. 回城、回响与关闭周期

回城后结算页按以下组展示：

1. 任务目标：完成、丢失、转化。
2. 资源：资金、补给、事实、声望、支援次数。
3. 队伍：伤病、疲劳、压力、士气、短标签。
4. 地图：已掌握节点、路线、警戒、证据。
5. NPC：支援使用、代价、下一阶段。
6. 下一钩子：补救任务、敌方动向或新支线。

ECHO 最多弹出 3 段短回响，其中队伍短回响优先；深度 NPC 支线由玩家主动点入。回响 ID 消费一次，重载不重复。

周期关闭事务（两个出口：继续下一周期 / 结束 DEMO）：

- 应用未出战成员的 DEMO 恢复规则。
- 结算维护和失败/撤退的周期后果。
- `world_cycle`、`cycle_id` 只各加 1 次。
- 写 `CYCLE_CLOSED` 快照，以 `cycle_close_commit_id` 幂等提交。
- 选择「继续下一周期」：回到 `PREPARING`，准备动作恢复 2、准备委托按 DEMO-02 §7 刷新；运行内第 3 个周期关闭后此选项不可用。
- 选择「结束本次 DEMO」：生成章节钩子并进入 `DEMO_EPILOGUE`。

---

## 7. 故障和非法操作

| 情况 | 行为 |
|---|---|
| 出发校验失败 | 回准备，不改变账本 |
| 战棋强退 | 回 `AUTO_COMBAT_START`，不产生结果 |
| 结果预览强退 | 恢复同一 `result_id`，不自动选择 |
| 结算中强退 | 通过 commit 日志恢复一次提交 |
| 周期关闭中强退 | 恢复关闭前/后的完整快照，不重复维护 |
| 战棋中按手动存档 | 拒绝，显示“战棋行动中不可存档” |
| 已结算结果再次领取 | 显示已提交，不重复处理 |
| 出发后换支援 | 拒绝，不消耗资源 |
| 失败后直接回准备 | 必须先接受失败结算或读取旧档 |

---

## 8. 验收用例

| ID | 预期 |
|---|---|
| TC-D01-01 | 开场到准备的变量只初始化一次 |
| TC-D01-02 | 不能用主角补成第四个战棋单位 |
| TC-D01-03 | 出发后换队/换难度/换 NPC 被拒 |
| TC-D01-04 | 战棋强退恢复 COMBAT_START，不重复扣费 |
| TC-D01-05 | 重试恢复临时战斗状态，战前地图代价不恢复 |
| TC-D01-06 | 重试换战术可改变合法结果 |
| TC-D01-07 | 同一 result_id 连点接受只提交一次 |
| TC-D01-08 | 接受失败后 2 分钟内显示资源/队伍/世界后果 |
| TC-D01-09 | 读取旧手动档不合并新奖励或 NPC 进度 |
| TC-D01-10 | 周期关闭重复触发只推进一次 world_cycle |
| TC-D01-11 | 任何结果都能到达回响和下一钩子 |
| TC-D01-12 | 回响重载不重复触发短对话奖励 |
| TC-D01-13 | 第 3 个周期关闭后只能进入 DEMO_EPILOGUE，不能开出第 4 个周期 |

这些是验收定义，不代表本文编写时已运行通过。
