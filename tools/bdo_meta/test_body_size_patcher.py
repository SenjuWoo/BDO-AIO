from __future__ import annotations

import io
import struct
import unittest

import body_size_patcher as bsp


class MetaBlockTests(unittest.TestCase):
    def test_file_block_reads_one_fixed_width_little_endian_record(self) -> None:
        values = (11, 22, 33, 44, 55, 66, 77)
        block = bsp.FileBlock(io.BytesIO(struct.pack("<7I", *values)))
        self.assertEqual(
            (
                block.hash,
                block.folderNum,
                block.fileNum,
                block.pazNum,
                block.fileOffset,
                block.zsize,
                block.size,
            ),
            values,
        )


class AxisContractTests(unittest.TestCase):
    def test_recommended_axis_matrix_matches_the_approved_design(self) -> None:
        self.assertEqual(
            bsp.RECOMMENDED_AXES,
            {
                "breasts.x": 1.55,
                "breasts.y": 1.55,
                "breasts.z": 1.55,
                "thighs.y": 1.35,
                "thighs.z": 1.35,
                "butt.x": 1.20,
                "butt.y": 1.20,
                "butt.z": 1.20,
                "pelvis.y": 1.40,
                "pelvis.z": 1.40,
                "belly.x": 1.28,
                "belly.z": 1.45,
            },
        )

    def test_parses_canonical_axis_values_in_order(self) -> None:
        parsed = bsp.parse_axis_spec(
            " breasts.x:1.55, breasts.y:1.80 ; belly.z:1.45 "
        )
        self.assertEqual(
            parsed,
            {"breasts.x": 1.55, "breasts.y": 1.80, "belly.z": 1.45},
        )

    def test_rejects_disallowed_length_and_belly_axes(self) -> None:
        for token in ("thighs.x:1.3", "pelvis.x:1.4", "belly.y:1.4"):
            with self.subTest(token=token), self.assertRaisesRegex(ValueError, "unsupported"):
                bsp.parse_axis_spec(token)

    def test_rejects_duplicate_nonfinite_and_out_of_range_values(self) -> None:
        invalid = (
            "breasts.x:1.5,breasts.x:1.6",
            "breasts.x:nan",
            "breasts.x:0.99",
            "breasts.x:100",
        )
        for raw in invalid:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                bsp.parse_axis_spec(raw)

    def test_expands_legacy_scalars_without_inferring_new_belly_x(self) -> None:
        self.assertEqual(
            bsp.expand_legacy_token("breasts", 1.65),
            {"breasts.x": 1.65, "breasts.y": 1.65, "breasts.z": 1.65},
        )
        self.assertEqual(
            bsp.expand_legacy_token("thighs", 1.30),
            {"thighs.y": 1.30, "thighs.z": 1.30},
        )
        self.assertEqual(
            bsp.expand_legacy_token("butt", 1.18),
            {
                "butt.x": 1.18,
                "butt.y": 1.18,
                "butt.z": 1.18,
                "pelvis.y": 1.18,
                "pelvis.z": 1.18,
            },
        )
        self.assertEqual(bsp.expand_legacy_token("belly", 1.45), {"belly.z": 1.45})

    def test_retired_or_unknown_only_specs_fail_closed(self) -> None:
        for raw in ("legs:2.0", "arms:2.0", "unknown:2.0", ""):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                bsp.parse_axis_spec(raw)

    def test_builds_symmetric_bones_and_separates_hip_from_pelvis(self) -> None:
        values = bsp.build_bone_axis_values({"butt.x": 1.20, "pelvis.z": 1.40})
        self.assertEqual(values["Bip01 L Hip"], {"x": 1.20})
        self.assertEqual(values["Bip01 R Hip"], {"x": 1.20})
        self.assertEqual(values["Bip01 Pelvis"], {"z": 1.40})


class AxisPatchingTests(unittest.TestCase):
    def patch(self, raw: bytes, axes: dict[str, float]) -> tuple[bytes, int, int]:
        return bsp.patch_xml_bytes(raw, bsp.build_bone_axis_values(axes))

    def test_breast_x_can_widen_without_touching_y_or_z(self) -> None:
        raw = (
            b'<ParamDesc Min="0.70 0.70 0.70" Max="1.30 1.40 1.45" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 L Breast"/>'
        )
        patched, edits, tags = self.patch(raw, {"breasts.x": 1.55})
        self.assertEqual((edits, tags), (1, 1))
        self.assertIn(b'Max="1.55 1.40 1.45"', patched)
        self.assertIn(b'Min="0.70 0.70 0.70"', patched)
        self.assertIn(b'Default="1.00 1.00 1.00"', patched)

    def test_recommended_breasts_raise_only_components_below_155(self) -> None:
        raw = (
            b'<ParamDesc Min="0.70 0.70 0.70" Max="1.30 1.55 1.65" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 R Breast"/>'
        )
        axes = {key: value for key, value in bsp.RECOMMENDED_AXES.items() if key.startswith("breasts.")}
        patched, edits, _ = self.patch(raw, axes)
        self.assertEqual(edits, 1)
        self.assertIn(b'Max="1.55 1.55 1.65"', patched)

    def test_thigh_x_height_axis_remains_unchanged(self) -> None:
        raw = (
            b'<ParamDesc Min="0.90 0.90 0.90" Max="1.10 1.10 1.10" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 L Thigh" '
            b'HeightAxis="X" WeightAxis01="Y" WeightAxis02="Z"/>'
        )
        patched, edits, _ = self.patch(raw, {"thighs.y": 1.35, "thighs.z": 1.35})
        self.assertEqual(edits, 1)
        self.assertIn(b'Max="1.10 1.35 1.35"', patched)

    def test_pelvis_x_height_axis_remains_unchanged(self) -> None:
        raw = (
            b'<ParamDesc Min="0.90 0.90 0.90" Max="1.20 1.15 1.20" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 Pelvis" HeightAxis="X"/>'
        )
        patched, _, _ = self.patch(raw, {"pelvis.y": 1.40, "pelvis.z": 1.40})
        self.assertIn(b'Max="1.20 1.40 1.40"', patched)

    def test_spine_x_is_the_only_height_axis_exception_and_y_stays_stock(self) -> None:
        raw = (
            b'<ParamDesc Min="0.90 0.90 0.90" Max="1.20 1.25 1.35" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 Spine" '
            b'HeightAxis="X" WeightAxis01="Y" WeightAxis02="Z"/>'
        )
        patched, edits, _ = self.patch(raw, {"belly.x": 1.28, "belly.z": 1.45})
        self.assertEqual(edits, 1)
        self.assertIn(b'Max="1.28 1.25 1.45"', patched)

    def test_widen_only_never_reduces_a_higher_class_value(self) -> None:
        raw = (
            b'<ParamDesc Min="0.70 0.70 0.70" Max="1.70 1.80 1.90" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 L Breast"/>'
        )
        patched, edits, tags = self.patch(raw, {"breasts.x": 1.55, "breasts.y": 1.55})
        self.assertEqual((edits, tags), (0, 1))
        self.assertEqual(patched, raw)

    def test_patch_is_byte_length_and_padding_preserving(self) -> None:
        raw = (
            b'<ParamDesc Min="0.70 0.70 0.70" Max="1.30 1.30 1.30 " '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 L Breast"/>'
        )
        patched, _, _ = self.patch(raw, {"breasts.x": 1.55})
        self.assertEqual(len(patched), len(raw))
        self.assertIn(b'Max="1.55 1.30 1.30 "', patched)

    def test_unselected_bones_remain_byte_identical(self) -> None:
        raw = (
            b'<ParamDesc Min="0.90 0.90 0.90" Max="1.10 1.00 1.00" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 L Calf" HeightAxis="X"/>'
            b'<ParamDesc Min="0.70 0.70 0.70" Max="1.30 1.30 1.30" '
            b'Default="1.00 1.00 1.00" BoneName="Bip01 L Breast"/>'
        )
        patched, _, tags = self.patch(raw, {"breasts.z": 1.55})
        self.assertEqual(tags, 1)
        self.assertEqual(len(patched), len(raw))
        self.assertIn(
            b'Max="1.10 1.00 1.00" Default="1.00 1.00 1.00" BoneName="Bip01 L Calf"',
            patched,
        )

    def test_rejects_non_vector_max(self) -> None:
        raw = b'<ParamDesc Min="0.70 0.70 0.70" Max="1.3" Default="1.00 1.00 1.00" BoneName="Bip01 L Breast"/>'
        with self.assertRaisesRegex(ValueError, "three-component numeric vector"):
            self.patch(raw, {"breasts.x": 1.55})


class FormattingAndAxisTests(unittest.TestCase):
    def test_vector_format_matches_fixed_width_game_shape(self) -> None:
        self.assertEqual(bsp.fmt_vector(0.7), b"0.70 0.70 0.70")
        self.assertEqual(bsp.fmt_vector(10.0), b"10.0 10.0 10.0")

    def test_reads_the_axis_declared_by_the_game(self) -> None:
        self.assertEqual(bsp.height_axis_index(b'<ParamDesc HeightAxis="X"/>'), 0)
        self.assertEqual(bsp.height_axis_index(b'<ParamDesc HeightAxis="Y"/>'), 1)
        self.assertEqual(bsp.height_axis_index(b'<ParamDesc HeightAxis="Z"/>'), 2)
        self.assertIsNone(bsp.height_axis_index(b'<ParamDesc WeightAxis01="Y"/>'))


if __name__ == "__main__":
    unittest.main()
