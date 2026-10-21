#!/usr/bin/env python3
"""Scan the live client's female upper-body PACs for open-chest tops -> registry JSON.

Read-only: reads the meta + PAZ archives, writes only --out. Needs numpy.
Re-run after a client patch to pick up new outfits; unlisted outfits keep vanilla cuts.

    python open_chest_scan.py --paz "<...>/Black Desert Online/PAZ" --out open_chest_registry.json
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import pathlib
import shutil
import sys
import tempfile
import time

from body_size_patcher import IceDecipher, MetaFile, extract_block
from class_coverage import FEMALE_CLASSES
from open_chest import BodyReference
from pac_geometry import read_pac_meshes
from vanilla_restore import AIO_BACKUP_NAME, meta_version

SCHEMA = 1
MIN_RECORDED = 0.15  # tops with less open breast area are never uncut, so not stored
UPPER = "armor/9_upperbody"
EXCLUDED_CLASSES = frozenset({"plw", "pbw"})
# Old Maehwa is not in FEMALE_CLASSES (no nude/genital work) but has its own upper-body folder.
EXTRA_CLASSES = {"pkw": "12_pkw"}


def log(msg: str) -> None:
    print(msg, flush=True)


def _norm(folder: str) -> str:
    return (folder or "").replace("\\", "/").strip("/").lower()


def load_blocks(paz: pathlib.Path, meta_name: str, ice: IceDecipher):
    with tempfile.TemporaryDirectory(prefix="bdo-aio-chest-") as tmp:
        shutil.copy2(paz / meta_name, pathlib.Path(tmp) / "pad00000.meta")
        return MetaFile(pathlib.Path(tmp), ice).fileBlocks


def scan_class(paz, ice, blocks, prefix: str, folder_id: str) -> dict:
    base = f"character/model/1_pc/{folder_id}"
    nude = [b for b in blocks if _norm(b.folderName) == f"{base}/nude" and b.fileName.lower() == f"{prefix}_00_nude_0001.pac"]
    tops = [b for b in blocks if _norm(b.folderName) == f"{base}/{UPPER}" and b.fileName.lower().endswith(".pac")]
    if not nude or not tops:
        return {"folder": f"1_Pc/{folder_id}/Armor/9_Upperbody", "skipped": "no nude body" if not nude else "no tops", "items": {}}
    body = read_pac_meshes(extract_block(paz, nude[0], ice))
    if not body:
        return {"folder": f"1_Pc/{folder_id}/Armor/9_Upperbody", "skipped": "nude body unreadable", "items": {}}
    ref = BodyReference(body)
    items, unreadable = {}, 0
    for b in tops:
        stem = b.fileName[:-4].lower()
        if stem.endswith("_dm"):
            continue  # damage variant of the base PAC; follows its base at apply time
        meshes = read_pac_meshes(extract_block(paz, b, ice))
        if not meshes:
            unreadable += 1
            continue
        mound, nipple = ref.open_fractions(meshes)
        if mound >= MIN_RECORDED:
            items[stem] = {"mound": round(mound, 3), "nipple": round(nipple, 3)}
    return {
        "folder": f"1_Pc/{folder_id}/Armor/9_Upperbody",
        "tops": len(tops),
        "unreadable": unreadable,
        "items": dict(sorted(items.items())),
    }


def dump_registry(reg: dict) -> str:
    """Stable, diff-friendly JSON: classes sorted, one outfit per line, classes with nothing recorded dropped."""
    lines = ["{", f' "schema": {reg["schema"]},', f' "client_version": {reg["client_version"]},', ' "classes": {']
    classes = [(p, c) for p, c in sorted(reg["classes"].items()) if c["items"]]
    for ci, (prefix, c) in enumerate(classes):
        lines += [f' "{prefix}": {{', f'  "folder": {json.dumps(c["folder"])},', f'  "tops": {c["tops"]},', '  "items": {']
        rows = [f'   {json.dumps(k)}: {json.dumps(v)}' for k, v in c["items"].items()]
        lines += [r + ("," if i < len(rows) - 1 else "") for i, r in enumerate(rows)]
        lines += ["  }", " }" + ("," if ci < len(classes) - 1 else "")]
    return "\n".join(lines + [" }", "}"]) + "\n"


def _scan_job(args):
    # Runs in a worker process: the ICE handle and 870k-block list cannot be shared, so each loads its own.
    paz, meta_name, prefix, folder_id = args
    ice = IceDecipher(pathlib.Path(__file__).resolve().parent / "ice_decipher.dll")
    t0 = time.time()
    res = scan_class(paz, ice, load_blocks(paz, meta_name, ice), prefix, folder_id)
    return prefix, res, time.time() - t0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--paz", required=True)
    ap.add_argument("--meta", default=None, help=f"meta to read (default: {AIO_BACKUP_NAME} if present, else pad00000.meta)")
    ap.add_argument("--classes", default="", help="comma list of prefixes (default: all)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 1),
                    help="worker processes, ~1.5 GB RAM each (default: min(4, cpus))")
    args = ap.parse_args()

    paz = pathlib.Path(args.paz)
    meta_name = args.meta or (AIO_BACKUP_NAME if (paz / AIO_BACKUP_NAME).is_file() else "pad00000.meta")
    if not (paz / meta_name).is_file():
        raise SystemExit(f"[FATAL] meta not found: {paz / meta_name}")

    # Shai is excluded upstream; Tamer is excluded here: her lore has her growing up as a small
    # child and her model reads childlike, so she is treated as age-ambiguous for this feature.
    classes = {p: v[0] for p, v in FEMALE_CLASSES.items() if p not in EXCLUDED_CLASSES}
    classes.update(EXTRA_CLASSES)
    want = {c.strip().lower() for c in args.classes.split(",") if c.strip()}
    out = {"schema": SCHEMA, "client_version": meta_version(paz / meta_name), "classes": {}}
    jobs = [(paz, meta_name, p, f) for p, f in classes.items() if not want or p in want]
    results = {}
    with concurrent.futures.ProcessPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        for prefix, res, secs in pool.map(_scan_job, jobs):
            results[prefix] = res
            log(f"  {prefix:5s} tops={res.get('tops', 0):4d} open>=0.15: {len(res['items']):3d}  "
                f"unreadable={res.get('unreadable', 0)} {res.get('skipped', '')} ({secs:.0f}s)")
    out["classes"] = results  # pool.map yields in submission order, so the JSON order matches a serial run
    pathlib.Path(args.out).write_bytes(dump_registry(out).encode("utf-8"))
    log(f"wrote {args.out} (client {out['client_version']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
