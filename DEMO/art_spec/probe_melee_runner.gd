## 临时诊断探针 v2：战士 melee 末帧可见性硬取证（用后删，不入库）
## 升级点：badge global_position 坐标锚定截图 / 命中钳制 1.0 排除 MISS /
## 敌方移动贴身（战士零移动 tween——v1 的外部 IDLE 回调干扰源排除）/
## 逐帧抓 badge 区域 + 墙钟停留统计（连续 tick cur=MELEE frame=1 ≥ 1/fps）
extends Node

const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")
const PARTY: Array = [
	[&"warrior", &"cls_warrior"],
	[&"ranger", &"cls_ranger"],
	[&"mage", &"cls_mage"],
	[&"priest", &"cls_priest"],
]

const LOG_PATH: String = "res://art_spec/probe_log.txt"

var _battle: Control = null
var _ctx: Variant = null
var _controller: Variant = null
var _shot_no: int = 0
var _phase: int = 0
var _waited: int = 0
var _last_delta: float = 0.0
var _melee_wall_start: int = -1   # 末帧落位墙钟（ms）
var _last_frame_seen: int = -1
var _warrior_id: StringName = &"warrior"

func _P(msg: String) -> void:
	## 探针日志直写文件 + print
	var f: FileAccess = FileAccess.open(LOG_PATH,
			FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE_READ)
	if f != null:
		f.seek_end()
		f.store_line(msg)
		f.close()
	print(msg)

func _ready() -> void:
	get_tree().root.title = "probe-melee-anim-v2"
	DirAccess.make_dir_recursive_absolute("res://art_spec/probe_melee/")
	var clear: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if clear != null:
		clear.close()
	_P("[PROBE] runner v2 _ready")
	_Startup()

func _Startup() -> void:
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
	get_tree().root.get_node("SceneManager").go(
			SceneManagerScript.SceneId.BATTLE_SCREEN, {&"battle_params": params})

func _process(delta: float) -> void:
	_last_delta = delta
	_waited += 1
	if _phase == 0:
		_battle = get_tree().root.find_child("BattleScreen", true, false) as Control
		if _battle != null and _battle.context != null:
			_ctx = _battle.context
			_controller = _battle.controller
			_P("[PROBE] 战斗装配成立 tick=%d" % _waited)
			_phase = 1
			_waited = 0
		elif _waited > 600:
			_P("[PROBE] 装配超时——退出")
			get_tree().quit(3)
		return
	if _phase == 1:
		if _waited < 40:
			return
		var warrior: BattleUnit = _UnitOf(&"warrior")
		var enemy: BattleUnit = _FirstEnemy()
		if warrior == null or enemy == null:
			_P("[PROBE] 缺单位——退出")
			get_tree().quit(3)
			return
		# 命中钳制 1.0（排除掷骰 MISS 干扰——v1 某次 run hit=false 的来源）
		var cfg: CoreConfig = _ctx.cfg as CoreConfig
		cfg.hit_clamp_min = 1.0
		cfg.hit_clamp_max = 1.0
		warrior.current_stamina = warrior.max_stamina
		# 敌方移动贴战士（战士零移动 tween——外部 IDLE 回调打在敌人 badge 上，
		# 战士动画链路无干扰；v1 的 _move_unit(warrior) 是吞帧复现源）
		var adj: Vector2i = warrior.grid_pos + Vector2i(0, -1)
		_controller._move_unit(enemy, adj)
		_P("[PROBE] 敌 %s(%s) 移动贴战士 →(%d,%d)；战士原地 @(x=%d,y=%d)" % [
				enemy.display_name, enemy.unit_id, adj.x, adj.y,
				warrior.grid_pos.x, warrior.grid_pos.y])
		var badge: UnitBadge = _BadgeOf(warrior)
		_P("[PROBE] 战士 badge global_position=%s size=%s（内容坐标）" % [
				badge.global_position, badge.size])
		_P("[PROBE] >>> 直调痛击（钳制必中）→ %s @(%d,%d)" % [
				enemy.display_name, enemy.grid_pos.x, enemy.grid_pos.y])
		var result: SkillExecutor.ExecutionResult = _controller._execute_skill(
				warrior, &"skl_warrior_power_strike", enemy.grid_pos)
		_P("[PROBE] 执行返回 hit=%s damage=%d（钳制下应 hit=true）" % [
				result.hit, result.damage])
		_PrintBadge("痛击后即刻(同帧)", warrior)
		_phase = 2
		_waited = 0
		return
	# phase 2：逐帧观测 45 帧（每帧打印 + badge 区域抓屏）
	if _waited <= 45:
		var w: BattleUnit = _UnitOf(&"warrior")
		var b: UnitBadge = _BadgeOf(w)
		if b != null:
			var atlas: AtlasTexture = b.get("_anim_atlas") as AtlasTexture
			var cur: int = b.anim.current as int
			var frame: int = b.anim.frame_index
			var hold_ms: int = 0
			if _melee_wall_start >= 0:
				hold_ms = Time.get_ticks_msec() - _melee_wall_start
			# 末帧落位墙钟锚定（首次见到 MELEE frame=1）
			if cur == UnitAnimState.Action.MELEE_ATTACK and frame == 1 \
					and _melee_wall_start < 0:
				_melee_wall_start = Time.get_ticks_msec()
			_P("[PROBE][t+%d] dt=%.4f cur=%d frame=%d/%d region_y=%.0f last=%d 末帧停留=%dms" % [
					_waited, _last_delta, cur, frame, b.anim.frame_count,
					atlas.region.position.y if atlas != null else -1.0,
					int(b.get("_last_frame_index")),
					Time.get_ticks_msec() - _melee_wall_start if _melee_wall_start >= 0 else -1])
			_ShotBadge("t%02d_c%d_f%d" % [_waited, cur, frame], b)
	elif _waited == 46:
		var b2: UnitBadge = _BadgeOf(_UnitOf(&"warrior"))
		if _melee_wall_start >= 0:
			_P("[PROBE] 末帧落位后 MELEE 态维持墙钟统计：见日志（应 ≥ 125ms @8fps）")
		_PrintBadge("收尾态", _UnitOf(&"warrior"))
		_P("[PROBE] 完成——退出")
		get_tree().quit(0)

func _PrintBadge(tag: String, unit: BattleUnit) -> void:
	## 打印战士 badge 动画链路内部状态
	var badge: UnitBadge = _BadgeOf(unit)
	if badge == null:
		_P("[PROBE][%s] badge 缺失" % tag)
		return
	var atlas: AtlasTexture = badge.get("_anim_atlas") as AtlasTexture
	var region_txt: String = "atlas=null"
	if atlas != null:
		region_txt = "region_y=%.0f atlas=%dx%d" % [
				atlas.region.position.y,
				atlas.atlas.get_width() if atlas.atlas != null else 0,
				atlas.atlas.get_height() if atlas.atlas != null else 0]
	_P("[PROBE][%s] cur=%d frame=%d/%d | %s | global=%s" % [
			tag, badge.anim.current as int, badge.anim.frame_index,
			badge.anim.frame_count, region_txt, badge.global_position])

func _ShotBadge(tag: String, badge: UnitBadge) -> void:
	## sprite 坐标锚定截图：badge 锚定全板（size=整板——不可作裁剪框），裁
	## badge 内 _sprite（64×64 TextureRect）global 区域 + 血条外扩，坐标来源
	## 即 sprite 本体，不猜区域；内容坐标 → 截图像素按视口比例换算
	_shot_no += 1
	var sprite: TextureRect = badge.get("_sprite") as TextureRect
	if sprite == null:
		return
	var img: Image = get_viewport().get_texture().get_image()
	var content: Vector2 = get_viewport().get_visible_rect().size
	if content.x <= 0.0 or img.get_width() <= 0:
		return
	var scale: Vector2 = Vector2(img.get_width() / content.x, img.get_height() / content.y)
	var pos: Vector2 = sprite.global_position * scale - Vector2(6.0 * scale.x, 12.0 * scale.y)
	var size: Vector2 = sprite.size * scale + Vector2(12.0 * scale.x, 20.0 * scale.y)
	var rect: Rect2i = Rect2i(Vector2i(pos), Vector2i(size))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if not rect.has_area():
		return
	var crop: Image = img.get_region(rect)
	crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png("res://art_spec/probe_melee/%02d_%s.png" % [_shot_no, tag])

func _BadgeOf(unit: BattleUnit) -> UnitBadge:
	var board: BattleBoard = _battle.get_node("%BoardLayer") as BattleBoard
	for child: Node in board.get_children():
		if child is UnitBadge and (child as UnitBadge).unit == unit:
			return child as UnitBadge
	return null

func _UnitOf(unit_id: StringName) -> BattleUnit:
	for unit: BattleUnit in _ctx.allies:
		if unit.unit_id == unit_id and unit.alive:
			return unit
	return null

func _FirstEnemy() -> BattleUnit:
	for unit: BattleUnit in _ctx.enemies:
		if unit.alive and unit.role_tag != UnitTags.ROLE_ELITE:
			return unit
	return null
