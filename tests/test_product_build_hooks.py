from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class ProductBuildHookTests(unittest.TestCase):
    def test_network_pipeline_forces_rtp_jpeg_compatible_format(self) -> None:
        source = (REPOSITORY_ROOT / "sources/gar-stream-tx/camera_tx.py").read_text(
            encoding="utf-8"
        )

        self.assertIn('"! videoconvert ! video/x-raw,format=I420 "', source)

    def test_sim_service_uses_gar_managed_system_environment(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            (root / "scripts").mkdir()
            shutil.copy2(
                REPOSITORY_ROOT / "scripts" / "product-sim-build.sh", root / "scripts"
            )
            (root / "sources/gar-stream-tx").mkdir(parents=True)
            (root / "sources/gar-tools/targets/linux-device/runtime").mkdir(
                parents=True
            )
            (root / "panel").mkdir()
            (root / "sources/gar-stream-tx/camera_tx.py").touch()
            (root / "sources/gar-stream-tx/requirements.txt").touch()

            result = subprocess.run(
                ["bash", str(root / "scripts/product-sim-build.sh")],
                cwd=root,
                text=True,
                capture_output=True,
                env={**os.environ, "GAR_STREAM_DISCOVERY_PEERS": "192.0.2.10"},
                check=False,
            )

            self.assertEqual(0, result.returncode, result.stderr)
            service = (
                root / "artifacts/from-codespace/files/gar-sim-app.service"
            ).read_text(encoding="utf-8")
            environment_file = "EnvironmentFile=-/etc/gar/system/gar-stream-tx.env"
            self.assertIn(environment_file, service)
            self.assertGreater(
                service.index(environment_file),
                service.index("Environment=GAR_STREAM_DISCOVERY_PORT=5601"),
                "the GAR topology port must override the static fallback",
            )
            self.assertNotIn("GAR_STREAM_DISCOVERY_PEERS", service)
            self.assertNotIn("/etc/gar/gar-stream-tx.env", service)
            self.assertNotIn("192.0.2.10", service)
            self.assertIn(
                "Environment=GAR_STREAM_METRICS_PATH=/run/gar/metrics/gar-stream-tx.json",
                service,
            )
            self.assertIn("Environment=GAR_CAMERA_TEST_PATTERN=1", service)
            manifest = json.loads(
                (root / "artifacts/from-codespace/artifact.json").read_text(
                    encoding="utf-8"
                )
            )
            files = manifest["deploy"]["app"]["files"]
            self.assertFalse(
                any(item["dest"] == "/etc/gar/gar-stream-tx.env" for item in files)
            )


if __name__ == "__main__":
    unittest.main()
