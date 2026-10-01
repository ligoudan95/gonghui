## 总控配置（CoreConfig）
## 职责：承载全局运行口径——运行模式（DEMO/完整版）、系统启用清单、检定与战斗
## 公式参数、探索视野等总控数值，是 GameConfig 自动加载单例的唯一数据源。
## 数据来源：案 16《内容数据与配置化》§2（配置化原则）；案 17《数值专项案》
## §3.1（属性域）/§3.3（D20 检定域）/§3.10（时间与探索域）/§3.11（DEMO 最小数值集）。
## id 命名规范：core 域固定主配置文件 cfg_main（文件名与 id 同名，全库唯一）。
## 数值性质：全部为【占位·试玩校准】（案 17 口径，DEMO 试玩后回调）。
class_name CoreConfig
extends Resource

## cfg_main 固定资源 id（C-5 单源：&"cfg_main" 字面量全库收敛此处——
## GameConfig 直载路径与 GameData 查表消费点统一引用）
const CFG_MAIN_ID: StringName = &"cfg_main"

## Resource 内建属性精确跳过清单（S3-M1 根修：原 `begins_with("resource_")`
## 前缀判据误伤数据字段——SkillDef.resource_type/resource_cost、ClassDef.
## resource_type/resource_source_attr、EnemyDef.resource_pool、NamingEntry.
## resource_id 均为业务字段，热重载时被错误跳过致旧引用见旧值）。只列
## Resource 真内建属性，新增内建属性时同步维护本清单。
const RESOURCE_BUILTIN_PROPS: Array[String] = [
	"resource_name",
	"resource_path",
	"resource_local_to_scene",
	"resource_scene_unique_id",
	"resource_group",
]

static func copy_props(from_record: Resource, to_record: Resource) -> void:
	## 资源属性逐项拷贝（R4-01 热重载同址刷新核心——定义于数据定义层：
	## GameConfig/GameData 两单例合向引用不反向）：脚本导出字段与普通属性
	## 全量拷入旧实例（嵌套子资源为引用替换——新 dot/modifiers 等一并生效）；
	## Resource 内建（**精确名单**——S3-M1 根修）、script 本身与元数据跳过
	##（同脚本类——属性集恒一致）
	## 参数 from_record：磁盘新读实例；to_record：旧实例（同址壳）
	## 返回：无
	for prop: Dictionary in from_record.get_property_list():
		var prop_name: String = String(prop["name"])
		if prop_name == "script" or prop_name == "NODE_PATH" \
				or prop_name.begins_with("metadata/") \
				or RESOURCE_BUILTIN_PROPS.has(prop_name):
			continue
		to_record.set(prop_name, from_record.get(prop_name))

## 运行模式：DEMO 阶段或完整版
enum Mode {
	DEMO,
	FULL,
}

## 资源 id（core 域固定为 cfg_main，与文件名一致）
## 注：数值字段默认值一律中性（0/空），真实定值由 data/core/cfg_main.tres 显式承载
## （数据表与 schema 分离：改数据不改脚本）
@export var id: StringName = &""
## 运行模式
@export var mode: Mode = Mode.DEMO
## 系统启用清单：StringName 系统键 -> bool 是否启用
## （真键 14 个 / 假键 8 个——M4 增补批起 quest_noncombat 翻真；清单以案 16
## 启用隔离原则为准，合法键集合见 GameConfig.SYSTEM_KEYS）
@export var enabled_systems: Dictionary[StringName, bool] = {}
## 调整值换算偏移：调整值 = floor((属性 - attr_modifier_offset) / attr_modifier_divisor)（案 17 §3.3）
@export var attr_modifier_offset: int = 0
## 调整值换算除数（同上式；属性 10 = +0）
@export var attr_modifier_divisor: int = 0
## 难度五档判定线：String 档名（极易/容易/普通/困难/极难）-> int 判定线（案 17 §3.3）
@export var difficulty_tiers: Dictionary[String, int] = {}
## 大成功降线除数 X：降线数 = max(0, floor((幸运 - 10) / X))（案 17 §3.3）
@export var crit_success_drop_divisor: int = 0
## 大成功判定线下限（案 17 §3.3：X=3 下 DEMO 极限幸运触不到，长期护栏）
@export var crit_success_line_min: int = 0
## 幸运兜底 Y：骰点低于 Y 时按 Y 计（骰 1 仍大失败，案 17 §3.3）
@export var luck_floor_y: int = 0
## 幸运兜底 Z 基值：Z = max(z_base, z_base + floor((幸运 - 10) / z_divisor))（案 17 §3.3）
@export var luck_floor_z_base: int = 0
## 幸运兜底 Z 除数（同上式）
@export var luck_floor_z_divisor: int = 0
## 探索视野半径 R（欧氏圆形度量，全员固定值，案 17 §3.10/§3.11 #17）
@export var vision_radius: int = 0
## 暗门检定触发半径（小队所在格与暗门格的格间欧氏距离阈值，案 17 §3.10/§3.11 #17）
@export var secret_door_trigger_radius: int = 0
## 状态叠加上限（同名状态叠加层数上限，案 11 口径）
@export var status_stack_limit: int = 0
## 命中率基准（命中率 = 基准 + 感知调整值×2% + 技能修正 − 目标闪避，案 17 §3.2；
## 2026-09-24 用户拍板校准 0.80 → 0.85，铁律①数值入表）
@export var hit_base: float = 0.0
## 闪避率基准（闪避 = 基准 + 敏捷调整值×2%，案 17 §3.2；本次校准保持 0.05，
## 顺手参数化与 hit_base 同构，报备口径）
@export var dodge_base: float = 0.0
## 命中率钳制下限（实际命中概率钳制 [min, max]，案 17 §3.4）
@export var hit_clamp_min: float = 0.0
## 命中率钳制上限（同上）
@export var hit_clamp_max: float = 0.0
## 伤害下限（最终伤害 max(1, ...)，案 17 §3.4）
@export var damage_floor: int = 0

# ---- 二级属性派生公式参数（批 B M1：DerivedStats 公式参数入表，纯搬家）----
## 生命基础值（生命 = base + 体质×con_mult + 职业系数×(等级−1)，§3.2）
@export var hp_base: int = 0
## 生命体质乘数（同上式）
@export var hp_con_mult: int = 0
## 资源池基础值（法力/精力 = base + 换算源属性×mult，§3.2）
@export var pool_base: int = 0
## 资源池属性乘数（同上式）
@export var pool_mult: int = 0
## 命中率感知调整值权重（基准 + 感调×本值，§3.2 #4）
@export var attr_hit_weight: float = 0.0
## 闪避率敏捷调整值权重（§3.2）
@export var attr_dodge_weight: float = 0.0
## 异常状态抗性基础值（§3.2）
@export var status_resist_base: float = 0.0
## 异常状态抗性调整值权重（max(体调,意调)×本值，§3.2）
@export var status_resist_weight: float = 0.0
## 物理/法术抗性调整值权重（体质/感知轨同值，§3.2）
@export var resist_weight: float = 0.0
## 暴击率基础值（§3.2/§3.4）
@export var crit_base: float = 0.0
## 暴击率幸运调整值权重（§3.2）
@export var crit_luck_weight: float = 0.0
## 暴击率敏捷调整值权重（§3.2）
@export var crit_agility_weight: float = 0.0
## 暴击伤害倍率基础值（150% 基础 + 词条加成，§3.2）
@export var crit_mult_base: float = 0.0

# ---- 移动力/行动参数（批 B M2/M3）----
## 移动力基准段上限（职业 + 敏捷加成合计封顶；状态修正不封顶——17-C8）
@export var move_base_cap: int = 0
## 敏捷移动加成门槛（敏捷 ≥ 本值时移动力获得加成，17-C8）
@export var agility_move_bonus_line: int = 0
## 敏捷移动加成点数（A-2：达门槛时移动力 + 本值——原 +1 硬编码入表）
@export var agility_move_bonus_amount: int = 0
## 敌方 AI 怒吼义务门槛（3×3 内我方数 ≥ 本值才考虑怒吼——AI 行为可调参数）
@export var ai_roar_ally_count_line: int = 0

# ---- 穿甲/护甲换算参数（A-1：原 ×1 硬编码入表）----
## 物理穿甲 = 力量调整值 × 本值（§3.2 穿甲行）
@export var pierce_per_modifier: int = 0
## 护甲属性段 = 对应调整值 × 本值（物理←体质 / 法术←感知，§3.2）
@export var armor_per_modifier: int = 0

# ---- 技能域参数（C-8）----
## 技能射程上限（技能表 range 合法域 [0, 本值]——校验带兜底）
@export var skill_range_max: int = 0

# ---- 招募参数（批 B M4）----
## 招募属性钳制带下限（百分位）
@export var recruit_band_min: int = 0
## 招募属性钳制带上限（百分位）
@export var recruit_band_max: int = 0

# ---- 内容计数基线（批 C M6：校验器计数带参数化——M2 加内容改表即可，
## 基线值随内容扩展同表维护；min/max 同值 = 恒定断言）----
## W4-12 漂移同步注（2026-09-26 审计）：计数带注释与表值须同步维护——
## 校验器 _CountBand 回退常量与 cfg 缺省回退均锚定本组字段；改表加内容时
## 同步改注释里的「DEMO N 恒定断言」计数（此前交互点注释 10 表值 11 漂移）
## 技能计数带（六职业普攻 / 职业档 1 技 / 敌方技 / 敌方通用普攻）
@export var content_skill_attacks_min: int = 0
@export var content_skill_attacks_max: int = 0
@export var content_class_skills_min: int = 0
@export var content_class_skills_max: int = 0
@export var content_enemy_skills_min: int = 0
@export var content_enemy_skills_max: int = 0
@export var content_enemy_common_min: int = 0
@export var content_enemy_common_max: int = 0
## 状态表计数带
@export var content_status_min: int = 0
@export var content_status_max: int = 0
## 敌人 / 敌方队伍计数带
@export var content_enemies_min: int = 0
@export var content_enemies_max: int = 0
@export var content_packs_min: int = 0
@export var content_packs_max: int = 0
## 地图 / 地格 / 装备计数带
@export var content_maps_min: int = 0
@export var content_maps_max: int = 0
@export var content_tiles_min: int = 0
@export var content_tiles_max: int = 0
@export var content_equip_min: int = 0
@export var content_equip_max: int = 0

# ---- UI 视觉参数（S1-4 + B 席批：视觉数值入表——铁律①口径延伸）----
## 地格解析失败兜底色（tile 表查无定义的占位格色；默认透明 = 未回填，
## UI 侧回退代码兜底常量，V-B2-value-domains 拦截 alpha ≤ 0）
@export var ui_tile_fallback_color: Color = Color(0, 0, 0, 0)
## 版本标签前缀（B-11：title 屏版本文案单源——替代代码「DEMO M0」三处字面量）
@export var version_label: String = ""
## 敌方行动演出延时秒（A-10：BattleController.delay_seconds 的表侧权威值；
## @export 保留为测试注入口，生产经 BattleSetup 装配后回填）
@export var ui_battle_delay_seconds: float = 0.0
## 结算面板战败色（R3-08）
@export var ui_result_defeat_color: Color = Color(0, 0, 0, 0)
## 结算面板撤退色（R3-08）
@export var ui_result_retreat_color: Color = Color(0, 0, 0, 0)
## 徽章 HP 低血阈值（R3-08：hp_ratio ≤ 本值转低血色——原 0.35 内联）
@export var ui_badge_hp_low_threshold: float = 0.0
## 事件链计数带（M2：DEMO 三链恒定断言——内容扩展同表维护）
@export var content_event_chains_min: int = 0
@export var content_event_chains_max: int = 0
## 单点事件计数带（M2：三单点）
@export var content_event_singles_min: int = 0
@export var content_event_singles_max: int = 0
## 事件四档反馈色（M2：大成功/成功/失败/大失败）
@export var ui_event_grade_crit_success_color: Color = Color(0, 0, 0, 0)
@export var ui_event_grade_success_color: Color = Color(0, 0, 0, 0)
@export var ui_event_grade_failure_color: Color = Color(0, 0, 0, 0)
@export var ui_event_grade_crit_failure_color: Color = Color(0, 0, 0, 0)
## D20 演出滚动时长（秒——M2 event_panel；点按跳过）
@export var ui_d20_roll_seconds: float = 0.0

# ---- M6 批 1 单位动作集演出参数（9 字段，均【占位·试玩校准】；盲审批
# 补峰值色/步数上限两字段；----
# 动作帧率 = UnitBadge _Process 帧推进速率（fps ≤ 0 冻结——测试注入口）；
# 移动步长 = 战场徽章移动 tween 单步时长（≤ 0 瞬移——测试注 0 先例）；
# 受击闪烁 = 单位徽章受击白闪时长（≤ 0 立即复位）+ 峰值色；
# 步数上限 = 远距移动 tween 总时长钳制护栏
## 待机动作帧率（帧/秒）
@export var ui_anim_idle_fps: float = 0.0
## 移动动作帧率（帧/秒）
@export var ui_anim_move_fps: float = 0.0
## 攻击动作帧率（帧/秒——近战/施放共用档）
@export var ui_anim_attack_fps: float = 0.0
## 受击动作帧率（帧/秒）
@export var ui_anim_hit_fps: float = 0.0
## 倒地动作帧率（帧/秒）
@export var ui_anim_downed_fps: float = 0.0
## 战场徽章移动演出单步时长（秒/步——D6=A：0.15s/步 tween 滑动）
@export var ui_battle_move_step_seconds: float = 0.0
## 徽章受击白闪时长（秒）
@export var ui_hit_flash_seconds: float = 0.0
## 徽章受击白闪峰值色（HDR 亮白——modulate 分量 > 1 提亮；盲审低14 入表，
## 消费经 UiTheme.color_of——峰值色调可表驱）
@export var ui_hit_flash_peak_color: Color = Color(0, 0, 0, 0)
## 战场徽章移动演出步数上限（盲审低15：远距 tween 总时长钳制护栏——
## 「总时长 = 步长 × min(路径步数, 本值)」）
@export var ui_battle_move_max_steps: int = 0

# ---- UI 徽章配色（B-1/B-2/B-3：unit_badge 全部内联色入表；默认透明 = 未回填）----
@export var ui_badge_hp_low_color: Color = Color(0, 0, 0, 0)
@export var ui_badge_hp_ok_color: Color = Color(0, 0, 0, 0)
@export var ui_badge_bar_back_color: Color = Color(0, 0, 0, 0)
@export var ui_badge_res_mana_color: Color = Color(0, 0, 0, 0)
@export var ui_badge_res_stamina_color: Color = Color(0, 0, 0, 0)
@export var ui_badge_fallback_ally_color: Color = Color(0, 0, 0, 0)
@export var ui_badge_fallback_enemy_color: Color = Color(0, 0, 0, 0)
@export var ui_badge_bewitch_color: Color = Color(0, 0, 0, 0)
@export var ui_badge_preview_strip_color: Color = Color(0, 0, 0, 0)
@export var ui_badge_preview_text_color: Color = Color(0, 0, 0, 0)
@export var ui_badge_outline_color: Color = Color(0, 0, 0, 0)

# ---- UI 信息卡配色（B-1：unit_info_card 内联色入表）----
@export var ui_card_buff_color: Color = Color(0, 0, 0, 0)
@export var ui_card_debuff_color: Color = Color(0, 0, 0, 0)
@export var ui_card_unknown_color: Color = Color(0, 0, 0, 0)
@export var ui_card_muted_color: Color = Color(0, 0, 0, 0)

# ---- UI 覆盖层配色（B-5：battle_board 范围/路径/确认/阻断色入表）----
@export var ui_overlay_move_fill_color: Color = Color(0, 0, 0, 0)
@export var ui_overlay_move_border_color: Color = Color(0, 0, 0, 0)
@export var ui_overlay_skill_fill_color: Color = Color(0, 0, 0, 0)
@export var ui_overlay_skill_border_color: Color = Color(0, 0, 0, 0)
@export var ui_overlay_blocked_fill_color: Color = Color(0, 0, 0, 0)
@export var ui_overlay_blocked_border_color: Color = Color(0, 0, 0, 0)
@export var ui_overlay_blocked_slash_color: Color = Color(0, 0, 0, 0)
@export var ui_overlay_path_color: Color = Color(0, 0, 0, 0)
@export var ui_overlay_confirm_color: Color = Color(0, 0, 0, 0)

# ---- UI 飘字/tips 配色（S4-M4-3-d：battle_board 飘字与 tips 两行入表；默认透明 = 未回填）----
@export var ui_damage_crit_color: Color = Color(0, 0, 0, 0)
@export var ui_damage_normal_color: Color = Color(0, 0, 0, 0)
@export var ui_tips_line1_color: Color = Color(0, 0, 0, 0)
@export var ui_tips_line2_color: Color = Color(0, 0, 0, 0)

# ---- UI 战斗日志配色（B-6：LINE_COLORS 五色入表）----
@export var ui_log_system_color: Color = Color(0, 0, 0, 0)
@export var ui_log_damage_color: Color = Color(0, 0, 0, 0)
@export var ui_log_heal_color: Color = Color(0, 0, 0, 0)
@export var ui_log_status_color: Color = Color(0, 0, 0, 0)
@export var ui_log_move_color: Color = Color(0, 0, 0, 0)

# ---- UI 共享配色（B-2 倒地灰显 / B-3 金色高亮 / B-4 深底面板）----
@export var ui_downed_modulate_color: Color = Color(0, 0, 0, 0)
@export var ui_highlight_gold_color: Color = Color(0, 0, 0, 0)
@export var ui_panel_dark_color: Color = Color(0, 0, 0, 0)

# ---- UI 字号档位（B-7：display/title/heading/subheading/large/body/normal/small/minor）----
@export var ui_font_size_display: int = 0
@export var ui_font_size_title: int = 0
@export var ui_font_size_heading: int = 0
@export var ui_font_size_subheading: int = 0
@export var ui_font_size_large: int = 0
@export var ui_font_size_body: int = 0
@export var ui_font_size_normal: int = 0
@export var ui_font_size_small: int = 0
@export var ui_font_size_minor: int = 0

# ---- M3 探索层参数（视觉/演出 + 内容计数带；默认透明/0 = 未回填）----
## 探索逐格步进演出时长（秒/格——M3 移动演出）
@export var ui_explore_move_step_seconds: float = 0.0
## 迷雾未探索遮蔽色（浓雾——UNSEEN 态遮罩）
@export var ui_fog_unseen_color: Color = Color(0, 0, 0, 0)
## 迷雾已探索遮蔽色（记忆态——DIM 态遮罩）
@export var ui_fog_dim_color: Color = Color(0, 0, 0, 0)
## 探索小队图标色
@export var ui_explore_party_color: Color = Color(0, 0, 0, 0)
## 目标点激活色（本委托绑定目标点高亮）
@export var ui_explore_target_active_color: Color = Color(0, 0, 0, 0)
## 目标点灰显色（非绑定目标点/未激活出口）
@export var ui_explore_target_dim_color: Color = Color(0, 0, 0, 0)
## 判据达成横幅色
@export var ui_explore_goal_banner_color: Color = Color(0, 0, 0, 0)
## 探索常显图标衬底色（目标点在迷雾之上的对比底——席4 L3 回填，
## 消除纯代码兜底）
@export var ui_explore_icon_backdrop_color: Color = Color(0, 0, 0, 0)
## 探索图计数带（M3：DEMO 总图 1 恒定断言）
@export var content_map_count_min: int = 0
@export var content_map_count_max: int = 0
## 交互点计数带（M3：DEMO 11 恒定断言——含出口点；W4-12 漂移同步 10→11）
@export var content_interact_points_min: int = 0
@export var content_interact_points_max: int = 0
## 目标点计数带（M3：DEMO 6 恒定断言）
@export var content_target_points_min: int = 0
@export var content_target_points_max: int = 0
## 遭遇权重计数带（M3：DEMO 2 恒定断言）
@export var content_encounter_weights_min: int = 0
@export var content_encounter_weights_max: int = 0

# ---- M4 经营层参数（案 2 日历 / 案 4 经济 / 案 5 招募与成长 / 案 6 委托）----
## 周天数（七日一周——周刷新与星期展示的周期基准；V-M4-cfg-domain 锚定 7）
@export var calendar_week_days: int = 0
## 星期显示开关（案 2 §2.1 历法显示 DEMO 必做 #19）
@export var calendar_week_display: bool = false
## 日结算管线步骤键（顺序消费——案 2 §2.4 固定顺序表驱动；M4 增补批起六步：
## quest_countdown 后插入 quest_noncombat_advance 轻度工期推进步；
## V-M4-cfg-domain 校验键集恰合六步序）
@export var day_settle_pipeline: Array[String] = []
## 初始资金（案 17 §3.7：500 金）
@export var initial_gold: int = 0
## 招募池容量（案 17 §3.7：DEMO 简化 3）
@export var recruit_pool_capacity: int = 0
## 招募花费三档（属性总和分档价——<74 → low / 74-77 → mid / ≥78 → high）
@export var recruit_cost_low: int = 0
@export var recruit_cost_mid: int = 0
@export var recruit_cost_high: int = 0
## 招募花费档界（下界 74 / 上界 78——避开高频中值 75/77/79，案 17 §3.7）
@export var recruit_cost_line_low: int = 0
@export var recruit_cost_line_high: int = 0
## 招募占位名池（【占位·试玩校准】——拍板⑦：招募命名走 cfg 名池）
@export var recruit_name_pool: Array[String] = []
## 升级经验曲线基数（升级所需经验 = 本值 × 当前等级——17-C5：100×L）
@export var exp_per_level_base: int = 0
## 等级上限（DEMO = 5，17-C5）
@export var level_cap: int = 0
## 每级全属性成长值（17-C3：全额口径 +1）
@export var levelup_all_attrs: int = 0
## 每级倾向侧重属性额外成长值（17-C3：+1）
@export var levelup_tendency_bonus: int = 0
## 出生技能点（17 案 §3.6：1 点）
@export var skill_points_birth: int = 0
## 每级技能点（17 案 §3.6：1 点/级）
@export var skill_points_per_level: int = 0
## 档 1 技能解锁花费（技能点/个，17 案 §3.6）
@export var skill_unlock_cost: int = 0
## 重伤休养基础天数（仅战败触发；宿舍缩减归 fac_ 表，案 17 §3.5：3 天）
@export var injury_rest_days: int = 0
## 委托板名义数量（DEMO 占位取 3——案 6 §5；允许板空不承诺恒定）
@export var quest_board_size: int = 0
## 周刷新/开局预生成抽板数（板刷池 11 不放回抽 3 上板——P-9；M4 增补批起
## 11 = 8 战斗 + 3 轻度混刷）
@export var quest_week_draw: int = 0
## 超额人数奖励加成率统一值（结算值 ×(1+本值×超额人数)，货币+经验适用、
## 声望不加；模板 excess_bonus_per_head > 0 时覆盖本值——M4 主批拍板③）
@export var quest_excess_bonus_per_head: float = 0.0
## 替换到期表现的新实例时限（「加急·」3 天——案 18 §2.6 自洽注）
@export var quest_replace_time_limit: int = 0
## 委托模板计数带（M4 增补批：DEMO 合计 12=板刷 11+事件授予 1）
@export var content_quest_templates_min: int = 0
@export var content_quest_templates_max: int = 0
## 板刷渠道模板计数带（M4 增补批：11 恒定断言——8 战斗+3 轻度混刷）
@export var content_quest_board_min: int = 0
@export var content_quest_board_max: int = 0
## 事件授予渠道模板计数带（M4：1 恒定断言）
@export var content_quest_grant_min: int = 0
@export var content_quest_grant_max: int = 0
## 轻度委托奖励带宽（M4 增补批：NON_COMBAT 模板校验带——exp/gold/reputation
## 各 min-max；【占位·试玩校准】，W4-12 漂移同步：改带须同步 validator 引用）
@export var quest_light_reward_exp_min: int = 0
@export var quest_light_reward_exp_max: int = 0
@export var quest_light_reward_gold_min: int = 0
@export var quest_light_reward_gold_max: int = 0
@export var quest_light_reward_reputation_min: int = 0
@export var quest_light_reward_reputation_max: int = 0
## 设施定义计数带（M4：宿舍+训练场 2 恒定断言）
@export var content_facilities_min: int = 0
@export var content_facilities_max: int = 0
## 冒险者初始种子计数带（M4：初始 4 人恒定断言）
@export var content_adv_seeds_min: int = 0
@export var content_adv_seeds_max: int = 0

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
