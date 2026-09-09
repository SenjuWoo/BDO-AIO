from __future__ import annotations

import pathlib
import shutil
import struct
import tempfile
import unittest

from paz_status_scan import classify_meta, find_backups
from vanilla_restore import AIO_BACKUP_NAME


class MetaStatusTests(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = pathlib.Path(tempfile.mkdtemp(prefix="bdoaio-status-test-"))
        self.addCleanup(shutil.rmtree, self.dir, True)

    def write_meta(self, name: str, version: int, body: bytes = b"") -> pathlib.Path:
        path = self.dir / name
        path.write_bytes(struct.pack("<I", version) + body)
        return path

    def classify(self, current_body: bytes = b"", snapshot_version: int = 3435, snapshot_body: bytes = b"") -> dict:
        current = self.write_meta("pad00000.meta", 3435, current_body)
        self.write_meta(AIO_BACKUP_NAME, snapshot_version, snapshot_body)
        return classify_meta(current, find_backups(self.dir))

    def test_stale_snapshot_is_unknown_not_modded(self) -> None:
        result = self.classify(current_body=b"changed", snapshot_version=3418, snapshot_body=b"clean")
        self.assertEqual(result["state"], "STALE_BACKUP")
        self.assertIsNone(result["matches_latest_backup"])
        self.assertFalse(result["version_matches"])

    def test_same_version_equal_snapshot_is_restored(self) -> None:
        result = self.classify(current_body=b"clean", snapshot_body=b"clean")
        self.assertEqual(result["state"], "RESTORED")
        self.assertTrue(result["matches_latest_backup"])
        self.assertTrue(result["version_matches"])

    def test_same_version_difference_is_modded(self) -> None:
        result = self.classify(current_body=b"changed", snapshot_body=b"clean")
        self.assertEqual(result["state"], "MODDED")
        self.assertFalse(result["matches_latest_backup"])

    def test_missing_reference_is_unknown(self) -> None:
        current = self.write_meta("pad00000.meta", 3435, b"clean")
        result = classify_meta(current, [])
        self.assertEqual(result["state"], "UNKNOWN")
        self.assertIn("No AIO vanilla snapshot", result["detail"])


if __name__ == "__main__":
    unittest.main()
