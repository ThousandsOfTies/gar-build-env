from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class DeploymentProfileTests(unittest.TestCase):
    def test_default_deployment_is_composable(self) -> None:
        result = subprocess.run(
            [str(ROOT / "scripts/product-target-build.sh"), "--describe"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        description = json.loads(result.stdout)
        self.assertEqual("raspberry-pi-5", description["deployment"])
        self.assertEqual("gar-adhoc-app", description["application"])
        self.assertEqual("planned", description["status"])

    def test_planned_deployment_cannot_be_packaged(self) -> None:
        result = subprocess.run(
            [str(ROOT / "scripts/package-target.sh")],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(3, result.returncode)
        self.assertIn("planned", result.stderr)


if __name__ == "__main__":
    unittest.main()
