## 校验报告（ValidationReport）
## 职责：承载 DataValidator 全库校验结果——error/warning 两级条目，
## 提供 is_ok / to_text 输出（供 run_validation 工具落盘与 gdUnit 断言消费）。
## 数据来源：DataValidator（res://scripts/data/data_validator.gd）产出。
## id 命名规范：本类为运行时产物，非数据表资源，无 id。
class_name ValidationReport
extends RefCounted

## 错误条目（阻断级：格式「V-M0-<规则> | <资源 id> | <描述>」）
var errors: Array[String] = []
## 警告条目（非阻断：如计数偏离预期带）
var warnings: Array[String] = []
## 校验的资源总数（报告头统计用）
var checked_count: int = 0

func add_error(rule_id: String, record_id: String, message: String) -> void:
	## 追加一条错误
	## 参数 rule_id：规则号（如 V-M0-ref-skill-status）；record_id：涉事资源 id；message：描述
	## 返回：无
	errors.append("%s | %s | %s" % [rule_id, record_id, message])

func add_warning(rule_id: String, record_id: String, message: String) -> void:
	## 追加一条警告
	## 参数 rule_id：规则号；record_id：涉事资源 id；message：描述
	## 返回：无
	warnings.append("%s | %s | %s" % [rule_id, record_id, message])

func has_errors() -> bool:
	## 是否存在错误条目
	## 参数：无
	## 返回：true = 存在错误（校验不通过）
	return not errors.is_empty()

func is_ok() -> bool:
	## 校验是否通过（零错误；警告允许）
	## 参数：无
	## 返回：true = 零错误
	return errors.is_empty()

func to_text() -> String:
	## 生成人读报告（头部统计 + 错误清单 + 警告清单）
	## 参数：无
	## 返回：多行文本
	var lines: Array[String] = []
	lines.append("=== 数据校验报告 ===")
	lines.append("检查资源数：%d | 错误：%d | 警告：%d" % [checked_count, errors.size(), warnings.size()])
	lines.append("结论：%s" % ("通过（零错误）" if is_ok() else "不通过（存在错误）"))
	if not errors.is_empty():
		lines.append("--- 错误 ---")
		for entry: String in errors:
			lines.append("[ERROR] " + entry)
	if not warnings.is_empty():
		lines.append("--- 警告 ---")
		for entry: String in warnings:
			lines.append("[WARN]  " + entry)
	return "\n".join(lines)
