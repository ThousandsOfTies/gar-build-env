from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ProductHardwareOwnershipTests(unittest.TestCase):
    def test_vibe_protocol_probe_lives_with_the_product(self) -> None:
        probe = (
            ROOT / "hardware" / "probes" / "spp-jsonl" / "bin" / "gar-spp-jsonl-probe"
        )

        self.assertTrue(probe.is_file())
        self.assertIn("Vibe Remote", probe.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
