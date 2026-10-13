#!/usr/bin/env python3
"""Render front-view contact sheets of the tops an open-chest registry selects (review aid).

Dev only (needs numpy + matplotlib). Reads the live meta/PAZ, writes PNGs under --out.

    python dev/open_chest_sheet.py --paz "<PAZ>" --registry tools/bdo_meta/open_chest_registry.json \
        --classes pew --band window --out sheets
"""
from __future__ import annotations

import argparse
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "tools" / "bdo_meta"))

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.collections import PolyCollection
from matplotlib.colors import to_rgba

from body_size_patcher import IceDecipher, extract_block
from open_chest import BodyReference
from open_chest_apply import TIERS
from open_chest_scan import _norm, load_blocks
from pac_geometry import read_pac_meshes
from vanilla_restore import AIO_BACKUP_NAME

COLORS = ["#2a7", "#c52", "#58c", "#cb3", "#a5c", "#3bb"]


def draw(ax, body, garment, title):
    polys = [body.positions[body.triangles]] if hasattr(body, "positions") else []
    cols = [np.tile([[0.85, 0.72, 0.66, 1.0]], (len(body.triangles), 1))]
    for i, m in enumerate(garment):
        polys.append(m.positions[m.triangles])
        cols.append(np.tile([to_rgba(COLORS[i % len(COLORS)])], (len(m.triangles), 1)))
    p, c = np.concatenate(polys), np.concatenate(cols)
    order = np.argsort(-p[:, :, 2].mean(1))  # far to near, so the front-most surface wins
    ax.add_collection(PolyCollection(p[order][:, :, :2], facecolors=c[order], edgecolors="none"))
    top = float(body.positions[:, 1].max())
    ax.set_xlim(-30, 30)
    ax.set_ylim(top - 70, top)
    ax.set_aspect("equal")
    ax.set_title(title, fontsize=7)
    ax.set_xticks([])
    ax.set_yticks([])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--paz", required=True)
    ap.add_argument("--registry", required=True)
    ap.add_argument("--classes", required=True)
    ap.add_argument("--band", choices=["open", "window", "rest"], default="window",
                    help="open/window = what that tier selects (window excludes open); rest = recorded but below both")
    ap.add_argument("--out", required=True)
    ap.add_argument("--per-sheet", type=int, default=24)
    ap.add_argument("--dpi", type=int, default=45)
    args = ap.parse_args()

    paz = pathlib.Path(args.paz)
    meta = AIO_BACKUP_NAME if (paz / AIO_BACKUP_NAME).is_file() else "pad00000.meta"
    ice = IceDecipher(pathlib.Path(__file__).resolve().parents[1] / "tools" / "bdo_meta" / "ice_decipher.dll")
    blocks = load_blocks(paz, meta, ice)
    reg = json.loads(pathlib.Path(args.registry).read_text("utf-8"))
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    open_min = TIERS["open"]
    win_min = TIERS["window"]
    for prefix in [c.strip() for c in args.classes.split(",") if c.strip()]:
        entry = reg["classes"][prefix]
        folder_id = entry["folder"].split("/")[1].lower()
        base = f"character/model/1_pc/{folder_id}"
        nude = next(b for b in blocks if _norm(b.folderName) == f"{base}/nude" and b.fileName.lower() == f"{prefix}_00_nude_0001.pac")
        body = read_pac_meshes(extract_block(paz, nude, ice))
        merged = type("B", (), {})()
        merged.positions = np.concatenate([m.positions for m in body])
        merged.triangles = np.concatenate([m.triangles + sum(len(x.positions) for x in body[:i]) for i, m in enumerate(body)])

        def band(v):
            is_open = v["mound"] >= open_min[0] and v["nipple"] >= open_min[1]
            is_win = v["nipple"] >= win_min[1]
            return "open" if is_open else "window" if is_win else "rest"

        stems = sorted((s for s, v in entry["items"].items() if band(v) == args.band),
                       key=lambda s: -entry["items"][s]["nipple"])
        tops = {b.fileName[:-4].lower(): b for b in blocks
                if _norm(b.folderName) == f"{base}/armor/9_upperbody" and b.fileName.lower().endswith(".pac")}
        for n, start in enumerate(range(0, len(stems), args.per_sheet), 1):
            chunk = stems[start:start + args.per_sheet]
            cols = min(6, args.per_sheet)
            rows = (len(chunk) + cols - 1) // cols
            fig, axes = plt.subplots(rows, cols, figsize=(2.6 * cols, 3.4 * rows), squeeze=False)
            for ax in axes.ravel():
                ax.axis("off")
            for ax, stem in zip(axes.ravel(), chunk):
                ax.axis("on")
                v = entry["items"][stem]
                draw(ax, merged, read_pac_meshes(extract_block(paz, tops[stem], ice)), f"{stem}\nmound {v['mound']:.2f} nip {v['nipple']:.2f}")
            fig.suptitle(f"{prefix} - {args.band} tops ({start + 1}-{start + len(chunk)} of {len(stems)})", fontsize=10)
            fig.tight_layout()
            path = out / f"{prefix}_{args.band}_{n:02d}.png"
            fig.savefig(path, dpi=args.dpi)
            plt.close(fig)
            print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
