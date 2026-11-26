# How to publish this package

## Before zip

1. Double-click `START.bat` → menu **9** (Verify pack integrity).
2. Expected: thousands of files, roughly **1500–2000 MB** under `pack\`.
3. Menu **9** must also list:
   - all **3** GameOption merge patches plus `tools\bdo_meta\gameoption_patcher.py`
   - `graphics\nvidia\Black_Desert_Max_Quality.nip`
   - `tools\nvidiaProfileInspector\nvidiaProfileInspector.exe` (recommended for self-contained zip)
   - if shipping DLSS: `experimental\dlss\OptiScaler\OptiScaler.dll` + `WARNING.txt` (label release as containing **EXPERIMENTAL / NOT SAFE** tools)
4. Confirm `config.json` is absent from the release source. It is generated locally and ignored. Keep `config.example.json` sanitized:

```json
{
  "pazFolder": "",
  "gender": "F",
  "armor": "A",
  "xyzwCollections": true,
  "npiPath": "",
  "lastRun": null
}
```

5. Do **not** include:
   - Your game `PAZ` folder
   - `files_to_patch` from a live install
   - `__pycache__`, random logs, personal notes
   - Old Downloads folders outside this tree

## Zip command (example)

From the parent of `BDO-AIO`:

```bat
7z a -t7z -mx=5 BDO-AIO-v1.0.0.7z BDO-AIO\* -x!BDO-AIO\.github\presentation
```

Or Windows:

```powershell
$source = Join-Path $PWD 'BDO-AIO\*'
$archive = Join-Path $PWD 'BDO-AIO-vX.Y.Z.zip'
Compress-Archive -Path $source -DestinationPath $archive -Force
```

(Compress-Archive is slower and makes larger zips than 7-Zip.)

## Release notes template

```text
BDO Modding AIO vX.Y.Z

- One-folder install: START.bat
- Bundled Midnight pack + PartCutGen + Meta Injector
- Bundled safe max-quality Remastered 1080p/1440p/4K GameOption merge patches (menu G)
- Bundled NVIDIA .nip + Profile Inspector import (menu N)
- Optional EXPERIMENTAL OptiScaler/DLSS (menu X) — **NOT SAFE**, ban/crash risk
- Choices: gender, armor type, optional XYZW collections
- Requires: BDO PAZ + Python 3 (mods); Documents\Black Desert (GameOption); NVIDIA GPU (nip/DLSS)

Credits: see CREDITS.md
```

## Legal / etiquette

- You are packaging third-party mods + tools. Keep credits.
- Hosting rules (Undertow, Discord, etc.) still apply to the mesh content.
- Do not strip CREDITS.md (or the Credits section in README.md).
- See `BACKUP.md` (this folder) for why `pack\` stays out of git and how full `.7z` release assets are the cloud backup.
