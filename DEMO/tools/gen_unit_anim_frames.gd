## 单位占位动作帧生成器（M6 批 1：六动作竖条占位过渡）
## 职责：以现有单位静态图（或既有 idle 竖条首帧）为基准，几何变换生成
## 9 单位 × 6 动作 = 54 张竖条占位 PNG（宽 128、高 = 帧数×128——帧数由
## 图高自动推导）+ AssetRegistry 同步（仅重建 spr_ 前缀键）+ naming_registry
## 同步（spr_ 条目重建）+ 旧静态图退役删除。
## 动作规格（帧数 ∈ V-M6-anim-geometry 规格带）：
##   idle 2 帧（上下 1px 浮动）/ move 4 帧（水平±2px 摆动+纵向起伏）/
##   melee_attack 3 帧（前倾 4px+水平压缩 8%）/ cast_ranged 3 帧（后仰回正
##   +亮度脉冲）/ hit 2 帧（白化 60%+位移 2px）/ downed 3 帧（旋转 15°→45°
##   →90° 压扁躺平，末帧 = 尸态）
## 几何变换：统一绕脚底中心（pivot 底边中点）平移/缩放/旋转（脚部锚定
## 防帧间抖动——04 组规格同款约束），白化为向白色 lerp。
## 用法：godot --headless -s res://tools/gen_unit_anim_frames.gd
##   （生成后需跑 godot --headless --import 产出 .import 方可运行时加载）
## 幂等：基准源优先取旧静态图（32×32 ×4 最近邻放大）；静态图已退役时
## 回落取 <id>_idle.png 首帧（idle 帧序 0 = 无变换基准——往返恒等）。
## 替换：正式素材 M6 批 3/4 按动作件 id 原位替换零改表。
extends SceneTree

## 输出目录
const OUT_DIR: String = "res://assets/units"
## AssetRegistry 路径
const REGISTRY_PATH: String = "res://data/assets/registry.tres"
## naming_registry 路径
const NAMING_PATH: String = "res://data/core/naming_registry.tres"

## 帧边长（宽 128、高 = 帧数×128——M6 规格；低13 盲审修复：引用
## SpriteResolver.ANIM_FRAME_SIZE 单源，消除手工拷贝漂移）
const FRAME_SIZE: int = SpriteResolver.ANIM_FRAME_SIZE

## 基准图放大倍数（旧静态图 32×32 → 128×128）
const BASE_SCALE: int = 4

## 九单位 sprite id（spr_*——与 ClassDef/EnemyDef.sprite_id 表值一致；
## 数据驱动加载需 GameData 装配链，工具态硬编码清单同旧生成器先例）
const UNIT_IDS: Array[String] = [
	"spr_cls_warrior",
	"spr_cls_rogue",
	"spr_cls_mage",
	"spr_cls_priest",
	"spr_cls_ranger",
	"spr_cls_arcanist",
	"spr_en_mutant_rat",
	"spr_en_goblin_miner",
	"spr_en_elite_boss",
]

## 单位中文名（naming 登记与日志消费）
const UNIT_NAMES: Dictionary = {
	"spr_cls_warrior": "战士",
	"spr_cls_rogue": "盗贼",
	"spr_cls_mage": "法师",
	"spr_cls_priest": "牧师",
	"spr_cls_ranger": "游侠",
	"spr_cls_arcanist": "奇术师",
	"spr_en_mutant_rat": "变异鼠",
	"spr_en_goblin_miner": "哥布林矿工",
	"spr_en_elite_boss": "矿洞祸首",
}

## 六动作定义：后缀 / 帧变换表（每帧 = {offset/rot/scale/whiten}）
## rot = 度；scale = 脚底锚定缩放；whiten = 向白 lerp 比例；
## 低4（盲审）：类型化 Array[Dictionary]（裸 Array 弱类型——后缀/帧表
## 键名拼错静默错乱，类型注解收窄字典层）
const ACTIONS: Array[Dictionary] = [
	{
		"suffix": "idle",
		"name": "待机",
		"frames": [
			{"offset": Vector2i(0, 0)},
			{"offset": Vector2i(0, -1)},
		],
	},
	{
		"suffix": "move",
		"name": "移动",
		"frames": [
			{"offset": Vector2i(-2, 0)},
			{"offset": Vector2i(0, -1)},
			{"offset": Vector2i(2, 0)},
			{"offset": Vector2i(0, 1)},
		],
	},
	{
		"suffix": "melee_attack",
		"name": "近战攻击",
		"frames": [
			{"offset": Vector2i(1, 0), "scale": Vector2(0.98, 1.0)},
			{"offset": Vector2i(4, 0), "scale": Vector2(0.92, 1.0)},
			{"offset": Vector2i(2, 0), "scale": Vector2(0.95, 1.0)},
		],
	},
	{
		"suffix": "cast_ranged",
		"name": "施放攻击",
		"frames": [
			{"offset": Vector2i(-2, 0), "whiten": 0.05},
			{"offset": Vector2i(-3, 0), "whiten": 0.15},
			{"offset": Vector2i(0, 0), "whiten": 0.25},
		],
	},
	{
		"suffix": "hit",
		"name": "受击",
		"frames": [
			{"offset": Vector2i(2, 0), "whiten": 0.6},
			{"offset": Vector2i(-2, 0), "whiten": 0.6},
		],
	},
	{
		"suffix": "downed",
		"name": "倒地",
		"frames": [
			{"rot": 15.0},
			{"rot": 45.0, "scale": Vector2(1.0, 0.85)},
			{"rot": 90.0, "scale": Vector2(1.0, 0.6)},
		],
	},
]

## 旧静态图与预览（退役删除基础清单；单位单图在退役口动态拼接）
const RETIRE_FILES: Array[String] = [
	"res://assets/units/_preview_all.png",
]

func _initialize() -> void:
	## MainLoop 回调：基准解析 → 54 竖条生成 → registry/naming 同步 → 旧件退役
	## 参数：无
	## 返回：无（任一步失败按退出码 1 结束）
	var ok: bool = true
	for unit_id: String in UNIT_IDS:
		var base: Image = _LoadBaseImage(unit_id)
		if base == null:
			printerr("gen_unit_anim_frames: 基准图缺失 %s（静态图与 idle 竖条均不存在）" % unit_id)
			ok = false
			continue
		ok = _GenerateUnitStrips(unit_id, base) and ok
	if ok:
		ok = _SyncAssetRegistry()
	if ok:
		ok = _SyncNamingRegistry()
	if ok:
		# 低2：退役删除失败（Windows 文件锁定等）不再静默——计入退出码
		ok = _RetireStaticSprites() and ok
	if ok:
		print("gen_unit_anim_frames: 生成完成（%d 单位 × %d 动作 = %d 竖条 + registry/naming 同步）" % [
				UNIT_IDS.size(), ACTIONS.size(), UNIT_IDS.size() * ACTIONS.size()])
		quit(0)
	else:
		printerr("gen_unit_anim_frames: 存在失败项，详见上方输出")
		quit(1)

func _LoadBaseImage(unit_id: String) -> Image:
	## 基准图解析（幂等双源）：旧静态图（32×32 ×4 最近邻放大）优先；
	## 已退役时回落 idle 竖条首帧（帧序 0 = 无变换基准）
	## 参数 unit_id：单位 sprite id
	## 返回：128×128 基准图；双源缺失返回 null
	var static_path: String = "%s/%s.png" % [OUT_DIR, unit_id]
	if FileAccess.file_exists(static_path):
		var raw: Image = _LoadPng(static_path)
		if raw == null:
			return null
		if raw.get_width() != FRAME_SIZE or raw.get_height() != FRAME_SIZE:
			raw.resize(FRAME_SIZE, FRAME_SIZE, Image.INTERPOLATE_NEAREST)
		return raw
	var idle_path: String = "%s/%s_idle.png" % [OUT_DIR, unit_id]
	if FileAccess.file_exists(idle_path):
		var strip: Image = _LoadPng(idle_path)
		if strip == null:
			return null
		return _FrameRegion(strip, 0)
	return null

func _LoadPng(path: String) -> Image:
	## PNG 文件读取（FileAccess + 解码——headless 工具态不经 ResourceLoader）
	## 参数 path：res:// 路径
	## 返回：解码 Image；失败返回 null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		printerr("gen_unit_anim_frames: 读取失败 %s" % path)
		return null
	var img := Image.new()
	var err: Error = img.load_png_from_buffer(bytes)
	if err != OK:
		printerr("gen_unit_anim_frames: PNG 解码失败 %s（错误码 %d）" % [path, err])
		return null
	return img

func _FrameRegion(strip: Image, frame_index: int) -> Image:
	## 竖条取帧区域（128×128）
	## 参数 strip：竖条图；frame_index：帧下标
	## 返回：区域副本
	return strip.get_region(Rect2i(0, frame_index * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE))

func _GenerateUnitStrips(unit_id: String, base: Image) -> bool:
	## 生成单单位 6 动作竖条
	## 参数 unit_id：单位 sprite id；base：基准图
	## 返回：true = 全部保存成功
	var ok: bool = true
	for action: Dictionary in ACTIONS:
		var frames: Array = action["frames"]
		var strip: Image = Image.create(FRAME_SIZE, frames.size() * FRAME_SIZE,
				false, Image.FORMAT_RGBA8)
		for index: int in frames.size():
			var frame: Image = _ComposeFrame(base, frames[index])
			strip.blend_rect(frame, Rect2i(Vector2i.ZERO,
					Vector2i(FRAME_SIZE, FRAME_SIZE)), Vector2i(0, index * FRAME_SIZE))
		var path: String = "%s/%s_%s.png" % [OUT_DIR, unit_id, action["suffix"]]
		var err: Error = strip.save_png(path)
		if err != OK:
			printerr("gen_unit_anim_frames: 保存失败 %s（错误码 %d）" % [path, err])
			ok = false
		else:
			print("gen_unit_anim_frames: %s（%s，%d 帧）" % [path, action["name"], frames.size()])
	return ok

func _ComposeFrame(base: Image, spec: Dictionary) -> Image:
	## 帧几何变换合成：dst(p) = pivot + R(rot)·(S(scale)·(src - pivot)) + offset
	## ——绕脚底中心（pivot = 底边中点）平移/缩放/旋转，白化向白 lerp；
	## 逆向映射 + 最近邻采样（占位视觉，像素级精度非必要）
	## 参数 base：基准图；spec：帧变换（offset/rot/scale/whiten）
	## 返回：128×128 变换帧
	var offset: Vector2 = spec.get("offset", Vector2i.ZERO)
	var rot_deg: float = spec.get("rot", 0.0)
	var scale: Vector2 = spec.get("scale", Vector2.ONE)
	var whiten: float = spec.get("whiten", 0.0)
	var frame: Image = Image.create(FRAME_SIZE, FRAME_SIZE, false, Image.FORMAT_RGBA8)
	var pivot: Vector2 = Vector2(float(FRAME_SIZE) * 0.5, float(FRAME_SIZE) - 1.0)
	var radians: float = deg_to_rad(rot_deg)
	# 逆向变换系数（R 逆 = 转置；S 逆 = 分量取倒数）
	var cos_r: float = cos(radians)
	var sin_r: float = sin(radians)
	for y: int in FRAME_SIZE:
		for x: int in FRAME_SIZE:
			var dst: Vector2 = Vector2(float(x), float(y)) - pivot - offset
			# 逆旋转（R^T）
			var unrotated: Vector2 = Vector2(
					dst.x * cos_r + dst.y * sin_r,
					-dst.x * sin_r + dst.y * cos_r)
			# 逆缩放
			var src: Vector2 = Vector2(unrotated.x / scale.x, unrotated.y / scale.y) + pivot
			var sx: int = roundi(src.x)
			var sy: int = roundi(src.y)
			if sx < 0 or sx >= FRAME_SIZE or sy < 0 or sy >= FRAME_SIZE:
				continue
			var pixel: Color = base.get_pixel(sx, sy)
			if pixel.a <= 0.0:
				continue
			if whiten > 0.0:
				pixel = pixel.lerp(Color(1.0, 1.0, 1.0, pixel.a), whiten)
			frame.set_pixel(x, y, pixel)
	return frame

func _SyncAssetRegistry() -> bool:
	## 同步 AssetRegistry：重建 spr_ 前缀键（保留其他键）——旧 9 单图键删除、
	## 54 动作键登记
	## 参数：无
	## 返回：true = 保存成功
	var registry: AssetRegistry = null
	if ResourceLoader.exists(REGISTRY_PATH):
		registry = load(REGISTRY_PATH) as AssetRegistry
	if registry == null:
		registry = AssetRegistry.new()
	var stale_keys: Array[StringName] = []
	for key: StringName in registry.mapping:
		if String(key).begins_with("spr_"):
			stale_keys.append(key)
	for key: StringName in stale_keys:
		registry.mapping.erase(key)
	for unit_id: String in UNIT_IDS:
		for action: Dictionary in ACTIONS:
			var asset_id: StringName = StringName("%s_%s" % [unit_id, action["suffix"]])
			registry.mapping[asset_id] = "%s/%s_%s.png" % [OUT_DIR, unit_id, action["suffix"]]
	registry.comment = "【占位·像素小人动作集】spr_* = M6 批 1 单位六动作竖条（tools/gen_unit_anim_frames.gd 程序化生成，可重复执行）；正式素材按动作件 id 原位替换（批 3/4）"
	var err: Error = ResourceSaver.save(registry, REGISTRY_PATH)
	if err != OK:
		printerr("gen_unit_anim_frames: registry 保存失败 %s（错误码 %d）" % [REGISTRY_PATH, err])
		return false
	print("gen_unit_anim_frames: AssetRegistry 已登记 %d 条 spr_* 映射" % registry.mapping.size())
	return true

func _SyncNamingRegistry() -> bool:
	## 同步 naming_registry：spr_ 前缀条目重建（旧 9 单图条目删除、54 动作
	## 条目登记——V-B2-naming 双向一致）；低3（盲审）：**保留既有 comment**
	##（comment 是人工演进的历史叙述——工具快照全文重写会把人工修订打回
	## 旧叙述；工具只同步条目不动 comment 字段）
	## 参数：无
	## 返回：true = 保存成功
	var naming: NamingRegistry = null
	if ResourceLoader.exists(NAMING_PATH):
		naming = load(NAMING_PATH) as NamingRegistry
	if naming == null:
		printerr("gen_unit_anim_frames: naming_registry 缺失 %s" % NAMING_PATH)
		return false
	var kept: Array[NamingEntry] = []
	var removed: int = 0
	for entry: NamingEntry in naming.entries:
		if String(entry.resource_id).begins_with("spr_"):
			removed += 1
		else:
			kept.append(entry)
	for unit_id: String in UNIT_IDS:
		for action: Dictionary in ACTIONS:
			var entry := NamingEntry.new()
			entry.resource_id = StringName("%s_%s" % [unit_id, action["suffix"]])
			entry.domain = &"assets"
			entry.display_name = "%s·%s" % [UNIT_NAMES[unit_id], action["name"]]
			entry.rule_note = "spr_<单位>_<动作>：单位六动作竖条（M6 批 1；assets 域 AssetRegistry 登记键；宽 128/高 = 帧数×128）"
			kept.append(entry)
	naming.entries = kept
	var err: Error = ResourceSaver.save(naming, NAMING_PATH)
	if err != OK:
		printerr("gen_unit_anim_frames: naming_registry 保存失败 %s（错误码 %d）" % [NAMING_PATH, err])
		return false
	print("gen_unit_anim_frames: naming_registry 已同步（移除旧条目 %d，现共 %d 条；comment 未改动）" % [
			removed, kept.size()])
	return true

func _RetireStaticSprites() -> bool:
	## 旧静态图退役：9 张单图 PNG（含 .import）+ 预览拼图删除
	## 参数：无
	## 返回：true = 全部删除成功（低2：DirAccess.remove_absolute 返回值不再
	## 丢弃——Windows 文件锁定等删除失败累计打印并影响退出码）
	var ok: bool = true
	var retire_paths: Array[String] = RETIRE_FILES.duplicate()
	for unit_id: String in UNIT_IDS:
		retire_paths.append("res://assets/units/%s.png" % unit_id)
	for path: String in retire_paths:
		for suffix: String in ["", ".import"]:
			var full_path: String = path + suffix
			if FileAccess.file_exists(full_path):
				var err: Error = DirAccess.remove_absolute(
						ProjectSettings.globalize_path(full_path))
				if err != OK:
					printerr("gen_unit_anim_frames: 退役删除失败 %s（错误码 %d——文件可能被占用）" % [
							full_path, err])
					ok = false
				else:
					print("gen_unit_anim_frames: 退役删除 %s" % full_path)
	return ok
