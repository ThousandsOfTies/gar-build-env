from __future__ import annotations

import ipaddress
import json
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class HardwareContractTests(unittest.TestCase):
    def test_requirements_and_raspberry_pi_binding_are_complete_and_neutral(self) -> None:
        hardware = REPOSITORY_ROOT / "hardware"
        requirements = json.loads((hardware / "requirements.json").read_text(encoding="utf-8"))
        binding = json.loads(
            (hardware / "bindings" / "raspberry-pi-5.json").read_text(encoding="utf-8")
        )

        self.assertEqual({"schema_version", "product", "requirements"}, set(requirements))
        self.assertEqual(1, requirements["schema_version"])
        self.assertEqual("gar-stream-tx", requirements["product"])
        by_id = {requirement["id"]: requirement for requirement in requirements["requirements"]}
        self.assertEqual(
            {"camera", "display", "lcd-dc", "lcd-rst", "encoder-a", "encoder-b", "encoder-switch", "network"},
            set(by_id),
        )
        self.assertEqual(30, by_id["camera"]["min_fps"])
        self.assertEqual(10000000, by_id["display"]["min_speed_hz"])
        self.assertEqual("usb-uvc-camera", by_id["camera"]["component"])
        self.assertEqual("ili9341", by_id["display"]["component"])
        self.assertEqual(
            {"ky-040"},
            {by_id[name]["component"] for name in ("encoder-a", "encoder-b", "encoder-switch")},
        )
        self.assertTrue(all(item["required_drivers"] for item in by_id.values()))

        self.assertEqual(1, binding["schema_version"])
        self.assertEqual("gar-stream-tx", binding["product"])
        self.assertEqual("raspberry-pi-5", binding["target_id"])
        self.assertEqual(set(by_id), {item["requirement"] for item in binding["mappings"]})
        lines = {item["requirement"]: item["line"] for item in binding["mappings"] if "line" in item}
        self.assertEqual(
            {"lcd-dc": 23, "lcd-rst": 24, "encoder-a": 17, "encoder-b": 27, "encoder-switch": 22},
            lines,
        )
        self.assertEqual(["19:MOSI", "21:MISO", "23:SCLK", "24:CS0"], binding["mappings"][1]["physical_pins"])
        self.assertEqual("spi0", binding["mappings"][1]["pinmux"])

        def assert_no_machine_ip(value: object) -> None:
            if isinstance(value, str):
                with self.assertRaises(ValueError):
                    ipaddress.ip_address(value)
            elif isinstance(value, dict):
                for nested in value.values():
                    assert_no_machine_ip(nested)
            elif isinstance(value, list):
                for nested in value:
                    assert_no_machine_ip(nested)

        assert_no_machine_ip(binding)


if __name__ == "__main__":
    unittest.main()
