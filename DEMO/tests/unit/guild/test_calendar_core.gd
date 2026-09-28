## 日历核心单元测试（M4 批 1）
## 覆盖：周刷新日判定（day8/15 触发、day1 不触发、day7 不触发）/星期显示
##（day1=周一、day7=周日、day8=周一）/到期线=上板日+N 不含当日/到期判定边界。
## 纯静态类直测——无 autoload 依赖。
extends GdUnitTestSuite

func test_week_refresh_day_triggers() -> void:
	## 周刷新日：每周第 1 天（day-1 整除 7）且非开局日——day8/15/22 触发
	assert_bool(CalendarCore.is_week_refresh_day(8, 7)).is_true()
	assert_bool(CalendarCore.is_week_refresh_day(15, 7)).is_true()
	assert_bool(CalendarCore.is_week_refresh_day(22, 7)).is_true()

func test_week_refresh_day_not_triggers() -> void:
	## 开局日 day1 不触发（开局预生成板保护）；周中日 day2-7 不触发
	for day: int in range(1, 8):
		assert_bool(CalendarCore.is_week_refresh_day(day, 7)).is_false()

func test_weekday_index_and_label() -> void:
	## 星期序数与显示：day1=周一（index 0）、day7=周日、day8=下一周一
	assert_int(CalendarCore.weekday_index(1, 7)).is_equal(0)
	assert_int(CalendarCore.weekday_index(7, 7)).is_equal(6)
	assert_int(CalendarCore.weekday_index(8, 7)).is_equal(0)
	assert_str(CalendarCore.weekday_label(1, 7)).is_equal("周一")
	assert_str(CalendarCore.weekday_label(6, 7)).is_equal("周六")
	assert_str(CalendarCore.weekday_label(7, 7)).is_equal("周日")
	assert_str(CalendarCore.weekday_label(29, 7)).is_equal("周一")

func test_expire_day_excludes_board_day() -> void:
	## 到期线=上板日+时限（不含上板当日）：day1 上板时限 5 → 到期线 6
	##（周一上板周六到期——17 案 §3.10 P-9 修订口径）
	assert_int(CalendarCore.expire_day(1, 5)).is_equal(6)
	assert_int(CalendarCore.expire_day(3, 5)).is_equal(8)
	assert_int(CalendarCore.expire_day(1, 7)).is_equal(8)

func test_is_expired_boundary() -> void:
	## 到期判定：到期线当日触发（day >= expire_day）；前一日未到期
	assert_bool(CalendarCore.is_expired(5, 6)).is_false()
	assert_bool(CalendarCore.is_expired(6, 6)).is_true()
	assert_bool(CalendarCore.is_expired(7, 6)).is_true()

func test_invalid_week_days_fallback() -> void:
	## 周天数非法（≤0）防御：不触发周刷新、星期序数回退 0
	assert_bool(CalendarCore.is_week_refresh_day(8, 0)).is_false()
	assert_int(CalendarCore.weekday_index(5, 0)).is_equal(0)
