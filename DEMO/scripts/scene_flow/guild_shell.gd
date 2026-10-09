## 公会壳（guild_shell）场景脚本——M4 批 2 正式公会主界面（批 3 补养成弹层）
## 职责：顶栏 HUD（第 N 天+星期+货币+声望）/ 队伍总览（RosterOverview——行点击
## →成员详情弹层：属性/装备/技能/花点解锁/倾向入口）/「等待一天」
##（出征中 disabled——日历冻结口径）/ 设施两入口+协会入口（新挂单角标）/
## 日结算轻提示行 + 完整汇总弹窗（DaySummaryPanel——M5 批 2，等待一天成功后
## 弹出；轻提示行维持现状双保险）/ 升级+倾向选择弹层（LevelupPanel——
## pending 队列驱动）；M0 存档演示三件与 M3 占位出征面板已随批 2 退役
##（存档走五时点自动存档；出征入口移驻协会屏挂单管理）。
## 场景背景（M6 批 3）：BackgroundTexture 经 AssetRegistry 取 bg_guild_hall
## 铺满全屏，ColorRect 纯色兜底（缺登记/缺文件安全降级）。
## 右栏布局口径（修复批次 5：M4 试玩验收第 1 轮 UI 反馈）：设施协会区块
## 置顶（EntryTitle→宿舍→训练场→协会）→「等待一天」「待选倾向」→
## 日结算轻提示行垂直撑满剩余空间（SideBox 子节点顺序契约见
## test_guild_shell_ui_contract）。
## 数据来源：M4 批 2 方案；案 15 §2.2（屏规格）；案 2 §2.2（等待/跳过一天）。
## 单例访问：统一 get_node("/root/X")（gdUnit 测试环境惯例）。
extends Control

## SceneManager 脚本常量引用（枚举常量不可经实例属性访问，见 title_screen.gd 注）
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")

## 场景背景资源 id（M6 批 3 首批入库——AssetRegistry 单源路径映射，铁律②）
const BACKGROUND_ASSET_ID: StringName = &"bg_guild_hall"
## 顶栏货币图标资源 id（M6 批 3.5b 组 6：icon_res_gold——金行 HBox 图标）
const GOLD_ICON_ASSET_ID: StringName = &"icon_res_gold"
## 顶栏货币图标边长（px——16-20px 档取 20）
const GOLD_ICON_SIZE: float = 20.0

## UI 文案模板（逻辑层零文案——UI 层单源；S4-M4-4：本屏内联文案收编单源，
## 惯例对齐 quest_board_panel/explore_screen 先例）
const UI_TEXTS: Dictionary = {
	&"no_session": "（未开始游戏）",
	&"session_hint": "从标题屏「开始」或「继续」进入游戏。",
	&"day_week_format": "第 %d 天·%s",
	&"day_format": "第 %d 天",
	&"gold_format": "%d 金",
	&"reputation_format": "声望 %d",
	&"wait_locked_tooltip": "出征进行中——日历冻结",
	&"wait_locked_hint": "出征进行中——日历冻结，不能等待。",
	&"pending_button_format": "待选倾向（%d 人）",
	&"association_label": "冒险者协会（委托·招募）",
	&"association_badge": "冒险者协会（委托·招募）★新挂单",
	&"day_summary_format": "第 %d 天：%s。",
	&"day_summary_plain": "第 %d 天：无事发生。",
	&"summary_recovered_format": "恢复 %d 人",
	&"summary_week_refresh": "委托板周刷新",
	&"summary_board_removed_format": "板上到期 %d 单",
	# S4-02：板刷三表现/挂单到期/新候选/轻度完成分组键集——与 DaySummaryPanel
	# UI_TEXTS 同值语义（BuildDetailLines 单源消费契约）
	&"summary_board_refreshed_format": "刷新补位 %d 单",
	&"summary_board_replaced_format": "替换加急 %d 单",
	&"summary_accepted_failed_format": "挂单到期失败 %d 单",
	&"summary_candidates_format": "新候选：%s",
	&"autosave_failed_hint": "⚠ 最近一次自动存档写入失败——进度可能未落盘，请重试操作。",
	## S5-R5-03：四入口 go 失败可见提示（%d = SceneManager 错误码）
	&"go_fail_hint_format": "页面跳转失败（错误码 %d）——请重试。",
	&"summary_light_done_format": "轻度委托完成：%s +%d 金 +%d 经验 +%d 声望",
	&"summary_light_done_bench_suffix": "（板凳 %d 人各得 %d 经验）",
	&"summary_light_done_level_suffix": "（%s）",
	&"summary_light_done_level_entry": "%s 升 %d 级",
}

## GameData 单例引用（_ready 缓存）
var _game_data: Node = null
## 总控配置（_ready 缓存）
var _cfg: CoreConfig = null
## 队伍总览组件
var _roster_overview: RosterOverview = null
## 成员详情弹层（批 3）
var _detail_panel: MemberDetailPanel = null
## 升级+倾向选择弹层（批 3）
var _levelup_panel: LevelupPanel = null
## 日结算汇总弹窗（M5 批 2——等待一天成功后完整汇总呈现）
var _day_summary_panel: DaySummaryPanel = null

func _ready() -> void:
	## 引擎回调：取走跨场景参数 → 装配总览/详情/升级组件 → 字号档位覆写 →
	## 全量刷新；订阅 GuildState 日结算信号（跨屏等待后回本屏刷新）
	## 参数：无
	## 返回：无
	_game_data = get_node("/root/GameData")
	_cfg = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	_ApplyBackgroundTexture()
	_scene_manager().take_pending_params()
	_roster_overview = RosterOverview.new()
	_roster_overview.setup(_cfg)
	_roster_overview.member_selected.connect(_OnMemberSelected)
	%RosterHost.add_child(_roster_overview)
	_detail_panel = MemberDetailPanel.new()
	_detail_panel.setup(_cfg, _game_data)
	_detail_panel.close_requested.connect(_OnDetailClosed)
	_detail_panel.tendency_select_requested.connect(_OnTendencySelectRequested)
	_detail_panel.member_changed.connect(_OnMemberChanged)
	%DetailHost.add_child(_detail_panel)
	_levelup_panel = LevelupPanel.new()
	_levelup_panel.setup(_cfg, _game_data)
	_levelup_panel.close_requested.connect(_OnLevelupClosed)
	_levelup_panel.member_changed.connect(_OnMemberChanged)
	%LevelupHost.add_child(_levelup_panel)
	_day_summary_panel = DaySummaryPanel.new()
	_day_summary_panel.setup(_cfg, _game_data)
	_day_summary_panel.closed.connect(_OnDaySummaryClosed)
	%DaySummaryHost.add_child(_day_summary_panel)
	_guild_state().day_settled.connect(_OnDaySettled)
	_ApplyFontTiers()
	_ApplyGoldIcon()
	RefreshAll()

func _ApplyFontTiers() -> void:
	## tscn 内嵌字号档位覆写（B-7 惯例：tscn 值留占位——字号体系只动 cfg）；
	## W3-08：本屏按钮统一 normal 档
	## 参数：无
	## 返回：无
	%DayLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_large", UiTheme.FONT_LARGE))
	%GoldLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_large", UiTheme.FONT_LARGE))
	%ReputationLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_large", UiTheme.FONT_LARGE))
	%SettleInfoLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	%EntryTitle.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	var button_font: int = UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL)
	for button: Button in [%BackButton, %WaitButton, %PendingButton, %DormitoryButton,
			%TrainingButton, %AssociationButton]:
		button.add_theme_font_size_override("font_size", button_font)
	%RosterPanel.add_theme_stylebox_override("panel",
			UiTheme.make_dark_panel_style(_cfg, _game_data))

func _ApplyGoldIcon() -> void:
	## 顶栏金行图标装配（M6 批 3.5b 组 6）：icon_res_gold 贴给 GoldIcon
	## （20px 垂直居中，HBox 内 Label 前）；缺件/缺登记降级——图标不显示
	## （visible = false），GoldLabel 文本行现状零变化
	## 参数：无
	## 返回：无
	if not AssetTex.apply_to(%GoldIcon, GOLD_ICON_ASSET_ID, _game_data):
		%GoldIcon.visible = false

func _ApplyBackgroundTexture() -> void:
	## 场景背景接线（M6 批 3；批 3.5b 薄转发消双源）：AssetTex.apply_to 单源
	## 装配 bg_guild_hall（KEEP_ASPECT_COVERED 保持比例裁切铺满全屏，窗口
	## resize 恒铺满）；缺登记/加载失败返回 false——Background ColorRect 纯色
	## 兜底底色原样可见（warning 由 AssetTex 一次性打印，不崩不刷屏）
	## 参数：无
	## 返回：无
	AssetTex.apply_to(%BackgroundTexture, BACKGROUND_ASSET_ID, _game_data)

func _save_manager() -> Node:
	## 取 SaveManager 自动加载单例
	## 参数：无
	## 返回：SaveManager 节点
	return get_node("/root/SaveManager")

func _scene_manager() -> Node:
	## 取 SceneManager 自动加载单例
	## 参数：无
	## 返回：SceneManager 节点
	return get_node("/root/SceneManager")

func _guild_state() -> Node:
	## 取 GuildState 自动加载单例
	## 参数：无
	## 返回：GuildState 节点
	return get_node("/root/GuildState")

func _HasSession() -> bool:
	## 会话就绪判定（new_game/load 后 GuildCore 已装配；无会话时占位显示）
	## 参数：无
	## 返回：true = 有进行中的公会会话
	return _save_manager().current != null and _guild_state().core.cfg != null

func RefreshAll() -> void:
	## 全量刷新（HUD+总览+按钮态+协会角标）——_ready 与跨屏返回入口共用
	## 参数：无
	## 返回：无
	if not _HasSession():
		%DayLabel.text = UI_TEXTS[&"no_session"]
		%GoldLabel.text = ""
		%ReputationLabel.text = ""
		%SettleInfoLabel.text = UI_TEXTS[&"session_hint"]
		%WaitButton.disabled = true
		_ApplyAssociationBadge()
		return
	var core: GuildCore = _guild_state().core
	var weekday: String = CalendarCore.weekday_label(core.day, _cfg.calendar_week_days) \
			if _cfg.calendar_week_display else ""
	# S4-R5-01①：HUD 四格式串改 UI_TEXTS 键消费（原字面量与四键双源漂移）
	%DayLabel.text = String(UI_TEXTS[&"day_week_format"]) % [core.day, weekday] \
			if not weekday.is_empty() else String(UI_TEXTS[&"day_format"]) % core.day
	%GoldLabel.text = String(UI_TEXTS[&"gold_format"]) % core.gold
	%ReputationLabel.text = String(UI_TEXTS[&"reputation_format"]) % core.reputation
	_roster_overview.refresh(core.roster, core.board, core.day, _game_data,
			core.pending_tendency_levels)
	var locked: bool = _save_manager().is_expedition_locked()
	%WaitButton.disabled = locked
	# Z2-6：出征冻结 tooltip（禁用态无点击反馈的口径提示）
	%WaitButton.tooltip_text = String(UI_TEXTS[&"wait_locked_tooltip"]) if locked else ""
	# Z2-3：悬置倾向直入入口（pending>0 时显示）
	%PendingButton.visible = not core.pending_tendency_levels.is_empty()
	%PendingButton.text = String(UI_TEXTS[&"pending_button_format"]) % core.pending_tendency_levels.size()
	# S3-M5-1-b：最近一次自动存档失败感知（四时点 FAILED 与 M-3 口径对称）；
	# S4-R2-05：警示不覆写当日摘要（「弹窗关闭后轻提示行可查」契约）——
	# 拼接呈现且幂等（已含不重复追加）；恢复正常后剥离警示行
	if _guild_state().last_autosave_failed:
		var warn_text: String = String(UI_TEXTS[&"autosave_failed_hint"])
		if not %SettleInfoLabel.text.contains(warn_text):
			%SettleInfoLabel.text += "\n" + warn_text
	elif %SettleInfoLabel.text.contains(String(UI_TEXTS[&"autosave_failed_hint"])):
		%SettleInfoLabel.text = %SettleInfoLabel.text.replace(
				"\n" + String(UI_TEXTS[&"autosave_failed_hint"]), "")
	_ApplyAssociationBadge()

func _OnDaySettled(_summary: Variant) -> void:
	## GuildState 日结算信号（跨屏等待触发——回本屏时统一刷新）
	## 参数 _summary：DaySummary（轻提示行由触发点写——此处只刷新）
	## 返回：无
	RefreshAll()

func _on_wait_pressed() -> void:
	## 「等待一天」（案 2 §2.2 兜底行为；出征中 disabled——日历冻结）：
	## GuildState.wait_one_day → 轻提示行（维持现状）+ 完整汇总弹窗（M5 批 2——
	## 弹窗关闭后轻提示行仍有当日单行摘要可查，双保险）；S5-02：弹窗打开期间
	## 不可再推一天（不再写存档/覆盖前日明细——关闭即解锁）
	## 参数：无
	## 返回：无
	if %DaySummaryHost.visible:
		return
	if not _HasSession():
		return
	var summary: GuildCore.DaySummary = _guild_state().wait_one_day()
	if summary == null:
		%SettleInfoLabel.text = UI_TEXTS[&"wait_locked_hint"]
		RefreshAll()
		return
	%SettleInfoLabel.text = _SummarizeDay(summary)
	RefreshAll()
	_day_summary_panel.open([summary])
	%DaySummaryHost.visible = true

func _OnDaySummaryClosed() -> void:
	## 日结算汇总弹窗关闭（隐藏宿主——轻提示行仍持当日摘要）
	## 参数：无
	## 返回：无
	_day_summary_panel.close()
	%DaySummaryHost.visible = false

func _on_pending_pressed() -> void:
	## 「待选倾向」直入入口（Z2-3：升级+倾向面板队列模式——不经成员详情）
	## 参数：无
	## 返回：无
	_levelup_panel.open(_guild_state().core)
	%LevelupHost.visible = true

func _SummarizeDay(summary: GuildCore.DaySummary) -> String:
	## 日结算轻提示行拼装（S4-02：分组明细行单源——DaySummaryPanel.
	## BuildDetailLines 共用拼装，轻提示行与汇总弹窗/外出期间汇总恒一致；
	## 板刷三表现含此前缺失的「刷新补位/替换加急」两组）
	## 参数 summary：GuildCore.DaySummary
	## 返回：提示文本
	var detail: PackedStringArray = DaySummaryPanel.BuildDetailLines(summary, UI_TEXTS)
	if detail.is_empty():
		return String(UI_TEXTS[&"day_summary_plain"]) % summary.day
	return String(UI_TEXTS[&"day_summary_format"]) % [summary.day, "；".join(detail)]

func _OnMemberSelected(unit_id: StringName) -> void:
	## 成员行点击 → 成员详情弹层（属性/装备/技能/解锁/倾向入口——批 3 接线）
	## 参数 unit_id：成员 id
	## 返回：无
	var member: AdventurerData = _guild_state().core.find_member(unit_id)
	if member == null:
		return
	_detail_panel.open(member, _guild_state().core)
	%DetailHost.visible = true

func _OnDetailClosed() -> void:
	## 详情弹层关闭
	## 参数：无
	## 返回：无
	_detail_panel.close()
	%DetailHost.visible = false

func _OnTendencySelectRequested(unit_id: StringName) -> void:
	## 详情弹层「选择倾向」→ 升级+倾向选择面板（聚焦该成员）
	## 参数 unit_id：成员 id
	## 返回：无
	%DetailHost.visible = false
	_detail_panel.close()
	_levelup_panel.open(_guild_state().core, unit_id)
	%LevelupHost.visible = true

func _OnLevelupClosed() -> void:
	## 升级面板关闭（总览刷新——属性/悬置可能已变）
	## 参数：无
	## 返回：无
	_levelup_panel.close()
	%LevelupHost.visible = false
	RefreshAll()

func _OnMemberChanged(_unit_id: StringName) -> void:
	## 成员数据变更（技能解锁/选倾向）→ 总览刷新
	## 参数 _unit_id：成员 id
	## 返回：无
	RefreshAll()

func _ApplyAssociationBadge() -> void:
	## 协会入口角标文案（读核心层 GuildCore.has_unseen_grants——M4-1：结算时
	## 公会壳可能已销毁、跨场景信号无监听，状态改常驻核心层随公会快照持久；
	## 进协会屏 _ready 清除）；S4-R2-04：文案经 UI_TEXTS 键消费（原硬编码
	## 字面量与 association_label/association_badge 键双源漂移）
	## 参数：无
	## 返回：无
	if not _HasSession():
		%AssociationButton.text = UI_TEXTS[&"association_label"]
		return
	%AssociationButton.text = UI_TEXTS[&"association_badge"] \
			if _guild_state().core.has_unseen_grants else UI_TEXTS[&"association_label"]

func _GoWithHint(target_id: int, label: String) -> void:
	## 四入口共用跳转（S4-07：go 重入拒绝 FAILED 分流——SceneManager 切换
	## 进行中属正常切换态，不弹「失败请重试」误报；其余错误码可见提示）
	## 参数 target_id：目标场景（SceneId）；label：失败提示语境词
	## 返回：无
	var err: Error = _scene_manager().go(target_id)
	if err == OK:
		return
	if err == FAILED:
		push_warning("guild_shell: %s被拒——场景切换进行中（正常重入）" % label)
		return
	push_warning("guild_shell: %s失败（错误码 %d）" % [label, err])
	%SettleInfoLabel.text = String(UI_TEXTS[&"go_fail_hint_format"]) % err

func _on_back_pressed() -> void:
	## 「返回标题」：纯导航（不触存档——存档走五时点自动存档）
	## 参数：无
	## 返回：无
	_GoWithHint(SceneManagerScript.SceneId.TITLE, "返回标题")

func _on_dormitory_pressed() -> void:
	## 宿舍入口（拍板⑥独立场景；scene_id=批 1 fac_ 表已落值）
	## 参数：无
	## 返回：无
	_GoWithHint(SceneManagerScript.SceneId.GUILD_DORMITORY, "进入宿舍")

func _on_training_pressed() -> void:
	## 训练场入口
	## 参数：无
	## 返回：无
	_GoWithHint(SceneManagerScript.SceneId.GUILD_TRAINING_GROUND, "进入训练场")

func _on_association_pressed() -> void:
	## 协会入口（委托板/挂单管理/招募池——M4 出征入口移驻；未查看挂单标志由
	## 协会屏 _ready 清除）
	## 参数：无
	## 返回：无
	_GoWithHint(SceneManagerScript.SceneId.ASSOCIATION_SCREEN, "进入协会")
