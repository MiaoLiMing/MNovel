import json
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from threading import Lock
from typing import Any, Iterator


class Database:
    def __init__(self, path: Path) -> None:
        self.path = path
        self._lock = Lock()

    @contextmanager
    def connect(self) -> Iterator[sqlite3.Connection]:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        connection = sqlite3.connect(self.path, check_same_thread=False)
        connection.row_factory = sqlite3.Row
        try:
            yield connection
            connection.commit()
        finally:
            connection.close()

    def initialize(self) -> None:
        with self.connect() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS favorites (
                    content_id TEXT PRIMARY KEY,
                    channel TEXT NOT NULL,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE TABLE IF NOT EXISTS progress (
                    content_id TEXT PRIMARY KEY,
                    channel TEXT NOT NULL,
                    unit_index INTEGER NOT NULL,
                    position REAL NOT NULL,
                    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                CREATE TABLE IF NOT EXISTS sources (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    kind TEXT NOT NULL,
                    enabled INTEGER NOT NULL DEFAULT 1,
                    priority INTEGER NOT NULL DEFAULT 0,
                    config_json TEXT NOT NULL DEFAULT '{}'
                );
                """
            )
            connection.execute("DELETE FROM sources WHERE id IN ('demo-books', 'demo-media')")
            connection.executemany(
                """
                INSERT OR IGNORE INTO sources(
                    id, name, kind, enabled, priority, config_json
                ) VALUES(?, ?, ?, ?, ?, ?)
                """,
                [
                    (
                        "open-library",
                        "Open Library",
                        "novel",
                        1,
                        90,
                        json.dumps(
                            {
                                "base_url": "https://openlibrary.org",
                                "access": "metadata",
                            }
                        ),
                    ),
                    (
                        "project-gutenberg",
                        "Project Gutenberg OPDS",
                        "novel",
                        1,
                        100,
                        json.dumps(
                            {
                                "base_url": "https://www.gutenberg.org/ebooks/search.opds/",
                                "access": "public_domain",
                            }
                        ),
                    ),
                    (
                        "local-opds",
                        "本地 OPDS / JSON",
                        "novel",
                        1,
                        110,
                        json.dumps({"base_url": "", "access": "user_configured"}),
                    ),
                    (
                        "internet-archive",
                        "Internet Archive",
                        "shortDrama",
                        1,
                        90,
                        json.dumps(
                            {
                                "base_url": "https://archive.org",
                                "access": "public_domain",
                            }
                        ),
                    ),
                    (
                        "tvmaze",
                        "TVmaze 开放数据",
                        "shortDrama",
                        1,
                        100,
                        json.dumps(
                            {
                                "base_url": "https://api.tvmaze.com",
                                "access": "public_domain",
                            }
                        ),
                    ),
                    (
                        "itunes",
                        "iTunes 官方源",
                        "video",
                        1,
                        100,
                        json.dumps(
                            {
                                "base_url": "https://itunes.apple.com",
                                "access": "public_domain",
                            }
                        ),
                    ),
                    (
                        "tmdb",
                        "TMDB",
                        "video",
                        0,
                        80,
                        json.dumps(
                            {
                                "base_url": "https://api.themoviedb.org",
                                "access": "metadata",
                                "requires_key": True,
                            }
                        ),
                    ),
                    (
                        "pexels-videos",
                        "Pexels Videos",
                        "video",
                        0,
                        70,
                        json.dumps(
                            {
                                "base_url": "https://api.pexels.com",
                                "access": "licensed_media",
                                "requires_key": True,
                            }
                        ),
                    ),
                ],
            )

    def list_sources(self) -> list[dict[str, Any]]:
        with self.connect() as connection:
            rows = connection.execute(
                "SELECT id, name, kind, enabled, priority, config_json FROM sources ORDER BY priority DESC"
            ).fetchall()
        return [
            {
                "id": row["id"],
                "name": row["name"],
                "kind": row["kind"],
                "enabled": bool(row["enabled"]),
                "priority": row["priority"],
                "config": json.loads(row["config_json"]),
            }
            for row in rows
        ]

    def add_source(
        self,
        source_id: str,
        name: str,
        kind: str,
        priority: int,
        config: dict[str, Any],
    ) -> None:
        with self._lock, self.connect() as connection:
            connection.execute(
                """
                INSERT INTO sources(id, name, kind, enabled, priority, config_json)
                VALUES(?, ?, ?, 1, ?, ?)
                """,
                (source_id, name, kind, priority, json.dumps(config)),
            )

    def set_source_enabled(self, source_id: str, enabled: bool) -> bool:
        with self._lock, self.connect() as connection:
            result = connection.execute(
                "UPDATE sources SET enabled = ? WHERE id = ?",
                (int(enabled), source_id),
            )
        return result.rowcount > 0

    def get_source(self, source_id: str) -> dict[str, Any] | None:
        with self.connect() as connection:
            row = connection.execute(
                """
                SELECT id, name, kind, enabled, priority, config_json
                FROM sources WHERE id = ?
                """,
                (source_id,),
            ).fetchone()
        if row is None:
            return None
        return {
            "id": row["id"],
            "name": row["name"],
            "kind": row["kind"],
            "enabled": bool(row["enabled"]),
            "priority": row["priority"],
            "config": json.loads(row["config_json"]),
        }

    def set_favorite(self, content_id: str, channel: str, active: bool) -> None:
        with self._lock, self.connect() as connection:
            if active:
                connection.execute(
                    "INSERT OR REPLACE INTO favorites(content_id, channel) VALUES(?, ?)",
                    (content_id, channel),
                )
            else:
                connection.execute("DELETE FROM favorites WHERE content_id = ?", (content_id,))

    def save_progress(
        self, content_id: str, channel: str, unit_index: int, position: float
    ) -> None:
        with self._lock, self.connect() as connection:
            connection.execute(
                """
                INSERT INTO progress(content_id, channel, unit_index, position)
                VALUES(?, ?, ?, ?)
                ON CONFLICT(content_id) DO UPDATE SET
                  channel = excluded.channel,
                  unit_index = excluded.unit_index,
                  position = excluded.position,
                  updated_at = CURRENT_TIMESTAMP
                """,
                (content_id, channel, unit_index, position),
            )

    def get_progress(self, content_id: str) -> dict[str, Any] | None:
        with self.connect() as connection:
            row = connection.execute(
                "SELECT content_id, channel, unit_index, position, updated_at FROM progress WHERE content_id = ?",
                (content_id,),
            ).fetchone()
        return dict(row) if row else None
