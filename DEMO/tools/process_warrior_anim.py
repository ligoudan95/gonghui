#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""战士待机锚点 + 近战两帧动作资源处理脚本（M6 美术替换·批 1）。

职责（同 id 原位替换，零改表）：
  1. art_spec/act/spr_cls_warrior_melee_attack.png（5504x3072 纯白底，
     左右并排两帧：左=蓄力、右=挥砍带月牙弧光）→ 列白像素统计自适应
     分割两帧 → 白底转 alpha + 孔洞填充 → 统一缩放脚底对齐 → 竖排
     128x256（上=帧0 蓄力、下=帧1 挥砍）→ 替换 assets/units/
     spr_cls_warrior_melee_attack.png
  2. art_spec/角色参考/anchor_spr_cls_warrior.png（3392x5056 纯白底，
     单帧待机站姿）→ 白底转 alpha + 孔洞填充 → 缩放 128x128 → 竖排
     2 帧 128x256（帧 1 = 帧 0 上移 1px 浮动——占位 idle 先例同款形态；
     【用户拍板 2026-10-07】单帧 anchor 图出 2 帧满足 V-M6-anim-geometry
     idle 规格带 [2,4]）→ 替换 assets/units/spr_cls_warrior_idle.png

处理要点（05 图标组返工事故教训——像素实证断言，杜绝 BGR/alpha 想当然）：
  - 白底软键：alpha = clip((WHITE_HI - min(R,G,B)) / (WHITE_HI - WHITE_LO))
    （mn<=235 全不透明、mn>=250 全透明、间线性羽化）
  - 孔洞填充：主体内部大面积纯白（白盔甲/高光/特效光，实测右帧纯白占
    主体 47%）会被白键抠穿——不接触图像边界的白色连通域整体回填
    alpha=1（接触边界的才是真背景）
  - 两帧分割：列非白像素统计找中部垂直空白带（列主体像素 <= 高*0.5%
    的连续段），取带中点；断言带位于宽度 35%-55%（防呆，不硬编码）
  - 布局：Lanczos 等比缩放、两帧统一 scale（大小一致感）、主体 bbox
    底边（含脚下浅灰椭圆阴影）对齐脚底基线 y=123、水平居中、四周留边
    5px；朝向按原图原样导入不翻转（视觉效果留给用户判断）
  - 像素实证（退出码把关）：尺寸/RGBA 模式 / 四角背景 alpha==0 /
    主体内部点 alpha==255 / 高饱和点源图-输出逐通道色差 <35（BGR 对调
    必炸）/ 半透明过渡像素占比 0.2%-15%（太少硬边、太多发糊）

用法：python tools/process_warrior_anim.py（工作目录任意，路径按脚本
位置解析；生成后需 godot --headless --import 重导入方可运行时加载）
"""
from __future__ import annotations

import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

## DEMO 工程根（脚本位于 DEMO/tools/）
ROOT: Path = Path(__file__).resolve().parent.parent

## 源图 / 输出（同 id 原位替换）
SRC_MELEE: Path = ROOT / "art_spec" / "act" / "spr_cls_warrior_melee_attack.png"
SRC_IDLE: Path = ROOT / "art_spec" / "角色参考" / "anchor_spr_cls_warrior.png"
OUT_MELEE: Path = ROOT / "assets" / "units" / "spr_cls_warrior_melee_attack.png"
OUT_IDLE: Path = ROOT / "assets" / "units" / "spr_cls_warrior_idle.png"

## 源图预期尺寸（防呆——图源换代先改此处再跑）
SRC_MELEE_SIZE: tuple[int, int] = (5504, 3072)
SRC_IDLE_SIZE: tuple[int, int] = (3392, 5056)

## 帧边长（M6 规格：宽 128、高 = 帧数x128，同 SpriteResolver.ANIM_FRAME_SIZE）
FRAME: int = 128
## 帧内四周留边（px）
EDGE_MARGIN: int = 5
## 脚底基线（主体 bbox 底边落位 y；脚下阴影随主体保留）
GROUND_Y: int = FRAME - 1 - EDGE_MARGIN

## 白底软键阈值：min(R,G,B) <= WHITE_LO 全不透明、>= WHITE_HI 全透明
WHITE_LO: int = 235
WHITE_HI: int = 250

## 分割带搜索区（宽度占比——防呆断言窗口）
SPLIT_ZONE: tuple[float, float] = (0.35, 0.55)
## 空白列判定：该列非白像素数 <= 高 * SPLIT_BLANK_RATIO
SPLIT_BLANK_RATIO: float = 0.005


def load_rgb(path: Path, expect_size: tuple[int, int]) -> np.ndarray:
    """读源图并断言尺寸（RGB ndarray HxWx3）。

    参数 path：图路径；expect_size：(宽, 高) 预期
    返回：RGB ndarray；失败抛异常（main 捕获计败）
    """
    im = Image.open(path).convert("RGB")
    if im.size != expect_size:
        raise ValueError("源图尺寸 %sx%s != 预期 %sx%s（%s）" % (*im.size, *expect_size, path))
    return np.asarray(im)


def cutout_white(rgb: np.ndarray) -> np.ndarray:
    """白底转 RGBA：软键 alpha + 孔洞填充（主体内部白色连通域回填）。

    参数 rgb：HxWx3 RGB ndarray
    返回：HxWx4 uint8 RGBA
    """
    h, w = rgb.shape[:2]
    mn = rgb.min(axis=2).astype(np.float32)
    alpha = np.clip((WHITE_HI - mn) / (WHITE_HI - WHITE_LO), 0.0, 1.0)

    # 孔洞填充：alpha<1 候选域连通域标记，不接触图像边界的连通域 = 主体
    # 内部白区（白盔甲/高光/特效光），整体回填 alpha=1（原色保留——内部
    # 高光显白即正确）；接触边界的连通域 = 真背景，维持软键
    cand = (alpha < 1.0).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(cand, 8)
    fill_mask = np.zeros((h, w), dtype=bool)
    for i in range(1, count):
        x, y, bw, bh, _area = stats[i]
        touches_edge = x == 0 or y == 0 or x + bw >= w or y + bh >= h
        if not touches_edge:
            fill_mask |= labels == i
    alpha[fill_mask] = 1.0

    out = np.dstack([rgb, np.round(alpha * 255.0).astype(np.uint8)])
    return out


def alpha_bbox(rgba: np.ndarray) -> tuple[int, int, int, int]:
    """alpha>0.5 二值化主体包围盒（含脚下阴影——阴影亮度低全不透明）。

    参数 rgba：HxWx4
    返回：(c0, r0, c1, r1) 闭区间；空主体抛异常
    """
    solid = rgba[:, :, 3] > 127
    if not solid.any():
        raise ValueError("主体为空（alpha 全透明）")
    rows = np.where(solid.any(axis=1))[0]
    cols = np.where(solid.any(axis=0))[0]
    return int(cols[0]), int(rows[0]), int(cols[-1]), int(rows[-1])


def find_split(rgb: np.ndarray) -> int:
    """两帧分割线：列非白像素统计找中部空白带中点（自适应，非硬编码）。

    参数 rgb：全图 RGB
    返回：分割列 x（左帧 [0, split)、右帧 [split, w)）
    """
    h, w = rgb.shape[:2]
    nonwhite = rgb.min(axis=2) < WHITE_LO
    col_counts = nonwhite.sum(axis=0)
    lo, hi = int(w * SPLIT_ZONE[0]), int(w * SPLIT_ZONE[1])
    thresh = max(1, int(h * SPLIT_BLANK_RATIO))
    blank = np.where(col_counts[lo:hi] <= thresh)[0] + lo
    if len(blank) == 0:
        raise ValueError("中部 %.0f%%-%.0f%% 未找到空白带（阈值 %d px/列）" % (
            SPLIT_ZONE[0] * 100, SPLIT_ZONE[1] * 100, thresh))
    # 取最长连续段（防噪声碎片），段中点为分割线
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
    print("  空白带：列 %d-%d（宽 %d，位于 %.1f%%-%.1f%%）→ 分割线 %d" % (
        s, e, e - s + 1, s * 100.0 / w, e * 100.0 / w, (s + e) // 2))
    return (s + e) // 2


def fit_into_frame(rgba: np.ndarray, scale: float) -> Image.Image:
    """主体 bbox 等比缩放 + 脚底基线对齐 + 水平居中落位 128x128 帧。

    参数 rgba：源 RGBA；scale：统一缩放比（两帧一致保证大小一致感）
    返回：128x128 RGBA PIL Image
    """
    c0, r0, c1, r1 = alpha_bbox(rgba)
    sub = rgba[r0:r1 + 1, c0:c1 + 1]
    src_h, src_w = sub.shape[:2]
    dst_w = max(1, int(round(src_w * scale)))
    dst_h = max(1, int(round(src_h * scale)))
    resized = Image.fromarray(sub, "RGBA").resize((dst_w, dst_h), Image.LANCZOS)
    # 脚底基线对齐（主体 bbox 底边贴 GROUND_Y）+ 水平居中
    pos_x = (FRAME - dst_w) // 2
    pos_y = GROUND_Y - dst_h + 1
    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    frame.paste(resized, (pos_x, pos_y), resized)
    return frame


def unified_scale(bboxes: list[tuple[int, int, int, int]]) -> float:
    """多帧统一缩放比：最大主体宽/高同时落入 (帧宽-2x边距) 框。

    参数 bboxes：各帧主体 bbox 列表
    返回：scale（两帧一致——大小一致感单源）
    """
    max_w = max(c1 - c0 + 1 for c0, _r0, c1, _r1 in bboxes)
    max_h = max(r1 - r0 + 1 for _c0, r0, _c1, r1 in bboxes)
    avail = FRAME - 2 * EDGE_MARGIN
    return min(avail / max_w, avail / max_h)


def sample_check(name: str, out: Image.Image, expect: tuple[int, int],
        src_ref: tuple[np.ndarray, tuple[int, int, int, int], float] | None) -> bool:
    """像素实证（05 事故教训）：尺寸/背景 alpha/主体实心/色序/过渡带。

    参数 name：件名；out：输出图；expect：预期 (宽, 高)；
        src_ref：(源 RGB, 源主体 bbox, fit scale)——高饱和点源-出对照
    返回：true = 全部断言通过（明细打印 stdout）
    """
    ok = True
    arr = np.asarray(out)

    def fail(msg: str) -> None:
        nonlocal ok
        ok = False
        print("  [实证失败] %s" % msg)

    if out.size != expect or out.mode != "RGBA":
        fail("尺寸/模式 %s %s != 预期 %s RGBA" % (out.size, out.mode, expect))
        return ok
    print("  尺寸/模式：%sx%s RGBA ✓" % out.size)

    # 帧数按 128 分段逐段验四角背景透明
    frames_h = expect[1] // FRAME
    for f in range(frames_h):
        y0 = f * FRAME
        for cx, cy in ((2, y0 + 2), (expect[0] - 3, y0 + 2), (2, y0 + FRAME - 3), (expect[0] - 3, y0 + FRAME - 3)):
            a = int(arr[cy, cx, 3])
            if a != 0:
                fail("帧%d 角点 (%d,%d) alpha=%d != 0" % (f, cx, cy, a))
            else:
                print("  帧%d 背景角 (%d,%d) RGBA=%s ✓" % (f, cx, cy, tuple(int(v) for v in arr[cy, cx])))

    # 主体实心点：alpha 域内取「帧中线附近最高 alpha 点」断言全不透明
    alpha = arr[:, :, 3]
    ys, xs = np.where(alpha > 0)
    if len(xs) == 0:
        fail("主体为空（全透明）")
        return ok
    mid_band = (ys >= expect[1] // 2 - 40) & (ys <= expect[1] // 2 + 40)
    if mid_band.any():
        idx = np.where(mid_band)[0]
        best = idx[np.argmax(alpha[ys[idx], xs[idx]])]
        bx, by = int(xs[best]), int(ys[best])
        px = tuple(int(v) for v in arr[by, bx])
        if px[3] != 255:
            fail("主体内部点 (%d,%d) alpha=%d != 255" % (bx, by, px[3]))
        else:
            print("  主体实心点 (%d,%d) RGBA=%s ✓" % (bx, by, px))
    # 主体占比（非空帧区）合理性：1%-90%
    for f in range(frames_h):
        seg = alpha[f * FRAME:(f + 1) * FRAME]
        cover = float((seg > 0).mean())
        if not (0.01 <= cover <= 0.90):
            fail("帧%d 主体覆盖 %.3f 越界 (0.01, 0.90)" % (f, cover))
        else:
            print("  帧%d 主体覆盖率 %.3f ✓" % (f, cover))

    # 半透明过渡带占比（羽化合理性）
    semi = float(((alpha > 0) & (alpha < 255)).mean())
    if not (0.002 <= semi <= 0.15):
        fail("半透明过渡占比 %.4f 越界 (0.002, 0.15)——太少硬边/太多发糊" % semi)
    else:
        print("  半透明过渡占比 %.4f ✓" % semi)

    # BGR 对调检查：主体 4x4 大块区域均值对照（大块均值在 LANCZOS 缩放下
    # 稳定；BGR 对调时 R↔B 互换必炸；单像素极值点缩放后落位偏差会误报）
    if src_ref is not None:
        src_rgb, (c0, r0, c1, r1), scale = src_ref
        sub = src_rgb[r0:r1 + 1, c0:c1 + 1]
        sub_mn = sub.min(axis=2)
        src_h, src_w = sub.shape[:2]
        dst_w = max(1, int(round(src_w * scale)))
        dst_h = max(1, int(round(src_h * scale)))
        pos_x = (FRAME - dst_w) // 2
        pos_y = GROUND_Y - dst_h + 1
        passed = 0
        cells = 0
        worst = 0.0
        worst_desc = ""
        for gy in range(4):
            for gx in range(4):
                ys0, ys1 = int(src_h * gy / 4), int(src_h * (gy + 1) / 4)
                xs0, xs1 = int(src_w * gx / 4), int(src_w * (gx + 1) / 4)
                cell = sub[ys0:ys1, xs0:xs1]
                cell_mn = sub_mn[ys0:ys1, xs0:xs1]
                src_opaque = cell[cell_mn < WHITE_HI]
                if src_opaque.shape[0] < 200:
                    continue  # 该块主体占比过低（人物轮廓外）——跳过不计
                src_px = src_opaque.mean(axis=0)
                # 映射到输出帧 0 区域（同 fit_into_frame 布局公式；越界裁剪）
                ox0 = max(0, pos_x + int(round(xs0 * scale)))
                ox1 = max(1, min(FRAME, pos_x + int(round(xs1 * scale))))
                oy0 = max(0, pos_y + int(round(ys0 * scale)))
                oy1 = max(1, min(FRAME, pos_y + int(round(ys1 * scale))))
                seg = arr[oy0:oy1, ox0:ox1]
                seg_op = seg[seg[:, :, 3] > 0][:, :3]
                if seg_op.shape[0] < 20:
                    continue
                out_px = seg_op.mean(axis=0)
                diff = max(abs(float(out_px[i]) - float(src_px[i])) for i in range(3))
                cells += 1
                if diff < 35.0:
                    passed += 1
                if diff > worst:
                    worst = diff
                    worst_desc = "块(%d,%d) 源 RGB=%s 出 RGB=%s" % (gx, gy,
                        [round(float(v), 1) for v in src_px], [round(float(v), 1) for v in out_px])
        if cells == 0 or passed < max(1, cells // 2):
            fail("大块色序对照：通过 %d/%d 块（需过半）——最差 %s（BGR 对调/色彩漂移嫌疑）" % (
                passed, cells, worst_desc))
        else:
            print("  大块色序对照：通过 %d/%d 块（逐通道差<35；最差 %.1f——%s）✓" % (
                passed, cells, worst, worst_desc))
    return ok


def main() -> int:
    """入口：两件资源生成 + 实证 + 落盘。

    参数：无（路径常量单源）
    返回：0 = 全部成功；1 = 任一失败（明细见 stdout）
    """
    ok = True

    # ---- 件 1：近战两帧（分割 → 抠图 → 统一缩放 → 竖排）----
    print("== 件 1：%s ==" % OUT_MELEE.relative_to(ROOT))
    melee_rgb = load_rgb(SRC_MELEE, SRC_MELEE_SIZE)
    split = find_split(melee_rgb)
    left = cutout_white(melee_rgb[:, :split])
    right = cutout_white(melee_rgb[:, split:])
    bboxes = [alpha_bbox(left), alpha_bbox(right)]
    print("  左帧(蓄力) 主体 bbox=%s 尺寸 %dx%d" % (bboxes[0], bboxes[0][2] - bboxes[0][0] + 1, bboxes[0][3] - bboxes[0][1] + 1))
    print("  右帧(挥砍) 主体 bbox(全图系)=%s 尺寸 %dx%d" % (bboxes[1], bboxes[1][2] - bboxes[1][0] + 1, bboxes[1][3] - bboxes[1][1] + 1))
    scale = unified_scale(bboxes)
    print("  统一缩放比 %.5f（脚底基线 y=%d、水平居中、边距 %dpx）" % (scale, GROUND_Y, EDGE_MARGIN))
    frame0 = fit_into_frame(left, scale)
    frame1 = fit_into_frame(right, scale)
    strip = Image.new("RGBA", (FRAME, FRAME * 2), (0, 0, 0, 0))
    strip.paste(frame0, (0, 0), frame0)   # 上 = 帧0 蓄力（原图左帧）
    strip.paste(frame1, (0, FRAME), frame1)  # 下 = 帧1 挥砍（原图右帧）
    left_ref = (melee_rgb[:, :split], bboxes[0], scale)
    ok = sample_check("melee_attack", strip, (FRAME, FRAME * 2), left_ref) and ok
    strip.save(OUT_MELEE)
    print("  已落盘 %s" % OUT_MELEE)

    # ---- 件 2：待机锚点（2 帧竖条——帧 1 = 帧 0 上移 1px 浮动）----
    print("== 件 2：%s ==" % OUT_IDLE.relative_to(ROOT))
    idle_rgb = load_rgb(SRC_IDLE, SRC_IDLE_SIZE)
    idle_rgba = cutout_white(idle_rgb)
    idle_bbox = alpha_bbox(idle_rgba)
    print("  主体 bbox=%s 尺寸 %dx%d" % (idle_bbox, idle_bbox[2] - idle_bbox[0] + 1, idle_bbox[3] - idle_bbox[1] + 1))
    idle_scale = unified_scale([idle_bbox])
    print("  缩放比 %.5f（脚底基线 y=%d、水平居中、边距 %dpx）" % (idle_scale, GROUND_Y, EDGE_MARGIN))
    idle_frame = fit_into_frame(idle_rgba, idle_scale)
    idle_strip = Image.new("RGBA", (FRAME, FRAME * 2), (0, 0, 0, 0))
    idle_strip.paste(idle_frame, (0, 0), idle_frame)              # 帧 0 = 原位
    shifted = idle_frame.crop((0, 1, FRAME, FRAME))                # 帧 1 = 上移 1px（裁顶 1 行）
    idle_strip.paste(shifted, (0, FRAME), shifted)                 # 贴帧 1 顶（底行留空）
    idle_ref = (idle_rgb, idle_bbox, idle_scale)
    ok = sample_check("idle", idle_strip, (FRAME, FRAME * 2), idle_ref) and ok
    # 结构断言：帧 1 逐行 == 帧 0 下一行（上移 1px 定义），帧 1 底行全透明
    idle_arr = np.asarray(idle_strip)
    if not np.array_equal(idle_arr[FRAME:FRAME * 2 - 1], idle_arr[1:FRAME]):
        ok = False
        print("  [实证失败] 帧 1 非 帧 0 上移 1px（逐行对比不一致）")
    elif idle_arr[FRAME * 2 - 1].any():
        ok = False
        print("  [实证失败] 帧 1 底行应全透明")
    else:
        print("  帧 1 = 帧 0 上移 1px 逐行一致 + 底行全透明 ✓")
    idle_strip.save(OUT_IDLE)
    print("  已落盘 %s" % OUT_IDLE)

    print("== 结果：%s ==" % ("全部通过" if ok else "存在实证失败项（见上）"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
