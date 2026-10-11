## UnitInfoCard 单元测试（2026-09-24 九轮后 BUG 修复防回归；顶部横条批
## 2026-10-11 增点选驱动三契约）
## 覆盖：状态图标修正量文本格式化——float 域（dodge +0.15）与 int 域
## （armor_physical +4）正确渲染（原 %g 非 GDScript % 运算符支持的格式
## 字符，运行时报 unsupported format character 且修正文本丢失；gdUnit
## 运行时错误会令用例失败，天然拦截回归）；顶部横条批：hide_card 幂等 /
## is_showing_unit 三态（show 后 true、hide 后 false、异单位 false）/
## show_unit 记录随切换覆写（B 案条件刷新判据）。
extends GdUnitTestSuite

## cfg_main 真实数据路径
const CFG_PATH: String = "res://data/core/cfg_main.tres"
## 状态表目录
const STATUS_DIR: String = "res://data/status/stats/"

## 套件级配置与状态表
var _cfg: CoreConfig
var _statuses: Dictionary = {}

func before() -> void:
	## 套件前置：加载 cfg 与两张带 modifiers 的状态表（草丛 float 域/盾墙 int 域）
	## 参数：无
	## 返回：无
	_cfg = load(CFG_PATH) as CoreConfig
	_statuses = {}
	for status_id: StringName in [&"BUFF_tile_grass", &"BUFF_shield_wall"]:
		_statuses[status_id] = load(STATUS_DIR + String(status_id) + ".tres")

func _LookupStatus(status_id: StringName) -> StatusDef:
	## 状态定义解析闭包
	## 参数 status_id：状态 id
	## 返回：StatusDef（未登记返回 null）
	return _statuses.get(status_id, null)

func _MakeCardAndUnit() -> Array:
	## 构建挂树信息卡 + 挂接状态管理器的单位（草丛闪避 0.15 + 盾墙护甲 4.0
	## 两状态在身）
	## 参数：无
	## 返回：[UnitInfoCard, BattleUnit]
	var card := UnitInfoCard.new()
	add_child(card)
	auto_free(card)
	card.setup(_LookupStatus)
	var manager := StatusManager.new()
	manager.setup(_cfg, _LookupStatus)
	var unit := BattleUnit.new()
	unit.unit_id = &"test_unit"
	unit.display_name = "测试单位"
	unit.current_hp = 50
	unit.max_hp = 100
	unit.bind_battle(_cfg, manager)
	manager.apply(unit, _statuses[&"BUFF_tile_grass"] as StatusDef,
			StatusInstance.SourceKind.TILE, &"tile_grass", 0, 1, false)
	manager.apply(unit, _statuses[&"BUFF_shield_wall"] as StatusDef,
			StatusInstance.SourceKind.SKILL, &"test_skill", 2, 1, false)
	return [card, unit]

func test_status_icon_modifier_text_formatting() -> void:
	## 修正量格式化契约：float 域显示 +0.15、int 域显示 +4（%d/%f 系格式
	## 字符）；%g 类非法格式字符的运行时错误将直接令本用例失败
	var pair: Array = _MakeCardAndUnit()
	var card: UnitInfoCard = pair[0]
	var unit: BattleUnit = pair[1]
	card.show_unit(unit)
	var tooltips: String = ""
	for child: Node in card._status_box.get_children():
		if child is ColorRect:
			tooltips += child.tooltip_text + "\n"
	assert_bool(tooltips.contains("+0.15")) \
			.override_failure_message("float 域修正（dodge 0.15）显示不符：%s" % tooltips) \
			.is_true()
	assert_bool(tooltips.contains("+4")) \
			.override_failure_message("int 域修正（armor_physical 4）显示不符：%s" % tooltips) \
			.is_true()

func test_mouse_filter_and_name_resolver_contract() -> void:
	## S4-4/S4-9 契约：面板容器与内层布局 IGNORE（右栏不遮点击——状态图标
	## 单独 STOP 保 tooltip）；显示名经 resolver 单源解析（回退直读兼容）
	var card := UnitInfoCard.new()
	add_child(card)
	auto_free(card)
	var resolver_calls: Array[StringName] = []
	var resolver: Callable = func(unit_id: StringName) -> String:
		resolver_calls.append(unit_id)
		return "解析名·%s" % String(unit_id)
	card.setup(_LookupStatus, resolver)
	var pair: Array = _MakeCardAndUnit()
	var unit: BattleUnit = pair[1]
	card.show_unit(unit)
	# S4-9：名称来自 resolver（单源 BattleContext.display_name_of 注入口）
	assert_str(card._name_label.text).is_equal("解析名·test_unit（我方）")
	assert_int(resolver_calls.size()).is_greater(0)
	# S4-4：面板与容器 IGNORE（图标 STOP 在 _MakeStatusIcon 已置——本用例锚定容器层）
	assert_int(card.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var box: Container = card.get_child(0) as Container
	assert_int(box.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	# resolver 无效（降级路径）：回退 unit.display_name 直读
	var degraded := UnitInfoCard.new()
	add_child(degraded)
	auto_free(degraded)
	degraded.setup(_LookupStatus)
	degraded.show_unit(unit)
	assert_str(degraded._name_label.text).is_equal("测试单位（我方）")

func test_hide_card_idempotent() -> void:
	## hide_card 幂等契约（顶部横条批）：未展示态收起零操作不报错；展示后
	## 收起 → invisible + id 清空；重复收起维持（幂等）
	var card := UnitInfoCard.new()
	add_child(card)
	auto_free(card)
	card.setup(_LookupStatus)
	# 未展示态收起（幂等入口零守卫需求）
	card.hide_card()
	assert_bool(card.visible).is_false()
	var pair: Array = _MakeCardAndUnit()
	var unit: BattleUnit = pair[1]
	card.show_unit(unit)
	assert_bool(card.visible).is_true()
	card.hide_card()
	assert_bool(card.visible).is_false()
	assert_bool(card.is_showing_unit(unit.unit_id)).is_false()
	# 重复收起幂等维持
	card.hide_card()
	assert_bool(card.visible).is_false()

func test_is_showing_unit_three_states() -> void:
	## is_showing_unit 三态契约（顶部横条批 B 案判据）：show 后 true /
	## hide 后 false / 异单位 false；visible 且 id 匹配双条件
	var card := UnitInfoCard.new()
	add_child(card)
	auto_free(card)
	card.setup(_LookupStatus)
	var other := BattleUnit.new()
	other.unit_id = &"other_unit"
	other.display_name = "另一单位"
	# 状态一：未展示（setup 默认 invisible）
	assert_bool(card.is_showing_unit(&"test_unit")).is_false()
	var pair: Array = _MakeCardAndUnit()
	var unit: BattleUnit = pair[1]
	# 状态二：show 后对本单位 true、异单位 false
	card.show_unit(unit)
	assert_bool(card.is_showing_unit(unit.unit_id)).is_true()
	assert_bool(card.is_showing_unit(other.unit_id)).is_false()
	# 状态三：hide 后 false
	card.hide_card()
	assert_bool(card.is_showing_unit(unit.unit_id)).is_false()

func test_show_unit_records_current_unit_switch() -> void:
	## show_unit 记录切换契约（顶部横条批）：连续 show 不同单位——记录随
	## 最后一次 show 覆写（条件刷新判据不串台）
	var card := UnitInfoCard.new()
	add_child(card)
	auto_free(card)
	card.setup(_LookupStatus)
	var pair: Array = _MakeCardAndUnit()
	var unit_a: BattleUnit = pair[1]
	var unit_b := BattleUnit.new()
	unit_b.unit_id = &"test_unit_b"
	unit_b.display_name = "测试单位乙"
	unit_b.current_hp = 10
	unit_b.max_hp = 20
	card.show_unit(unit_a)
	assert_bool(card.is_showing_unit(unit_a.unit_id)).is_true()
	card.show_unit(unit_b)
	assert_bool(card.is_showing_unit(unit_a.unit_id)).is_false() \
			.override_failure_message("切换单位后旧单位记录应被覆写")
	assert_bool(card.is_showing_unit(unit_b.unit_id)).is_true()
