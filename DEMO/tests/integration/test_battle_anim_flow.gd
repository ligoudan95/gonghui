## M6 批 1 战斗动作流集成测试（GdUnitSceneRunner + 真实占位动作资产）
## 覆盖：battle_started 全员 IDLE / skill_executed 姿态路由（MELEE/CAST/NONE）
## + 朝向翻转（同列重置默认——低8）/ MISS 不播受击 / 命中 HIT+白闪 /
## unit_moved MOVE+位置直落与立即回落 IDLE（cfg 注 0——低6）/ 非 0 步长
## tween 生命周期（中5：池登记/杀旧起新/回落 IDLE）/ trap_triggered 存活
## HIT / unit_downed 尸态锁定+条隐藏（D5）/ 三致倒路径统一 DOWNED（中3：
## 攻击致死链真实 _execute_skill 实测 3/3）/ battle_ended 尸体常驻 /
## 序条头像首帧 atlas 契约 / 批次 A 移动朝向随步更新（链首即刻/竖直回正/
## 瞬移一次判定/无位移不触发/移动与攻击朝向互相覆盖）。
## 驱动口径：真实装配进战斗屏后 controller 信号直发（连接链 = 生产接线），
## 演出参数经共享 cfg 注入并即恢复。
extends GdUnitTestSuite

## 战斗场景路径
const BATTLE_SCENE: String = "res://scenes/battle/battle_screen.tscn"
## SceneId.BATTLE_SCREEN（测试直构参数进战斗屏——B-22 口径）
const SCENE_BATTLE: int = 2

func before_test() -> void:
	## 用例前置：复位 SceneManager 可变状态 + 清解析缓存
	## 参数：无
	## 返回：无
	var scene_manager: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_object(scene_manager).is_not_null()
	scene_manager.current_id = -1
	scene_manager.previous_id = -1
	scene_manager.pending_params = {}
	scene_manager._switch_pending = false
	SpriteResolver.clear_cache()

func after_test() -> void:
	## 用例级后置：清解析缓存（套件隔离）
	## 参数：无
	## 返回：无
	SpriteResolver.clear_cache()

func _EnterRandomBattle() -> Control:
	## 直构 BattleParams（默认 4 职业）进 BATTLE_SCREEN 并等挂载
	## 参数：无
	## 返回：战斗屏根（await 场景切换）
	var game_data: Node = get_tree().root.get_node("GameData")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var party: Array[AdventurerData] = []
	for pair: Array in [[&"warrior", &"cls_warrior"], [&"rogue", &"cls_rogue"],
			[&"mage", &"cls_mage"], [&"priest", &"cls_priest"]]:
		var cls: ClassDef = game_data.get_record(pair[1]) as ClassDef
		var attrs: Dictionary[StringName, int] = AttrRoller.roll_fixed_four(cls, rng)
		party.append(AdventurerData.create_debug(pair[0], pair[1], attrs, game_data))
	var params := BattleParams.new()
	params.pack_id = &"enc_m1_random_pack"
	params.party = party
	get_tree().root.get_node("SceneManager").go(SCENE_BATTLE,
			{&"battle_params": params})
	await get_tree().process_frame
	await get_tree().process_frame
	return get_tree().root.find_child("BattleScreen", true, false) as Control

func _BadgesOf(battle: Control) -> Array[UnitBadge]:
	## 板面徽章池查询（按子节点类型收集；视口批：徽章挂 WorldLayer 下——
	## 遍历随挂载点）
	## 参数 battle：战斗屏根
	## 返回：UnitBadge 数组
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	var badges: Array[UnitBadge] = []
	for child: Node in board._world_layer.get_children():
		if child is UnitBadge:
			badges.append(child as UnitBadge)
	return badges

func _BadgeOf(battle: Control, unit: BattleUnit) -> UnitBadge:
	## 单单位徽章查询
	## 参数 battle：战斗屏根；unit：单位
	## 返回：徽章；查无返回 null
	for badge: UnitBadge in _BadgesOf(battle):
		if badge.unit == unit:
			return badge
	return null

func _ResetBadge(badge: UnitBadge) -> void:
	## 徽章动作态硬复位（测试夹具口：绕过优先级仲裁直置 IDLE 首帧——
	## 开战自动演出残留态不污染后续直发断言）
	## 参数 badge：徽章
	## 返回：无
	badge.anim.current = UnitAnimState.Action.IDLE
	badge.anim.frame_index = 0

func _AliveUnitOf(units: Array) -> BattleUnit:
	## 取首个存活单位（开战自动演出期偶发承伤/致死的确定性防护）
	## 参数 units：单位池
	## 返回：存活单位；无存活返回 null
	for unit: BattleUnit in units:
		if unit.alive:
			return unit
	return null

func _MakeResult(skill_id: StringName, target_id: StringName,
		hit: bool, damage: int, has_attack: bool = true) -> SkillExecutor.ExecutionResult:
	## 手造 ExecutionResult（信号直发口径——不依赖真实执行链随机性）
	## 参数 skill_id/target_id/hit/damage：技能/目标/命中/伤害；has_attack：
	## 是否含攻击掷链（攻击技 true——MISS 判据；纯状态/治疗 false）
	## 返回：构造结果
	var result: SkillExecutor.ExecutionResult = SkillExecutor.ExecutionResult.new()
	result.success = true
	result.hit = hit
	result.damage = damage
	result.target_id = target_id
	result.trace = {&"skill": skill_id, &"target": target_id}
	if has_attack:
		result.trace[&"hit_chain"] = {&"passed": hit}
	return result

func test_battle_started_all_idle() -> void:
	## battle_started → 全员 IDLE（占位竖条非空——非色块回退）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	await get_tree().process_frame
	var badges: Array[UnitBadge] = _BadgesOf(battle)
	assert_int(badges.size()).is_equal(7)
	for badge: UnitBadge in badges:
		assert_int(badge.current_action()).is_equal(UnitAnimState.Action.IDLE)
		assert_bool(badge.is_downed_pose()).is_false()
	battle.controller.abort_battle()

func test_skill_pose_routing_melee_cast_none() -> void:
	## D4=A 姿态路由：挥击（MELEE）→ MELEE_ATTACK；火球（CAST）→ CAST_RANGED；
	## 盾墙（NONE）→ 不动（IDLE 维持）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var caster: BattleUnit = _AliveUnitOf(battle.context.allies)
	var target: BattleUnit = _AliveUnitOf(battle.context.enemies)
	_ResetBadge(_BadgeOf(battle, caster))
	battle._OnSkillExecuted(caster, _MakeResult(&"skl_atk_warrior", target.unit_id, true, 5))
	assert_int(_BadgeOf(battle, caster).current_action()) \
			.is_equal(UnitAnimState.Action.MELEE_ATTACK)
	_ResetBadge(_BadgeOf(battle, caster))
	battle._OnSkillExecuted(caster, _MakeResult(&"skl_mage_fireball", target.unit_id, true, 5))
	assert_int(_BadgeOf(battle, caster).current_action()) \
			.is_equal(UnitAnimState.Action.CAST_RANGED)
	# NONE 姿态：复位 IDLE 后发盾墙——动作不接（IDLE 维持；无攻击掷不飘 MISS）
	_ResetBadge(_BadgeOf(battle, caster))
	battle._OnSkillExecuted(caster, _MakeResult(&"skl_warrior_shield_wall",
			caster.unit_id, false, 0, false))
	assert_int(_BadgeOf(battle, caster).current_action()).is_equal(UnitAnimState.Action.IDLE)

func test_skill_pose_flip_resets_on_same_column() -> void:
	## 低8（盲审）契约：目标与施法者同列（grid_pos.x 相等）→ flip 重置默认
	## 朝向（不保持上次攻击的残留翻转）——先手动翻转残留再发同列攻击验证
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	var caster: BattleUnit = _AliveUnitOf(battle.context.allies)
	var target: BattleUnit = _AliveUnitOf(battle.context.enemies)
	# 残留翻转态：上次攻击朝左翻转
	board.set_badge_flip(caster, true)
	assert_bool(_FlipHOf(_BadgeOf(battle, caster))).is_true()
	# 同列目标（x 拉平——朝向无相位依据）：攻击分派后重置默认朝向
	target.grid_pos = Vector2i(caster.grid_pos.x, target.grid_pos.y)
	battle._OnSkillExecuted(caster, _MakeResult(&"skl_atk_warrior",
			target.unit_id, true, 5))
	assert_bool(_FlipHOf(_BadgeOf(battle, caster))).is_false() \
			.override_failure_message("同列攻击未重置默认朝向（保持上次残留翻转）")
	# 异列回归：目标在右 → 不翻转；目标在左（x 允许时）→ 翻转
	target.grid_pos = Vector2i(caster.grid_pos.x + 2, target.grid_pos.y)
	battle._OnSkillExecuted(caster, _MakeResult(&"skl_atk_warrior",
			target.unit_id, true, 5))
	assert_bool(_FlipHOf(_BadgeOf(battle, caster))).is_false()
	var left_x: int = caster.grid_pos.x - 2
	if left_x >= 0:
		target.grid_pos = Vector2i(left_x, target.grid_pos.y)
		battle._OnSkillExecuted(caster, _MakeResult(&"skl_atk_warrior",
				target.unit_id, true, 5))
		assert_bool(_FlipHOf(_BadgeOf(battle, caster))).is_true()

func _FlipHOf(badge: UnitBadge) -> bool:
	## 徽章 sprite 水平翻转态查询（低8 契约断言口）
	## 参数 badge：徽章
	## 返回：flip_h
	var sprite: TextureRect = badge.get_children().filter(
			func(child: Node) -> bool: return child is TextureRect)[0] as TextureRect
	return sprite.flip_h

func test_miss_no_hit_and_float_text() -> void:
	## 闪避拍板口径：攻击掷未命中 → 目标不播受击 + MISS 飘字可见
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var caster: BattleUnit = _AliveUnitOf(battle.context.allies)
	var target: BattleUnit = _AliveUnitOf(battle.context.enemies)
	_ResetBadge(_BadgeOf(battle, target))
	battle._OnSkillExecuted(caster, _MakeResult(&"skl_atk_warrior",
			target.unit_id, false, 0))
	assert_int(_BadgeOf(battle, target).current_action()).is_equal(UnitAnimState.Action.IDLE)
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	# 视口批：飘字挂 WorldLayer 下——遍历随挂载点
	var miss_labels: Array = board._world_layer.get_children().filter(func(child: Node) -> bool:
		return child is Label and (child as Label).text == "闪避")
	assert_int(miss_labels.size()).is_equal(1)

func test_hit_damage_plays_hit_and_flash() -> void:
	## 命中且伤害 > 0 → 目标 HIT + 受击白闪（flash 时长注大值断言 sprite 高亮）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var cfg: CoreConfig = battle.context.cfg
	var original_flash: float = cfg.ui_hit_flash_seconds
	cfg.ui_hit_flash_seconds = 60.0
	var caster: BattleUnit = _AliveUnitOf(battle.context.allies)
	var target: BattleUnit = _AliveUnitOf(battle.context.enemies)
	_ResetBadge(_BadgeOf(battle, target))
	battle._OnSkillExecuted(caster, _MakeResult(&"skl_atk_warrior",
			target.unit_id, true, 5))
	cfg.ui_hit_flash_seconds = original_flash
	var target_badge: UnitBadge = _BadgeOf(battle, target)
	assert_int(target_badge.current_action()).is_equal(UnitAnimState.Action.HIT)
	var sprite: TextureRect = target_badge.get_children().filter(
			func(child: Node) -> bool: return child is TextureRect)[0] as TextureRect
	assert_bool(sprite.modulate == Color(1, 1, 1, 1)).is_false() \
			.override_failure_message("受击白闪未生效（sprite modulate 未高亮）")
	# 低14（盲审）：白闪峰值色入表（cfg ui_hit_flash_peak_color——HDR 亮白
	# 消费锚定：峰值 == 表值而非代码内联）
	assert_bool(sprite.modulate == cfg.ui_hit_flash_peak_color) \
			.override_failure_message("白闪峰值 != cfg.ui_hit_flash_peak_color（%s != %s）" % [
					sprite.modulate, cfg.ui_hit_flash_peak_color])

func test_unit_moved_teleport_falls_back_idle() -> void:
	## D6=A 移动演出（cfg 步长注 0 瞬移）：位置直落新格 + **立即回落 IDLE**
	##（低6 盲审修复：瞬移分支与 tween 分支 tween_callback 回落对称——
	## cfg 置 0 后不再走步动画常驻到下次行动）；试玩反馈批：瞬移分支无演出
	## 过程不建**移动燃线**（燃线池/映射双空——漏洞1 修复：燃线入独立池
	## _burning_overlays，断言目标随之锚定燃线池而非预览池）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var cfg: CoreConfig = battle.context.cfg
	var original_step: float = cfg.ui_battle_move_step_seconds
	cfg.ui_battle_move_step_seconds = 0.0
	var unit: BattleUnit = _AliveUnitOf(battle.context.allies)
	var from_pos: Vector2i = unit.grid_pos
	var to_pos: Vector2i = from_pos + Vector2i(1, 0)
	unit.grid_pos = to_pos
	battle.controller.unit_moved.emit(unit, from_pos, to_pos, [to_pos])
	cfg.ui_battle_move_step_seconds = original_step
	var badge: UnitBadge = _BadgeOf(battle, unit)
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.IDLE)
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	assert_vector(badge.position).is_equal(board.cell_rect(to_pos).position)
	assert_int(board._burning_overlays.size()) \
			.override_failure_message("瞬移分支不应建移动燃线").is_equal(0)
	assert_int(board._burning_highlight_cells.size()).is_equal(0)

func test_unit_moved_tween_lifecycle_and_idle_fallback() -> void:
	## 中5（盲审）：非 0 步长移动演出主路径——tween 池登记/finished 出池/
	## 移动中再移动杀旧起新/tween 完成回落 IDLE 全锚定（此前全部用例注 0
	## 走瞬移分支，主路径零测试锚定）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var cfg: CoreConfig = battle.context.cfg
	var original_step: float = cfg.ui_battle_move_step_seconds
	cfg.ui_battle_move_step_seconds = 0.02
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	var unit: BattleUnit = _AliveUnitOf(battle.context.allies)
	var badge: UnitBadge = _BadgeOf(battle, unit)
	var from_a: Vector2i = unit.grid_pos
	var to_a: Vector2i = from_a + Vector2i(2, 0)
	unit.grid_pos = to_a
	battle.controller.unit_moved.emit(unit, from_a, to_a,
			[from_a + Vector2i(1, 0), to_a])
	# 登记在池 + MOVE 播放 + 未落终点（在途）
	assert_bool(board._move_tweens.has(unit.unit_id)).is_true()
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.MOVE)
	assert_vector(badge.position).is_not_equal(board.cell_rect(to_a).position)
	var old_tween: Tween = board._move_tweens[unit.unit_id] as Tween
	assert_bool(old_tween.is_valid()).is_true()
	# 移动中再移动（同帧无推进）：杀旧起新——旧 tween 失效、池内仍有新 tween
	var from_b: Vector2i = to_a
	var to_b: Vector2i = from_b + Vector2i(0, 2)
	unit.grid_pos = to_b
	battle.controller.unit_moved.emit(unit, from_b, to_b,
			[from_b + Vector2i(0, 1), to_b])
	assert_bool(old_tween.is_valid()).is_false() \
			.override_failure_message("重移动未杀旧 tween（杀旧起新失效）")
	assert_bool(board._move_tweens.has(unit.unit_id)).is_true()
	# 等待播完：回落 IDLE + 出池 + 落位终点（逐拐点链终点 = 目的地）
	var waited: int = 0
	while board._move_tweens.has(unit.unit_id) and waited < 300:
		await get_tree().process_frame
		waited += 1
	cfg.ui_battle_move_step_seconds = original_step
	assert_bool(waited < 300).is_true().override_failure_message("移动 tween 未在帧限内完成")
	assert_bool(board._move_tweens.has(unit.unit_id)).is_false() \
			.override_failure_message("tween 完成后未出池")
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.IDLE)
	assert_vector(badge.position).is_equal(board.cell_rect(to_b).position)

func test_unit_moved_path_highlights_extinguish_on_arrival() -> void:
	## 试玩反馈批（D4 契约修订）：移动过程路径闪烁高光——真实路径建**燃线**
	##（含终点不含起点）→ 逐格链每段到达即熄灭（走过的格消失、前方格仍在）
	## → 全程完成燃线清空；步长注 0.3s/段拉长时序窗供分段断言；漏洞1 修复
	## 断言目标锚定：燃线入独立池 _burning_overlays（不随 clear_overlays/
	## _ClearSelection 清理——由熄灭回调与 tween finished 自然烧完自清）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var cfg: CoreConfig = battle.context.cfg
	var original_step: float = cfg.ui_battle_move_step_seconds
	cfg.ui_battle_move_step_seconds = 0.3
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	var unit: BattleUnit = _AliveUnitOf(battle.context.allies)
	var from_pos: Vector2i = unit.grid_pos
	var mid: Vector2i = from_pos + Vector2i(1, 0)
	var to_pos: Vector2i = from_pos + Vector2i(2, 0)
	unit.grid_pos = to_pos
	battle.controller.unit_moved.emit(unit, from_pos, to_pos, [mid, to_pos])
	# 移动开始：真实路径 2 格全亮（unit_moved 处理器前置 clear 已清旧层——
	# 此处池内容全部来自 move_badge 重建入燃线池）
	assert_int(board._burning_overlays.size()).is_equal(2)
	assert_bool(board._burning_highlight_cells.has(mid)).is_true()
	assert_bool(board._burning_highlight_cells.has(to_pos)).is_true()
	# 第一段（0.3s）完成后：走过格熄灭、终点仍在闪
	await get_tree().create_timer(0.55).timeout
	assert_bool(board._burning_highlight_cells.has(mid)).is_false() \
			.override_failure_message("走过的格燃线未熄灭")
	assert_bool(board._burning_highlight_cells.has(to_pos)).is_true() \
			.override_failure_message("前方格燃线不应提前熄灭")
	# 全程完成（两段 0.6s + 余量）：燃线全清 + 回落 IDLE
	var waited: int = 0
	while board._move_tweens.has(unit.unit_id) and waited < 300:
		await get_tree().process_frame
		waited += 1
	cfg.ui_battle_move_step_seconds = original_step
	assert_bool(waited < 300).is_true().override_failure_message("移动 tween 未在帧限内完成")
	assert_int(board._burning_overlays.size()).is_equal(0)
	assert_int(board._burning_highlight_cells.size()).is_equal(0)
	assert_int(_BadgeOf(battle, unit).current_action()).is_equal(UnitAnimState.Action.IDLE)

func test_move_tap_production_chain_burning_highlights_lifecycle() -> void:
	## 漏洞1 测试缺口补位（生产链版——区别于上方直发 unit_moved 信号版）：
	## 两次 _HandleMoveTap 同格（首点预览 + 二连点确认）走真实交互链——
	## request_move → unit_moved → 处理器前置 clear_overlays（清预览层）+
	## move_badge 重建燃线（独立池）；断言确认后燃线高光节点在移动 tween
	## 完成前仍存在（演出窗口内采样——确认分支随后的 _ClearSelection 与
	## turn_started 均不清在途燃线）、tween finished 后逐格熄灭自清
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	var controller: BattleController = battle.controller
	controller.delay_seconds = 0.0
	# 等首个我方指令窗（开战自动流——首动单位 controllable 才开指令窗）
	var waited: int = 0
	while (controller.current_unit == null or not controller.awaiting_command) \
			and waited < 900:
		await get_tree().process_frame
		waited += 1
	assert_bool(controller.awaiting_command) \
			.override_failure_message("未等到我方指令窗").is_true()
	var unit: BattleUnit = controller.current_unit
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	var cfg: CoreConfig = battle.context.cfg
	var original_step: float = cfg.ui_battle_move_step_seconds
	cfg.ui_battle_move_step_seconds = 0.3
	# 挑真实寻路最长路径的可达目标（≥2 格拉长演出窗供中途采样；可达集内
	# 恒有非起点格——find_reachable 至少含邻接格）
	var dest: Vector2i = Vector2i(-1, -1)
	var path_len: int = 0
	for cell: Vector2i in battle.context.grid.find_reachable(unit, unit.move_final()):
		if cell == unit.grid_pos:
			continue
		var probe_len: int = battle.context.grid.find_path(unit, unit.grid_pos,
				cell, unit.move_final()).size()
		if probe_len > path_len:
			path_len = probe_len
			dest = cell
	assert_int(path_len).is_greater(0)
	var real_path: Array[Vector2i] = battle.context.grid.find_path(unit,
			unit.grid_pos, dest, unit.move_final())
	# 首点同格预览：高光入预览池（选择态），燃线池未动
	battle._HandleMoveTap(dest)
	assert_vector(battle._pending_cell).is_equal(dest)
	assert_int(board._path_highlight_cells.size()).is_equal(path_len)
	assert_int(board._burning_overlays.size()).is_equal(0)
	# 二连点确认：request_move 受理 → unit_moved → 前置 clear 清预览 +
	# move_badge 按同一路径重建燃线（演出窗口内存在）
	battle._HandleMoveTap(dest)
	assert_bool(unit.has_moved).is_true()
	assert_bool(board._move_tweens.has(unit.unit_id)).is_true() \
			.override_failure_message("确认移动后应有在途移动 tween")
	assert_int(board._path_highlight_cells.size()).is_equal(0) \
			.override_failure_message("确认后预览高光应被前置 clear 清空")
	assert_int(board._burning_overlays.size()).is_equal(path_len) \
			.override_failure_message("确认后燃线应在演出窗口内存在（独立池）")
	# 中途采样（路径 ≥2 格时）：首格已熄、终点仍在烧
	if path_len >= 2:
		await get_tree().create_timer(0.55).timeout
		assert_bool(board._burning_highlight_cells.has(real_path[0])).is_false() \
				.override_failure_message("走过的格燃线未熄灭（生产链）")
		assert_bool(board._burning_highlight_cells.has(dest)).is_true() \
				.override_failure_message("前方格燃线不应提前熄灭（生产链）")
	# tween finished 后：燃线逐格熄尽自清（无任何 clear_overlays 介入）
	var settle: int = 0
	while board._move_tweens.has(unit.unit_id) and settle < 300:
		await get_tree().process_frame
		settle += 1
	cfg.ui_battle_move_step_seconds = original_step
	assert_bool(settle < 300).is_true() \
			.override_failure_message("移动 tween 未在帧限内完成（生产链）")
	assert_int(board._burning_overlays.size()).is_equal(0) \
			.override_failure_message("tween 完成后燃线未自清（生产链）")
	assert_int(board._burning_highlight_cells.size()).is_equal(0)
	controller.abort_battle()

func test_trap_triggered_alive_plays_hit() -> void:
	## 陷阱触发：存活承伤 → HIT + 受击白闪（低7 盲审修复：与技能命中路径
	## HIT+白闪体验统一——闪时长注大值断言 sprite 高亮）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var cfg: CoreConfig = battle.context.cfg
	var flash_backup: float = cfg.ui_hit_flash_seconds
	cfg.ui_hit_flash_seconds = 60.0
	var unit: BattleUnit = _AliveUnitOf(battle.context.allies)
	_ResetBadge(_BadgeOf(battle, unit))
	battle.controller.trap_triggered.emit(unit, 3)
	cfg.ui_hit_flash_seconds = flash_backup
	var badge: UnitBadge = _BadgeOf(battle, unit)
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.HIT)
	var sprite: TextureRect = badge.get_children().filter(
			func(child: Node) -> bool: return child is TextureRect)[0] as TextureRect
	assert_bool(sprite.modulate == Color(1, 1, 1, 1)).is_false() \
			.override_failure_message("陷阱承伤未补受击白闪（低7 未修）")

func test_round_settled_dot_plays_hit_with_flash() -> void:
	## DOT 跳伤：存活承伤者 HIT + 受击白闪（低7：三承伤路径体验统一）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var cfg: CoreConfig = battle.context.cfg
	var flash_backup: float = cfg.ui_hit_flash_seconds
	cfg.ui_hit_flash_seconds = 60.0
	var unit: BattleUnit = _AliveUnitOf(battle.context.allies)
	_ResetBadge(_BadgeOf(battle, unit))
	battle.controller.round_settled.emit(1, [{&"unit": unit, &"damage": 2}])
	cfg.ui_hit_flash_seconds = flash_backup
	var badge: UnitBadge = _BadgeOf(battle, unit)
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.HIT)
	var sprite: TextureRect = badge.get_children().filter(
			func(child: Node) -> bool: return child is TextureRect)[0] as TextureRect
	assert_bool(sprite.modulate == Color(1, 1, 1, 1)).is_false() \
			.override_failure_message("DOT 承伤未补受击白闪（低7 未修）")

func test_unit_downed_locks_corpse_pose_and_hides_bars() -> void:
	## D5=A 尸态：unit_downed → DOWNED 锁定 + 血条/资源条隐藏 + 灰度维持 +
	## battle_ended 后尸体常驻（不回落）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var unit: BattleUnit = _AliveUnitOf(battle.context.enemies)
	unit.take_damage(unit.current_hp)
	battle.controller.unit_downed.emit(unit)
	var badge: UnitBadge = _BadgeOf(battle, unit)
	assert_bool(badge.is_downed_pose()).is_true()
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.DOWNED)
	# 条隐藏（尸态只留 sprite）：全部 ColorRect 子节点不可见（HP/资源条/环/蛊惑边）
	var rects: Array = badge.get_children().filter(func(child: Node) -> bool:
		return child is ColorRect)
	assert_bool(rects.size() >= 8).is_true() \
			.override_failure_message("徽章条/环节点数异常（%d）" % rects.size())
	for rect: ColorRect in rects:
		assert_bool(rect.visible).is_false() \
				.override_failure_message("尸态残留可见条/环：%s" % rect.name)
	# 后续任何动作请求被吸收（尸体常驻）；battle_ended 不清尸
	badge.play_action(UnitAnimState.Action.HIT)
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.DOWNED)
	var result: BattleResult = BattleResult.new()
	result.kind = BattleResult.ResultKind.VICTORY
	result.rounds_used = 1
	battle.controller.battle_ended.emit(result)
	await get_tree().process_frame
	assert_int(badge.current_action()).is_equal(UnitAnimState.Action.DOWNED)

func test_three_death_paths_unified_downed() -> void:
	## 三致倒路径（攻击/DOT/陷阱）统一经 unit_downed——动作层只消费该信号：
	## 同一 handler 连接一次，任一路径致死 emit 后恒 DOWNED（时序：HIT 先播、
	## DOWNED 后至——优先级吸收一切）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	# 统一消费契约：battle_screen 恰一订阅（BattleLog 另订——日志非动作层）
	var screen_subscribed: int = 0
	for connection: Dictionary in battle.controller.unit_downed.get_connections():
		var callable: Callable = connection["callable"] as Callable
		if callable.get_object() == battle:
			screen_subscribed += 1
	assert_int(screen_subscribed).is_equal(1)
	# 路径一：DOT 结算跳伤（round_settled）后致死
	var victim: BattleUnit = _AliveUnitOf(battle.context.enemies)
	_ResetBadge(_BadgeOf(battle, victim))
	battle.controller.round_settled.emit(1, [{&"unit": victim, &"damage": 999}])
	assert_int(_BadgeOf(battle, victim).current_action()).is_equal(UnitAnimState.Action.HIT)
	victim.take_damage(victim.current_hp)
	battle.controller.unit_downed.emit(victim)
	assert_bool(_BadgeOf(battle, victim).is_downed_pose()).is_true()
	# 路径二：陷阱致死（trap_triggered 存活 HIT → unit_downed 覆盖 DOWNED）
	var traped: BattleUnit = _AliveUnitOf(battle.context.allies)
	_ResetBadge(_BadgeOf(battle, traped))
	battle.controller.trap_triggered.emit(traped, 5)
	assert_int(_BadgeOf(battle, traped).current_action()).is_equal(UnitAnimState.Action.HIT)
	traped.take_damage(traped.current_hp)
	battle.controller.unit_downed.emit(traped)
	assert_int(_BadgeOf(battle, traped).current_action()).is_equal(UnitAnimState.Action.DOWNED)
	# 路径三（中3 盲审补位）：攻击致死链——真实 _execute_skill 实测（生产
	# 发射序：skill_executed 先发目标播 HIT → result.downed_units →
	# _mark_downed → unit_downed 后至覆盖 DOWNED；时序探针锁定两信号顺序）
	var attacker: BattleUnit = _AliveUnitOf(battle.context.allies)
	var slain: BattleUnit = _AliveUnitOf(battle.context.enemies)
	var cfg: CoreConfig = battle.context.cfg
	var clamp_min_backup: float = cfg.hit_clamp_min
	var clamp_max_backup: float = cfg.hit_clamp_max
	# 命中确定性：钳制带双注 1.0（hit_chance 恒 1.0——roll randf < 1 恒过，
	# 不依赖 rng 掷运）
	cfg.hit_clamp_min = 1.0
	cfg.hit_clamp_max = 1.0
	battle.context.grid.remove_unit(attacker.grid_pos)
	attacker.grid_pos = _AdjacentCellOf(battle, slain.grid_pos)
	battle.context.grid.place_unit(attacker.grid_pos, attacker)
	slain.take_damage(slain.current_hp - 1)
	var order: Array[String] = []
	battle.controller.skill_executed.connect(
			func(_c: BattleUnit, _r: SkillExecutor.ExecutionResult) -> void:
				order.append("skill"))
	battle.controller.unit_downed.connect(func(_u: BattleUnit) -> void:
		order.append("downed"))
	var result: SkillExecutor.ExecutionResult = battle.controller._execute_skill(
			attacker, &"skl_atk_warrior", slain.grid_pos)
	cfg.hit_clamp_min = clamp_min_backup
	cfg.hit_clamp_max = clamp_max_backup
	assert_object(result).is_not_null()
	assert_bool(result.success).is_true()
	assert_bool(result.downed_units.has(slain.unit_id)).is_true()
	assert_int(order.size()).is_equal(2)
	assert_str(order[0]).is_equal("skill")
	assert_str(order[1]).is_equal("downed") \
			.override_failure_message("攻击链信号时序异常（HIT 先播、DOWNED 后至）")
	var victim_badge: UnitBadge = _BadgeOf(battle, slain)
	assert_bool(victim_badge.is_downed_pose()).is_true()
	assert_int(victim_badge.current_action()).is_equal(UnitAnimState.Action.DOWNED)

func _AdjacentCellOf(battle: Control, center: Vector2i) -> Vector2i:
	## 取邻接可落格（攻击射程 1 贴身摆位用——界内可通行无存活占位优先）
	## 参数 battle：战斗屏根；center：目标格
	## 返回：邻接格（四向全堵的兜底回 center——不应发生）
	for delta: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)]:
		var cell: Vector2i = center + delta
		var tile: TileTypeDef = battle.context.grid.tile_at(cell)
		var occupant: Object = battle.context.grid.get_unit_at(cell)
		if tile != null and tile.walkable and occupant == null:
			return cell
	return center

func test_round_settled_dot_hit_skips_dead() -> void:
	## round_settled：存活承伤者 HIT；已倒地者不覆盖尸态（DOWNED 吸收）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var alive_one: BattleUnit = _AliveUnitOf(battle.context.allies)
	var dead_one: BattleUnit = _AliveUnitOf(battle.context.enemies)
	_ResetBadge(_BadgeOf(battle, alive_one))
	dead_one.take_damage(dead_one.current_hp)
	battle.controller.unit_downed.emit(dead_one)
	battle.controller.round_settled.emit(1, [
			{&"unit": alive_one, &"damage": 2},
			{&"unit": dead_one, &"damage": 2},
	])
	assert_int(_BadgeOf(battle, alive_one).current_action()).is_equal(UnitAnimState.Action.HIT)
	assert_int(_BadgeOf(battle, dead_one).current_action()).is_equal(UnitAnimState.Action.DOWNED)

func test_move_facing_updates_per_step() -> void:
	## 批次 A 用例①：逐格随步更新朝向——emit 后链首回调即刻按第一步定
	## 初始朝向（左行 → 面左），第二段竖直步迈入瞬间回正（x 相等 → 默认）；
	## 移动结束后保持最终朝向；直发口径摆安全起点（纯视觉层不校验格占用）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var cfg: CoreConfig = battle.context.cfg
	var original_step: float = cfg.ui_battle_move_step_seconds
	cfg.ui_battle_move_step_seconds = 0.3
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	var unit: BattleUnit = _AliveUnitOf(battle.context.enemies)
	# L 形路径：左行一步 + 竖直一步（两段相位不同——面左/回正各锚定一段）
	var from_pos: Vector2i = Vector2i(5, 5)
	var mid: Vector2i = from_pos + Vector2i(-1, 0)
	var to_pos: Vector2i = Vector2i(mid.x, mid.y - 1)
	unit.grid_pos = to_pos
	var badge: UnitBadge = _BadgeOf(battle, unit)
	# 预置残留默认态：确证链首回调真实改写（而非默认值巧合）
	board.set_badge_flip(unit, false)
	battle.controller.unit_moved.emit(unit, from_pos, to_pos, [mid, to_pos])
	await get_tree().process_frame
	assert_bool(_FlipHOf(badge)).is_true() \
			.override_failure_message("链首未按第一步（左行）即刻面左翻转")
	# 第一段（0.3s）完成、第二段竖直步已迈入（0.45s 采样点）：回正默认朝向
	await get_tree().create_timer(0.45).timeout
	assert_bool(_FlipHOf(badge)).is_false() \
			.override_failure_message("第二段竖直步迈入后未回正默认朝向")
	var waited: int = 0
	while board._move_tweens.has(unit.unit_id) and waited < 300:
		await get_tree().process_frame
		waited += 1
	cfg.ui_battle_move_step_seconds = original_step
	assert_bool(waited < 300).is_true().override_failure_message("移动 tween 未在帧限内完成")
	assert_bool(_FlipHOf(badge)).is_false() \
			.override_failure_message("移动结束后未保持最终朝向（竖直回正态）")

func test_move_facing_teleport_single_judgment() -> void:
	## 批次 A 用例②：瞬移（步长注 0）退化起终点一次判定——左移 → 面左；
	## 同列竖直移 → 回正默认（与攻击同列回正同口径）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var cfg: CoreConfig = battle.context.cfg
	var original_step: float = cfg.ui_battle_move_step_seconds
	cfg.ui_battle_move_step_seconds = 0.0
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	var unit: BattleUnit = _AliveUnitOf(battle.context.enemies)
	# 左移两格：起终点一次判定 → 面左
	var from_a: Vector2i = Vector2i(5, 5)
	var to_a: Vector2i = from_a + Vector2i(-2, 0)
	unit.grid_pos = to_a
	board.set_badge_flip(unit, false)
	battle.controller.unit_moved.emit(unit, from_a, to_a, [to_a])
	assert_bool(_FlipHOf(_BadgeOf(battle, unit))).is_true() \
			.override_failure_message("瞬移左移未按起终点判定面左")
	# 同列竖直移：x 相等 → 回正默认
	var from_b: Vector2i = to_a
	var to_b: Vector2i = Vector2i(from_b.x, from_b.y - 2)
	unit.grid_pos = to_b
	battle.controller.unit_moved.emit(unit, from_b, to_b, [to_b])
	assert_bool(_FlipHOf(_BadgeOf(battle, unit))).is_false() \
			.override_failure_message("瞬移同列移未回正默认朝向")
	cfg.ui_battle_move_step_seconds = original_step

func test_move_facing_no_displacement_keeps_flip() -> void:
	## 批次 A 用例③：无位移（起点==终点）不触发朝向判定——预置翻转维持原样
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	var unit: BattleUnit = _AliveUnitOf(battle.context.enemies)
	var stay: Vector2i = Vector2i(5, 5)
	unit.grid_pos = stay
	board.set_badge_flip(unit, true)
	battle.controller.unit_moved.emit(unit, stay, stay, [])
	assert_bool(_FlipHOf(_BadgeOf(battle, unit))).is_true() \
			.override_failure_message("无位移分支不应触碰朝向（预置翻转被改写）")

func test_move_facing_and_attack_facing_bidirectional() -> void:
	## 批次 A 用例④：移动与攻击朝向时序互相覆盖——移动→攻击（右移回正后
	## 攻击左侧目标再翻面）；攻击→移动（攻击翻面态下右移链首回调回正）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	battle.controller.abort_battle()
	var cfg: CoreConfig = battle.context.cfg
	var original_step: float = cfg.ui_battle_move_step_seconds
	cfg.ui_battle_move_step_seconds = 0.02
	var board: BattleBoard = battle.get_node("%BoardLayer") as BattleBoard
	var caster: BattleUnit = _AliveUnitOf(battle.context.allies)
	var target: BattleUnit = _AliveUnitOf(battle.context.enemies)
	caster.grid_pos = Vector2i(2, 4)
	var badge: UnitBadge = _BadgeOf(battle, caster)
	# —— 移动→攻击：预置翻面，右移链首回调回正；移动完成后攻击左侧目标再翻面
	board.set_badge_flip(caster, true)
	var from_a: Vector2i = caster.grid_pos
	var to_a: Vector2i = from_a + Vector2i(2, 0)
	caster.grid_pos = to_a
	battle.controller.unit_moved.emit(caster, from_a, to_a,
			[from_a + Vector2i(1, 0), to_a])
	await get_tree().process_frame
	assert_bool(_FlipHOf(badge)).is_false() \
			.override_failure_message("右移链首未回正（残留攻击翻面未覆盖）")
	var waited: int = 0
	while board._move_tweens.has(caster.unit_id) and waited < 300:
		await get_tree().process_frame
		waited += 1
	assert_bool(waited < 300).is_true().override_failure_message("移动 tween 未在帧限内完成")
	target.grid_pos = Vector2i(to_a.x - 2, to_a.y)
	battle._OnSkillExecuted(caster, _MakeResult(&"skl_atk_warrior",
			target.unit_id, true, 5))
	assert_bool(_FlipHOf(badge)).is_true() \
			.override_failure_message("攻击未覆盖移动朝向（左侧目标未翻面）")
	# —— 攻击→移动：翻面态下右移，链首回调回正
	var from_b: Vector2i = caster.grid_pos
	var to_b: Vector2i = from_b + Vector2i(2, 0)
	caster.grid_pos = to_b
	battle.controller.unit_moved.emit(caster, from_b, to_b,
			[from_b + Vector2i(1, 0), to_b])
	await get_tree().process_frame
	assert_bool(_FlipHOf(badge)).is_false() \
			.override_failure_message("移动未覆盖攻击朝向（右侧移动未回正）")
	var settle: int = 0
	while board._move_tweens.has(caster.unit_id) and settle < 300:
		await get_tree().process_frame
		settle += 1
	cfg.ui_battle_move_step_seconds = original_step
	assert_bool(settle < 300).is_true().override_failure_message("移动 tween 未在帧限内完成（攻击→移动）")

func test_turn_order_bar_uses_idle_first_frame_atlas() -> void:
	## 序条头像契约（×2 断言组）：重建后每条目 icon = AtlasTexture（idle 竖条
	## 首帧切片，region 128×128）——整竖条直显拦截；循环盲审修复②（一帧
	## 叠显，S4-R3-01 同式）：再次 rebuild（每回合初真实路径）——发起帧旧
	## 条目立即隐藏（queue_free 延迟帧末，修复前旧/新条目一帧叠渲、序条
	## 短暂双倍长度）；新条目计数正确
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	var bar: TurnOrderBar = battle.get_node("%TurnOrderBar") as TurnOrderBar
	assert_int(bar.get_child_count()).is_equal(7)
	for entry: PanelContainer in bar.get_children():
		var icon: TextureRect = entry.get_child(0).get_child(0) as TextureRect
		assert_object(icon.texture).is_not_null()
		var atlas: AtlasTexture = icon.texture as AtlasTexture
		assert_object(atlas).is_not_null()
		assert_int(int(atlas.region.size.x)).is_equal(SpriteResolver.ANIM_FRAME_SIZE)
		assert_int(int(atlas.region.position.y)).is_equal(0)
		assert_int(int(atlas.region.size.y)).is_equal(SpriteResolver.ANIM_FRAME_SIZE)
	# 重建契约：发起帧旧条目隐藏 + 新条目计数/可见正确
	var old_entries: Array[Node] = []
	for entry: Node in bar.get_children():
		old_entries.append(entry)
	bar.rebuild([battle.context.allies[0], battle.context.allies[1]])
	for old_entry: Node in old_entries:
		assert_bool(old_entry.is_queued_for_deletion()) \
				.override_failure_message("旧序条条目应已排队释放").is_true()
		var old_visual: CanvasItem = old_entry as CanvasItem
		if old_visual != null:
			assert_bool(old_visual.visible) \
					.override_failure_message("重建发起帧旧条目应立即隐藏（一帧叠显）").is_false()
	assert_int(bar._entries.size()).is_equal(2)
	for entry: PanelContainer in bar._entries.values():
		assert_bool(entry.visible) \
				.override_failure_message("重建后新条目应可见").is_true()
	battle.controller.abort_battle()
