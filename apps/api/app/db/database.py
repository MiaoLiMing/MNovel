import json
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from threading import Lock
from typing import Any, Iterator


DEFAULT_SOURCES: list[tuple[str, str, str, int, int, dict[str, Any]]] = [
    (
        "qidian",
        "起点中文网",
        "novel",
        1,
        100,
        {"base_url": "https://www.qidian.com", "built_in": True},
    ),
    (
        "zongheng",
        "纵横中文网",
        "novel",
        1,
        90,
        {"base_url": "https://www.zongheng.com", "built_in": True},
    ),
    (
        "fanqie",
        "番茄小说",
        "novel",
        1,
        80,
        {"base_url": "https://fanqienovel.com", "built_in": True},
    ),
    (
        "qimao",
        "七猫小说",
        "novel",
        1,
        70,
        {"base_url": "https://www.qimao.com", "built_in": True},
    ),
    (
        "faloo",
        "飞卢小说",
        "novel",
        1,
        60,
        {"base_url": "https://b.faloo.com", "built_in": True},
    ),
    (
        "jjwxc",
        "晋江文学城",
        "novel",
        1,
        50,
        {"base_url": "https://www.jjwxc.net", "built_in": True},
    ),
    (
        "ciweimao",
        "刺猬猫",
        "novel",
        0,
        40,
        {"base_url": "https://www.ciweimao.com", "built_in": True},
    ),
    (
        "custom-example",
        "自定义书源示例",
        "json",
        0,
        30,
        {"base_url": "", "built_in": True, "access": "user_configured"},
    ),
]


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
            connection.executemany(
                """
                INSERT OR IGNORE INTO sources(
                    id, name, kind, enabled, priority, config_json
                ) VALUES(?, ?, ?, ?, ?, ?)
                """,
                [
                    (
                        source_id,
                        name,
                        kind,
                        enabled,
                        priority,
                        json.dumps(config, ensure_ascii=False),
                    )
                    for source_id, name, kind, enabled, priority, config in DEFAULT_SOURCES
                ],
            )

    def list_sources(self) -> list[dict[str, Any]]:
        with self.connect() as connection:
            rows = connection.execute(
                """
                SELECT id, name, kind, enabled, priority, config_json
                FROM sources
                ORDER BY priority DESC, name COLLATE NOCASE
                """
            ).fetchall()
        return [self._source_row(row) for row in rows]

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
                (
                    source_id,
                    name,
                    kind,
                    priority,
                    json.dumps(config, ensure_ascii=False),
                ),
            )

    def update_source(
        self,
        source_id: str,
        *,
        name: str | None = None,
        base_url: str | None = None,
        priority: int | None = None,
    ) -> bool:
        with self._lock, self.connect() as connection:
            row = connection.execute(
                "SELECT name, priority, config_json FROM sources WHERE id = ?",
                (source_id,),
            ).fetchone()
            if row is None:
                return False
            config = json.loads(row["config_json"])
            if base_url is not None:
                config["base_url"] = base_url
            connection.execute(
                """
                UPDATE sources
                SET name = ?, priority = ?, config_json = ?
                WHERE id = ?
                """,
                (
                    name or row["name"],
                    priority if priority is not None else row["priority"],
                    json.dumps(config, ensure_ascii=False),
                    source_id,
                ),
            )
        return True

    def set_source_enabled(self, source_id: str, enabled: bool) -> bool:
        with self._lock, self.connect() as connection:
            result = connection.execute(
                "UPDATE sources SET enabled = ? WHERE id = ?",
                (int(enabled), source_id),
            )
        return result.rowcount > 0

    def reorder_sources(self, source_ids: list[str]) -> None:
        with self._lock, self.connect() as connection:
            known = {
                row["id"]
                for row in connection.execute("SELECT id FROM sources").fetchall()
            }
            ordered = [source_id for source_id in source_ids if source_id in known]
            trailing = [source_id for source_id in known if source_id not in ordered]
            complete = ordered + trailing
            priority = len(complete) * 10
            for source_id in complete:
                connection.execute(
                    "UPDATE sources SET priority = ? WHERE id = ?",
                    (priority, source_id),
                )
                priority -= 10

    def delete_source(self, source_id: str) -> bool:
        with self._lock, self.connect() as connection:
            row = connection.execute(
                "SELECT config_json FROM sources WHERE id = ?", (source_id,)
            ).fetchone()
            if row is None:
                return False
            config = json.loads(row["config_json"])
            if bool(config.get("built_in")):
                return False
            result = connection.execute("DELETE FROM sources WHERE id = ?", (source_id,))
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
        return self._source_row(row) if row else None

    def set_favorite(self, content_id: str, channel: str, active: bool) -> None:
        with self._lock, self.connect() as connection:
            if active:
                connection.execute(
                    "INSERT OR REPLACE INTO favorites(content_id, channel) VALUES(?, ?)",
                    (content_id, channel),
                )
            else:
                connection.execute(
                    "DELETE FROM favorites WHERE content_id = ?", (content_id,)
                )

    def list_favorite_ids(self, channel: str | None = None) -> list[str]:
        with self.connect() as connection:
            if channel:
                rows = connection.execute(
                    """
                    SELECT content_id FROM favorites
                    WHERE channel = ?
                    ORDER BY created_at DESC
                    """,
                    (channel,),
                ).fetchall()
            else:
                rows = connection.execute(
                    "SELECT content_id FROM favorites ORDER BY created_at DESC"
                ).fetchall()
        return [str(row["content_id"]) for row in rows]

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
                """
                SELECT content_id, channel, unit_index, position, updated_at
                FROM progress WHERE content_id = ?
                """,
                (content_id,),
            ).fetchone()
        return dict(row) if row else None

    def list_progress(self) -> list[dict[str, Any]]:
        with self.connect() as connection:
            rows = connection.execute(
                """
                SELECT content_id, channel, unit_index, position, updated_at
                FROM progress ORDER BY updated_at DESC
                """
            ).fetchall()
        return [dict(row) for row in rows]

    @staticmethod
    def _source_row(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "name": row["name"],
            "kind": row["kind"],
            "enabled": bool(row["enabled"]),
            "priority": row["priority"],
            "config": json.loads(row["config_json"]),
        }
