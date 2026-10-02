## 场景背景入库处理工具（M6 批 3 首批试运行：BG_2 → bg_guild_hall）
## 职责：art_spec/background/ 用户源图（只读不动）→ 居中裁切至精确 16:9 →
## LANCZOS 缩放至 1920×1080 → 输出 assets/bg/<资源 id>.png（文件名 == 资源 id，
## 铁律②）；处理后回读输出文件校验尺寸。
## 复用说明：后续背景入库（BG_1 → bg_association_hall 等，01_背景组共 4 件）
## 复制本文件改 SOURCE_PATH / OUT_ID 两常量即可（裁切/缩放/校验流程通用）。
## 用法：godot --headless -s res://tools/process_bg_guild_hall.gd
##   （生成后需跑 godot --headless --import 产出 .import 方可运行时加载；
##   registry/naming 登记不在本工具职责内——按任务指令手工追加）
extends SceneTree

## 源图路径（用户素材区——本工具只读）
const SOURCE_PATH: String = "res://art_spec/background/BG_2.png"

## 输出资源 id（文件名 == 资源 id；M6 方案 01_背景组规格：bg_guild_hall）
const OUT_ID: String = "bg_guild_hall"

## 输出目录（assets/ 分组目录——bg 组）
const OUT_DIR: String = "res://assets/bg"

## 输出尺寸（场景背景规格：1920×1080，01_背景组）
const OUT_WIDTH: int = 1920
const OUT_HEIGHT: int = 1080

func _initialize() -> void:
	## MainLoop 回调：读源图 → 居中裁切精确 16:9 → 缩放输出 → 回读校验
	## 参数：无
	## 返回：无（任一步失败按退出码 1 结束）
	var source: Image = _LoadPng(SOURCE_PATH)
	if source == null:
		quit(1)
		return
	var cropped: Image = _CenterCropExact169(source)
	var cropped_size: Vector2i = cropped.get_size()
	print("process_bg: 源图 %dx%d → 裁切 %dx%d（精确 16:9 居中）" % [
			source.get_width(), source.get_height(), cropped_size.x, cropped_size.y])
	cropped.resize(OUT_WIDTH, OUT_HEIGHT, Image.INTERPOLATE_LANCZOS)
	var out_path: String = "%s/%s.png" % [OUT_DIR, OUT_ID]
	if not _EnsureOutDir():
		quit(1)
		return
	var err: Error = cropped.save_png(out_path)
	if err != OK:
		printerr("process_bg: 保存失败 %s（错误码 %d）" % [out_path, err])
		quit(1)
		return
	# 回读校验：尺寸须为 1920×1080（防写入截断/异常）
	var verify: Image = _LoadPng(out_path)
	if verify == null or verify.get_width() != OUT_WIDTH or verify.get_height() != OUT_HEIGHT:
		printerr("process_bg: 输出文件校验失败 %s（期望 %dx%d）" % [
				out_path, OUT_WIDTH, OUT_HEIGHT])
		quit(1)
		return
	print("process_bg: 输出 %s（%dx%d 校验通过，源图未改动）" % [
			out_path, verify.get_width(), verify.get_height()])
	quit(0)

func _LoadPng(path: String) -> Image:
	## PNG 文件读取（FileAccess + 解码——headless 工具态不经 ResourceLoader，
	## 与 gen_unit_anim_frames._LoadPng 同款）
	## 参数 path：res:// 路径
	## 返回：解码 Image；失败返回 null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		printerr("process_bg: 读取失败 %s" % path)
		return null
	var img := Image.new()
	var err: Error = img.load_png_from_buffer(bytes)
	if err != OK:
		printerr("process_bg: PNG 解码失败 %s（错误码 %d）" % [path, err])
		return null
	return img

func _CenterCropExact169(source: Image) -> Image:
	## 居中裁切至精确 16:9：取源图内可容纳的最大 16:9 整数边矩形（边长基数
	## n = min(w/16, h/9) 下取整），水平/垂直居中——保证输出无拉伸畸变
	##（如 5504×3072 → n=341 → 5456×3069；3072 非 9 整倍，直接按高度裁宽
	## 只能得近似 16:9，故纵横双向微裁）
	## 参数 source：源图
	## 返回：裁切区域副本
	var width: int = source.get_width()
	var height: int = source.get_height()
	var base: int = mini(width / 16, height / 9)
	var crop_w: int = base * 16
	var crop_h: int = base * 9
	var origin: Vector2i = Vector2i((width - crop_w) / 2, (height - crop_h) / 2)
	return source.get_region(Rect2i(origin, Vector2i(crop_w, crop_h)))

func _EnsureOutDir() -> bool:
	## 输出目录确保存在（递归建目录）
	## 参数：无
	## 返回：true = 目录就绪
	var err: Error = DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(OUT_DIR))
	if err != OK:
		printerr("process_bg: 建目录失败 %s（错误码 %d）" % [OUT_DIR, err])
		return false
	return true
