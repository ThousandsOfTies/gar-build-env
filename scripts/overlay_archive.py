#!/usr/bin/env python3
"""Safely extract and deterministically create Product rootfs overlays."""

from __future__ import annotations

import argparse
import os
import shutil
import stat
import tarfile
import tempfile
from pathlib import Path, PurePosixPath


class OverlayArchiveError(RuntimeError):
    pass


def _member_path(name: str) -> Path:
    pure = PurePosixPath(name)
    if pure.is_absolute() or ".." in pure.parts:
        raise OverlayArchiveError(f"unsafe archive member path: {name!r}")
    parts = tuple(part for part in pure.parts if part not in ("", "."))
    return Path(*parts)


def _contained(root: Path, candidate: Path) -> bool:
    try:
        candidate.relative_to(root)
    except ValueError:
        return False
    return True


def extract_overlay(archive_path: Path, output_dir: Path) -> None:
    if output_dir.is_symlink():
        raise OverlayArchiveError(f"output directory must not be a symlink: {output_dir}")
    output_dir.mkdir(parents=True, exist_ok=True)
    if any(output_dir.iterdir()):
        raise OverlayArchiveError(f"output directory must be empty: {output_dir}")
    root = output_dir.resolve()

    with tarfile.open(archive_path, mode="r:bz2") as archive:
        validated: list[tuple[tarfile.TarInfo, Path]] = []
        seen: set[Path] = set()
        for member in archive.getmembers():
            relative = _member_path(member.name)
            if relative in seen:
                raise OverlayArchiveError(
                    f"duplicate archive member path: {member.name!r}"
                )
            seen.add(relative)
            if member.issym() or member.islnk():
                raise OverlayArchiveError(
                    f"links are not permitted in Product overlays: {member.name!r}"
                )
            if not (member.isdir() or member.isfile()):
                raise OverlayArchiveError(
                    f"special archive member is not permitted: {member.name!r}"
                )
            destination = (root / relative).resolve(strict=False)
            if not _contained(root, destination):
                raise OverlayArchiveError(
                    f"archive member escapes output directory: {member.name!r}"
                )
            validated.append((member, relative))

        directories: list[tuple[Path, int]] = []
        for member, relative in validated:
            destination = root / relative
            if member.isdir():
                destination.mkdir(parents=True, exist_ok=True, mode=0o700)
                directories.append((destination, member.mode & 0o777))
                continue

            destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            parent = destination.parent.resolve()
            if not _contained(root, parent):
                raise OverlayArchiveError(
                    f"archive parent escapes output directory: {member.name!r}"
                )
            source = archive.extractfile(member)
            if source is None:
                raise OverlayArchiveError(f"cannot read archive member: {member.name!r}")
            flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
            if hasattr(os, "O_NOFOLLOW"):
                flags |= os.O_NOFOLLOW
            descriptor = os.open(destination, flags, member.mode & 0o777)
            with source, os.fdopen(descriptor, "wb") as output:
                shutil.copyfileobj(source, output)
            os.chmod(destination, member.mode & 0o777, follow_symlinks=False)

        for directory, mode in sorted(
            directories, key=lambda item: len(item[0].parts), reverse=True
        ):
            os.chmod(directory, mode, follow_symlinks=False)


def _tar_info(path: Path, archive_name: str) -> tarfile.TarInfo:
    metadata = path.stat(follow_symlinks=False)
    info = tarfile.TarInfo(archive_name)
    info.uid = 0
    info.gid = 0
    info.uname = ""
    info.gname = ""
    info.mtime = 0
    info.mode = stat.S_IMODE(metadata.st_mode)
    if stat.S_ISDIR(metadata.st_mode):
        info.type = tarfile.DIRTYPE
        info.size = 0
    elif stat.S_ISREG(metadata.st_mode):
        info.type = tarfile.REGTYPE
        info.size = metadata.st_size
    else:
        raise OverlayArchiveError(f"unsupported overlay entry: {path}")
    return info


def create_overlay(input_dir: Path, archive_path: Path) -> None:
    if input_dir.is_symlink() or not input_dir.is_dir():
        raise OverlayArchiveError(f"overlay input must be a real directory: {input_dir}")
    root = input_dir.resolve()
    entries = [root, *sorted(root.rglob("*"), key=lambda path: path.relative_to(root).as_posix())]
    for entry in entries:
        if entry.is_symlink():
            raise OverlayArchiveError(f"links are not permitted in Product overlays: {entry}")
        _tar_info(entry, ".")

    archive_path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{archive_path.name}.", dir=archive_path.parent
    )
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        with tarfile.open(
            temporary, mode="w:bz2", format=tarfile.GNU_FORMAT, compresslevel=9
        ) as archive:
            root_info = _tar_info(root, ".")
            archive.addfile(root_info)
            for entry in entries[1:]:
                relative = entry.relative_to(root).as_posix()
                info = _tar_info(entry, f"./{relative}")
                if info.isfile():
                    with entry.open("rb") as source:
                        archive.addfile(info, source)
                else:
                    archive.addfile(info)
        os.chmod(temporary, 0o644)
        os.replace(temporary, archive_path)
    finally:
        temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("extract", "create"):
        subparser = subparsers.add_parser(command)
        subparser.add_argument("--input", type=Path, required=True)
        subparser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()

    try:
        if arguments.command == "extract":
            extract_overlay(arguments.input, arguments.output)
        else:
            create_overlay(arguments.input, arguments.output)
    except (OSError, tarfile.TarError, OverlayArchiveError) as error:
        parser.exit(1, f"overlay archive: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
