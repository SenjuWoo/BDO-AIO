# `pack\` — Midnight mod content (full offline / release archive)

This folder is **required** for menu options that deploy Midnight, run PartCutGen, and launch Meta Injector.

## Is it on GitHub?

| Location | Present? |
|----------|----------|
| Git **source tree** (`main`) | **No** — ignored on purpose (~1.8 GB, 40k+ files) |
| GitHub **Releases** `BDO-AIO-v*-full.7z` | **Yes** (when that release uploaded a full archive) |
| Your local machine | Should be yes if you installed the full offline package |
| `<offline backup>\BDO-mods-assets\` | Secondary backup of tools + older packs / full 7z |

**Ignoring in git ≠ deleting.** It only stops multi-gigabyte binaries from living in every git commit/clone.

## What belongs here

```text
pack\
  midnight_xyzw.cmd
  midnight_xyzw\
    midnight_xyzw.py
    _00_suzu_nude\
    _00_thegreatsage_nude\
    _00_remove_underwear\
    _00_remove_all_armors\
    _01_xyzw_collections\
    ...
  Meta Injector.exe
  PartCutGen.exe
```

Typical source: Midnight / heisha PAZ release (e.g. 0.4.x with Seraph).

## After a source-only clone

1. Download the newest **`BDO-AIO-v*-full.7z`** from Releases, **or** restore from your offline backup.
2. Extract so files land **inside** `pack\` (not a nested random folder name).
3. Run `START.bat` → menu **9** to verify (~1.5–2 GB, thousands of files).

## Credits

See root **[`CREDITS.md`](../CREDITS.md)** — Midnight, Suzu, TheGreatSage, Meta Injector, PartCutGen, collection authors.
