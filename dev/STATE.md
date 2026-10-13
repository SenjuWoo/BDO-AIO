# BDO-AIO state

## 2026-10-13 - open-chest outfits (2.6.0 development, branch `feat/open-chest-uncut`)

Shelved per-outfit work resumed and implemented: see [OPEN-CHEST.md](OPEN-CHEST.md) and
D-2026-10-13-I. Built and tested locally (Python + PowerShell suites); applied only to a temp
copy of `partcutdesc.xml`. Next gate is the user's in-game run: set Open-chest outfits, run
PartCutGen then Meta Injector, check a known open top (for example Ranger `pew_kw_ub_0001`,
`pew_hw_ub_0031`) and a closed top for clipping. Release stays gated on that result.
Published baseline is still v2.5.0.

## Current review checkpoint — 2026-09-17

See [REVIEW-RESUME.md](REVIEW-RESUME.md) for current review evidence and limits.
The September 11 apply and archive preflight did complete later than the snapshot
below: see the final sections of `../VALIDATION.md`. The stale-reference status
below must not be treated as today's game state. This review does not modify game
files. Local changes include a sidebar clipping fix and exception-safe stage
replacement, with regression coverage. Publication remains deferred.

## Earlier snapshot (historical)

**Date:** 2026-09-11
**Version:** `2.4.2` with unpublished dashboard/review changes.
**Published baseline:** `v2.4.2`, separate from these local changes.
**Current plan:** [IMPROVEMENT-PLAN.md](IMPROVEMENT-PLAN.md).

## Current development state

Native WPF dashboard and reviewed backend fixes are implemented. Source Python and
ten Windows PowerShell suites pass locally. Independent follow-up UI review closed
stale-scan, failure-state and validation-focus findings. Publishing/pushing is deferred.
The post-runtime rerun revalidated all ten PowerShell suites. Four stale verifier
processes had held the shared save mutex; after they were closed, `test_dashboard.ps1`
passed without weakening the guard or touching user settings.

Current live state after the user's authorized full apply on 2026-09-11: game client
**3444**, same-version AIO vanilla reference **3444**, and **2,254** staged files.
Meta Injector completed with exit code 0 and post-injection verification passed; the
live meta is now `MODIFIED` relative to the retained vanilla reference. The user also
confirmed the selected saved setup works in-game. The older 3435 backup remains retained
but is not eligible for restore.

Full-install synchronization and read-only launch checks are recorded in
`VALIDATION.md`. Keyboard/DPI/accessibility exercise and broader class/outfit coverage
remain separate from this successful selected-setup test. No preview release artifact
has been published. A local clean full-pack preflight archive is retained at
`Z:\Backup\Ai documentation\BDO-AIO-preflight-2.4.2-full-clean.7z`; Body UNCUT
remains shelved research.

## Historical observation below — not current game or release state

## Status: client-version rollback fixed; user's game is clean vanilla

A client patch (3412 -> 3418) plus an inject run left the meta reporting an older
client version than the one installed. The launcher treated that as a rollback,
re-downloaded ~1 GB of patches and replaced `pad00000.meta`, wiping the injection and
leaving 1.65 GB of orphaned archives. The visible symptom was "corrupted files".
Nothing was corrupt. PartCutGen was suspected and cleared.

2.4.2 records the client version before injecting and re-checks it after, refuses to
restore a snapshot from a different client version, and adds `verify`. Full write-up:
`dev/CLIENT-PATCH-RULES.md`.

## Live machine state (2026-08-27)

- `pad00000.meta` verified: 861,376 blocks, 0 missing archives, 0 overruns, version 3418.
- Vanilla snapshot exists again (`pad00000.BDOAIO-VANILLA.meta`, `meta_version: 3418`).
  There was **none at all** before - any restore would have needed a Steam repair.
- 19 orphaned `PAD6133x-6135x.PAZ` deleted, 1.65 GB reclaimed.
- `files_to_patch` still holds the user's five stages plus a freshly generated
  `_PartCutGen/character/partcutdesc.xml`.
- **Mods are not currently applied.** The pipeline has not been re-run since the patch.

## Historical next steps (2026-08-27, superseded by the current plan)

1. User re-runs deploy -> PartCutGen -> Meta Injector.
2. Watch for `Client version before inject: 3418` and the post-inject check. If it
   reports a mismatch, Meta Injector reproduces the bug and it is worth reporting to
   that tool's author - the AIO can only detect it, not prevent it.

## Do not repeat

1. Verify class prefixes against `$Script:FemaleClasses` - `phw` is Sorceress, `pew` is
   Ranger. Assuming otherwise invalidated an entire test campaign.
2. Never blank DXT1 or `*_cull*` textures - `dev/TEXTURE-BLANKING-RULES.md`.
3. Judge injected/vanilla state from the **meta**, never from folders or stray archives
   on disk. Two guards used disk artefacts as a proxy and both were wrong.
4. Never restore a vanilla snapshot taken under a different client version.
