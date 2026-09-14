<p align="center">
  <img src="docs/images/logo.svg" width="72" height="72" alt="BDO Modding AIO mark">
</p>

<h1 align="center">BDO Modding AIO</h1>

<p align="center"><strong>Windows menu for Black Desert Online client mods. Not Skyrim.</strong></p>

<p align="center">
  Midnight deploy → PartCutGen → Meta Injector, plus restored body / hide / censorship<br>
  tooling, vanilla-restore safety, and an optional experimental OptiScaler path.
</p>

<p align="center">
  <a href="https://github.com/ShugokiFable/BDO-AIO/actions/workflows/ci.yml"><img src="https://github.com/ShugokiFable/BDO-AIO/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-c9a227?labelColor=0c0f12" alt="MIT License"></a>
  <a href="https://github.com/ShugokiFable/BDO-AIO/releases/tag/v2.4.2"><img src="https://img.shields.io/badge/release-v2.4.2-d4af37?labelColor=0c0f12" alt="v2.4.2"></a>
</p>

<p align="center">
  <a href="#quick-start">Quick start</a>
  ·
  <a href="#options-menu-2">Options</a>
  ·
  <a href="#pipeline">Pipeline</a>
  ·
  <a href="#honest-status">Honest status</a>
  ·
  <a href="CHANGELOG.md">Changelog</a>
</p>

**Current tree: v2.4.2.** Latest release: [v2.4.2](https://github.com/ShugokiFable/BDO-AIO/releases/tag/v2.4.2). Double-click **`START.bat`**.

| Download | What you get |
| --- | --- |
| **[Full offline `.7z` (recommended)](https://github.com/ShugokiFable/BDO-AIO/releases/latest)** | Scripts + **`pack\`** Midnight (~1.8 GB) + injectors — use this |
| This git `main` branch | Scripts + docs + tools only — **no** Midnight meshes unless you add `pack\` yourself |

This git tree has no application screenshot. The UI is the `START.bat` / `bdo_aio.ps1` console menu.

## What it does

- **Midnight** deploy → **PartCutGen** → **Meta Injector**
- Underwear / armor hide, Suzu + TheGreatSage nude bases, optional **XYZW** skimpy collections
- **RESTORED** options: body Max ceilings, slot hide, pubic hair, censorship texture tiers, authored 3D vagina/penis
- **Vanilla restore safety** for body-size users (required before many game updates)
- GameOption max-quality profiles + NVIDIA `.nip` import (Orbmu2k NVIDIA Profile Inspector — not an NVIDIA partnership)
- Optional **EXPERIMENTAL / NOT SAFE** OptiScaler (menu **X**)

### Feature labels

| Label | Meaning |
| --- | --- |
| **MODERN** | Midnight / Meta Injector 2026 pipeline |
| **RESTORED** | Classic Resorepless-era feature, re-wired here |
| **EXPERIMENTAL** | From-scratch in this AIO only — not a classic restore |

Details: [`docs/FEATURE-LABELS.md`](docs/FEATURE-LABELS.md)

## Options (menu 2)

### MODERN

| Area | Options |
| --- | --- |
| Gender | Female / Male / Both |
| Armor hide | All / Pearl / Free / Underwear-only |
| Collections | XYZW outfit packs on/off |

### RESTORED

| Area | Options |
| --- | --- |
| **Body size (Max ceilings only)** | **Recommended** or per-axis **Custom** for five regions. Recommended: breasts X/Y/Z 1.55; thighs Y/Z 1.35; butt cheeks X/Y/Z 1.20; front pelvis/groin Y/Z 1.40; belly X 1.28 and Z 1.45. Thigh X, Pelvis X, and Belly Y stay untouched. Belly X is the sole intentional `HeightAxis` exception and can lengthen the lower torso. Only Max widens; Min/Default and higher class values remain. Restore once before an exact Recommended test if an older injection used breasts above 1.55 or widened Belly Y. |
| **Slot hide** | Gloves / boots / helmets / weapons / stockings |
| **Pubic hair** | Per-class styles; shared-atlas classes share one style; texture-only |
| **Censorship tiers** | Live-client **DXT5/DXT3** transparent blanks only. **Never DXT1**, never `*_cull*`, never 2018 stubs. Default **off**. Mesh/DXT1 built-in shorts need an XYZW remesh — see [`dev/TEXTURE-BLANKING-RULES.md`](dev/TEXTURE-BLANKING-RULES.md). |
| **3D vagina / penis** | Authored meshes only (10 female + 6 male). **Nude body PAC only** — does not overwrite Midnight underwear hide. |

### Not supported

| Area | Reason |
| --- | --- |
| Genitals on classes with no authored mesh | Reusing another class's PAC steals that class's body *and* skin |
| Separate pubic style per shared-atlas class | 13 females share one texture; material rename made bodies invisible |
| Pubic hair on Corsair | No matching hair bin size |
| "Strip every outfit" via texture censorship | Safe only for DXT5 overlays; geometry shorts need remeshes |

### EXPERIMENTAL

| Area | Options |
| --- | --- |
| Main menu **[X]** | OptiScaler / DLSS-style inject — **NOT SAFE** |

## Quick start

1. Download the latest **`BDO-AIO-v*-full.7z`** from [Releases](https://github.com/ShugokiFable/BDO-AIO/releases/latest) (or use this repo + fill `pack\`).
2. Extract to a short path; install **Python 3** if needed (`winget install Python.Python.3.12`).
3. **`START.bat`** → **`9`** verify pack (~1.5–2 GB under `pack\`).
4. **`6`** Full Wizard (or configure options first) → pick live **PAZ** (`pad00000.meta` inside).
5. Finish **PartCutGen**, then **Meta Injector**.
6. Optional: **`G`** GameOption. **`N`** NVIDIA `.nip`. **`X`** OptiScaler (not safe).
7. After a game patch: let the launcher finish, start the game once, re-snapshot vanilla, then re-apply. Restoring a vanilla snapshot taken on a **different client version** is refused — that is what used to look like "corrupted files".
8. **Body-size users:** do **not** log characters saved above stock Max while the client is vanilla — the game clamps and re-saves them (and can overwrite Beauty Album presets). Re-inject body size **first**, then play. AIO snapshots `Documents\Black Desert\Customization` into `backup\` on restore.
9. After a successful re-mod: **`H`** (heisha regen if inject breaks) then wizard again if needed.

**Requires separately:** [BDO Toolkit 1.3.0](https://www.undertow.club/) for Meta Injector 1.4.1 (not bundled).

## Why `pack/` is not in git

~1.8 GB / 40k+ files. Full offline payload ships as **`BDO-AIO-v*-full.7z`** on Releases. A source-only clone is incomplete without that archive or a local `pack\`.

## Layout (full offline tree)

```text
BDO-AIO/
  START.bat              <- run this
  bdo_aio.ps1
  README.md / CREDITS.md / CHANGELOG.md
  config.example.json    <- ship this; config.json is local-only
  pack/                  <- REQUIRED (~1.5-2 GB) in full releases
  graphics/              <- GameOption patches + nvidia .nip
  tools/                 <- bdo_meta, NPI, restored assets
  experimental/dlss/     <- optional, dangerous
  docs/                  <- feature labels / ecosystem notes
  dev/                   <- maintainer / AI notes (not needed to play)
```

## Pipeline

```text
NA/EU: Deploy -> PartCutGen -> Meta Injector -> Launch
Other regions: same, then Meta Patcher only if your region needs it (not bundled)
```

Meta Injector is launched via a short-path canonical stage so deep XYZW trees do not hit Windows path limits.

## Changelog (latest)

### v2.4.2

- Fixes mods silently reverting with the game reporting **corrupted files**. Nothing was corrupt: `pad00000.meta` carries the client version at offset 0, an inject left it reading an older version than the installed client, and the launcher re-downloaded ~1 GB of patches and replaced the meta.
- Meta Injector runs now record the client version **before** injecting and re-check it after. On a mismatch the AIO says **DO NOT LAUNCH**.
- New `verify` step proves every block resolves inside an archive that exists, before you launch.
- Restoring a vanilla snapshot taken on a **different client version** is now refused — it causes the same wipe.
- After a game patch: let the launcher finish, start the game once, re-snapshot vanilla, then re-apply.
- No body-slider values, packs, or pipeline behaviour changed from v2.4.1.

### v2.4.1

- Wording hotfix: **Butt cheeks** means cheek shape/roundness, while **Front pelvis/groin Z** is the main overall pelvis/ass-size control.
- No body-slider values or mappings changed from v2.4.0.

### v2.4.0

- Simplified body limits to **Recommended**, **Custom**, and **Keep current**.
- Five independent regions with 12 explicit axis ceilings, including separate butt cheeks and front pelvis/groin.
- Schema-2 migration, Max-only enforcement, atomic generation, and read-only 75-descriptor validation.

Full history: [`CHANGELOG.md`](CHANGELOG.md) · version notes: [`VERSION.md`](VERSION.md)

## Honest status

Verified in this tree:

- `CURRENT.txt` / `VERSION.md` — **v2.4.2**
- CI (`.github/workflows/ci.yml`) — PowerShell parse + PSScriptAnalyzer, JSON, Python compile
- [`VALIDATION.md`](VALIDATION.md) — v2.4.1 tool-validated: 94 Python tests, PowerShell suites, read-only live PAZ audit (75 descriptors, 2,383 Max edits, zero byte-length / Min / Default / protected-axis violations). v2.4.2 did not change slider values.

Not claimed:

- that a git clone without `pack\` is playable
- in-game appearance across every class and outfit (still user-tested)
- a compiled GUI screenshot (there isn't one)
- NVIDIA endorsement of the `.nip` profile

## Credits

[`CREDITS.md`](CREDITS.md) — keep in every zip. This AIO is a wrapper; meshes/tools belong to Midnight/heisha, Suzu, TheGreatSage, XYZW authors, Meta Injector/PartCutGen authors, Resorepless lineage, Orbmu2k (NPI), OptiScaler (experimental), and this repo's menu/tooling.

**Black Desert Online** (c) Pearl Abyss. Client mods can break after patches and may violate ToS — use at your own risk.

## License

[MIT](LICENSE)
