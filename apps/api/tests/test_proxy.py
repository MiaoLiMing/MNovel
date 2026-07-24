import urllib.parse


def test_proxy_video_master_and_key_fallback(client):
    master_url = "https://play.hhuus.com/play/dyP9ryVb/index.m3u8"
    response = client.get(
        f"/api/v1/mnovel/proxy/video?url={urllib.parse.quote(master_url)}"
    )
    assert response.status_code == 200
    assert "master_url=" in response.text

    key_url = "https://play.hhuus.com/20241215/kS6LzTdr/enc.key"
    key_response = client.get(
        f"/api/v1/mnovel/proxy/video?url={urllib.parse.quote(key_url)}&master_url={urllib.parse.quote(master_url)}"
    )
    assert key_response.status_code == 200
    assert len(key_response.content) == 16
