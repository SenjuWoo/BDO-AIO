# App review resume ledger

## Scope
Continue the existing improvement plan: fix reproducible defects, preserve choices/assets, verify source and full installation, produce a local verified package. No game deployment or publication in this pass.

## Reconstructed baseline
- Source: sibling `BDO-AIO-git-push`, main at `d8e3b91`, five commits ahead of cached origin/main, plus pre-existing uncommitted dashboard/backend work. Preserve all of it.
- Installed app: sibling `BDO-AIO`, not a Git repository.
- User-supplied GitHub URL resolves to `SenjuWoo/BDO-AIO`; local remote still names the former owner.
- Attached and misplaced preflight archives are byte-identical: 231649806 bytes; SHA256 `e1d77c6c843dbefb131e3413ee1feae718b005f69e84b8662c85b80a460c9aef`.
- Misplaced original: `Z:/Backup/Ai documentation/BDO-AIO-preflight-2.4.2-full-clean.7z`. Do not discard before verified relocation.
- `VALIDATION.md` contains later apply/package evidence than `dev/STATE.md`, including a user-confirmed in-game pass on 2026-09-11; the stale 3435/3444 wording in STATE.md is historical, not current.

## Verified evidence (all executed this session, source tree)
- Python unittest discovery: 129 tests OK, six optional full-pack skips.
- All ten Windows PowerShell suites pass (`dev/review-checks.ps1`), 13 PowerShell files parse.
- Preflight archive: `7z t` clean, 42155 files; extracted to `%LOCALAPPDATA%/Temp/BDO AIO Review 20260917/preflight`.
- Preflight vs current source: only `ui/dashboard.xaml` differs (this session's fix) plus review files; the four non-code diffs are docs the preflight intentionally predates.
- Native dashboard test with `-CaptureDir` renders all eight pages at 1120 and 940 px.
- Pixel inspection found one defect: sidebar label "Graphics & performance" clipped to "performanc" at both sizes. Root cause: fixed 210px sidebar column (xaml line 62) minus 22+18 panel margins minus 12+12 item padding leaves 146px for text.
- Fix applied: column width 210 -> 224. Re-render verified by direct inspection at both sizes: label fully visible. Full dashboard suite still passes.
- `Update-DashboardTick` completion branches runtime-verified via disposable probe (P1 process cleanup, P2 recovery outcome, P3 graphics outcome, P4 timings with stage-report exclusion): all pass. Probe and measurement scripts deleted after use.
- Hostile-locale probe (fa-IR, ar-SA, ps-AF, ckb-IQ, dv-MV, prg-001, ks-IN): `[DateTime]::Parse` handles the emitted ISO formats fine; timestamp-parse nit disproven and dropped, no code change.
- Git status must stay clean of stray probe files; `tools/bdo_meta/_probe_tick.ps1` was an audit-child artifact, run once then removed.

## Changed files so far
- `ui/dashboard.xaml` line 62 only (210 -> 224). Everything else untouched.

## Remaining gates
- Process the two independent audit reports when delivered; apply only root-cause fixes with regression coverage; rerun all suites after.
- Source/install allowlist sync with previous-file backup and hashes (installed app intentionally lags on docs only).
- Clean-package extraction/test/hash from the post-fix tree; rehome misplaced preflight without losing provenance; reconcile state/plan docs.
- Do not claim perfect or universal in-game coverage.
