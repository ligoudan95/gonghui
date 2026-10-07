## 探索屏左栏（ExplorePartyPanel，代码构建 UI 组件——三栏改版批）
## 职责：冒险者信息侧栏——「探索」标题 + 队伍成员卡（1~4 张）：职业图标
## （cls.icon_id 贴图，缺件不显）/姓名行（姓名·Lv等级，中毒未倒地缀「·中毒」）/
## HP 行（血条 + cur/max 文本，低血变红，带上限 = DerivedStats.calc_hp 装配
## 口径同源）/倒地整卡灰显 + HP 文本显「倒地」（优先于中毒标记）。
## 文案口径：UI 层单源（hp_downed/hp_poison_tag 自 explore_screen.UI_TEXTS
## 迁入组件文案表）；面板底复用 make_dark_panel_style、血条三色复用
## ui_badge_hp_low/ok_color + ui_badge_bar_back_color + ui_badge_hp_low_threshold
## （cfg 既有键零新增）。
## 组件内运行时节点不用 % 唯一名（DaySummaryPanel 先例——成员变量直引）。
class_name ExplorePartyPanel
extends VBoxContainer

## UI 文案单源（改措辞只动此处）
const UI_TEXTS: Dictionary = {
	&"title": "探索",
	&"hp_downed": "倒地",
	&"hp_poison_tag": "·中毒",
	&"name_level_format": "%s·Lv%d",
	&"hp_text_format": "%d/%d",
}

## 职业图标渲染边长（px——占位 UI 结构参数，X3-06 豁免先例同口径，
## 归口案 16 §2.7——文档登记由 docs-updater 后续补；不入 CoreConfig）
const ICON_RENDER_SIZE: float = 24.0

## 总控配置（setup 注入）
var _cfg: CoreConfig = null
## GameData（setup 注入——职业表/图标解析）
var _game_data: Node = null
## 卡片区（成员卡挂载点——setup 建骨架后 refresh_party 清建）
var _cards_box: VBoxContainer = null

func setup(cfg: CoreConfig, game_data: Node) -> void:
	## 构建侧栏骨架（深底面板外壳 + 标题 + 卡片区）
	## 参数 cfg：总控配置；game_data：GameData 单例
	## 返回：无
	_cfg = cfg
	_game_data = game_data
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_FILL
	var shell := PanelContainer.new()
	shell.name = "Shell"
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.size_flags_horizontal = Control.SIZE_FILL
	shell.add_theme_stylebox_override("panel",
			UiTheme.make_dark_panel_style(cfg, game_data))
	add_child(shell)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	shell.add_child(box)
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = String(UI_TEXTS[&"title"])
	title.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_heading", UiTheme.FONT_HEADING))
	box.add_child(title)
	_cards_box = VBoxContainer.new()
	_cards_box.name = "CardsBox"
	_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_box.add_theme_constant_override("separation", 10)
	box.add_child(_cards_box)

func refresh_party(run: ExpeditionRun) -> void:
	## 刷新队伍卡区（清建 1~4 卡——先 visible=false 再 queue_free，
	## S4-R3-01 先例防旧卡与重建卡一帧叠渲）
	## 参数 run：出征运行态
	## 返回：无
	for child: Node in _cards_box.get_children():
		var old_card: Control = child as Control
		if old_card != null:
			old_card.visible = false
		child.queue_free()
	if run == null:
		return
	for adv: AdventurerData in run.party:
		_cards_box.add_child(_MakeMemberCard(adv, run))

func _MakeMemberCard(adv: AdventurerData, run: ExpeditionRun) -> Control:
	## 构建单张成员卡：HBox[职业图标（缺件不显，24px）+ VBox[姓名行/HP 行]]
	## 参数 adv：成员数据；run：出征运行态（HP/倒地/染毒读值）
	## 返回：卡根（未挂树由调用方挂入）
	var is_downed: bool = run.downed.get(adv, false)
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	if is_downed:
		# 倒地整卡灰显（UiTheme.EXPLORE_TARGET_DIM 同值语义——灰度压暗）
		card.modulate = UiTheme.color_of(_cfg, &"ui_explore_target_dim_color",
				UiTheme.EXPLORE_TARGET_DIM)
	# 职业图标（cls.icon_id 贴图；查无职业/缺件不显——X3-06 豁免口径）
	var cls: ClassDef = _game_data.get_record(adv.class_id) as ClassDef
	if cls != null and cls.icon_id != &"":
		var texture: Texture2D = AssetTex.texture_of(cls.icon_id, _game_data)
		if texture != null:
			var icon := TextureRect.new()
			icon.texture = texture
			# 属性序契约（_MakeIconNode 同坑规避）：stretch/expand 先于尺寸
			icon.stretch_mode = TextureRect.STRETCH_SCALE
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.custom_minimum_size = Vector2.ONE * ICON_RENDER_SIZE
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(icon)
	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	card.add_child(info)
	# 姓名行（display_name·LvN；中毒未倒地缀「·中毒」——倒地优先走 HP 行口径）
	var name_text: String = String(UI_TEXTS[&"name_level_format"]) \
			% [adv.display_name, adv.level]
	if run.poisoned.has(adv) and not is_downed:
		name_text += String(UI_TEXTS[&"hp_poison_tag"])
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	info.add_child(name_label)
	# HP 行（血条 + cur/max 文本；倒地显「倒地」——优先于中毒）
	var hp_row := HBoxContainer.new()
	hp_row.name = "HpRow"
	hp_row.add_theme_constant_override("separation", 6)
	info.add_child(hp_row)
	var hp_bar := ProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(120, 14)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(hp_bar)
	var hp_label := Label.new()
	hp_label.name = "HpLabel"
	hp_row.add_child(hp_label)
	hp_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(_cfg, &"ui_font_size_small", UiTheme.FONT_SMALL))
	var current: int = int(run.hp.get(adv, 0))
	var max_hp: int = 0
	if cls != null:
		# HP 上限装配口径单源：DerivedStats.calc_hp 同式同参——与
		## guild_state.build_expedition_run / explore_screen._MakeDefaultRun
		## 三处同源（体质×职业×等级×cfg），改动须三口同步
		max_hp = DerivedStats.calc_hp(
				int(adv.attrs.get(AttrKeys.CONSTITUTION,
						AttrKeys.DEFAULT_ATTR_VALUE)),
				cls, adv.level, _cfg)
	if max_hp <= 0:
		# 派生失败回退：仅当前值（血条满格不误导）
		max_hp = maxi(current, 1)
	hp_bar.max_value = max_hp
	hp_bar.value = clampi(current, 0, max_hp)
	if is_downed:
		hp_label.text = String(UI_TEXTS[&"hp_downed"])
	else:
		hp_label.text = String(UI_TEXTS[&"hp_text_format"]) % [current, max_hp]
	# 血条配色（低血变红——阈值/三色复用 ui_badge_* 既有键）
	var ratio: float = float(current) / float(max_hp) if max_hp > 0 else 0.0
	var low_threshold: float = _cfg.ui_badge_hp_low_threshold \
			if _cfg != null and _cfg.ui_badge_hp_low_threshold > 0.0 \
			else UiTheme.BADGE_HP_LOW_THRESHOLD
	var fill_color: Color = UiTheme.color_of(_cfg, &"ui_badge_hp_low_color",
			UiTheme.BADGE_HP_LOW) if ratio <= low_threshold \
			else UiTheme.color_of(_cfg, &"ui_badge_hp_ok_color",
			UiTheme.BADGE_HP_OK)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = UiTheme.color_of(_cfg, &"ui_badge_bar_back_color",
			UiTheme.BADGE_BAR_BACK)
	back_style.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("background", back_style)
	return card
