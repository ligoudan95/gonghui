## 代码兜底常量与 cfg_main 一致性锚定测试（盲审 S1-5 前瞻加固）
## 覆盖：全部 FALLBACK 常量（battle_rules / battle_unit / enemy_ai /
## status_manager / derived_stats / data_validator._MoveBaseCap）与 cfg_main
## 当前表值一致——表值调整而兜底常量漏改时（cfg 未注入路径行为分叉）此处
## 先红；调表时同步改兜底常量（或删除兜底）的口径由本套件锁定。
extends GdUnitTestSuite

## cfg_main 真实数据路径
const CFG_PATH: String = "res://data/core/cfg_main.tres"
## GameData 脚本路径（_MoveBaseCap 消费）
const GAME_DATA_SCRIPT: String = "res://scripts/autoload/game_data.gd"

## 套件级配置与 GameData 实例
var _cfg: CoreConfig
var _game_data: Node

func before() -> void:
	## 套件前置：加载 cfg_main 与 GameData（重资源只载一次）
	## 参数：无
	## 返回：无
	_cfg = load(CFG_PATH) as CoreConfig
	_game_data = load(GAME_DATA_SCRIPT).new()
	_game_data.initialize_data()

func after() -> void:
	## 套件后置：释放 GameData 实例
	## 参数：无
	## 返回：无
	_game_data.free()

func test_battle_rules_fallbacks_match_cfg() -> void:
	## BattleRules 兜底常量锚定：attr_modifier offset/divisor + 暴击三参
	assert_int(BattleRules.ATTR_MODIFIER_OFFSET_FALLBACK).is_equal(_cfg.attr_modifier_offset)
	assert_int(BattleRules.ATTR_MODIFIER_DIVISOR_FALLBACK).is_equal(_cfg.attr_modifier_divisor)
	assert_float(BattleRules.CRIT_BASE_FALLBACK).is_equal_approx(_cfg.crit_base, 0.0001)
	assert_float(BattleRules.CRIT_LUCK_WEIGHT_FALLBACK).is_equal_approx(_cfg.crit_luck_weight, 0.0001)
	assert_float(BattleRules.CRIT_AGILITY_WEIGHT_FALLBACK) \
			.is_equal_approx(_cfg.crit_agility_weight, 0.0001)

func test_battle_unit_fallbacks_match_cfg() -> void:
	## BattleUnit 兜底常量锚定：移动力基准段上限 + 敏捷加成门槛
	assert_int(BattleUnit.MOVE_BASE_CAP_FALLBACK).is_equal(_cfg.move_base_cap)
	assert_int(BattleUnit.AGILITY_MOVE_BONUS_LINE_FALLBACK) \
			.is_equal(_cfg.agility_move_bonus_line)

func test_enemy_ai_fallbacks_match_cfg() -> void:
	## EnemyAI 兜底常量锚定：怒吼义务门槛
	assert_int(EnemyAI.ROAR_ALLY_COUNT_LINE_FALLBACK).is_equal(_cfg.ai_roar_ally_count_line)

func test_status_manager_stack_limit_fallback() -> void:
	## StatusManager 叠加上限兜底（_StackLimit 的 cfg 空回退 2）与表值一致
	var manager := StatusManager.new()
	manager.setup(null, Callable())
	assert_int(manager._StackLimit()).is_equal(_cfg.status_stack_limit)

func test_derived_stats_fallbacks_match_cfg() -> void:
	## DerivedStats 兜底常量锚定：调整值换算 + 生命/资源池 + 派生权重全集
	assert_int(DerivedStats.ATTR_MODIFIER_OFFSET_FALLBACK).is_equal(_cfg.attr_modifier_offset)
	assert_int(DerivedStats.ATTR_MODIFIER_DIVISOR_FALLBACK).is_equal(_cfg.attr_modifier_divisor)
	assert_int(DerivedStats.HP_BASE_FALLBACK).is_equal(_cfg.hp_base)
	assert_int(DerivedStats.HP_CON_MULT_FALLBACK).is_equal(_cfg.hp_con_mult)
	assert_int(DerivedStats.POOL_BASE_FALLBACK).is_equal(_cfg.pool_base)
	assert_int(DerivedStats.POOL_MULT_FALLBACK).is_equal(_cfg.pool_mult)
	assert_float(DerivedStats.ATTR_HIT_WEIGHT_FALLBACK).is_equal_approx(_cfg.attr_hit_weight, 0.0001)
	assert_float(DerivedStats.ATTR_DODGE_WEIGHT_FALLBACK).is_equal_approx(_cfg.attr_dodge_weight, 0.0001)
	assert_float(DerivedStats.STATUS_RESIST_BASE_FALLBACK) \
			.is_equal_approx(_cfg.status_resist_base, 0.0001)
	assert_float(DerivedStats.STATUS_RESIST_WEIGHT_FALLBACK) \
			.is_equal_approx(_cfg.status_resist_weight, 0.0001)
	assert_float(DerivedStats.RESIST_WEIGHT_FALLBACK).is_equal_approx(_cfg.resist_weight, 0.0001)
	assert_float(DerivedStats.HIT_BASE_FALLBACK).is_equal_approx(_cfg.hit_base, 0.0001)
	assert_float(DerivedStats.DODGE_BASE_FALLBACK).is_equal_approx(_cfg.dodge_base, 0.0001)

func test_validator_move_cap_fallback_matches_cfg() -> void:
	## DataValidator._MoveBaseCap 兜底（cfg 缺省回退 6）与表值一致
	assert_int(DataValidator._MoveBaseCap(_game_data)).is_equal(_cfg.move_base_cap)

func test_new_param_fallbacks_match_cfg() -> void:
	## 解耦复审 A 批新参数兜底锚定：穿甲/护甲换算乘数（A-1）、敏捷移动加成
	## 点数（A-2）、伤害下限/命中钳制带（A-4）、叠层上限（A-16）、技能射程
	## 上限（C-8）——C-3 V 规则的测试侧镜像
	assert_int(DerivedStats.PIERCE_PER_MODIFIER_FALLBACK).is_equal(_cfg.pierce_per_modifier)
	assert_int(DerivedStats.ARMOR_PER_MODIFIER_FALLBACK).is_equal(_cfg.armor_per_modifier)
	assert_int(BattleUnit.AGILITY_MOVE_BONUS_AMOUNT_FALLBACK) 			.is_equal(_cfg.agility_move_bonus_amount)
	assert_int(BattleRules.DAMAGE_FLOOR_FALLBACK).is_equal(_cfg.damage_floor)
	assert_float(BattleRules.HIT_CLAMP_MIN_FALLBACK).is_equal_approx(_cfg.hit_clamp_min, 0.0001)
	assert_float(BattleRules.HIT_CLAMP_MAX_FALLBACK).is_equal_approx(_cfg.hit_clamp_max, 0.0001)
	assert_int(StatusManager.STACK_LIMIT_FALLBACK).is_equal(_cfg.status_stack_limit)
	assert_int(DataValidator.SKILL_RANGE_MAX_FALLBACK).is_equal(_cfg.skill_range_max)
	assert_str(_cfg.version_label).is_not_empty()
	assert_float(_cfg.ui_battle_delay_seconds).is_greater(0.0)

func test_crit_mult_fallback_matches_cfg() -> void:
	## R1-3：暴击倍率兜底锚定（执行链与 AI 期望经 crit_mult_base_of 单源）
	assert_float(BattleRules.CRIT_MULT_BASE_FALLBACK).is_equal_approx(
			_cfg.crit_mult_base, 0.0001)

func test_ui_theme_fallbacks_match_cfg() -> void:
	## UiTheme 全量兜底锚定（R3-04/R5-04）：全部 UI 色 + 字号档位 + 面板/阈值
	## ——C-3 V 规则的测试侧镜像（漂移双保险）
	var color_pairs: Array = [
		["ui_badge_hp_low_color", UiTheme.BADGE_HP_LOW],
		["ui_badge_hp_ok_color", UiTheme.BADGE_HP_OK],
		["ui_badge_bar_back_color", UiTheme.BADGE_BAR_BACK],
		["ui_badge_res_mana_color", UiTheme.BADGE_RES_MANA],
		["ui_badge_res_stamina_color", UiTheme.BADGE_RES_STAMINA],
		["ui_badge_fallback_ally_color", UiTheme.BADGE_FALLBACK_ALLY],
		["ui_badge_fallback_enemy_color", UiTheme.BADGE_FALLBACK_ENEMY],
		["ui_badge_bewitch_color", UiTheme.BADGE_BEWITCH],
		["ui_badge_preview_strip_color", UiTheme.BADGE_PREVIEW_STRIP],
		["ui_badge_preview_text_color", UiTheme.BADGE_PREVIEW_TEXT],
		["ui_badge_outline_color", UiTheme.BADGE_OUTLINE],
		["ui_card_buff_color", UiTheme.CARD_BUFF],
		["ui_card_debuff_color", UiTheme.CARD_DEBUFF],
		["ui_card_unknown_color", UiTheme.CARD_UNKNOWN],
		["ui_card_muted_color", UiTheme.CARD_MUTED],
		["ui_overlay_move_fill_color", UiTheme.OVERLAY_MOVE_FILL],
		["ui_overlay_move_border_color", UiTheme.OVERLAY_MOVE_BORDER],
		["ui_overlay_skill_fill_color", UiTheme.OVERLAY_SKILL_FILL],
		["ui_overlay_skill_border_color", UiTheme.OVERLAY_SKILL_BORDER],
		["ui_overlay_blocked_fill_color", UiTheme.OVERLAY_BLOCKED_FILL],
		["ui_overlay_blocked_border_color", UiTheme.OVERLAY_BLOCKED_BORDER],
		["ui_overlay_blocked_slash_color", UiTheme.OVERLAY_BLOCKED_SLASH],
		["ui_overlay_path_color", UiTheme.OVERLAY_PATH],
		["ui_overlay_confirm_color", UiTheme.OVERLAY_CONFIRM],
		["ui_log_system_color", UiTheme.LOG_SYSTEM],
		["ui_log_damage_color", UiTheme.LOG_DAMAGE],
		["ui_log_heal_color", UiTheme.LOG_HEAL],
		["ui_log_status_color", UiTheme.LOG_STATUS],
		["ui_log_move_color", UiTheme.LOG_MOVE],
		["ui_downed_modulate_color", UiTheme.DOWNED_MODULATE],
		["ui_highlight_gold_color", UiTheme.HIGHLIGHT_GOLD],
		["ui_panel_dark_color", UiTheme.PANEL_DARK],
		["ui_tile_fallback_color", UiTheme.TILE_FALLBACK],
		["ui_result_defeat_color", UiTheme.RESULT_DEFEAT],
		["ui_result_retreat_color", UiTheme.RESULT_RETREAT],
	]
	for pair: Array in color_pairs:
		assert_bool(_cfg.get(pair[0]) is Color and (_cfg.get(pair[0]) as Color).is_equal_approx(pair[1])) 				.override_failure_message("%s 表值 != UiTheme 兜底" % pair[0]).is_true()
	var font_pairs: Array = [
		["ui_font_size_display", UiTheme.FONT_DISPLAY],
		["ui_font_size_title", UiTheme.FONT_TITLE],
		["ui_font_size_heading", UiTheme.FONT_HEADING],
		["ui_font_size_subheading", UiTheme.FONT_SUBHEADING],
		["ui_font_size_large", UiTheme.FONT_LARGE],
		["ui_font_size_body", UiTheme.FONT_BODY],
		["ui_font_size_normal", UiTheme.FONT_NORMAL],
		["ui_font_size_small", UiTheme.FONT_SMALL],
		["ui_font_size_minor", UiTheme.FONT_MINOR],
	]
	for pair: Array in font_pairs:
		assert_int(int(_cfg.get(pair[0]))).is_equal(int(pair[1])) 				.override_failure_message("%s 表值 != UiTheme 兜底档位" % pair[0])
	assert_float(_cfg.ui_badge_hp_low_threshold).is_equal_approx(
			UiTheme.BADGE_HP_LOW_THRESHOLD, 0.0001)

func test_ui_theme_readers_three_states() -> void:
	## UiTheme 读取口三态（R5-04）：表值优先 / 未回填回退 / cfg 空回退——
	## 颜色与字号两族各三断言
	var blank: CoreConfig = CoreConfig.new()
	# ①表值优先（真表）
	assert_bool(UiTheme.color_of(_cfg, &"ui_highlight_gold_color",
			Color(0, 0, 1)).is_equal_approx(UiTheme.HIGHLIGHT_GOLD)).is_true()
	assert_int(UiTheme.font_of(_cfg, &"ui_font_size_body", 1)).is_equal(UiTheme.FONT_BODY)
	# ②未回填回退（空表实例——字段默认透明/0）
	assert_bool(UiTheme.color_of(blank, &"ui_highlight_gold_color",
			UiTheme.HIGHLIGHT_GOLD).is_equal_approx(UiTheme.HIGHLIGHT_GOLD)).is_true()
	assert_int(UiTheme.font_of(blank, &"ui_font_size_body", UiTheme.FONT_BODY)) 			.is_equal(UiTheme.FONT_BODY)
	# ③cfg 空回退
	assert_bool(UiTheme.color_of(null, &"ui_highlight_gold_color",
			UiTheme.HIGHLIGHT_GOLD).is_equal_approx(UiTheme.HIGHLIGHT_GOLD)).is_true()
	assert_int(UiTheme.font_of(null, &"ui_font_size_body", UiTheme.FONT_BODY)) 			.is_equal(UiTheme.FONT_BODY)
