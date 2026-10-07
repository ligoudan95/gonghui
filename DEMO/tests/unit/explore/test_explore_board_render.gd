## 探索板渲染镜像与适配契约测试（三栏改版批——C2 拍板 (b) 渲染镜像 + C7 放宽上限；
## 2026-10-03 试玩反馈批增：目标点仅绑定渲染〔批 A〕+ 矿洞段可通行格染色〔批 B〕）
## 覆盖：镜像正映射（数据 y=0〔北/村口〕绘于屏幕下方——出口贴底/北行靠下/
## 南北翻转序）/ 全图 round-trip（cell_from_local 与 _cell_origin 互逆——点按
## 命中与绘制落位同口径）/ fit 上限参数化（cfg 表值 1.2 生效 + cfg 缺省回退
## UiTheme 兜底）/ 目标点可见性（绑定金色渲染·未绑定与自由探索全隐藏）/
## 矿洞染色（可通行格淡鹅黄·岩壁与村子段不染·cfg 缺省回退兜底）。
## 环境与形态：帧内真 autoload（GameData——layering 先例），板面直注构建
## （不经场景——镜像映射与适配是纯逻辑）。
extends GdUnitTestSuite

## 直注构建的板面实例池（after_test 统一释放——未挂树节点测试框架不回收）
var _boards: Array[ExploreBoard] = []

func after_test() -> void:
	## 用例级后置：释放直注构建的板面（225 格级子节点——防 orphan 计数）
	## 参数：无
	## 返回：无
	for board: ExploreBoard in _boards:
		board.free()
	_boards.clear()

func _MakeBoard(cfg: CoreConfig) -> ExploreBoard:
	## 直注构建板面（setup 手动装配——cfg 可空 = 兜底模式）
	## 参数 cfg：总控配置（null = 走 UiTheme 兜底）
	## 返回：装配完成的 ExploreBoard（未挂树）
	var game_data: Node = get_tree().root.get_node("GameData")
	var map_def: ExploreMapDef = game_data.get_record(&"map_m1_village_mine") \
			as ExploreMapDef
	var state := ExploreMapState.new()
	state.setup(map_def, func(tile_id: StringName) -> ExploreTileDef:
		return game_data.get_record(tile_id) as ExploreTileDef)
	var board := ExploreBoard.new()
	board.setup(cfg, map_def, state, game_data)
	_boards.append(board)
	return board

func test_mirror_cell_origin_north_at_bottom() -> void:
	## 镜像正映射：数据 (7,0)〔北缘出口〕绘制原点 y == 14 行贴底；
	## (7,1)〔出生行〕== 13 行；(0,0) 绘制低于 (0,14)〔南北翻转序〕
	var board: ExploreBoard = _MakeBoard(get_tree().root.get_node("GameData") \
			.get_record(&"cfg_main") as CoreConfig)
	assert_float(board._cell_origin(Vector2i(7, 0)).y) \
			.is_equal_approx(14.0 * float(ExploreBoard.CELL_SIZE), 0.01) \
			.override_failure_message("北缘出口 (7,0) 应绘于板面最下行")
	assert_float(board._cell_origin(Vector2i(7, 1)).y) \
			.is_equal_approx(13.0 * float(ExploreBoard.CELL_SIZE), 0.01)
	assert_float(board._cell_origin(Vector2i(0, 0)).y) \
			.is_greater(board._cell_origin(Vector2i(0, 14)).y) \
			.override_failure_message("数据 y=0 应绘制在 y=14 之下（南北翻转）")
	assert_float(board._cell_origin(Vector2i(3, 0)).x) \
			.is_equal_approx(3.0 * float(ExploreBoard.CELL_SIZE), 0.01) \
			.override_failure_message("镜像只翻 y——x 恒等")

func test_mirror_round_trip_all_cells() -> void:
	## 全图 225 格 round-trip：cell_from_local(_cell_origin(c)+格心偏移) == c
	##（命中反解与正映射互逆——点按命中格 == 绘制格，镜像不破点按）
	var board: ExploreBoard = _MakeBoard(get_tree().root.get_node("GameData") \
			.get_record(&"cfg_main") as CoreConfig)
	var mismatches: int = 0
	for y: int in board._map_def.size.y:
		for x: int in board._map_def.size.x:
			var cell: Vector2i = Vector2i(x, y)
			var hit: Vector2i = board.cell_from_local(
					board._cell_origin(cell) + Vector2(30.0, 30.0))
			if hit != cell:
				mismatches += 1
	assert_int(mismatches).is_equal(0) \
			.override_failure_message("镜像 round-trip 破裂（命中格 != 绘制格）")
	assert_int(board._map_def.size.x * board._map_def.size.y).is_equal(225)

func test_fit_cap_from_cfg_table() -> void:
	## fit 上限参数化：cfg 表值 1.2 生效——超大宿主下 scale == 1.2（放宽后
	## 满高放大介入；原上限 1.0 恒不放大回归锚）
	var board: ExploreBoard = _MakeBoard(get_tree().root.get_node("GameData") \
			.get_record(&"cfg_main") as CoreConfig)
	board.fit_to(Vector2(2000, 2000))
	assert_float(board.scale.x).is_equal_approx(1.2, 0.001) \
			.override_failure_message("cfg 表值上限 1.2 应生效（放大介入）")
	assert_float(board.scale.y).is_equal_approx(1.2, 0.001)

func test_fit_cap_fallback_without_cfg() -> void:
	## fit 上限缺省回退：cfg == null 时走 UiTheme.EXPLORE_BOARD_FIT_MAX 兜底
	##（表值与兜底同值锚定另见 DataValidator V-B2-cfg-fallback）
	var board: ExploreBoard = _MakeBoard(null)
	board.fit_to(Vector2(2000, 2000))
	assert_float(board.scale.x) \
			.is_equal_approx(UiTheme.EXPLORE_BOARD_FIT_MAX, 0.001) \
			.override_failure_message("cfg 缺省应回退 UiTheme 兜底上限")

func _Cfg() -> CoreConfig:
	## 取 cfg_main 表值（染色/高亮断言的表驱动基准）
	## 参数：无
	## 返回：CoreConfig
	return get_tree().root.get_node("GameData").get_record(&"cfg_main") as CoreConfig

func test_target_icons_bound_only_visible() -> void:
	## 目标点可见性契约（2026-10-03 试玩反馈批 A——原非绑定灰显推翻）：
	## refresh 绑定 tp_old_well——仅该点图标+衬底可见且金色高亮，其余 5 目标点
	## 完全隐藏；构建期（refresh 前）默认全隐藏（首帧不闪现）
	var cfg: CoreConfig = _Cfg()
	var active: Color = UiTheme.color_of(cfg, &"ui_explore_target_active_color",
			UiTheme.EXPLORE_TARGET_ACTIVE)
	var board: ExploreBoard = _MakeBoard(cfg)
	# 构建期默认隐藏（首帧 refresh 前不闪现未绑定图标）
	for tp_id: StringName in board._target_icons:
		assert_bool(board._target_icons[tp_id].visible).is_false() \
				.override_failure_message("%s 构建期应默认隐藏" % tp_id)
	# 绑定刷新：仅绑定目标渲染
	board.refresh(Vector2i(7, 1), null, {}, {}, &"tp_old_well", false)
	assert_bool(board._target_icons[&"tp_old_well"].visible).is_true()
	assert_bool(board._target_backdrops[&"tp_old_well"].visible).is_true()
	assert_bool(board._target_icons[&"tp_old_well"].modulate.is_equal_approx(active)).is_true()
	for tp_id: StringName in [&"tp_mine_east_gallery", &"tp_mine_north_wall",
			&"tp_mine_south_shaft", &"tp_mine_west_camp", &"tp_mine_track_yard"]:
		assert_bool(board._target_icons[tp_id].visible).is_false() \
				.override_failure_message("%s 未绑定目标点应隐藏" % tp_id)
		assert_bool(board._target_backdrops[tp_id].visible).is_false() \
				.override_failure_message("%s 未绑定目标点衬底应隐藏" % tp_id)

func test_target_icons_free_explore_all_hidden() -> void:
	## 自由探索契约（试玩反馈批 A）：active_tp_id 为空——全部目标点（含衬底）
	## 不显示（无委托会话板面无目标点）
	var board: ExploreBoard = _MakeBoard(_Cfg())
	board.refresh(Vector2i(7, 1), null, {}, {}, &"", true)
	for tp_id: StringName in board._target_icons:
		assert_bool(board._target_icons[tp_id].visible).is_false() \
				.override_failure_message("自由探索 %s 应隐藏" % tp_id)
		assert_bool(board._target_backdrops[tp_id].visible).is_false()

func test_mine_walkable_tint_and_others_untinted() -> void:
	## 矿洞段染色契约（试玩反馈批 B）：矿洞可通行格（地面/毒沼）modulate
	## 淡鹅黄；不可通行岩壁与村子段（fog_lit_rows 全亮行）不染（WHITE 原色）
	var cfg: CoreConfig = _Cfg()
	var tint: Color = UiTheme.color_of(cfg, &"ui_explore_mine_walk_tint_color",
			UiTheme.EXPLORE_MINE_WALK_TINT)
	var board: ExploreBoard = _MakeBoard(cfg)
	# 矿洞段可通行：地面 (1,4) 与毒沼 (13,5)（可通行——同染口径）
	assert_bool(board._cell_panels[Vector2i(1, 4)].modulate.is_equal_approx(tint)) \
			.override_failure_message("矿洞地面格应染淡鹅黄").is_true()
	assert_bool(board._cell_panels[Vector2i(13, 5)].modulate.is_equal_approx(tint)) \
			.override_failure_message("矿洞毒沼格（可通行）应染淡鹅黄").is_true()
	# 不可通行：岩壁 (0,3) 不染
	assert_bool(board._cell_panels[Vector2i(0, 3)].modulate.is_equal_approx(Color.WHITE)) \
			.override_failure_message("岩壁格（不可通行）不应染色").is_true()
	# 村子段（全亮行）：地面 (0,0) 与障碍水井 (4,0) 均不染
	assert_bool(board._cell_panels[Vector2i(0, 0)].modulate.is_equal_approx(Color.WHITE)) \
			.override_failure_message("村子地面格不应染色").is_true()
	assert_bool(board._cell_panels[Vector2i(4, 0)].modulate.is_equal_approx(Color.WHITE)) \
			.override_failure_message("村子水井格（障碍）不应染色").is_true()

func test_mine_walk_tint_fallback_without_cfg() -> void:
	## 矿洞染色缺省回退：cfg == null 时走 UiTheme.EXPLORE_MINE_WALK_TINT 兜底
	##（表值与兜底同值锚定另见 DataValidator V-B2-cfg-fallback）
	var board: ExploreBoard = _MakeBoard(null)
	assert_bool(board._cell_panels[Vector2i(1, 4)].modulate
			.is_equal_approx(UiTheme.EXPLORE_MINE_WALK_TINT)) \
			.override_failure_message("cfg 缺省应回退 UiTheme 兜底染色").is_true()
	assert_bool(board._cell_panels[Vector2i(0, 0)].modulate.is_equal_approx(Color.WHITE)) \
			.override_failure_message("cfg 缺省下村子段仍不染").is_true()
