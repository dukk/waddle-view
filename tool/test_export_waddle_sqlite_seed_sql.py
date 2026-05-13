"""Unit tests for tool/export_waddle_sqlite_seed_sql.py (stdlib only)."""
from __future__ import annotations

import importlib.util
import sqlite3
import tempfile
import unittest
from pathlib import Path


def _load_exporter():
    root = Path(__file__).resolve().parent
    path = root / "export_waddle_sqlite_seed_sql.py"
    spec = importlib.util.spec_from_file_location("export_waddle_sqlite_seed_sql", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class TestExportWaddleSqliteSeedSql(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ex = _load_exporter()

    def test_sql_literal(self):
        ex = self.ex
        self.assertEqual(ex._sql_literal(None), "NULL")
        self.assertEqual(ex._sql_literal("a'b"), "'a''b'")
        self.assertEqual(ex._sql_literal(42), "42")
        self.assertEqual(ex._sql_literal(True), "1")
        self.assertEqual(ex._sql_literal(False), "0")
        self.assertEqual(ex._sql_literal(b"\x00\xff"), "X'00ff'")

    def test_export_round_trip_minimal_fk(self):
        ex = self.ex
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "waddle_view.sqlite"
            conn = sqlite3.connect(str(db))
            try:
                conn.execute(
                    "CREATE TABLE parent (id TEXT NOT NULL PRIMARY KEY, label TEXT NOT NULL);"
                )
                conn.execute(
                    """
                    CREATE TABLE child (
                      id TEXT NOT NULL PRIMARY KEY,
                      parent_id TEXT NOT NULL,
                      FOREIGN KEY(parent_id) REFERENCES parent(id)
                    );
                    """
                )
                conn.execute("INSERT INTO parent (id, label) VALUES ('p1', 'x');")
                conn.execute(
                    "INSERT INTO child (id, parent_id) VALUES ('c1', 'p1');"
                )
                conn.commit()
            finally:
                conn.close()

            sql = ex.export_seed_sql(db)
            self.assertIn("DELETE FROM \"child\";", sql)
            self.assertIn("DELETE FROM \"parent\";", sql)
            self.assertIn("INSERT INTO \"parent\"", sql)
            self.assertIn("INSERT INTO \"child\"", sql)
            self.assertIn("PRAGMA foreign_keys=OFF;", sql)
            self.assertIn("COMMIT;", sql)

            target = Path(td) / "target.sqlite"
            conn2 = sqlite3.connect(str(target))
            try:
                conn2.execute(
                    "CREATE TABLE parent (id TEXT NOT NULL PRIMARY KEY, label TEXT NOT NULL);"
                )
                conn2.execute(
                    """
                    CREATE TABLE child (
                      id TEXT NOT NULL PRIMARY KEY,
                      parent_id TEXT NOT NULL,
                      FOREIGN KEY(parent_id) REFERENCES parent(id)
                    );
                    """
                )
                conn2.commit()
                conn2.executescript(sql)
                n_p = conn2.execute("SELECT COUNT(*) FROM parent").fetchone()[0]
                n_c = conn2.execute("SELECT COUNT(*) FROM child").fetchone()[0]
                self.assertEqual(n_p, 1)
                self.assertEqual(n_c, 1)
            finally:
                conn2.close()


if __name__ == "__main__":
    unittest.main()
