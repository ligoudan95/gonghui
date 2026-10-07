## 公会快照往返与建档冒烟测试（M4 批 1）
## 覆盖：v2 序列化往返全字段（JSON 桥）/restore 后板/挂单/占用/池/名册一致/
## 出征锁期间 autosave 跳过（provider 注册态）/new_game 初始态（500 金/4 人名册/
## 委托板 3/招募池 3——headless 冒烟口径）。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"
## SaveManager 脚本路径
const SAVE_MANAGER_SCRIPT: String = "res://scripts/autoload/save_manager.gd"
## GuildState 脚本路径
const GUILD_STATE_SCRIPT: String = "res://scripts/autoload/guild_state.gd"
## 存档路径（清理与读取）
const SAVE_PATH: String = "user://saves/main_save.json"

## 套件级 GameData
var _game_data: Node

func before_test() -> void:
	## 用例级前置：GameData 实例 + 存档目录清理
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()
	_CleanSaveDir()

func after_test() -> void:
	## 用例级后置：释放 GameData、清理存档目录
	_game_data.free()
	_CleanSaveDir()

func _Cfg() -> CoreConfig:
	## 总控配置读取口
	return _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig

func _MakeRng(seed_value: int) -> RandomNumberGenerator:
	## 固定种子随机源
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _CleanSaveDir() -> void:
	## 清理 user://saves 全部文件
	var dir: DirAccess = DirAccess.open("user://saves")
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while not entry_name.is_empty():
		if not dir.current_is_dir():
			dir.remove(entry_name)
		entry_name = dir.get_next()
	dir.list_dir_end()

func _ReadSaveText() -> String:
	## 读存档正本文本
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text

func _BuildMutatedCore() -> GuildCore:
	## 构造含全要素变更的核心：日历推进/接取+编队占用/招募/设施升级/悬置倾向
	var core := GuildCore.new()
	core.setup(_Cfg(), _game_data, _MakeRng(501))
	core.settle_one_day()
	core.gold = 1200
	core.reputation = 7
	var inst: QuestInstance = core.board.spawn_on_board(&"q_lair_purge", 2)
	var party: Array[StringName] = [
		core.roster[0].unit_id, core.roster[1].unit_id, core.roster[2].unit_id,
	]
	core.accept_quest(inst.serial, party)
	core.upgrade_facility(&"fac_training_ground")
	core.recruit(0)
	var pending: Dictionary = {}
	GrowthCore.apply_exp(core.roster[3], 250, _Cfg(), _game_data, pending)
	core.pending_tendency_levels = pending
	core.roster[0].status = AdventurerData.Status.RESTING
	core.roster[0].rest_days = 2
	core.roster[0].last_expedition_day = 2
	return core

func test_snapshot_roundtrip_full_fields() -> void:
	## 快照往返全字段：save → JSON.stringify → parse → restore 后全字段等价
	var core := _BuildMutatedCore()
	core.has_unseen_grants = true
	var snapshot: Dictionary = core.to_snapshot()
	var parsed: Variant = JSON.parse_string(JSON.stringify(snapshot))
	assert_object(parsed).is_not_null()
	var restored := GuildCore.new()
	restored.attach(_Cfg(), _game_data, _MakeRng(502))
	restored.restore_snapshot(parsed)
	# 顶层运行态
	assert_int(restored.day).is_equal(core.day)
	assert_int(restored.gold).is_equal(core.gold)
	assert_int(restored.reputation).is_equal(core.reputation)
	assert_int(restored.board.serial).is_equal(core.board.serial)
	assert_int(restored.recruit_pool.serial).is_equal(core.recruit_pool.serial)
	# 设施等级
	assert_int(int(restored.facility_levels[&"fac_training_ground"])).is_equal(2)
	assert_int(int(restored.facility_levels[&"fac_dormitory"])).is_equal(1)
	# 名册逐成员全字段（含休养/出征标记/经验/属性）
	assert_int(restored.roster.size()).is_equal(core.roster.size())
	for index: int in core.roster.size():
		var source: AdventurerData = core.roster[index]
		var target: AdventurerData = restored.roster[index]
		assert_str(String(target.unit_id)).is_equal(String(source.unit_id))
		assert_str(String(target.class_id)).is_equal(String(source.class_id))
		assert_str(target.display_name).is_equal(source.display_name)
		assert_int(target.level).is_equal(source.level)
		assert_int(target.exp).is_equal(source.exp)
		assert_int(target.attrs.size()).is_equal(source.attrs.size())
		for attr_id: StringName in source.attrs:
			assert_int(int(target.attrs[attr_id])).is_equal(int(source.attrs[attr_id]))
		assert_int(target.skill_ids.size()).is_equal(source.skill_ids.size())
		assert_int(target.skill_points).is_equal(source.skill_points)
		assert_str(String(target.tendency_id)).is_equal(String(source.tendency_id))
		assert_int(target.status).is_equal(source.status)
		assert_int(target.rest_days).is_equal(source.rest_days)
		assert_int(target.last_expedition_day).is_equal(source.last_expedition_day)
		assert_bool(target.pre_unlocked).is_equal(source.pre_unlocked)
		assert_int(target.stress).is_equal(source.stress)
	assert_int(restored.roster[0].status).is_equal(AdventurerData.Status.RESTING)
	assert_int(restored.roster[0].rest_days).is_equal(2)
	# 板与挂单：模板/序号/状态/到期线/占用一致
	assert_int(restored.board.board.size()).is_equal(core.board.board.size())
	assert_int(restored.board.accepted.size()).is_equal(core.board.accepted.size())
	var source_inst: QuestInstance = core.board.accepted[0]
	var target_inst: QuestInstance = restored.board.accepted[0]
	assert_int(target_inst.serial).is_equal(source_inst.serial)
	assert_str(String(target_inst.template_id)).is_equal(String(source_inst.template_id))
	assert_int(target_inst.state).is_equal(source_inst.state)
	assert_int(target_inst.expire_day).is_equal(source_inst.expire_day)
	assert_int(target_inst.party_ids.size()).is_equal(3)
	# 占用一致性（restore 后占用口径等价）
	assert_int(restored.board.occupied_member_ids().size()).is_equal(
			core.board.occupied_member_ids().size())
	# 招募池：候选数与序号一致
	assert_int(restored.recruit_pool.candidates.size()).is_equal(
			core.recruit_pool.candidates.size())
	# 悬置倾向与编队记忆 + 未查看挂单标志（M4-1：v2 内加可选字段——旧档缺省 false）
	assert_int(int(restored.pending_tendency_levels.size())).is_equal(
			int(core.pending_tendency_levels.size()))
	assert_int(restored.last_party_by_tpl.size()).is_equal(core.last_party_by_tpl.size())
	assert_bool(restored.has_unseen_grants).is_true()
	var fresh_core := GuildCore.new()
	fresh_core.attach(_Cfg(), _game_data, _MakeRng(505))
	fresh_core.restore_snapshot({"day": 1})
	assert_bool(fresh_core.has_unseen_grants).is_false()

func test_expedition_lock_skips_provider_autosave() -> void:
	## 出征锁期间 autosave 跳过（provider 注册态下）：锁时 autosave 返回 OK
	## 但文件不变；解锁后写入
	var save_manager: Node = load(SAVE_MANAGER_SCRIPT).new()
	add_child(save_manager)
	save_manager.new_game()
	var core := GuildCore.new()
	core.setup(_Cfg(), _game_data, _MakeRng(503))
	save_manager.register_snapshot_provider(&"guild",
			Callable(core, "to_snapshot"), Callable(core, "restore_snapshot"))
	assert_int(save_manager.autosave(SaveData.SavePoint.DAY_END)).is_equal(OK)
	var baseline: String = _ReadSaveText()
	assert_str(baseline).is_not_empty()
	save_manager.set_expedition_lock(true)
	core.settle_one_day()
	core.gold = 999
	assert_int(save_manager.autosave(SaveData.SavePoint.DAY_END)).is_equal(OK)
	assert_str(_ReadSaveText()).is_equal(baseline)
	save_manager.set_expedition_lock(false)
	assert_int(save_manager.autosave(SaveData.SavePoint.DAY_END)).is_equal(OK)
	assert_str(_ReadSaveText()).is_not_equal(baseline)
	save_manager.free()

func test_return_settled_save_failure_flagged() -> void:
	## M-3 回归：RETURN_SETTLED autosave 失败（注入：current 置空）——
	## summary.save_failed 置位（结算面板警示行消费）
	var save_manager: Node = load(SAVE_MANAGER_SCRIPT).new()
	add_child(save_manager)
	# 修复批次 3（套件隔离）：局部 GuildState 不 add_child——避免 _ready 的
	# bind 命中真 autoload SaveManager 覆写其 provider（局部实例释放后真 SM
	# 残留悬空 Callable，套件顺序一变即 errors）；手动等价初始化后直用
	var state: Node = load(GUILD_STATE_SCRIPT).new()
	state.core = GuildCore.new()
	state._rng = _MakeRng(506)
	state.bind(save_manager, _game_data)
	state.new_game()
	var run := ExpeditionRun.new()
	run.base_days = 1
	save_manager.current = null
	var summary: Variant = state.settle_expedition(run,
			GuildCore.ExpeditionOutcome.RETREAT)
	assert_object(summary).is_not_null()
	assert_bool(summary.save_failed).is_true()
	state.free()
	save_manager.free()

func test_new_game_initial_state_and_load_restore() -> void:
	## 建档冒烟（headless 口径）：GuildState.new_game → 500 金/4 人名册/
	## 委托板 3/招募池 3/game_day=1/NEW_GAME 写盘；load_game → 快照恢复等价
	var save_manager: Node = load(SAVE_MANAGER_SCRIPT).new()
	add_child(save_manager)
	# 修复批次 3（套件隔离）：同上——局部 GuildState 不 add_child 手动初始化
	var state: Node = load(GUILD_STATE_SCRIPT).new()
	state.core = GuildCore.new()
	state._rng = _MakeRng(504)
	state.bind(save_manager, _game_data)
	state.new_game()
	# 初始态断言（完成标准口径）
	assert_int(state.core.gold).is_equal(500)
	assert_int(state.core.roster.size()).is_equal(4)
	assert_int(state.core.board.board.size()).is_equal(3)
	assert_int(state.core.recruit_pool.candidates.size()).is_equal(3)
	assert_int(save_manager.current.game_day).is_equal(1)
	assert_int(save_manager.current.save_point).is_equal(SaveData.SavePoint.NEW_GAME)
	assert_int(save_manager.current.schema_version).is_equal(SaveData.SCHEMA_VERSION)
	# 初始 4 人：预解锁第 1 技（1 个）+出生 1 点+职业集合恰为定稿四职业
	var class_set: Array[StringName] = []
	for member: AdventurerData in state.core.roster:
		assert_bool(member.pre_unlocked).is_true()
		assert_int(member.skill_ids.size()).is_equal(1)
		assert_int(member.skill_points).is_equal(1)
		assert_int(member.status).is_equal(AdventurerData.Status.HEALTHY)
		class_set.append(member.class_id)
	assert_bool(class_set.has(&"cls_warrior")).is_true()
	assert_bool(class_set.has(&"cls_rogue")).is_true()
	assert_bool(class_set.has(&"cls_mage")).is_true()
	assert_bool(class_set.has(&"cls_priest")).is_true()
	# 读档恢复：天数/名册/委托板规模等价
	var gold_before: int = state.core.gold
	var roster_before: int = state.core.roster.size()
	save_manager.current = null
	var loaded: SaveData = save_manager.load_game()
	assert_object(loaded).is_not_null()
	assert_int(loaded.game_day).is_equal(1)
	assert_int(state.core.gold).is_equal(gold_before)
	assert_int(state.core.roster.size()).is_equal(roster_before)
	assert_int(state.core.board.board.size()).is_equal(3)
	assert_int(state.core.recruit_pool.candidates.size()).is_equal(3)
	# 存档侧公会快照键落盘
	assert_bool(loaded.payload.has(&"guild")).is_true()
	state.free()
	save_manager.free()

func test_s3m2_malformed_snapshot_conservative_clear() -> void:
	## S3-M2 回归（拍板：保守清空）：畸形 payload——roster/facility_levels 破坏成
	## Dictionary/标量、board/candidates 破坏成标量——restore 链不 SCRIPT ERROR
	## 中断，对应槽保守清空，读档可继续（core 运行态自洽）
	var core := GuildCore.new()
	core.attach(_Cfg(), _game_data, _MakeRng(511))
	core.restore_snapshot({
		"day": 4,
		"gold": 300,
		"board": "corrupted",
		"recruit_pool": 42,
		"facility_levels": 17,
		"roster": {"broken": true},
		"last_party_by_tpl": 7,
		"pending_tendency_levels": 1.5,
	})
	# 全部槽保守清空、顶层标量仍恢复、无中断后续断言可达
	assert_int(core.day).is_equal(4)
	assert_int(core.gold).is_equal(300)
	assert_int(core.board.board.size()).is_equal(0)
	assert_int(core.board.accepted.size()).is_equal(0)
	assert_int(core.recruit_pool.candidates.size()).is_equal(0)
	assert_int(core.facility_levels.size()).is_equal(0)
	assert_int(core.roster.size()).is_equal(0)
	assert_int(core.last_party_by_tpl.size()).is_equal(0)
	assert_int(core.pending_tendency_levels.size()).is_equal(0)
	# 恢复后 core 仍可用（新游戏语义重建——读档可继续）
	core.board.initial_fill(core.day)
	assert_int(core.board.board.size()).is_equal(3)

func test_s3m2_malformed_member_entries_skipped() -> void:
	## S3-M2 补充：roster 数组内混入非 Dictionary 条目——跳过坏条目、好条目
	## 正常恢复（与「实例损坏条目跳过」既有口径一致）
	var good := GuildCore.new()
	good.setup(_Cfg(), _game_data, _MakeRng(512))
	var snapshot: Dictionary = good.to_snapshot()
	snapshot["roster"] = [snapshot["roster"][0], "corrupted-entry", 42]
	var core := GuildCore.new()
	core.attach(_Cfg(), _game_data, _MakeRng(513))
	core.restore_snapshot(snapshot)
	assert_int(core.roster.size()).is_equal(1)
	assert_str(String(core.roster[0].unit_id)).is_equal(
			String(good.roster[0].unit_id))

func test_s3m5b_wait_day_autosave_failure_flagged() -> void:
	## S3-M5-1-b 回归：DAY_END autosave FAILED（注入 current 置空）——
	## GuildState.last_autosave_failed 置位（guild_shell RefreshAll 感知），
	## 与 RETURN_SETTLED 的 summary.save_failed 口径对称
	var save_manager: Node = load(SAVE_MANAGER_SCRIPT).new()
	add_child(save_manager)
	var state: Node = load(GUILD_STATE_SCRIPT).new()
	state.core = GuildCore.new()
	state._rng = _MakeRng(514)
	state.bind(save_manager, _game_data)
	state.new_game()
	assert_bool(state.last_autosave_failed).is_false()
	save_manager.current = null
	var summary: GuildCore.DaySummary = state.wait_one_day()
	assert_object(summary).is_not_null()
	assert_bool(state.last_autosave_failed).is_true()
	state.free()
	save_manager.free()

# --------------------------------------------------------------------------
# 读档一致性矩阵（M5 批 1）：五时点逐一 autosave → 丢弃运行态（关游戏模拟）→
# load_game → 断言 scene_id 锚定 + core 关键态一致
# --------------------------------------------------------------------------

func _MakeLocalState() -> Array:
	## 局部 SaveManager + GuildState 装配（套件隔离口径——手动等价初始化）
	## 返回：[save_manager, state]（调用方负责 free）
	var save_manager: Node = load(SAVE_MANAGER_SCRIPT).new()
	add_child(save_manager)
	var state: Node = load(GUILD_STATE_SCRIPT).new()
	state.core = GuildCore.new()
	state._rng = _MakeRng(521)
	state.bind(save_manager, _game_data)
	return [save_manager, state]

func _ReloadAndAssert(state: Node, save_manager: Node, expected_day: int,
		expected_gold: int, expected_roster: int) -> SaveData:
	## 读档一致性矩阵共用：丢弃运行态 → load_game → core 关键态一致 + 就绪判定
	## 参数 state/save_manager：局部 GuildState/SaveManager；expected_*：期望值
	## 返回：载入的 SaveData（调用方按矩阵再断言 scene_id/save_point）
	save_manager.current = null
	state.core = GuildCore.new()
	var loaded: SaveData = save_manager.load_game()
	assert_object(loaded).is_not_null()
	assert_int(state.core.day).is_equal(expected_day)
	assert_int(state.core.gold).is_equal(expected_gold)
	assert_int(state.core.roster.size()).is_equal(expected_roster)
	assert_bool(state.has_guild_data()).is_true()
	return loaded

func test_reload_matrix_new_game_point() -> void:
	## 矩阵①NEW_GAME：scene_id=guild_shell、初始态（500 金/4 人/板 3/池 3）一致
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	state.new_game()
	var loaded: SaveData = _ReloadAndAssert(state, save_manager, 1, 500, 4)
	assert_str(String(loaded.scene_id)).is_equal("guild_shell")
	assert_int(loaded.save_point).is_equal(SaveData.SavePoint.NEW_GAME)
	assert_int(loaded.game_day).is_equal(1)
	assert_int(state.core.board.board.size()).is_equal(3)
	assert_int(state.core.recruit_pool.candidates.size()).is_equal(3)
	state.free()
	save_manager.free()

func test_reload_matrix_day_end_point() -> void:
	## 矩阵②DAY_END：等待一天 → scene_id 仍锚 guild_shell（城内时点）、
	## day+1 与名册一致
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	state.new_game()
	state.wait_one_day()
	var loaded: SaveData = _ReloadAndAssert(state, save_manager, 2, 500, 4)
	assert_str(String(loaded.scene_id)).is_equal("guild_shell")
	assert_int(loaded.save_point).is_equal(SaveData.SavePoint.DAY_END)
	assert_int(loaded.game_day).is_equal(2)
	state.free()
	save_manager.free()

func test_reload_matrix_return_settled_point() -> void:
	## 矩阵③RETURN_SETTLED：回城结算（自由探索会话——事件奖励入账）→
	## 场景锚定公会壳（GuildState.settle_expedition 内锚定）、结算态入档
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	state.new_game()
	var run := ExpeditionRun.new()
	run.base_days = 1
	run.add_reward(15, 20, 1)
	var summary: Variant = state.settle_expedition(run,
			GuildCore.ExpeditionOutcome.SUCCESS)
	assert_int(summary.gold_gained).is_equal(20)
	var loaded: SaveData = _ReloadAndAssert(state, save_manager, 2, 520, 4)
	assert_str(String(loaded.scene_id)).is_equal("guild_shell")
	assert_int(loaded.save_point).is_equal(SaveData.SavePoint.RETURN_SETTLED)
	assert_int(loaded.game_day).is_equal(2)
	assert_int(state.core.reputation).is_equal(1)
	state.free()
	save_manager.free()

func test_reload_matrix_facility_upgraded_point() -> void:
	## 矩阵④FACILITY_UPGRADED：设施屏时点 scene_id=设施屏名（fac.scene_id
	## 数据单源——训练场/宿舍两变体）、升级扣款与等级入档
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	state.new_game()
	state.core.gold = 2000
	# 训练场变体（600 金）：模拟进设施屏的 go 上报（生产链
	## SceneManager.go→_ReportSceneToSave 写 scene_id）
	var train_fac: FacilityDef = state.core.facility_def(&"fac_training_ground")
	save_manager.current.scene_id = train_fac.scene_id
	assert_bool(state.upgrade_facility(&"fac_training_ground")).is_true()
	var loaded: SaveData = _ReloadAndAssert(state, save_manager, 1, 1400, 4)
	assert_str(String(loaded.scene_id)).is_equal("guild_training_ground")
	assert_int(loaded.save_point).is_equal(SaveData.SavePoint.FACILITY_UPGRADED)
	assert_int(int(state.core.facility_levels[&"fac_training_ground"])).is_equal(2)
	# 宿舍变体（800 金）
	var dorm_fac: FacilityDef = state.core.facility_def(&"fac_dormitory")
	save_manager.current.scene_id = dorm_fac.scene_id
	assert_bool(state.upgrade_facility(&"fac_dormitory")).is_true()
	var loaded2: SaveData = _ReloadAndAssert(state, save_manager, 1, 600, 4)
	assert_str(String(loaded2.scene_id)).is_equal("guild_dormitory")
	assert_int(loaded2.save_point).is_equal(SaveData.SavePoint.FACILITY_UPGRADED)
	assert_int(int(state.core.facility_levels[&"fac_dormitory"])).is_equal(2)
	state.free()
	save_manager.free()

func test_reload_matrix_recruit_done_point() -> void:
	## 矩阵⑤RECRUIT_DONE：协会屏时点 scene_id=association_screen、
	## 入册+扣款+招募池消耗入档
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	state.new_game()
	save_manager.current.scene_id = &"association_screen"
	var cost: int = state.core.recruit_pool.cost_of(
			state.core.recruit_pool.candidates[0])
	assert_object(state.recruit(0)).is_not_null()
	var loaded: SaveData = _ReloadAndAssert(state, save_manager, 1, 500 - cost, 5)
	assert_str(String(loaded.scene_id)).is_equal("association_screen")
	assert_int(loaded.save_point).is_equal(SaveData.SavePoint.RECRUIT_DONE)
	assert_int(loaded.game_day).is_equal(1)
	# 招募池消耗一致（3 候选入册 1 → 2）
	assert_int(state.core.recruit_pool.candidates.size()).is_equal(2)
	state.free()
	save_manager.free()

func test_s301_empty_guild_snapshot_clears_slots_and_gate() -> void:
	## S3-01：读档成功但公会快照为空（guild:{} 旧档）——core 运行态槽保守清空
	##（同进程残留旧局不再污染新读档/静默覆盖）+ has_guild_data() 返回 false
	##（title 走开新档提示）；有效快照读档后恢复 true
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	# 同进程残留旧局：建档推进一天（stale 态 day=2、名册 4、金 500）
	state.new_game()
	state.wait_one_day()
	assert_int(state.core.day).is_equal(2)
	assert_bool(state.has_guild_data()).is_true()
	# 覆盖为空公会快照旧档（payload guild={} —— M0 直连旧流程形态，raw 写盘）
	var raw_save: String = "{\"schema_version\": 3, \"save_point\": 0, \"game_day\": 1, \"mode\": \"demo\", \"scene_id\": \"guild_shell\", \"saved_unix_time\": 0, \"payload\": {\"guild\": {}}}"
	DirAccess.make_dir_recursive_absolute("user://saves")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(raw_save)
	file.close()
	# 读回空快照旧档：槽清空 + 旗标 false（title 不再误判有效公会数据）
	save_manager.current = null
	var loaded: SaveData = save_manager.load_game()
	assert_object(loaded).is_not_null()
	assert_bool(state.has_guild_data()).is_false()
	assert_int(state.core.day).is_equal(1)
	assert_int(state.core.roster.size()).is_equal(0)
	assert_int(state.core.gold).is_equal(0)
	# 重新建档：旗标恢复 true（title「开始」链路不受空档读档影响）
	state.new_game()
	assert_bool(state.has_guild_data()).is_true()
	assert_int(state.core.roster.size()).is_equal(4)
	state.free()
	save_manager.free()

func test_s301_no_guild_key_save_clears_stale_session() -> void:
	## S3-01 补口：payload 无 guild 键的旧档（provider 不被调用的路径）——
	## save_loaded 钩子清同进程残留旧局（此前 stale 装配冒充有效快照）
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	state.new_game()
	state.wait_one_day()
	assert_int(state.core.day).is_equal(2)
	# raw 写 v3 档（payload 无 guild 键——M0 直连旧档形态）
	var raw_save: String = "{\"schema_version\": 3, \"save_point\": 0, \"game_day\": 1, \"mode\": \"demo\", \"scene_id\": \"guild_shell\", \"saved_unix_time\": 0, \"payload\": {}}"
	DirAccess.make_dir_recursive_absolute("user://saves")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(raw_save)
	file.close()
	save_manager.current = null
	var loaded: SaveData = save_manager.load_game()
	assert_object(loaded).is_not_null()
	assert_bool(state.has_guild_data()).is_false()
	assert_int(state.core.day).is_equal(1)
	state.free()
	save_manager.free()

func test_s302_restore_resets_autosave_failed_flag() -> void:
	## S3-02：读档成功路径复位 last_autosave_failed（上一局的 autosave 失败
	## 警示不跨局残留）
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	state.new_game()
	state.last_autosave_failed = true
	assert_bool(state.last_autosave_failed).is_true()
	save_manager.current = null
	var loaded: SaveData = save_manager.load_game()
	assert_object(loaded).is_not_null()
	assert_bool(state.has_guild_data()).is_true()
	assert_bool(state.last_autosave_failed).is_false()
	state.free()
	save_manager.free()

func test_s3r201_malformed_guild_payload_type_skips_and_clears() -> void:
	## S3-R2-01：payload 值类型不符（guild:[]）——SaveManager 跳过 restore 调用
	##（不再触发 provider 侧类型校验错误中止 restore 链），GuildState 经
	## save_loaded 钩子走既有清空链：旗标 false + 槽清空（残留旧局不冒充）
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	state.new_game()
	state.wait_one_day()
	assert_int(state.core.day).is_equal(2)
	# 覆盖为坏类型公会快照档（payload guild=[] ——手改档形态，raw 写盘）
	var raw_save: String = "{\"schema_version\": 3, \"save_point\": 0, \"game_day\": 1, \"mode\": \"demo\", \"scene_id\": \"guild_shell\", \"saved_unix_time\": 0, \"payload\": {\"guild\": []}}"
	DirAccess.make_dir_recursive_absolute("user://saves")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(raw_save)
	file.close()
	save_manager.current = null
	var loaded: SaveData = save_manager.load_game()
	assert_object(loaded).is_not_null()
	assert_bool(state.has_guild_data()).is_false()
	assert_int(state.core.day).is_equal(1)
	assert_int(state.core.roster.size()).is_equal(0)
	state.free()
	save_manager.free()

func test_s505_settle_idempotent_returns_cached_summary() -> void:
	## S5-05：settle_expedition 幂等早退返回首次结算摘要缓存——重复调用拿到
	## 同一实例（含 reason 等完整字段，不再是无 reason 空摘要）
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	state.new_game()
	var run := ExpeditionRun.new()
	run.base_days = 1
	var first: Variant = state.settle_expedition(run,
			GuildCore.ExpeditionOutcome.RETREAT)
	assert_object(first).is_not_null()
	assert_bool(run.settled).is_true()
	var second: Variant = state.settle_expedition(run,
			GuildCore.ExpeditionOutcome.DEFEAT)
	assert_object(second).is_same(first)
	state.free()
	save_manager.free()

func test_s305_from_dict_bad_elements_skipped() -> void:
	## S3-05：手改档混入非串元素（party_ids [1,2] / attrs 坏键 / 技能·怪癖
	## 清单坏元素）——元素级跳过不中断整条 restore 链
	var quest_data: Dictionary = {
		"serial": 3, "template_id": "q_lair_purge", "state": 0, "expire_day": 9,
		"party_ids": ["adv_iron_peak", 3, "adv_erin"], "urgent": false,
		"work_days_left": 0,
	}
	var inst: QuestInstance = QuestInstance.from_dict(quest_data)
	assert_object(inst).is_not_null()
	assert_int(inst.party_ids.size()).is_equal(2)
	assert_bool(inst.party_ids.has(&"adv_iron_peak")).is_true()
	assert_bool(inst.party_ids.has(&"adv_erin")).is_true()
	var adv_data: Dictionary = {
		"unit_id": "adv_test", "class_id": "cls_warrior", "display_name": "测试",
		"level": 1, "exp": 0,
		"attrs": {"strength": 16, 5: 10},
		"skill_ids": ["skl_warrior_power_strike", 7],
		"skill_points": 0, "tendency_id": "", "status": 0, "rest_days": 0,
		"last_expedition_day": 0, "pre_unlocked": true, "equip_slots": {},
		"stress": 0,
		"quirks": [1, "q_odd"],
	}
	var adv: AdventurerData = AdventurerData.from_dict(adv_data)
	assert_object(adv).is_not_null()
	assert_int(adv.attrs.size()).is_equal(1)
	assert_bool(adv.attrs.has(&"strength")).is_true()
	assert_int(adv.skill_ids.size()).is_equal(1)
	assert_bool(adv.skill_ids.has(&"skl_warrior_power_strike")).is_true()
	assert_int(adv.quirks.size()).is_equal(1)
	assert_bool(adv.quirks.has(&"q_odd")).is_true()

func test_s3r3_dirty_field_type_rejected() -> void:
	## S3-R3-01/02：from_dict 字段类型校验补漏——quest_instance.template_id
	## 非串 / adventurer_data.display_name 非串 → null 拒载（脏档不进 restore 链）
	var quest_data: Dictionary = {
		"serial": 3, "template_id": 5, "state": 0, "expire_day": 9,
		"party_ids": [], "urgent": false, "work_days_left": 0,
	}
	assert_object(QuestInstance.from_dict(quest_data)).is_null()
	var adv_data: Dictionary = {
		"unit_id": "adv_test", "class_id": "cls_warrior", "display_name": 99,
		"level": 1, "exp": 0, "attrs": {}, "skill_ids": [],
		"skill_points": 0, "tendency_id": "", "status": 0, "rest_days": 0,
		"last_expedition_day": 0, "pre_unlocked": true, "equip_slots": {},
		"stress": 0, "quirks": [],
	}
	assert_object(AdventurerData.from_dict(adv_data)).is_null()
	# S3-R4-04：脏档 level:0 拒载（等级 1 起——0 免费满级）
	var zero_level: Dictionary = adv_data.duplicate()
	zero_level["display_name"] = "测试"
	zero_level["level"] = 0
	assert_object(AdventurerData.from_dict(zero_level)).is_null()

func test_s3r402_dirty_container_values_restore_chain_intact() -> void:
	## S3-R4-02：容器型脏值矩阵——day/gold/board·pool serial/facility 值/
	## party_memory 元素/attrs 值/pending 值/has_unseen_grants 全为容器时
	## restore 链不中断（此前裸 int()/String()/bool() SCRIPT ERROR 中止——
	## stale core 存活 + 旗标冒充读档成功）；门卫后各槽回退默认、core 自洽
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	# 同进程残留旧局（day=2——若 restore 中止则 stale 值存活）
	state.new_game()
	state.wait_one_day()
	assert_int(state.core.day).is_equal(2)
	var raw_save: String = "{\"schema_version\": 3, \"save_point\": 0, \"game_day\": 1, \"mode\": \"demo\", \"scene_id\": \"guild_shell\", \"saved_unix_time\": 0, \"payload\": {\"guild\": {\"day\": [], \"gold\": [], \"reputation\": [], \"board\": {\"serial\": []}, \"recruit_pool\": {\"serial\": []}, \"facility_levels\": {\"fac_dormitory\": []}, \"roster\": [{\"unit_id\": \"adv_t\", \"class_id\": \"cls_warrior\", \"display_name\": \"测试\", \"level\": 1, \"exp\": 0, \"attrs\": {\"strength\": []}, \"skill_ids\": [], \"skill_points\": 0, \"tendency_id\": \"\", \"status\": 0, \"rest_days\": 0, \"last_expedition_day\": 0, \"pre_unlocked\": true, \"equip_slots\": {}, \"stress\": 0, \"quirks\": []}], \"last_party_by_tpl\": {\"q_lair_purge\": [\"adv_a\", 5]}, \"pending_tendency_levels\": {\"adv_t\": []}, \"has_unseen_grants\": []}}}"
	DirAccess.make_dir_recursive_absolute("user://saves")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(raw_save)
	file.close()
	save_manager.current = null
	var loaded: SaveData = save_manager.load_game()
	assert_object(loaded).is_not_null()
	# 链完整走完：各脏槽回退默认（非 stale 残留）+ 旗标如实（恢复完成）
	assert_int(state.core.day).is_equal(1)
	assert_int(state.core.gold).is_equal(0)
	assert_int(state.core.board.serial).is_equal(1)
	assert_int(state.core.recruit_pool.serial).is_equal(1)
	assert_int(int(state.core.facility_levels.get(&"fac_dormitory", 0))).is_equal(1)
	assert_int(state.core.roster.size()).is_equal(1)
	assert_int(int(state.core.roster[0].attrs.get(&"strength", 0))) \
			.is_equal(AttrKeys.DEFAULT_ATTR_VALUE)
	assert_int(state.core.last_party_by_tpl["q_lair_purge"].size()).is_equal(1)
	assert_int(int(state.core.pending_tendency_levels.get("adv_t", -1))).is_equal(0)
	assert_bool(state.core.has_unseen_grants).is_false()
	assert_bool(state.has_guild_data()).is_true()
	state.free()
	save_manager.free()

func test_s3r5_serial_safety_and_roster_dedup_matrix() -> void:
	## S3-R5-01/02/03：serial 追平与名册查重矩阵——①board serial 脏回退 1 而
	## 实例 serial=5 存活 → 追平 6，后续上板不撞号（find_on_board 定位唯一）；
	## ②recruit serial 脏回退 1 而名册 adv_recruit_2 存活 → 兜底 3（新招募
	## 不发 adv_recruit_1 撞名册同 id）；③roster 双同 id + 空 unit_id 跳过
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	var adv_json: String = "{\"unit_id\": \"adv_recruit_2\", \"class_id\": \"cls_warrior\", \"display_name\": \"招募员\", \"level\": 1, \"exp\": 0, \"attrs\": {}, \"skill_ids\": [], \"skill_points\": 0, \"tendency_id\": \"\", \"status\": 0, \"rest_days\": 0, \"last_expedition_day\": 0, \"pre_unlocked\": false, \"equip_slots\": {}, \"stress\": 0, \"quirks\": []}"
	var adv_empty_json: String = "{\"unit_id\": \"\", \"class_id\": \"cls_warrior\", \"display_name\": \"空 id\", \"level\": 1, \"exp\": 0, \"attrs\": {}, \"skill_ids\": [], \"skill_points\": 0, \"tendency_id\": \"\", \"status\": 0, \"rest_days\": 0, \"last_expedition_day\": 0, \"pre_unlocked\": false, \"equip_slots\": {}, \"stress\": 0, \"quirks\": []}"
	var inst_json: String = "{\"serial\": 5, \"template_id\": \"q_lair_purge\", \"state\": 1, \"expire_day\": 9, \"party_ids\": [], \"urgent\": false, \"work_days_left\": 0}"
	var raw_save: String = "{\"schema_version\": 3, \"save_point\": 0, \"game_day\": 1, \"mode\": \"demo\", \"scene_id\": \"guild_shell\", \"saved_unix_time\": 0, \"payload\": {\"guild\": {\"board\": {\"serial\": [], \"accepted\": [" + inst_json + "]}, \"recruit_pool\": {\"serial\": []}, \"roster\": [" + adv_json + ", " + adv_json + ", " + adv_empty_json + "]}}}"
	DirAccess.make_dir_recursive_absolute("user://saves")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(raw_save)
	file.close()
	save_manager.current = null
	var loaded: SaveData = save_manager.load_game()
	assert_object(loaded).is_not_null()
	# ①board serial 追平：实例 serial=5 存活 → 发号 6 起（新上板不撞旧实例）
	assert_int(state.core.board.accepted.size()).is_equal(1)
	assert_int(state.core.board.serial).is_equal(6)
	var fresh_inst: QuestInstance = state.core.board.spawn_on_board(&"q_chore_supply_run",
			state.core.day)
	assert_int(fresh_inst.serial).is_equal(6)
	assert_object(state.core.board.find_on_board(6)).is_same(fresh_inst)
	# ②recruit serial 名册兜底：adv_recruit_2 存活 → ≥3（不发 1 撞名册）
	assert_int(state.core.recruit_pool.serial).is_greater_equal(3)
	# ③roster 查重 + 拒空：3 条脏 roster 只留 1 条有效
	assert_int(state.core.roster.size()).is_equal(1)
	assert_str(String(state.core.roster[0].unit_id)).is_equal("adv_recruit_2")
	state.free()
	save_manager.free()

func test_b3_resting_member_roundtrip() -> void:
	## 功能二批 3 增补：RESTING+rest_days 落档恢复（倒地转重伤经既有
	## status/rest_days 通道持久——schema 零变更）
	var local: Array = _MakeLocalState()
	var save_manager: Node = local[0]
	var state: Node = local[1]
	state.new_game()
	var member: AdventurerData = state.core.roster[1]
	member.status = AdventurerData.Status.RESTING
	member.rest_days = 3
	assert_int(save_manager.autosave(SaveData.SavePoint.DAY_END)).is_equal(OK)
	save_manager.current = null
	state.core = GuildCore.new()
	var loaded: SaveData = save_manager.load_game()
	assert_object(loaded).is_not_null()
	var restored: AdventurerData = state.core.find_member(member.unit_id)
	assert_object(restored).is_not_null()
	assert_int(restored.status).is_equal(AdventurerData.Status.RESTING)
	assert_int(restored.rest_days).is_equal(3)
	state.free()
	save_manager.free()

func _QuestDict(serial_value: int, template_id: String) -> Dictionary:
	## 构造合法 QuestInstance 快照条目（P18 脏档用例共用）
	## 参数 serial_value：实例序号；template_id：模板 id
	## 返回：快照字典
	return {
		"serial": serial_value, "template_id": template_id, "state": 0,
		"expire_day": 9, "party_ids": [], "urgent": false,
		"work_days_left": 0,
	}

func test_s2r7_restore_snapshot_duplicate_serial_skipped() -> void:
	## S2-07（P18）：restore_snapshot serial 查重——board 内同 serial 双条目
	## 与跨容器（board+accepted）同 serial 均按损坏条目跳过（首条保留，
	## find_on_board/find_accepted 定位歧义拦截；对齐 roster 口径）
	var board := QuestBoard.new()
	board.restore_snapshot({
		"serial": 5,
		"board": [
			_QuestDict(1, "q_lair_purge"),
			_QuestDict(1, "q_chore_supply_run"),
			_QuestDict(2, "q_chore_tavern_help"),
		],
		"accepted": [
			_QuestDict(2, "q_chore_messenger"),
			_QuestDict(3, "q_lost_miner_keepsake"),
		],
	})
	assert_int(board.board.size()).is_equal(2)
	assert_str(String(board.board[0].template_id)).is_equal("q_lair_purge")
	assert_str(String(board.board[1].template_id)).is_equal("q_chore_tavern_help")
	assert_int(board.accepted.size()).is_equal(1)
	assert_str(String(board.accepted[0].template_id)).is_equal("q_lost_miner_keepsake")
	# serial 追平口径不受查重影响：max(快照声明 5, 已恢复实例最大号 3 + 1) = 5
	assert_int(board.serial).is_equal(5)

func test_s2r9_adventurer_negative_values_rejected() -> void:
	## S2-09（P19）：exp/skill_points/rest_days/last_expedition_day 四键负值
	## 拒载（与 level 下界同式——脏档负经验回滚经济/负技能点免费解锁）
	for negative_key: String in ["exp", "skill_points", "rest_days",
			"last_expedition_day"]:
		var adv_data: Dictionary = {
			"unit_id": "adv_test", "class_id": "cls_warrior", "display_name": "测试",
			"level": 1, "exp": 0,
			"attrs": {}, "skill_ids": [],
			"skill_points": 0, "tendency_id": "", "status": 0, "rest_days": 0,
			"last_expedition_day": 0, "pre_unlocked": true, "equip_slots": {},
			"stress": 0, "quirks": [],
		}
		adv_data[negative_key] = -1
		var loaded: AdventurerData = AdventurerData.from_dict(adv_data)
		assert_bool(loaded == null) \
				.override_failure_message("负值键 %s 应拒载" % negative_key).is_true()

func test_new_game_missing_cfg_aborts_cleanly() -> void:
	## 审计修复回归（2026-10-03）：cfg_main 查无时 new_game 干净中止——
	## push_error + return，core 未半初始化（cfg 仍空）且 SaveManager 不被
	## 清空建档（current 仍 null——无「存档已初始化但随后中止」半途态）
	var save_manager: Node = load(SAVE_MANAGER_SCRIPT).new()
	add_child(save_manager)
	# 套件隔离同上：局部 GuildState 不 add_child 手动初始化
	var state: Node = load(GUILD_STATE_SCRIPT).new()
	state.core = GuildCore.new()
	state._rng = _MakeRng(507)
	state.bind(save_manager, _game_data)
	# 注入：摘除 cfg_main 记录（_ResolveCfg 查无 → null）
	var records: Dictionary = _game_data.get("_records") as Dictionary
	assert_object(records).is_not_null()
	var cfg_record: Resource = records[CoreConfig.CFG_MAIN_ID]
	records.erase(CoreConfig.CFG_MAIN_ID)
	state.new_game()
	# 立即恢复（gdUnit 断言失败不中断函数——还原必达，不污染套件共享实例）
	records[CoreConfig.CFG_MAIN_ID] = cfg_record
	assert_object(state.core.cfg).is_null()
	assert_object(save_manager.current).is_null()
	state.free()
	save_manager.free()
