from collections.abc import Iterable

from app.schemas.content import (
    Channel,
    ContentDetail,
    ContentSummary,
    FilterGroup,
    FilterOption,
    HomeResponse,
    HomeSection,
    NovelStatus,
    SearchMeta,
    TaxonomyResponse,
)


def _book(
    *,
    book_id: str,
    title: str,
    creator: str,
    category: str,
    summary: str,
    cover: str,
    popularity: str,
    unit_count: int,
    score: float,
    word_count: int,
    status: NovelStatus,
    latest_chapter: str,
    tags: list[str],
    source_labels: list[str],
) -> ContentDetail:
    return ContentDetail(
        id=book_id,
        channel=Channel.novel,
        title=title,
        creator=creator,
        category=category,
        summary=summary,
        cover=cover,
        popularity=popularity,
        unit_count=unit_count,
        source_count=len(source_labels),
        source_id="mnovel-curated",
        source_name=source_labels[0],
        is_live=False,
        score=score,
        word_count=word_count,
        status=status,
        latest_chapter=latest_chapter,
        tags=tags,
        source_labels=source_labels,
        rating_count=max(1200, int(score * 2350)),
        update_frequency="每日更新" if status == NovelStatus.serializing else "已完结",
        copyright_notice="本地书目仅用于聚合索引，正文由用户配置的可用书源提供。",
    )


CATALOG: list[ContentDetail] = [
    _book(
        book_id="novel-mystery-lord",
        title="诡秘之主",
        creator="爱潜水的乌贼",
        category="玄幻 · 西方奇幻",
        summary="蒸汽与机械的浪潮中，谁能触及非凡？历史和黑暗的迷雾里，又是谁在耳语？这是一个关于诡秘、命运与自我选择的故事。",
        cover="asset://design/cover-mystery-lord.png",
        popularity="23.5 万人在读",
        unit_count=1432,
        score=9.6,
        word_count=4460000,
        status=NovelStatus.completed,
        latest_chapter="第1432章 新的旅程",
        tags=["玄幻", "完结", "高口碑"],
        source_labels=["起点中文网", "纵横中文网", "番茄小说", "七猫小说", "自定义书源"],
    ),
    _book(
        book_id="novel-fate-ring",
        title="宿命之环",
        creator="爱潜水的乌贼",
        category="玄幻 · 异世大陆",
        summary="命运的齿轮在迷雾中悄然转动，少年循着梦境和秘仪留下的痕迹，走入一个被宿命环绕的世界。",
        cover="asset://design/cover-fate-ring.png",
        popularity="12.6 万人在读",
        unit_count=868,
        score=9.4,
        word_count=3100000,
        status=NovelStatus.serializing,
        latest_chapter="第868章 环与门",
        tags=["玄幻", "连载中", "诡秘"],
        source_labels=["起点中文网", "纵横中文网", "自定义书源"],
    ),
    _book(
        book_id="novel-sword-arrival",
        title="剑来",
        creator="烽火戏诸侯",
        category="仙侠 · 古典仙侠",
        summary="大千世界，无奇不有。一个贫寒少年从小镇出发，仗剑远游，看天地、见众生，也在漫长道路上寻找自己的答案。",
        cover="asset://design/cover-sword-arrival.png",
        popularity="9.8 万人在读",
        unit_count=1120,
        score=9.3,
        word_count=12000000,
        status=NovelStatus.serializing,
        latest_chapter="第1120章 山雨入城",
        tags=["仙侠", "连载中", "剑道"],
        source_labels=["纵横中文网", "七猫小说", "自定义书源"],
    ),
    _book(
        book_id="novel-weird-immortal",
        title="道诡异仙",
        creator="狐尾的笔",
        category="仙侠 · 幻想修仙",
        summary="真实与虚幻交错，诡谲的世界没有可靠的答案。少年必须在混乱中守住自己，也守住那些仍值得相信的人。",
        cover="asset://design/cover-weird-immortal.png",
        popularity="8.7 万人在读",
        unit_count=1058,
        score=9.1,
        word_count=2200000,
        status=NovelStatus.completed,
        latest_chapter="第1058章 归途",
        tags=["仙侠", "完结", "悬疑"],
        source_labels=["起点中文网", "番茄小说", "自定义书源"],
    ),
    _book(
        book_id="novel-night-guard",
        title="大奉打更人",
        creator="卖报小郎君",
        category="仙侠 · 东方玄幻",
        summary="现代思维落入古代王朝，一名打更人从离奇案件出发，拨开朝堂、江湖与术法交织的层层迷雾。",
        cover="asset://design/cover-night-guard.png",
        popularity="4.8 万人在读",
        unit_count=910,
        score=9.0,
        word_count=3820000,
        status=NovelStatus.completed,
        latest_chapter="第910章 人间长安",
        tags=["仙侠", "完结", "探案"],
        source_labels=["起点中文网", "七猫小说", "自定义书源"],
    ),
    _book(
        book_id="novel-red-heart",
        title="赤心巡天",
        creator="情何以甚",
        category="仙侠 · 古典仙侠",
        summary="山河万里，少年以一颗赤心丈量天地，在漫长仙途中辨善恶、见真我。",
        cover="asset://design/cover-red-heart.png",
        popularity="7.1 万人在读",
        unit_count=1516,
        score=9.2,
        word_count=7200000,
        status=NovelStatus.serializing,
        latest_chapter="第1516章 天涯同路",
        tags=["仙侠", "连载中", "群像"],
        source_labels=["起点中文网", "纵横中文网", "自定义书源"],
    ),
    _book(
        book_id="novel-chaotic-era",
        title="乱世书",
        creator="姬叉",
        category="武侠 · 幻想武侠",
        summary="乱世如书，每一页都写着江湖与庙堂。来客执刀入局，也把自己的名字写进时代。",
        cover="asset://design/cover-chaotic-era.png",
        popularity="6.3 万人在读",
        unit_count=788,
        score=8.9,
        word_count=2050000,
        status=NovelStatus.completed,
        latest_chapter="第788章 书尽人间",
        tags=["武侠", "完结", "江湖"],
        source_labels=["起点中文网", "番茄小说", "自定义书源"],
    ),
    _book(
        book_id="novel-judge",
        title="我在阴府当判官",
        creator="三九音域",
        category="都市 · 灵异",
        summary="城市灯火之下，古老秩序从未远去。年轻判官在一桩桩异闻中维护阴阳两界的边界。",
        cover="asset://design/cover-underworld-judge.png",
        popularity="5.2 万人在读",
        unit_count=672,
        score=8.8,
        word_count=1890000,
        status=NovelStatus.serializing,
        latest_chapter="第672章 子夜来客",
        tags=["都市", "连载中", "灵异"],
        source_labels=["番茄小说", "七猫小说", "自定义书源"],
    ),
]


class CatalogRepository:
    def __init__(self, catalog: Iterable[ContentDetail] | None = None) -> None:
        self._catalog = list(catalog or CATALOG)

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
        items = [
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
        return items

    def get(self, content_id: str) -> ContentDetail | None:
        return next((item for item in self._catalog if item.id == content_id), None)

    def home(self, channel: str = "推荐") -> HomeResponse:
        items = self._catalog
        if channel == "男生":
            items = [item for item in items if "古言" not in item.category]
        elif channel == "女生":
            items = [item for item in items if item.id in {"novel-judge", "novel-fate-ring"}]
        elif channel == "出版":
            items = [item for item in items if item.status == NovelStatus.completed]
        if not items:
            items = self._catalog
        return HomeResponse(
            featured=items[1] if len(items) > 1 else items[0],
            carousel=items[:4],
            sections=[
                HomeSection(
                    id="editors-pick",
                    title="精选推荐",
                    action_label="换一换",
                    items=items[2:6] or items[:4],
                ),
                HomeSection(
                    id="latest",
                    title="最近上新",
                    action_label="更多",
                    items=list(reversed(items[-5:])),
                ),
            ],
        )

    def taxonomy(self) -> TaxonomyResponse:
        return TaxonomyResponse(
            groups=[
                FilterGroup(
                    id="category",
                    label="题材",
                    options=[
                        FilterOption(value=value, label=value)
                        for value in [
                            "全部",
                            "玄幻",
                            "奇幻",
                            "武侠",
                            "仙侠",
                            "都市",
                            "历史",
                            "军事",
                            "科幻",
                            "游戏",
                            "悬疑",
                            "其他",
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
                FilterGroup(
                    id="source",
                    label="来源",
                    options=[
                        FilterOption(value=value, label=value)
                        for value in [
                            "全部",
                            "起点中文网",
                            "纵横中文网",
                            "番茄小说",
                            "七猫小说",
                            "飞卢小说",
                            "刺猬猫",
                            "自定义书源",
                        ]
                    ],
                ),
            ]
        )

    def search_meta(self) -> SearchMeta:
        ordered = sorted(self._catalog, key=lambda item: item.score, reverse=True)
        return SearchMeta(
            hot=ordered,
            suggestions=[item.title for item in ordered[:6]],
        )

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
