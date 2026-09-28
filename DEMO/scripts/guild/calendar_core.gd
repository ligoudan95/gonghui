## 日历核心（CalendarCore，纯静态工具类）
## 职责：星期/周刷新日/到期线的纯计算——日结算委托步骤与委托板到期判定的
## 口径单源（GuildCore/QuestBoard/批 2 HUD 共用）。
## 数据来源：案 2《时间与日历》§2.1（开局日=周 1、首个周刷新=第 8 天日结算、
## 七日一周星期展示）/§2.4 第 7 步（周刷新日跳过板上常规到期）；
## 二审拍板组（时限 N 天=上板日+N 天到期、不含上板当日）。
## 纯逻辑约束：不触任何 autoload——周天数经参数注入（cfg.calendar_week_days）。
class_name CalendarCore
extends RefCounted

## 中文星期字（周一…周日——语言级常量，超出周天数回退末位）
const WEEKDAY_NAMES: Array[String] = ["一", "二", "三", "四", "五", "六", "日"]

static func is_week_refresh_day(day: int, week_days: int) -> bool:
	## 周刷新日判定：每周第 1 天（(day-1) 可被周天数整除）且非开局日（day > 1
	## ——开局当日预生成板不触发周刷新，防当日被清空，案 2 §2.1/案 6 §2.2）
	## 参数 day：当日天数（day_advance 之后的值）；week_days：周天数（cfg 注入）
	## 返回：true = 本日结算执行周刷新
	return day > 1 and week_days > 0 and (day - 1) % week_days == 0

static func weekday_index(day: int, week_days: int) -> int:
	## 星期序数（0 起，0 = 周首）：开局 day=1 即周首
	## 参数 day/week_days：天数 / 周天数
	## 返回：0 起的星期序数；week_days 非法时回退 0
	if week_days <= 0:
		return 0
	return (day - 1) % week_days

static func weekday_label(day: int, week_days: int) -> String:
	## 星期显示文案（day 1 = 周一、day 7 = 周日——案 2 §2.1 历法展示）
	## 参数 day/week_days：天数 / 周天数
	## 返回：如「周一」；超周天数回退末位
	var index: int = clampi(weekday_index(day, week_days), 0, WEEKDAY_NAMES.size() - 1)
	return "周" + WEEKDAY_NAMES[index]

static func expire_day(board_day: int, time_limit_days: int) -> int:
	## 到期线计算：上板/授予日 + 时限（不含上板当日——二审拍板组口径；
	## 时限 5 天周一上板 → 周六到期）
	## 参数 board_day：上板/授予日；time_limit_days：时限天数
	## 返回：到期天数（当前 day ≥ 到期线即触发到期处理）
	return board_day + time_limit_days

static func is_expired(current_day: int, expire_at: int) -> bool:
	## 到期判定（日结算 quest_countdown 步消费：板上三表现与挂单到期失败同判）
	## 参数 current_day：当日天数；expire_at：到期线
	## 返回：true = 已到期
	return current_day >= expire_at
