## 战斗日志卷轴集成测试（布局三改批：日志卷轴化+左列收窄+棋盘右扩）
## 覆盖：卷轴组件契约——收起默认态（浮层 invisible/根 IGNORE/锚点占位）、
## 展开/收起 toggle（即时态注入）、收起穿透（可见 STOP 全落锚点热区内）、
## 展开拦截不越自身（面板 STOP 且含日志、rect 不越卷轴全屏 rect）、
## z 序契约（300 压棋盘 Z_TEXT=200、ResultLayer 400 压卷轴）、锚点热区
## ≥48 且 cfg 驱动重算、720/600/450 三档展开钳制公式（381.6/309.6/240
## 兜底）+ 展开右缘不越屏宽−12、未读计数（收起累计/展开清零/收起不清/
## 展开态不计）、敌方轮锚点文案切换、降级路径（卷轴在位收起不遮
## IdleLabel）、BattleLog 迁移零回归（push_line 计数）。
## 环境口径：scene_runner 直开走无参降级路径（卷轴在位保持收起、cfg 读取
## 口兜底）；cfg 注入经 apply_cfg（cfg_main 实例临时改键、用后还原——
## test_battle_anim_flow 同式）。
extends GdUnitTestSuite

## 战斗场景路径
const BATTLE_SCENE: String = "res://scenes/battle/battle_screen.tscn"
## 提示语文案锚点（与 BattleLogScroller.UI_TEXTS.enemy_turn_hint 同值——
## 改文案两处同步）
const HINT_TEXT: String = "敌方行动中…（点按战场可跳过演出）"

func _Cfg() -> CoreConfig:
	## cfg_main 实例读取（共享资源——改键用后由调用方还原）
	## 参数：无
	## 返回：CoreConfig
	return load("res://data/core/cfg_main.tres") as CoreConfig

func _MakeInstant(runner: GdUnitSceneRunner) -> BattleLogScroller:
	## 卷轴即时态装配（toggle_seconds 注 0——即时无动画口径）+ 返回引用
	## 参数 runner：场景运行器
	## 返回：LogScroller
	var battle: Control = runner.scene() as Control
	var scroller: BattleLogScroller = battle.get_node("%LogScroller") as BattleLogScroller
	var cfg: CoreConfig = _Cfg()
	cfg.ui_battle_log_toggle_seconds = 0.0
	scroller.apply_cfg(cfg, null)
	return scroller

func _CollectVisibleStops(root: Control, out: Array[Control]) -> void:
	## 递归收集树内可见 STOP 控件（收起穿透断言消费——含祖先可见性）
	## 参数 root：遍历根；out：输出收集表
	## 返回：无
	for child: Node in root.get_children():
		var control: Control = child as Control
		if control == null:
			continue
		if control.is_visible_in_tree() \
				and control.mouse_filter == Control.MOUSE_FILTER_STOP:
			out.append(control)
		_CollectVisibleStops(control, out)

func test_collapsed_default_contract() -> void:
	## 用例①：收起默认契约——展开逻辑态 false、ExpandPanel invisible、
	## 未读 0、根 IGNORE 全穿透、锚点占位「战斗日志 (0)」
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var scroller: BattleLogScroller = battle.get_node("%LogScroller") as BattleLogScroller
	assert_object(scroller).is_not_null()
	assert_bool(scroller.is_expanded()).is_false()
	assert_int(scroller.get_unread_count()).is_equal(0)
	var expand_panel: PanelContainer = battle.get_node("%ExpandPanel") as PanelContainer
	assert_bool(expand_panel.visible).is_false() \
			.override_failure_message("新日志不自动展开——ExpandPanel 默认应 invisible")
	assert_int(scroller.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_str((battle.get_node("%AnchorLabel") as Label).text).is_equal("战斗日志 (0)")

func test_expand_and_collapse_toggle_instant() -> void:
	## 用例②：展开/收起 toggle（即时态注入）——set_expanded(true) 面板可见
	## 且正尺寸、(false) 回落隐藏、toggle_expanded 薄转发翻转
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var cfg: CoreConfig = _Cfg()
	var original_seconds: float = cfg.ui_battle_log_toggle_seconds
	var scroller: BattleLogScroller = _MakeInstant(runner)
	var expand_panel: PanelContainer = battle.get_node("%ExpandPanel") as PanelContainer
	scroller.set_expanded(true)
	await get_tree().process_frame
	assert_bool(scroller.is_expanded()).is_true()
	assert_bool(expand_panel.visible).is_true()
	assert_float(expand_panel.size.y).is_greater(200.0) \
			.override_failure_message("展开面板高度塌缩（%s）" % expand_panel.size)
	scroller.set_expanded(false)
	await get_tree().process_frame
	assert_bool(scroller.is_expanded()).is_false()
	assert_bool(expand_panel.visible).is_false()
	scroller.toggle_expanded()
	assert_bool(scroller.is_expanded()).is_true()
	scroller.toggle_expanded()
	assert_bool(scroller.is_expanded()).is_false()
	cfg.ui_battle_log_toggle_seconds = original_seconds

func test_collapsed_click_through_no_stray_stop() -> void:
	## 用例③：收起穿透——卷轴树内全部可见 STOP 控件 rect ⊆ 锚点热区 rect
	##（根 IGNORE + 展开面板 invisible——收起态棋盘零遮挡，静态断言口径同
	## layout 套件）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var scroller: BattleLogScroller = battle.get_node("%LogScroller") as BattleLogScroller
	var hit_area: Control = battle.get_node("%HitArea") as Control
	var stops: Array[Control] = []
	_CollectVisibleStops(scroller, stops)
	assert_int(stops.size()).is_greater_equal(1) \
			.override_failure_message("锚点热区应存在且 STOP")
	var hit_rect: Rect2 = hit_area.get_global_rect()
	for stop: Control in stops:
		assert_bool(hit_rect.encloses(stop.get_global_rect())).is_true() \
				.override_failure_message("收起态 STOP 控件 %s rect %s 越出锚点热区 %s" % [
						stop.name, stop.get_global_rect(), hit_rect])

func test_expanded_panel_intercept_within_self() -> void:
	## 用例④：展开 rect 内拦截不越自身——ExpandPanel STOP、rect 不越卷轴
	## 全屏 rect、BattleLog 含于面板 rect 内
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var cfg: CoreConfig = _Cfg()
	var original_seconds: float = cfg.ui_battle_log_toggle_seconds
	var scroller: BattleLogScroller = _MakeInstant(runner)
	scroller.set_expanded(true)
	await get_tree().process_frame
	var expand_panel: PanelContainer = battle.get_node("%ExpandPanel") as PanelContainer
	assert_int(expand_panel.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_bool(scroller.get_global_rect().encloses(expand_panel.get_global_rect())).is_true() \
			.override_failure_message("展开面板 %s 越出卷轴全屏 rect %s" % [
					expand_panel.get_global_rect(), scroller.get_global_rect()])
	var log_panel: PanelContainer = battle.get_node("%BattleLog") as PanelContainer
	assert_bool(expand_panel.get_global_rect().encloses(log_panel.get_global_rect())).is_true() \
			.override_failure_message("BattleLog %s 越出展开面板 %s" % [
					log_panel.get_global_rect(), expand_panel.get_global_rect()])
	scroller.set_expanded(false)
	cfg.ui_battle_log_toggle_seconds = original_seconds

func test_z_order_contract() -> void:
	## 用例⑤：z 序契约——卷轴 Z_LOG_OVERLAY=300 压棋盘 tips/飘字
	## BattleBoard.Z_TEXT=200；ResultLayer z=400 压卷轴（结算弹出不被遮）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var scroller: Control = battle.get_node("%LogScroller")
	assert_int(scroller.z_index).is_equal(BattleLogScroller.Z_LOG_OVERLAY)
	assert_int(BattleLogScroller.Z_LOG_OVERLAY).is_greater(BattleBoard.Z_TEXT) \
			.override_failure_message("卷轴 z=%d 应压棋盘飘字 Z_TEXT=%d" % [
					BattleLogScroller.Z_LOG_OVERLAY, BattleBoard.Z_TEXT])
	var result_layer: Control = battle.get_node("ResultLayer") as Control
	assert_int(result_layer.z_index).is_equal(400)
	assert_int(result_layer.z_index).is_greater(scroller.z_index) \
			.override_failure_message("ResultLayer z=%d 应压卷轴 z=%d" % [
					result_layer.z_index, scroller.z_index])

func test_anchor_hit_area_min_size_cfg_driven() -> void:
	## 用例⑥：锚点热区 ≥48×48 触控硬条款且 cfg 驱动重算——锚点视觉改小
	##（96×20）热区钳 96×48；hit_min 改 64 热区随表重算高度抬 64
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var cfg: CoreConfig = _Cfg()
	var original_w: float = cfg.ui_battle_log_anchor_width
	var original_h: float = cfg.ui_battle_log_anchor_height
	var original_min: float = cfg.ui_battle_log_hit_min_size
	var scroller: BattleLogScroller = battle.get_node("%LogScroller") as BattleLogScroller
	var hit_area: Control = battle.get_node("%HitArea") as Control
	cfg.ui_battle_log_anchor_width = 96.0
	cfg.ui_battle_log_anchor_height = 20.0
	scroller.apply_cfg(cfg, null)
	await get_tree().process_frame
	assert_float(hit_area.size.x).is_greater_equal(48.0)
	assert_float(hit_area.size.y).is_greater_equal(48.0) \
			.override_failure_message("锚点热区 %s < 48×48 触控硬条款" % hit_area.size)
	assert_float(absf(hit_area.size.x - 96.0)).is_less_equal(0.5)
	assert_float(absf(hit_area.size.y - 48.0)).is_less_equal(0.5)
	# 改表重算：hit_min 抬 64 → 热区高随表抬升（max(20,64) = 64）
	cfg.ui_battle_log_hit_min_size = 64.0
	scroller.apply_cfg(cfg, null)
	await get_tree().process_frame
	assert_float(hit_area.size.y).is_greater_equal(64.0) \
			.override_failure_message("hit_min=64 改表后热区未重算（%s）" % hit_area.size)
	cfg.ui_battle_log_anchor_width = original_w
	cfg.ui_battle_log_anchor_height = original_h
	cfg.ui_battle_log_hit_min_size = original_min

func test_expand_clamp_three_window_tiers() -> void:
	## 用例⑦：三档展开钳制公式——720 档（636×0.6=381.6）/600 档
	##（516×0.6=309.6）/450 极矮档（219.6 < 240 → 240 兜底）；展开态
	## resize 跟随重算；右缘不越屏宽−12
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var cfg: CoreConfig = _Cfg()
	var original_seconds: float = cfg.ui_battle_log_toggle_seconds
	var scroller: BattleLogScroller = _MakeInstant(runner)
	var expand_panel: PanelContainer = battle.get_node("%ExpandPanel") as PanelContainer
	battle.size = Vector2(1280.0, 720.0)
	await get_tree().process_frame
	await get_tree().process_frame
	scroller.set_expanded(true)
	await get_tree().process_frame
	assert_float(expand_panel.size.y).is_equal_approx(381.6, 0.1) \
			.override_failure_message("720 档展开高 %s 应为 381.6" % expand_panel.size.y)
	battle.size = Vector2(1280.0, 600.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(expand_panel.size.y).is_equal_approx(309.6, 0.1) \
			.override_failure_message("600 档展开高 %s 应为 309.6（resize 跟随重算）" % expand_panel.size.y)
	battle.size = Vector2(1280.0, 450.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(expand_panel.size.y).is_equal_approx(240.0, 0.1) \
			.override_failure_message("450 极矮档展开高 %s 应为 240 兜底" % expand_panel.size.y)
	assert_float(expand_panel.get_global_rect().end.x) \
			.is_less_equal(battle.get_global_rect().end.x - 12.0 + 0.5) \
			.override_failure_message("展开面板右缘 %s 越屏宽−12 %s" % [
					expand_panel.get_global_rect().end.x,
					battle.get_global_rect().end.x - 12.0])
	scroller.set_expanded(false)
	cfg.ui_battle_log_toggle_seconds = original_seconds

func test_unread_count_lifecycle() -> void:
	## 用例⑧：未读计数——收起态 push×3 → 3 且锚点染计数；展开清 0；
	## 展开态 push 不计；收起不清（0 维持）；再收起新条目重新累计
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var cfg: CoreConfig = _Cfg()
	var original_seconds: float = cfg.ui_battle_log_toggle_seconds
	cfg.ui_battle_log_toggle_seconds = 0.0
	var scroller: BattleLogScroller = battle.get_node("%LogScroller") as BattleLogScroller
	var log_panel: BattleLog = battle.get_node("%BattleLog") as BattleLog
	scroller.setup(log_panel, cfg, null)
	log_panel.push_line("探针一", BattleLog.LineKind.SYSTEM)
	log_panel.push_line("探针二", BattleLog.LineKind.SYSTEM)
	log_panel.push_line("探针三", BattleLog.LineKind.SYSTEM)
	assert_int(scroller.get_unread_count()).is_equal(3)
	assert_str((battle.get_node("%AnchorLabel") as Label).text).is_equal("战斗日志 (3)")
	scroller.set_expanded(true)
	assert_int(scroller.get_unread_count()).is_equal(0)
	assert_str((battle.get_node("%AnchorLabel") as Label).text).is_equal("战斗日志 (0)")
	log_panel.push_line("展开态条目", BattleLog.LineKind.SYSTEM)
	assert_int(scroller.get_unread_count()).is_equal(0) \
			.override_failure_message("展开态新条目不应计未读")
	scroller.set_expanded(false)
	assert_int(scroller.get_unread_count()).is_equal(0) \
			.override_failure_message("收起不应清未读（本例展开后为 0 维持）")
	log_panel.push_line("收起后条目", BattleLog.LineKind.SYSTEM)
	assert_int(scroller.get_unread_count()).is_equal(1)
	cfg.ui_battle_log_toggle_seconds = original_seconds

func test_enemy_hint_anchor_text_switch() -> void:
	## 用例⑨：敌方轮文案切换——active 锚点显提示语、false 恢复
	##「战斗日志 (N)」格式（battle_screen turn/ended 接线的组件级口径）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var scroller: BattleLogScroller = battle.get_node("%LogScroller") as BattleLogScroller
	var anchor_label: Label = battle.get_node("%AnchorLabel") as Label
	scroller.set_enemy_hint_active(true)
	assert_str(anchor_label.text).is_equal(HINT_TEXT)
	scroller.set_enemy_hint_active(false)
	assert_str(anchor_label.text).is_equal("战斗日志 (0)") \
			.override_failure_message("敌方提示解除后应恢复日志计数文案（实际 %s）" % anchor_label.text)

func test_degraded_run_scroller_not_blocking_idle_label() -> void:
	## 用例⑩：降级路径（无参直开）——卷轴在位保持收起；锚点条与 IdleLabel
	## 矩形不相交（不遮待机提示）；根 IGNORE 无输入拦截
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	await get_tree().process_frame
	var idle_label: Label = battle.get_node("%IdleLabel") as Label
	assert_bool(idle_label.visible).is_true() \
			.override_failure_message("降级路径 IdleLabel 应可见")
	var scroller: BattleLogScroller = battle.get_node("%LogScroller") as BattleLogScroller
	assert_bool(scroller.is_expanded()).is_false()
	assert_int(scroller.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var anchor_bar: PanelContainer = battle.get_node("%AnchorBar") as PanelContainer
	assert_bool(anchor_bar.get_global_rect().intersects(idle_label.get_global_rect())).is_false() \
			.override_failure_message("锚点条 %s 与 IdleLabel %s 矩形相交——降级态遮挡待机提示" % [
					anchor_bar.get_global_rect(), idle_label.get_global_rect()])

func test_battle_log_migration_zero_regression() -> void:
	## 用例⑪：BattleLog 迁移零回归——迁父后 push_line 条目正常入容器
	##（get_entries 计数递增；渲染/滚动链路由场景冒烟与日志套件覆盖）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var log_panel: BattleLog = battle.get_node("%BattleLog") as BattleLog
	assert_object(log_panel).is_not_null()
	assert_str(log_panel.get_parent().name).is_equal("ExpandPanel")
	var before: int = log_panel.get_entries().get_child_count()
	log_panel.push_line("迁移回归探针", BattleLog.LineKind.SYSTEM)
	await get_tree().process_frame
	assert_int(log_panel.get_entries().get_child_count()).is_equal(before + 1) \
			.override_failure_message("迁移后 push_line 未入容器（%d → %d）" % [
					before, log_panel.get_entries().get_child_count()])
