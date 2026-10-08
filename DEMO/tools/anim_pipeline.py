#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""单位动作竖条处理通用管线库（M6 美术替换·批 2 抽取泛化）。

从 tools/process_warrior_anim.py（批 1 先例）抽取的通用函数，参数化分割
方向（横切=上下两帧 / 纵切=左右两帧）；批 1 先例脚本保持不动（其整域孔洞
回填的最终态已定稿，重跑须产出相同结果——本库的逐像素回填与其行为不同，
故独立成库不复改先例）。

与先例的差异（批 2 需求驱动）：
  1. 孔洞回填改**逐像素**：候选连通域（不触图像边界）内，仅回填「中性
     白灰」像素（mn >= HOLE_WHITE_MN 且 max(R,G,B)-min(R,G,B) <=
     HOLE_NEUTRAL_DIFF）为 alpha=1；域内羽化带与**偏色半透明特效**（盗贼
     淡蓝刀光实测均值 RGB=[241,246,252]，mn=241 / 通道差=11）保持软键
     alpha——刀光不当孔洞误填充（任务红线）。
  2. 分割方向参数化：split="v" = 上下两帧（行白像素统计找中部水平空白
     带，批 2 三件 3072x5504 竖排源图）；split="h" = 左右两帧（列统计，
     批 1 同款）。
  3. 像素实证断言支持逐帧源图对照（先例只对照帧 0——批 2 两帧内容差异
     大，逐帧对照抓 BGR 对调/色彩漂移更严）。
  4. 新增朝向估计（estimate_facing）：头部质心偏移 / 质量左右不对称 /
     下半前缘伸展三指标投票——报告用（原样导入不翻转，朝向仅记录）。

用法：被 tools/process_anim_batch2.py 消费（本文件为库，不直接执行）。
"""
from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

## 帧边长（M6 规格：宽 128、高 = 帧数x128，同 SpriteResolver.ANIM_FRAME_SIZE）
FRAME: int = 128
## 帧内四周留边（px，批 1 同款口径）
EDGE_MARGIN: int = 5
## 脚底基线（主体 bbox 底边落位 y；脚下阴影随主体保留）
GROUND_Y: int = FRAME - 1 - EDGE_MARGIN

## 白底软键阈值：min(R,G,B) <= WHITE_LO 全不透明、>= WHITE_HI 全透明
WHITE_LO: int = 235
WHITE_HI: int = 250

## 孔洞回填逐像素判定（批 2：中性白灰才回填，偏色半透明特效不填）
## 依据：批 2 源图实测——盗贼淡蓝刀光孤立域均值 RGB=[241,246,252]（mn=241、
## 通道差=11）；白孔域（帽/白发/白衣）均值 RGB 各通道 248-254（通道差 <= 6）。
## 两簇间隔离带充分：mn >= 243 且通道差 <= 6 判白灰回填，刀光 (241, 246,
## 252) mn=241<243 且通道差=11>6 双重排除。
HOLE_WHITE_MN: int = 243
HOLE_NEUTRAL_DIFF: int = 6

## 分割带搜索区（分割轴占比——防呆断言窗口，两向通用）
SPLIT_ZONE: tuple[float, float] = (0.35, 0.55)
## 空白判定：该行/列非白像素数 <= 正交边长 * SPLIT_BLANK_RATIO
SPLIT_BLANK_RATIO: float = 0.005


def load_rgb(path: Path, expect_size: tuple[int, int]) -> np.ndarray:
    """读源图并断言尺寸（RGB ndarray HxWx3）。

    参数 path：图路径；expect_size：(宽, 高) 预期
    返回：RGB ndarray；失败抛异常（调用方捕获计败）
    """
    im = Image.open(path).convert("RGB")
    if im.size != expect_size:
        raise ValueError("源图尺寸 %sx%s != 预期 %sx%s（%s）" % (*im.size, *expect_size, path))
    return np.asarray(im)


def cutout_white(rgb: np.ndarray) -> np.ndarray:
    """白底转 RGBA：软键 alpha + 逐像素孔洞回填（中性白灰回填、偏色
    半透明特效保持软键——盗贼淡蓝刀光不误填）。

    参数 rgb：HxWx3 RGB ndarray
    返回：HxWx4 uint8 RGBA
    """
    h, w = rgb.shape[:2]
    mn_f = rgb.min(axis=2).astype(np.float32)
    alpha = np.clip((WHITE_HI - mn_f) / (WHITE_HI - WHITE_LO), 0.0, 1.0)

    # 孔洞候选：alpha<1 连通域；不接触图像边界的域 = 主体内部白区候选
    #（接触边界的 = 真背景软键带，绝不回填）；域内逐像素按中性白灰判据
    # 回填（白孔/白衣浅灰阴影 alpha=1 原色保留；淡蓝刀光等偏色半透明
    # 特效与轮廓羽化带保持软键 alpha）
    cand = (alpha < 1.0).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(cand, 8)
    mn = rgb.min(axis=2)
    diff = rgb.max(axis=2).astype(np.int16) - mn.astype(np.int16)
    fill_mask = np.zeros((h, w), dtype=bool)
    for i in range(1, count):
        x, y, bw, bh, _area = stats[i]
        touches_edge = x == 0 or y == 0 or x + bw >= w or y + bh >= h
        if touches_edge:
            continue
        region = labels == i
        neutral_white = (mn >= HOLE_WHITE_MN) & (diff <= HOLE_NEUTRAL_DIFF)
        fill_mask |= region & neutral_white
    alpha[fill_mask] = 1.0

    return np.dstack([rgb, np.round(alpha * 255.0).astype(np.uint8)])


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


def find_split(rgb: np.ndarray, axis: str) -> int:
    """两帧分割线：非白像素统计找中部空白带中点（自适应，非硬编码）。

    参数 rgb：全图 RGB；axis："v" = 上下两帧（行统计，返回分割行 y，
    上帧 [0, split) / 下帧 [split, h)）；"h" = 左右两帧（列统计，返回
    分割列 x，左帧 [0, split) / 右帧 [split, w)）——批 1 同款
    返回：分割线坐标
    """
    h, w = rgb.shape[:2]
    nonwhite = rgb.min(axis=2) < WHITE_LO
    if axis == "v":
        counts = nonwhite.sum(axis=1)
        total, span = h, w
    elif axis == "h":
        counts = nonwhite.sum(axis=0)
        total, span = w, h
    else:
        raise ValueError("axis 须为 'v'（上下帧）或 'h'（左右帧），收到 %r" % axis)
    lo, hi = int(total * SPLIT_ZONE[0]), int(total * SPLIT_ZONE[1])
    thresh = max(1, int(span * SPLIT_BLANK_RATIO))
    blank = np.where(counts[lo:hi] <= thresh)[0] + lo
    if len(blank) == 0:
        raise ValueError("中部 %.0f%%-%.0f%% 未找到空白带（阈值 %d px/%s，axis=%s）" % (
            SPLIT_ZONE[0] * 100, SPLIT_ZONE[1] * 100, thresh,
            "行" if axis == "v" else "列", axis))
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
    print("  空白带（%s）：%d-%d（宽 %d，位于 %.1f%%-%.1f%%）→ 分割线 %d" % (
        axis, s, e, e - s + 1, s * 100.0 / total, e * 100.0 / total, (s + e) // 2))
    return (s + e) // 2


def unified_scale(bboxes: list[tuple[int, int, int, int]]) -> float:
    """多帧统一缩放比：最大主体宽/高同时落入 (帧宽-2x边距) 框。

    参数 bboxes：各帧主体 bbox 列表
    返回：scale（两帧一致——大小一致感单源）
    """
    max_w = max(c1 - c0 + 1 for c0, _r0, c1, _r1 in bboxes)
    max_h = max(r1 - r0 + 1 for _c0, r0, _c1, r1 in bboxes)
    avail = FRAME - 2 * EDGE_MARGIN
    return min(avail / max_w, avail / max_h)


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


def stack_strip(frames: list[Image.Image]) -> Image.Image:
    """多帧竖排成竖条（帧 0 在顶——M6 动作竖条规格）。

    参数 frames：各帧 128x128 RGBA
    返回：128 x (128*帧数) RGBA 竖条
    """
    strip = Image.new("RGBA", (FRAME, FRAME * len(frames)), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        strip.paste(fr, (0, i * FRAME), fr)
    return strip


def sample_check(name: str, out: Image.Image, expect: tuple[int, int],
        src_refs: list[tuple[np.ndarray, tuple[int, int, int, int], float]] | None) -> bool:
    """像素实证（05 事故教训）：尺寸/背景 alpha/主体实心/色序/过渡带 +
    逐帧 bbox 合理性。src_refs 支持逐帧源图对照（帧 i 对照输出竖条第
    i 段——两帧内容差异大时比先例只对照帧 0 更严）。

    参数 name：件名；out：输出竖条；expect：预期 (宽, 高)；
        src_refs：逐帧 (源 RGB, 源主体 bbox, fit scale)——None 跳过色序对照
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
    frames_h = expect[1] // FRAME

    # 帧数按 128 分段逐段验四角背景透明
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

    # 逐帧主体覆盖率与 bbox 合理性（1%-90%；bbox 宽高 >= 帧宽 30%——人物
    # 立绘主体过小说明分割残片/空白帧混入）
    for f in range(frames_h):
        seg = alpha[f * FRAME:(f + 1) * FRAME]
        cover = float((seg > 0).mean())
        if not (0.01 <= cover <= 0.90):
            fail("帧%d 主体覆盖 %.3f 越界 (0.01, 0.90)" % (f, cover))
        else:
            print("  帧%d 主体覆盖率 %.3f ✓" % (f, cover))
        frows = np.where((seg > 0).any(axis=1))[0]
        fcols = np.where((seg > 0).any(axis=0))[0]
        bw = int(fcols[-1] - fcols[0] + 1)
        bh = int(frows[-1] - frows[0] + 1)
        if bw < FRAME * 0.3 or bh < FRAME * 0.3:
            fail("帧%d 主体 bbox %dx%d 过小（<30%% 帧——空白帧/残片嫌疑）" % (f, bw, bh))
        else:
            print("  帧%d 主体 bbox %dx%d ✓" % (f, bw, bh))

    # 半透明过渡带占比（羽化合理性）
    semi = float(((alpha > 0) & (alpha < 255)).mean())
    if not (0.002 <= semi <= 0.15):
        fail("半透明过渡占比 %.4f 越界 (0.002, 0.15)——太少硬边/太多发糊" % semi)
    else:
        print("  半透明过渡占比 %.4f ✓" % semi)

    # BGR 对调检查：逐帧主体 4x4 大块区域均值对照（大块均值在 LANCZOS 缩放
    # 下稳定；BGR 对调时 R↔B 互换必炸；单像素极值点缩放后落位偏差会误报）
    if src_refs is not None:
        if len(src_refs) != frames_h:
            fail("逐帧对照数 %d != 帧数 %d" % (len(src_refs), frames_h))
            return ok
        total_passed = 0
        total_cells = 0
        worst = 0.0
        worst_desc = ""
        for f, (src_rgb, (c0, r0, c1, r1), scale) in enumerate(src_refs):
            sub = src_rgb[r0:r1 + 1, c0:c1 + 1]
            sub_mn = sub.min(axis=2)
            src_h, src_w = sub.shape[:2]
            dst_w = max(1, int(round(src_w * scale)))
            dst_h = max(1, int(round(src_h * scale)))
            pos_x = (FRAME - dst_w) // 2
            pos_y = GROUND_Y - dst_h + 1
            passed = 0
            cells = 0
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
                    # 映射到输出竖条第 f 段（同 fit_into_frame 布局公式；越界裁剪）
                    ox0 = max(0, pos_x + int(round(xs0 * scale)))
                    ox1 = max(1, min(FRAME, pos_x + int(round(xs1 * scale))))
                    oy0 = max(0, f * FRAME + pos_y + int(round(ys0 * scale)))
                    oy1 = max(1, min((f + 1) * FRAME, f * FRAME + pos_y + int(round(ys1 * scale))))
                    seg = arr[oy0:oy1, ox0:ox1]
                    seg_op = seg[seg[:, :, 3] > 0][:, :3]
                    if seg_op.shape[0] < 20:
                        continue
                    out_px = seg_op.mean(axis=0)
                    diff = max(abs(float(out_px[i]) - float(src_px[i])) for i in range(3))
                    cells += 1
                    total_cells += 1
                    if diff < 35.0:
                        passed += 1
                        total_passed += 1
                    if diff > worst:
                        worst = diff
                        worst_desc = "帧%d 块(%d,%d) 源 RGB=%s 出 RGB=%s" % (f, gx, gy,
                            [round(float(v), 1) for v in src_px], [round(float(v), 1) for v in out_px])
            if cells == 0:
                fail("帧%d 大块色序对照：无有效对照块" % f)
        if total_cells == 0 or total_passed < max(1, total_cells // 2):
            fail("大块色序对照：通过 %d/%d 块（需过半）——最差 %s（BGR 对调/色彩漂移嫌疑）" % (
                total_passed, total_cells, worst_desc))
        else:
            print("  大块色序对照：通过 %d/%d 块（逐通道差<35；最差 %.1f——%s）✓" % (
                total_passed, total_cells, worst, worst_desc))
    return ok


def estimate_facing(rgba: np.ndarray) -> tuple[str, str]:
    """朝向启发式估计（报告用——原样导入不翻转，仅记录）。

    三指标投票（人物面朝侧的像素质量特征）：
      1. 头部质心偏移：bbox 顶部 22% 高度区质心 x 偏 bbox 中心（人物通常
         头部前倾/偏向面朝侧）
      2. 质量不对称：实心像素质心 x 偏 bbox 中心（前伸肢体/武器增重）
      3. 下半前缘伸展：bbox 下 40% 高度区，左/右实心边缘最远点距中心差
        （前倾突刺/挥击方向延伸）
    参数 rgba：源帧 RGBA
    返回：(朝向 "left"/"right"/"uncertain"，指标明细文本)
    """
    solid = rgba[:, :, 3] > 127
    c0, r0, c1, r1 = alpha_bbox(rgba)
    height = r1 - r0 + 1
    cx = (c0 + c1) / 2.0
    votes_l = 0
    votes_r = 0
    notes: list[str] = []

    # 指标 1：头部质心偏移（顶部 22%）
    head = solid[r0:r0 + int(height * 0.22), :]
    hcols = np.where(head.any(axis=0))[0]
    if len(hcols) > 0:
        head_cx = float(hcols.mean())
        d1 = head_cx - cx
        notes.append("头部质心偏移 %+.0fpx" % d1)
        if abs(d1) > (c1 - c0) * 0.02:
            votes_r += 1 if d1 > 0 else 0
            votes_l += 1 if d1 < 0 else 0

    # 指标 2：整体质量不对称
    mcols = np.where(solid.any(axis=0))[0]
    mrows = solid.sum(axis=0)
    mass_cx = float((mcols * mrows[mcols]).sum() / max(1, mrows[mcols].sum()))
    d2 = mass_cx - cx
    notes.append("质量质心偏移 %+.0fpx" % d2)
    if abs(d2) > (c1 - c0) * 0.02:
        votes_r += 1 if d2 > 0 else 0
        votes_l += 1 if d2 < 0 else 0

    # 指标 3：下半前缘伸展（底部 40%）
    lower = solid[r0 + int(height * 0.6):, :]
    lcols = np.where(lower.any(axis=0))[0]
    if len(lcols) > 0:
        reach_l = cx - float(lcols[0])
        reach_r = float(lcols[-1]) - cx
        d3 = reach_r - reach_l
        notes.append("下半前缘伸展差 %+.0fpx（右%+.0f/左%+.0f）" % (d3, reach_r, reach_l))
        if abs(d3) > (c1 - c0) * 0.03:
            votes_r += 1 if d3 > 0 else 0
            votes_l += 1 if d3 < 0 else 0

    if votes_l > votes_r:
        facing = "left"
    elif votes_r > votes_l:
        facing = "right"
    else:
        facing = "uncertain"
    return facing, "；".join(notes) + " → 票 左%d/右%d" % (votes_l, votes_r)


def preview_montage(items: list[tuple[str, Image.Image, list[str]]], out_path: Path,
        zoom: int = 4) -> None:
    """入库成品逐帧放大拼图（视觉验收证据）：每件一行（件名标题 + 各帧
    横排 4x NEAREST 放大 + 帧名标注——ASCII，PIL 内置位图字体无中文）。

    参数 items：(件名, 竖条 RGBA, 逐帧标签列表) 列表；out_path：输出路径；
        zoom：放大倍数
    返回：无（落盘 PNG）
    """
    pad = 14
    title_h = 20
    label_h = 18
    cell_w = FRAME * zoom + pad
    row_h = FRAME * 2 * zoom + title_h + label_h + pad
    board_w = cell_w * max(len(labels) for _n, _im, labels in items) + pad
    board = Image.new("RGBA", (board_w, row_h * len(items) + pad), (24, 24, 28, 255))
    draw = ImageDraw.Draw(board)
    y = pad
    for name, strip, labels in items:
        draw.text((pad, y), "%s" % name, fill=(230, 230, 230, 255))
        big = strip.resize((strip.size[0] * zoom, strip.size[1] * zoom), Image.NEAREST)
        for f, label in enumerate(labels):
            fx = pad + f * cell_w
            # 逐帧从竖条切段贴入（帧 i = 竖条第 i 个 128 段）
            seg = big.crop((0, f * FRAME * zoom, FRAME * zoom, (f + 1) * FRAME * zoom))
            board.paste(seg, (fx, y + title_h), seg)
            draw.text((fx, y + title_h + FRAME * 2 * zoom + 3), label,
                    fill=(160, 200, 255, 255))
            if f > 0:
                lx = fx - pad // 2
                draw.line([(lx, y + title_h), (lx, y + title_h + FRAME * 2 * zoom)],
                        fill=(90, 90, 110, 255), width=1)
        y += row_h
    board.save(out_path)
    print("  拼图预览已落盘 %s" % out_path)
