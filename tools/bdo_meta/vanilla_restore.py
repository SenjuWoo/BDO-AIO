#!/usr/bin/env python3
"""Back up and restore the live BDO meta, and clean up injected PAZ files.

Meta Injector does not edit the game's original PAZ archives. It appends NEW
PAD*.PAZ files and rewrites pad00000.meta to point at them. So restoring a
pre-inject pad00000.meta returns the game to vanilla, and the appended PAZ files
become orphaned dead weight (they are still on disk, just referenced by nothing).

That is why "restore the meta" alone can look like it did nothing: the multi-GB
injected PAZ files stay behind, and any later inject re-applies from whatever is
still sitting in files_to_patch.

Safety rules:
  * A PAZ file is only ever deleted when it is BOTH unreferenced by the restored
    meta AND numbered above the highest number that meta references. Vanilla ships
    unreferenced low-numbered archives; those are never touched.
  * The oldest backup is treated as the pristine one -- a newer backup can be a
    backup of an already-injected meta.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime
import hashlib
import io
import json
import pathlib
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import uuid

from body_size_patcher import IceDecipher, MetaFile

AIO_BACKUP_NAME = "pad00000.BDOAIO-VANILLA.meta"
AIO_BACKUP_INFO = "pad00000.BDOAIO-VANILLA.json"
PAZ_FILE = re.compile(r"^pad(\d{5})\.paz$", re.IGNORECASE)


def log(msg: str) -> None:
    print(msg, flush=True)


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def meta_version(path: pathlib.Path) -> int:
    """Client version stamped in the meta header (uint32 LE at offset 0).

    The launcher reads this to decide whether the client is up to date. Restoring a
    snapshot taken under an older client writes that older number back, the launcher
    sees the client as out of date, re-downloads Paz/pad00000.meta, and every
    injection is silently wiped. Measured on 2026-08-27: a 3412 snapshot restored
    onto a 3418 install did exactly that.
    """
    with open(path, "rb") as f:
        return struct.unpack("<I", f.read(4))[0]


def referenced_paz(meta_path: pathlib.Path, ice: IceDecipher) -> set[int]:
    """PAZ numbers a meta file points at. Parsed via a temp copy, name-independent."""
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="bdoaio-meta-"))
    try:
        shutil.copy2(meta_path, tmp / "pad00000.meta")
        meta = MetaFile(tmp, ice)
        return {b.pazNum for b in meta.fileBlocks}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def find_backups(paz: pathlib.Path) -> list[pathlib.Path]:
    """Meta Injector backups plus our own, oldest first."""
    found = [p for p in paz.glob("*.meta.backup") if p.is_file()]
    found.sort(key=lambda p: (p.stat().st_mtime, p.name))
    aio = paz / AIO_BACKUP_NAME
    if aio.is_file():
        found.insert(0, aio)
    return found


def orphan_paz(paz: pathlib.Path, keep: set[int]) -> list[pathlib.Path]:
    if not keep:
        return []
    ceiling = max(keep)
    out = []
    for path in paz.iterdir():
        match = PAZ_FILE.match(path.name)
        if not match:
            continue
        number = int(match.group(1))
        if number not in keep and number > ceiling:
            out.append(path)
    return sorted(out, key=lambda p: p.name.lower())


def human(n: int) -> str:
    return f"{n / (1024 ** 3):.2f} GB" if n >= 1024 ** 3 else f"{n / (1024 ** 2):.1f} MB"


def cmd_scan(paz: pathlib.Path, ice: IceDecipher) -> int:
    current = paz / "pad00000.meta"
    if not current.is_file():
        log(f"[FATAL] {current} not found")
        return 2

    current_version = meta_version(current)
    log(f"current meta      : {current.stat().st_size} bytes")
    log(f"client/meta version: {current_version}")

    backups = find_backups(paz)
    if not backups:
        log("backups           : NONE FOUND")
        log("")
        log("[WARN] No pre-inject meta backup exists. Run the 'backup' command BEFORE")
        log("       your next inject, or a restore will need Steam/launcher repair.")
        return 1

    log(f"backups           : {len(backups)} (oldest first)")
    pristine = backups[0]
    pristine_version = meta_version(pristine)
    for path in backups:
        version = meta_version(path)
        mark = "  <== will be used (oldest)" if path == pristine else ""
        log(f"  {path.name}  client/meta version {version}{mark}")

    if pristine_version != current_version:
        log("")
        log("state             : STALE BACKUP / UNKNOWN")
        log(f"                    live client is {current_version}; oldest backup is {pristine_version}")
        log("                    Do not infer injected or clean state from this version mismatch.")
        log("                    Let the launcher finish patching, then run 'backup --force'.")
        return 1

    cur_refs = referenced_paz(current, ice)
    log(f"current references : {len(cur_refs)} PAZ, max {max(cur_refs)}")

    keep = referenced_paz(pristine, ice)
    injected = sorted(cur_refs - keep)
    orphans = orphan_paz(paz, keep)
    total = sum(p.stat().st_size for p in orphans)
    log("")
    log(f"injected PAZ refs : {len(injected)}" + (f"  {injected[:6]}{'...' if len(injected) > 6 else ''}" if injected else ""))
    log(f"deletable PAZ     : {len(orphans)}  ({human(total)})")
    if not injected and not orphans:
        log("state             : VANILLA (meta references nothing extra)")
    elif not injected:
        # A failed or patched-over inject leaves archives behind while the meta is
        # clean. Calling that "INJECTED" sent a whole debugging session down the
        # wrong path -- the meta is what the game reads, so the meta decides.
        log("state             : VANILLA META + ORPHAN ARCHIVES")
        log("                    The meta references none of them, so no mod is live.")
        log("                    Run 'restore --apply' to delete them and reclaim the space.")
    else:
        log("state             : INJECTED")
    return 0


def contiguous_game_max(paz: pathlib.Path) -> int:
    """Highest PAZ index in the game's own unbroken 1..N run.

    The patcher ships PAD00001..PADnnnnn with no gaps. Meta Injector appends its
    archives far above that run (e.g. PAD61337+), so the first gap separates game
    data from injected data.
    """
    on_disk = set()
    for path in paz.iterdir():
        match = PAZ_FILE.match(path.name)
        if match:
            on_disk.add(int(match.group(1)))
    top = 0
    for number in sorted(on_disk):
        if number == top + 1:
            top = number
        elif number > top + 1:
            break
    return top


def meta_is_injected(paz: pathlib.Path, refs: set[int]) -> bool:
    """True when the META ITSELF references archives past the game's own run.

    Judge by what the meta references, never by leftover staging folders on disk:
    a failed inject can leave both the folder and orphan PAZ behind while the meta
    was rolled back by the launcher and is perfectly vanilla.
    """
    top = contiguous_game_max(paz)
    return bool(top) and any(r > top for r in refs)


def cmd_backup(paz: pathlib.Path, ice: IceDecipher, force: bool) -> int:
    target = paz / AIO_BACKUP_NAME
    current = paz / "pad00000.meta"
    if not current.is_file():
        log(f"[FATAL] {current} not found")
        return 2

    if target.is_file() and not force:
        try:
            current_version = meta_version(current)
            snapshot_version = meta_version(target)
        except (OSError, struct.error) as exc:
            log(f"[FATAL] Could not read the live/snapshot meta version: {exc}")
            return 2
        if snapshot_version != current_version:
            log(f"[FATAL] Existing AIO snapshot is stale: snapshot {snapshot_version}, live {current_version}.")
            log("        It will not be silently accepted or overwritten by a normal inject run.")
            log("        Let the launcher finish patching, then run 'backup --force' after the live meta is clean.")
            return 5
        log(f"[OK] AIO vanilla backup already exists for client {current_version}: {target.name}")
        return 0

    backups = find_backups(paz)
    candidates = [p for p in backups if p.name != AIO_BACKUP_NAME]
    cur_refs = referenced_paz(current, ice)

    if candidates:
        source = candidates[0]
        why = "oldest Meta Injector backup"
        if meta_version(source) != meta_version(current):
            log(f"[WARN] Ignoring stale Meta Injector backup {source.name} (client {meta_version(source)}).")
            source = current
            why = "current meta (older backups are stale)"
    else:
        source = current
        why = "current meta"

    src_refs = referenced_paz(source, ice)
    if source == current and len(cur_refs) != len(src_refs):
        log("[FATAL] unexpected mismatch reading the current meta")
        return 3
    if meta_is_injected(paz, src_refs):
        log(f"[FATAL] Refusing to snapshot {source.name} as 'vanilla': it references")
        log(f"        archives above the game's own run (max {max(src_refs)}), so it is injected.")
        log("        Verify/repair the game first, then run backup again.")
        return 4

    shutil.copy2(source, target)
    info = {
        "source": source.name,
        "reason": why,
        "sha256": sha256(target),
        "bytes": target.stat().st_size,
        "paz_referenced": len(src_refs),
        "paz_max": max(src_refs),
        "meta_version": meta_version(target),
    }
    (paz / AIO_BACKUP_INFO).write_text(json.dumps(info, indent=2), encoding="utf-8")
    log(f"[OK] vanilla meta snapshot written from {why}: {target.name}")
    log(f"     sha256={info['sha256'][:16]}...  {len(src_refs)} PAZ referenced, max {info['paz_max']}")
    log(f"     client/meta version={info['meta_version']}")
    return 0


def cmd_restore(paz: pathlib.Path, ice: IceDecipher, delete_paz: bool, apply: bool) -> int:
    current = paz / "pad00000.meta"
    backups = find_backups(paz)
    if not backups:
        log("[FATAL] No backup found. Cannot restore without a pre-inject pad00000.meta.")
        log("        Use the Steam or Pearl Abyss launcher to verify/repair game files.")
        return 2

    pristine = backups[0]
    keep = referenced_paz(pristine, ice)
    cur_refs = referenced_paz(current, ice)
    injected = sorted(cur_refs - keep)
    missing = sorted(keep - cur_refs)
    orphans = orphan_paz(paz, keep)
    total = sum(p.stat().st_size for p in orphans)

    log(f"restore source    : {pristine.name}")
    log(f"  references      : {len(keep)} PAZ, max {max(keep)}")
    log(f"  current adds    : {len(injected)} injected PAZ reference(s)")
    back_ver, cur_ver = meta_version(pristine), meta_version(current)
    log(f"  meta version    : backup {back_ver} vs live {cur_ver}")
    if back_ver != cur_ver:
        log("")
        log(f"[FATAL] STALE SNAPSHOT. This backup was taken under client {back_ver};")
        log(f"        the installed client is {cur_ver}. Restoring it stamps {back_ver} back")
        log("        into the meta header, so the launcher decides the client is out of")
        log("        date, re-downloads Paz/pad00000.meta, and wipes every injection.")
        log("")
        log("        Do this instead:")
        log("          1. Delete this stale snapshot and let the launcher finish patching.")
        log("          2. Launch the game once so the launcher stops repairing.")
        log("          3. Run 'backup' again to snapshot the CURRENT clean meta.")
        return 5
    if missing:
        log(f"  [WARN] backup references {len(missing)} PAZ the current meta does not.")
        log("         The backup may be older than a game patch; verify game files if the game misbehaves.")
    log(f"  deletable PAZ   : {len(orphans)} ({human(total)})")
    for path in orphans[:12]:
        log(f"      {path.name}  {human(path.stat().st_size)}")
    if len(orphans) > 12:
        log(f"      ... and {len(orphans) - 12} more")

    if not apply:
        log("")
        log("DRY RUN -- nothing changed. Re-run with --apply to perform the restore.")
        return 0

    safety = paz / "pad00000.pre-restore.meta"
    shutil.copy2(current, safety)
    log(f"  saved current meta as {safety.name} (in case you want it back)")

    shutil.copy2(pristine, current)
    log(f"[OK] pad00000.meta restored from {pristine.name}")

    removed = 0
    freed = 0
    if delete_paz:
        for path in orphans:
            size = path.stat().st_size
            try:
                path.unlink()
                removed += 1
                freed += size
            except OSError as exc:
                log(f"  [WARN] could not delete {path.name}: {exc}")
        log(f"[OK] removed {removed} injected PAZ file(s), freed {human(freed)}")
    elif orphans:
        log(f"[NOTE] {len(orphans)} injected PAZ file(s) left on disk ({human(total)}).")

    stage = paz / "BDO_AIO_INJECT"
    if stage.exists():
        shutil.rmtree(stage, ignore_errors=True)
        log("[OK] removed BDO_AIO_INJECT stage folder")

    after = referenced_paz(current, ice)
    if after == keep:
        log("[VERIFIED] restored meta references exactly the backup's PAZ set.")
        return 0
    log("[FATAL] post-restore verification failed")
    return 5


def cmd_verify(paz: pathlib.Path, ice: IceDecipher, expect: int = 0) -> int:
    """Prove the live meta is internally consistent BEFORE the game is launched.

    A meta that points past the end of an archive, or at an archive that is not on
    disk, is what the client reports as corrupted data. Checking it here costs one
    parse and turns a mystery crash into a message.
    """
    current = paz / "pad00000.meta"
    if not current.is_file():
        log(f"[FATAL] {current} not found")
        return 2

    sizes = {}
    for path in paz.iterdir():
        match = PAZ_FILE.match(path.name)
        if match:
            sizes[int(match.group(1))] = path.stat().st_size

    tmp = pathlib.Path(tempfile.mkdtemp())
    try:
        shutil.copy2(current, tmp / "pad00000.meta")
        meta = MetaFile(tmp, ice)
        absent, overflow, ok = {}, [], 0
        for block in meta.fileBlocks:
            size = sizes.get(block.pazNum)
            if size is None:
                absent[block.pazNum] = absent.get(block.pazNum, 0) + 1
            elif block.fileOffset + (block.zsize or block.size) > size:
                overflow.append(block)
            else:
                ok += 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    live = meta_version(current)
    log(f"client/meta version: {live}")
    if expect and live != expect:
        log("")
        log(f"[FAIL] The meta header now says client {live}, but it said {expect} before this run.")
        log("       The launcher reads that number. A lower value makes it believe the client")
        log("       rolled back, so it re-downloads Paz/pad00000.meta and every mod is wiped.")
        log("       Measured 2026-08-27: 3418 -> 3412 cost a 1 GB re-patch and the whole injection.")
        log("")
        log("       DO NOT LAUNCH. Restore, then re-inject:")
        log("         vanilla_restore.py restore --apply --paz \"<PAZ>\"")
        return 1
    log(f"blocks readable    : {ok}")
    log(f"missing archives   : {sum(absent.values())} block(s) across {len(absent)} PAZ {sorted(absent)[:8]}")
    log(f"past end of archive: {len(overflow)}")
    if absent or overflow:
        log("")
        log("[FAIL] This meta is NOT safe to play. The client will report corrupted data.")
        log("       Restore with: vanilla_restore.py restore --apply")
        return 1
    log("")
    log("[OK] every block resolves inside an archive that exists. Safe to launch.")
    return 0


def inspect_recovery_meta(paz: pathlib.Path, path: pathlib.Path, ice: IceDecipher) -> dict:
    """Read a candidate against real archive bounds without modifying PAZ."""
    sizes = {int(PAZ_FILE.match(p.name)[1]): p.stat().st_size
             for p in paz.iterdir() if PAZ_FILE.match(p.name) and p.is_file()}
    with tempfile.TemporaryDirectory(prefix="bdo-recovery-inspect-") as tmp:
        shutil.copy2(path, pathlib.Path(tmp) / "pad00000.meta")
        # The shared parser prints progress; keep the recovery JSON channel clean.
        with contextlib.redirect_stdout(io.StringIO()):
            meta = MetaFile(pathlib.Path(tmp), ice)
        missing = overruns = 0
        refs = set()
        for block in meta.fileBlocks:
            refs.add(block.pazNum)
            size = sizes.get(block.pazNum)
            if size is None:
                missing += 1
            elif block.fileOffset + (block.zsize or block.size) > size:
                overruns += 1
        return {"version": meta_version(path), "sha256": sha256(path),
                "blocks": len(meta.fileBlocks), "refs": sorted(refs),
                "missing": missing, "overruns": overruns,
                "valid": bool(refs) and not missing and not overruns}


def _plain_path(path: pathlib.Path) -> None:
    if path.is_symlink() or (path.exists() and getattr(path.lstat(), "st_file_attributes", 0) & 0x400):
        raise ValueError(f"Linked/reparse recovery target is not supported: {path.name}")


def recovery_fingerprint(paz: pathlib.Path) -> str:
    """Bind approval to meta bytes, backup bytes and archive names/sizes/mtimes."""
    rows = []
    for path in sorted(paz.iterdir(), key=lambda p: p.name.lower()):
        if PAZ_FILE.match(path.name):
            _plain_path(path)
            if not path.is_file():
                raise ValueError(f"Archive is not a regular file: {path.name}")
            st = path.stat()
            rows.append([path.name, st.st_size, st.st_mtime_ns])
        elif path.name.casefold() in ("pad00000.meta", AIO_BACKUP_NAME.casefold(), AIO_BACKUP_INFO.casefold()) or path.name.casefold().endswith(".meta.backup"):
            _plain_path(path)
            rows.append([path.name, sha256(path), path.stat().st_mtime_ns])
    raw = json.dumps([str(paz.resolve()).casefold(), rows], separators=(",", ":"))
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def recovery_plan(paz: pathlib.Path, ice: IceDecipher) -> dict:
    paz = paz.resolve(strict=True)
    before = recovery_fingerprint(paz)
    try:
        current = inspect_recovery_meta(paz, paz / "pad00000.meta", ice)
    except (OSError, ValueError, struct.error) as exc:
        try:
            version = meta_version(paz / "pad00000.meta")
        except (OSError, struct.error):
            version = None
        current = {"version": version, "sha256": sha256(paz / "pad00000.meta"),
                   "blocks": 0, "refs": [], "missing": 0, "overruns": 0,
                   "valid": False, "error": str(exc)}
    backups = find_backups(paz)
    backup = None
    restore_reason = "No reference backup exists. Use the game launcher's repair first."
    if backups:
        source = backups[0]
        backup = {"name": source.name, "version": None, "valid": False}
        try:
            backup["version"] = meta_version(source)
            if backup["version"] != current["version"]:
                restore_reason = f"Backup client {backup['version']} differs from live client {current['version']}. Restore is blocked."
            else:
                backup.update(inspect_recovery_meta(paz, source, ice))
                if not backup["valid"]:
                    restore_reason = "The backup has missing archives, out-of-bounds blocks or no references."
                elif meta_is_injected(paz, set(backup["refs"])) or not contiguous_game_max(paz):
                    backup["valid"] = False
                    restore_reason = "The backup is not eligible as a vanilla reference by archive checks."
                else:
                    info = paz / AIO_BACKUP_INFO
                    if source.name.casefold() == AIO_BACKUP_NAME.casefold() and info.exists():
                        recorded = json.loads(info.read_text(encoding="utf-8-sig"))
                        if recorded.get("sha256") != backup["sha256"]:
                            raise ValueError("The AIO backup checksum differs from its recorded checksum.")
                    restore_reason = "Same-client backup passes archive checks. Restore replaces only pad00000.meta; archives and staging stay in place."
        except (OSError, ValueError, struct.error) as exc:
            backup["valid"] = False
            restore_reason = f"Backup cannot be used: {exc}"
    top = contiguous_game_max(paz)
    snapshot_ok = current["valid"] and bool(top) and not meta_is_injected(paz, set(current["refs"]))
    snapshot_reason = ("Current meta passes archive checks and references no archives above the contiguous game range. Confirm launcher patch/repair is complete; these checks do not prove vendor authenticity."
                       if snapshot_ok else "Current meta is invalid or references archives outside the contiguous game range. Finish launcher repair before creating a reference.")
    candidates = []
    if current["valid"]:
        # ponytail: conservative high-number rule; never infer archive ownership.
        ceiling = max(top, max(current["refs"]))
        candidates = [{"name": p.name, "bytes": p.stat().st_size}
                      for p in orphan_paz(paz, {ceiling}) if p.is_file()]
    if recovery_fingerprint(paz) != before:
        raise ValueError("PAZ changed while scanning. Refresh the recovery preview.")
    return {"schema": 1, "targetPaz": str(paz), "token": before,
            "scannedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "current": current, "backup": backup,
            "restore": {"allowed": bool(backup and backup["valid"]), "reason": restore_reason},
            "snapshot": {"allowed": snapshot_ok, "reason": snapshot_reason},
            "cleanup": {"allowed": bool(candidates), "reason": "Moves only the listed unreferenced high-numbered archives into BDO_AIO_RECOVERY. This is recoverable isolation, not disk-space reclamation.",
                        "files": candidates, "bytes": sum(p["bytes"] for p in candidates)}}


def assert_recovery_idle() -> None:
    if os.name != "nt":
        return
    host = pathlib.Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
    command = "if (Get-Process -Name 'BlackDesert*','BDOLauncher','PearlAbyssLauncher','PartCutGen','Meta Injector','Meta Patcher' -ErrorAction SilentlyContinue) { exit 3 }"
    result = subprocess.run([str(host), "-NoProfile", "-Command", command],
                            capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW, timeout=15)
    if result.returncode:
        raise ValueError("Close the game, launcher and patch tools before recovery.")


def _atomic_recovery_write(target: pathlib.Path, content: bytes) -> None:
    _plain_path(target)
    fd, name = tempfile.mkstemp(prefix=".bdo-recovery-", suffix=".tmp", dir=target.parent)
    tmp = pathlib.Path(name)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(tmp, target)
    finally:
        if tmp.exists():
            tmp.unlink()


def apply_recovery(paz: pathlib.Path, ice: IceDecipher, operation: str, token: str, confirmed: bool) -> dict:
    if not confirmed or operation not in ("restore", "snapshot", "cleanup"):
        raise ValueError("Recovery requires an explicit confirmed operation.")
    plan = recovery_plan(paz, ice)
    if not token or token != plan["token"]:
        raise ValueError("PAZ or its backups changed after preview. Refresh and review again.")
    if not plan[operation]["allowed"]:
        raise ValueError(plan[operation]["reason"])
    assert_recovery_idle()
    if recovery_fingerprint(paz) != token:
        raise ValueError("PAZ changed before recovery. Refresh and review again.")
    root = paz / "BDO_AIO_RECOVERY"
    _plain_path(root)
    retained = root / (datetime.datetime.now().strftime("%Y%m%d-%H%M%S-") + uuid.uuid4().hex[:8])
    retained.mkdir(parents=True)
    current = paz / "pad00000.meta"
    moved = []
    written = []
    originals = {}
    receipt = {"operation": operation, "state": "running", "changed": [], "retainedPath": str(retained), "previewToken": token}
    try:
        if operation == "restore":
            targets = [current]
        elif operation == "snapshot":
            targets = [paz / AIO_BACKUP_NAME, paz / AIO_BACKUP_INFO]
        else:
            targets = []
        for target in targets:
            originals[target] = target.read_bytes() if target.exists() else None
            if originals[target] is not None:
                _atomic_recovery_write(retained / target.name, originals[target])
        _atomic_recovery_write(retained / "receipt.json", json.dumps(receipt, indent=2).encode())
        if recovery_fingerprint(paz) != token:
            raise ValueError("PAZ changed while retaining originals. Nothing was applied.")
        if operation == "restore":
            content = (paz / plan["backup"]["name"]).read_bytes()
            if hashlib.sha256(content).hexdigest() != plan["backup"]["sha256"]:
                raise ValueError("Backup changed before restore. Nothing was applied.")
            _atomic_recovery_write(current, content)
            written.append((current, hashlib.sha256(content).hexdigest()))
            checked = inspect_recovery_meta(paz, current, ice)
            if not checked["valid"] or sha256(current) != plan["backup"]["sha256"]:
                raise ValueError("Restored meta failed verification.")
        elif operation == "snapshot":
            content = current.read_bytes()
            target = paz / AIO_BACKUP_NAME
            _atomic_recovery_write(target, content)
            written.append((target, hashlib.sha256(content).hexdigest()))
            info = {"source": current.name, "reason": "user-confirmed current-client reference",
                    "sha256": sha256(target), "bytes": len(content), "meta_version": plan["current"]["version"],
                    "paz_referenced": len(plan["current"]["refs"]), "paz_max": max(plan["current"]["refs"])}
            if info["sha256"] != plan["current"]["sha256"]:
                raise ValueError("Current meta changed during reference capture.")
            data = json.dumps(info, indent=2).encode()
            _atomic_recovery_write(paz / AIO_BACKUP_INFO, data)
            written.append((paz / AIO_BACKUP_INFO, hashlib.sha256(data).hexdigest()))
        else:
            for item in plan["cleanup"]["files"]:
                path = paz / item["name"]
                _plain_path(path)
                destination = retained / path.name
                # Same-volume rename; do not copy gigabytes or delete archives.
                path.rename(destination)
                moved.append((path, destination))
        receipt["changed"] = [p.name for p, _ in written] + [p.name for p, _ in moved]
        receipt["state"] = "completed"
        _atomic_recovery_write(retained / "receipt.json", json.dumps(receipt, indent=2).encode())
        return receipt
    except Exception as exc:
        rollback_errors = []
        for source, destination in reversed(moved):
            try:
                if source.exists():
                    raise ValueError(f"Cannot restore {source.name}: its original path is occupied.")
                destination.rename(source)
            except Exception as rollback_exc:
                rollback_errors.append(str(rollback_exc))
        for target, expected in reversed(written):
            try:
                if sha256(target) != expected:
                    raise ValueError(f"{target.name} changed again; not overwriting it during rollback.")
                if originals[target] is None:
                    target.unlink()
                else:
                    _atomic_recovery_write(target, originals[target])
            except Exception as rollback_exc:
                rollback_errors.append(str(rollback_exc))
        receipt.update(state="failed", error=str(exc), rollbackErrors=rollback_errors)
        _atomic_recovery_write(retained / "receipt.json", json.dumps(receipt, indent=2).encode())
        raise ValueError(f"Recovery stopped: {exc}. Retained files: {retained}. Rollback errors: {rollback_errors}") from exc


def main() -> int:
    ap = argparse.ArgumentParser(description="Back up / restore the live BDO meta")
    ap.add_argument("command", choices=["scan", "backup", "restore", "verify", "recovery-plan", "recover"])
    ap.add_argument("--operation", choices=["restore", "snapshot", "cleanup"])
    ap.add_argument("--preview-token", default="")
    ap.add_argument("--confirmed", action="store_true")
    ap.add_argument("--paz", required=True)
    ap.add_argument("--apply", action="store_true", help="restore: actually write (default is a dry run)")
    ap.add_argument("--keep-paz", action="store_true", help="restore: leave injected PAZ files on disk")
    ap.add_argument("--force", action="store_true", help="backup: overwrite an existing AIO snapshot")
    ap.add_argument("--expect-version", type=int, default=0,
                    help="verify: fail if the meta header no longer reports this client version")
    args = ap.parse_args()

    paz = pathlib.Path(args.paz)
    if not paz.is_dir():
        log(f"[FATAL] not a folder: {paz}")
        return 2
    dll = pathlib.Path(__file__).resolve().parent / "ice_decipher.dll"
    if not dll.is_file():
        log(f"[FATAL] missing {dll}")
        return 2
    ice = IceDecipher(dll)

    if args.command in ("recovery-plan", "recover"):
        try:
            result = (recovery_plan(paz, ice) if args.command == "recovery-plan" else
                      apply_recovery(paz, ice, args.operation, args.preview_token, args.confirmed))
            print(json.dumps(result))
            return 0
        except Exception as exc:
            print(json.dumps({"state": "failed", "error": str(exc)}))
            return 1

    if args.command == "scan":
        return cmd_scan(paz, ice)
    if args.command == "backup":
        return cmd_backup(paz, ice, args.force)
    if args.command == "verify":
        return cmd_verify(paz, ice, args.expect_version)
    return cmd_restore(paz, ice, not args.keep_paz, args.apply)


if __name__ == "__main__":
    sys.exit(main())
