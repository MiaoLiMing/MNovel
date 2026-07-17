import os
from dataclasses import dataclass
from pathlib import Path


def _csv(name: str) -> tuple[str, ...]:
    return tuple(value.strip() for value in os.getenv(name, "").split(",") if value.strip())


@dataclass(frozen=True, slots=True)
class Settings:
    app_name: str = "MNovel API"
    api_prefix: str = "/api/v1"
    database_path: Path = Path("data/mnovel.db")
    cors_origins: tuple[str, ...] = ()
    access_token: str = ""

    @classmethod
    def from_env(cls) -> "Settings":
        defaults = cls()
        return cls(
            app_name=os.getenv("MNOVEL_APP_NAME", defaults.app_name),
            api_prefix=os.getenv("MNOVEL_API_PREFIX", defaults.api_prefix),
            database_path=Path(
                os.getenv("MNOVEL_DATABASE_PATH", str(defaults.database_path))
            ),
            cors_origins=_csv("MNOVEL_CORS_ORIGINS"),
            access_token=os.getenv("MNOVEL_ACCESS_TOKEN", "").strip(),
        )


settings = Settings.from_env()
