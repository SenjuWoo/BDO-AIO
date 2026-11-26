# Dashboard guide

`START.bat` opens the native WPF dashboard; `START-CLASSIC.bat` keeps the original
console. Both use the same configuration and patching tools. This page is the detailed
walk-through; the [README](../README.md) has the short version.

## Appearance

Obsidian & Gold ships with **Dark** (default), **Night** and **Light** themes.
Use **Appearance** in the sidebar to preview; **Save settings** remembers the choice.

## Dashboard workflow

1. In **Overview**, choose the live PAZ folder. If Python is not found, use
   **Choose Python...** to select an existing Python 3 `python.exe`, then save.
2. Adjust **Mod choices**, **Body limits**, and the native **Detailed editor**.
   The editor includes individual pubic styles, the shared-texture group, ten authored
   female meshes and six male mesh styles. **Save settings** only saves choices;
   it does not patch the game. Mixed legacy selections remain unchanged until edited.
3. In **Graphics & performance**, preview a bundled GameOption profile before applying
   it. **Remastered 1440p is the dashboard default**; 1080p and DLDSR 4K remain
   available for other displays. The merge keeps unknown/current settings and creates
   a complete backup beside `GameOption.txt`. NVIDIA `.nip` import stays visible in
   the official NVIDIA tool; experimental upscaling remains a separate action.
4. Review the status and dependency checks, close the game and its launcher, then
   choose **Apply saved choices**. Complete PartCutGen and Meta Injector in their
   real tool consoles. A failed step stops the sequence.
5. **Activity** shows actual elapsed time, launcher output and reported outcome.
   **Verify current meta** checks client version and archive references, not appearance.

The dashboard has its own title bar, scrollbar and form styling. `START.bat` launches
the PowerShell host hidden; startup failures appear in a dialog. The real patching
tools and legacy console utilities still use interactive consoles. Routine recovery
and known GameOption profile work now stay in native pages.

## Graphics and performance

The native graphics page currently handles the reversible, well-understood slice:
preview and merge a bundled GameOption profile while preserving the rest of the
current file. Applying requires a fresh preview, acknowledgement, a closed BDO
process/launcher, and a complete timestamped backup. The page does not claim an FPS
gain; retest appearance and performance in-game.

The bundled NVIDIA `.nip` remains an explicit import through NVIDIA Profile Inspector
so driver-side confirmation and rollback stay visible. Experimental DLSS / OptiScaler
is intentionally separate until its compatibility and rollback evidence are stronger.

## Recovery and game updates

Choose **Check recovery options** for a read-only preview. It checks live/backup
client versions, archive bounds and the exact optional archive move list. Choose an
action, read its changes, acknowledge it, then confirm. If files change after the
preview, recovery refuses the old approval and asks for a fresh check.

- **Restore meta:** requires an eligible same-client backup. Retains the current
  meta first, copies local Customization presets if present, then replaces only
  `pad00000.meta`. A preset-copy failure stops recovery. Archives and staging stay.
- **Create current-client reference:** after launcher patch/repair has finished,
  records the current meta and checksum, retaining the previous reference. Archive
  checks do not prove vendor authenticity; do not capture before repair finishes.
- **Isolate unused archives:** moves only the displayed unreferenced high-numbered
  archives into `PAZ/BDO_AIO_RECOVERY/`. No deletion and no disk-space reclamation.

Writes require the game, launcher and patch tools to be closed. Retained originals
and a receipt live under `PAZ/BDO_AIO_RECOVERY/`; preset copies live under the app's
`backup/`. Write failures attempt rollback without overwriting newly changed files;
any rollback failure is reported with the retained path. Nothing is auto-pruned.
After updating, create the current-client reference and reapply choices, PartCutGen
and injection before playing modded characters. Do not load oversized characters
while stock limits are active: a local preset backup cannot undo server-side clamping.

Staged files are not proof that mods are active. A stale backup must never be
restored onto a newer client. Use recovery only after checking the current status.
Rebuilding restored choices moves old AIO-generated stages to
`PAZ/BDO_AIO_STAGE_BACKUPS/`; user folders and Midnight stages are not archived.
Stale generated pubic packages use the same recoverable archive; these archives are
not automatically pruned.

Current work and remaining gates: [`dev/IMPROVEMENT-PLAN.md`](../dev/IMPROVEMENT-PLAN.md).
