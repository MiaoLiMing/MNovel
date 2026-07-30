from typing import Any

from pydantic import BaseModel, Field


class LegacySource(BaseModel):
    id: str
    name: str
    base_url: str
    group: str
    source_type: str
    enabled: bool = False
    original_enabled: bool = True
    priority: int = 0
    serial_number: int = 0
    user_agent: str = ""
    login_url: str = ""
    compatibility: str
    compatibility_reason: str
    built_in: bool = True
    origin: str
    original_index: int = Field(ge=0)
    reference: str = ""
    rules: dict[str, Any] = Field(default_factory=dict)


class LegacySourceSummary(BaseModel):
    total: int
    compatibility: dict[str, int]
    groups: dict[str, int]


class LegacyBook(BaseModel):
    id: str
    title: str
    author: str = ""
    cover: str = ""
    introduction: str = ""
    kind: str = ""
    latest_chapter: str = ""
    detail_url: str
    source_id: str
    source_name: str


class LegacyChapter(BaseModel):
    index: int = Field(ge=0)
    title: str
    url: str


class LegacyChapterContent(BaseModel):
    title: str
    paragraphs: list[str]
    source_id: str
