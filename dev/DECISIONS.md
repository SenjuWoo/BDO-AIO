# Decisions — body uncut

## D-2026-08-06-A — Only free boob windows; pearl is Midnight

**Decision:** BDO-AIO recommended body uncut targets **free** open-chest tops only.  
Pearl/cash is owned by Midnight XYZW collections.

**Why:** User request; Midnight already remeshes/uncuts pearl sets.

## D-2026-08-06-B — No skin-paint auto as recommended

**Decision:** Retire free_items + chest UV skin score as green **[1]**.

**Why:** User QA — closed free Looks (6, 8) clipped; only true window Look (7) should uncut.

## D-2026-08-06-C — Registry + exact discovery

**Decision:** Confirmed stems live in `dev/boob_window_registry.txt`. Discovery via menu **[4] EXACT**. Document research limits in `BOOB-WINDOW-OUTFITS.md`.

**Why:** No public PAC catalog (Firecrawl confirmed). Character-creator Look #s are not PAC IDs.

## D-2026-08-06-D — Do not publish Body UNCUT wave yet

**Decision:** 2.2.1–2.2.6 body-uncut / Zereth research stays **local**. Public stays **v2.2.0**.  
Body UNCUT is **not required** on LL/Undertow/GitHub until remesh or a narrow, honest File-cut feature ships.  
See `dev/PUBLISH-STATUS.md`.

## D-2026-08-06-E — Dev docs under `dev/`

**Decision:** Maintainer / AI markdown lives under `dev/` so release root stays user-facing.

## D-2026-08-06-G — REVOKES D-2026-08-06-F (wrong class tested)

**Decision:** D-2026-08-06-F is **withdrawn**. Its evidence is invalid.

**Why:** `phw` = **Sorceress**, `pew` = **Ranger** (`bdo_aio.ps1:86-87`). The nuclear test
Disabled 357 **Sorceress** upperbody files and then inspected a **Ranger**. Ranger's folder
cut `PEW_Upperbody → 1_Pc/3_PEW/Armor/9_Upperbody` was never touched in any test. Ranger ub
also has **zero** `*_cull*` maps, so no clip-mask mechanism is involved either.

**Consequence:** Body UNCUT is **not** ruled out for Zereth; it was never tried on Ranger.
Remesh is not the required fix path. The real constraint is that all 348 Ranger ub PACs share
one folder-level cut, so blanket uncut clips closed tops — exact-mode `[4]` on Zereth's stem
is the fix. Stem still unidentified.

## D-2026-08-06-F — Ranger free Look 7 is remesh, not Body UNCUT  ⛔ REVOKED by D-2026-08-06-G

**Decision:** Stop pursuing partcut Disable for free open Ranger Look #7 after nuclear test
(357 PHW ub Disabled; areola still cut). Product path for that look is **mesh remesh/XYZW**,
same class of fix as Midnight collections. Body UNCUT remains only for real File body cuts.

**Evidence:** User PartCut log 357 matches + in-game retest; earlier “7 worked + 6/8 clip” was not a
reusable single free-skin stem (Ranger free-skin scores ~0; clips were false-positive closed free uncuts).

**User follow-up:** Find Look 7 display name in-game; do not resume stem-list Body UNCUT hunts.

## D-2026-08-07-H — Remove Body UNCUT from the launcher

**Decision:** Delete `[2] -> [B] Body UNCUT`, `body_uncut_targets.py`, its tests and its
config keys. Keep `tools/bdo_meta/partcut_recut.py` as the dev-only working technique.

**Why:** Measured — PartCutGen exclusions only move per-`<File>` cuts into `Disable`, and
vanilla garments get their cut from a folder-level `<BasicCutType><Path>`. 80 files staged
into `Disable` changed nothing in game. The feature was structurally incapable of its
advertised job, so it was dead weight in the menu.

**Kept:** `_body_uncut` stays in `$Script:AioPatchFolderPrefixes` so recovery still purges
leftover stages from older versions.

## D-2026-10-13-I - Resume per-outfit uncut as "Open-chest outfits", detected from meshes

**Decision:** Un-shelve the per-outfit uncut. Ship it as an opt-in setting (`openChestUncut`:
off / open / window, default off) built on `partcut_recut`'s technique, with the outfit list
produced by mesh analysis instead of hand bisection. Detail: [OPEN-CHEST.md](OPEN-CHEST.md).

**Supersedes:** D-2026-08-06-A ("free only"). Scope is now every vanilla top not staged by
Midnight, free or cash-shop, per user choice on 2026-10-13. D-2026-08-07-H stands: the old
global "Body UNCUT" menu stays removed; this is a different mechanism (folder-to-file recut).

**Why:** "Nothing in the game files marks a top as open-chested" was the blocker. The meshes
do: a native `.pac` reader plus a front-view coverage measure separates bare/windowed tops
from closed ones, validated against PACtool and on contact sheets.

**Scope limits:** Tamer and Shai excluded (age-ambiguous / childlike); texture-alpha windows
and event-costume PACs not handled; list tied to client 3474 (rescanned 2026-10-21; 3454 -> 3474 added 47 tops, removed none) and refreshable with
`open_chest_scan.py`. No in-game proof yet.
