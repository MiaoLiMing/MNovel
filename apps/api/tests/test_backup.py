import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from app.db.backup import backup_database


class BackupTestCase(unittest.TestCase):
    def test_backup_creates_consistent_copy(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.db"
            destination = Path(directory) / "backup" / "copy.db"
            with closing(sqlite3.connect(source)) as connection:
                connection.execute("CREATE TABLE sample(value TEXT NOT NULL)")
                connection.execute("INSERT INTO sample(value) VALUES('ready')")
                connection.commit()

            backup_database(source, destination)

            with closing(sqlite3.connect(destination)) as connection:
                value = connection.execute("SELECT value FROM sample").fetchone()
            self.assertEqual(value, ("ready",))


if __name__ == "__main__":
    unittest.main()
