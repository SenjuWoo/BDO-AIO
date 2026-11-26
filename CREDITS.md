# Credits

**BDO-AIO is a convenience wrapper / installer menu.**  
Almost all mesh, texture, inject, and nude/skimpy content was created by other people.  
This project does **not** claim ownership of those assets.

If you are an original author and want a credit corrected, expanded, or removed from a public mirror, open an issue or contact the repo owner.

---

## This AIO package (wrapper / tools authored or adapted here)

| Component | Credit |
|-----------|--------|
| `START.bat`, `bdo_aio.ps1` menu / wizard / restore flow | **SenjuWoo** (package author) |
| `tools/bdo_meta/*` helpers (body size, pubic apply, genital apply, inject stage builder, GameOption merge, PAZ scan, vanilla restore, etc.) | **SenjuWoo** (package author), built on top of community formats and restored workflows |
| Remastered GameOption merge patches (`graphics/*.patch`) | **SenjuWoo** (cleaned to real BDO keys only) |
| `graphics/nvidia/Black_Desert_Max_Quality.nip` | **SenjuWoo** (NVIDIA driver profile for `blackdesert64.exe`) |
| Docs (`README`, `DESIGN`, `VALIDATION`, feature labels, ecosystem notes) | **SenjuWoo** |

---

## Core third-party mod content (required for nude / hide / inject)

| Component | Author / source | Notes |
|-----------|-----------------|--------|
| **Midnight XYZW** deploy pack, hide generators, collections layout | **Midnight Xyzw** / **heisha** | Upstream: [github.com/midnightxyzw/heisha](https://github.com/midnightxyzw/heisha). Bundled under `pack/midnight_xyzw/` in full offline builds. |
| **Suzu** nude body meshes / textures | **Suzu** | Historical high-quality nude bases; paths under `_00_suzu_nude/`. Originally circulated on Undertow / community channels. |
| Improved high-poly body / mesh fixes (incl. Seraph-related mesh work credited in Midnight lineage) | **TheGreatSage** | Paths under `_00_thegreatsage_nude/`. Discord / community mesh fixer. |
| Armor hide / underwear hide dummy PAC + AO sets | Generated from **Midnight / heisha** pipeline against live PAZ metadata | `_00_remove_all_armors/`, `_00_remove_underwear/` |
| Classic **Resorepless**-era features restored in this AIO (body sliders, slot hide, pubic styles, censorship tiers, authored genital packs) | Original **Resorepless** ecosystem authors + later porters | Resorepless itself is abandoned (~2018). AIO re-implements apply paths; assets under `tools/genital_packs`, `tools/pubic_hair`, `tools/censorship_removal` are from that restored lineage, not invented here. |

### Meta inject pipeline (executables in full offline `pack\`)

| Tool | Credit / lineage |
|------|------------------|
| **Meta Injector** 1.4.1 | BDO modding community / Undertow toolkit lineage — [Meta Injector on Undertow](https://www.undertow.club/downloads/meta-injector.4367/) |
| **PartCutGen** 1.1.0 | BDO modding community (eyeline-fix lineage), shipped with current Midnight/heisha workflow |
| **BDO Toolkit** 1.3.0 | External dependency of Meta Injector — **not redistributed** by this AIO; user installs separately |
| **Meta Patcher** 1.1.0 | Separate region-correcting tool — [Undertow](https://www.undertow.club/downloads/meta-patcher.7829/); **not bundled**; author's FAQ excludes NA/EU |

---

## Midnight XYZW collections (optional outfit packs)

These ship under `pack/midnight_xyzw/_01_xyzw_collections/` when present.  
Folder names and `_source.txt` links are the primary attribution. Credits go to the original Discord / community authors; Midnight only packages them.

| Collection (folder) | Attribution notes |
|---------------------|-------------------|
| `_crimson_sky` | Community Crimson Sky outfit ports — source Discord thread linked in `_source.txt` |
| `_milk_maid_venecil` | Milk Maid / Venecil set (Main / Maid / Fairy Discord sources in `_source.txt`) |
| `_romantic-kitty` | Romantic Kitty ports (incl. Mookyang / Cloud Umbra / Wonderland variants) — Discord source in `_source.txt` |
| `_selaine` | Selaine outfit cuts — local `_readme.txt` |
| `_deadeye/_highnoon_lewd` | Deadeye High Noon lewd set — Discord source in `_source.txt` |
| `_guardian/_kharoxia` | Guardian Kharoxia set — Discord source in `_source.txt` |
| `_kuno/_scarlet_destiny` | Kuno Scarlet Destiny set |
| `_lahn/_kamashella_dalore_ruby_floretta` | Lahn Kamashella / Dalore / Ruby Floretta — Discord source in `_source.txt` |
| `_ranger/_celestia` | Ranger Celestia — Discord source in `_source.txt` |
| `_ranger/_kamashella_delore` | Ranger Kamashella Delore |
| `_02_by_author/_aizen53/_kaine_outfit` | **aizen53** — Kaine outfit pack |

Primary community hub for many of these threads: BDO modding Discord (channel IDs recorded in each `_source.txt`).

If an author name is missing, the folder name + Discord source link is intentional until a clearer public handle is known.

---

## Graphics / driver / experimental utilities

| Component | Author / source |
|-----------|-----------------|
| **NVIDIA Profile Inspector** | **Orbmu2k** and contributors — [github.com/Orbmu2k/nvidiaProfileInspector](https://github.com/Orbmu2k/nvidiaProfileInspector) |
| **OptiScaler** (experimental menu **X**) | OptiScaler project — [github.com/optiscaler/OptiScaler](https://github.com/optiscaler/OptiScaler) |
| **NVIDIA Streamline** DLLs (experimental) | **NVIDIA** (subject to NVIDIA licenses under `experimental/dlss/Streamline/`) |
| AMD FidelityFX / XeSS libraries bundled with OptiScaler | Their respective vendors / open licenses as shipped in the OptiScaler package |

**Experimental DLSS tools are unofficial third-party hooks.** Always ship and read `experimental/dlss/WARNING.txt`. They are **NOT SAFE** (ban / crash / ToS risk).

---

## Hosts & historical community (not ownership claims)

| Place | Role |
|-------|------|
| [Undertow](https://www.undertow.club/) | Long-time host for Meta tools and historical BDO body mods (Suzu-era downloads, injector pages) |
| BDO modding Discord communities | XYZW collection authors, TheGreatSage mesh work, ongoing ports |
| [heisha / midnightxyzw on GitHub](https://github.com/midnightxyzw/heisha) | Current open generator + release notes for Midnight |

---

## Black Desert Online

**Black Desert Online** and all related trademarks, game assets, and client data are property of **Pearl Abyss** (and regional publishers as applicable).

This AIO does not claim any rights to official game files. Client mods can break after patches and may violate the game’s Terms of Service / Operational Policy. Use at your own risk.

---

## Obligations when redistributing this package

1. **Keep this `CREDITS.md` (or equivalent) in every release zip.**
2. **Do not claim mesh/texture/injector content as your own.**
3. **Credit is not the same as permission.** Respect original authors’ redistribution rules on Undertow, Discord, and GitHub.
4. The heavy nude/hide payload lives under `pack/` and selected `tools/` folders — that content remains third-party.
5. Prefer linking authors to their original pages when you publish mirrors.

---

## External tools intentionally **not** bundled

- **BDO Toolkit 1.3.0** (Meta Injector dependency — detect only)
- **Meta Patcher 1.1.0** (region-specific; obtain from author if needed)
- Creator-only / superseded: PAZ Browser/Unpacker, PACtool, 3D Converter, abandoned Resorepless UI, old 0.3.0-only packs when superseded

---

## Thanks

Huge thanks to **Midnight Xyzw**, **Suzu**, **TheGreatSage**, the **Meta Injector / PartCutGen** authors, **Resorepless**-era creators, **aizen53** and every collection author under `_01_xyzw_collections`, **Orbmu2k**, **OptiScaler** contributors, and everyone who kept BDO client-mod tooling alive after official client changes.

Without their work, this AIO menu would be an empty launcher.
