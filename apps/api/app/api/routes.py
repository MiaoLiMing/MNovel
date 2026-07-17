import re
from uuid import uuid4

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from app.db.database import Database
from app.repositories.catalog import CatalogRepository
from app.schemas.content import (
    Channel,
    ChapterContent,
    ContentSummary,
    FavoriteUpdate,
    PlaybackLine,
    ProgressUpdate,
    SourceImport,
    SourceStatus,
    SourceToggle,
    UnitSummary,
)
from app.core.security import build_token_guard
from app.services.source_guard import UnsafeSourceUrl, validate_public_source_url
from app.services.live_catalog import LiveCatalogService


def create_router(
    database: Database,
    live_catalog: LiveCatalogService | None = None,
    access_token: str = "",
) -> APIRouter:
    router = APIRouter()
    catalog = CatalogRepository()
    remote = live_catalog or LiveCatalogService()
    require_token = build_token_guard(access_token)

    def db() -> Database:
        return database

    def require(content_id: str) -> ContentSummary:
        item = remote.get_cached(content_id) or catalog.get(content_id)
        if item is None:
            raise HTTPException(status_code=404, detail="内容不存在")
        return item

    @router.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "service": "mnovel-api"}

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
        return await remote.discover(selected, query=query)

    @router.get("/discover", response_model=list[ContentSummary])
    async def discover(
        channel: Channel = Channel.novel,
        category: str = Query(default="", max_length=40),
    ) -> list[ContentSummary]:
        return await remote.discover(channel, category=category)

    @router.get("/content/{content_id}", response_model=ContentSummary)
    def detail(content_id: str) -> ContentSummary:
        item = remote.get_cached(content_id) or catalog.get(content_id)
        if item is None:
            raise HTTPException(status_code=404, detail="内容不存在或尚未从目录加载")
        return item

    @router.get("/content/{content_id}/units", response_model=list[UnitSummary])
    def units(content_id: str, limit: int = Query(default=50, ge=1, le=200)) -> list[UnitSummary]:
        item = require(content_id)
        count = min(item.unit_count, limit)
        noun = "章" if item.channel == Channel.novel else "集"
        return [
            UnitSummary(
                id=f"{content_id}-{index + 1}",
                index=index,
                title=f"第 {index + 1} {noun}",
                duration_seconds=None if item.channel == Channel.novel else 720,
            )
            for index in range(count)
        ]

    @router.get("/content/{content_id}/chapters/{chapter_index}", response_model=ChapterContent)
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
        return ChapterContent(
            id=f"{content_id}-{chapter_index + 1}",
            index=chapter_index,
            title=f"第 {chapter_index + 1} 章 风从远山来",
            paragraphs=[
                "晨雾沿着山脊缓慢散开，石阶尽头传来一声清越的剑鸣。",
                "风穿过松林，卷起衣角，也把旧日的疑问重新送到眼前。",
                "远处钟声响起，群山依次回应。少年握紧剑鞘，继续向前。",
            ],
            source_id="local-opds",
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
    def favorite(content_id: str, body: FavoriteUpdate, store: Database = Depends(db)) -> None:
        require(content_id)
        store.set_favorite(content_id, body.channel.value, body.active)

    @router.put("/progress/{content_id}", dependencies=[Depends(require_token)])
    def update_progress(
        content_id: str, body: ProgressUpdate, store: Database = Depends(db)
    ) -> dict[str, bool]:
        require(content_id)
        store.save_progress(content_id, body.channel.value, body.unit_index, body.position)
        return {"saved": True}

    @router.get("/progress/{content_id}", dependencies=[Depends(require_token)])
    def progress(content_id: str, store: Database = Depends(db)) -> dict:
        require(content_id)
        value = store.get_progress(content_id)
        if value is None:
            raise HTTPException(status_code=404, detail="暂无进度")
        return value

    @router.get(
        "/sources",
        response_model=list[SourceStatus],
        dependencies=[Depends(require_token)],
    )
    def sources(store: Database = Depends(db)) -> list[SourceStatus]:
        return [
            SourceStatus(
                id=item["id"],
                name=item["name"],
                kind=item["kind"],
                enabled=item["enabled"],
                priority=item["priority"],
                latency_ms=168 if item["kind"] == "novel" else 204,
            )
            for item in store.list_sources()
        ]

    @router.post(
        "/sources",
        response_model=SourceStatus,
        status_code=status.HTTP_201_CREATED,
        dependencies=[Depends(require_token)],
    )
    def import_source(body: SourceImport, store: Database = Depends(db)) -> SourceStatus:
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
            {"base_url": base_url, "access": "user_configured"},
        )
        return SourceStatus(
            id=source_id,
            name=body.name,
            kind=body.kind,
            enabled=True,
            priority=body.priority,
            health="unchecked",
            latency_ms=0,
        )

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
        return SourceStatus(
            id=item["id"],
            name=item["name"],
            kind=item["kind"],
            enabled=item["enabled"],
            priority=item["priority"],
            health="healthy" if item["enabled"] else "disabled",
            latency_ms=0,
        )

    @router.post(
        "/sources/{source_id}/health",
        response_model=SourceStatus,
        dependencies=[Depends(require_token)],
    )
    def check_source(source_id: str, store: Database = Depends(db)) -> SourceStatus:
        item = store.get_source(source_id)
        if item is None:
            raise HTTPException(status_code=404, detail="内容源不存在")
        config = item["config"]
        base_url = str(config.get("base_url", ""))
        health = "configuration_required" if not base_url else "healthy"
        if config.get("requires_key"):
            health = "api_key_required"
        return SourceStatus(
            id=item["id"],
            name=item["name"],
            kind=item["kind"],
            enabled=item["enabled"],
            priority=item["priority"],
            health=health,
            latency_ms=0,
        )

    return router
