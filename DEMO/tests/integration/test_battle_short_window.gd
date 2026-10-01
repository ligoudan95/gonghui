## 极矮窗口契约测试（M6 批 2 挂账 4.3：720px 最小窗口下战斗屏右栏完整可操作）
## 覆盖：project 最小窗口 1280×720 设置且不与双档视口冲突；右侧栏容器化结构
##（UnitInfoCard+BattleLog 收进 RightPanel ScrollContainer）；内容 min 高恒超
## 720 视口可用高（矮窗必然可滚——#24 同款先例）；模拟 1280×720 根尺寸后
## 右栏滚动可达 + 日志正尺寸 + 底栏不遮右栏；棋盘正尺寸；中4（盲审）：
## 竖滚动条占宽补偿契约（内容 min 宽让出条宽、右缘不裁）；低16（盲审）：
## 1280×600 嵌入视口监测档（编辑器嵌入不守最小窗——回归红灯）。
extends GdUnitTestSuite

## 战斗场景路径
const BATTLE_SCENE: String = "res://scenes/battle/battle_screen.tscn"

func test_project_minimum_window_settings() -> void:
	## project.godot 最小窗口契约：1280×720（不与双档 viewport 1440×900 冲突
	##——minimum ≤ viewport 双向断言）
	var min_width: int = int(ProjectSettings.get_setting(
			"display/window/size/minimum_width", 0))
	var min_height: int = int(ProjectSettings.get_setting(
			"display/window/size/minimum_height", 0))
	assert_int(min_width).is_equal(1280)
	assert_int(min_height).is_equal(720)
	var vp_width: int = int(ProjectSettings.get_setting(
			"display/window/size/viewport_width", 0))
	var vp_height: int = int(ProjectSettings.get_setting(
			"display/window/size/viewport_height", 0))
	assert_int(vp_width).is_equal(1440)
	assert_int(vp_height).is_equal(900)
	assert_bool(min_width <= vp_width and min_height <= vp_height).is_true() \
			.override_failure_message("最小窗口超双档视口——设置冲突")

func test_right_panel_container_structure() -> void:
	## 容器化结构契约：UnitInfoCard/BattleLog 均为 RightPanel/RightLayout 子节点
	##（极矮窗口改造收口——两栏不再各自锚定漂浮）；树序信息卡在日志上
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	var info_card: Control = battle.get_node("%UnitInfoCard")
	var log_panel: Control = battle.get_node("%BattleLog")
	assert_str(info_card.get_parent().name).is_equal("RightLayout")
	assert_str(log_panel.get_parent().name).is_equal("RightLayout")
	assert_str(log_panel.get_parent().get_parent().name).is_equal("RightPanel")
	assert_bool(info_card.get_index() < log_panel.get_index()).is_true()

func test_right_panel_content_min_exceeds_720_viewport() -> void:
	## 滚动必然性契约：信息卡点亮态下右栏内容 min 总高（180 + 间距 + 420 =
	## 608）恒大于 720 视口下右栏可用高（720 − 84 顶 − 108 底 = 528）——数值
	## 锚定，不依赖运行时视口（信息卡默认隐藏、show_unit 才点亮——隐藏子
	## 节点不进容器 min，测试显式点亮后量取）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var info_card: Control = battle.get_node("%UnitInfoCard")
	info_card.visible = true
	await get_tree().process_frame
	var layout: VBoxContainer = battle.get_node("%RightPanel/RightLayout") as VBoxContainer
	var combined_min: Vector2 = layout.get_combined_minimum_size()
	assert_float(combined_min.y).is_greater_equal(608.0) \
			.override_failure_message("右栏内容 min 高 %s 塌缩（预期 ≥608）" % combined_min)
	assert_bool(combined_min.y > 720.0 - 84.0 - 108.0).is_true() \
			.override_failure_message("720 视口下右栏内容不超高——滚动契约失效")

func test_short_window_right_panel_scrollable() -> void:
	## 模拟 1280×720 根尺寸 + 信息卡点亮态：右栏纵向滚动可达（v scroll bar
	## max > 0）——矮窗下右栏完整可操作的机制锚点
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	assert_object(battle).is_not_null()
	battle.get_node("%UnitInfoCard").visible = true
	battle.size = Vector2(1280.0, 720.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var right_panel: ScrollContainer = battle.get_node("%RightPanel") as ScrollContainer
	assert_object(right_panel).is_not_null()
	assert_float(right_panel.size.y).is_greater(500.0) \
			.override_failure_message("720 根尺寸下右栏高度异常（%s）" % right_panel.size)
	assert_float(right_panel.get_v_scroll_bar().max_value).is_greater(0.0) \
			.override_failure_message("矮窗下右栏不可滚动——内容被裁不可达")

func test_short_window_log_and_board_positive_size() -> void:
	## 模拟 1280×720 根尺寸：日志正尺寸（>200×200——六轮塌缩 BUG 防回归）
	## + 棋盘正尺寸（矮窗不挤塌左侧战场）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	battle.size = Vector2(1280.0, 720.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var log_panel: Control = battle.get_node("%BattleLog")
	assert_float(log_panel.size.y).is_greater(200.0) \
			.override_failure_message("矮窗日志高度塌缩（%s）" % log_panel.size)
	assert_float(log_panel.size.x).is_greater(200.0)
	var board: Control = battle.get_node("%BoardLayer")
	assert_float(board.size.x).is_greater(200.0)
	assert_float(board.size.y).is_greater(200.0) \
			.override_failure_message("矮窗棋盘高度塌缩（%s）" % board.size)

func test_short_window_bottom_bar_not_overlapping_right_panel() -> void:
	## 模拟 1280×720 根尺寸：右栏底边不与底栏顶边重叠（右栏 offset_bottom=-108
	## vs 底栏高 100——8px 呼吸带数值契约）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	battle.size = Vector2(1280.0, 720.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var right_panel: Control = battle.get_node("%RightPanel")
	var bottom_bar: Control = battle.get_node("BottomBar")
	assert_float(right_panel.get_end().y).is_less_equal(bottom_bar.position.y) \
			.override_failure_message("右栏底边 %s 越过底栏顶 %s——重叠遮挡" % [
					right_panel.get_end().y, bottom_bar.position.y])

func test_short_window_scrollbar_compensation_no_clip() -> void:
	## 中4（盲审）契约：720 矮窗竖滚动条出现时——①内容 min 宽 + 滚动条宽 ≤
	## 面板宽（补偿生效）；②日志右缘不越面板可视右缘（横滚禁用下越界即恒
	## 裁不可达——含面板右边框完整可见）。修法 = battle_screen 竖滚动条显隐
	## 动态补偿内容 min 宽（条宽让出，非 overlay 滚动条不再挤裁内容）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	battle.get_node("%UnitInfoCard").visible = true
	battle.size = Vector2(1280.0, 720.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var right_panel: ScrollContainer = battle.get_node("%RightPanel") as ScrollContainer
	var bar: VScrollBar = right_panel.get_v_scroll_bar()
	assert_bool(bar.is_visible_in_tree()).is_true() \
			.override_failure_message("720 矮窗右栏竖滚动条未出现——契约前置失效")
	var log_panel: PanelContainer = battle.get_node("%BattleLog") as PanelContainer
	# ① 补偿数值契约：内容 min 宽已让出滚动条宽
	assert_float(log_panel.custom_minimum_size.x + bar.size.x) \
			.is_less_equal(right_panel.size.x + 0.5) \
			.override_failure_message("内容 min 宽 %s + 滚动条宽 %s 超面板宽 %s——补偿未生效" % [
					log_panel.custom_minimum_size.x, bar.size.x, right_panel.size.x])
	# ② 视口层契约：日志右缘不越面板可视右缘（面板右缘 − 条宽）
	assert_float(log_panel.get_global_rect().end.x) \
			.is_less_equal(right_panel.get_global_rect().end.x - bar.size.x + 0.5) \
			.override_failure_message("BattleLog 右缘 %s 越可视右缘 %s——矮窗右缘恒裁不可达" % [
					log_panel.get_global_rect().end.x,
					right_panel.get_global_rect().end.x - bar.size.x])

func test_short_window_600_height_layout_monitor() -> void:
	## 低16（盲审）：<720 嵌入视口监测档（project 最小窗只约束独立运行窗——
	## 编辑器嵌入视口不守 1280×720，无兜底只能监测）：1280×600 下右栏仍可
	## 滚 + 日志右缘不裁 + 棋盘不塌（回归红灯；窗口管理属编辑器行为工程上
	## 不可控，见 battle_screen/project.godot 注）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	battle.get_node("%UnitInfoCard").visible = true
	battle.size = Vector2(1280.0, 600.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var right_panel: ScrollContainer = battle.get_node("%RightPanel") as ScrollContainer
	var bar: VScrollBar = right_panel.get_v_scroll_bar()
	assert_bool(bar.is_visible_in_tree()).is_true()
	assert_float(bar.max_value).is_greater(0.0) \
			.override_failure_message("600 嵌入视口右栏不可滚动")
	var log_panel: PanelContainer = battle.get_node("%BattleLog") as PanelContainer
	assert_float(log_panel.get_global_rect().end.x) \
			.is_less_equal(right_panel.get_global_rect().end.x - bar.size.x + 0.5) \
			.override_failure_message("600 嵌入视口日志右缘被裁（补偿未覆盖矮档）")
	var board: Control = battle.get_node("%BoardLayer")
	assert_float(board.size.x).is_greater(200.0)
	assert_float(board.size.y).is_greater(150.0) \
			.override_failure_message("600 嵌入视口棋盘高度塌缩（%s）" % board.size)
