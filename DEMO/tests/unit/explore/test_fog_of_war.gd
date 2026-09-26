## 战争迷雾单元测试（M3 批 1；2026-09-26 遮挡拍板扩测）
## 覆盖：三态判定（UNSEEN/DIM/LIT）/ 圆形边界（无墙场景等价圆：格心欧氏
## (3,0)/(2,2) 界内、(3,1)≈3.16 界外）/ 墙体遮挡（墙后不可见/墙格自身可见/
## 绕侧可见/揭示解除遮挡——实时回调）/ 已探索记忆 DIM 不受遮挡影响 /
## 全亮行恒亮（村子段不随距离退暗）/ 记忆累积（重复移动不重复揭示）/ 实例隔离。
extends GdUnitTestSuite

func _MakeFog(radius: int, lit_rows: Array[int], size: Vector2i) -> FogOfWar:
	## 构建迷雾实例（无遮蔽回调——纯圆形口径）
	## 参数 radius/lit_rows/size：装配参数
	## 返回：FogOfWar
	var fog := FogOfWar.new()
	fog.setup(radius, lit_rows, size)
	return fog

func _MakeOpaqueFog(radius: int, lit_rows: Array[int], size: Vector2i,
		walls: Dictionary) -> FogOfWar:
	## 构建带遮蔽回调的迷雾实例（walls 字典即墙集——实时可变，揭示解除
	## 遮挡用例经增删条目模拟暗门 reveal）
	## 参数 radius/lit_rows/size：装配参数；walls：墙格集（Vector2i -> true）
	## 返回：FogOfWar
	var fog := FogOfWar.new()
	fog.setup(radius, lit_rows, size,
			func(cell: Vector2i) -> bool: return walls.has(cell))
	return fog

func test_circle_boundary_offsets() -> void:
	## 圆形边界（无墙场景等价圆）：半径 3 中心 (5,5)——(3,0) 偏移距离 3 与
	## (2,2)≈2.83 界内；(3,1)≈3.16 界外（欧氏圆形非切比雪夫）；无遮蔽回调
	## 与恒透明回调两口径等价（遮挡拍板后圆形为无墙特例）
	var fog := _MakeFog(3, [], Vector2i(10, 10))
	var cells: Array[Vector2i] = fog.visible_cells(Vector2i(5, 5))
	assert_bool(cells.has(Vector2i(3, 5))).is_true()
	assert_bool(cells.has(Vector2i(7, 7))).is_true()
	assert_bool(cells.has(Vector2i(8, 6))).is_false()
	# 圆形格数锚点：dx,dy ∈ [-3,3] 且 dx²+dy² ≤ 9 = 29 格
	assert_int(cells.size()).is_equal(29)
	# 恒透明回调等价（无墙 = 全通透）
	var transparent := _MakeOpaqueFog(3, [], Vector2i(10, 10), {})
	assert_int(transparent.visible_cells(Vector2i(5, 5)).size()).is_equal(29)

func test_visible_cells_clipped_to_bounds() -> void:
	## 视野裁边：靠边位置可见集不越界（(0,0) 半径 3 → 仅界内格）
	var fog := _MakeFog(3, [], Vector2i(10, 10))
	var cells: Array[Vector2i] = fog.visible_cells(Vector2i(0, 0))
	for cell: Vector2i in cells:
		assert_bool(cell.x >= 0 and cell.x < 10 and cell.y >= 0 and cell.y < 10).is_true()
	assert_bool(cells.has(Vector2i(3, 0))).is_true()
	assert_bool(cells.has(Vector2i(0, 3))).is_true()

func test_three_states() -> void:
	## 三态：视野内 LIT / 离开后 DIM（记忆）/ 未达区域 UNSEEN
	var fog := _MakeFog(2, [], Vector2i(10, 10))
	fog.on_moved(Vector2i(0, 0))
	# 视野内（距离 ≤ 2）LIT
	assert_int(fog.state_of(Vector2i(1, 1), Vector2i(0, 0))).is_equal(FogOfWar.CellState.LIT)
	# 已探索但离队（(0,0) 距 (4,0) = 4 > 2）DIM
	fog.on_moved(Vector2i(4, 0))
	assert_int(fog.state_of(Vector2i(0, 0), Vector2i(4, 0))).is_equal(FogOfWar.CellState.DIM)
	# 从未入视野的远格 UNSEEN
	assert_int(fog.state_of(Vector2i(9, 9), Vector2i(4, 0))).is_equal(FogOfWar.CellState.UNSEEN)

func test_lit_rows_always_lit() -> void:
	## 全亮行恒亮：村子行 [0,1,2]——离队再远也不退暗（不随距离 DIM）
	var fog := _MakeFog(2, [0, 1, 2], Vector2i(10, 10))
	fog.on_moved(Vector2i(9, 2))
	assert_int(fog.state_of(Vector2i(0, 0), Vector2i(9, 2))).is_equal(FogOfWar.CellState.LIT)
	assert_int(fog.state_of(Vector2i(5, 1), Vector2i(9, 2))).is_equal(FogOfWar.CellState.LIT)
	# 非全亮行不受影响（矿洞行照常按距离）
	assert_int(fog.state_of(Vector2i(0, 3), Vector2i(9, 2))).is_equal(FogOfWar.CellState.UNSEEN)

func test_memory_accumulates_no_duplicates() -> void:
	## 记忆累积：首次移动返回新揭示集；原地重复移动返回空；已探索格不再重复计入
	var fog := _MakeFog(2, [], Vector2i(10, 10))
	var first: Array[Vector2i] = fog.on_moved(Vector2i(5, 5))
	assert_int(first.size()).is_greater(0)
	var repeat: Array[Vector2i] = fog.on_moved(Vector2i(5, 5))
	assert_int(repeat.size()).is_equal(0)
	var explored_after_first: int = fog.explored_count()
	# 相邻移动仅新增边缘格
	var second: Array[Vector2i] = fog.on_moved(Vector2i(6, 5))
	assert_int(fog.explored_count()).is_equal(explored_after_first + second.size())
	for cell: Vector2i in second:
		assert_bool(first.has(cell)).is_false()

func test_instance_isolation() -> void:
	## 实例隔离：A 实例的探索记忆不影响 B 实例（并发出征互不串扰）
	var fog_a := _MakeFog(2, [], Vector2i(10, 10))
	var fog_b := _MakeFog(2, [], Vector2i(10, 10))
	fog_a.on_moved(Vector2i(5, 5))
	assert_int(fog_a.explored_count()).is_greater(0)
	assert_int(fog_b.explored_count()).is_equal(0)
	assert_bool(fog_b.is_explored(Vector2i(5, 5))).is_false()

func test_lit_rows_accessor_sorted() -> void:
	## 全亮行号列表读取口（升序重建）
	var fog := _MakeFog(3, [2, 0, 1], Vector2i(15, 15))
	var rows: Array[int] = fog.lit_rows()
	assert_int(rows.size()).is_equal(3)
	assert_int(rows[0]).is_equal(0)
	assert_int(rows[2]).is_equal(2)

# --------------------------------------------------------------------------
# 墙体遮挡（2026-09-25 用户拍板：视野被墙遮挡——格线口径对齐战棋视线）
# --------------------------------------------------------------------------

func test_wall_occlusion_blocks_and_wall_self_visible() -> void:
	## 遮挡基线：墙 (5,6)——墙格自身可见（端点不算，看得到挡住你的墙）；
	## 墙正后格 (5,8)（距离 3 圆内）不可见（中间格墙阻断）→ 未探索 UNSEEN；
	## 同列近格 (5,4) 无遮挡照常可见
	var fog := _MakeOpaqueFog(3, [], Vector2i(10, 10), {Vector2i(5, 6): true})
	var cells: Array[Vector2i] = fog.visible_cells(Vector2i(5, 5))
	assert_bool(cells.has(Vector2i(5, 6))).is_true() \
			.override_failure_message("墙格自身应可见")
	assert_bool(cells.has(Vector2i(5, 8))).is_false() \
			.override_failure_message("墙正后格不应可见")
	assert_int(fog.state_of(Vector2i(5, 8), Vector2i(5, 5))).is_equal(
			FogOfWar.CellState.UNSEEN)
	assert_bool(cells.has(Vector2i(5, 4))).is_true()

func test_side_route_visible_around_wall() -> void:
	## 绕侧可见：墙占 (4,6)/(5,6) 而 (6,6) 开——(6,7)（圆内）视线折经开格
	## (6,6) 可见；(5,7) 仍被 (5,6) 正挡不可见
	var fog := _MakeOpaqueFog(3, [], Vector2i(10, 10),
			{Vector2i(4, 6): true, Vector2i(5, 6): true})
	var cells: Array[Vector2i] = fog.visible_cells(Vector2i(5, 5))
	assert_bool(cells.has(Vector2i(6, 7))).is_true() \
			.override_failure_message("绕侧开格后方应可见")
	assert_bool(cells.has(Vector2i(5, 7))).is_false() \
			.override_failure_message("正墙后方不应可见")

func test_reveal_removes_occlusion_live_probe() -> void:
	## 揭示解除遮挡（实时回调非快照）：墙在 → 墙后格不在可见集；同一迷雾
	## 实例下移除墙（暗门 reveal 后格变 etile_path 语义）→ 现查即见
	var walls: Dictionary = {Vector2i(5, 6): true}
	var fog := _MakeOpaqueFog(3, [], Vector2i(10, 10), walls)
	assert_bool(fog.visible_cells(Vector2i(5, 5)).has(Vector2i(5, 8))).is_false()
	walls.erase(Vector2i(5, 6))
	assert_bool(fog.visible_cells(Vector2i(5, 5)).has(Vector2i(5, 8))).is_true() \
			.override_failure_message("墙移除（揭示）后遮挡应实时解除")

func test_explored_memory_dim_not_occluded() -> void:
	## 已探索记忆（DIM）不受遮挡影响：透明期从 (5,7) 看过 (5,6)；换遮挡
	## 探针后 (5,6) 在 (5,3) 视野圆内但被 (5,4) 墙挡——回落 DIM（记忆）非
	## UNSEEN；同视野内无遮挡近格 (5,2) 照常 LIT——state_of 优先级 =
	## 全亮行 > 遮挡视野 LIT > 记忆 DIM > UNSEEN
	var fog := _MakeFog(3, [], Vector2i(10, 10))
	fog.on_moved(Vector2i(5, 7))
	assert_bool(fog.is_explored(Vector2i(5, 6))).is_true()
	fog.set_opaque_probe(func(cell: Vector2i) -> bool:
		return cell == Vector2i(5, 4))
	assert_int(fog.state_of(Vector2i(5, 6), Vector2i(5, 3))).is_equal(
			FogOfWar.CellState.DIM) \
			.override_failure_message("曾见格被墙挡应保持 DIM 记忆态")
	assert_int(fog.state_of(Vector2i(5, 2), Vector2i(5, 3))).is_equal(
			FogOfWar.CellState.LIT) \
			.override_failure_message("无遮挡近格应 LIT")

func test_occlusion_reduces_reveal_set_on_moved() -> void:
	## 遮挡收敛揭示集：同位置同半径——遮挡探针下新揭示集 ≤ 无墙纯圆
	## （墙后格不入记忆集，驱动探索绕行）
	var open_fog := _MakeFog(3, [], Vector2i(10, 10))
	var open_reveal: Array[Vector2i] = open_fog.on_moved(Vector2i(5, 5))
	var walled_fog := _MakeOpaqueFog(3, [], Vector2i(10, 10), {Vector2i(5, 6): true})
	var walled_reveal: Array[Vector2i] = walled_fog.on_moved(Vector2i(5, 5))
	assert_int(walled_reveal.size()).is_less(open_reveal.size())
	assert_bool(walled_fog.is_explored(Vector2i(5, 8))).is_false() \
			.override_failure_message("墙后格不应入记忆集")

func test_w17_out_of_bounds_cell_not_lit_by_row_lookup() -> void:
	## W1-7/W2-4（2026-09-26 审计）：state_of 界内判定前置——界外格不查
	## 全亮行（修复前越界行号误撞 _lit_rows 集会白得 LIT：图外 (2,-1) 行号
	## 无撞不显缺陷，构造负行号同格语义验证界外恒 UNSEEN）
	var fog := _MakeFog(3, [0, 1], Vector2i(10, 10))
	assert_int(fog.state_of(Vector2i(20, 0), Vector2i(5, 5))).is_equal(
			FogOfWar.CellState.UNSEEN) \
			.override_failure_message("界外格应恒 UNSEEN（不查全亮行）")
	assert_int(fog.state_of(Vector2i(5, 15), Vector2i(5, 5))).is_equal(
			FogOfWar.CellState.UNSEEN)
