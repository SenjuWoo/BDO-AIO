# BDO-AIO 2.5.0

Native WPF dashboard with Obsidian & Gold Dark/Night/Light themes, detailed
editing, recovery and graphics previews. Run START.bat; START-CLASSIC.bat
retains the console. Theme selection is remembered by Save settings.


## Surviving client patches

A BDO patch replaces `pad00000.meta` wholesale, wiping any injection and orphaning its
archives. The meta header also carries the client version, so restoring an old snapshot
makes the launcher re-download the meta and report corrupted files.

- `restore` refuses a snapshot from a different client version, with the correct order.
- New `verify` proves every block resolves before you launch; Meta Injector runs it.
- `scan` reports the client version and no longer mislabels a clean meta as injected.
- Startup warns when the client patched since your last inject.

Details: `dev/CLIENT-PATCH-RULES.md`.

## Wording hotfix

The launcher now explicitly says that **Butt cheeks** controls cheek shape and
roundness rather than total ass size. **Front pelvis/groin Z (`pelvis.z`)** is
identified as the main overall pelvis/ass-size control affecting the front groin
and rear. Slider mappings and values are unchanged from 2.4.0.

## Axis-aware body slider controls

The body-size workflow now has only **Recommended**, **Custom**, and **Keep current**. Recommended unlocks five regions with explicit axis ceilings:

| Region | Recommended Max ceilings |
|---|---|
| Breasts | X/Y/Z 1.55 |
| Thighs | Y/Z 1.35; X leg length untouched |
| Butt cheeks | X/Y/Z 1.20 |
| Front pelvis/groin | Y/Z 1.40; X length untouched |
| Belly/lower back | X 1.28, Z 1.45; Y untouched |

Custom exposes each supported axis separately. Breast help explains X length/projection, Y width, Z height, the uneven observed stock caps (X 1.30 versus Y/Z 1.55), and balanced versus equal-additive test values.

## Safety and migration

- Only `Max` is patched. `Min` and `Default` are never modified.
- Values are widen-only and exact descriptor byte length is preserved.
- Spine X is the sole intentional `HeightAxis` exception. It can lengthen the lower torso and shift the groin downward.
- Schema-1 Custom values migrate into explicit axes. Old Belly scalars become Belly Z only and never infer the new Belly X setting.
- A vanilla restore is unnecessary when keeping or raising the same ceilings. Restore once before testing exact Recommended values if an older injection used breasts above 1.55 or widened Belly Y.

## Validation status

The Python and PowerShell suites pass. A read-only live PAZ audit found 75 descriptors; all 75 patched successfully in memory with 3,136 target tags, 2,383 Max edits, and zero byte-length, Min, Default, protected-axis, or widen-only violations.

In-game appearance across classes and outfits still requires user testing.
