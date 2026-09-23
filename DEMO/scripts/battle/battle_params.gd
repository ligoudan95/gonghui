## 战斗开局参数包（BattleParams，RefCounted 纯逻辑类）
## 职责：承载一场战斗的开局六维度输入——遭遇队伍 id、我方出战名单、
## 先攻口径、敌方出生位覆盖、开局载入状态、地形/队形覆盖（M2 检定带入
## 与场景联调的挂点）；供 BattleSetup.build 消费。
## 数据来源：案 9《战棋战斗》；案 11 §2.3（开局载入锚点——载入状态视为
## 回合 1 前施加）；案 18《事件文案专项案》（检定带入状态——M2 联调）。
## 纯逻辑约束：不触任何 autoload；rng 为测试/M2 注入口（缺省现场随机）。
class_name BattleParams
extends RefCounted

## 先攻口径（NORMAL = 常规速度排序；ALLY_FIRST/ENEMY_FIRST = 检定带入的
## 先攻优势口径——M2 事件联调挂点，M1 仅承载字段）
enum FirstStrike {
	NORMAL,
	ALLY_FIRST,
	ENEMY_FIRST,
}

## 遭遇队伍 id（battle/enemy_packs 域）
var pack_id: StringName = &""
## 我方出战名单（槽位序 = 数组序）
var party: Array[AdventurerData] = []
## 先攻口径（M1 默认 NORMAL）
var first_strike: FirstStrike = FirstStrike.NORMAL
## 敌方出生位覆盖（enemy_spawns 下标序列；空 = 默认分配——精英首位 + 其余洗位）
var enemy_spawn_override: Array[int] = []
## 开局载入状态：{status_id: StringName, target: StringName 单位 id, duration: int}
## （施加走 CHECKIN 来源 + first_tick_round=1 开局载入锚点）
var initial_statuses: Array[Dictionary] = []
## 地形覆盖（pos -> tile id；M2 场景联调挂点，M1 默认空不消费）
var terrain_override: Dictionary = {}
## 我方队形覆盖（按队伍序的出生格；M1 默认空 = player_spawns 顺排）
var formation: Array[Vector2i] = []
## 随机源注入口（测试确定性 / M2 复现场景；null = 现场随机种子）
var rng: RandomNumberGenerator = null
