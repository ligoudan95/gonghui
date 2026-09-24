## BattleLog 渲染冒烟单元测试（2026-09-24 五轮试玩反馈）
## 覆盖：条目追加/着色类型、trace 中文模板渲染（伤害链/失败码映射/状态链）、
## 条目上限裁旧。headless 不测滚动视觉——只测文本行数与模板契约。
## 组件需挂树（_ready 自建滚动区子节点）。
extends GdUnitTestSuite

## 构建挂树日志栏（context 置空——_NameOf 回退 id 原文）
func _MakeLog() -> BattleLog:
	## 参数：无
	## 返回：已挂树日志栏（auto_free 释放）
	var log_panel := BattleLog.new()
	add_child(log_panel)
	auto_free(log_panel)
	return log_panel

## 取条目文本数组（末位在前倒序不便断言——按序返回）
func _LinesOf(log_panel: BattleLog) -> Array[String]:
	## 参数 log_panel：日志栏
	## 返回：条目文本（树序）
	var lines: Array[String] = []
	for child: Node in log_panel.get_entries().get_children():
		if child is Label:
			lines.append((child as Label).text)
	return lines

func test_push_line_appends_entries() -> void:
	## 基础追加：三条不同类型 → 三行文本且内容正确
	var log_panel: BattleLog = _MakeLog()
	log_panel.push_line("—— 回合 1 ——", BattleLog.LineKind.SYSTEM)
	log_panel.push_line("法师 移动 (2,3)→(4,3)", BattleLog.LineKind.MOVE)
	log_panel.push_line("法师 · 魔弹 → 鼠人", BattleLog.LineKind.DAMAGE)
	var lines: Array[String] = _LinesOf(log_panel)
	assert_int(lines.size()).is_equal(3)
	assert_str(lines[0]).is_equal("—— 回合 1 ——")
	assert_str(lines[2]).is_equal("法师 · 魔弹 → 鼠人")

func test_skill_trace_damage_template() -> void:
	## 伤害链模板：喂结构化 trace（真实键契约）→ 主行 + 命中行 + 伤害行，
	## 含命中率构成与最终值（中文模板在 UI 层——本用例锁模板关键字）
	var log_panel: BattleLog = _MakeLog()
	var result := SkillExecutor.ExecutionResult.new()
	result.trace = {
		&"skill": &"skl_warrior_power_strike",
		&"caster": &"warrior",
		&"target": &"rat",
		&"hit_chain": {&"base": 0.78, &"mod": 0, &"dodge": 0.04,
				&"final": 0.74, &"passed": true},
		&"damage_chain": {&"raw": 24.96, &"panel_mult": 1.0, &"race_mult": 1.0,
				&"resist": 0.0, &"armor": 2, &"pierce": 3, &"mitigated": 25,
				&"crit_chance": 0.05, &"crit": false, &"final": 25},
	}
	log_panel.push_skill_trace("战士", result)
	var lines: Array[String] = _LinesOf(log_panel)
	assert_int(lines.size()).is_equal(3)
	assert_str(lines[0]).is_equal("战士 · skl_warrior_power_strike → rat")
	assert_bool(lines[1].contains("命中 74%")).is_true()
	assert_bool(lines[1].contains("→ 命中")).is_true()
	assert_bool(lines[2].contains("输出 25.0")).is_true()
	assert_bool(lines[2].contains("最终 25")).is_true()

func test_skill_trace_fail_template() -> void:
	## 失败模板：fail_reason → 中文映射单行（无后续链）
	var log_panel: BattleLog = _MakeLog()
	var result := SkillExecutor.ExecutionResult.new()
	result.trace = {
		&"skill": &"skl_mage_fireball",
		&"caster": &"mage",
		&"fail_reason": &"out_of_range",
	}
	log_panel.push_skill_trace("法师", result)
	var lines: Array[String] = _LinesOf(log_panel)
	assert_int(lines.size()).is_equal(1)
	assert_bool(lines[0].contains("失败：射程外")).is_true()

func test_skill_trace_status_and_heal_template() -> void:
	## 状态/治疗模板：statuses 逐条 ✓/✗ + 治疗量行
	var log_panel: BattleLog = _MakeLog()
	var result := SkillExecutor.ExecutionResult.new()
	result.trace = {
		&"skill": &"skl_priest_heal",
		&"caster": &"priest",
		&"target": &"warrior",
		&"heal": 32,
	}
	log_panel.push_skill_trace("牧师", result)
	var lines: Array[String] = _LinesOf(log_panel)
	assert_int(lines.size()).is_equal(2)
	assert_bool(lines[1].contains("治疗 32")).is_true()
	var status_result := SkillExecutor.ExecutionResult.new()
	status_result.trace = {
		&"skill": &"skl_mage_frost_chain",
		&"caster": &"mage",
		&"target": &"rat",
		&"hit_chain": {&"base": 0.8, &"mod": 0, &"dodge": 0.04,
				&"final": 0.76, &"passed": true},
		&"damage_chain": {&"raw": 10.8, &"panel_mult": 1.0, &"race_mult": 1.0,
				&"resist": 0.0, &"armor": 2, &"pierce": 3, &"mitigated": 11,
				&"crit_chance": 0.05, &"crit": false, &"final": 11},
		&"statuses": [
			{&"id": &"DEBUFF_root", &"duration": 1, &"applied": true},
			{&"id": &"DEBUFF_slow", &"duration": 2, &"applied": false},
		],
	}
	log_panel.push_skill_trace("法师", status_result)
	var all_lines: Array[String] = _LinesOf(log_panel)
	# 追加主行 + 命中 + 伤害 + 状态×2 = 5 行（累计 2 + 5 = 7）
	assert_int(all_lines.size()).is_equal(7)
	assert_bool(all_lines[5].contains("DEBUFF_root 1 回合 ✓")).is_true()
	assert_bool(all_lines[6].contains("DEBUFF_slow 2 回合 ✗")).is_true()

func test_skill_and_status_names_chinese() -> void:
	## 技能/状态中文名渲染（批 D L7）：context lookup 可查 → 表 display_name
	## （火球术/草丛遮蔽）；空 context / 查无 → 回退 id 原文
	var log_panel: BattleLog = _MakeLog()
	var context := BattleSetup.BattleContext.new()
	context.skill_lookup = func(skill_id: StringName) -> SkillDef:
		return load("res://data/class/skills/%s.tres" % String(skill_id)) as SkillDef
	context.status_lookup = func(status_id: StringName) -> StatusDef:
		return load("res://data/status/stats/%s.tres" % String(status_id)) as StatusDef
	log_panel.context = context
	assert_str(log_panel._SkillNameOf(&"skl_mage_fireball")).is_equal("火球术")
	assert_str(log_panel._StatusNameOf(&"BUFF_tile_grass")).is_equal("草丛遮蔽")
	assert_str(log_panel._SkillNameOf(&"skl_nope")).is_equal("skl_nope")
	# 空 context 回退 id 原文（直开冒烟路径）
	var bare: BattleLog = _MakeLog()
	assert_str(bare._SkillNameOf(&"skl_mage_fireball")).is_equal("skl_mage_fireball")
	assert_str(bare._StatusNameOf(&"BUFF_tile_grass")).is_equal("BUFF_tile_grass")

func test_line_cap_trims_oldest() -> void:
	## 上限裁旧：压入上限 + 5 条 → 条目数钳制 MAX_LINES 且最旧被裁
	var log_panel: BattleLog = _MakeLog()
	for index: int in BattleLog.MAX_LINES + 5:
		log_panel.push_line("行 %d" % index, BattleLog.LineKind.SYSTEM)
	assert_int(log_panel.get_entries().get_child_count()).is_equal(BattleLog.MAX_LINES)
	var first: Label = log_panel.get_entries().get_child(0) as Label
	assert_str(first.text).is_equal("行 5")
