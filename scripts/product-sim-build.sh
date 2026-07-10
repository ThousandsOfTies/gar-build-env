#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi

package_dir="${VIBE_REMOTE_PACKAGE_DIR:-sources/gar-vibe-ui/vibe-remote}"
tools_dir="${GAR_TOOLS_DIR:-sources/gar-tools}"
client_dir="${repo_root}/${package_dir}/m5stickc-client"
tools_root="${repo_root}/${tools_dir}"

if [[ ! -f "${client_dir}/Makefile" || ! -d "${tools_root}" ]]; then
  echo "missing product submodules; run: git submodule update --init --recursive" >&2
  exit 1
fi

PATH="${HOME}/.venvs/platformio/bin:${PATH}" \
  make -C "${client_dir}" wokwi-build \
    GAR_TOOLS_ROOT="${tools_root}" \
    WOKWI_WORKSPACE="${repo_root}/.gar/wokwi/m5stackc"
