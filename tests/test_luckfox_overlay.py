from __future__ import annotations

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CAPSULE = REPO_ROOT / "scripts" / "targets" / "luckfox-rk3506"
OVERLAY = CAPSULE / "rk3506-gar-servo-pet-i2c1-overlay.dts"


class LuckfoxOverlayTests(unittest.TestCase):
    def test_target_configuration_is_guarded_and_product_scoped(self) -> None:
        configure = (CAPSULE / "configure-target").read_text(encoding="utf-8")

        self.assertIn('model" = "Luckfox Lyra Plus', configure)
        self.assertIn("boot_device=/dev/mtdblock1", configure)
        self.assertIn("luckfox-lyra-plus-boot-original.img", configure)
        self.assertIn("Device Tree write-back verification failed", configure)
        self.assertIn("exit 10", configure)
        self.assertNotIn("gar-stream", configure.lower())

    @unittest.skipUnless(
        all(shutil.which(tool) for tool in ("dtc", "fdtoverlay", "fdtget")),
        "device-tree-compiler tools are unavailable",
    )
    def test_overlay_applies_i2c1_and_both_rm_io_pins(self) -> None:
        base_source = """/dts-v1/;
/ {
    compatible = "luckfox,lyra-plus", "rockchip,rk3506";
    #address-cells = <1>;
    #size-cells = <1>;
    pinctrl {};
    i2c@ff050000 {
        compatible = "rockchip,rk3506-i2c";
        reg = <0xff050000 0x1000>;
        status = "disabled";
    };
};
"""
        with tempfile.TemporaryDirectory(prefix="gar-lyra-overlay-test.") as temporary:
            root = Path(temporary)
            base_dts = root / "base.dts"
            base_dtb = root / "base.dtb"
            overlay_dtb = root / "overlay.dtbo"
            merged = root / "merged.dtb"
            base_dts.write_text(base_source, encoding="utf-8")
            subprocess.run(
                ("dtc", "-I", "dts", "-O", "dtb", "-o", base_dtb, base_dts),
                check=True,
                capture_output=True,
                text=True,
            )
            subprocess.run(
                ("dtc", "-@", "-I", "dts", "-O", "dtb", "-o", overlay_dtb, OVERLAY),
                check=True,
                capture_output=True,
                text=True,
            )
            subprocess.run(
                ("fdtoverlay", "-i", base_dtb, "-o", merged, overlay_dtb),
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

            self.assertEqual("okay", fdtget("s", "/i2c@ff050000", "status"))
            self.assertEqual("100000", fdtget("i", "/i2c@ff050000", "clock-frequency"))
            self.assertEqual(
                ["0", "10", "32"],
                fdtget(
                    "i",
                    "/pinctrl/gar-servo-pet-i2c1-pins/scl",
                    "rockchip,pins",
                ).split()[:3],
            )
            self.assertEqual(
                ["0", "11", "33"],
                fdtget(
                    "i",
                    "/pinctrl/gar-servo-pet-i2c1-pins/sda",
                    "rockchip,pins",
                ).split()[:3],
            )
            self.assertEqual(
                2,
                len(fdtget("i", "/i2c@ff050000", "pinctrl-0").split()),
            )


if __name__ == "__main__":
    unittest.main()
