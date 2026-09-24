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

## 条目池（unit_id -> PanelContainer）
var _entries: Dictionary = {}
## sprite 纹理缓存（sprite id -> Texture2D；setup 注入来源）
var _texture_cache: Dictionary = {}
## GameData（sprite 路径解析）
var _game_data: Node = null

func setup(game_data: Node) -> void:
	## 注入依赖（sprite 解析）
	## 参数 game_data：GameData
	## 返回：无
	_game_data = game_data
	add_theme_constant_override("separation", ENTRY_SEPARATION)

func rebuild(units: Array) -> void:
	## 重建序列条（ROUND_START 调；按行动序排布）
	## 参数 units：本回合行动序列（速度排序产物）
	## 返回：无
	for child: Node in get_children():
		child.queue_free()
	_entries.clear()
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
		icon.texture = _TextureOf(_SpriteIdOf(unit))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var speed_label := Label.new()
		speed_label.text = str(unit.speed_for_order())
		speed_label.add_theme_font_size_override("font_size", 12)
		speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(speed_label)
		entry.add_child(box)
		add_child(entry)
		_entries[unit.unit_id] = entry
		if not unit.alive:
			entry.modulate = Color(0.5, 0.5, 0.5, 0.5)

func set_current(unit: BattleUnit) -> void:
	## 当前行动位高亮（金色；其余复位；倒地灰显保持）
	## 参数 unit：当前行动单位（null = 全清）
	## 返回：无
	for unit_id: StringName in _entries:
		var entry: PanelContainer = _entries[unit_id]
		if unit != null and unit_id == unit.unit_id:
			entry.modulate = Color(1.0, 0.85, 0.3)
		else:
			entry.modulate = Color(1, 1, 1, 1)

func _TextureOf(sprite_id: StringName) -> Texture2D:
	## sprite id → 纹理（缓存复用；缺登记返回 null——头像空白）
	## 参数 sprite_id：资源 id
	## 返回：Texture2D
	if _texture_cache.has(sprite_id):
		return _texture_cache[sprite_id]
	var texture: Texture2D = null
	if _game_data != null:
		var path: String = _game_data.get_asset_path(sprite_id)
		if not path.is_empty():
			texture = load(path) as Texture2D
	_texture_cache[sprite_id] = texture
	return texture

func _SpriteIdOf(unit: BattleUnit) -> StringName:
	## 单位 → sprite 资源 id（批 A H3 表驱动：ClassDef/EnemyDef.sprite_id——
	## 经 GameData 查表，删除原拼接规则复刻；查无回退空 id 走占位色块）
	## 参数 unit：单位
	## 返回：sprite id
	if _game_data == null:
		return &""
	if unit.side == SkillDef.SkillSide.ALLY:
		var cls: ClassDef = _game_data.get_record(unit.class_id) as ClassDef
		return cls.sprite_id if cls != null else &""
	var enemy: EnemyDef = _game_data.get_record(unit.enemy_id) as EnemyDef
	return enemy.sprite_id if enemy != null else &""
