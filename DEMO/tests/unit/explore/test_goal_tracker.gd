## 判据追踪器单元测试（M3 批 1）
## 覆盖：EXPLORE 通道（目标点交互匹配达成）/ CLEAR 通道（队伍胜利匹配达成）/
## 双通道互斥（EXPLORE 会话吃战斗胜利不达成）/ 达成锁定（幂等）/ 无判据会话。
extends GdUnitTestSuite

func test_explore_channel_matches() -> void:
	## EXPLORE 通道：绑定目标点交互 → 达成；达成后锁定（重复交互返 false）
	var tracker := GoalTracker.new()
	tracker.setup(QuestTemplateDef.GoalType.EXPLORE, &"tp_old_well")
	assert_bool(tracker.is_done()).is_false()
	# 非绑定目标不达成
	assert_bool(tracker.on_target_interacted(&"tp_mine_north_wall")).is_false()
	assert_bool(tracker.is_done()).is_false()
	# 绑定目标达成
	assert_bool(tracker.on_target_interacted(&"tp_old_well")).is_true()
	assert_bool(tracker.is_done()).is_true()
	# 达成锁定：再次交互返 false（不重复达成）
	assert_bool(tracker.on_target_interacted(&"tp_old_well")).is_false()

func test_clear_channel_matches() -> void:
	## CLEAR 通道：绑定队伍胜利 → 达成；其他队伍胜利不达成
	var tracker := GoalTracker.new()
	tracker.setup(QuestTemplateDef.GoalType.CLEAR, &"enc_m1_lair_pack")
	assert_bool(tracker.on_battle_victory(&"enc_m1_random_pack")).is_false()
	assert_bool(tracker.on_battle_victory(&"enc_m1_lair_pack")).is_true()
	assert_bool(tracker.is_done()).is_true()

func test_channels_are_exclusive() -> void:
	## 双通道互斥：EXPLORE 会话吃战斗胜利不达成 / CLEAR 会话吃目标点交互不达成
	var explore_tracker := GoalTracker.new()
	explore_tracker.setup(QuestTemplateDef.GoalType.EXPLORE, &"tp_old_well")
	assert_bool(explore_tracker.on_battle_victory(&"tp_old_well")).is_false()
	var clear_tracker := GoalTracker.new()
	clear_tracker.setup(QuestTemplateDef.GoalType.CLEAR, &"enc_m1_lair_pack")
	assert_bool(clear_tracker.on_target_interacted(&"enc_m1_lair_pack")).is_false()

func test_no_goal_session() -> void:
	## 无判据会话（自由探索）：两通道均不达成
	var tracker := GoalTracker.new()
	tracker.setup(-1, &"")
	assert_bool(tracker.on_target_interacted(&"tp_old_well")).is_false()
	assert_bool(tracker.on_battle_victory(&"enc_m1_lair_pack")).is_false()
	assert_bool(tracker.is_done()).is_false()

func test_setup_resets_state() -> void:
	## 重复 setup 重置：上一判据达成态不泄漏到新会话
	var tracker := GoalTracker.new()
	tracker.setup(QuestTemplateDef.GoalType.EXPLORE, &"tp_old_well")
	tracker.on_target_interacted(&"tp_old_well")
	tracker.setup(QuestTemplateDef.GoalType.CLEAR, &"enc_m1_lair_pack")
	assert_bool(tracker.is_done()).is_false()
