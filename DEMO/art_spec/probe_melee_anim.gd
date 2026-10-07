## 临时诊断探针壳（用后删）：把 runner 挂到 root 常驻（SceneManager 切战斗屏
## 时本壳被替换释放，runner 留存——visual_smoke_driver 同款模式）
extends Node

const RUNNER_SCRIPT: GDScript = preload("res://art_spec/probe_melee_runner.gd")

func _ready() -> void:
	var runner: Node = RUNNER_SCRIPT.new()
	runner.name = "ProbeMeleeRunner"
	get_tree().root.add_child.call_deferred(runner)
