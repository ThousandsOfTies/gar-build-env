from __future__ import annotations

import json
import os
import subprocess
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
COMPOSER = REPO_ROOT / "scripts" / "package_target.py"
PUBLIC_ENTRYPOINT = REPO_ROOT / "scripts" / "package-target.sh"
COMPATIBILITY_ENTRYPOINT = REPO_ROOT / "scripts" / "product-target-build.sh"


class DeploymentProfileTests(unittest.TestCase):
    def clean_environment(self) -> dict[str, str]:
        environment = dict(os.environ)
        environment.pop("GAR_DEPLOYMENT", None)
        environment.pop("GAR_TARGET", None)
        return environment

    def run_command(
        self,
        command: list[str],
        *,
        expected: int = 0,
        environment: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            command,
            cwd=REPO_ROOT,
            env=environment if environment is not None else self.clean_environment(),
            check=False,
            text=True,
            capture_output=True,
        )
        self.assertEqual(expected, result.returncode, result.stderr)
        return result

    def test_frdm_deployment_composes_application_target_and_binding(self) -> None:
        result = self.run_command(
            [
                sys.executable,
                str(COMPOSER),
                "--deployment",
                "frdm-imx91s",
                "--describe",
            ]
        )
        description = json.loads(result.stdout)
        self.assertEqual("frdm-imx91s", description["deployment"])
        self.assertEqual("gar-servo-pet", description["product"])
        self.assertEqual("gar-servo-pet", description["application"])
        self.assertEqual("frdm-imx91s", description["target"])
        self.assertEqual("uuu-image-and-app", description["artifact_kind"])
        self.assertEqual(
            {
                "i2c": "hardware/i2c.csv",
                "connections": "hardware/connections.csv",
                "servo_calibration": "hardware/servo-calibration.csv",
            },
            description["application_runtime"]["configuration"],
        )
        self.assertEqual(
            "sources/gar-servo-pet/app.json",
            description["paths"]["application"],
        )
        self.assertEqual(
            "hardware/bindings/frdm-imx91s.json",
            description["paths"]["binding"],
        )
        self.assertEqual(
            "scripts/targets/frdm-imx91s/package.sh",
            description["paths"]["packager"],
        )
        self.assertEqual(
            "config/frdm-imx91s.env.example",
            description["paths"]["target_defaults"],
        )
        self.assertEqual(
            "config/frdm-imx91s.env",
            description["paths"]["target_local"],
        )

    def test_lyra_deployment_composes_the_same_application_with_ssh_target(self) -> None:
        result = self.run_command(
            [
                sys.executable,
                str(COMPOSER),
                "--deployment",
                "luckfox-rk3506",
                "--describe",
            ]
        )
        description = json.loads(result.stdout)
        self.assertEqual("luckfox-rk3506", description["deployment"])
        self.assertEqual("gar-servo-pet", description["product"])
        self.assertEqual("gar-servo-pet", description["application"])
        self.assertEqual("luckfox-rk3506", description["target"])
        self.assertEqual("ssh-app", description["artifact_kind"])
        self.assertEqual(
            "hardware/bindings/luckfox-rk3506.json",
            description["paths"]["binding"],
        )
        self.assertEqual(
            "hardware/profiles/luckfox-rk3506/i2c.csv",
            description["paths"]["i2c"],
        )
        self.assertEqual(
            "scripts/targets/luckfox-rk3506/package.sh",
            description["paths"]["packager"],
        )

    def test_public_and_compatibility_entrypoints_describe_same_deployment(self) -> None:
        commands = (
            [str(PUBLIC_ENTRYPOINT), "--deployment", "frdm-imx91s", "--describe"],
            [str(COMPATIBILITY_ENTRYPOINT), "--describe"],
        )
        descriptions = [json.loads(self.run_command(command).stdout) for command in commands]
        self.assertEqual(descriptions[0], descriptions[1])

    def test_explicit_target_cannot_drift_from_deployment(self) -> None:
        environment = self.clean_environment()
        environment["GAR_TARGET"] = "luckfox-rk3506"
        result = self.run_command(
            [
                sys.executable,
                str(COMPOSER),
                "--deployment",
                "frdm-imx91s",
                "--describe",
            ],
            expected=2,
            environment=environment,
        )
        self.assertIn("GAR_TARGET does not match", result.stderr)

    def test_legacy_i2c_file_mirrors_the_nxp_runtime_profile(self) -> None:
        legacy = REPO_ROOT / "hardware" / "i2c.csv"
        nxp_profile = REPO_ROOT / "hardware" / "profiles" / "frdm-imx91s" / "i2c.csv"
        self.assertEqual(legacy.read_bytes(), nxp_profile.read_bytes())

    def test_nxp_binding_keeps_the_verified_header_contract(self) -> None:
        binding_path = REPO_ROOT / "hardware" / "bindings" / "frdm-imx91s.json"
        binding = json.loads(binding_path.read_text(encoding="utf-8"))
        interface = binding["interfaces"][0]
        self.assertEqual("LPI2C4", interface["controller"])
        self.assertEqual(3, interface["bus"])
        self.assertEqual("/dev/i2c-3", interface["device"])
        self.assertEqual("0x40", interface["address"])
        self.assertEqual(100_000, interface["frequency_hz"])
        self.assertEqual(3.3, interface["logic_voltage_v"])
        self.assertEqual({"SDA": "3", "SCL": "5"}, interface["pins"])

    def test_lyra_binding_keeps_the_official_i2c1_header_contract(self) -> None:
        binding_path = REPO_ROOT / "hardware" / "bindings" / "luckfox-rk3506.json"
        binding = json.loads(binding_path.read_text(encoding="utf-8"))
        interface = binding["interfaces"][0]
        self.assertEqual("I2C1", interface["controller"])
        self.assertEqual(1, interface["bus"])
        self.assertEqual("/dev/i2c-1", interface["device"])
        self.assertEqual("0x40", interface["address"])
        self.assertEqual(100_000, interface["frequency_hz"])
        self.assertEqual(3.3, interface["logic_voltage_v"])
        self.assertEqual(
            {"SDA": "17:RM_IO11", "SCL": "19:RM_IO10"},
            interface["pins"],
        )


if __name__ == "__main__":
    unittest.main()
