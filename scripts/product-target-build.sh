#!/usr/bin/env bash
# GarStreamRx uses the same Python application bundle on the Linux simulation
# host and the Luckfox target. Keep a distinct GAR hook so the build
# environment can select TARGET_APP without knowing that implementation detail.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${repo_root}/scripts/product-sim-build.sh" "$@"
