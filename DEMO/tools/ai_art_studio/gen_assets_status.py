#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""入库状态快照生成器（AI 生图工作台配套）。

职责：
  汇总游戏工程侧的资产入库实况，生成 119 件（规格书 00-10 组总量）的
  id → 入库状态映射，写出浏览器可直接 <script src> 引入的 assets_status.js
  （供工作台左栏「入库状态」列只读展示；独立于 assets_data.js 生成链，
  重跑 extract_prompts.py 不会覆写本文件，反之亦然）。

数据源（三路合成）：
  1) DEMO/data/assets/registry.tres —— 键清单 = 在册资产位（当前 118 键，
     其中 ui_main_theme 为 UI 主题资源（.tres 非生图件），不属 119 件口径，排除）
  2) DEMO/art_spec/风格指导/art_source_log.md —— 「一、AI 生图分区」已登记行
     = 正式件单源（占位件按该表维护规则第 3 条不登记）
  3) 特殊状态注记（本文件 SPECIAL_STATUS 字典，随用户拍板/入库批次更新）

状态值集合（最终形态，UI 端配短标签）：
  已正式入库 / 已正式（待重生成替换）/ 占位（待生成）
  / 占位（错件拦截·待重导出）/ 未入册

口径：119 件 = 规格书 00-10 组总量
  = registry(118) − ui_main_theme(1) + 字体 2 件(font_cn_body/font_cn_title，未入册)
  其中 116 件为全集生图件（119 − bg_guild_hall − 字体 2），与工作台条目口径见 README。

对账（任一失败 → 非零退出，不写出文件；宁报勿漏）：
  - registry 键数 == 118（EXPECTED_REGISTRY_COUNT）
  - 状态映射总量 == 119（EXPECTED_TOTAL）
  - AI 分区登记 id 全部在册
  - 特殊注记 id 全部在 119 口径内，且与登记/占位基础事实一致
  - 字体 2 件确未入册（已入册则须同步更新本脚本口径）
  - assets_data.js 存在时：工作台 116 生图件全部被状态映射覆盖

用法（在本文件所在目录执行）：
  python gen_assets_status.py
"""

import json
import re
import sys
from datetime import datetime
from pathlib import Path

# 期望对账口径（当前批次常量；规格书总量或 registry 结构变更时同步维护）
EXPECTED_REGISTRY_COUNT = 118   # registry.tres 键数（含 ui_main_theme）
EXPECTED_TOTAL = 119            # 规格书 00-10 组总量

# registry 中不属 119 件生图口径的键（UI 主题资源：project.godot [gui] 直引消费，登记仅为反查闭合）
EXCLUDE_REGISTRY_KEYS = {"ui_main_theme"}

# 规格书 10_字体组 2 件：ttf/otf 无法程序造占位、不走 AI 生图、registry 无键 → 未入册
UNREGISTERED_IDS = {"font_cn_body", "font_cn_title"}

# 状态值常量（输出与 UI 短标签映射的唯一依据）
STATUS_FORMAL = "已正式入库"
STATUS_FORMAL_REPLACE = "已正式（待重生成替换）"
STATUS_PLACEHOLDER = "占位（待生成）"
STATUS_BLOCKED = "占位（错件拦截·待重导出）"
STATUS_UNREGISTERED = "未入册"

# 状态值展示序（counts 键序稳定，输出幂等可读）
STATUS_ORDER = [STATUS_FORMAL, STATUS_FORMAL_REPLACE, STATUS_BLOCKED,
                STATUS_PLACEHOLDER, STATUS_UNREGISTERED]

# 特殊状态注记（优先于默认规则；随用户拍板/批次流转维护，来源见各行注释）
SPECIAL_STATUS = {
    # 2026-10-03 用户重导出协会屏源图并审核确认，随批 3 后半快速通道正式入库
    #（tools/process_bg_batch.gd 同 id 覆盖占位；MD5 已核 ≠ bg_guild_hall 错件防复发）。
    # art_source_log AI 分区尚未登记——本注记为留档补登前的过渡覆盖，docs 侧补登后可移除
    #（届时默认规则即给出「已正式入库」，状态值不变）。
    "bg_association_hall": STATUS_FORMAL,
}

# registry 键行：&"资源id": "res://…（Dictionary[StringName, String] 条目）
RE_REGISTRY_KEY = re.compile(r'^&"([a-z0-9_]+)":\s*"res://')
# AI 分区表数据行首列：| 资源id | 中文名 | …（表头「资源 id」与分隔行 |---| 均不匹配资源 id 形态）
RE_LOG_ROW = re.compile(r"^\|\s*([a-z0-9_]+)\s*\|")


def read_lines(file_path: Path) -> list:
    """读取文本文件并按行拆分（统一 UTF-8，容忍 BOM）。

    参数：file_path——目标文件绝对路径
    返回：去行尾换行的行列表
    """
    with open(file_path, "r", encoding="utf-8-sig") as fh:
        return [line.rstrip("\r\n") for line in fh]


def parse_registry_keys(tres_path: Path) -> list:
    """解析 registry.tres 提取全部资源键清单。

    参数：tres_path——registry.tres 路径
    返回：资源 id 列表（文件行序）
    """
    keys: list = []
    for line in read_lines(tres_path):
        match = RE_REGISTRY_KEY.match(line.strip())
        if match:
            keys.append(match.group(1))
    return keys


def parse_ai_logged_ids(log_path: Path) -> list:
    """解析 art_source_log.md「一、AI 生图分区」表格的已登记资源 id。

    参数：log_path——art_source_log.md 路径
    返回：已登记正式件 id 列表（表行序）
    """
    ids: list = []
    in_section = False
    for line in read_lines(log_path):
        if line.startswith("## 一、AI 生图分区"):
            in_section = True
            continue
        if in_section:
            if line.startswith("## "):   # 进入下一主节（购买分区等），AI 分区结束
                break
            match = RE_LOG_ROW.match(line)
            if match:
                ids.append(match.group(1))
    return ids


def load_workbench_gen_ids(js_path: Path) -> set:
    """解析 assets_data.js 提取工作台 116 生图件 id（锚图剔除，对账衔接用）。

    参数：js_path——assets_data.js 路径
    返回：生图件 id 集合
    """
    text = js_path.read_text(encoding="utf-8-sig")
    marker = "window.ASSETS_DATA = "
    start = text.find(marker)
    if start < 0:
        raise ValueError("assets_data.js 结构异常：缺少 window.ASSETS_DATA 赋值")
    payload = text[start + len(marker):].strip()
    if payload.endswith(";"):
        payload = payload[:-1]
    data = json.loads(payload)
    return {it["id"] for it in data.get("items", []) if not it.get("is_anchor")}


def build_status(registry_ids: list, ai_logged_ids: list) -> dict:
    """按默认规则 + 特殊注记合成 119 件状态映射。

    参数：registry_ids——registry 键列表；ai_logged_ids——AI 分区已登记 id 列表
    返回：{资源id: 状态值}
    """
    registry_set = set(registry_ids)
    ai_logged_set = set(ai_logged_ids)
    coverage = (registry_set - EXCLUDE_REGISTRY_KEYS) | UNREGISTERED_IDS
    status: dict = {}
    for res_id in sorted(coverage):
        if res_id in SPECIAL_STATUS:
            status[res_id] = SPECIAL_STATUS[res_id]          # 特殊注记优先
        elif res_id in UNREGISTERED_IDS:
            status[res_id] = STATUS_UNREGISTERED             # 字体 2 件
        elif res_id in ai_logged_set:
            status[res_id] = STATUS_FORMAL                   # 在册 + 已留档 = 正式件
        else:
            status[res_id] = STATUS_PLACEHOLDER              # 在册未留档 = 占位件
    return status


def validate(registry_ids: list, ai_logged_ids: list, status: dict) -> list:
    """全局对账：口径总量、登记↔在册一致、特殊注记与基础事实相符、工作台衔接。

    参数：registry_ids/ai_logged_ids/status——解析与合成结果
    返回：错误列表（空 = 通过）
    """
    errors: list = []
    registry_set = set(registry_ids)
    ai_logged_set = set(ai_logged_ids)
    coverage = (registry_set - EXCLUDE_REGISTRY_KEYS) | UNREGISTERED_IDS

    if len(registry_ids) != EXPECTED_REGISTRY_COUNT:
        errors.append("registry 键数对账失败：解析 %d 键，期望 %d 键（口径变更须同步本脚本常量）"
                      % (len(registry_ids), EXPECTED_REGISTRY_COUNT))
    if len(status) != EXPECTED_TOTAL:
        errors.append("状态映射总量对账失败：合成 %d 件，期望 %d 件（实际口径 = registry %d − 排除 %d + 字体 %d）"
                      % (len(status), EXPECTED_TOTAL, len(registry_set), len(EXCLUDE_REGISTRY_KEYS), len(UNREGISTERED_IDS)))
    # AI 分区登记件必须在册（登记错表/解析错位防线）
    logged_not_in_registry = sorted(ai_logged_set - registry_set)
    if logged_not_in_registry:
        errors.append("AI 分区已登记但 registry 无键：%s" % ", ".join(logged_not_in_registry))
    # 特殊注记必须落在 119 口径内，且与登记/占位基础事实一致
    for res_id, value in SPECIAL_STATUS.items():
        if res_id not in coverage:
            errors.append("特殊注记 %s 不在 119 件口径内" % res_id)
        elif value == STATUS_FORMAL_REPLACE and res_id not in ai_logged_set:
            errors.append("特殊注记 %s 标「%s」但 AI 分区未登记（口径不符）" % (res_id, value))
        elif value == STATUS_BLOCKED and (res_id not in registry_set or res_id in ai_logged_set):
            errors.append("特殊注记 %s 标「%s」但基础事实不符（应为在册占位且未登记）" % (res_id, value))
    # 字体 2 件确未入册（已入册则口径须更新）
    font_registered = sorted(UNREGISTERED_IDS & registry_set)
    if font_registered:
        errors.append("字体件 %s 已出现在 registry——「未入册」口径过时，请更新本脚本" % ", ".join(font_registered))
    # 工作台 116 生图件衔接（assets_data.js 存在时）
    js_path = Path(__file__).resolve().parent / "assets_data.js"
    if js_path.is_file():
        try:
            gen_ids = load_workbench_gen_ids(js_path)
        except (ValueError, json.JSONDecodeError) as exc:
            errors.append("assets_data.js 解析失败：%s" % exc)
        else:
            uncovered = sorted(gen_ids - set(status))
            if uncovered:
                errors.append("工作台生图件未被状态映射覆盖：%s" % ", ".join(uncovered))
    return errors


def write_js(status: dict, registry_path: Path, log_path: Path, out_path: Path) -> dict:
    """把状态映射序列化为 assets_status.js（浏览器 <script src> 直引）。

    参数：status——状态映射；registry_path/log_path——两路数据源（溯源写入头部）；
         out_path——输出 js 路径
    返回：写出的数据 dict
    """
    now = datetime.now()
    generated_at = now.strftime("%Y-%m-%d %H:%M:%S")
    counts = {value: 0 for value in STATUS_ORDER}
    for value in status.values():
        counts[value] = counts.get(value, 0) + 1
    data = {
        "generated_at": generated_at,
        "source_registry": registry_path.as_posix(),
        "source_log": log_path.as_posix(),
        "expected_total": EXPECTED_TOTAL,
        "counts": counts,
        "status": {res_id: status[res_id] for res_id in sorted(status)},
    }
    payload = json.dumps(data, ensure_ascii=False, indent=2)
    header = (
        "// 本文件由 gen_assets_status.py 自动生成，请勿手改；重跑脚本可再生成（每次素材入库批后重跑一次，见 README）\n"
        "// 数据源: DEMO/data/assets/registry.tres（键清单=在册）+ DEMO/art_spec/风格指导/art_source_log.md（AI 分区已登记行=正式件单源）+ 脚本内特殊注记\n"
        "// 状态值: %s\n"
        "// 口径: %d 件 = 规格书 00-10 组总量（registry %d − ui_main_theme + 字体 2 件）；四套口径说明见 README\n"
        "// 生成时间: %s\n"
        % (" / ".join(STATUS_ORDER), EXPECTED_TOTAL, EXPECTED_REGISTRY_COUNT, generated_at)
    )
    content = header + "window.ASSETS_STATUS = %s;\n" % payload
    with open(out_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(content)
    return data


def main() -> int:
    """脚本入口：解析 → 合成 → 对账 → 写出，输出对账报告。

    返回：进程退出码（0 = 全部通过）
    """
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")  # Windows GBK 控制台兜底
    script_dir = Path(__file__).resolve().parent
    demo_root = script_dir.parents[1]
    registry_path = demo_root / "data" / "assets" / "registry.tres"
    log_path = demo_root / "art_spec" / "风格指导" / "art_source_log.md"
    out_path = script_dir / "assets_status.js"

    if not registry_path.is_file():
        print("[错误] 找不到 registry：%s" % registry_path)
        return 2
    if not log_path.is_file():
        print("[错误] 找不到来源留档表：%s" % log_path)
        return 2

    registry_ids = parse_registry_keys(registry_path)
    ai_logged_ids = parse_ai_logged_ids(log_path)
    status = build_status(registry_ids, ai_logged_ids)
    errors = validate(registry_ids, ai_logged_ids, status)

    print("=" * 56)
    print("入库状态快照生成对账（119 件口径）")
    print("=" * 56)
    print("registry：%s（%d 键，排除 %s）"
          % (registry_path.name, len(registry_ids), "/".join(sorted(EXCLUDE_REGISTRY_KEYS))))
    print("来源留档：%s（AI 分区已登记 %d 件）" % (log_path.name, len(ai_logged_ids)))
    print("特殊注记：%d 件（%s）" % (len(SPECIAL_STATUS), ", ".join(sorted(SPECIAL_STATUS))))
    print("AI 分区已登记：%s" % ", ".join(ai_logged_ids))
    if errors:
        print("-" * 56)
        print("[失败] 共 %d 处问题（宁报勿漏，逐项修复后重跑；未写出文件）：" % len(errors))
        for err in errors:
            print("  - %s" % err)
        return 1
    data = write_js(status, registry_path, log_path, out_path)
    print("-" * 56)
    for value in STATUS_ORDER:
        print("  %-14s：%3d 件" % (value, data["counts"].get(value, 0)))
    print("-" * 56)
    print("[通过] 已写出：%s（%d 件，生成时间 %s）" % (out_path, len(status), data["generated_at"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
