## BattleBoard 路径闪烁高光机制单元测试（试玩反馈批：A8 箭头表现改
## 呼吸式高光——D4 契约修订；二轮修复：预览路径与移动裁决同源——
## show_path_preview 直收 find_path 结果，直线近似（lerp 穿障碍）废除；
## 漏洞1 修复：高光双池分层——预览入 _path_overlays（选择态，clear_overlays
## 可清）、move_badge 移动燃线入 _burning_overlays（独立演出生命周期，
## 不随 clear_overlays/_ClearSelection 清理，由逐格熄灭回调自清——
## 断言目标随分层锚定各自池）
## 覆盖：show_path_preview 高光渲染（逐格 ColorRect 满格 + 金色 + 峰值起步
## + 池/映射双登记）/ 绕障碍同源断言（真实 8×8 图：预览格集 == find_path
## 结果逐格、不含障碍、≠ 旧直线插值集合）/ 空路径清旧（不可达双保险）/
## 参数表驱动与非法回退（cfg 峰值/周期/渐变形态三读取口）/ 燃线单格熄灭
##（池与映射同步减、幂等）/ move_badge 演出分支燃线生命周期（L 形路径中途
## 格全覆盖——逐格序列无拐点压缩、瞬移/哨兵分支不建）/ clear_overlays 清
## 预览池清映射且**不清燃线池**（分层回归锚定）。
## 注：闪烁动态（呼吸相位）与移动中逐格熄灭时序属树内推进行为，归
## test_battle_anim_flow 集成用例与视觉冒烟截图，本套离树只锚静态契约。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## 真实 8×8 地图与地格目录（绕障碍同源用例——test_battle_grid 同款夹具）
const MAP_PATH: String = "res://data/battle/maps/btm_m1_random_8x8.tres"
const TILE_DIR: String = "res://data/battle/tiles/"

## 套件级 GameData 实例
var _game_data: Node

## 套件级地格定义池（绕障碍用例）
var _tiles: Dictionary = {}

## 测试替身单位（鸭子契约：id/side/alive/grid_pos——find_path 消费面）
class FakeUnit:
	extends RefCounted
	var id: StringName = &"unit"
	var side: int = 0
	var alive: bool = true
	var grid_pos: Vector2i = Vector2i.ZERO

func before() -> void:
	## 套件前置：实例化 GameData 并显式初始化；加载六地格表（绕障碍用例）
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()
	_tiles = {}
	for tile_id: StringName in [&"tile_normal", &"tile_obstacle", &"tile_grass",
			&"tile_highground", &"tile_poison_swamp", &"tile_trap"]:
		_tiles[tile_id] = load(TILE_DIR + String(tile_id) + ".tres")

func after() -> void:
	## 套件后置：清纹理缓存（防污染后续套件）
	## 参数：无
	## 返回：无
	AssetTex.clear_cache()

func _MakeBoard() -> BattleBoard:
	## 离树 BattleBoard 实例（几何手填——show_path_preview/_ShowPathHighlights
	## 不消费 context 之外的装配，高光渲染可离树验证；E1：手填菱形全宽
	## cell_width，cell_height 经 iso_ratio 兜底派生 0.5×64=32）
	## 参数：无
	## 返回：装配好几何与 game_data 的板层实例
	var board: BattleBoard = auto_free(BattleBoard.new())
	board.cell_width = 64.0
	board.origin = Vector2.ZERO
	board._game_data = _game_data
	return board

func _MakeContextWith(cfg: CoreConfig) -> BattleSetup.BattleContext:
	## 轻构战斗上下文（只挂 cfg——参数读取口消费面）
	## 参数 cfg：总控配置
	## 返回：上下文
	var ctx: BattleSetup.BattleContext = BattleSetup.BattleContext.new()
	ctx.cfg = cfg
	return ctx

func _MakeRealGrid() -> BattleGrid:
	## 真实 8×8 战场构建（绕障碍用例——test_battle_grid 同款：地图+六地格表）
	## 参数：无
	## 返回：已装配战场（setup 失败断言兜底）
	var map_def: BattleMapDef = load(MAP_PATH) as BattleMapDef
	var grid: BattleGrid = auto_free(BattleGrid.new())
	assert_bool(grid.setup(map_def, _LookupTile)).is_true()
	return grid

func _LookupTile(tile_id: StringName) -> TileTypeDef:
	## 地格定义解析闭包（字典查找——test_battle_grid 同款）
	## 参数 tile_id：地格 id
	## 返回：TileTypeDef（未登记返回 null）
	return _tiles.get(tile_id, null)

func _PlaceUnit(grid: BattleGrid, pos: Vector2i) -> FakeUnit:
	## 构建并放置替身单位（find_path 鸭子契约消费面）
	## 参数 grid：战场；pos：所在格
	## 返回：已放置单位
	var unit := FakeUnit.new()
	unit.grid_pos = pos
	grid.place_unit(pos, unit)
	return unit

func test_show_path_preview_renders_highlight_cells() -> void:
	## 高光渲染：直收 3 格路径 → 池 3 holder、映射 3 键，每 holder 一满盒
	## 菱形色面（E1：DiamondFill——金色高光色、IGNORE 鼠标契约；holder
	## position/size 断言经 board.cell_rect 取值——消除用例内联数学）
	var board: BattleBoard = _MakeBoard()
	var preview_cells: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	board.show_path_preview(preview_cells)
	assert_int(board._path_overlays.size()).is_equal(3)
	assert_int(board._path_highlight_cells.size()).is_equal(3)
	for index: int in board._path_overlays.size():
		var holder: Control = board._path_overlays[index]
		assert_int(holder.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		var cell: Vector2i = preview_cells[index]
		assert_vector(holder.position).is_equal(board.cell_rect(cell).position)
		assert_bool(holder.size == board.cell_rect(cell).size).override_failure_message(
				"高光块应满盒（不被其他尺寸钳制）").is_true()
		var glow: Control = holder.get_child(0)
		assert_object(glow).is_not_null()
		assert_bool(glow.size == holder.size) \
				.override_failure_message("高光色面应满盒").is_true()
		var diamond: BattleBoard.DiamondFill = holder.get_child(0) as BattleBoard.DiamondFill
		assert_object(diamond).is_not_null()
		assert_bool(diamond.fill_color == UiTheme.BATTLE_PATH_HIGHLIGHT_COLOR) \
				.override_failure_message("高光色应为金色表驱动色").is_true()

func test_show_path_preview_matches_find_path_around_obstacles() -> void:
	## 二轮修复核心断言（同源）：真实 8×8 图 (4,3)→(0,3)——y=3 行被障碍
	## (3,3)/(1,3) 阻断，预览高光格集 == find_path（request_move 移动同款
	## 寻路函数）结果逐格一一对应；路径不含障碍格、长于直线距离（绕行），
	## 且 ≠ 旧直线插值集合（lerp 穿障碍行为已废除的锚定）
	var grid: BattleGrid = _MakeRealGrid()
	var unit: FakeUnit = _PlaceUnit(grid, Vector2i(4, 3))
	var path: Array[Vector2i] = grid.find_path(unit, Vector2i(4, 3),
			Vector2i(0, 3), 8)
	assert_int(path.size()).is_greater(4) \
			.override_failure_message("y=3 行被双障碍阻断——真实路径应绕行长于直线 4 格")
	assert_bool(path.has(Vector2i(3, 3))).is_false() \
			.override_failure_message("真实寻路路径不得含障碍格 (3,3)")
	assert_bool(path.has(Vector2i(1, 3))).is_false() \
			.override_failure_message("真实寻路路径不得含障碍格 (1,3)")
	assert_vector(path[path.size() - 1]).is_equal(Vector2i(0, 3))
	var board: BattleBoard = _MakeBoard()
	board.show_path_preview(path)
	assert_int(board._path_highlight_cells.size()).is_equal(path.size())
	for cell: Vector2i in path:
		assert_bool(board._path_highlight_cells.has(cell)) \
				.override_failure_message("预览高光与寻路路径逐格一一对应（缺 %s）" % str(cell)).is_true()
	# 旧直线插值集合（lerp 时代产物）与真实路径必有差异——同源而非直线的锚定
	var straight_line: Array[Vector2i] = [Vector2i(3, 3), Vector2i(2, 3),
			Vector2i(1, 3), Vector2i(0, 3)]
	assert_bool(straight_line.has(Vector2i(3, 3))).is_true()
	var is_same: bool = straight_line.size() == path.size()
	if is_same:
		for index: int in straight_line.size():
			if straight_line[index] != path[index]:
				is_same = false
				break
	assert_bool(is_same).is_false() \
			.override_failure_message("真实路径不应等于直线插值集合（穿障碍旧行为复活？）")

func test_show_path_preview_empty_path_clears_old_highlights() -> void:
	## 空路径边界（不可达/退化——find_path 返回空）：清旧预览不画新高光
	##（调用方可达性过滤外的双保险）
	var board: BattleBoard = _MakeBoard()
	board.show_path_preview([Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])
	assert_int(board._path_overlays.size()).is_equal(3)
	board.show_path_preview([])
	assert_int(board._path_overlays.size()).is_equal(0)
	assert_int(board._path_highlight_cells.size()).is_equal(0)

func test_highlight_starts_at_peak_alpha() -> void:
	## 峰值起步：预览瞬间即以峰值 alpha 可见（呼吸循环从峰值出发向谷值回落；
	## E1：glow 泛化 Control（DiamondFill）——modulate.a 契约零改）
	var board: BattleBoard = _MakeBoard()
	board.show_path_preview([Vector2i(1, 0), Vector2i(2, 0)])
	for holder: Control in board._path_overlays:
		var glow: Control = holder.get_child(0)
		assert_float(glow.modulate.a).is_equal_approx(
				UiTheme.BATTLE_PATH_HIGHLIGHT_PEAK_ALPHA, 0.001)

func test_path_preview_replaces_previous_highlights() -> void:
	## 清旧画新：二次预览（换目标格）不叠层——池与映射按新路径重建
	var board: BattleBoard = _MakeBoard()
	board.show_path_preview([Vector2i(1, 0), Vector2i(2, 0)])
	board.show_path_preview([Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)])
	assert_int(board._path_overlays.size()).is_equal(4)
	assert_int(board._path_highlight_cells.size()).is_equal(4)
	assert_bool(board._path_highlight_cells.has(Vector2i(4, 0))).is_true()

func test_clear_overlays_clears_preview_pool_not_burning_pool() -> void:
	## clear 链路回归（漏洞1 修复分层锚定）：clear_overlays 清**预览**池与
	## 映射双清零，**不触燃线池**（独立演出生命周期——燃线由逐格熄灭回调与
	## 移动 tween finished 自然烧完自清，行动轮切换不截断在途燃线）
	var fixture: Array = _MakeMoveFixture(0.05)
	var board: BattleBoard = fixture[0]
	var unit: BattleUnit = fixture[1]
	unit.grid_pos = Vector2i(2, 0)
	board.move_badge(unit, Vector2i(0, 0), [Vector2i(1, 0), Vector2i(2, 0)])
	board.show_path_preview([Vector2i(4, 0), Vector2i(5, 0)])
	assert_int(board._burning_overlays.size()).is_equal(2)
	assert_int(board._path_overlays.size()).is_equal(2)
	board.clear_overlays()
	assert_int(board._path_overlays.size()).is_equal(0)
	assert_int(board._path_highlight_cells.size()).is_equal(0)
	assert_int(board._burning_overlays.size()).is_equal(2) \
			.override_failure_message("clear_overlays 不得清在途移动燃线（漏洞1 修复）")
	assert_int(board._burning_highlight_cells.size()).is_equal(2)

func test_extinguish_removes_cell_and_is_idempotent() -> void:
	## 燃线单格熄灭：走过的格从燃线池与映射同步移除；重复熄灭/未知格熄灭
	## 幂等不崩（漏洞1 修复：熄灭对象锚定燃线池——预览层不走熄灭，由
	## show_path_preview 清池重画）
	var fixture: Array = _MakeMoveFixture(0.05)
	var board: BattleBoard = fixture[0]
	var unit: BattleUnit = fixture[1]
	unit.grid_pos = Vector2i(3, 0)
	board.move_badge(unit, Vector2i(0, 0), [Vector2i(1, 0), Vector2i(2, 0),
			Vector2i(3, 0)])
	assert_int(board._burning_overlays.size()).is_equal(3)
	var holder: Control = board._burning_highlight_cells[Vector2i(1, 0)]
	board._ExtinguishPathHighlight(Vector2i(1, 0))
	assert_int(board._burning_overlays.size()).is_equal(2)
	assert_bool(board._burning_highlight_cells.has(Vector2i(1, 0))).is_false()
	assert_bool(is_instance_valid(holder)).is_true()
	# 幂等：同格再熄/未知格熄均无效果不崩
	board._ExtinguishPathHighlight(Vector2i(1, 0))
	board._ExtinguishPathHighlight(Vector2i(99, 99))
	assert_int(board._burning_overlays.size()).is_equal(2)

func test_highlight_params_fallback_on_missing_or_invalid_cfg() -> void:
	## 参数回退：cfg 缺失（context null）或表值非法（峰值越 (0,1]/周期 ≤ 0/
	## 渐变形态越枚举界）→ 三读取口回退 UiTheme 兜底；合法表值注入生效
	var board: BattleBoard = _MakeBoard()
	assert_float(board._PathHighlightPeakAlpha()).is_equal_approx(
			UiTheme.BATTLE_PATH_HIGHLIGHT_PEAK_ALPHA, 0.0001)
	assert_float(board._PathHighlightFlashSeconds()).is_equal_approx(
			UiTheme.BATTLE_PATH_HIGHLIGHT_FLASH_SECONDS, 0.0001)
	assert_int(board._PathHighlightTrans()).is_equal(UiTheme.BATTLE_PATH_HIGHLIGHT_TRANS)
	var cfg: CoreConfig = auto_free(CoreConfig.new())
	board.context = _MakeContextWith(cfg)
	assert_float(board._PathHighlightPeakAlpha()).is_equal_approx(
			UiTheme.BATTLE_PATH_HIGHLIGHT_PEAK_ALPHA, 0.0001) \
			.override_failure_message("峰值 0（未回填）应回退兜底")
	assert_float(board._PathHighlightFlashSeconds()).is_equal_approx(
			UiTheme.BATTLE_PATH_HIGHLIGHT_FLASH_SECONDS, 0.0001) \
			.override_failure_message("周期 0（未回填）应回退兜底")
	assert_int(board._PathHighlightTrans()).is_equal(
			UiTheme.BATTLE_PATH_HIGHLIGHT_TRANS) \
			.override_failure_message("渐变形态 0（未回填哨兵）应回退兜底 SINE")
	cfg.ui_battle_path_highlight_peak_alpha = 2.0
	cfg.ui_battle_path_highlight_flash_seconds = -0.5
	cfg.ui_battle_path_highlight_trans = 99
	assert_float(board._PathHighlightPeakAlpha()).is_equal_approx(
			UiTheme.BATTLE_PATH_HIGHLIGHT_PEAK_ALPHA, 0.0001)
	assert_float(board._PathHighlightFlashSeconds()).is_equal_approx(
			UiTheme.BATTLE_PATH_HIGHLIGHT_FLASH_SECONDS, 0.0001)
	assert_int(board._PathHighlightTrans()).is_equal(UiTheme.BATTLE_PATH_HIGHLIGHT_TRANS)
	cfg.ui_battle_path_highlight_peak_alpha = 0.4
	cfg.ui_battle_path_highlight_flash_seconds = 1.2
	cfg.ui_battle_path_highlight_trans = Tween.TransitionType.TRANS_CUBIC
	assert_float(board._PathHighlightPeakAlpha()).is_equal_approx(0.4, 0.0001)
	assert_float(board._PathHighlightFlashSeconds()).is_equal_approx(1.2, 0.0001)
	assert_int(board._PathHighlightTrans()).is_equal(Tween.TransitionType.TRANS_CUBIC)

func _MakeMoveFixture(cfg_step_seconds: float) -> Array:
	## move_badge 测试夹具：离树板 + 轻构上下文（步长注入）+ 塞入未装配徽章
	##（move_badge 只消费 position/play_action——未 setup 徽章逻辑进态视觉缺省）
	## 参数 cfg_step_seconds：注入步长（0 = 瞬移分支）
	## 返回：[board, unit]
	var board: BattleBoard = _MakeBoard()
	var cfg: CoreConfig = auto_free(CoreConfig.new())
	cfg.ui_battle_move_step_seconds = cfg_step_seconds
	cfg.ui_battle_move_max_steps = 6
	board.context = _MakeContextWith(cfg)
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = &"test_ally"
	unit.grid_pos = Vector2i(3, 0)
	var badge: UnitBadge = auto_free(UnitBadge.new())
	board._badges[unit.unit_id] = badge
	return [board, unit]

func test_move_badge_tween_branch_builds_highlights_on_full_path() -> void:
	## 移动开始燃线：tween 分支按真实路径立即建**燃线**（独立池）——L 形 5 格
	## 路径（含同列段）中途格全入燃线（逐格序列无拐点压缩——「拐点间逐格补全」
	## 锚定）；燃线池/映射键集与路径格一一对应（含终点不含起点），且与预览
	## 池分层互不串扰（预览池空——燃线不占选择态池）
	var fixture: Array = _MakeMoveFixture(0.05)
	var board: BattleBoard = fixture[0]
	var unit: BattleUnit = fixture[1]
	unit.grid_pos = Vector2i(3, 2)
	board.move_badge(unit, Vector2i(0, 0), [Vector2i(1, 0), Vector2i(2, 0),
			Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)])
	assert_int(board._burning_overlays.size()).is_equal(5)
	assert_int(board._burning_highlight_cells.size()).is_equal(5)
	assert_int(board._path_overlays.size()).is_equal(0) \
			.override_failure_message("移动燃线应入独立池，不占预览池")
	for cell: Vector2i in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
			Vector2i(3, 1), Vector2i(3, 2)]:
		assert_bool(board._burning_highlight_cells.has(cell)) \
				.override_failure_message("路径中途格 %s 应在燃线列（逐格无压缩）" % str(cell)).is_true()
	assert_bool(board._burning_highlight_cells.has(Vector2i(0, 0))).is_false() \
			.override_failure_message("燃线不含起点格（与预览口径一致）")

func test_move_badge_teleport_branch_builds_no_highlights() -> void:
	## 瞬移分支（步长 ≤ 0）：无演出过程不建燃线（直落 + 立即回落 IDLE——
	## 低6 口径不动）；若瞬移中断了在途演出（had_move_tween）其旧燃线随
	## kill 失去熄灭回调被一并清（漏洞1 修复边界 c 收口）
	var fixture: Array = _MakeMoveFixture(0.0)
	var board: BattleBoard = fixture[0]
	var unit: BattleUnit = fixture[1]
	board.move_badge(unit, Vector2i(0, 0), [Vector2i(3, 0)])
	assert_int(board._burning_overlays.size()).is_equal(0)
	assert_int(board._burning_highlight_cells.size()).is_equal(0)

func test_move_badge_no_move_sentinel_builds_no_highlights() -> void:
	## 无效起点哨兵（直落分支）：不建燃线
	var fixture: Array = _MakeMoveFixture(0.05)
	var board: BattleBoard = fixture[0]
	var unit: BattleUnit = fixture[1]
	board.move_badge(unit)
	assert_int(board._burning_overlays.size()).is_equal(0)

func test_move_badge_teleport_interrupt_clears_inflight_burning() -> void:
	## 漏洞1 修复边界 c 收口锚定：单位在途燃线烧着（tween 分支先建）→ 同单位
	## 瞬移直落（步长改注 0 重入 move_badge）——旧 tween 被 kill，逐格熄灭
	## 回调随之失效，在途燃线必须一并清（修复前残留至 resize 重建）
	var fixture: Array = _MakeMoveFixture(0.05)
	var board: BattleBoard = fixture[0]
	var unit: BattleUnit = fixture[1]
	unit.grid_pos = Vector2i(2, 0)
	board.move_badge(unit, Vector2i(0, 0), [Vector2i(1, 0), Vector2i(2, 0)])
	assert_int(board._burning_overlays.size()).is_equal(2)
	assert_bool(board._move_tweens.has(unit.unit_id)).is_true()
	# 步长改注 0：同单位再入 move_badge 走瞬移分支——kill 在途 tween + 清燃线
	var cfg: CoreConfig = board.context.cfg
	cfg.ui_battle_move_step_seconds = 0.0
	unit.grid_pos = Vector2i(0, 2)
	board.move_badge(unit, Vector2i(2, 0), [Vector2i(1, 0), Vector2i(0, 1),
			Vector2i(0, 2)])
	assert_int(board._burning_overlays.size()).is_equal(0) \
			.override_failure_message("瞬移中断在途演出后燃线未清（失去熄灭回调将永久残留）")
	assert_int(board._burning_highlight_cells.size()).is_equal(0)
