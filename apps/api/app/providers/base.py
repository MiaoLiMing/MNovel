import re
import urllib.parse

import httpx
from typing import List, Optional
from app.schemas.videos import VideoDetail, VideoSimple


class BaseProvider:
    """
    影视源解析基类
    """

    def __init__(
        self, source_id: int, name: str, api_url: str, ext_config: Optional[str] = None
    ):
        self.source_id = source_id
        self.name = name
        self.api_url = api_url
        self.ext_config = ext_config
        self.timeout = 10
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }

    async def search(self, keyword: str, page: int = 1) -> List[VideoSimple]:
        """
        根据关键字搜索视频
        """
        raise NotImplementedError

    async def get_latest(
        self, category_id: Optional[str] = None, page: int = 1
    ) -> List[VideoSimple]:
        """
        获取最新更新的视频列表
        """
        raise NotImplementedError

    async def get_detail(self, video_id: str) -> Optional[VideoDetail]:
        """
        获取视频详情与播放选集列表
        """
        raise NotImplementedError

    async def parse_play_url(self, play_url: str) -> str:
        """
        将网页播放线路解析为真实媒体地址；已经是媒体直链时原样返回。
        """
        if re.search(r"\.(?:m3u8|mp4|m4v|mov|webm)(?:$|[?#])", play_url, re.I):
            return play_url

        try:
            async with httpx.AsyncClient(
                timeout=10,
                follow_redirects=True,
                verify=False,
            ) as client:
                response = await client.get(play_url, headers=self.headers)
                response.raise_for_status()
            body = response.text.replace(r"\/", "/")
            patterns = (
                r"(?:url|src|file)\s*[:=]\s*['\"]([^'\"]+\.(?:m3u8|mp4)(?:\?[^'\"]*)?)['\"]",
                r"['\"]([^'\"]+\.(?:m3u8|mp4)(?:\?[^'\"]*)?)['\"]",
            )
            for pattern in patterns:
                match = re.search(pattern, body, re.I)
                if match:
                    return urllib.parse.urljoin(str(response.url), match.group(1))
        except Exception:
            return play_url
        return play_url
