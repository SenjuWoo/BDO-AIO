from __future__ import annotations

import pathlib
import unittest

from inject_stage_builder import (
    MARKER_NAME,
    Candidate,
    materialize,
    meta_injector_path,
    route_missing_generated_files,
    select_winners,
)


class InjectStageBuilderTests(unittest.TestCase):
    def test_strips_organizer_directories_but_keeps_game_path(self) -> None:
        internal, add, legacy, reason = meta_injector_path(
            pathlib.PurePath("_midnight_xyzw", "_01_xyzw_collections", "character", "texture", "x.dds")
        )
        self.assertEqual(internal, "character/texture/x.dds")
        self.assertFalse(add)
        self.assertFalse(legacy)
        self.assertIsNone(reason)

    def test_migrates_old_unmarked_pubic_style_directory(self) -> None:
        internal, add, _, reason = meta_injector_path(
            pathlib.PurePath(
                "_pubic_hair_EXPERIMENTAL_reuse", "full_bush",
                "character", "texture", "x.dds",
            )
        )
        self.assertEqual(internal, "character/texture/x.dds")
        self.assertFalse(add)
        self.assertIsNone(reason)

    def test_ignores_old_generated_readme(self) -> None:
        internal, _, _, reason = meta_injector_path(
            pathlib.PurePath("_pubic_hair_EXPERIMENTAL_reuse", "full_bush", "README.txt")
        )
        self.assertIsNone(internal)
        self.assertEqual(reason, "ignored_tool_metadata")

    def test_preserves_add_semantics(self) -> None:
        internal, add, legacy, reason = meta_injector_path(
            pathlib.PurePath("_pack", "_add", "character", "new.pac")
        )
        self.assertEqual(internal, "character/new.pac")
        self.assertTrue(add)
        self.assertFalse(legacy)
        self.assertIsNone(reason)

    def test_double_marker_disables_branch(self) -> None:
        internal, _, _, reason = meta_injector_path(pathlib.PurePath("__disabled", "character", "x.dds"))
        self.assertIsNone(internal)
        self.assertEqual(reason, "disabled_branch")

    def test_absent_normal_file_is_excluded_but_add_is_kept(self) -> None:
        normal = Candidate("a", "a", "character/a.dds", "character/a.dds", False, False, 100, 1)
        added = Candidate("b", "b", "character/b.dds", "_add/character/b.dds", True, False, 100, 1)
        winners, absent, _ = select_winners([normal, added], set())
        self.assertEqual([item.internal_path for item in winners], ["character/b.dds"])
        self.assertEqual(absent[0]["internal_path"], "character/a.dds")

    def test_old_generated_pubic_file_is_migrated_to_add(self) -> None:
        generated = Candidate(
            "a", "_pubic_hair_EXPERIMENTAL_reuse/full_bush/character/texture/new.dds",
            "character/texture/new.dds", "character/texture/new.dds", False, False, 700, 1,
        )
        winners, absent, _ = select_winners([generated], set())
        self.assertFalse(absent)
        self.assertTrue(winners[0].add)
        self.assertEqual(winners[0].stage_relative, "_add/character/texture/new.dds")

    def test_higher_priority_layer_wins_collision(self) -> None:
        base = Candidate("a", "_midnight/a", "character/x.dds", "character/x.dds", False, False, 100, 1)
        overlay = Candidate("b", "_pubic/b", "character/x.dds", "character/x.dds", False, False, 400, 1)
        winners, _, overrides = select_winners([overlay, base], {"character/x.dds"})
        self.assertEqual(winners[0].source, "b")
        self.assertEqual(overrides[0]["replaced"], ["_midnight/a"])

    def test_composited_pubic_texture_wins_plain_genital_texture(self) -> None:
        genital = Candidate(
            "genital", "_genital_RESTORED_native/character/texture/pbw_00_nude_0001.dds",
            "character/texture/pbw_00_nude_0001.dds", "character/texture/pbw_00_nude_0001.dds",
            False, False, 600, 1,
        )
        pubic = Candidate(
            "pubic", "_pubic_hair_RESTORED_native/_full_bush/character/texture/pbw_00_nude_0001.dds",
            "character/texture/pbw_00_nude_0001.dds", "character/texture/pbw_00_nude_0001.dds",
            False, False, 700, 1,
        )
        winners, _, _ = select_winners([pubic, genital], {pubic.internal_path})
        self.assertEqual(winners[0].source, "pubic")

    def test_materialize_uses_owned_atomic_stage(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            source = root / "source.dds"
            source.write_bytes(b"DDS test")
            stage = root / "stage"
            winner = Candidate(
                str(source), "_pack/character/texture/source.dds",
                "character/texture/source.dds", "character/texture/source.dds",
                False, False, 100, source.stat().st_size,
            )
            materialize(stage, [winner], {"counts": {}})
            self.assertTrue((stage / MARKER_NAME).is_file())
            self.assertEqual(
                (stage / "character" / "texture" / "source.dds").read_bytes(),
                b"DDS test",
            )

    def test_failed_promotion_preserves_previous_stage_and_retry_works(self) -> None:
        import tempfile
        from unittest.mock import patch

        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            stage = root / "stage"
            stage.mkdir()
            (stage / MARKER_NAME).write_text("owned")
            (stage / "previous.dds").write_bytes(b"previous")
            source = root / "new.dds"
            source.write_bytes(b"replacement")
            winner = Candidate(str(source), "new.dds", "new.dds", "new.dds", False, False, 100, 11)
            rename = pathlib.Path.rename

            def fail_promotion(path, target):
                if path == stage.with_name("stage.building"):
                    raise PermissionError("replacement rename denied")
                return rename(path, target)

            with patch.object(pathlib.Path, "rename", fail_promotion):
                with self.assertRaisesRegex(PermissionError, "replacement rename denied"):
                    materialize(stage, [winner], {})
            self.assertTrue((stage / "previous.dds").is_file(), "Previous working stage was deleted")
            self.assertEqual((stage / "previous.dds").read_bytes(), b"previous")
            self.assertFalse(stage.with_name("stage.building").exists())
            materialize(stage, [winner], {})
            self.assertEqual((stage / "new.dds").read_bytes(), b"replacement")
            self.assertFalse((stage / "previous.dds").exists())
            self.assertEqual(list(root.glob("stage.previous-*")), [])

    def test_routes_intentional_new_file_through_add_marker(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as temp:
            out = pathlib.Path(temp)
            generated = out / "character" / "texture" / "new.dds"
            generated.parent.mkdir(parents=True)
            generated.write_bytes(b"DDS test")
            moved = route_missing_generated_files(out, set())
            self.assertEqual(moved, ["character/texture/new.dds"])
            self.assertFalse(generated.exists())
            self.assertTrue((out / "_add" / "character" / "texture" / "new.dds").is_file())


if __name__ == "__main__":
    unittest.main()
