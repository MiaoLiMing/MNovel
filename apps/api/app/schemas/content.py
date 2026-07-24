from enum import StrEnum

from pydantic import BaseModel, Field, HttpUrl


class Channel(StrEnum):
    novel = "novel"
    short_drama = "shortDrama"
    video = "video"


class NovelStatus(StrEnum):
    serializing = "serializing"
    completed = "completed"


class ContentSummary(BaseModel):
    id: str
    channel: Channel = Channel.novel
    title: str
    creator: str
    category: str
    summary: str
    cover: str
    popularity: str
    unit_count: int = Field(ge=0)
    source_count: int = Field(default=1, ge=0)
    source_id: str = "local"
    source_name: str = "内置书库"
    is_live: bool = False
    score: float = Field(default=0, ge=0, le=10)
    word_count: int = Field(default=0, ge=0)
    status: NovelStatus = NovelStatus.serializing
    latest_chapter: str = ""
    tags: list[str] = Field(default_factory=list)
    source_labels: list[str] = Field(default_factory=list)
    accent: str = "#FF5A3C"


class ContentDetail(ContentSummary):
    rating_count: int = Field(default=0, ge=0)
    update_frequency: str = "持续更新"
    copyright_notice: str = "内容由对应书源提供"


class HomeSection(BaseModel):
    id: str
    title: str
    action_label: str = "更多"
    items: list[ContentSummary]


class HomeResponse(BaseModel):
    featured: ContentSummary
    carousel: list[ContentSummary]
    sections: list[HomeSection]


class FilterOption(BaseModel):
    value: str
    label: str


class FilterGroup(BaseModel):
    id: str
    label: str
    multiple: bool = False
    options: list[FilterOption]


class TaxonomyResponse(BaseModel):
    groups: list[FilterGroup]


class SearchMeta(BaseModel):
    hot: list[ContentSummary]
    suggestions: list[str]


class UnitSummary(BaseModel):
    id: str
    index: int = Field(ge=0)
    title: str
    duration_seconds: int | None = Field(default=None, ge=0)
    updated_at: str | None = None


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


class ProgressStatus(BaseModel):
    content_id: str
    channel: Channel
    unit_index: int
    position: float
    updated_at: str


class HistoryItem(BaseModel):
    content: ContentSummary
    unit_index: int = 0
    position: float = 0
    updated_at: str = ""


class ReaderSummary(BaseModel):
    shelf_count: int = 0
    reading_hours: float = 0
    completed_count: int = 0
    history_count: int = 0


class SourceImport(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    kind: str = Field(pattern="^(novel|shortDrama|video|media|json|js)$")
    base_url: HttpUrl
    priority: int = Field(default=50, ge=0, le=999)


class SourceUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    base_url: HttpUrl | None = None
    priority: int | None = Field(default=None, ge=0, le=999)


class SourceToggle(BaseModel):
    enabled: bool


class SourceOrderUpdate(BaseModel):
    source_ids: list[str] = Field(min_length=1)


class SourceStatus(BaseModel):
    id: str
    name: str
    kind: str
    enabled: bool
    priority: int
    health: str = "healthy"
    latency_ms: int = 0
    base_url: str = ""
    built_in: bool = False
    last_checked: str | None = None
