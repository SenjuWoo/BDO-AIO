# BDO-AIO Axis-Aware Body Slider Controls Design

**Date:** 2026-08-09

**Target release:** v2.4.0

**Source authority:** `%USERPROFILE%\Documents\Apps\BDO-AIO-git-push`

**Status:** Approved design awaiting written-spec review

## Goal

Replace the current four scalar body-size groups and four named magnitude presets with a simpler Recommended/Custom workflow. Support the five body regions the user identified, expose only the intended axes, preserve the patcher's byte-safe widen-only behavior, and make breast-axis behavior understandable enough that users can test different scaling theories without guessing.

The feature changes slider `Max` ceilings only. It does not force a character to use those values.

## User Experience

The body-size menu offers:

1. **Recommended** - apply the axis-specific limits in the table below.
2. **Custom** - choose supported axes individually, with Recommended values as defaults.
3. **Keep current** - leave configuration unchanged. This is navigation, not another preset.

Remove Baseline, High, and Extreme from the user-facing preset choices. Users who want larger limits use Custom.

## Recommended Axis Matrix

| Region | Game bone | X | Y | Z |
|---|---|---:|---:|---:|
| Breasts | `Bip01 L Breast`, `Bip01 R Breast` | 1.55 | 1.55 | 1.55 |
| Thighs | `Bip01 L Thigh`, `Bip01 R Thigh` | untouched | 1.35 | 1.35 |
| Butt cheeks | `Bip01 L Hip`, `Bip01 R Hip` | 1.20 | 1.20 | 1.20 |
| Front pelvis/groin | `Bip01 Pelvis` | untouched | 1.40 | 1.40 |
| Belly/lower back | `Bip01 Spine` | 1.28 | untouched | 1.45 |

Rules:

- Left/right paired bones always receive the same limits.
- Thigh X stays untouched so the tool does not increase leg length.
- Pelvis X stays untouched.
- Belly Z is the last belly-depth slider identified by the user.
- Belly X 1.28 is an intentional, narrowly scoped `HeightAxis` exception. It can lengthen the lower torso and move the groin downward. The launcher must say this plainly.
- Belly Y stays untouched.
- Butt cheeks map to the game's left/right Hip bones. The Pelvis bone becomes its own front pelvis/groin region.

## Custom Controls

Custom exposes exactly these inputs:

- Breasts: X, Y, Z
- Thighs: Y, Z
- Butt cheeks: X, Y, Z
- Front pelvis/groin: Y, Z
- Belly/lower back: X, Z

All inputs are absolute `Max` ceilings. There is no automatic percentage or delta mode. Each input defaults to the Recommended value and can be omitted so that axis remains exactly as shipped by the game.

### Required Breast Explanation

The breast screen must explain the axes before prompting:

- X is length/forward projection.
- Y is width.
- Z is height.
- The observed stock peak is uneven: X 1.30 and Y/Z 1.55.
- Those numbers are independent slider ceilings, not a required anatomical ratio and not a body shape that the game automatically applies.
- Setting X/Y/Z to the same value gives equal absolute scale ceilings.
- Adding the same amount to the observed stock caps preserves equal numeric headroom increases, not necessarily equal visible deformation.

Show these examples in the launcher:

| Purpose | X | Y | Z |
|---|---:|---:|---:|
| Recommended balanced absolute ceilings | 1.55 | 1.55 | 1.55 |
| Equal +0.20 over observed stock peak | 1.50 | 1.75 | 1.75 |
| Equal +0.25 over observed stock peak | 1.55 | 1.80 | 1.80 |
| User's previously tested uniform custom limits | 1.65 | 1.65 | 1.65 |

The launcher must not claim that `1.55/1.80/1.80` is more anatomically correct. It is a testing option. Different classes and meshes can deform differently.

## Configuration Schema

Add a body-size schema/version marker and store axis-qualified entries. The canonical form is:

```text
breasts.x:1.55,breasts.y:1.55,breasts.z:1.55,
thighs.y:1.35,thighs.z:1.35,
butt.x:1.20,butt.y:1.20,butt.z:1.20,
pelvis.y:1.40,pelvis.z:1.40,
belly.x:1.28,belly.z:1.45
```

The launcher and Python patcher use the same canonical names and axis rules. The launcher must round-trip the canonical form without changing values or order unexpectedly.

### Legacy Migration

Legacy unqualified values remain readable and migrate once into explicit axes:

- `breasts:V` becomes breast X/Y/Z = V.
- `thighs:V` becomes thigh Y/Z = V; thigh X remains untouched.
- Legacy merged `butt:V` becomes butt-cheek X/Y/Z = V and pelvis Y/Z = V.
- `belly:V` becomes belly Z = V in the corrected five-region model; belly X and Y are not inferred.

Named legacy presets migrate to the new Recommended matrix. Existing Custom values are not discarded. Migration must be documented in the launcher summary and validation notes.

## Patcher Architecture

Replace uniform per-group limits with an explicit per-bone/per-axis allowlist. A target carries an optional value for X, Y, and Z. `None` means preserve the source component byte-for-byte.

Allowed axes:

- Breast: X/Y/Z
- Thigh: Y/Z
- Hip: X/Y/Z
- Pelvis: Y/Z
- Spine: X/Z

The engine continues to:

- Change `Max` only.
- Never change `Min` or `Default`.
- Widen only; retain class-authored maxima that are already larger.
- Preserve the exact byte length of every file and rewritten field.
- Reject non-finite, unsupported, or unrepresentable values.
- Leave unrelated tags and axes unchanged.
- Produce no promoted partial output when any descriptor fails validation.

The existing generic `HeightAxis` protection remains the default. Only the explicit Spine X target may override it. No general switch for modifying length axes is added.

## Error Handling and Output

The launcher rejects unsupported region/axis combinations and invalid numbers before invoking Python. Python repeats validation rather than trusting launcher input.

Generation reports:

- Requested region and axis values.
- Axes widened.
- Axes already above the requested ceiling and therefore preserved.
- Protected or omitted axes left untouched.
- Descriptor/file counts.

Any validation or field-width failure aborts the generated body-size package and reports the exact file, bone, axis, and value. It must not leave a package that looks complete after a partial failure.

## Restore and Upgrade Behavior

No vanilla restoration is required before updating the application source.

A one-time vanilla restore is required before an exact runtime test when any previously injected ceiling must be lowered or removed. This applies to the user's current state because:

- Existing breast ceilings may be 1.65 while Recommended is 1.55.
- The current patcher widens Belly Y, while the new design leaves Belly Y untouched.
- The old butt setting merged Hip and Pelvis behavior.

Users keeping or raising the same axes do not need a restore. The launcher must explain the distinction before recommending restoration.

## Validation

Automated validation must cover:

1. Parsing and formatting every canonical axis token.
2. Legacy scalar migration and named-preset migration.
3. Every allowed axis changing independently.
4. Every disallowed axis remaining byte-identical.
5. Spine X as the sole explicit `HeightAxis` exception.
6. `Min`, `Default`, unrelated tags, and file length remaining unchanged.
7. Widen-only preservation of higher stock maxima.
8. Left/right symmetry.
9. Launcher configuration round-trip and Python argument generation.
10. Fail-closed behavior for malformed values and insufficient field widths.
11. Read-only integration against all 75 available customization descriptors.
12. Package-content and personal-path/credential scans.

Runtime test checklist for the user:

- Recommended breast X/Y/Z travel.
- Custom breast `1.50/1.75/1.75` and `1.55/1.80/1.80` comparisons.
- Thigh length remains unchanged while Y/Z gain travel.
- Butt-cheek and front pelvis/groin controls move independently.
- Belly Z gains travel; Belly Y remains stock after a clean restore.
- Belly X 1.28 produces an acceptable lower-torso/groin shift.
- Cross-class and outfit clipping checks.

Automated and structural checks are not in-game proof.

## Documentation, Installation, and Release

Treat this as v2.4.0 because it changes the configuration schema and separates controls. Incorporate the unpublished v2.3.1 belly-depth fix.

Update `README.md`, `CHANGELOG.md`, `VERSION.md`, `CURRENT.txt`, `VALIDATION.md`, `config.example.json`, launcher help, Python help, and focused tests.

After validation:

1. Commit the authoritative source.
2. Sync only the completed product into `%USERPROFILE%\Documents\Apps\BDO-AIO`, preserving personal configuration through migration.
3. Do not create permanent duplicate work/output folders.
4. Push `main`.
5. Tag and publish v2.4.0.
6. Upload one full archive plus SHA-256 sidecar.
7. Download and checksum-verify the published asset.
8. Keep public v2.3.0 available as the rollback release.

Do not edit the live game PAZ/deployed tree during implementation or structural validation. Runtime restore and injection remain explicit user actions.

## Out of Scope

- Arms, calves, general leg length, and unrelated body bones.
- Changing character `Default` shape or `Min` ceilings.
- Automatically applying a body shape to saved characters.
- Claiming one breast cap ratio is universally anatomically correct.
- Runtime proof for every class or outfit without user testing.
- Unrelated Midnight, genital, pubic-hair, graphics, or Meta Injector changes.
