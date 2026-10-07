## 临时六屏背景验证驱动入口（M6 批 3 后半——非生产代码，不入 selfcheck）
## 职责：本场景仅作启动壳——把常驻 runner 挂到 root（SceneManager 切换场景
## 时本场景会被替换释放，runner 留存继续驱动）。visual_smoke_driver 同构。
## 用法（真窗口工程默认分辨率，勿加 --headless）：
##   godot --path DEMO res://tools/visual_smoke/bg_showcase_driver.tscn
extends Node

## 常驻 runner 脚本（逻辑主体）
const RUNNER_SCRIPT: GDScript = preload("res://tools/visual_smoke/bg_showcase_runner.gd")

func _ready() -> void:
	## 引擎回调：spawn 常驻 runner 到 root 后待命（场景随后被目标屏替换）。
	## call_deferred：场景启动期 root 忙于建树，直接 add_child 会被拒
	##（visual_smoke_driver 先例实测）
	## 参数：无
	## 返回：无
	var runner: Node = RUNNER_SCRIPT.new()
	runner.name = "BgShowcaseRunner"
	get_tree().root.add_child.call_deferred(runner)
