import json
import re
from dataclasses import dataclass
from typing import Any
from urllib.parse import quote, urljoin

import httpx
from bs4 import BeautifulSoup, Tag
from jsonpath_ng.ext import parse as parse_jsonpath

from app.schemas.legacy_sources import LegacyBook, LegacyChapter, LegacySource
from app.services.source_guard import validate_public_source_url

MAX_RESPONSE_BYTES = 2 * 1024 * 1024
MAX_REDIRECTS = 3


class LegacyRuleError(ValueError):
    pass


@dataclass(frozen=True)
class RequestSpec:
    url: str
    method: str
    body: dict[str, str]
    charset: str


class SafeLegacyHttpClient:
    async def request(
        self,
        spec: RequestSpec,
        *,
        user_agent: str = "",
    ) -> tuple[str, str]:
        url = validate_public_source_url(spec.url)
        headers = {
            "User-Agent": user_agent or "MNovel/1.0 legacy source compatibility"
        }
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(10, connect=5),
            follow_redirects=False,
            verify=True,
            headers=headers,
        ) as client:
            for _ in range(MAX_REDIRECTS + 1):
                async with client.stream(
                    spec.method,
                    url,
                    data=spec.body if spec.method == "POST" else None,
                ) as response:
                    if response.is_redirect:
                        target = response.headers.get("location", "")
                        if not target:
                            raise LegacyRuleError("书源返回了无地址的重定向")
                        url = validate_public_source_url(urljoin(url, target))
                        continue
                    response.raise_for_status()
                    chunks: list[bytes] = []
                    size = 0
                    async for chunk in response.aiter_bytes():
                        size += len(chunk)
                        if size > MAX_RESPONSE_BYTES:
                            raise LegacyRuleError("书源响应超过 2 MB 上限")
                        chunks.append(chunk)
                    charset = spec.charset or response.encoding or "utf-8"
                    try:
                        text = b"".join(chunks).decode(charset, errors="replace")
                    except LookupError as exc:
                        raise LegacyRuleError(f"不支持的字符集：{charset}") from exc
                    return text, str(response.url)
        raise LegacyRuleError("书源重定向次数超过上限")


class LegacyRuleEngine:
    def __init__(self, http_client: SafeLegacyHttpClient | None = None) -> None:
        self.http = http_client or SafeLegacyHttpClient()

    async def search(
        self,
        source: LegacySource,
        keyword: str,
        page: int = 1,
    ) -> list[LegacyBook]:
        self._ensure_compatible(source)
        rules = source.rules
        spec = self._request_spec(
            source,
            str(rules.get("ruleSearchUrl", "")),
            search_key=keyword,
            page=page,
        )
        payload, final_url = await self.http.request(
            spec,
            user_agent=source.user_agent,
        )
        nodes = self._select_nodes(payload, str(rules["ruleSearchList"]))
        books: list[LegacyBook] = []
        for index, node in enumerate(nodes[:100]):
            detail = self._value(node, str(rules["ruleSearchNoteUrl"]), final_url)
            title = self._value(node, str(rules["ruleSearchName"]), final_url)
            if not title or not detail:
                continue
            detail_url = urljoin(final_url, detail)
            books.append(
                LegacyBook(
                    id=f"{source.id}:{quote(detail_url, safe='')}",
                    title=title,
                    author=self._value(
                        node, str(rules.get("ruleSearchAuthor", "")), final_url
                    ),
                    cover=urljoin(
                        final_url,
                        self._value(
                            node,
                            str(rules.get("ruleSearchCoverUrl", "")),
                            final_url,
                        ),
                    ),
                    introduction=self._value(
                        node,
                        str(rules.get("ruleSearchIntroduce", "")),
                        final_url,
                    ),
                    kind=self._value(
                        node, str(rules.get("ruleSearchKind", "")), final_url
                    ),
                    latest_chapter=self._value(
                        node,
                        str(rules.get("ruleSearchLastChapter", "")),
                        final_url,
                    ),
                    detail_url=detail_url,
                    source_id=source.id,
                    source_name=source.name,
                )
            )
        return books

    async def chapters(
        self,
        source: LegacySource,
        detail_url: str,
    ) -> list[LegacyChapter]:
        self._ensure_compatible(source)
        payload, final_url = await self.http.request(
            RequestSpec(detail_url, "GET", {}, ""),
            user_agent=source.user_agent,
        )
        nodes = self._select_nodes(payload, str(source.rules["ruleChapterList"]))
        chapters: list[LegacyChapter] = []
        for index, node in enumerate(nodes[:10000]):
            title = self._value(
                node, str(source.rules["ruleChapterName"]), final_url
            )
            url_rule = str(
                source.rules.get("ruleChapterUrl")
                or source.rules.get("ruleContentUrl")
                or ""
            )
            chapter_url = self._value(node, url_rule, final_url)
            if title and chapter_url:
                chapters.append(
                    LegacyChapter(
                        index=index,
                        title=title,
                        url=urljoin(final_url, chapter_url),
                    )
                )
        return chapters

    async def chapter_content(
        self,
        source: LegacySource,
        chapter_url: str,
        *,
        title: str = "",
    ) -> list[str]:
        self._ensure_compatible(source)
        payload, final_url = await self.http.request(
            RequestSpec(chapter_url, "GET", {}, ""),
            user_agent=source.user_agent,
        )
        values = self._select_nodes(payload, str(source.rules["ruleBookContent"]))
        paragraphs: list[str] = []
        for value in values:
            text = self._node_text(value)
            paragraphs.extend(
                part.strip()
                for part in re.split(r"(?:\r?\n|\u3000{2,}|<br\s*/?>)+", text)
                if part.strip()
            )
        if not paragraphs:
            raise LegacyRuleError(f"正文规则未匹配内容：{final_url}")
        return paragraphs[:5000]

    def _ensure_compatible(self, source: LegacySource) -> None:
        if source.compatibility != "compatible_core":
            raise LegacyRuleError(source.compatibility_reason)

    def _request_spec(
        self,
        source: LegacySource,
        template: str,
        *,
        search_key: str,
        page: int,
    ) -> RequestSpec:
        if not template:
            raise LegacyRuleError("缺少请求地址规则")
        request_part, *options = template.split("|")
        charset = ""
        for option in options:
            if option.lower().startswith("char="):
                charset = option.split("=", 1)[1].strip()
        request_part = (
            request_part.replace("searchKey", quote(search_key))
            .replace("{searchKey}", quote(search_key))
            .replace("searchPage", str(max(1, page)))
            .replace("{searchPage}", str(max(1, page)))
        )
        method = "GET"
        body: dict[str, str] = {}
        if "@" in request_part:
            possible_url, raw_body = request_part.split("@", 1)
            if possible_url.startswith(("http://", "https://", "/")):
                request_part = possible_url
                method = "POST"
                for pair in raw_body.split("&"):
                    if "=" in pair:
                        key, value = pair.split("=", 1)
                        body[key] = value
        url = urljoin(source.base_url.rstrip("/") + "/", request_part)
        return RequestSpec(url, method, body, charset)

    def _select_nodes(self, payload: str, rule: str) -> list[Any]:
        if not rule:
            return []
        clean_rule = rule.strip()
        if clean_rule.lower().startswith("@json:"):
            clean_rule = clean_rule.split(":", 1)[1]
            return self._json_nodes(payload, clean_rule)
        if clean_rule.startswith("$"):
            return self._json_nodes(payload, clean_rule)
        try:
            decoded = json.loads(payload)
        except json.JSONDecodeError:
            decoded = None
        if decoded is not None and (
            clean_rule.startswith("$") or re.match(r"^[\w.]+\[\*]", clean_rule)
        ):
            return self._json_nodes(decoded, clean_rule)
        soup = BeautifulSoup(payload, "html.parser")
        selector, _, _ = self._split_terminal(clean_rule)
        css = self._legacy_selector_to_css(selector)
        try:
            return list(soup.select(css))
        except Exception as exc:
            raise LegacyRuleError(f"不支持的列表规则：{rule}") from exc

    def _json_nodes(self, payload: str | Any, rule: str) -> list[Any]:
        try:
            decoded = json.loads(payload) if isinstance(payload, str) else payload
            expression = parse_jsonpath(rule)
            return [match.value for match in expression.find(decoded)]
        except (json.JSONDecodeError, Exception) as exc:
            raise LegacyRuleError(f"JSONPath 规则执行失败：{rule}") from exc

    def _value(self, node: Any, rule: str, base_url: str) -> str:
        if not rule:
            return ""
        for fallback in rule.split("||"):
            value = self._value_once(node, fallback.strip(), base_url)
            if value:
                return value
        return ""

    def _value_once(self, node: Any, rule: str, base_url: str) -> str:
        if not rule:
            return ""
        main, replacement = self._split_replacement(rule)
        if isinstance(node, (dict, list)):
            values = self._json_value(node, main)
        else:
            selector, terminal, index = self._split_terminal(main)
            selected: list[Any]
            if selector in {"", "text", "html", "href", "src"}:
                selected = [node]
                terminal = selector or terminal
            else:
                css = self._legacy_selector_to_css(selector)
                try:
                    selected = list(node.select(css))
                except Exception:
                    return ""
            if index is not None:
                selected = selected[index : index + 1]
            values = [self._terminal_value(value, terminal) for value in selected]
        value = " ".join(part.strip() for part in values if part and part.strip()).strip()
        if replacement:
            pattern, substitute = replacement
            try:
                value = re.sub(pattern, substitute, value)
            except re.error:
                return ""
        return value

    def _json_value(self, node: Any, rule: str) -> list[str]:
        clean = rule.removeprefix("@JSon:").removeprefix("@JSON:")
        if clean.startswith("$"):
            try:
                return [
                    str(match.value)
                    for match in parse_jsonpath(clean).find(node)
                    if match.value is not None
                ]
            except Exception:
                return []
        current = node
        for part in clean.split("."):
            if not part:
                continue
            if isinstance(current, dict):
                current = current.get(part)
            else:
                return []
        if current is None:
            return []
        if isinstance(current, list):
            return [str(value) for value in current]
        return [str(current)]

    def _split_terminal(self, rule: str) -> tuple[str, str, int | None]:
        parts = [part for part in rule.split("@") if part]
        terminal = "text"
        if parts and parts[-1] in {
            "text",
            "textNodes",
            "html",
            "href",
            "src",
            "content",
        }:
            terminal = parts.pop()
        selector_parts: list[str] = []
        selected_index: int | None = None
        for part in parts:
            match = re.fullmatch(r"(.+?)\.(\d+)", part)
            if match:
                part = match.group(1)
                selected_index = int(match.group(2))
            selector_parts.append(part)
        return "@".join(selector_parts), terminal, selected_index

    def _legacy_selector_to_css(self, rule: str) -> str:
        rule = rule.removeprefix("@css:").strip()
        if not rule:
            return "*"
        if "@" not in rule and (
            rule.startswith((".", "#", "["))
            or " " in rule
            or ":" in rule
        ):
            return rule
        tokens: list[str] = []
        for part in rule.split("@"):
            if part.startswith("class."):
                classes = [value for value in part[6:].split(" ") if value]
                tokens.append("".join(f".{value}" for value in classes))
            elif part.startswith("id."):
                tokens.append(f"#{part[3:]}")
            elif part.startswith("tag."):
                tokens.append(part[4:])
            elif part:
                tokens.append(part)
        return " ".join(tokens) or "*"

    def _terminal_value(self, node: Any, terminal: str) -> str:
        if not isinstance(node, Tag):
            return str(node)
        if terminal == "html":
            return node.decode_contents()
        if terminal in {"href", "src", "content"}:
            return str(node.get(terminal, ""))
        if terminal == "textNodes":
            return "\n".join(
                text.strip() for text in node.stripped_strings if text.strip()
            )
        return node.get_text(" ", strip=True)

    def _node_text(self, node: Any) -> str:
        if isinstance(node, Tag):
            return node.get_text("\n", strip=True)
        if isinstance(node, (dict, list)):
            return json.dumps(node, ensure_ascii=False)
        return str(node)

    def _split_replacement(
        self, rule: str
    ) -> tuple[str, tuple[str, str] | None]:
        if "##" not in rule:
            return rule, None
        main, pattern, *rest = rule.split("##")
        substitute = rest[0] if rest else ""
        return main, (pattern, substitute)
