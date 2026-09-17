"""Recovery transactions on disposable files; no game or tool execution."""
import json
import contextlib
import io
import pathlib
import struct
import tempfile
import unittest
from unittest.mock import patch

import vanilla_restore as vr

REAL_INSPECT = vr.inspect_recovery_meta


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="bdo-recovery-test-")
        self.addCleanup(temp.cleanup)
        self.paz = pathlib.Path(temp.name)
        self.current = self.paz / "pad00000.meta"
        self.backup = self.paz / vr.AIO_BACKUP_NAME
        self.write_meta(self.current, 3444, b"MODDED")
        self.write_meta(self.backup, 3444, b"CLEAN")
        for number in (0, 1, 2, 61337, 61338):
            (self.paz / f"PAD{number:05d}.PAZ").write_bytes(b"archive")
        (self.paz / "files_to_patch").mkdir()
        (self.paz / "files_to_patch/personal.txt").write_bytes(b"personal")
        for name, replacement in (("inspect_recovery_meta", self.inspect), ("assert_recovery_idle", lambda: None)):
            mock = patch.object(vr, name, replacement)
            mock.start()
            self.addCleanup(mock.stop)

    @staticmethod
    def write_meta(path, version, content):
        path.write_bytes(struct.pack("<I", version) + content)

    def inspect(self, paz, path, ice):
        payload = path.read_bytes()[4:]
        refs = [1, 2, 61337] if payload == b"MODDED" else [1, 2]
        return dict(version=vr.meta_version(path), sha256=vr.sha256(path),
                    blocks=len(refs), refs=refs, missing=0, overruns=0,
                    valid=payload != b"BROKEN")

    def apply(self, operation, token=None, confirmed=True):
        return vr.apply_recovery(self.paz, None, operation,
                                 token or vr.recovery_plan(self.paz, None)["token"], confirmed)

    def test_preview_read_only_and_stale_backup_blocked(self):
        self.write_meta(self.backup, 3435, b"CLEAN")
        before = vr.recovery_fingerprint(self.paz)
        plan = vr.recovery_plan(self.paz, None)
        self.assertFalse(plan["restore"]["allowed"])
        self.assertFalse(plan["snapshot"]["allowed"])
        self.assertEqual(before, vr.recovery_fingerprint(self.paz))
        self.assertFalse((self.paz / "BDO_AIO_RECOVERY").exists())

    def test_confirmation_required(self):
        with self.assertRaisesRegex(ValueError, "explicit"):
            self.apply("restore", confirmed=False)
        self.assertFalse((self.paz / "BDO_AIO_RECOVERY").exists())

    def test_changed_archive_invalidates_approval(self):
        token = vr.recovery_plan(self.paz, None)["token"]
        (self.paz / "PAD00001.PAZ").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "changed after preview"):
            self.apply("restore", token)
        self.assertFalse((self.paz / "BDO_AIO_RECOVERY").exists())

    def test_bad_backup_checksum_blocked(self):
        (self.paz / vr.AIO_BACKUP_INFO).write_text(json.dumps({"sha256": "wrong"}))
        self.assertFalse(vr.recovery_plan(self.paz, None)["restore"]["allowed"])

    def test_injected_backup_blocked(self):
        self.write_meta(self.backup, 3444, b"MODDED")
        self.assertFalse(vr.recovery_plan(self.paz, None)["restore"]["allowed"])

    def test_restore_retains_original_and_leaves_archives_and_staging(self):
        original = self.current.read_bytes()
        result = self.apply("restore")
        self.assertEqual(result["state"], "completed")
        self.assertEqual(self.current.read_bytes(), self.backup.read_bytes())
        self.assertEqual((pathlib.Path(result["retainedPath"]) / self.current.name).read_bytes(), original)
        self.assertTrue((self.paz / "PAD61338.PAZ").exists())
        self.assertEqual((self.paz / "files_to_patch/personal.txt").read_bytes(), b"personal")

    def test_snapshot_captures_current_not_old_backup(self):
        self.write_meta(self.current, 3444, b"CLEAN")
        self.write_meta(self.backup, 3435, b"CLEAN")
        original = self.backup.read_bytes()
        result = self.apply("snapshot")
        self.assertEqual(self.backup.read_bytes(), self.current.read_bytes())
        self.assertEqual((pathlib.Path(result["retainedPath"]) / self.backup.name).read_bytes(), original)
        info = json.loads((self.paz / vr.AIO_BACKUP_INFO).read_text())
        self.assertEqual(info["sha256"], vr.sha256(self.current))
        self.assertEqual(info["meta_version"], 3444)

    def test_cleanup_only_moves_listed_unused_high_archive(self):
        result = self.apply("cleanup")
        self.assertEqual(result["changed"], ["PAD61338.PAZ"])
        self.assertEqual((pathlib.Path(result["retainedPath"]) / "PAD61338.PAZ").read_bytes(), b"archive")
        for number in (0, 1, 2, 61337):
            self.assertTrue((self.paz / f"PAD{number:05d}.PAZ").exists())

    def test_game_running_stops_before_writes(self):
        with patch.object(vr, "assert_recovery_idle", side_effect=ValueError("game running")):
            with self.assertRaisesRegex(ValueError, "game running"):
                self.apply("restore")
        self.assertFalse((self.paz / "BDO_AIO_RECOVERY").exists())

    def test_snapshot_second_write_failure_rolls_back(self):
        self.write_meta(self.current, 3444, b"CLEAN")
        original = self.backup.read_bytes()
        writer = vr._atomic_recovery_write
        def fail_info(path, data):
            if path == self.paz / vr.AIO_BACKUP_INFO:
                raise OSError("injected write failure")
            writer(path, data)
        with patch.object(vr, "_atomic_recovery_write", side_effect=fail_info):
            with self.assertRaisesRegex(ValueError, "injected write failure"):
                self.apply("snapshot")
        self.assertEqual(self.backup.read_bytes(), original)
        self.assertFalse((self.paz / vr.AIO_BACKUP_INFO).exists())

    def test_failed_post_restore_check_rolls_back(self):
        original = self.current.read_bytes()
        def reject_restored(paz, path, ice):
            result = self.inspect(paz, path, ice)
            if path == self.current and path.read_bytes()[4:] == b"CLEAN":
                result["valid"] = False
            return result
        with patch.object(vr, "inspect_recovery_meta", side_effect=reject_restored):
            with self.assertRaisesRegex(ValueError, "failed verification"):
                self.apply("restore")
        self.assertEqual(self.current.read_bytes(), original)

    def test_linked_target_blocked(self):
        with patch.object(pathlib.Path, "is_symlink", return_value=True):
            with self.assertRaisesRegex(ValueError, "Linked/reparse"):
                vr.recovery_fingerprint(self.paz)

    def test_real_parser_checks_bounds_and_missing_archives(self):
        class PlainIce:
            def decrypt(self, data):
                return data
        folders = b"\x00" * 8 + b"character\x00"
        names = b"example.xml\x00"
        data = (struct.pack("<III", 3444, 0, 1)
                + struct.pack("<7I", 631490897, 0, 0, 1, 0, 4, 4)
                + struct.pack("<I", len(folders)) + folders
                + struct.pack("<I", len(names)) + names)
        self.current.write_bytes(data)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertTrue(REAL_INSPECT(self.paz, self.current, PlainIce())["valid"])
        self.assertEqual(output.getvalue(), "", "Parser progress polluted recovery JSON")
        archive = self.paz / "PAD00001.PAZ"
        archive.write_bytes(b"x")
        self.assertEqual(REAL_INSPECT(self.paz, self.current, PlainIce())["overruns"], 1)
        archive.unlink()
        self.assertEqual(REAL_INSPECT(self.paz, self.current, PlainIce())["missing"], 1)

    def test_partial_cleanup_failure_restores_moved_archive(self):
        (self.paz / "PAD61339.PAZ").write_bytes(b"archive")
        rename = pathlib.Path.rename
        def fail_second(path, destination):
            if path == self.paz / "PAD61339.PAZ":
                raise OSError("injected move failure")
            return rename(path, destination)
        with patch.object(pathlib.Path, "rename", fail_second):
            with self.assertRaisesRegex(ValueError, "injected move failure"):
                self.apply("cleanup")
        self.assertEqual((self.paz / "PAD61338.PAZ").read_bytes(), b"archive")
        self.assertEqual((self.paz / "PAD61339.PAZ").read_bytes(), b"archive")


if __name__ == "__main__":
    unittest.main()
