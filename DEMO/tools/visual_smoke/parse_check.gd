## 临时解析自检（视觉冒烟驱动脚本编译校验——headless 快速失败用，非生产代码）
## 用法：godot --headless --path DEMO -s res://tools/visual_smoke/parse_check.gd
extends SceneTree

func _initialize() -> void:
	## MainLoop 回调：加载并重编译两个驱动脚本——解析/编译失败即报错退出
	## 参数：无
	## 返回：无
	var failures: int = 0
	for path: String in ["res://tools/visual_smoke/visual_smoke_driver.gd",
			"res://tools/visual_smoke/visual_smoke_runner.gd"]:
		var script: GDScript = load(path) as GDScript
		if script == null:
			printerr("[PARSE] 加载失败 %s" % path)
			failures += 1
			continue
		if script.reload() != OK:
			printerr("[PARSE] 编译失败 %s" % path)
			failures += 1
		else:
			print("[PARSE] 编译通过 %s" % path)
	quit(1 if failures > 0 else 0)
