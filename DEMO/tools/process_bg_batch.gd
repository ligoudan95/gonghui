## 场景背景批量入库处理工具（M6 批 3 后半：art_spec/background 正式件 → assets/bg）
## 职责：扫描 art_spec/background/ 下 bg_*.png 源图（用户素材区——**只读不动**；
## BG_1.jpg 等非 bg_ 前缀/非 png 文件天然排除）→ 居中裁切至精确 16:9
##（process_bg_guild_hall 先例裁法）→ LANCZOS 缩放至 1920×1080 → 不透明 PNG
##（带 alpha 源转 RGB8 丢弃 alpha；无 alpha 源直通）→ **同 id 原位覆盖**
## assets/bg/<id>.png 占位（文件名 == 资源 id，铁律②；registry/naming 零改动
## ——同 id 替换口径，零差异证明归 tools/sync_asset_registry.gd）。处理后回读
## 校验尺寸+无 alpha。
## 与 process_bg_guild_hall.gd 的关系：首批试运行单件工具**保留不动**（历史留痕
## ——其源图 BG_2.png 已不在素材区无法重跑，且其改动属批 3 已验收变更集）；
## 本工具为同一处理逻辑的批量泛化后继（裁切/缩放/校验流程与其一致）。
## 用法：godot --headless -s res://tools/process_bg_batch.gd
##   （生成后需跑 godot --headless --import 重建导入缓存方可运行时加载；
##   registry/naming 登记不在本工具职责内——新增 id 归 sync_asset_registry.gd，
##   同 id 替换零改表）
extends SceneTree

## 源图目录（用户素材区——本工具只读；文件名即资源 id）
const SOURCE_DIR: String = "res://art_spec/background"

## 输出目录（assets/ 分组目录——bg 组）
const OUT_DIR: String = "res://assets/bg"

## 源文件前缀过滤（bg_ 前缀小写——BG_1.jpg 用户参考图大小写+扩展名双重排除）
const FILE_PREFIX: String = "bg_"

## 源文件扩展名过滤
const FILE_EXT: String = ".png"

## 输出尺寸（场景背景规格：1920×1080，01_背景组）
const OUT_WIDTH: int = 1920
const OUT_HEIGHT: int = 1080

## 最近一次裁切尺寸缓存（_ProcessOne 打印报告用——裁切函数单职责不回流）
var cropped_size_report: Vector2i = Vector2i.ZERO

func _initialize() -> void:
	## MainLoop 回调：扫描源目录 → 逐件「读源图 → 居中裁切精确 16:9 → 缩放 →
	## 不透明化 → 覆盖输出 → 回读校验」→ 汇总
	## 参数：无
	## 返回：无（任一件失败按退出码 1 结束）
	var sources: PackedStringArray = _ScanSources()
	if sources.is_empty():
		printerr("process_bg_batch: 源目录无 %s*%s 文件（%s）" % [
				FILE_PREFIX, FILE_EXT, SOURCE_DIR])
		quit(1)
		return
	var ok: bool = true
	for file_name: String in sources:
		ok = _ProcessOne(file_name) and ok
	if ok:
		print("process_bg_batch: 批量入库完成（%d 件，源目录未改动）" % sources.size())
		quit(0)
	else:
		printerr("process_bg_batch: 存在失败项，详见上方输出")
		quit(1)

func _ScanSources() -> PackedStringArray:
	## 源目录扫描：bg_ 前缀 + .png 扩展（字典序稳定输出）
	## 参数：无
	## 返回：合格源文件名列表
	var result: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(SOURCE_DIR)
	if dir == null:
		printerr("process_bg_batch: 源目录不可用 %s" % SOURCE_DIR)
		return result
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if file_name.begins_with(FILE_PREFIX) and file_name.ends_with(FILE_EXT) \
				and not dir.current_is_dir():
			result.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

func _ProcessOne(file_name: String) -> bool:
	## 单件处理链：读源图 → 居中裁切精确 16:9 → LANCZOS 缩放 → 不透明化 →
	## 同 id 覆盖输出 → 回读校验（尺寸+无 alpha）
	## 参数 file_name：源文件名（== 资源 id + .png）
	## 返回：true = 处理并校验通过
	var asset_id: String = file_name.get_basename()
	var source: Image = _LoadPng("%s/%s" % [SOURCE_DIR, file_name])
	if source == null:
		return false
	var cropped: Image = _CenterCropExact169(source)
	cropped.resize(OUT_WIDTH, OUT_HEIGHT, Image.INTERPOLATE_LANCZOS)
	# 不透明硬性要求（01 组规格）：带 alpha 源转 RGB8 丢弃通道（全不透明图
	# 无损）；无 alpha 源 convert 为同一格式幂等直通
	if cropped.detect_alpha():
		cropped.convert(Image.FORMAT_RGB8)
	var out_path: String = "%s/%s.png" % [OUT_DIR, asset_id]
	if not _EnsureOutDir():
		return false
	var err: Error = cropped.save_png(out_path)
	if err != OK:
		printerr("process_bg_batch: 保存失败 %s（错误码 %d）" % [out_path, err])
		return false
	var verify: Image = _LoadPng(out_path)
	if verify == null or verify.get_width() != OUT_WIDTH or verify.get_height() != OUT_HEIGHT:
		printerr("process_bg_batch: 输出文件校验失败 %s（期望 %dx%d）" % [
				out_path, OUT_WIDTH, OUT_HEIGHT])
		return false
	if verify.detect_alpha():
		printerr("process_bg_batch: 输出文件含 alpha 通道 %s（规格要求不透明）" % out_path)
		return false
	print("process_bg_batch: %s 源 %dx%d → 裁切 %dx%d（左右各裁 %d/上下共裁 %d px）→ %dx%d 不透明，%s（%d 字节）" % [
			asset_id, source.get_width(), source.get_height(),
			cropped_size_report.x, cropped_size_report.y,
			(source.get_width() - cropped_size_report.x) / 2,
			source.get_height() - cropped_size_report.y,
			OUT_WIDTH, OUT_HEIGHT, out_path, FileAccess.get_file_as_bytes(out_path).size()])
	return true

func _CenterCropExact169(source: Image) -> Image:
	## 居中裁切至精确 16:9（process_bg_guild_hall 先例裁法）：取源图内可容纳的
	## 最大 16:9 整数边矩形（边长基数 n = min(w/16, h/9) 下取整），水平/垂直
	## 居中——保证输出无拉伸畸变（如 5504×3072 → n=341 → 5456×3069；纵横
	## 双向微裁，直接缩放只能得近似 16:9）
	## 参数 source：源图
	## 返回：裁切区域副本
	var width: int = source.get_width()
	var height: int = source.get_height()
	var base: int = mini(width / 16, height / 9)
	var crop_w: int = base * 16
	var crop_h: int = base * 9
	var origin: Vector2i = Vector2i((width - crop_w) / 2, (height - crop_h) / 2)
	cropped_size_report = Vector2i(crop_w, crop_h)
	return source.get_region(Rect2i(origin, Vector2i(crop_w, crop_h)))

func _LoadPng(path: String) -> Image:
	## PNG 文件读取（FileAccess + 解码——headless 工具态不经 ResourceLoader，
	## 与 process_bg_guild_hall._LoadPng 同款）
	## 参数 path：res:// 路径
	## 返回：解码 Image；失败返回 null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		printerr("process_bg_batch: 读取失败 %s" % path)
		return null
	var img := Image.new()
	var err: Error = img.load_png_from_buffer(bytes)
	if err != OK:
		printerr("process_bg_batch: PNG 解码失败 %s（错误码 %d）" % [path, err])
		return null
	return img

func _EnsureOutDir() -> bool:
	## 输出目录确保存在（递归建目录——防御新增分组目录场景）
	## 参数：无
	## 返回：true = 目录就绪
	var err: Error = DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(OUT_DIR))
	if err != OK:
		printerr("process_bg_batch: 建目录失败 %s（错误码 %d）" % [OUT_DIR, err])
		return false
	return true
