## sprite 解析器（SpriteResolver，纯静态工具类）
## 职责：单位 sprite 的单源解析——单位 → sprite 资源 id（ClassDef/EnemyDef.
## sprite_id 查表）→ 纹理（GameData.get_asset_path → AssetRegistry → load，
## 进程级缓存）——批 4 C 组 H3：原 battle_board 与 turn_order_bar 各自复刻的
## _SpriteIdOf/_TextureOf 收敛到此一处，两 UI 改为薄转发。
## M6 批 1 扩动作帧解析口：动作件 id = <sprite_id>_<action>（六动作竖条
## PNG，宽 128/高 = 帧数×128），frame_atlas_of 出 AtlasTexture 单帧供
## TextureRect 直显（UnitBadge/序条头像消费）——静态单图口（texture_of 直查
## 单位 sprite_id）随静态图退役不再被单位链路消费（V-M6-anim-quad 锚定
## 六动作齐套）。
## 数据来源：批 A H3 表驱动口径（ClassDef/EnemyDef.sprite_id 入表；
## 查无回退空 id 走占位色块/空白头像）。
## 纯逻辑约束：不触 autoload 节点树——game_data 经参数注入（调用方持有引用）。
class_name SpriteResolver
extends RefCounted

## 动作竖条帧边长（像素——M6 规格单源：宽 128、高 = 帧数×128；
## DataValidator V-M6-anim-geometry 同引）
const ANIM_FRAME_SIZE: int = 128

## 六动作资产后缀（UnitAnimState.Action 枚举序一一对应：
## IDLE=0/MOVE=1/MELEE_ATTACK=2/CAST_RANGED=3/HIT=4/DOWNED=5）
const ANIM_ACTIONS: Array[StringName] = [
	&"idle",
	&"move",
	&"melee_attack",
	&"cast_ranged",
	&"hit",
	&"downed",
]

## sprite 纹理进程级缓存（sprite id -> Texture2D；null = 已知缺登记——
## 缓存穿透防止每帧重复查 registry）
static var _texture_cache: Dictionary = {}

## 单帧 AtlasTexture 进程级缓存（"<动作件 id>#<帧下标>" -> AtlasTexture）
static var _atlas_cache: Dictionary = {}

static func sprite_id_of(unit: BattleUnit, game_data: Node) -> StringName:
	## 单位 → sprite 资源 id：我方查 ClassDef.sprite_id、敌方查 EnemyDef.
	## sprite_id（H3 表驱动）；查无/game_data 缺失回退空 id（调用方走占位色块）
	## 参数 unit：单位；game_data：GameData（get_record 查表）
	## 返回：sprite id（spr_cls_* / spr_en_*；空 = 无表登记）
	if game_data == null:
		return &""
	if unit.side == SkillDef.SkillSide.ALLY:
		var cls: ClassDef = game_data.get_record(unit.class_id) as ClassDef
		return cls.sprite_id if cls != null else &""
	var enemy: EnemyDef = game_data.get_record(unit.enemy_id) as EnemyDef
	return enemy.sprite_id if enemy != null else &""

static func texture_of(sprite_id: StringName, game_data: Node) -> Texture2D:
	## sprite id → 纹理：缓存命中直取；否则经 game_data.get_asset_path
	## （AssetRegistry 路径映射）load；空 id/缺登记回退 null（占位色块）
	## 参数 sprite_id：资源 id；game_data：GameData（registry 取路径）
	## 返回：Texture2D；未登记返回 null
	if _texture_cache.has(sprite_id):
		return _texture_cache[sprite_id]
	var texture: Texture2D = null
	if game_data != null and not String(sprite_id).is_empty():
		var path: String = game_data.get_asset_path(sprite_id)
		if not path.is_empty():
			texture = load(path) as Texture2D
	_texture_cache[sprite_id] = texture
	return texture

static func clear_cache() -> void:
	## 清空纹理与单帧 atlas 缓存（测试隔离口——表热重载后防止旧纹理驻留）
	## 参数：无
	## 返回：无
	_texture_cache = {}
	_atlas_cache = {}

static func anim_id_of(sprite_id: StringName, action: int) -> StringName:
	## 单位 sprite id + 动作 → 动作件资源 id（<sprite_id>_<action>）
	## 参数 sprite_id：单位 sprite id（spr_*）；action：UnitAnimState.Action
	## 返回：动作件 id（空 sprite_id 回退空 id）
	if String(sprite_id).is_empty() or action < 0 or action >= ANIM_ACTIONS.size():
		return &""
	return StringName(String(sprite_id) + "_" + String(ANIM_ACTIONS[action]))

static func anim_texture_of(sprite_id: StringName, action: int,
		game_data: Node) -> Texture2D:
	## 动作件竖条纹理解析（M6 批 1：动作件 id → registry → load；
	## 竖条整图（宽 128/高 = 帧数×128）——帧切片经 frame_atlas_of）
	## 参数 sprite_id：单位 sprite id；action：UnitAnimState.Action；
	## game_data：GameData（registry 取路径）
	## 返回：竖条 Texture2D；未登记/加载失败返回 null
	return texture_of(anim_id_of(sprite_id, action), game_data)

static func frame_atlas_of(sprite_id: StringName, action: int, frame_index: int,
		game_data: Node) -> AtlasTexture:
	## 动作件单帧 AtlasTexture 解析（M6 批 1）：竖条按帧下标切片（region =
	## (0, 帧×128, 128, 128)）；帧下标越界钳制到 [0, 帧数-1]（防御竖条
	## 高度不足/下标溢出的坏资源）；缓存命中直取
	## 参数 sprite_id：单位 sprite id；action：UnitAnimState.Action；
	## frame_index：帧下标；game_data：GameData
	## 返回：单帧 AtlasTexture；竖条缺登记返回 null
	var strip: Texture2D = anim_texture_of(sprite_id, action, game_data)
	if strip == null:
		return null
	var frame_count: int = frame_count_of(strip)
	if frame_count <= 0:
		# 低11（盲审）：不足一帧（高 < 128）——整条哑火推运行时警告（生产面
		# 由 V-M6-anim-geometry 落盘拦截，此处兜运行时坏资源/热更漏检）
		push_warning("SpriteResolver: 竖条 '%s' 高 %d 不足一帧（%d/帧）——帧切片哑火返回 null" % [
				anim_id_of(sprite_id, action), strip.get_height(), ANIM_FRAME_SIZE])
		return null
	var clamped: int = clampi(frame_index, 0, frame_count - 1)
	var cache_key: String = "%s#%d" % [anim_id_of(sprite_id, action), clamped]
	if _atlas_cache.has(cache_key):
		return _atlas_cache[cache_key] as AtlasTexture
	var atlas := AtlasTexture.new()
	atlas.atlas = strip
	atlas.region = Rect2(0.0, float(clamped * ANIM_FRAME_SIZE),
			float(ANIM_FRAME_SIZE), float(ANIM_FRAME_SIZE))
	_atlas_cache[cache_key] = atlas
	return atlas

static func frame_count_of(strip: Texture2D) -> int:
	## 竖条帧数推导（图高 ÷ 帧边长；M6 规格：高 = 帧数×128）；非整倍高
	## 推运行时警告（低11 盲审：静默截断防御日志——生产面由 V-M6-anim-geometry
	## 落盘拦截，此处兜运行时坏资源/热更漏检）
	## 参数 strip：竖条纹理
	## 返回：帧数（< 1 = 非法/零高）
	if strip == null:
		return 0
	var height: int = strip.get_height()
	if height % ANIM_FRAME_SIZE != 0:
		push_warning("SpriteResolver: 竖条高 %d 非 %d 整倍——帧数截断为 %d（余 %dpx 丢弃）" % [
				height, ANIM_FRAME_SIZE, height / ANIM_FRAME_SIZE,
				height % ANIM_FRAME_SIZE])
	return height / ANIM_FRAME_SIZE
