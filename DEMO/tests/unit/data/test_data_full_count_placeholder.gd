## 全量数据计数断言（批 2 已激活）
## 原 M0 批 1 占位套件：批 2 全库 48 表落地后激活（DO_SKIP_PLACEHOLDER=false），
## 断言值按批 2 定名表校准（技能 23=6+12+4+1、状态 11、敌 3、配 3、登记 48 条）。
## gdUnit4 无单测级 skip API——本套件以套件级 do_skip 参数机制保留跳过开关，
## 供批 3+ 数据规模变化时临时跳过用。
extends GdUnitTestSuite

## 占位激活开关（批 2 已激活；后续数据规模调整时可临时置 true 跳过本套件）
const DO_SKIP_PLACEHOLDER: bool = false

## 跳过原因（置 true 时生效）
const SKIP_REASON_PLACEHOLDER: String = "数据规模调整期临时跳过全量计数断言"

## GameData 自动加载脚本路径
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级 GameData 实例
var _game_data: Node

func before(do_skip := DO_SKIP_PLACEHOLDER, skip_reason := SKIP_REASON_PLACEHOLDER) -> void:
	## 套件前置：gdUnit 扫描器读取 do_skip/skip_reason 实现套件级跳过；
	## 未跳过时实例化 GameData 并显式初始化
	## 参数 do_skip：true = 本套件标记 SKIPPED；skip_reason：跳过原因
	## 返回：无
	_game_data = auto_free(load(GAME_DATA_SCRIPT).new())
	_game_data.initialize_data()

func test_class_def_count() -> void:
	## class/classes 域 6 职业
	assert_int(_game_data.get_domain(&"class/classes").size()).is_equal(6)

func test_skill_def_count() -> void:
	## class/skills 域 6 普攻 + 12 DEMO 技能 + 4 敌方技能 + 1 敌方通用普攻 = 23
	assert_int(_game_data.get_domain(&"class/skills").size()).is_equal(23)

func test_status_def_count() -> void:
	## status/stats 域 11 状态（17 案 §3.11 #6 的 10-15 带内）
	assert_int(_game_data.get_domain(&"status/stats").size()).is_equal(11)

func test_enemy_def_count() -> void:
	## battle/enemies 域 2 杂兵 + 1 精英 = 3
	assert_int(_game_data.get_domain(&"battle/enemies").size()).is_equal(3)

func test_enemy_pack_and_naming_counts() -> void:
	## battle/enemy_packs 域 3 配置；命名登记表 62 条（M0 批 2 的 48 条 +
	## M1 批 1 战斗域 14 条：btm×2 / tile×6 / eqp×6）
	assert_int(_game_data.get_domain(&"battle/enemy_packs").size()).is_equal(3)
	var registry: NamingRegistry = _game_data.get_record(&"naming_registry")
	assert_int(registry.entries.size()).is_equal(85)
