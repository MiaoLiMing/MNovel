import asyncio
import logging
from typing import List, Dict, Optional
from app.providers.base import BaseProvider
from app.providers.cms_json import CmsJsonProvider
from app.schemas.videos import VideoSimple

logger = logging.getLogger(__name__)

DEFAULT_SOURCES = [
    {
        "id": 1,
        "name": "豪华资源",
        "channel": "video",
        "api_type": "cms_json",
        "api_url": "https://hhzyapi.com/api.php/provide/vod/at/json",
        "built_in": True,
    },
    {
        "id": 2,
        "name": "暴风资源",
        "channel": "video",
        "api_type": "cms_json",
        "api_url": "https://bfzyapi.com/api.php/provide/vod/at/json",
        "built_in": True,
    },
    {
        "id": 3,
        "name": "无尽资源",
        "channel": "video",
        "api_type": "cms_json",
        "api_url": "https://api.wujinapi.me/api.php/provide/vod/at/json",
        "built_in": True,
    },
]


class ProviderManager:
    """
    影视源引擎管理器
    """

    def __init__(self):
        self._providers: Dict[int, BaseProvider] = {}
        self._sources_meta: Dict[int, Dict] = {}
        self._next_id = 100
        self._init_default_providers()

    def _init_default_providers(self):
        for item in DEFAULT_SOURCES:
            provider = CmsJsonProvider(
                source_id=item["id"],
                name=item["name"],
                api_url=item["api_url"],
            )
            self._providers[item["id"]] = provider
            self._sources_meta[item["id"]] = item
        logger.info(f"Initialized {len(self._providers)} default movie providers.")

    def list_sources(self, channel: Optional[str] = None) -> List[Dict]:
        sources = list(self._sources_meta.values())
        if channel:
            sources = [s for s in sources if s.get("channel") == channel]
        return sources

    def add_custom_source(
        self, name: str, api_url: str, channel: str = "video"
    ) -> Dict:
        new_id = self._next_id
        self._next_id += 1
        item = {
            "id": new_id,
            "name": name,
            "channel": channel,
            "api_type": "cms_json",
            "api_url": api_url,
            "built_in": False,
        }
        provider = CmsJsonProvider(
            source_id=new_id,
            name=name,
            api_url=api_url,
        )
        self._providers[new_id] = provider
        self._sources_meta[new_id] = item
        return item

    def delete_custom_source(self, source_id: int) -> bool:
        meta = self._sources_meta.get(source_id)
        if not meta or meta.get("built_in"):
            return False
        self._providers.pop(source_id, None)
        self._sources_meta.pop(source_id, None)
        return True

    def get_provider(self, source_id: int) -> Optional[BaseProvider]:
        return self._providers.get(source_id) or self._providers.get(1)

    async def search_all(self, keyword: str, page: int = 1) -> List[VideoSimple]:
        if not self._providers:
            return []

        tasks = []
        for provider in self._providers.values():
            tasks.append(self._safe_search(provider, keyword, page))

        results_nested = await asyncio.gather(*tasks)

        flat_results = []
        for res_list in results_nested:
            flat_results.extend(res_list)

        return flat_results

    async def _safe_search(
        self, provider: BaseProvider, keyword: str, page: int
    ) -> List[VideoSimple]:
        try:
            return await asyncio.wait_for(provider.search(keyword, page), timeout=8.0)
        except asyncio.TimeoutError:
            logger.warning(f"Search timeout (8s) for provider: {provider.name}")
        except Exception as e:
            logger.error(f"Search failed for provider {provider.name}: {e}")
        return []

    async def get_latest_all(self, page: int = 1) -> List[VideoSimple]:
        if not self._providers:
            return []

        active_providers = list(self._providers.values())[:3]
        tasks = []
        for provider in active_providers:
            tasks.append(self._safe_get_latest(provider, page))

        results_nested = await asyncio.gather(*tasks)

        flat_results = []
        for res_list in results_nested:
            flat_results.extend(res_list)
        return flat_results

    async def _safe_get_latest(
        self, provider: BaseProvider, page: int
    ) -> List[VideoSimple]:
        try:
            return await asyncio.wait_for(provider.get_latest(page=page), timeout=8.0)
        except Exception as e:
            logger.error(f"Get latest failed for provider {provider.name}: {e}")
        return []


provider_manager = ProviderManager()
