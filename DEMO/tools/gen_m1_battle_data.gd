## M1 批 1 战斗数据生成器
## 职责：生成 14 张新数据表（.tres）——地格 6 / 战场地图 2 / 初始装备 6，
## 回填 3 张敌方队伍表的 battle_map_ref，重生成命名登记表（48 + 14 = 62 条）。
## 数值来源：案 9《战棋战斗》（地格机制）；案 17《数值专项案》§3.4（武器加值行）/
## §3.9（地格效果/战场规模）/§3.11 #7（DEMO 初始装备）；陷阱=纯伤害地格
## （第九轮拍板 DEMO 降级，无状态绑定）。
## 用法：godot --headless --import 后
##   godot --headless -s res://tools/gen_m1_battle_data.gd
## 注：可重复执行（幂等覆盖）；全部布置【占位·试玩校准】——障碍约 10%
## （8×8 图 8 格 / 10×10 图 12 格）、草丛 3、高地 2、毒沼 1-2、中线附近散布、
## 避开出生区、保证出生位到敌方区连通；GameData 域注册与 DataValidator
## V-M1-* 校验由本批代码侧同步落地。
extends SceneTree

## !! 警示（解耦复审 C-10）：本工具为 M0/M1 首次生成占位数据的脚本——
## 全库数据已人工调校定稿，重跑将【覆盖调校值】，必须先备份并对 diff
## 逐行复核后才可采纳。

## 我方出生位（底部 4 格；两张图同规格口径——x 居中 4 连格）
const PLAYER_SPAWNS_8X8: Array[Vector2i] = [
	Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7),
]
## 敌方出生位候选（顶部 4 格）
const ENEMY_SPAWNS_8X8: Array[Vector2i] = [
	Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
]
## 10×10 图出生位（同口径）
const PLAYER_SPAWNS_10X10: Array[Vector2i] = [
	Vector2i(3, 9), Vector2i(4, 9), Vector2i(5, 9), Vector2i(6, 9),
]
## 10×10 图敌方出生位
const ENEMY_SPAWNS_10X10: Array[Vector2i] = [
	Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0),
]

func _initialize() -> void:
	## MainLoop 回调：依次生成地格/地图/装备、回填队伍地图引用、重生成命名登记表后退出
	## 参数：无
	## 返回：无（任一保存失败按退出码 1 结束）
	var ok: bool = true
	ok = _GenerateTiles() and ok
	ok = _GenerateMaps() and ok
	ok = _GenerateEquips() and ok
	ok = _BackfillPackMaps() and ok
	ok = _RegenerateNamingRegistry() and ok
	if ok:
		print("gen_m1_battle_data: 全部数据生成完成")
		quit(0)
	else:
		printerr("gen_m1_battle_data: 存在保存失败项")
		quit(1)

func _SaveResource(resource: Resource, path: String) -> bool:
	## 保存资源到指定路径（目录不存在则先创建）并打印结果
	## 参数 resource：待保存资源；path：目标 res:// 路径
	## 返回：true = 保存成功
	var dir_path: String = path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var err: Error = ResourceSaver.save(resource, path)
	if err != OK:
		printerr("gen_m1_battle_data: 保存失败 %s（错误码 %d）" % [path, err])
		return false
	print("gen_m1_battle_data: 已生成 %s" % path)
	return true

# =========================================================================
# 地格域 battle/tiles（6 张，TileTypeDef；17 案 §3.9 地格效果）
# =========================================================================

func _GenerateTiles() -> bool:
	## 生成 6 张地格表（普通/障碍/草丛/高地/毒沼/陷阱；陷阱纯伤害无状态绑定）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	ok = _SaveResource(_MakeTile(&"tile_normal", "普通地面",
			TileTypeDef.Kind.NORMAL, true, 1, &"", TileTypeDef.Trigger.STANDING,
			"普通地面（默认地格）"), "res://data/battle/tiles/tile_normal.tres") and ok
	ok = _SaveResource(_MakeTile(&"tile_obstacle", "障碍",
			TileTypeDef.Kind.OBSTACLE, false, 1, &"", TileTypeDef.Trigger.STANDING,
			"障碍：不可通行、阻断视线"), "res://data/battle/tiles/tile_obstacle.tres") and ok
	ok = _SaveResource(_MakeTile(&"tile_grass", "草丛",
			TileTypeDef.Kind.STATUS, true, 1, &"BUFF_tile_grass", TileTypeDef.Trigger.STANDING,
			"草丛：站格闪避 +15%（17 案 §3.9）"), "res://data/battle/tiles/tile_grass.tres") and ok
	ok = _SaveResource(_MakeTile(&"tile_highground", "高地",
			TileTypeDef.Kind.STATUS, true, 1, &"BUFF_tile_highground", TileTypeDef.Trigger.STANDING,
			"高地：站格面板伤害 ×1.2（随技能系数同层乘算，17 案 §3.9）"),
			"res://data/battle/tiles/tile_highground.tres") and ok
	ok = _SaveResource(_MakeTile(&"tile_poison_swamp", "毒沼",
			TileTypeDef.Kind.STATUS, true, 1, &"DEBUFF_tile_poison", TileTypeDef.Trigger.STANDING,
			"毒沼：站格回合末固定 6 伤，固定值直接结算、不走减免轨（§3.9，同陷阱 D7 口径）"),
			"res://data/battle/tiles/tile_poison_swamp.tres") and ok
	ok = _SaveResource(_MakeTile(&"tile_trap", "陷阱",
			TileTypeDef.Kind.STATUS, true, 1, &"", TileTypeDef.Trigger.ENEMY_ENTER_ONCE,
			"陷阱：敌方踏入触发一次性纯伤害（预结算直取、免两段判定与减免轨——第九轮拍板 DEMO 降级，无状态绑定）"),
			"res://data/battle/tiles/tile_trap.tres") and ok
	return ok

func _MakeTile(tile_id: StringName, display_name: String, kind: TileTypeDef.Kind,
		walkable: bool, move_cost: int, status_id: StringName,
		trigger: TileTypeDef.Trigger, comment: String) -> TileTypeDef:
	## 构建 TileTypeDef 资源
	## 参数：见 TileTypeDef 字段（comment 为效果备注，落 .tres 时统一加占位标注）
	## 返回：填充完成的 TileTypeDef
	var tile := TileTypeDef.new()
	tile.id = tile_id
	tile.display_name = display_name
	tile.kind = kind
	tile.walkable = walkable
	tile.move_cost = move_cost
	tile.status_id = status_id
	tile.trigger = trigger
	tile.comment = "【占位·试玩校准】" + comment + "；来源：17 案 §3.9 地格效果"
	return tile

# =========================================================================
# 战场地图域 battle/maps（2 张，BattleMapDef；17 案 §3.9 战场规模）
# =========================================================================

func _GenerateMaps() -> bool:
	## 生成 2 张战场地图（随机遭遇 8×8 / 巢穴必然遭遇 10×10；
	## 布置【占位·试玩校准】：障碍约 10%（8/12 格）、草丛 3、高地 2、毒沼 1-2、
	## 中线附近散布、避开出生区、保证出生位到敌方区连通）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	# 8×8 随机图：障碍 8（y2:2 y3:2 y4:2 y5:2）/草丛 3（(5,2)(3,4)(5,4)）/
	# 高地 2（(5,3)(2,5)）/毒沼 1（(4,5)）；行 0/7 出生区全空
	ok = _SaveResource(_MakeMap(&"btm_m1_random_8x8", "矿洞随机遭遇图（8×8）", Vector2i(8, 8), [
		"........",
		"........",
		"..X..g.X",
		".X.X.h..",
		"..Xg.gX.",
		".Xh.p..X",
		"........",
		"........",
	], PLAYER_SPAWNS_8X8, ENEMY_SPAWNS_8X8,
			"随机遭遇战场（17 案 §3.9：随机 8×8）；enc_m1_random_pack/enc_m1_wisp_nest 引用"),
			"res://data/battle/maps/btm_m1_random_8x8.tres") and ok
	# 10×10 巢穴图：障碍 12（y2-y7 各 2）/草丛 3（(5,2)(7,4)(1,5)）/
	# 高地 2（(7,3)(6,5)）/毒沼 2（(3,6)(6,7)）；行 0/9 出生区全空
	ok = _SaveResource(_MakeMap(&"btm_m1_lair_10x10", "巢穴必然遭遇图（10×10）", Vector2i(10, 10), [
		"..........",
		"..........",
		"..X..g.X..",
		".X..X..h..",
		"...X..Xg..",
		".gX...h.X.",
		".X.p.X....",
		"....X.pX..",
		"..........",
		"..........",
	], PLAYER_SPAWNS_10X10, ENEMY_SPAWNS_10X10,
			"必然遭遇战场（17 案 §3.9：必然 10×10）；enc_m1_lair_pack 引用"),
			"res://data/battle/maps/btm_m1_lair_10x10.tres") and ok
	return ok

func _MakeMap(map_id: StringName, display_name: String, map_size: Vector2i,
		rows: Array, player_spawns: Array[Vector2i], enemy_spawns: Array[Vector2i],
		comment: String) -> BattleMapDef:
	## 构建 BattleMapDef 资源（统一图例：'.'普通 'X'障碍 'g'草丛 'h'高地 'p'毒沼）
	## 参数：见 BattleMapDef 字段（rows 为 String 数组字面量）
	## 返回：填充完成的 BattleMapDef
	var map_def := BattleMapDef.new()
	map_def.id = map_id
	map_def.display_name = display_name
	map_def.size = map_size
	var typed_rows: Array[String] = []
	for row: String in rows:
		typed_rows.append(row)
	map_def.rows = typed_rows
	map_def.legend = {
		".": &"tile_normal",
		"X": &"tile_obstacle",
		"g": &"tile_grass",
		"h": &"tile_highground",
		"p": &"tile_poison_swamp",
	}
	map_def.player_spawns = player_spawns
	map_def.enemy_spawns = enemy_spawns
	map_def.retreat_cells = []
	map_def.comment = "【占位·试玩校准】" + comment + "；布置：障碍约 10%、草丛 3、高地 2、毒沼 1-2、中线散布、出生区避让、出生位-敌方区连通（试玩校准点）"
	return map_def

# =========================================================================
# 装备域 equip（6 张，EquipDef；17 案 §3.4 武器加值行 + §3.11 #7）
# =========================================================================

func _GenerateEquips() -> bool:
	## 生成 6 张 DEMO 初始装备表（普通档；DEMO 不可卸下）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	ok = _SaveResource(_MakeEquip(&"eqp_init_warrior", "战士初始装备（重甲套）",
			&"cls_warrior", 4, 5), "res://data/equip/eqp_init_warrior.tres") and ok
	ok = _SaveResource(_MakeEquip(&"eqp_init_rogue", "盗贼初始装备（皮甲套）",
			&"cls_rogue", 3, 3), "res://data/equip/eqp_init_rogue.tres") and ok
	ok = _SaveResource(_MakeEquip(&"eqp_init_ranger", "游侠初始装备（游侠皮甲套）",
			&"cls_ranger", 3, 2), "res://data/equip/eqp_init_ranger.tres") and ok
	ok = _SaveResource(_MakeEquip(&"eqp_init_mage", "法师初始装备（布甲套）",
			&"cls_mage", 2, 1), "res://data/equip/eqp_init_mage.tres") and ok
	ok = _SaveResource(_MakeEquip(&"eqp_init_priest", "牧师初始装备（布甲套）",
			&"cls_priest", 2, 1), "res://data/equip/eqp_init_priest.tres") and ok
	ok = _SaveResource(_MakeEquip(&"eqp_init_arcanist", "奇术师初始装备（布甲套）",
			&"cls_arcanist", 2, 1), "res://data/equip/eqp_init_arcanist.tres") and ok
	return ok

func _MakeEquip(equip_id: StringName, display_name: String, class_ref: StringName,
		weapon_bonus: int, armor_value: int) -> EquipDef:
	## 构建 EquipDef 资源
	## 参数：见 EquipDef 字段
	## 返回：填充完成的 EquipDef
	var equip := EquipDef.new()
	equip.id = equip_id
	equip.display_name = display_name
	equip.class_ref = class_ref
	equip.weapon_bonus = weapon_bonus
	equip.armor_value = armor_value
	equip.comment = "【占位·试玩校准】DEMO 初始装备（普通档）·不可卸下；数值来源：17 案 §3.4 武器加值行 + §3.11 #7；护甲物理/法术双轨同计"
	return equip

# =========================================================================
# 敌方队伍 battle_map_ref 回填（3 张，只改引用与备注、不动其他字段）
# =========================================================================

func _BackfillPackMaps() -> bool:
	## 回填 3 张敌方队伍表的 battle_map_ref（M0 批 4 预留口，M1 批 1 落地）：
	## 精确改引用字段 + 备注同步，其余字段原样保留
	## 参数：无
	## 返回：true = 全部回填成功
	var backfills: Dictionary = {
		&"enc_m1_random_pack": [&"btm_m1_random_8x8",
			"【占位·试玩校准】随机遭遇：池（鼠/哥布林）×3（17 案 §3.8 配置）；battle_map_ref=随机图 8×8（M1 批 1 回填）"],
		&"enc_m1_lair_pack": [&"btm_m1_lair_10x10",
			"【占位·试玩校准】必然遭遇：精英×1 + 池（鼠/哥布林）×2-3（17 案 §3.8 配置）；battle_map_ref=必然图 10×10（M1 批 1 回填）"],
		&"enc_m1_wisp_nest": [&"btm_m1_random_8x8",
			"【占位·试玩校准】事件 B 出口遭遇：鼠×2 + 哥布林×1（18 案 §4.1）；battle_map_ref=复用矿道随机图 8×8（M1 批 1 回填）"],
	}
	var ok: bool = true
	for pack_id: StringName in backfills:
		var path: String = "res://data/battle/enemy_packs/%s.tres" % pack_id
		var pack: EnemyPackDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EnemyPackDef
		if pack == null:
			printerr("gen_m1_battle_data: 队伍表加载失败 %s" % path)
			ok = false
			continue
		pack.battle_map_ref = backfills[pack_id][0]
		pack.comment = backfills[pack_id][1]
		ok = _SaveResource(pack, path) and ok
	return ok

# =========================================================================
# 资源命名登记表重生成（data/core/naming_registry.tres，48 + 14 = 62 条）
# =========================================================================

func _RegenerateNamingRegistry() -> bool:
	## 重生成命名登记表：加载现有登记（M0 批 2 的 48 条），追加本批 14 条新资源
	## （btm_×2 / tile_×6 / eqp_×6），幂等（已登记的跳过）
	## 参数：无
	## 返回：true = 保存成功
	var registry: NamingRegistry = ResourceLoader.load(
			"res://data/core/naming_registry.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as NamingRegistry
	if registry == null:
		printerr("gen_m1_battle_data: naming_registry 加载失败")
		return false
	var entries: Array[NamingEntry] = registry.entries
	var existing_ids: Dictionary = {}
	for entry: NamingEntry in entries:
		existing_ids[entry.resource_id] = true
	# ---- battle/maps 域（2 条）----
	var map_rules: Dictionary = {
		&"btm_m1_random_8x8": ["矿洞随机遭遇图（8×8）", "btm_<区域>_<规格>：战场地图（m1=矿洞一层；8x8=随机遭遇规格，17 案 §3.9）"],
		&"btm_m1_lair_10x10": ["巢穴必然遭遇图（10×10）", "btm_<区域>_<规格>：战场地图（10x10=必然遭遇规格，17 案 §3.9）"],
	}
	# ---- battle/tiles 域（6 条）----
	var tile_rules: Dictionary = {
		&"tile_normal": ["普通地面", "tile_<语义>：地格类型定义（默认地格）"],
		&"tile_obstacle": ["障碍", "tile_<语义>：地格类型定义（不可通行/阻断视线）"],
		&"tile_grass": ["草丛", "tile_<语义>：地格类型定义（STATUS 类绑定 BUFF_tile_grass/STANDING）"],
		&"tile_highground": ["高地", "tile_<语义>：地格类型定义（STATUS 类绑定 BUFF_tile_highground/STANDING）"],
		&"tile_poison_swamp": ["毒沼", "tile_<语义>：地格类型定义（STATUS 类绑定 DEBUFF_tile_poison/STANDING）"],
		&"tile_trap": ["陷阱", "tile_<语义>：地格类型定义（ENEMY_ENTER_ONCE 触发·纯伤害无状态绑定，第九轮拍板）"],
	}
	# ---- equip 域（6 条）----
	var equip_rules: Dictionary = {
		&"eqp_init_warrior": ["战士初始装备（重甲套）", "eqp_init_<职业>：DEMO 初始装备（不可卸下，17 案 §3.4/§3.11 #7）"],
		&"eqp_init_rogue": ["盗贼初始装备（皮甲套）", "eqp_init_<职业>：DEMO 初始装备（不可卸下）"],
		&"eqp_init_ranger": ["游侠初始装备（游侠皮甲套）", "eqp_init_<职业>：DEMO 初始装备（不可卸下）"],
		&"eqp_init_mage": ["法师初始装备（布甲套）", "eqp_init_<职业>：DEMO 初始装备（不可卸下）"],
		&"eqp_init_priest": ["牧师初始装备（布甲套）", "eqp_init_<职业>：DEMO 初始装备（不可卸下）"],
		&"eqp_init_arcanist": ["奇术师初始装备（布甲套）", "eqp_init_<职业>：DEMO 初始装备（不可卸下）"],
	}
	var appended: int = 0
	appended += _AppendEntries(entries, existing_ids, &"battle/maps", map_rules)
	appended += _AppendEntries(entries, existing_ids, &"battle/tiles", tile_rules)
	appended += _AppendEntries(entries, existing_ids, &"equip", equip_rules)
	registry.entries = entries
	registry.comment = "全库资源命名登记表（用户拍板②·2026-09-23）：每条记录资源 id/域前缀/中文名/命名规则；条目随资源增删同步维护；M1 批 1 追加战斗域 14 条（共 %d 条）" % entries.size()
	print("gen_m1_battle_data: naming_registry 登记条目数 = %d（新增 %d）" % [entries.size(), appended])
	return _SaveResource(registry, "res://data/core/naming_registry.tres")

func _AppendEntries(entries: Array[NamingEntry], existing_ids: Dictionary,
		domain: StringName, rules: Dictionary) -> int:
	## 向登记表追加一批条目（幂等：已在 existing_ids 的跳过）
	## 参数 entries：登记数组（原位追加）；existing_ids：已登记 id 集；domain：域键；rules：{id: [中文名, 规则注]}
	## 返回：实际追加条数
	var appended: int = 0
	for resource_id: StringName in rules:
		if existing_ids.has(resource_id):
			continue
		entries.append(_MakeNamingEntry(resource_id, domain,
				rules[resource_id][0], rules[resource_id][1]))
		existing_ids[resource_id] = true
		appended += 1
	return appended

func _MakeNamingEntry(resource_id: StringName, domain: StringName,
		display_name: String, rule_note: String) -> NamingEntry:
	## 构建命名登记条目子资源
	## 参数：资源 id / 所属域键 / 中文名 / 命名规则说明
	## 返回：NamingEntry
	var entry := NamingEntry.new()
	entry.resource_id = resource_id
	entry.domain = domain
	entry.display_name = display_name
	entry.rule_note = rule_note
	return entry
