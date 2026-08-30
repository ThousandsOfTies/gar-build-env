#!/usr/bin/env bash
# Build the physical-device artifact for `gar target build`.
#
# The application Python modules are deliberately the same ones used by the
# Linux simulation. The product artifact owns only its application directory;
# the selected Target recipe owns root-level OS integration and boot services.
# Simulation stubs and the Web Panel are never included here.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi

app_dir="${repo_root}/${GAR_SIM_APP_DIR:-sources/gar-stream-tx}"
artifact_root="${repo_root}/${GAR_TARGET_ARTIFACT_ROOT:-artifacts/from-codespace}"
artifact_dir="${artifact_root}/files/gar-stream-tx"
target="${GAR_TARGET:-raspberry-pi-5}"
deploy_dest="${GAR_TARGET_ARTIFACT_DEST:-/opt/gar/apps/gar-stream-tx}"

if [[ "$#" -gt 1 || ( "$#" -eq 1 && "$1" != "clean" ) ]]; then
  echo "usage: $0 [clean]" >&2
  exit 2
fi

if [[ "${1:-}" == "clean" ]]; then
  rm -rf "${artifact_root}"
  echo "Removed target artifact: ${artifact_root}"
  exit 0
fi

if [[ ! -f "${app_dir}/camera_tx.py" || ! -f "${app_dir}/requirements.txt" ]]; then
  echo "missing target application sources; run: git submodule update --init --recursive" >&2
  exit 1
fi

if [[ "${target}" != "raspberry-pi-5" ]]; then
  echo "unsupported physical target for GarStreamTx: ${target}" >&2
  echo "select raspberry-pi-5 in gar setup" >&2
  exit 1
fi

rm -rf "${artifact_dir}"
mkdir -p "${artifact_dir}"
cp "${app_dir}"/*.py "${app_dir}/requirements.txt" "${artifact_dir}/"

cat > "${artifact_dir}/run" <<'EOF'
#!/usr/bin/env bash
# Physical Raspberry Pi 5 defaults. The TX advertises itself and streams only
# while one or more receivers hold a renewable request lease.
set -euo pipefail

export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED="${PYTHONUNBUFFERED:-1}"
export GAR_GPIO_CHIP="${GAR_GPIO_CHIP:-/dev/gpiochip0}"
export GAR_CAMERA_DEVICE="${GAR_CAMERA_DEVICE:-/dev/video0}"
export GAR_CAMERA_FPS="${GAR_CAMERA_FPS:-30}"
export GAR_LOCAL_DISPLAY="${GAR_LOCAL_DISPLAY:-1}"
export GAR_LCD_DC_GPIO="${GAR_LCD_DC_GPIO:-23}"
export GAR_LCD_RST_GPIO="${GAR_LCD_RST_GPIO:-24}"

exec python3 "$(dirname "$0")/camera_tx.py"
EOF
chmod 0755 "${artifact_dir}/run"

cat > "${artifact_dir}/gar-stream-tx.env.example" <<'EOF'
# Optional Raspberry Pi overrides. TX-to-RX addressing is discovered at runtime.
GAR_STREAM_SOURCE_NAME=GarStreamTx
GAR_STREAM_DISCOVERY_PORT=5601
GAR_GPIO_CHIP=/dev/gpiochip0
GAR_CAMERA_DEVICE=/dev/video0
GAR_CAMERA_CAPS=image/jpeg
GAR_CAMERA_IO_MODE=auto
GAR_CAMERA_WIDTH=2048
GAR_CAMERA_HEIGHT=1536
GAR_CAMERA_FPS=30
GAR_LOCAL_DISPLAY=1
GAR_LCD_DC_GPIO=23
GAR_LCD_RST_GPIO=24
EOF

python3 - "${artifact_root}/artifact.json" "${target}" "${deploy_dest}" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

output, target, destination = sys.argv[1:]
payload = {
    "name": "gar-stream-tx-target",
    "target": target,
    "deploy": {
        "app": {
            "files": [
                {"src": "files/gar-stream-tx", "dest": destination}
            ]
        }
    },
}
Path(output).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

echo "Target: ${target}"
echo "Artifact: ${artifact_root}"
