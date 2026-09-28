## 设施屏（facility_screen）场景脚本——M4 批 2（宿舍/训练场共用）
## 职责：纯展示+返回+升级——设施名/当前等级效果/升级按钮（费用+下一级效果
## Tooltip 读 fac_ 表）；升级走 GuildState.upgrade_facility（校验+扣款+
## FACILITY_UPGRADED 存档+即时生效）；scene_id 消费批 1 fac_ 表已落值（拍板⑥）。
## 数据来源：案 3 §2.2/§2.3（设施效果曲线与升级规则）；UI 规范=案 15 + UiTheme。
## 单例访问：统一 get_node("/root/X")（gdUnit 测试环境惯例）。
extends Control

## SceneManager 脚本常量引用
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")

## 按钮统一尺寸（S5-M5-1-h：原两处 Vector2 字面量提常量）
const BUTTON_SIZE: Vector2 = Vector2(280, 56)

## 本屏设施 id（tscn 注入：fac_dormitory / fac_training_ground）
@export var facility_id: StringName = &""

## GameData 单例引用
var _game_data: Node = null
## 总控配置
var _cfg: CoreConfig = null
## 设施定义（_ready 解析）
var _fac: FacilityDef = null
## 设施名行
var _title_label: Label = null
## 当前效果行
var _effect_label: Label = null
## 升级按钮
var _upgrade_button: Button = null
## 提示行
var _hint_label: Label = null

func _ready() -> void:
	## 引擎回调：解析设施定义 → 构建展示 → 刷新
	## 参数：无
	## 返回：无
	_game_data = get_node("/root/GameData")
	_cfg = _game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	get_node("/root/SceneManager").take_pending_params()
	_fac = _game_data.get_record(facility_id) as FacilityDef
	_BuildLayout()
	Refresh()

func _BuildLayout() -> void:
	## 构建展示骨架（代码构建——EventPanel/ExploreBoard 先例）
	## 参数：无
	## 返回：无
	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_top = 0.0
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 24
	box.offset_top = 16
	box.offset_right = -24
	box.offset_bottom = -16
	add_child(box)
	_title_label = _MakeLabel(box, &"ui_font_size_heading", UiTheme.FONT_HEADING)
	_title_label.name = "TitleLabel"
	_effect_label = _MakeLabel(box, &"ui_font_size_body", UiTheme.FONT_BODY)
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.name = "EffectLabel"
	_hint_label = _MakeLabel(box, &"ui_font_size_normal", UiTheme.FONT_NORMAL)
	_hint_label.name = "HintLabel"
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_upgrade_button = Button.new()
	_upgrade_button.name = "UpgradeButton"
	_upgrade_button.custom_minimum_size = BUTTON_SIZE
	_upgrade_button.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	_upgrade_button.pressed.connect(_OnUpgradePressed)
	box.add_child(_upgrade_button)
	var back_button := Button.new()
	back_button.text = "返回公会"
	back_button.custom_minimum_size = BUTTON_SIZE
	back_button.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	back_button.pressed.connect(_OnBackPressed)
	box.add_child(back_button)

func _MakeLabel(parent: Node, field: StringName, fallback: int) -> Label:
	## 建标签（字号档位表驱动）
	## 参数 parent：父容器；field/fallback：cfg 字段与兜底档位
	## 返回：Label
	var label := Label.new()
	label.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, field, fallback))
	parent.add_child(label)
	return label

func Refresh() -> void:
	## 刷新展示（当前级效果读表；升级按钮费用/下一级效果 Tooltip）
	## 参数：无
	## 返回：无
	if _fac == null:
		_title_label.text = "设施数据缺失（%s）" % String(facility_id)
		_effect_label.text = ""
		_upgrade_button.disabled = true
		_upgrade_button.text = "升级"
		return
	var core: GuildCore = get_node("/root/GuildState").core
	# D-2/Z2-12：等级读值 clamp [1, max_level]——防脏档越界
	var level: int = clampi(int(core.facility_levels.get(_fac.id, 1)), 1, _fac.max_level)
	_title_label.text = "%s（Lv%d）" % [_fac.display_name, level]
	_effect_label.text = "当前效果：%s" % _EffectText(_fac.levels[level - 1])
	_hint_label.text = ""
	if level >= _fac.max_level:
		_upgrade_button.disabled = true
		_upgrade_button.text = "已满级"
		_upgrade_button.tooltip_text = "当前效果：%s" % _EffectText(_fac.levels[level - 1])
		return
	var next_row: FacilityLevelDef = _fac.levels[level]
	# M4-7：余额不足禁用 + tooltip 显示余额（对齐招募按钮标准）
	var affordable: bool = core.gold >= next_row.upgrade_cost
	_upgrade_button.disabled = not affordable
	_upgrade_button.text = "升级（%d 金）" % next_row.upgrade_cost
	_upgrade_button.tooltip_text = "当前效果：%s\n升级后：%s\n费用：%d 金\n余额：%d 金%s" % [
			_EffectText(_fac.levels[level - 1]), _EffectText(next_row),
			next_row.upgrade_cost, core.gold,
			"" if affordable else "——余额不足"]

func _EffectText(row: FacilityLevelDef) -> String:
	## 单级效果文案（按 kind 取对应字段——读表显示不得错报数值）
	## 参数 row：等级效果行
	## 返回：效果文本
	if _fac == null:
		return "—"
	match _fac.facility_kind:
		FacilityDef.FacilityKind.DORMITORY:
			return "容量 %d 人｜重伤休养 -%d 天" % [row.dorm_capacity, row.rest_days_reduction]
		FacilityDef.FacilityKind.TRAINING:
			return "板凳经验分享率 %d%%" % roundi(row.bench_share_rate * 100.0)
	return "—"

func _OnUpgradePressed() -> void:
	## 升级按钮（GuildState.upgrade_facility——校验/扣款/存档/即时生效）
	## 参数：无
	## 返回：无
	if not get_node("/root/GuildState").upgrade_facility(facility_id):
		_hint_label.text = get_node("/root/GuildState").core.last_error
		return
	Refresh()

func _OnBackPressed() -> void:
	## 返回公会主界面
	## 参数：无
	## 返回：无
	var err: Error = get_node("/root/SceneManager").go(SceneManagerScript.SceneId.GUILD_SHELL)
	if err != OK:
		push_warning("facility_screen: 返回公会失败（错误码 %d）" % err)
