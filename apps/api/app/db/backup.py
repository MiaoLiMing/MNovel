import argparse
import sqlite3
from contextlib import closing
from pathlib import Path


def backup_database(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(source)) as source_connection:
        with closing(sqlite3.connect(destination)) as destination_connection:
            source_connection.backup(destination_connection)


def main() -> None:
    parser = argparse.ArgumentParser(description="Create a consistent SQLite backup")
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    backup_database(args.source, args.destination)


if __name__ == "__main__":
    main()
