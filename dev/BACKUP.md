# Backup map (do not lose the pack)

## Why `pack/` is in `.gitignore`

| Reason | Detail |
|--------|--------|
| Size | ~**1.8 GB**, **40 000+** files under `pack/midnight_xyzw` |
| Git UX | Normal clones would download multi-GB every time |
| History bloat | One bad commit of the pack makes the repo unusable forever without rewrite |
| Established pattern | Full offline payload ships as **`BDO-AIO-vX.Y.Z-full.7z`** on GitHub Releases |

The same idea applies to bulky **OptiScaler / Streamline** binaries under `experimental/dlss/`.

## Where the real full copy lives

| Path | Role |
|------|------|
| `%USERPROFILE%\Documents\Apps\BDO-AIO\` | **Working tree** (scripts + full `pack\` when installed) |
| GitHub **Releases** | **Primary cloud backup** of the full offline zip (`*-full.7z` + `.sha256`) |
| `Z:\Backup\BDO-mods-assets\` | **Secondary offline backup** (tools, heisha tree, older packs, full 7z copies) |
| Git `main` branch | Scripts + docs + many `tools/` assets — **not** a substitute for `pack\` |

### Known release assets

- Prefer the latest **`BDO-AIO-v*-full.7z`** (e.g. **v2.2.0**). Tags **without** a `-full.7z` asset are **source-only**.
- Always prefer the release that includes **`BDO-AIO-v…-full.7z`**.

## Build a full offline archive (maintainer)

From the **parent** of `BDO-AIO` (PowerShell):

```powershell
$root = '%USERPROFILE%\Documents\Apps\BDO-AIO'
$ver  = (Get-Content (Join-Path $root 'CURRENT.txt') -Raw).Trim()
$out  = "%USERPROFILE%\Documents\Apps\BDO-AIO-v$ver-full.7z"
$seven = 'C:\Program Files\7-Zip\7z.exe'

& $seven a -t7z -mx=5 -mmt=on $out `
  "$root\*" `
  "-xr!config.json" `
  "-xr!.claude" `
  "-xr!backup" `
  "-xr!__pycache__" `
  "-xr!*.pyc" `
  "-xr!.git" `
  "-xr!files_to_patch"

# `.claude` is machine-local tooling state. `backup\` may contain the user's
# private Beauty Album / Customization presets. Neither belongs in a release.

Get-FileHash $out -Algorithm SHA256 | ForEach-Object {
  "$($_.Hash.ToLower())  $(Split-Path $out -Leaf)" |
    Set-Content -Encoding ascii ($out + '.sha256')
}

Copy-Item $out, ($out + '.sha256') 'Z:\Backup\BDO-mods-assets\' -Force
```

Upload both files to the matching GitHub release:

```powershell
gh release upload "v$ver" $out ($out + '.sha256') -R ShugokiFable/BDO-AIO --clobber
```

## Recover if the working folder dies

1. Download `BDO-AIO-v*-full.7z` from GitHub Releases **or** copy from `Z:\Backup\BDO-mods-assets\`.
2. Extract to e.g. `Documents\Apps\BDO-AIO\`.
3. Run menu **9** (verify pack integrity).
4. Optionally re-clone scripts from git and re-copy `pack\` from the archive if you prefer a hybrid layout.

## Credits

Attribution for every third-party piece: **`CREDITS.md`**.
