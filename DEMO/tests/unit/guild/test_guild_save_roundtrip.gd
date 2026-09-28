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
