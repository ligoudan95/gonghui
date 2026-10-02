## 占位资产生成器口径契约测试（中2/中3 修复锚定——四席盲审）
## 覆盖：迷雾/范围占位「中性全不透明」口径双锚——生成器 spec 值（α=1.0 +
## RGB 中性 r==g==b）与已入库 PNG 像素实况（解码原始文件断言 α=255 且通道
## 中性）。净遮蔽 α 完全由运行时 modulate（cfg 色）承载，纹理自带 α 参与
## 相乘的失真口径（迷雾 0.92×0.92/范围 0.10×0.18）不得回归。
## 中1 防覆写与顺手2 comment 保留属工具运行时行为，验证证据在 headless
## 工具跑批（工作汇报留存），不在本套件。
extends GdUnitTestSuite

## 占位生成器脚本（SceneTree 脚本——常量经 preload 类访问，不实例化）
const GenTool: GDScript = preload("res://tools/gen_asset_placeholders.gd")

## 中性全不透明锚定的采样点（角/心/雾团纹样带——覆盖底色与纹样两类像素）
const SAMPLE_POINTS: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(256, 256), Vector2i(400, 100), Vector2i(64, 320),
]

func _AssertNeutralOpaque(color: Color, label: String) -> void:
	## 单色中性全不透明断言（α=1.0 + r==g==b——色相交由运行时 modulate）
	## 参数 color：受检色；label：断言失败定位文案
	## 返回：无
	assert_float(color.a).override_failure_message(
			"%s 应全不透明（α=1.0——净 α 由 modulate 单乘）" % label).is_equal(1.0)
	assert_bool(is_equal_approx(color.r, color.g) \
			and is_equal_approx(color.g, color.b)).override_failure_message(
			"%s 应中性白灰（r==g==b——不带色相）" % label).is_true()

func test_fog_specs_neutral_opaque() -> void:
	## 中2 spec 锚：迷雾两键 base/accent 中性白灰且 α=1.0（旧版自带
	## α0.92/0.55 与 modulate α 相乘——净观感偏离 cfg 调定值，已废）
	for asset_id: String in ["fx_fog_unseen", "fx_fog_dim"]:
		var spec: Dictionary = GenTool.SPECS[asset_id]
		_AssertNeutralOpaque(spec["base"], "%s base" % asset_id)
		_AssertNeutralOpaque(spec["accent"], "%s accent" % asset_id)

func test_range_spec_neutral_opaque() -> void:
	## 中3 spec 锚：范围键 base/accent 全不透明中性白（旧版 α0.18 与
	## modulate α0.10 双乘净观感仅 0.018——cfg 失真，已废）
	var spec: Dictionary = GenTool.SPECS["fx_battle_range"]
	_AssertNeutralOpaque(spec["base"], "fx_battle_range base")
	_AssertNeutralOpaque(spec["accent"], "fx_battle_range accent")

func _LoadPng(path: String) -> Image:
	## PNG 原始字节直读（不经资源导入——FileAccess 解码，重生成后即刻可验）
	## 参数 path：文件路径（res://）
	## 返回：解码后 Image（解码失败断言即败）
	var img := Image.new()
	assert_int(img.load_png_from_buffer(FileAccess.get_file_as_bytes(path))) \
			.override_failure_message("PNG 解码失败：%s" % path).is_equal(OK)
	return img

func test_fog_png_pixels_opaque_neutral() -> void:
	## 中2 文件锚：迷雾两张入库 PNG 像素全不透明（α=255）且通道中性——
	## 纹样为灰度亮度差而非 α 差（采样含雾团纹样带像素）
	for path: String in ["res://assets/fx/fx_fog_unseen.png",
			"res://assets/fx/fx_fog_dim.png"]:
		var img: Image = _LoadPng(path)
		assert_int(img.get_width()).is_equal(512)
		assert_int(img.get_height()).is_equal(512)
		for point: Vector2i in SAMPLE_POINTS:
			var color: Color = img.get_pixel(point.x, point.y)
			assert_int(int(round(color.a * 255.0))).override_failure_message(
					"%s (%d,%d) 像素应全不透明" % [path, point.x, point.y]) \
					.is_equal(255)
			assert_bool(is_equal_approx(color.r, color.g) \
					and is_equal_approx(color.g, color.b)).override_failure_message(
					"%s (%d,%d) 像素应通道中性" % [path, point.x, point.y]).is_true()

func test_range_png_pixels_opaque_neutral() -> void:
	## 中3 文件锚：范围格面入库 PNG 像素全不透明中性——填充与描边两类像素
	## 采样（(2,2) 描边带 / (64,64) 填充心），净观感 = modulate（cfg 色）单乘
	var img: Image = _LoadPng("res://assets/fx/fx_battle_range.png")
	assert_int(img.get_width()).is_equal(128)
	assert_int(img.get_height()).is_equal(128)
	for point: Vector2i in [Vector2i(2, 2), Vector2i(64, 64), Vector2i(120, 64)]:
		var color: Color = img.get_pixel(point.x, point.y)
		assert_int(int(round(color.a * 255.0))).override_failure_message(
				"fx_battle_range.png (%d,%d) 像素应全不透明" % [point.x, point.y]) \
				.is_equal(255)
		assert_bool(is_equal_approx(color.r, color.g) \
				and is_equal_approx(color.g, color.b)).override_failure_message(
				"fx_battle_range.png (%d,%d) 像素应通道中性" % [point.x, point.y]).is_true()
