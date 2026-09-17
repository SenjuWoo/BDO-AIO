#!/usr/bin/env python3
"""Build a short, canonical Meta Injector input tree without dropping mod collections."""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import shutil
import sys
from dataclasses import asdict, dataclass

from body_size_patcher import IceDecipher, MetaFile


MARKER_NAME = ".bdo-aio-inject-stage-v1"
REPORT_NAME = ".bdo-aio-inject-manifest.json"
PUBIC_STYLE_DIRS = {
    "shaved", "shaved_innie", "full_bush", "full_bush_2", "full_bush_3",
    "medium_bush", "medium_bush2", "small_bush", "small_bush_2",
    "thin_landing_strip", "wide_landing_strip", "trimmed", "wider_trimmed",
}


@dataclass
class Candidate:
    source: str
    source_relative: str
    internal_path: str
    stage_relative: str
    add: bool
    legacy: bool
    priority: int
    size: int


def normalize_internal(path: str) -> str:
    return "/".join(part for part in path.replace("\\", "/").split("/") if part).lower()


def layer_priority(parts: tuple[str, ...]) -> int:
    if not parts:
        return 0
    top = parts[0].lower()
    if not top.startswith(("_", ".")):
        return 1000  # direct user-authored game path wins
    known = (
        ("_midnight_xyzw", 100),
        ("_body_size_limits", 200),
        ("_slot_hide_", 300),
        # Pubic output is a composited nude DDS and must win over the plain nude
        # texture carried by some genital packs. The genital PAC still remains.
        ("_pubic_hair_", 700),
        ("_censorship_", 500),
        ("_genital_", 600),
    )
    for prefix, priority in known:
        if top.startswith(prefix):
            return priority
    return 150


def meta_injector_path(relative: pathlib.PurePath) -> tuple[str | None, bool, bool, str | None]:
    """Mirror Meta Injector 1.4.1's directory marker behavior."""
    if relative.name.lower() == "readme.txt":
        return None, False, False, "ignored_tool_metadata"
    if relative.name.startswith((".", "_")):
        return None, False, False, "ignored_filename"
    kept: list[str] = []
    add = False
    legacy = False
    for index, part in enumerate(relative.parts[:-1]):
        # 2.0.0-2.0.4 accidentally emitted an unmarked style directory. Treat
        # that known AIO layer as an organizer so existing outputs migrate.
        if (
            index == 1
            and relative.parts[0].lower().startswith("_pubic_hair_")
            and part.lower() in PUBIC_STYLE_DIRS
        ):
            continue
        if part.startswith((".", "_")):
            remainder = part[1:]
            if remainder.startswith(part[0]):
                return None, False, False, "disabled_branch"
            if remainder.lower() == "add":
                add = True
            elif remainder.lower() == "legacy":
                legacy = True
            continue
        kept.append(part)
    internal = normalize_internal("/".join((*kept, relative.name)))
    if not internal:
        return None, add, legacy, "empty_internal_path"
    return internal, add, legacy, None


def collect_candidates(source: pathlib.Path) -> tuple[list[Candidate], list[dict]]:
    candidates: list[Candidate] = []
    ignored: list[dict] = []
    files = sorted((p for p in source.rglob("*") if p.is_file()), key=lambda p: str(p.relative_to(source)).lower())
    for file_path in files:
        relative = file_path.relative_to(source)
        internal, add, legacy, reason = meta_injector_path(relative)
        if reason:
            ignored.append({"source_relative": str(relative), "reason": reason})
            continue
        assert internal is not None
        marker_prefix = "_legacy/" if legacy else ("_add/" if add else "")
        candidates.append(
            Candidate(
                source=str(file_path),
                source_relative=str(relative),
                internal_path=internal,
                stage_relative=marker_prefix + internal,
                add=add,
                legacy=legacy,
                priority=layer_priority(relative.parts),
                size=file_path.stat().st_size,
            )
        )
    return candidates, ignored


def load_known_meta(paz: pathlib.Path) -> set[str]:
    tool_dir = pathlib.Path(__file__).resolve().parent
    meta = MetaFile(paz, IceDecipher(tool_dir / "ice_decipher.dll"))
    return {
        normalize_internal(f"{block.folderName}/{block.fileName}")
        for block in meta.fileBlocks
        if block.fileName
    }


def route_missing_generated_files(output: pathlib.Path, known_meta: set[str]) -> list[str]:
    """Move intentional new generated files under Meta Injector's _add marker."""
    candidates, _ = collect_candidates(output)
    moved: list[str] = []
    for candidate in candidates:
        if candidate.add or candidate.legacy or candidate.internal_path in known_meta:
            continue
        source = pathlib.Path(candidate.source)
        destination = output.joinpath("_add", *candidate.internal_path.split("/"))
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists():
            destination.unlink()
        shutil.move(str(source), str(destination))
        moved.append(candidate.internal_path)
    for directory in sorted(
        (p for p in output.rglob("*") if p.is_dir() and "_add" not in p.parts),
        key=lambda p: len(p.parts),
        reverse=True,
    ):
        try:
            directory.rmdir()
        except OSError:
            pass
    return moved


def select_winners(candidates: list[Candidate], known_meta: set[str]) -> tuple[list[Candidate], list[dict], list[dict]]:
    absent: list[dict] = []
    eligible: list[Candidate] = []
    for candidate in candidates:
        if candidate.internal_path not in known_meta and not candidate.add and not candidate.legacy:
            top = pathlib.PurePath(candidate.source_relative).parts[0].lower()
            if top.startswith(("_pubic_hair_", "_genital_")):
                candidate.add = True
                candidate.stage_relative = "_add/" + candidate.internal_path
            else:
                absent.append({
                    "source_relative": candidate.source_relative,
                    "internal_path": candidate.internal_path,
                    "reason": "not_in_current_meta",
                })
                continue
        eligible.append(candidate)

    by_internal: dict[str, list[Candidate]] = {}
    for candidate in eligible:
        by_internal.setdefault(candidate.internal_path, []).append(candidate)

    winners: list[Candidate] = []
    overrides: list[dict] = []
    for internal, group in sorted(by_internal.items()):
        ordered = sorted(group, key=lambda c: (c.priority, c.source_relative.lower()))
        winner = ordered[-1]
        winners.append(winner)
        if len(ordered) > 1:
            overrides.append({
                "internal_path": internal,
                "winner": winner.source_relative,
                "replaced": [item.source_relative for item in ordered[:-1]],
            })
    return winners, absent, overrides


def safe_remove_owned_stage(path: pathlib.Path) -> None:
    if not path.exists():
        return
    if not (path / MARKER_NAME).is_file():
        raise RuntimeError(f"refusing to remove unowned directory: {path}")
    shutil.rmtree(path)


def materialize(stage: pathlib.Path, winners: list[Candidate], report: dict) -> None:
    building = stage.with_name(stage.name + ".building")
    safe_remove_owned_stage(building)
    building.mkdir(parents=True)
    (building / MARKER_NAME).write_text("BDO-AIO owned injection stage\n", encoding="ascii")
    hardlinks = 0
    copies = 0
    try:
        for candidate in winners:
            destination = building.joinpath(*candidate.stage_relative.split("/"))
            destination.parent.mkdir(parents=True, exist_ok=True)
            try:
                os.link(candidate.source, destination)
                hardlinks += 1
            except OSError:
                shutil.copy2(candidate.source, destination)
                copies += 1
        report["materialized"] = {"hardlinks": hardlinks, "copies": copies}
        (building / REPORT_NAME).write_text(json.dumps(report, indent=2), encoding="utf-8")
        previous = None
        if stage.exists():
            if not (stage / MARKER_NAME).is_file():
                raise RuntimeError(f"refusing to replace unowned directory: {stage}")
            import uuid
            previous = stage.with_name(stage.name + ".previous-" + uuid.uuid4().hex)
            stage.rename(previous)
        try:
            building.rename(stage)
        except Exception:
            if previous is not None:
                previous.rename(stage)
            raise
        if previous is not None:
            safe_remove_owned_stage(previous)
    except Exception:
        safe_remove_owned_stage(building)
        raise


def build_report(paz: pathlib.Path, source: pathlib.Path, stage: pathlib.Path, dry_run: bool) -> dict:
    known_meta = load_known_meta(paz)
    candidates, ignored = collect_candidates(source)
    winners, absent, overrides = select_winners(candidates, known_meta)
    max_source = max((len(c.source) for c in candidates), default=0)
    max_stage = max((len(str(stage.joinpath(*c.stage_relative.split("/")))) for c in winners), default=0)
    report = {
        "version": 1,
        "paz": str(paz),
        "source": str(source),
        "stage": str(stage),
        "dry_run": dry_run,
        "counts": {
            "source_candidates": len(candidates),
            "staged_winners": len(winners),
            "ignored_by_injector_rules": len(ignored),
            "not_in_current_meta": len(absent),
            "overridden_inputs": sum(len(item["replaced"]) for item in overrides),
            "new_meta_entries": sum(1 for item in winners if item.add),
        },
        "max_paths": {"source_full": max_source, "canonical_stage_full": max_stage},
        "ignored": ignored,
        "not_in_current_meta": absent,
        "overrides": overrides,
        "winners": [asdict(item) for item in winners],
    }
    # Missing normal entries are generation/layout bugs, not a reason to quietly
    # drop content. Refuse to build until the producing tool is corrected.
    if not dry_run and not absent:
        materialize(stage, winners, report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description="Prepare a canonical short-path tree for Meta Injector 1.4.1")
    parser.add_argument("--paz", required=True)
    parser.add_argument("--source", default="")
    parser.add_argument("--stage", default="")
    parser.add_argument("--report", default="")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    paz = pathlib.Path(args.paz).resolve()
    source = pathlib.Path(args.source).resolve() if args.source else paz / "files_to_patch"
    stage = pathlib.Path(args.stage).resolve() if args.stage else paz / "BDO_AIO_INJECT"
    if not (paz / "pad00000.meta").is_file():
        print(f"[FATAL] missing {paz / 'pad00000.meta'}")
        return 2
    if not source.is_dir():
        print(f"[FATAL] missing source directory {source}")
        return 2
    if stage == source or source in stage.parents:
        print("[FATAL] stage must not be the source or a child of the source")
        return 2

    try:
        report = build_report(paz, source, stage, args.dry_run)
    except Exception as exc:
        print(f"[FATAL] {exc}")
        return 3

    if args.report:
        pathlib.Path(args.report).write_text(json.dumps(report, indent=2), encoding="utf-8")
    counts = report["counts"]
    print("=== BDO-AIO CANONICAL INJECT STAGE ===")
    print(f"Source candidates : {counts['source_candidates']}")
    print(f"Staged winners    : {counts['staged_winners']}")
    print(f"Overrides resolved: {counts['overridden_inputs']}")
    print(f"New meta entries  : {counts['new_meta_entries']}")
    print(f"Invalid/obsolete  : {counts['not_in_current_meta']}")
    print(f"Injector-ignored  : {counts['ignored_by_injector_rules']}")
    print(f"Max source path   : {report['max_paths']['source_full']}")
    print(f"Max stage path    : {report['max_paths']['canonical_stage_full']}")
    if report["not_in_current_meta"]:
        print("Files absent from the current live meta (not sent to Meta Injector):")
        for item in report["not_in_current_meta"]:
            print(f"  {item['source_relative']} -> {item['internal_path']}")
    if report["not_in_current_meta"] and not args.dry_run:
        print("Stage not written: fix the invalid/obsolete inputs above.")
        return 4
    if args.dry_run:
        print("Dry run: no stage was written.")
    else:
        print(f"Stage ready: {stage}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
