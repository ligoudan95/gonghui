#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""角色组第二批 3 件动作资源处理脚本（M6 美术替换·批 2）。

职责（同 id 原位替换，零改表——registry 路径不变）：
  art_spec/act/ 三件源图（均 3072x5504 RGB 纯白底，**上下两帧竖排**，
  横切分割 = 行白像素统计找中部水平空白带自适应 + 防呆断言）→ 白底转
  alpha 软键羽化 + 逐像素孔洞回填（中性白灰回填 / 淡蓝刀光偏色半透明
  特效保持软键——tools/anim_pipeline.py 通用管线）→ Lanczos 等比、两帧
  统一缩放比、脚底基线对齐 y=122、水平居中、四周留边 5px → 竖排 128x256
  两帧（上=帧0、下=帧1）→ 像素实证断言 → 替换 assets/units/ 同名件。

清单（视觉已确认的源图内容）：
  1. spr_cls_warrior_idle.png   上下两帧待机（帧间细微呼吸差）→ 替换
     库内复制帧版本（同 id——本批为真实呼吸差两帧）
  2. spr_cls_mage_melee_attack.png  上=举杖蓄力 / 下=挥击+弧光粒子
  3. spr_cls_rogue_melee_attack.png 上=弓步蓄力双刀藏后 / 下=前倾突刺+
     淡蓝刀光（孔洞回填须区分——见 anim_pipeline.HOLE_* 注）

附加产出：reports/act2_shots/batch2_montage_4x.png 六帧 4x 放大拼图
（帧名标注——视觉验收证据）；stdout 记录逐帧朝向估计（原样导入不翻转）。

用法：python tools/process_anim_batch2.py（工作目录任意，路径按脚本
位置解析；生成后需 godot --headless --import 重导入方可运行时加载）。
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import anim_pipeline as pipe  # noqa: E402（同目录导入——路径注入后可解析）

## DEMO 工程根（脚本位于 DEMO/tools/）
ROOT: Path = Path(__file__).resolve().parent.parent

## 本批任务清单：件名 -> (源文件, 输出路径, 源图预期尺寸, 帧语义标签)
JOBS: list[dict[str, object]] = [
    {
        "name": "spr_cls_warrior_idle",
        "src": ROOT / "art_spec" / "act" / "spr_cls_warrior_idle.png",
        "out": ROOT / "assets" / "units" / "spr_cls_warrior_idle.png",
        "size": (3072, 5504),
        "labels": ["idle f0 (upper, breath A)", "idle f1 (lower, breath B)"],
    },
    {
        "name": "spr_cls_mage_melee_attack",
        "src": ROOT / "art_spec" / "act" / "spr_cls_mage_melee_attack.png",
        "out": ROOT / "assets" / "units" / "spr_cls_mage_melee_attack.png",
        "size": (3072, 5504),
        "labels": ["melee f0 (upper, charge)", "melee f1 (lower, swing+arc)"],
    },
    {
        "name": "spr_cls_rogue_melee_attack",
        "src": ROOT / "art_spec" / "act" / "spr_cls_rogue_melee_attack.png",
        "out": ROOT / "assets" / "units" / "spr_cls_rogue_melee_attack.png",
        "size": (3072, 5504),
        "labels": ["melee f0 (upper, lunge hold)", "melee f1 (lower, thrust+glint)"],
    },
]

## 拼图预览输出（reports/ 已 gitignore——视觉验收证据不入版本控制）
MONTAGE: Path = ROOT / "reports" / "act2_shots" / "batch2_montage_4x.png"

## 拼图收集（process_job 填充）
_montage_items: list[tuple[str, Image.Image, list[str]]] = []


def process_job(job: dict[str, object]) -> bool:
    """单件处理：横切分割两帧 → 抠图 → 统一缩放布局 → 竖排 → 实证 → 落盘。

    参数 job：任务项（name/src/out/size/labels）
    返回：true = 全部断言通过且已落盘
    """
    name: str = str(job["name"])
    src: Path = job["src"]  # type: ignore[assignment]
    out: Path = job["out"]  # type: ignore[assignment]
    size: tuple[int, int] = job["size"]  # type: ignore[assignment]
    labels: list[str] = job["labels"]  # type: ignore[assignment]
    print("== %s ==" % out.relative_to(ROOT))
    rgb = pipe.load_rgb(src, size)
    split = pipe.find_split(rgb, "v")
    top = pipe.cutout_white(rgb[:split])
    bottom = pipe.cutout_white(rgb[split:])
    bboxes = [pipe.alpha_bbox(top), pipe.alpha_bbox(bottom)]
    for tag, frame_rgba, bbox in (("上帧", top, bboxes[0]), ("下帧", bottom, bboxes[1])):
        print("  %s 主体 bbox=%s 尺寸 %dx%d" % (tag, bbox,
                bbox[2] - bbox[0] + 1, bbox[3] - bbox[1] + 1))
        facing, note = pipe.estimate_facing(frame_rgba)
        print("  %s 朝向估计：%s（%s）——原样导入不翻转" % (tag, facing, note))
    scale = pipe.unified_scale(bboxes)
    print("  统一缩放比 %.5f（脚底基线 y=%d、水平居中、边距 %dpx）" % (
            scale, pipe.GROUND_Y, pipe.EDGE_MARGIN))
    frames = [pipe.fit_into_frame(top, scale), pipe.fit_into_frame(bottom, scale)]
    strip = pipe.stack_strip(frames)
    refs = [(rgb[:split], bboxes[0], scale), (rgb[split:], bboxes[1], scale)]
    ok = pipe.sample_check(name, strip, (pipe.FRAME, pipe.FRAME * 2), refs)
    if not ok:
        print("  [跳过落盘] 实证未全过——保留库内现有件")
        return False
    strip.save(out)
    print("  已落盘 %s" % out)
    _montage_items.append((name, strip, labels))
    return True


def main() -> int:
    """入口：三件处理 + 拼图落盘。

    参数：无
    返回：0 = 全部成功；1 = 任一失败（明细见 stdout）
    """
    all_ok = True
    for job in JOBS:
        all_ok = process_job(job) and all_ok
    if _montage_items:
        MONTAGE.parent.mkdir(parents=True, exist_ok=True)
        pipe.preview_montage(_montage_items, MONTAGE, zoom=4)
    print("== 结果：%s ==" % ("全部通过" if all_ok else "存在实证失败项（见上）"))
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
