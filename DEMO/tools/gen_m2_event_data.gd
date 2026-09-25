## M2 批 1 事件与检定数据生成器
## 职责：生成 DEMO 事件内容表——事件链 3 / 事件节点 11 / 事件选项 10 /
## 单点事件 3 / 委托模板 1（q_lost_miner_keepsake），重生成命名登记表
## （+28 条）；hidden_marks 域先建后空 0 行（铁律⑧）。
## 内容来源：案 18 §2.1-2.5（文案逐格落）；机制归案 8；数值【占位·试玩校准】。
## 用法：godot --headless --import 后
##   godot --headless -s res://tools/gen_m2_event_data.gd
## 注：可重复执行（幂等覆盖）。
extends SceneTree

## !! 警示（解耦复审 C-10 同口径）：本工具为首次生成占位数据的脚本——
## 全库数据已人工调校定稿，重跑将【覆盖调校值】，必须先备份并对 diff
## 逐行复核后才可采纳。

func _initialize() -> void:
	## MainLoop 回调：依次生成链/节点/选项/单点/委托、重生成命名登记表后退出
	## 参数：无
	## 返回：无（任一保存失败按退出码 1 结束）
	var ok: bool = true
	ok = _GenerateChains() and ok
	ok = _GenerateNodes() and ok
	ok = _GenerateOptions() and ok
	ok = _GenerateSingles() and ok
	ok = _GenerateQuests() and ok
	ok = _RegenerateNamingRegistry() and ok
	if ok:
		print("gen_m2_event_data: 全部数据生成完成")
		quit(0)
	else:
		printerr("gen_m2_event_data: 存在保存失败项")
		quit(1)

func _SaveResource(resource: Resource, path: String) -> bool:
	## 保存资源到指定路径（目录不存在则先创建）
	## 参数 resource：待保存资源；path：目标 res:// 路径
	## 返回：true = 保存成功
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err: Error = ResourceSaver.save(resource, path)
	if err != OK:
		printerr("保存失败 %s（错误码 %d）" % [path, err])
		return false
	print("已生成 %s" % path)
	return true

func _Reward(exp: int, gold: int, reputation: int) -> RewardDef:
	## 构建奖励子资源
	## 参数 exp/gold/reputation：三货币量
	## 返回：RewardDef
	var reward := RewardDef.new()
	reward.exp = exp
	reward.gold = gold
	reward.reputation = reputation
	return reward

func _Modifier(text: String, exp: int, gold: int, reputation: int,
		hp_delta: int) -> EventModifierDef:
	## 构建修饰子资源
	## 参数 text：演出文本；exp/gold/reputation：奖励增量；hp_delta：队伍损耗（负）
	## 返回：EventModifierDef
	var modifier := EventModifierDef.new()
	modifier.text = text
	modifier.reward_delta = _Reward(exp, gold, reputation)
	modifier.party_hp_delta = hp_delta
	return modifier

func _Outcome(kind: int, exp: int, gold: int, reputation: int,
		texts: Dictionary) -> EventOutcomeDef:
	## 构建 A 类出口子资源
	## 参数 kind：ExitKind；exp/gold/reputation：奖励；texts：四档文本
	## 返回：EventOutcomeDef
	var outcome := EventOutcomeDef.new()
	outcome.exit_kind = kind
	outcome.reward = _Reward(exp, gold, reputation)
	var typed: Dictionary[StringName, String] = {}
	for key: StringName in texts:
		typed[key] = texts[key]
	outcome.texts = typed
	return outcome

func _BattleOutcome(pack: StringName, first_strike: StringName, layout: StringName,
		initial_status: StringName, pre_texts: Dictionary, post_exp: int,
		post_gold: int, post_texts: Dictionary) -> EventOutcomeDef:
	## 构建 B 类出口子资源（开局参数包 + 战后递归 A 出口）
	## 参数 pack：敌方队伍 id；first_strike/layout：先手权与分布 token；
	## initial_status：初始状态 id（空=无）；pre_texts：战前四档文本；
	## post_exp/post_gold/post_texts：战后出口
	## 返回：EventOutcomeDef
	var outcome := EventOutcomeDef.new()
	outcome.exit_kind = EventOutcomeDef.ExitKind.B
	var battle := BattleOpeningDef.new()
	battle.pack_id = pack
	battle.first_strike_token = first_strike
	battle.enemy_layout_token = layout
	battle.initial_status_id = initial_status
	battle.post_battle = _Outcome(EventOutcomeDef.ExitKind.A, post_exp, post_gold, 0, post_texts)
	outcome.battle = battle
	var typed: Dictionary[StringName, String] = {}
	for key: StringName in pre_texts:
		typed[key] = pre_texts[key]
	outcome.texts = typed
	return outcome

func _GenerateChains() -> bool:
	## 生成事件链 3 条
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	var rules: Array = [
		[&"chain_mine_collapse", "塌方救援", &"evn_collapse_n1", &"", &"evp_mine_01",
				"案 18 §2.1；塌方救援链（耗时代价演示）"],
		[&"chain_mine_wisp", "矿道鬼火", &"evn_wisp_n1", &"", &"evp_mine_02",
				"案 18 §2.2；矿道鬼火链（B 类出口演示：伏击/列阵）"],
		[&"chain_mine_camp", "废弃矿工营地", &"evn_camp_n1", &"", &"evp_mine_03",
				"案 18 §2.3；废弃营地链（C8 授予委托演示）"],
	]
	for rule: Array in rules:
		var chain := EventChainDef.new()
		chain.id = rule[0]
		chain.display_name = rule[1]
		chain.entry_node_id = rule[2]
		chain.quest_ref_id = rule[3]
		chain.trigger_point_id = rule[4]
		chain.comment = "【占位·试玩校准】" + rule[5]
		ok = _SaveResource(chain, "res://data/event/chains/%s.tres" % rule[0]) and ok
	return ok

func _GenerateNodes() -> bool:
	## 生成事件节点 11 条（终端节点内嵌 outcome）
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	var node := EventNodeDef.new()
	# ---- 链一塌方（n1 入口 + n2-n5 终端）----
	node = EventNodeDef.new()
	node.id = &"evn_collapse_n1"
	node.display_name = "塌方现场"
	node.chain_id = &"chain_mine_collapse"
	node.narrative_text = "前方的矿道塌了半边，碎石堆得一人多高。屏住呼吸——石头后面，传来一阵压得很低的呻吟。有人被埋在里面。"
	node.option_ids = [&"opt_collapse_1", &"opt_collapse_2", &"opt_collapse_3", &"opt_collapse_4"]
	node.comment = "【占位·试玩校准】案 18 §2.1 入口节点"
	ok = _SaveResource(node, "res://data/event/nodes/evn_collapse_n1.tres") and ok

	node = EventNodeDef.new()
	node.id = &"evn_collapse_n2"
	node.display_name = "窄缝救人"
	node.chain_id = &"chain_mine_collapse"
	node.narrative_text = "半个时辰后，石头堆里露出一张灰扑扑的脸。矿工老周咳嗽着爬出来，拍了半天胸口，才从怀里摸出一小把铜币：「救命之恩，别嫌少。」"
	node.outcome = _Outcome(EventOutcomeDef.ExitKind.A, 15, 10, 0, {
		&"success": "及时救出了被困的矿工。他掏出贴身的钱袋致谢。",
		&"crit_success": "老周犹豫了一下，又把藏在靴筒里的私房钱也掏了出来——「真是救命恩人。」",
		&"failure": "人已救出，无惊无险。",
		&"crit_failure": "人已救出，无惊无险。",
	})
	node.comment = "【占位·试玩校准】案 18 §2.1 n2 终端（o1 成功向）"
	ok = _SaveResource(node, "res://data/event/nodes/evn_collapse_n2.tres") and ok

	node = EventNodeDef.new()
	node.id = &"evn_collapse_n3"
	node.display_name = "整通道敞开"
	node.chain_id = &"chain_mine_collapse"
	node.narrative_text = "撬棍吱嘎作响，巨石轰隆滚开，整条通道豁然敞亮。老周拍着屁股站起来，毫发无伤，连工具包都还背在背上。他把包里最沉的那块矿石塞给你们：「这个厚道！」"
	node.outcome = _Outcome(EventOutcomeDef.ExitKind.A, 20, 15, 0, {
		&"success": "通道整个敞开，人和工具都保住了。",
		&"crit_success": "巨石底下压着的正是矿工们来不及搬走的工具箱——上着锁，完好无损。",
		&"failure": "通道已开，此路无虞。",
		&"crit_failure": "通道已开，此路无虞。",
	})
	node.comment = "【占位·试玩校准】案 18 §2.1 n3 终端（o2 成功向）"
	ok = _SaveResource(node, "res://data/event/nodes/evn_collapse_n3.tres") and ok

	node = EventNodeDef.new()
	node.id = &"evn_collapse_n4"
	node.display_name = "自己爬出"
	node.chain_id = &"chain_mine_collapse"
	node.narrative_text = "扒了半天，只清出一条窄缝。最后是老周自己挤出来的，胳膊蹭掉一片皮。他摆摆手表示不碍事，把干粮袋里最后半张饼掰给了你们。"
	node.outcome = _Outcome(EventOutcomeDef.ExitKind.A, 10, 5, 0, {
		&"success": "没能完全清开通道，但人总算出来了——受了点轻伤，谢礼也薄了些。",
		&"crit_success": "窄缝里还带出来一小袋没散的干粮。",
		&"failure": "没能完全清开通道，但人总算出来了——受了点轻伤，谢礼也薄了些。",
		&"crit_failure": "头顶的碎石这时又簌簌滑落一片。众人抱头散开，还是蹭了一身伤。",
	})
	node.comment = "【占位·试玩校准】案 18 §2.1 n4 终端（o1/o2 失败共向）"
	ok = _SaveResource(node, "res://data/event/nodes/evn_collapse_n4.tres") and ok

	node = EventNodeDef.new()
	node.id = &"evn_collapse_n5"
	node.display_name = "支护稳救"
	node.chain_id = &"chain_mine_collapse"
	node.narrative_text = "找来坑木、垫上石楔，支护、清石、再支护——多花了一整天，稳稳当当把人请了出来。老周千恩万谢，就着火把画了张他记得的旧矿道草图，末了指了指北边：「那一带的墙，敲起来有空响，你们留心。」"
	node.outcome = _Outcome(EventOutcomeDef.ExitKind.A, 15, 15, 0, {
		&"success": "稳妥的代价是多花一天，换来的是完整的谢礼与一张草图。（情报：北壁有空响）",
		&"crit_success": "草图上还标了一处老周自己都忘了的存钱点。",
		&"failure": "稳妥完成，无惊无险。",
		&"crit_failure": "稳妥完成，无惊无险。",
	})
	node.comment = "【占位·试玩校准】案 18 §2.1 n5 终端（o3 纯选择·耗时 +1 天）"
	ok = _SaveResource(node, "res://data/event/nodes/evn_collapse_n5.tres") and ok

	# ---- 链二鬼火（n1 入口 + n2/n3 B 出口演出终端）----
	node = EventNodeDef.new()
	node.id = &"evn_wisp_n1"
	node.display_name = "岔道鬼火"
	node.chain_id = &"chain_mine_wisp"
	node.narrative_text = "岔道口浮着一团幽蓝的火。不摇不晃，就那么悬在半人高的地方，明一下，暗一下——像是有什么东西在里面眨眼睛。"
	node.option_ids = [&"opt_wisp_1", &"opt_wisp_2", &"opt_wisp_3"]
	node.comment = "【占位·试玩校准】案 18 §2.2 入口节点"
	ok = _SaveResource(node, "res://data/event/nodes/evn_wisp_n1.tres") and ok

	node = EventNodeDef.new()
	node.id = &"evn_wisp_n2"
	node.display_name = "被伏击"
	node.chain_id = &"chain_mine_wisp"
	node.narrative_text = "鬼火在你们眼前散作几点火星。四下忽然窸窣作响——巢穴就在脚下，而你们正好站在正中央。"
	node.outcome = _BattleOutcome(&"enc_m1_wisp_nest", &"enemy_first", &"clustered",
			&"DEBUFF_exposed", {
		&"success": "散尽的火星燎在后颈上，你们慢了不止半拍。",
		&"failure": "散尽的火星燎在后颈上，你们慢了不止半拍。",
		&"crit_failure": "火星燎伤了眼睛，队伍一阵手忙脚乱。",
	}, 15, 15, {
		&"success": "打散这窝东西后，你们从巢穴里扒出一小堆亮闪闪的「收藏品」。",
		&"failure": "战后清点，巢穴里多少还有些值钱的玩意儿。",
	})
	node.comment = "【占位·试玩校准】案 18 §2.2 n2（o1 失败·被伏击：敌先手+集结+暴露减益 18-C7）"
	ok = _SaveResource(node, "res://data/event/nodes/evn_wisp_n2.tres") and ok

	node = EventNodeDef.new()
	node.id = &"evn_wisp_n3"
	node.display_name = "列阵推进"
	node.chain_id = &"chain_mine_wisp"
	node.narrative_text = "鬼火在齐整的枪尖前徘徊了两圈，散了。火把的光惊动不了什么——深处巢穴里的东西，正等着你们自己走进去。"
	node.outcome = _BattleOutcome(&"enc_m1_wisp_nest", &"ally_first", &"spread", &"", {
		&"success": "枪尖齐整，你们主动踏进了巢穴的领地。",
		&"failure": "枪尖齐整，你们主动踏进了巢穴的领地。",
	}, 15, 15, {
		&"success": "打散这窝东西后，你们从巢穴里扒出一小堆亮闪闪的「收藏品」。",
		&"failure": "战后清点，巢穴里多少还有些值钱的玩意儿。",
	})
	node.comment = "【占位·试玩校准】案 18 §2.2 n3（o3 纯选择·列阵：我先手+分散）"
	ok = _SaveResource(node, "res://data/event/nodes/evn_wisp_n3.tres") and ok

	# ---- 链三营地（n1 入口 + n2 C8 终端 + n3 终端）----
	node = EventNodeDef.new()
	node.id = &"evn_camp_n1"
	node.display_name = "废弃营地"
	node.chain_id = &"chain_mine_camp"
	node.narrative_text = "一间废弃的矿工营地：床板翻倒，灶膛冷透，晾衣绳上还挂着半件烂衣裳。角落有一本被水泡胀的日记，床底塞着一只上锁的工具箱。奇怪的是——灶膛里的灰，像是新近被人踩过。"
	node.option_ids = [&"opt_camp_1", &"opt_camp_2", &"opt_camp_3"]
	node.comment = "【占位·试玩校准】案 18 §2.3 入口节点"
	ok = _SaveResource(node, "res://data/event/nodes/evn_camp_n1.tres") and ok

	node = EventNodeDef.new()
	node.id = &"evn_camp_n2"
	node.display_name = "完整日记"
	node.chain_id = &"chain_mine_camp"
	node.narrative_text = "纸页粘连，但关键的字都认得出：撤离那晚，托米没能从老井暗窖出来——他的工具包和这个月的工钱都还留在下面。最后一页只有一行：「谁捡到这本子，替我去村口，跟她说一声。」"
	var c8_outcome := _Outcome(EventOutcomeDef.ExitKind.A, 20, 0, 0, {
		&"success": "日记里写明了老井暗窖的位置。这桩事，该有人替他走一趟。",
		&"crit_success": "日记的夹层里贴着一张矿区草图，老井的位置圈了三个圈；草图下还压着几枚没来得及花的工钱币。",
		&"failure": "日记可读，此路无失败。",
		&"crit_failure": "日记可读，此路无失败。",
	})
	c8_outcome.grant_quest_id = &"q_lost_miner_keepsake"
	node.outcome = c8_outcome
	node.comment = "【占位·试玩校准】案 18 §2.3 n2（C8 授予委托终端·20 经验）"
	ok = _SaveResource(node, "res://data/event/nodes/evn_camp_n2.tres") and ok

	node = EventNodeDef.new()
	node.id = &"evn_camp_n3"
	node.display_name = "模糊日记"
	node.chain_id = &"chain_mine_camp"
	node.narrative_text = "纸页泡烂了大半，翻来覆去只认出半行字：「老井……下面……」。剩下的，都糊成了深色的印子。"
	node.outcome = _Outcome(EventOutcomeDef.ExitKind.A, 10, 0, 0, {
		&"success": "线索残缺，但方向总算有了一个。",
		&"crit_success": "糊掉的纸页背面还透着半个字——「北」。",
		&"failure": "线索残缺，但方向总算有了一个。",
		&"crit_failure": "翻页时纸页散成碎片，毛边还在指腹上割了道小口。",
	})
	node.comment = "【占位·试玩校准】案 18 §2.3 n3 终端（o1 失败向）"
	ok = _SaveResource(node, "res://data/event/nodes/evn_camp_n3.tres") and ok
	return ok

func _GenerateOptions() -> bool:
	## 生成事件选项 10 条
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	var rules: Array = [
		# ---- 链一 ----
		[&"opt_collapse_1", "徒手扒开碎石", EventOptionDef.OptionKind.CHECK,
				&"constitution", "容易", &"evn_collapse_n2", &"evn_collapse_n4", null, null,
				"徒手救人：+15 金 / 全队生命 −5", 0],
		[&"opt_collapse_2", "用撬棍顶起巨石", EventOptionDef.OptionKind.CHECK,
				&"strength", "困难", &"evn_collapse_n3", &"evn_collapse_n4", null, null,
				"撬巨石：+15 金 / 全队生命 −5", 0],
		[&"opt_collapse_3", "先支护再慢慢挖", EventOptionDef.OptionKind.PURE,
				&"", "", &"evn_collapse_n5", &"", null, null,
				"耗时 +1 天（案 8 #3 演示·全案唯一）", 1],
		[&"opt_collapse_4", "贴壁绕过塌方区", EventOptionDef.OptionKind.PURE,
				&"", "", &"", &"",
				_Outcome(EventOutcomeDef.ExitKind.A, 0, 0, 0, {
					&"plain": "委托的时限压在肩上。你们贴着岩壁，从塌方区边缘挤了过去。身后的呻吟声越来越远，谁都没有说话。",
					&"success": "绕行成功。",
					&"failure": "绕行成功。",
				}), null,
				"直接出口 E1（无奖励）", 0],
		# ---- 链二 ----
		[&"opt_wisp_1", "屏住呼吸，跟上去", EventOptionDef.OptionKind.CHECK,
				&"perception", "普通", &"", &"evn_wisp_n2",
				_Outcome(EventOutcomeDef.ExitKind.A, 15, 20, 0, {
					&"success": "跟到岔道深处，鬼火停在一片干燥的岩壁上——是矿脉上附生的荧晶群在幽幽发光。撬下几块，就是实打实的钱。",
					&"crit_success": "荧晶根部还生着一小丛磷伞菇——药铺常年收这个，又添一笔。",
					&"failure": "荧晶已到手。",
					&"crit_failure": "荧晶已到手。",
				}), null,
				"+10 金 / 全队生命 −5", 0],
		[&"opt_wisp_2", "举着火把凑近细看", EventOptionDef.OptionKind.CHECK,
				&"intelligence", "容易", &"", &"",
				_Outcome(EventOutcomeDef.ExitKind.A, 15, 10, 0, {
					&"success": "火光凑近，那团蓝焰纹丝不动。是磷光真菌，无害。掰一把揣进包里——又见这条道上地面干燥、没有兽迹，是个歇脚的好地方。",
					&"crit_success": "真菌丛里还裹着一枚矿工失落的钱币。",
					&"failure": "凑得太近，一团孢子呛得你们连打了十几个喷嚏。等眼泪鼻涕一起收场——咳，不过是真菌，虚惊一场。",
					&"crit_failure": "喷嚏声在矿道里荡出老长的回音。黑暗深处，有什么被惊醒后又重新趴了下去——你们后颈发凉，快步退了回来。",
				}),
				_Outcome(EventOutcomeDef.ExitKind.A, 10, 0, 0, {
					&"success": "虚惊一场，认了个明白。",
					&"failure": "凑得太近，一团孢子呛得你们连打了十几个喷嚏。等眼泪鼻涕一起收场——咳，不过是真菌，虚惊一场。",
					&"crit_success": "虚惊一场。",
					&"crit_failure": "孢子呛了满鼻，退了回来。",
				}),
				"+10 金 / 全队生命 −5", 0],
		[&"opt_wisp_3", "列阵戒备，稳步推进", EventOptionDef.OptionKind.PURE,
				&"", "", &"evn_wisp_n3", &"", null, null,
				"主动求战线（我方先手+分散）", 0],
		# ---- 链三 ----
		[&"opt_camp_1", "小心翻开日记", EventOptionDef.OptionKind.CHECK,
				&"intelligence", "困难", &"evn_camp_n2", &"evn_camp_n3", null, null,
				"+20 金 / 全队生命 −5", 0],
		[&"opt_camp_2", "撬开工具箱", EventOptionDef.OptionKind.CHECK,
				&"luck", "极易", &"", &"",
				_Outcome(EventOutcomeDef.ExitKind.A, 10, 30, 0, {
					&"success": "锁扣崩开。箱底垫着块油布——是矿工撤离前来不及带走的积蓄，一包包得整整齐齐。",
					&"crit_success": "油布下面还有一层夹底——另一包更沉的工钱币躺在里面。",
					&"failure": "箱里只有些铁器，此路无失败。",
					&"crit_failure": "箱里只有些铁器，此路无失败。",
				}),
				_Outcome(EventOutcomeDef.ExitKind.A, 10, 5, 0, {
					&"success": "锁芯锈死了。费尽力气撬开，只有半箱铁器，论斤称给废铁铺还能换几个钱。",
					&"crit_success": "铁器里混着一根完好的钢钎。",
					&"failure": "锁芯锈死了。费尽力气撬开，只有半箱铁器，论斤称给废铁铺还能换几个钱。",
					&"crit_failure": "撬棍打滑，凿穿了箱底——你们眼睁睁看着一小包钱币顺着石缝漏了下去，手心也震得发麻。",
				}),
				"+20 金 / 全队生命 −5", 0],
		[&"opt_camp_3", "生起火，喊两嗓子试探", EventOptionDef.OptionKind.CHECK,
				&"willpower", "容易", &"", &"",
				_Outcome(EventOutcomeDef.ExitKind.A, 10, 15, 1, {
					&"success": "火光刚旺，草席底下就窸窸窣窣拱出来一个跛脚的老矿工——他守着营地不敢挪窝，怕的就是「下面那些东西」。安顿好他，他非要把随身的旧披风留给你们：「卖了吧，别嫌破。」",
					&"crit_success": "老矿工临走前指了指北边：「那面墙后头有风。我埋伙食钱的时候听见过。」",
					&"failure": "火光无碍。",
					&"crit_failure": "火光无碍。",
				}),
				_Outcome(EventOutcomeDef.ExitKind.A, 10, 5, 0, {
					&"success": "喊了半天没人应。火堆倒把潮气烘干了，就地歇了歇脚，捡了些可卖的铁器。",
					&"crit_success": "歇脚时顺手把营地收拾利索了。",
					&"failure": "喊了半天没人应。火堆倒把潮气烘干了，就地歇了歇脚，捡了些可卖的铁器。",
					&"crit_failure": "烟没顺着烟道走，倒灌回来熏得众人眼泪横流，咳了半天才顺过气。",
				}),
				"声望 +1 / 全队生命 −5", 0],
	]
	for rule: Array in rules:
		var option := EventOptionDef.new()
		option.id = rule[0]
		option.display_name = rule[1]
		option.kind = rule[2]
		option.check_attr_id = rule[3]
		option.difficulty_tier = rule[4]
		option.success_to = rule[5]
		option.failure_to = rule[6]
		if rule[7] != null:
			option.success_outcome = rule[7]
		if rule[8] != null:
			option.failure_outcome = rule[8]
		option.cost_days = rule[10]
		option.comment = "【占位·试玩校准】案 18 §2.x；" + rule[9]
		# 修饰：检定选项统一「大成功 +金额（或声望）/ 大失败 全队生命 −5」
		if option.kind == EventOptionDef.OptionKind.CHECK:
			var bonus_text: String = rule[9]
			if option.id == &"opt_camp_3":
				option.crit_modifier = _Modifier("老矿工临走前指了指北边：「那面墙后头有风。」",
						0, 0, 1, 0)
			elif option.id == &"opt_wisp_1":
				option.crit_modifier = _Modifier("荧晶根部还生着一小丛磷伞菇——药铺常年收这个。",
						0, 10, 0, 0)
			elif option.id == &"opt_wisp_2":
				option.crit_modifier = _Modifier("真菌丛里还裹着一枚矿工失落的钱币。",
						0, 10, 0, 0)
			elif option.id == &"opt_collapse_1" or option.id == &"opt_collapse_2":
				option.crit_modifier = _Modifier("塌开的石缝里还滚出几枚矿工掉落的铜币。",
						0, 15, 0, 0)
			elif option.id == &"opt_camp_1":
				option.crit_modifier = _Modifier("日记的夹层里贴着一张矿区草图，草图下还压着几枚工钱币。",
						0, 20, 0, 0)
			elif option.id == &"opt_camp_2":
				option.crit_modifier = _Modifier("油布下面还有一层夹底——另一包更沉的工钱币躺在里面。",
						0, 20, 0, 0)
			option.crit_fail_modifier = _Modifier("慌乱间蹭了一身伤。", 0, 0, 0, -5)
		ok = _SaveResource(option, "res://data/event/options/%s.tres" % rule[0]) and ok
	return ok

func _GenerateSingles() -> bool:
	## 生成单点事件 3 条
	## 参数：无
	## 返回：true = 全部保存成功
	var ok: bool = true
	var single := SingleEventDef.new()
	single.id = &"sp_village_cart"
	single.display_name = "陷进泥里的板车"
	single.narrative_text = "进村的土路上，老农的板车深深地陷进泥里，一车南瓜摇摇欲坠。老农看见你们胸口协会的徽记，眼睛一下子亮了。"
	single.check_attr_id = &"strength"
	single.difficulty_tier = "容易"
	single.success_outcome = _Outcome(EventOutcomeDef.ExitKind.A, 10, 0, 1, {
		&"success": "一声号子，车轮「咔哒」弹回辙上。老农乐得直拍腿，硬塞给你们两个大南瓜，又朝协会的方向拱了拱手。",
		&"crit_success": "顺手把撞歪的辕木也敲正了。老农非要再塞一袋腌菜：「冬天就粥，顶好！」",
		&"failure": "车没抬动，几个人反倒溅了一身泥。老农哈哈笑着摆手：「心意领了，娃们，等村里的小伙子收工再说。」",
		&"crit_failure": "用力过猛，车没动，人先叠进了泥里。老农一边拉人一边笑得直不起腰，末了还是塞了两个南瓜。",
	})
	single.failure_outcome = _Outcome(EventOutcomeDef.ExitKind.A, 10, 0, 0, {
		&"failure": "车没抬动，几个人反倒溅了一身泥。老农哈哈笑着摆手：「心意领了，娃们，等村里的小伙子收工再说。」",
		&"success": "车抬起来了。",
	})
	single.crit_modifier = _Modifier("老农非要再塞一袋腌菜。", 0, 0, 1, 0)
	single.crit_fail_modifier = _Modifier("（无额外实效，从简——单点安全区放宽）", 0, 0, 0, 0)
	single.comment = "【占位·试玩校准】案 18 §2.4 村子单点·力量容易(8)"
	ok = _SaveResource(single, "res://data/event/singles/sp_village_cart.tres") and ok

	single = SingleEventDef.new()
	single.id = &"sp_village_traveler"
	single.display_name = "井边的旅人"
	single.narrative_text = "水井边坐着个斗篷旅人，脚边斜靠着一柄裹布的长枪。见你们过来，他举了举锡杯：「下矿的？听一句劝——这矿里的墙，不都是实心的。北边那面，敲一敲。」说完他把杯子扣在井沿上，走了。"
	single.success_outcome = _Outcome(EventOutcomeDef.ExitKind.A, 10, 0, 0, {
		&"plain": "旅人走了。这句话，你们记下了。（情报：北边那面墙敲一敲）",
		&"success": "旅人走了。这句话，你们记下了。",
		&"failure": "旅人走了。",
	})
	single.comment = "【占位·试玩校准】案 18 §2.4 无检定单档结算（暗门铺垫）"
	ok = _SaveResource(single, "res://data/event/singles/sp_village_traveler.tres") and ok

	single = SingleEventDef.new()
	single.id = &"sp_mine_secretdoor"
	single.display_name = "北壁的风"
	single.narrative_text = "矿洞一层的北壁。凑近了听——砖缝里确实透着一丝极轻的风声，若有若无。"
	single.check_attr_id = &"perception"
	single.difficulty_tier = "极难"
	var door_success := _Outcome(EventOutcomeDef.ExitKind.A, 10, 0, 0, {
		&"success": "北壁的砖缝确实透着风。抠开几块松动的砖，一条仅容一人侧身的窄道露了出来——绕过整段塌陷区，直通矿洞深处。前人早就在砖上刻了记号。",
		&"crit_success": "窄道口的墙角塞着一个油布小包——干硬的口粮，和十五枚旧币。先行者留下的，现在归你们了。",
		&"failure": "此路无失败。",
		&"crit_failure": "此路无失败。",
	})
	door_success.unlock_flag = &"secret_door_mine_north"
	single.success_outcome = door_success
	single.failure_outcome = _Outcome(EventOutcomeDef.ExitKind.A, 10, 0, 0, {
		&"failure": "敲遍了整面北墙，声音都闷闷的。也许……真的只是风。（暗门保持隐藏，可走主路绕行）",
		&"success": "风声找到了。",
		&"crit_failure": "松动的砖块哗啦啦砸了一地。你们后跳半步，灰头土脸——墙里似乎有什么翻动了一下，又归于寂静。",
	})
	single.crit_modifier = _Modifier("窄道口的墙角塞着一个油布小包——先行者留下的。", 0, 15, 0, 0)
	single.crit_fail_modifier = _Modifier("碎砖砸了一地，灰头土脸。", 0, 0, 0, -5)
	single.comment = "【占位·试玩校准】案 18 §2.5 暗门检定·感知极难(17)·unlock_flag=secret_door_mine_north"
	ok = _SaveResource(single, "res://data/event/singles/sp_mine_secretdoor.tres") and ok
	return ok

func _GenerateQuests() -> bool:
	## 生成委托模板 1 条（q_lost_miner_keepsake——M2 拍板③只落此 1 行）
	## 参数：无
	## 返回：true = 保存成功
	var quest := QuestTemplateDef.new()
	quest.id = &"q_lost_miner_keepsake"
	quest.display_name = "没能回家的托米"
	quest.quest_type = QuestTemplateDef.QuestType.NORMAL
	quest.exec_class = QuestTemplateDef.ExecClass.COMBAT
	quest.level_tier = 1
	quest.goal_type = QuestTemplateDef.GoalType.EXPLORE
	quest.goal_param = &"tp_old_well"
	quest.region_id = &"mine"
	quest.party_min = 2
	quest.party_max = 4
	quest.time_limit_days = 7
	quest.reward = _Reward(80, 150, 5)
	quest.acquire_channel = QuestTemplateDef.AcquireChannel.EVENT_GRANT
	quest.comment = "【占位·试玩校准】案 18 §2.3 事件授予专用（18-C3）；目标=老井暗窖 tp_old_well；奖励 150金/80经验/声望5"
	return _SaveResource(quest, "res://data/quest/templates/q_lost_miner_keepsake.tres")

func _RegenerateNamingRegistry() -> bool:
	## 重生成命名登记表：追加 M2 的 28 条（链 3/节点 11/选项 10/单点 3/委托 1），
	## 幂等（已登记跳过）
	## 参数：无
	## 返回：true = 保存成功
	var registry: NamingRegistry = ResourceLoader.load(
			"res://data/core/naming_registry.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as NamingRegistry
	if registry == null:
		printerr("gen_m2_event_data: naming_registry 加载失败")
		return false
	var entries: Array[NamingEntry] = registry.entries
	var existing_ids: Dictionary = {}
	for entry: NamingEntry in entries:
		existing_ids[entry.resource_id] = true
	var chain_rules: Dictionary = {
		&"chain_mine_collapse": ["塌方救援（链）", "chain_<语义>：事件链（M2·案 8/18）"],
		&"chain_mine_wisp": ["矿道鬼火（链）", "chain_<语义>：事件链（B 出口演示）"],
		&"chain_mine_camp": ["废弃矿工营地（链）", "chain_<语义>：事件链（C8 授予演示）"],
	}
	var node_rules: Dictionary = {
		&"evn_collapse_n1": ["塌方现场", "evn_<链>_<序>：事件节点"],
		&"evn_collapse_n2": ["窄缝救人", "evn_<链>_<序>：事件节点（终端 A）"],
		&"evn_collapse_n3": ["整通道敞开", "evn_<链>_<序>：事件节点（终端 A）"],
		&"evn_collapse_n4": ["自己爬出", "evn_<链>_<序>：事件节点（终端 A·失败共向）"],
		&"evn_collapse_n5": ["支护稳救", "evn_<链>_<序>：事件节点（终端 A·耗时线）"],
		&"evn_wisp_n1": ["岔道鬼火", "evn_<链>_<序>：事件节点"],
		&"evn_wisp_n2": ["被伏击", "evn_<链>_<序>：事件节点（终端 B·敌先手）"],
		&"evn_wisp_n3": ["列阵推进", "evn_<链>_<序>：事件节点（终端 B·我先手）"],
		&"evn_camp_n1": ["废弃营地", "evn_<链>_<序>：事件节点"],
		&"evn_camp_n2": ["完整日记", "evn_<链>_<序>：事件节点（C8 授予终端）"],
		&"evn_camp_n3": ["模糊日记", "evn_<链>_<序>：事件节点（终端 A）"],
	}
	var option_rules: Dictionary = {
		&"opt_collapse_1": ["徒手扒开碎石", "opt_<链>_<序>：事件选项（体质·容易）"],
		&"opt_collapse_2": ["用撬棍顶起巨石", "opt_<链>_<序>：事件选项（力量·困难）"],
		&"opt_collapse_3": ["先支护再慢慢挖", "opt_<链>_<序>：事件选项（纯选择·耗时 +1）"],
		&"opt_collapse_4": ["贴壁绕过塌方区", "opt_<链>_<序>：事件选项（纯选择·直接出口）"],
		&"opt_wisp_1": ["屏住呼吸，跟上去", "opt_<链>_<序>：事件选项（感知·普通）"],
		&"opt_wisp_2": ["举着火把凑近细看", "opt_<链>_<序>：事件选项（智力·容易）"],
		&"opt_wisp_3": ["列阵戒备，稳步推进", "opt_<链>_<序>：事件选项（纯选择）"],
		&"opt_camp_1": ["小心翻开日记", "opt_<链>_<序>：事件选项（智力·困难）"],
		&"opt_camp_2": ["撬开工具箱", "opt_<链>_<序>：事件选项（幸运·极易）"],
		&"opt_camp_3": ["生起火，喊两嗓子试探", "opt_<链>_<序>：事件选项（意志·容易）"],
	}
	var single_rules: Dictionary = {
		&"sp_village_cart": ["陷进泥里的板车", "sp_<区域>_<语义>：单点事件（力量·容易）"],
		&"sp_village_traveler": ["井边的旅人", "sp_<区域>_<语义>：单点事件（无检定）"],
		&"sp_mine_secretdoor": ["北壁的风", "sp_<区域>_<语义>：单点事件（暗门·感知·极难）"],
	}
	var quest_rules: Dictionary = {
		&"q_lost_miner_keepsake": ["没能回家的托米", "q_<语义>：委托模板（事件授予专用）"],
	}
	var appended: int = 0
	appended += _AppendEntries(entries, existing_ids, &"event/chains", chain_rules)
	appended += _AppendEntries(entries, existing_ids, &"event/nodes", node_rules)
	appended += _AppendEntries(entries, existing_ids, &"event/options", option_rules)
	appended += _AppendEntries(entries, existing_ids, &"event/singles", single_rules)
	appended += _AppendEntries(entries, existing_ids, &"quest/templates", quest_rules)
	print("gen_m2_event_data: naming 登记追加 %d 条（总 %d）" % [appended, entries.size()])
	return _SaveResource(registry, "res://data/core/naming_registry.tres")

func _AppendEntries(entries: Array[NamingEntry], existing_ids: Dictionary,
		domain: StringName, rules: Dictionary) -> int:
	## 幂等追加登记条目
	## 参数 entries/existing_ids：登记表现状；domain：域键；rules：id -> [中文名, 规则注]
	## 返回：追加条数
	var appended: int = 0
	for record_id: StringName in rules:
		if existing_ids.has(record_id):
			continue
		var entry := NamingEntry.new()
		entry.resource_id = record_id
		entry.domain = domain
		entry.display_name = rules[record_id][0]
		entry.rule_note = rules[record_id][1]
		entries.append(entry)
		existing_ids[record_id] = true
		appended += 1
	return appended
