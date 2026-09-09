from __future__ import annotations

import pathlib
import tempfile
import struct
import shutil
import unittest

from vanilla_restore import cmd_backup, cmd_scan, meta_version, contiguous_game_max, meta_is_injected

from vanilla_restore import AIO_BACKUP_NAME, find_backups, human, orphan_paz


class OrphanSelectionTests(unittest.TestCase):
    """A PAZ is deletable only if it is unreferenced AND above the vanilla ceiling."""

    def setUp(self) -> None:
        self.dir = pathlib.Path(tempfile.mkdtemp(prefix="bdoaio-test-"))

    def make(self, *numbers: int) -> None:
        for n in numbers:
            (self.dir / f"PAD{n:05d}.PAZ").write_bytes(b"x")

    def test_deletes_only_the_injected_high_numbers(self) -> None:
        self.make(1, 2, 500, 11398, 61337, 61338)
        keep = {1, 2, 11398}
        got = [p.name for p in orphan_paz(self.dir, keep)]
        self.assertEqual(got, ["PAD61337.PAZ", "PAD61338.PAZ"])

    def test_never_deletes_unreferenced_vanilla_archives(self) -> None:
        """Vanilla ships archives no meta block points at; those must survive."""
        self.make(500, 9000, 11398)
        keep = {11398}
        self.assertEqual(orphan_paz(self.dir, keep), [])

    def test_no_keep_set_deletes_nothing(self) -> None:
        self.make(61337)
        self.assertEqual(orphan_paz(self.dir, set()), [])

    def test_ignores_non_paz_files(self) -> None:
        self.make(61337)
        (self.dir / "pad00000.meta").write_bytes(b"x")
        (self.dir / "pad00000.meta.backup").write_bytes(b"x")
        (self.dir / "Meta Injector.exe").write_bytes(b"x")
        got = [p.name for p in orphan_paz(self.dir, {11398})]
        self.assertEqual(got, ["PAD61337.PAZ"])

    def test_matches_lowercase_paz_names(self) -> None:
        (self.dir / "pad61337.paz").write_bytes(b"x")
        self.assertEqual([p.name for p in orphan_paz(self.dir, {11398})], ["pad61337.paz"])


class BackupOrderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = pathlib.Path(tempfile.mkdtemp(prefix="bdoaio-test-"))

    def test_oldest_backup_wins(self) -> None:
        import os, time

        older = self.dir / "pad00000[2026-08-01][1].meta.backup"
        newer = self.dir / "pad00000[2026-08-03][2].meta.backup"
        older.write_bytes(b"a")
        newer.write_bytes(b"b")
        now = time.time()
        os.utime(older, (now - 10000, now - 10000))
        os.utime(newer, (now, now))
        self.assertEqual(find_backups(self.dir)[0].name, older.name)

    def test_aio_snapshot_is_preferred_over_injector_backups(self) -> None:
        (self.dir / "pad00000[2026-08-01][1].meta.backup").write_bytes(b"a")
        (self.dir / AIO_BACKUP_NAME).write_bytes(b"v")
        self.assertEqual(find_backups(self.dir)[0].name, AIO_BACKUP_NAME)

    def test_no_backups_is_empty_not_an_error(self) -> None:
        self.assertEqual(find_backups(self.dir), [])


class HumanTests(unittest.TestCase):
    def test_units(self) -> None:
        self.assertEqual(human(1024 ** 2), "1.0 MB")
        self.assertTrue(human(2 * 1024 ** 3).endswith("GB"))


class MetaVersionTests(unittest.TestCase):
    """The client version at offset 0 is what makes a stale snapshot dangerous."""

    def setUp(self) -> None:
        self.dir = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir, True)

    def test_reads_uint32_le_at_offset_zero(self) -> None:
        p = self.dir / "pad00000.meta"
        p.write_bytes(struct.pack("<I", 3418) + bytes(64))
        self.assertEqual(meta_version(p), 3418)

    def test_distinguishes_two_client_versions(self) -> None:
        a, b = self.dir / "a.meta", self.dir / "b.meta"
        a.write_bytes(struct.pack("<I", 3412) + bytes(16))
        b.write_bytes(struct.pack("<I", 3418) + bytes(16))
        # restore must refuse exactly this pairing
        self.assertNotEqual(meta_version(a), meta_version(b))


class FreshnessGuardTests(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir, True)

    def write_meta(self, name: str, version: int) -> pathlib.Path:
        path = self.dir / name
        path.write_bytes(struct.pack("<I", version) + bytes(64))
        return path

    def test_backup_rejects_stale_existing_snapshot(self) -> None:
        self.write_meta("pad00000.meta", 3435)
        self.write_meta(AIO_BACKUP_NAME, 3418)
        self.assertEqual(cmd_backup(self.dir, None, False), 5)

    def test_backup_accepts_existing_snapshot_for_same_client(self) -> None:
        self.write_meta("pad00000.meta", 3435)
        self.write_meta(AIO_BACKUP_NAME, 3435)
        self.assertEqual(cmd_backup(self.dir, None, False), 0)

    def test_scan_refuses_to_infer_state_from_stale_snapshot(self) -> None:
        self.write_meta("pad00000.meta", 3435)
        self.write_meta(AIO_BACKUP_NAME, 3418)
        self.assertEqual(cmd_scan(self.dir, None), 1)


class InjectedDetectionTests(unittest.TestCase):
    """State comes from the meta, never from leftover folders on disk."""

    def setUp(self) -> None:
        self.dir = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir, True)

    def _paz(self, numbers) -> None:
        for n in numbers:
            (self.dir / f"PAD{n:05d}.PAZ").write_bytes(b"")

    def test_contiguous_run_stops_at_the_first_gap(self) -> None:
        self._paz([1, 2, 3, 4, 61337, 61338])
        self.assertEqual(contiguous_game_max(self.dir), 4)

    def test_clean_meta_is_not_injected_even_with_orphans_present(self) -> None:
        # the exact 2026-08-27 case: archives on disk, meta references none of them
        self._paz([1, 2, 3, 4, 61337, 61338])
        (self.dir / "BDO_AIO_INJECT").mkdir()
        self.assertFalse(meta_is_injected(self.dir, {1, 2, 3, 4}))

    def test_meta_referencing_appended_archives_is_injected(self) -> None:
        self._paz([1, 2, 3, 4, 61337])
        self.assertTrue(meta_is_injected(self.dir, {1, 2, 3, 4, 61337}))

    def test_no_paz_on_disk_is_not_called_injected(self) -> None:
        self.assertFalse(meta_is_injected(self.dir, {1, 2}))


if __name__ == "__main__":
    unittest.main()
