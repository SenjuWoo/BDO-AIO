# BDO-AIO improvement plan

Updated 2026-09-11. Local/unpublished development on the 2.4.2 codebase.
Do not push, tag or publish until the requested edit/review cycle is finished.

## 0. Establish evidence and boundaries — implemented

- Source: `BDO-AIO-git-push`; full local installation: sibling `BDO-AIO`.
- Preserve personal configuration, pack assets, user staging and backups.
- Keep game data read-only during development; tests use temporary directories.
- Separate saved settings, staging, modified meta, reference verification and actual
  in-game appearance. None alone proves all the others.
- Persist per-injection timings and exit/status evidence. The authorized 2026-09-11
  run now has a structured timing report; the earlier 122-second estimate remains
  historical evidence from the older launcher.

## 1. Correctness and measured performance — implemented, runtime gate completed

- Retain the fixed-width parser optimization: prior local read-only measurements
  reduced three parser-heavy steps by 15–18%; not the whole injection process.
- Bound malformed input, clean temporary extraction state, and preserve stale-client
  snapshot refusal. Reject injected backup candidates.
- Stop workflows on generator/backup/injector/verification failure, with one boolean
  result per action. Archive old generated choices before rebuilding enabled ones.
- Keep Meta Injector's internal PAZ writes unchanged. Its binary owns the slow save
  transition; elapsed heartbeat is not internal-phase instrumentation.
- The authorized client-3444 run measured backup **77 ms**, stage build **3.842 s**,
  Meta Injector **151.200 s**, and verification **2.221 s**. The injector exited 0,
  verification passed, and the client version stayed 3444 before and after.
- Meta Injector is conclusively the dominant timed phase. No safe app-side speedup is
  justified yet; do not parallelize archive writes or skip injection without a
  separately proven no-op invariant.

## 2. Coherent native app — implemented, primary hands-on gate completed

- Native WPF shell, no browser runtime: Overview, Mod choices, Body limits,
  Detailed editor, Recovery & updates, Tools, Activity. Preserve the classic launcher.
- Native detailed controls cover private/shared pubic hair, ten supported female
  meshes, six male styles and equipment class filters; configuration no longer
  depends on the console editor. Custom title bar and styled native controls keep
  resize, scrolling, dropdown and keyboard-focus behavior.
- Async read-only scans; queued refresh and obsolete-result rejection.
- Explicit save versus apply; conflict-detecting config writes with recoverable
  backup and unknown-field preservation; selectable existing Python interpreter.
- Real console interaction for legacy tools; no fabricated percentages or success.
- Automated layout renders at 1120x820 and 940x680, all eight pages and detailed tabs,
  all 12 axes, workflow failure
  regressions and independent follow-up UI review.
- The user completed the actual PartCutGen + Meta Injector session and confirmed the
  selected saved setup works in-game. Remaining manual coverage is normal desktop
  keyboard/DPI/screen-reader exercise; automated wiring tests do not replace it.

### Native recovery follow-up — implemented 2026-09-11

- Separate read-only preview, same-client restore, current-client reference capture
  and explicit archive isolation. Preview tokens expire when relevant files change.
- Originals and receipts retained; guarded rollback and required preset-copy success.
  No archive/staging deletion, no config mutation, no console prompts for recovery.
- Failure/rollback tests use disposable files. Real source GUI -> hidden process ->
  Python -> JSON -> WPF preview passed against live PAZ without writes to game/config.
- The user captured a current-client reference after launcher repair/update. Live and
  reference metadata both report client 3444, and the previous reference was retained
  under `PAZ/BDO_AIO_RECOVERY/`. Actual restore and archive isolation on user data
  remain unperformed; no destructive cleanup was authorized.

### Native graphics follow-up — implemented 2026-09-11

- Added a native **Graphics & performance** page for bundled GameOption profiles.
  Preview is read-only; apply requires a fresh token, acknowledgement, an idle BDO
  process/launcher check and a complete backup beside the current file.
- Reused the existing line-preserving GameOption patcher. Unknown/current settings
  remain in place; the page reports changed keys rather than inventing performance
  numbers. NVIDIA `.nip` import remains in NVIDIA Profile Inspector and experimental
  DLSS / OptiScaler remains a separate legacy action.
- Remastered 1440p is the dashboard default while 1080p and DLDSR 4K remain available.
  Legacy graphics apply now shares the idle guard and collision-safe backup behavior;
  user-facing generated-stage cleanup and stale pubic packages are recoverable archives.
- Disposable tests cover atomic merge, byte-identical backup, unknown-key retention,
  stale-preview refusal, confirmation, navigation, dirty-state and busy-state locks.
- Installed visual smoke is complete: the real Graphics page preview and the existing
  Recovery preview both retained their protected file hashes. A GameOption apply and
  in-game FPS/appearance check remain optional; the saved-choice Meta Injector timing
  gate is complete and does not justify changing the external archive-save phase.

## 3. Shelved per-outfit work — research only, not restored as a global toggle

- Resume `dev/PARTCUT-MECHANICS.md` only with a confirmed class/outfit test target.
- Use `partcut_recut.py --dry-run` against the current live meta first. Vanilla
  folder-level cuts require folder-to-file recutting, not just a Disable entry.
- Ranger is `pew`, Sorceress is `phw`. Look 11 is `pew_03_ub_0002`; Look 7 remains
  unnamed. Do not revive the disproven Zereth label or cross-class test conclusions.
- Gate each candidate on a narrow keep-list, known positive control, exact staged
  diff, reversible backup, and matching before/after in-game evidence.
- Only proven outfits become an opt-in curated feature. No automatic "all outfits"
  claim, generated compatibility guesses, or remeshing prerequisite without evidence.

## 4. Release only after edits and runtime validation

- Test both source-only and full-pack installations. Preserve machine-local settings.
- The CI parser boundary was corrected and the source-only fresh-tree gate passed in
  a path with spaces/Unicode. A clean source-plus-full-pack preflight archive was
  tested and freshly extracted in a path with spaces/Unicode; archive integrity,
  dashboard tests and the packaged Verify Pack action all passed.
- Check package inclusion of GUI/XAML/classic launcher; exclude config, logs, backup
  archives, local maintainer files and machine-specific paths. The clean archive
  audit found zero forbidden entries and retained the source-only license/CI files.
- The dashboard suite was rerun after four stale verifier processes were closed and
  passed with exit code 0. The shared operation mutex remains intentionally guarded.
- Local preflight archive retained at
  `Z:\Backup\Ai documentation\BDO-AIO-preflight-2.4.2-full-clean.7z`; this is not
  a public release artifact.
- With publication authorization: final commit, push, successful CI on that exact
  SHA, package/tag/release from it, then download and verify the published bytes.
- Do not claim a new release, native-tool compatibility or in-game results from
  local unit tests alone.
