#!/usr/bin/env bash
# Build and package GarStreamRx's ARM64 virtual-device runtime for
# `gar sim env build` and `gar sim env deploy`.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi

tools_dir="${repo_root}/${GAR_TOOLS_DIR:-sources/gar-tools}"
runtime_dir="${tools_dir}/targets/linux-device/runtime"
dockerfile="${repo_root}/Dockerfile"
image="${GAR_SIM_RUNTIME_BUILD_IMAGE:-gar-build-env-arm64-runtime}"
target="${GAR_SIM_TARGET:-luckfox-rv1106}"
artifact_root="${repo_root}/${GAR_SIM_ARTIFACT_ROOT:-artifacts/from-codespace}"
files_dir="${artifact_root}/files"

if [[ ! -f "${runtime_dir}/Makefile" || ! -f "${dockerfile}" ]]; then
  echo "missing Linux simulation runtime; run: git submodule update --init --recursive" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "gar sim env build: local runtime build requires a usable Docker daemon." >&2
  echo "Run gar setup and choose Local Docker, or select a Codespaces workspace." >&2
  exit 1
fi

docker build --tag "${image}" --file "${dockerfile}" "${repo_root}"
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --volume "${tools_dir}:/work/gar-tools" \
  --workdir /work/gar-tools/targets/linux-device/runtime \
  "${image}" \
  make

mkdir -p "${files_dir}"
rm -f "${files_dir}/cuse_spi_ili9341"
cp "${runtime_dir}/i2c-stub/cuse_i2c" "${files_dir}/cuse_i2c"
# GAR's generic SPI systemd unit starts /usr/local/sbin/cuse_spi.  For the RX
# product that binary must emulate the ILI9341 panel, not the MFRC-522 stub.
cp "${runtime_dir}/ili9341-stub/cuse_spi_ili9341" "${files_dir}/cuse_spi"
rm -rf "${files_dir}/web-bridge"
mkdir -p "${files_dir}/web-bridge"
cp -R "${runtime_dir}/web-bridge/." "${files_dir}/web-bridge/"

python3 - "${artifact_root}/artifact.json" "${target}" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

output, target = sys.argv[1:]
output_path = Path(output)
try:
    payload = json.loads(output_path.read_text(encoding="utf-8"))
except FileNotFoundError:
    payload = {"name": "gar-stream-rx-simulation", "deploy": {}}

payload["name"] = "gar-stream-rx-simulation"
payload["target"] = target
deploy = payload.setdefault("deploy", {})
deploy["sim_env"] = {
    "files": [
        {"src": "files/cuse_i2c", "dest": "~/cuse_i2c", "mode": "0755"},
        {"src": "files/cuse_spi", "dest": "~/cuse_spi", "mode": "0755"},
        {"src": "files/web-bridge", "dest": "~/web-bridge"},
    ]
}
output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

echo "Simulation runtime built: ${runtime_dir}"
echo "Runtime artifact: ${artifact_root}"
