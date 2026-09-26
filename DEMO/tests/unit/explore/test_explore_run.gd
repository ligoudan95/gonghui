## ExpeditionRun 探索扩展单元测试（M3 批 1；V-2 2026-09-26 审计扩测）
## 覆盖：start_explore 初始化（fog/格位/耗时基准表值注入/判据上下文——
## V-2 起不首揭视野，初始揭示移至探索屏挂接遮挡后）/ 初始揭示遮挡口径
## （带墙图：墙后格 UNSEEN——run 侧不白得 DIM）/ 无委托会话 / M2 默认兼容
## （新字段全默认值——旧用例零感知）/ build_hp_overrides 单源（倒地过滤 +
## 缺键兜底 1 + unit_id 键——M2 行为等价）。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData
	## 参数：无
	## 返回：无
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()

func after() -> void:
	## 套件后置：释放 GameData
	## 参数：无
	## 返回：无
	_game_data.free()

func _MakeMapDef() -> ExploreMapDef:
	## 取 DEMO 探索图定义（真表数据）
	## 参数：无
	## 返回：ExploreMapDef
	return _game_data.get_record(&"map_m1_village_mine") as ExploreMapDef

func _MakeRun() -> ExpeditionRun:
	## 构建三人运行态（HP 40/50/30——第二人倒地；第三人缺 hp 键测兜底）
	## 参数：无
	## 返回：ExpeditionRun
	var run := ExpeditionRun.new()
	run.party = [
		AdventurerData.create_debug(&"a", &"cls_warrior", {
			&"strength": 16, &"agility": 10, &"constitution": 14,
			&"intelligence": 7, &"perception": 9, &"willpower": 9, &"luck": 9}, _game_data),
		AdventurerData.create_debug(&"b", &"cls_mage", {
			&"strength": 7, &"agility": 10, &"constitution": 9,
			&"intelligence": 16, &"perception": 11, &"willpower": 9, &"luck": 9}, _game_data),
		AdventurerData.create_debug(&"c", &"cls_priest", {
			&"strength": 10, &"agility": 10, &"constitution": 11,
			&"intelligence": 10, &"perception": 15, &"willpower": 13, &"luck": 9}, _game_data),
	]
	run.hp = {run.party[0]: 40, run.party[1]: 50}
	run.downed = {run.party[1]: true}
	return run

func test_start_explore_initializes_session() -> void:
	## start_explore 初始化：map_id/格位=出生格/耗时基准=表值注入/判据上下文/
	## fog 建立；V-2（2026-09-26 审计）起**不首揭视野**——初始揭示移至探索屏
	## 挂接遮挡探针后（此处纯圆揭示会白得墙后格 DIM）；出生格踏入登记与
	## 视野分离不受影响
	var map_def := _MakeMapDef()
	var quest: QuestTemplateDef = _game_data.get_record(&"q_lost_miner_keepsake") as QuestTemplateDef
	var run := _MakeRun()
	run.start_explore(map_def, quest, 3)
	assert_str(String(run.map_id)).is_equal("map_m1_village_mine")
	assert_bool(run.party_pos == map_def.start_cell).is_true()
	assert_int(run.base_days).is_equal(map_def.base_expedition_days)
	assert_str(String(run.quest_template_id)).is_equal("q_lost_miner_keepsake")
	assert_int(run.goal_kind).is_equal(QuestTemplateDef.GoalType.EXPLORE)
	assert_str(String(run.goal_param)).is_equal("tp_old_well")
	assert_bool(run.goal_done).is_false()
	assert_int(run.random_encounters_fired).is_equal(0)
	assert_object(run.fog).is_not_null()
	# V-2：run 侧不首揭——记忆集为空（初始揭示由 explore_screen 挂接遮挡后执行）
	assert_int(run.fog.explored_count()).is_equal(0)
	assert_bool(run.fog.is_explored(map_def.start_cell)).is_false()
	# 出生格已登记踏入（新格遭遇判定口径——与视野分离）
	assert_bool(run.visited_cells.has(map_def.start_cell)).is_true()

func _MakeWalledMapDef() -> ExploreMapDef:
	## 构造带墙探索图（V-2 用例专用）：7×7，出生 (3,1)，y=2 岩壁墙排仅
	## x=3 留缺口——(3,1) 视角下 (1,3) 圆内但被 (2,2) 墙挡、(3,4) 经缺口可见
	## 参数：无
	## 返回：ExploreMapDef
	var map_def := ExploreMapDef.new()
	map_def.id = &"map_v2_walled_test"
	map_def.display_name = "V-2 带墙测试图"
	map_def.size = Vector2i(7, 7)
	map_def.rows = [
		".......",
		".......",
		"XXX.XXX",
		".......",
		".......",
		".......",
		".......",
	]
	map_def.legend = {&".": &"etile_floor", &"X": &"etile_wall"}
	map_def.start_cell = Vector2i(3, 1)
	map_def.fog_lit_rows = []
	map_def.base_expedition_days = 1
	return map_def

func test_v2_initial_reveal_respects_walls_after_probe_attach() -> void:
	## V-2（2026-09-26 审计）：初始视野揭示移至挂接遮挡探针之后——带墙图
	## start_explore + 挂接 + 首揭：出生点墙后格必须 UNSEEN（修复前 run 侧
	## 纯圆首揭白得墙后格 DIM）；墙格自身可见；缺口直线格可见
	var map_def := _MakeWalledMapDef()
	var run := _MakeRun()
	run.start_explore(map_def, null, 3)
	# run 侧未首揭（挂接前记忆集恒空）
	assert_int(run.fog.explored_count()).is_equal(0)
	# 探索屏同序装配：图态 → 挂接实时墙体探针 → 首揭
	var state := ExploreMapState.new()
	assert_bool(state.setup(map_def, func(tile_id: StringName) -> ExploreTileDef:
		return _game_data.get_record(tile_id) as ExploreTileDef)).is_true()
	run.fog.set_opaque_probe(func(cell: Vector2i) -> bool:
		return not state.walkable(cell))
	run.fog.on_moved(run.party_pos)
	# 墙后格 (1,3)（视野圆内 dist≈2.83，视线经 (2,2) 墙阻断）——UNSEEN 未入记忆
	assert_int(run.fog.state_of(Vector2i(1, 3), run.party_pos)).is_equal(
			FogOfWar.CellState.UNSEEN)
	assert_bool(run.fog.is_explored(Vector2i(1, 3))).is_false()
	# 墙格自身可见（(2,2) 端点不算——看得到挡住你的墙）
	assert_bool(run.fog.is_explored(Vector2i(2, 2))).is_true()
	# 缺口直线格 (3,4)（dist 3 圆内，视线经 (3,2) 缺口 + (3,3)）——LIT
	assert_int(run.fog.state_of(Vector2i(3, 4), run.party_pos)).is_equal(
			FogOfWar.CellState.LIT)

func test_start_explore_without_quest() -> void:
	## 无委托会话：判据上下文空（goal_kind -1 / 模板 id 空）——自由探索
	var run := _MakeRun()
	run.start_explore(_MakeMapDef(), null, 3)
	assert_str(String(run.quest_template_id)).is_equal("")
	assert_int(run.goal_kind).is_equal(-1)
	assert_str(String(run.goal_param)).is_equal("")

func test_m2_defaults_untouched() -> void:
	## M2 默认兼容：未 start_explore 的运行态——fog null / 格位哨兵 / 耗时基准 1 /
	## 判据 -1（事件演示宿主等 M2 用例零感知）
	var run := _MakeRun()
	assert_object(run.fog).is_null()
	assert_bool(run.party_pos == ExpeditionRun.NO_CELL).is_true()
	assert_int(run.base_days).is_equal(1)
	assert_int(run.goal_kind).is_equal(-1)
	assert_int(run.total_days()).is_equal(1)

func test_build_hp_overrides_single_source() -> void:
	## build_hp_overrides 单源：倒地过滤（b 不带入）+ 缺键兜底 1（c 无 hp 键）+
	## unit_id 字符串键（BattleSetup 查表口径）——M2 build_battle_params 行为等价
	var run := _MakeRun()
	var hp_map: Dictionary = run.build_hp_overrides()
	assert_int(hp_map.size()).is_equal(2)
	assert_int(int(hp_map.get(&"a", 0))).is_equal(40)
	assert_bool(hp_map.has(&"b")).is_false()
	assert_int(int(hp_map.get(&"c", 0))).is_equal(1)

func test_event_runner_delegates_hp_overrides() -> void:
	## EventRunner.build_battle_params 委托单源：产出 == run.build_hp_overrides()
	## （M2 回归锚——B 出口参数组装经同一方法）
	var run := _MakeRun()
	var runner := EventRunner.new()
	runner.setup(null, func(_record_id: StringName) -> Resource: return null,
			RandomNumberGenerator.new())
	# 构造最小 B 出口（无初始状态/无分布——仅验证 hp_overrides 委托）
	var outcome := EventOutcomeDef.new()
	outcome.exit_kind = EventOutcomeDef.ExitKind.B
	var battle := BattleOpeningDef.new()
	battle.pack_id = &"enc_m1_random_pack"
	outcome.battle = battle
	var params: BattleParams = runner.build_battle_params(outcome, run)
	assert_int(params.hp_overrides.size()).is_equal(2)
	assert_int(int(params.hp_overrides.get(&"a", 0))).is_equal(40)
	assert_bool(params.hp_overrides.has(&"b")).is_false()
	assert_int(int(params.hp_overrides.get(&"c", 0))).is_equal(1)
