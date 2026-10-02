## M6 批 3.5b 接线波组 1 背景契约测试（六屏）
## 覆盖：六屏 tscn BackgroundTexture 节点结构契约（KEEP_ASPECT_COVERED +
## 全矩形锚定 + mouse_filter 忽略——guild_shell 同构）/ 各屏 _ready 装配
##（贴图非空：title/guild_shell/association/宿舍/训练场/battle 降级/explore
## 演示会话）/ 缺件注入降级（texture 置空不崩——ColorRect 纯色兜底常驻）。
## 环境口径：gdUnit 帧内真 autoload（对齐 test_guild_shell_ui_contract 惯例）。
extends GdUnitTestSuite

## 六屏场景路径
const SCENE_PATHS: Array[String] = [
	"res://scenes/title/title_screen.tscn",
	"res://scenes/guild/guild_shell.tscn",
	"res://scenes/guild/association_screen.tscn",
	"res://scenes/guild/guild_dormitory.tscn",
	"res://scenes/guild/guild_training_ground.tscn",
	"res://scenes/battle/battle_screen.tscn",
	"res://scenes/explore/explore_screen.tscn",
]

func before_test() -> void:
	## 用例前置：复位 SceneManager 可变状态 + 出征锁 + GuildState 核心
	##（association/facility 的 RefreshAll/Refresh 消费 core——空核心会崩）
	## 参数：无
	## 返回：无
	AssetTex.clear_cache()
	var scene_manager: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_object(scene_manager).is_not_null()
	scene_manager.current_id = -1
	scene_manager.previous_id = -1
	var no_params: Dictionary = {}
	scene_manager.pending_params = no_params
	scene_manager._switch_pending = false
	var save_manager: Node = get_tree().root.get_node_or_null("SaveManager")
	if save_manager != null:
		save_manager.set_expedition_lock(false)
	var guild_state: Node = get_tree().root.get_node_or_null("GuildState")
	if guild_state != null:
		guild_state.core = GuildCore.new()

func after_test() -> void:
	## 用例后置：清纹理缓存 + 复位出征锁（explore 会话持锁防泄漏）
	## 参数：无
	## 返回：无
	AssetTex.clear_cache()
	var save_manager: Node = get_tree().root.get_node_or_null("SaveManager")
	if save_manager != null:
		save_manager.set_expedition_lock(false)

func _WaitFrames(frames: int) -> void:
	## 帧等待助手
	## 参数 frames：帧数
	## 返回：无（协程）
	for _i: int in frames:
		await get_tree().process_frame

func test_all_scene_background_texture_node_contract() -> void:
	## 结构契约：六屏 tscn 均含 BackgroundTexture（Background ColorRect 之下、
	## KEEP_ASPECT_COVERED + 全矩形锚定 + mouse_filter 忽略——guild_shell
	## BackgroundTexture 同构；纯色兜底 ColorRect 常驻）
	for scene_path: String in SCENE_PATHS:
		var packed: PackedScene = load(scene_path) as PackedScene
		assert_object(packed).is_not_null()
		var root: Node = packed.instantiate()
		auto_free(root)
		var texture_rect: TextureRect = root.get_node("%BackgroundTexture") as TextureRect
		assert_object(texture_rect).is_not_null() \
				.override_failure_message("%s 缺 BackgroundTexture" % scene_path)
		assert_int(texture_rect.stretch_mode) \
				.is_equal(TextureRect.STRETCH_KEEP_ASPECT_COVERED)
		assert_int(texture_rect.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		assert_float(texture_rect.anchor_right).is_equal(1.0)
		assert_float(texture_rect.anchor_bottom).is_equal(1.0)
		var background: ColorRect = texture_rect.get_parent() as ColorRect
		assert_object(background).is_not_null()

func test_title_screen_background_applied_and_missing_fallback() -> void:
	## 标题屏装配：_ready 后 bg_title 贴图就位；缺件注入重调 → texture 置空
	## 不崩（ColorRect 纯色兜底常驻——缺登记 warning 单次不刷屏）
	var runner: GdUnitSceneRunner = scene_runner(SCENE_PATHS[0])
	await _WaitFrames(2)
	var screen: Control = runner.scene() as Control
	var texture_rect: TextureRect = screen.get_node("%BackgroundTexture") as TextureRect
	assert_object(texture_rect.texture).is_not_null()
	# 缺件注入降级：缓存写 null 重调——纯色兜底
	AssetTex._cache[&"bg_title"] = null
	screen._ApplyBackgroundTexture()
	assert_object(texture_rect.texture).is_null()
	AssetTex.clear_cache()
	screen._ApplyBackgroundTexture()
	assert_object(texture_rect.texture).is_not_null()

func test_guild_shell_background_thin_forward_and_gold_icon() -> void:
	## 公会壳：薄转发装配（bg_guild_hall 非空）+ 顶栏金行 HBox 图标
	##（icon_res_gold 非空、GoldLabel 文本逻辑不动）
	var runner: GdUnitSceneRunner = scene_runner(SCENE_PATHS[1])
	await _WaitFrames(2)
	var shell: Control = runner.scene() as Control
	var texture_rect: TextureRect = shell.get_node("%BackgroundTexture") as TextureRect
	assert_object(texture_rect.texture).is_not_null()
	var gold_icon: TextureRect = shell.get_node("%GoldIcon") as TextureRect
	assert_object(gold_icon).is_not_null()
	assert_object(gold_icon.texture).is_not_null()
	assert_bool(gold_icon.visible).is_true()
	var gold_label: Label = shell.get_node("%GoldLabel") as Label
	assert_object(gold_label).is_not_null()

func test_association_and_facility_backgrounds_applied() -> void:
	## 协会屏 + 设施两屏：bg_association_hall / 表驱动 bg_asset_id（宿舍
	## bg_dormitory、训练场 bg_training_ground——FacilityDef 单源）装配非空
	var assoc_runner: GdUnitSceneRunner = scene_runner(SCENE_PATHS[2])
	await _WaitFrames(2)
	var assoc: Control = assoc_runner.scene() as Control
	assert_object((assoc.get_node("%BackgroundTexture") as TextureRect).texture) \
			.is_not_null()
	for scene_path: String in [SCENE_PATHS[3], SCENE_PATHS[4]]:
		var runner: GdUnitSceneRunner = scene_runner(scene_path)
		await _WaitFrames(2)
		var screen: Control = runner.scene() as Control
		assert_object((screen.get_node("%BackgroundTexture") as TextureRect).texture) \
				.is_not_null() \
				.override_failure_message("%s 背景贴图未装配" % scene_path)

func test_battle_screen_background_on_degraded_open() -> void:
	## 战斗屏降级路径（无战斗参数直开）：背景与战斗装配解耦——
	## bg_battle_mine 照常装配
	var runner: GdUnitSceneRunner = scene_runner(SCENE_PATHS[5])
	await _WaitFrames(2)
	var screen: Control = runner.scene() as Control
	assert_object((screen.get_node("%BackgroundTexture") as TextureRect).texture) \
			.is_not_null()

func test_explore_screen_background_on_demo_session() -> void:
	## 探索屏演示会话（无跨场景参数——默认队自由探索）：bg_explore 装配非空
	var runner: GdUnitSceneRunner = scene_runner(SCENE_PATHS[6])
	await _WaitFrames(3)
	var screen: Control = runner.scene() as Control
	assert_object((screen.get_node("%BackgroundTexture") as TextureRect).texture) \
			.is_not_null()
