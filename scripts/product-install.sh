#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_dir="${VIBE_REMOTE_PACKAGE_DIR:-sources/gar-vibe-ui/vibe-remote}"
package_root="${repo_root}/${package_dir}"

if [[ ! -f "${package_root}/package.json" ]]; then
  echo "missing Vibe Remote package: ${package_root}" >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

npm_cmd=(npm)
if [[ -x "${package_root}/scripts/npm.sh" ]]; then
  npm_cmd=("${package_root}/scripts/npm.sh")
fi

if [[ -f "${package_root}/package-lock.json" ]]; then
  (cd "${package_root}" && "${npm_cmd[@]}" ci)
else
  (cd "${package_root}" && "${npm_cmd[@]}" install)
fi

echo "GarVibeRemote setup complete: ${package_root}"
