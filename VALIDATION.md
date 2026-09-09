# BDO-AIO v2.4.1 validation

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
| `& 'C:\\Users\\karlo\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\python\\python.exe' -B -m unittest discover -s tools\\bdo_meta -p test_*.py -v` | 0 | 109 Python tests passed; 6 skipped because the optional Midnight nude pack was absent. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\\bdo_meta\\test_body_size_config.ps1` | 0 | Existing body-size/config suite passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\\bdo_meta\\test_config_roundtrip.ps1` | 0 | Existing config persistence suite passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\\bdo_meta\\test_launcher_static.ps1` | 0 | PowerShell 5.1 parse/call-graph/variable checks passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\\bdo_meta\\test_meta_inject_launcher.ps1` | 0 | Structured report round-trip and stage-builder argument isolation passed. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\\bdo_meta\\test_pubic_config.ps1` | 0 | Existing pubic configuration suite passed. |
| `& 'C:\\Users\\karlo\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\python\\python.exe' tools\\bdo_meta\\paz_status_scan.py --paz 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Black Desert Online\\Paz' --json` | 0 | Correctly reported live client 3435 vs AIO snapshot 3418 as `STALE_BACKUP / UNKNOWN`. |
| `& 'C:\\Users\\karlo\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\python\\python.exe' tools\\bdo_meta\\partcut_recut.py --xml 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Black Desert Online\\Paz\\files_to_patch\\_PartCutGen\\character\\partcutdesc.xml' --paz 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Black Desert Online\\Paz' --group PEW_Upperbody --folder '1_Pc/3_PEW/Armor/9_Upperbody' --keep 'pew_03_ub_0002*' --dry-run` | 0 | Used live `pad00000.meta`; found 352 PACs, kept 2, re-cut 350. |

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
