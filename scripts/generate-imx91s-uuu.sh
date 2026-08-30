#!/usr/bin/env bash
# Compatibility entrypoint; implementation lives in the FRDM-IMX91S Target Capsule.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${script_dir}/targets/frdm-imx91s/provisioning/uuu/generate.sh" "$@"
