#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${repo_root}/scripts/setup-common.sh"
"${repo_root}/scripts/setup-product.sh"

echo "Gapless Agent Runtime build environment is ready."
