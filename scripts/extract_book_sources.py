"""从用户提供的 APK 中提取并规范化旧版阅读书源。

该脚本只读取 APK 的 assets/bookSource.json，不反编译或复制应用代码。
输出是可审计的 MNovel Legacy 规则目录，默认禁用所有未经检测的第三方源。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import zipfile
from collections import Counter
from copy import deepcopy
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

ASSET_PATH = "assets/bookSource.json"
REQUIRED_SEARCH_RULES = (
    "ruleSearchUrl",
    "ruleSearchList",
    "ruleSearchName",
    "ruleSearchNoteUrl",
)
REQUIRED_READER_RULES = (
    "ruleChapterList",
    "ruleChapterName",
    "ruleContentUrl",
    "ruleBookContent",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path, help="包含 assets/bookSource.json 的 APK")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("data/book_sources"),
        help="输出目录，默认 data/book_sources",
    )
    parser.add_argument(
        "--mobile-output",
        type=Path,
        help="可选：写入不含执行规则的 Flutter 书源目录",
    )
    return parser.parse_args()


def read_asset(apk: Path) -> tuple[bytes, list[dict[str, Any]]]:
    with zipfile.ZipFile(apk) as archive:
        raw = archive.read(ASSET_PATH)
    decoded = json.loads(raw.decode("utf-8-sig"))
    if not isinstance(decoded, list):
        raise ValueError(f"{ASSET_PATH} 顶层必须是数组")
    return raw, [dict(item) for item in decoded]


def resolve_references(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    resolved: list[dict[str, Any]] = []
    for index, item in enumerate(items):
        reference = item.get("$ref")
        if not reference:
            resolved.append(deepcopy(item))
            continue
        match = re.fullmatch(r"\$\[(\d+)]", str(reference))
        if not match:
            resolved.append(
                {
                    "_invalid_reference": str(reference),
                    "_original_index": index,
                }
            )
            continue
        target_index = int(match.group(1))
        if target_index >= index or target_index >= len(resolved):
            resolved.append(
                {
                    "_invalid_reference": str(reference),
                    "_original_index": index,
                }
            )
            continue
        copied = deepcopy(resolved[target_index])
        copied["_reference"] = str(reference)
        resolved.append(copied)
    return resolved


def clean_text(value: Any) -> str:
    return str(value or "").strip()


def is_public_http_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme in {"http", "https"} and bool(parsed.hostname)


def stable_id(item: dict[str, Any], index: int) -> str:
    identity = "\n".join(
        (
            clean_text(item.get("bookSourceUrl")).lower(),
            clean_text(item.get("bookSourceName")),
            clean_text(item.get("ruleSearchUrl")),
            str(index),
        )
    )
    digest = hashlib.sha256(identity.encode("utf-8")).hexdigest()[:16]
    return f"legacy-{digest}"


def classify(item: dict[str, Any]) -> tuple[str, str]:
    if item.get("_invalid_reference"):
        return "invalid_reference", "引用目标无效"

    source_type = clean_text(item.get("bookSourceType")).upper()
    if source_type in {"AUDIO", "1"}:
        return "audio", "音频书源不进入小说聚合"

    base_url = clean_text(item.get("bookSourceUrl"))
    if not is_public_http_url(base_url):
        return "invalid_url", "书源地址不是有效 HTTP(S) URL"

    if clean_text(item.get("loginUrl")):
        return "login_required", "配置包含登录入口，默认关闭"

    rule_values = [
        clean_text(value)
        for key, value in item.items()
        if key.startswith("rule")
    ]
    if any(
        marker in value.lower()
        for value in rule_values
        for marker in (
            "<js>",
            "@js:",
            "@put:",
            "@get:",
            "@xpath:",
            "webview",
            "cookie",
        )
    ):
        return "script_required", "包含脚本、状态变量、WebView 或 Cookie 规则"

    missing = [
        field
        for field in (*REQUIRED_SEARCH_RULES, *REQUIRED_READER_RULES)
        if not clean_text(item.get(field))
    ]
    if missing:
        return "incomplete", f"缺少关键规则：{', '.join(missing)}"
    return "compatible_core", "可由受限兼容子集尝试执行"


def normalize_item(item: dict[str, Any], index: int) -> dict[str, Any]:
    compatibility, reason = classify(item)
    rules = {
        key: value
        for key, value in item.items()
        if key.startswith("rule") and value not in (None, "")
    }
    return {
        "id": stable_id(item, index),
        "name": clean_text(item.get("bookSourceName")) or f"未命名书源 {index + 1}",
        "base_url": clean_text(item.get("bookSourceUrl")),
        "group": clean_text(item.get("bookSourceGroup")) or "未分组",
        "source_type": clean_text(item.get("bookSourceType")) or "NOVEL",
        "enabled": False,
        "original_enabled": bool(item.get("enable", True)),
        "priority": int(item.get("weight") or 0),
        "serial_number": int(item.get("serialNumber") or 0),
        "user_agent": clean_text(item.get("httpUserAgent")),
        "login_url": clean_text(item.get("loginUrl")),
        "compatibility": compatibility,
        "compatibility_reason": reason,
        "built_in": True,
        "origin": "apk:assets/bookSource.json",
        "original_index": index,
        "reference": clean_text(item.get("_reference")),
        "rules": rules,
    }


def build_audit(
    apk: Path,
    raw: bytes,
    sources: list[dict[str, Any]],
) -> dict[str, Any]:
    compatibility = Counter(source["compatibility"] for source in sources)
    groups = Counter(source["group"] for source in sources)
    duplicate_hosts = Counter(
        urlparse(source["base_url"]).hostname or ""
        for source in sources
        if source["base_url"]
    )
    return {
        "schema_version": 1,
        "generated_at": datetime.now(UTC).isoformat(),
        "apk": {
            "path": str(apk.resolve()),
            "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
            "asset": ASSET_PATH,
            "asset_sha256": hashlib.sha256(raw).hexdigest(),
            "asset_bytes": len(raw),
        },
        "total": len(sources),
        "compatibility": dict(sorted(compatibility.items())),
        "groups": dict(groups.most_common()),
        "duplicate_hosts": {
            host: count
            for host, count in duplicate_hosts.most_common()
            if host and count > 1
        },
    }


def audit_markdown(audit: dict[str, Any]) -> str:
    lines = [
        "# APK 书源审计报告",
        "",
        f"- 原始记录：{audit['total']}",
        f"- APK SHA-256：`{audit['apk']['sha256']}`",
        f"- 资源 SHA-256：`{audit['apk']['asset_sha256']}`",
        f"- 资源大小：{audit['apk']['asset_bytes']} bytes",
        "",
        "## 兼容性分类",
        "",
        "| 分类 | 数量 |",
        "| --- | ---: |",
    ]
    lines.extend(
        f"| `{name}` | {count} |"
        for name, count in audit["compatibility"].items()
    )
    lines.extend(
        [
            "",
            "说明：所有 APK 第三方源首次均保持关闭；只有完整链路检测通过后才应启用。",
            "",
            "## 静态分析限制",
            "",
            "APK 使用 360 加固，静态 DEX 只包含壳代码。兼容实现依据完整规则资产和可观察行为重写，未复制 APK 应用代码。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    args = parse_args()
    raw, items = read_asset(args.apk)
    resolved = resolve_references(items)
    sources = [normalize_item(item, index) for index, item in enumerate(resolved)]
    audit = build_audit(args.apk, raw, sources)

    args.output.mkdir(parents=True, exist_ok=True)
    catalog = {
        "schema_version": 1,
        "source": audit["apk"],
        "sources": sources,
    }
    (args.output / "legacy_sources.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (args.output / "audit.json").write_text(
        json.dumps(audit, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (args.output / "audit.md").write_text(
        audit_markdown(audit),
        encoding="utf-8",
    )
    if args.mobile_output:
        args.mobile_output.parent.mkdir(parents=True, exist_ok=True)
        mobile_sources = [
            {
                "id": source["id"],
                "name": source["name"],
                "description": source["compatibility_reason"],
                "endpoint": source["base_url"],
                "group": source["group"],
                "compatibility": source["compatibility"],
                "compatibility_reason": source["compatibility_reason"],
                "enabled": False,
                "health": (
                    "unknown"
                    if source["compatibility"] == "compatible_core"
                    else "configurationRequired"
                ),
                "priority": source["priority"],
                "built_in": True,
                "kind": "legacy",
            }
            for source in sources
        ]
        args.mobile_output.write_text(
            json.dumps(
                {"schema_version": 1, "sources": mobile_sources},
                ensure_ascii=False,
                separators=(",", ":"),
            ),
            encoding="utf-8",
        )
    print(json.dumps(audit["compatibility"], ensure_ascii=False))
    print(f"已生成 {len(sources)} 条书源：{args.output.resolve()}")


if __name__ == "__main__":
    main()
