#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AI 生图提示词全集解析器（Gemini 生图工作台配套）。

职责：
  解析 DEMO/art_spec/风格指导/AI生图提示词全集.md，提取 116 件正式素材 + 9 张单位锚图
  的提示词与元数据，生成浏览器可直接 <script src> 引入的 assets_data.js。

用法（在本文件所在目录执行）：
  python extract_prompts.py            # 默认相对路径解析仓库内全集文件
  python extract_prompts.py <全集md路径> [-o <输出js路径>]

特性：
  - 仅 Python3 标准库；UTF-8 全程正确处理（含中文路径）
  - 幂等：同一输入恒定产出同一字节内容（JSON 键序固定、缩进固定）
  - 解析失败的件明确报错列出（宁报勿漏），任何缺项以非零退出码结束
"""

import argparse
import json
import re
import sys
from pathlib import Path

# 期望对账口径（全集「本全集对账」节）
EXPECTED_ITEM_COUNT = 116
EXPECTED_ANCHOR_COUNT = 9

# 件条目标题：### 资源id（中文名）——中文名可含嵌套括号（贪婪匹配到最后一层）
RE_ITEM_HEADER = re.compile(r"^###\s+([a-z0-9_]+)（(.+)）\s*$")
# 锚图条目标题：### 单位id 单位名（单位设定卡与锚图）——单位名可含括号
RE_ANCHOR_HEADER = re.compile(r"^###\s+([a-z0-9_]+)\s+(.+?)（单位设定卡与锚图）\s*$")
# 组节标题：## 01 背景组（6 件）→ 组号 + 组名（去「组」尾缀）
RE_GROUP_HEADER = re.compile(r"^##\s+(\d{2})\s+(.+?)组（")
# 总表数据行：| 资源 id | 中文名 | 组 | 尺寸·帧带 | 优先级 |
RE_SUMMARY_ROW = re.compile(r"^\|\s*([a-z0-9_]+)\s*\|\s*([^|]+?)\s*\|\s*(\d{2}[^|]*?)\s*\|\s*([^|]*?)\s*\|\s*(P\d[^|]*?)\s*\|\s*$")
# 条目内字段行
RE_FIELD_SPEC = re.compile(r"^-\s*目标规格：(.+)$")
RE_FIELD_POST = re.compile(r"^-\s*出图后处理：(.+)$")
RE_FIELD_POSITIVE = re.compile(r"^-\s*正向提示词（完整版，直接复制）：\s*$")
RE_FIELD_NEGATIVE = re.compile(r"^-\s*负面提示词（完整版，直接复制）：\s*$")
RE_FIELD_ANCHOR_PROMPT = re.compile(r"^-\s*锚图提示词（生产辅助件[^：]*）：\s*$")
RE_FIELD_UNIT_CARD = re.compile(r"^-\s*设定卡（同人同装锚定源）：(.+)$")
RE_FIELD_ROUTE = re.compile(r"^-\s*主用/备用路由：(.+)$")
RE_CN_REF = re.compile(r"^\s*中文参考：(.+)$")
RE_CODE_OPEN = re.compile(r"^```(text)?\s*$")


def read_lines(md_path: Path) -> list:
    """读取全集文件并按行拆分（统一 UTF-8，容忍 BOM）。

    参数：md_path——全集 md 的绝对路径
    返回：去行尾换行的行列表
    """
    with open(md_path, "r", encoding="utf-8-sig") as fh:
        return [line.rstrip("\r\n") for line in fh]


def parse_summary_table(lines: list) -> dict:
    """解析头部「全量总表（116 件）」为 id→元数据映射。

    参数：lines——全集行列表
    返回：{资源id: {"name_cn":…, "group_full":…, "size":…, "priority":…}}
    """
    summary: dict = {}
    in_table = False
    for line in lines:
        if line.startswith("## 全量总表"):
            in_table = True
            continue
        if in_table:
            if line.startswith("## "):  # 进入下一主节，总表结束
                break
            match = RE_SUMMARY_ROW.match(line)
            if match:
                res_id, name_cn, group_full, size, priority = match.groups()
                summary[res_id] = {
                    "name_cn": name_cn.strip(),
                    "group_full": group_full.strip(),
                    "size": size.strip(),
                    "priority": priority.strip(),
                }
    return summary


def split_group_name(group_full: str) -> tuple:
    """把总表组列（如「04 单位动作」）拆为组号与组名。

    参数：group_full——总表组列原文
    返回：(组号, 组名)
    """
    match = re.match(r"^(\d{2})\s+(.+)$", group_full)
    if not match:
        raise ValueError("总表组列格式异常: %r" % group_full)
    return match.group(1), match.group(2)


def extract_code_block(lines: list, start: int) -> tuple:
    """从 start 行之后提取第一个代码块内容。

    参数：lines——全集行列表；start——字段行（如「正向提示词…」）的下标
    返回：(代码块合并文本, 代码块结束后的下一行下标)
    """
    idx = start + 1
    # 跳过空行寻找围栏开头
    while idx < len(lines) and not lines[idx].strip():
        idx += 1
    if idx >= len(lines) or not RE_CODE_OPEN.match(lines[idx].strip()):
        return "", idx
    idx += 1
    block: list = []
    while idx < len(lines) and lines[idx].strip() != "```":
        block.append(lines[idx])
        idx += 1
    if idx >= len(lines):
        return "", idx  # 围栏未闭合
    return "\n".join(block).strip(), idx + 1


def find_cn_ref(lines: list, start: int) -> tuple:
    """从 start 行之后寻找最近的「中文参考：」行。

    参数：lines——全集行列表；start——起始下标（代码块结束后）
    返回：(中文参考内容, 是否找到)
    """
    idx = start
    while idx < len(lines):
        line = lines[idx]
        if RE_CN_REF.match(line):
            return RE_CN_REF.match(line).group(1).strip(), True
        if line.startswith("### ") or line.startswith("## "):
            break  # 越界进入下一节
        idx += 1
    return "", False


def parse_items(lines: list, summary: dict) -> tuple:
    """逐节解析件条目与锚图条目。

    参数：lines——全集行列表；summary——总表映射
    返回：(件列表, 锚图列表, 错误列表)
    """
    items: list = []
    anchors: list = []
    errors: list = []
    current_group_id = ""
    current_group_name = ""
    idx = 0
    total = len(lines)
    while idx < total:
        line = lines[idx]
        group_match = RE_GROUP_HEADER.match(line)
        if group_match:
            current_group_id, current_group_name = group_match.group(1), group_match.group(2)
            idx += 1
            continue
        anchor_match = RE_ANCHOR_HEADER.match(line)
        if anchor_match:
            anchor, idx = parse_anchor_entry(lines, idx, anchor_match, current_group_id)
            anchors.append(anchor)
            continue
        item_match = RE_ITEM_HEADER.match(line)
        if item_match and current_group_id:
            item, idx, item_errors = parse_item_entry(
                lines, idx, item_match, current_group_id, current_group_name, summary
            )
            items.append(item)
            errors.extend(item_errors)
            continue
        idx += 1
    return items, anchors, errors


def parse_item_entry(lines: list, start: int, header_match: re.match,
                     group_id: str, group_name: str, summary: dict) -> tuple:
    """解析单个件条目（### 资源id（中文名） 至下一节之间）。

    参数：lines——全集行列表；start——标题行下标；header_match——标题正则结果；
         group_id/group_name——当前所属组；summary——总表映射（对账用）
    返回：(条目 dict, 结束下标, 本条错误列表)
    """
    res_id, name_cn = header_match.group(1), header_match.group(2)
    spec = ""
    post_process = ""
    prompt_en = ""
    prompt_cn = ""
    negative_en = ""
    negative_cn = ""
    idx = start + 1
    total = len(lines)
    while idx < total:
        line = lines[idx]
        if line.startswith("### ") or line.startswith("## ") or line.startswith("---"):
            break
        match = RE_FIELD_SPEC.match(line)
        if match:
            spec = match.group(1).strip()
            idx += 1
            continue
        match = RE_FIELD_POST.match(line)
        if match:
            post_process = match.group(1).strip()
            idx += 1
            continue
        if RE_FIELD_POSITIVE.match(line):
            prompt_en, after = extract_code_block(lines, idx)
            prompt_cn, found = find_cn_ref(lines, after)
            if not found:
                prompt_cn = ""
            idx = after
            continue
        if RE_FIELD_NEGATIVE.match(line):
            negative_en, after = extract_code_block(lines, idx)
            negative_cn, found = find_cn_ref(lines, after)
            if not found:
                negative_cn = ""
            idx = after
            continue
        idx += 1
    # 与总表对账
    table_meta = summary.get(res_id)
    priority = table_meta["priority"] if table_meta else ""
    if table_meta is None:
        errors = ["件 %s 不在头部总表中（或总表缺失该行）" % res_id]
    elif table_meta["name_cn"] != name_cn:
        errors = ["件 %s 中文名不一致：条目 %r vs 总表 %r" % (res_id, name_cn, table_meta["name_cn"])]
    else:
        errors = []
    # 缺项校验（宁报勿漏）
    for label, value in (("目标规格", spec), ("出图后处理", post_process),
                         ("正向英文", prompt_en), ("正向中文", prompt_cn),
                         ("负面英文", negative_en), ("负面中文", negative_cn)):
        if not value:
            errors.append("件 %s 缺少字段「%s」" % (res_id, label))
    item = {
        "id": res_id,
        "name_cn": name_cn,
        "group_id": group_id,
        "group_name": group_name,
        "priority": priority,
        "spec": spec,
        "post_process": post_process,
        "prompt_en": prompt_en,
        "prompt_cn": prompt_cn,
        "negative_en": negative_en,
        "negative_cn": negative_cn,
        "is_anchor": False,
        "unit_id": None,
    }
    return item, idx, errors


def parse_anchor_entry(lines: list, start: int, header_match: re.match, group_id: str) -> tuple:
    """解析单个锚图条目（### 单位id 单位名（单位设定卡与锚图））。

    参数：lines——全集行列表；start——标题行下标；header_match——标题正则结果；
         group_id——当前所属组（04）
    返回：(锚图 dict, 结束下标)
    """
    unit_id, unit_name = header_match.group(1), header_match.group(2)
    unit_card = ""
    route = ""
    prompt_en = ""
    prompt_cn = ""
    idx = start + 1
    total = len(lines)
    while idx < total:
        line = lines[idx]
        if line.startswith("### ") or line.startswith("## ") or line.startswith("---"):
            break
        match = RE_FIELD_UNIT_CARD.match(line)
        if match:
            unit_card = match.group(1).strip()
            idx += 1
            continue
        match = RE_FIELD_ROUTE.match(line)
        if match:
            route = match.group(1).strip()
            idx += 1
            continue
        if RE_FIELD_ANCHOR_PROMPT.match(line):
            prompt_en, after = extract_code_block(lines, idx)
            prompt_cn, found = find_cn_ref(lines, after)
            if not found:
                prompt_cn = ""
            idx = after
            continue
        idx += 1
    anchor = {
        "id": "anchor_%s" % unit_id,
        "name_cn": "%s·锚图（生产辅助件·非入库）" % unit_name,
        "group_id": group_id,
        "group_name": "锚图",
        "priority": "P1 单位动作",
        "spec": unit_card,
        "post_process": ("单帧全身立绘（透明底）；对照设定卡确认定稿后，同单位 6 个动作件均以此为"
                         "img2img 参考图（idle 首帧=锚图常态站姿）。%s" % ("主用/备用路由：" + route if route else "")),
        "prompt_en": prompt_en,
        "prompt_cn": prompt_cn,
        "negative_en": "",  # 锚图小节无负面串，后续以 04 组通用负面基串回填
        "negative_cn": "",
        "is_anchor": True,
        "unit_id": unit_id,
    }
    return anchor, idx


def validate(items: list, anchors: list, summary: dict) -> list:
    """全局对账：件数、锚图数、总表双向一致、锚图字段完整。

    参数：items——件列表；anchors——锚图列表；summary——总表映射
    返回：错误列表（空 = 通过）
    """
    errors: list = []
    if len(items) != EXPECTED_ITEM_COUNT:
        errors.append("件数对账失败：解析 %d 件，期望 %d 件" % (len(items), EXPECTED_ITEM_COUNT))
    if len(anchors) != EXPECTED_ANCHOR_COUNT:
        errors.append("锚图数对账失败：解析 %d 张，期望 %d 张" % (len(anchors), EXPECTED_ANCHOR_COUNT))
    # 总表 ↔ 条目 双向
    item_ids = set(it["id"] for it in items)
    table_ids = set(summary.keys())
    only_in_items = sorted(item_ids - table_ids)
    only_in_table = sorted(table_ids - item_ids)
    if only_in_items:
        errors.append("条目有而总表无：%s" % ", ".join(only_in_items))
    if only_in_table:
        errors.append("总表有而条目无：%s" % ", ".join(only_in_table))
    # id 重复
    seen: set = set()
    for entry in items + anchors:
        if entry["id"] in seen:
            errors.append("资源 id 重复：%s" % entry["id"])
        seen.add(entry["id"])
    # 锚图必备字段
    for anchor in anchors:
        for label, value in (("锚图英文", anchor["prompt_en"]), ("锚图中文", anchor["prompt_cn"]),
                             ("设定卡", anchor["spec"])):
            if not value:
                errors.append("锚图 %s 缺少字段「%s」" % (anchor["id"], label))
    return errors


def build_output(items: list, anchors: list, summary: dict, md_path: Path, line_count: int) -> dict:
    """组装将写入 assets_data.js 的数据结构。

    参数：items/anchors——解析结果；summary——总表映射；md_path/line_count——溯源信息
    返回：输出 dict
    """
    # 组目录：以总表组列顺序为准（01→09）
    groups: list = []
    group_order: list = []
    group_map: dict = {}
    for res_id in summary:  # dict 保持插入序（Python 3.7+），与总表行序一致
        group_full = summary[res_id]["group_full"]
        if group_full not in group_map:
            gid, gname = split_group_name(group_full)
            group_map[group_full] = True
            group_order.append({"id": gid, "name": gname, "full": group_full, "count": 0})
    group_count_map = {g["id"]: g for g in group_order}
    for item in items:
        if item["group_id"] in group_count_map:
            group_count_map[item["group_id"]]["count"] += 1
    # 04 组第一件（spr_cls_warrior_idle）的负面串 = 全卷通用负面基串，回填锚图
    base_negative_en = ""
    base_negative_cn = ""
    for item in items:
        if item["group_id"] == "04" and item["negative_en"]:
            base_negative_en = item["negative_en"]
            base_negative_cn = item["negative_cn"]
            break
    for anchor in anchors:
        anchor["negative_en"] = base_negative_en
        anchor["negative_cn"] = base_negative_cn
    return {
        "source": md_path.as_posix(),
        "source_lines": line_count,
        "expected_counts": {"items": EXPECTED_ITEM_COUNT, "anchors": EXPECTED_ANCHOR_COUNT},
        "groups": group_order,
        "items": items + anchors,  # 正式件在前、锚图殿后（工具端按 is_anchor 区隔显示）
    }


def write_js(data: dict, out_path: Path) -> None:
    """把数据序列化为 assets_data.js（幂等输出）。

    参数：data——输出 dict；out_path——目标 js 路径
    """
    payload = json.dumps(data, ensure_ascii=False, indent=2)
    content = (
        "// 本文件由 extract_prompts.py 自动生成，请勿手改；重跑脚本可再生成\n"
        "// 数据源: DEMO/art_spec/风格指导/AI生图提示词全集.md（116 件正式素材 + 9 张单位锚图）\n"
        "window.ASSETS_DATA = %s;\n" % payload
    )
    with open(out_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(content)


def main() -> int:
    """脚本入口：解析 → 校验 → 写出，输出对账报告。

    返回：进程退出码（0 = 全部通过）
    """
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")  # Windows GBK 控制台兜底
    script_dir = Path(__file__).resolve().parent
    default_md = script_dir.parents[1] / "art_spec" / "风格指导" / "AI生图提示词全集.md"
    parser = argparse.ArgumentParser(description="解析 AI 生图提示词全集 → assets_data.js")
    parser.add_argument("md_path", nargs="?", default=str(default_md), help="全集 md 路径")
    parser.add_argument("-o", "--output", default=str(script_dir / "assets_data.js"), help="输出 js 路径")
    args = parser.parse_args()

    md_path = Path(args.md_path)
    out_path = Path(args.output)
    if not md_path.is_file():
        print("[错误] 找不到全集文件：%s" % md_path)
        return 2
    lines = read_lines(md_path)
    summary = parse_summary_table(lines)
    if not summary:
        print("[错误] 头部总表解析为空，请检查全集结构")
        return 2
    items, anchors, errors = parse_items(lines, summary)
    errors.extend(validate(items, anchors, summary))

    print("=" * 56)
    print("AI 生图提示词全集解析对账")
    print("=" * 56)
    print("数据源：%s（%d 行）" % (md_path, len(lines)))
    print("总表条目：%d 行" % len(summary))
    print("解析正式件：%d / 期望 %d" % (len(items), EXPECTED_ITEM_COUNT))
    print("解析锚图：%d / 期望 %d" % (len(anchors), EXPECTED_ANCHOR_COUNT))
    group_stat: dict = {}
    for item in items:
        key = "%s %s" % (item["group_id"], item["group_name"])
        group_stat[key] = group_stat.get(key, 0) + 1
    for key in sorted(group_stat):
        print("  %s：%d 件" % (key, group_stat[key]))
    print("锚图归属单位：%s" % ", ".join(a["unit_id"] for a in anchors))
    if errors:
        print("-" * 56)
        print("[失败] 共 %d 处问题（宁报勿漏，逐项修复后重跑）：" % len(errors))
        for err in errors:
            print("  - %s" % err)
        return 1
    data = build_output(items, anchors, summary, md_path, len(lines))
    write_js(data, out_path)
    print("-" * 56)
    print("[通过] 已写出：%s（%d 件 + %d 锚图 = %d 条目）"
          % (out_path, len(items), len(anchors), len(data["items"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
