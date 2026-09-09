# How BDO actually cuts the body under a garment

**Measured 2026-08-06/07 on a live NA client, Ranger.** This file exists because two
sessions burned a lot of testing on conclusions that turned out to be artefacts. Read it
before touching partcut anything.

---

## The three rules

### 1. Class prefixes are not guessable — look them up

**`phw` is Sorceress. Ranger is `pew`.** Source of truth: `bdo_aio.ps1` `$Script:FemaleClasses`.

An entire test campaign (including a 357-file "nuclear" test) targeted `phw` while
inspecting a Ranger. Ranger was never in the target set once, and every "Body UNCUT cannot
fix this" conclusion drawn from it was void. `docs/MOD-ECOSYSTEM-2026.md` has the table.

### 2. `Disable` cannot override a folder-level cut

`partcutdesc.xml` declares cut-group membership two ways:

```xml
<BasicCutType Name="PEW_Upperbody">          <!-- by FOLDER -->
  <Path>1_Pc/3_PEW/Armor/9_Upperbody</Path>  <!-- all 348 Ranger tops at once -->
</BasicCutType>

<CutType Name="Event_UB">                    <!-- by FILE -->
  <File>1_Pc/3_PEW/Armor/9_Upperbody/PEW_10_UB_0002_E.pac</File>
</CutType>

<Relation CutType="...">                     <!-- which groups a worn item hides -->
  <Cut>PEW_Upperbody</Cut>
</Relation>
```

PartCutGen's `.partcutdesc_exclusions.txt` only moves `<File>` entries into
`<CutType Name="Disable">`. **A garment whose membership comes from a `<Path>` is
unaffected**, no matter how many of its files land in `Disable`.

Measured: staging all 80 free Ranger tops put 80 `<File>` entries in `Disable` and changed
**nothing** in game. Deleting the one `<Path>` line restored the body under **all 348**.

This is why the old `[B] Body UNCUT` feature was removed — for vanilla garments it was
structurally incapable of doing anything. It only ever worked on Midnight/XYZW outfits,
which carry real `<File>` cuts.

### 3. Element order matters — nothing after `<Relation>` is read

Every `CutType` and `BasicCutType` in the stock file precedes the `<Relation>` run.
A `<CutType>` block appended at end of file is **silently ignored**: 268 re-cut `<File>`
entries had zero effect until the block was moved ahead of the first `<Relation>`.

No error, no warning. It just does nothing.

---

## The working technique: per-outfit uncut

`tools/bdo_meta/partcut_recut.py`. Drop the folder `<Path>`, then re-add a `<CutType>`
listing every PAC in that folder **except** the ones to leave uncut. Kept garments leave
the cut group and render the whole body; everything else keeps vanilla behaviour and does
not clip.

```bash
python partcut_recut.py --xml "<PAZ>/files_to_patch/_PartCutGen/character/partcutdesc.xml" --paz "<PAZ>" --group PEW_Upperbody --folder "1_Pc/3_PEW/Armor/9_Upperbody" --keep "pew_03_ub_0002*"
```

The tool analyzes the live `pad00000.meta` by default. Pass `--meta
pad00000.BDOAIO-VANILLA.meta` only when deliberately doing research against that
snapshot; it is not selected implicitly when a stale snapshot exists.

Run **after** PartCutGen `[4]`, **before** Meta Injector `[5]`. PartCutGen rewrites
`partcutdesc.xml`, so re-running `[4]` alone silently reverts to vanilla. Confirmed working
in game: one outfit uncut, nothing else clipped.

**Never park scratch files under `_PartCutGen\character\`** — the inject stage builder
treats every file there as a candidate and aborts with exit code 4.

---

## Open problem: identifying an outfit from a character-creator slot

There is no public name→PAC map (Firecrawl confirmed), and character-creator "Looks" are
preview slots, not PAC IDs. Identification is empirical: uncut a set, see which slot changes.

**Confirmed mapping**

| CC slot | PAC |
|---------|-----|
| Look 11 | `pew_03_ub_0002` |
| Look 12 | underwear (no top) |

**Ranger Look 7 — narrowed, not solved**

| Set tested | Look 7 |
|------------|--------|
| all 348 Ranger tops | **works** |
| free `pew_00_ub_*` (80) | cut → eliminated |
| `pew_03_ub_0002` alone | cut (Look **11** changed instead) |
| small tiers `01/02/03/50/bw/fw/hw/kw/sd/vw` (33 outfits) | **works** → it is in here |

Next split would have been `pew_02_ub_*` + `pew_03_ub_*` (16 outfits), keeping
`pew_03_ub_0002` as a positive control. ~4 rounds remain.

Note the earlier "Look 7 = [Ranger] Zereth" ID is **unreliable**: it came from matching
screenshots to a lime-green feathered vest, and that vest is `pew_03_ub_0002` = Look **11**.
Treat Look 7 as unnamed.

**Texture-colour ranking has poor coverage** — only 55 of 133 non-free Ranger tops have a
diffuse under `character/texture` with a matching stem, so it can rank but not enumerate.

---

## Why this is shelved (2026-08-07)

The areola seam is only noticeable at high breast-size values, so it is cosmetic for most
players. Per-outfit uncut works but needs a hand-built list per outfit per class, and
nothing in the game files marks a top as open-chested. Public release stays **v2.2.0**.

To resume: pick up the bisection above with `partcut_recut.py`.
