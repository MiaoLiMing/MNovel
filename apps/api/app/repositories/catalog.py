from app.schemas.content import Channel, ContentSummary


CATALOG = [
    ContentSummary(
        id="novel-sword",
        channel=Channel.novel,
        title="长风问剑",
        creator="山止川行",
        category="仙侠 · 剑道",
        summary="少年从边城启程，在山河与人心之间寻找自己的剑道。",
        cover="asset://cover-changfeng-wenjian.png",
        popularity="128 万在读",
        unit_count=1268,
        source_count=3,
    ),
    ContentSummary(
        id="novel-stars",
        channel=Channel.novel,
        title="星海余烬",
        creator="拾光者",
        category="科幻 · 星际",
        summary="旧世界沉入星海，最后一座空间城在余烬中寻找新的航路。",
        cover="asset://cover-xinghai-yujin.png",
        popularity="96 万在读",
        unit_count=486,
        source_count=2,
    ),
    ContentSummary(
        id="novel-phoenix",
        channel=Channel.novel,
        title="凤归长安",
        creator="青梅煮雪",
        category="古言 · 权谋",
        summary="一封旧案卷宗，让她重回长安，也重新走进那场未完的风雪。",
        cover="asset://cover-fenggui-changan.png",
        popularity="78 万在读",
        unit_count=392,
        source_count=3,
    ),
    ContentSummary(
        id="drama-fog",
        channel=Channel.short_drama,
        title="雾城回响",
        creator="青岚影业",
        category="悬疑 · 都市",
        summary="记者与刑警追查一段消失的录音。",
        cover="asset://poster-wucheng-huixiang.png",
        popularity="382 万热度",
        unit_count=36,
        source_count=2,
    ),
    ContentSummary(
        id="video-mountain",
        channel=Channel.video,
        title="远山之下",
        creator="原野纪录",
        category="纪录片 · 自然",
        summary="沿着雪线与河谷前行，记录人与高山之间的关系。",
        cover="asset://poster-yuanshan-zhixia.png",
        popularity="9.2 分",
        unit_count=6,
        source_count=2,
    ),
]


class CatalogRepository:
    def list(self, channel: Channel | None = None, query: str = "") -> list[ContentSummary]:
        normalized = query.strip().casefold()
        return [
            item
            for item in CATALOG
            if (channel is None or item.channel == channel)
            and (
                not normalized
                or normalized in item.title.casefold()
                or normalized in item.creator.casefold()
            )
        ]

    def get(self, content_id: str) -> ContentSummary | None:
        return next((item for item in CATALOG if item.id == content_id), None)
