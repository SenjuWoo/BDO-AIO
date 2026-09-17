# Boob-window outfits — Ranger Look 7

**Last update:** 2026-08-06  
**Class:** Ranger = **`pew`**. (`phw` is **Sorceress** — see `bdo_aio.ps1:86-87`.)  

> ⛔ **Everything in this file that concludes "Body UNCUT cannot fix Look 7" is VOID.**
> Those tests Disabled `phw` (Sorceress) and inspected a Ranger. Ranger's own folder cut,
> `PEW_Upperbody → 1_Pc/3_PEW/Armor/9_Upperbody`, was never disabled. See `dev/STATE.md`.

**User action:** Finding Look #7 **display name** in-game after final inject.

---

## Verdict

**Body UNCUT (partcut Disable) cannot restore areola on free open Ranger Look #7.**

Nuclear test: `1_pc/2_phw/armor/9_upperbody/` matched **357** files → injected → Look 7 still cut at areola.  
Look 8 only slightly clipped when shaking camera (body under armor + high breast scale).

**Next fix class:** identify outfit → **remesh / XYZW-style PAC** (like Midnight collections), not more Disable lists.

---

## Character-creator Looks (user QA)

Looks = **preview slots only**, not PAC IDs.

| Look | Type | Want | Body UNCUT |
|------|------|------|------------|
| 3 | Premium | No poke | Midnight owns pearl remesh; not free auto-uncut |
| 6 | Free closed | No poke | Do not uncut |
| **7** | Free open / boob window | Real areola | **Remesh needed** |
| 8 | Free closed | No poke | Do not uncut; nuclear caused slight clip only |

---

## Test log

| Stage | Look 7 areola | Notes |
|-------|---------------|--------|
| Empty registry | Cut | Pipeline empty |
| Free-skin multi-class (earlier) | User: “worked” | Also clipped closed free; see “false success” below |
| Free PHW + Event_UB + pearl candidates | Still cut | Live meta had Disable; steps OK |
| Nuclear all PHW `9_upperbody/` (357) | **Still cut** | Decisive |
| Optional: + `event_costume/` | User testing | Last partcut path probe |

### Why earlier “7 worked + 6/8 clipped” is not a reusable stem list

- **Clips:** free-skin auto Disabled closed free tops with high chest skin paint → poke-through.  
- **Look 7 “worked”:** for Ranger, free-skin scores ~0; free-window stages did **not** bulk-list free PHW. They mainly added Event_UB + Midnight collection exclusions. Not a clean “only free Look 7” entry we can re-enable.  
- **Nuclear** already Disabled every `9_upperbody` PAC; if Disable alone fixed Look 7, nuclear would have. It did not → cannot “find the one stem from the old list” via partcut.

---

## Pipeline (steps were correct)

1. `START.bat` → main menu **4** PartCutGen → **5** Meta Injector → full game restart.  
2. Same Meta Injector **file count** is normal; content of `partcutdesc.xml` changes; `pad00000.meta` mtime updates.  
3. Live meta extraction previously confirmed free PHW in Disable and Event_UB PHW line commented.

Details: `dev/PIPELINE-VERIFY.md`.

---

## Firecrawl / public data

No public name→PAC map for free/pearl boob windows (BDOCodex/Garmoth = display names only).  
Outfit name from **in-game** is the practical identifier.

---

## User visual guesses (2026-08-06)

| Guess | Pearl / free? | Notes |
|-------|---------------|--------|
| **Blanchard** | Pearl shop | [Ranger] Blanchard set / headpiece — pearls |
| **Ignis** | Pearl shop | [Ranger] Ignis Armor — pearls (~1600 armor alone) |
| **Hercules’ Might** | **Free-ish** | Functional gear (drops / quest boxes / market), **not** Pearl Shop costume. Can be what “I spawned with” style gear looks like, but often bulkier fantasy plate, not always deep cleavage |
| CC “Looks” free slots | Free armor previews | Steam note: first few creation looks are free sets; one premium look is shown by default |

**Spawn / Look #7 with cleavage** is often a **free armor visual** that *resembles* pearl fashion, or a **premium Look preview** (Ignis/Blanchard-like) that is still pearl even if it shows in CC.

### How to identify free CC Looks (no name in UI)

**Fact:** Free Looks in character creation often show **no item name** and the panel says
**“Looks (Not applied in-game)”**. No pearl **P** = not Pearl Shop. There is **no** reliable
hover name. Do **not** ask the user to “open equipment for the name” for pure CC previews.

**What free Looks actually are** (community consensus):

- Leveling / vendor / drop **gear** previews (old progression sets), **not** Pearl costumes.
- Common free-ish sets people map by eye: **Hercules’ Might**, **Dobart**, **Taritas**,
  **Heve**, **Agerian**, **Zereth**, etc. Pearl **P** looks: Ignis, Blanchard, etc.

**Practical ID methods (no name required):**

1. **Screenshot Look 7 only** → match on https://bdo.mmo-fashion.com (filter Ranger, non-pearl equipment)  
2. Count free thumbnails left-to-right/top-to-bottom (skip **P** icons); Look #7 = 7th free tile  
3. Side-by-side: Pearl Shop Ignis/Blanchard (if same silhouette → pearl-like free gear or miscount of P)  
4. Reddit: free CC armors = old leveling gear; one free blue set may even be **unobtainable on NA/EU** (Purnado/Annapurna) but still previews in CC  

User screenshot `2026-08-06_182252038.PNG`: green-hair Ranger, leather underbust + metal plates + red scarf + midriff, open chest — free CC look with cleavage (not a tooltip name).

## Look 7 ID (2026-08-06) — LOCKED

```text
Look 7 display name: [Ranger] Zereth / Zereth Armor
Pearl vs free: FREE equipment (mob drops / leveling gear) — NOT Pearl Shop
  - No P icon in CC (user-confirmed)
  - mmo-fashion: Source = Dropped off mobs
  - Visual: lime-green vest, white feather shoulders/skirt, deep V cleavage,
    single long green sleeve, white undershirt, bow — matches user screenshots
    2026-08-06_189459295.PNG / 189461102.PNG
  - GPT visual match confidence ~0.99; human review agrees silhouette
PAC stem: UNKNOWN (no "zereth" in file names; classic free set = one of free PHW
  phw_0x_ub_* — nuclear Disable of all 9_upperbody already failed areola restore)
Path: expected 1_pc/2_phw/armor/9_upperbody/<stem>.pac
Plan: REMESH / XYZW-style for Zereth chest mesh — NOT Body UNCUT Disable
Screenshots: %USERPROFILE%\Documents\Black Desert\ScreenShot\2026-08-06_189459295.PNG
             %USERPROFILE%\Documents\Black Desert\ScreenShot\2026-08-06_189461102.PNG
Ref: https://bdo.mmo-fashion.com/ranger-zereth/
```

Rejected guesses: Ignis/Blanchard (Pearl + P icon). Hercules was plausible free gear but visual is Zereth (feathered lime vest), not Hercules plate.

Do not restart free-skin auto or nuclear Disable hunts for this symptom.

---

## Related decisions

- `dev/DECISIONS.md` → **D-2026-08-06-F** (remesh, not Body UNCUT)  
- Green menu **[1]** = registry only; registry empty until remesh-confirmed stems exist  
