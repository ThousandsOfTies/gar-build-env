from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ArtifactManifestTests(unittest.TestCase):
    def test_extension_bundle_uses_the_standard_app_section(self) -> None:
        manifest = json.loads(
            (ROOT / "config/artifact-manifest.json").read_text(encoding="utf-8")
        )

        self.assertEqual({"app"}, set(manifest["deploy"]))
        self.assertEqual(
            [
                {
                    "src": "files/vibe-remote-extension",
                    "dest": "~/vibe-remote-extension",
                }
            ],
            manifest["deploy"]["app"]["files"],
        )

    def test_packager_adds_firmware_as_an_app_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "scripts").mkdir()
            (root / "config").mkdir()
            shutil.copy2(
                ROOT / "scripts/product-artifacts.sh",
                root / "scripts/product-artifacts.sh",
            )
            shutil.copy2(
                ROOT / "config/artifact-manifest.json",
                root / "config/artifact-manifest.json",
            )
            package = root / "sources/gar-vibe-ui/vibe-remote"
            for relative in ("dist", "scripts", "integrations"):
                directory = package / relative
                directory.mkdir(parents=True, exist_ok=True)
                (directory / "content.txt").write_text(relative, encoding="utf-8")
            for filename in ("package.json", "package-lock.json", "README.md"):
                (package / filename).write_text("{}\n", encoding="utf-8")
            firmware = package / "m5stickc-client/artifacts/20260819/firmware.bin"
            firmware.parent.mkdir(parents=True)
            firmware.write_bytes(b"firmware")

            result = subprocess.run(
                ["bash", str(root / "scripts/product-artifacts.sh")],
                cwd=root,
                env=os.environ.copy(),
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(0, result.returncode, result.stderr)
            artifact_root = root / "artifacts/from-codespace"
            manifest = json.loads(
                (artifact_root / "artifact.json").read_text(encoding="utf-8")
            )
            self.assertEqual(
                [
                    {
                        "src": "files/vibe-remote-extension",
                        "dest": "~/vibe-remote-extension",
                    },
                    {
                        "src": "files/m5stickc-firmware",
                        "dest": "~/m5stickc-firmware",
                    },
                ],
                manifest["deploy"]["app"]["files"],
            )
            self.assertEqual(
                b"firmware",
                (artifact_root / "files/m5stickc-firmware/firmware.bin").read_bytes(),
            )


if __name__ == "__main__":
    unittest.main()
