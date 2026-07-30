"""下载、规范化并合并 Legado 订阅书源。

输入文件可以包含编号、说明文字和多个 HTTP(S) 订阅地址。脚本只接收顶层为
数组且数组项包含 bookSourceUrl/bookSourceName 的响应，自动忽略登录响应等内容。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlparse
from urllib.request import Request, urlopen

URL_PATTERN = re.compile(r"https?://[^\s，,]+")
SEARCH_FIELDS = {
    "bookList": "ruleSearchList",
    "name": "ruleSearchName",
    "bookUrl": "ruleSearchNoteUrl",
    "author": "ruleSearchAuthor",
    "coverUrl": "ruleSearchCoverUrl",
    "intro": "ruleSearchIntroduce",
    "kind": "ruleSearchKind",
    "lastChapter": "ruleSearchLastChapter",
}
TOC_FIELDS = {
    "chapterList": "ruleChapterList",
    "chapterName": "ruleChapterName",
    "chapterUrl": "ruleChapterUrl",
}
CONTENT_FIELDS = {"content": "ruleBookContent"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("subscription_file", type=Path)
    parser.add_argument("--existing", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--mobile-output", type=Path, required=True)
    parser.add_argument("--timeout", type=float, default=30)
    return parser.parse_args()


def text(value: Any) -> str:
    return str(value or "").strip()


def integer(value: Any) -> int:
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def subscription_urls(path: Path) -> list[str]:
    content = path.read_text(encoding="utf-8-sig")
    return list(dict.fromkeys(URL_PATTERN.findall(content)))


def download_sources(url: str, timeout: float) -> list[dict[str, Any]]:
    request = Request(url, headers={"User-Agent": "MNovel-source-import/1.0"})
    with urlopen(request, timeout=timeout) as response:
        payload = json.loads(response.read().decode("utf-8-sig"))
    if not isinstance(payload, list):
        return []
    return [
        dict(item)
        for item in payload
        if isinstance(item, dict)
        and text(item.get("bookSourceUrl"))
        and text(item.get("bookSourceName"))
    ]


def public_base_url(value: str) -> str:
    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        return ""
    return value.rstrip("/")


def canonical_key(source: dict[str, Any]) -> str:
    parsed = urlparse(text(source.get("base_url")))
    host = (parsed.hostname or "").casefold()
    port = f":{parsed.port}" if parsed.port else ""
    path = (parsed.path or "").rstrip("/")
    return f"{parsed.scheme.casefold()}://{host}{port}{path}"


def source_id(base_url: str, name: str) -> str:
    identity = f"{base_url.casefold()}\n{name}".encode()
    return f"legado-{hashlib.sha256(identity).hexdigest()[:16]}"


def rule_map(item: dict[str, Any]) -> dict[str, Any]:
    rules: dict[str, Any] = {}
    search_url = item.get("searchUrl")
    if search_url not in (None, ""):
        rules["ruleSearchUrl"] = search_url
    for group_name, mapping in (
        ("ruleSearch", SEARCH_FIELDS),
        ("ruleToc", TOC_FIELDS),
        ("ruleContent", CONTENT_FIELDS),
    ):
        group = item.get(group_name)
        if not isinstance(group, dict):
            continue
        for source_name, target_name in mapping.items():
            if group.get(source_name) not in (None, ""):
                rules[target_name] = group[source_name]
    # 旧版平铺规则仍然存在于部分订阅中。
    for key, value in item.items():
        if key.startswith("rule") and not isinstance(value, dict):
            if value not in (None, ""):
                rules[key] = value
    header = item.get("header")
    if header not in (None, "", {}):
        rules["header"] = header
    return rules


def user_agent(item: dict[str, Any]) -> str:
    explicit = text(item.get("httpUserAgent"))
    if explicit:
        return explicit
    header = item.get("header")
    if isinstance(header, str):
        try:
            header = json.loads(header)
        except json.JSONDecodeError:
            header = {}
    if isinstance(header, dict):
        return text(header.get("User-Agent") or header.get("user-agent"))
    return ""


def compatibility(item: dict[str, Any], rules: dict[str, Any]) -> tuple[str, str]:
    if text(item.get("loginUrl")) or text(item.get("loginUi")):
        return "login_required", "配置包含登录或人工授权入口"
    serialized = json.dumps(item, ensure_ascii=False).casefold()
    if "webview" in serialized:
        return "webview_required", "规则依赖 WebView 验证"
    required = (
        "ruleSearchUrl",
        "ruleSearchList",
        "ruleSearchName",
        "ruleSearchNoteUrl",
    )
    missing = [field for field in required if rules.get(field) in (None, "")]
    if missing:
        return "incomplete", f"缺少搜索规则：{', '.join(missing)}"
    if any(marker in serialized for marker in ("@js:", "<js>", "@put:", "@get:")):
        return "script_required", "包含 JavaScript 或状态变量，由 JVM 兼容层尝试执行"
    return "compatible_core", "具备完整搜索规则"


def normalize(item: dict[str, Any], origin: str, index: int) -> dict[str, Any] | None:
    base_url = public_base_url(text(item.get("bookSourceUrl")))
    if not base_url:
        return None
    name = text(item.get("bookSourceName")) or f"未命名书源 {index + 1}"
    rules = rule_map(item)
    level, reason = compatibility(item, rules)
    return {
        "id": source_id(base_url, name),
        "name": name,
        "base_url": base_url,
        "group": text(item.get("bookSourceGroup")) or "未分组",
        "source_type": text(item.get("bookSourceType")) or "0",
        "enabled": True,
        "original_enabled": bool(item.get("enabled", item.get("enable", True))),
        # 新鲜规则优先进入冷启动搜索批次，运行后再由成功率和延迟接管排序。
        "priority": integer(
            item.get("lastUpdateTime")
            or item.get("customOrder")
            or item.get("weight")
        ),
        "serial_number": integer(item.get("serialNumber")),
        "user_agent": user_agent(item),
        "login_url": text(item.get("loginUrl")),
        "compatibility": level,
        "compatibility_reason": reason,
        "built_in": True,
        "origin": origin,
        "original_index": index,
        "reference": "",
        "rules": rules,
    }


def existing_sources(path: Path | None) -> list[dict[str, Any]]:
    if path is None or not path.exists():
        return []
    payload = json.loads(path.read_text(encoding="utf-8"))
    return [dict(item) for item in payload.get("sources", [])]


def mobile_source(source: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": source["id"],
        "name": source["name"],
        "description": source["compatibility_reason"],
        "endpoint": source["base_url"],
        "group": source["group"],
        "compatibility": source["compatibility"],
        "compatibility_reason": source["compatibility_reason"],
        "enabled": True,
        "health": "unknown",
        "priority": source["priority"],
        "built_in": True,
        "kind": "legacy",
    }


def main() -> None:
    args = parse_args()
    urls = subscription_urls(args.subscription_file)
    if not urls:
        raise SystemExit("订阅文件中没有 HTTP(S) 地址")

    accepted: list[dict[str, Any]] = []
    downloads: list[dict[str, Any]] = []
    for url in urls:
        try:
            raw_sources = download_sources(url, args.timeout)
            normalized = [
                source
                for index, item in enumerate(raw_sources)
                if (source := normalize(item, f"subscription:{url}", index))
                is not None
            ]
            accepted.extend(normalized)
            downloads.append({"url": url, "status": "ok", "accepted": len(normalized)})
        except Exception as exc:
            downloads.append(
                {"url": url, "status": "error", "accepted": 0, "error": str(exc)}
            )

    # 旧目录先放入，订阅中的新规则按规范化站点地址覆盖旧规则。
    merged = {
        canonical_key(source): source
        for source in existing_sources(args.existing)
        if canonical_key(source)
    }
    for source in accepted:
        merged[canonical_key(source)] = source
    sources = sorted(
        merged.values(),
        key=lambda source: (-int(source.get("priority", 0)), source["name"].casefold()),
    )
    counts = Counter(source["compatibility"] for source in sources)
    catalog = {
        "schema_version": 2,
        "generated_at": datetime.now(UTC).isoformat(),
        "subscriptions": downloads,
        "sources": sources,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    args.mobile_output.parent.mkdir(parents=True, exist_ok=True)
    args.mobile_output.write_text(
        json.dumps(
            {
                "schema_version": 2,
                "generated_at": catalog["generated_at"],
                "sources": [mobile_source(source) for source in sources],
            },
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "subscriptions": downloads,
                "downloaded": len(accepted),
                "merged": len(sources),
                "compatibility": dict(sorted(counts.items())),
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
