## BattleBoard 移动朝向纯函数单元测试（批次 A：移动演出全程随步设朝向）
## 覆盖：facing_flip_of 三分支纯逻辑——下一格 x 更小 → 面左（flip=true）/
## 更大 → 面右（默认，flip=false）/ 相等（竖直步）→ 回正默认朝向（flip=false，
## 与攻击同列回正同口径）。链路时序（链首即刻/逐段回调/瞬移一次判定/
## 无位移不触发）归 test_battle_anim_flow 集成用例，本套只锚纯函数契约。
## E1 注：等距投影下逻辑竖直步（x 相等）在屏幕呈斜向移动观感——纯函数
## 判据零改（朝向仍按逻辑 x 相位），视觉校准归 E3 打磨批。
extends GdUnitTestSuite

func test_facing_left_step_flips() -> void:
	## 下一格 x 更小（向左行进）→ 面左翻转
	assert_bool(BattleBoard.facing_flip_of(3, 2)).is_true() \
			.override_failure_message("左行步 (3→2) 应面左翻转")

func test_facing_right_step_keeps_default() -> void:
	## 下一格 x 更大（向右行进）→ 默认朝向不翻
	assert_bool(BattleBoard.facing_flip_of(2, 3)).is_false() \
			.override_failure_message("右行步 (2→3) 应保持默认朝向")

func test_facing_vertical_step_resets_default() -> void:
	## x 相等（竖直步）→ 回正默认朝向（与攻击同列回正同口径——不保持残留翻转）
	assert_bool(BattleBoard.facing_flip_of(3, 3)).is_false() \
			.override_failure_message("竖直步 (3→3) 应回正默认朝向")
