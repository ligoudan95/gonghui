## M0 批 1 占位数据生成器
## 职责：生成 data/core 域总控配置 cfg_main.tres，数值按 17 案 §3.1/§3.3/§3.10/§3.11
## 定值填充；用 ResourceSaver 写盘以保证 Godot 4.7.2 类型化容器序列化格式正确。
## 用法：先 godot --headless --import 重建全局类缓存，再
##   godot --headless -s res://tools/gen_m0_placeholders.gd
## 说明：naming_registry.tres 自批 2 起由 gen_m0_batch2_data.gd 生成（全库 48 条登记），
## 本工具不再生成；生成结果需人工在编辑器复核。
extends SceneTree

## !! 警示（解耦复审 C-10）：本工具为 M0/M1 首次生成占位数据的脚本——
## 全库数据已人工调校定稿，重跑将【覆盖调校值】，必须先备份并对 diff
## 逐行复核后才可采纳。

## DEMO 启用系统键（真键 13，案 16 启用清单）
const ENABLED_KEYS: Array[StringName] = [
	&"calendar", &"guild_facility", &"economy", &"adventurer", &"quest",
	&"map_explore", &"event_check", &"battle", &"class_skill", &"status",
	&"world_scene", &"ui_config", &"auto_save",
]

## DEMO 禁用系统键（假键 9）
const DISABLED_KEYS: Array[StringName] = [
	&"stress", &"second_class", &"shop", &"craft_chain", &"quest_noncombat",
	&"event_exit_d", &"hidden_content", &"npc_place", &"story",
]

## 难度五档判定线（案 17 §3.3：极易/容易/普通/困难/极难）
const DIFFICULTY_TIERS: Dictionary[String, int] = {
	"极易": 5,
	"容易": 8,
	"普通": 11,
	"困难": 14,
	"极难": 17,
}

func _initialize() -> void:
	## MainLoop 回调：生成两个占位资源后退出
	## 参数：无
	## 返回：无（任一保存失败按退出码 1 结束）
	var ok: bool = true
	ok = _GenerateCoreConfig() and ok
	if ok:
		print("gen_m0_placeholders: 全部占位数据生成完成")
		quit(0)
	else:
		printerr("gen_m0_placeholders: 存在保存失败项")
		quit(1)

func _GenerateCoreConfig() -> bool:
	## 生成 data/core/cfg_main.tres（17 案 §3.1/§3.3/§3.10/§3.11 定值）
	## 参数：无
	## 返回：true = 保存成功
	var cfg := CoreConfig.new()
	cfg.id = &"cfg_main"
	cfg.mode = CoreConfig.Mode.DEMO
	var enabled: Dictionary[StringName, bool] = {}
	for key: StringName in ENABLED_KEYS:
		enabled[key] = true
	for key: StringName in DISABLED_KEYS:
		enabled[key] = false
	cfg.enabled_systems = enabled
	cfg.attr_modifier_offset = 10
	cfg.attr_modifier_divisor = 2
	cfg.difficulty_tiers = DIFFICULTY_TIERS
	cfg.crit_success_drop_divisor = 3
	cfg.crit_success_line_min = 16
	cfg.luck_floor_y = 4
	cfg.luck_floor_z_base = 2
	cfg.luck_floor_z_divisor = 4
	cfg.vision_radius = 3
	cfg.secret_door_trigger_radius = 2
	cfg.status_stack_limit = 2
	cfg.hit_clamp_min = 0.05
	cfg.hit_clamp_max = 0.95
	cfg.damage_floor = 1
	cfg.comment = "【占位·试玩校准】数值来源：17 案 §3.1/§3.3/§3.10/§3.11（DEMO 最小数值集）"
	return _SaveResource(cfg, "res://data/core/cfg_main.tres")

func _SaveResource(resource: Resource, path: String) -> bool:
	## 保存资源到指定路径并打印结果
	## 参数 resource：待保存资源；path：目标 res:// 路径
	## 返回：true = 保存成功
	var err: Error = ResourceSaver.save(resource, path)
	if err != OK:
		printerr("gen_m0_placeholders: 保存失败 %s（错误码 %d）" % [path, err])
		return false
	print("gen_m0_placeholders: 已生成 %s" % path)
	return true
