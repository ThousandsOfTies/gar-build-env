#!/usr/bin/env bash
# Build GarStreamTx's ARM64 virtual-device runtime for `gar sim env build`.
# This hook runs in the selected product workspace.  Runtime binaries are
# cross-compiled for the ARM64 simulation host and later transferred by
# `gar sim env deploy`.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi

tools_dir="${repo_root}/${GAR_TOOLS_DIR:-sources/gar-tools}"
runtime_dir="${tools_dir}/targets/linux-device/runtime"

if [[ ! -f "${runtime_dir}/Makefile" ]]; then
  echo "missing Linux simulation runtime; run: git submodule update --init --recursive" >&2
  exit 1
fi

if ! command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
  echo "gar sim env build: aarch64-linux-gnu-gcc が見つかりません。" >&2
  echo "local でビルドする場合は ARM64 cross compiler を導入してください。" >&2
  echo "Codespaces workspace を選択してビルドすることもできます。" >&2
  exit 1
fi

make -C "${runtime_dir}"
echo "Simulation runtime built: ${runtime_dir}"
