## BattleBoard 路径箭头机制单元测试（M6 批 3.5a A8）
## 覆盖：path_arrow_rotation 逐格方向推导（右 0/下 90/左 180/上 270、末格沿用
## 前方向、单格回退、对角步水平优先）/ show_path_preview 箭头渲染（占位箭头
## 在档时逐格 TextureRect + 池契约）/ 缺件降级（缓存注入 null 回退逐格高亮
## overlay）——_path_overlays 池与 clear 链路零改的回归锚定。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 实例
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData 并显式初始化
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

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

func _MakeBoard() -> BattleBoard:
	## 离树 BattleBoard 实例（几何手填——show_path_preview/_ShowPathArrows 不
	## 消费 context，覆盖层渲染可离树验证）
	## 参数：无
	## 返回：装配好几何与 game_data 的板层实例
	var board: BattleBoard = auto_free(BattleBoard.new())
	board.cell_size = 64.0
	board.origin = Vector2.ZERO
	board._game_data = _game_data
	return board

func test_arrow_rotation_four_directions() -> void:
	## 四方向推导：右 0 / 下 90 / 左 180 / 上 270（右向基准素材旋转映射）
	var right_path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	assert_float(BattleBoard.path_arrow_rotation(right_path, 0)).is_equal(0.0)
	assert_float(BattleBoard.path_arrow_rotation(right_path, 1)).is_equal(0.0)
	var down_path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
	assert_float(BattleBoard.path_arrow_rotation(down_path, 0)).is_equal(90.0)
	var left_path: Array[Vector2i] = [Vector2i(2, 0), Vector2i(1, 0)]
	assert_float(BattleBoard.path_arrow_rotation(left_path, 0)).is_equal(180.0)
	var up_path: Array[Vector2i] = [Vector2i(0, 2), Vector2i(0, 1)]
	assert_float(BattleBoard.path_arrow_rotation(up_path, 0)).is_equal(270.0)

func test_arrow_rotation_last_cell_inherits_previous() -> void:
	## 末格沿用前方向：L 折线 [右, 右, 下]——末格（下段终点）沿用前段方向 90°
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)]
	assert_float(BattleBoard.path_arrow_rotation(cells, 1)).is_equal(0.0)
	assert_float(BattleBoard.path_arrow_rotation(cells, 2)).is_equal(90.0)
	assert_float(BattleBoard.path_arrow_rotation(cells, 3)).is_equal(90.0)

func test_arrow_rotation_single_cell_and_diagonal() -> void:
	## 单格路径回退 0°（右）；对角步（直线近似斜向跳格）水平分量优先（0/180）
	var single: Array[Vector2i] = [Vector2i(3, 3)]
	assert_float(BattleBoard.path_arrow_rotation(single, 0)).is_equal(0.0)
	var diagonal_right: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1)]
	assert_float(BattleBoard.path_arrow_rotation(diagonal_right, 0)).is_equal(0.0)
	var diagonal_left: Array[Vector2i] = [Vector2i(2, 0), Vector2i(1, 1)]
	assert_float(BattleBoard.path_arrow_rotation(diagonal_left, 0)).is_equal(180.0)

func test_show_path_preview_renders_arrow_textures() -> void:
	## 箭头渲染（占位箭头在档）：水平路径 3 格 → 池 3 个 holder，每 holder 一
	## 个 TextureRect 子节点、纹理非空、旋转角契约（全 0°）
	var board: BattleBoard = _MakeBoard()
	board.show_path_preview(Vector2i(0, 0), Vector2i(3, 0))
	assert_int(board._path_overlays.size()).is_equal(3)
	for index: int in board._path_overlays.size():
		var holder: Control = board._path_overlays[index]
		var sprite: TextureRect = holder.get_child(0) as TextureRect
		assert_object(sprite).is_not_null()
		assert_object(sprite.texture).is_not_null()
		assert_float(sprite.rotation_degrees).is_equal(
				BattleBoard.path_arrow_rotation(
						[Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], index))
	# 清池链路零改回归：clear_overlays 后池归零
	board.clear_overlays()
	assert_int(board._path_overlays.size()).is_equal(0)

func test_arrow_texture_size_matches_cell_and_pivot_centered() -> void:
	## 高1 尺寸契约：箭头 TextureRect 的 stretch/expand 先于 size/pivot 设置
	##（expand 默认 KEEP_SIZE 时纹理 min-size 128×128 钳住 size 赋值——箭头
	## 恒纹理原尺寸溢出格 40-88px）；断言箭头 size == holder size == 满格
	## cell_size、pivot == size*0.5（居中旋转不偏移）
	var board: BattleBoard = _MakeBoard()
	board.show_path_preview(Vector2i(0, 0), Vector2i(3, 0))
	# 路径箭头不含起点格（与既有渲染用例同口径——中间+目标 3 格）
	assert_int(board._path_overlays.size()).is_equal(3)
	for holder: Control in board._path_overlays:
		var sprite: TextureRect = holder.get_child(0) as TextureRect
		assert_object(sprite).is_not_null()
		assert_int(sprite.stretch_mode).is_equal(TextureRect.STRETCH_SCALE)
		assert_int(sprite.expand_mode).is_equal(TextureRect.EXPAND_IGNORE_SIZE)
		assert_bool(sprite.size == holder.size).override_failure_message(
				"箭头尺寸应 == 格尺寸（不被纹理 min-size 钳制）").is_true()
		assert_bool(sprite.size == Vector2(64.0, 64.0)).is_true()
		assert_bool(sprite.pivot_offset == sprite.size * 0.5).override_failure_message(
				"箭头 pivot 应居中（旋转不偏移格心）").is_true()

func test_show_path_preview_falls_back_to_overlay_when_missing() -> void:
	## 缺件降级：缓存注入 null（模拟 registry 缺箭头登记）→ 回退现状逐格高亮
	## overlay（holder 子节点 = ColorRect 填充块非 TextureRect 箭头）；
	## M6 批 3.5b 组 8 注：_ShowOverlay 填充块另有 fx_battle_range 染色态
	##（TextureRect），本用例锚定「色块回退」需同时注入 range 缺件
	AssetTex.clear_cache()
	AssetTex._cache[BattleBoard.PATH_ARROW_ASSET_ID] = null
	AssetTex._cache[BattleBoard.RANGE_OVERLAY_ASSET_ID] = null
	var board: BattleBoard = _MakeBoard()
	board.show_path_preview(Vector2i(0, 0), Vector2i(2, 0))
	assert_int(board._path_overlays.size()).is_equal(2)
	for holder: Control in board._path_overlays:
		var fill: ColorRect = holder.get_child(0) as ColorRect
		assert_object(fill).is_not_null()
	# 箭头资产在档恢复（清缓存后直查 registry）→ 重新走箭头形态
	AssetTex.clear_cache()
	board.show_path_preview(Vector2i(0, 0), Vector2i(2, 0))
	var sprite: TextureRect = board._path_overlays[0].get_child(0) as TextureRect
	assert_object(sprite).is_not_null()
