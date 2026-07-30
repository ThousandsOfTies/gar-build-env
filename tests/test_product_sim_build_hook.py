from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class ProductSimBuildHookTests(unittest.TestCase):
    def _create_product_fixture(self, root: Path) -> Path:
        scripts = root / "scripts"
        scripts.mkdir()
        for name in ("product-sim-build.sh", "package_wokwi_sim_app.py"):
            shutil.copy2(REPOSITORY_ROOT / "scripts" / name, scripts / name)

        (root / "sources" / "gar-tools").mkdir(parents=True)
        client = root / "sources" / "gar-vibe-ui" / "vibe-remote" / "m5stickc-client"
        client.mkdir(parents=True)
        (client / "Makefile").write_text(
            """\
wokwi-build:
\tmkdir -p "$(WOKWI_WORKSPACE)/.pio/build/m5stackc"
\tprintf '{}\\n' > "$(WOKWI_WORKSPACE)/diagram.json"
\tprintf '[wokwi]\\n' > "$(WOKWI_WORKSPACE)/wokwi.toml"
\tprintf 'firmware' > "$(WOKWI_WORKSPACE)/.pio/build/m5stackc/firmware.bin"
\tprintf 'elf' > "$(WOKWI_WORKSPACE)/.pio/build/m5stackc/firmware.elf"
""",
            encoding="utf-8",
        )
        return scripts / "product-sim-build.sh"

    def _run_hook(
        self,
        hook: Path,
        *arguments: str,
        environment: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(hook), *arguments],
            cwd=hook.parents[1],
            env={**os.environ, **(environment or {})},
            text=True,
            capture_output=True,
            check=False,
        )

    def test_build_packages_deployable_app_and_clean_removes_its_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            hook = self._create_product_fixture(root)

            build = self._run_hook(hook)

            self.assertEqual(0, build.returncode, build.stderr)
            artifact_root = root / "artifacts" / "from-codespace"
            manifest = json.loads(
                (artifact_root / "artifact.json").read_text(encoding="utf-8")
            )
            self.assertEqual(
                [{"src": "files/wokwi-m5stackc", "dest": "."}],
                manifest["deploy"]["app"]["files"],
            )
            firmware = (
                artifact_root
                / "files"
                / "wokwi-m5stackc"
                / ".pio"
                / "build"
                / "m5stackc"
                / "firmware.bin"
            )
            self.assertEqual(b"firmware", firmware.read_bytes())

            clean = self._run_hook(hook, "clean")

            self.assertEqual(0, clean.returncode, clean.stderr)
            self.assertFalse(artifact_root.exists())
            self.assertFalse((root / ".gar" / "build" / "wokwi" / "m5stackc").exists())

    def test_explicit_tools_directory_overrides_product_defaults(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            hook = self._create_product_fixture(root)
            config = root / "config"
            config.mkdir()
            (config / "product.env").write_text(
                "export GAR_TOOLS_DIR=sources/missing-tools\n",
                encoding="utf-8",
            )

            build = self._run_hook(
                hook,
                environment={"GAR_TOOLS_DIR": "sources/gar-tools"},
            )

            self.assertEqual(0, build.returncode, build.stderr)


if __name__ == "__main__":
    unittest.main()
