## 临时视觉冒烟驱动入口（M6 批 1+2 表现层视觉验证——非生产代码，不入 selfcheck）
## 职责：本场景仅作启动壳——把常驻 runner 挂到 root（SceneManager 切换战斗屏
## 时本场景会被替换释放，runner 留存继续驱动）。
## 用法（真窗口 1280×720，勿加 --headless）：
##   godot --path DEMO --resolution 1280x720 res://tools/visual_smoke/visual_smoke_driver.tscn
extends Node

## 常驻 runner 脚本（逻辑主体）
const RUNNER_SCRIPT: GDScript = preload("res://tools/visual_smoke/visual_smoke_runner.gd")

func _ready() -> void:
	## 引擎回调：spawn 常驻 runner 到 root 后待命（场景随后被战斗屏替换）。
	## call_deferred：场景启动期 root 忙于建树，直接 add_child 会被拒
	##（实测报 Parent node is busy setting up children）
	## 参数：无
	## 返回：无
	var runner: Node = RUNNER_SCRIPT.new()
	runner.name = "VisualSmokeRunner"
	get_tree().root.add_child.call_deferred(runner)
