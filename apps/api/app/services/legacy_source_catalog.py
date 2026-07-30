import json
from collections import Counter
from functools import lru_cache
from pathlib import Path

from app.schemas.legacy_sources import LegacySource, LegacySourceSummary


def default_catalog_path() -> Path:
    return Path(__file__).resolve().parents[4] / "data/book_sources/legacy_sources.json"


class LegacySourceCatalog:
    def __init__(self, path: Path | None = None) -> None:
        self.path = path or default_catalog_path()
        self._sources: list[LegacySource] | None = None
        self._by_id: dict[str, LegacySource] = {}

    def _load(self) -> list[LegacySource]:
        if self._sources is not None:
            return self._sources
        if not self.path.exists():
            self._sources = []
            return self._sources
        payload = json.loads(self.path.read_text(encoding="utf-8"))
        values = payload.get("sources", [])
        self._sources = [LegacySource.model_validate(value) for value in values]
        self._by_id = {source.id: source for source in self._sources}
        return self._sources

    def list(
        self,
        *,
        query: str = "",
        compatibility: str = "",
        group: str = "",
        offset: int = 0,
        limit: int = 100,
    ) -> list[LegacySource]:
        values = self._load()
        normalized_query = query.strip().casefold()
        if normalized_query:
            values = [
                source
                for source in values
                if normalized_query
                in f"{source.name} {source.base_url} {source.group}".casefold()
            ]
        if compatibility:
            values = [
                source
                for source in values
                if source.compatibility == compatibility
            ]
        if group:
            values = [source for source in values if source.group == group]
        return values[offset : offset + limit]

    def get(self, source_id: str) -> LegacySource | None:
        self._load()
        return self._by_id.get(source_id)

    def summary(self) -> LegacySourceSummary:
        values = self._load()
        return LegacySourceSummary(
            total=len(values),
            compatibility=dict(
                sorted(Counter(source.compatibility for source in values).items())
            ),
            groups=dict(Counter(source.group for source in values).most_common()),
        )


@lru_cache
def legacy_source_catalog() -> LegacySourceCatalog:
    return LegacySourceCatalog()
