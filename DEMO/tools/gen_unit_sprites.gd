## 单位占位 sprite 生成器（插队任务：M1 战棋像素小人临时资源）
## 职责：程序化绘制 9 张 32x32 单位占位 PNG（我方六职业蓝系 / 敌方三红系）、
## 生成 3x3 预览拼图（4x 放大 + id 标注）、同步 AssetRegistry 登记。
## 设计依据：案 20 《视觉专项案》§3.4（Q 版二头身 / 剪影辨识=武器+头饰）；
## 案 10 《职业与技能》§2.1（六职业定位）；案 17 《数值专项案》§3.8（敌方三敌种）。
## 图案约定：'.' = 透明；其余单字符查本单位 palette；'o' = 1px 深色描边
## （精英头目例外=金边轮廓）；底部 2-4px 半透明椭圆阴影。
## 用法：godot --headless -s res://tools/gen_unit_sprites.gd
## 幂等：重复执行覆盖生成 PNG/预览；registry 仅重建 spr_ 前缀键（保留其他键）。
## 替换：正式二次元资源 M6 按案 20 同 id 原位替换，本生成器届时退役。
extends SceneTree

## 输出目录与文件
const OUT_DIR: String = "res://assets/units"
const PREVIEW_PATH: String = "res://assets/units/_preview_all.png"
const REGISTRY_PATH: String = "res://data/assets/registry.tres"

## 单位图案画布边长（像素）
const SIZE: int = 32

## 预览放大倍数与单元尺寸
const PREVIEW_SCALE: int = 4
const PREVIEW_CELL: int = SIZE * PREVIEW_SCALE

## 预览标签区高 / 外边距 / 格间距（像素）
const LABEL_H: int = 28
const PREVIEW_PAD: int = 8
const PREVIEW_GAP: int = 8

## 阴影色（半透明黑，任何底色上稳定可读）
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)

## 9 个单位图案定义（id / 调色板 / 32 行图案，行序即 y 坐标）
const UNITS: Array = [
	{
		"id": "spr_cls_warrior",
		"desc": "战士：金羽冠重盔+宽体蓝甲，左手塔盾（金菱徽），右手竖剑超头顶（剪影辨识）",
		"palette": {
			"o": Color("#1c2130"), "H": Color("#d9a441"), "S": Color("#5a7bb5"),
			"F": Color("#f2c9a0"), "E": Color("#ffffff"), "P": Color("#2b4f8f"),
			"A": Color("#6f8fc4"), "a": Color("#4a68a0"), "L": Color("#6b4a33"),
			"D": Color("#85a3d4"), "W": Color("#cdd6e4"), "w": Color("#8f9aac"),
			"h": SHADOW_COLOR,
		},
		"rows": [
			"...............HH...............",
			"..............oHHo..............",
			"............ooSSSSoo............",
			"...........oSSSSSSSSo....W......",
			"...........oSSSSSSSSo...wWWo....",
			"..........oSSSSSSSSSSo..wWWo....",
			"..........oSSSSSSSSSSo..wWWo....",
			"..........oSFFFFFFFFSo..wWWo....",
			"..........oSFFFFFFFFSo..wWWo....",
			"..........oSFEPFFPEFSo..wWWo....",
			"..........oSFPPFFPPFSo..wWWo....",
			"..........oSFFFFFFFFSo..wWWo....",
			"............ooFFFFFFoo..wWWo....",
			".........oAAAAAAAAAAAAo.wWWo....",
			".........oAAAAAAAAAAAAo.wWWo....",
			".........oAAaaaaaaaaAAo.wWWo....",
			"...oDDDo.oAAAaaaaaaAAAo.wWWo....",
			"..oDDDDDooAAAaaaaaaAAAo.wWWo....",
			"..oDDDDDooAALLLLLLLLAAo.wWWo....",
			"..oDDHDDooAALLLLLLLLAAo.wWWo....",
			"..oDHHHDooAAAaaaaaaAAAooHHHHHo..",
			"..oDHHHDooaaAAAooAAAaao.LLo.....",
			"..oDDHDDooaAAAooooAAAao.LLo.....",
			"...oDDDo...oLLo..oLLo...oHo.....",
			"...........oLLo..oLLo...........",
			"...........oooo..oooo...........",
			".........hhhhhhhhhhhhhh.........",
			"...........hhhhhhhhhh...........",
			"................................",
			"................................",
			"................................",
			"................................",
		],
	},
	{
		"id": "spr_cls_rogue",
		"desc": "盗贼：靛蓝兜帽罩脸（帽尖后垂），阴影中青白亮眼，双匕首（右竖握/左反握），瘦削身形",
		"palette": {
			"o": Color("#14182a"), "B": Color("#3d4e7a"), "b": Color("#2b3860"),
			"U": Color("#232b47"), "E": Color("#a8e4f0"), "F": Color("#d8a98c"),
			"A": Color("#4a5878"), "a": Color("#37415e"), "L": Color("#5a4632"),
			"W": Color("#cdd6e4"), "G": Color("#8a8f9c"), "h": SHADOW_COLOR,
		},
		"rows": [
			"................................",
			"................................",
			".............oBo................",
			"...........oBBBo................",
			"..........oBBBBBBBBBBo..........",
			"..........oBBbbbbbbBBo..........",
			"..........oBBBBBBBBBBo..........",
			"..........oBBBBBBBBBBo..........",
			"..........oBBUUUUUUBBo..........",
			"..........oBUUUUUUUUBo..........",
			"..........oBUEEUUEEUBo...W......",
			"..........oBUEEUUEEUBo...W......",
			"..........oBUUFFFFUUBo...W......",
			"............ooFFFFFFoo...W......",
			"...........oAAAAAAAAo....W......",
			"...........oAAaAAaAAo....W......",
			"...........oAAAAAAAAo..oGo......",
			"........G..oAALLLLLAo...G.......",
			"........G..oAAAAAAAAo...G.......",
			"........W..oAAaAAaAAo...W.......",
			"........W..oAAaaaaAAo...........",
			"........W..oAA....AAo...........",
			"........W..obb....bbo...........",
			"........W...oo....oo............",
			"................................",
			"..........hhhhhhhhhhhh..........",
			"............hhhhhhhhhh..........",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
		],
	},
	{
		"id": "spr_cls_mage",
		"desc": "法师：天蓝尖帽（帽尖折垂左侧+金星），长袍垂地，右手长杖顶蓝白宝珠",
		"palette": {
			"o": Color("#1a1a2e"), "C": Color("#5e93e8"), "B": Color("#4a7fd6"),
			"b": Color("#3560a8"), "H": Color("#d9a441"), "F": Color("#f2c9a0"),
			"E": Color("#ffffff"), "P": Color("#2b6fb8"), "W": Color("#bcd8ff"),
			"Y": Color("#ffffff"), "L": Color("#7a5a3a"), "h": SHADOW_COLOR,
		},
		"rows": [
			"................................",
			"...............oCo..............",
			".............oCCo......oWWWo....",
			"...........oCCCCCCo....oWWWo....",
			".........oCCCCCCCCCCo..oWYWo....",
			"........oCCCCCCCCHHCCo..ooo.....",
			".......oCCCCCCCCCCCCCCo..L......",
			"........oooooooooooooo...L......",
			"..........oFFFFFFFFFFo...L......",
			"..........oFFEPFFPEFFo...L......",
			"..........oFFPPFFPPFFo...L......",
			"..........oFFFFFFFFFFo...L......",
			"..........ooFFFFFFFFoo...L......",
			".........oBBBBBBBBBBBBo...L.....",
			".........oBBbbbbbbbbBBo...L.....",
			".........oBBBbbbbbbBBBo...L.....",
			"........oBBBbbbbbbbbBBBo..L.....",
			"........oBBBbbbbbbbbBBBo..L.....",
			"........oBBbbbbbbbbbbBBo..L.....",
			"........oBBbbbbbbbbbbBBo..L.....",
			"........oBbbbbbbbbbbbbBo..L.....",
			"........oBbbbbbbbbbbbbBo..L.....",
			"........obbbbbbbbbbbbbbo..L.....",
			"........obbbbbbbbbbbbbbo..L.....",
			"........obbbbbbbbbbbbbbo..L.....",
			".......obbbbbbbbbbbbbbbbo.......",
			".......oooooooooooooooooo.......",
			"........hhhhhhhhhhhhhhhh........",
			"..........hhhhhhhhhh............",
			"................................",
			"................................",
			"................................",
		],
	},
	{
		"id": "spr_cls_priest",
		"desc": "牧师：白袍+金腰带金头圈，头巾包发，右手权杖顶金色十字圣徽",
		"palette": {
			"o": Color("#2a2620"), "W": Color("#f2efe6"), "w": Color("#d9d2c0"),
			"H": Color("#d9a441"), "F": Color("#f2c9a0"), "P": Color("#7a5a3a"),
			"L": Color("#8a6a4a"), "E": Color("#ffffff"), "h": SHADOW_COLOR,
		},
		"rows": [
			"................................",
			"................................",
			".........................HH.....",
			"............ooWWWWoo..HHHHHHHH..",
			"..........oWWWWWWWWWWoHHHHHHHH..",
			"..........oWWWWWWWWWWo...LL.....",
			"..........oWWHHHHHHWWo...LL.....",
			"..........oWWWWWWWWWWo...LL.....",
			"..........oWWWWWWWWWWo...LL.....",
			"..........oWFFFFFFFFWo...LL.....",
			"..........oWFEPFFPEFWo...LL.....",
			"..........oWFPPFFPPFWo...LL.....",
			"..........oWFFFFFFFFWo...LL.....",
			"...........oWWFFFFWWo....LL.....",
			".........oWWWWWWWWWWWWo..LL.....",
			".........oWWWWWWWWWWWWo..LL.....",
			"........oWWWWWWWWWWWWWWo.LL.....",
			"........oWWWWWWWWWWWWWWo.LL.....",
			"........oWHHHHHHHHHHHHWo.LL.....",
			"........oWWWWWWWWWWWWWWo.LL.....",
			"........oWwWWWWWWWWwWWWo.LL.....",
			"........oWWWWWWWWWWWWWWo.LL.....",
			"........oWwWWWWWWWWwWWWo.LL.....",
			"........oWWWWWWWWWWWWWWo.LL.....",
			"........owwWWWWWWWWwwWWo.LL.....",
			".......owwwwwwwwwwwwwwo.ooo.....",
			".......oooooooooooooooo.........",
			"........hhhhhhhhhhhhhhhh........",
			"..........hhhhhhhhhh............",
			"................................",
			"................................",
			"................................",
		],
	},
	{
		"id": "spr_cls_ranger",
		"desc": "游侠：深绿宽檐帽+青绿披风（两侧展开），斜挎皮带，右手箭袋（白羽），左手长弓（弓弧+弦）",
		"palette": {
			"o": Color("#1a2420"), "N": Color("#35604a"), "n": Color("#2a4c3a"),
			"G": Color("#3f7d5f"), "g": Color("#2d5c46"), "A": Color("#6a8f5a"),
			"a": Color("#57784a"), "b": Color("#4f4a3c"), "L": Color("#7a5a3a"),
			"S": Color("#e8e2d4"), "F": Color("#f2c9a0"), "E": Color("#ffffff"),
			"P": Color("#2b4f8f"), "h": SHADOW_COLOR,
		},
		"rows": [
			"................................",
			"................................",
			"................................",
			"................................",
			"............ooNNoo..............",
			"...........oNNNNNNNNo.S.S.......",
			"...........oNNNNNNNNo.S.S.......",
			"..........oNNNNNNNNNNo..........",
			"....L.Sonnnnnnnnnnnnnnno........",
			"...LL.SoFFFFFFFFFFFFo...........",
			"...L..S.oFFFEPFFPEFFFo..........",
			"..LL..S.oFFFPPFFPPFFFo..........",
			"..LL..S.oFFFFFFFFFFFFo..........",
			"..L...S.ooFFFFFFFFFFoo..........",
			".LL....S.oAAAAAAAAAAAAo.........",
			".LL..oGG.oAALLAAAAAAAAoGGo......",
			".LL..oGG.oAaAALLAAAAAAoGGo......",
			".LL..oGG.oAAaAALLAAAAAoGGo......",
			".LL...oG.oAAAaAALLAAAAo.Go......",
			".LL.....oAAAAAAAAAAAAo..........",
			"..LL...S.oAAAAAAAAAAAAo.........",
			"..LL...S...oAA....oAA..o........",
			"..LL...S...obb....obb..o........",
			"...L...S...oLL....oLL..o........",
			"....L..S...ooo....ooo..o........",
			"...LL.S..hhhhhhhhhhhhhh.........",
			"...........hhhhhhhhhh...........",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
		],
	},
	{
		"id": "spr_cls_arcanist",
		"desc": "奇术师：暗紫宽袍+罩帽（阴影中亮紫眼），右上浮空菱形水晶（高光），胸前翻开魔典（金符文）",
		"palette": {
			"o": Color("#201a2e"), "V": Color("#5a3d7a"), "v": Color("#412d5c"),
			"U": Color("#2a1f3e"), "E": Color("#b98ae8"), "F": Color("#d8a98c"),
			"X": Color("#c77dff"), "Y": Color("#efe2ff"), "P": Color("#e8e2d4"),
			"H": Color("#d9a441"), "h": SHADOW_COLOR,
		},
		"rows": [
			"................................",
			"................................",
			"............ooVVoo..............",
			"..........oVVVVVVVVVVo...X......",
			"..........oVVVVVVVVVVo..XYX.....",
			"..........oVvvvvvvvvVo..XXX.....",
			"..........oVVVVVVVVVVo..XXX.....",
			"..........oVVVVVVVVVVo...X......",
			"..........oVUUUUUUUUVo..........",
			"..........oVUEEUUEEUVo..........",
			"..........oVUEEUUEEUVo..........",
			"..........oVUUUUUUUUVo..........",
			"..........oVVUFFFFUVVo..........",
			"...........oVFFFFFFVo...........",
			".........oVVVVVVVVVVVVo.........",
			".........oVVVvvvvVVVVVo.........",
			"........oVVVVvvvvVVVVVo.........",
			"........oVVVVVvvVVVVVVo.........",
			"........oVHVVVvvVVVVVHVo........",
			"........oV.oPPPPPPPPo.Vo........",
			"........oV.oPPVhVhPPo.Vo........",
			"........oV.oPPVVVVPPo.Vo........",
			"........oV.oPPPPPPPPo.Vo........",
			"........oV.oHHHHHHHHo.Vo........",
			"........ovvvvvvvvvvvvvvo........",
			".......ovvvvvvvvvvvvvvvvo.......",
			".......oooooooooooooooooo.......",
			"........hhhhhhhhhhhhhhhh........",
			"..........hhhhhhhhhh............",
			"................................",
			"................................",
			"................................",
		],
	},
	{
		"id": "spr_en_mutant_rat",
		"desc": "变异鼠：红褐皮毛四足啮齿（伏低侧视），背鬃深红尖刺，红眼+白门牙，左伸粉尾，红系杂兵",
		"palette": {
			"o": Color("#241410"), "m": Color("#5e2018"), "B": Color("#8f4a3d"),
			"b": Color("#6b332b"), "n": Color("#c48a7a"), "t": Color("#c98a7a"),
			"R": Color("#ff5a4a"), "Y": Color("#ffd9a0"), "W": Color("#ffffff"),
			"h": SHADOW_COLOR,
		},
		"rows": [
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			".....................oo.........",
			"........mm...mm...mmotto........",
			".......oBBBBBBBBBBBBBBoo........",
			"......oBBBBBBBBBBBBBBBoo........",
			".tt...oBbBBBBBBBBBbBBoBBBBBo....",
			"..ttt.oBbBBBBBBBBBbBBooBRYBBnno.",
			"....t.oBbBBBBBBBBBbBBooBRBBBnno.",
			"....t.oBnnnnnnnnnnbBBooBBBnnnnt.",
			"....t.oBnnnnnnnnnnnnBooBnnWWnnn.",
			"......onnnnnnnnnnnnnoooBnnnnoo..",
			".......oBo........oBo...........",
			".......oBo........oBo...........",
			".......ooo........ooo...........",
			"....hhhhhhhhhhhhhhhhhhhhhhhhh...",
			"......hhhhhhhhhhhhhhhhhhhhh.....",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
		],
	},
	{
		"id": "spr_en_goblin_miner",
		"desc": "哥布林矿工：红矿帽+金头灯，绿皮尖耳+红眼獠牙，红背带裤，右肩扛矿镐（钢镐头），红系杂兵",
		"palette": {
			"o": Color("#1e2418"), "C": Color("#c74a3c"), "c": Color("#96352b"),
			"H": Color("#ffd76a"), "G": Color("#5e9e4f"), "g": Color("#46763a"),
			"R": Color("#ff6a5a"), "Y": Color("#ffe9a0"), "W": Color("#ffffff"),
			"A": Color("#a03d33"), "a": Color("#7a2b24"), "L": Color("#7a5a3a"),
			"M": Color("#9aa3ad"), "h": SHADOW_COLOR,
		},
		"rows": [
			"................................",
			".............oo.................",
			"...........oCCCCo...............",
			"..........oCCHHCCCCo............",
			".........oCCCCCCCCCCo...........",
			"........oCCCCCCCCCCCCCCo........",
			"........oooooooooooooooo........",
			".........oGGGGGGGGGGGGo.........",
			"....oGG..oGGGGGGGGGGGGo.Go......",
			"....oGG..oGRYGGGGGRYGooMMMMMMMo.",
			".....ooG.oGRRGGGGRRGooMMMMMMMo..",
			".....oo..oGGGGGGGGGGGGoM..L...M.",
			".........oGGgGGGGGGgGGo...L.....",
			".........ooGWGGGGGGWGoo...L.....",
			".........oGGGGGGGGGGGGo...L.....",
			".........oGAAAAAAAAAAGo...L.....",
			"........oGAAAAAAAAAAAAGo..L.....",
			"........oGAAAAAAAAAAAAGo..L.....",
			"........oGAaAAAAAAAAaAGo..L.....",
			"........oGGAAAAAAAAAAGGo.GLG....",
			"........oGGGGGGGGGGGGGGo.GGG....",
			".........oGGGG....GGGGo.........",
			".........oGGGG....GGGGo.........",
			".........oLLLL....LLLLo.........",
			".........hhhhhhhhhhhhhh.........",
			"...........hhhhhhhhhh...........",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
		],
	},
	{
		"id": "spr_en_elite_boss",
		"desc": "矿洞祸首：顶天立地大体型（占满 32 高），金边轮廓（描边=o 金），暗红重甲+双弯角+肩刺，右手巨锤，红眼獠牙",
		"palette": {
			"o": Color("#e8b84a"), "K": Color("#6e2f2f"), "V": Color("#7a2430"),
			"v": Color("#571822"), "H": Color("#ffd76a"), "F": Color("#b98a6a"),
			"R": Color("#ff5a4a"), "W": Color("#ffffff"), "M": Color("#6a7280"),
			"m": Color("#4a5058"), "L": Color("#4a3220"), "h": SHADOW_COLOR,
		},
		"rows": [
			"..........K..........K..........",
			".........KK..........KK.........",
			".........KK..........KK.........",
			".........oVVVVVVVVVVVVoMMMMMMMo.",
			".........oVVVVVVVVVVVVoMHMMHHMo.",
			".........oVVVVVVVVVVVVoMMMMMMMo.",
			".........oVVVVVVVVVVVVooMmMMmMo.",
			".........oVVHHHHHHHHVVoMMMMMMMo.",
			".........oVFFFFFFFFFFVoomMMMMmo.",
			".........oVRRVVVVRRVVoooooooo...",
			".........oVRRVVVVRRVVo..........",
			".........oVFFFFFFFFFFVo.........",
			".........oVFWFFFFFFWFVo.........",
			"....KK....ooFFFFFFFFoo....KK....",
			"....oVVVVVVVVVVVVVVVVVVVVVVo....",
			".....oVvVVVVVVVVVVVVVVVVvVoL....",
			".....oVVVVVvvvvvvvvvVVVVVVoL....",
			".....oVVVvVVVVVVVvVVVVVVVVoL....",
			"........oVVVVVvVVVVVVVVo.VVL....",
			"........oVvVVVvVVvVVVVVoVVVL....",
			"........oVVVHHVVVVHHVVVoVVVL....",
			"........oVvVVVvVVvVVVVVoVVVL....",
			"........oVVVVVvVVVVVVVVo...L....",
			"........oVvVHHVVVVHHvVVo...L....",
			".........ovvVVVVVVVVVVvvo.......",
			".........ovvvvvvvvvvvvvvo.......",
			"..........oVVVV..VVVVo..........",
			"..........oVVVV..VVVVo..........",
			"..........oKKKK..KKKKo..........",
			"........hhhhhhhhhhhhhhhh........",
			"..........hhhhhhhhhh............",
			"................................",
		],
	},
]

## 3x5 像素字体（预览标签用；行主序 15 位，'1' = 着色）
const FONT_3X5: Dictionary = {
	"a": "010101111101101", "b": "110101110101110", "c": "011100100100011",
	"d": "110101101101110", "e": "111100110100111", "f": "111100110100100",
	"g": "011100101101011", "h": "101101111101101", "i": "111010010010111",
	"j": "001001001101010", "k": "101101110101101", "l": "100100100100111",
	"m": "101111111101101", "n": "110101101101101", "o": "010101101101010",
	"p": "110101110100100", "q": "010101101011001", "r": "110101110101101",
	"s": "011100010001110", "t": "111010010010010", "u": "101101101101111",
	"v": "101101101101010", "w": "101101111111101", "x": "101101010101101",
	"y": "101101010010010", "z": "111001010100111", "_": "000000000000111",
}

func _initialize() -> void:
	## MainLoop 回调：校验图案自洽 -> 生成 9 PNG -> 同步 registry -> 生成预览
	## 参数：无
	## 返回：无（任一步失败按退出码 1 结束）
	var ok: bool = true
	ok = _EnsureOutputDir() and ok
	ok = _ValidatePatterns() and ok
	if ok:
		for unit: Dictionary in UNITS:
			ok = _GenerateSprite(unit) and ok
	if ok:
		ok = _GenerateRegistry()
	if ok:
		ok = _GeneratePreview()
	if ok:
		print("gen_unit_sprites: 全部产物生成完成（%d 单位 + registry + 预览）" % UNITS.size())
		quit(0)
	else:
		printerr("gen_unit_sprites: 存在失败项，详见上方输出")
		quit(1)

func _EnsureOutputDir() -> bool:
	## 确保输出目录存在（不存在则递归创建）
	## 参数：无
	## 返回：true = 目录可用
	var abs_dir: String = ProjectSettings.globalize_path(OUT_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		return true
	var err: Error = DirAccess.make_dir_recursive_absolute(abs_dir)
	if err != OK:
		printerr("gen_unit_sprites: 输出目录创建失败 %s（错误码 %d）" % [abs_dir, err])
		return false
	return true

func _ValidatePatterns() -> bool:
	## 图案数据自洽校验：行数=32 / 每行长度=32 / 字符在 '.' 或调色板内
	## 参数：无
	## 返回：true = 全部图案合法
	var ok: bool = true
	for unit: Dictionary in UNITS:
		var unit_id: String = unit["id"]
		var rows: Array = unit["rows"]
		var palette: Dictionary = unit["palette"]
		if rows.size() != SIZE:
			printerr("gen_unit_sprites: %s 行数 %d != %d" % [unit_id, rows.size(), SIZE])
			ok = false
			continue
		for y: int in rows.size():
			var line: String = rows[y]
			if line.length() != SIZE:
				printerr("gen_unit_sprites: %s 第 %d 行长度 %d != %d：'%s'" % [
					unit_id, y, line.length(), SIZE, line])
				ok = false
				continue
			for x: int in line.length():
				var ch: String = line[x]
				if ch != "." and not palette.has(ch):
					printerr("gen_unit_sprites: %s (%d,%d) 未知字符 '%s'" % [unit_id, x, y, ch])
					ok = false
	return ok

func _RenderUnit(unit: Dictionary) -> Image:
	## 按图案定义渲染单张 32x32 Image（透明底）
	## 参数 unit：单位定义（palette + rows）
	## 返回：渲染完成的 Image（调用方负责保存/合成）
	var img: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var palette: Dictionary = unit["palette"]
	var rows: Array = unit["rows"]
	for y: int in SIZE:
		var line: String = rows[y]
		for x: int in SIZE:
			var ch: String = line[x]
			if ch == ".":
				continue
			img.set_pixel(x, y, palette[ch])
	return img

func _GenerateSprite(unit: Dictionary) -> bool:
	## 渲染并保存单个单位 PNG
	## 参数 unit：单位定义
	## 返回：true = 保存成功
	var unit_id: String = unit["id"]
	var path: String = "%s/%s.png" % [OUT_DIR, unit_id]
	var img: Image = _RenderUnit(unit)
	var err: Error = img.save_png(path)
	if err != OK:
		printerr("gen_unit_sprites: 保存失败 %s（错误码 %d）" % [path, err])
		return false
	print("gen_unit_sprites: 已生成 %s（%s）" % [path, unit["desc"]])
	return true

func _GenerateRegistry() -> bool:
	## 同步 AssetRegistry：重建 spr_ 前缀键（保留其他键），登记 9 条 id -> 路径映射
	## 参数：无
	## 返回：true = 保存成功
	var registry: AssetRegistry = null
	if ResourceLoader.exists(REGISTRY_PATH):
		registry = load(REGISTRY_PATH) as AssetRegistry
	if registry == null:
		registry = AssetRegistry.new()
	# 收集旧 spr_ 键后删除（遍历中删除不安全）
	var stale_keys: Array[StringName] = []
	for key: StringName in registry.mapping:
		if String(key).begins_with("spr_"):
			stale_keys.append(key)
	for key: StringName in stale_keys:
		registry.mapping.erase(key)
	for unit: Dictionary in UNITS:
		var unit_id: StringName = StringName(unit["id"])
		registry.mapping[unit_id] = "%s/%s.png" % [OUT_DIR, unit["id"]]
	registry.comment = "【占位·像素小人】spr_* = M1 战棋单位临时资源（tools/gen_unit_sprites.gd 程序化绘制，可重复执行）；M6 按案 20 正式二次元资源同 id 原位替换"
	var err: Error = ResourceSaver.save(registry, REGISTRY_PATH)
	if err != OK:
		printerr("gen_unit_sprites: registry 保存失败 %s（错误码 %d）" % [REGISTRY_PATH, err])
		return false
	print("gen_unit_sprites: registry 已登记 %d 条 spr_* 映射 -> %s" % [UNITS.size(), REGISTRY_PATH])
	return true

func _GeneratePreview() -> bool:
	## 生成 3x3 预览拼图：4x 最近邻放大 + 像素字体标注 id（两行：前缀/名称）
	## 参数：无
	## 返回：true = 保存成功
	var width: int = PREVIEW_PAD * 2 + PREVIEW_CELL * 3 + PREVIEW_GAP * 2
	var height: int = PREVIEW_PAD * 2 + (PREVIEW_CELL + LABEL_H) * 3 + PREVIEW_GAP * 2
	var canvas: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("#2b303b"))
	for index: int in UNITS.size():
		var column: int = index % 3
		var row: int = index / 3
		var offset_x: int = PREVIEW_PAD + column * (PREVIEW_CELL + PREVIEW_GAP)
		var offset_y: int = PREVIEW_PAD + row * (PREVIEW_CELL + LABEL_H + PREVIEW_GAP)
		# 单元格底色块（深一格以衬托透明轮廓）
		for py: int in PREVIEW_CELL:
			for px: int in PREVIEW_CELL:
				canvas.set_pixel(offset_x + px, offset_y + py, Color("#1d2129"))
		var big: Image = _RenderUnit(UNITS[index])
		big.resize(PREVIEW_CELL, PREVIEW_CELL, Image.INTERPOLATE_NEAREST)
		_BlitAlpha(canvas, big, Vector2i(offset_x, offset_y))
		# 标签两行：前缀（spr_cls_/spr_en_）+ 名称
		var unit_id: String = UNITS[index]["id"]
		var prefix: String = "%s_%s_" % [unit_id.get_slice("_", 0), unit_id.get_slice("_", 1)]
		var unit_name: String = unit_id.trim_prefix(prefix)
		_DrawText3x5(canvas, prefix, Vector2i(offset_x, offset_y + PREVIEW_CELL + 3), Color("#9aa3b2"), 2)
		_DrawText3x5(canvas, unit_name, Vector2i(offset_x, offset_y + PREVIEW_CELL + 16), Color("#ffffff"), 2)
	var err: Error = canvas.save_png(PREVIEW_PATH)
	if err != OK:
		printerr("gen_unit_sprites: 预览保存失败 %s（错误码 %d）" % [PREVIEW_PATH, err])
		return false
	print("gen_unit_sprites: 预览拼图已生成 %s（%dx%d）" % [PREVIEW_PATH, width, height])
	return true

func _BlitAlpha(dst: Image, src: Image, offset: Vector2i) -> void:
	## 带 alpha 混合的图像拷贝（dst = dst*(1-a) + src*a）
	## 参数 dst：目标画布；src：源图（含 alpha）；offset：目标左上角
	## 返回：无
	for y: int in src.get_height():
		for x: int in src.get_width():
			var pixel: Color = src.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var dst_x: int = offset.x + x
			var dst_y: int = offset.y + y
			if pixel.a >= 1.0:
				dst.set_pixel(dst_x, dst_y, pixel)
			else:
				var base: Color = dst.get_pixel(dst_x, dst_y)
				dst.set_pixel(dst_x, dst_y, base.lerp(pixel, pixel.a))

func _DrawText3x5(img: Image, text: String, origin: Vector2i, color: Color, scale: int) -> void:
	## 用 3x5 像素字体绘制标签文字（步进 4*scale）
	## 参数 img：目标画布；text：文本；origin：左上角；color：颜色；scale：放大倍数
	## 返回：无
	var cursor_x: int = origin.x
	for ch: String in text:
		var glyph: String = FONT_3X5.get(ch, "")
		if not glyph.is_empty():
			for gy: int in 5:
				for gx: int in 3:
					if glyph[gy * 3 + gx] != "1":
						continue
					for sy: int in scale:
						for sx: int in scale:
							img.set_pixel(cursor_x + gx * scale + sx, origin.y + gy * scale + sy, color)
		cursor_x += 4 * scale
