## 遭遇判定器单元测试（M3 批 1）
## 覆盖：4% 概率掷值（同种子探针 rng 确定断言——无概率窗）/ 旧格不掷 /
## 上限拦截（fired ≥ random_max）/ 安全区（chance 0）/ 权重空拒绝 /
## 宝箱金域掷值（域内 + 探针同值 + 非法域返 0）。
extends GdUnitTestSuite

func _MakeWeight(chance: float, max_count: int) -> EncounterWeightDef:
	## 构建遭遇权重
	## 参数 chance/max_count：概率与上限
	## 返回：EncounterWeightDef
	var weight := EncounterWeightDef.new()
	weight.id = &"encw_test"
	weight.region_id = &"reg_mine"
	weight.encounter_chance = chance
	weight.random_pack_id = &"enc_m1_random_pack"
	weight.random_max = max_count
	return weight

func _MakeChest(min_gold: int, max_gold: int) -> InteractPointDef:
	## 构建宝箱交互点
	## 参数 min_gold/max_gold：金域
	## 返回：InteractPointDef
	var point := InteractPointDef.new()
	point.id = &"evp_chest_test"
	point.kind = InteractPointDef.Kind.TREASURE
	point.gold_min = min_gold
	point.gold_max = max_gold
	return point

func test_chance_roll_deterministic() -> void:
	## 4% 概率掷值：同种子双 rng（探针取首个 randf 期望值）——命中与未中
	## 两分支各取一确定性种子断言（种内遍历挑选，无概率窗）
	var weight := _MakeWeight(0.04, 1)
	var hit_seed: int = -1
	var miss_seed: int = -1
	for seed_value: int in range(1000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() < 0.04:
			hit_seed = seed_value
			break
	for seed_value: int in range(1000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() >= 0.04:
			miss_seed = seed_value
			break
	assert_int(hit_seed).is_not_equal(-1)
	assert_int(miss_seed).is_not_equal(-1)
	# 命中种子：掷值 < 0.04 → true
	var hit_rng := RandomNumberGenerator.new()
	hit_rng.seed = hit_seed
	assert_bool(EncounterJudge.should_trigger(true, weight, 0, hit_rng)).is_true()
	# 未中种子：掷值 ≥ 0.04 → false
	var miss_rng := RandomNumberGenerator.new()
	miss_rng.seed = miss_seed
	assert_bool(EncounterJudge.should_trigger(true, weight, 0, miss_rng)).is_false()

func test_old_cell_never_rolls() -> void:
	## 旧格不掷：is_new_cell false 恒拒（即便种子必命中）
	var weight := _MakeWeight(0.99, 9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_bool(EncounterJudge.should_trigger(false, weight, 0, rng)).is_false()

func test_fired_cap_blocks() -> void:
	## 上限拦截：fired ≥ random_max 拒（DEMO 上限 1——首战后不再掷）
	var weight := _MakeWeight(0.99, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_bool(EncounterJudge.should_trigger(true, weight, 1, rng)).is_false()
	assert_bool(EncounterJudge.should_trigger(true, weight, 0, rng)).is_true()

func test_safe_region_zero_chance() -> void:
	## 村子安全区：chance 0 不掷（恒 false）
	var weight := _MakeWeight(0.0, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_bool(EncounterJudge.should_trigger(true, weight, 0, rng)).is_false()

func test_null_weight_rejected() -> void:
	## 权重空拒绝（无区域权重的兜底安全口径）
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_bool(EncounterJudge.should_trigger(true, null, 0, rng)).is_false()

func test_treasure_gold_in_band() -> void:
	## 宝箱金域：掷值 ∈ [min, max]（多种子扫描）；探针同种子同值（randi_range 同源）
	var chest := _MakeChest(20, 40)
	for seed_value: int in range(50):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var gold: int = EncounterJudge.roll_treasure_gold(chest, rng)
		assert_bool(gold >= 20 and gold <= 40).is_true()
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		assert_int(gold).is_equal(probe.randi_range(20, 40))

func test_treasure_invalid_band_returns_zero() -> void:
	## 非法金域（min > max）返 0（数据侧由 V-M3-treasure-domain 拦截）
	var chest := _MakeChest(40, 20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_int(EncounterJudge.roll_treasure_gold(chest, rng)).is_equal(0)
	assert_int(EncounterJudge.roll_treasure_gold(null, rng)).is_equal(0)
