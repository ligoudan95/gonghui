## M3 批 1 探索层数据生成器
## 职责：生成 DEMO 探索层内容表——区域 3 / 探索地格 4 / 探索图 1
## （map_m1_village_mine：村口南段 3 行全亮 + 矿洞 12 行，P3=A 15×15 总图）/
## 交互点 11（链三 + 村子单点二 + 暗门 + 必然遭遇 + 宝箱三 + 出口）/
## 目标点 6（矿洞五勘查点 + 村子老井）/ 遭遇权重 2 / 委托模板 q_lair_purge 1
## （P1 提前落）+ q_lost_miner_keepsake 回填 map_id/region_id（V-M3 闭环）/
## 隐藏标记 hm_mine_secret_door 1；重生成命名登记表（+29 条）。
## 内容来源：案 7《地图与探索》；案 18 §2.6（q_lair_purge 定稿行）；
## M3 方案批 1（P1/P3 拍板）。数值【占位·试玩校准】。
## 用法：godot --headless --import 后
##   godot --headless -s res://tools/gen_m3_explore_data.gd
## 注：可重复执行（幂等覆盖；q_lost_miner_keepsake 仅回填两字段——其余字段
## 保留磁盘现值）。
extends SceneTree

## !! 警示（沿 gen_m2_event_data C-10 同口径）：本工具为首次生成占位数据的
## 脚本——全库数据已人工调校定稿，重跑将【覆盖调校值】，必须先备份并对 diff
## 逐行复核后才可采纳。

## DEMO 探索图 id（q_lost_miner_keepsake 回填与探索屏路由共引）
const MAP_ID: StringName = &"map_m1_village_mine"

func _initialize() -> void:
	## MainLoop 回调：依次生成区域/地格/图/交互点/目标点/遭遇权重/委托/
	## 隐藏标记、重生成命名登记表后退出
	## 参数：无
	## 返回：无（任一保存失败按退出码 1 结束）
	var ok: bool = true
	ok = _GenerateRegions() and ok
	ok = _GenerateTiles() and ok
	ok = _GenerateMap() and ok
	ok = _GenerateInteractPoints() and ok
	ok = _GenerateTargetPoints() and ok
	ok = _GenerateEncounterWeights() and ok
	ok = _GenerateQuests() and ok
	ok = _GenerateHiddenMarks() and ok
	ok = _RegenerateNamingRegistry() and ok
	if ok:
		print("gen_m3_explore_data: 全部数据生成完成")
		quit(0)
	else:
		printerr("gen_m3_explore_data: 存在保存失败项")
		quit(1)

func _SaveResource(resource: Resource, path: String) -> bool:
	## 保存资源到指定路径（目录不存在则先创建）
	## 参数 resource：待保存资源；path：目标 res:// 路径
	## 返回：true = 保存成功
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err: Error = ResourceSaver.save(resource, path)
	if err != OK:
		printerr("保存失败 %s（错误码 %d）" % [path, err])
		return false
	print("已生成 %s" % path)
	return true

func _GenerateRegions() -> bool:
	## 生成区域 3 条（reg_city 登记不落图 / reg_village 村子段 / reg_mine 矿洞段）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	var rules: Array = [
		[&"reg_city", "光辉城", "工会总部所在的大城市——委托与结算的归处。",
				"reg_<语义>：世界区域（M3；DEMO 城区不落图）"],
		[&"reg_village", "村口聚落", "贴着矿洞讨生活的村子南段——安全区，无随机遭遇。",
				"reg_<语义>：世界区域（M3；探索图全亮行段）"],
		[&"reg_mine", "矿洞一层", "哥布林盘踞的旧矿洞，深处有巢穴。",
				"reg_<语义>：世界区域（M3；探索图雾行段）"],
	]
	for rule: Array in rules:
		var region := RegionDef.new()
		region.id = rule[0]
		region.display_name = rule[1]
		region.description = rule[2]
		region.comment = "【占位·试玩校准】" + rule[3]
		ok = _SaveResource(region, "res://data/world/regions/%s.tres" % rule[0]) and ok
	return ok

func _GenerateTiles() -> bool:
	## 生成探索地格 4 条（floor/wall/path/village_ground——程序化占位视觉色块）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	var rules: Array = [
		[&"etile_floor", "矿洞地面", true,
				Color(0.24, 0.22, 0.19, 1), Color(0, 0, 0, 0), ExploreTileDef.Style.PLAIN,
				"etile_<语义>：探索地格（普通可通行）"],
		[&"etile_wall", "岩壁", false,
				Color(0.13, 0.13, 0.15, 1), Color(0.05, 0.05, 0.06, 1), ExploreTileDef.Style.BLOCK,
				"etile_<语义>：探索地格（障碍——寻路绕行）"],
		[&"etile_path", "隐秘通道", true,
				Color(0.55, 0.45, 0.25, 1), Color(0.85, 0.7, 0.35, 1), ExploreTileDef.Style.RAISED,
				"etile_<语义>：探索地格（暗门揭示后的捷径——reveal_tile_id 目标）"],
		[&"etile_village_ground", "村中土路", true,
				Color(0.30, 0.38, 0.24, 1), Color(0, 0, 0, 0), ExploreTileDef.Style.PLAIN,
				"etile_<语义>：探索地格（村子段地面）"],
	]
	for rule: Array in rules:
		var tile := ExploreTileDef.new()
		tile.id = rule[0]
		tile.display_name = rule[1]
		tile.walkable = rule[2]
		tile.fill_color = rule[3]
		tile.accent_color = rule[4]
		tile.style = rule[5]
		tile.comment = "【占位·试玩校准】" + rule[6]
		ok = _SaveResource(tile, "res://data/map/tiles/%s.tres" % rule[0]) and ok
	return ok

func _GenerateMap() -> bool:
	## 生成探索图 1 条（map_m1_village_mine——15×15：y0-2 村子段全亮 /
	## y3-14 矿洞段；北廊-西巷-东竖-中层的回字形矿道，中央竖井直通底部巢穴；
	## 暗门 (12,5)(12,6) 揭示为捷径，连通北廊东端与西巷横廊）
	## 参数：无
	## 返回：true = 保存成功
	var map_def := ExploreMapDef.new()
	map_def.id = MAP_ID
	map_def.display_name = "村口矿道·总图"
	map_def.size = Vector2i(15, 15)
	map_def.rows = [
		"vvvvvvvvvvvvvvv",  # y=0  村子段（(5,0) 旅人 / (7,0) 回城出口）
		"vvvvvvvvvvvvvvv",  # y=1  村子段（(7,1) 出生格）
		"vvvvvvvvvvvvvvv",  # y=2  村子段（(10,2) 板车 / (7,3) 矿洞入口在其下）
		"XXXXXXX.XXXXXXX",  # y=3  矿洞北壁（仅 x=7 入口）
		"X.............X",  # y=4  北廊（(1,4) 矿箱 / (9,4) 北壁勘查点 / (12,4) 暗门）
		"X.XXXXX.XXXXX.X",  # y=5  西竖井/中央竖井/东竖井（暗门揭示格 (12,5)）
		"X.XXXXX.XXXXX.X",  # y=6  同上（暗门揭示格 (12,6)；(1,6) 塌方救援）
		"X.............X",  # y=7  中层横廊（(1,7) 西巷勘查点 / (4,7) 营地 / (13,7) 东矿脉）
		"XXX.XXX.XXX.XXX",  # y=8  三竖井（(3,8) 矿道鬼火）
		"XXX.XXX.XXX.XXX",  # y=9  三竖井
		"X.............X",  # y=10 下层横廊（(1,10) 矿箱 / (13,10) 矿箱）
		"XXXX.XX.XX.XXXX",  # y=11 下层三竖井
		"XXXX.XX.XX.XXXX",  # y=12 下层三竖井
		"XXX.........XXX",  # y=13 底层横廊（(3,13) 南竖井 / (5,13) 老井暗窖 / (11,13) 调车场）
		"XXXXXXX.XXXXXXX",  # y=14 巢穴（(7,14) 必然遭遇）
	]
	var legend: Dictionary[StringName, StringName] = {
		&".": &"etile_floor",
		&"X": &"etile_wall",
		&"v": &"etile_village_ground",
		&"p": &"etile_path",
	}
	map_def.legend = legend
	map_def.region_ids = [&"reg_village", &"reg_mine"]
	map_def.start_cell = Vector2i(7, 1)
	map_def.fog_enabled = true
	map_def.fog_lit_rows = [0, 1, 2]
	map_def.base_expedition_days = 1
	map_def.comment = "【占位·试玩校准】M3 P3=A 总图：村子南段 3 行全亮 + 矿洞 12 行；" \
			+ "region_ids 惯例序 [全亮行段（村子）, 其余（矿洞）]；" \
			+ "耗时基准唯一权威 base_expedition_days=1（ExpeditionRun 注入）"
	return _SaveResource(map_def, "res://data/map/maps/%s.tres" % MAP_ID)

func _GenerateInteractPoints() -> bool:
	## 生成交互点 11 条（链三 ENTER + 村子单点二 ENTER + 暗门 NEAR +
	## 必然遭遇 ENTER + 宝箱三 TAP + 出口 TAP）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	var rules: Array = [
		[&"evp_mine_01", "塌方救援", Vector2i(1, 6), InteractPointDef.Kind.CHAIN,
				InteractPointDef.Trigger.ENTER, &"chain_mine_collapse", 0, 0, [], &"",
				"evp_<区域>_<序>：交互点（链入口——塌方区）"],
		[&"evp_mine_02", "矿道鬼火", Vector2i(3, 8), InteractPointDef.Kind.CHAIN,
				InteractPointDef.Trigger.ENTER, &"chain_mine_wisp", 0, 0, [], &"",
				"evp_<区域>_<序>：交互点（链入口——岔道）"],
		[&"evp_mine_03", "废弃矿工营地", Vector2i(4, 7), InteractPointDef.Kind.CHAIN,
				InteractPointDef.Trigger.ENTER, &"chain_mine_camp", 0, 0, [], &"",
				"evp_<区域>_<序>：交互点（链入口——西巷营地）"],
		[&"evp_village_01", "陷进泥里的板车", Vector2i(10, 2), InteractPointDef.Kind.SINGLE,
				InteractPointDef.Trigger.ENTER, &"sp_village_cart", 0, 0, [], &"",
				"evp_<区域>_<序>：交互点（村子单点）"],
		[&"evp_village_02", "井边的旅人", Vector2i(5, 0), InteractPointDef.Kind.SINGLE,
				InteractPointDef.Trigger.ENTER, &"sp_village_traveler", 0, 0, [], &"",
				"evp_<区域>_<序>：交互点（村子单点——暗门铺垫）"],
		[&"evp_mine_secret", "北壁的风", Vector2i(12, 4), InteractPointDef.Kind.SECRET_DOOR,
				InteractPointDef.Trigger.NEAR, &"sp_mine_secretdoor", 0, 0,
				[Vector2i(12, 5), Vector2i(12, 6)], &"etile_path",
				"evp_<区域>_<语义>：交互点（暗门——揭示 (12,5)(12,6) 为捷径，连通北廊东端与西巷横廊；【试玩观察项 L6】捷径全局收益偏弱——主路 6 格/捷径 4 格，试玩后校准 reveal_cells 范围）"],
		[&"evp_mine_lair", "哥布林营地", Vector2i(7, 14), InteractPointDef.Kind.BATTLE,
				InteractPointDef.Trigger.ENTER, &"enc_m1_lair_pack", 0, 0, [], &"",
				"evp_<区域>_<语义>：交互点（必然遭遇——巢穴）"],
		[&"evp_mine_chest_01", "弃置矿箱·北廊", Vector2i(1, 4), InteractPointDef.Kind.TREASURE,
				InteractPointDef.Trigger.TAP, &"", 20, 40, [], &"",
				"evp_<区域>_<语义>：交互点（宝箱——金域 [20,40]）"],
		[&"evp_mine_chest_02", "弃置矿箱·西巷", Vector2i(1, 10), InteractPointDef.Kind.TREASURE,
				InteractPointDef.Trigger.TAP, &"", 20, 35, [], &"",
				"evp_<区域>_<语义>：交互点（宝箱——金域 [20,35]）"],
		[&"evp_mine_chest_03", "弃置矿箱·东场", Vector2i(13, 10), InteractPointDef.Kind.TREASURE,
				InteractPointDef.Trigger.TAP, &"", 25, 40, [], &"",
				"evp_<区域>_<语义>：交互点（宝箱——金域 [25,40]）"],
		[&"evp_village_exit", "回城出口", Vector2i(7, 0), InteractPointDef.Kind.EXIT,
				InteractPointDef.Trigger.TAP, &"", 0, 0, [], &"",
				"evp_<区域>_<语义>：交互点（出口——判据达成后点按交付）"],
	]
	for rule: Array in rules:
		var point := InteractPointDef.new()
		point.id = rule[0]
		point.display_name = rule[1]
		point.cell = rule[2]
		point.kind = rule[3]
		point.trigger = rule[4]
		point.ref_id = rule[5]
		point.gold_min = rule[6]
		point.gold_max = rule[7]
		# 类型化数组显式构建（Variant 中间量直赋类型化属性不走编译期转换）
		var reveal: Array[Vector2i] = []
		for cell: Vector2i in rule[8]:
			reveal.append(cell)
		point.reveal_cells = reveal
		point.reveal_tile_id = rule[9]
		point.comment = "【占位·试玩校准】" + rule[10]
		ok = _SaveResource(point, "res://data/map/interact_points/%s.tres" % rule[0]) and ok
	return ok

func _GenerateTargetPoints() -> bool:
	## 生成目标点 6 条（矿洞五勘查点 + 村子老井——EXPLORE 判据目标）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	var rules: Array = [
		[&"tp_mine_east_gallery", "东岔道矿脉", Vector2i(13, 7),
				"tp_<区域>_<语义>：目标点（东矿脉观测点——q_vein_survey 类锚点，DEMO 由老井线消费）"],
		[&"tp_mine_north_wall", "北壁", Vector2i(9, 4),
				"tp_<区域>_<语义>：目标点（北壁观测点——暗门事件近旁）"],
		[&"tp_mine_south_shaft", "南竖井", Vector2i(3, 13),
				"tp_<区域>_<语义>：目标点（南竖井观测点）"],
		[&"tp_mine_west_camp", "西巷旧营地", Vector2i(1, 7),
				"tp_<区域>_<语义>：目标点（西巷巡查点）"],
		[&"tp_mine_track_yard", "轨道调车场", Vector2i(11, 13),
				"tp_<区域>_<语义>：目标点（调车场勘验点）"],
		[&"tp_old_well", "老井暗窖", Vector2i(5, 13),
				"tp_<语义>：目标点（老井暗窖——井道直通矿洞底层；M3 质检 M1 拍板 B：移矿洞深处；q_lost_miner_keepsake 判据）"],
	]
	for rule: Array in rules:
		var target := TargetPointDef.new()
		target.id = rule[0]
		target.display_name = rule[1]
		target.cell = rule[2]
		target.comment = "【占位·试玩校准】" + rule[3]
		ok = _SaveResource(target, "res://data/map/target_points/%s.tres" % rule[0]) and ok
	return ok

func _GenerateEncounterWeights() -> bool:
	## 生成遭遇权重 2 条（encw_mine 0 / encw_village 0——用户拍板 2026-09-25
	## 【DEMO 排除所有随机战斗】：机制保留、数据侧关闭，两区均 chance 0
	## 前置拒掷；pack 仅为引用闭环占位）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	var rules: Array = [
		[&"encw_mine", &"reg_mine", 0.0, &"enc_m1_random_pack", 1,
				"【用户拍板 2026-09-25】DEMO 排除所有随机战斗——机制保留数据侧关闭（chance 0 前置拒掷；pack 仅为引用闭环占位，与村区同口径）"],
		[&"encw_village", &"reg_village", 0.0, &"enc_m1_random_pack", 1,
				"encw_<区域>：遭遇权重（村子——安全区，chance 0 不掷；pack 仅为引用闭环占位）"],
	]
	for rule: Array in rules:
		var weight := EncounterWeightDef.new()
		weight.id = rule[0]
		weight.region_id = rule[1]
		weight.encounter_chance = rule[2]
		weight.random_pack_id = rule[3]
		weight.random_max = rule[4]
		weight.comment = "【占位·试玩校准】" + rule[5]
		ok = _SaveResource(weight, "res://data/map/encounter_weights/%s.tres" % rule[0]) and ok
	return ok

func _GenerateQuests() -> bool:
	## 生成委托模板 q_lair_purge 1 条（P1 提前落——CLEAR 判据委托模板）+ 回填
	## q_lost_miner_keepsake 的 map_id/region_id（V-M3-ref-quest-goal 闭环；
	## 其余字段保留磁盘现值）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	var quest := QuestTemplateDef.new()
	quest.id = &"q_lair_purge"
	quest.display_name = "清剿哥布林营地"
	quest.quest_type = QuestTemplateDef.QuestType.NORMAL
	quest.exec_class = QuestTemplateDef.ExecClass.COMBAT
	quest.level_tier = 1
	quest.goal_type = QuestTemplateDef.GoalType.CLEAR
	quest.goal_param = &"enc_m1_lair_pack"
	quest.region_id = &"reg_mine"
	quest.map_id = MAP_ID
	quest.party_min = 3
	quest.party_max = 4
	quest.time_limit_days = 5
	var reward := RewardDef.new()
	reward.exp = 80
	reward.gold = 150
	reward.reputation = 5
	quest.reward = reward
	quest.acquire_channel = QuestTemplateDef.AcquireChannel.BOARD
	quest.comment = "【占位·试玩校准】案 18 §2.6 定稿行（P1 提前落）；CLEAR 判据 " \
			+ "enc_m1_lair_pack；人力 3-4（2026-09-25 M3 质检拍板改回案文定稿）；时限 5 天；奖励 150金/80经验/声望5"
	ok = _SaveResource(quest, "res://data/quest/templates/q_lair_purge.tres") and ok
	# q_lost_miner_keepsake 回填（仅两字段——磁盘现值加载后改写）
	var keepsake: QuestTemplateDef = ResourceLoader.load(
			"res://data/quest/templates/q_lost_miner_keepsake.tres", "",
			ResourceLoader.CACHE_MODE_IGNORE) as QuestTemplateDef
	if keepsake == null:
		printerr("gen_m3_explore_data: q_lost_miner_keepsake 加载失败")
		return false
	keepsake.map_id = MAP_ID
	keepsake.region_id = &"reg_mine"
	return _SaveResource(keepsake, "res://data/quest/templates/q_lost_miner_keepsake.tres") and ok

func _GenerateHiddenMarks() -> bool:
	## 生成隐藏标记 1 条（hm_mine_secret_door——暗门 unlock_flag 登记；
	## hidden_marks 域 M2 先建后空、M3 落首行）
	## 参数：无
	## 返回：true = 保存成功
	var mark := HiddenMarkDef.new()
	mark.id = &"hm_mine_secret_door"
	mark.display_name = "北壁暗门"
	mark.unlock_flag = &"secret_door_mine_north"
	mark.comment = "【占位·试玩校准】hm_<语义>：隐藏标记（sp_mine_secretdoor " \
			+ "成功出口 unlock_flag=secret_door_mine_north 承载）"
	return _SaveResource(mark, "res://data/event/hidden_marks/hm_mine_secret_door.tres")

func _RegenerateNamingRegistry() -> bool:
	## 重生成命名登记表：追加 M3 的 29 条（图 1/地格 4/交互点 11/目标点 6/
	## 权重 2/区域 3/委托 1/标记 1），幂等（已登记跳过）
	## 参数：无
	## 返回：true = 保存成功
	var registry: NamingRegistry = ResourceLoader.load(
			"res://data/core/naming_registry.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as NamingRegistry
	if registry == null:
		printerr("gen_m3_explore_data: naming_registry 加载失败")
		return false
	var entries: Array[NamingEntry] = registry.entries
	var existing_ids: Dictionary = {}
	for entry: NamingEntry in entries:
		existing_ids[entry.resource_id] = true
	var map_rules: Dictionary = {
		MAP_ID: ["村口矿道·总图", "map_<区域>_<语义>：探索图（M3·P3=A 总图）"],
	}
	var tile_rules: Dictionary = {
		&"etile_floor": ["矿洞地面", "etile_<语义>：探索地格（可通行）"],
		&"etile_wall": ["岩壁", "etile_<语义>：探索地格（障碍）"],
		&"etile_path": ["隐秘通道", "etile_<语义>：探索地格（暗门捷径）"],
		&"etile_village_ground": ["村中土路", "etile_<语义>：探索地格（村子段）"],
	}
	var point_rules: Dictionary = {
		&"evp_mine_01": ["塌方救援（点）", "evp_<区域>_<序>：交互点（链入口）"],
		&"evp_mine_02": ["矿道鬼火（点）", "evp_<区域>_<序>：交互点（链入口）"],
		&"evp_mine_03": ["废弃矿工营地（点）", "evp_<区域>_<序>：交互点（链入口）"],
		&"evp_village_01": ["陷进泥里的板车（点）", "evp_<区域>_<序>：交互点（村子单点）"],
		&"evp_village_02": ["井边的旅人（点）", "evp_<区域>_<序>：交互点（村子单点）"],
		&"evp_mine_secret": ["北壁的风（点）", "evp_<区域>_<语义>：交互点（暗门 NEAR）"],
		&"evp_mine_lair": ["哥布林营地（点）", "evp_<区域>_<语义>：交互点（必然遭遇）"],
		&"evp_mine_chest_01": ["弃置矿箱·北廊", "evp_<区域>_<语义>：交互点（宝箱 TAP）"],
		&"evp_mine_chest_02": ["弃置矿箱·西巷", "evp_<区域>_<语义>：交互点（宝箱 TAP）"],
		&"evp_mine_chest_03": ["弃置矿箱·东场", "evp_<区域>_<语义>：交互点（宝箱 TAP）"],
		&"evp_village_exit": ["回城出口（点）", "evp_<区域>_<语义>：交互点（出口 TAP）"],
	}
	var target_rules: Dictionary = {
		&"tp_mine_east_gallery": ["东岔道矿脉", "tp_<区域>_<语义>：目标点（勘查）"],
		&"tp_mine_north_wall": ["北壁", "tp_<区域>_<语义>：目标点（勘查）"],
		&"tp_mine_south_shaft": ["南竖井", "tp_<区域>_<语义>：目标点（勘查）"],
		&"tp_mine_west_camp": ["西巷旧营地", "tp_<区域>_<语义>：目标点（勘查）"],
		&"tp_mine_track_yard": ["轨道调车场", "tp_<区域>_<语义>：目标点（勘查）"],
		&"tp_old_well": ["老井暗窖", "tp_<语义>：目标点（矿洞深处——判据锚点；M3 质检拍板 B 移位）"],
	}
	var encw_rules: Dictionary = {
		&"encw_mine": ["矿洞遭遇权重", "encw_<区域>：遭遇权重"],
		&"encw_village": ["村子遭遇权重", "encw_<区域>：遭遇权重（安全区）"],
	}
	var region_rules: Dictionary = {
		&"reg_city": ["光辉城", "reg_<语义>：世界区域"],
		&"reg_village": ["村口聚落", "reg_<语义>：世界区域"],
		&"reg_mine": ["矿洞一层", "reg_<语义>：世界区域"],
	}
	var quest_rules: Dictionary = {
		&"q_lair_purge": ["清剿哥布林营地", "q_<语义>：委托模板（板刷——CLEAR 判据）"],
	}
	var mark_rules: Dictionary = {
		&"hm_mine_secret_door": ["北壁暗门", "hm_<语义>：隐藏标记（暗门 unlock_flag 登记）"],
	}
	var appended: int = 0
	appended += _AppendEntries(entries, existing_ids, &"map/maps", map_rules)
	appended += _AppendEntries(entries, existing_ids, &"map/tiles", tile_rules)
	appended += _AppendEntries(entries, existing_ids, &"map/interact_points", point_rules)
	appended += _AppendEntries(entries, existing_ids, &"map/target_points", target_rules)
	appended += _AppendEntries(entries, existing_ids, &"map/encounter_weights", encw_rules)
	appended += _AppendEntries(entries, existing_ids, &"world/regions", region_rules)
	appended += _AppendEntries(entries, existing_ids, &"quest/templates", quest_rules)
	appended += _AppendEntries(entries, existing_ids, &"event/hidden_marks", mark_rules)
	_SyncEntryTexts(entries, {
		&"tp_old_well": ["老井暗窖", "tp_<语义>：目标点（矿洞深处——判据锚点；M3 质检拍板 B 移位）"],
	})
	print("gen_m3_explore_data: naming 登记追加 %d 条（总 %d）" % [appended, entries.size()])
	return _SaveResource(registry, "res://data/core/naming_registry.tres")

func _SyncEntryTexts(entries: Array[NamingEntry], texts: Dictionary) -> void:
	## 既有条目文案同步（幂等追加不改旧条——移位/改名经本口刷新中文名与规则注）。
	## W4-16 登记注：一次性数据生成工具的补丁口——M3 数据全部落盘定稿后随
	## 本工具整体退役（再生成场景消失），勿再为单条文案漂移追加同步规则
	## 参数 entries：登记表现状；texts：id -> [中文名, 规则注]
	## 返回：无
	for entry: NamingEntry in entries:
		if not texts.has(entry.resource_id):
			continue
		entry.display_name = texts[entry.resource_id][0]
		entry.rule_note = texts[entry.resource_id][1]

func _AppendEntries(entries: Array[NamingEntry], existing_ids: Dictionary,
		domain: StringName, rules: Dictionary) -> int:
	## 幂等追加登记条目
	## 参数 entries/existing_ids：登记表现状；domain：域键；rules：id -> [中文名, 规则注]
	## 返回：追加条数
	var appended: int = 0
	for record_id: StringName in rules:
		if existing_ids.has(record_id):
			continue
		var entry := NamingEntry.new()
		entry.resource_id = record_id
		entry.domain = domain
		entry.display_name = rules[record_id][0]
		entry.rule_note = rules[record_id][1]
		entries.append(entry)
		existing_ids[record_id] = true
		appended += 1
	return appended
