from __future__ import annotations

import pathlib
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

import partcut_recut


class MetaSelectionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = pathlib.Path(tempfile.mkdtemp(prefix="bdoaio-partcut-test-"))
        self.addCleanup(shutil.rmtree, self.dir, True)
        (self.dir / "pad00000.meta").write_bytes(b"live")
        (self.dir / "pad00000.BDOAIO-VANILLA.meta").write_bytes(b"snapshot")

    def run_dry(self, *extra: str):
        argv = [
            "partcut_recut.py",
            "--xml",
            str(self.dir / "partcutdesc.xml"),
            "--paz",
            str(self.dir),
            "--group",
            "PEW_Upperbody",
            "--folder",
            "1_Pc/3_PEW/Armor/9_Upperbody",
            "--dry-run",
            *extra,
        ]
        with patch.object(partcut_recut, "folder_pacs", return_value=["1_Pc/3_PEW/Armor/9_Upperbody/a.pac"]) as folder_pacs:
            with patch.object(sys, "argv", argv):
                self.assertEqual(partcut_recut.main(), 0)
        return folder_pacs

    def test_default_uses_live_meta(self) -> None:
        folder_pacs = self.run_dry()
        self.assertEqual(folder_pacs.call_args.args[1], "pad00000.meta")

    def test_snapshot_requires_explicit_selection(self) -> None:
        folder_pacs = self.run_dry("--meta", "pad00000.BDOAIO-VANILLA.meta")
        self.assertEqual(folder_pacs.call_args.args[1], "pad00000.BDOAIO-VANILLA.meta")

    def test_temporary_meta_copy_is_removed_on_parser_failure(self) -> None:
        copies = []

        def broken_meta(work, ice):
            copies.append(work)
            self.assertEqual((work / "pad00000.meta").read_bytes(), b"live")
            raise ValueError("bad meta")

        with patch.object(partcut_recut, "IceDecipher"), patch.object(partcut_recut, "MetaFile", side_effect=broken_meta):
            with self.assertRaisesRegex(ValueError, "bad meta"):
                partcut_recut.folder_pacs(self.dir, "pad00000.meta", "1_Pc/3_PEW/Armor/9_Upperbody")
        self.assertEqual(len(copies), 1)
        self.assertFalse(copies[0].exists())


if __name__ == "__main__":
    unittest.main()
