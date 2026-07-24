def test_list_sources(client):
    response = client.get("/api/v1/mnovel/provider/sources")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 3
    builtin_names = [s["name"] for s in data if s.get("built_in")]
    assert "豪华资源" in builtin_names
    assert "暴风资源" in builtin_names
    assert "无尽资源" in builtin_names


def test_cannot_delete_builtin_source(client):
    response = client.delete("/api/v1/mnovel/provider/sources/1")
    assert response.status_code == 400
    assert "内置源不可删除" in response.json()["detail"]


def test_add_and_delete_custom_source(client):
    add_res = client.post(
        "/api/v1/mnovel/provider/sources?name=自定义源&api_url=https://custom.com/api.php&channel=video"
    )
    assert add_res.status_code == 200
    data = add_res.json()
    assert data["name"] == "自定义源"
    assert not data["built_in"]
    new_id = data["id"]

    del_res = client.delete(f"/api/v1/mnovel/provider/sources/{new_id}")
    assert del_res.status_code == 200
    assert del_res.json()["status"] == "success"
