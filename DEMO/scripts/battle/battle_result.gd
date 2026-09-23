## 战斗结果（BattleResult，RefCounted 纯逻辑类）
## 职责：承载一场战斗的终局产出——胜负口径（胜利/战败/撤退）、使用回合数、
## 各单位终局资源快照与倒地名单；供委托结算（战利品/损耗）与 UI 结算屏消费。
## 数据来源：案 9《战棋战斗》（撤退 = 委托失败口径占位——完整撤退机制批 3+）。
class_name BattleResult
extends RefCounted

## 终局口径（VICTORY = 敌方全灭；DEFEAT = 我方全灭（同时全灭按战败）；
## RETREAT = 主动撤退（委托失败口径占位））
enum ResultKind {
	VICTORY,
	DEFEAT,
	RETREAT,
}

## 终局口径
var kind: ResultKind = ResultKind.VICTORY
## 使用回合数（RETREAT = 撤退时回合号）
var rounds_used: int = 0
## 各单位终局快照：{unit_id, end_hp, end_mana, end_stamina, downed: bool}
var end_stats: Array[Dictionary] = []
## 倒地单位 id 名单（时序记录）
var downed_units: Array[StringName] = []

func kind_text() -> String:
	## 终局口径文本（日志/断言可读化）
	## 参数：无
	## 返回：口径名
	match kind:
		ResultKind.VICTORY:
			return "VICTORY"
		ResultKind.DEFEAT:
			return "DEFEAT"
		_:
			return "RETREAT"
