## 委托板面板（QuestBoardPanel，代码构建 UI 组件）
## 职责：协会屏委托板分区——板上委托卡列表（QuestCard）+ 空板提示；
## 接取请求透传信号（协会屏接单弹层 organize_panel 消费）。
## UI 规范：UiTheme 字号档位（零硬编码样式）。
class_name QuestBoardPanel
extends VBoxContainer

## UI 文案单源（R2：周刷新+到期轮换的准确表述——每日刷新的是招募池）
const UI_TEXTS: Dictionary = {
	&"board_title": "委托板（每周一换新·到期自动轮换）",
	&"board_empty": "（板上是空的——等待日结算刷新）",
}

## 板上委托被点接取（serial=实例序号）
signal quest_picked(serial: int)

## 总控配置（setup 注入）
var _cfg: CoreConfig = null
## 标题行
var _title_label: Label = null
## 卡片容器
var _card_box: VBoxContainer = null
## 空板提示行
var _empty_label: Label = null
## 实例序号 -> 卡片索引（刷新重建）
var _cards: Array[QuestCard] = []

func setup(cfg: CoreConfig) -> void:
	## 构建面板骨架
	## 参数 cfg：总控配置
	## 返回：无
	_cfg = cfg
	add_theme_constant_override("separation", 6)
	_title_label = Label.new()
	_title_label.text = UI_TEXTS[&"board_title"]
	_title_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	add_child(_title_label)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 8)
	add_child(_card_box)
	_empty_label = Label.new()
	_empty_label.text = UI_TEXTS[&"board_empty"]
	_empty_label.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	add_child(_empty_label)

func refresh(instances: Array[QuestInstance], game_data: Node, day: int) -> void:
	## 刷新板上委托卡列表（全量重建）
	## 参数 instances：板上实例；game_data：GameData；day：当日天数
	## 返回：无
	for card: QuestCard in _cards:
		card.queue_free()
	_cards.clear()
	for inst: QuestInstance in instances:
		var card := QuestCard.new()
		_card_box.add_child(card)
		card.setup(_cfg, game_data)
		card.refresh(inst, game_data, day)
		card.accept_requested.connect(_OnCardAccept)
		_cards.append(card)
	_empty_label.visible = instances.is_empty()

func _OnCardAccept(serial: int) -> void:
	## 卡片接取透传
	## 参数 serial：实例序号
	## 返回：无
	quest_picked.emit(serial)
