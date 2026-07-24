import httpx
import logging
from typing import List, Optional, Dict
from app.providers.base import BaseProvider
from app.schemas.videos import VideoSimple, VideoDetail, Episode

logger = logging.getLogger(__name__)


class CmsJsonProvider(BaseProvider):
    """
    对接苹果CMS等支持JSON输出的接口
    """

    def _parse_play_url_field(
        self, play_from: str, play_url: str
    ) -> Dict[str, List[Episode]]:
        result = {}
        if not play_url:
            return result

        from_list = play_from.split("$$$") if play_from else ["默认线路"]
        url_list = play_url.split("$$$")

        for i, urls_str in enumerate(url_list):
            line_name = from_list[i] if i < len(from_list) else f"线路 {i + 1}"
            episodes = []

            ep_strs = urls_str.split("#")
            for ep_str in ep_strs:
                if not ep_str:
                    continue
                parts = ep_str.split("$")
                if len(parts) >= 2:
                    name = parts[0].strip()
                    url = parts[1].strip()
                elif len(parts) == 1:
                    name = f"第 {len(episodes) + 1} 集"
                    url = parts[0].strip()
                else:
                    continue

                if url:
                    episodes.append(Episode(name=name, url=url))

            if episodes:
                result[line_name] = episodes

        return result

    async def search(self, keyword: str, page: int = 1) -> List[VideoSimple]:
        url = f"{self.api_url}?ac=detail&wd={keyword}&pg={page}"
        try:
            async with httpx.AsyncClient(verify=False) as client:
                response = await client.get(
                    url, headers=self.headers, timeout=self.timeout
                )
                if response.status_code == 200:
                    data = response.json()
                    vod_list = data.get("list", [])
                    results = []
                    for item in vod_list:
                        results.append(
                            VideoSimple(
                                id=str(item.get("vod_id")),
                                source_id=self.source_id,
                                source_name=self.name,
                                title=item.get("vod_name", ""),
                                cover=item.get("vod_pic"),
                                category=item.get("type_name"),
                                remarks=item.get("vod_remarks"),
                            )
                        )
                    return results
        except Exception as e:
            logger.error(f"CMS {self.name} search error: {e}")
        return []

    async def get_latest(
        self, category_id: Optional[str] = None, page: int = 1
    ) -> List[VideoSimple]:
        url = f"{self.api_url}?ac=detail&pg={page}"
        if category_id:
            url += f"&t={category_id}"

        try:
            async with httpx.AsyncClient(verify=False) as client:
                response = await client.get(
                    url, headers=self.headers, timeout=self.timeout
                )
                if response.status_code == 200:
                    data = response.json()
                    vod_list = data.get("list", [])
                    results = []
                    for item in vod_list:
                        results.append(
                            VideoSimple(
                                id=str(item.get("vod_id")),
                                source_id=self.source_id,
                                source_name=self.name,
                                title=item.get("vod_name", ""),
                                cover=item.get("vod_pic"),
                                category=item.get("type_name"),
                                remarks=item.get("vod_remarks"),
                            )
                        )
                    return results
        except Exception as e:
            logger.error(f"CMS {self.name} get_latest error: {e}")
        return []

    async def get_detail(self, video_id: str) -> Optional[VideoDetail]:
        url = f"{self.api_url}?ac=detail&ids={video_id}"
        try:
            async with httpx.AsyncClient(verify=False) as client:
                response = await client.get(
                    url, headers=self.headers, timeout=self.timeout
                )
                if response.status_code == 200:
                    data = response.json()
                    vod_list = data.get("list", [])
                    if not vod_list:
                        return None

                    item = vod_list[0]
                    play_from = item.get("vod_play_from", "")
                    play_url = item.get("vod_play_url", "")
                    playlists = self._parse_play_url_field(play_from, play_url)

                    return VideoDetail(
                        id=str(item.get("vod_id")),
                        source_id=self.source_id,
                        source_name=self.name,
                        title=item.get("vod_name", ""),
                        cover=item.get("vod_pic"),
                        category=item.get("type_name"),
                        remarks=item.get("vod_remarks"),
                        director=item.get("vod_director"),
                        actor=item.get("vod_actor"),
                        description=item.get("vod_content"),
                        area=item.get("vod_area"),
                        year=str(item.get("vod_year", "")),
                        last_update=item.get("vod_time"),
                        playlists=playlists,
                    )
        except Exception as e:
            logger.error(f"CMS {self.name} get_detail error: {e}")
        return None
