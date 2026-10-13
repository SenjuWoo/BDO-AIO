from __future__ import annotations

import struct
import unittest

try:
    import numpy as np
except ImportError:  # the scanner needs numpy; the launcher itself does not
    raise unittest.SkipTest("numpy not installed")

import pac_geometry


def lod_block(positions: np.ndarray, triangles: np.ndarray) -> bytes:
    verts = np.zeros((len(positions), 32), dtype=np.uint8)
    verts[:, :12] = positions.astype("<f4").view(np.uint8).reshape(-1, 12)
    verts[:, 12:] = 0xAB  # normals/uv/weights are ignored
    return (
        struct.pack("<H", len(positions)) + verts.tobytes()
        + struct.pack("<I", triangles.size) + triangles.astype("<u2").tobytes()
    )


EMPTY_LOD = struct.pack("<HI", 0, 0)
QUAD = np.array([[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0]], dtype=np.float32)
TRIS = np.array([[0, 1, 2], [0, 2, 3]], dtype=np.int32)


def mesh_block(name: str, lods: list[bytes]) -> bytes:
    return bytes([len(name)]) + name.encode() + b"\x01\x00" + b"".join(lods)


class ReadPacMeshesTests(unittest.TestCase):
    def test_reads_lod0_of_every_mesh_after_a_junk_header(self) -> None:
        second = QUAD + np.float32(5)
        data = (
            b"PAR \x03\x01\x00" + bytes(range(1, 90)) + b"\x00\x02\x00"
            + mesh_block("PEW_00_UB_0001", [lod_block(QUAD, TRIS)] * 3)
            + mesh_block("PEW_03_UB_0002", [lod_block(second, TRIS), EMPTY_LOD, EMPTY_LOD])
        )
        meshes = pac_geometry.read_pac_meshes(data)
        self.assertEqual([m.name for m in meshes], ["PEW_00_UB_0001", "PEW_03_UB_0002"])
        np.testing.assert_allclose(meshes[0].positions, QUAD)
        np.testing.assert_allclose(meshes[1].positions, second)
        np.testing.assert_array_equal(meshes[1].triangles, TRIS)

    def test_rejects_indices_beyond_the_vertex_count(self) -> None:
        bad = lod_block(QUAD, np.array([[0, 1, 9]]))
        self.assertEqual(pac_geometry.read_pac_meshes(mesh_block("X_BAD_MESH", [bad] * 3)), [])

    def test_name_whose_length_prefix_lies_is_not_a_mesh(self) -> None:
        data = b"\x05" + b"PEW_00_UB_0001" + b"\x01\x00" + lod_block(QUAD, TRIS) * 3
        self.assertEqual(pac_geometry.read_pac_meshes(data), [])

    def test_empty_and_garbage_input(self) -> None:
        self.assertEqual(pac_geometry.read_pac_meshes(b""), [])
        self.assertEqual(pac_geometry.read_pac_meshes(bytes(range(256)) * 20), [])

    def test_mesh_without_lod0_geometry_is_skipped(self) -> None:
        self.assertEqual(pac_geometry.read_pac_meshes(mesh_block("PEW_00_UB_0009", [EMPTY_LOD] * 3)), [])


if __name__ == "__main__":
    unittest.main()
