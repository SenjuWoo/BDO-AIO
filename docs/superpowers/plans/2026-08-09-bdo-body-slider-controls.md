# BDO-AIO v2.4.0 Axis-Aware Body Slider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship BDO-AIO v2.4.0 with a Recommended/Custom five-region body-slider workflow, explicit per-axis ceilings, safe legacy migration, verified installation, and a checksum-verified GitHub release.

**Architecture:** Keep `bdo_aio.ps1` as the user-facing configuration authority and `tools/bdo_meta/body_size_patcher.py` as the byte-safe PAZ descriptor transformer. Replace scalar part values with canonical `region.axis:value` tokens shared by both layers. The Python patcher uses an explicit region/axis allowlist, preserves source bytes for omitted axes, and permits only Spine X as an intentional `HeightAxis` exception.

**Tech Stack:** Windows PowerShell 5.1-compatible launcher, Python 3 standard library, unittest-style Python tests, PowerShell AST/config tests, Git, GitHub CLI, and 7-Zip.

## Global Constraints

- Source authority is `%USERPROFILE%\Documents\Apps\BDO-AIO-git-push`.
- The live game directory, PAZ tree, and deployed `files_to_patch` tree are read-only during implementation and structural validation.
- Target release is v2.4.0 and includes the unpublished v2.3.1 belly-depth correction.
- Change only `Max`; never change `Min` or `Default`.
- Preserve exact descriptor byte length and every omitted or unsupported axis.
- Widen only; never lower a class-authored maximum.
- Thigh X, Pelvis X, and Belly Y remain untouched.
- Spine X is the sole explicit `HeightAxis` exception and defaults to 1.28.
- Do not create permanent duplicate source, install, or output trees.
- Automated validation is structural evidence, not in-game proof.

## File Map

- Modify `tools/bdo_meta/body_size_patcher.py`: canonical axis parsing, target mapping, byte-safe per-axis widening, atomic generation, CLI reporting.
- Modify `tools/bdo_meta/test_body_size_patcher.py`: Python unit and descriptor-byte safety coverage.
- Modify `tools/bdo_meta/_verify_presets_vs_stock.py`: validate the v2.4.0 axis matrix rather than retired scalar presets.
- Modify `bdo_aio.ps1`: schema 2 config, migration, Recommended/Custom menu, breast guidance, argument formatting, restore warning.
- Modify `tools/bdo_meta/test_body_size_config.ps1`: PowerShell parser, formatter, migration, menu constants, and encoding coverage.
- Modify `config.example.json`: sanitized schema 2 Recommended example.
- Modify `README.md`, `CHANGELOG.md`, `VERSION.md`, `CURRENT.txt`, `VALIDATION.md`, and `dev/PUBLISH-STATUS.md`: v2.4.0 user and maintainer documentation.
- Create `docs/releases/v2.4.0.md`: validated GitHub release notes and source for the community changelog handoff.
- Create or update focused release notes only inside the existing documentation structure; do not add maintainer paste sheets to the public root.

---

### Task 1: Python per-axis patch engine

**Files:**
- Modify: `tools/bdo_meta/body_size_patcher.py`
- Modify: `tools/bdo_meta/test_body_size_patcher.py`

**Interfaces:**
- Produces: `RECOMMENDED_AXES: dict[str, float]` keyed by canonical names such as `breasts.x`.
- Produces: `parse_axis_spec(raw: str, defaults: dict[str, float] | None = None) -> dict[str, float]`.
- Produces: `expand_legacy_token(name: str, value: float) -> dict[str, float]`.
- Produces: `build_bone_axis_values(axis_values: dict[str, float]) -> dict[str, dict[str, float]]`.
- Produces: `widen_vector_axes(old_value: bytes, axis_limits: dict[str, float], height_axis: int | None, bone: str) -> bytes | None`.
- Preserves: `patch_xml_bytes(raw: bytes, bone_values: dict[str, dict[str, float]]) -> tuple[bytes, int, int]`.

- [ ] **Step 1: Replace retired scalar-group assertions with failing axis-contract tests**

Add tests that assert the complete Recommended matrix and allowed keys:

```python
EXPECTED = {
    "breasts.x": 1.55, "breasts.y": 1.55, "breasts.z": 1.55,
    "thighs.y": 1.35, "thighs.z": 1.35,
    "butt.x": 1.20, "butt.y": 1.20, "butt.z": 1.20,
    "pelvis.y": 1.40, "pelvis.z": 1.40,
    "belly.x": 1.28, "belly.z": 1.45,
}
self.assertEqual(RECOMMENDED_AXES, EXPECTED)
```

Assert unsupported keys such as `thighs.x`, `pelvis.x`, and `belly.y` raise `ValueError` rather than being ignored.

- [ ] **Step 2: Run the focused Python test and verify failure**

Run:

```powershell
python -B .\tools\bdo_meta\test_body_size_patcher.py
```

Expected: FAIL because `RECOMMENDED_AXES` and `parse_axis_spec` do not exist.

- [ ] **Step 3: Implement canonical region/axis metadata and parser**

Add explicit metadata equivalent to:

```python
REGION_BONES = {
    "breasts": ("Bip01 L Breast", "Bip01 R Breast"),
    "thighs": ("Bip01 L Thigh", "Bip01 R Thigh"),
    "butt": ("Bip01 L Hip", "Bip01 R Hip"),
    "pelvis": ("Bip01 Pelvis",),
    "belly": ("Bip01 Spine",),
}
ALLOWED_AXES = {
    "breasts": ("x", "y", "z"),
    "thighs": ("y", "z"),
    "butt": ("x", "y", "z"),
    "pelvis": ("y", "z"),
    "belly": ("x", "z"),
}
HEIGHT_AXIS_EXCEPTIONS = {("Bip01 Spine", "x")}
```

`parse_axis_spec` must normalize case/whitespace, reject duplicates, reject unknown or disallowed axes, reject non-finite values, and require `1.0 <= value <= 99.0`.

- [ ] **Step 4: Add failing tests for independent axis widening**

Use representative tags and verify:

```python
raw = (
    b'<ParamDesc Min="0.70 0.70 0.70" Max="1.30 1.55 1.55" '
    b'Default="1.00 1.00 1.00" BoneName="Bip01 L Breast"/>'
)
values = build_bone_axis_values({"breasts.x": 1.55})
patched, _, _ = patch_xml_bytes(raw, values)
self.assertIn(b'Max="1.55 1.55 1.55"', patched)
self.assertIn(b'Min="0.70 0.70 0.70"', patched)
self.assertIn(b'Default="1.00 1.00 1.00"', patched)
```

Add separate assertions for Thigh X unchanged, Pelvis X unchanged, Belly Y unchanged, and Spine X allowed despite `HeightAxis="X"`.

- [ ] **Step 5: Run tests and verify the new cases fail**

Run the same focused Python command. Expected: axis-patching cases FAIL while parser cases PASS.

- [ ] **Step 6: Implement per-axis bone targets and widening**

Change `build_bone_values` into `build_bone_axis_values`. Rewrite only explicitly supplied components. A component on the descriptor's declared `HeightAxis` stays unchanged unless `(bone, axis)` is present in `HEIGHT_AXIS_EXCEPTIONS`.

Retire functional `--min` support: accept it only for command-line compatibility, print a warning that it is ignored since v2.4.0, and never write `Min`. Keep `--default` ignored with its existing warning.

- [ ] **Step 7: Add failing tests for legacy scalar expansion**

Assert:

```python
self.assertEqual(expand_legacy_token("breasts", 1.65), {
    "breasts.x": 1.65, "breasts.y": 1.65, "breasts.z": 1.65,
})
self.assertEqual(expand_legacy_token("thighs", 1.30), {
    "thighs.y": 1.30, "thighs.z": 1.30,
})
self.assertEqual(expand_legacy_token("butt", 1.18), {
    "butt.x": 1.18, "butt.y": 1.18, "butt.z": 1.18,
    "pelvis.y": 1.18, "pelvis.z": 1.18,
})
self.assertEqual(expand_legacy_token("belly", 1.45), {"belly.z": 1.45})
```

- [ ] **Step 8: Implement legacy token expansion and update CLI defaults/help**

Use Recommended axis tokens when `--parts` is omitted. Accept legacy unqualified tokens only through documented expansion. Log the final canonical axis list and never describe the run as protecting every HeightAxis; call out the intentional Spine X exception.

- [ ] **Step 9: Make output promotion fail-closed**

Extract and patch every matching descriptor first, retaining intended outputs in memory or a temporary directory under the requested output parent. Only write/promote `_body_size_limits` after all selected descriptors pass extraction and byte validation. On failure, leave the previous completed package intact and remove temporary content.

- [ ] **Step 10: Run Python tests**

```powershell
python -B .\tools\bdo_meta\test_body_size_patcher.py
```

Expected: all tests PASS.

- [ ] **Step 11: Commit the Python engine**

```powershell
git add tools/bdo_meta/body_size_patcher.py tools/bdo_meta/test_body_size_patcher.py
git commit -m "feat: add axis-aware body limit patching"
```

---

### Task 2: PowerShell schema, migration, and Recommended/Custom UI

**Files:**
- Modify: `bdo_aio.ps1`
- Modify: `tools/bdo_meta/test_body_size_config.ps1`
- Modify: `config.example.json`

**Interfaces:**
- Consumes: canonical axis keys and values from Task 1.
- Produces: `$Script:BodySizeSchema = 2`.
- Produces: `$Script:BodySizeRecommendedSpec` containing all 12 canonical axis entries.
- Preserves: `Get-BodySizeSpec`, `Format-BodySizeSpec`, `Get-BodySizeArg`, and `Update-BodySizeConfig` as launcher entry points, returning/formatting axis-qualified ordered dictionaries.

- [ ] **Step 1: Write failing PowerShell tests for schema 2**

Replace four-scalar expectations with checks that:

```powershell
$Script:BodySizeRecommendedSpec -eq 'breasts.x:1.55,breasts.y:1.55,breasts.z:1.55,thighs.y:1.35,thighs.z:1.35,butt.x:1.2,butt.y:1.2,butt.z:1.2,pelvis.y:1.4,pelvis.z:1.4,belly.x:1.28,belly.z:1.45'
```

and that `Get-BodySizeSpec` accepts every allowed key while rejecting `thighs.x`, `pelvis.x`, and `belly.y`.

- [ ] **Step 2: Run the config test and verify failure**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\bdo_meta\test_body_size_config.ps1
```

Expected: FAIL because schema 2 constants and axis parsing are absent.

- [ ] **Step 3: Implement schema 2 constants and canonical parsing**

Define the same region/axis allowlist used by Python, update default config creation, include `bodySizeSchema` in config normalization, and make `Get-BodySizeArg` emit canonical tokens without locale-dependent decimal commas.

- [ ] **Step 4: Write failing migration tests**

Create legacy configurations with no `bodySizeSchema` and assert the exact expansions from the approved spec. Verify a named legacy preset becomes the new Recommended spec and an existing Custom value is retained through expansion.

- [ ] **Step 5: Implement one-time migration**

`Update-BodySizeConfig` must:

1. Detect schema 0/1 or an unqualified token.
2. Expand legacy Custom tokens into canonical axes.
3. Replace legacy named presets with the new Recommended matrix.
4. Set `bodySizeSchema` to 2.
5. Preserve unrelated user configuration.
6. Save the migrated canonical form only after successful validation.

- [ ] **Step 6: Write failing tests for the simplified menu text**

Parse the launcher AST/text and assert that the body-size menu contains Recommended, Custom, and Keep current while retired Baseline/High/Extreme choices and preset constants are absent from the active configuration function.

- [ ] **Step 7: Implement Recommended/Custom menu and breast guidance**

Recommended assigns the 12-axis matrix. Custom prompts only the allowed axes and asks whether to include each axis so omission remains possible. Before breast inputs, print:

```text
X = length / forward projection
Y = width
Z = height
Observed stock peak: X 1.30, Y/Z 1.55.
These are independent ceilings, not a required body ratio.
Balanced absolute: 1.55 / 1.55 / 1.55
Equal +0.20 test: 1.50 / 1.75 / 1.75
Equal +0.25 test: 1.55 / 1.80 / 1.80
Different classes and meshes can react differently.
```

Prompt separately for breast X/Y/Z. Explain that Belly X is an intentional torso-length/groin-position adjustment and require an explicit confirmation if Custom exceeds the Recommended 1.28.

- [ ] **Step 8: Update restore guidance and summaries**

The menu must state that no restore is needed to keep/raise a ceiling, but an exact Recommended test requires a clean restore when prior injections widened Belly Y or set breasts above 1.55. Summaries list region, axis, and ceiling rather than scalar group values.

- [ ] **Step 9: Preserve Windows PowerShell encoding**

Keep `bdo_aio.ps1` UTF-8 with BOM because PowerShell 5.1 otherwise renders existing non-ASCII UI text as mojibake. Run the existing BOM and mojibake checks.

- [ ] **Step 10: Run PowerShell and Python focused tests**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\bdo_meta\test_body_size_config.ps1
python -B .\tools\bdo_meta\test_body_size_patcher.py
```

Expected: both PASS.

- [ ] **Step 11: Commit launcher and migration**

```powershell
git add bdo_aio.ps1 config.example.json tools/bdo_meta/test_body_size_config.ps1
git commit -m "feat: add five-region body size controls"
```

---

### Task 3: Live-descriptor integration, documentation, and v2.4.0 metadata

**Files:**
- Modify: `tools/bdo_meta/_verify_presets_vs_stock.py`
- Create: `docs/releases/v2.4.0.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `VERSION.md`
- Modify: `CURRENT.txt`
- Modify: `VALIDATION.md`
- Modify: `dev/PUBLISH-STATUS.md`

**Interfaces:**
- Consumes: the Task 1 axis engine and Task 2 canonical launcher spec.
- Produces: reproducible validation evidence and public v2.4.0 documentation.

- [ ] **Step 1: Update the stock verifier expectations before implementation metadata**

Make `_verify_presets_vs_stock.py` import `RECOMMENDED_AXES`, assert the 12 exact values, and report which axes exceed the observed per-axis stock peaks. It must explicitly permit a Recommended value equal to an observed stock peak when the goal is balanced access, while confirming Belly Z 1.45 exceeds 1.35.

- [ ] **Step 2: Run all focused body-size validation**

```powershell
python -B .\tools\bdo_meta\test_body_size_patcher.py
python -B .\tools\bdo_meta\_verify_presets_vs_stock.py
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\bdo_meta\test_body_size_config.ps1
```

Expected: all PASS.

- [ ] **Step 3: Run read-only 75-descriptor integration**

Use the existing restored/live descriptor extraction path without writing to the game directory. Patch in memory with the Recommended matrix and assert:

- 75 descriptors discovered.
- Every output length equals its input length.
- `Min` and `Default` are unchanged.
- Thigh X, Pelvis X, and Belly Y are unchanged.
- Spine X changes only when below 1.28.
- Higher class-authored maxima are retained.
- No unrelated bone or tag changes.

Record the exact command, counts, and results in `VALIDATION.md`.

- [ ] **Step 4: Run repository-wide structural checks**

```powershell
$env:PYTHONPYCACHEPREFIX = Join-Path $env:TEMP 'bdo-aio-v240-pycache'
python -m compileall -q .\tools
powershell.exe -NoProfile -Command "$errors=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path '.\bdo_aio.ps1'),[ref]$null,[ref]$errors) > $null; if($errors.Count){$errors | ForEach-Object Message; exit 1}"
git diff --check
```

Delete only the named temporary pycache after confirming its resolved path is under `%TEMP%`.

- [ ] **Step 5: Update public and maintainer documentation**

Document:

- Recommended/Custom simplification.
- Five regions and exact axis matrix.
- Detailed breast X/Y/Z explanation and examples.
- Spine X intentional exception and restore boundary.
- Legacy migration.
- Structural-versus-runtime validation boundary.
- Upgrade steps and rollback release.

Write `docs/releases/v2.4.0.md` with the exact public release summary, axis table, migration/restore instructions, safety limits, and explicit statement that cross-class/outfit runtime verification remains pending.

- [ ] **Step 6: Set v2.4.0 metadata**

Set `CURRENT.txt` to `2.4.0`, rewrite the current section of `VERSION.md`, prepend the v2.4.0 section to `CHANGELOG.md`, update the README release summary, and mark GitHub publication as pending in `dev/PUBLISH-STATUS.md`.

- [ ] **Step 7: Scan release-tracked content**

Verify no `config.json`, game PAZ content, deployed `files_to_patch`, `__pycache__`, credentials, personal presets, or staging notes are tracked or destined for the archive.

- [ ] **Step 8: Commit v2.4.0 documentation and validation**

```powershell
git add README.md CHANGELOG.md VERSION.md CURRENT.txt VALIDATION.md dev/PUBLISH-STATUS.md docs/releases/v2.4.0.md tools/bdo_meta/_verify_presets_vs_stock.py
git commit -m "docs: prepare BDO-AIO 2.4.0"
```

---

### Task 4: Installed-folder verification and GitHub publication

**Files:**
- Sync changed tracked product files into: `%USERPROFILE%\Documents\Apps\BDO-AIO`
- Create one release asset under: `Z:\Backup\BDO-mods-assets`
- Update after publication: `dev/PUBLISH-STATUS.md`

**Interfaces:**
- Consumes: clean, validated v2.4.0 authoritative repository.
- Produces: updated existing installation, pushed main branch, `v2.4.0` tag/release, full archive, SHA-256 sidecar, and verified downloaded checksum.

- [ ] **Step 1: Confirm release preconditions**

```powershell
git status --short --branch
git log -5 --oneline --decorate
gh auth status
gh release view v2.4.0 -R ShugokiFable/BDO-AIO
```

Expected: working tree clean; `v2.4.0` release/tag absent; authentication valid. Do not overwrite an unexpected existing tag or release.

- [ ] **Step 2: Sync the existing install without creating another product copy**

Copy only the files changed for v2.4.0 from the authoritative repo into `%USERPROFILE%\Documents\Apps\BDO-AIO`. Preserve `config.json`, `pack`, personal backups, and unrelated installed assets. Re-run focused tests against the installed copies where practical and compare SHA-256 for each synchronized tracked file.

- [ ] **Step 3: Build the single full archive**

Create `Z:\Backup\BDO-mods-assets\BDO-AIO-v2.4.0-full.7z` from the existing installed AIO folder, excluding `config.json`, backups, logs, caches, personal presets, and generated/live patch content. Create `BDO-AIO-v2.4.0-full.7z.sha256` beside it.

- [ ] **Step 4: Inspect archive contents and checksum**

```powershell
7z t 'Z:\Backup\BDO-mods-assets\BDO-AIO-v2.4.0-full.7z'
7z l 'Z:\Backup\BDO-mods-assets\BDO-AIO-v2.4.0-full.7z'
Get-FileHash -Algorithm SHA256 'Z:\Backup\BDO-mods-assets\BDO-AIO-v2.4.0-full.7z'
```

Confirm root layout, required bundled tools/pack, absence of personal content, and sidecar equality.

- [ ] **Step 5: Push source and create release**

```powershell
git push origin main
git tag -a v2.4.0 -m "BDO-AIO v2.4.0"
git push origin v2.4.0
gh release create v2.4.0 'Z:\Backup\BDO-mods-assets\BDO-AIO-v2.4.0-full.7z' 'Z:\Backup\BDO-mods-assets\BDO-AIO-v2.4.0-full.7z.sha256' --repo ShugokiFable/BDO-AIO --title 'BDO-AIO v2.4.0' --notes-file 'docs/releases/v2.4.0.md'
```

Release notes must summarize the five-region matrix, breast axis guidance, migration, restore requirement, and runtime-test caveat.

- [ ] **Step 6: Verify GitHub independently**

Use `gh release view v2.4.0` to confirm tag, assets, sizes, and publication status. Download both assets into a uniquely named `%TEMP%` directory, verify the downloaded SHA-256 against the sidecar and local archive, then delete only that verified temporary directory.

- [ ] **Step 7: Record publication evidence and push it**

Update `dev/PUBLISH-STATUS.md` with branch, commit, tag, release URL, asset names/sizes, and verified SHA-256. Commit and push:

```powershell
git add dev/PUBLISH-STATUS.md
git commit -m "docs: record BDO-AIO 2.4.0 publication"
git push origin main
```

- [ ] **Step 8: Prepare the community changelog handoff**

Provide the user a concise LoversLab/Undertow-ready changelog containing:

- New Recommended/Custom workflow.
- Five supported regions and exact Recommended values.
- Breast X/Y/Z meaning and Custom examples.
- Legacy migration and one-time restore conditions.
- Safety guarantees and runtime caveat.
- GitHub release URL and checksum.

Do not claim cross-class/outfit runtime verification that the user has not performed.
