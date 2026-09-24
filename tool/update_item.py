"""根据当前 Dota 2 数据更新项目根目录的 item.json。

物品英文 ID 从 ``items.txt`` 中筛选，简体中文名称来自 Dota 2 官方
``datafeed/itemlist`` 接口。默认只收录仍可购买的商店物品，并额外保留
肉山奖励和共享树之祭祀等常用特殊物品。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


if os.name == "nt":
    # 保证 PowerShell、Codex 终端和重定向日志里的中文输出一致。
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_ITEMS_FILE = (
    PROJECT_ROOT / "vpk" / "pak01_dir" / "scripts" / "npc" / "items.txt"
)
DEFAULT_OUTPUT = PROJECT_ROOT / "item.json"
ITEM_LIST_URL = "https://www.dota2.com/datafeed/itemlist?language=schinese"

# 这些物品不能直接从商店购买，但仍属于常用的正式物品名称。
SPECIAL_ITEMS = (
    "item_aegis",
    "item_ultimate_scepter_roshan",
    "item_aghanims_shard_roshan",
    "item_cheese",
    "item_royale_with_cheese",
    "item_refresher_shard",
    "item_roshans_banner",
)

# 按相邻的普通物品插入，保持 item.json 容易人工浏览。
ITEMS_INSERTED_AFTER = {
    "item_ward_sentry": ("item_ward_observer",),
    "item_tango": ("item_tango_single",),
}

ITEM_NAME_RE = re.compile(r'^"(item_[a-z0-9_]+)"\s*$')
PROPERTY_RE = re.compile(r'^"([^"]+)"\s+"([^"]*)"\s*$')


class UpdateError(RuntimeError):
    """物品表无法安全更新时抛出。"""


@dataclass
class ItemDefinition:
    """items.txt 中一个顶层物品块里用于筛选的字段。"""

    name: str
    properties: Dict[str, str] = field(default_factory=dict)

    @property
    def is_active_shop_item(self) -> bool:
        if self.name.startswith("item_recipe_"):
            return False
        if self.properties.get("ItemPurchasable") == "0":
            return False
        if self.properties.get("IsObsolete") == "1":
            return False
        try:
            return int(self.properties.get("ItemCost", "0")) > 0
        except ValueError:
            return False


def strip_line_comment(line: str) -> str:
    """删除字符串外的 // 注释。"""
    in_string = False
    escaped = False
    index = 0
    while index < len(line):
        char = line[index]
        if escaped:
            escaped = False
        elif char == "\\" and in_string:
            escaped = True
        elif char == '"':
            in_string = not in_string
        elif not in_string and char == "/" and line[index : index + 2] == "//":
            return line[:index]
        index += 1
    return line


def brace_delta(line: str) -> int:
    """计算字符串外的大括号层级变化。"""
    in_string = False
    escaped = False
    delta = 0
    for char in line:
        if escaped:
            escaped = False
        elif char == "\\" and in_string:
            escaped = True
        elif char == '"':
            in_string = not in_string
        elif not in_string and char == "{":
            delta += 1
        elif not in_string and char == "}":
            delta -= 1
    return delta


def parse_item_definitions(path: Path) -> List[ItemDefinition]:
    """按原文件顺序解析 items.txt 的顶层物品定义。"""
    if not path.is_file():
        raise UpdateError(f"找不到物品定义文件：{path}")

    definitions: List[ItemDefinition] = []
    depth = 0
    pending_name: Optional[str] = None
    current: Optional[ItemDefinition] = None

    with path.open("r", encoding="utf-8-sig", errors="strict") as source:
        for raw_line in source:
            line = strip_line_comment(raw_line).strip()
            before_depth = depth

            if current is None and before_depth == 1:
                match = ITEM_NAME_RE.fullmatch(line)
                if match:
                    pending_name = match.group(1)

            line_delta = brace_delta(line)
            if (
                current is None
                and pending_name is not None
                and before_depth == 1
                and line_delta > 0
            ):
                current = ItemDefinition(pending_name)
                pending_name = None

            if current is not None and before_depth == 2:
                property_match = PROPERTY_RE.fullmatch(line)
                if property_match:
                    key, value = property_match.groups()
                    current.properties[key] = value

            depth += line_delta
            if depth < 0:
                raise UpdateError(f"items.txt 大括号不匹配：{path}")

            if current is not None and before_depth >= 2 and depth == 1:
                definitions.append(current)
                current = None

    if depth != 0 or current is not None:
        raise UpdateError(f"items.txt 结尾结构不完整：{path}")
    if len(definitions) < 100:
        raise UpdateError(
            f"只解析到 {len(definitions)} 个物品定义，拒绝覆盖 item.json"
        )
    return definitions


def fetch_chinese_names(url: str, timeout: float) -> Dict[str, str]:
    """从 Dota 2 官方接口取得内部 ID 到简体中文名的映射。"""
    request = Request(url, headers={"User-Agent": "DotaModTool-item-updater/1.0"})
    with urlopen(request, timeout=timeout) as response:
        payload = json.load(response)

    try:
        items = payload["result"]["data"]["itemabilities"]
    except (KeyError, TypeError) as exc:
        raise UpdateError("官方接口返回结构异常，拒绝覆盖 item.json") from exc

    names: Dict[str, str] = {}
    for item in items:
        if not isinstance(item, dict):
            continue
        name = item.get("name")
        chinese_name = item.get("name_loc")
        if isinstance(name, str) and isinstance(chinese_name, str) and chinese_name:
            names[name] = chinese_name

    if len(names) < 100:
        raise UpdateError(f"官方接口只返回 {len(names)} 个有效名称，拒绝更新")
    return names


def unique_in_order(names: Iterable[str]) -> List[str]:
    """按首次出现顺序去重。"""
    result: List[str] = []
    seen = set()
    for name in names:
        if name not in seen:
            seen.add(name)
            result.append(name)
    return result


def build_item_map(
    definitions: Iterable[ItemDefinition], localizations: Dict[str, str]
) -> Dict[str, str]:
    """生成最终的有序物品名称映射。"""
    names: List[str] = list(SPECIAL_ITEMS)
    active_count = 0

    for definition in definitions:
        if not definition.is_active_shop_item:
            continue
        active_count += 1
        names.append(definition.name)
        names.extend(ITEMS_INSERTED_AFTER.get(definition.name, ()))

    if active_count < 100:
        raise UpdateError(f"只筛选到 {active_count} 个有效商店物品，拒绝更新")

    names = unique_in_order(names)
    missing = [name for name in names if name not in localizations]
    if missing:
        details = "\n".join(f"  - {name}" for name in missing)
        raise UpdateError(f"官方中文数据缺少以下物品：\n{details}")

    return {name: localizations[name] for name in names}


def load_existing(path: Path) -> Dict[str, str]:
    """读取旧文件，用于统计差异；文件不存在时返回空映射。"""
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8-sig") as source:
        value = json.load(source)
    if not isinstance(value, dict):
        raise UpdateError(f"现有文件根节点不是 JSON 对象：{path}")
    return value


def write_json_atomic(path: Path, value: Dict[str, str]) -> None:
    """先写临时文件再替换，避免中途失败损坏旧文件。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as output:
            output.write(text)
        os.replace(str(temporary_path), str(path))
    finally:
        try:
            temporary_path.unlink()
        except FileNotFoundError:
            pass


def print_change_summary(old: Dict[str, str], new: Dict[str, str]) -> None:
    added = [name for name in new if name not in old]
    removed = [name for name in old if name not in new]
    renamed = [name for name in new if name in old and new[name] != old[name]]
    print(
        f"物品数：{len(old)} -> {len(new)}；"
        f"新增 {len(added)}，移除 {len(removed)}，译名更新 {len(renamed)}"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="使用 Dota 2 官方简体中文数据更新 item.json"
    )
    parser.add_argument(
        "--items-file",
        type=Path,
        default=DEFAULT_ITEMS_FILE,
        help=f"items.txt 路径（默认：{DEFAULT_ITEMS_FILE}）",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"输出 JSON 路径（默认：{DEFAULT_OUTPUT}）",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=30.0,
        help="官方接口请求超时秒数（默认：30）",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="只校验和显示差异，不写入文件",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        definitions = parse_item_definitions(args.items_file.resolve())
        localizations = fetch_chinese_names(ITEM_LIST_URL, args.timeout)
        new_items = build_item_map(definitions, localizations)
        output = args.output.resolve()
        old_items = load_existing(output)
        print_change_summary(old_items, new_items)

        if old_items == new_items:
            print(f"无需更新：{output}")
            return 0
        if args.dry_run:
            print(f"试运行完成，未写入：{output}")
            return 0

        write_json_atomic(output, new_items)
        print(f"更新完成：{output}")
        return 0
    except (UpdateError, OSError, HTTPError, URLError, json.JSONDecodeError) as exc:
        print(f"更新失败：{exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
