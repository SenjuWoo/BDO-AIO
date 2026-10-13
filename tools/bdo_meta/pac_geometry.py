#!/usr/bin/env python3
"""Read mesh geometry (LOD0 positions + triangles) from a Black Desert `.pac` model.

Layout, measured against PACtool 1.4.4 output on live-client PACs (positions match to
2e-11, triangles match exactly):

    <variable-length header>
    per mesh:  u8 len, ascii material name, u16 (always 1 so far), then 3 LODs of
        u16 vertex_count          (LOD1/LOD2 may be absent: u16 0 + u32 0)
        vertex_count * 32 bytes   (float32 x, y, z first; the other 20 bytes are
                                   normal/uv/weights and are ignored here)
        u32 index_count           (multiple of 3)
        index_count * u16

The header length varies per file, so meshes are located by scanning for the
name+marker pattern and accepting a candidate only when all three LOD blocks parse and
every index is below its vertex count. A file that yields nothing is reported as empty
rather than guessed at.
"""
from __future__ import annotations

import re
import struct
from dataclasses import dataclass

import numpy as np

VERTEX_STRIDE = 32
LOD_COUNT = 3
_MAX_VERTS = 65535
_NAME = re.compile(rb"([\x01-\x60])([A-Za-z0-9_.\- ]{3,96})\x01\x00")


@dataclass(frozen=True)
class Mesh:
    name: str
    positions: np.ndarray  # (N, 3) float32, LOD0
    triangles: np.ndarray  # (M, 3) int32, LOD0


def _read_lod(data: bytes, pos: int):
    """Parse one LOD block at `pos`; return (positions, triangles, end) or None."""
    if pos + 2 > len(data):
        return None
    vcount = struct.unpack_from("<H", data, pos)[0]
    if vcount == 0 and pos + 6 <= len(data) and struct.unpack_from("<I", data, pos + 2)[0] == 0:
        return None, None, pos + 6  # a mesh may omit lower LODs: u16 0 + u32 0
    if vcount < 3:
        return None
    vstart = pos + 2
    vend = vstart + vcount * VERTEX_STRIDE
    if vend + 4 > len(data):
        return None
    icount = struct.unpack_from("<I", data, vend)[0]
    if icount == 0 or icount % 3 or icount > 3 * _MAX_VERTS * 4:
        return None
    iend = vend + 4 + icount * 2
    if iend > len(data):
        return None
    idx = np.frombuffer(data, dtype="<u2", count=icount, offset=vend + 4)
    if int(idx.max()) >= vcount:
        return None
    verts = np.frombuffer(data, dtype=np.uint8, count=vcount * VERTEX_STRIDE, offset=vstart)
    pos3 = verts.reshape(vcount, VERTEX_STRIDE)[:, :12].copy().view("<f4").reshape(vcount, 3)
    if not np.isfinite(pos3).all() or float(np.abs(pos3).max()) > 5000.0:
        return None
    return pos3, idx.astype(np.int32).reshape(-1, 3), iend


def read_pac_meshes(data: bytes) -> list[Mesh]:
    """Every mesh in the PAC, LOD0 geometry only. Empty list if none validate."""
    meshes: list[Mesh] = []
    cursor = 0
    while True:
        m = _NAME.search(data, cursor)
        if not m:
            break
        if m.group(1)[0] != len(m.group(2)):
            cursor = m.start() + 1
            continue
        pos, lod0 = m.end(), None
        for lod in range(LOD_COUNT):
            got = _read_lod(data, pos)
            if got is None or (lod == 0 and got[0] is None):
                lod0 = None
                break
            if lod == 0:
                lod0 = got
            pos = got[2]
        if lod0 is None:
            cursor = m.start() + 1
            continue
        meshes.append(Mesh(m.group(2).decode("ascii", "replace"), lod0[0], lod0[1]))
        cursor = pos
    return meshes
