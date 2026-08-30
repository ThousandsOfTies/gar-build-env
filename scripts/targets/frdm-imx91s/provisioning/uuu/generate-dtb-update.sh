#!/usr/bin/env bash
# Compose Product defaults with the reusable guarded DTB-only UUU generator.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${script_dir}/common.sh"
frdm_imx91s_uuu_init

: "${GAR_IMX91S_DTB_UPDATE_OUTPUT:=${GAR_FRDM_IMX91S_REPO_ROOT}/artifacts/from-codespace/Update-dtb-gar-servo-pet.lst}"
: "${GAR_IMX91S_UUU_BUNDLE:=${GAR_FRDM_IMX91S_REPO_ROOT}/artifacts/from-codespace}"

export GAR_IMX91S_DTB_UPDATE_OUTPUT GAR_IMX91S_UUU_BUNDLE
exec "${GAR_FRDM_IMX91S_TARGET_UUU_ROOT}/generate-dtb-update.sh" "$@"
