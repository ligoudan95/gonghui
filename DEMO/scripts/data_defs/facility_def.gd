## 设施定义（FacilityDef）
## 职责：公会设施表行——设施类别、等级上限与逐级效果曲线（FacilityLevelDef
## 子资源数组）、设施场景名引用；DEMO 两行（宿舍 fac_dormitory / 训练场
## fac_training_ground，均 1-2 级，案 3 §2.1 DEMO 豁免：上限 2 级不与公会等级挂钩）。
## 数据来源：案 3《公会等级与设施》§2.2/§2.3；案 17 §3.7/§3.11 #10（数值收口）。
## id 命名规范：guild/facilities 域，fac_ 前缀，文件名与 id 同名。
class_name FacilityDef
extends Resource

## 设施类别（决定效果字段的消费口径）
enum FacilityKind {
	DORMITORY,
	TRAINING,
}

## 设施 id（如 &"fac_dormitory"）
@export var id: StringName = &""
## 中文名（如「宿舍」）
@export var display_name: String = ""
## 设施类别
@export var facility_kind: FacilityKind = FacilityKind.DORMITORY
## 等级上限（DEMO 固定 2——案 3 §2.1 豁免条款，不与公会等级挂钩）
@export var max_level: int = 2
## 逐级效果行（levels[i].level == i + 1 恒一致——V-M4-fac-domain 校验）
@export var levels: Array[FacilityLevelDef] = []
## 设施场景名（SceneManager.SCENE_REGISTRY 键；场景文件批 2 落地、本批先落引用值，
## 拍板⑥「设施=三独立场景」的表侧承载）
@export var scene_id: StringName = &""
## 设施背景资产 id（M6 批 3.5a A6：背景接线的数据位——bg_* 键经 assets 域
## AssetRegistry 映射；空 = 占位合法（3.5b 接线前过渡态，V-M6-fac-bg 不收紧空值））
@export var bg_asset_id: StringName = &""

## 设计备注（【占位·试玩校准】等标注与数据来源说明，Inspector 可编辑）
@export var comment: String = ""
