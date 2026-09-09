# Client patches vs. injected metas

**Measured 2026-08-27 on a live NA client, from the launcher's own `update.log`.**

---

## What actually happened (corrected)

The client sat on **3418 from Aug 25 through Aug 26 23:53:55**. The user ran BDO-AIO
at roughly 23:59-00:02. Then:

```
2026-08-26 23:53:55  client version: 3418      <- stable for days
2026-08-27 00:02:52  client version: 3412      <- regressed, 51s after the inject
2026-08-27 00:02:52  Collecting patch files... 3413..3418.PAP  (~1 GB)
2026-08-27 00:03:43  [FLOW] file updated: Paz/pad00000.meta
```

The launcher believed the client had rolled back six versions, re-downloaded the
patches, and **replaced `pad00000.meta`**, wiping the injection and stranding 1.65 GB
of `PAD6xxxx.PAZ` archives. The user's only symptom was the game reporting corrupted
files. Nothing was corrupt.

**The user did not restore anything, and the AIO does not restore before injecting**
(`Run-MetaInjector` calls `backup`, which only no-ops when the snapshot matches the
live client version and now aborts on a stale snapshot). The only
write to `pad00000.meta` in that window was Meta Injector's own. So Meta Injector wrote
a **stale client version into the meta header**.

Where it got `3412` is **not proven** - no meta backup survived anywhere in the install.
`3412` is this install's genuine Aug-19 version, which is consistent with the injector
reusing something from around then, but that is inference, not evidence.

## The header field

`pad00000.meta` begins with a `uint32` little-endian client version at **offset 0**
(`PartCutGen` prints it as `Meta version:`). The launcher reads it to decide whether the
client is up to date. Anything that lowers it triggers a rollback re-patch.

## Rules

1. **Check the version field across an inject.** Record it before Meta Injector runs and
   compare after. `verify --expect-version N` fails when it changed. This is the only
   check that catches this failure, and it catches it *before* the game is launched.
2. **Never restore a snapshot from a different client version.** `restore` refuses this
   (exit 5). This is a separate hazard with the same end result.
3. **After any patch, re-snapshot.** Let the launcher finish, start the game once, then
   `backup --force`, then re-apply AIO.
4. **Judge state from the meta, never from files on disk.** A patched-over inject leaves
   the staging folder and orphan archives behind while the meta is clean. Two guards used
   disk artefacts as a proxy and both were wrong: `backup` refused on the presence of
   `BDO_AIO_INJECT`, and `scan` printed `state: INJECTED` at zero injected references.
5. **Verify block resolution too.** `verify` proves every block lands inside an archive
   that exists - the actual definition of corrupted data.

## PartCutGen is not at fault

Against a clean 3418 meta it reports `Meta file status: Clean` and generates 1679
exclusions normally. It fails only when handed an inconsistent meta - a symptom.

It sets `Console.WindowWidth` as the first statement in `Main`, so it throws
`IOException: The handle is invalid` under any redirected stdin/stdout. To drive it from
a script: spawn with `CREATE_NEW_CONSOLE`, `AttachConsole(pid)`, inject keys with
`WriteConsoleInputW`, scrape with `ReadConsoleOutputCharacterW`. Do not pipe it.

## Quick commands

```bash
python tools/bdo_meta/vanilla_restore.py scan    --paz "<PAZ>"
python tools/bdo_meta/vanilla_restore.py verify  --expect-version 3418 --paz "<PAZ>"
python tools/bdo_meta/vanilla_restore.py backup --force --paz "<PAZ>"
python tools/bdo_meta/vanilla_restore.py restore --apply --paz "<PAZ>"
```
