#!/usr/bin/env python3
"""
Per-outfit body uncut for a folder-cut garment group.

PartCutGen's .partcutdesc_exclusions.txt can only move <File> entries into
<CutType Name="Disable">. That does nothing for a group whose membership comes from a
folder rule:

    <BasicCutType Name="PEW_Upperbody">
      <Path>1_Pc/3_PEW/Armor/9_Upperbody</Path>   <- all 348 Ranger tops, by folder

Measured: staging all 80 free Ranger tops into Disable changed nothing in game, because
the folder <Path> still puts them in the cut group. Deleting that <Path> restores the
whole body under every Ranger top -- Look 7's areola came back and every closed top
started clipping.

So this tool inverts it. BasicCutType (by folder) and CutType (by file) declare
membership in the SAME group -- <Relation> references the group by name either way. Drop
the folder <Path>, then re-add a <CutType> listing every PAC in that folder EXCEPT the
ones named by --keep. Kept garments leave the group and render the whole body; everything
else keeps its vanilla cut and does not clip.

Run AFTER PartCutGen and BEFORE Meta Injector. PartCutGen rewrites partcutdesc.xml, so
re-run this on every regeneration. Idempotent: the generated block is fenced by markers
and replaced wholesale.
"""
from __future__ import annotations

import argparse
import fnmatch
import pathlib
import re
import shutil
import sys
import tempfile

from body_size_patcher import IceDecipher, MetaFile

BEGIN = "<!-- BDO-AIO recut BEGIN {group} -->"
END = "<!-- BDO-AIO recut END {group} -->"


def log(m: str) -> None:
    print(m, flush=True)


def folder_pacs(paz: pathlib.Path, meta_name: str, folder: str) -> list[str]:
    """Every .pac the archives hold in `folder`, as partcutdesc-style paths."""
    dll = pathlib.Path(__file__).resolve().parent / "ice_decipher.dll"
    ice = IceDecipher(dll)
    with tempfile.TemporaryDirectory(prefix="bdo-aio-recut-") as temp:
        work = pathlib.Path(temp)
        shutil.copy2(paz / meta_name, work / "pad00000.meta")
        meta = MetaFile(work, ice)
    want = f"character/model/{folder.lower()}"
    out = []
    for b in meta.fileBlocks:
        got = (b.folderName or "").replace("\\", "/").strip("/").lower()
        name = (b.fileName or "")
        if got == want and name.lower().endswith(".pac"):
            out.append(f"{folder}/{name}")
    return sorted(set(out))


def strip_folder_path(xml: str, group: str, folder: str) -> tuple[str, bool]:
    m = re.search(rf'<BasicCutType\s+Name="{re.escape(group)}"\s*>.*?</BasicCutType>', xml, re.S)
    if not m:
        raise SystemExit(f"[FATAL] no <BasicCutType Name=\"{group}\">")
    blk = m.group(0)
    new = re.sub(rf'[ \t]*<Path>{re.escape(folder)}</Path>\r?\n', "", blk, flags=re.I)
    return xml.replace(blk, new), new != blk


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--xml", required=True, help="files_to_patch/_PartCutGen/character/partcutdesc.xml")
    ap.add_argument("--paz", required=True)
    ap.add_argument("--group", required=True, help="e.g. PEW_Upperbody")
    ap.add_argument("--folder", required=True, help="e.g. 1_Pc/3_PEW/Armor/9_Upperbody")
    ap.add_argument("--keep", default="", help="comma separated globs to leave UNCUT")
    ap.add_argument(
        "--meta",
        default=None,
        help="meta filename to analyze (default: live pad00000.meta; pass a snapshot explicitly for research)",
    )
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    xml_path = pathlib.Path(args.xml)
    paz = pathlib.Path(args.paz)
    meta_name = args.meta or "pad00000.meta"
    if not (paz / meta_name).is_file():
        raise SystemExit(f"[FATAL] meta file not found: {paz / meta_name}")

    keep = [k.strip().lower() for k in args.keep.split(",") if k.strip()]
    pacs = folder_pacs(paz, meta_name, args.folder)
    if not pacs:
        raise SystemExit(f"[FATAL] no .pac found in {args.folder}")

    kept = [p for p in pacs if any(fnmatch.fnmatch(p.rsplit("/", 1)[-1].lower(), k) for k in keep)]
    recut = [p for p in pacs if p not in set(kept)]
    log(f"  {len(pacs)} pac in {args.folder}")
    log(f"  UNCUT (body shows through): {len(kept)}")
    for p in kept[:12]:
        log(f"     {p.rsplit('/', 1)[-1]}")
    if len(kept) > 12:
        log(f"     ... +{len(kept) - 12} more")
    log(f"  re-cut (vanilla behaviour):  {len(recut)}")
    if args.dry_run:
        return 0
    if not kept:
        log("  [WARN] --keep matched nothing; this re-cuts the whole folder (vanilla).")

    # latin-1 round trip keeps every byte: the file can hold non-UTF-8 names (0x8c measured)
    xml = xml_path.read_bytes().decode("latin-1")
    begin, end = BEGIN.format(group=args.group), END.format(group=args.group)

    # drop any previous run's block, then the folder rule
    xml = re.sub(re.escape(begin) + r".*?" + re.escape(end) + r"\r?\n?", "", xml, flags=re.S)
    xml, removed = strip_folder_path(xml, args.group, args.folder)
    log(f"  folder <Path> removed: {removed}")

    lines = [begin, f'<CutType Name="{args.group}">']
    lines += [f"  <File>{p}</File>" for p in recut]
    lines += ["</CutType>", end, ""]
    block = "\n".join(lines)

    # Every CutType/BasicCutType in the stock file precedes the <Relation> run, and a
    # block appended after them is silently ignored (measured: 268 re-cut files had no
    # effect in game). Insert ahead of the first <Relation> instead.
    anchor = xml.find("<Relation")
    if anchor < 0:
        raise SystemExit("[FATAL] no <Relation> to anchor against")
    nl = "\r\n" if "\r\n" in xml else "\n"
    xml_path.write_bytes((xml[:anchor] + block.replace("\n", nl) + xml[anchor:]).encode("latin-1"))
    log(f"  wrote {len(recut)} <File> entries into <CutType Name=\"{args.group}\">")
    log("  next: Meta Injector (step 5), then restart the client")
    return 0


if __name__ == "__main__":
    sys.exit(main())
