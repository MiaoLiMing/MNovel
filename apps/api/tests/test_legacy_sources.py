from pathlib import Path

import pytest

from app.schemas.legacy_sources import LegacySource
from app.services.legacy_rule_engine import LegacyRuleEngine, RequestSpec
from app.services.legacy_source_catalog import LegacySourceCatalog


class FixtureHttpClient:
    async def request(
        self,
        spec: RequestSpec,
        *,
        user_agent: str = "",
    ) -> tuple[str, str]:
        if "/search" in spec.url:
            return (
                """
                <ul class="result">
                  <li><a href="/book/1">测试小说</a><span>测试作者</span></li>
                </ul>
                """,
                "https://example.com/search?q=test",
            )
        if "/book/1" in spec.url:
            return (
                """
                <div class="chapters">
                  <a href="/chapter/1">第一章</a>
                  <a href="/chapter/2">第二章</a>
                </div>
                """,
                "https://example.com/book/1",
            )
        return (
            '<article id="content">第一段<br>第二段</article>',
            "https://example.com/chapter/1",
        )


def fixture_source() -> LegacySource:
    return LegacySource(
        id="legacy-test",
        name="测试源",
        base_url="https://example.com",
        group="测试",
        source_type="NOVEL",
        compatibility="compatible_core",
        compatibility_reason="测试",
        origin="fixture",
        original_index=0,
        rules={
            "ruleSearchUrl": "/search?q=searchKey&page=searchPage",
            "ruleSearchList": "class.result@tag.li",
            "ruleSearchName": "tag.a@text",
            "ruleSearchAuthor": "tag.span@text",
            "ruleSearchNoteUrl": "tag.a@href",
            "ruleChapterList": "class.chapters@tag.a",
            "ruleChapterName": "text",
            "ruleContentUrl": "href",
            "ruleBookContent": "id.content@textNodes",
        },
    )


def test_catalog_contains_all_apk_records():
    path = (
        Path(__file__).resolve().parents[3]
        / "data/book_sources/legacy_sources.json"
    )
    summary = LegacySourceCatalog(path).summary()
    assert summary.total == 1142
    assert sum(summary.compatibility.values()) == 1142


def test_legacy_catalog_api_can_filter(client):
    summary = client.get("/api/v1/mnovel/sources/legacy/summary")
    assert summary.status_code == 200
    assert summary.json()["total"] == 1142

    response = client.get(
        "/api/v1/mnovel/sources/legacy",
        params={"query": "reader.browser.miui.com", "limit": 20},
    )
    assert response.status_code == 200
    assert any("免费小说之王" in item["name"] for item in response.json())


@pytest.mark.asyncio
async def test_html_rule_chain():
    engine = LegacyRuleEngine(http_client=FixtureHttpClient())
    source = fixture_source()

    books = await engine.search(source, "test")
    assert [book.title for book in books] == ["测试小说"]
    assert books[0].author == "测试作者"

    chapters = await engine.chapters(source, books[0].detail_url)
    assert [chapter.title for chapter in chapters] == ["第一章", "第二章"]

    paragraphs = await engine.chapter_content(source, chapters[0].url)
    assert paragraphs == ["第一段", "第二段"]
