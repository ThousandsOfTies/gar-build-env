from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CAPSULE = REPO_ROOT / "scripts" / "targets" / "frdm-imx91s"
OVERLAY = CAPSULE / "device-tree" / "imx91s-gar-servo-pet-i2c4-overlay.dtso"
PUBLIC_DTB_BUILDER = REPO_ROOT / "scripts" / "build-imx91s-dtb.sh"
PUBLIC_UUU_GENERATOR = REPO_ROOT / "scripts" / "generate-imx91s-uuu.sh"
CANONICAL_CONFIG = REPO_ROOT / "config" / "frdm-imx91s.env.example"


class FrdmImx91sCapsuleTests(unittest.TestCase):
    def test_controller_sources_are_grouped_in_the_target_capsule(self) -> None:
        expected = (
            CAPSULE / "package.sh",
            CAPSULE / "device-tree" / "build.sh",
            OVERLAY,
            CAPSULE / "provisioning" / "uuu" / "common.sh",
            CAPSULE / "provisioning" / "uuu" / "generate.sh",
            CAPSULE / "provisioning" / "uuu" / "generate-dtb-update.sh",
            CAPSULE / "provisioning" / "uuu" / "generate-layout-probe.sh",
            CAPSULE / "provisioning" / "uuu" / "stage.sh",
        )
        self.assertTrue(all(path.is_file() for path in expected))
        self.assertFalse(
            (REPO_ROOT / "hardware" / "devicetree" / "imx91s-i2c4-pca9685.dtso").exists()
        )
        for old_name in (
            "build-dtb.sh",
            "generate-uuu.sh",
            "generate-dtb-update.sh",
            "generate-layout-probe.sh",
            "stage-uuu.sh",
        ):
            self.assertFalse((CAPSULE / old_name).exists())

        wrapper_targets = {
            "build-imx91s-dtb.sh": "device-tree/build.sh",
            "generate-imx91s-uuu.sh": "provisioning/uuu/generate.sh",
            "generate-imx91s-dtb-update.sh": "provisioning/uuu/generate-dtb-update.sh",
            "generate-imx91s-layout-probe.sh": "provisioning/uuu/generate-layout-probe.sh",
            "stage-imx91s-uuu.sh": "provisioning/uuu/stage.sh",
        }
        for wrapper_name, target in wrapper_targets.items():
            wrapper = (REPO_ROOT / "scripts" / wrapper_name).read_text(encoding="utf-8")
            self.assertIn(f"targets/frdm-imx91s/{target}", wrapper)

    def test_uuu_compatibility_entrypoint_uses_canonical_product_defaults(self) -> None:
        environment = dict(os.environ)
        environment["GAR_IMX91S_UUU_CONFIG"] = str(CANONICAL_CONFIG)
        result = subprocess.run(
            (str(PUBLIC_UUU_GENERATOR), "--allow-unconfirmed", "--dry-run"),
            cwd=REPO_ROOT,
            env=environment,
            check=False,
            text=True,
            capture_output=True,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("DTB:             imx91-11x11-frdm-imx91s-gar-servo-pet.dtb", result.stdout)
        self.assertIn("RAM boot image:  flash_gar_servo_pet.bin", result.stdout)
        self.assertIn("NAND confirmed:  0", result.stdout)

    @unittest.skipUnless(
        all(shutil.which(tool) for tool in ("dtc", "fdtoverlay", "fdtget")),
        "device-tree-compiler tools are unavailable",
    )
    def test_public_builder_applies_capsule_owned_lpi2c4_overlay(self) -> None:
        base_source = """/dts-v1/;
/ {
    compatible = "fsl,imx91-11x11-frdm";
    regulator-exp-3v3 {};
    regulator-exp-5v {};
    soc@0 {
        bus@42000000 {
            i2c@42540000 {
                status = "disabled";
            };
        };
        bus@44000000 {
            pinctrl@443c0000 {};
        };
    };
};
"""
        with tempfile.TemporaryDirectory(prefix="gar-frdm-overlay-test.") as temporary:
            root = Path(temporary)
            base_dts = root / "base.dts"
            base_dtb = root / "base.dtb"
            merged = root / "merged.dtb"
            base_dts.write_text(base_source, encoding="utf-8")
            subprocess.run(
                ("dtc", "-I", "dts", "-O", "dtb", "-o", base_dtb, base_dts),
                check=True,
                capture_output=True,
                text=True,
            )
            environment = dict(os.environ)
            environment.pop("GAR_IMX91S_DT_OVERLAY", None)
            subprocess.run(
                (str(PUBLIC_DTB_BUILDER), "--base", base_dtb, "--output", merged),
                cwd=REPO_ROOT,
                env=environment,
                check=True,
                capture_output=True,
                text=True,
            )

            def fdtget(kind: str, node: str, property_name: str) -> str:
                result = subprocess.run(
                    ("fdtget", f"-t{kind}", merged, node, property_name),
                    check=True,
                    capture_output=True,
                    text=True,
                )
                return result.stdout.strip()

            i2c_node = "/soc@0/bus@42000000/i2c@42540000"
            pin_node = "/soc@0/bus@44000000/pinctrl@443c0000/lpi2c4-gar-servo-pet-grp"
            self.assertEqual("okay", fdtget("s", i2c_node, "status"))
            self.assertEqual("100000", fdtget("i", i2c_node, "clock-frequency"))
            self.assertEqual(
                "18 1c8 3fc 1 0 40000b9e 1c 1cc 3f8 1 0 40000b9e",
                fdtget("x", pin_node, "fsl,pins"),
            )
            for regulator in ("/regulator-exp-3v3", "/regulator-exp-5v"):
                subprocess.run(
                    ("fdtget", merged, regulator, "regulator-always-on"),
                    check=True,
                    capture_output=True,
                    text=True,
                )


if __name__ == "__main__":
    unittest.main()
