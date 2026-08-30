#!/usr/bin/env bash
# Backward-compatible GAR Product hook. New builds are selected and validated
# by a Deployment Profile before entering a Target Capsule.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${repo_root}/scripts/package-target.sh" "$@"
