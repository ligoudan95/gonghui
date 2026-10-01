## UI 文案收编抽样契约测试（M6 批 2 挂账 4.2）
## 覆盖：13 文件内联 UI 中文收编后——①抽样断言各文件 UI_TEXTS 键值还原
##（仅搬运不改值防回归）；②全量扫描源文件：注释行/push_* 日志行/常量定义
## 块之外不得残留中文字符串字面量（新增内联文案在落盘侧即拦截）。
## 豁免口径：push_error/push_warning 诊断串、常量单源本体（UI_TEXTS/
## ATTR_NAMES/MSG_*/TOOLTIP_TEMPLATES 等）、# 注释。
extends GdUnitTestSuite

## 收编文件清单（方案 §4.2——13 文件；方案名单实列 14 项含 title_screen）
const FILES: Array[String] = [
	"res://scripts/scene_flow/association_screen.gd",
	"res://scripts/ui/guild/organize_panel.gd",
	"res://scripts/ui/guild/member_detail_panel.gd",
	"res://scripts/ui/guild/levelup_panel.gd",
	"res://scripts/ui/guild/accepted_panel.gd",
	"res://scripts/ui/guild/recruit_panel.gd",
	"res://scripts/ui/guild/roster_overview.gd",
	"res://scripts/ui/guild/quest_card.gd",
	"res://scripts/ui/event/event_panel.gd",
	"res://scripts/ui/battle/battle_screen.gd",
	"res://scripts/ui/battle/result_panel.gd",
	"res://scripts/ui/battle/battle_log.gd",
	"res://scripts/scene_flow/facility_screen.gd",
	"res://scripts/scene_flow/title_screen.gd",
]

func test_battle_log_texts_sampled() -> void:
	## 抽样①：battle_log 格式串搬运还原（回合头/倒地/命中链模板）
	assert_str(String(BattleLog.UI_TEXTS[&"round_line_format"])).is_equal("—— 回合 %d ——")
	assert_str(String(BattleLog.UI_TEXTS[&"downed_line_format"])).is_equal("%s 倒地")
	assert_str(String(BattleLog.UI_TEXTS[&"hit_line_format"])) \
			.is_equal("  命中 %d%%（基准 %d +修正 %d −闪避 %d）→ %s")
	assert_str(String(BattleLog.UI_TEXTS[&"hit_missed"])).is_equal("失手")
	assert_str(String(BattleLog.MSG_MOVE_REJECTED)).is_equal("无法移动到该格——请重新选择")

func test_result_panel_texts_sampled() -> void:
	## 抽样②：result_panel 三态标题与摘要行
	assert_str(String(ResultPanel.UI_TEXTS[&"victory_title"])).is_equal("战斗胜利")
	assert_str(String(ResultPanel.UI_TEXTS[&"defeat_title"])).is_equal("战败·全队重伤休养")
	assert_str(String(ResultPanel.UI_TEXTS[&"retreat_title"])).is_equal("撤退成功·委托失败")
	assert_str(String(ResultPanel.UI_TEXTS[&"summary_line_format"])) \
			.is_equal("\n回合数：%d｜倒地：%s")
	assert_str(String(ResultPanel.UI_TEXTS[&"downed_none"])).is_equal("无")

func test_member_detail_texts_sampled() -> void:
	## 抽样③：member_detail_panel 状态行/装备行（经 load 取 const——类未
	## class_name 引用的场景流/组件经 preload 脚本读）
	var script: GDScript = load("res://scripts/ui/guild/member_detail_panel.gd") as GDScript
	var texts: Dictionary = script.get("UI_TEXTS")
	assert_str(String(texts[&"status_healthy"])).is_equal("健康")
	assert_str(String(texts[&"exp_capped"])).is_equal("已满级")
	assert_str(String(texts[&"equip_missing"])) \
			.is_equal("装备（初始套装·固定）：未查到职业套装")

func test_facility_texts_sampled() -> void:
	## 抽样④：facility_screen 升级钮/tooltip 模板
	var script: GDScript = load("res://scripts/scene_flow/facility_screen.gd") as GDScript
	var texts: Dictionary = script.get("UI_TEXTS")
	assert_str(String(texts[&"back_button"])).is_equal("返回公会")
	assert_str(String(texts[&"max_level_text"])).is_equal("已满级")
	assert_str(String(texts[&"upgrade_cost_format"])).is_equal("升级（%d 金）")
	assert_str(String(texts[&"effect_dorm_format"])) \
			.is_equal("容量 %d 人｜重伤休养 -%d 天")

func test_accepted_and_organize_texts_sampled() -> void:
	## 抽样⑤：accepted_panel 行模板 + organize_panel 预览模板
	assert_str(String(AcceptedPanel.UI_TEXTS[&"row_format"])) \
			.is_equal("%s｜%s｜%s｜编队：%s")
	assert_str(String(AcceptedPanel.UI_TEXTS[&"start_button"])).is_equal("出征")
	assert_str(String(OrganizePanel.UI_TEXTS[&"confirm_button"])).is_equal("确认编队")
	assert_str(String(OrganizePanel.UI_TEXTS[&"preview_over_format"])) \
			.is_equal("已选 %d 人——超出上限 %d，无法确认")
	assert_str(String(QuestCard.UI_TEXTS[&"reward_format"])) \
			.is_equal("奖励：%d 金 / %d 经验 / %d 声望")

func _ScanInlineResidual(path: String) -> Array[String]:
	## 残留扫描：排除注释行/push_* 日志行/常量定义块（const 起至配对 `}` 止），
	## 其余行含中文字符串字面量即报（返回「行号: 内容」清单）
	## 参数 path：脚本路径
	## 返回：残留行清单
	var residuals: Array[String] = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ["<open failed>"]
	var in_const_block: bool = false
	var line_no: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_no += 1
		var trimmed: String = line.strip_edges()
		if in_const_block:
			if trimmed.begins_with("}") or trimmed.ends_with("}"):
				in_const_block = false
			continue
		if trimmed.begins_with("#"):
			continue
		if trimmed.begins_with("const "):
			if not trimmed.ends_with("}"):
				in_const_block = true
			continue
		if line.contains("push_error") or line.contains("push_warning"):
			continue
		for index: int in line.length():
			var code: int = line.unicode_at(index)
			if code >= 0x4E00 and code <= 0x9FFF:
				residuals.append("%d: %s" % [line_no, trimmed])
				break
	file.close()
	return residuals

func test_no_inline_ui_chinese_residual_in_all_files() -> void:
	## 核心契约：13 文件常量块/注释/push_* 之外零中文残留（新增内联文案拦截）
	for path: String in FILES:
		var residuals: Array[String] = _ScanInlineResidual(path)
		assert_int(residuals.size()).is_equal(0) \
				.override_failure_message("%s 存在内联 UI 中文残留：%s" % [
						path, ", ".join(residuals.slice(0, 3))])
