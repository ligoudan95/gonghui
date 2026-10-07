## 临时视觉冒烟驱动主体（试玩反馈批验证——非生产代码，不入 selfcheck）
## 职责：真窗口（工程默认 1440×900）下验证路径闪烁高光与真实寻路**同源**
##（二轮修复：预览直收 find_path 结果，直线近似穿障碍已废除）并截图到
## res://reports/visual_smoke/feedback_batch2/，供视觉侧车核验：
##   ① 绕障碍场景预览——可达格中挑「寻路长 > 曼哈顿」的绕行目标（障碍/
##      占位致绕），stdout 输出直线距离 vs 真实路径对照证据，连拍呼吸
##      相位帧（金色高光贴真实路径、不穿障碍）
##   ② 真实 request_move 移动中连拍（同一路径重建高光 + 逐格熄灭）
## 驱动口径：SceneManager.go 真实切换（铁律⑦）；战斗屏直构 BattleParams
##（visual_smoke_runner 先例同款 enc_m1_lair_pack 真实装配，不 new_game
## 不触存档写）；预览直调 battle_screen._HandleMoveTap（生产点按链——
## 含 find_path 同源接线）。一轮批 title 布局截图见 feedback_batch/。
## 保护：序列走完自动退出；120s 总超时兜底 quit(2) 防挂死。
extends Node

## SceneManager 脚本类引用（SceneId 常量——autoload 枚举不可经实例属性访问）
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")
## 截图输出目录（独立子目录——不清 feedback_batch 一轮产物）
const OUT_DIR: String = "res://reports/visual_smoke/feedback_batch2/"
## 我方队伍（战斗屏装配——visual_smoke_runner.PARTY 同款）
const PARTY: Array = [
	[&"warrior", &"cls_warrior"],
	[&"ranger", &"cls_ranger"],
	[&"mage", &"cls_mage"],
	[&"priest", &"cls_priest"],
]
## 总超时（秒——防挂死兜底）
const WATCHDOG_SECONDS: float = 120.0

## 战斗屏根（装配后供相位 B 消费）
var _battle: Control = null
## 战斗上下文（装配后缓存）
var _ctx: BattleSetup.BattleContext = null
## 战斗控制器（装配后缓存）
var _controller: BattleController = null
## 截图序号（文件名前缀）
var _shot_no: int = 0
## 序列完成标记（watchdog 判据）
var _done: bool = false

func _ready() -> void:
	## 引擎回调：准备输出目录 → 挂 watchdog → 启动驱动协程（fire-and-forget）
	## 参数：无
	## 返回：无
	get_tree().root.title = "gonghui-feedback-batch（试玩反馈批验证窗口）"
	_PrepareOutDir()
	get_tree().create_timer(WATCHDOG_SECONDS).timeout.connect(
		func() -> void:
			if not _done:
				_Print("watchdog", "总超时 %.0f 秒——强制退出（防挂死）" % WATCHDOG_SECONDS)
				get_tree().quit(2)
	)
	_Run()

# --------------------------------------------------------------------------
# 主序列
# --------------------------------------------------------------------------

func _Run() -> void:
	## 驱动主序列：战斗绕障碍路径高光（预览呼吸相位连拍 → 真实移动中
	## 熄灭连拍 → 完成清空）→ 退出
	## 参数：无
	## 返回：无（协程）
	var t0: int = Time.get_ticks_msec()
	_Print("boot", "试玩反馈批二轮驱动启动（真窗口 %s，非 headless）" % str(
			DisplayServer.window_get_size()))
	await _PhasePathHighlights()
	_done = true
	_Print("done", "驱动序列完成：耗时 %.1f s——自动退出" % [
			(Time.get_ticks_msec() - t0) / 1000.0])
	await get_tree().create_timer(0.4).timeout
	get_tree().quit(0)

# --------------------------------------------------------------------------
# 相位：绕障碍路径闪烁高光
# --------------------------------------------------------------------------

func _PhasePathHighlights() -> void:
	## 路径闪烁高光同源验证：进战斗 → 等我方指令窗 → 挑绕障碍目标格
	##（寻路长 > 曼哈顿 = 绕行证据）→ 走生产点按链 _HandleMoveTap（含
	## find_path 同源接线）连拍呼吸相位 → 真实 request_move 移动中连拍
	##（同一路径重建 + 逐格熄灭）→ 等完成拍清空帧
	## 参数：无
	## 返回：无（协程）
	await _EnterBattle()
	if _battle == null or _ctx == null or _controller == null:
		_Print("path", "战斗装配失败——相位终止")
		return
	var waited: int = 0
	while (_controller.current_unit == null or not _controller.awaiting_command) \
			and waited < 900:
		await get_tree().process_frame
		waited += 1
	if _controller.current_unit == null:
		_Print("path", "未等到我方指令窗——相位终止")
		return
	var unit: BattleUnit = _controller.current_unit
	var board: BattleBoard = _battle.get_node("%BoardLayer") as BattleBoard
	var dest: Vector2i = _PickDetourReachable(unit)
	if dest == Vector2i(-1, -1):
		_Print("path", "无可达格——相位终止")
		return
	var real_path: Array[Vector2i] = _ctx.grid.find_path(unit, unit.grid_pos,
			dest, unit.move_final())
	var manhattan: int = absi(dest.x - unit.grid_pos.x) + absi(dest.y - unit.grid_pos.y)
	_Print("path", "绕障碍预览 %s → %s：曼哈顿 %d 格 / 真实寻路 %d 格（绕行 %s）" % [
			str(unit.grid_pos), str(dest), manhattan, real_path.size(), str(real_path)])
	_Print("path", "呼吸周期 %.2fs / 峰值 %.2f" % [
			board._PathHighlightFlashSeconds(), board._PathHighlightPeakAlpha()])
	# 预览阶段：走生产点按链（含 find_path 同源接线），连拍呼吸不同相位
	_battle._HandleMoveTap(dest)
	_Print("path", "点按预览后高光格数 %d（应 == 寻路 %d 格，且不含起点）" % [
			board._path_highlight_cells.size(), real_path.size()])
	await _Shot("path_highlight_preview_bright")
	await get_tree().create_timer(0.3).timeout
	await _Shot("path_highlight_preview_dim")
	await get_tree().create_timer(0.3).timeout
	await _Shot("path_highlight_preview_bright_again")
	# 真实移动：二连点生产链确认（同格再 _HandleMoveTap——首点已置
	# _pending_cell，确认分支内部走 controller.request_move → unit_moved →
	# 同一路径重建高光 + 逐格熄灭；不直调 request_move 绕过点按链）
	#（步长 0.15s/步——0.12s 间隔连拍覆盖在途窗口）
	_battle._HandleMoveTap(dest)
	_Print("path", "二连点确认 → %s 受理=%s（连拍移动中熄灭帧）" % [
			str(dest), unit.has_moved])
	var burst_count: int = mini(real_path.size() + 3, 10)
	for i: int in range(burst_count):
		await _Shot("path_highlight_moving_extinguish_%d" % (i + 1))
		await get_tree().create_timer(0.12).timeout
	# 等移动 tween 收尾（完成回调逐格熄尽）拍清空帧
	var settle: int = 0
	while board._move_tweens.has(unit.unit_id) and settle < 300:
		await get_tree().process_frame
		settle += 1
	await get_tree().create_timer(0.2).timeout
	_Print("path", "移动完成：覆盖池 %d / 高光映射 %d（应全 0）" % [
			board._path_overlays.size(), board._path_highlight_cells.size()])
	await _Shot("path_highlight_all_extinguished")

func _EnterBattle() -> void:
	## 直构 BattleParams（4 职业）经 SceneManager 进 BATTLE_SCREEN 并等挂载
	##（visual_smoke_runner._EnterBattle 同款——不 new_game 不触存档写）
	## 参数：无
	## 返回：无（协程——等场景切换落地）
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
	var err: Error = get_tree().root.get_node("SceneManager").go(
			SceneManagerScript.SceneId.BATTLE_SCREEN, {&"battle_params": params})
	if err != OK:
		_Print("enter", "SceneManager.go 失败（错误码 %d）" % err)
		return
	for i: int in range(6):
		await get_tree().process_frame
	_battle = get_tree().root.find_child("BattleScreen", true, false) as Control
	if _battle == null or _battle.context == null:
		_Print("enter", "BattleScreen 未挂载或装配降级")
		return
	_ctx = _battle.context
	_controller = _battle.controller
	_Print("enter", "战斗装配成立：我方 %d + 敌方 %d" % [
			_ctx.allies.size(), _ctx.enemies.size()])

func _PickDetourReachable(unit: BattleUnit) -> Vector2i:
	## 绕障碍目标挑选（同源验证主体）：可达格中寻「find_path 长度 > 曼哈顿
	## 距离」者（障碍/占位致绕——预览贴真实路径不穿障碍的证据场景）；无绕行
	## 格退化最远可达格（随机图障碍摆位不保证）
	## 参数 unit：当前行动单位
	## 返回：目的地（无合适返回 (-1,-1)）
	var reachable: Array[Vector2i] = _ctx.grid.find_reachable(unit, unit.move_final())
	var detour: Vector2i = Vector2i(-1, -1)
	var detour_gain: int = 0
	var farthest: Vector2i = Vector2i(-1, -1)
	var farthest_dist: int = 0
	for dest: Vector2i in reachable:
		if dest == unit.grid_pos:
			continue
		var manhattan: int = absi(dest.x - unit.grid_pos.x) + absi(dest.y - unit.grid_pos.y)
		if manhattan > farthest_dist:
			farthest_dist = manhattan
			farthest = dest
		var path_len: int = _ctx.grid.find_path(unit, unit.grid_pos, dest,
				unit.move_final()).size()
		if path_len > manhattan and path_len - manhattan > detour_gain:
			detour_gain = path_len - manhattan
			detour = dest
	if detour != Vector2i(-1, -1):
		return detour
	return farthest

# --------------------------------------------------------------------------
# 截图与输出工具
# --------------------------------------------------------------------------

func _PrepareOutDir() -> void:
	## 输出目录就绪（建目录 + 清旧 png——重复运行不混批）
	## 参数：无
	## 返回：无
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var dir: DirAccess = DirAccess.open(OUT_DIR)
	if dir == null:
		push_error("[FB-SMOKE] 输出目录不可用 %s" % OUT_DIR)
		return
	for file_name: String in dir.get_files():
		if file_name.ends_with(".png"):
			dir.remove(file_name)

func _Shot(tag: String) -> void:
	## 单帧截图：等本帧绘制完成后取视口纹理存盘（真窗口渲染帧）
	## 参数 tag：验证点标记（文件名组成部分）
	## 返回：无（协程）
	await RenderingServer.frame_post_draw
	_shot_no += 1
	var path: String = "%s%02d_%s.png" % [OUT_DIR, _shot_no, tag]
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(path)
	print("[FB-SHOT] #%02d %s  %dx%d err=%d" % [_shot_no, tag, img.get_width(),
			img.get_height(), err])

func _Print(tag: String, msg: String) -> void:
	## 统一时序日志（stdout——供人工比对截图时刻）
	## 参数 tag：相位标记；msg：内容
	## 返回：无
	print("[FB-SMOKE][%s] %s" % [tag, msg])
