## 探索屏显示层级契约测试（2026-09-25 用户拍板层级修复）
## 覆盖：UI 弹层 z 高于 board 全部绘制层（事件面板不再被迷雾穿透——z_index
## 在 CanvasLayer 内跨子树全局生效的回归锚点）/ PanelHost 树序与类型（全屏
## 居中容器、EventPanel 挂其下且限宽弹窗化）/ board 内部 z 序（迷雾盖已探索
## 内容图标、常显目标点+衬底与小队在迷雾之上）/ 底部间距 ≥12。
## 环境：gdUnit 帧内真 autoload（GameData/SaveManager/SceneManager）。
extends GdUnitTestSuite

## 探索屏场景路径
const EXPLORE_SCENE: String = "res://scenes/explore/explore_screen.tscn"
## explore_screen 脚本常量引用（UI_POPUP_Z_INDEX 单源锚点）
const ExploreScreenScript: GDScript = \
		preload("res://scripts/scene_flow/explore_screen.gd")

func before_test() -> void:
	## 用例前置：复位 SceneManager 可变状态 + 出征锁
	## 参数：无
	## 返回：无
	var scene_manager: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_object(scene_manager).is_not_null()
	scene_manager.current_id = -1
	scene_manager.previous_id = -1
	var no_params: Dictionary = {}
	scene_manager.pending_params = no_params
	get_tree().root.get_node("SaveManager").set_expedition_lock(false)

func _WaitFrames(frames: int) -> void:
	## 帧等待助手
	## 参数 frames：帧数
	## 返回：无（协程）
	for _i: int in frames:
		await get_tree().process_frame

func _OpenExploreScreen() -> Control:
	## 挂载探索屏（q_lair_purge 委托会话——板面全量装配交互点/目标点/迷雾）
	## 参数：无
	## 返回：场景根 Control
	var game_data: Node = get_tree().root.get_node("GameData")
	var cfg: CoreConfig = game_data.get_record(&"cfg_main") as CoreConfig
	var run := ExpeditionRun.new()
	var adv: AdventurerData = AdventurerData.create_debug(&"t", &"cls_warrior", {
			&"strength": 14, &"agility": 10, &"constitution": 14,
			&"intelligence": 7, &"perception": 15, &"willpower": 9, &"luck": 9},
			game_data)
	run.party.append(adv)
	run.hp[adv] = 30
	var map_def: ExploreMapDef = game_data.get_record(&"map_m1_village_mine") \
			as ExploreMapDef
	run.start_explore(map_def, game_data.get_record(&"q_lair_purge") \
			as QuestTemplateDef, cfg.vision_radius)
	get_tree().root.get_node("SceneManager").pending_params = \
			{&"expedition_run": run}
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	await _WaitFrames(2)
	return runner.scene() as Control

func test_ui_popup_z_above_all_board_layers() -> void:
	## UI 弹层契约：事件面板宿主与结算面板 z == UI_POPUP_Z_INDEX 单源值，
	## 恒高于 board 全部绘制层（Z_PARTY 为 board 内最高层）
	var screen: Control = await _OpenExploreScreen()
	var panel_host: Control = screen.get_node("%PanelHost")
	var settlement: Control = screen.get_node("%SettlementPanel")
	assert_int(panel_host.z_index).is_equal(ExploreScreenScript.UI_POPUP_Z_INDEX)
	assert_int(settlement.z_index).is_equal(ExploreScreenScript.UI_POPUP_Z_INDEX)
	assert_int(panel_host.z_index).is_greater(ExploreBoard.Z_PARTY)
	assert_int(settlement.z_index).is_greater(ExploreBoard.Z_PARTY)

func test_panel_host_after_layout_and_fullscreen_centered() -> void:
	## PanelHost 树序在 Layout（board 宿主子树）之后 + 全屏居中容器类型
	## （EventPanel 弹窗化：面板在容器内限宽居中，不裸浮压全屏）
	var screen: Control = await _OpenExploreScreen()
	var layout: Node = screen.get_node("Layout")
	var panel_host: Control = screen.get_node("%PanelHost")
	assert_bool(panel_host is CenterContainer).is_true()
	assert_int(panel_host.get_index()).is_greater(layout.get_index())
	assert_int(panel_host.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	# 事件面板挂接在 PanelHost 之下且限宽（宽度上限 < 设计屏宽 1920）
	assert_bool(screen._panel.get_parent() == panel_host).is_true()
	assert_int(int(screen._panel.custom_minimum_size.x)) \
			.is_equal(ExploreScreenScript.EVENT_PANEL_WIDTH)
	assert_int(int(screen._panel.custom_minimum_size.x)).is_less(1920)

func test_board_fog_over_content_icons() -> void:
	## board 内部契约①：迷雾 z(Z_FOG) 画在已探索内容图标(Z_CONTENT)之上
	## （DIM 态半透明压暗记忆格图标——遮挡规则不再颠倒）
	var screen: Control = await _OpenExploreScreen()
	for icon: Label in screen._board._point_icons.values():
		assert_int(icon.z_index).is_equal(ExploreBoard.Z_CONTENT)
		assert_int(icon.z_index).is_less(ExploreBoard.Z_FOG)
	for overlay: ColorRect in screen._board._fog_rects.values():
		assert_int(overlay.z_index).is_equal(ExploreBoard.Z_FOG)
	# 底格仍在最底
	for panel: Panel in screen._board._cell_panels.values():
		assert_int(panel.z_index).is_equal(ExploreBoard.Z_TILE)
		assert_int(panel.z_index).is_less(ExploreBoard.Z_FOG)

func test_board_overlay_and_party_above_fog() -> void:
	## board 内部契约②：常显目标点图标+衬底(Z_OVERLAY) 与小队图标(Z_PARTY)
	## 在迷雾之上（拍板例外：目标点常显带衬底、视野内小队可见）——但恒低于
	## UI 弹层 z
	var screen: Control = await _OpenExploreScreen()
	assert_int(screen._board._party_icon.z_index).is_equal(ExploreBoard.Z_PARTY)
	for tp_id: StringName in screen._board._target_icons:
		var icon: Label = screen._board._target_icons[tp_id]
		var backdrop: ColorRect = screen._board._target_backdrops[tp_id]
		assert_int(icon.z_index).is_equal(ExploreBoard.Z_OVERLAY)
		assert_int(backdrop.z_index).is_equal(ExploreBoard.Z_OVERLAY)
		assert_int(icon.z_index).is_greater(ExploreBoard.Z_FOG)
		# 衬底同格同层、树序在图标之前（垫图标之下）且内缩不顶格线
		assert_bool(backdrop.position == icon.position
				+ Vector2.ONE * float(ExploreBoard.BACKDROP_INSET)).is_true()
		assert_bool(backdrop.get_index() < icon.get_index()).is_true()
	# board 内最高层仍低于 UI 弹层
	assert_int(ExploreBoard.Z_PARTY) \
			.is_less(ExploreScreenScript.UI_POPUP_Z_INDEX)

func test_bottom_vertical_spacing_at_least_12() -> void:
	## 底部三元素间距：Layout 行距 ≥12（板面底缘/提示行/撤退按钮互不黏连）
	var screen: Control = await _OpenExploreScreen()
	var layout: VBoxContainer = screen.get_node("Layout") as VBoxContainer
	assert_int(layout.get_theme_constant("separation")).is_greater_equal(12)
