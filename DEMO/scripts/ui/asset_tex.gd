## 资产纹理解析器（AssetTex，纯静态工具类）
## 职责：任意资产 id → Texture2D 的单源解析（M6 批 3.5a 接线机制基建 A1）：
## id → GameData.get_asset_path（AssetRegistry 路径映射）→ load，进程级缓存
##（game_data 有效时 null = 已知缺件缓存穿透——防止每帧重复查 registry；
## 空 game_data/空 id 不落缓存——null 驻留会毒化同进程后续解析）；
## pick_variant 提供主件+变体按格坐标稳定哈希选取（同格恒定——tile 纹样
## 混铺打破重复感）；apply_to 一行装配 TextureRect。批 3.5b 的九组 UI 消费点
##（背景/探索战棋 tile 渲染/图标/迷雾/系统图标/UI 件/选中框）统一经本类取纹理。
## 数据来源：M6 批 3.5a 接线方案 A1；SpriteResolver.texture_of 自本批起薄
## 转发本类（单位链路缓存收口单份，clear_cache 两口同清）。
## 纯逻辑约束：不触 autoload 节点树——game_data 经参数注入（调用方持有引用）。
class_name AssetTex
extends RefCounted

## 纹理进程级缓存（资产 id -> Texture2D；game_data 有效时 null = 已知缺件/
## 缺登记——缓存穿透防止每帧重复查 registry，缺件加载失败 warning 只在穿透
## 首发时打一次；空 game_data/空 id **不入池**——循环盲审第二轮·低：null
## 驻留会毒化同进程后续解析（game_data 就绪后也恒命中 null，测试顺序依赖地雷））
static var _cache: Dictionary = {}

static func texture_of(asset_id: StringName, game_data: Node) -> Texture2D:
	## 资产 id → 纹理：缓存命中直取；否则经 game_data.get_asset_path
	##（AssetRegistry 路径映射）load；空 id/空 game_data/缺登记/加载失败
	## 回退 null（调用方走占位色块/降级路径）。空 game_data/空 id **不落缓存**
	##（循环盲审第二轮·低：此前无条件落缓存致 null 驻留毒化——game_data 后续
	## 就绪也无法恢复解析）；game_data 有效的解析照旧缓存（缺登记/加载失败
	## null 穿透口径不变）
	## 参数 asset_id：资产 id（bg_/tile_/icon_/ui_/fx_/spr_ 前缀）；game_data：GameData
	## 返回：Texture2D；未登记/加载失败返回 null
	if _cache.has(asset_id):
		return _cache[asset_id]
	if game_data == null or String(asset_id).is_empty():
		return null
	var texture: Texture2D = null
	var path: String = game_data.get_asset_path(asset_id)
	if not path.is_empty():
		texture = load(path) as Texture2D
		if texture == null:
			push_warning("AssetTex: 资产 '%s' 加载失败（%s）——本会话缓存 null 降级" % [
					asset_id, path])
	_cache[asset_id] = texture
	return texture

static func pick_variant(base_id: StringName, variants: Array[StringName],
		cell: Vector2i) -> StringName:
	## 主件+变体按格坐标稳定哈希选取：(cell.x*7+cell.y*13) % 件数——同格恒定
	## （重绘/重进图不换纹样），异格打散（tile 纹样混铺打破重复感）；负坐标
	## 取正模（防御未来负坐标输入，语义不变）
	## 参数 base_id：主件资产 id；variants：变体资产 id 列表（空 = 恒返主件）
	## cell：格坐标（稳定哈希种子）
	## 返回：选中的资产 id（主件或某变体）
	if variants.is_empty():
		return base_id
	var pool: Array[StringName] = [base_id]
	pool.append_array(variants)
	var hash_value: int = cell.x * 7 + cell.y * 13
	if hash_value < 0:
		hash_value = -hash_value
	return pool[hash_value % pool.size()]

static func apply_to(rect: TextureRect, asset_id: StringName, game_data: Node) -> bool:
	## 一行装配：解析纹理并贴到 TextureRect（rect 空安全返回 false）
	## 参数 rect：目标 TextureRect；asset_id：资产 id；game_data：GameData
	## 返回：true = 贴图成功（纹理非空；false = 缺件降级信号）
	# 顺手5：is_instance_valid 防御——freed 实例 != null 为真（Godot freed
	## 引用语义坑：queue_free 后同帧内引用非空但已不可访问属性），双检收口
	if rect == null or not is_instance_valid(rect):
		return false
	var texture: Texture2D = texture_of(asset_id, game_data)
	rect.texture = texture
	return texture != null

static func clear_cache() -> void:
	## 清空纹理缓存（测试隔离口——表热重载/换 GameData 后防止旧纹理驻留；
	## SpriteResolver.clear_cache 同清本池——两口同清）
	## 参数：无
	## 返回：无
	_cache = {}
