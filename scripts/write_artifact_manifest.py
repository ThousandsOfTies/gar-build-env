#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: write_artifact_manifest.py ARTIFACT_ROOT", file=sys.stderr)
        return 2

    artifact_root = Path(argv[1])
    payload = {
        "name": "gar-poc-bundle",
        "deploy": {
            "app": {
                "files": [
                    {
                        "src": "files/sensor_demo",
                        "dest": "~/sensor_demo",
                        "mode": "0755",
                    }
                ]
            },
            "sim_env": {
                "files": [
                    {
                        "src": "files/cuse_i2c",
                        "dest": "~/cuse_i2c",
                        "mode": "0755",
                    },
                    {
                        "src": "files/cuse_spi",
                        "dest": "~/cuse_spi",
                        "mode": "0755",
                    },
                    {
                        "src": "files/web-bridge",
                        "dest": "~/web-bridge",
                    },
                ]
            },
        },
    }
    artifact_root.mkdir(parents=True, exist_ok=True)
    (artifact_root / "artifact.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
