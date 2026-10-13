#!/usr/bin/env python3
"""Measure how much of a class's breast region a top leaves uncovered.

Why geometry: nothing in the game data marks a top as open-chested, and the vanilla
meshes do not overlap the nude breast surface (the body under a garment is cut away, so
the garment shell sits INSIDE the nude breast volume). So coverage is judged in 2D from
the front, counting only garment triangles in the front half of the torso.

Both meshes live in the same model space, so the nude body PAC of the class is the
reference: its breast mound (the front-most band of the torso) is the region that
shows through any opening. Front is -Z, up is +Y (verified against PACtool output).
"""
from __future__ import annotations

import numpy as np

from pac_geometry import Mesh

RES = 0.25  # model units per pixel
HALF_WIDTH = 40.0
_BAND_BELOW, _BAND_ABOVE = 9.0, 10.0  # rows around the apex that make up the breast band
_MOUND_DEPTH, _NIPPLE_DEPTH = 5.0, 1.5  # front-surface depth (units) behind the apex


class Grid:
    def __init__(self, y_top: float):
        self.y0 = y_top - 110.0
        self.w = int(2 * HALF_WIDTH / RES)
        self.h = int(118.0 / RES)
        self.xs = -HALF_WIDTH + (np.arange(self.w) + 0.5) * RES
        self.ys = self.y0 + (np.arange(self.h) + 0.5) * RES

    def depth(self, meshes: list[Mesh], mode: str = "min") -> np.ndarray:
        """Per-pixel front (min) or back (max) z of every mesh; +/-inf where empty."""
        fill = np.inf if mode == "min" else -np.inf
        zb = np.full((self.h, self.w), fill, dtype=np.float32)
        pick = np.minimum if mode == "min" else np.maximum
        for mesh in meshes:
            tri = mesh.positions[mesh.triangles]
            px = (tri[:, :, 0] + HALF_WIDTH) / RES
            py = (tri[:, :, 1] - self.y0) / RES
            lo_x, hi_x = np.floor(px.min(1)).astype(int), np.ceil(px.max(1)).astype(int)
            lo_y, hi_y = np.floor(py.min(1)).astype(int), np.ceil(py.max(1)).astype(int)
            for i in range(len(tri)):
                x0, x1 = max(lo_x[i], 0), min(hi_x[i], self.w - 1)
                y0, y1 = max(lo_y[i], 0), min(hi_y[i], self.h - 1)
                if x1 < x0 or y1 < y0:
                    continue
                x, y, z = px[i], py[i], tri[i, :, 2]
                den = (y[1] - y[2]) * (x[0] - x[2]) + (x[2] - x[1]) * (y[0] - y[2])
                if abs(den) < 1e-9:
                    continue
                gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
                a = ((y[1] - y[2]) * (gx - x[2]) + (x[2] - x[1]) * (gy - y[2])) / den
                b = ((y[2] - y[0]) * (gx - x[2]) + (x[0] - x[2]) * (gy - y[2])) / den
                inside = (a >= -1e-4) & (b >= -1e-4) & (a + b <= 1 + 1e-4)
                if inside.any():
                    sub = zb[y0 : y1 + 1, x0 : x1 + 1]
                    sub[inside] = pick(sub[inside], (a * z[0] + b * z[1] + (1 - a - b) * z[2])[inside].astype(np.float32))
        return zb


class BodyReference:
    """Breast regions of a class's nude body, computed once and reused per garment."""

    def __init__(self, body: list[Mesh]):
        top = float(max(m.positions[:, 1].max() for m in body))
        self.grid = Grid(top)
        front = self.grid.depth(body, "min")
        back = self.grid.depth(body, "max")
        with np.errstate(invalid="ignore"):  # empty pixels are +inf / -inf
            self.mid = (front + back) / 2
        seen = np.isfinite(front)
        rows = (self.grid.ys > top * 0.68) & (self.grid.ys < top * 0.96)
        masked = np.where(seen & rows[:, None], front, np.inf)
        ay, _ = np.unravel_index(np.argmin(masked), masked.shape)
        apex_z = float(masked[ay].min())
        apex_y = float(self.grid.ys[ay])
        band = (self.grid.ys > apex_y - _BAND_BELOW) & (self.grid.ys < apex_y + _BAND_ABOVE)
        torso = np.abs(self.grid.xs) < 20.0
        base = seen & band[:, None] & torso[None, :]
        self.mound = base & (front < apex_z + _MOUND_DEPTH)
        self.nipple = base & (front < apex_z + _NIPPLE_DEPTH)
        self.apex_y = apex_y

    def open_fractions(self, garment: list[Mesh]) -> tuple[float, float]:
        """(breast mound, nipple zone) fraction NOT covered by the garment's front half."""
        covered = self.grid.depth(garment, "min") < self.mid
        return (
            float(1 - covered[self.mound].mean()) if self.mound.any() else 0.0,
            float(1 - covered[self.nipple].mean()) if self.nipple.any() else 0.0,
        )
