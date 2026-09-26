## 公会壳（guild_shell）场景脚本
## 职责：M0 占位主场景——展示当前存档信息（save_point 名/game_day/mode，
## 肉眼验证读档一致的锚点）；「保存并返回标题」触发 DAY_END 自动存档演示；
## 「返回标题」不存档直接回标题；M3 批 2 增「出征（占位）」面板
## （P1：两委托按钮 + 临时职业勾选编队 → EXPLORE_SCREEN——M4 出征层接管）。
## B-22（M3 批 3 拍板 P2=A）：M1 战棋调试块与 M2 事件演示入口已拆除
## （event_screen 场景/注册/测试保留至 M4 清理）。
## 数据来源：M0 批 4 方案；屏规格=案 15 §2.2；M1 批 3 方案 §7.4；M3 方案批 2/3。
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

## 临时职业勾选编队表（节点名 -> 职业 id；默认勾选 = 初始固定 4 人）——
## 出征占位面板编队口；M4 出征层接管后随面板退役
const PARTY_CLASS_OPTIONS: Array = [
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
	## （22→subheading）/ 出征标题与警示（M3 批 2）；W3-08：四按钮补齐
	## （保存/返回/出征×2——按钮统一 normal 档，三屏收口）
	## 参数：无
	## 返回：无
	var cfg: CoreConfig = _game_data().get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	%SaveInfoLabel.get_parent().get_node("HeaderLabel").add_theme_font_size_override(
			"font_size", UiTheme.font_of(cfg, &"ui_font_size_title", UiTheme.FONT_TITLE))
	%SaveInfoLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_subheading", UiTheme.FONT_SUBHEADING))
	%SaveWarnLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	get_node("Center/Layout/ExpeditionTitle").add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_body", UiTheme.FONT_BODY))
	%ExpeditionWarnLabel.add_theme_font_size_override("font_size",
			UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL))
	var button_font: int = UiTheme.font_of(cfg, &"ui_font_size_normal", UiTheme.FONT_NORMAL)
	for button_path: String in ["Center/Layout/SaveAndBackButton", "Center/Layout/BackButton",
			"Center/Layout/ExpeditionQuestRow/ExpeditionExploreButton",
			"Center/Layout/ExpeditionQuestRow/ExpeditionPurgeButton"]:
		(get_node(button_path) as Button).add_theme_font_size_override("font_size", button_font)

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

func _on_expedition_explore_pressed() -> void:
	## 出征按钮①：探索委托「没能回家的托米」（q_lost_miner_keepsake——
	## 事件授予委托模板复用为占位出征口）
	## 参数：无
	## 返回：无
	_StartExpedition(&"q_lost_miner_keepsake")

func _on_expedition_purge_pressed() -> void:
	## 出征按钮②：清剿委托「清剿哥布林营地」（q_lair_purge——P1 提前落的
	## CLEAR 判据模板）
	## 参数：无
	## 返回：无
	_StartExpedition(&"q_lair_purge")

func _BuildCheckedParty() -> Array[AdventurerData]:
	## 按职业勾选组装出战队伍（17-C7 中值偏上掷值——出征占位面板编队口）
	## 参数：无
	## 返回：出战队伍（空 = 未勾选任何职业）
	var game_data: Node = _game_data()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var party: Array[AdventurerData] = []
	for entry: Dictionary in PARTY_CLASS_OPTIONS:
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
	return party

func _StartExpedition(quest_id: StringName) -> void:
	## 出征会话组装（P1 占位出征面板）：勾选编队 → 初始满血（装配口径派生）
	## → run.start_explore（委托判据上下文 + 迷雾/耗时基准注入）→
	## EXPLORE_SCREEN（expedition_run 跨场景参数）；至少 1 人校验
	## 参数 quest_id：委托模板 id
	## 返回：无
	var game_data: Node = _game_data()
	var cfg: CoreConfig = game_data.get_record(CoreConfig.CFG_MAIN_ID) as CoreConfig
	var party: Array[AdventurerData] = _BuildCheckedParty()
	if party.is_empty():
		%ExpeditionWarnLabel.text = "至少勾选 1 名职业"
		return
	%ExpeditionWarnLabel.text = ""
	var run := ExpeditionRun.new()
	for adv: AdventurerData in party:
		run.party.append(adv)
		var cls: ClassDef = game_data.get_record(adv.class_id) as ClassDef
		run.hp[adv] = DerivedStats.calc_hp(
				int(adv.attrs.get(&"constitution", 10)), cls, adv.level, cfg)
	var quest: QuestTemplateDef = game_data.get_record(quest_id) as QuestTemplateDef
	var map_def: ExploreMapDef = null
	if quest != null and quest.map_id != &"":
		map_def = game_data.get_record(quest.map_id) as ExploreMapDef
	if map_def == null:
		# V-4（2026-09-26 审计）：图域空越界守卫——取首图前判空（对齐
		# explore_screen._MakeDefaultRun 口径），空时警告提示并中止出征
		var maps: Array = game_data.get_domain(&"map/maps")
		if maps.is_empty():
			%ExpeditionWarnLabel.text = "探索图数据缺失——无法出征。（占位提示——M4 出征层接管）"
			push_warning("guild_shell: map/maps 域为空——出征中止（V-4）")
			return
		map_def = maps[0] as ExploreMapDef
	run.start_explore(map_def, quest, cfg.vision_radius)
	# R4-15：关键入口消费 go 返回值（切换失败可感知）
	var err: Error = _scene_manager().go(SceneManagerScript.SceneId.EXPLORE_SCREEN,
			{&"expedition_run": run})
	if err != OK:
		push_warning("guild_shell: 进入探索屏失败（错误码 %d）" % err)
