## sprite 解析器（SpriteResolver，纯静态工具类）
## 职责：单位 sprite 的单源解析——单位 → sprite 资源 id（ClassDef/EnemyDef.
## sprite_id 查表）→ 纹理（GameData.get_asset_path → AssetRegistry → load，
## 进程级缓存）——批 4 C 组 H3：原 battle_board 与 turn_order_bar 各自复刻的
## _SpriteIdOf/_TextureOf 收敛到此一处，两 UI 改为薄转发。
## 数据来源：批 A H3 表驱动口径（ClassDef/EnemyDef.sprite_id 入表；
## 查无回退空 id 走占位色块/空白头像）。
## 纯逻辑约束：不触 autoload 节点树——game_data 经参数注入（调用方持有引用）。
class_name SpriteResolver
extends RefCounted

## sprite 纹理进程级缓存（sprite id -> Texture2D；null = 已知缺登记——
## 缓存穿透防止每帧重复查 registry）
static var _texture_cache: Dictionary = {}

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
	## 清空纹理缓存（测试隔离口——表热重载后防止旧纹理驻留）
	## 参数：无
	## 返回：无
	_texture_cache = {}
