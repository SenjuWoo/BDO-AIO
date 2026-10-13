from __future__ import annotations

import json
import pathlib
import re
import shutil
import tempfile
import unittest

import open_chest_apply as oca

XML = """<CutType Name="Disable">
  <File>1_pc/3_pew/armor/9_upperbody/pew_10_ub_0006.pac</File>
</CutType>
<BasicCutType Name="PEW_Upperbody">
  <Path>1_Pc/3_PEW/Armor/9_Upperbody</Path>
  <Path>1_Pc/8_PWW/Armor/9_Upperbody</Path>
</BasicCutType>
<BasicCutType Name="Upperbody">
  <Path>1_Pc/4_PGM/Armor/9_Upperbody</Path>
</BasicCutType>
<Relation CutType="PEW_Upperbody">
  <Cut>Nude</Cut>
</Relation>
"""
FOLDER = "1_Pc/3_PEW/Armor/9_Upperbody"
TOPS = {f"character/model/{FOLDER.lower()}": [
    "pew_00_ub_0001.pac", "pew_10_ub_0027.pac", "pew_10_ub_0027_dm.pac",
    "pew_10_ub_0067.pac", "pew_10_ub_0006.pac", "pew_kw_ub_0001.pac"]}
REGISTRY = {"schema": 1, "client_version": 3454, "classes": {"pew": {"folder": FOLDER, "items": {
    "pew_10_ub_0027": {"mound": 1.0, "nipple": 1.0},   # bare chest
    "pew_10_ub_0067": {"mound": 0.6, "nipple": 0.7},   # window
    "pew_10_ub_0006": {"mound": 1.0, "nipple": 1.0},   # staged by Midnight below
    "pew_kw_ub_0001": {"mound": 0.2, "nipple": 0.1},   # barely open
}}}}


def block_files(xml: str, group: str) -> list[str]:
    m = re.search(rf'<CutType Name="{group}">(.*?)</CutType>', xml, re.S)
    return re.findall(r"<File>.*/(.*?)</File>", m.group(1)) if m else []


class SelectionTests(unittest.TestCase):
    def test_tiers(self) -> None:
        items = REGISTRY["classes"]["pew"]["items"]
        self.assertEqual(oca.selected_stems(items, "open"), {"pew_10_ub_0027", "pew_10_ub_0006"})
        self.assertEqual(oca.selected_stems(items, "window"), {"pew_10_ub_0027", "pew_10_ub_0006", "pew_10_ub_0067"})


class ApplyRegistryTests(unittest.TestCase):
    def apply(self, tier="open", xml=XML, staged=None):
        return oca.apply_registry(xml, REGISTRY, tier, TOPS, staged or {"3_pew": {"pew_10_ub_0006.pac"}})

    def test_selected_tops_leave_the_group_and_the_rest_stay_cut(self) -> None:
        xml, report = self.apply()
        self.assertNotIn("<Path>1_Pc/3_PEW/Armor/9_Upperbody</Path>", xml)
        self.assertIn("<Path>1_Pc/8_PWW/Armor/9_Upperbody</Path>", xml)  # shared group keeps other classes
        self.assertEqual(sorted(block_files(xml, "PEW_Upperbody")),
                         ["pew_00_ub_0001.pac", "pew_10_ub_0006.pac", "pew_10_ub_0067.pac", "pew_kw_ub_0001.pac"])
        self.assertEqual(report["pew"]["uncut"], 2)  # 0027 + its _dm; 0006 is staged elsewhere
        self.assertEqual(report["pew"]["staged_skipped"], 1)

    def test_window_tier_also_uncuts_windows(self) -> None:
        xml, _ = self.apply("window")
        self.assertNotIn("pew_10_ub_0067.pac", block_files(xml, "PEW_Upperbody"))

    def test_block_precedes_first_relation(self) -> None:
        xml, _ = self.apply()
        self.assertLess(xml.index('<CutType Name="PEW_Upperbody">'), xml.index("<Relation"))

    def test_idempotent(self) -> None:
        once, _ = self.apply()
        # PartCutGen would normally regenerate; re-running on its own output must not stack blocks.
        regen_path_back = once.replace("<BasicCutType Name=\"PEW_Upperbody\">\n", f'<BasicCutType Name="PEW_Upperbody">\n  <Path>{FOLDER}</Path>\n')
        twice, _ = self.apply(xml=regen_path_back)
        self.assertEqual(once.count("BDO-AIO open-chest BEGIN"), 1)
        self.assertEqual(once, twice)

    def test_nothing_selected_leaves_xml_untouched(self) -> None:
        reg = json.loads(json.dumps(REGISTRY))
        reg["classes"]["pew"]["items"] = {"pew_kw_ub_0001": {"mound": 0.2, "nipple": 0.1}}
        xml, report = oca.apply_registry(XML, reg, "open", TOPS, {})
        self.assertEqual(xml, XML)
        self.assertFalse(report["pew"]["applied"])

    def test_folder_without_a_basic_cut_group_is_left_vanilla(self) -> None:
        xml_without = XML.replace("<Path>1_Pc/3_PEW/Armor/9_Upperbody</Path>\n  ", "")
        xml, report = self.apply(xml=xml_without)
        self.assertEqual(xml, xml_without)
        self.assertIn("note", report["pew"])

    def test_malformed_xml_without_relation_is_an_error(self) -> None:
        with self.assertRaises(ValueError):
            self.apply(xml=XML.split("<Relation")[0])


class FileRoundTripTests(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = pathlib.Path(tempfile.mkdtemp(prefix="bdoaio-chest-"))
        self.addCleanup(shutil.rmtree, self.dir, True)
        self.path = self.dir / "partcutdesc.xml"

    def test_non_utf8_bytes_and_crlf_survive_the_rewrite(self) -> None:
        # The live file holds a 0x8c byte; a UTF-8 round trip would replace it with U+FFFD.
        original = XML.replace("<Relation", "<!-- \x8c -->\n<Relation", 1).replace("\n", "\r\n").encode("latin-1")
        self.path.write_bytes(original)
        changed, _ = oca.apply_file(self.path, REGISTRY, "open", TOPS, {})
        out = self.path.read_bytes()
        self.assertTrue(changed)
        self.assertIn(b"<!-- \x8c -->", out)
        self.assertNotIn(b"\xef\xbf\xbd", out)
        self.assertNotRegex(out, rb"(?<!\r)\n")  # every inserted line break is CRLF like the file

    def test_dry_run_leaves_the_file_alone(self) -> None:
        self.path.write_bytes(XML.encode("latin-1"))
        changed, _ = oca.apply_file(self.path, REGISTRY, "open", TOPS, {}, write=False)
        self.assertTrue(changed)
        self.assertEqual(self.path.read_bytes(), XML.encode("latin-1"))


class StagedTopsTests(unittest.TestCase):
    def test_finds_staged_pacs_and_ignores_partcutgen_output(self) -> None:
        root = pathlib.Path(tempfile.mkdtemp(prefix="bdoaio-chest-"))
        self.addCleanup(shutil.rmtree, root, True)
        for rel in ("_midnight_xyzw/x/character/model/1_pc/3_pew/armor/9_upperbody/PEW_10_UB_0006.pac",
                    "_PartCutGen/character/model/1_pc/3_pew/armor/9_upperbody/pew_bogus.pac"):
            p = root / rel
            p.parent.mkdir(parents=True)
            p.write_bytes(b"x")
        self.assertEqual(oca.staged_tops(root), {"3_pew": {"pew_10_ub_0006.pac"}})


if __name__ == "__main__":
    unittest.main()
