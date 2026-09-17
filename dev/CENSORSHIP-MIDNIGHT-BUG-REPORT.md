# BDO-AIO: Censorship removal vs Midnight XYZW — bug report for Claude

**Date:** 2026-08-06  
**Project:** `%USERPROFILE%\Documents\Apps\BDO-AIO`
**Game PAZ:** `C:\Program Files (x86)\Steam\steamapps\common\Black Desert Online\PAZ`  
**Code version at report time:** **2.1.5** (genital underwear fix local; censorship still broken)  
**Repo / context:** ShugokiFable/BDO-AIO (user machine)  
**Player symptom:** Under skirts / outfits, **lower body empty** — no butt, no crotch/vagina mesh, **thighs / “slot 9” invisible**. Boots and upper pieces often still visible. Looks like a **geometry hole / cull**, not a missing texture tint.

**Primary test class/outfit:** Female **Ranger (`pew`)** with a green skirt “Looks” outfit that has **baked-in panty/shorts** under the skirt. User wanted: shorts gone **and** nude body (ass/pussy) visible under the skirt.

---

## 1. Executive summary

1. **With Midnight XYZW + other AIO options, but censorship tier = off → no hole.** User confirmed: *“all options except censorship removal and there is no more issues.”*
2. **Censorship tier medium alone → hole returns** (user-confirmed isolation).
3. **Censorship tier expanded → hole** (confirmed as the bad package in an earlier pair; see isolation table).
4. Censorship does **not** “enable” the nude body. It only **replaces underpaint/decal textures** (and sometimes whole `lb` maps or culls). That can erase the *look* of painted shorts while **punching a hole** instead of compositing Suzu/TGS nude body under the garment.
5. **Strong conflict hypothesis with Midnight XYZW:** inject layer priority **`_censorship_*` = 500 > `_midnight_xyzw` = 100**, so censorship **always wins filename collisions**. Medium ships **4×4 stub DDS** and at least one **`*_cull*`** that can overwrite a larger Midnight/XYZW cull.
6. **Not all packages are broken** — only the classic Resorepless-style censorship tiers. Midnight, pubes, body size, 3D vagina (with 2.1.5) work together when censorship is off.

**Ask for Claude:** redesign or retire medium/high/expanded so they are safe **with** full Midnight + XYZW collections, **or** hard-disable / document them as incompatible; do not leave users with a tier that removes paint by destroying lower-body under outfits.

---

## 2. Isolation matrix (what was actually tested)

Be precise — some runs were co-staged first; later runs cleaned that up.

| # | What was staged / enabled | Alone? | Under-skirt body | Notes |
|---|---------------------------|--------|------------------|--------|
| A | Midnight (F, armor **U** underwear hide) + body size; **no** pubic, **no** genital, **no** censorship | Yes (baseline after restore) | **OK** | Body restored after earlier mess |
| B | **Pubic hair only** (+ Midnight); **no** genital, **no** censorship | Yes | **OK** | Pubic = 3 full-size body DDS only; not a mesh killer |
| C | Pubic + **`_censorship_expanded`** (+ Midnight) | **No** (pair) | **BAD** | First blamed “pubes”; stage audit showed expanded co-deployed. User then: *“it WAS the censorship patch.”* Removing censorship, keeping pubes → OK → expanded was the delta |
| D | **Medium + 3D vagina** (+ Midnight, pubes often on) | **No** (pair) | **BAD** | Did not prove which of the two |
| E | **`_censorship_medium` alone** (+ Midnight stack; no genital intended) | **Yes** | **BAD** | User: *“tried with medium censorship removal and the bug was there.”* |
| F | **All options except any censorship** (Midnight + pubes + 3D vagina + rest; `censorshipTier=off`) | N/A | **OK** | User final: *no more issues* |

### Not cleanly isolated

| Item | Status |
|------|--------|
| **Expanded completely alone** (Midnight only + expanded, **no** pubes/genital) | **Not a formal solo run.** Expanded was proven bad as the *difference* that broke a working pubes setup (row C). Expanded **includes the full medium legacy list** + ~376 live blanks → medium-alone FAIL (E) implies expanded remains unsafe. |
| **High alone** | **Not tested.** Code: `high` copies the **same** `MEDIUM_HIGH_FILES` list as `medium` → treat as BAD. |
| **Minimal alone** | **Not tested.** Only 3 files (`pbw_00_lb_0018`, `pbw_00_ub_0054`, `pbw_00_ub_0054_dec`). Lower risk but unproven. |
| **3D vagina alone before 2.1.5** | Co-mixed with medium in row D. After F, vagina works **with** Midnight/pubes when censorship is off. |

### Honesty check (user asked)

> “I forgot we tested censorship alone no? and did it break?”

- **Medium alone: YES tested. YES it broke.** (row E)  
- **Expanded alone (no other restored packs): not a formal solo run**; expanded **did** break when added on top of an otherwise OK Midnight+pubes setup, and it **supersets** medium.  
- **Do not claim expanded was solo-tested on bare Midnight without pubes** — claim medium was, and expanded is a superset + earlier delta-fail.

---

## 3. What each system does (why user was confused)

| System | Job | Reveals nude ass/pussy under skirt? |
|--------|-----|-------------------------------------|
| **Midnight underwear hide** | Replace `armor/38_underwear/*_uw_*.pac` with ~1 KB **dummy** mesh | Indirectly: removes default underwear mesh so body can show |
| **Midnight Suzu / TheGreatSage nude** | Real **nude body PAC** + textures (TGS often `*_noalpha*`) | **Yes** when outfit alpha/cull allows body under garment |
| **XYZW collections** | Skimpy / edited **outfit meshes** (removes or reworks built-in shorts on some looks) | Per-outfit mesh work, not global texture blanking |
| **Armor hide A/P/F** | Strip armor meshes | Full nude look; loses outfit pieces |
| **Pubic hair** | Composite hair onto **nude body DDS** only | Cosmetics on body texture |
| **3D vagina (2.1.5)** | Authored genital **nude body PAC** only | On nude body when that PAC is used |
| **Censorship medium/high/expanded** | Replace `character/texture/*` underpaint / decals / some `lb` / (legacy) culls | **No.** Erases or blanks **textures**. Does not install nude body. Bad maps → **hole**, not reveal |

User observation: censorship seemed to remove Ranger **baked shorts** look but **did not** show ass/pussy.  
**Why:** texture stub/blank/cull kills or clips the region; nude body is a **separate mesh/composite path**. Hole ≠ body reveal.

---

## 4. Inject priorities (conflict mechanism)

From `tools/bdo_meta/inject_stage_builder.py` `layer_priority`:

| Layer prefix | Priority |
|--------------|----------|
| `_midnight_xyzw` | **100** |
| `_censorship_` | **500** |
| `_genital_` | **600** |
| `_pubic_hair_` | **700** |

**Any same relative path in censorship always overrides Midnight/XYZW.**

That is the core “they can’t be used together safely” mechanism when filenames collide or when censorship emits destructive stubs for names the live game still uses as full maps.

---

## 5. Measured evidence on staged medium pack

Path pattern: `files_to_patch/_censorship_medium/character/texture/…`

| File | Size | Header | Risk |
|------|------|--------|------|
| `pew_02_lb_0001.dds` | **152 B** | DDS **4×4** DXT1 | Ranger **lowerbody** name — stub, not a real lb map |
| `pew_00_lb_0033_dec.dds` | **152 B** | 4×4 DXT1 | Stub decal |
| Several `pdw_*` under/dec | **176 B** | tiny DXT | Stubs |
| `pdw_00_sho_0002_cull.dds` | ~699 KB | **1024²** DXT1 (real image in pack) | **Cull map** |
| Same name under Midnight XYZW collection | **~4.2 MB** | **2048²** | Medium **overwrites** Midnight cull (priority 500 > 100) |

Expanded (when regenerated) also blanked hundreds of under/dec textures; **2.1.4** stopped blanking `*_cull*` in the **live expand scan**, but:
- Expanded still **copies full medium legacy list** (including stubs + `pdw_00_sho_0002_cull.dds`).
- Expanded still blanks many non-cull maps; user still saw holes with expanded.

Pubic DDS check (when people blamed pubes): `pew_01_nude_0001.dds` same size as Suzu base, **alpha all 255**, only RGB hair delta — **cannot** delete thigh meshes.

---

## 6. Separate bug fixed in 2.1.5 (genital ≠ censorship)

**Not the censorship hole**, but related “empty under skirt” work:

`genital_pack_apply.copy_female_class` / `copy_male_class` used to write the **same full genital body PAC** to:

1. `…/nude/<prefix>_00_nude_0001.pac` (correct), and  
2. `…/armor/38_underwear/<prefix>_00_uw_0001.pac` (**wrong**)

Measured Ranger:

| Path | Midnight hide | Genital (old) |
|------|---------------|---------------|
| `pew_00_uw_0001.pac` | **1051 B** dummy | **433698 B** (= nude PAC bytes) |
| Priority | 100 | **600 wins** |

**2.1.5 fix:** nude body only; **zero** `*uw_0001.pac` from genital. Tests added. Staged pack regenerated with 0 underwear PACs.

User’s final OK run with vagina + no censorship is consistent with this + censorship off.

---

## 7. Censorship tier implementation (for the fixer)

File: `tools/bdo_meta/censorship_pack_apply.py`

| Tier | Behavior |
|------|----------|
| `off` | No output |
| `minimal` | Copy 3 legacy DDS from `tools/censorship_removal/` |
| `medium` / `high` | Copy `MEDIUM_HIGH_FILES` (~26 names) from pack root |
| `expanded` | medium list + live PAZ scan blanking candidates matching under/dec/`lb`+`dec` rules; **`EXPAND_NAME_NEVER = ("_cull",)`** since 2.1.4 for **expand scan only** |

Legacy list still includes **`pdw_00_sho_0002_cull.dds`** and Ranger stubs **`pew_02_lb_0001.dds`**, **`pew_00_lb_0033_dec.dds`**.

AIO UI still offers expanded as max tier; config currently **`censorshipTier: off`** after failures.

---

## 8. Conclusions

1. **Censorship medium is broken on this user’s Midnight+XYZW 2026 stack** (alone, confirmed).  
2. **Expanded is broken** (delta-confirmed; superset of medium + mass blanks).  
3. **High = medium** in code → treat broken.  
4. **Minimal** unknown.  
5. **Off is the only known-good censorship setting** with full AIO+Midnight.  
6. Symptom of “shorts gone but no crotch” is **expected** for destructive texture/cull overrides — **not** a missing nude body apply.  
7. **Midnight/XYZW already cover** underwear hide, nude body, and many skimpy outfit meshes. Classic Resorepless censorship is an **older parallel pipeline** that **fights** Midnight via priority and stale stubs.  
8. Genital underwear overwrite was a **real separate bug** (2.1.5); do not conflate with censorship when diagnosing.

---

## 9. Recommended fix directions for Claude

Priority order:

1. **Product:** Default `censorshipTier` = `off`. In UI/README: **“Incompatible / unsafe with Midnight XYZW — leave off unless you know you need it.”**  
2. **Hard safety on medium/high list:**  
   - Drop any file with size &lt; ~1 KB or dimensions ≤ 4×4.  
   - Drop **all** `*_cull*` from legacy copy (or only ship if identical size to live meta and not present in Midnight stage).  
   - Drop full `*_lb_*` / `*_ub_*` replacements that are not clearly `*_dec*` underpaint (or verify against live PAZ dimensions before copy).  
3. **Collision gate:** Before writing a censorship DDS, if the same basename exists under staged `_midnight_xyzw` (or known XYZW paths), **skip** or require explicit override.  
4. **Expanded:** Keep no-cull blanking; never blank full body atlases; require live block size match; prefer only `underup` / `*_dec*` with `_lb_`/`_ub_`. Re-test on Ranger skirt after medium is safe.  
5. **Optional:** New tier `midnight_safe` = empty or tiny whitelist proven on live client with Midnight always deployed first.  
6. **Do not** fix by “making censorship apply nude body” — wrong layer; nude is Midnight/genital.  
7. **Regression tests:**  
   - Fail if any emitted DDS is 4×4 or &lt; 256 bytes.  
   - Fail if any emitted name contains `_cull` (unless on an allowlist with size check).  
   - Fail if emitted path collides with a fixture Midnight file of different size.  
8. **User retest after fix:** Restore → Midnight only → add fixed medium only → same Ranger skirt. Expect: no hole; body still from Midnight; any paint removal is bonus.

---

## 10. User config snapshot (end state)

```json
"gender": "F",
"armor": "U",
"censorshipTier": "off",
"female3dVagina": true,
"pubicHairClasses": "pgw,pew,pww",
"pubicHairStyles": "pgw=full_bush,pew=medium_bush,pww=medium_bush"
```

Working stack: Midnight + pubes + 3D vagina + no censorship.

---

## 11. Key code / doc paths

| Path | Role |
|------|------|
| `tools/bdo_meta/censorship_pack_apply.py` | Tiers, medium list, expanded blank, cull never on expand |
| `tools/censorship_removal/` | Legacy DDS sources for minimal/medium |
| `tools/bdo_meta/inject_stage_builder.py` | Layer priorities 100/500/600/700 |
| `tools/bdo_meta/genital_pack_apply.py` | 2.1.5 nude-only (no uw) |
| `pack/midnight_xyzw/` | Underwear hide, nude, XYZW collections |
| `todo.txt` | User isolation checklist |
| `CHANGELOG.md` / `VERSION.md` | 2.1.4 cull expand fix; 2.1.5 genital uw fix |

---

## 12. One-paragraph pitch for Claude

Classic Resorepless **censorship removal** (medium/high/expanded) is punching holes in the lower body under outfits when used with **Midnight XYZW** on a 2026 NA client. User isolation: full AIO stack works with **censorship off**; **medium alone** reintroduces empty thighs/crotch under a Ranger skirt; expanded previously did the same. Mechanism: censorship priority 500 overrides Midnight; medium ships **4×4 stub lowerbody/decal DDS** and a **cull** that can replace Midnight’s larger cull. Censorship only swaps textures—it never reveals the nude body—so “panties gone, no ass/pussy” is a hole, not a missing nude apply. Please make medium/expanded Midnight-safe (or disable them) with size/cull/collision guards and regression tests; leave default off.

---

*End of report. Author: user + Grok isolation session 2026-08-06.*
)
