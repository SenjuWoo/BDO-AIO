#!/usr/bin/env python3
"""Uncut the body under open-chest tops by rewriting PartCutGen's partcutdesc.xml.

Why this shape (measured, see dev/PARTCUT-MECHANICS.md): vanilla tops join their body-cut
group through a folder rule, <BasicCutType Name="PEW_Upperbody"><Path>..9_Upperbody</Path>,
and PartCutGen's exclusions cannot override a folder rule. So for every class that has
selected tops this drops that class's folder <Path> from its group and re-adds every
OTHER top of the folder as a per-file <CutType> of the same name. Selected tops leave the
group and render the whole body; all other tops keep their vanilla cut.

Run after PartCutGen and before Meta Injector (PartCutGen rewrites the file, so run it on
every regeneration). Idempotent: its blocks are fenced by markers and replaced wholesale.
Tops already staged under files_to_patch (Midnight XYZW etc.) are never touched.
Standard library only.

    python open_chest_apply.py --paz <PAZ> --registry open_chest_registry.json --tier open
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import shutil
import sys
import tempfile

from body_size_patcher import IceDecipher, MetaFile
from vanilla_restore import meta_version

BEGIN = "<!-- BDO-AIO open-chest BEGIN {group} -->"
END = "<!-- BDO-AIO open-chest END {group} -->"
SCHEMA = 1
# Share of the breast area the top leaves uncovered, as (min mound, min nipple zone).
# "open": the nipple zone is bare and most of the breast too, so uncutting has almost
# nothing to clip. "window": adds slit/keyhole/open-front tops where at least half of the
# nipple zone shows; breasts at extreme slider values can poke through the part that
# stays covered. Bikini cups and narrow plunges cover the nipples, so they stay vanilla
# (uncut, the breast would poke through the cloth). Calibrated on contact sheets of the
# Ranger set (dev/open_chest_sheet.py).
TIERS = {"open": (0.65, 0.95), "window": (0.0, 0.5)}
CUT_FILE = "partcutdesc.xml"


def log(msg: str) -> None:
    print(msg, flush=True)


def selected_stems(items: dict, tier: str) -> set[str]:
    min_mound, min_nipple = TIERS[tier]
    return {s for s, v in items.items() if v["mound"] >= min_mound and v["nipple"] >= min_nipple}


def staged_tops(files_to_patch: pathlib.Path) -> dict[str, set[str]]:
    """folder id ('3_pew') -> lowercase PAC names already staged by another pack."""
    out: dict[str, set[str]] = {}
    pat = re.compile(r"[\\/]character[\\/]model[\\/]1_pc[\\/]([^\\/]+)[\\/]armor[\\/]9_upperbody[\\/]([^\\/]+\.pac)$", re.I)
    for root, dirs, files in os.walk(files_to_patch):
        if pathlib.Path(root) == files_to_patch:
            dirs[:] = [d for d in dirs if d != "_PartCutGen"]
        for name in files:
            m = pat.search(os.path.join(root, name))
            if m:
                out.setdefault(m.group(1).lower(), set()).add(m.group(2).lower())
    return out


def meta_tops(paz: pathlib.Path, meta_name: str, folders: set[str]) -> dict[str, list[str]]:
    """lowercase 'character/model/<folder>' -> sorted PAC names, for the wanted folders."""
    ice = IceDecipher(pathlib.Path(__file__).resolve().parent / "ice_decipher.dll")
    with tempfile.TemporaryDirectory(prefix="bdo-aio-chest-") as tmp:
        shutil.copy2(paz / meta_name, pathlib.Path(tmp) / "pad00000.meta")
        blocks = MetaFile(pathlib.Path(tmp), ice).fileBlocks
    want = {f"character/model/{f.lower()}" for f in folders}
    found: dict[str, set[str]] = {w: set() for w in want}
    for b in blocks:
        key = (b.folderName or "").replace("\\", "/").strip("/").lower()
        if key in found and (b.fileName or "").lower().endswith(".pac"):
            found[key].add(b.fileName)
    return {k: sorted(v) for k, v in found.items()}


def groups_with_path(xml: str, folder: str) -> list[str]:
    """Names of every <BasicCutType> whose <Path> list contains `folder`."""
    names = []
    for m in re.finditer(r'<BasicCutType\s+Name="([^"]+)"\s*>(.*?)</BasicCutType>', xml, re.S):
        if re.search(rf"<Path>\s*{re.escape(folder)}\s*</Path>", m.group(2), re.I):
            names.append(m.group(1))
    return names


def strip_path(xml: str, group: str, folder: str) -> str:
    m = re.search(rf'<BasicCutType\s+Name="{re.escape(group)}"\s*>.*?</BasicCutType>', xml, re.S)
    block = m.group(0)
    new = re.sub(rf"[ \t]*<Path>\s*{re.escape(folder)}\s*</Path>\r?\n", "", block, flags=re.I)
    return xml.replace(block, new)


def apply_registry(xml: str, registry: dict, tier: str, tops: dict, staged: dict) -> tuple[str, dict]:
    """Return (new xml, per-class report). Pure function: no file access."""
    xml = re.sub(r"<!-- BDO-AIO open-chest BEGIN .*? -->.*?<!-- BDO-AIO open-chest END .*? -->\r?\n?", "", xml, flags=re.S)
    plan: dict[str, list[str]] = {}
    report: dict[str, dict] = {}
    for prefix, entry in sorted(registry["classes"].items()):
        folder = entry["folder"]
        folder_id = folder.split("/")[1].lower()
        names = tops.get(f"character/model/{folder.lower()}", [])
        chosen = selected_stems(entry["items"], tier)
        skip = staged.get(folder_id, set())
        keep = {s for s in chosen if f"{s}.pac" not in skip}
        keep |= {f"{s}_dm" for s in keep}
        uncut = [n for n in names if n[:-4].lower() in keep]
        info = {"selected": len(chosen), "staged_skipped": len(chosen) - len({s for s in keep if not s.endswith("_dm")}),
                "uncut": len(uncut), "applied": False}
        report[prefix] = info
        if not uncut:
            continue
        groups = groups_with_path(xml, folder)
        if not groups:
            info["note"] = "folder is not in a BasicCutType; left vanilla"
            continue
        recut = [f"{folder}/{n}" for n in names if n not in uncut]
        for g in groups:
            xml = strip_path(xml, g, folder)
            plan.setdefault(g, []).extend(recut)
        info["applied"] = True
    if plan:
        blocks = []
        for g, files in plan.items():
            blocks += [BEGIN.format(group=g), f'<CutType Name="{g}">', *[f"  <File>{f}</File>" for f in files], "</CutType>", END.format(group=g)]
        anchor = xml.find("<Relation")  # nothing after the first <Relation> is read by the game
        if anchor < 0:
            raise ValueError("no <Relation> to anchor against; partcutdesc.xml looks malformed")
        nl = "\r\n" if "\r\n" in xml else "\n"  # keep the file's own line endings
        xml = xml[:anchor] + nl.join(blocks) + nl + xml[anchor:]
    return xml, report


def apply_file(xml_path: pathlib.Path, registry: dict, tier: str, tops: dict, staged: dict, write: bool = True) -> tuple[bool, dict]:
    """Rewrite `xml_path` in place; return (changed, per-class report).

    The file is handled as latin-1 bytes: it can hold non-UTF-8 names, which a UTF-8
    round trip would silently replace.
    """
    xml = xml_path.read_bytes().decode("latin-1")
    new_xml, report = apply_registry(xml, registry, tier, tops, staged)
    changed = new_xml != xml
    if changed and write:
        tmp = xml_path.with_suffix(".xml.tmp")
        tmp.write_bytes(new_xml.encode("latin-1"))
        os.replace(tmp, xml_path)
    return changed, report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--paz", required=True)
    ap.add_argument("--registry", required=True)
    ap.add_argument("--tier", choices=sorted(TIERS), default="open")
    ap.add_argument("--meta", default=None, help="meta to read the PAC list from (default: live pad00000.meta)")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    paz = pathlib.Path(args.paz)
    xml_path = paz / "files_to_patch" / "_PartCutGen" / "character" / CUT_FILE
    if not xml_path.is_file():
        raise SystemExit(f"[FATAL] {xml_path} not found - run PartCutGen first")
    registry = json.loads(pathlib.Path(args.registry).read_text("utf-8"))
    if registry.get("schema") != SCHEMA:
        raise SystemExit(f"[FATAL] unsupported registry schema {registry.get('schema')!r}")
    meta_name = args.meta or "pad00000.meta"
    folders = {e["folder"] for e in registry["classes"].values() if e["items"]}
    tops = meta_tops(paz, meta_name, folders)
    staged = staged_tops(paz / "files_to_patch")
    changed, report = apply_file(xml_path, registry, args.tier, tops, staged, write=not args.dry_run)
    log(f"  tier={args.tier} registry client {registry.get('client_version')}")
    live = meta_version(paz / meta_name)
    if registry.get("client_version") != live:
        # Tops added by a patch are absent from the registry and keep the vanilla cut (safe, not uncut).
        log(f"  [!] registry was scanned on client {registry.get('client_version')}, game is {live}: "
            "new outfits keep their vanilla cut until open_chest_scan.py is re-run")
    for prefix, info in report.items():
        if info["selected"]:
            note = f"  ({info['note']})" if "note" in info else ""
            log(f"  {prefix:5s} selected={info['selected']:3d} uncut={info['uncut']:3d} staged-skip={info['staged_skipped']:2d}{note}")
    if args.dry_run:
        log("  dry run: partcutdesc.xml not modified")
        return 0
    log(f"  classes uncut: {sum(1 for i in report.values() if i['applied'])}  (partcutdesc.xml {'rewritten' if changed else 'unchanged'})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
