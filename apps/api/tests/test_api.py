import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.routes import create_router
from app.db.database import Database
from app.services.live_catalog import LiveCatalogService


class ApiTestCase(unittest.TestCase):
    token = "test-only-token"

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        database = Database(Path(self.temp.name) / "test.db")
        database.initialize()
        app = FastAPI()
        app.include_router(
            create_router(
                database,
                LiveCatalogService(enabled=False),
                access_token=self.token,
            ),
            prefix="/api/v1",
        )
        self.client = TestClient(app)

    @property
    def auth(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.token}"}

    def tearDown(self) -> None:
        self.client.close()
        self.temp.cleanup()

    def test_health_and_discover(self) -> None:
        self.assertEqual(self.client.get("/api/v1/health").status_code, 200)
        response = self.client.get("/api/v1/discover", params={"channel": "novel"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), [])

    def test_missing_server_token_fails_closed(self) -> None:
        database = Database(Path(self.temp.name) / "no-token.db")
        database.initialize()
        app = FastAPI()
        app.include_router(create_router(database, access_token=""), prefix="/api/v1")
        with TestClient(app) as client:
            response = client.get("/api/v1/sources")
        self.assertEqual(response.status_code, 503)

    def test_progress_roundtrip(self) -> None:
        self.assertEqual(
            self.client.get("/api/v1/progress/novel-sword").status_code,
            401,
        )
        response = self.client.put(
            "/api/v1/progress/novel-sword",
            json={"channel": "novel", "unit_index": 8, "position": 0.42},
            headers=self.auth,
        )
        self.assertEqual(response.status_code, 200)
        saved = self.client.get(
            "/api/v1/progress/novel-sword",
            headers=self.auth,
        ).json()
        self.assertEqual(saved["unit_index"], 8)
        self.assertEqual(saved["position"], 0.42)

    def test_media_playback_contract(self) -> None:
        response = self.client.post(
            "/api/v1/content/drama-fog/episodes/0/playback",
            headers=self.auth,
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()[0]["protocol"], "demo")

    def test_built_in_sources_and_toggle(self) -> None:
        response = self.client.get("/api/v1/sources", headers=self.auth)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()), 8)
        source = next(item for item in response.json() if item["id"] == "tmdb")
        self.assertFalse(source["enabled"])

        toggled = self.client.put(
            "/api/v1/sources/tmdb/enabled",
            json={"enabled": True},
            headers=self.auth,
        )
        self.assertEqual(toggled.status_code, 200)
        self.assertTrue(toggled.json()["enabled"])

        health = self.client.post("/api/v1/sources/tmdb/health", headers=self.auth)
        self.assertEqual(health.json()["health"], "api_key_required")

    def test_import_source_validates_public_url(self) -> None:
        rejected = self.client.post(
            "/api/v1/sources",
            json={
                "name": "私网源",
                "kind": "novel",
                "base_url": "http://127.0.0.1/catalog.json",
            },
            headers=self.auth,
        )
        self.assertEqual(rejected.status_code, 400)

        with patch(
            "app.api.routes.validate_public_source_url",
            return_value="https://example.com/catalog.json",
        ):
            imported = self.client.post(
                "/api/v1/sources",
                json={
                    "name": "自定义目录",
                    "kind": "novel",
                    "base_url": "https://example.com/catalog.json",
                    "priority": 60,
                },
                headers=self.auth,
            )
        self.assertEqual(imported.status_code, 201)
        self.assertEqual(imported.json()["health"], "unchecked")


if __name__ == "__main__":
    unittest.main()
