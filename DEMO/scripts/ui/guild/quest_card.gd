## 委托卡（QuestCard，代码构建 UI 组件）
## 职责：单份板上委托的卡片展示——名称（含加急前缀）/等级档/剩余天数/
## 推荐属性/人力区间/目标区域/奖励预览/发布人；接取按钮经信号回抛。
## 数据来源：案 6 §2.4（推荐编队信息显示）/案 18 §2.6（板刷字段）；
## UI 规范：UiTheme 深底面板/字号档位/color_of·font_of 读取口（零硬编码样式）。
class_name QuestCard
extends PanelContainer

## 推荐属性中文映射（UI 层语言常量——AttrKeys id -> 展示名）
const ATTR_NAMES: Dictionary = {
	&"strength": "力量", &"agility": "敏捷", &"constitution": "体质",
	&"intelligence": "智力", &"perception": "感知", &"willpower": "意志",
	&"luck": "幸运",
}

## UI 文案单源（M4 增补批：轻度信息行格式串；M6 批 2 挂账 4.2：内联 UI
## 中文收编——改措辞只动此处；M6 批 3.5b 组 6：奖励分段格式串——贴图态
## 三图标分段，缺件态维持整行 reward_format 现状）
const UI_TEXTS: Dictionary = {
	&"accept_button": "接单",
	&"title_format": "%s（等级 %d）",
	&"info_format": "剩余 %d 天｜推荐：%s｜人力 %d-%d｜区域：%s",
	&"reward_format": "奖励：%d 金 / %d 经验 / %d 声望",
	&"reward_none": "奖励：—",
	&"desc_format": "%s：%s",
	&"light_info_format": "剩余 %d 天｜派 %d-%d 人 · 工期 %d 天 · 无需出征",
	&"reward_title": "奖励：",
	&"reward_gold_format": "%d 金",
	&"reward_exp_format": "%d 经验",
	&"reward_repu_format": "%d 声望",
}

## 奖励行三段图标资产 id（组 6：金/经验/声望——AssetTex 单源解析；
## 三键全缺件时奖励行维持现状整行文本零回归）
const REWARD_ICON_IDS: Array[StringName] = [&"icon_res_gold", &"icon_res_exp",
		&"icon_res_repu"]
## 奖励行图标边长（px）
const REWARD_ICON_SIZE: float = 18.0

## 总控配置（setup 注入）
var _cfg: CoreConfig = null
## GameData（setup 注入——奖励图标 AssetTex 解析；空 = 缺件降级）
var _game_data: Node = null
## 名称行（加急前缀+名称+等级档）
var _title_label: Label = null
## 明细行（剩余天数/推荐属性/人力区间/目标区域）
var _info_label: Label = null
## 奖励行容器（组 6：整行 Label / 三段图标行两种形态切换）
var _reward_box: HBoxContainer = null
## 奖励预览行（缺件降级态整行文本——现状分支保留）
var _reward_label: Label = null
## 描述/发布人行
var _desc_label: Label = null
## 接取按钮
var _accept_button: Button = null
## 当前展示实例序号（refresh 写入——接取请求回抛；声明集中文件头）
var _serial: int = 0

## 接取请求信号（serial=实例序号）
signal accept_requested(serial: int)

func setup(cfg: CoreConfig, game_data: Node = null) -> void:
	## 构建卡片骨架（宿主 add_child 前后调用皆可）；M6 批 3.5b：game_data
	## 注入（九宫格面板与奖励行图标解析；空 = 双缺件降级——现状零回归）
	## 参数 cfg：总控配置（字号档位表驱动）；game_data：GameData（可空）
	## 返回：无
	_cfg = cfg
	_game_data = game_data
	add_theme_stylebox_override("panel", UiTheme.make_dark_panel_style(cfg, game_data))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_title_label = _MakeLabel(box, &"ui_font_size_body", UiTheme.FONT_BODY)
	_info_label = _MakeLabel(box, &"ui_font_size_normal", UiTheme.FONT_NORMAL)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_box = HBoxContainer.new()
	_reward_box.add_theme_constant_override("separation", 10)
	box.add_child(_reward_box)
	_reward_label = _MakeLabel(_reward_box, &"ui_font_size_normal", UiTheme.FONT_NORMAL)
	_reward_label.add_theme_color_override("font_color",
			UiTheme.color_of(cfg, &"ui_highlight_gold_color", UiTheme.HIGHLIGHT_GOLD))
	_desc_label = _MakeLabel(box, &"ui_font_size_small", UiTheme.FONT_SMALL)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_accept_button = Button.new()
	_accept_button.name = "AcceptButton"
	_accept_button.text = UI_TEXTS[&"accept_button"]
	_accept_button.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	_accept_button.pressed.connect(func() -> void: accept_requested.emit(_serial))
	box.add_child(_accept_button)

func _MakeLabel(parent: Node, field: StringName, fallback: int) -> Label:
	## 建标签（字号档位表驱动）
	## 参数 parent：父容器；field/fallback：cfg 字段与兜底档位
	## 返回：Label
	var label := Label.new()
	label.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, field, fallback))
	parent.add_child(label)
	return label

func refresh(inst: QuestInstance, game_data: Node, day: int) -> void:
	## 刷新卡片内容（读表显示——不得错报数值）
	## 参数 inst：委托实例；game_data：GameData；day：当日天数
	## 返回：无
	_serial = inst.serial
	var tpl: QuestTemplateDef = game_data.get_record(inst.template_id) as QuestTemplateDef
	if tpl == null:
		_title_label.text = String(inst.template_id)
		_info_label.text = ""
		_reward_label.text = ""
		_desc_label.text = ""
		return
	_title_label.text = UI_TEXTS[&"title_format"] % [inst.display_name(game_data), tpl.level_tier]
	var remain: int = maxi(0, inst.remaining_days(day))
	var region: RegionDef = game_data.get_record(tpl.region_id) as RegionDef
	var region_name: String = region.display_name if region != null else String(tpl.region_id)
	# M4 增补批：轻度分支——工期/无需出征信息行（标题经 display_name 自动带
	# 「轻度·」前缀；不显推荐属性行——轻度无检定消费）
	if tpl.exec_class == QuestTemplateDef.ExecClass.NON_COMBAT:
		_info_label.text = String(UI_TEXTS[&"light_info_format"]) % [
				remain, tpl.party_min, tpl.party_max, tpl.duration_days]
	else:
		var recommend: PackedStringArray = []
		for attr_id: StringName in tpl.recommend_attrs:
			recommend.append(String(ATTR_NAMES.get(attr_id, String(attr_id))))
		_info_label.text = UI_TEXTS[&"info_format"] % [
				remain, " ".join(recommend), tpl.party_min, tpl.party_max, region_name]
	_reward_label.text = UI_TEXTS[&"reward_format"] % [
			tpl.reward.gold, tpl.reward.exp, tpl.reward.reputation] if tpl.reward != null \
			else UI_TEXTS[&"reward_none"]
	_RefreshRewardRow(tpl)
	_desc_label.text = UI_TEXTS[&"desc_format"] % [tpl.issuer, tpl.description]

func _RefreshRewardRow(tpl: QuestTemplateDef) -> void:
	## 奖励行形态装配（M6 批 3.5b 组 6）：三段图标任一在档 → 标题+三段
	## [icon+数值] 图标行（_reward_label 隐藏）；三键全缺件/无奖励 → 整行
	## Label 文本现状（缺件态视觉零回归——_reward_label.text 已由调用方写好）
	## 参数 tpl：委托模板（reward 为空的降级分支同现况）
	## 返回：无
	for child: Node in _reward_box.get_children():
		if child != _reward_label:
			child.queue_free()
	var textures: Array[Texture2D] = []
	for asset_id: StringName in REWARD_ICON_IDS:
		textures.append(AssetTex.texture_of(asset_id, _game_data))
	var has_any_icon: bool = false
	for texture: Texture2D in textures:
		if texture != null:
			has_any_icon = true
			break
	if tpl.reward == null or not has_any_icon:
		_reward_label.visible = true
		return
	_reward_label.visible = false
	var title := Label.new()
	title.text = UI_TEXTS[&"reward_title"]
	title.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	title.add_theme_color_override("font_color",
			UiTheme.color_of(_cfg, &"ui_highlight_gold_color", UiTheme.HIGHLIGHT_GOLD))
	_reward_box.add_child(title)
	var value_keys: Array[StringName] = [&"gold", &"exp", &"reputation"]
	var value_formats: Array[StringName] = [&"reward_gold_format",
			&"reward_exp_format", &"reward_repu_format"]
	for index: int in textures.size():
		var part := HBoxContainer.new()
		part.add_theme_constant_override("separation", 4)
		if textures[index] != null:
			var icon := TextureRect.new()
			icon.texture = textures[index]
			icon.custom_minimum_size = Vector2.ONE * REWARD_ICON_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			part.add_child(icon)
		var value_label := Label.new()
		value_label.text = UI_TEXTS[value_formats[index]] % int(tpl.reward.get(value_keys[index]))
		value_label.add_theme_font_size_override("font_size",
				UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
		value_label.add_theme_color_override("font_color",
				UiTheme.color_of(_cfg, &"ui_highlight_gold_color", UiTheme.HIGHLIGHT_GOLD))
		part.add_child(value_label)
		_reward_box.add_child(part)
