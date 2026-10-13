# BDO-AIO v2.4.1 validation

Historical release evidence follows. Current unpublished work is recorded in the
dated dashboard review section at the end; older client versions are not current.

Date: 2026-08-09

## Scope

- Five body regions with 12 explicit axis ceilings.
- Recommended/Custom schema-2 launcher configuration and legacy migration.
- Max-only, widen-only, exact-byte patching.
- Read-only live PAZ descriptor audit. No game or deployed patch files were written.
- Butt-cheek versus pelvis-Z wording regression checks.

## Commands and results

| Command | Exit | Result |
|---|---:|---|
| `python -B tools\bdo_meta\test_body_size_patcher.py` | 0 | 18 focused axis/parser/byte-safety tests passed. |
| `python -B -m unittest discover -v tools\bdo_meta` | 0 | 94 complete Python tests passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\bdo_meta\test_body_size_config.ps1` | 0 | Schema 2, migration, UI text, invariant formatting, and PowerShell 5.1 BOM checks passed. |
| `test_launcher_static.ps1`, `test_meta_inject_launcher.ps1`, `test_pubic_config.ps1` | 0 | Launcher parse/call graph, Meta Injector argument isolation, and pubic configuration suites passed. |
| `python -B tools\bdo_meta\_verify_presets_vs_stock.py --paz "...\Black Desert Online\PAZ"` | 0 | 75 descriptors, 75 changed in memory, 3,136 target tags, 2,383 Max edits, 0 violations. |
| `git diff --check` | 0 | No whitespace errors before commit. |
| `7z t BDO-AIO-v2.4.1-full.7z` | 0 | 42,143 files tested; archive integrity passed. |
| release exclusion audit | 0 | No `config.json`, `.claude`, backups, live staging, Python caches, or `files_to_patch` entries. |

## Live audit invariants

- Descriptor count: 75.
- Every patched output retained its exact input byte length.
- `Min` and `Default` remained byte-identical.
- Thigh X, Pelvis X, and Belly Y remained unchanged.
- Spine X changed only under the explicit Belly-X target.
- No higher class-authored Max value was reduced.

## Verdict

```text
SCOPE: PASS
DIFF REVIEW: PASS
PYTHON TESTS: PASS
POWERSHELL TESTS: PASS
READ-ONLY LIVE DESCRIPTOR AUDIT: PASS
PACKAGE: PASS (232,356,266 bytes; SHA-256 7753daa2b71fb8ce816a4a7b9ab108bd0983d7f20e7005b732661a33706f90b7)
REMOTE RELEASE: PASS (public asset downloaded, checksum matched, 7-Zip retest passed)
UNRESOLVED: cross-class and outfit appearance requires in-game user testing
FINAL: PASS (tool-validated; runtime appearance pending)
```

## Local pending validation - stale-state guard and injector observability

Date: 2026-09-09

### Scope

- Version-bound vanilla snapshot classification and backup refusal.
- Live-meta default for per-outfit PartCut research.
- Per-run Meta Injector JSON report wiring and timing fields.
- No live PAZ, deployed source, or user configuration writes.

### Commands and results

| Command | Exit | Result |
|---|---:|---|
| `& '%USERPROFILE%\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\python\\python.exe' -B -m unittest discover -s tools\\bdo_meta -p test_*.py -v` | 0 | 109 Python tests passed; 6 skipped because the optional Midnight nude pack was absent. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\\bdo_meta\\test_body_size_config.ps1` | 0 | Existing body-size/config suite passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\\bdo_meta\\test_config_roundtrip.ps1` | 0 | Existing config persistence suite passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\\bdo_meta\\test_launcher_static.ps1` | 0 | PowerShell 5.1 parse/call-graph/variable checks passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\\bdo_meta\\test_meta_inject_launcher.ps1` | 0 | Structured report round-trip and stage-builder argument isolation passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\\bdo_meta\\test_pubic_config.ps1` | 0 | Existing pubic configuration suite passed. |
| `& '%USERPROFILE%\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\python\\python.exe' tools\\bdo_meta\\paz_status_scan.py --paz 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Black Desert Online\\Paz' --json` | 0 | Correctly reported live client 3435 vs AIO snapshot 3418 as `STALE_BACKUP / UNKNOWN`. |
| `& '%USERPROFILE%\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\python\\python.exe' tools\\bdo_meta\\partcut_recut.py --xml 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Black Desert Online\\Paz\\files_to_patch\\_PartCutGen\\character\\partcutdesc.xml' --paz 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Black Desert Online\\Paz' --group PEW_Upperbody --folder '1_Pc/3_PEW/Armor/9_Upperbody' --keep 'pew_03_ub_0002*' --dry-run` | 0 | Used live `pad00000.meta`; found 352 PACs, kept 2, re-cut 350. |

### Verdict

```text
SCOPE: PASS
DIFF REVIEW: PASS
BUILD/COMPILE: PASS (PowerShell parser and static checks)
TESTS/VALIDATORS: PASS
PACKAGE INSPECTION: N/A (not publishing yet)
UNRESOLVED: full Meta Injector duration requires a matching clean live snapshot; in-game appearance remains unverified
FINAL: PASS (local/unpublished)
```

## Local performance baseline — meta parser optimization

Date: 2026-09-09

The shared `FileBlock` reader now unpacks each fixed-width 28-byte record in one
operation instead of seven small reads. The same live PAZ was measured three times
per phase before and after the change; every sample exited 0.

| Read-only phase | Before median | After median | Change |
|---|---:|---:|---:|
| `vanilla_restore.py verify` | 2,692 ms | 2,279 ms | -15.3% |
| `inject_stage_builder.py --dry-run` | 3,559 ms | 2,972 ms | -16.5% |
| `partcut_recut.py --dry-run` | 2,462 ms | 2,010 ms | -18.4% |
| `paz_status_scan.py --json` | 521 ms | 547 ms | within run-to-run noise; stale state skips meta parsing |

The external Meta Injector was not run because the live client is version 3435
while the AIO vanilla snapshot is version 3418. No live PAZ, staged source, or user
configuration was modified by this benchmark.

## Live post-inject validation — 2026-09-09

The user completed a fresh Meta Injector run against client version 3435. The
external tool took approximately 122 seconds by user observation; the run used
the older unpacked app, so no structured launcher timing report was produced.

| Command | Exit | Result |
|---|---:|---|
| `paz_status_scan.py --json` | 0 | `INJECTED + STAGED`; same-version meta state `MODDED`; live version 3435; 19 injected PAZ references. |
| `vanilla_restore.py verify --expect-version 3435` | 0 | 862,978 blocks readable; 0 missing archives; 0 past-end blocks. |
| `vanilla_restore.py scan` | 0 | 19 injected PAZ archives identified; restore was not applied. |

The current source launcher has the new five-second heartbeat and elapsed-time
display for the next run. Codex performed only read-only checks after the user's
inject; no live PAZ, staged source, or configuration file was changed here.

## Unpublished dashboard and backend review — 2026-09-10

- Source Python: 115 tests total, 109 passed, 6 skipped (optional full-pack assets
  absent in the source checkout). This is not 115 passing asset tests.
- Eight Windows PowerShell 5.1 suites passed: body config, config round-trip, dashboard,
  launcher results, launcher static, injector launcher, pubic config, workflow results.
- Real child-process failure verifies that noisy stdout cannot become boolean success.
  Temporary workflow tests cover backup failure, injector failure, verification failure,
  success, failed PartCutGen sequencing and selective generated-stage archiving.
- Dashboard tests load actual WPF/XAML: 12 axes, save/unknown-field round-trip,
  atomic backup, invalid input, concurrent edits, corrupt config, navigation/busy
  states, obsolete async scan rejection, failed-scan clearing and error-focus wiring.
- Rendered all five pages at 1120x820 and 940x680; independent follow-up UI review
  passed its listed findings. Manual keyboard, screen-reader and non-100% DPI behavior
  remain unverified; automated UIA wiring is not a screen-reader test.
- Latest read-only live meta: client 3444, snapshot 3435, `STALE BACKUP / UNKNOWN`.
  `vanilla_restore.py verify` passed: 863,154 blocks, no missing archives or overruns.
  No game or live staged files were changed. No new injector timing claim is made.
- Local PSScriptAnalyzer is unavailable; remote CI was updated but not pushed/run.
  No release artifact, fresh extraction or in-game appearance proof for this preview.

### Full local installation check

- Synchronized 42 changed/new allowlisted scripts, tests, UI and documentation files;
  retained exact prior files under `backup/dashboard-preview-20260910-174756/`.
  No pack payloads were overwritten and no files were deleted.
- Backed up personal config, then added only `pythonPath` pointing to an existing
  Python 3 runtime on this machine. Every pre-existing configuration value compared
  equal afterward. No machine-specific interpreter path was added to shipped defaults.
- Full-pack Python: **115 tests passed, zero skips**. All eight Windows PowerShell
  suites passed from the installed app as well as the source checkout.
- Read-only actual installed WPF dashboard scan: Python/full pack available, Toolkit
  detected, client 3444 and different-version vanilla reference correctly shown.
  Two observed scan dispatches took 18/15 ms and completed in 2,667/1,764 ms;
  navigation was available while scanning. These are smoke observations, not a benchmark.
- Opening/scanning retained identical personal-config and live-meta SHA-256 hashes.
  Actual content rendered at 1120x820 and inspected. No apply, restore, PartCutGen,
  Meta Injector or game launch was performed by this check.

### Native detailed editor and chrome follow-up — 2026-09-10

- Removed the dashboard's console Options action; it now has six pages and native
  pubic-hair, female-mesh and male-mesh tabs, plus the equipment class filter.
- Extended WPF tests pass: private/shared style serialization, immersive/clear presets,
  empty enabled female selection refusal, male custom-choice retention, invalid class
  filter refusal, unchanged legacy mixed/partial selection retention, and busy locking.
- Custom scroll track maintains its binding to actual scroll offset; dropdown retains
  its native Popup part; title-bar buttons have accessible names and chrome hit regions.
- Rendered six pages and all three detailed tabs at 1120x820 and 940x680; inspected
  custom chrome and themed inputs. An actual shown WPF window successfully maximized,
  restored, minimized, opened a themed dropdown and closed via its caption controls.
- Re-ran all eight PowerShell suites and the source Python suite (109 passed, six
  optional full-pack skips). No patching or personal-setting changes are part of this pass.
- Windows Script Host was not usable in the sandbox; no VBS dependency is shipped.
  START.bat uses the existing PowerShell host with WindowStyle Hidden and a startup
  error dialog. Keyboard/DPI/screen-reader coverage is still not claimed as exhaustive.
- Installed follow-up: eight changed files backed up under
  `backup/dashboard-polish-20260910-180931/`; updated dashboard regressions and all
  115 full-pack Python tests passed. A fresh installed read-only scan retained the
  same config/meta hashes and detected all dependencies. No personal choices changed.

### Native Recovery & updates — 2026-09-11

- Seven native pages. Recovery preview, restore, reference capture and archive
  isolation run through a hidden child process and structured result report.
- Source Python: 129 tests run, 123 passed and six optional full-pack skips.
  Fourteen recovery tests cover preview immutability, stale/injected/checksum-invalid
  backup refusal, explicit approval, changed preview, game-process guard, retained
  originals, snapshot selection, move-only cleanup, failed-write/post-check/move
  rollback, linked paths and the real parser's archive bounds/clean JSON channel.
- The nine pre-graphics Windows PowerShell suites and the syntax gate passed. Recovery tests
  exercise preset copies including hidden files, required-copy failure, guarded
  handoff, one structured result, and native control acknowledgement/target locking.
- Real source GUI -> hidden PowerShell -> Python -> JSON -> WPF preview completed
  in about 5.3 seconds; dispatch took 233 ms and navigation remained available.
  These are smoke observations, not comparative performance claims.
- Read-only live result: client 3444, reference 3435, restore blocked; 863,154 blocks,
  zero missing archives/overruns. Nineteen optional isolation candidates total
  1,770,217,868 bytes. Nothing was moved, restored or captured as a new reference.
- Personal config and live meta SHA-256 were unchanged around the integrated scan.
  The pre-graphics dashboard pages rendered at 1120x820 and 940x680. Restore/rollback were exercised
  only on disposable fixtures, not the user's game. No publication or remote CI run.
- Installed follow-up at that point: 11/11 allowlisted runtime/UI files match the verified source;
  existing targets are retained under `backup/dashboard-recovery-20260911-133422-42c0baa3/`.
  Installed Python (129 tests) and the nine pre-graphics PowerShell suites passed. The installed
  WPF preview dispatched in 228 ms and completed in 5.45 seconds; config and live
  meta hashes remained unchanged. The corrected portable recovery test is retained
  under `backup/dashboard-recovery-test-fix-20260911-133659-e9970ffe/`.

### Native Graphics & performance — 2026-09-11

- Added the native graphics page with a read-only GameOption preview, changed-key
  list, explicit acknowledgement and hidden structured child action. Applying makes
  a complete byte-preserving backup before the existing atomic line-preserving merge.
- Disposable PowerShell coverage passes for profile preview, unknown-key retention,
  byte-identical backup, stale-preview token invalidation, confirmation, navigation,
  dirty-state locking, busy-state locking and reload reset.
- Source Python unittest discovery: 129 tests, 123 passed and six optional full-pack
  skips. PowerShell parser, XAML parser, launcher static checks and all ten local
  PowerShell suites passed. The `pytest` wrapper reached its test output but did not
  terminate in this host, so the bounded unittest result is the recorded Python gate.
- No GameOption apply, NVIDIA import, PAZ write, config write or publication was done
  by this phase.

### Installed graphics integration follow-up — 2026-09-11

- Backed up the prior installed files under
  `backup/dashboard-graphics-20260911-140546/`, then synchronized 12 reviewed source
  files. Source and installed hashes match for each synchronized file; `config.json`
  was not copied.
- Installed Python unittest discovery passed all 129 tests with zero optional skips.
  All ten Windows PowerShell suites, PowerShell/XAML parsing and launcher static checks
  passed from the installed tree.
- Real installed Graphics preview: 267 ms dispatch, 944 ms completion, Remastered
  1080p profile, 2,707-byte current GameOption. The rendered page was captured at
  `bdo-graphics/Live-Graphics-1120.png`; config and GameOption SHA-256 hashes were
  unchanged. No apply or NVIDIA import was performed.
- Real installed Recovery preview after the page addition: 230 ms dispatch, 5.51 s
  completion; client 3444/reference 3435 remained correctly blocked and config/live
  meta hashes stayed unchanged. No PAZ write, publication, push or release was done.

### Full safety review and 1440p default — 2026-09-11

- Source review found and corrected three concrete boundary issues: legacy graphics
  apply now checks the idle game/tool boundary and uses a GUID-suffixed backup;
  user-facing generated-stage cleanup archives instead of deleting; stale pubic
  packages are archived under `PAZ/BDO_AIO_STAGE_BACKUPS/`.
- Added regression coverage for stale-package retention and the legacy graphics
  idle guard. Source gates remained green: 129 Python tests (123 passed, six
  optional full-pack skips), all ten PowerShell suites, launcher static checks and
  PowerShell/XAML parsing.
- Synchronized eight reviewed runtime/docs/test files to the installed tree with prior
  copies retained at `backup/review-hardening-20260911-142921/`; after the final
  validation/state-doc sync, all eleven compared source/installed hashes match.
  The installed tree passed 129 Python tests with zero skips, all ten PowerShell
  suites, static checks and parsers.
- Real installed read-only Graphics preview selected **Remastered 1440p**, completed
  in 888 ms after 235 ms dispatch, reported five changed keys and 112 preserved lines,
  and left config/GameOption SHA-256 hashes unchanged. Rendered evidence is at
  `bdo-graphics/Live-Graphics-1120.png`.
- Real installed read-only Recovery preview completed successfully; live client 3444
  versus reference 3435 remains correctly blocked, with 19 recoverable candidates
  totaling 1,770,217,868 bytes. Config and live-meta hashes remained unchanged.
  No full apply, PAZ write, publication, push or release was performed.

### Pre-release CI and fresh-tree audit — 2026-09-11

- Fixed the CI PowerShell syntax gate to pass real token/error references instead of
  `[ref]$null`. The equivalent all-file PowerShell parser gate passes locally.
- Source-only fresh-tree proof used a disposable path containing spaces and Unicode,
  with no prior config, backup, log or pack state. The dashboard child exited 0,
  initialized all eight pages, selected `GameOption_Remastered_1440p.patch`, and
  created no config until an explicit save. The disposable tree was removed after
  verification; `pack\` was intentionally excluded because it is not in Git.
- `PSScriptAnalyzer` is not installed in this host, so its error-level gate remains
  explicitly unclaimed; CI installs and runs it on Windows. Full-pack extraction and
  artifact-byte verification remain release gates for after the edit cycle.
- Structural package preflight found all 11 required dashboard/classic/UI/graphics
  paths and confirmed `.gitignore` excludes `config.json`, `logs/`, `backup/` and
  `pack/**`. Developer-only `.git` and test `logs/` remain in the working tree but
  are not release contents.

### User-authorized full apply and in-game validation — 2026-09-11

- The user captured a current-client vanilla reference after launcher repair. The
  live meta and reference both report client version **3444**; the previous reference
  was retained under `PAZ/BDO_AIO_RECOVERY/`.
- The installed dashboard then completed the full saved-choice workflow: generators,
  PartCutGen, Meta Injector and post-injection verification. Operation record:
  `logs/operation-f0f8b658b1374ff388a83cde97dbaf9a.json`.

| Phase | Result |
|---|---|
| Backup/reference check | Same-client 3444 reference accepted. |
| Stage build | Completed in 3,842 ms. |
| Meta Injector | Started and completed; 151,200 ms, exit code 0. |
| Version verification | Passed; client version 3444 before and after. |
| Live status scan | `META MODIFIED + STAGED`; 2,254 staged files remain. |
| In-game validation | **User-confirmed pass** for the selected saved setup. |

The structured report is `logs/meta-inject-b3c7d969b0cb49febcdac30a6efb16ae.json`.
This proves the selected setup end to end; it does not claim every supported class or
outfit combination has been visually tested. No publication, push or release was done.

### Full-pack archive preflight — 2026-09-11

- The installed full package passed its built-in Verify Pack action: **41,889** pack
  files, **1,860.9 MB**, all three graphics patches, NVIDIA NIP/Profile Inspector and
  the experimental DLSS payload present.
- A clean staging tree was built from the current source checkout plus only the verified
  full `pack\` and experimental payload. It contained **42,155** files and
  **2,317,060,687** uncompressed bytes. Required source-only files including `LICENSE`,
  `SECURITY.md` and CI metadata were present; forbidden local artifacts numbered zero.
- Local archive: `Z:\Backup\Ai documentation\BDO-AIO-preflight-2.4.2-full-clean.7z`
  (**231,649,806 bytes**). `7z t` passed for all 42,155 entries with zero forbidden
  archive paths.
- Fresh extraction into a path containing spaces and Unicode restored all 42,155 files.
  The extracted dashboard suite exited 0, and the extracted Verify Pack action exited 0.
  The temporary staging/extraction directories were removed afterward; the archive is
  retained for local review only.
- No commit, push, tag, GitHub release or public upload was performed. CI's hosted
  PSScriptAnalyzer gate and exact-SHA release sequence remain outstanding publication
  gates.

### Open-chest outfits (2.6.0 development) - 2026-10-13

Read-only on the game: archives and meta were only read; every write went to the repository
or a scratch folder. No in-game run of this feature has happened yet.

| Check | Result |
|-------|--------|
| Native `.pac` reader vs PACtool 1.4.4, all Ranger upper bodies | 348/348 identical (positions <= 1e-4, triangles exact); 4 PACs hold no mesh in either tool |
| Detector reproduces the prototype that was checked on contact sheets | 99 Ranger tops recorded, zero metric differences |
| Cross-class consistency | Same premium outfit scores alike on Ranger, Witch and Seraph (for example `10_ub_0205`: mound 0.54, nipple 0.82 on both) |
| Narrowed Look-7 shortlist (33 small-tier Ranger outfits) | exactly `pew_hw_ub_0031` and `pew_kw_ub_0001` flagged open |
| Registry scan | 18 classes, client 3454; Tamer, Shai and Old Maehwa (no nude body) not included |
| Apply on a temp copy of the live `partcutdesc.xml` | 18 classes, 3 shared groups rewritten, 0 declarations after the first `<Relation>`, non-UTF-8 byte and CRLF preserved |
| Python tests | new suites for the PAC reader, the detector and the recut (22 tests) pass |
| PowerShell suites | config round trip, launcher static and dashboard pass with the new setting |

Not proven: in-game appearance of any outfit, texture-alpha windows, event-costume tops.
