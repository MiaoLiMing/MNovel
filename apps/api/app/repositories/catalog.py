from collections.abc import Iterable

from app.schemas.content import (
    Channel,
    ContentDetail,
    ContentSummary,
    FilterGroup,
    FilterOption,
    HomeResponse,
    NovelStatus,
    SearchMeta,
    TaxonomyResponse,
)

# The development API must never invent catalog entries. Real results are
# provided by configured remote/rule sources in the service layer.
CATALOG: list[ContentDetail] = []


class CatalogRepository:
    def __init__(self, catalog: Iterable[ContentDetail] | None = None) -> None:
        self._catalog = list(CATALOG if catalog is None else catalog)

    def list(
        self,
        channel: Channel | None = None,
        query: str = "",
        *,
        category: str = "",
        status: NovelStatus | None = None,
        word_count: str = "",
        source: str = "",
    ) -> list[ContentSummary]:
        normalized = query.strip().casefold()
        return [
            item
            for item in self._catalog
            if (channel is None or item.channel == channel)
            and (
                not normalized
                or normalized in item.title.casefold()
                or normalized in item.creator.casefold()
                or any(normalized in tag.casefold() for tag in item.tags)
            )
            and (
                not category
                or category == "全部"
                or category in item.category
                or category in item.tags
            )
            and (status is None or item.status == status)
            and (not source or source == "全部" or source in item.source_labels)
            and self._matches_word_count(item.word_count, word_count)
        ]

    def get(self, content_id: str) -> ContentDetail | None:
        return next((item for item in self._catalog if item.id == content_id), None)

    def home(self, channel: str = "推荐") -> HomeResponse:
        items = self._catalog
        if channel == "男生":
            items = [item for item in items if "古言" not in item.category]
        elif channel == "女生":
            items = [item for item in items if "女频" in item.tags]
        elif channel == "出版":
            items = [item for item in items if item.status == NovelStatus.completed]
        return HomeResponse(featured=items[0] if items else None, carousel=items[:4], sections=[])

    def taxonomy(self) -> TaxonomyResponse:
        return TaxonomyResponse(
            groups=[
                FilterGroup(
                    id="category",
                    label="题材",
                    options=[
                        FilterOption(value=value, label=value)
                        for value in [
                            "全部", "玄幻", "奇幻", "武侠", "仙侠", "都市",
                            "历史", "军事", "科幻", "游戏", "悬疑", "其他",
                        ]
                    ],
                ),
                FilterGroup(
                    id="status",
                    label="状态",
                    options=[
                        FilterOption(value="all", label="全部"),
                        FilterOption(value="serializing", label="连载中"),
                        FilterOption(value="completed", label="已完结"),
                    ],
                ),
                FilterGroup(
                    id="word_count",
                    label="字数",
                    options=[
                        FilterOption(value=value, label=label)
                        for value, label in [
                            ("all", "全部"),
                            ("under-300k", "30万以下"),
                            ("300k-1m", "30-100万"),
                            ("1m-3m", "100-300万"),
                            ("3m-5m", "300-500万"),
                            ("over-5m", "500万以上"),
                        ]
                    ],
                ),
            ]
        )

    def search_meta(self) -> SearchMeta:
        ordered = sorted(self._catalog, key=lambda item: item.score, reverse=True)
        return SearchMeta(hot=ordered, suggestions=[item.title for item in ordered[:6]])

    @staticmethod
    def _matches_word_count(word_count: int, bucket: str) -> bool:
        if not bucket or bucket == "all":
            return True
        return {
            "under-300k": word_count < 300_000,
            "300k-1m": 300_000 <= word_count < 1_000_000,
            "1m-3m": 1_000_000 <= word_count < 3_000_000,
            "3m-5m": 3_000_000 <= word_count < 5_000_000,
            "over-5m": word_count >= 5_000_000,
        }.get(bucket, True)
