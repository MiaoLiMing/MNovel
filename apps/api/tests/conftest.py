import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes import create_router
from app.db.database import Database
from app.repositories.catalog import CatalogRepository
from app.schemas.content import ContentDetail


@pytest.fixture
def client(tmp_path):
    database = Database(tmp_path / "test.db")
    database.initialize()
    app = FastAPI()
    fixture = ContentDetail(
        id="fixture-book",
        title="接口测试书目",
        creator="测试作者",
        category="测试分类",
        summary="仅存在于自动化测试中的书目。",
        cover="",
        popularity="",
        unit_count=3,
        source_id="fixture",
        source_name="测试夹具",
        source_labels=["测试夹具"],
    )
    app.include_router(
        create_router(
            database,
            catalog_repository=CatalogRepository([fixture]),
        ),
        prefix="/api/v1/mnovel",
    )
    with TestClient(app) as test_client:
        yield test_client
