## 日结算汇总弹窗（DaySummaryPanel，代码构建 UI 组件——M5 批 2）
## 职责：等待一天成功后的完整日结算汇总呈现——GuildCore.aggregate_day_summaries
## 聚合（单日=1 组；回城补结算逐日=多组）→ 分组明细行（BuildDetailLines 静态
## 共用口——本弹窗正文与 explore_screen「外出期间汇总」行防双源）→
## 标题/正文/关闭钮骨架（UiTheme 深底+字号档位；弹层 z=100 置顶）。
## 文案口径：与 guild_shell 轻提示行同值语义、独立常量表（UI 层各自单源）。
## 数据来源：案 2 §2.4 第 10 步「汇总通知」（M5 工作项 4 完整汇总弹窗）。
class_name DaySummaryPanel
extends PanelContainer

## 关闭信号（宿主隐藏弹层宿主——DetailHost/LevelupHost 先例）
signal closed

## 弹层 z（单源置顶——LevelupPanel/OrganizePanel 先例；explore_screen
## UI_POPUP_Z_INDEX 同值语义）
const POPUP_Z_INDEX: int = 100

## UI 文案单源（改措辞只动此处；summary_* 分组键集=BuildDetailLines 消费契约
## ——explore_screen 增同键集后共用行拼装）
const UI_TEXTS: Dictionary = {
	&"title_format": "第 %d 天·结算汇总",
	&"empty_line": "无事发生。",
	&"close_button": "关闭",
	&"summary_recovered_format": "恢复 %d 人",
	&"summary_week_refresh": "委托板周刷新",
	&"summary_board_removed_format": "板上到期 %d 单",
	&"summary_board_refreshed_format": "刷新补位 %d 单",
	&"summary_board_replaced_format": "替换加急 %d 单",
	&"summary_accepted_failed_format": "挂单到期失败 %d 单",
	&"summary_candidates_format": "新候选：%s",
	&"summary_light_done_format": "轻度委托完成：%s +%d 金 +%d 经验 +%d 声望",
	&"summary_light_done_bench_suffix": "（板凳 %d 人各得 %d 经验）",
	&"summary_light_done_level_suffix": "（%s）",
	&"summary_light_done_level_entry": "%s 升 %d 级",
}

## 正文限宽（px——autowrap 生效前提；EVENT_PANEL_WIDTH 占位先例同口径）
const BODY_MIN_WIDTH: int = 640

## 总控配置
var _cfg: CoreConfig = null
## 内容容器
var _box: VBoxContainer = null
## 标题行
var _title_label: Label = null
## 正文行（明细行 \n 拼接）
var _body_label: Label = null

func setup(cfg: CoreConfig, game_data: Node = null) -> void:
	## 构建弹层骨架（标题/正文/关闭钮——初始隐藏）；M6 批 3.5b：game_data
	## 注入（九宫格面板贴图态；空 = 缺件降级 StyleBoxFlat）
	## 参数 cfg：总控配置；game_data：GameData（可空）
	## 返回：无
	_cfg = cfg
	visible = false
	z_index = POPUP_Z_INDEX
	add_theme_stylebox_override("panel", UiTheme.make_dark_panel_style(cfg, game_data))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	_box.add_child(_title_label)
	_body_label = Label.new()
	_body_label.name = "BodyLabel"
	# WORD_SMART 智能换行（M5 批 2 实测枚举值=3；定值 2=WORD——代码一律用
	# 枚举名，LevelupPanel 先例）
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(BODY_MIN_WIDTH, 0)
	_body_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	_box.add_child(_body_label)
	var close_button := Button.new()
	close_button.name = "CloseSummaryButton"
	close_button.text = UI_TEXTS[&"close_button"]
	close_button.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	close_button.pressed.connect(func() -> void: closed.emit())
	_box.add_child(close_button)

func open(summaries: Array) -> void:
	## 打开：聚合 → 标题（末组天数）+ 分组明细行正文（无事=占位行）
	## 参数 summaries：DaySummary 列表（单日 [summary] 或回城补结算逐日多组）
	## 返回：无
	var agg: GuildCore.DaySummary = GuildCore.aggregate_day_summaries(summaries)
	_title_label.text = String(UI_TEXTS[&"title_format"]) % agg.day
	var lines: PackedStringArray = BuildDetailLines(agg, UI_TEXTS)
	_body_label.text = "\n".join(lines) if not lines.is_empty() \
			else String(UI_TEXTS[&"empty_line"])
	visible = true

func close() -> void:
	## 关闭弹层
	## 参数：无
	## 返回：无
	visible = false

static func BuildDetailLines(agg: GuildCore.DaySummary,
		texts: Dictionary) -> PackedStringArray:
	## 分组明细行拼装（本弹窗正文与 explore_screen「外出期间汇总」行共用——
	## 防双源）：恢复完成/周刷新/板上到期三表现/挂单到期失败/新候选/轻度完成
	## 含板凳后缀；全空返回空数组（调用方判空不出行/不冗余）
	## 参数 agg：聚合 DaySummary；texts：文案表（须含 summary_* 分组键集）
	## 返回：明细行数组（空=无事发生）
	var lines: PackedStringArray = []
	if not agg.recovered_ids.is_empty():
		lines.append(String(texts[&"summary_recovered_format"])
				% agg.recovered_ids.size())
	if agg.week_refreshed:
		lines.append(String(texts[&"summary_week_refresh"]))
	if not agg.board_removed.is_empty():
		lines.append(String(texts[&"summary_board_removed_format"])
				% agg.board_removed.size())
	if not agg.board_refreshed.is_empty():
		lines.append(String(texts[&"summary_board_refreshed_format"])
				% agg.board_refreshed.size())
	if not agg.board_replaced.is_empty():
		lines.append(String(texts[&"summary_board_replaced_format"])
				% agg.board_replaced.size())
	if not agg.accepted_failed.is_empty():
		lines.append(String(texts[&"summary_accepted_failed_format"])
				% agg.accepted_failed.size())
	if not agg.new_candidate_names.is_empty():
		lines.append(String(texts[&"summary_candidates_format"])
				% "、".join(agg.new_candidate_names))
	for result: GuildCore.LightQuestResult in agg.light_completed:
		var entry_text: String = String(texts[&"summary_light_done_format"]) % [
				result.display_name, result.gold, result.exp, result.reputation]
		if result.bench_member_count > 0:
			entry_text += String(texts[&"summary_light_done_bench_suffix"]) % [
					result.bench_member_count, result.bench_exp_per_member]
		# 盲审 R2-2：升级后缀（levels_gained 非空才出——成员名升 N 级，
		## 多人顿号并接；文案两键单源）
		if not result.levels_gained.is_empty():
			var level_parts: PackedStringArray = []
			for unit_key: String in result.levels_gained:
				level_parts.append(String(texts[&"summary_light_done_level_entry"]) % [
						unit_key, int(result.levels_gained[unit_key])])
			entry_text += String(texts[&"summary_light_done_level_suffix"]) % [
					"、".join(level_parts)]
		lines.append(entry_text)
	return lines
