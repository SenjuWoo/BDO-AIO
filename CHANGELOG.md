## Unreleased

- Status and restore scans now report `STALE BACKUP / UNKNOWN` instead of inferring
  injection from a snapshot taken under a different client version.
- Normal Meta Injector runs abort when the existing AIO vanilla snapshot is stale;
  `backup --force` is required after a patch and a clean live meta.
- Per-outfit PartCut research now defaults to the live meta; old snapshots require
  explicit `--meta` selection.
- Meta Injector runs now write a per-run JSON report with stage, injector, and verify
  timings plus child-process exit/status evidence under the app's `logs` folder.
- Shared PAZ meta parsing now reads each fixed-width block in one operation; local
  verification, stage planning, and PartCut planning are about 15–18% faster.
- The Meta Injector wait now shows a five-second progress heartbeat and reports its
  elapsed archive-save time when the external tool closes.

## 2.4.2 - Catch a rolled-back client version before it wipes your mods

Symptom: mods reverted on their own and the game reported corrupted files. Cause: the
meta header carries the client version at offset 0, Meta Injector wrote a stale value
(3418 -> 3412), and the launcher concluded the client had rolled back - re-downloading
six patches and replacing `pad00000.meta`, which wiped the injection and stranded
1.65 GB of archives. Nothing was actually corrupt, and PartCutGen was not at fault.

- Meta Injector runs now record the client version **before** injecting and re-check it
  after. On a mismatch the AIO says DO NOT LAUNCH and points at restore.
- New `verify` command: `--expect-version N` catches the regression, and it also proves
  every block resolves inside an archive that exists.
- `restore` refuses a snapshot whose `meta_version` differs from the live meta (exit 5).
- `backup` records `meta_version` and judges the meta instead of refusing whenever a
  `BDO_AIO_INJECT` folder happens to exist.
- `scan` reports the client version and no longer prints `INJECTED` when the meta
  references zero injected archives.
- Startup warns when the client version changed since the last inject.
- Dropped the old "restore vanilla first when the launcher walls on a patch" advice.

Full write-up: `dev/CLIENT-PATCH-RULES.md`.

## v2.4.1 - 2026-08-09 - body-control wording hotfix

- Clarified that **Butt cheeks** controls cheek shape/roundness, not total ass size.
- Clarified that **Front pelvis/groin Z (`pelvis.z`)** is the main overall pelvis/ass-size control and affects both the front groin and rear.
- Added the explanation to the Recommended summary, Custom introduction, and the live `pelvis.z` prompt.
- Added PowerShell regression checks so both explanations must remain in the launcher.
- No slider mappings, ceilings, patch output, or migration behavior changed from v2.4.0.

## v2.4.0 - 2026-08-09 - axis-aware body slider controls

### Simpler workflow

- Replaced Baseline/Recommended/High/Extreme with **Recommended**, **Custom**, and **Keep current**.
- Split the old merged butt setting into independent **butt-cheek** and **front pelvis/groin** controls.
- Added 12 explicit axis ceilings across five regions.

### Recommended axis matrix

| Region | Max ceilings |
|---|---|
| Breasts | X/Y/Z 1.55 |
| Thighs | Y/Z 1.35; X leg length untouched |
| Butt cheeks | X/Y/Z 1.20 |
| Front pelvis/groin | Y/Z 1.40; X untouched |
| Belly/lower back | X 1.28, Z 1.45; Y untouched |

### Breast Custom guidance

- X is length/forward projection, Y is width, and Z is height.
- Documents the uneven observed stock peak: X 1.30 versus Y/Z 1.55.
- Shows balanced 1.55/1.55/1.55, equal +0.20 (1.50/1.75/1.75), and equal +0.25 (1.55/1.80/1.80) examples.
- Treats these as independent testable ceilings, not a universally correct anatomical ratio.

### Migration and safety

- Added body-size configuration schema 2 with canonical `region.axis:value` entries.
- Legacy Custom values migrate automatically. Old Belly scalars become Belly Z only and never infer Belly X.
- `Min` and `Default` can no longer be written, including through old command-line flags.
- Patching remains widen-only and exact-byte-length preserving.
- Spine X is the sole intentional `HeightAxis` exception and is clearly warned in the launcher.
- Generation validates all descriptors before replacing the completed body-size package.

### Validation

- Python axis suite: 18 tests passed.
- PowerShell schema/migration/UI suite passed under Windows PowerShell 5.1 with BOM verification.
- Read-only live PAZ audit: 75 descriptors, 3,136 target tags, 2,383 Max edits, zero violations.
- In-game cross-class and outfit appearance remains user-testable rather than claimed as proven.

## v2.3.1 - 2026-08-09 - lower-belly depth-slider hotfix candidate

### Root cause

The v2.3.0 `belly` mapping and deployment were correct, but its preset numbers
were not. The last Lower Back and Belly control is the `WeightAxis02="Z"` depth
axis on `Bip01 Spine`. A restored live-meta comparison found that **30 of 75**
current class descriptors already ship with a Z maximum of **1.35**. Because the
patcher is widen-only, v2.3.0 values of 1.20/1.25/1.30 could not add any travel
to that slider on those classes.

### Fix

| Preset | v2.3.0 belly | v2.3.1 belly | Meaning |
|--------|---------------|---------------|---------|
| Baseline | 1.10 | **1.35** | Covers the highest observed stock Z ceiling. |
| Recommended | 1.20 | **1.45** | Adds conservative 0.10 depth/width headroom. |
| High | 1.25 | **1.60** | Larger lower-belly/lower-back range; outfit testing required. |
| Extreme | 1.30 | **1.75** | Strong range; clipping/overinflation risk. |

- `Bip01 Spine` remains the only belly bone patched. `Spine1` and `Spine2` stay untouched.
- X `HeightAxis` torso length, `Default`, and `Min` remain byte-for-byte unchanged.
- No vanilla restore is needed to raise an already injected 1.25 ceiling to 1.45+
  because the patcher only widens. Reconfigure belly, regenerate, and inject again.
- Regression coverage now starts from the real stock `Max="1.10 1.20 1.35"`
  descriptor and requires recommended to produce `Max="1.10 1.45 1.45"`.

**Runtime status:** tool-validated candidate; the user still needs to confirm the
last slider gains visible travel in the Beauty Salon before public release.

## v2.3.0 - 2026-08-09 - safe Lower Back and Belly slider

### User-facing summary
| Area | Change |
|------|--------|
| **New body control** | Restores Resorepless' **Lower Back and Belly** limit as a separate `belly` setting. |
| **Correct game bone** | Targets only `Bip01 Spine`, matching the original Resorepless v3.6f source. `Spine1` and `Spine2` remain untouched. |
| **No torso stretching** | Never changes the spine's declared X `HeightAxis`; only Y/Z lower-back and abdomen girth can widen. |
| **Conservative presets** | Baseline **1.10**, recommended **1.20**, high **1.25**, extreme **1.30**. |
| **Class shapes preserved** | Widen-only: a class component already above the requested ceiling is never reduced. `Default` and `Min` remain untouched. |
| **Compatibility** | Legacy `spine`, `stomach`, and `abdomen` names resolve to `belly`. Existing custom specs remain literal; reopen body-size configuration to add belly. Named presets gain belly automatically. |

### Why this is safe now
The old tool wrote one value across the whole `Bip01 Spine` scale vector, including
the X torso-length axis. BDO-AIO reads `HeightAxis="X"` from each live descriptor and
leaves it byte-for-byte unchanged. For example, a stock `Max="1.10 1.10 1.10"`
with recommended belly becomes `Max="1.10 1.20 1.20"`—not `1.20 1.20 1.20`.

### Upgrade
1. Replace the previous AIO files with v2.3.0; keep your `config.json` and `pack\`.
2. Open body-size configuration and choose a named preset, or add **belly** to a custom setup.
3. Regenerate body limits, then run PartCutGen and Meta Injector normally.
4. No vanilla restore is needed to add or raise belly. Restore first only if lowering a ceiling already injected by an older tool.

SHA256: see `BDO-AIO-v2.3.0-full.7z.sha256` beside the release archive.

---
## v2.2.8 - 2026-08-07 - vanilla restore safety (body size + game updates)

**Public update from v2.2.0.** Focus: stop silent body-shape loss when you restore
vanilla for launcher patches. Internal experiments between 2.2.1 and 2.2.7 never
shipped on LoversLab / Undertow / GitHub Releases as full packages.

### User-facing summary
| Area | Change |
|------|--------|
| **Game updates** | Many patches stall if meta/PAZ is still modded. Use menu **[R] -> [1]** to go vanilla, update, then re-mod. |
| **Body size safety** | Characters saved **above stock Max** are **clamped** if you load them while the client is vanilla. The game re-saves that shape. |
| **Beauty Album / presets** | Local Customization presets can be **overwritten** with the same clamped data. Loading the preset after clamp often does nothing useful. |
| **Warnings** | Full notice on body-size menu and **[R] -> [1]**; confirm before dry-run; post-restore next-steps list. |
| **Backup** | On restore, copy-only snapshot of `Documents\Black Desert\Customization` into `backup\Customization-<timestamp>\` under the AIO folder. |
| **Still included** | Everything from **2.2.0**: safe censorship, genital nude-only, body Max ceilings, Midnight wizard. |

### Safe free order (avoids paid Beauty Salon rebuild)
1. While still modded: save Beauty Album / Customization presets you care about.
2. Menu **[R] -> [1]** restore vanilla (AIO also snapshots Customization\).
3. Let Pearl Abyss / Steam update or verify.
4. **Do not** log characters that were above stock Max while the client is vanilla.
5. Re-apply body size (+ other packs) -> PartCutGen -> Meta Injector first.
6. Only then log those characters.

### Important limits
- Re-raising Max ceilings after a clamp does **not** restore the old shape or size.
- AIO cannot recover server-side appearance once it was re-saved clamped.
- `backup\Customization-*` only helps if it was taken **before** clamp, and applying a
  preset still usually needs the Beauty Salon (pearls / coupons).
- Salon "lower sliders first" works but costs currency; the free path is the order above.

### Not in this release
- No free open-chest / cleavage remesh for vanilla outfits (Midnight/XYZW still handle remeshed pieces).
- Experimental "Body UNCUT" menu never shipped publicly and is not present.

### Upgrade
1. Download **BDO-AIO-v2.2.8-full.7z**
2. Extract; **START.bat** -> **9** verify pack
3. If old censorship is still injected: **[R]** restore vanilla first (read body-size warnings)
4. Full Wizard / re-apply options -> PartCutGen -> Meta Injector

SHA256 (full archive):
`2cc24893083102f3f84667a9d40ac0d5663350dcce9e6a7497e6af2b62e620e4`

---
## v2.2.0 - 2026-08-06 - minor: safe censorship + genital underwear fix + body Max presets

**Consolidates everything since the last public full archive (v2.1.4)** into one
uploadable release for GitHub, Undertow, and LoversLab. Internal patches 2.1.5 and
2.1.6 are included; body Max presets were finalized in 2.1.3 and remain as below.

### User-facing summary
| Area | Change |
|------|--------|
| **Censorship tiers** | Live-client transparent blanks (DXT5/DXT3 only). No DXT1, no `*_cull*`, no 2018 4?-4 stubs. Default stays **off**. |
| **3D vagina / penis** | Nude body PAC only ??" never overwrite Midnight underwear hide. |
| **Body size** | Max ceilings: vanilla / recommended / high / extreme with per-part warnings. |
| **UI** | Cleaner `[R]` recovery; honest genital class list; clearer pubic shared-atlas menu. |
| **Docs** | `dev/TEXTURE-BLANKING-RULES.md` ??" what texture blanking can and cannot do vs XYZW remeshes. |

### Censorship rewrite (was 2.1.4 + 2.1.6)
- **2.1.4:** expanded live scan no longer blanks `*_cull*` clip masks (floating torso / no legs).
- **2.1.6:** medium/high no longer copy stale Resorepless files. 25/27 legacy names were
  wrong size or 4?-4 stubs (Ranger medium hits were both 152 B stubs ??' ???shorts gone, no body???).
  Blanks are rebuilt from live PAZ; only DXT5/DXT3 get transparent payloads; DXT1 refused
  (measured: even correct BC1 transparent blocks kill base-diffuse meshes on 2026 client).
- Built-in shorts that are **mesh** or **DXT1 base** need a **XYZW remesh**, not censorship.
- After shrinking the emitted set: **restore vanilla meta before re-inject**.

### Genital safety (was 2.1.5)
- Stopped writing full genital body PAC to `armor/38_underwear/*_uw_0001.pac`
  (priority 600 was beating Midnight???s 1 KB dummy hide ??' empty under skirts).

### Body size Max ceilings (was 2.1.3)
- Widen-only Max patch; never writes Default; never HeightAxis length.
- Stock Max is **per part** (breasts ~1.25, thighs ~1.10??"1.15, hips ~1.00??"1.10) ??" not all 1.25.
- Presets: **vanilla** 1.25/1.15/1.10 ?? **recommended** 1.37/1.30/1.18 ?? **high** 1.65/1.40/1.19 ?? **extreme** 2.00/1.45/1.20.
- High/extreme warnings are **per-part** (outfit clip / thigh collide / butt pyramid), not generic ???everything clips.???

### UI / honesty (2.1.6)
- Recovery menu 9 ??' 4 (restore game vs clear staged build).
- 3D vagina picker: only 10 authored-mesh classes (no fake ???new females??? reuse).
- Pubic menu lists private-atlas vs the 13 sharing `phw_01_nude_0001` before you pick.

### Tests
- `tools/bdo_meta`: unit suite green (censorship format guards, genital nude-only, body size, inject priorities, ???).

### Not in this release / known limits
- Nexus full nude AIO: still **not** TOS-safe to host there.
- Censorship cannot remesh Taritas-style built-in shorts; use XYZW collections or commission a mesh.
- Shai / child content: still excluded.

---

## v2.1.6 - 2026-08-06 - fix: censorship tiers can no longer overwrite a live texture with a stale one

### The bug
Censorship tier **medium alone** still holed the lower body under a Ranger skirt
(`[Honor] Taritas Armor`): the built-in shorts came off, but there was no ass, crotch
or skin under them ??" just dead mesh. 2.1.4 only fixed the `expanded` **live scan**;
`medium` / `high` never go through that path. They copy the legacy Resorepless list.

### Cause
`copy_legacy()` checked only that the target name still exists in the live PAZ. It
never checked whether the ~2018 pack file still *matches* the texture it replaces.
Measured against the vanilla meta, 25 of the 27 medium entries do not:

| Problem | Count | Example |
|---------|-------|---------|
| 4?-4 DXT stub, 152??"176 B | 9 | `pew_00_lb_0033_dec.dds` 152 B vs live **1 398 256 B** |
| mipless ??" flat 1024?? over the client's mipped map | 13 | `pdw_02_lb_0005.dds` 524 416 B vs live **699 192 B** |
| geometry clip mask | 1 | `pdw_00_sho_0002_cull.dds` |
| absent from live | 1 | `pbw_00_ub_0054_dm.dds` |
| genuinely current | **2** | `pbw_00_ub_0054.dds`, `pnw_00_ub_0001_dec.dds` |

Ranger gets exactly two files from medium ??" `pew_00_lb_0033_dec.dds` and
`pew_02_lb_0001.dds` ??" and **both are 152-byte 4?-4 stubs**. A 4?-4 block does erase
the painted shorts, but it is then smeared across the entire lower-body UV, so the
body renders as one dead colour. That is the "shorts gone, no ass or crotch, broken
mesh" report exactly.

### Fix ??" rebuild the blank from the live client, and only where blanking means transparent
Two changes, and the second is what makes the feature actually work.

**1. `legacy_reject_reason()`** refuses any 2018 pack file that is a ???4?-4 / <256 B
stub, a `*_cull*` clip mask, or a different byte size than the live block. Only 2 of
27 survive (`pbw_00_ub_0054.dds`, `pnw_00_ub_0001_dec.dds`) ??" genuine authored
repaints, which beat a blank and are still copied.

**2. Everything it refuses is regenerated from the live PAZ** instead of being dropped,
so dimensions, format and mip chain are correct by construction. Whether that is safe
is decided by the pixel format, via new `transparent_payload()`:

| Live format | Encoding written | Decodes to |
|---|---|---|
| **DXT5 / DXT3** | payload zeroed ??' `alpha0=alpha1=0`, index 0 | fully transparent |
| **DXT1** | `00 00 01 00 FF FF FF FF` per block | fully transparent |
| uncompressed + alpha | alpha zeroed | fully transparent |
| `*_cull*` | (clip mask) | never touched |

**DXT1 is never touched.** Tried twice on the live client, meshes broke both times:

1. Zeroing a DXT1 block leaves `color0 == color1 == 0` at index 0 ??" **opaque black**.
   It paints over the body instead of revealing it.
2. BC1 *does* have a transparent encoding (`color0 <= color1` selects 3-colour mode
   where index 3 is transparent ??" `00 00 01 00 FF FF FF FF`, byte-for-byte what the
   2018 pack shipped in its stubs). Writing that at the correct live size **still**
   broke meshes: first across all 157 DXT1 maps in the scan, then again with only the
   pack's 15 hand-picked names.

The block was right and the idea was still wrong. Transparency removes a painted layer
only when the shader treats the map as an **overlay**. BDO uses DXT1 for **base diffuse**
maps, and an alpha-tested base map that is fully transparent discards the whole mesh.
Only alpha-carrying formats (DXT5/DXT3) can be blanked safely ??" those are true overlay
layers, and zeroing their alpha makes them stop drawing without touching geometry.

**Consequence, stated plainly:** built-in shorts that live on a DXT1 base map cannot be
removed by texture censorship at all. That includes the ones under Ranger's
`[Honor] Taritas Armor`. Removing those needs a remeshed garment ??" which is what the
Midnight XYZW collections are, and that outfit is not one of the four they cover.

`pew_00_lb_0033_dec.dds` ??" the layer that paints the shorts under Ranger's
`[Honor] Taritas Armor` ??" is live **DXT5 1024?? / 1 398 256 B**. It is now emitted as a
correctly-sized transparent DXT5, so the shorts come off *and* the body underneath
renders.

### Measured result on this client

| Tier | before | after |
|---|---|---|
| minimal | 3 stale copies | 1 authored + live rebuilds |
| medium / high | 27 attempted, 25 destructive | **10 emitted** |
| expanded | 450 emitted, 432 **zeroed** incl. 57 clip masks | **236 emitted** ??" 235 DXT5 transparent + 1 authored repaint, **0 clip masks** |

Every emitted file decodes to transparent rather than to black.

**Shrinking the emitted set requires a vanilla restore first.** Meta Injector updates
the meta for every file it writes, so a re-inject correctly replaces anything the new
run still emits. But a file the new run *omits* keeps whatever the previous run
injected. Going from 393 files down to 249 leaves 144 stale blanks live unless the
meta is restored first.

### Documented
`dev/TEXTURE-BLANKING-RULES.md` ??" the format rules, the DXT1 trap, why `*_cull*` is
geometry, why the 2018 pack is not a source of files, the restore-before-shrinking
workflow rule, the diagnosis checklist, and the four disproven theories so nobody
re-runs them. `todo.txt` (the isolation checklist) is deleted; it is superseded.

### Correction to the earlier report
The "censorship priority 500 overwrites a Midnight XYZW cull" theory is **wrong** ??"
Midnight ships none of the legacy filenames (checked all 27; zero collisions). The
priority table is real but never fires here. The cause is stale pack files, not a
layer conflict.

### Also: the 3D vagina class picker no longer offers classes it will silently drop
`Select-FemaleClasses` is shared between pubic hair and 3D vagina, but its labels were
hardcoded for **pubes**: it listed all 19 females, tagged 5 as `native-bin` (the pubes
native set, unrelated to genital meshes) and 9 as `EXPER`, and offered
`[N] native bins only` / `[E] new females only`. Picking `[E]` in the 3D-vagina menu
selected nine classes that have **no** authored mesh ??" all of them dropped a moment
later with a "skipped" warning. Nothing was broken, but it read as if experimental
cross-class support still existed. It does not; it was removed in 2.1.1.

The picker now takes a `-Supported` list. In the 3D-vagina menu it shows only the 10
classes that have an authored mesh, tags them `authored mesh`, and refuses `[N]`/`[E]`
with a reason. The pubic-hair menu is unchanged.

### Also: the pubic hair menu states the split up front
It said "the 13 classes sharing one texture can only share a single style" without
naming them, so which classes were individually styleable only became clear after
picking. It now lists both groups by name before you choose, explains that the 13 share
`phw_01_nude_0001`, and notes that separating them would need a material rename inside
the body PAC ??" the change that made bodies invisible in 2.1.0. The group option is
kept: it is the only way Sorceress, Valkyrie, Lahn, Mystic, Maehwa and Kunoichi can
have pubic hair at all.

### Also: the `[R]` recovery menu, 9 options down to 4
It had grown overlapping and off-topic entries: `[V]` already offered to do `[1]`,
`[5]` was literally "do 1 + 3", `[3]`/`[4]` were OptiScaler/DLSS features rather than
game recovery, and `[6]` only printed a paragraph. The two genuinely different actions
??" *undo the game* vs *empty the build folder* ??" were not visually distinguished, which
is the thing that actually needed to be obvious.

```
   [1] RESTORE GAME TO VANILLA      undo every change inside the game
   [2] CLEAR STAGED MOD FILES       empty files_to_patch (does NOT touch the game)
   [3] Vanilla meta backup / scan   -> [S] scan  [B] backup
   [4] Undo experimental graphics   -> [U] uninstall  [R] restore backup
   [0] Back
```

Nothing was removed. `[2]` now asks AIO-only vs everything instead of being two
entries, the verify-game-files steps print automatically when a vanilla restore
cannot complete, and each destructive branch states what it did *not* change.

### What censorship removal is, and is not
It only swaps **textures**. It never installs a nude body ??" that is Midnight
(Suzu / TheGreatSage) and the genital packs. "Shorts gone but nothing underneath" was
a destroyed map, not a half-working reveal. Keep Midnight and the genital pack on;
censorship removal is only there to take the painted-on underwear off the outfits that
have it baked into a decal layer.

`off` remains the default in `config.example.json`.

## v2.1.5 - 2026-08-06 - fix: genital packs no longer overwrite underwear hide

### Empty body / invisible thighs under skirts with 3D vagina (or penis)
User isolation: body OK with pubes alone; hole returned with **medium + 3D vagina**
staged. Measured on Ranger in `files_to_patch`:

| Path | Midnight | Genital (broken) |
|------|----------|------------------|
| `???/38_underwear/pew_00_uw_0001.pac` | **1051 B** dummy hide | **433698 B** full body (= nude PAC) |
| Layer priority | 100 | **600 wins** |

`copy_female_class` / `copy_male_class` had been copying the genital body PAC to
**both** `nude/` and `armor/38_underwear/`. Underwear is a separate equip slot;
stuffing a body mesh there defeats Midnight hide and breaks lower-body under
garments. Fix: write **nude body only**. Tests assert zero `*uw_0001.pac` from
genital apply.

### Not fixed in this patch
- Censorship **expanded** can still punch body (user-confirmed; leave **off**).
- Medium alone was not isolated; keep medium optional after re-test.

## v2.1.4 - 2026-08-06 - fix: censorship "expanded" no longer blanks geometry clip masks

### The bug
One Ranger outfit rendered with no legs ??" torso floating, boots left standing on the
ground. Reported on **Ranger set `0274`**.

### Cause
`censorship_pack_apply.py` treated `*_cull*.dds` as painted-on censorship and ran it
through `blank_keep_size()`, which keeps the declared byte size but zeroes the image
payload. A `_cull` map is not a decal ??" it is the **geometry clip mask** that decides
which body texels survive underneath a garment. All 57 of these files are DXT1, and a
zeroed DXT1 payload decodes to **solid black**, i.e. "cull everything". The whole body
region under the garment was discarded, while separately-materialled pieces (boots)
kept rendering where they were.

This is a texture-side failure. It is *not* partcutdesc: PartCutGen only ever adds a
`Disable` section, and every deployed Ranger garment was already in it.

### Fix
`_cull` is now in a new `EXPAND_NAME_NEVER` list, checked **before** the positive
match rules so no other token can reach it. Cull maps that genuinely need changing are
still shipped as hand-authored images through `MEDIUM_HIGH_FILES`.

Exactly **57 staged files** change behaviour: 56 revert to vanilla, and
`pdw_00_sho_0002_cull.dds` keeps its authored pack image. Nothing else in the
`expanded` tier moves (377 underwear/decal textures are emitted as before).

### Other sets that were silently at risk
Same root cause, all now reverted to vanilla. Most were invisible because the garment
already covered the culled area:

| Class | Sets |
|-------|------|
| Ranger (`pew`) | `00_ub_0274` ??? the reported break |
| Lahn (`psw`) | `00_ub_0125`, `00_ub_0219`, `02_ub_0002`, `02_ub_0003` |
| Dosa (`prsa`) | `00_lb_0002`, `00_ub_0002` |
| Dark Knight (`pdw`) | `00_lb_0002`, `00_ub_0002_01`, `00_sho_0002_dm` |
| Seraph (`pdkl`) | `00_ub_0001`, `00_ub_0001_01` |
| Witch (`pww`) | `00_ub_0203`, `00_sho_0268` |
| Valkyrie (`pvw`) | `10_lb_0097_01`, `10_lb_0097_02` |
| Scholar (`pnyw`) | `00_ub_0001` |
| male classes | `pgms_00_sho_0001`, `phm_10_sho_0083`, `ppm_00_ub_0268`, `pwm_00_ub_0232` |
| NPC / boss | `m0166_desertboss`, `m0456_illezra` |

### Re-applying
The blanked textures are already inside an injected `PAD*.PAZ`, and the corrected stage
simply *omits* them ??" omission cannot overwrite an existing entry. So a plain re-patch
is not enough:

1. `R` menu -> `[1]` ??" restore the vanilla meta snapshot
2. re-run deploy -> PartCutGen -> Meta Injector

## v2.1.3 - 2026-08-06 - body size Max ceilings + vanilla clarity

### What the numbers mean
Each bone has **Min / Default / Max** scale multipliers in `customizationboneparamdesc`:
- **Min** ??? slider floor (vanilla often ~0.70??"0.90)
- **Default** ??? neutral body (vanilla almost always **1.00**)
- **Max** ??? slider ceiling ??" **this is what presets patch** (widen-only)

Presets do **not** force body size; you still set size in beauty salon / character creation. Caps are client-side only.

### Vanilla Max ceilings (restored live PAZ scan, all classes)
| Part | Typical stock Max |
|------|-------------------|
| Breasts | **~1.25** (majority of tags) |
| Thighs | peak **~1.10??"1.15** (varies; some classes already ~1.35 girth) |
| Hips | **~1.00 or 1.10** (many lock at 1.00) |
| Pelvis | peak median **~1.20** (grouped with hips as **butt**) |

So **recommended butt 1.18 is above stock hip Max**, not below.

### Presets (breasts / thighs / butt = Max ceilings)
Stock Max is **different per body part** ??" not ???vanilla = 1.25 everywhere.???

```text
vanilla:     1.25 / 1.15 / 1.10   ~stock Max (breasts / thighs / hips)
recommended: 1.37 / 1.30 / 1.18   NO CLIP unlock (default, user-measured)
high:        1.65 / 1.40 / 1.19   breasts may clip outfits; thighs may collide
extreme:     2.00 / 1.45 / 1.20   breasts clip outfits; thighs collide; butt pyramid risk
```

Above recommended, problems are **per part** (not ???everything clips clothes???):
- **Breasts** ??' outfit clipping (pick outfits that won???t clip)
- **Thighs** ??' thighs collide / overlap each other
- **Butt** ??' lower cheek pyramid polygon spike (mesh looks broken)

### Menu
Prints Min/Default/Max explanation, vanilla ceilings, recommended no-clip values, and per-part red/yellow tradeoff warnings on high/extreme. Custom mode reminds vanilla vs recommended numbers.

### Migration
Named presets re-derive their table on load. Custom specs are left alone.

## v2.1.2 - 2026-08-05 - crash fix after genital generation

### Crash after a successful genital run
`Apply-GenitalPacks` still referenced `$reuse` in its success message after the
variable was removed in 2.1.1, so the launcher threw
`The variable '$reuse' cannot be retrieved because it has not been set` and
exited **after** the packs had already been written correctly. The generated
output was fine; only the closing message crashed.

### Static guard so this cannot recur
New `tools/bdo_meta/test_launcher_static.ps1` walks the launcher's AST and fails
when a variable is read but never assigned in its function, or when a called
function does not exist. Verified against the real bug: reintroducing the
`$reuse` reference makes it fail with the exact line number. This is the second
stale-reference bug of this kind, so it is now covered by a test.

### Wording
Removed every remaining EXPERIMENTAL-REUSE label from the menus. Cross-class
genital reuse no longer exists, so offering it in text was misleading -- one menu
still read "EXPERIMENTAL-REUSE only if you opted in" on a run where nothing of
the sort was possible.

### Runtime status
User-confirmed in game on 2.1.2: body sliders, pubic hair on the texture-only
classes, and 3D vagina with the authored meshes all behave as intended. The
2.1.1 crash was in the post-run message only -- the packs it had already written
were correct.

### Note on PartCutGen "matched 0 files"
Three exclusion patterns in the bundled Midnight pack match nothing
(`pwge_00_lb_0001_dm`, `pdw_00_ub_0002_mul*`, `pdw_00_ub_0002_mul_na*`). These
are informational: PartCutGen finished with `Saving ... DONE` and wrote
`partcutdesc.xml`. Nothing to fix on the AIO side.

## v2.1.1 - 2026-08-04 - genital packs restricted to authored meshes

### Work record
- Task: audit 3D vagina / penis for the failure that made new-class bodies vanish
- Runtime status: **tool-validated** against the shipped pack and the live game
  index ??" not yet in-game confirmed

### Genitals do NOT have the invisible-body bug
Checked every generated PAC against the textures the pack ships: **0 missing
materials**. Nothing is renamed to an invented material name, so no body can lose
its material the way the pubic alias attempt did. Males were already safe ??" they
never had donor reuse, and the 6 classes without an authored mesh are skipped.

### But female donor reuse was wrong in a different way
A genital PAC is a whole body: it carries the mesh **and** the class's skin
material. Copying one under another class's filename hands that class the donor's
body and the donor's skin. Measured against the shipped pack:

- All 10 authored female meshes bind exactly the atlas their vanilla body already
  uses ??" proof they were authored per class.
- **7 of the 9 donor mappings bound a different atlas**: Deadeye??'Ranger,
  Woosa/Scholar/Nova??'Witch, Drakania??'Dark Knight, Guardian/Corsair??'Sorceress.
  Only Maegu and Seraph happened to match. That is the original "Deadeye body
  looks stretched" report.

Female cross-class reuse is removed. Supported: the 10 female classes with an
authored mesh (Sorceress, Ranger, Tamer, Valkyrie, Witch, Kunoichi, Dark Knight,
Mystic, Lahn, Maehwa) and the 6 male classes with one (Warrior, Berserker, Musa,
Wizard, Ninja, Striker). Every other class is skipped with a stated reason.
`--all-classes` / `--new-females` are still accepted but print a note and do
nothing, so an older launcher cannot crash.

### Underwear was being written to a path the game never reads
`copy_female_class` / `copy_male_class` put both the nude and the underwear PAC
under `nude/`. Verified against the live game index: the real entry is
`character/model/1_pc/<folder>/armor/38_underwear/<prefix>_00_uw_0001.pac`, while
the same name under `nude/` is **not** a meta entry. All 16 underwear PACs were
therefore landing where nothing looks and being routed to `_add` as bogus new
entries. Added `female_underwear_folder()` / `male_underwear_folder()` and routed
them correctly.

### Validation
- Python suite: PASS, 83 tests.
- PowerShell suites and the 5.1 parser: PASS.
- Full real-pack run (10 females + 6 males): exit 0, 32 PACs, 17 textures,
  **0 underwear PACs under nude/, 0 files routed to `_add` (was 16), 0 paths
  absent from the game meta, 0 PACs with a missing texture.**
- Requesting the 9 unsupported classes produces 9 explicit skips and no output.
- In-game: confirmed by the user on 2.1.2.

## v2.1.0 - 2026-08-04 - body slider repair + per-class pubic hair

### Work record
- AI application: Claude Code
- Model: Opus 5
- Parent: v2.0.9
- Task: sliders applied to bones the user never selected; bodies stretching (Deadeye)
- Runtime status: **tool-validated** against the live client ??" not yet in-game confirmed
- Scope: body sliders only. Pubic-hair per-class leakage and 3D vagina are deferred.

### Root causes found in the live game data (75 `customizationboneparamdesc` files)
- **The patcher overwrote `Default`.** Vanilla `Default` is per-class and
  anisotropic (Calf ships `1.10 0.88 1.00`, Thigh `0.97 0.90 0.90`, and 296 calf
  / 243 upper-arm / 112 thigh tags are non-uniform). Writing one uniform number
  over it re-proportioned bodies with no slider moved. This is the stretching.
- **All three axes were written with the same value.** The game declares which
  axis is bone length per tag: `HeightAxis="X"` on Thigh, Calf, Pelvis, Spine,
  UpperArm and Forearm; Hip and Breast declare none and are pure girth. Raising
  the length axis lengthens limbs and torso instead of thickening them.
- **`legs` / `spine` / `arms` were selectable at all.** They are length-dominant,
  and they are children of Pelvis, so they already inherit its scale ??" selecting
  pelvis visibly moved them regardless of the parts list.

### Fixes
- `Default` is never written. The game's per-class baseline is preserved exactly.
- The declared `HeightAxis` component is never written. Thigh girth widens; leg
  length stays vanilla, so characters cannot be made taller.
- Widen-only: a component is raised toward the requested max and never lowered
  below what the game already allowed.
- Groups reduced to `breasts`, `thighs`, `butt`. `legs`/`spine`/`arms` retired.
- **`butt` now patches hip *and* pelvis together.** Measured on the live client:
  33 of 75 body files lock `Bip01 L/R Hip` Max at ???1.00 ??" the butt slider cannot
  move at all on those classes ??" and in all 33 the Pelvis still has headroom.
  Patching hip alone was a no-op for ~44% of classes, matching the long-standing
  community reports that the butt slider does nothing on newer classes.
- Each part carries its own max. Recommended preset: breasts 2.0, thighs 1.5,
  butt 1.4. Custom mode asks per part and writes only the parts chosen.
- A named preset re-derives its numbers on upgrade, so tuning a preset reaches
  users who picked it; only `custom` keeps a literal spec.
- Launcher config collapsed to one literal `bodySizeParts` spec
  (`breasts:2.0,thighs:1.5,butt:1.4`); `bodySizeMin`/`Default`/`Max` removed.
  Legacy configs migrate once with a visible message. An empty or retired-only
  selection resolves to *nothing*, never to "all".

### Per-class pubic hair (step 2) ??" root cause was never the filter
Measured from the Midnight nude PACs, which store their texture name once each:

- **13 of 19 female bodies render from ONE texture, `phw_01_nude_0001`**:
  Sorceress, Kunoichi, Mystic, Lahn, Nova, Maehwa, Drakania, Maegu, Woosa,
  Scholar, Valkyrie, Deadeye, Seraph. Only Tamer, Guardian, Dark Knight,
  Corsair, Ranger and Witch own their texture. Styling that one DDS styles all
  13 no matter what the class filter says ??" the filter was working; the target
  was shared. This also matches the community reports about shared body art.
- `NEW_FEMALE_PUBIC_BASE` guessed a donor atlas per class and was **wrong for 7
  of 9 entries** (Guardian was sent to Sorceress's atlas although it owns
  `pgw_01_nude_0001`; Nova/Drakania/Maegu/Woosa/Scholar/Deadeye were all sent to
  the wrong atlas). Donor guessing is gone: the atlas is read from the PAC.
- The launcher also wrote a **second** pubic package ("new females EXPERIMENTAL")
  with its own class list in the same run, and named packages per style/mode so a
  previous run's package stayed in `files_to_patch` and kept being injected.

Fixes (final iteration):
- New `tools/bdo_meta/body_atlas.py` resolves each class's nude body PAC and the
  atlas it actually references, with explicit source precedence (TheGreatSage
  primary, Suzu for Tamer/Deadeye) instead of glob order.
- The earlier material-alias approach (renaming the PAC's embedded texture stem
  to a private name) was tried and **reverted**: that string is a MATERIAL name
  resolved through the engine's material registry, not a texture path a new DDS
  can satisfy, so aliased bodies turned invisible in game.
- Final approach is **texture-only, zero PAC writes**. Classes that own their
  atlas are styled in place (PRIVATE-ATLAS). Classes sharing an atlas are styled
  once for the whole group when every sharer is selected with the SAME style
  (WHOLE-SHARED-GROUP); partial or conflicting selections are SKIPPED with a
  clear notice listing the sharers - never guessed, never widened silently.
- Styles are **per class** (`--styles pnw=full_bush,pcw=trimmed`); the atlas a
  class renders from is read from its PAC, so donor guessing is gone.
- One package (`_pubic_hair_perclass`); stale `_pubic_hair_*` packages are removed
  before every run. The second generator pass is deleted.
- Empty selection is a hard error, never "all".
- Disk cost is surfaced in the menu before generating (~111 MB per distinct style
  chosen among shared-atlas classes).

### Immersive pubic preset
One-key preset giving each class a different look, from the user's breakdown:
full bush (Guardian, Deadeye), medium bush (Witch, Ranger), small bush
(Drakania, Sorceress), trimmed (Corsair, Mystic), thin landing strip (Seraph,
Woosa), shaved innie (Valkyrie, Maehwa). Dark Knight, Kunoichi, Lahn, Maegu,
Nova, Scholar and Tamer are **omitted on purpose** ??" the nude body is already
bare, so leaving them unselected is both the correct look and free.

Known asset limit: **Corsair cannot receive pubic hair.** Its texture is
22,369,776 bytes and no shipped hair bin matches that size. It is skipped with a
clear message, and the menu warns before generating.

### Restore to vanilla (new)
Meta Injector does not edit the original PAZ archives ??" it appends new ones
(21 files, 1.83 GB on the test machine) and rewrites `pad00000.meta`. Restoring
the meta alone therefore leaves multi-GB orphans behind, and any later inject
re-applies from whatever is still in `files_to_patch`, which is why a restore
could look like it did nothing.

- New `tools/bdo_meta/vanilla_restore.py` with `scan`, `backup`, `restore`.
- `restore` puts back the **oldest** backup (a newer one can be a backup of an
  already-injected meta), deletes the injected PAZ, removes the inject stage, and
  verifies the result references exactly the backup's PAZ set. Dry run by default;
  the current meta is saved as `pad00000.pre-restore.meta` before writing.
- A PAZ is deleted only when it is **both** unreferenced by the restored meta
  **and** numbered above the highest number that meta references ??" vanilla ships
  unreferenced low-numbered archives and those are never touched.
- `backup` snapshots a pristine meta to `pad00000.BDOAIO-VANILLA.meta` with a
  sha256 sidecar, and **runs automatically before every inject**. It refuses to
  snapshot an already-injected meta as "vanilla".
- Launcher menu `[R]` gains `[V]` restore, `[S]` scan, `[B]` backup.
- AIO settings in `config.json` are never touched by a restore.

### Validation
- Python suite: PASS, 80 tests (body size, body atlas, vanilla restore, pubic).
- PowerShell: `test_body_size_config.ps1`, `test_pubic_config.ps1`,
  `test_meta_inject_launcher.ps1` all PASS; `bdo_aio.ps1` parses clean under
  Windows PowerShell 5.1.
- Live-asset body-size runs (read-only inputs, output to scratch), diffed
  byte-for-byte against the originals across all 75 files:
  - recommended preset (breasts 2.0 / thighs 1.5 / butt 1.4) ??" all changes on
    the 7 selected bones only;
  - `breasts:2.0` only ??" breast bones only, 0 elsewhere;
  - 0 files resized, 0 `Default` changed, 0 HeightAxis components changed,
    0 ranges narrowed, 0 bytes changed outside the selected tags.
- Live-asset pubic runs (read-only inputs, output to scratch):
  - shared-atlas partial selection (e.g. `pnw=full_bush` alone) ??" SKIPPED with
    the full sharer list, 0 files written;
  - whole shared group with one style (13 classes, `full_bush`) ??" exactly one
    styled DDS generated, 0 PACs written, 0 other atlases touched.
- Note: Guardian has no exact hair bin, so it uses a same-size donor bin (logged
  as `same-size donor`). Placement comes from `offsets.bin` and is unaffected.
- Not verified: in-game appearance of styled textures. Requires Meta Injector +
  beauty salon; pubic-hair per-class results not yet in-game confirmed.

## v2.0.9 - 2026-08-01

### Work record
- AI application: Codex desktop
- Model: GPT-5
- Reasoning mode: high
- Parent: v2.0.8 (`1f84a4e`)
- Task: diagnose and repair restored full-bush textures appearing shaved on Witch/Sorceress
- Intended files: pubic texture generator, one regression test, version/release documentation
- Runtime status at start: **contradicted** for pubic hair (user observed a shaved character despite a clean injector run); 3D vagina remains user-untested
- Authority: edited the clean authoritative Git checkout directly, per the user's no-duplicate/no-output preference; parent commit and GitHub release history provide rollback

### Restored pubic DDS layout repair
- Proved the PAC material bindings and canonical stage precedence were correct: Sorceress uses `phw_01_nude_0001`, Witch uses `pww_01_nude_0001`, and the generated pubic files win injection.
- Found the silent failure: the restored offset table addresses a 4K DXT1 DDS ending at byte 11,184,948, while Midnight ships Ranger/Sorceress/Witch as 89,478,612-byte uncompressed 32-bit DDS files. The old code checked only file length and therefore wrote compressed blocks into unrelated raw pixels while reporting success.
- Preserve the exact legacy byte patch for compatible Tamer/Dark Knight DXT1 files.
- For same-size 32-bit mipmapped DDS files, decode the selected and shaved DXT1 blocks, apply their per-pixel style delta to the matching mip/UV coordinates, and preserve the current body texture, DDS header, mip layout, and alpha.
- Reject unsupported DDS layouts and malformed/length-mismatched overlay resources instead of reporting a false success.

### Validation
- Python suite: PASS, 32 tests including exact DXT1 preservation and DXT1-to-32-bit translation.
- Live-asset dry run (read-only inputs): PASS for Sorceress and Witch; both kept 89,478,612-byte files, byte-identical 128-byte headers, unchanged alpha, and visible full-bush pixels in the expected UV region.
- Temporary generated DDS files and preview were deleted after validation; no duplicate product snapshot or retained output was created.
- Runtime status: **tool-validated**; user must regenerate the pubic option, rerun Meta Injector, and confirm in game. 3D vagina remains untested.

## v2.0.8 - 2026-08-01

### Work record
- AI application: Codex desktop
- Model: GPT-5
- Reasoning mode: high
- Parent: v2.0.7 (`9f57495`)
- Task: hotfix the canonical Meta Injector launcher after Windows PowerShell captured stage-builder console output as the stage path
- Intended files: `bdo_aio.ps1`, PowerShell regression check, and release/control documentation
- Runtime status at start: **contradicted** (user screenshot shows `Start-Process -ArgumentList` rejecting `System.Object[]`)
- PartCutGen evidence: **runtime-evidenced success** (`partcutdesc.xml` saved after 1,679 exclusions; zero-match optional patterns are informational)

### Meta Injector launch hotfix
- Routed canonical stage-builder stdout to the console instead of PowerShell's function success stream, keeping the returned stage path scalar.
- Cast the returned path to `System.String` and pass Meta Injector one explicit quoted `-files` argument string for Windows PowerShell compatibility.
- Added a regression that emits two simulated builder report lines and proves the function still returns only `X:\BDO_AIO_INJECT`.

### Validation
- Windows PowerShell parser: PASS.
- Exact PowerShell regression: PASS.
- Existing Python suite: PASS, 30 tests.
- Runtime status: **tool-validated**; user Meta Injector rerun and in-game validation remain required.

## v2.0.7 - 2026-08-01

### Work record
- AI application: Codex desktop
- Parent: v2.0.6 (`ad1534c`)
- Task: repair genital PAC/UV texture deployment and replace destructive graphics-file copying with safe Remastered-quality 1080p/1440p/4K patches
- Runtime status at start: **contradicted** (user reports black characters and broken graphics settings)
- Authority state: unchanged until the isolated full snapshot passes validation

### Genital PAC/material repair
- Read the nude material stem embedded in each restored PAC and deploy that exact authored diffuse/normal/material texture set under its original filename.
- Removed donor texture renaming: renaming a PAC for another female class does not rewrite its internal material binding or UV atlas.
- Fixed native PAC mismatches already present in the old packs: Mystic, Valkyrie, Kunoichi, Lahn, and Maehwa use `PHW_01`; Ninja uses `PHM_00`; normal Wizard uses `PWM_01`; hard Wizard uses `PWM_00`.
- Validate PAC material count, matching diffuse DDS presence, DDS magic/header, and non-zero dimensions; fail the generator instead of deploying a black/untextured body.
- Kept female donor reuse opt-in and kept all male choices native-only.

### Safe current-client graphics patches
- Removed all three stale complete `GameOption.txt` replacements and the Ultra screenshot profile.
- Removed the unused hardcoded `GameOptionGraphicsPath.txt` placeholder; the AIO resolves the Windows Documents folder directly.
- Added maximum-quality Remastered merge patches for 1920x1080, 2560x1440, and optional 3840x2160 DLDSR.
- Added an atomic line-preserving patcher that refuses duplicate/missing keys and preserves adapter identity, window mode, HDR, audio, UI, camera, gamma/contrast, account settings, ordering, line endings, and unknown/new client fields.
- Corrected current-client enum values from installed 2026 Lua bytecode: the Remastered UI entry saves `graphicOption = 9`, Ultra saves `8`, and High textures save `textureQuality = 0`. The stale 2.0.6 files incorrectly forced `7` and low textures (`2`).
- Use only current, locally verified GameOption keys; no fake ray tracing, DLSS, FSR2/3, Lumen, LOD, shadow, bloom, or other invented hidden-engine keys.
- Keep the current NVIDIA Profile Inspector 3.0.2.1 profile separate and optional; its documented driver-level texture quality settings do not replace GameOption.

### Validation added
- Added regression tests for line-preserving GameOption merges, fail-closed missing keys, and the shipped Remastered/High values.
- Added regression tests for original PAC material filenames and missing-diffuse failure.
- Validated all 22 bundled genital PACs against all 18 bundled DDS files and generated every female donor, male-normal, and male-hard combination against current read-only NA metadata.

## v2.0.6 - 2026-08-01

### Midnight deploy
- Added a non-interactive `--yes` mode to the bundled Midnight deployer and pass it from the AIO after the existing `Deploy now?` confirmation.
- Removed the stale second XYZW/path-length warning. XYZW stays enabled when selected and continues through the canonical short-path injection stage.
- Fixed the Full Wizard to call the same PartCutGen and canonical Meta Injector functions as menus 4/5 instead of bypassing the 2.0.5 injection fix.

### Body-slider crash fix, completed
- Preserve each live vector attribute's exact byte width, including the trailing padding now present on some `Default` fields.
- Fresh live reproduction now passes all 75 files and 17,562 attribute edits with every output byte-length identical to its source.

### Current class coverage and donor safety
- Regenerated heisha 0.4.1 armor/underwear hides from the live 2026-08-01 NA `pad00000.meta`.
- Added 26 Wukong underwear files and 553 Wukong armor files under the verified live prefix `34_pgms`; Dosa coverage remains present.
- Female donor reuse remains available. Male genital packs are now strictly native-only; Archer, Hashashin, Sage, Dosa, Wukong, and the Wizard revamp never receive a borrowed penis mesh.

### Region-correct tool workflow
- Detect the installed client region from `service.ini`.
- Skip Meta Patcher on NA/EU as directed by the author's FAQ. Other detected official regions may be offered the separately downloaded tool; unknown regions are never guessed.
- Meta Injector 1.4.1 and PartCutGen 1.1.0 remain the current bundled heisha workflow. Meta Patcher is not bundled.

### Experimental DLL cleanup
- Removed the redundant DLSS Enabler installer, loose `version.dll`, zzDLL upgrade swaps, and DirectStorage injection.
- Menu X now offers only the unmodified official OptiScaler 0.9.4 bundle and remains explicitly unsupported/unsafe for BDO.
- Uninstall refuses filename-only deletion without the AIO install marker and will not remove an unrelated or unverifiable proxy DLL.

## v2.0.5 - 2026-08-01

### Work record
- AI application: Codex desktop
- Model: GPT-5
- Reasoning mode: high
- Parent: v2.0.4 (`783202e`)
- Task: fix the body-slider crash, replace the path-length skip with a real unlimited-content staging strategy, classify failed patch inputs, and audit redundant tools
- Intended files: `bdo_aio.ps1`, `tools/bdo_meta/body_size_patcher.py`, path/injection helpers, tests, release/control documentation
- Runtime status at start: **contradicted** (user reports slider-only crash)

### Body slider crash fix
- Replaced scalar XML edits such as `Min="0.7"` with the three-component vectors BDO actually stores, such as `Min="0.70 0.70 0.70"`.
- Patch only the matching `BoneName` tag, including duplicate attributes, without normalizing BDO's non-standard XML dialect.
- Preserve the byte length of every extracted `customizationboneparamdesc.xml`; abort the entire generator on malformed/scalar source instead of emitting a partial patch.
- Live-PAZ reproduction: 75 files, 6,786 attribute edits, every output exactly the original byte length.

### No-delete injection path
- Replaced the v2.0.4 MAX_PATH warning/deletion flow with `inject_stage_builder.py`.
- Canonicalize Meta Injector 1.4.1 organizer markers, flatten non-game layers, resolve overrides deterministically, and invoke the injector through temporary short drive roots with its official `-files` argument.
- Keep all Midnight XYZW collections. No collection is deleted or skipped for path length.
- Validate normal paths against the current live meta; preserve `_add` and `_legacy` semantics.
- Migrate old unmarked pubic style folders and old generated new-class files into correct organizer/`_add` staging automatically.

### Failed-file fixes
- Pubic style folders now use an underscore organizer marker, and generated README files use Meta Injector's dot-ignore marker.
- New-class pubic/genital files absent from current meta are intentionally routed through `_add`, not reported as failures.
- Removed redundant donor-named PAC copies from new-class genital output.
- Exact expanded-censorship scan now excludes `texture_thumbnail`, stale legacy names, Shai/child/age-ambiguous names, and non-DDS decode failures.
- Stored ICE-encrypted DDS entries are decrypted and magic-validated before output.
- Pubic composited nude DDS deterministically wins collisions with plain nude textures carried by genital packs.

### Suite reliability and tool audit
- Detect Python through `python.exe`, the `py` launcher, or normal per-user installs.
- Apply-all now reports and returns generator failures instead of claiming success.
- Removed dead Resorepless and PAZ Unpacker launchers plus the obsolete path-length deletion helper.
- Meta Injector 1.4.1 now preflights its exact BDO Toolkit 1.3.0 dependency.
- Meta Patcher 1.1.0 is correctly treated as a separate optional/client-dependent correcting pass and offered when present.
- `config.json` is now generated/ignored; `config.example.json` is the sanitized public template.

## v2.0.4

### Meta Injector path-length guard
- Pre-check `files_to_patch` for Windows **MAX_PATH (~260)** before launching Meta Injector
- Warns when XYZW collections create deep paths under Program Files
- Offers to delete `_midnight_xyzw\_01_xyzw_collections` before inject
- Tool: `tools/bdo_meta/path_length_check.py`

## v2.0.3

### PAZ stock vs modded status scan
- Main menu **[S]** + status line on main screen: detect whether `pad00000.meta` is **STOCK / MODDED / RESTORED**
- Uses Meta Injector `pad00000[*][*].meta.backup` files + hash compare to current meta
- Lists **staged** `files_to_patch` AIO packages vs Midnight content
- Flags experimental OptiScaler/DLSS marker in game root
- Tool: `tools/bdo_meta/paz_status_scan.py --paz <PAZ> [--json] [--write-status auto]`

## v2.0.2

### Per-class pubic hair / female genitals
- Options **[6]** pubic: pick **which females** get the style (ALL / native bins / new females / custom multi-select / type prefixes)
- Options **[V]** female 3D vagina: same per-class picker
- Options **[F]** new-females package: choose which of Seraph/Deadeye/??? to apply
- CLI: `pubic_hair_apply.py --classes phw,pdkl` ?? `genital_pack_apply.py --female-classes ???`
- Config: `pubicHairClasses`, `genitalFemaleClasses` (empty = all)

## v2.0.1

### Hotfix (post-2.0.0 audit)
- **Apply-all RESTORED** fixed for custom body size (`--preset custom` was invalid; now uses effective min/default/max)
- `body_size_patcher.py` accepts `--preset custom` with required `--min/--default/--max`
- Slot hide / body size: clean fatal when `pad00000.meta` missing (no stack trace)
- Expanded censorship name match tightened (underpaint lb/ub + under/cull; less logo collateral)
- `config.json` template includes `slotHideClasses` + `heishaRoot`
- Apply-all genitals: pack presence check; new-females folders when reuse enabled

## v2.0.0

### Censorship expansion
- New tier **expanded**: legacy medium pack + live PAZ scan for under-armor / decal textures on all classes/outfits

### Polish
- **[A] Apply ALL RESTORED choices** (body ??' slots ??' pubic ??' censorship ??' genitals; optional new-females)
- Full wizard can run RESTORED batch after Midnight
- **Per-class slot hide** (`slotHideClasses` / `--classes phw,pdkl`)
- **[H] Post-patch regen helper** (heisha `run.cmd` guidance)
- **[R] Restore / clean** AIO folders, experimental DLLs, backup restore, verify-game notes

### Experimental upscale pack
- Bundled **upgrades/**: newer DLSS (nvngx), AMD FidelityFX/FSR, DirectStorage 1.4
- Installer can **swap FSR** (`fsr31` + upgraded amd_fidelityfx_*) and optional DStorage
- Full offline release includes OptiScaler + Streamline + upgrades

## v1.4.2

### NEW FEMALES genitals + pubic [EXPERIMENTAL-REUSE]
- Options hub **[F]**: Seraph, Deadeye, Woosa, Maegu, Scholar, Nova, Corsair, Drakania, Guardian
- Preferred per-class genital donors + renamed textures
- Pubic: synthesize class-named nude DDS from preferred Midnight base + hair bin
- CLI: `--new-females` on `genital_pack_apply.py` / `pubic_hair_apply.py`
- Outputs: `_genital_EXPERIMENTAL_new_females`, `_pubic_hair_EXPERIMENTAL_new_females\<style>`
- Honesty: replaces TGS/Suzu nude PAC for those classes ??" not original art

## v1.4.1

### Donor reuse is experimental and separated
- Genitals / pubic hair default to **NATIVE (RESTORED)** only
- **EXPERIMENTAL-REUSE** (donor mesh/bin for missing classes) is **opt-in** in Options **[6]** / **[V]**
- Separate `files_to_patch` folders: `_???_RESTORED_native` vs `_???_EXPERIMENTAL_reuse`
- Python CLIs: `--native-only` (default) vs `--all-classes` (experimental reuse)
- Config keys: `pubicHairReuse`, `genitalReuse` (default `false`)
- Docs/README/FEATURE-LABELS updated to match the app

## v1.4.0

Best-effort all-class coverage for genital/pubic packs with NATIVE vs EXPERIMENTAL-REUSE labeling.

## v1.3.5

Honesty labels (MODERN / RESTORED / EXPERIMENTAL) in app and docs.

## v1.3.0

Censorship tier packs and legacy penis / 3D vagina menus.

## v1.2.0

Body size limits, slot hide, pubic hair (easy RESTORED set).

## v1.1.0

Presets + custom body size values.

## v1.0.0

Initial AIO: Midnight wizard, GameOption, NVIDIA .nip, optional EXPERIMENTAL DLSS hub.
