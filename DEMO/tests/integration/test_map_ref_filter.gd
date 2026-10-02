## 点位 map 归属字段化测试（M6 批 2 挂账 4.1）
## 覆盖：17 张点位表 map_ref 全回填；V-M3-map-points 扩展负注入（空值/
## 悬空归属）；V-M3-ref-quest-goal 扩展负注入（委托图与目标点归属不一致）；
## explore_board 图标层按图过滤；explore_screen 点位查询按图过滤（_PointAt/
## _TargetAt——_SecretDoorPointAt/_ApplySecretRevealIfNeeded 同构过滤表达式，
## 行为同源）。注入即恢复（共享实例卫生）。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## 探索场景路径（直开默认演示会话——首图自由探索）
const EXPLORE_SCENE: String = "res://scenes/explore/explore_screen.tscn"

## 套件级 GameData 实例
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData 并显式初始化
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

func test_map_ref_backfilled_on_all_points() -> void:
	## 数据回填契约：11 交互点 + 6 目标点 map_ref 全部 == 首图 id
	var interact_count: int = 0
	for record: Resource in _game_data.get_domain(&"map/interact_points"):
		var point := record as InteractPointDef
		assert_str(String(point.map_ref)).is_equal("map_m1_village_mine") \
				.override_failure_message("%s map_ref 未回填首图" % point.id)
		interact_count += 1
	assert_int(interact_count).is_equal(11)
	var target_count: int = 0
	for record: Resource in _game_data.get_domain(&"map/target_points"):
		var target := record as TargetPointDef
		assert_str(String(target.map_ref)).is_equal("map_m1_village_mine") \
				.override_failure_message("%s map_ref 未回填首图" % target.id)
		target_count += 1
	assert_int(target_count).is_equal(6)

func test_validator_empty_map_ref_caught() -> void:
	## V-M3-map-points 扩展①：map_ref 置空 → 报错；恢复归零
	var point: InteractPointDef = _game_data.get_record(&"evp_mine_01") as InteractPointDef
	var original: StringName = point.map_ref
	point.map_ref = &""
	var report: ValidationReport = DataValidator.run_all(_game_data)
	point.map_ref = original
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M3-map-points") and entry.contains("evp_mine_01") \
				and entry.contains("map_ref 为空"):
			matched = true
	assert_bool(matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_validator_dangling_map_ref_caught() -> void:
	## V-M3-map-points 扩展②：map_ref 指向不存在图 → 悬空归属报错；恢复归零
	var target: TargetPointDef = _game_data.get_record(&"tp_old_well") as TargetPointDef
	var original: StringName = target.map_ref
	target.map_ref = &"map_nope"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	target.map_ref = original
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M3-map-points") and entry.contains("tp_old_well") \
				and entry.contains("不在 map/maps 域"):
			matched = true
	assert_bool(matched).is_true()
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_validator_quest_map_mismatch_caught() -> void:
	## V-M3-ref-quest-goal 扩展：EXPLORE 判据委托图 ≠ 目标点归属图 →
	## 判据跨图不可达报错；恢复归零
	var quest: QuestTemplateDef = _game_data.get_record(&"q_lost_miner_keepsake") as QuestTemplateDef
	assert_object(quest).is_not_null()
	var original_map: StringName = quest.map_id
	quest.map_id = &"map_nope"
	var report: ValidationReport = DataValidator.run_all(_game_data)
	quest.map_id = original_map
	var matched: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M3-ref-quest-goal") and entry.contains(quest.id) \
				and entry.contains("不一致"):
			matched = true
	assert_bool(matched).is_true() \
			.override_failure_message("委托图与目标点归属不一致未被拦截")
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_validator_quest_empty_map_id_accurate_error() -> void:
	## 低17（盲审）：EXPLORE 委托 map_id 为空 → 按「map_id 为空」根因报错
	##（根因是委托未绑图，此前落「图不一致」误导文案指向目标点）；恢复归零
	var quest: QuestTemplateDef = _game_data.get_record(&"q_north_survey") as QuestTemplateDef
	assert_object(quest).is_not_null()
	var original_map: StringName = quest.map_id
	quest.map_id = &""
	var report: ValidationReport = DataValidator.run_all(_game_data)
	quest.map_id = original_map
	var empty_hit: bool = false
	var misleading: bool = false
	for entry: String in report.errors:
		if entry.begins_with("V-M3-ref-quest-goal") and entry.contains(quest.id):
			if entry.contains("map_id 为空"):
				empty_hit = true
			if entry.contains("不一致"):
				misleading = true
	assert_bool(empty_hit).is_true() \
			.override_failure_message("map_id 为空未被按根因拦截")
	assert_bool(misleading).is_false() \
			.override_failure_message("map_id 空时仍报「图不一致」误导文案（低17 未修）")
	assert_int(DataValidator.run_all(_game_data).errors.size()).is_equal(0)

func test_explore_board_icon_filter_by_map_ref() -> void:
	## explore_board 图标层过滤：当前图全部点位建图标；单点 map_ref 改假图后
	## 该点图标不再构建（他图点位不越权建标）；恢复
	var map_def: ExploreMapDef = _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef
	var state := ExploreMapState.new()
	state.setup(map_def, func(tile_id: StringName) -> ExploreTileDef:
		return _game_data.get_record(tile_id) as ExploreTileDef)
	var board := ExploreBoard.new()
	add_child(board)
	auto_free(board)
	board.setup(_game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig,
			map_def, state, _game_data)
	# M6 批 3.5b 组 4 适配：图标贴图态为 Control 根（非 Label），树扫 z 层
	# 会混入衬底 ColorRect——改按 _point_icons/_target_icons 字典尺寸直断
	var interact_icons: int = board._point_icons.size()
	var target_icons: int = board._target_icons.size()
	assert_int(interact_icons).is_equal(11)
	assert_int(target_icons).is_equal(6)
	# 过滤：宝箱点改挂他图 → 图标层 10 个（重建后；queue_free 延迟释放——
	# 等一帧再计数）
	var chest: InteractPointDef = _game_data.get_record(&"evp_mine_chest_01") as InteractPointDef
	var original: StringName = chest.map_ref
	chest.map_ref = &"map_other"
	board.setup(_game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig,
			map_def, state, _game_data)
	chest.map_ref = original
	await get_tree().process_frame
	var interact_after: int = board._point_icons.size()
	assert_int(interact_after).is_equal(10) \
			.override_failure_message("他图点位图标未被过滤（%d）" % interact_after)

func test_explore_screen_point_query_filter_by_map_ref() -> void:
	## explore_screen 点位查询过滤（直开默认演示会话）：当前图点位可查中；
	## 改挂他图后同格查询返回 null（_SecretDoorPointAt/_ApplySecretReveal
	## 同构过滤表达式——行为同源不另测）
	var runner: GdUnitSceneRunner = scene_runner(EXPLORE_SCENE)
	var screen: Control = runner.scene() as Control
	assert_object(screen).is_not_null()
	var point: InteractPointDef = _game_data.get_record(&"evp_mine_secret") as InteractPointDef
	assert_object(point).is_not_null()
	var hit_point: InteractPointDef = screen._PointAt(point.cell, point.trigger)
	assert_object(hit_point).is_not_null()
	assert_str(String(hit_point.id)).is_equal("evp_mine_secret")
	var target_point: TargetPointDef = _game_data.get_record(&"tp_old_well") as TargetPointDef
	var hit_target: TargetPointDef = screen._TargetAt(target_point.cell)
	assert_object(hit_target).is_not_null()
	assert_str(String(hit_target.id)).is_equal("tp_old_well")
	# 过滤：改挂他图 → 同格查询不再命中（恢复在后）
	var original_a: StringName = point.map_ref
	var original_b: StringName = target_point.map_ref
	point.map_ref = &"map_other"
	target_point.map_ref = &"map_other"
	assert_object(screen._PointAt(point.cell, point.trigger)).is_null()
	assert_object(screen._TargetAt(target_point.cell)).is_null()
	point.map_ref = original_a
	target_point.map_ref = original_b
	assert_str(String(screen._PointAt(point.cell, point.trigger).id)).is_equal("evp_mine_secret")
