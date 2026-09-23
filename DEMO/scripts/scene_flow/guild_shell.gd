## 公会壳（guild_shell）场景脚本
## 职责：M0 占位主场景——展示当前存档信息（save_point 名/game_day/mode，
## 肉眼验证读档一致的锚点）；「保存并返回标题」触发 DAY_END 自动存档演示；
## 「返回标题」不存档直接回标题。
## 数据来源：M0 批 4 方案；屏规格=案 15 §2.2。
## 单例访问：统一 get_node("/root/X")（gdUnit 测试环境不注册 autoload 标识符）。
extends Control

## SceneManager 脚本常量引用（枚举常量不可经实例属性访问，见 title_screen.gd 注）
const SceneManagerScript: GDScript = preload("res://scripts/autoload/scene_manager.gd")

func _ready() -> void:
	## 引擎回调：取走跨场景参数（读后清空机制）并刷新存档信息展示
	## 参数：无
	## 返回：无
	_scene_manager().take_pending_params()
	_RefreshSaveInfo()

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

func _RefreshSaveInfo() -> void:
	## 刷新存档信息展示（无运行态时显示提示）
	## 参数：无
	## 返回：无
	var save: SaveData = _save_manager().current
	if save == null:
		%SaveInfoLabel.text = "（无运行态存档）"
		return
	var point_name: String = String(SaveData.SavePoint.find_key(save.save_point))
	%SaveInfoLabel.text = "存档点：%s｜游戏天数：%d｜模式：%s" % [point_name, save.game_day, save.mode]

func _on_save_and_back_pressed() -> void:
	## 「保存并返回标题」：DAY_END 自动存档（M0 演示触发点）后回标题
	## 参数：无
	## 返回：无
	_save_manager().autosave(SaveData.SavePoint.DAY_END)
	_scene_manager().go(SceneManagerScript.SceneId.TITLE)

func _on_back_pressed() -> void:
	## 「返回标题」：不存档直接回标题
	## 参数：无
	## 返回：无
	_scene_manager().go(SceneManagerScript.SceneId.TITLE)
