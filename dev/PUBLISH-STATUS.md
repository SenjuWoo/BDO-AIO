# Publish status — public sites vs local tree

**Checked:** 2026-08-27
**Local/source version:** **v2.4.2** (pushed to `main`; no release archive built yet)
**GitHub release:** **v2.4.1** is public with the complete offline archive and checksum

---

## Public channels

| Channel | URL | Status |
|---------|-----|--------|
| **GitHub** | https://github.com/SenjuWoo/BDO-AIO/releases/tag/v2.4.1 | Primary download |
| **LoversLab** | https://www.loverslab.com/files/file/50558-bdo-aio-—-midnight-nudehide-meta-injector-wizard-black-desert-online/ | Upload full.7z manually (see docs/LOVERSLAB-RESOURCE.md) |
| **Undertow** | https://www.undertow.club/downloads/bdo-aio-—-midnight-nude-hide-meta-injector-wizard.9468/ | Upload full.7z manually (see docs/UNDERTOW-RESOURCE.md) |

## v2.4.1 publication evidence

- Tagged source commit: `5d9c193`.
- Published: `2026-08-10T00:37:52Z` (`2026-08-09` America/Halifax).
- Archive: `BDO-AIO-v2.4.1-full.7z` — 232,356,266 bytes.
- SHA-256: `7753daa2b71fb8ce816a4a7b9ab108bd0983d7f20e7005b732661a33706f90b7`.
- Sidecar: `BDO-AIO-v2.4.1-full.7z.sha256` — 90 bytes.
- The public archive was downloaded after publication, matched the local hash,
  and passed a fresh 7-Zip integrity test.

## v2.4.0 publication evidence

- Tagged source commit: `75c2dd0`.
- Published: `2026-08-10T00:12:34Z` (`2026-08-09` America/Halifax).
- Archive: `BDO-AIO-v2.4.0-full.7z` — 232,362,576 bytes.
- SHA-256: `c3399ee92c44fe7810badd0133ac388015fbb192099b7b9021134e7b16e45778`.
- Sidecar: `BDO-AIO-v2.4.0-full.7z.sha256` — 90 bytes.
- The two public assets were downloaded after publication; the downloaded
  archive matched the local hash and passed a fresh 7-Zip integrity test.

Structural validation is complete. Cross-class/outfit appearance remains an
explicit user runtime test and is not claimed as automated proof.


## 2026-08-27 - v2.4.2 PUBLISHED on GitHub

| Item | Value |
|------|-------|
| Tag | `v2.4.2` on commit `27c474c` |
| CI on that SHA | green (PowerShell + PSScriptAnalyzer, JSON + Python) |
| Release | https://github.com/SenjuWoo/BDO-AIO/releases/tag/v2.4.2 |
| Asset | `BDO-AIO-v2.4.2-full.7z` - 207,272,976 bytes, 42,146 files |
| sha256 | `d95e54464a4f3a93917e63e2732d54d7f0db9f51b066065896d84cd6491b6cfd` |
| Verified | built / published / `.sha256` all agree; archive passes `7z t` |
| Backup | `Z:\Backup\BDO-mods-assets\BDO-AIO-v2.4.2-full.7z` |
| README | bumped to v2.4.2 |

Archive excludes `config.json` (machine-specific), `backup/`, `__pycache__`, `.git`,
`.claude` - same exclusions as v2.4.1.

**Still to do (manual, needs your logins):** upload the same `full.7z` to LoversLab and
Undertow and paste the short changelog. Neither has been touched.
