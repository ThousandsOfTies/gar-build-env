#!/usr/bin/env bash
# Compose Product defaults with the reusable read-only NAND layout probe.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${script_dir}/common.sh"
frdm_imx91s_uuu_init

: "${GAR_IMX91S_UUU_BUNDLE:=${GAR_FRDM_IMX91S_REPO_ROOT}/artifacts/from-codespace}"
: "${GAR_IMX91S_LAYOUT_PROBE_OUTPUT:=${GAR_IMX91S_UUU_BUNDLE}/Inspect-imx91s-layout.lst}"

export GAR_IMX91S_UUU_BUNDLE GAR_IMX91S_LAYOUT_PROBE_OUTPUT
exec "${GAR_FRDM_IMX91S_TARGET_UUU_ROOT}/generate-layout-probe.sh" "$@"
