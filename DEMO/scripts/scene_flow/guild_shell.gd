## 公会壳（guild_shell）场景脚本
## 职责：M0 占位主场景——展示当前存档信息（save_point 名/game_day/mode，
## 肉眼验证读档一致的锚点）；「保存并返回标题」触发 DAY_END 自动存档演示；
## 「返回标题」不存档直接回标题；M1 批 3 增「战棋原型调试入口」面板
## （拍板 B：6 职业勾选 + 两遭遇按钮 → BATTLE_SCREEN；M2 后拆除）。
## 数据来源：M0 批 4 方案；屏规格=案 15 §2.2；M1 批 3 方案 §7.4。
## 单例访问：统一 get_node("/root/X")（gdUnit 测试环境不注册 autoload 标识符）。
extends Control

## SceneManager 脚本常量引用（枚举常量不可经实例属性访问，见 title_screen.gd 注）
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")

## 存档点枚举 -> 中文（B-12：SavePoint 全枚举映射——原英文枚举名直出）
const SAVE_POINT_NAMES: Dictionary = {
	SaveData.SavePoint.DAY_END: "日结算",
	SaveData.SavePoint.RETURN_SETTLED: "回城结算",
	SaveData.SavePoint.FACILITY_UPGRADED: "设施升级",
	SaveData.SavePoint.RECRUIT_DONE: "招募完成",
}

## 调试入口职业勾选表（节点名 -> 职业 id；默认勾选 = 初始固定 4 人）
const DEBUG_CLASSES: Array = [
	{"check": "CheckWarrior", "class_id": &"cls_warrior", "default": true},
	{"check": "CheckRogue", "class_id": &"cls_rogue", "default": true},
	{"check": "CheckMage", "class_id": &"cls_mage", "default": true},
	{"check": "CheckPriest", "class_id": &"cls_priest", "default": true},
	{"check": "CheckRanger", "class_id": &"cls_ranger", "default": false},
	{"check": "CheckArcanist", "class_id": &"cls_arcanist", "default": false},
]

func _ready() -> void:
	## 引擎回调：取走跨场景参数（读后清空机制）并刷新存档信息展示；
	## B-7：tscn 内嵌字号按档位覆写（tscn 值留占位——字号体系只动 cfg）
	## 参数：无
	## 返回：无
	_ApplyFontTiers()
	_scene_manager().take_pending_params()
	_RefreshSaveInfo()

func _ApplyFontTiers() -> void:
	## tscn 内嵌字号档位覆写（B-7）：HeaderLabel（48→title）/ SaveInfoLabel
	## （22→subheading）/ 调试标题（20→body）
	## 参数：无
	## 返回：无
	var cfg: CoreConfig = _game_data().get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	%SaveInfoLabel.get_parent().get_node("HeaderLabel").add_theme_font_size_override(
			"font_size", UiTheme.font_of(cfg, &"ui_font_size_title", UiTheme.FONT_TITLE))
	%SaveInfoLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	%SaveWarnLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	get_node("Center/Layout/DebugTitle").add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_body", UiTheme.FONT_BODY))
	# R3-06：调试警示标签同档位覆写（漏网补齐）
	%DebugWarnLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))

func _save_manager() -> Node:
	## 取 SaveManager 自动加载单例（节点路径方式，环境无关）
	## 参数：无
	## 返回：SaveManager 节点
	return get_node("/root/SaveManager")

func _scene_manager() -> Node:
	## 取 SceneManager 自动加载单例（节点路径方式，环境无关）
	## 参数：无
	## 返回：SceneManager 节点
	return get_node("/root/SceneManager")

func _game_data() -> Node:
	## 取 GameData 自动加载单例（职业表/装备解析）
	## 参数：无
	## 返回：GameData 节点
	return get_node("/root/GameData")

func _RefreshSaveInfo() -> void:
	## 刷新存档信息展示（无运行态时显示提示）
	## 参数：无
	## 返回：无
	var save: SaveData = _save_manager().current
	if save == null:
		%SaveInfoLabel.text = "（无运行态存档）"
		return
	var point_name: String = String(SAVE_POINT_NAMES.get(save.save_point,
			SaveData.SavePoint.find_key(save.save_point)))
	%SaveInfoLabel.text = "存档点：%s｜游戏天数：%d｜模式：%s" % [point_name, save.game_day, save.mode]

func _on_save_and_back_pressed() -> void:
	## 「保存并返回标题」：DAY_END 自动存档（M0 演示触发点）后回标题；
	## S5-4：autosave 失败（FAILED）时提示保存失败并留在本屏（不切场景、
	## 不吞错误——存档写入异常用户可重试）
	## 参数：无
	## 返回：无
	if _save_manager().autosave(SaveData.SavePoint.DAY_END) != OK:
		# B-21：存档警示独立标签（与调试入口警示拆离——M2 拆调试块不误伤）
		%SaveWarnLabel.text = "存档写入失败——已留在本屏，请重试"
		return
	%SaveWarnLabel.text = ""
	_scene_manager().go(SceneManagerScript.SceneId.TITLE)

func _on_back_pressed() -> void:
	## 「返回标题」：不存档直接回标题
	## 参数：无
	## 返回：无
	_scene_manager().go(SceneManagerScript.SceneId.TITLE)

func _on_debug_random_pressed() -> void:
	## 调试入口①：随机遭遇战（8×8，enc_m1_random_pack）
	## 参数：无
	## 返回：无
	_StartDebugBattle(&"enc_m1_random_pack")

func _on_debug_lair_pressed() -> void:
	## 调试入口②：必然遭遇战（10×10，enc_m1_lair_pack）
	## 参数：无
	## 返回：无
	_StartDebugBattle(&"enc_m1_lair_pack")

func _StartDebugBattle(pack_id: StringName) -> void:
	## 组装调试出战队伍（勾选职业，17-C7 中值偏上掷值）并切 BATTLE_SCREEN；
	## 至少 1 人校验（不足时警示标签、不切场景）；S3-04：勾选上限对齐
	## 遭遇地图出生位数（动态查表零硬编码——超编在 BattleSetup 侧也已硬拒）
	## 参数 pack_id：遭遇队伍 id
	## 返回：无
	var game_data: Node = _game_data()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var party: Array[AdventurerData] = []
	for entry: Dictionary in DEBUG_CLASSES:
		var check: CheckBox = get_node("%" + String(entry["check"])) as CheckBox
		if check == null or not check.button_pressed:
			continue
		var class_id: StringName = entry["class_id"]
		var cls: ClassDef = game_data.get_record(class_id) as ClassDef
		if cls == null:
			continue
		var attrs: Dictionary[StringName, int] = AttrRoller.roll_fixed_four(cls, rng)
		party.append(AdventurerData.create_debug(
				StringName(String(class_id).trim_prefix("cls_")),
				class_id, attrs, game_data))
	if party.is_empty():
		%DebugWarnLabel.text = "至少勾选 1 名职业"
		return
	# S3-04：出战人数 ≤ 该遭遇地图我方出生位（超编提示不切场景）
	var pack: EnemyPackDef = game_data.get_record(pack_id) as EnemyPackDef
	if pack != null:
		var map_def: BattleMapDef = game_data.get_record(pack.battle_map_ref) as BattleMapDef
		if map_def != null and party.size() > map_def.player_spawns.size():
			%DebugWarnLabel.text = "至多勾选 %d 名职业（地图出生位上限）" % map_def.player_spawns.size()
			return
	%DebugWarnLabel.text = ""
	var params := BattleParams.new()
	params.pack_id = pack_id
	params.party = party
	# R4-15：关键入口消费 go 返回值（切换失败可感知）
	var err: Error = _scene_manager().go(SceneManagerScript.SceneId.BATTLE_SCREEN,
			{&"battle_params": params})
	if err != OK:
		push_warning("guild_shell: 进入战斗屏失败（错误码 %d）" % err)
