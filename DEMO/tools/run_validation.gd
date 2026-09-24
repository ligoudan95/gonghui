## 数据校验入口（headless 运行）
## 职责：自建 GameData 实例扫描全库 → DataValidator.run_all → 报告写
## user://reports/validation_report.txt 并打印；退出码 0=零错误 / 1=存在错误（CI 判定用）。
## 用法：godot --headless -s res://tools/run_validation.gd
## 注：-s 模式不注册 autoload 单例且 _initialize 阶段挂树不触发 _ready（批 1/2 实测
## 结论），故手动实例化后显式调 initialize_data()。
## S5-8：报告路径 res://reports/ → user://reports/——res:// 在导出版只读、
## 源码运行下写入也会污染仓库工作区；user:// 对源码运行/导出版同效。
## 本机 user:// 实际位置：编辑器「打开用户数据文件夹」或 %APPDATA%/Godot/
## app_userdata/<project_name>/reports/。
extends SceneTree

## GameData 自动加载脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 报告输出目录与文件（user://——见文件头 S5-8 注）
const REPORT_DIR: String = "user://reports"
const REPORT_PATH: String = "user://reports/validation_report.txt"

func _initialize() -> void:
	## MainLoop 回调：跑全库校验、落盘报告、按结果退出
	## 参数：无
	## 返回：无
	var game_data: Node = load(GAME_DATA_SCRIPT).new()
	game_data.initialize_data()
	var report: ValidationReport = DataValidator.run_all(game_data)
	var text: String = report.to_text()
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("run_validation: 报告写入失败 %s" % REPORT_PATH)
		quit(1)
		return
	file.store_string(text)
	file.close()
	print(text)
	print("run_validation: 报告已写入 %s" % REPORT_PATH)
	var has_errors: bool = report.has_errors()
	game_data.free()
	quit(1 if has_errors else 0)
