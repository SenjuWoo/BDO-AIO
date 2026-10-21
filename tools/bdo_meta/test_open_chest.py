from __future__ import annotations

import json
import unittest

try:
    import numpy as np
except ImportError:
    raise unittest.SkipTest("numpy not installed")

from open_chest import BodyReference
from open_chest_scan import dump_registry
from pac_geometry import Mesh


def grid(x0, x1, y0, y1, z, step=1.0, skip=None) -> Mesh:
    """Flat or shaped quad grid; z may be a callable. `skip(x, y)` punches holes."""
    xs, ys = np.arange(x0, x1 + 1e-6, step), np.arange(y0, y1 + 1e-6, step)
    zf = z if callable(z) else (lambda x, y: z)
    pos = np.array([[x, y, zf(x, y)] for y in ys for x in xs], dtype=np.float32)
    w, tris = len(xs), []
    for j in range(len(ys) - 1):
        for i in range(w - 1):
            if skip and skip(xs[i] + step / 2, ys[j] + step / 2):
                continue
            a, b, c, d = j * w + i, j * w + i + 1, (j + 1) * w + i + 1, (j + 1) * w + i
            tris += [[a, b, c], [a, c, d]]
    return Mesh("grid", pos, np.array(tris, dtype=np.int32))


def bump(x, y):  # two breasts at y=150, front is -Z
    return -8 - 12 * (np.exp(-((abs(x) - 7) ** 2 + (y - 150) ** 2) / 18))


class OpenChestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.body = BodyReference([grid(-16, 16, 100, 180, bump, 0.5), grid(-16, 16, 100, 180, 8.0, 2.0)])

    def test_garment_covering_the_chest_is_closed(self) -> None:
        mound, nipple = self.body.open_fractions([grid(-20, 20, 100, 180, -25.0, 0.5)])
        self.assertLess(mound, 0.02)
        self.assertLess(nipple, 0.02)

    def test_garment_without_a_chest_piece_is_fully_open(self) -> None:
        mound, nipple = self.body.open_fractions([grid(-20, 20, 100, 125, -25.0)])
        self.assertGreater(mound, 0.98)
        self.assertGreater(nipple, 0.98)

    def test_window_is_between_closed_and_open(self) -> None:
        hole = lambda x, y: abs(x) < 8 and 143 < y < 157  # plunge: bares the inner half of each breast
        mound, nipple = self.body.open_fractions([grid(-20, 20, 100, 180, -25.0, 0.5, skip=hole)])
        self.assertGreater(mound, 0.2)
        self.assertLess(mound, 0.9)

    def test_back_panel_does_not_count_as_cover(self) -> None:
        mound, _ = self.body.open_fractions([grid(-20, 20, 100, 180, 20.0, 1.0)])  # behind the body
        self.assertGreater(mound, 0.98)


class RegistryDumpTests(unittest.TestCase):
    def test_dump_round_trips_sorted_and_drops_empty_classes(self) -> None:
        reg = {"schema": 1, "client_version": 9, "classes": {
            "pzz": {"folder": "1_Pc/2_pzz/Armor/9_Upperbody", "tops": 3, "unreadable": 0,
                    "items": {"pzz_00_ub_0001": {"mound": 0.5, "nipple": 0.25}}},
            "paa": {"folder": "1_Pc/1_paa/Armor/9_Upperbody", "tops": 2, "items": {}, "skipped": "no nude body"},
            "pbb": {"folder": "1_Pc/3_pbb/Armor/9_Upperbody", "tops": 4,
                    "items": {"a": {"mound": 1.0, "nipple": 1.0}, "b": {"mound": 0.2, "nipple": 0.0}}},
        }}
        out = json.loads(dump_registry(reg))
        self.assertEqual(list(out["classes"]), ["pbb", "pzz"])
        self.assertEqual(out["classes"]["pbb"]["items"], reg["classes"]["pbb"]["items"])
        self.assertEqual(out["client_version"], 9)


if __name__ == "__main__":
    unittest.main()
