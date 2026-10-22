# BDO-AIO state

## 2026-10-21 - resume after session wipe; client patched to 3474

- Recovered from disk + git (BleachBit had wiped Claude sessions; Codex backup is older than disk).
  The repo now lives at `BDO-AIO\BDO-AIO-git-push` (moved 2026-10-15); `BDO-AIO` is the installed copy.
- Game client is **3474** (patched 2026-10-16). Live `pad00000.meta` is stock 3474 (mods not live);
  `pad00000.BDOAIO-VANILLA.meta` is a stale 3454 snapshot (the injector's `backup` step re-snapshots);
  `files_to_patch` still holds 3454-era stages, which Apply-all rebuilds from the current PAZ.
- `open_chest_registry.json` rescanned on 3474: +47 tops, none removed, no score changed. Serial and
  4-job scans are byte-identical; scan time 16 min -> ~5 min (`--jobs`, default 4).
- `open_chest_apply.py` now warns when the registry client differs from the installed client.
  Dry-run against the live 3474 meta passed for every class (no game file written).
- Pipeline timing (logs/meta-inject-*.json): Meta Injector is ~152-157 s of ~160 s; our backup, stage
  build and verify total ~10 s, so there is no meaningful launcher-side speedup left.
- Unverified: newer Meta Injector / PartCutGen / Midnight versions (search and Undertow page failed).
- Gate unchanged: the user's in-game run (see 2026-10-13 below). Release stays gated on it.

## 2026-10-21 (later) - game refused to start after the second apply; fixed

- First apply (open chest Off) and screenshots were fine. Second apply (Window) injected, verify
  passed, but the game closed: "file corruption in PAD61354.PAZ". Cause and evidence in
  D-2026-10-21-J. 27 body-size entries pointed at overwritten data.
- Recovery done with the app's own restore: vanilla 3474 meta restored from the AIO snapshot,
  19 injected PAZ removed (1.65 GB), verify passed. Beauty Album presets copied to
  `backup\Customization-20261021-230331` first. The game is vanilla again; mods are NOT live.
- Code: `Ensure-VanillaMeta` guard + tests (`test_meta_inject_launcher.ps1`).
- Next: the user runs Apply saved choices once (Window), tests in game. Window uncut counts per
  class are in the 2026-10-21 operation log (e.g. pew selected 57, uncut 86).

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
