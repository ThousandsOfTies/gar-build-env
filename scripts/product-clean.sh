#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_dir="${VIBE_REMOTE_PACKAGE_DIR:-sources/gar-vibe-ui/vibe-remote}"
package_root="${repo_root}/${package_dir}"

rm -rf "${repo_root}/artifacts/from-codespace"
rm -rf "${package_root}/dist"
rm -rf "${package_root}/m5stickc-client/.pio"
rm -rf "${package_root}/m5stickc-client/artifacts"
