#!/usr/bin/env python3
"""Package a built Wokwi project as a GAR simulation-app artifact."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path
from uuid import uuid4


RUNTIME_FILES = (
    Path("diagram.json"),
    Path("wokwi.toml"),
    Path(".pio/build/m5stackc/firmware.bin"),
    Path(".pio/build/m5stackc/firmware.elf"),
)
BUILD_WORKSPACE_SUFFIX = (".gar", "build", "wokwi", "m5stackc")
ARTIFACT_ROOT_SUFFIX = ("artifacts", "from-codespace")


def reject_symlink_components(path: Path, label: str) -> None:
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current /= part
        if current.is_symlink():
            raise RuntimeError(f"{label} must not use a symlink: {current}")


def paths_overlap(first: Path, second: Path) -> bool:
    return (
        first == second or first.is_relative_to(second) or second.is_relative_to(first)
    )


def validate_output_layout(workspace: Path, artifact_root: Path) -> None:
    if workspace.parts[-len(BUILD_WORKSPACE_SUFFIX) :] != BUILD_WORKSPACE_SUFFIX:
        raise RuntimeError(
            "Wokwi build workspace must end with .gar/build/wokwi/m5stackc: "
            f"{workspace}"
        )
    if artifact_root.parts[-len(ARTIFACT_ROOT_SUFFIX) :] != ARTIFACT_ROOT_SUFFIX:
        raise RuntimeError(
            "Wokwi artifact root must end with artifacts/from-codespace: "
            f"{artifact_root}"
        )

    if paths_overlap(workspace, artifact_root):
        raise RuntimeError(
            f"Wokwi build workspace and artifact root must not overlap: "
            f"{workspace} and {artifact_root}"
        )

    workspace_repository = workspace.parents[len(BUILD_WORKSPACE_SUFFIX) - 1]
    artifact_repository = artifact_root.parents[len(ARTIFACT_ROOT_SUFFIX) - 1]
    if workspace_repository != artifact_repository:
        raise RuntimeError(
            "Wokwi build workspace and artifact root must belong to the same repository: "
            f"{workspace} and {artifact_root}"
        )
    if artifact_repository == Path(artifact_repository.anchor):
        raise RuntimeError(
            f"Wokwi output repository must not be the filesystem root: "
            f"{artifact_repository}"
        )

    reject_symlink_components(workspace, "Wokwi build workspace")
    reject_symlink_components(artifact_root, "Artifact root")


def validate_runtime_files(workspace: Path) -> None:
    if not workspace.is_dir():
        raise RuntimeError(f"Wokwi build workspace is not a directory: {workspace}")

    for relative_path in RUNTIME_FILES:
        current = workspace
        for part in relative_path.parts:
            current /= part
            if current.is_symlink():
                raise RuntimeError(
                    f"Wokwi runtime file must not use a symlink: {current}"
                )
        if not current.is_file():
            raise RuntimeError(f"Wokwi runtime file is missing: {current}")


def artifact_manifest() -> dict[str, object]:
    return {
        "name": "gar-vibe-remote-wokwi",
        "deploy": {
            "app": {
                "files": [
                    {
                        "src": "files/wokwi-m5stackc",
                        "dest": ".",
                    }
                ]
            }
        },
    }


def remove_directory(directory: Path) -> None:
    if not directory.exists():
        return
    if not directory.is_dir():
        raise RuntimeError(f"Generated path is not a directory: {directory}")

    removal_path = directory.parent / f".{directory.name}.remove-{uuid4().hex}"
    os.replace(directory, removal_path)
    shutil.rmtree(removal_path)


def reset_build_workspace(workspace: Path, artifact_root: Path) -> None:
    workspace = workspace.expanduser().absolute()
    artifact_root = artifact_root.expanduser().absolute()
    validate_output_layout(workspace, artifact_root)
    remove_directory(workspace)


def is_owned_wokwi_artifact(artifact_root: Path) -> bool:
    manifest_path = artifact_root / "artifact.json"
    try:
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    return payload == artifact_manifest()


def clean_wokwi_sim_app(workspace: Path, artifact_root: Path) -> None:
    workspace = workspace.expanduser().absolute()
    artifact_root = artifact_root.expanduser().absolute()
    validate_output_layout(workspace, artifact_root)
    remove_directory(workspace)
    if artifact_root.is_dir() and is_owned_wokwi_artifact(artifact_root):
        remove_directory(artifact_root)


def package_wokwi_sim_app(workspace: Path, artifact_root: Path) -> None:
    workspace = workspace.expanduser().absolute()
    artifact_root = artifact_root.expanduser().absolute()
    validate_output_layout(workspace, artifact_root)
    validate_runtime_files(workspace)

    if artifact_root.exists() and not artifact_root.is_dir():
        raise RuntimeError(f"Artifact root is not a directory: {artifact_root}")

    artifact_root.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=f".{artifact_root.name}.wokwi-", dir=artifact_root.parent
    ) as temporary_directory:
        staged_root = Path(temporary_directory) / "bundle"
        staged_workspace = staged_root / "files" / "wokwi-m5stackc"
        for relative_path in RUNTIME_FILES:
            destination = staged_workspace / relative_path
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(workspace / relative_path, destination)

        (staged_root / "artifact.json").write_text(
            json.dumps(artifact_manifest(), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

        backup_root: Path | None = None
        if artifact_root.exists():
            backup_root = artifact_root.parent / (
                f".{artifact_root.name}.backup-{uuid4().hex}"
            )
            os.replace(artifact_root, backup_root)
        try:
            os.replace(staged_root, artifact_root)
        except BaseException:
            if (
                backup_root is not None
                and backup_root.exists()
                and not artifact_root.exists()
            ):
                os.replace(backup_root, artifact_root)
            raise
        if backup_root is not None:
            shutil.rmtree(backup_root)


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[0] not in {"clean", "package", "reset-build"}:
        print(
            f"usage: {Path(sys.argv[0]).name} "
            "{clean|package|reset-build} WORKSPACE ARTIFACT_ROOT",
            file=sys.stderr,
        )
        return 2
    try:
        action = argv[0]
        workspace = Path(argv[1])
        artifact_root = Path(argv[2])
        if action == "clean":
            clean_wokwi_sim_app(workspace, artifact_root)
        elif action == "package":
            package_wokwi_sim_app(workspace, artifact_root)
        else:
            reset_build_workspace(workspace, artifact_root)
    except (OSError, RuntimeError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
