from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPOSITORY_ROOT / "scripts"))

from package_wokwi_sim_app import (  # noqa: E402
    RUNTIME_FILES,
    clean_wokwi_sim_app,
    package_wokwi_sim_app,
)


class PackageWokwiSimAppTests(unittest.TestCase):
    def _output_paths(self, repository: Path) -> tuple[Path, Path]:
        return (
            repository / ".gar" / "build" / "wokwi" / "m5stackc",
            repository / "artifacts" / "from-codespace",
        )

    def _write_runtime_files(self, workspace: Path) -> None:
        for relative_path in RUNTIME_FILES:
            source = workspace / relative_path
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_text(relative_path.as_posix(), encoding="utf-8")

    def test_packages_only_files_needed_by_the_runtime(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            workspace, artifact_root = self._output_paths(root)
            self._write_runtime_files(workspace)
            (workspace / "button.test.yaml").write_text("stale", encoding="utf-8")

            package_wokwi_sim_app(workspace, artifact_root)

            packaged_workspace = artifact_root / "files" / "wokwi-m5stackc"
            for relative_path in RUNTIME_FILES:
                self.assertTrue((packaged_workspace / relative_path).is_file())
            self.assertFalse((packaged_workspace / "button.test.yaml").exists())
            manifest = json.loads(
                (artifact_root / "artifact.json").read_text(encoding="utf-8")
            )
            self.assertEqual(
                [{"src": "files/wokwi-m5stackc", "dest": "."}],
                manifest["deploy"]["app"]["files"],
            )

    def test_missing_runtime_file_preserves_previous_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            workspace, artifact_root = self._output_paths(root)
            workspace.mkdir(parents=True)
            artifact_root.mkdir(parents=True)
            previous_file = artifact_root / "previous"
            previous_file.write_text("keep", encoding="utf-8")

            with self.assertRaisesRegex(RuntimeError, "runtime file is missing"):
                package_wokwi_sim_app(workspace, artifact_root)

            self.assertEqual("keep", previous_file.read_text(encoding="utf-8"))

    def test_rejects_symlinked_runtime_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            workspace, artifact_root = self._output_paths(root)
            self._write_runtime_files(workspace)
            firmware = workspace / RUNTIME_FILES[-2]
            outside = root / "outside.bin"
            outside.write_text("outside", encoding="utf-8")
            firmware.unlink()
            firmware.symlink_to(outside)

            with self.assertRaisesRegex(RuntimeError, "must not use a symlink"):
                package_wokwi_sim_app(workspace, artifact_root)

    def test_rejects_nonstandard_or_overlapping_artifact_root(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            workspace, artifact_root = self._output_paths(root)
            self._write_runtime_files(workspace)

            with self.assertRaisesRegex(RuntimeError, "must end with"):
                package_wokwi_sim_app(workspace, root / "artifact")

            overlapping_root = workspace / "artifacts" / "from-codespace"
            with self.assertRaisesRegex(RuntimeError, "must not overlap"):
                package_wokwi_sim_app(workspace, overlapping_root)

            with self.assertRaisesRegex(RuntimeError, "build workspace must end with"):
                package_wokwi_sim_app(Path("/"), artifact_root)

            with self.assertRaisesRegex(
                RuntimeError, "must not be the filesystem root"
            ):
                package_wokwi_sim_app(
                    Path("/.gar/build/wokwi/m5stackc"),
                    Path("/artifacts/from-codespace"),
                )

    def test_rejects_artifact_root_with_intermediate_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            repository = root / "repository"
            workspace, artifact_root = self._output_paths(repository)
            self._write_runtime_files(workspace)
            real_artifacts = root / "real-artifacts"
            real_artifacts.mkdir()
            (repository / "artifacts").symlink_to(
                real_artifacts, target_is_directory=True
            )

            with self.assertRaisesRegex(RuntimeError, "must not use a symlink"):
                package_wokwi_sim_app(workspace, artifact_root)

            self.assertEqual([], list(real_artifacts.iterdir()))

    def test_restores_previous_artifact_when_staged_exchange_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            workspace, artifact_root = self._output_paths(root)
            self._write_runtime_files(workspace)
            artifact_root.mkdir(parents=True)
            previous_file = artifact_root / "previous"
            previous_file.write_text("keep", encoding="utf-8")
            real_replace = os.replace

            def fail_staged_exchange(
                source: str | Path, destination: str | Path
            ) -> None:
                if Path(source).name == "bundle" and Path(destination) == artifact_root:
                    raise OSError("simulated exchange failure")
                real_replace(source, destination)

            with mock.patch(
                "package_wokwi_sim_app.os.replace", side_effect=fail_staged_exchange
            ):
                with self.assertRaisesRegex(OSError, "simulated exchange failure"):
                    package_wokwi_sim_app(workspace, artifact_root)

            self.assertEqual("keep", previous_file.read_text(encoding="utf-8"))

    def test_clean_removes_owned_build_and_artifact_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            workspace, artifact_root = self._output_paths(root)
            self._write_runtime_files(workspace)
            package_wokwi_sim_app(workspace, artifact_root)

            clean_wokwi_sim_app(workspace, artifact_root)

            self.assertFalse(workspace.exists())
            self.assertFalse(artifact_root.exists())

    def test_clean_preserves_artifact_output_owned_by_another_hook(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            workspace, artifact_root = self._output_paths(root)
            self._write_runtime_files(workspace)
            artifact_root.mkdir(parents=True)
            manifest = artifact_root / "artifact.json"
            manifest.write_text('{"name": "another-hook"}\n', encoding="utf-8")

            clean_wokwi_sim_app(workspace, artifact_root)

            self.assertFalse(workspace.exists())
            self.assertEqual(
                {"name": "another-hook"},
                json.loads(manifest.read_text(encoding="utf-8")),
            )


if __name__ == "__main__":
    unittest.main()
