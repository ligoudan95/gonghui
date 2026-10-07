## 六屏背景视觉验证驱动（M6 批 3 后半：正式背景素材入库截图产出）
## 职责：真窗口（工程默认 1440×900）下按真实场景链驱动六个背景消费屏
##（标题/协会/战斗/探索/宿舍设施/训练场设施——批 3.5b 组 1 全部消费点），
## 逐屏截图到 res://reports/visual_smoke/bg_batch/，供视觉侧车核验新背景
## 实际渲染效果（非占位）。非生产代码，不入 selfcheck。
## 驱动口径：全部经 SceneManager.go 真实切换（铁律⑦）；协会屏需公会运行态
##——GuildState.new_game() 建档（铺满委托板/招募池的真实画面）；战斗屏直构
## BattleParams（visual_smoke_runner 先例同款 enc_m1_lair_pack 真实装配）；
## 探索屏无参直开走 _MakeDefaultRun 默认演示队。
## 存档保护：new_game 会 autosave 覆盖 user://saves/main_save.json——驱动前
## 备份三件存档文件、结束后按「先存在者还原/先不存在者清除」恢复原状
##（截图工具不得破坏用户存档）。
## 保护：序列走完自动退出；150s 总超时兜底 quit(2) 防挂死。
extends Node

## SceneManager 脚本类引用（SceneId 常量——autoload 枚举不可经实例属性访问）
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")
## 截图输出目录默认值（独立子目录——不清 visual_smoke 批 1/2 既有产物）
const OUT_DIR_DEFAULT: String = "res://reports/visual_smoke/bg_batch/"
## 环境变量名（覆盖输出目录——复核批指定新目录免改码）
const OUT_DIR_ENV: String = "BG_SHOWCASE_OUT"
## 我方队伍（战斗屏装配——visual_smoke_runner.PARTY 同款）
const PARTY: Array = [
	[&"warrior", &"cls_warrior"],
	[&"ranger", &"cls_ranger"],
	[&"mage", &"cls_mage"],
	[&"priest", &"cls_priest"],
]
## 存档文件三件套（正本/.bak/.tmp——备份恢复范围）
const SAVE_FILES: PackedStringArray = ["main_save.json", "main_save.json.bak",
		"main_save.json.tmp"]
## 存档备份目录（user://——驱动期间隔离原档）
const BACKUP_DIR: String = "user://saves/_bg_showcase_backup"
## 总超时（秒——防挂死兜底）
const WATCHDOG_SECONDS: float = 150.0
## 每屏切换后布局落定等待（秒）
const SETTLE_SECONDS: float = 0.6

## 备份时已存在的存档文件集（恢复判定单源）
var _existed_saves: Dictionary = {}
## 序列完成标记（watchdog 判据）
var _done: bool = false
## 实际输出目录（_ready 经环境变量 BG_SHOWCASE_OUT 覆盖——默认 OUT_DIR_DEFAULT）
var _out_dir: String = OUT_DIR_DEFAULT

func _ready() -> void:
	## 引擎回调：清输出目录 → 挂 watchdog → 启动驱动协程（fire-and-forget）
	## 参数：无
	## 返回：无
	get_tree().root.title = "gonghui-bg-showcase（六屏背景验证窗口）"
	var env_dir: String = OS.get_environment(OUT_DIR_ENV).strip_edges()
	if not env_dir.is_empty():
		_out_dir = env_dir if env_dir.ends_with("/") else env_dir + "/"
	_Print("boot", "输出目录 %s（env %s）" % [_out_dir, OUT_DIR_ENV])
	_PrepareOutDir()
	get_tree().create_timer(WATCHDOG_SECONDS).timeout.connect(
			func() -> void:
				if not _done:
					_Print("watchdog", "总超时 %.0f 秒——强制退出（防挂死）" % WATCHDOG_SECONDS)
					_RestoreSaves()
					get_tree().quit(2)
	)
	_Run()

func _Run() -> void:
	## 驱动主序列：备份存档 → new_game → 六屏逐一「go → 落定 → 截图」→
	## 恢复存档 → 汇总退出
	## 参数：无
	## 返回：无（协程）
	var t0: int = Time.get_ticks_msec()
	_Print("boot", "六屏背景验证驱动启动（真窗口 %s）" % str(
			DisplayServer.window_get_size()))
	_BackupSaves()
	get_tree().root.get_node("GuildState").new_game()
	_Print("boot", "new_game 建档完成（协会屏铺真实委托板/招募池）")
	await _Goto(SceneManagerScript.SceneId.TITLE, {})
	await _ShotScreen("01_title_bg_title", "TitleScreen")
	await _Goto(SceneManagerScript.SceneId.ASSOCIATION_SCREEN, {})
	await _ShotScreen("02_association_bg_association_hall", "AssociationScreen")
	var params := _BuildBattleParams()
	await _Goto(SceneManagerScript.SceneId.BATTLE_SCREEN,
			{&"battle_params": params})
	await _ShotScreen("03_battle_bg_battle_mine", "BattleScreen")
	await _Goto(SceneManagerScript.SceneId.EXPLORE_SCREEN, {})
	await _ShotScreen("04_explore_bg_explore", "ExploreScreen")
	await _Goto(SceneManagerScript.SceneId.GUILD_DORMITORY, {})
	await _ShotScreen("05_dormitory_bg_dormitory", "FacilityScreen")
	await _Goto(SceneManagerScript.SceneId.GUILD_TRAINING_GROUND, {})
	await _ShotScreen("06_training_bg_training_ground", "FacilityScreen")
	_RestoreSaves()
	_done = true
	var count: int = 0
	var dir: DirAccess = DirAccess.open(_out_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			if file_name.ends_with(".png"):
				count += 1
	_Print("done", "六屏截图完成：%d 张 / 耗时 %.1f s / 存档已还原——自动退出" % [
			count, (Time.get_ticks_msec() - t0) / 1000.0])
	await get_tree().create_timer(0.4).timeout
	get_tree().quit(0)

func _Goto(scene_id: int, params: Dictionary) -> void:
	## 场景切换 + 切换锁释放等待（_FinishSwitch 两帧窗口后 + 布局落定）
	## 参数 scene_id：SceneId 之一；params：跨场景参数
	## 返回：无（协程）
	var err: Error = get_tree().root.get_node("SceneManager").go(scene_id, params)
	_Print("goto", "go(%d) 受理=%s" % [scene_id, err == OK])
	for i: int in range(6):
		await get_tree().process_frame
	await get_tree().create_timer(SETTLE_SECONDS).timeout

func _ShotScreen(tag: String, expect_node: String) -> void:
	## 单屏截图：目标场景根存在性证据 + 单帧截图存盘
	## 参数 tag：文件名标记；expect_node：预期场景根节点名（stdout 证据）
	## 返回：无（协程）
	var root_name: String = ""
	if get_tree().current_scene != null:
		root_name = get_tree().current_scene.name
	await RenderingServer.frame_post_draw
	var path: String = "%s%s.png" % [_out_dir, tag]
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(path)
	_Print("shot", "%s（场景根=%s 预期=%s 尺寸=%dx%d err=%d）" % [
			tag, root_name, expect_node, img.get_width(), img.get_height(), err])

func _BuildBattleParams() -> BattleParams:
	## 战斗参数直构（visual_smoke_runner._EnterBattle 同款：四职业随机属性队
	## + enc_m1_lair_pack 巢穴图——真实装配含精英/杂兵/障碍的完整战局）
	## 参数：无
	## 返回：BattleParams
	var game_data: Node = get_tree().root.get_node("GameData")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var party: Array[AdventurerData] = []
	for pair: Array in PARTY:
		var cls: ClassDef = game_data.get_record(pair[1]) as ClassDef
		var attrs: Dictionary[StringName, int] = AttrRoller.roll_fixed_four(cls, rng)
		party.append(AdventurerData.create_debug(pair[0], pair[1], attrs, game_data))
	var params := BattleParams.new()
	params.pack_id = &"enc_m1_lair_pack"
	params.party = party
	return params

# --------------------------------------------------------------------------
# 存档备份/恢复（截图工具不得破坏用户存档）
# --------------------------------------------------------------------------

func _BackupSaves() -> void:
	## 存档三件套备份：先存在者复制进隔离目录并记录；备份目录先清（防上次
	## 中断残留误判）
	## 参数：无
	## 返回：无
	_existed_saves = {}
	DirAccess.make_dir_recursive_absolute(BACKUP_DIR)
	var dir: DirAccess = DirAccess.open(BACKUP_DIR)
	if dir != null:
		for file_name: String in dir.get_files():
			dir.remove(file_name)
	for file_name: String in SAVE_FILES:
		var src: String = "user://saves/%s" % file_name
		if FileAccess.file_exists(src):
			DirAccess.copy_absolute(src, "%s/%s" % [BACKUP_DIR, file_name])
			_existed_saves[file_name] = true
	_Print("save", "备份完成：先前存在存档 %d/%d 件" % [
			_existed_saves.size(), SAVE_FILES.size()])

func _RestoreSaves() -> void:
	## 存档恢复：先存在者从备份还原覆盖；先不存在者删除驱动期间新产物；
	## 清空备份目录
	## 参数：无
	## 返回：无
	for file_name: String in SAVE_FILES:
		var src: String = "user://saves/%s" % file_name
		if _existed_saves.has(file_name):
			DirAccess.copy_absolute("%s/%s" % [BACKUP_DIR, file_name], src)
		elif FileAccess.file_exists(src):
			DirAccess.remove_absolute(src)
	var dir: DirAccess = DirAccess.open(BACKUP_DIR)
	if dir != null:
		for file_name: String in dir.get_files():
			dir.remove(file_name)
	_Print("save", "存档已还原原状（存在者还原 %d 件/新生成者清除）" % _existed_saves.size())

func _PrepareOutDir() -> void:
	## 输出目录就绪（建目录 + 清旧 png——重复运行不混批）
	## 参数：无
	## 返回：无
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var dir: DirAccess = DirAccess.open(_out_dir)
	if dir == null:
		push_error("[BG-SHOWCASE] 输出目录不可用 %s" % _out_dir)
		return
	for file_name: String in dir.get_files():
		if file_name.ends_with(".png"):
			dir.remove(file_name)

func _Print(tag: String, msg: String) -> void:
	## 统一时序日志（stdout——供人工比对截图时刻）
	## 参数 tag：相位标记；msg：内容
	## 返回：无
	print("[BG-SHOWCASE][%s] %s" % [tag, msg])
