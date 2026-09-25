## 检定结果（CheckResult，RefCounted 纯数据类）
## 职责：单次 D20 检定的结果快照——骰值/有效骰/调整值/合计/档位与大成功线。
## 数据来源：案 17 §3.3（D20 检定域四档判定）。
## 纯逻辑约束：无状态纯数据；由 CheckRoller 产出、事件引擎/UI 消费。
class_name CheckResult
extends RefCounted

## 检定档位（大成功/成功/失败/大失败——骰 1 恒大失败、骰 ≥ 线大成功）
enum Grade {
	CRIT_SUCCESS,
	SUCCESS,
	FAILURE,
	CRIT_FAILURE,
}

## 原始骰值（1-20）
var die: int = 1
## 有效骰（= max(die, Z 幸运兜底)；骰 1 不兜——大失败优先）
var effective_die: int = 1
## 属性调整值（BattleRules.attr_modifier 单源）
var modifier: int = 0
## 合计（modifier + effective_die）
var total: int = 0
## 档位
var grade: Grade = Grade.FAILURE
## 本检定的大成功判定线（crit_line_of 产出——快照供 UI 反馈）
var crit_line: int = 20

func grade_text() -> String:
	## 档位中文名（UI 反馈条消费）
	## 参数：无
	## 返回：档位名
	match grade:
		Grade.CRIT_SUCCESS:
			return "大成功"
		Grade.SUCCESS:
			return "成功"
		Grade.FAILURE:
			return "失败"
		_:
			return "大失败"
