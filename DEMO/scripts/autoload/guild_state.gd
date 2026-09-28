## 公会状态（自动加载单例：GuildState）
## 职责：M4 经营层 autoload 薄壳——持有 GuildCore 实例、向 SaveManager 注册
## 公会快照 provider（payload[&"guild"]）、#26 五时点 autosave 业务口与信号桥。
## 全部规则逻辑在 GuildCore 纯逻辑类（铁律⑥），本类不承载规则。
## 依赖：GameData（读表）/SaveManager（provider+autosave+出征锁）——铁律④链
## GameConfig→GameData→SaveManager→GuildState→SceneManager 的第四环。
## 注册位注记（席4 L2 对齐）：Godot 重写 project.godot 后实际注册于 SceneManager
## 之后（链上第五位）——本单例依赖仅 GameData/SaveManager（先于本单例入树），
## 晚注册不影响 _ready 装配，注释与实况对齐、注册不动。
## new_game 入口批 2 接 title 屏。
extends Node

## 日结算完成（等待/跳过一天或回城补结算逐日——参数 DaySummary）
signal day_settled(summary: GuildCore.DaySummary)
## 回城结算完成（参数 ExpeditionSummary）
signal expedition_settled(summary: GuildCore.ExpeditionSummary)
## 设施升级完成（参数设施 id）
signal facility_upgraded(facility_id: StringName)
## 招募入册完成（参数新成员）
signal member_recruited(member: AdventurerData)

## 公会运行态核心（规则门面——UI/流程层经本单例访问）
var core: GuildCore
## 注入的 SaveManager（bind 装配；_ready 取 /root/SaveManager）
var _save_manager: Node
## 注入的 GameData（bind 装配）
var _game_data: Node
## 随机源（new_game 建档时 randomize；测试经 bind 前覆写可注入固定种子）
var _rng: RandomNumberGenerator
## 最近一次自动存档失败标记（S3-M5-1-b：RETURN_SETTLED 之外的 autosave
## FAILED 的 UI 感知——与 M-3 的 summary.save_failed 口径对称；guild_shell
## RefreshAll 消费呈现；每次业务操作入口复位）
var last_autosave_failed: bool = false

func _ready() -> void:
	## 引擎回调：建核心并按铁律④链装配依赖（SaveManager 已先于本单例入树）
	## 参数：无
	## 返回：无
	core = GuildCore.new()
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	bind(get_node_or_null("/root/SaveManager"), get_node_or_null("/root/GameData"))

func bind(save_manager: Node, game_data: Node) -> void:
	## 依赖装配 + 快照 provider 注册（autoload _ready 与测试注入同一入口）
	## 参数 save_manager/game_data：SaveManager / GameData 节点（测试可传实例）
	## 返回：无
	_save_manager = save_manager
	_game_data = game_data
	if _save_manager != null:
		_save_manager.register_snapshot_provider(&"guild", _SaveSnapshot, _RestoreSnapshot)

func new_game() -> void:
	## 新档入口（批 2 接 title「开始新游戏」；本批先落方法）：SaveManager 建档
	## → GuildCore.setup（初始资金/种子名册/委托板预生成/招募池首刷）→
	## 同步天数 → autosave(NEW_GAME)
	## 参数：无
	## 返回：无
	if _save_manager == null or _game_data == null:
		push_error("GuildState: 依赖未装配（SaveManager/GameData），new_game 中止")
		return
	_save_manager.new_game()
	core.setup(_ResolveCfg(), _game_data, _rng)
	_SyncDay()
	last_autosave_failed = _save_manager.autosave(SaveData.SavePoint.NEW_GAME) != OK

func wait_one_day() -> GuildCore.DaySummary:
	## 等待/跳过一天（案 2 §2.2 兜底行为；出征进行中不可用——日历冻结口径）：
	## 出征锁校验 → settle_one_day → 同步 game_day → autosave(DAY_END) → 信号
	## 参数：无
	## 返回：DaySummary；出征锁生效返回 null
	if _IsExpeditionLocked():
		push_warning("GuildState: 出征进行中不可跳过一天（日历冻结口径）")
		return null
	var summary := core.settle_one_day()
	_SyncDay()
	if _save_manager != null:
		last_autosave_failed = _save_manager.autosave(SaveData.SavePoint.DAY_END) != OK
	day_settled.emit(summary)
	return summary

func settle_expedition(run: ExpeditionRun,
		outcome: GuildCore.ExpeditionOutcome) -> GuildCore.ExpeditionSummary:
	## 回城结算业务口：**先释出征锁**（回城即出征结束——锁序保证
	## RETURN_SETTLED autosave 不被 #26 出征锁跳过；调用方 explore_screen 亦先行
	## 释锁——双保险单点）→ core 结算 → 同步天数 → **场景锚定公会壳**
	##（RETURN_SETTLED 时点玩家语义在城内——title「继续」按 scene_id 回最近
	## 城内时点，不落探索屏裸开）→ autosave(RETURN_SETTLED) → 信号
	## 参数 run：出征会话；outcome：出口（四出口之一）
	## 返回：ExpeditionSummary
	# S3-M5-1-a：壳层幂等早退——run 已结算时 core 返回空摘要，但壳层不得
	# 再 _SyncDay/autosave/emit（空摘要信号会误导 UI 重复刷新与落盘）
	if run.settled:
		return core.settle_expedition(run, outcome)
	if _save_manager != null:
		_save_manager.set_expedition_lock(false)
	var summary := core.settle_expedition(run, outcome)
	_SyncDay()
	if _save_manager != null and _save_manager.current != null:
		_save_manager.current.scene_id = SaveData.SCENE_GUILD_SHELL
	# M-3：RETURN_SETTLED 失败消费——写入失败时摘要带标志（结算面板警示行）
	if _save_manager != null and _save_manager.autosave(
			SaveData.SavePoint.RETURN_SETTLED) != OK:
		summary.save_failed = true
	expedition_settled.emit(summary)
	return summary

func build_expedition_run(inst: QuestInstance) -> ExpeditionRun:
	## 出征会话装配（纯装配无副作用）：编队成员取自名册（实例 party_ids）、
	## HP 按装配口径派生（DerivedStats）、判据/迷雾/耗时基准经 start_explore
	## 注入（表值唯一权威）
	## 参数 inst：目标委托实例（ACCEPTED/IN_PROGRESS 均可装配）
	## 返回：ExpeditionRun；成员/图缺失返回 null（调用方提示）
	if core == null or core.game_data == null:
		return null
	var quest_tpl: QuestTemplateDef = core.game_data.get_record(inst.template_id) as QuestTemplateDef
	if quest_tpl == null:
		push_warning("GuildState: 出征委托模板 '%s' 查无" % inst.template_id)
		return null
	var run := ExpeditionRun.new()
	for member_id: StringName in inst.party_ids:
		var member: AdventurerData = core.find_member(member_id)
		if member == null:
			push_warning("GuildState: 编队成员 '%s' 不在名册——出征中止" % member_id)
			return null
		run.party.append(member)
		var cls: ClassDef = core.game_data.get_record(member.class_id) as ClassDef
		run.hp[member] = DerivedStats.calc_hp(
				int(member.attrs.get(AttrKeys.CONSTITUTION, AttrKeys.DEFAULT_ATTR_VALUE)),
				cls, member.level, core.cfg)
	var map_def: ExploreMapDef = null
	if quest_tpl.map_id != &"":
		map_def = core.game_data.get_record(quest_tpl.map_id) as ExploreMapDef
	if map_def == null:
		var maps: Array = core.game_data.get_domain(&"map/maps")
		if maps.is_empty():
			push_warning("GuildState: map/maps 域为空——出征中止")
			return null
		map_def = maps[0] as ExploreMapDef
	run.quest_serial = inst.serial
	run.start_explore(map_def, quest_tpl, core.cfg.vision_radius)
	return run

func begin_expedition(inst: QuestInstance) -> ExpeditionRun:
	## 出征确认业务口（M4-3：消除「确认出征→探索屏落锁」帧窗）：装配 run →
	## core.start_expedition（进行中 1 上限/每日一次/编队校验）→ **同一同步段内
	## 置出征锁**（锁起点=确认成功——go() 切换期间等待按钮即被禁用，无空窗）；
	## 装配或校验失败零副作用（不置锁不迁移状态，原因见 core.last_error）
	## 参数 inst：挂单（ACCEPTED）实例
	## 返回：ExpeditionRun；失败返回 null
	core.last_error = ""
	var run: ExpeditionRun = build_expedition_run(inst)
	if run == null:
		return null
	if not core.start_expedition(inst.serial):
		return null
	if _save_manager != null:
		_save_manager.set_expedition_lock(true)
	return run

func recruit(index: int) -> AdventurerData:
	## 招募业务口：core 校验扣款入册 → autosave(RECRUIT_DONE) → 信号
	## 参数 index：候选下标
	## 返回：入册成员；失败返回 null（原因在 core.last_error）
	var member: AdventurerData = core.recruit(index)
	if member != null:
		if _save_manager != null:
			last_autosave_failed = _save_manager.autosave(SaveData.SavePoint.RECRUIT_DONE) != OK
		member_recruited.emit(member)
	return member

func upgrade_facility(facility_id: StringName) -> bool:
	## 设施升级业务口：core 校验扣款升级 → autosave(FACILITY_UPGRADED) → 信号
	## 参数 facility_id：设施 id
	## 返回：true = 升级成功
	if core.upgrade_facility(facility_id):
		if _save_manager != null:
			last_autosave_failed = _save_manager.autosave(SaveData.SavePoint.FACILITY_UPGRADED) != OK
		facility_upgraded.emit(facility_id)
		return true
	return false

func has_guild_data() -> bool:
	## 公会快照数据就绪判定（D-7：title「继续」消费——读档成功但公会快照为空
	## 的旧档/测试档不进公会占位屏，提示开新档）
	## 参数：无
	## 返回：true = 核心已装配（cfg/game_data 就绪——restore 或 new_game 完成）
	return core != null and core.cfg != null and core.game_data != null

func _SaveSnapshot() -> Dictionary:
	## 快照收集 provider 口（SaveManager autosave 回调）：核心未装配（M0 直连
	## SaveManager 的旧流程先于 GuildState.new_game 写盘）时返回空表——不落垃圾快照
	## 参数：无
	## 返回：公会快照 Dictionary
	if core == null or core.cfg == null:
		return {}
	return core.to_snapshot()

func _RestoreSnapshot(data: Dictionary) -> void:
	## 快照恢复 provider 口（SaveManager load_game 回调）：未装配依赖时先挂
	## （读档先于 new_game 的路径），再全量回放。**不回写 current.game_day**——
	## 快照 day 与存档顶层数字在生产流恒一致（写入前经 _SyncDay 同步），
	## 恢复侧单源在快照、顶层数字由 SaveData 自持；M0 直连旧流程的存档
	##（无公会快照/空快照）不被反向改写
	## 参数 data：存档 payload[&"guild"]
	## 返回：无
	if _game_data == null:
		push_warning("GuildState: GameData 未装配，公会快照恢复跳过")
		return
	if data.is_empty():
		return
	if core.cfg == null or core.game_data == null:
		core.attach(_ResolveCfg(), _game_data, _rng)
	core.restore_snapshot(data)

func _ResolveCfg() -> CoreConfig:
	## 总控配置读取（C-5 口径：GameData.get_record 直读 CoreConfig）
	## 参数：无
	## 返回：CoreConfig；查无返回 null（new_game 侧报错）
	return _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig

func _SyncDay() -> void:
	## 天数同步（GuildCore.day → SaveManager.current.game_day——快照与存档
	## 顶层数字一致；无 SaveManager/运行态时静默跳过）
	## 参数：无
	## 返回：无
	if _save_manager == null or _save_manager.current == null:
		return
	_save_manager.current.game_day = core.day

func _IsExpeditionLocked() -> bool:
	## 出征锁读取（SaveManager.is_expedition_locked——M4 补的读取口）
	## 参数：无
	## 返回：true = 出征中（日历冻结）
	if _save_manager == null:
		return false
	return _save_manager.is_expedition_locked()
