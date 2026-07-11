#!/usr/bin/env bash
# GaplessAgentRuntime invokes scripts/product-sim-build.sh for `gar sim build`.
# GarStreamRx is a Python application for the Luckfox RV1106 target.  The
# simulation artifact is therefore a validated application bundle, while
# `gar sim env build` builds the separate Linux device stubs and web bridge.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi

app_dir="${repo_root}/${GAR_SIM_APP_DIR:-sources/gar-stream-rx}"
tools_dir="${repo_root}/${GAR_TOOLS_DIR:-sources/gar-tools}"
target="${GAR_SIM_TARGET:-luckfox-rv1106}"
artifact_root="${repo_root}/${GAR_SIM_ARTIFACT_ROOT:-artifacts/from-codespace}"
artifact_dir="${artifact_root}/files/gar-stream-rx"
deploy_dest="${GAR_SIM_ARTIFACT_DEST:-~/gar-stream-rx}"

if [[ "$#" -gt 1 || ( "$#" -eq 1 && "$1" != "clean" ) ]]; then
  echo "usage: $0 [clean]" >&2
  exit 2
fi

if [[ "${1:-}" == "clean" ]]; then
  rm -rf "${artifact_root}"
  echo "Removed simulation artifact: ${artifact_root}"
  exit 0
fi

if [[ ! -f "${app_dir}/video_monitor.py" || ! -f "${app_dir}/requirements.txt" || ! -d "${tools_dir}/targets/linux-device/runtime" ]]; then
  echo "missing simulation sources; run: git submodule update --init --recursive" >&2
  exit 1
fi

rm -rf "${artifact_root}"
mkdir -p "${artifact_dir}"

# Keep the deployable app self-contained and validate all Python sources in
# the copied artifact, so build output never adds __pycache__ to the submodule.
cp "${app_dir}"/*.py "${app_dir}/requirements.txt" "${artifact_dir}/"
python3 -m compileall -q -f "${artifact_dir}"

python3 - "${artifact_root}/artifact.json" "${target}" "${deploy_dest}" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

output, target, destination = sys.argv[1:]
payload = {
    "name": "gar-stream-rx-simulation",
    "target": target,
    "deploy": {
        "app": {
            "files": [
                {
                    "src": "files/gar-stream-rx",
                    "dest": destination,
                }
            ]
        }
    },
}
Path(output).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

echo "Target: ${target}"
echo "Artifact: ${artifact_root}"
