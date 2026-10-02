## AssetTex 资产纹理解析单元测试（M6 批 3.5a A1）
## 覆盖：登记资产解析与缓存一致性 / 缺件 null 缓存穿透 / 空 id 与空 game_data
## 降级（循环盲审第二轮·低：不落缓存 + 后续有效 game_data 恢复解析）/
## pick_variant 稳定哈希 / apply_to 装配 / clear_cache 隔离与
## SpriteResolver 薄转发同池回归——消费真实生成的占位资产（GameData 实例化
## + registry 查路径，headless 加载已导入 PNG）。
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
	AssetTex.clear_cache()

func after() -> void:
	## 套件后置：清解析缓存（防污染后续套件）
	## 参数：无
	## 返回：无
	AssetTex.clear_cache()

func test_texture_of_registered_asset() -> void:
	## 登记资产解析：职业图标占位键非空 + 尺寸 64×64（占位规格锚定）
	var texture: Texture2D = AssetTex.texture_of(&"icon_class_warrior", _game_data)
	assert_object(texture).is_not_null()
	assert_int(texture.get_width()).is_equal(64)
	assert_int(texture.get_height()).is_equal(64)

func test_texture_of_cached_instance_shared() -> void:
	## 缓存一致性：同 id 两次解析返回同一实例（进程级缓存——收口单份）；
	## clear 后缓存项失效（重新解析仍有效——实例同一性由引擎 ResourceCache
	## 兜底，工具缓存层以键存在性锚定隔离）
	var first: Texture2D = AssetTex.texture_of(&"bg_dormitory", _game_data)
	var second: Texture2D = AssetTex.texture_of(&"bg_dormitory", _game_data)
	assert_object(second).is_same(first)
	AssetTex.clear_cache()
	assert_bool(AssetTex._cache.has(&"bg_dormitory")).is_false()
	var third: Texture2D = AssetTex.texture_of(&"bg_dormitory", _game_data)
	assert_object(third).is_not_null()

func test_texture_of_missing_penetrates_cache() -> void:
	## 缺件穿透：未登记 id 回退 null 且 null 驻留缓存（第二次查询命中 null
	## 不再查 registry——防每帧重复查表）
	assert_object(AssetTex.texture_of(&"icon_nope_unregistered", _game_data)).is_null()
	assert_bool(AssetTex._cache.has(&"icon_nope_unregistered")).is_true()
	assert_object(AssetTex.texture_of(&"icon_nope_unregistered", _game_data)).is_null()

func test_texture_of_empty_id_and_null_data_fallback() -> void:
	## 降级防御：空 id / 空 game_data 回退 null（不崩不查表）；循环盲审
	## 第二轮·低：两者**均不落缓存**（null 驻留毒化防御——同 id 后续以有效
	## game_data 解析可恢复，见 test_null_data_then_valid_data_recovers）
	assert_object(AssetTex.texture_of(&"", _game_data)).is_null()
	assert_bool(AssetTex._cache.has(&"")) \
			.override_failure_message("空 id 不得落缓存（null 驻留毒化）").is_false()
	assert_object(AssetTex.texture_of(&"icon_class_warrior", null)).is_null()
	assert_bool(AssetTex._cache.has(&"icon_class_warrior")) \
			.override_failure_message("空 game_data 不得落缓存（null 驻留毒化）").is_false()

func test_null_data_then_valid_data_recovers() -> void:
	## 先 null 后有效 game_data 可恢复解析（循环盲审第二轮·低锚定）：
	## game_data 未就绪期（屏 _ready 早于 autoload 或降级直开）的解析 null
	## 不驻留缓存——同 id 就绪后重查 registry 恢复非空纹理（修复前 null
	## 驻留恒命中，测试顺序依赖地雷）
	assert_object(AssetTex.texture_of(&"bg_dormitory", null)).is_null()
	assert_bool(AssetTex._cache.has(&"bg_dormitory")).is_false()
	var recovered: Texture2D = AssetTex.texture_of(&"bg_dormitory", _game_data)
	assert_object(recovered).override_failure_message(
			"null 解析后有效 game_data 应恢复解析（不毒化）").is_not_null()
	assert_bool(AssetTex._cache.has(&"bg_dormitory")).is_true()

func test_pick_variant_stable_hash() -> void:
	## 变体选取稳定哈希：(cell.x*7+cell.y*13) % 件数——同格恒定、异格打散；
	## 空变体列表恒返主件
	var base_id: StringName = &"tile_mine_floor_01"
	var variants: Array[StringName] = [&"tile_mine_floor_02"]
	# (0,0)：0 % 2 = 0 → 主件；(1,0)：7 % 2 = 1 → 变体；(2,0)：14 % 2 = 0 → 主件
	assert_str(String(AssetTex.pick_variant(base_id, variants, Vector2i(0, 0)))) \
			.is_equal("tile_mine_floor_01")
	assert_str(String(AssetTex.pick_variant(base_id, variants, Vector2i(1, 0)))) \
			.is_equal("tile_mine_floor_02")
	assert_str(String(AssetTex.pick_variant(base_id, variants, Vector2i(2, 0)))) \
			.is_equal("tile_mine_floor_01")
	# 同格恒定（重复调用同结果）
	assert_str(String(AssetTex.pick_variant(base_id, variants, Vector2i(1, 0)))) \
			.is_equal("tile_mine_floor_02")
	# 纵向分量参与：(0,1)：13 % 2 = 1 → 变体
	assert_str(String(AssetTex.pick_variant(base_id, variants, Vector2i(0, 1)))) \
			.is_equal("tile_mine_floor_02")
	# 空变体恒返主件
	assert_str(String(AssetTex.pick_variant(base_id, [], Vector2i(9, 9)))) \
			.is_equal("tile_mine_floor_01")

func test_apply_to_binds_texture() -> void:
	## 一行装配：登记 id 贴图成功 true / 缺件 false 贴 null / 空 rect 安全 false
	var rect: TextureRect = auto_free(TextureRect.new())
	assert_bool(AssetTex.apply_to(rect, &"fx_battle_path_arrow", _game_data)).is_true()
	assert_object(rect.texture).is_not_null()
	assert_bool(AssetTex.apply_to(rect, &"fx_nope_unregistered", _game_data)).is_false()
	assert_object(rect.texture).is_null()
	assert_bool(AssetTex.apply_to(null, &"fx_battle_path_arrow", _game_data)).is_false()

func test_apply_to_freed_instance_semantics_anchor() -> void:
	## 顺手5 语义锚（Godot 4.7.2 实测口径）：free 后的悬挂引用在 Variant 比较
	## 下 == null 为真（旧说法『freed != null』在现行引擎已收口为 null 等价），
	## 且向带类型参数（TextureRect）的函数直传 freed 引用在调用边界即被引擎
	## 拦截（Invalid type 错误——函数体不可达，本用例不做该 doomed 调用）；
	## apply_to 的 is_instance_valid 防御为边界拦截之外的纵深第二道，
	## null 检查覆盖 Variant null 等价路径——两口均在
	var rect := TextureRect.new()
	rect.free()
	var boxed: Variant = rect
	assert_bool(boxed == null).override_failure_message(
			"freed 引用 Variant 比较应等价 null（4.7.2 语义）").is_true()
	assert_bool(is_instance_valid(boxed)).is_false()
	# null 直传照旧安全 false（既有口回归——apply_to 防御双检收口）
	assert_bool(AssetTex.apply_to(null, &"fx_battle_path_arrow", _game_data)).is_false()

func test_sprite_resolver_forward_shares_cache() -> void:
	## SpriteResolver 薄转发回归：texture_of 走 AssetTex 同一缓存（实例一致）；
	## SpriteResolver.clear_cache 两口同清（AssetTex 池一并清空——键存在性锚定）
	var resolver_texture: Texture2D = SpriteResolver.texture_of(&"spr_cls_warrior_idle",
			_game_data)
	assert_object(resolver_texture).is_not_null()
	var asset_tex_texture: Texture2D = AssetTex.texture_of(&"spr_cls_warrior_idle",
			_game_data)
	assert_object(asset_tex_texture).is_same(resolver_texture)
	SpriteResolver.clear_cache()
	assert_bool(AssetTex._cache.has(&"spr_cls_warrior_idle")).is_false()
	var reloaded: Texture2D = AssetTex.texture_of(&"spr_cls_warrior_idle", _game_data)
	assert_object(reloaded).is_not_null()
