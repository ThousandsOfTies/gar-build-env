#!/usr/bin/env bash
# Stable Product build entrypoint. Deployment selection and validation live in
# package_target.py; the selected Target Capsule owns the actual packaging.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gar_requested_deployment="${GAR_DEPLOYMENT:-}"
if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi
if [[ -n "$gar_requested_deployment" ]]; then
  export GAR_DEPLOYMENT="$gar_requested_deployment"
fi
unset gar_requested_deployment
exec python3 "${repo_root}/scripts/package_target.py" "$@"
