## 回合序条（TurnOrderBar，HBoxContainer——TopBar 内）
## 职责：展示本回合行动序列——各单位小头像（sprite 36×36 Nearest）+ 速度值，
## 当前行动位金色高亮、倒地灰显；每回合初（round_started）重建。
## 数据来源：M1 批 3 方案 §7.1（TopBar.TurnOrderBar：头像+速度值当前高亮）。
class_name TurnOrderBar
extends HBoxContainer

## 序条头像显示尺寸
const ICON_SIZE: float = 36.0
## 条目间距
const ENTRY_SEPARATION: int = 8
## 总控配置（B-2/B-3/B-7：配色/字号表驱动注入——setup 传入，空 = 纯兜底）
var _cfg: CoreConfig = null

## 表驱动色读取（B-2/B-3）
func _Color(field: StringName, fallback: Color) -> Color:
	## 参数 field：cfg 字段名；fallback：UiTheme 兜底常量
	## 返回：生效颜色
	return UiTheme.color_of(_cfg, field, fallback)

## 字号档位读取（B-7）
func _UiFont(field: StringName, fallback: int) -> int:
	## 参数 field：cfg 字段名；fallback：UiTheme 兜底档位
	## 返回：生效字号
	return UiTheme.font_of(_cfg, field, fallback)

## 条目池（unit_id -> PanelContainer）
var _entries: Dictionary = {}
## 条目单位索引（unit_id -> BattleUnit；S4-6 倒地灰显的即时查询）
var _units: Dictionary = {}
## GameData（sprite 路径解析——批 4 H3：纹理缓存与解析逻辑单源至 SpriteResolver，
## 本层缓存字段删除）
var _game_data: Node = null

func setup(game_data: Node, cfg: CoreConfig = null) -> void:
	## 注入依赖（sprite 解析 + 配色/字号表驱动配置）
	## 参数 game_data：GameData；cfg：总控配置（可空——B 席批表驱动）
	## 返回：无
	_game_data = game_data
	_cfg = cfg
	add_theme_constant_override("separation", ENTRY_SEPARATION)

func rebuild(units: Array) -> void:
	## 重建序列条（ROUND_START 调；按行动序排布；倒地条目建即灰显）
	## 参数 units：本回合行动序列（速度排序产物）
	## 返回：无
	for child: Node in get_children():
		child.queue_free()
	_entries.clear()
	_units.clear()
	for unit: BattleUnit in units:
		var entry := PanelContainer.new()
		entry.custom_minimum_size = Vector2(ICON_SIZE + 16, ICON_SIZE + 28)
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 0)
		var icon := TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.texture = SpriteResolver.texture_of(
				SpriteResolver.sprite_id_of(unit, _game_data), _game_data)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var speed_label := Label.new()
		speed_label.text = str(unit.speed_for_order())
		speed_label.add_theme_font_size_override("font_size", _UiFont(&"ui_font_size_minor", UiTheme.FONT_MINOR))
		speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(speed_label)
		entry.add_child(box)
		add_child(entry)
		_entries[unit.unit_id] = entry
		_units[unit.unit_id] = unit
		if not unit.alive:
			entry.modulate = _Color(&"ui_downed_modulate_color", UiTheme.DOWNED_MODULATE)

func set_current(unit: BattleUnit) -> void:
	## 当前行动位高亮（金色；其余复位——倒地条目复位时保持灰显，
	## S4-6：经 _units 索引判活）
	## 参数 unit：当前行动单位（null = 全清）
	## 返回：无
	for unit_id: StringName in _entries:
		var entry: PanelContainer = _entries[unit_id]
		if unit != null and unit_id == unit.unit_id:
			entry.modulate = _Color(&"ui_highlight_gold_color", UiTheme.HIGHLIGHT_GOLD)
		else:
			entry.modulate = _Color(&"ui_downed_modulate_color", UiTheme.DOWNED_MODULATE) \
					if _IsDowned(unit_id) else Color(1, 1, 1, 1)

func set_downed(unit: BattleUnit) -> void:
	## 倒地即时灰显（S4-6：unit_downed 信号回调——此前倒地灰显只在回合初
	## rebuild 生效，同回合内 UI 追认延迟）
	## 参数 unit：倒地单位
	## 返回：无
	_units[unit.unit_id] = unit
	var entry: PanelContainer = _entries.get(unit.unit_id, null)
	if entry != null:
		entry.modulate = _Color(&"ui_downed_modulate_color", UiTheme.DOWNED_MODULATE)

func _IsDowned(unit_id: StringName) -> bool:
	## 条目单位是否倒地（S4-6：无索引记录按存活处理）
	## 参数 unit_id：单位 id
	## 返回：true = 倒地
	var unit: BattleUnit = _units.get(unit_id, null)
	return unit != null and not unit.alive

