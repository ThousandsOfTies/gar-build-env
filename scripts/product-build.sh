#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_dir="${VIBE_REMOTE_PACKAGE_DIR:-sources/gar-vibe-ui/vibe-remote}"
package_root="${repo_root}/${package_dir}"
pio_env="${PIO_ENV:-m5stickc-plus2-vibe-min}"

npm_cmd=(npm)
if [[ -x "${package_root}/scripts/npm.sh" ]]; then
  npm_cmd=("${package_root}/scripts/npm.sh")
fi

(
  cd "${package_root}"
  "${npm_cmd[@]}" run compile
  "${npm_cmd[@]}" run typecheck
  "${npm_cmd[@]}" run lint
  "${npm_cmd[@]}" test
)

if [[ "${VIBE_BUILD_FIRMWARE:-0}" == "1" ]]; then
  PATH="${HOME}/.venvs/platformio/bin:${PATH}" \
    make -C "${package_root}/m5stickc-client" vm-package PIO_ENV="${pio_env}"
fi
