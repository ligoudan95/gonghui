#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批 2 源图探测（临时产物——不入版本控制，用后删）。
探测三张 3072x5504 源图的：中部水平空白带、上下帧主体 bbox、白色孔洞
（alpha<1 且不触边界的连通域）、盗贼淡蓝刀光的 mn 分布与连通性。
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT: Path = Path(__file__).resolve().parent.parent.parent  # DEMO/
ACT: Path = ROOT / "art_spec" / "act"
SOURCES: list[str] = [
    "spr_cls_warrior_idle.png",
    "spr_cls_mage_melee_attack.png",
    "spr_cls_rogue_melee_attack.png",
]
WHITE_LO: int = 235
WHITE_HI: int = 250
SPLIT_ZONE: tuple[float, float] = (0.35, 0.55)
SPLIT_BLANK_RATIO: float = 0.005


def find_vsplit(rgb: np.ndarray) -> int:
    h, w = rgb.shape[:2]
    nonwhite = rgb.min(axis=2) < WHITE_LO
    row_counts = nonwhite.sum(axis=1)
    lo, hi = int(h * SPLIT_ZONE[0]), int(h * SPLIT_ZONE[1])
    thresh = max(1, int(w * SPLIT_BLANK_RATIO))
    blank = np.where(row_counts[lo:hi] <= thresh)[0] + lo
    if len(blank) == 0:
        raise ValueError("no blank band")
    runs: list[tuple[int, int]] = []
    start = prev = int(blank[0])
    for c in blank[1:]:
        c = int(c)
        if c == prev + 1:
            prev = c
        else:
            runs.append((start, prev))
            start = prev = c
    runs.append((start, prev))
    s, e = max(runs, key=lambda r: r[1] - r[0])
    return (s + e) // 2


def alpha_of(rgb: np.ndarray) -> np.ndarray:
    mn = rgb.min(axis=2).astype(np.float32)
    return np.clip((WHITE_HI - mn) / (WHITE_HI - WHITE_LO), 0.0, 1.0)


def main() -> None:
    for name in SOURCES:
        path: Path = ACT / name
        im = Image.open(path).convert("RGB")
        rgb = np.asarray(im)
        h, w = rgb.shape[:2]
        print("== %s %dx%d ==" % (name, w, h))
        try:
            split = find_vsplit(rgb)
        except ValueError as exc:
            print("  分割失败：%s" % exc)
            continue
        print("  vsplit 行 y=%d（%.1f%%）" % (split, split * 100.0 / h))
        for tag, seg in (("上帧", rgb[:split]), ("下帧", rgb[split:])):
            alpha = alpha_of(seg)
            solid = alpha > 0.5
            rows = np.where(solid.any(axis=1))[0]
            cols = np.where(solid.any(axis=0))[0]
            bbox = (int(cols[0]), int(rows[0]), int(cols[-1]), int(rows[-1]))
            bw, bh = bbox[2] - bbox[0] + 1, bbox[3] - bbox[1] + 1
            # 孔洞候选：alpha<1 连通域，不触段边界
            cand = (alpha < 1.0).astype(np.uint8)
            count, labels, stats, _ = cv2.connectedComponentsWithStats(cand, 8)
            holes = []
            for i in range(1, count):
                x, y, bw2, bh2, area = stats[i]
                touches = x == 0 or y == 0 or x + bw2 >= seg.shape[1] or y + bh2 >= seg.shape[0]
                if not touches and area > 500:
                    mask = labels == i
                    mn_seg = seg.min(axis=2)
                    mn_vals = mn_seg[mask]
                    # 域内 mn 分布：纯白(>=250)/羽化(235-250)/彩色(<235)
                    pure = float((mn_vals >= 250).mean())
                    semi = float(((mn_vals >= 235) & (mn_vals < 250)).mean())
                    color = float((mn_vals < 235).mean())
                    mean_rgb = seg[mask].mean(axis=0)
                    holes.append((int(area), round(pure, 2), round(semi, 2),
                            round(color, 2), [round(float(v)) for v in mean_rgb]))
            holes.sort(reverse=True)
            print("  %s bbox=%s %dx%d 覆盖率%.3f 孔洞域(面积>500): %d 个" % (
                tag, bbox, bw, bh, float(solid.mean()), len(holes)))
            for hh in holes[:6]:
                print("    面积=%d 纯白占比%.2f 羽化%.2f 彩色%.2f 均值RGB=%s" % hh)
            # 半透明总量
            semi_total = float(((alpha > 0) & (alpha < 1)).mean())
            print("    半透明像素占比 %.4f" % semi_total)


if __name__ == "__main__":
    main()
