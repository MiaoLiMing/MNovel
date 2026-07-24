def test_videos_latest(client):
    response = client.get("/api/v1/mnovel/videos/latest")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)


def test_videos_search(client):
    response = client.get("/api/v1/mnovel/videos/search?wd=维多利亚")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)


def test_videos_parse(client):
    test_url = "https://play.hhuus.com/play/dyP9ryVb/index.m3u8"
    response = client.get(
        f"/api/v1/mnovel/videos/parse?source_id=1&play_url={test_url}"
    )
    assert response.status_code == 200
    data = response.json()
    assert "url" in data
    assert "headers" in data
    assert "parse_type" in data
