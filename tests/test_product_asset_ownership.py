from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ProductAssetOwnershipTests(unittest.TestCase):
    def test_rv1106_product_logic_lives_with_tx(self) -> None:
        expected = (
            "hardware/targets/luckfox-rv1106/gpio.csv",
            "tools/rv1106/app-template/src/main.cpp",
            "tools/rv1106/runtime/bin/gar-luckfox-sim-isp-engine",
            "tools/rv1106/runtime/bin/gar-luckfox-sim-rotary-ui",
            "tools/rv1106/scripts/luckfox_push_rtsp.sh",
            "docs/rv1106/05_RV1106_FEATURE_MENU.md",
        )

        for relative_path in expected:
            with self.subTest(path=relative_path):
                self.assertTrue((ROOT / relative_path).is_file())

    def test_camera_panel_component_is_packaged_by_the_product(self) -> None:
        panel = (ROOT / "panel" / "index.html").read_text(encoding="utf-8")

        self.assertIn("./components/video-transmitter.js", panel)
        self.assertTrue(
            (ROOT / "panel" / "components" / "video-transmitter.js").is_file()
        )


if __name__ == "__main__":
    unittest.main()
