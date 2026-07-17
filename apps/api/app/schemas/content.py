from enum import StrEnum

from pydantic import BaseModel, Field, HttpUrl


class Channel(StrEnum):
    novel = "novel"
    short_drama = "shortDrama"
    video = "video"


class ContentSummary(BaseModel):
    id: str
    channel: Channel
    title: str
    creator: str
    category: str
    summary: str
    cover: str
    popularity: str
    unit_count: int = Field(ge=0)
    source_count: int = Field(default=1, ge=0)
    source_id: str = "local"
    source_name: str = "本地内容"
    is_live: bool = False


class UnitSummary(BaseModel):
    id: str
    index: int = Field(ge=0)
    title: str
    duration_seconds: int | None = Field(default=None, ge=0)


class ChapterContent(BaseModel):
    id: str
    index: int
    title: str
    paragraphs: list[str]
    source_id: str


class PlaybackLine(BaseModel):
    id: str
    label: str
    protocol: str
    quality: str
    url: str
    expires_in: int = Field(ge=0)
    drm: str | None = None


class FavoriteUpdate(BaseModel):
    channel: Channel
    active: bool


class ProgressUpdate(BaseModel):
    channel: Channel
    unit_index: int = Field(ge=0)
    position: float = Field(ge=0, le=1)


class SourceImport(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    kind: str = Field(pattern="^(novel|shortDrama|video|media)$")
    base_url: HttpUrl
    priority: int = Field(default=50, ge=0, le=999)


class SourceToggle(BaseModel):
    enabled: bool


class SourceStatus(BaseModel):
    id: str
    name: str
    kind: str
    enabled: bool
    priority: int
    health: str = "healthy"
    latency_ms: int = 0
