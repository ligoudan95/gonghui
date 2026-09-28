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

## 总控配置（setup 注入）
var _cfg: CoreConfig = null
## 名称行（加急前缀+名称+等级档）
var _title_label: Label = null
## 明细行（剩余天数/推荐属性/人力区间/目标区域）
var _info_label: Label = null
## 奖励预览行
var _reward_label: Label = null
## 描述/发布人行
var _desc_label: Label = null
## 接取按钮
var _accept_button: Button = null

## 接取请求信号（serial=实例序号）
signal accept_requested(serial: int)

func setup(cfg: CoreConfig) -> void:
	## 构建卡片骨架（宿主 add_child 前后调用皆可）
	## 参数 cfg：总控配置（字号档位表驱动）
	## 返回：无
	_cfg = cfg
	add_theme_stylebox_override("panel", UiTheme.make_dark_panel_style(cfg))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_title_label = _MakeLabel(box, &"ui_font_size_body", UiTheme.FONT_BODY)
	_info_label = _MakeLabel(box, &"ui_font_size_normal", UiTheme.FONT_NORMAL)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_label = _MakeLabel(box, &"ui_font_size_normal", UiTheme.FONT_NORMAL)
	_reward_label.add_theme_color_override("font_color",
			UiTheme.color_of(cfg, &"ui_highlight_gold_color", UiTheme.HIGHLIGHT_GOLD))
	_desc_label = _MakeLabel(box, &"ui_font_size_small", UiTheme.FONT_SMALL)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_accept_button = Button.new()
	_accept_button.name = "AcceptButton"
	_accept_button.text = "接单"
	_accept_button.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	_accept_button.pressed.connect(func() -> void: accept_requested.emit(_serial))
	box.add_child(_accept_button)

var _serial: int = 0

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
	_title_label.text = "%s（等级 %d）" % [inst.display_name(game_data), tpl.level_tier]
	var remain: int = maxi(0, inst.remaining_days(day))
	var recommend: PackedStringArray = []
	for attr_id: StringName in tpl.recommend_attrs:
		recommend.append(String(ATTR_NAMES.get(attr_id, String(attr_id))))
	var region: RegionDef = game_data.get_record(tpl.region_id) as RegionDef
	var region_name: String = region.display_name if region != null else String(tpl.region_id)
	_info_label.text = "剩余 %d 天｜推荐：%s｜人力 %d-%d｜区域：%s" % [
			remain, " ".join(recommend), tpl.party_min, tpl.party_max, region_name]
	_reward_label.text = "奖励：%d 金 / %d 经验 / %d 声望" % [
			tpl.reward.gold, tpl.reward.exp, tpl.reward.reputation] if tpl.reward != null \
			else "奖励：—"
	_desc_label.text = "%s：%s" % [tpl.issuer, tpl.description]
