## 战斗屏顶部横条集成测试（顶部横条批：LeftPanel 退役、回合 UI+行动序
## 上移顶部横条、信息卡改点选浮层）
## 覆盖：横条几何契约（总高 68 单源 / MarginBox 四边距 / 右预留 174）、
## cfg 值域外回退（margin −1 / alpha 0 / 预留 100 → UiTheme 兜底）、
## 行动序降级护栏（>10 切紧凑条目 52×44 无速度子节点、8↔11 交替 rebuild
## 无残留、8 条目常规 92×44 全卡）、topbar_total_height 纯函数（cfg null/
## 未回填 → 68）、四消费点单源联动（margin_top 改 20 → 横条底 76/板顶 76/
## IdleLabel 顶 84/卷轴展开顶 84 一次断言）、信息卡浮层时序（B 案点选驱动：
## turn_started 不弹 / 点单位显 / 点空收 / 终局收 / status_changed 条件刷新）。
## 环境口径：scene_runner 直开走无参降级路径（横条在位兜底常量布局）；
## cfg 注入经 apply_cfg（cfg_main 实例临时改键、用后还原——log_scroller
## 套件同式）；时序用例经 _EnterRandomBattle 真实装配（anim_flow 同式）。
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

func _Cfg() -> CoreConfig:
	## cfg_main 实例读取（共享资源——改键用后由调用方还原）
	## 参数：无
	## 返回：CoreConfig
	return load("res://data/core/cfg_main.tres") as CoreConfig

func _MakeUnits(count: int) -> Array:
	## 手造测试单位（rebuild 消费面：unit_id/display_name/alive——speed_
	## for_order 未 bind 走兜底 0，尺寸契约与速度值无关）
	## 参数 count：单位数
	## 返回：BattleUnit 数组
	var units: Array = []
	for i: int in range(count):
		var unit := BattleUnit.new()
		unit.unit_id = StringName("topbar_probe_%d" % i)
		unit.display_name = "横条探针%d" % i
		unit.alive = true
		units.append(unit)
	return units

func test_topbar_geometry_contract() -> void:
	## 用例①：横条几何契约——降级直开兜底态总高 68（offset_bottom 与实测
	## size.y 双断言）、MarginBox 四边距 = 兜底值（cfg_main 表值同值——
	## apply_cfg 注入后不变）；1440/720 两档根尺寸总高恒 68（横条高与窗口
	## 无关——全锚下 resize 只变宽）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var topbar: BattleTopBar = battle.get_node("%TopBar") as BattleTopBar
	var margin_box: MarginContainer = battle.get_node("TopBar/MarginBox") as MarginContainer
	assert_float(topbar.offset_bottom).is_equal(UiTheme.topbar_total_height(null))
	assert_float(topbar.offset_bottom).is_equal(68.0)
	assert_int(margin_box.get_theme_constant("margin_top")).is_equal(int(UiTheme.TOPBAR_MARGIN_TOP))
	assert_int(margin_box.get_theme_constant("margin_bottom")).is_equal(int(UiTheme.TOPBAR_MARGIN_BOTTOM))
	assert_int(margin_box.get_theme_constant("margin_left")).is_equal(int(UiTheme.TOPBAR_LEFT_MARGIN))
	assert_int(margin_box.get_theme_constant("margin_right")).is_equal(int(UiTheme.TOPBAR_RIGHT_RESERVE))
	# cfg 注入（表值 == 兜底）后几何不变
	topbar.apply_cfg(_Cfg())
	assert_float(topbar.offset_bottom).is_equal(68.0)
	assert_float(topbar.total_height()).is_equal(68.0)
	# 两档根尺寸实测总高恒 68
	for root_size: Vector2 in [Vector2(1440.0, 900.0), Vector2(1280.0, 720.0)]:
		battle.size = root_size
		await get_tree().process_frame
		await get_tree().process_frame
		assert_float(topbar.size.y).is_equal(68.0) \
				.override_failure_message("根尺寸 %s 下横条实测高 %s 应恒 68" % [
						root_size, topbar.size.y])

func test_topbar_invalid_cfg_falls_back() -> void:
	## 用例②：cfg 值域外回退——margin −1（越 [0,32] 下界）/ alpha 0（未回填
	## 哨兵）/ 预留 100（越 [120,280] 下界）→ UiTheme 兜底（读取口单键断言
	## + 几何整体回 68）
	var topbar: BattleTopBar = auto_free(BattleTopBar.new())
	add_child(topbar)
	var cfg: CoreConfig = auto_free(CoreConfig.new())
	cfg.ui_battle_topbar_margin_top = -1.0
	cfg.ui_battle_topbar_margin_bottom = 40.0
	cfg.ui_battle_topbar_left_margin = -5.0
	cfg.ui_battle_topbar_right_reserve = 100.0
	cfg.ui_battle_topbar_bg_alpha = 0.0
	topbar.apply_cfg(cfg)
	assert_float(topbar._LeftMargin()).is_equal(UiTheme.TOPBAR_LEFT_MARGIN)
	assert_float(topbar._RightReserve()).is_equal(UiTheme.TOPBAR_RIGHT_RESERVE)
	assert_float(topbar._BgAlpha()).is_equal(UiTheme.TOPBAR_BG_ALPHA)
	assert_float(UiTheme.topbar_margin_top_of(cfg)).is_equal(UiTheme.TOPBAR_MARGIN_TOP)
	assert_float(UiTheme.topbar_margin_bottom_of(cfg)).is_equal(UiTheme.TOPBAR_MARGIN_BOTTOM)
	assert_float(topbar.total_height()).is_equal(68.0) \
			.override_failure_message("非法 margin 组合应回退兜底总高 68（实际 %s）" % str(topbar.total_height()))

func test_turn_order_degrade_guard() -> void:
	## 用例③：行动序降级护栏——rebuild 11 单位（> 阈值 10）→ 紧凑条目
	## 52×44、box 仅 icon 无 speed 子节点、combined min ≤ 可用宽；rebuild 8
	## → 常规条目 92×44 全卡（icon+speed）；8↔11 交替 rebuild 无残留
	##（重建式组件——每次 rebuild 全量重判）
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var order_bar: TurnOrderBar = battle.get_node("%TurnOrderBar") as TurnOrderBar
	order_bar.setup(null, _Cfg())
	battle.size = Vector2(1280.0, 720.0)
	# 11 单位 → 降级紧凑条目
	order_bar.rebuild(_MakeUnits(11))
	await get_tree().process_frame
	assert_int(order_bar.get_child_count()).is_equal(11)
	var available: float = 1280.0 - UiTheme.TOPBAR_LEFT_MARGIN - UiTheme.TOPBAR_RIGHT_RESERVE
	assert_float(order_bar.get_combined_minimum_size().x).is_less_equal(available) \
			.override_failure_message("11 条目紧凑态 combined min %s 超可用宽 %s" % [
					order_bar.get_combined_minimum_size().x, available])
	for entry: Node in order_bar.get_children():
		var panel: PanelContainer = entry as PanelContainer
		assert_vector(panel.custom_minimum_size).is_equal(Vector2(52.0, 44.0)) \
				.override_failure_message("紧凑条目应为 52×44（实际 %s）" % panel.custom_minimum_size)
		assert_int(panel.get_child(0).get_child_count()).is_equal(1) \
				.override_failure_message("紧凑条目 box 应仅 icon 无 speed 子节点")
	# 8 单位 → 常规全卡（icon+speed）
	order_bar.rebuild(_MakeUnits(8))
	await get_tree().process_frame
	assert_int(order_bar.get_child_count()).is_equal(8)
	for entry: Node in order_bar.get_children():
		var panel: PanelContainer = entry as PanelContainer
		assert_vector(panel.custom_minimum_size).is_equal(
				Vector2(TurnOrderBar.ENTRY_WIDTH, UiTheme.TOPBAR_ENTRY_HEIGHT)) \
				.override_failure_message("常规条目应为 92×44（实际 %s）" % panel.custom_minimum_size)
		assert_int(panel.get_child(0).get_child_count()).is_equal(2) \
				.override_failure_message("常规条目 box 应含 icon+speed 两子节点")
	# 交替重判无残留（11 紧凑 → 8 常规 → 11 紧凑，末态每条目恰一子）
	order_bar.rebuild(_MakeUnits(11))
	await get_tree().process_frame
	assert_int(order_bar.get_child_count()).is_equal(11)
	for entry: Node in order_bar.get_children():
		assert_int((entry as PanelContainer).get_child(0).get_child_count()).is_equal(1)

func test_topbar_total_height_pure_function() -> void:
	## 用例④：topbar_total_height 纯函数——cfg null / 未回填（0 哨兵）→
	## 兜底 68；合法表值按 margin 两键线性（20+44+12=76 / 12+44+30=86）；
	## 越界值回退兜底
	assert_float(UiTheme.topbar_total_height(null)).is_equal(68.0)
	var empty_cfg: CoreConfig = auto_free(CoreConfig.new())
	assert_float(UiTheme.topbar_total_height(empty_cfg)).is_equal(68.0) \
			.override_failure_message("未回填哨兵应回退兜底 68")
	var cfg: CoreConfig = auto_free(CoreConfig.new())
	cfg.ui_battle_topbar_margin_top = 20.0
	cfg.ui_battle_topbar_margin_bottom = 12.0
	assert_float(UiTheme.topbar_total_height(cfg)).is_equal(76.0)
	cfg.ui_battle_topbar_margin_top = 12.0
	cfg.ui_battle_topbar_margin_bottom = 30.0
	assert_float(UiTheme.topbar_total_height(cfg)).is_equal(86.0)
	cfg.ui_battle_topbar_margin_bottom = 64.0
	assert_float(UiTheme.topbar_total_height(cfg)).is_equal(68.0) \
			.override_failure_message("margin 越界（64 > 32）应回退兜底 68")

func test_four_consumers_single_source_linkage() -> void:
	## 用例⑤：四消费点单源联动——cfg margin_top 改 20（总高 76）一次断言
	## 四处：TopBar offset_bottom 76 / BoardLayer offset_top 76 / IdleLabel
	## offset_top 84（76+8）/ LogScroller 展开顶 144（76+12+48+8——范围修复
	## 批展开顶改锚点下缘基准）；还原后四处回默认
	var runner: GdUnitSceneRunner = scene_runner(BATTLE_SCENE)
	var battle: Control = runner.scene() as Control
	var cfg: CoreConfig = _Cfg()
	var original_top: float = cfg.ui_battle_topbar_margin_top
	var topbar: BattleTopBar = battle.get_node("%TopBar") as BattleTopBar
	var scroller: BattleLogScroller = battle.get_node("%LogScroller") as BattleLogScroller
	var expand_panel: PanelContainer = battle.get_node("%ExpandPanel") as PanelContainer
	cfg.ui_battle_topbar_margin_top = 20.0
	topbar.apply_cfg(cfg)
	scroller.apply_cfg(cfg, null)
	battle._ApplyTopBarGeometry()
	await get_tree().process_frame
	assert_float(topbar.offset_bottom).is_equal(76.0) \
			.override_failure_message("消费点① TopBar 底应 76")
	assert_float(battle.get_node("%BoardLayer").offset_top).is_equal(76.0) \
			.override_failure_message("消费点② 板区顶应 76")
	assert_float(battle.get_node("%IdleLabel").offset_top).is_equal(84.0) \
			.override_failure_message("消费点③ IdleLabel 顶应 76+8=84")
	assert_float(expand_panel.offset_top).is_equal(144.0) \
			.override_failure_message("消费点④ 卷轴展开顶应 76+12+48+8=144")
	# 还原后四处回默认
	cfg.ui_battle_topbar_margin_top = original_top
	topbar.apply_cfg(cfg)
	scroller.apply_cfg(cfg, null)
	battle._ApplyTopBarGeometry()
	await get_tree().process_frame
	assert_float(topbar.offset_bottom).is_equal(68.0)
	assert_float(battle.get_node("%BoardLayer").offset_top).is_equal(68.0)
	assert_float(battle.get_node("%IdleLabel").offset_top).is_equal(76.0)
	assert_float(expand_panel.offset_top).is_equal(136.0)

func _EnterRandomBattle() -> Control:
	## 直构 BattleParams（默认 4 职业）进 BATTLE_SCREEN 并等挂载
	##（anim_flow _EnterRandomBattle 同式）
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

func test_info_card_overlay_timing_point_driven() -> void:
	## 用例⑥：信息卡浮层时序（B 案点选驱动）——真实装配进战斗：turn_started
	## 不弹卡（横条金色高亮已示当前位）；点单位格（_HandleMoveTap occupant
	## 分支）显卡；点不可达空格（收起点②）收卡；技能纯空取消（收起点③）收卡
	## +技能选择态清空；出格点按（收起点①）收卡；再显后终局（收起点④）收卡；
	## status_changed 条件刷新（未看不弹、正在看才刷新）；unit_downed 条件
	## 刷新（看 A 时 B 倒地不抢卡）；设计动机锁定——确认移动成功后卡维持
	## 展示（hide_card 绝不进 _ClearSelection，防「查看后确认移动卡闪没」
	## 回归无红灯——三席盲审 T1-3 补段）
	var battle: Control = await _EnterRandomBattle()
	assert_object(battle).is_not_null()
	battle.controller.delay_seconds = 0.0
	# 等玩家指令窗（首个我方单位轮——turn_started 已发：B 案不弹卡）
	var settle: int = 0
	while not battle.controller.awaiting_command and settle < 600:
		await get_tree().process_frame
		settle += 1
	assert_bool(battle.controller.awaiting_command).is_true() \
			.override_failure_message("帧限内未进入玩家指令窗")
	var card: UnitInfoCard = battle.get_node("%UnitInfoCard") as UnitInfoCard
	assert_bool(card.visible).is_false() \
			.override_failure_message("turn_started 不应弹卡（B 案点选驱动）")
	# status_changed：未在看该单位 → 不弹
	var viewer: BattleUnit = battle.context.units[0]
	battle.controller.status_changed.emit(viewer, &"DEBUFF_poison")
	assert_bool(card.visible).is_false() \
			.override_failure_message("未在看时 status_changed 不应弹卡")
	# 点单位格显卡（occupant 分支——生产路径 _HandleMoveTap）
	battle._HandleMoveTap(viewer.grid_pos)
	assert_bool(card.visible).is_true() \
			.override_failure_message("点单位格应显卡（occupant 分支）")
	assert_bool(card.is_showing_unit(viewer.unit_id)).is_true()
	# status_changed：正在看 → 条件刷新（维持展示该单位）
	battle.controller.status_changed.emit(viewer, &"DEBUFF_poison")
	assert_bool(card.is_showing_unit(viewer.unit_id)).is_true() \
			.override_failure_message("正在看时 status_changed 应刷新维持展示")
	# unit_downed：看 A 时他单位倒地不抢卡（条件刷新不强制弹）
	var other: BattleUnit = null
	for unit: BattleUnit in battle.context.units:
		if unit != viewer and unit.alive:
			other = unit
			break
	if other != null:
		battle.controller.unit_downed.emit(other)
		assert_bool(card.is_showing_unit(viewer.unit_id)).is_true() \
				.override_failure_message("他单位倒地不应抢占正在看的卡")
	# 点不可达空格收卡（收起点②——寻一既无单位又不可达格）
	var hider_cell: Vector2i = Vector2i(-9, -9)
	var reachable: Array[Vector2i] = battle.context.grid.find_reachable(
			battle.controller.current_unit, battle.controller.current_unit.move_final())
	for y: int in battle.context.grid.size.y:
		for x: int in battle.context.grid.size.x:
			var probe: Vector2i = Vector2i(x, y)
			if not reachable.has(probe) \
					and battle.context.grid.get_unit_at(probe) == null:
				hider_cell = probe
				break
		if hider_cell != Vector2i(-9, -9):
			break
	assert_bool(hider_cell != Vector2i(-9, -9)).is_true() \
			.override_failure_message("未找到不可达空格（夹具失效）")
	battle._HandleMoveTap(hider_cell)
	assert_bool(card.visible).is_false() \
			.override_failure_message("点不可达空格应收卡（收起点②）")
	# 技能纯空取消收卡（收起点③）：再显卡 → 进技能模式 → 纯空格
	## _HandleSkillTap → 收卡 + 技能选择态清空
	battle._HandleMoveTap(viewer.grid_pos)
	assert_bool(card.visible).is_true()
	battle._EnterSkillMode(battle.controller.current_unit.base_attack_id)
	assert_bool(battle._selected_skill_id != &"").is_true() \
			.override_failure_message("夹具失效：技能模式未进入")
	battle._HandleSkillTap(hider_cell)
	assert_bool(card.visible).is_false() \
			.override_failure_message("技能纯空取消应收卡（收起点③）")
	assert_str(String(battle._selected_skill_id)).is_equal("") \
			.override_failure_message("技能纯空取消应清技能选择态")
	# 出格点按收卡（收起点①）：再显卡 → 板区非格区左键（cell (-1,-1)）
	## → 收卡
	battle._HandleMoveTap(viewer.grid_pos)
	assert_bool(card.visible).is_true()
	var outside_event := InputEventMouseButton.new()
	outside_event.button_index = MOUSE_BUTTON_LEFT
	outside_event.pressed = true
	outside_event.position = Vector2(-64.0, -64.0)
	battle._on_board_gui_input(outside_event)
	assert_bool(card.visible).is_false() \
			.override_failure_message("出格点按应收卡（收起点①）")
	# 设计动机锁定（T1-3）：hide_card 绝不进 _ClearSelection——点单位显卡 →
	## 可达格两点确认移动成功 → 卡维持展示（确认移动路径 _ClearSelection
	## 不得连带收卡——「查看后确认移动卡闪没」竞态防回归红灯）
	battle._HandleMoveTap(viewer.grid_pos)
	assert_bool(card.visible).is_true()
	var mover: BattleUnit = battle.controller.current_unit
	var mover_reachable: Array[Vector2i] = battle.context.grid.find_reachable(
			mover, mover.move_final())
	var target_cell: Vector2i = Vector2i(-9, -9)
	for probe: Vector2i in mover_reachable:
		if probe != mover.grid_pos:
			target_cell = probe
			break
	assert_bool(target_cell != Vector2i(-9, -9)).is_true() \
			.override_failure_message("夹具失效：无可移动格")
	battle._HandleMoveTap(target_cell)
	battle._HandleMoveTap(target_cell)
	assert_bool(mover.has_moved).is_true() \
			.override_failure_message("夹具失效：两点确认移动未执行")
	assert_bool(card.visible).is_true() \
			.override_failure_message("确认移动后卡应维持展示（hide_card 不得进 _ClearSelection）")
	# 终局收卡（收起点④）
	battle._OnBattleEnded(BattleResult.new())
	assert_bool(card.visible).is_false() \
			.override_failure_message("终局应收卡（收起点④）")
	battle.controller.abort_battle()
