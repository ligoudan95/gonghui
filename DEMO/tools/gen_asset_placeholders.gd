## M6 批 3.5a 占位资产生成器（tools/gen_asset_placeholders.gd）
## 职责：为 art_spec 01-10 组盘点的全部 64 件新增资产 id 中的 62 件（字体 2 件
## font_cn_body/font_cn_title 无法程序造 ttf：跳过生成与 registry/naming 登记，
## 字体接线留素材到位后）程序化生成占位 PNG——按分组目录落盘 assets/bg|tiles|
## icons|ui|fx + AssetRegistry 增键 + naming_registry 增条（domain=&"assets"）
## 三同步；幂等重跑零 diff（像素确定性生成 + 登记只补缺、无缺不落盘）。
## 占位规格按组：bg 1920×1080 组色渐变 / tile 128×128 程序纹样（物件件带
## 中心母题）/ icon 64×64 透明底简单形状 / ui 件按 08 组规格（面板 96×96、
## 按钮三态 128×64、四档标签 96×48）/ fx 按各组尺寸（迷雾 512×512、战棋
## 叠加 128×128、D20 256×256）。
## 另登记 ui_main_theme（assets/ui/main_theme.tres）——theme 由 project.godot
## [gui] theme/custom 直引路径消费，registry 登记仅为 V-R4-asset-reverse
## assets 目录反查闭合（直引路径豁免注记归 docs）。
## 用法：godot --headless -s res://tools/gen_asset_placeholders.gd
##   （生成后需跑 godot --headless --import 产出 .import 方可运行时加载）
## 替换：正式素材按资产 id 原位替换零改码（gen_unit_anim_frames 先例模式）。
extends SceneTree

## AssetRegistry 路径
const REGISTRY_PATH: String = "res://data/assets/registry.tres"
## naming_registry 路径
const NAMING_PATH: String = "res://data/core/naming_registry.tres"
## 主题登记键与路径（V-R4 反查闭合——见文件头注）
const THEME_ID: StringName = &"ui_main_theme"
const THEME_PATH: String = "res://assets/ui/main_theme.tres"

## 占位资产规格表：id -> {group/size/kind/base/accent/name}
## （art_spec 01-09 组 v1.1 盘点单源；色值对齐 00_全局风格约束统一色板）
const SPECS: Dictionary = {
	# ---- 01 背景组（6 件·1920×1080·组色 = 公会系暖 / 矿洞系冷）----
	"bg_association_hall": {"group": "bg", "size": Vector2i(1920, 1080), "kind": "bg",
			"base": Color(0.545, 0.353, 0.235), "accent": Color(0.91, 0.85, 0.71),
			"name": "冒险者协会入口·背景"},
	"bg_dormitory": {"group": "bg", "size": Vector2i(1920, 1080), "kind": "bg",
			"base": Color(0.486, 0.31, 0.2), "accent": Color(0.878, 0.482, 0.224),
			"name": "宿舍设施场景·背景"},
	"bg_training_ground": {"group": "bg", "size": Vector2i(1920, 1080), "kind": "bg",
			"base": Color(0.541, 0.416, 0.259), "accent": Color(0.29, 0.482, 0.651),
			"name": "训练场设施场景·背景"},
	"bg_title": {"group": "bg", "size": Vector2i(1920, 1080), "kind": "bg",
			"base": Color(0.431, 0.29, 0.208), "accent": Color(0.961, 0.784, 0.412),
			"name": "标题屏背景"},
	"bg_battle_mine": {"group": "bg", "size": Vector2i(1920, 1080), "kind": "bg",
			"base": Color(0.243, 0.271, 0.314), "accent": Color(0.878, 0.482, 0.224),
			"name": "战斗屏矿洞环境·背景"},
	"bg_explore": {"group": "bg", "size": Vector2i(1920, 1080), "kind": "bg",
			"base": Color(0.18, 0.2, 0.231), "accent": Color(0.243, 0.271, 0.314),
			"name": "探索屏环境·背景"},
	# ---- 02 矿洞 tile 组（9 件·128×128）----
	"tile_mine_floor_01": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile",
			"base": Color(0.353, 0.392, 0.447), "accent": Color(0.243, 0.271, 0.314),
			"name": "矿洞地面·基岩"},
	"tile_mine_floor_02": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile",
			"base": Color(0.337, 0.376, 0.431), "accent": Color(0.29, 0.333, 0.408),
			"name": "矿洞地面·碎石变体"},
	"tile_mine_wall": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile",
			"base": Color(0.243, 0.271, 0.314), "accent": Color(0.165, 0.184, 0.22),
			"name": "岩壁 tile"},
	"tile_mine_rock": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile_motif",
			"base": Color(0.29, 0.322, 0.376), "accent": Color(0.243, 0.271, 0.314),
			"name": "障碍·塌方碎石堆"},
	"tile_mine_cart": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile_motif",
			"base": Color(0.431, 0.29, 0.208), "accent": Color(0.659, 0.518, 0.235),
			"name": "障碍·废弃矿车"},
	"tile_battle_bush": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile",
			"base": Color(0.298, 0.478, 0.22), "accent": Color(0.486, 0.659, 0.353),
			"name": "战棋草丛 tile"},
	"tile_battle_highground": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile_motif",
			"base": Color(0.69, 0.604, 0.282), "accent": Color(0.541, 0.463, 0.22),
			"name": "战棋高地 tile"},
	"tile_battle_poison_swamp": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile",
			"base": Color(0.478, 0.18, 0.208), "accent": Color(0.298, 0.604, 0.373),
			"name": "战棋毒沼 tile"},
	"tile_battle_trap": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile_motif",
			"base": Color(0.333, 0.376, 0.451), "accent": Color(0.878, 0.482, 0.224),
			"name": "战棋陷阱 tile"},
	# ---- 03 村子 tile 组（7 件·128×128）----
	"tile_village_grass_01": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile",
			"base": Color(0.486, 0.659, 0.353), "accent": Color(0.369, 0.541, 0.267),
			"name": "草地·基色"},
	"tile_village_grass_02": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile_motif",
			"base": Color(0.455, 0.627, 0.322), "accent": Color(0.831, 0.686, 0.216),
			"name": "草地·野花变体"},
	"tile_village_path": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile",
			"base": Color(0.725, 0.608, 0.42), "accent": Color(0.588, 0.474, 0.306),
			"name": "土路 tile"},
	"tile_village_well": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile_motif",
			"base": Color(0.541, 0.561, 0.596), "accent": Color(0.431, 0.29, 0.208),
			"name": "水井 tile"},
	"tile_village_house": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile_motif",
			"base": Color(0.769, 0.635, 0.396), "accent": Color(0.431, 0.29, 0.208),
			"name": "农舍 tile"},
	"tile_village_tree_01": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile_motif",
			"base": Color(0.306, 0.478, 0.227), "accent": Color(0.431, 0.29, 0.208),
			"name": "树木·阔叶单株"},
	"tile_village_tree_02": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile_motif",
			"base": Color(0.275, 0.439, 0.208), "accent": Color(0.431, 0.29, 0.208),
			"name": "树木·双株变体"},
	# ---- 05 小队与交互图标组（6 图标 + 暗门 tile 1·见上 tiles 组）----
	"tile_secret_passage": {"group": "tiles", "size": Vector2i(128, 128), "kind": "tile_motif",
			"base": Color(0.243, 0.271, 0.314), "accent": Color(0.961, 0.784, 0.412),
			"name": "暗门开启窄道 tile"},
	"icon_explore_party": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.239, 0.49, 0.784), "accent": Color(0.91, 0.941, 0.98),
			"name": "探索小队标记"},
	"icon_pt_event": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.91, 0.85, 0.71), "accent": Color(0.831, 0.686, 0.216),
			"name": "事件点图标"},
	"icon_pt_treasure": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.545, 0.353, 0.235), "accent": Color(0.831, 0.686, 0.216),
			"name": "宝箱图标"},
	"icon_pt_target": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.239, 0.49, 0.784), "accent": Color(0.545, 0.353, 0.235),
			"name": "委托目标点图标"},
	"icon_pt_exit": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.353, 0.392, 0.447), "accent": Color(0.961, 0.784, 0.412),
			"name": "出口图标"},
	"icon_pt_battle": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.541, 0.561, 0.596), "accent": Color(0.545, 0.353, 0.235),
			"name": "必然遭遇点图标"},
	# ---- 07 系统图标组（19 件·64×64）----
	"icon_res_gold": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.831, 0.686, 0.216), "accent": Color(0.545, 0.353, 0.235),
			"name": "货币图标"},
	"icon_res_exp": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.169, 0.227, 0.404), "accent": Color(0.961, 0.784, 0.412),
			"name": "经验图标"},
	"icon_res_repu": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.831, 0.686, 0.216), "accent": Color(0.239, 0.49, 0.784),
			"name": "声望图标"},
	"icon_attr_str": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.627, 0.322, 0.176), "accent": Color(0.878, 0.482, 0.224),
			"name": "力量图标"},
	"icon_attr_agi": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.298, 0.604, 0.624), "accent": Color(0.91, 0.941, 0.98),
			"name": "敏捷图标"},
	"icon_attr_con": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.545, 0.353, 0.235), "accent": Color(0.659, 0.518, 0.235),
			"name": "体质图标"},
	"icon_attr_int": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.169, 0.227, 0.404), "accent": Color(0.831, 0.686, 0.216),
			"name": "智力图标"},
	"icon_attr_wis": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.831, 0.686, 0.216), "accent": Color(0.961, 0.914, 0.784),
			"name": "感知图标"},
	"icon_attr_wil": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.369, 0.247, 0.51), "accent": Color(0.831, 0.686, 0.216),
			"name": "意志图标"},
	"icon_attr_luk": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.486, 0.659, 0.353), "accent": Color(0.961, 0.784, 0.412),
			"name": "幸运图标"},
	"icon_res_hp": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.753, 0.224, 0.169), "accent": Color(0.91, 0.85, 0.71),
			"name": "生命图标"},
	"icon_res_mp": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.239, 0.49, 0.784), "accent": Color(0.91, 0.941, 0.98),
			"name": "法力图标"},
	"icon_res_sp": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.878, 0.722, 0.294), "accent": Color(0.961, 0.914, 0.784),
			"name": "精力图标"},
	"icon_class_warrior": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.29, 0.482, 0.651), "accent": Color(0.91, 0.941, 0.98),
			"name": "战士图标"},
	"icon_class_rogue": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.369, 0.247, 0.51), "accent": Color(0.91, 0.941, 0.98),
			"name": "盗贼图标"},
	"icon_class_mage": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.169, 0.227, 0.404), "accent": Color(0.878, 0.482, 0.224),
			"name": "法师图标"},
	"icon_class_priest": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.949, 0.918, 0.847), "accent": Color(0.831, 0.686, 0.216),
			"name": "牧师图标"},
	"icon_class_ranger": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.243, 0.42, 0.29), "accent": Color(0.91, 0.85, 0.71),
			"name": "游侠图标"},
	"icon_class_arcanist": {"group": "icons", "size": Vector2i(64, 64), "kind": "icon",
			"base": Color(0.478, 0.18, 0.208), "accent": Color(0.831, 0.686, 0.216),
			"name": "奇术师图标"},
	# ---- 08 UI 基础件组（8 件）----
	"ui_panel_ninepatch": {"group": "ui", "size": Vector2i(96, 96), "kind": "panel",
			"base": Color(0.149, 0.169, 0.22, 0.85), "accent": Color(0.659, 0.518, 0.235),
			"name": "面板九宫格母图"},
	"ui_button_normal": {"group": "ui", "size": Vector2i(128, 64), "kind": "button",
			"base": Color(0.91, 0.85, 0.71), "accent": Color(0.659, 0.518, 0.235),
			"name": "主按钮·常态"},
	"ui_button_hover": {"group": "ui", "size": Vector2i(128, 64), "kind": "button",
			"base": Color(0.965, 0.925, 0.82), "accent": Color(0.961, 0.784, 0.412),
			"name": "主按钮·悬停态"},
	"ui_button_disabled": {"group": "ui", "size": Vector2i(128, 64), "kind": "button",
			"base": Color(0.478, 0.545, 0.627, 0.8), "accent": Color(0.33, 0.36, 0.42),
			"name": "主按钮·禁用态"},
	"ui_label_result_crit_success": {"group": "ui", "size": Vector2i(96, 48), "kind": "label",
			"base": Color(0.831, 0.686, 0.216), "accent": Color(0.545, 0.42, 0.12),
			"name": "大成功标签底"},
	"ui_label_result_success": {"group": "ui", "size": Vector2i(96, 48), "kind": "label",
			"base": Color(0.298, 0.604, 0.373), "accent": Color(0.18, 0.42, 0.24),
			"name": "成功标签底"},
	"ui_label_result_failure": {"group": "ui", "size": Vector2i(96, 48), "kind": "label",
			"base": Color(0.478, 0.545, 0.627), "accent": Color(0.33, 0.38, 0.45),
			"name": "失败标签底"},
	"ui_label_result_crit_failure": {"group": "ui", "size": Vector2i(96, 48), "kind": "label",
			"base": Color(0.69, 0.227, 0.227), "accent": Color(0.45, 0.13, 0.13),
			"name": "大失败标签底"},
	# ---- 06 迷雾组（2 件·512×512）+ 09 战棋叠加与 D20 组（4 件）----
	# 迷雾/范围两键（中2/中3 修复口径）：中性白灰 + 全不透明（α=1.0）——
	# 色相与净遮蔽 α 完全由运行时 modulate（cfg 色）承载，纹理不再自带 α 参与
	# 相乘（旧版自带 α 与 modulate α 双乘致净观感偏离 cfg 调定值）
	"fx_fog_unseen": {"group": "fx", "size": Vector2i(512, 512), "kind": "fog",
			"base": Color(1, 1, 1, 1.0), "accent": Color(0.82, 0.82, 0.82, 1.0),
			"name": "未探索浓雾贴图"},
	"fx_fog_dim": {"group": "fx", "size": Vector2i(512, 512), "kind": "fog",
			"base": Color(1, 1, 1, 1.0), "accent": Color(0.72, 0.72, 0.72, 1.0),
			"name": "已探索暗态滤镜"},
	"fx_battle_select": {"group": "fx", "size": Vector2i(128, 128), "kind": "select",
			"base": Color(0.961, 0.784, 0.412, 0.9), "accent": Color(0.961, 0.784, 0.412, 0.9),
			"name": "选中框叠加件"},
	"fx_battle_range": {"group": "fx", "size": Vector2i(128, 128), "kind": "range",
			"base": Color(1, 1, 1, 1.0), "accent": Color(0.78, 0.78, 0.78, 1.0),
			"name": "范围指示格面"},
	"fx_battle_path_arrow": {"group": "fx", "size": Vector2i(128, 128), "kind": "arrow",
			"base": Color(0.961, 0.784, 0.412, 0.8), "accent": Color(0.45, 0.34, 0.1, 0.9),
			"name": "路径箭头"},
	"fx_d20": {"group": "fx", "size": Vector2i(256, 256), "kind": "d20",
			"base": Color(0.353, 0.392, 0.447), "accent": Color(0.961, 0.784, 0.412),
			"name": "D20 骰面"},
}

## 前缀 -> naming rule_note（资产条目登记注记——按分组规格单源）
const RULE_NOTES: Dictionary = {
	"bg_": "bg_<场景名>：场景背景图（M6 批 3.5a 占位——程序色块 1920×1080；正式素材同 id 原位替换）",
	"tile_": "tile_<语义>：地形/物件 tile（M6 批 3.5a 占位——程序纹样 128×128；正式素材同 id 原位替换）",
	"icon_": "icon_<语义>：图标（M6 批 3.5a 占位——简单形状 64×64 透明底；正式素材同 id 原位替换）",
	"ui_": "ui_<语义>：UI 母图（M6 批 3.5a 占位——程序样式；正式素材同 id 原位替换）",
	"fx_": "fx_<语义>：迷雾/叠加/演出件（M6 批 3.5a 占位——程序纹理；正式素材同 id 原位替换）",
}

func _initialize() -> void:
	## MainLoop 回调：62 件占位 PNG 生成（中1 防覆写：文件已存在即跳过——
	## 生成与登记两侧对齐「只补缺」）→ registry/naming 增量同步（只补缺）
	## 参数：无
	## 返回：无（任一步失败按退出码 1 结束）
	var ok: bool = true
	for asset_id: String in SPECS:
		ok = _GeneratePlaceholder(asset_id, SPECS[asset_id]) and ok
	if ok:
		ok = _SyncAssetRegistry()
	if ok:
		ok = _SyncNamingRegistry()
	if ok:
		print("gen_asset_placeholders: 生成完成（落盘 %d 件、跳过已存在 %d 件 + registry/naming 增量同步）" % [
				SPECS.size() - _skip_count, _skip_count])
		quit(0)
	else:
		printerr("gen_asset_placeholders: 存在失败项，详见上方输出")
		quit(1)

## 本轮已存在跳过计数（中1 防覆写——只补缺口径的运行证据）
var _skip_count: int = 0

func _GeneratePlaceholder(asset_id: String, spec: Dictionary) -> bool:
	## 单件占位图生成（确定性像素——同入参重跑字节级一致）；中1 防覆写：
	## 目标文件已存在即跳过（FileAccess.file_exists——正式素材同 id 原位
	## 替换后重跑本工具不覆写，占位不再吃掉正式素材）
	## 参数 asset_id：资产 id；spec：规格（group/size/kind/base/accent/name）
	## 返回：true = 保存成功或已存在跳过
	var path: String = "res://assets/%s/%s.png" % [String(spec["group"]), asset_id]
	if FileAccess.file_exists(path):
		_skip_count += 1
		print("gen_asset_placeholders: 跳过已存在 %s（只补缺——不覆写既有文件）" % path)
		return true
	var size: Vector2i = spec["size"]
	# 分组目录懒建（首次运行 assets/tiles|icons|ui|fx 不存在——save_png 不建目录）
	var dir_path: String = "res://assets/%s" % String(spec["group"])
	DirAccess.make_dir_recursive_absolute(dir_path)
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var seed_value: int = asset_id.hash()
	match String(spec["kind"]):
		"bg":
			_ComposeBg(img, spec)
		"tile":
			_ComposeTile(img, spec, seed_value, false)
		"tile_motif":
			_ComposeTile(img, spec, seed_value, true)
		"icon":
			_ComposeIcon(img, spec)
		"panel":
			_ComposePanel(img, spec)
		"button":
			_ComposeButton(img, spec)
		"label":
			_ComposeLabel(img, spec)
		"fog":
			_ComposeFog(img, spec, seed_value)
		"select":
			_ComposeSelect(img, spec)
		"range":
			_ComposeRange(img, spec)
		"arrow":
			_ComposeArrow(img, spec)
		"d20":
			_ComposeD20(img, spec)
		_:
			printerr("gen_asset_placeholders: 未知占位 kind '%s'（%s）" % [spec["kind"], asset_id])
			return false
	var err: Error = img.save_png(path)
	if err != OK:
		printerr("gen_asset_placeholders: 保存失败 %s（错误码 %d）" % [path, err])
		return false
	print("gen_asset_placeholders: %s（%s，%d×%d）" % [path, spec["name"], size.x, size.y])
	return true

# --------------------------------------------------------------------------
# 分组占位合成（全部确定性像素——无随机源，幂等重跑零 diff）
# --------------------------------------------------------------------------

func _ComposeBg(img: Image, spec: Dictionary) -> void:
	## 背景组：组色纵向渐变（12 段带状插值）+ 底部压暗带（UI 安全区提示）+
	## accent 斜向细纹（暖色点光/冷色矿纹意象）
	## 参数 img：目标图；spec：规格
	## 返回：无
	var base: Color = spec["base"]
	var accent: Color = spec["accent"]
	var width: int = img.get_width()
	var height: int = img.get_height()
	var bands: int = 12
	var band_height: int = height / bands
	for band: int in bands:
		var t: float = float(band) / float(bands - 1)
		var band_color: Color = base.lerp(base.darkened(0.35), t)
		img.fill_rect(Rect2i(0, band * band_height, width, band_height), band_color)
	# 底部压暗带（下边状态条 UI 安全区）
	img.fill_rect(Rect2i(0, height - 140, width, 140), Color(0, 0, 0, 0.28))
	# 斜向细纹（64px 间隔——低频不抢 UI；向 accent 色轻插值保持不透明底）
	for offset: int in range(-height, width, 64):
		for step_px: int in height:
			var x: int = offset + step_px
			if x >= 0 and x < width:
				var existing: Color = img.get_pixel(x, step_px)
				img.set_pixel(x, step_px, existing.lerp(
						Color(accent.r, accent.g, accent.b, existing.a), 0.06))

func _ComposeTile(img: Image, spec: Dictionary, seed_value: int, motif: bool) -> void:
	## tile 组：底色 + 确定性斑点纹样（碎石/草簇意象）+ 深色描边；物件件
	## （motif=true）加中心母题块（物件剪影占位）
	## 参数 img：目标图；spec：规格；seed_value：确定性种子；motif：物件件标记
	## 返回：无
	var base: Color = spec["base"]
	var accent: Color = spec["accent"]
	var width: int = img.get_width()
	var height: int = img.get_height()
	img.fill(base)
	for y: int in height:
		for x: int in width:
			var h: int = _Hash2(x, y, seed_value)
			if h % 100 < 7:
				img.set_pixel(x, y, base.darkened(0.22))
			elif h % 100 < 11:
				img.set_pixel(x, y, accent.lightened(0.12))
	if motif:
		# 中心母题：accent 内块 + 深色内缘（物件剪影占位——正式件替换）
		var inset: int = 34
		img.fill_rect(Rect2i(inset, inset, width - inset * 2, height - inset * 2), accent)
		var inner: int = inset + 8
		img.fill_rect(Rect2i(inner, inner, width - inner * 2, height - inner * 2),
				accent.darkened(0.15))
	# 深色描边（格界辨识）
	_DrawBorder(img, base.darkened(0.4), 3)

func _ComposeIcon(img: Image, spec: Dictionary) -> void:
	## 图标组：透明底 + 圆形衬底（base）+ 内圆（accent）+ 深色外描——简单形状占位
	## 参数 img：目标图；spec：规格
	## 返回：无
	var base: Color = spec["base"]
	var accent: Color = spec["accent"]
	var cx: float = float(img.get_width()) * 0.5
	var cy: float = float(img.get_height()) * 0.5
	for y: int in img.get_height():
		for x: int in img.get_width():
			var dist: float = Vector2(float(x) - cx, float(y) - cy).length()
			if dist <= 26.0 and dist > 23.0:
				img.set_pixel(x, y, base.darkened(0.45))
			elif dist <= 23.0 and dist > 11.0:
				img.set_pixel(x, y, base)
			elif dist <= 11.0:
				img.set_pixel(x, y, accent)

func _ComposePanel(img: Image, spec: Dictionary) -> void:
	## UI 面板九宫格：深色半透明底 + 金属包边描边 + 四角包角件（24px 九宫格切角
	## 语义——四角区域完整自包含，中段拉伸占位）
	## 参数 img：目标图；spec：规格
	## 返回：无
	img.fill(spec["base"])
	_DrawBorder(img, spec["accent"], 4)
	var trim: Color = spec["accent"].lightened(0.25)
	img.fill_rect(Rect2i(4, 4, 20, 4), trim)
	img.fill_rect(Rect2i(4, 4, 4, 20), trim)
	img.fill_rect(Rect2i(img.get_width() - 24, 4, 20, 4), trim)
	img.fill_rect(Rect2i(img.get_width() - 8, 4, 4, 20), trim)
	img.fill_rect(Rect2i(4, img.get_height() - 8, 20, 4), trim)
	img.fill_rect(Rect2i(4, img.get_height() - 24, 4, 20), trim)
	img.fill_rect(Rect2i(img.get_width() - 24, img.get_height() - 8, 20, 4), trim)
	img.fill_rect(Rect2i(img.get_width() - 8, img.get_height() - 24, 4, 20), trim)

func _ComposeButton(img: Image, spec: Dictionary) -> void:
	## UI 按钮三宫格：面底（base）+ 描边（accent）+ 左右 24px 端帽压暗（端帽
	## 暖木纹意象占位——中段横向拉伸语义）
	## 参数 img：目标图；spec：规格
	## 返回：无
	img.fill(spec["base"])
	_DrawBorder(img, spec["accent"], 3)
	var cap: Color = Color(spec["base"].r, spec["base"].g, spec["base"].b, 1.0).darkened(0.18)
	img.fill_rect(Rect2i(6, 3, 18, img.get_height() - 6), cap)
	img.fill_rect(Rect2i(img.get_width() - 24, 3, 18, img.get_height() - 6), cap)

func _ComposeLabel(img: Image, spec: Dictionary) -> void:
	## UI 四档反馈标签：色底（base）+ 描边（accent）+ 切角（占位造型）
	## 参数 img：目标图；spec：规格
	## 返回：无
	img.fill(spec["base"])
	_DrawBorder(img, spec["accent"], 2)
	var notch: int = 6
	for step_px: int in notch:
		img.fill_rect(Rect2i(step_px, step_px, 2, 2), Color(0, 0, 0, 0))
		img.fill_rect(Rect2i(img.get_width() - 2 - step_px, step_px, 2, 2), Color(0, 0, 0, 0))

func _ComposeFog(img: Image, spec: Dictionary, seed_value: int) -> void:
	## 迷雾组（中2 修复口径）：中性白底（全不透明 α=1.0）+ 确定性灰度雾团噪声
	##（亮度差承载纹理感——纹样可见性与格内变化）；色相与净遮蔽 α 完全由
	## 运行时 modulate（cfg 色）承载。旧版底色自带 α0.92/0.55 与 modulate α
	## 相乘（0.92×0.92/0.55×0.55）——净观感偏离 cfg 调定值，已废
	## 参数 img：目标图；spec：规格（base/accent 中性白灰）；seed_value：确定性种子
	## 返回：无
	var base: Color = spec["base"]
	var accent: Color = spec["accent"]
	img.fill(base)
	for y: int in img.get_height():
		for x: int in img.get_width():
			var h: int = _Hash2(x / 8, y / 8, seed_value)
			if h % 100 < 16:
				var lift: float = float(h % 7) * 0.012
				img.set_pixel(x, y, Color(
						clampf(accent.r - lift, 0.0, 1.0),
						clampf(accent.g - lift, 0.0, 1.0),
						clampf(accent.b - lift, 0.0, 1.0), 1.0))

func _ComposeSelect(img: Image, spec: Dictionary) -> void:
	## 选中框叠加件：中央镂空 + 四角灯火黄角括（24px 臂长/6px 粗——不遮单位）
	## 参数 img：目标图；spec：规格
	## 返回：无
	var color: Color = spec["base"]
	var arm: int = 24
	var thick: int = 6
	var size: int = img.get_width()
	img.fill_rect(Rect2i(0, 0, arm, thick), color)
	img.fill_rect(Rect2i(0, 0, thick, arm), color)
	img.fill_rect(Rect2i(size - arm, 0, arm, thick), color)
	img.fill_rect(Rect2i(size - thick, 0, thick, arm), color)
	img.fill_rect(Rect2i(0, size - thick, arm, thick), color)
	img.fill_rect(Rect2i(0, size - arm, thick, arm), color)
	img.fill_rect(Rect2i(size - arm, size - thick, arm, thick), color)
	img.fill_rect(Rect2i(size - thick, size - arm, thick, arm), color)

func _ComposeRange(img: Image, spec: Dictionary) -> void:
	## 范围指示格面（中3 修复口径）：全不透明中性白填充（α=1.0）+ 灰细描边
	##（格界辨识——亮度差）；运行时 modulate=cfg 填充色染色（净 α 完全由
	## modulate 承载 = cfg 调定值）。旧版自带 α0.18 与 modulate α0.10 双乘
	## 净观感仅 0.018——cfg 失真，已废
	## 参数 img：目标图；spec：规格（base/accent 中性白灰全不透明）
	## 返回：无
	img.fill(spec["base"])
	_DrawBorder(img, spec["accent"], 3)

func _ComposeArrow(img: Image, spec: Dictionary) -> void:
	## 路径箭头：右向单箭头（灯火黄箭身 + 深描边）——旋转 ±90°/180° 复用基准；
	## 几何：箭身 x ∈ [12, 68] 半高 12 + 三角头 x ∈ (68, 112] 自半高 30 收敛至尖
	## 参数 img：目标图；spec：规格
	## 返回：无
	var body: Color = spec["base"]
	var outline: Color = spec["accent"]
	var width: int = img.get_width()
	var height: int = img.get_height()
	var mid_y: float = float(height) * 0.5
	var shaft_x0: int = 12
	var shaft_x1: int = 68
	var tip_x: int = 112
	var shaft_half: float = 12.0
	var head_half: float = 30.0
	for y: int in height:
		for x: int in width:
			var half: float = -1.0
			if x >= shaft_x0 and x <= shaft_x1:
				half = shaft_half
			elif x > shaft_x1 and x <= tip_x:
				half = head_half * float(tip_x - x) / float(tip_x - shaft_x1)
			if half >= 0.0 and absf(float(y) - mid_y) <= half:
				img.set_pixel(x, y, body)
	# 描边（沿箭身/箭头上下缘一行 + 尾部封边）
	for x: int in range(shaft_x0, tip_x + 1):
		var half: float = shaft_half if x <= shaft_x1 \
				else head_half * float(tip_x - x) / float(tip_x - shaft_x1)
		var top: int = int(mid_y - half) - 1
		var bottom: int = int(mid_y + half) + 1
		if top >= 0:
			img.set_pixel(x, top, outline)
		if bottom < height:
			img.set_pixel(x, bottom, outline)
	for dy: int in range(-int(shaft_half) - 1, int(shaft_half) + 2):
		var y_edge: int = int(mid_y) + dy
		if y_edge >= 0 and y_edge < height:
			img.set_pixel(shaft_x0 - 1, y_edge, outline)

func _ComposeD20(img: Image, spec: Dictionary) -> void:
	## D20 骰面：居中六边形骰体（冷蓝灰面 + 灯火黄棱线高光）——骰面数字
	## 程序渲染占位（正式件同 id 替换）
	## 参数 img：目标图；spec：规格
	## 返回：无
	var base: Color = spec["base"]
	var edge: Color = spec["accent"]
	var size: int = img.get_width()
	var cx: float = float(size) * 0.5
	var cy: float = float(size) * 0.5
	for y: int in size:
		for x: int in size:
			var dist: float = absf(float(x) - cx) / 0.87 + absf(float(y) - cy)
			if dist <= 96.0 and dist > 90.0:
				img.set_pixel(x, y, edge)
			elif dist <= 90.0:
				img.set_pixel(x, y, base)
	# 内棱线（简化二十面意象——水平中线 + 两条斜线）
	for x: int in range(int(cx) - 78, int(cx) + 78):
		img.set_pixel(x, int(cy), edge)
	for step_px: int in range(-60, 61):
		var x_top: int = int(cx) + step_px
		var y_top: int = int(cy - step_px * 0.55)
		if x_top >= 0 and x_top < size and y_top >= 0 and y_top < size:
			img.set_pixel(x_top, y_top, edge)

# --------------------------------------------------------------------------
# 登记同步（增量补缺——无缺不落盘，幂等零 diff）
# --------------------------------------------------------------------------

func _SyncAssetRegistry() -> bool:
	## 同步 AssetRegistry：62 键 PNG 映射 + ui_main_theme 主题键（V-R4 反查闭合）
	## 只补缺——已齐时不保存（重跑零 diff）；**保留既有 comment**（顺手2——
	## naming 侧同口径：comment 是人工演进的历史叙述，工具只同步条目不动
	## comment 字段；仅 registry 首建 comment 为空时写入批次注记）
	## 参数：无
	## 返回：true = 成功（或无需落盘）
	var registry: AssetRegistry = null
	if ResourceLoader.exists(REGISTRY_PATH):
		registry = load(REGISTRY_PATH) as AssetRegistry
	if registry == null:
		registry = AssetRegistry.new()
	var added: int = 0
	for asset_id: String in SPECS:
		var key: StringName = StringName(asset_id)
		if registry.mapping.has(key):
			continue
		registry.mapping[key] = "res://assets/%s/%s.png" % [String(SPECS[asset_id]["group"]), asset_id]
		added += 1
	if not registry.mapping.has(THEME_ID):
		registry.mapping[THEME_ID] = THEME_PATH
		added += 1
	if added == 0:
		print("gen_asset_placeholders: AssetRegistry 已齐（%d 键）——无需落盘" % registry.mapping.size())
		return true
	# 顺手2：仅首建写入（comment 空 = registry 新建）——既有 comment 保留不覆写
	if String(registry.comment).is_empty():
		registry.comment = "【占位·资产登记】spr_* = M6 批 1 单位六动作竖条；bg_/tile_/icon_/ui_/fx_* = M6 批 3.5a 占位资产（tools/gen_asset_placeholders.gd 程序化生成，可重复执行）；ui_main_theme = 全局 UI 主题（project.godot [gui] 直引路径消费，登记仅为 assets 目录反查闭合）；正式素材按资产 id 原位替换"
	var err: Error = ResourceSaver.save(registry, REGISTRY_PATH)
	if err != OK:
		printerr("gen_asset_placeholders: registry 保存失败 %s（错误码 %d）" % [REGISTRY_PATH, err])
		return false
	print("gen_asset_placeholders: AssetRegistry 增 %d 键（现共 %d 键）" % [added, registry.mapping.size()])
	return true

func _SyncNamingRegistry() -> bool:
	## 同步 naming_registry：62 条资产条目 + ui_main_theme 条目（domain=&"assets"）
	## 只补缺——已齐时不保存（重跑零 diff）；**保留既有 comment**（低3 先例：
	## comment 是人工演进的历史叙述，工具只同步条目不动 comment 字段）
	## 参数：无
	## 返回：true = 成功（或无需落盘）
	var naming: NamingRegistry = null
	if ResourceLoader.exists(NAMING_PATH):
		naming = load(NAMING_PATH) as NamingRegistry
	if naming == null:
		printerr("gen_asset_placeholders: naming_registry 缺失 %s" % NAMING_PATH)
		return false
	var existing: Dictionary = {}
	for entry: NamingEntry in naming.entries:
		existing[entry.resource_id] = true
	var added: int = 0
	for asset_id: String in SPECS:
		var key: StringName = StringName(asset_id)
		if existing.has(key):
			continue
		var entry := NamingEntry.new()
		entry.resource_id = key
		entry.domain = &"assets"
		entry.display_name = String(SPECS[asset_id]["name"])
		entry.rule_note = _RuleNoteOf(asset_id)
		naming.entries.append(entry)
		added += 1
	if not existing.has(THEME_ID):
		var theme_entry := NamingEntry.new()
		theme_entry.resource_id = THEME_ID
		theme_entry.domain = &"assets"
		theme_entry.display_name = "全局 UI 主题"
		theme_entry.rule_note = "ui_<语义>：UI 主题资源（M6 批 3.5a；project.godot [gui] theme/custom 直引路径消费，registry 登记仅为 assets 目录反查闭合——直引路径豁免注记归 docs）"
		naming.entries.append(theme_entry)
		added += 1
	if added == 0:
		print("gen_asset_placeholders: naming_registry 已齐（%d 条）——无需落盘" % naming.entries.size())
		return true
	var err: Error = ResourceSaver.save(naming, NAMING_PATH)
	if err != OK:
		printerr("gen_asset_placeholders: naming_registry 保存失败 %s（错误码 %d）" % [NAMING_PATH, err])
		return false
	print("gen_asset_placeholders: naming_registry 增 %d 条（现共 %d 条；comment 未改动）" % [
			added, naming.entries.size()])
	return true

func _RuleNoteOf(asset_id: String) -> String:
	## 资产 id → 分组 rule_note（前缀最长匹配——tile_battle_* 归 tile_ 组）
	## 参数 asset_id：资产 id
	## 返回：rule_note 文本
	for prefix: String in RULE_NOTES:
		if asset_id.begins_with(prefix):
			return String(RULE_NOTES[prefix])
	return "assets 域登记键（M6 批 3.5a 占位；正式素材同 id 原位替换）"

# --------------------------------------------------------------------------
# 确定性像素辅助（无随机源——幂等重跑字节级一致）
# --------------------------------------------------------------------------

func _Hash2(x: int, y: int, seed_value: int) -> int:
	## 二维确定性散列（坐标混排 + xorshift 折叠——占位纹样种子）
	## 参数 x/y：像素坐标；seed_value：资产 id 哈希种子
	## 返回：非负散列值
	var h: int = (x * 374761393 + y * 668265263 + seed_value * 1274126177) & 0x7FFFFFFF
	h = (h ^ (h >> 13)) & 0x7FFFFFFF
	h = (h * 1274126177) & 0x7FFFFFFF
	return (h ^ (h >> 16)) & 0x7FFFFFFF

func _DrawBorder(img: Image, color: Color, width_px: int) -> void:
	## 四边描边（占位格界/包边意象）
	## 参数 img：目标图；color：描边色；width_px：粗细
	## 返回：无
	var w: int = img.get_width()
	var h: int = img.get_height()
	img.fill_rect(Rect2i(0, 0, w, width_px), color)
	img.fill_rect(Rect2i(0, h - width_px, w, width_px), color)
	img.fill_rect(Rect2i(0, 0, width_px, h), color)
	img.fill_rect(Rect2i(w - width_px, 0, width_px, h), color)
