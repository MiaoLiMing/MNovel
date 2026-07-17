import asyncio
import html
import math
import re
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

import httpx

from app.schemas.content import Channel, ContentSummary


ATOM = {"a": "http://www.w3.org/2005/Atom"}


class LiveCatalogService:
    """聚合合法公开目录；网络失败时返回空列表，不伪装成真实数据。"""

    def __init__(self, enabled: bool = True, ttl_seconds: int = 900) -> None:
        self.enabled = enabled
        self.ttl_seconds = ttl_seconds
        self._cache: dict[str, tuple[float, list[ContentSummary]]] = {}
        self._items: dict[str, ContentSummary] = {}
        self._text_cache: dict[str, str] = {}

    async def discover(
        self,
        channel: Channel,
        query: str = "",
        category: str = "",
    ) -> list[ContentSummary]:
        if not self.enabled:
            return []
        key = f"{channel.value}:{query.strip()}:{category.strip()}"
        cached = self._cache.get(key)
        if cached and time.monotonic() - cached[0] < self.ttl_seconds:
            return cached[1]

        try:
            if channel == Channel.novel:
                category_query = {
                    "全部": "fiction",
                    "都市": "city fiction",
                    "玄幻": "fantasy",
                    "仙侠": "adventure",
                    "科幻": "science fiction",
                    "历史": "history",
                    "悬疑": "mystery",
                    "古言": "romance",
                    "现实": "social life fiction",
                }.get(category, category)
                items = await self._gutenberg(query or category_query or "fiction")
            elif channel == Channel.short_drama:
                items = await self._tvmaze(query or category)
                if not items:
                    items = await self._internet_archive(channel, query, category)
            elif channel == Channel.video:
                items = await self._itunes(query or category)
                if not items:
                    items = await self._internet_archive(channel, query, category)
            else:
                items = []
        except (httpx.HTTPError, ET.ParseError, ValueError):
            return []

        self._cache[key] = (time.monotonic(), items)
        self._items.update({item.id: item for item in items})
        if channel == Channel.novel and items:
            asyncio.create_task(self._warm_text(items[0].id))
        return items

    async def _warm_text(self, content_id: str) -> None:
        try:
            await self.gutenberg_text(content_id)
        except httpx.HTTPError:
            return

    def get_cached(self, content_id: str) -> ContentSummary | None:
        return self._items.get(content_id)

    async def gutenberg_text(self, content_id: str) -> str | None:
        if content_id in self._text_cache:
            return self._text_cache[content_id]
        match = re.fullmatch(r"gutenberg-(\d+)", content_id)
        if not match:
            return None
        ebook = match.group(1)
        text = await asyncio.to_thread(self._download_text, ebook)
        self._text_cache[content_id] = text
        return text

    @staticmethod
    def _download_text(ebook: str) -> str:
        cache_path = Path("data/content-cache/gutenberg") / f"{ebook}.txt"
        if cache_path.exists():
            return cache_path.read_text(encoding="utf-8", errors="replace")
        with httpx.Client(
            timeout=45,
            follow_redirects=True,
            headers={"User-Agent": "MNovel/1.0 (private reader)"},
        ) as client:
            response = client.get(f"https://www.gutenberg.org/ebooks/{ebook}.txt.utf-8")
            response.raise_for_status()
            cache_path.parent.mkdir(parents=True, exist_ok=True)
            cache_path.write_bytes(response.content)
            return response.text

    async def _gutenberg(self, query: str) -> list[ContentSummary]:
        async with httpx.AsyncClient(
            timeout=16,
            follow_redirects=True,
            headers={"User-Agent": "MNovel/1.0 (private reader)"},
        ) as client:
            search = await client.get(
                "https://www.gutenberg.org/ebooks/search.opds/",
                params={"query": query},
            )
            search.raise_for_status()
            root = ET.fromstring(search.content)
            detail_urls: list[str] = []
            for entry in root.findall("a:entry", ATOM):
                item_id = entry.findtext("a:id", default="", namespaces=ATOM)
                if re.fullmatch(r"https://www\.gutenberg\.org/ebooks/\d+\.opds", item_id):
                    detail_urls.append(item_id)
                if len(detail_urls) == 10:
                    break

            responses = await asyncio.gather(
                *(client.get(url) for url in detail_urls),
                return_exceptions=True,
            )

        items: list[ContentSummary] = []
        for response in responses:
            if isinstance(response, BaseException) or response.status_code >= 400:
                continue
            item = self._parse_gutenberg_detail(response.content)
            if item:
                items.append(item)
        return items

    def _parse_gutenberg_detail(self, payload: bytes) -> ContentSummary | None:
        root = ET.fromstring(payload)
        entry = root.find("a:entry", ATOM)
        if entry is None:
            return None
        urn = entry.findtext("a:id", default="", namespaces=ATOM)
        match = re.search(r"gutenberg:(\d+)", urn)
        if not match:
            return None
        ebook = match.group(1)
        title = entry.findtext("a:title", default="未命名作品", namespaces=ATOM)
        author = entry.findtext("a:author/a:name", default="未知作者", namespaces=ATOM)
        categories = [
            node.attrib.get("term", "")
            for node in entry.findall("a:category", ATOM)
            if node.attrib.get("term")
        ]
        cover = f"assets/gutenberg/{ebook}/cover"
        acquisition_lengths = [
            int(link.attrib.get("length", "0"))
            for link in entry.findall("a:link", ATOM)
            if link.attrib.get("rel") == "http://opds-spec.org/acquisition"
            and link.attrib.get("length", "").isdigit()
        ]
        estimated_text_length = max(acquisition_lengths, default=25000)
        raw_content = (
            " ".join(entry.find("a:content", ATOM).itertext())
            if entry.find("a:content", ATOM) is not None
            else ""
        )
        plain = re.sub(r"\s+", " ", html.unescape(raw_content)).strip()
        summary_match = re.search(r"Summary:\s*(.+?)(?:Reading Level:|Author:)", plain)
        downloads_match = re.search(r"Downloads:\s*(\d+)", plain)
        return ContentSummary(
            id=f"gutenberg-{ebook}",
            channel=Channel.novel,
            title=title.strip(),
            creator=author.strip(),
            category=" · ".join(categories[:2]) or "公共领域文学",
            summary=(
                summary_match.group(1).strip()
                if summary_match
                else "Project Gutenberg 公共领域电子书。"
            ),
            cover=cover,
            popularity=(
                f"{int(downloads_match.group(1)):,} 次下载" if downloads_match else "公共领域"
            ),
            unit_count=max(1, math.ceil(estimated_text_length / 25000)),
            source_count=1,
            source_id="project-gutenberg",
            source_name="Project Gutenberg OPDS",
            is_live=True,
        )

    async def _tvmaze(self, query: str) -> list[ContentSummary]:
        term = query.strip()
        try:
            async with httpx.AsyncClient(
                timeout=12,
                follow_redirects=True,
                headers={"User-Agent": "MNovel/1.0 (private reader)"},
            ) as client:
                if term and term != "全部":
                    response = await client.get(
                        "https://api.tvmaze.com/search/shows",
                        params={"q": term},
                    )
                    response.raise_for_status()
                    shows_data = response.json()
                    shows = [item["show"] for item in shows_data if isinstance(item, dict) and "show" in item]
                else:
                    response = await client.get("https://api.tvmaze.com/shows", params={"page": 0})
                    response.raise_for_status()
                    shows = response.json()[:12]
        except Exception:
            return []

        items: list[ContentSummary] = []
        for show in shows:
            if not isinstance(show, dict) or not show.get("id"):
                continue
            show_id = str(show["id"])
            title = show.get("name", "未命名短剧")
            genres = show.get("genres", [])
            category_str = " · ".join(genres) if genres else "都市剧场"
            
            raw_summary = show.get("summary") or "暂无详细简介。"
            summary = re.sub(r"<[^>]+>", "", raw_summary).strip()
            
            image_dict = show.get("image") or {}
            cover = image_dict.get("medium") or image_dict.get("original") or ""
            
            rating_dict = show.get("rating") or {}
            rating = rating_dict.get("average")
            popularity = f"评分 {rating}" if rating else "热门热播"
            
            creator = "TVmaze"
            network_dict = show.get("network")
            if network_dict and isinstance(network_dict, dict) and network_dict.get("name"):
                creator = network_dict["name"]
            else:
                web_dict = show.get("webChannel")
                if web_dict and isinstance(web_dict, dict) and web_dict.get("name"):
                    creator = web_dict["name"]

            items.append(
                ContentSummary(
                    id=f"tvmaze-{show_id}",
                    channel=Channel.short_drama,
                    title=title,
                    creator=creator,
                    category=category_str,
                    summary=summary,
                    cover=cover,
                    popularity=popularity,
                    unit_count=45,
                    source_count=1,
                    source_id="tvmaze",
                    source_name="TVmaze 开放数据",
                    is_live=True,
                )
            )
        return items

    async def _itunes(self, query: str) -> list[ContentSummary]:
        term = query.strip()
        if not term or term == "全部":
            term = "classic"
        try:
            async with httpx.AsyncClient(
                timeout=12,
                follow_redirects=True,
                headers={"User-Agent": "MNovel/1.0 (private reader)"},
            ) as client:
                response = await client.get(
                    "https://itunes.apple.com/search",
                    params={"media": "movie", "term": term, "limit": 12, "country": "cn"},
                )
                response.raise_for_status()
                results = response.json().get("results", [])
        except Exception:
            return []

        items: list[ContentSummary] = []
        for movie in results:
            if not isinstance(movie, dict):
                continue
            track_id = movie.get("trackId")
            if not track_id:
                continue
            title = movie.get("trackName", "未命名影片")
            creator = movie.get("artistName") or "经典影视"
            category_str = movie.get("primaryGenreName") or "电影"
            summary = movie.get("longDescription") or movie.get("shortDescription") or "暂无影片简介。"
            
            cover = movie.get("artworkUrl100", "")
            if cover and cover.endswith("100x100bb.jpg"):
                cover = cover.replace("100x100bb.jpg", "600x600bb.jpg")
            elif cover:
                cover = re.sub(r"\d+x\d+bb", "600x600", cover)

            rating_or_price = movie.get("contentAdvisoryRating") or "PG-13"
            popularity = f"评级 {rating_or_price}"

            items.append(
                ContentSummary(
                    id=f"itunes-{track_id}",
                    channel=Channel.video,
                    title=title,
                    creator=creator,
                    category=category_str,
                    summary=summary,
                    cover=cover,
                    popularity=popularity,
                    unit_count=1,
                    source_count=1,
                    source_id="itunes",
                    source_name="iTunes 官方源",
                    is_live=True,
                )
            )
        return items

    async def _internet_archive(
        self,
        channel: Channel,
        query: str,
        category: str,
    ) -> list[ContentSummary]:
        filters = ["mediatype:movies", "collection:opensource_movies"]
        term = (query or category).strip()
        if channel == Channel.short_drama:
            filters.append('(subject:"Short films" OR title:short)')
        if term and term != "全部":
            filters.append(f"({term})")
        async with httpx.AsyncClient(
            timeout=16,
            follow_redirects=True,
            headers={"User-Agent": "MNovel/1.0 (private reader)"},
        ) as client:
            response = await client.get(
                "https://archive.org/advancedsearch.php",
                params={
                    "q": " AND ".join(filters),
                    "fl[]": [
                        "identifier",
                        "title",
                        "creator",
                        "description",
                        "downloads",
                        "subject",
                    ],
                    "sort[]": "downloads desc",
                    "rows": 12,
                    "page": 1,
                    "output": "json",
                },
            )
            response.raise_for_status()
            docs = response.json().get("response", {}).get("docs", [])

        return [self._archive_item(doc, channel) for doc in docs if doc.get("identifier")]

    def _archive_item(self, doc: dict[str, Any], channel: Channel) -> ContentSummary:
        identifier = str(doc["identifier"])
        creator = doc.get("creator", "Internet Archive")
        if isinstance(creator, list):
            creator = creator[0] if creator else "Internet Archive"
        subject = doc.get("subject", [])
        if isinstance(subject, str):
            subject = [subject]
        description = doc.get("description", "Internet Archive 公开馆藏视频。")
        if isinstance(description, list):
            description = description[0] if description else "Internet Archive 公开馆藏视频。"
        return ContentSummary(
            id=f"archive-{identifier}",
            channel=channel,
            title=str(doc.get("title") or identifier),
            creator=str(creator),
            category=" · ".join(str(value) for value in subject[:2]) or "公开影像",
            summary=re.sub(r"<[^>]+>", "", str(description))[:500],
            cover=f"https://archive.org/services/img/{identifier}",
            popularity=f"{int(doc.get('downloads') or 0):,} 次观看",
            unit_count=1,
            source_count=1,
            source_id="internet-archive",
            source_name="Internet Archive",
            is_live=True,
        )
