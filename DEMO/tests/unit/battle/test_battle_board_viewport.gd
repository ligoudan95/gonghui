## 战斗屏视口交互单元测试（视口批：滚轮缩放 + 中键拖动平移）
## 覆盖：三纯函数直测（zoom_steps_of 档表生成——首档恒 1.0/末档截断/防退步/
## 单档/非法入参；clamp_viewport_position 贴边钳制——fit 态两轴强制 0/
## 溢出轴上下界=包围盒贴边/半溢出/zoom=1 全锁/非法 zoom 防御；
## zoom_position_for_anchor 锚点推算——锚点不动点恒等/边界样例/非法 z 防御）；
## 运行态直调公开口（headless 不模拟鼠标事件）：缩放逐档/触顶无效/缩回
## 0 档 pan 归零回正、瞬跳与 tween 两模式终值、resize 防抖重建后视口态全
## 复位 + 档表按新 fit 重建 + WorldLayer 存活、cell_from_board_local 手算
## 预期 + transform API 交叉断言、在途移动中缩放徽章 world local 恒等、
## 拖动三口序列（begin→激活→end 的 tooltip 抑制/恢复与光标）+ 轮询兜底
##（headless 无中键按下 → _process 自动收口）、720 让位档数样例。
## 阈值激活路径已知未覆盖（headless 限制，盲审修复 9/S5-1 实测留痕）：
## Input.parse_input_event 在 headless DisplayServer 下不更新 Input 单例
## 按键状态，begin→位移>PAN_DRAG_THRESHOLD→active 的 _process 轮询判定
## 链无法注入驱动——激活语义经 _ActivatePan 直调覆盖、阈值比较分支归
## 人工验收（详 test_pan_polling_fallback_ends_pending 尾注）。
## 数学单源锚点 = 视口批方案 §二/§三/§四（坐标链/档表/钳制公式）。
extends GdUnitTestSuite

## GameData 脚本路径（AssetTex 纹理解析注入）
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## 真实 8×8 地图（test_battle_board_resize_debounce 同源夹具）
const MAP_PATH: String = "res://data/battle/maps/btm_m1_random_8x8.tres"
## 地格表目录
const TILE_DIR: String = "res://data/battle/tiles/"

## 套件级 GameData 实例
var _game_data: Node
## 地格定义表（id -> TileTypeDef）
var _tiles: Dictionary = {}

func before() -> void:
	## 套件前置：实例化 GameData 并加载地格表
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()
	_tiles = {}
	for tile_id: StringName in [&"tile_normal", &"tile_obstacle", &"tile_grass",
			&"tile_highground", &"tile_poison_swamp", &"tile_trap"]:
		_tiles[tile_id] = load(TILE_DIR + String(tile_id) + ".tres")

func before_test() -> void:
	## 用例前置：清纹理缓存（用例间隔离——含缺件 null 驻留）
	## 参数：无
	## 返回：无
	AssetTex.clear_cache()

func after() -> void:
	## 套件后置：清纹理缓存（防污染后续套件）
	## 参数：无
	## 返回：无
	AssetTex.clear_cache()

func _MakeBoard(board_size: Vector2, cfg: CoreConfig = null,
		with_unit: bool = false) -> BattleBoard:
	## 构建挂树装配板（真实 8×8 地图 + 空队伍；cfg 可注入——空 = 纯兜底
	## 模式（缩放动画走兜底 0.1s tween）；with_unit = 附单测试单位供
	## move_badge 在途徽章断言）
	## 参数 board_size：板面像素尺寸；cfg：总控配置（可空）；with_unit：附单位
	## 返回：已 setup 的板层实例（auto_free 释放）
	var map_def: BattleMapDef = load(MAP_PATH) as BattleMapDef
	var grid := BattleGrid.new()
	assert_bool(grid.setup(map_def, _LookupTile)).is_true()
	var context := BattleSetup.BattleContext.new()
	context.grid = grid
	context.cfg = cfg
	context.units = []
	if with_unit:
		var unit := BattleUnit.new()
		unit.unit_id = &"viewport_probe"
		unit.current_hp = 50
		unit.max_hp = 50
		unit.grid_pos = Vector2i(2, 2)
		context.units = [unit]
	var board: BattleBoard = auto_free(BattleBoard.new())
	add_child(board)
	board.size = board_size
	board.setup(context, _game_data)
	return board

func _LookupTile(tile_id: StringName) -> TileTypeDef:
	## 地格定义解析闭包（字典查找——test_battle_grid 同式）
	## 参数 tile_id：地格 id
	## 返回：TileTypeDef（未登记返回 null）
	return _tiles.get(tile_id, null)

func _InstantCfg() -> CoreConfig:
	## 瞬跳模式 cfg（ui_battle_zoom_seconds = 0——直落无 tween，断言即时）
	## 参数：无
	## 返回：CoreConfig（auto_free 由调用方）
	var cfg: CoreConfig = CoreConfig.new()
	auto_free(cfg)
	cfg.ui_battle_zoom_step_ratio = 0.1
	cfg.ui_battle_zoom_seconds = 0.0
	cfg.ui_battle_iso_ratio = 0.5
	return cfg

# --------------------------------------------------------------------------
# 纯函数直测：zoom_steps_of（档表生成）
# --------------------------------------------------------------------------

func test_zoom_steps_first_is_one_last_is_max_clamped() -> void:
	## 档表基本契约：首档恒 1.0；末档 == zoom_max 精确截断（2.2/80 = 176/80）；
	## 中间档严格递增（每档 = 前档 × 1.1）
	var steps: Array[float] = BattleBoard.zoom_steps_of(80.0, 176.0, 0.1)
	assert_int(steps.size()).is_greater(2)
	assert_float(steps[0]).is_equal(1.0)
	assert_float(steps[steps.size() - 1]).is_equal_approx(176.0 / 80.0, 0.0001)
	for index: int in range(1, steps.size() - 1):
		assert_float(steps[index]).is_equal_approx(steps[index - 1] * 1.1, 0.0001) \
				.override_failure_message("档 %d 步距失 1.1 倍递进" % index)
		assert_bool(steps[index] < steps[steps.size() - 1]).is_true()

func test_zoom_steps_single_step_when_max_equals_base() -> void:
	## zoom_max == 1 单档：钳制上限 == fit（zoom_max == 1 合法已知行为——
	## 返回 [1.0] 单档）；zoom_max < 1 与非法入参（base/ratio ≤ 0）同单档
	var equal: Array[float] = BattleBoard.zoom_steps_of(100.0, 100.0, 0.1)
	assert_int(equal.size()).is_equal(1)
	assert_float(equal[0]).is_equal(1.0)
	var below: Array[float] = BattleBoard.zoom_steps_of(100.0, 90.0, 0.1)
	assert_int(below.size()).is_equal(1)
	assert_float(below[0]).is_equal(1.0)

func test_zoom_steps_invalid_inputs_fallback_single() -> void:
	## 非法入参防御：base ≤ 0 / ratio ≤ 0 均回退 [1.0] 单档（不崩溃不产
	## 非法档——空表/负档会破 zoom 消费链）
	for bad: Array in [[0.0, 176.0, 0.1], [-80.0, 176.0, 0.1], [80.0, 176.0, 0.0],
			[80.0, 176.0, -0.1]]:
		var steps: Array[float] = BattleBoard.zoom_steps_of(bad[0], bad[1], bad[2])
		assert_int(steps.size()).is_equal(1) \
				.override_failure_message("非法入参 %s 应回退单档" % str(bad))
		assert_float(steps[0]).is_equal(1.0)

func test_zoom_steps_anti_regression_drops_tiny_step() -> void:
	## 防退步：末档与前档差 < ZOOM_MIN_STEP_GAP(0.02) 丢前档——构造
	## zoom_max = 1.0 + (1.1 + gap) 的邻界样例（前档 1.1、末档 1.11 差
	## 0.01 < 0.02 → 丢 1.1 档）；首档 1.0 结构位保留（size > 2 才丢）
	var tiny: Array[float] = BattleBoard.zoom_steps_of(100.0, 111.0, 0.1)
	# 档序 1.0, 1.1, 1.21 ≥ 1.11? 否（1.21 > 1.11 循环在 current=1.21 ≥ 1.11
	# 退出——末档 1.11 截断，前档 1.1 差 0.01 < 0.02 丢弃）
	assert_int(tiny.size()).is_equal(2)
	assert_float(tiny[0]).is_equal(1.0)
	assert_float(tiny[1]).is_equal_approx(1.11, 0.0001)
	# 两档表不丢（首档/末档结构位——差再小保留，防「fit 档被吞」）
	var two_step: Array[float] = BattleBoard.zoom_steps_of(100.0, 101.0, 0.1)
	assert_int(two_step.size()).is_equal(2)
	assert_float(two_step[0]).is_equal(1.0)
	assert_float(two_step[1]).is_equal_approx(1.01, 0.0001)

# --------------------------------------------------------------------------
# 纯函数直测：clamp_viewport_position（贴边钳制）
# --------------------------------------------------------------------------

func test_clamp_fit_state_forces_zero_both_axes() -> void:
	## fit 态（board_box == layer_size、zoom == 1 无溢出）两轴强制 0——
	## 任意 pos 归零（fit 回正口径）
	var clamped: Vector2 = BattleBoard.clamp_viewport_position(
			Vector2(50.0, 60.0), Vector2(400.0, 300.0), Vector2(400.0, 300.0),
			1.0, Vector2(123.0, -45.0))
	assert_vector(clamped).is_equal(Vector2.ZERO)

func test_clamp_overflow_axis_bounds_align_board_edges() -> void:
	## 溢出轴钳制边界 = 包围盒贴边（内容覆盖视口语义）：origin=(50,40)、
	## box=(500,200)、layer=(400,300)、zoom=1——X 溢出（500 > 400）带
	## [layer−(origin+box), −origin] = [−150, −50]：上界 = 内容左缘贴板左缘
	##（pan ≤ −50）、下界 = 内容右缘贴板右缘（pan ≥ −150）；Y 无溢出（200
	## < 300）强制 0
	var box: Vector2 = Vector2(500.0, 200.0)
	var layer: Vector2 = Vector2(400.0, 300.0)
	var origin: Vector2 = Vector2(50.0, 40.0)
	var zoom: float = 1.0
	# 带内保留原值
	var inside: Vector2 = BattleBoard.clamp_viewport_position(origin, box,
			layer, zoom, Vector2(-100.0, 123.0))
	assert_float(inside.x).is_equal_approx(-100.0, 0.0001) \
			.override_failure_message("带内 pan 应保留原值")
	# 上界锚：pan 过大（内容偏右）→ 钳 −origin×zoom = −50（内容左缘贴板左）
	var left_align: Vector2 = BattleBoard.clamp_viewport_position(origin, box,
			layer, zoom, Vector2(1000.0, 0.0))
	assert_float(left_align.x).is_equal_approx(-50.0, 0.0001) \
			.override_failure_message("内容左缘 pan 超界应钳到贴板左缘 −origin×zoom")
	# 下界锚：pan 过小（内容偏左）→ 钳 layer−(origin+box)×zoom = −150
	##（内容右缘贴板右）
	var right_align: Vector2 = BattleBoard.clamp_viewport_position(origin, box,
			layer, zoom, Vector2(-999.0, 0.0))
	assert_float(right_align.x).is_equal_approx(-150.0, 0.0001) \
			.override_failure_message("内容右缘 pan 超界应钳到贴板右缘 layer−(origin+box)×zoom")
	# Y 轴无溢出（200 < 300）强制 0
	assert_float(left_align.y).is_equal(0.0)
	assert_float(right_align.y).is_equal(0.0)

func test_clamp_half_overflow_per_axis() -> void:
	## 半溢出（一轴溢出一轴 fit）：X 溢出按带钳制（pos −999 越下界 → 钳
	## 内容右缘贴板右 = layer−(origin+box) = −220）、Y 无溢出强制 0——
	## 两轴独立判定
	var clamped: Vector2 = BattleBoard.clamp_viewport_position(
			Vector2(20.0, 60.0), Vector2(600.0, 300.0), Vector2(400.0, 360.0),
			1.0, Vector2(-999.0, 999.0))
	assert_float(clamped.x).is_equal_approx(-220.0, 0.0001)
	assert_float(clamped.y).is_equal(0.0)

func test_clamp_zoom_one_locks_and_zero_zoom_defensive() -> void:
	## zoom=1 全锁：box==layer 两轴无溢出全归 0；zoom ≤ 0 防御返回原值
	##（不产 NaN——除零/负缩放护栏）
	var locked: Vector2 = BattleBoard.clamp_viewport_position(
			Vector2(0.0, 0.0), Vector2(300.0, 300.0), Vector2(300.0, 300.0),
			1.0, Vector2(77.0, 88.0))
	assert_vector(locked).is_equal(Vector2.ZERO)
	var defensive: Vector2 = BattleBoard.clamp_viewport_position(
			Vector2(10.0, 10.0), Vector2(300.0, 300.0), Vector2(400.0, 400.0),
			0.0, Vector2(55.0, 66.0))
	assert_vector(defensive).is_equal(Vector2(55.0, 66.0))

# --------------------------------------------------------------------------
# 纯函数直测：zoom_position_for_anchor（锚点推算）
# --------------------------------------------------------------------------

func test_zoom_anchor_fixed_point_identity() -> void:
	## 锚点不动点恒等：p0 = anchor（锚点即平移位）→ p1 = anchor（锚点处
	## 内容缩放前后不动——公式退化恒等）
	var p1: Vector2 = BattleBoard.zoom_position_for_anchor(
			Vector2(100.0, 80.0), 1.0, 2.0, Vector2(100.0, 80.0))
	assert_vector(p1).is_equal(Vector2(100.0, 80.0))

func test_zoom_anchor_boundary_samples() -> void:
	## 边界样例：anchor=(200,150)、p0=(50,40)、z0=1→z1=2——
	## p1 = anchor − (anchor−p0)×2 = (200−300, 150−220) = (−100, −70)
	##（手算对照）；缩回对称 z1=2→z0 换位验证往返
	var p1: Vector2 = BattleBoard.zoom_position_for_anchor(
			Vector2(50.0, 40.0), 1.0, 2.0, Vector2(200.0, 150.0))
	assert_vector(p1).is_equal_approx(Vector2(-100.0, -70.0), Vector2(0.0001, 0.0001))
	# 往返：z0=2→z1=1 从 p1 推回 p0（锚点公式自逆）
	var back: Vector2 = BattleBoard.zoom_position_for_anchor(
			p1, 2.0, 1.0, Vector2(200.0, 150.0))
	assert_vector(back).is_equal_approx(Vector2(50.0, 40.0), Vector2(0.0001, 0.0001))

func test_zoom_anchor_invalid_zoom_defensive() -> void:
	## 非法 z（≤ 0）防御返回 p0 原样
	assert_vector(BattleBoard.zoom_position_for_anchor(
			Vector2(30.0, 40.0), 0.0, 2.0, Vector2(100.0, 100.0))) \
			.is_equal(Vector2(30.0, 40.0))
	assert_vector(BattleBoard.zoom_position_for_anchor(
			Vector2(30.0, 40.0), 1.0, -2.0, Vector2(100.0, 100.0))) \
			.is_equal(Vector2(30.0, 40.0))

# --------------------------------------------------------------------------
# 运行态直测：WorldLayer 契约 + 缩放步进
# --------------------------------------------------------------------------

func test_world_layer_lazy_build_contract() -> void:
	## WorldLayer 懒建契约：装配后存在——parent == BoardLayer、IGNORE、
	## z == 0、FULL_RECT 尺寸 == 板尺寸（视口态载体唯一性）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0))
	var world: Control = board._world_layer
	assert_object(world).is_not_null()
	assert_object(world.get_parent()).is_same(board)
	assert_int(world.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(world.z_index).is_equal(0)
	await get_tree().process_frame
	assert_vector(world.size).is_equal(board.size) \
			.override_failure_message("WorldLayer FULL_RECT 尺寸应恒 == 板尺寸（实际 %s vs %s）" % [
					world.size, board.size])
	# 地格全挂 world 下（挂载收口契约）
	assert_int(world.get_child_count()).is_equal(64)
	for cell: Vector2i in board._cells:
		assert_object((board._cells[cell] as Control).get_parent()).is_same(world)

func test_zoom_step_through_all_steps_instant_mode() -> void:
	## 逐档步进（瞬跳模式）：每次 +1 world.scale 直落档表值、_zoom_index
	## 递进；触顶后再 +1 无效（下标与缩放不变——无效滚动早退）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0), _InstantCfg())
	var steps: Array[float] = board._zoom_steps.duplicate()
	assert_int(steps.size()).is_greater(2)
	for expected_index: int in range(1, steps.size()):
		board.viewport_zoom_step(1, Vector2(320.0, 320.0))
		assert_int(board._zoom_index).is_equal(expected_index)
		assert_vector(board._world_layer.scale) \
				.is_equal_approx(Vector2(steps[expected_index], steps[expected_index]),
						Vector2(0.001, 0.001)) \
				.override_failure_message("档 %d 瞬跳终值失步" % expected_index)
	# 触顶无效：scale/下标/平移目标均不变
	var scale_before: Vector2 = board._world_layer.scale
	var pan_before: Vector2 = board._view_pan_target
	board.viewport_zoom_step(1, Vector2(320.0, 320.0))
	assert_int(board._zoom_index).is_equal(steps.size() - 1)
	assert_vector(board._world_layer.scale).is_equal(scale_before)
	assert_vector(board._view_pan_target).is_equal(pan_before)

func test_zoom_out_back_to_fit_resets_pan_to_zero() -> void:
	## 触底回正：放大逐档产生非零 pan 后逐档缩回 0 档——两轴无溢出 pan
	## 被钳制强制 0（fit 回正无专门复位路径——钳制口径天然归零）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0), _InstantCfg())
	var steps: Array[float] = board._zoom_steps
	for index: int in steps.size() - 1:
		board.viewport_zoom_step(1, Vector2(100.0, 500.0))
	assert_int(board._zoom_index).is_equal(steps.size() - 1)
	# 640×640 板 fit=80：末档 2.2 下 X 轴溢出（包围盒 640×2.2 > 640）→
	# 偏心锚点推算的非零 pan 需先确认（非退化前提）
	assert_bool(board._view_pan_target != Vector2.ZERO).is_true() \
			.override_failure_message("前置失败：末档偏心锚点应产生非零 pan")
	for index: int in steps.size() - 1:
		board.viewport_zoom_step(-1, Vector2(100.0, 500.0))
	assert_int(board._zoom_index).is_equal(0)
	assert_vector(board._world_layer.scale).is_equal(Vector2.ONE)
	assert_vector(board._world_layer.position).is_equal(Vector2.ZERO) \
			.override_failure_message("缩回 0 档 pan 应归零回正")
	assert_vector(board._view_pan_target).is_equal(Vector2.ZERO)

func test_zoom_step_degraded_board_noop() -> void:
	## 降级守卫：未装配（context null）与未建视口层直调公开口零风险
	##（不崩溃、状态不变）
	var degraded: BattleBoard = auto_free(BattleBoard.new())
	add_child(degraded)
	degraded.viewport_zoom_step(1, Vector2(10.0, 10.0))
	degraded.viewport_begin_pan(Vector2(10.0, 10.0))
	degraded.viewport_end_pan()
	assert_bool(degraded.viewport_is_panning()).is_false()
	assert_vector(degraded.cell_from_board_local(Vector2(10.0, 10.0))) \
			.is_equal(Vector2i(-1, -1))

# --------------------------------------------------------------------------
# 运行态直测：tween 模式终值 / resize 复位 / 命中逆变换 / 在途徽章
# --------------------------------------------------------------------------

func test_zoom_step_tween_mode_reaches_target() -> void:
	## tween 模式（兜底 cfg——0.1s SINE/OUT 并行插值）：发起时 scale 尚未
	## 到位（在途）、动画播完后终值 == 目标档（await 若干帧收口）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0))
	var target: float = board._zoom_steps[1]
	board.viewport_zoom_step(1, Vector2(320.0, 320.0))
	# 发起帧尚未到位（tween 起点 = 旧档 1.0 ≠ 目标档——gdUnit 无向量
	## not_approx 口，精确不等断言）
	assert_vector(board._world_layer.scale).is_not_equal(Vector2(target, target)) \
			.override_failure_message("tween 模式发起帧不应瞬跳到位")
	# 目标位即时落账（连续滚动取目标态——tween 未完也不影响下次推算基准）
	assert_int(board._zoom_index).is_equal(1)
	var waited: int = 0
	while board._zoom_tween != null and board._zoom_tween.is_valid() and waited < 120:
		await get_tree().process_frame
		waited += 1
	assert_bool(waited < 120).is_true() \
			.override_failure_message("缩放 tween 未在帧限内完成（盲审修复 10）")
	assert_vector(board._world_layer.scale) \
			.is_equal_approx(Vector2(target, target), Vector2(0.001, 0.001)) \
			.override_failure_message("tween 播完终值应 == 目标档 %s" % str(target))

func test_resize_rebuilds_resets_viewport_and_steps() -> void:
	## resize 防抖重建：缩放平移态放大后改尺寸 → 帧末重建——视口态全复位
	##（scale=ONE/position=ZERO/档归 0/目标位清零）+ 档表按新 fit 重建
	##（640→480 让位 fit 60：zoom_max 2.9333 > 旧 2.2，档表更长）+ WorldLayer
	## 存活未释放 + 重建后地格仍挂 world 下
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0), _InstantCfg())
	var old_steps_size: int = board._zoom_steps.size()
	board.viewport_zoom_step(2, Vector2(150.0, 300.0))
	assert_int(board._zoom_index).is_equal(2)
	var world: Control = board._world_layer
	board.size = Vector2(480.0, 360.0)
	await get_tree().process_frame
	await get_tree().process_frame
	# 视口态全复位
	assert_int(board._zoom_index).is_equal(0)
	assert_vector(world.scale).is_equal(Vector2.ONE)
	assert_vector(world.position).is_equal(Vector2.ZERO)
	assert_vector(board._view_pan_target).is_equal(Vector2.ZERO)
	# 档表按新 fit 重建：480×360 让位 fit=60 → zoom_max = 176/60 ≈ 2.9333
	assert_float(board.cell_width).is_equal(60.0)
	assert_float(board._zoom_steps[board._zoom_steps.size() - 1]) \
			.is_equal_approx(176.0 / 60.0, 0.0001)
	assert_bool(board._zoom_steps.size() > old_steps_size).is_true() \
			.override_failure_message("fit 让位 60 档表应比 fit 80 更长（档数 %d vs %d）" % [
					board._zoom_steps.size(), old_steps_size])
	# WorldLayer 存活 + 地格重挂其下
	assert_bool(is_instance_valid(world) and not world.is_queued_for_deletion()).is_true()
	assert_object(world.get_parent()).is_same(board)
	assert_int(board._cells.size()).is_equal(64)
	for cell: Vector2i in board._cells:
		assert_object((board._cells[cell] as Control).get_parent()).is_same(world)

func test_cell_from_board_local_matches_manual_and_transform_api() -> void:
	## 命中逆变换：设 zoom/pan 后——手算 board_local = pan + zoom × 格中心
	## world local → cell_from_board_local 命中该格；与 transform API 交叉
	## 断言（world.transform.affine_inverse() × board_local == 格中心 world
	## local——两路换算恒等）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0), _InstantCfg())
	# 放大两档（锚点推算产生非零 pan——非退化前提）
	board.viewport_zoom_step(2, Vector2(100.0, 450.0))
	var zoom: float = board._world_layer.scale.x
	var pan: Vector2 = board._world_layer.position
	assert_bool(pan != Vector2.ZERO).is_true() \
			.override_failure_message("前置失败：偏心锚点两档应产生非零 pan")
	for y: int in 8:
		for x: int in 8:
			var cell: Vector2i = Vector2i(x, y)
			var center_world_local: Vector2 = board.cell_rect(cell).get_center()
			var board_local: Vector2 = pan + center_world_local * zoom
			assert_vector(board.cell_from_board_local(board_local)).is_equal(cell) \
					.override_failure_message("视口态格 %s 命中失恒等" % str(cell))
			# transform API 交叉断言（引擎变换与手算公式同构——Control 经
			## get_transform() 取本地变换）
			var via_transform: Vector2 = board._world_layer.get_transform().affine_inverse() \
					* board_local
			assert_vector(via_transform).is_equal_approx(center_world_local,
					Vector2(0.0001, 0.0001))
	# zoom ≤ 0 防御哨兵（口径同 cell_from_local 越界返回）
	board._world_layer.scale = Vector2(-1.0, -1.0)
	assert_vector(board.cell_from_board_local(Vector2(320.0, 320.0))) \
			.is_equal(Vector2i(-1, -1))

func test_inflight_move_badge_tracks_viewport_world_local_identity() -> void:
	## 在途移动中缩放：徽章 world local（position）不因视口缩放变化——
	## 屏幕位置 = world 变换 × local 恒等（缩放只改外层变换，tween 插值
	## 的 local 轨迹零感知）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0), _InstantCfg(), true)
	var unit: BattleUnit = board.context.units[0] as BattleUnit
	var cfg: CoreConfig = board.context.cfg as CoreConfig
	cfg.ui_battle_move_step_seconds = 0.3
	unit.grid_pos = Vector2i(5, 2)
	board.move_badge(unit, Vector2i(2, 2),
			[Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)])
	await get_tree().process_frame
	var badge: UnitBadge = board._badges[&"viewport_probe"]
	assert_object(badge.get_parent()).is_same(board._world_layer)
	var local_before: Vector2 = badge.position
	var screen_before: Vector2 = board._world_layer.get_global_transform() * local_before
	# 在途缩放两档（瞬跳——tween 中断直落）
	board.viewport_zoom_step(2, Vector2(320.0, 320.0))
	# world local 恒等：徽章 local 轨迹不被视口扰动
	assert_vector(badge.position).is_equal(local_before)
	# 屏幕位置随视口同步：global == world 变换 × local（缩放后外层变换改写）
	var screen_after: Vector2 = badge.global_position
	assert_vector(screen_after).is_equal_approx(
			board._world_layer.get_global_transform() * badge.position,
			Vector2(0.0001, 0.0001))
	assert_bool(screen_before != screen_after).is_true() \
			.override_failure_message("前置失败：缩放后徽章屏幕位应随视口改变")
	# 等待在途移动完成（tween 不被缩放 kill——移动演出连续性）
	var waited: int = 0
	while board._move_tweens.has(unit.unit_id) and waited < 300:
		await get_tree().process_frame
		waited += 1
	assert_bool(waited < 300).is_true() \
			.override_failure_message("移动 tween 未在帧限内完成（盲审修复 10）")
	assert_vector(badge.position).is_equal(board.cell_rect(unit.grid_pos).position)

# --------------------------------------------------------------------------
# 运行态直测：平移三口序列 + 轮询兜底 + 720 让位档数
# --------------------------------------------------------------------------

func test_pan_sequence_below_threshold_end_no_suppression() -> void:
	## 未过阈值轻点：begin → 直接收口（未激活）——无位移、tooltip 未抑制
	##（拖动态表现仅激活后进入）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0), _InstantCfg())
	# 造特殊格 tooltip（毒沼 tile 有 description——毒沼格在 8×8 图内存在与否
	# 不定，直接用障碍格：8×8 图必含障碍）
	var tooltip_cell: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in board._cells:
		var tile: TileTypeDef = board.context.grid.tile_at(cell)
		if tile != null and tile.kind != TileTypeDef.Kind.NORMAL:
			tooltip_cell = cell
			break
	assert_bool(tooltip_cell != Vector2i(-1, -1)).is_true() \
			.override_failure_message("前置失败：8×8 图应含特殊格")
	var visual: Control = board._cells[tooltip_cell]
	var tooltip_before: String = visual.tooltip_text
	var filter_before: int = visual.mouse_filter
	assert_bool(tooltip_before.is_empty()).is_false()
	board.viewport_begin_pan(Vector2(100.0, 100.0))
	assert_bool(board.viewport_is_panning()).is_true()
	board.viewport_end_pan()
	assert_bool(board.viewport_is_panning()).is_false()
	assert_vector(board._world_layer.position).is_equal(Vector2.ZERO)
	assert_str(visual.tooltip_text).is_equal(tooltip_before)
	assert_int(visual.mouse_filter).is_equal(filter_before)

func test_pan_activate_suppress_and_restore_tooltips() -> void:
	## 激活拖动序列：begin → 激活（_ActivatePan——headless 不模拟鼠标位移，
	## 激活语义直调验证）→ 格 tooltip 抑制 + IGNORE + CURSOR_MOVE + 在途
	## 缩放 tween kill 直落 → end 恢复（单源 _ApplyAllCellTooltips 重算 +
	## 光标回默认）；幂等二次 end 无异常；盲审修复 1/2 回归锁：pending 期
	## 滚轮改目标位后激活重锚（增量基准 = 激活瞬间终态）、active 态滚轮
	## 早退（拖动禁缩放）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0))
	# 造在途缩放 tween（兜底 0.1s）+ 非零目标 pan——激活时应 kill 并直落
	board.viewport_zoom_step(3, Vector2(100.0, 500.0))
	assert_bool(board._zoom_tween != null and board._zoom_tween.is_valid()).is_true()
	board.viewport_begin_pan(Vector2(200.0, 200.0))
	# 盲审修复 2（S2-2）场景：pending 期滚轮仍可缩放（修复 1 只挡 active
	## 态）——目标档/目标位随之改写，激活须以改写后的终态重锚增量基准
	board.viewport_zoom_step(1, Vector2(100.0, 500.0))
	var pending_index: int = board._zoom_index
	var pending_pan: Vector2 = board._view_pan_target
	assert_int(pending_index).is_equal(4)
	board._ActivatePan()
	assert_bool(board.viewport_is_panning()).is_true()
	# 在途 tween 已 kill、scale/position 直落重锚后目标档终态；
	## _pan_start_pos == 激活瞬间 _view_pan_target（修复 2：无基准跳变）
	assert_bool(board._zoom_tween == null or not board._zoom_tween.is_valid()).is_true()
	assert_vector(board._world_layer.scale) \
			.is_equal_approx(Vector2(board._zoom_steps[pending_index],
					board._zoom_steps[pending_index]), Vector2(0.0001, 0.0001))
	assert_vector(board._world_layer.position).is_equal(pending_pan)
	assert_vector(board._pan_start_pos).is_equal(board._view_pan_target) \
			.override_failure_message("激活时应以当前目标位重锚增量基准（盲审修复 2）")
	# 盲审修复 1 回归锁：active 态滚轮早退（档位/缩放/目标位均不变）
	var active_scale: Vector2 = board._world_layer.scale
	var active_pan: Vector2 = board._view_pan_target
	board.viewport_zoom_step(1, Vector2(320.0, 320.0))
	assert_int(board._zoom_index).is_equal(pending_index) \
			.override_failure_message("拖动态不得响应滚轮缩放（盲审修复 1）")
	assert_vector(board._world_layer.scale).is_equal(active_scale)
	assert_vector(board._view_pan_target).is_equal(active_pan)
	# 拖动态表现：全部格 tooltip 抑制 + IGNORE + 移动光标
	for cell: Vector2i in board._cells:
		assert_str((board._cells[cell] as Control).tooltip_text).is_empty() \
				.override_failure_message("拖动态格 %s tooltip 应抑制" % str(cell))
		assert_int((board._cells[cell] as Control).mouse_filter) \
				.is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(board.mouse_default_cursor_shape).is_equal(Control.CURSOR_MOVE)
	# end 恢复：tooltip 单源重算回归（特殊格描述非空/普通格空）+ 光标默认
	board.viewport_end_pan()
	assert_bool(board.viewport_is_panning()).is_false()
	var restored_special: bool = false
	for cell: Vector2i in board._cells:
		var tile: TileTypeDef = board.context.grid.tile_at(cell)
		if tile != null and tile.kind != TileTypeDef.Kind.NORMAL:
			assert_bool(not (board._cells[cell] as Control).tooltip_text.is_empty()) \
					.override_failure_message("松手后格 %s tooltip 应回归" % str(cell))
			assert_int((board._cells[cell] as Control).mouse_filter) \
					.is_equal(Control.MOUSE_FILTER_PASS)
			restored_special = true
	assert_bool(restored_special).is_true()
	assert_int(board.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)
	# 幂等：二次 end 无异常、状态保持复位
	board.viewport_end_pan()
	assert_bool(board.viewport_is_panning()).is_false()

func test_pan_polling_fallback_ends_pending() -> void:
	## 轮询兜底：begin 后 headless 无中键按下——下一帧 _process 自动收口
	##（gui_input release 丢失路径的全局轮询防线）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0), _InstantCfg())
	board.viewport_begin_pan(Vector2(300.0, 300.0))
	assert_bool(board._pan_pending).is_true()
	await get_tree().process_frame
	assert_bool(board.viewport_is_panning()).is_false() \
			.override_failure_message("中键未按下时 _process 轮询应自动收口 pending")
	# 阈值激活路径已知未覆盖（headless 限制，盲审修复 9/S5-1 实测留痕）：
	## Input.parse_input_event 注入中键 pressed 实测不更新 Input 单例状态
	##（is_mouse_button_pressed 恒 false——headless DisplayServer 无窗口
	## 事件循环），begin→位移>阈值→active 的 _process 轮询判定链无法注入
	## 驱动；激活语义由 test_pan_activate_suppress_and_restore_tooltips
	## 直调 _ActivatePan 覆盖、钳制数学由纯函数用例覆盖，阈值判定本身
	## （PAN_DRAG_THRESHOLD 比较分支）归人工验收（真窗口试玩）

func test_720_yield_layout_has_multi_zoom_steps() -> void:
	## 720 档让位路径（480×360——fit=60 < 下限 72 让位）：档表非单档且
	## 末档 == 176/60（fit 让位后 zoom_max 更大、档更多——缩放仍有意义）
	var board: BattleBoard = _MakeBoard(Vector2(480.0, 360.0), _InstantCfg())
	assert_float(board.cell_width).is_equal(60.0)
	assert_int(board._zoom_steps.size()).is_greater(2) \
			.override_failure_message("720 让位档表应非单档（zoom_max ≈ 2.93）")
	assert_float(board._zoom_steps[0]).is_equal(1.0)
	assert_float(board._zoom_steps[board._zoom_steps.size() - 1]) \
			.is_equal_approx(176.0 / 60.0, 0.0001)

func test_target_tips_position_clamps_in_board_coords_under_viewport() -> void:
	## 盲审修复 4（S4-03）回归锁：tips 上界判据与左右钳制在板本地坐标系
	## 执行——放大平移后 world 本地位置允许越板，换算回板本地必在钳制带内；
	## fit 态（zoom=1/pan=0 两系重合）定位与原公式逐值一致（行为零变化）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0), _InstantCfg())
	var cell: Vector2i = Vector2i(3, 3)
	# fit 态锚定：与修复前定位公式（格上方居中）逐值一致
	board.show_target_tips(cell, "预计伤害 5", "命中率 85%")
	var panel: PanelContainer = board.target_tips_panel()
	var tips_size: Vector2 = panel.get_minimum_size()
	var rect: Rect2 = board.cell_rect(cell)
	var expected: Vector2 = Vector2(
			rect.position.x + (rect.size.x - tips_size.x) * 0.5,
			rect.position.y - tips_size.y - BattleBoard.TIPS_MARGIN)
	assert_vector(panel.position).is_equal_approx(expected, Vector2(0.5, 0.5)) \
			.override_failure_message("fit 态 tips 定位应与原公式一致（行为零变化）")
	# 视口态：放大两档（偏心锚点产生非零 pan）重定位——板本地恒在界内
	board.viewport_zoom_step(2, Vector2(100.0, 450.0))
	board.show_target_tips(cell, "预计伤害 5", "命中率 85%")
	var zoom: float = board._world_layer.scale.x
	var pan: Vector2 = board._world_layer.position
	var board_pos: Vector2 = panel.position * zoom + pan
	assert_float(board_pos.x).is_greater_equal(BattleBoard.TIPS_CLAMP_MARGIN - 0.5) \
			.override_failure_message("视口态 tips 板本地左界越出钳制带")
	assert_float(board_pos.x).is_less_equal(
			640.0 - tips_size.x - BattleBoard.TIPS_CLAMP_MARGIN + 0.5) \
			.override_failure_message("视口态 tips 板本地右界越出钳制带")

func test_target_tips_flips_below_cell_when_board_top_scrolled_out() -> void:
	## R1-01：tips y 上界翻转分支视口态回归——深负 pan.y（板上缘滚出视口）
	## 下顶行格 tips：world 本地「格上方」位换算板本地 y < 0 触发翻转（改落
	## 格下方），断言翻转后 tips 板本地 y ≥ 格底（不压格、不出板顶）
	var board: BattleBoard = _MakeBoard(Vector2(640.0, 640.0), _InstantCfg())
	var cell: Vector2i = Vector2i(3, 0)
	# 先 fit 态触发一次 tips 建面板取尺寸（懒建——后续视口态重定位复用）
	board.show_target_tips(cell, "预计伤害 5", "命中率 85%")
	var panel: PanelContainer = board.target_tips_panel()
	var tips_size: Vector2 = panel.get_minimum_size()
	# 连续放大至末档、锚点 y 取板外深位——pan.y 被钳到 Y 溢出带下界
	##（640×640 板 fit=80：box.y=320、末档 2.2 溢出 640——带
	## [640−480×2.2, −160×2.2] = [−416, −352]），锚点 (100, 2000) 推出
	## 深负 pan.y = −416
	for index: int in board._zoom_steps.size() - 1:
		board.viewport_zoom_step(1, Vector2(100.0, 2000.0))
	var zoom: float = board._world_layer.scale.x
	var pan: Vector2 = board._world_layer.position
	assert_float(pan.y).is_less(-350.0) \
			.override_failure_message("前置失败：锚点下推应产生深负 pan.y（实际 %s）" % str(pan))
	# 顶行格 (3,0)：格上方 tips 位换算板本地 y < 0（翻转判据命中）
	var rect: Rect2 = board.cell_rect(cell)
	var above_board_y: float = (rect.position.y - tips_size.y
			- BattleBoard.TIPS_MARGIN) * zoom + pan.y
	assert_float(above_board_y).is_less(0.0) \
			.override_failure_message("前置失败：视口态顶行格上方位板本地应出板顶")
	board.show_target_tips(cell, "预计伤害 5", "命中率 85%")
	# 翻转断言：tips 落格下方（板本地 y ≥ 格底板本地 y——不压格不假翻转）
	var tips_board_y: float = panel.position.y * zoom + pan.y
	var cell_bottom_board_y: float = (rect.position.y + rect.size.y) * zoom + pan.y
	assert_float(tips_board_y).is_greater_equal(cell_bottom_board_y - 0.5) \
			.override_failure_message("翻转后 tips 板本地 y 应 ≥ 格底（落格下方）")
