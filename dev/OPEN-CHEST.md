# Open-chest outfits (v2.6.0)

Resumes the shelved per-outfit work in [PARTCUT-MECHANICS.md](PARTCUT-MECHANICS.md) and
replaces its manual bisection with mesh analysis. Decision record: D-2026-10-13-I.

## What it does

Vanilla part cuts hide the body under every top, so a top with a cleavage opening shows a
seam where the breast should be (worst at high breast sliders). With **Open-chest outfits**
on, the tops whose mesh leaves the chest open are removed from their cut group, so the whole
body renders under them. Every other top keeps its vanilla cut, so closed tops do not clip.
Outfits already staged by Midnight XYZW (or anything else under `files_to_patch`) are never
touched.

| Mode | Selects | Clipping risk |
|------|---------|---------------|
| `off` (default) | nothing | none |
| `open` | nipple zone >= 95% bare and breast mound >= 65% bare (bare-chest bolero, shoulder pieces, corset-only) | almost none |
| `window` | everything `open` does, plus tops with >= 50% of the nipple zone exposed (slits, keyholes, open fronts) | breasts at extreme sliders can poke through the covered remainder |

## How a top is judged

`pac_geometry.py` reads LOD0 positions + triangles straight from the `.pac` (no third-party
exe). `open_chest.py` rasterizes the class's nude body and the top from the front (-Z) and
measures the share of the body's breast mound / nipple zone not covered by the top's
front-half triangles.

- Depth is deliberately not compared against the nude surface: vanilla shells sit INSIDE
  the nude breast volume (the body under them is cut), so a depth test calls every top open.
- A back panel does not count as cover (front half of the torso only).
- Verified visually on contact sheets (`dev/open_chest_sheet.py`) for the Ranger set.
- Bikini cups and narrow plunges cover the nipples, so they stay `off`: uncut, the breast
  would poke through the cloth.

## The registry

`tools/bdo_meta/open_chest_registry.json` is the shipped result: per class, every top with
>= 15% of the breast mound open, with its two measures. It is tied to the client it was
scanned on (`client_version`). Tops added by a later patch are not in it and keep their
vanilla cut: safe by default, just not uncut.

Refresh after a patch (needs numpy; read-only on the game, writes only `--out`; classes scan in
parallel, `--jobs N`, ~1.5 GB RAM each, default 4: about 5 minutes versus 16 serial on client 3474):

```bash
python tools/bdo_meta/open_chest_scan.py --paz "<...>/Black Desert Online/PAZ" --out tools/bdo_meta/open_chest_registry.json
```

Optional review sheets (needs matplotlib):

```bash
python dev/open_chest_sheet.py --paz "<PAZ>" --registry tools/bdo_meta/open_chest_registry.json --classes pew --band window --out sheets
```

## How it is applied

`open_chest_apply.py` runs right after PartCutGen (the launcher does this) and before Meta
Injector: it strips each selected class's folder `<Path>` from its `<BasicCutType>` and adds
every other top of that folder back as a per-file `<CutType>` of the same name, before the
first `<Relation>` (nothing after it is read). Cut groups are shared between classes (for
example `PEW_Upperbody` also lists the Witch/Wizard folders), so only the selected class's
`<Path>` is removed. `_dm` variants follow their base PAC. Re-running is idempotent.

## Not covered (stated, not hidden)

- Windows made by texture alpha / painted skin instead of missing geometry are not detected.
- `event_costume` PACs are file-based cuts and are not processed yet.
- No in-game proof exists for any individual outfit until the user tests it; the technique
  itself (drop the folder `<Path>`, re-add per-file) was confirmed in game on 2026-08-07.
- Look numbers in the character creator are not PAC IDs; names come from the stems.

## Evidence

- PAC reader vs PACtool 1.4.4: 348/348 Ranger PACs identical (positions to 1e-4, triangles
  exact); the 4 remaining PACs hold no mesh in either tool.
- Old bisection (PARTCUT-MECHANICS): Look 7 lies in the 33 small-tier Ranger outfits; the
  detector flags exactly two bare-chest tops among them, `pew_hw_ub_0031` and
  `pew_kw_ub_0001`.
