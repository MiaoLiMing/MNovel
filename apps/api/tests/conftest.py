import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes import create_router
from app.db.database import Database


@pytest.fixture
def client(tmp_path):
    database = Database(tmp_path / "test.db")
    database.initialize()
    app = FastAPI()
    app.include_router(create_router(database), prefix="/api/v1/mnovel")
    with TestClient(app) as test_client:
        yield test_client
