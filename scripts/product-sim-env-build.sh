#!/usr/bin/env bash
# Build GarStreamTx's ARM64 virtual-device runtime for `gar sim env build`.
# This hook runs in the selected product workspace.  Runtime binaries are
# cross-compiled in the product branch's Docker build environment and later
# transferred by `gar sim env deploy`.
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

echo "Simulation runtime built: ${runtime_dir}"
