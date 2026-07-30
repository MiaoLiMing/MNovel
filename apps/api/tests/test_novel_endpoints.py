def test_catalog_discovery_and_reader_contract(client):
    home = client.get("/api/v1/mnovel/home?channel=推荐")
    assert home.status_code == 200
    home_data = home.json()
    assert home_data["featured"]["channel"] == "novel"
    assert home_data["sections"] == []

    taxonomy = client.get("/api/v1/mnovel/taxonomy")
    assert taxonomy.status_code == 200
    assert {group["id"] for group in taxonomy.json()["groups"]} == {
        "category",
        "status",
        "word_count",
    }

    content_id = home_data["featured"]["id"]
    title = home_data["featured"]["title"]
    search = client.get("/api/v1/mnovel/search", params={"query": title})
    assert search.status_code == 200
    assert any(item["id"] == content_id for item in search.json())

    filtered = client.get(
        "/api/v1/mnovel/discover",
        params={"channel": "novel", "status": "serializing"},
    )
    assert filtered.status_code == 200
    assert all(item["status"] == "serializing" for item in filtered.json())

    detail = client.get(f"/api/v1/mnovel/content/{content_id}")
    assert detail.status_code == 200
    assert detail.json()["source_count"] >= 1

    units = client.get(
        f"/api/v1/mnovel/content/{content_id}/units",
        params={"offset": 0, "limit": 3},
    )
    assert units.status_code == 200
    assert [unit["index"] for unit in units.json()] == [0, 1, 2]

    chapter = client.get(f"/api/v1/mnovel/content/{content_id}/chapters/0")
    assert chapter.status_code == 424
    assert "没有可用正文" in chapter.json()["detail"]


def test_shelf_progress_history_and_summary(client):
    content_id = client.get("/api/v1/mnovel/home").json()["featured"]["id"]

    favorite = client.put(
        f"/api/v1/mnovel/favorites/{content_id}",
        json={"channel": "novel", "active": True},
    )
    assert favorite.status_code == 204
    assert [item["id"] for item in client.get("/api/v1/mnovel/favorites").json()] == [
        content_id
    ]

    progress = client.put(
        f"/api/v1/mnovel/progress/{content_id}",
        json={"channel": "novel", "unit_index": 4, "position": 0.5},
    )
    assert progress.status_code == 200
    saved = client.get(f"/api/v1/mnovel/progress/{content_id}")
    assert saved.status_code == 200
    assert saved.json()["unit_index"] == 4
    assert saved.json()["position"] == 0.5

    history = client.get("/api/v1/mnovel/history")
    assert history.status_code == 200
    assert history.json()[0]["content"]["id"] == content_id

    summary = client.get("/api/v1/mnovel/me/summary")
    assert summary.status_code == 200
    assert summary.json()["shelf_count"] == 1
    assert summary.json()["history_count"] == 1


def test_source_crud_and_order(client, monkeypatch):
    monkeypatch.setattr(
        "app.api.routes.validate_public_source_url", lambda value: value
    )
    initial = client.get("/api/v1/mnovel/sources")
    assert initial.status_code == 200
    assert initial.json()

    created = client.post(
        "/api/v1/mnovel/sources",
        json={
            "name": "测试书源",
            "kind": "json",
            "base_url": "https://books.example.com/catalog.json",
            "priority": 88,
        },
    )
    assert created.status_code == 201
    source_id = created.json()["id"]
    assert created.json()["health"] == "unchecked"

    updated = client.patch(
        f"/api/v1/mnovel/sources/{source_id}",
        json={"name": "测试书源二", "priority": 99},
    )
    assert updated.status_code == 200
    assert updated.json()["name"] == "测试书源二"

    disabled = client.put(
        f"/api/v1/mnovel/sources/{source_id}/enabled", json={"enabled": False}
    )
    assert disabled.status_code == 200
    assert disabled.json()["health"] == "disabled"

    reordered = client.put(
        "/api/v1/mnovel/sources/order", json={"source_ids": [source_id]}
    )
    assert reordered.status_code == 200
    assert reordered.json()[0]["id"] == source_id

    deleted = client.delete(f"/api/v1/mnovel/sources/{source_id}")
    assert deleted.status_code == 204
    assert all(
        source["id"] != source_id
        for source in client.get("/api/v1/mnovel/sources").json()
    )
