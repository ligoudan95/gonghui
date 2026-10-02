## M6 批 3.5b 接线波组件级契约测试（组 2-8）
## 覆盖：探索 tile 贴图分支/降级（组 2）、战棋 tile 贴图/陷阱标记两态（组 3）、
## 交互图标 _MakeIconNode 两态与 KIND_ICONS 映射（组 4）、迷雾懒挂贴图与
## refresh 三态选图（组 5）、系统图标（金行/奖励行/属性行/状态行/职业图标——
## 组 6）、九宫格 StyleBoxTexture 切换（组 7）、选中框/范围叠加/D20 与四档
## 底图容器（组 8）。缺件注入复用 test_asset_tex 模式（缓存写 null + 还原）。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## 测试地图 id（村矿图——floor/wall/path/ground 混合）
const MAP_ID: StringName = &"map_m1_village_mine"

## 套件级 GameData 实例
var _game_data: Node
## 总控配置
var _cfg: CoreConfig

func before() -> void:
	## 套件前置：实例化 GameData 并显式初始化
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()
	_cfg = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig

func before_test() -> void:
	## 用例前置：清纹理缓存（含缺件 null 驻留——用例间隔离）
	## 参数：无
	## 返回：无
	AssetTex.clear_cache()

func after() -> void:
	## 套件后置：清纹理缓存（防污染后续套件）
	## 参数：无
	## 返回：无
	AssetTex.clear_cache()

func _InjectMissing(asset_id: StringName) -> void:
	## 缺件注入（缓存写 null——模拟 registry 缺登记/加载失败）
	## 参数 asset_id：资产 id
	## 返回：无
	AssetTex._cache[asset_id] = null

func _MakeExploreBoard() -> ExploreBoard:
	## 构建挂树探索板（真图装配——村矿图 + 真实点位/迷雾层）
	## 参数：无
	## 返回：已 setup 的 ExploreBoard（auto_free 释放）
	var map_def: ExploreMapDef = _game_data.get_record(MAP_ID) as ExploreMapDef
	var state := ExploreMapState.new()
	state.setup(map_def, func(tile_id: StringName) -> ExploreTileDef:
			return _game_data.get_record(tile_id) as ExploreTileDef)
	var board := ExploreBoard.new()
	add_child(board)
	auto_free(board)
	board.setup(_cfg, map_def, state, _game_data)
	return board

func _MakeRun() -> ExpeditionRun:
	## 构建探索运行态（单成员 + 村矿图自由探索——迷雾三态驱动源）
	## 参数：无
	## 返回：ExpeditionRun
	var run := ExpeditionRun.new()
	var adv: AdventurerData = AdventurerData.create_debug(&"t", &"cls_warrior", {
			&"strength": 14, &"agility": 10, &"constitution": 14,
			&"intelligence": 7, &"perception": 15, &"willpower": 9, &"luck": 9},
			_game_data)
	run.party.append(adv)
	run.hp[adv] = 30
	var map_def: ExploreMapDef = _game_data.get_record(MAP_ID) as ExploreMapDef
	run.start_explore(map_def, null, _cfg.vision_radius)
	return run

# --------------------------------------------------------------------------
# 组 2 探索 tile
# --------------------------------------------------------------------------

func test_explore_tile_texture_branch() -> void:
	## 贴图分支：真图装配后底格层出现贴图格（TextureRect 根——STRETCH_SCALE
	## 满格、z=Z_TILE、贴图非空）；值类型泛化 Control 全格 z 契约
	var board: ExploreBoard = _MakeExploreBoard()
	var texture_cells: int = 0
	for cell: Vector2i in board._cell_panels:
		var visual: Control = board._cell_panels[cell]
		assert_int(visual.z_index).is_equal(ExploreBoard.Z_TILE)
		if visual is TextureRect:
			texture_cells += 1
			var rect: TextureRect = visual as TextureRect
			assert_object(rect.texture).is_not_null()
			assert_int(rect.stretch_mode).is_equal(TextureRect.STRETCH_SCALE)
			assert_bool(rect.size == Vector2.ONE * float(ExploreBoard.CELL_SIZE)).is_true()
	assert_int(texture_cells).is_greater(0)

func test_explore_tile_fallback_panel_branch() -> void:
	## 缺件降级：floor 双变体注入 null 后装配——floor 格回落现状 Panel 色块
	##（_TileStyleOf 分支），z 契约不变（占位态视觉零回归）
	_InjectMissing(&"tile_mine_floor_01")
	_InjectMissing(&"tile_mine_floor_02")
	var board: ExploreBoard = _MakeExploreBoard()
	var panel_cells: int = 0
	for cell: Vector2i in board._cell_panels:
		if board._cell_panels[cell] is Panel:
			panel_cells += 1
	assert_int(panel_cells).is_greater(0)

func test_explore_tile_rebuild_hides_old_layer_instantly() -> void:
	## 重建型刷新一帧叠显契约（循环盲审修复②，S4-R3-01 同式）：refresh_tiles
	##（暗门揭示重建路径）发起帧旧底格层立即不可见（queue_free 延迟帧末——
	## 修复前旧层与新层同帧叠渲一帧）；新层计数与图幅一致
	var board: ExploreBoard = _MakeExploreBoard()
	var map_def: ExploreMapDef = _game_data.get_record(MAP_ID) as ExploreMapDef
	var old_panels: Array[Control] = []
	for cell: Vector2i in board._cell_panels:
		old_panels.append(board._cell_panels[cell])
	board.refresh_tiles()
	# 旧层：仍挂树待帧末释放，但发起帧立即隐藏（不可见）
	for old_visual: Control in old_panels:
		assert_bool(old_visual.is_queued_for_deletion()) \
				.override_failure_message("旧底格应已排队释放").is_true()
		assert_bool(old_visual.visible) \
				.override_failure_message("重建发起帧旧底格应立即隐藏（一帧叠显）").is_false()
	# 新层：计数与图幅一致且可见
	assert_int(board._cell_panels.size()) \
			.is_equal(map_def.size.x * map_def.size.y)
	for cell: Vector2i in board._cell_panels:
		var fresh_visual: Control = board._cell_panels[cell]
		assert_bool(fresh_visual.visible) \
				.override_failure_message("新底格应可见").is_true()

func test_explore_setup_rebuild_hides_old_children_instantly() -> void:
	## setup 全量重建一帧叠显契约（循环盲审第三轮修复①，S4-R3-01 同式——
	## _BuildTileLayer 先例补齐到 setup 清场循环）：重复 setup 发起帧旧子节点
	##（底格/迷雾/图标全层）立即不可见（queue_free 延迟帧末——修复前旧板面
	## 与重建层同帧叠渲一帧）；新板面全层重建且可见
	var board: ExploreBoard = _MakeExploreBoard()
	var old_children: Array[Node] = []
	for child: Node in board.get_children():
		old_children.append(child)
	assert_int(old_children.size()).is_greater(0)
	var map_def: ExploreMapDef = _game_data.get_record(MAP_ID) as ExploreMapDef
	var state := ExploreMapState.new()
	state.setup(map_def, func(tile_id: StringName) -> ExploreTileDef:
			return _game_data.get_record(tile_id) as ExploreTileDef)
	board.setup(_cfg, map_def, state, _game_data)
	# 旧子节点：仍挂树待帧末释放，但发起帧立即隐藏（不可见）
	for old_child: Node in old_children:
		assert_bool(old_child.is_queued_for_deletion()) \
				.override_failure_message("旧板面子节点应已排队释放").is_true()
		var old_visual: CanvasItem = old_child as CanvasItem
		if old_visual != null:
			assert_bool(old_visual.visible) \
					.override_failure_message("重建发起帧旧子节点应立即隐藏（一帧叠显）").is_false()
	# 新板面：全层重建（底格计数 == 图幅）且可见
	assert_int(board._cell_panels.size()) \
			.is_equal(map_def.size.x * map_def.size.y)
	for cell: Vector2i in board._cell_panels:
		var fresh_tile: Control = board._cell_panels[cell]
		assert_bool(fresh_tile.visible) \
				.override_failure_message("新底格应可见").is_true()

# --------------------------------------------------------------------------
# 组 4 交互图标
# --------------------------------------------------------------------------

func test_kind_icons_mapping_contract() -> void:
	## KIND_ICONS 映射契约：链/单点 → 事件、宝箱/战斗/出口各归位；
	## SECRET_DOOR 无贴图位（不登记——维持字形降级）
	assert_str(String(ExploreBoard.KIND_ICONS[InteractPointDef.Kind.CHAIN])) \
			.is_equal("icon_pt_event")
	assert_str(String(ExploreBoard.KIND_ICONS[InteractPointDef.Kind.SINGLE])) \
			.is_equal("icon_pt_event")
	assert_str(String(ExploreBoard.KIND_ICONS[InteractPointDef.Kind.TREASURE])) \
			.is_equal("icon_pt_treasure")
	assert_str(String(ExploreBoard.KIND_ICONS[InteractPointDef.Kind.BATTLE])) \
			.is_equal("icon_pt_battle")
	assert_str(String(ExploreBoard.KIND_ICONS[InteractPointDef.Kind.EXIT])) \
			.is_equal("icon_pt_exit")
	assert_bool(ExploreBoard.KIND_ICONS.has(InteractPointDef.Kind.SECRET_DOOR)).is_false()

func test_make_icon_node_texture_branch() -> void:
	## 贴图分支：在档 id → 满格 Control 根 + 子 TextureRect（48 渲染居中——
	## (60−48)/2=6 偏移），modulate/visible 刷新逻辑 Control 泛化
	var board: ExploreBoard = _MakeExploreBoard()
	var icon: Control = board._MakeIconNode(&"icon_pt_treasure", "箱")
	auto_free(icon)
	assert_bool(icon is Control).is_true()
	assert_int(icon.get_child_count()).is_equal(1)
	var rect: TextureRect = icon.get_child(0) as TextureRect
	assert_object(rect).is_not_null()
	assert_object(rect.texture).is_not_null()
	assert_bool(rect.size == Vector2.ONE * ExploreBoard.ICON_RENDER_SIZE).is_true()
	assert_float(rect.position.x).is_equal(
			(float(ExploreBoard.CELL_SIZE) - ExploreBoard.ICON_RENDER_SIZE) * 0.5)

func test_make_icon_node_fallback_label() -> void:
	## 降级分支：空 id（SECRET_DOOR 位）与缺件 id → 现状 Label 字形
	var board: ExploreBoard = _MakeExploreBoard()
	var door_icon: Control = board._MakeIconNode(&"", "门")
	auto_free(door_icon)
	assert_bool(door_icon is Label).is_true()
	_InjectMissing(&"icon_pt_treasure")
	var chest_icon: Control = board._MakeIconNode(&"icon_pt_treasure", "箱")
	auto_free(chest_icon)
	assert_bool(chest_icon is Label).is_true()

func test_explore_icon_layers_texture_on_real_map() -> void:
	## 真图装配：点位/目标点/小队图标贴图态就位（贴图根或含 TextureRect 子），
	## modulate 灰态/金态刷新逻辑经 Control 泛化零改（refresh 不崩 + 目标点
	## 金态断言）
	var board: ExploreBoard = _MakeExploreBoard()
	var run: ExpeditionRun = _MakeRun()
	board.refresh(run.party_pos, run.fog, run.consumed_events, run.unlock_flags,
			"", false)
	var textured_points: int = 0
	for point_id: StringName in board._point_icons:
		var icon: Control = board._point_icons[point_id]
		if icon.get_child(0) is TextureRect:
			textured_points += 1
	assert_int(textured_points).is_greater(0)
	# 目标点常显与小队：贴图态含 TextureRect 子节点
	assert_bool(board._party_icon.get_child_count() > 0
			and board._party_icon.get_child(0) is TextureRect).is_true()
	for tp_id: StringName in board._target_icons:
		var icon: Control = board._target_icons[tp_id]
		assert_int(icon.z_index).is_equal(ExploreBoard.Z_OVERLAY)

# --------------------------------------------------------------------------
# 组 5 迷雾
# --------------------------------------------------------------------------

func test_fog_layer_lazy_texture_siblings() -> void:
	## 懒建契约（中2 结构：贴图与纯色兜底是兄弟节点——父 ColorRect
	## visible=false 会连带隐藏整棵子树，父子结构无法只显贴图）：fx 两键任一
	## 在档 → 每格 ColorRect 常驻（无子节点）+ 同格兄弟 TextureRect（初始
	## 隐藏——refresh 按态点亮；z/几何与纯色块同构）
	var board: ExploreBoard = _MakeExploreBoard()
	assert_int(board._fog_textures.size()).is_equal(board._fog_rects.size())
	for cell: Vector2i in board._fog_rects:
		var overlay: ColorRect = board._fog_rects[cell]
		assert_int(overlay.get_child_count()).is_equal(0)
		var fog_tex: TextureRect = board._fog_textures[cell]
		assert_bool(fog_tex.visible).is_false()
		assert_bool(fog_tex.get_parent() == board).is_true()
		assert_int(fog_tex.z_index).is_equal(ExploreBoard.Z_FOG)
		assert_bool(fog_tex.position == overlay.position).is_true()
		assert_bool(fog_tex.size == overlay.size).is_true()

func test_fog_missing_no_children() -> void:
	## 缺件降级：fx 两键注入 null → 不建贴图（纯色现状零回归——refresh
	## _ApplyFogTexture 早退不崩；父 ColorRect 恒显示承载纯色遮蔽）
	_InjectMissing(&"fx_fog_unseen")
	_InjectMissing(&"fx_fog_dim")
	var board: ExploreBoard = _MakeExploreBoard()
	assert_int(board._fog_textures.size()).is_equal(0)
	for cell: Vector2i in board._fog_rects:
		assert_int(board._fog_rects[cell].get_child_count()).is_equal(0)
	var run: ExpeditionRun = _MakeRun()
	board.refresh(run.party_pos, run.fog, {}, {}, "", false)
	var unseen_color: Color = UiTheme.color_of(_cfg, &"ui_fog_unseen_color",
			UiTheme.FOG_UNSEEN)
	for cell: Vector2i in board._fog_rects:
		if run.fog.state_of(cell, run.party_pos) == FogOfWar.CellState.UNSEEN:
			assert_bool(board._fog_rects[cell].visible).is_true()
			assert_bool(board._fog_rects[cell].color.is_equal_approx(unseen_color)).is_true()
			break

func test_fog_refresh_selects_texture_by_state() -> void:
	## refresh 三态（中2 双绘防线锚定）：UNSEEN 选浓雾贴图 + modulate=cfg 色
	## + 父 ColorRect 隐藏（净 α = cfg 单乘——父+子同显 α 叠加已废）；移动后
	## 旧视野边缘 DIM 选记忆贴图同锚定；当前视野 LIT 格父与贴图均隐藏
	var board: ExploreBoard = _MakeExploreBoard()
	var run: ExpeditionRun = _MakeRun()
	var unseen_color: Color = UiTheme.color_of(_cfg, &"ui_fog_unseen_color",
			UiTheme.FOG_UNSEEN)
	var dim_color: Color = UiTheme.color_of(_cfg, &"ui_fog_dim_color",
			UiTheme.FOG_DIM)
	# 初始：远处 UNSEEN 格贴图态断言（贴图显 + 父隐藏）
	var party: Vector2i = run.party_pos
	board.refresh(party, run.fog, {}, {}, "", false)
	var unseen_checked: bool = false
	for cell: Vector2i in board._fog_textures:
		if run.fog.state_of(cell, party) == FogOfWar.CellState.UNSEEN:
			var fog_tex: TextureRect = board._fog_textures[cell]
			assert_object(fog_tex.texture).is_not_null()
			assert_bool(fog_tex.visible).is_true()
			assert_bool(fog_tex.modulate.is_equal_approx(unseen_color)).is_true()
			assert_bool(board._fog_rects[cell].visible).override_failure_message(
					"贴图态父 ColorRect 应隐藏（α 双乘防线）").is_false()
			unseen_checked = true
			break
	assert_bool(unseen_checked).is_true()
	# 移动后：旧视野（当前视野外、已探索）DIM 格贴图态断言——先揭示 A 视野
	## 再移动到远格 B（首揭在 start_explore 不做——explore_screen 口径同）
	run.fog.on_moved(party)
	var map_def: ExploreMapDef = _game_data.get_record(MAP_ID) as ExploreMapDef
	var moved: Vector2i = party
	for y: int in map_def.size.y:
		var found: bool = false
		for x: int in map_def.size.x:
			var probe: Vector2i = Vector2i(x, y)
			var delta: Vector2i = probe - party
			if absi(delta.x) > _cfg.vision_radius + 1 \
					or absi(delta.y) > _cfg.vision_radius + 1:
				moved = probe
				found = true
				break
		if found:
			break
	run.fog.on_moved(moved)
	run.party_pos = moved
	board.refresh(moved, run.fog, {}, {}, "", false)
	var dim_checked: bool = false
	var lit_checked: bool = false
	for cell: Vector2i in board._fog_textures:
		match run.fog.state_of(cell, moved):
			FogOfWar.CellState.DIM:
				var dim_tex: TextureRect = board._fog_textures[cell]
				assert_object(dim_tex.texture).is_not_null()
				assert_bool(dim_tex.visible).is_true()
				assert_bool(dim_tex.modulate.is_equal_approx(dim_color)).is_true()
				assert_bool(board._fog_rects[cell].visible).is_false()
				dim_checked = true
			FogOfWar.CellState.LIT:
				assert_bool(board._fog_rects[cell].visible).is_false()
				assert_bool(board._fog_textures[cell].visible).is_false()
				lit_checked = true
			_:
				pass
	assert_bool(dim_checked).is_true()
	assert_bool(lit_checked).is_true()

func test_fog_state_missing_texture_parent_visible() -> void:
	## 缺件态父恢复显示（中2）：单键缺件注入（fx_fog_dim=null——fx_fog_unseen
	## 在档）→ DIM 格贴图隐藏 + 父 ColorRect 显示（纯色兜底）；UNSEEN 格仍
	## 贴图态（父隐藏）——两态互不干扰
	_InjectMissing(&"fx_fog_dim")
	var board: ExploreBoard = _MakeExploreBoard()
	var run: ExpeditionRun = _MakeRun()
	var party: Vector2i = run.party_pos
	run.fog.on_moved(party)
	var map_def: ExploreMapDef = _game_data.get_record(MAP_ID) as ExploreMapDef
	var moved: Vector2i = party
	for y: int in map_def.size.y:
		var found: bool = false
		for x: int in map_def.size.x:
			var probe: Vector2i = Vector2i(x, y)
			var delta: Vector2i = probe - party
			if absi(delta.x) > _cfg.vision_radius + 1 \
					or absi(delta.y) > _cfg.vision_radius + 1:
				moved = probe
				found = true
				break
		if found:
			break
	run.fog.on_moved(moved)
	run.party_pos = moved
	board.refresh(moved, run.fog, {}, {}, "", false)
	var dim_checked: bool = false
	var unseen_checked: bool = false
	for cell: Vector2i in board._fog_textures:
		match run.fog.state_of(cell, moved):
			FogOfWar.CellState.DIM:
				assert_bool(board._fog_textures[cell].visible).is_false()
				assert_bool(board._fog_rects[cell].visible).override_failure_message(
						"DIM 缺件态父 ColorRect 应恢复显示").is_true()
				dim_checked = true
			FogOfWar.CellState.UNSEEN:
				assert_bool(board._fog_textures[cell].visible).is_true()
				assert_bool(board._fog_rects[cell].visible).is_false()
				unseen_checked = true
			_:
				pass
	assert_bool(dim_checked).is_true()
	assert_bool(unseen_checked).is_true()

# --------------------------------------------------------------------------
# 组 3 战棋 tile
# --------------------------------------------------------------------------

func _MakeBattleBoard(inject_floor_missing: bool) -> BattleBoard:
	## 构建战斗板层（随机遭遇包真装配；inject_floor_missing = floor 双变体
	## 缺件注入——降级分支用）
	## 参数 inject_floor_missing：是否注入 floor 贴图缺件
	## 返回：已 setup 的 BattleBoard（auto_free 释放）
	if inject_floor_missing:
		_InjectMissing(&"tile_mine_floor_01")
		_InjectMissing(&"tile_mine_floor_02")
	var params := BattleParams.new()
	params.pack_id = &"enc_m1_random_pack"
	params.party = [AdventurerData.create_debug(&"warrior", &"cls_warrior", {
			&"strength": 16, &"agility": 10, &"constitution": 14,
			&"intelligence": 7, &"perception": 9, &"willpower": 9, &"luck": 9},
			_game_data)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	params.rng = rng
	var context: BattleSetup.BattleContext = BattleSetup.build(params, _game_data)
	var board := BattleBoard.new()
	add_child(board)
	auto_free(board)
	board.setup(context, _game_data)
	return board

func test_battle_cell_texture_branch() -> void:
	## 贴图分支：tile 表 asset_id 在档的格 → Control 根 + 满格 TextureRect 子
	##（贴图态 gap=0 无缝——子尺寸 == cell_size）
	var board: BattleBoard = _MakeBattleBoard(false)
	var textured_cells: int = 0
	for cell: Vector2i in board._cells:
		var visual: Control = board._cells[cell]
		if visual.get_child_count() > 0 and visual.get_child(0) is TextureRect:
			textured_cells += 1
			var rect: TextureRect = visual.get_child(0) as TextureRect
			assert_object(rect.texture).is_not_null()
			assert_bool(rect.size == Vector2(board.cell_size, board.cell_size)).is_true()
			# 贴图态 gap=0：根尺寸 == 满格 cell_size（无缝铺贴）
			assert_bool(visual.size == Vector2(board.cell_size, board.cell_size)).is_true()
	assert_int(textured_cells).is_greater(0)

func test_battle_cell_fallback_color_rect() -> void:
	## 缺件降级：floor 双变体注入 null → 普通格回落现状色块（ColorRect 根）
	_InjectMissing(&"tile_mine_floor_01")
	_InjectMissing(&"tile_mine_floor_02")
	var board: BattleBoard = _MakeBattleBoard(false)
	var plain_cells: int = 0
	for cell: Vector2i in board._cells:
		if board._cells[cell] is ColorRect:
			plain_cells += 1
	assert_int(plain_cells).is_greater(0)

func test_trap_mark_texture_and_fallback() -> void:
	## 陷阱标记两态：贴图在档 → 整格半透明 TextureRect（meta trap_mark 沿用 +
	## modulate.a == TRAP_TILE_ALPHA）；缺件注入 → 现状橙色角块 ColorRect
	var board: BattleBoard = _MakeBattleBoard(false)
	var context: BattleSetup.BattleContext = board.context
	var trap_cell: Vector2i = (context.units[0] as BattleUnit).grid_pos
	context.grid.spawn_dynamic_tile(trap_cell, &"tile_trap", 5, &"")
	board.RefreshDynamicMarks()
	var mark_textured: Control = _FindTrapMark(board)
	assert_object(mark_textured).is_not_null()
	assert_int(mark_textured.get_child_count()).is_equal(1)
	assert_bool(mark_textured.get_child(0) is TextureRect).is_true()
	assert_bool(is_equal_approx(mark_textured.modulate.a,
			BattleBoard.TRAP_TILE_ALPHA)).is_true()
	# 缺件降级：tile_battle_trap 注入 null → 现状 ColorRect 角块
	_InjectMissing(&"tile_battle_trap")
	board.RefreshDynamicMarks()
	var mark_fallback: Control = _FindTrapMark(board)
	assert_object(mark_fallback).is_not_null()
	assert_bool(mark_fallback is ColorRect).is_true()

func _FindTrapMark(board: BattleBoard) -> Control:
	## 查找最新陷阱标记节点（meta trap_mark 扫描——取末位：清理为 queue_free
	## 延迟帧末，重画后新旧并存，新节点恒在尾部）
	## 参数 board：战斗板层
	## 返回：最新标记节点；无返回 null
	var mark: Control = null
	for child: Node in board.get_children():
		if child is Control and child.get_meta(&"trap_mark", false):
			mark = child as Control
	return mark

# --------------------------------------------------------------------------
# 组 8 叠加（选中框 / 范围覆盖）
# --------------------------------------------------------------------------

func test_unit_badge_select_ring_texture_branch() -> void:
	## 选中框贴图态：game_data 注入 → _ring 单元素 TextureRect（格尺寸
	## STRETCH_SCALE、贴图非空）
	var unit := BattleUnit.new()
	unit.unit_id = &"test_unit"
	unit.current_hp = 50
	unit.max_hp = 100
	var badge := UnitBadge.new()
	add_child(badge)
	auto_free(badge)
	badge.setup(unit, 72.0, null, {}, _game_data)
	assert_int(badge._ring.size()).is_equal(1)
	var ring: Control = badge._ring[0]
	assert_bool(ring is TextureRect).is_true()
	assert_object((ring as TextureRect).texture).is_not_null()
	assert_bool(ring.size == Vector2(72.0, 72.0)).is_true()

func test_unit_badge_select_ring_fallback_four_edges() -> void:
	## 选中框缺件态：无 game_data（纯兜底模式）→ 现状金色四边带（4 条
	## ColorRect——占位态视觉零回归）
	var unit := BattleUnit.new()
	unit.unit_id = &"test_unit"
	unit.current_hp = 50
	unit.max_hp = 100
	var badge := UnitBadge.new()
	add_child(badge)
	auto_free(badge)
	badge.setup(unit, 72.0)
	assert_int(badge._ring.size()).is_equal(4)
	for edge: Control in badge._ring:
		assert_bool(edge is ColorRect).is_true()

func test_unit_badge_ring_breath_generalized() -> void:
	## 呼吸 tween 泛化：贴图态 _ring 单 TextureRect 下 set_current 呼吸照常
	##（_ring_tween 启停 + modulate.a 驱动——两态零改复用的回归锚点）
	var unit := BattleUnit.new()
	unit.unit_id = &"test_unit"
	unit.current_hp = 50
	unit.max_hp = 100
	var badge := UnitBadge.new()
	add_child(badge)
	auto_free(badge)
	badge.setup(unit, 72.0, null, {}, _game_data)
	badge.set_current(true)
	assert_object(badge._ring_tween).is_not_null()
	assert_bool(badge._ring[0].visible).is_true()
	badge.set_current(false)
	assert_object(badge._ring_tween).is_null()
	assert_bool(badge._ring[0].visible).is_false()
	assert_float(badge._ring[0].modulate.a).is_equal(1.0)

func test_battle_overlay_range_texture_and_fallback() -> void:
	## 范围覆盖两态：fx_battle_range 在档 → 填充块 TextureRect + modulate =
	## cfg 填充色（染蓝）；缺件注入 → 现状 ColorRect 填充块
	var board: BattleBoard = auto_free(BattleBoard.new())
	board.cell_size = 64.0
	board.origin = Vector2.ZERO
	board._game_data = _game_data
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	board.show_move_range(cells)
	assert_int(board._move_overlays.size()).is_equal(2)
	var fill_tex: TextureRect = board._move_overlays[0].get_child(0) as TextureRect
	assert_object(fill_tex).is_not_null()
	assert_object(fill_tex.texture).is_not_null()
	var move_fill: Color = UiTheme.color_of(null,
			&"ui_overlay_move_fill_color", UiTheme.OVERLAY_MOVE_FILL)
	assert_bool(fill_tex.modulate.is_equal_approx(move_fill)).is_true()
	# 缺件降级：现状 ColorRect
	_InjectMissing(&"fx_battle_range")
	board.show_move_range(cells)
	var fill_rect: ColorRect = board._move_overlays[0].get_child(0) as ColorRect
	assert_object(fill_rect).is_not_null()

# --------------------------------------------------------------------------
# 组 7 九宫格 / 四档底图 / D20 容器
# --------------------------------------------------------------------------

func test_dark_panel_style_texture_branch() -> void:
	## 九宫格贴图态：game_data 注入 → StyleBoxTexture（贴图非空 + 四边
	## 24px 纹理边距）
	var style: StyleBox = UiTheme.make_dark_panel_style(_cfg, _game_data)
	assert_bool(style is StyleBoxTexture).is_true()
	var tex_style: StyleBoxTexture = style as StyleBoxTexture
	assert_object(tex_style.texture).is_not_null()
	assert_float(tex_style.get_margin(SIDE_LEFT)).is_equal(UiTheme.PANEL_NINEPATCH_MARGIN)
	assert_float(tex_style.get_margin(SIDE_TOP)).is_equal(UiTheme.PANEL_NINEPATCH_MARGIN)

func test_dark_panel_style_fallback_flat() -> void:
	## 九宫格降级：无 game_data / 缺件注入 → 现状 StyleBoxFlat（圆角 6 +
	## 内边距 8——占位态视觉零回归）
	var flat_style: StyleBox = UiTheme.make_dark_panel_style(_cfg, null)
	assert_bool(flat_style is StyleBoxFlat).is_true()
	_InjectMissing(&"ui_panel_ninepatch")
	var missing_style: StyleBox = UiTheme.make_dark_panel_style(_cfg, _game_data)
	assert_bool(missing_style is StyleBoxFlat).is_true()

func test_event_panel_grade_and_d20_hosts() -> void:
	## 四档底图 + D20 骰面容器：CenterContainer 双子叠印（底图 TextureRect +
	## 文字 Label）；show_settled 底图按档就位 + 文字色逻辑零改；D20 骰面
	## ≥200px；_Reset 后隐藏
	var panel := EventPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.setup(_cfg, _game_data)
	assert_bool(panel._grade_host is CenterContainer).is_true()
	assert_bool(panel._grade_label.get_parent() == panel._grade_host).is_true()
	assert_bool(panel._d20_host is CenterContainer).is_true()
	# D20 骰面：贴图在档挂载 + ≥200px；数字 Label 常驻（滚动逻辑零改）
	assert_object(panel._d20_icon.texture).is_not_null()
	assert_float(panel._d20_icon.custom_minimum_size.x) \
			.is_greater_equal(EventPanel.D20_FACE_MIN_SIZE)
	assert_bool(panel._d20_label.get_parent() == panel._d20_host).is_true()
	# 四档底图：show_settled 按档装配 + 文字不变
	panel.show_settled(CheckResult.Grade.CRIT_SUCCESS, "文本", "")
	assert_bool(panel._grade_host.visible).is_true()
	assert_object(panel._grade_icon.texture).is_not_null()
	assert_str(panel._grade_label.text).contains("大成功")
	panel._Reset()
	assert_bool(panel._grade_host.visible).is_false()
	assert_bool(panel._grade_label.visible).is_false()

func test_event_panel_d20_and_grade_fallback() -> void:
	## 缺件降级：fx_d20/ui_label_* 注入 null → 骰面不占位（texture null——
	## 纯数字现状）、四档底图不占位（纯文字现状——文字色逻辑零改）
	_InjectMissing(&"fx_d20")
	_InjectMissing(&"ui_label_result_crit_success")
	var panel := EventPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.setup(_cfg, _game_data)
	assert_object(panel._d20_icon.texture).is_null()
	assert_float(panel._d20_icon.custom_minimum_size.x).is_equal(0.0)
	panel.show_settled(CheckResult.Grade.CRIT_SUCCESS, "文本", "")
	assert_bool(panel._grade_host.visible).is_true()
	assert_object(panel._grade_icon.texture).is_null()
	assert_str(panel._grade_label.text).contains("大成功")

# --------------------------------------------------------------------------
# 组 6 系统图标
# --------------------------------------------------------------------------

func test_quest_card_reward_icon_row_and_fallback() -> void:
	## 奖励行两态：贴图在档 → 标题+三段 [icon+数值]（_reward_label 隐藏）；
	## 三键注入 null → 现状整行文本（reward_format）可见零回归
	var inst := QuestInstance.new()
	inst.serial = 1
	inst.template_id = &"q_chore_supply_run"
	var card := QuestCard.new()
	add_child(card)
	auto_free(card)
	card.setup(_cfg, _game_data)
	card.refresh(inst, _game_data, 1)
	var icon_count: int = 0
	for child: Node in card._reward_box.get_children():
		if child is HBoxContainer:
			for part_child: Node in (child as HBoxContainer).get_children():
				if part_child is TextureRect:
					icon_count += 1
	assert_int(icon_count).is_equal(3)
	assert_bool(card._reward_label.visible).is_false()
	# 缺件降级：现状整行
	_InjectMissing(&"icon_res_gold")
	_InjectMissing(&"icon_res_exp")
	_InjectMissing(&"icon_res_repu")
	var card2 := QuestCard.new()
	add_child(card2)
	auto_free(card2)
	card2.setup(_cfg, _game_data)
	card2.refresh(inst, _game_data, 1)
	assert_bool(card2._reward_label.visible).is_true()
	assert_str(card2._reward_label.text).contains("奖励：")
	assert_bool(card2._reward_label.text.contains("/")).is_true()

func _MakeCore() -> GuildCore:
	## 构建测试公会核心（cfg/game_data 注入——弹层数据源）
	## 参数：无
	## 返回：GuildCore
	var core := GuildCore.new()
	core.cfg = _cfg
	core.game_data = _game_data
	return core

func test_member_detail_panel_icon_rows() -> void:
	## 成员详情三处图标：标题行职业图标 + 状态行经验图标 + 属性行 7 个图标行
	##（ATTR_ICON_IDS 任一在档 → 7 行模式——含图标行计数 == 1+1+7）
	var core: GuildCore = _MakeCore()
	var member: AdventurerData = AdventurerData.create_debug(&"alice",
			&"cls_warrior", {
			&"strength": 14, &"agility": 10, &"constitution": 12,
			&"intelligence": 7, &"perception": 9, &"willpower": 9, &"luck": 9},
			_game_data)
	var panel := MemberDetailPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.setup(_cfg, _game_data)
	panel.open(member, core)
	var icon_row_count: int = 0
	for child: Node in panel._box.get_children():
		if child is HBoxContainer:
			var has_icon: bool = false
			for row_child: Node in (child as HBoxContainer).get_children():
				if row_child is TextureRect:
					has_icon = true
			if has_icon:
				icon_row_count += 1
	assert_int(icon_row_count).is_equal(9)

func test_member_detail_panel_attr_fallback_single_line() -> void:
	## 属性行缺件降级：七属性贴图全注入 null → 现状单行 join 文本
	##（「力量 14 敏捷 10 …」无图标行零回归；职业/经验图标同时注入降级
	## ——断言整弹层零图标行）
	for asset_id: StringName in [&"icon_attr_str", &"icon_attr_agi",
			&"icon_attr_con", &"icon_attr_int", &"icon_attr_wis",
			&"icon_attr_wil", &"icon_attr_luk", &"icon_res_exp",
			&"icon_class_warrior"]:
		_InjectMissing(asset_id)
	var core: GuildCore = _MakeCore()
	var member: AdventurerData = AdventurerData.create_debug(&"alice",
			&"cls_warrior", {
			&"strength": 14, &"agility": 10, &"constitution": 12,
			&"intelligence": 7, &"perception": 9, &"willpower": 9, &"luck": 9},
			_game_data)
	var panel := MemberDetailPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.setup(_cfg, _game_data)
	panel.open(member, core)
	var icon_row_count: int = 0
	for child: Node in panel._box.get_children():
		if child is HBoxContainer:
			for row_child: Node in (child as HBoxContainer).get_children():
				if row_child is TextureRect:
					icon_row_count += 1
	assert_int(icon_row_count).is_equal(0)

func test_unit_info_card_stat_icons_and_fallback() -> void:
	## 状态行两态：HP+资源贴图齐备 → [HP 图标+HP 段][资源图标+资源段] 拆段
	##（_stats_label 隐藏但文本已写——契约读值不漂移）；缺件 → 单 Label
	## 整行现状
	var unit := BattleUnit.new()
	unit.unit_id = &"test_unit"
	unit.current_hp = 30
	unit.max_hp = 40
	unit.current_mana = 5
	unit.max_mana = 8
	var card := UnitInfoCard.new()
	add_child(card)
	auto_free(card)
	card.setup(func(_status_id: StringName) -> StatusDef: return null)
	card.apply_cfg(_cfg, _game_data)
	card.show_unit(unit)
	var icon_count: int = 0
	for child: Node in card._stats_box.get_children():
		if child is TextureRect:
			icon_count += 1
	assert_int(icon_count).is_equal(2)
	assert_bool(card._stats_label.visible).is_false()
	assert_str(card._stats_label.text).contains("HP 30/40")
	# 缺件降级：现状单 Label 整行（缓存注入 null——进程缓存命中会绕过
	## game_data 判空，需按键穿透）
	_InjectMissing(&"icon_res_hp")
	_InjectMissing(&"icon_res_mp")
	_InjectMissing(&"icon_res_sp")
	var degraded := UnitInfoCard.new()
	add_child(degraded)
	auto_free(degraded)
	degraded.setup(func(_status_id: StringName) -> StatusDef: return null)
	degraded.apply_cfg(_cfg, null)
	degraded.show_unit(unit)
	assert_bool(degraded._stats_label.visible).is_true()
	assert_str(degraded._stats_label.text).contains("｜")
	assert_int(degraded._stats_box.get_child_count()).is_equal(1)

func test_roster_and_organize_class_icons() -> void:
	## 职业图标（总览行 + 编队选人行）：ClassDef.icon_id 在档 → Button.icon /
	## CheckBox.icon 非空（缺件降级 = 纯文字行现状零改）；中4 尺寸钳制：
	## expand_icon=false + icon_max_width=20（64 源裸贴撑爆行高的防线——
	## 与 recruit_panel 20px 口径统一），行最小高 < 50（裸贴态 ≥64）
	var member: AdventurerData = AdventurerData.create_debug(&"alice",
			&"cls_warrior", {
			&"strength": 14, &"agility": 10, &"constitution": 12,
			&"intelligence": 7, &"perception": 9, &"willpower": 9, &"luck": 9},
			_game_data)
	var roster := RosterOverview.new()
	add_child(roster)
	auto_free(roster)
	roster.setup(_cfg)
	roster.refresh([member], QuestBoard.new(), 1, _game_data)
	var row_button: Button = roster._row_buttons[0]
	assert_object(row_button.icon).is_not_null()
	assert_bool(row_button.expand_icon).is_false()
	assert_int(row_button.get_theme_constant("icon_max_width")) \
			.is_equal(RosterOverview.CLASS_ICON_MAX_WIDTH)
	assert_int(row_button.get_theme_constant("icon_max_width")).is_equal(20)
	assert_float(row_button.get_minimum_size().y).is_less(50.0)
	# 编队弹层选人行
	var core: GuildCore = _MakeCore()
	core.roster.append(member)
	var inst := QuestInstance.new()
	inst.serial = 1
	inst.template_id = &"q_chore_supply_run"
	inst.state = QuestInstance.State.ACCEPTED
	var organize := OrganizePanel.new()
	add_child(organize)
	auto_free(organize)
	organize.setup(_cfg, _game_data)
	organize.open(inst, core)
	var check: CheckBox = organize._checks[member.unit_id]
	assert_object(check.icon).is_not_null()
	assert_bool(check.expand_icon).is_false()
	assert_int(check.get_theme_constant("icon_max_width")) \
			.is_equal(OrganizePanel.CLASS_ICON_MAX_WIDTH)
	assert_float(check.get_minimum_size().y).is_less(50.0)

func test_recruit_panel_class_icon() -> void:
	## 招募候选行职业图标：icon_id 在档 → 行首 20px TextureRect
	var core: GuildCore = _MakeCore()
	core.recruit_pool.cfg = _cfg
	var candidate: AdventurerData = AdventurerData.create_debug(&"bob",
			&"cls_mage", {
			&"strength": 7, &"agility": 10, &"constitution": 9,
			&"intelligence": 16, &"perception": 11, &"willpower": 9, &"luck": 9},
			_game_data)
	core.recruit_pool.candidates.append(candidate)
	var panel := RecruitPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.setup(_cfg)
	panel.refresh(core)
	assert_int(panel._rows.size()).is_equal(1)
	var icon_found: bool = false
	for row_child: Node in panel._rows[0].get_children():
		if row_child is TextureRect:
			icon_found = true
	assert_bool(icon_found).is_true()

# --------------------------------------------------------------------------
# 循环盲审修复②：重建型刷新一帧叠显契约（三面板——S4-R3-01 同式）
# --------------------------------------------------------------------------

func test_accepted_panel_refresh_hides_old_rows_instantly() -> void:
	## 挂单面板重建契约：refresh 再发起（换挂单集）——旧行立即隐藏
	##（queue_free 延迟帧末，修复前旧行与新行一帧叠渲）；新行计数正确
	var core: GuildCore = _MakeCore()
	var inst := QuestInstance.new()
	inst.serial = 1
	inst.template_id = &"q_chore_supply_run"
	inst.state = QuestInstance.State.ACCEPTED
	var panel := AcceptedPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.setup(_cfg)
	panel.refresh([inst], core)
	assert_int(panel._rows.size()).is_equal(1)
	var old_rows: Array[VBoxContainer] = panel._rows.duplicate()
	var no_instances: Array[QuestInstance] = []
	panel.refresh(no_instances, core)
	for old_row: VBoxContainer in old_rows:
		assert_bool(old_row.is_queued_for_deletion()) \
				.override_failure_message("旧行应已排队释放").is_true()
		assert_bool(old_row.visible) \
				.override_failure_message("重建发起帧旧行应立即隐藏（一帧叠显）").is_false()
	assert_int(panel._rows.size()).is_equal(0)

func test_recruit_panel_refresh_hides_old_rows_instantly() -> void:
	## 招募面板重建契约：refresh 再发起（候选清空）——旧行立即隐藏；
	## 新行计数正确
	var core: GuildCore = _MakeCore()
	core.recruit_pool.cfg = _cfg
	var candidate: AdventurerData = AdventurerData.create_debug(&"bob",
			&"cls_mage", {
			&"strength": 7, &"agility": 10, &"constitution": 9,
			&"intelligence": 16, &"perception": 11, &"willpower": 9, &"luck": 9},
			_game_data)
	core.recruit_pool.candidates.append(candidate)
	var panel := RecruitPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.setup(_cfg)
	panel.refresh(core)
	assert_int(panel._rows.size()).is_equal(1)
	var old_rows: Array[HBoxContainer] = panel._rows.duplicate()
	core.recruit_pool.candidates.clear()
	panel.refresh(core)
	for old_row: HBoxContainer in old_rows:
		assert_bool(old_row.is_queued_for_deletion()) \
				.override_failure_message("旧行应已排队释放").is_true()
		assert_bool(old_row.visible) \
				.override_failure_message("重建发起帧旧行应立即隐藏（一帧叠显）").is_false()
	assert_int(panel._rows.size()).is_equal(0)

func test_roster_overview_refresh_hides_old_rows_instantly() -> void:
	## 名册总览重建契约：refresh 再发起（成员清空）——旧行按钮立即隐藏；
	## 新行计数正确
	var member: AdventurerData = AdventurerData.create_debug(&"alice",
			&"cls_warrior", {
			&"strength": 14, &"agility": 10, &"constitution": 12,
			&"intelligence": 7, &"perception": 9, &"willpower": 9, &"luck": 9},
			_game_data)
	var roster := RosterOverview.new()
	add_child(roster)
	auto_free(roster)
	roster.setup(_cfg)
	roster.refresh([member], QuestBoard.new(), 1, _game_data)
	assert_int(roster._row_buttons.size()).is_equal(1)
	var old_buttons: Array[Button] = roster._row_buttons.duplicate()
	var no_members: Array[AdventurerData] = []
	roster.refresh(no_members, QuestBoard.new(), 1, _game_data)
	for old_button: Button in old_buttons:
		assert_bool(old_button.is_queued_for_deletion()) \
				.override_failure_message("旧行应已排队释放").is_true()
		assert_bool(old_button.visible) \
				.override_failure_message("重建发起帧旧行应立即隐藏（一帧叠显）").is_false()
	assert_int(roster._row_buttons.size()).is_equal(0)
