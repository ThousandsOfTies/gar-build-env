#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
requested_package_dir="${VIBE_REMOTE_PACKAGE_DIR:-}"
requested_tools_dir="${GAR_TOOLS_DIR:-}"

if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi

package_dir="${requested_package_dir:-${VIBE_REMOTE_PACKAGE_DIR:-sources/gar-vibe-ui/vibe-remote}}"
tools_dir="${requested_tools_dir:-${GAR_TOOLS_DIR:-sources/gar-tools}}"
client_dir="${repo_root}/${package_dir}/m5stickc-client"
tools_root="${repo_root}/${tools_dir}"
build_workspace="${repo_root}/.gar/build/wokwi/m5stackc"
artifact_root="${repo_root}/artifacts/from-codespace"

if [[ "${1:-}" == "clean" && $# -eq 1 ]]; then
  python3 "${repo_root}/scripts/package_wokwi_sim_app.py" clean \
    "${build_workspace}" \
    "${artifact_root}"
  exit 0
elif [[ $# -gt 0 ]]; then
  echo "usage: $0 [clean]" >&2
  exit 2
fi

if [[ ! -f "${client_dir}/Makefile" || ! -d "${tools_root}" ]]; then
  echo "missing product submodules; run: git submodule update --init --recursive" >&2
  exit 1
fi

python3 "${repo_root}/scripts/package_wokwi_sim_app.py" reset-build \
  "${build_workspace}" \
  "${artifact_root}"

PATH="${HOME}/.venvs/platformio/bin:${PATH}" \
  make -C "${client_dir}" wokwi-build \
    GAR_TOOLS_ROOT="${tools_root}" \
    WOKWI_WORKSPACE="${build_workspace}"

python3 "${repo_root}/scripts/package_wokwi_sim_app.py" package \
  "${build_workspace}" \
  "${artifact_root}"

echo "Wokwi simulation artifact: ${artifact_root}"
