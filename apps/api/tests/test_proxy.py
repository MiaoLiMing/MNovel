import asyncio
import urllib.parse

import httpx


def test_proxy_video_master_and_key_fallback(client, monkeypatch):
    master_url = "https://play.hhuus.com/play/dyP9ryVb/index.m3u8"
    key_url = "https://play.hhuus.com/20241215/kS6LzTdr/enc.key"

    def handle(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith(".m3u8"):
            return httpx.Response(
                200,
                text='#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="../enc.key"\nsegment.ts',
                headers={"content-type": "application/vnd.apple.mpegurl"},
                request=request,
            )
        if request.url.path.endswith(".key"):
            return httpx.Response(200, content=b"0123456789abcdef", request=request)
        return httpx.Response(404, request=request)

    upstream = httpx.AsyncClient(transport=httpx.MockTransport(handle))
    client.app.state.video_http_client = upstream
    monkeypatch.setattr(
        "app.api.routes.validate_public_source_url", lambda value: value
    )
    try:
        response = client.get(
            f"/api/v1/mnovel/proxy/video?url={urllib.parse.quote(master_url)}"
        )
        assert response.status_code == 200
        assert "master_url=" in response.text

        key_response = client.get(
            f"/api/v1/mnovel/proxy/video?url={urllib.parse.quote(key_url)}&master_url={urllib.parse.quote(master_url)}"
        )
        assert key_response.status_code == 200
        assert key_response.content == b"0123456789abcdef"
    finally:
        asyncio.run(upstream.aclose())
