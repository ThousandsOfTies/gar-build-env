#!/usr/bin/env bash
# Build and package the real M5StickC firmware for `gar target build`.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
artifact_root="${repo_root}/artifacts/from-codespace"

VIBE_BUILD_FIRMWARE=1 make -C "${repo_root}" artifacts

firmware_dir="${artifact_root}/files/m5stickc-firmware"
if [[ ! -d "${firmware_dir}" ]]; then
  echo "target firmware artifact was not generated: ${firmware_dir}" >&2
  exit 1
fi

python3 - "${artifact_root}/artifact.json" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
payload = json.loads(manifest_path.read_text(encoding="utf-8"))
payload.setdefault("deploy", {})["app"] = {
    "files": [
        {
            "src": "files/m5stickc-firmware",
            "dest": "firmware",
        }
    ]
}
manifest_path.write_text(
    json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

echo "Target artifact: ${artifact_root}"
