import re
import time
from uuid import uuid4

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status

from app.core.security import build_token_guard
from app.db.database import Database
from app.repositories.catalog import CatalogRepository
from app.schemas.content import (
    Channel,
    ChapterContent,
    ContentDetail,
    ContentSummary,
    FavoriteUpdate,
    HistoryItem,
    HomeResponse,
    NovelStatus,
    PlaybackLine,
    ReaderSummary,
    SearchMeta,
    ProgressUpdate,
    SourceImport,
    SourceOrderUpdate,
    SourceStatus,
    SourceToggle,
    SourceUpdate,
    TaxonomyResponse,
    UnitSummary,
)
from app.services.live_catalog import LiveCatalogService
from app.services.source_guard import UnsafeSourceUrl, validate_public_source_url


def create_router(
    database: Database,
    live_catalog: LiveCatalogService | None = None,
    access_token: str = "",
) -> APIRouter:
    router = APIRouter()
    catalog = CatalogRepository()
    remote = live_catalog or LiveCatalogService()
    require_token = build_token_guard(access_token)
    chapter_titles = (
        "旧友",
        "交谈",
        "计划",
        "邀请",
        "准备",
        "启程",
        "风暴前夕",
        "选择",
        "隐秘来客",
        "远方的钟声",
    )

    def db() -> Database:
        return database

    def require(content_id: str) -> ContentSummary:
        item = catalog.get(content_id)
        if item is None:
            raise HTTPException(status_code=404, detail="内容不存在")
        return item

    def present_source(item: dict, *, health: str | None = None, latency: int = 0) -> SourceStatus:
        config = item["config"]
        base_url = str(config.get("base_url", ""))
        resolved_health = health or (
            "disabled"
            if not item["enabled"]
            else "configuration_required"
            if not base_url
            else "healthy"
        )
        return SourceStatus(
            id=item["id"],
            name=item["name"],
            kind=item["kind"],
            enabled=item["enabled"],
            priority=item["priority"],
            health=resolved_health,
            latency_ms=latency,
            base_url=base_url,
            built_in=bool(config.get("built_in")),
        )

    @router.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "service": "mnovel-api"}

    @router.get("/home", response_model=HomeResponse)
    def home(channel: str = Query(default="推荐", max_length=12)) -> HomeResponse:
        return catalog.home(channel)

    @router.get("/taxonomy", response_model=TaxonomyResponse)
    def taxonomy() -> TaxonomyResponse:
        return catalog.taxonomy()

    @router.get("/search/meta", response_model=SearchMeta)
    def search_meta() -> SearchMeta:
        return catalog.search_meta()

    @router.get("/assets/gutenberg/{ebook}/cover")
    async def gutenberg_cover(ebook: int) -> Response:
        if ebook < 1:
            raise HTTPException(status_code=404, detail="封面不存在")
        try:
            async with httpx.AsyncClient(timeout=15, follow_redirects=True) as client:
                result = await client.get(
                    f"https://www.gutenberg.org/cache/epub/{ebook}/pg{ebook}.cover.medium.jpg"
                )
                result.raise_for_status()
        except httpx.HTTPError as exc:
            raise HTTPException(status_code=404, detail="封面暂时不可用") from exc
        return Response(
            content=result.content,
            media_type=result.headers.get("content-type", "image/jpeg"),
            headers={"Cache-Control": "public, max-age=86400"},
        )

    @router.get("/search", response_model=list[ContentSummary])
    async def search(
        query: str = Query(default="", max_length=80),
        channel: Channel | None = None,
    ) -> list[ContentSummary]:
        selected = channel or Channel.novel
        local_items = catalog.list(selected, query)
        if local_items or not query.strip():
            return local_items
        return await remote.discover(selected, query=query)

    @router.get("/discover", response_model=list[ContentSummary])
    async def discover(
        channel: Channel = Channel.novel,
        category: str = Query(default="", max_length=40),
        novel_status: NovelStatus | None = Query(default=None, alias="status"),
        word_count: str = Query(default="", max_length=20),
        source: str = Query(default="", max_length=80),
        query: str = Query(default="", max_length=80),
    ) -> list[ContentSummary]:
        items = catalog.list(
            channel,
            query=query,
            category=category,
            status=novel_status,
            word_count=word_count,
            source=source,
        )
        if items or channel == Channel.novel:
            return items
        return await remote.discover(channel, query=query, category=category)

    @router.get("/content/{content_id}", response_model=ContentDetail)
    def detail(content_id: str) -> ContentSummary:
        item = remote.get_cached(content_id) or catalog.get(content_id)
        if item is None:
            raise HTTPException(status_code=404, detail="内容不存在或尚未从目录加载")
        return item

    @router.get("/content/{content_id}/units", response_model=list[UnitSummary])
    def units(
        content_id: str,
        offset: int = Query(default=0, ge=0),
        limit: int = Query(default=100, ge=1, le=200),
    ) -> list[UnitSummary]:
        item = require(content_id)
        if offset >= item.unit_count:
            return []
        count = min(item.unit_count - offset, limit)
        noun = "章" if item.channel == Channel.novel else "集"
        return [
            UnitSummary(
                id=f"{content_id}-{offset + index + 1}",
                index=offset + index,
                title=f"第 {offset + index + 1}{noun} {chapter_titles[(offset + index) % len(chapter_titles)]}",
                duration_seconds=None if item.channel == Channel.novel else 720,
            )
            for index in range(count)
        ]

    @router.get(
        "/content/{content_id}/chapters/{chapter_index}", response_model=ChapterContent
    )
    async def chapter(content_id: str, chapter_index: int) -> ChapterContent:
        if content_id.startswith("gutenberg-"):
            raw = await remote.gutenberg_text(content_id)
            if not raw:
                raise HTTPException(status_code=502, detail="正文暂时不可用")
            body = raw
            if "*** START OF THE PROJECT GUTENBERG" in body:
                body = body.split("*** START OF THE PROJECT GUTENBERG", 1)[1]
            if "*** END OF THE PROJECT GUTENBERG" in body:
                body = body.split("*** END OF THE PROJECT GUTENBERG", 1)[0]
            paragraphs = [
                " ".join(part.split())
                for part in re.split(r"\r?\n\s*\r?\n", body)
                if len(" ".join(part.split())) > 1
            ]
            chunks: list[list[str]] = []
            current: list[str] = []
            current_size = 0
            for paragraph in paragraphs:
                if current and current_size + len(paragraph) > 30000:
                    chunks.append(current)
                    current = []
                    current_size = 0
                current.append(paragraph)
                current_size += len(paragraph)
            if current:
                chunks.append(current)
            if chapter_index >= len(chunks):
                raise HTTPException(status_code=404, detail="章节不存在")
            item = remote.get_cached(content_id)
            return ChapterContent(
                id=f"{content_id}-{chapter_index + 1}",
                index=chapter_index,
                title=f"{item.title if item else '正文'} · 第 {chapter_index + 1} 节",
                paragraphs=chunks[chapter_index],
                source_id="project-gutenberg",
            )
        item = require(content_id)
        if item.channel != Channel.novel:
            raise HTTPException(status_code=400, detail="该内容不是小说")
        if chapter_index < 0 or chapter_index >= item.unit_count:
            raise HTTPException(status_code=404, detail="章节不存在")
        chapter_title = chapter_titles[chapter_index % len(chapter_titles)]
        return ChapterContent(
            id=f"{content_id}-{chapter_index + 1}",
            index=chapter_index,
            title=f"第 {chapter_index + 1} 章 {chapter_title}",
            paragraphs=[
                "“愚者”，梅林沉默地注视着这个年轻人。良久，他轻声说道：",
                "“或许你还没有意识到，成为非凡者的你，已经不再是普通的你了。”",
                "晨雾沿着山脊缓慢散开，石阶尽头传来一声清越的钟鸣。",
                "这个世界上有很多秘密，有些被牢牢藏在泥土和灰尘之下。",
                "如果你真的决定踏上这条道路，就必须无惧深渊的凝视，接受这一切。",
                "他顿了顿，目光深邃。",
                "“记住，力量越大，责任越大，代价也越大。”",
            ],
            source_id=item.source_id,
        )

    @router.post(
        "/content/{content_id}/episodes/{episode_index}/playback",
        response_model=list[PlaybackLine],
        dependencies=[Depends(require_token)],
    )
    def playback(content_id: str, episode_index: int) -> list[PlaybackLine]:
        item = require(content_id)
        if item.channel == Channel.novel:
            raise HTTPException(status_code=400, detail="小说不提供播放线路")
        if episode_index < 0 or episode_index >= item.unit_count:
            raise HTTPException(status_code=404, detail="剧集不存在")
        return [
            PlaybackLine(
                id="demo-line-a",
                label="演示线路 A",
                protocol="demo",
                quality="1080P",
                url=f"demo://{content_id}/{episode_index}",
                expires_in=300,
            )
        ]

    @router.put(
        "/favorites/{content_id}",
        status_code=status.HTTP_204_NO_CONTENT,
        dependencies=[Depends(require_token)],
    )
    def favorite(
        content_id: str, body: FavoriteUpdate, store: Database = Depends(db)
    ) -> None:
        require(content_id)
        store.set_favorite(content_id, body.channel.value, body.active)

    @router.get(
        "/favorites",
        response_model=list[ContentSummary],
        dependencies=[Depends(require_token)],
    )
    def favorites(
        channel: Channel = Channel.novel,
        store: Database = Depends(db),
    ) -> list[ContentSummary]:
        return [
            item
            for content_id in store.list_favorite_ids(channel.value)
            if (item := catalog.get(content_id)) is not None
        ]

    @router.put("/progress/{content_id}", dependencies=[Depends(require_token)])
    def update_progress(
        content_id: str, body: ProgressUpdate, store: Database = Depends(db)
    ) -> dict[str, bool]:
        require(content_id)
        store.save_progress(
            content_id, body.channel.value, body.unit_index, body.position
        )
        return {"saved": True}

    @router.get("/progress/{content_id}", dependencies=[Depends(require_token)])
    def progress(content_id: str, store: Database = Depends(db)) -> dict:
        require(content_id)
        value = store.get_progress(content_id)
        if value is None:
            raise HTTPException(status_code=404, detail="暂无进度")
        return value

    @router.get(
        "/history",
        response_model=list[HistoryItem],
        dependencies=[Depends(require_token)],
    )
    def history(store: Database = Depends(db)) -> list[HistoryItem]:
        values: list[HistoryItem] = []
        for entry in store.list_progress():
            item = catalog.get(str(entry["content_id"]))
            if item is None:
                continue
            values.append(
                HistoryItem(
                    content=item,
                    unit_index=int(entry["unit_index"]),
                    position=float(entry["position"]),
                    updated_at=str(entry["updated_at"]),
                )
            )
        return values

    @router.get(
        "/me/summary",
        response_model=ReaderSummary,
        dependencies=[Depends(require_token)],
    )
    def reader_summary(store: Database = Depends(db)) -> ReaderSummary:
        favorites_count = len(store.list_favorite_ids(Channel.novel.value))
        progress_values = store.list_progress()
        completed = sum(1 for entry in progress_values if float(entry["position"]) >= 0.98)
        estimated_minutes = sum(
            max(8, int(entry["unit_index"]) * 3 + float(entry["position"]) * 12)
            for entry in progress_values
        )
        return ReaderSummary(
            shelf_count=favorites_count,
            reading_hours=round(estimated_minutes / 60, 1),
            completed_count=completed,
            history_count=len(progress_values),
        )

    @router.get(
        "/sources",
        response_model=list[SourceStatus],
        dependencies=[Depends(require_token)],
    )
    def sources(store: Database = Depends(db)) -> list[SourceStatus]:
        return [present_source(item) for item in store.list_sources()]

    @router.post(
        "/sources",
        response_model=SourceStatus,
        status_code=status.HTTP_201_CREATED,
        dependencies=[Depends(require_token)],
    )
    def import_source(
        body: SourceImport, store: Database = Depends(db)
    ) -> SourceStatus:
        try:
            base_url = validate_public_source_url(str(body.base_url))
        except UnsafeSourceUrl as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        source_id = f"custom-{uuid4().hex[:12]}"
        store.add_source(
            source_id,
            body.name,
            body.kind,
            body.priority,
            {
                "base_url": base_url,
                "access": "user_configured",
                "built_in": False,
            },
        )
        item = store.get_source(source_id)
        assert item is not None
        return present_source(item, health="unchecked")

    @router.put(
        "/sources/{source_id}/enabled",
        response_model=SourceStatus,
        dependencies=[Depends(require_token)],
    )
    def toggle_source(
        source_id: str,
        body: SourceToggle,
        store: Database = Depends(db),
    ) -> SourceStatus:
        if not store.set_source_enabled(source_id, body.enabled):
            raise HTTPException(status_code=404, detail="内容源不存在")
        item = store.get_source(source_id)
        assert item is not None
        return present_source(
            item,
            health="healthy" if item["enabled"] else "disabled",
        )

    @router.patch(
        "/sources/{source_id}",
        response_model=SourceStatus,
        dependencies=[Depends(require_token)],
    )
    def update_source(
        source_id: str,
        body: SourceUpdate,
        store: Database = Depends(db),
    ) -> SourceStatus:
        base_url: str | None = None
        if body.base_url is not None:
            try:
                base_url = validate_public_source_url(str(body.base_url))
            except UnsafeSourceUrl as exc:
                raise HTTPException(status_code=400, detail=str(exc)) from exc
        if not store.update_source(
            source_id,
            name=body.name,
            base_url=base_url,
            priority=body.priority,
        ):
            raise HTTPException(status_code=404, detail="内容源不存在")
        item = store.get_source(source_id)
        assert item is not None
        return present_source(item, health="unchecked")

    @router.put(
        "/sources/order",
        response_model=list[SourceStatus],
        dependencies=[Depends(require_token)],
    )
    def reorder_sources(
        body: SourceOrderUpdate,
        store: Database = Depends(db),
    ) -> list[SourceStatus]:
        store.reorder_sources(body.source_ids)
        return [present_source(item) for item in store.list_sources()]

    @router.delete(
        "/sources/{source_id}",
        status_code=status.HTTP_204_NO_CONTENT,
        dependencies=[Depends(require_token)],
    )
    def delete_source(source_id: str, store: Database = Depends(db)) -> None:
        item = store.get_source(source_id)
        if item is None:
            raise HTTPException(status_code=404, detail="内容源不存在")
        if bool(item["config"].get("built_in")):
            raise HTTPException(status_code=400, detail="内置书源不可删除")
        if not store.delete_source(source_id):
            raise HTTPException(status_code=404, detail="内容源不存在")

    @router.post(
        "/sources/{source_id}/health",
        response_model=SourceStatus,
        dependencies=[Depends(require_token)],
    )
    async def check_source(
        source_id: str, store: Database = Depends(db)
    ) -> SourceStatus:
        item = store.get_source(source_id)
        if item is None:
            raise HTTPException(status_code=404, detail="内容源不存在")
        config = item["config"]
        base_url = str(config.get("base_url", ""))
        if not base_url:
            return present_source(item, health="configuration_required")
        started = time.perf_counter()
        try:
            validate_public_source_url(base_url)
            async with httpx.AsyncClient(
                timeout=httpx.Timeout(6, connect=4),
                follow_redirects=True,
                verify=False,
                headers={"User-Agent": "MNovel/1.0 source health check"},
            ) as client:
                response = await client.get(base_url)
            latency = int((time.perf_counter() - started) * 1000)
            health = "healthy" if response.status_code < 500 else "error"
            return present_source(item, health=health, latency=latency)
        except (httpx.HTTPError, UnsafeSourceUrl):
            latency = int((time.perf_counter() - started) * 1000)
            return present_source(item, health="error", latency=latency)

    @router.get("/proxy/video", name="proxy_video")
    async def proxy_video(
        request: Request,
        url: str = Query(...),
        referer: str | None = Query(default=None),
        master_url: str | None = Query(default=None),
    ) -> Response:
        import urllib.parse
        from fastapi.responses import StreamingResponse

        target_url = url.strip()
        effective_master = master_url.strip() if master_url else target_url
        try:
            validate_public_source_url(target_url)
            validate_public_source_url(effective_master)
        except UnsafeSourceUrl as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        }
        if request.headers.get("range"):
            headers["Range"] = request.headers["range"]

        if referer:
            headers["Referer"] = referer
            parsed_ref = urllib.parse.urlparse(referer)
            if parsed_ref.scheme and parsed_ref.netloc:
                headers["Origin"] = f"{parsed_ref.scheme}://{parsed_ref.netloc}"
        else:
            parsed_url = urllib.parse.urlparse(target_url)
            if parsed_url.scheme and parsed_url.netloc:
                headers["Referer"] = f"{parsed_url.scheme}://{parsed_url.netloc}/"
                headers["Origin"] = f"{parsed_url.scheme}://{parsed_url.netloc}"

        try:
            client: httpx.AsyncClient = request.app.state.video_http_client
            parsed_path = urllib.parse.urlparse(target_url).path.lower()
            is_m3u8 = parsed_path.endswith(".m3u8") or "m3u8" in target_url.lower()

            if is_m3u8:
                resp = await client.get(target_url, headers=headers)
                if resp.status_code == 404 and effective_master != target_url:
                    filename = target_url.split("/")[-1]
                    fallback_target = urllib.parse.urljoin(effective_master, filename)
                    validate_public_source_url(fallback_target)
                    resp = await client.get(fallback_target, headers=headers)
                resp.raise_for_status()
                content_type = resp.headers.get("content-type", "")

                text = resp.text
                lines = text.splitlines()
                rewritten_lines = []
                base_url = str(resp.url)

                def proxy_url_for(value: str) -> str:
                    absolute = urllib.parse.urljoin(base_url, value)
                    params = {
                        "url": absolute,
                        "master_url": effective_master,
                    }
                    if referer:
                        params["referer"] = referer
                    return str(
                        request.url_for("proxy_video").include_query_params(**params)
                    )

                for line in lines:
                    line_stripped = line.strip()
                    if not line_stripped:
                        continue
                    if line_stripped.startswith("#"):
                        if 'URI="' in line_stripped:
                            line_stripped = re.sub(
                                r'URI="([^"]+)"',
                                lambda match: f'URI="{proxy_url_for(match.group(1))}"',
                                line_stripped,
                            )
                        rewritten_lines.append(line_stripped)
                    else:
                        rewritten_lines.append(proxy_url_for(line_stripped))

                rewritten_content = "\n".join(rewritten_lines)
                return Response(
                    content=rewritten_content.encode("utf-8"),
                    media_type="application/vnd.apple.mpegurl"
                    if "mpegurl" in content_type
                    else content_type or "application/x-mpegURL",
                    headers={
                        "Access-Control-Allow-Origin": "*",
                        "Cache-Control": "private, max-age=15",
                    },
                )
            else:
                req = client.build_request("GET", target_url, headers=headers)
                r = await client.send(req, stream=True)
                if r.status_code == 404 and effective_master != target_url:
                    await r.aclose()
                    filename = target_url.split("/")[-1]
                    fallback_target = urllib.parse.urljoin(effective_master, filename)
                    req = client.build_request("GET", fallback_target, headers=headers)
                    r = await client.send(req, stream=True)

                r.raise_for_status()

                async def stream_generator():
                    try:
                        async for chunk in r.aiter_bytes(chunk_size=128 * 1024):
                            yield chunk
                    finally:
                        await r.aclose()

                resp_headers = {
                    "Access-Control-Allow-Origin": "*",
                }
                if r.headers.get("content-length"):
                    resp_headers["Content-Length"] = r.headers["content-length"]
                if r.headers.get("accept-ranges"):
                    resp_headers["Accept-Ranges"] = r.headers["accept-ranges"]
                if r.headers.get("content-range"):
                    resp_headers["Content-Range"] = r.headers["content-range"]

                return StreamingResponse(
                    stream_generator(),
                    status_code=r.status_code,
                    media_type=r.headers.get(
                        "content-type", "application/octet-stream"
                    ),
                    headers=resp_headers,
                )
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Proxy error: {str(e)}")

    @router.get("/videos/latest", name="get_latest_videos")
    async def get_latest_videos(page: int = Query(1, ge=1)):
        from app.providers.manager import provider_manager

        return await provider_manager.get_latest_all(page=page)

    @router.get("/videos/search", name="search_videos")
    async def search_videos(
        wd: str = Query(..., min_length=1), page: int = Query(1, ge=1)
    ):
        from app.providers.manager import provider_manager

        return await provider_manager.search_all(keyword=wd, page=page)

    @router.get("/videos/detail", name="get_video_detail")
    async def get_video_detail(source_id: int = Query(1), vod_id: str = Query(...)):
        from app.providers.manager import provider_manager

        provider = provider_manager.get_provider(source_id)
        if not provider:
            raise HTTPException(status_code=404, detail="影视源未找到")
        detail = await provider.get_detail(vod_id)
        if not detail:
            raise HTTPException(status_code=404, detail="影片详情获取失败")
        return detail

    @router.get("/videos/parse", name="parse_play_url")
    async def parse_play_url(
        request: Request,
        source_id: int = Query(1),
        play_url: str = Query(...),
    ):
        from app.providers.manager import provider_manager
        from app.schemas.videos import ParseResult

        provider = provider_manager.get_provider(source_id)
        try:
            validate_public_source_url(play_url)
        except UnsafeSourceUrl as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        final_url = await provider.parse_play_url(play_url) if provider else play_url
        resolved = final_url != play_url

        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        }
        import urllib.parse

        parsed = urllib.parse.urlparse(play_url if resolved else final_url)
        if parsed.scheme and parsed.netloc:
            headers["Referer"] = f"{parsed.scheme}://{parsed.netloc}/"
            headers["Origin"] = f"{parsed.scheme}://{parsed.netloc}"

        direct_media = (
            re.search(
                r"\.(?:m3u8|mp4|m4v|mov|webm)(?:$|[?#])",
                final_url,
                re.I,
            )
            is not None
        )
        parse_type = "direct" if direct_media else "unsupported"
        proxy_url = None
        if direct_media:
            proxy_url = str(
                request.url_for("proxy_video").include_query_params(
                    url=final_url,
                    referer=headers.get("Referer", ""),
                )
            )

        return ParseResult(
            url=final_url,
            headers=headers,
            parse_type=parse_type,
            proxy_url=proxy_url,
            resolved=resolved,
        )

    @router.get("/provider/sources", name="list_provider_sources")
    async def list_provider_sources(channel: str | None = Query(default=None)):
        from app.providers.manager import provider_manager

        return provider_manager.list_sources(channel=channel)

    @router.post("/provider/sources", name="add_provider_source")
    async def add_provider_source(
        name: str = Query(...), api_url: str = Query(...), channel: str = Query("video")
    ):
        from app.providers.manager import provider_manager

        return provider_manager.add_custom_source(
            name=name, api_url=api_url, channel=channel
        )

    @router.delete("/provider/sources/{source_id}", name="delete_provider_source")
    async def delete_provider_source(source_id: int):
        from app.providers.manager import provider_manager

        success = provider_manager.delete_custom_source(source_id)
        if not success:
            raise HTTPException(status_code=400, detail="内置源不可删除或源不存在")
        return {"status": "success", "id": source_id}

    return router
