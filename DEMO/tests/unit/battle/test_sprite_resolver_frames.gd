## SpriteResolver 动作帧解析单元测试（M6 批 1）
## 覆盖：动作件 id 组装 / 竖条纹理解析 / 首帧 AtlasTexture region / 越界钳 /
## 缓存一致性 / clear_cache 隔离 / 帧数推导——消费真实生成的占位竖条资产
##（GameData 实例化 + registry 查路径，headless 加载已导入 PNG）。
extends GdUnitTestSuite

## GameData 脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 实例
var _game_data: Node

func before() -> void:
	## 套件前置：实例化 GameData 并显式初始化
	## 参数：无
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

func before_test() -> void:
	## 用例前置：清解析缓存（null 缓存穿透口径——缺登记查询会驻留 null，
	## 用例间隔离必须重置）
	## 参数：无
	## 返回：无
	SpriteResolver.clear_cache()

func after() -> void:
	## 套件后置：清解析缓存（防污染后续套件）
	## 参数：无
	## 返回：无
	SpriteResolver.clear_cache()

func test_anim_id_composition() -> void:
	## 动作件 id 组装：<sprite_id>_<action> 六后缀逐一断言
	var sprite_id: StringName = &"spr_cls_warrior"
	assert_str(String(SpriteResolver.anim_id_of(sprite_id,
			UnitAnimState.Action.IDLE))).is_equal("spr_cls_warrior_idle")
	assert_str(String(SpriteResolver.anim_id_of(sprite_id,
			UnitAnimState.Action.MOVE))).is_equal("spr_cls_warrior_move")
	assert_str(String(SpriteResolver.anim_id_of(sprite_id,
			UnitAnimState.Action.MELEE_ATTACK))).is_equal("spr_cls_warrior_melee_attack")
	assert_str(String(SpriteResolver.anim_id_of(sprite_id,
			UnitAnimState.Action.CAST_RANGED))).is_equal("spr_cls_warrior_cast_ranged")
	assert_str(String(SpriteResolver.anim_id_of(sprite_id,
			UnitAnimState.Action.HIT))).is_equal("spr_cls_warrior_hit")
	assert_str(String(SpriteResolver.anim_id_of(sprite_id,
			UnitAnimState.Action.DOWNED))).is_equal("spr_cls_warrior_downed")

func test_anim_id_guards_empty_and_out_of_range() -> void:
	## 组装防御：空 sprite_id / 越界 action 回退空 id
	assert_str(String(SpriteResolver.anim_id_of(&"", UnitAnimState.Action.IDLE))) \
			.is_empty()
	assert_str(String(SpriteResolver.anim_id_of(&"spr_cls_warrior", 99))).is_empty()
	assert_str(String(SpriteResolver.anim_id_of(&"spr_cls_warrior", -1))).is_empty()

func test_anim_texture_of_resolves_registered_strip() -> void:
	## 竖条纹理解析：真实登记键非空 + 尺寸 = 宽 128 高 帧数×128
	var strip: Texture2D = SpriteResolver.anim_texture_of(&"spr_en_elite_boss",
			UnitAnimState.Action.DOWNED, _game_data)
	assert_object(strip).is_not_null()
	assert_int(strip.get_width()).is_equal(SpriteResolver.ANIM_FRAME_SIZE)
	assert_int(strip.get_height()).is_equal(3 * SpriteResolver.ANIM_FRAME_SIZE)

func test_anim_texture_of_missing_returns_null() -> void:
	## 缺登记回退：未登记 id / 空表回退 null（占位色块路径）
	assert_object(SpriteResolver.anim_texture_of(&"spr_cls_nope",
			UnitAnimState.Action.IDLE, _game_data)).is_null()
	assert_object(SpriteResolver.anim_texture_of(&"spr_cls_warrior",
			UnitAnimState.Action.IDLE, null)).is_null()

func test_frame_atlas_region_steps_by_frame() -> void:
	## 首帧 AtlasTexture region：帧 0 = (0,0)，帧 1 = (0,128)——逐帧切片契约
	var frame0: AtlasTexture = SpriteResolver.frame_atlas_of(&"spr_cls_warrior",
			UnitAnimState.Action.IDLE, 0, _game_data)
	assert_object(frame0).is_not_null()
	assert_int(int(frame0.region.position.y)).is_equal(0)
	assert_int(int(frame0.region.size.x)).is_equal(SpriteResolver.ANIM_FRAME_SIZE)
	assert_int(int(frame0.region.size.y)).is_equal(SpriteResolver.ANIM_FRAME_SIZE)
	var frame1: AtlasTexture = SpriteResolver.frame_atlas_of(&"spr_cls_warrior",
			UnitAnimState.Action.IDLE, 1, _game_data)
	assert_int(int(frame1.region.position.y)).is_equal(SpriteResolver.ANIM_FRAME_SIZE)

func test_frame_atlas_out_of_range_clamps_to_last() -> void:
	## 越界钳：帧下标 99 → 钳末帧（downed 3 帧 → region.y = 256）
	var clamped: AtlasTexture = SpriteResolver.frame_atlas_of(&"spr_en_elite_boss",
			UnitAnimState.Action.DOWNED, 99, _game_data)
	assert_object(clamped).is_not_null()
	assert_int(int(clamped.region.position.y)).is_equal(2 * SpriteResolver.ANIM_FRAME_SIZE)

func test_frame_atlas_cached_instance_shared() -> void:
	## 缓存一致性：同 id 同帧两次解析返回同一实例（进程级缓存）
	var first: AtlasTexture = SpriteResolver.frame_atlas_of(&"spr_cls_mage",
			UnitAnimState.Action.HIT, 0, _game_data)
	var second: AtlasTexture = SpriteResolver.frame_atlas_of(&"spr_cls_mage",
			UnitAnimState.Action.HIT, 0, _game_data)
	assert_object(second).is_same(first)
	SpriteResolver.clear_cache()
	var third: AtlasTexture = SpriteResolver.frame_atlas_of(&"spr_cls_mage",
			UnitAnimState.Action.HIT, 0, _game_data)
	assert_object(third).is_not_same(first)

func test_frame_count_of_derives_from_height() -> void:
	## 帧数推导：图高 ÷ 128（idle 256→2 / downed 384→3 / null→0）
	assert_int(SpriteResolver.frame_count_of(SpriteResolver.anim_texture_of(
			&"spr_cls_rogue", UnitAnimState.Action.IDLE, _game_data))).is_equal(2)
	assert_int(SpriteResolver.frame_count_of(SpriteResolver.anim_texture_of(
			&"spr_cls_rogue", UnitAnimState.Action.DOWNED, _game_data))).is_equal(3)
	assert_int(SpriteResolver.frame_count_of(null)).is_equal(0)

func test_frame_count_of_non_multiple_height_truncates_with_warning() -> void:
	## 低11：非整倍高防御——高 300 → 截断 2 帧（余 44px 丢弃，运行时推
	## 警告日志）；高 127 → 0（不足一帧）
	var tall: Image = Image.create(SpriteResolver.ANIM_FRAME_SIZE, 300,
			false, Image.FORMAT_RGBA8)
	assert_int(SpriteResolver.frame_count_of(
			ImageTexture.create_from_image(tall))).is_equal(2)
	var short: Image = Image.create(SpriteResolver.ANIM_FRAME_SIZE, 127,
			false, Image.FORMAT_RGBA8)
	assert_int(SpriteResolver.frame_count_of(
			ImageTexture.create_from_image(short))).is_equal(0)

func test_frame_atlas_of_negative_index_clamps_to_first() -> void:
	## 低11：负向下标钳制——-5 → 钳首帧（region.y == 0，与正向下标钳末帧对称）
	var clamped: AtlasTexture = SpriteResolver.frame_atlas_of(&"spr_cls_rogue",
			UnitAnimState.Action.IDLE, -5, _game_data)
	assert_object(clamped).is_not_null()
	assert_int(int(clamped.region.position.y)).is_equal(0)

func test_frame_atlas_of_sub_frame_height_returns_null_with_warning() -> void:
	## 低11：不足一帧竖条（高 127）——frame_atlas_of 返 null（整条哑火推
	## 运行时警告；校验器已拦生产面，此为防御契约锚定）
	var tiny: ImageTexture = ImageTexture.create_from_image(Image.create(
			SpriteResolver.ANIM_FRAME_SIZE, 127, false, Image.FORMAT_RGBA8))
	# 经注入路径消费（直塞缓存模拟 registry 解析结果——frame_atlas_of 内部
	# 走 anim_texture_of；M6 批 3.5a 起纹理缓存收口 AssetTex：清缓存后置入假条）
	AssetTex._cache[&"spr_fake_tiny_idle"] = tiny
	assert_object(SpriteResolver.frame_atlas_of(&"spr_fake_tiny",
			UnitAnimState.Action.IDLE, 0, _game_data)).is_null()
	SpriteResolver.clear_cache()
