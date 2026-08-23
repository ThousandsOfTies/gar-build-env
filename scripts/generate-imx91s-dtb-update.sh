#!/usr/bin/env bash
# Product wrapper around the reusable FRDM-IMX91S DTB-only UUU generator.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
uuu_root="${repo_root}/sources/gar-tools/targets/frdm-imx91s/provisioning/uuu"

# shellcheck disable=SC1091
source "${repo_root}/config/imx91s-uuu.env.example"

: "${GAR_IMX91S_UUU_CONFIG:=${repo_root}/config/imx91s-uuu.env}"
if [[ ! -f "$GAR_IMX91S_UUU_CONFIG" ]]; then
  GAR_IMX91S_UUU_CONFIG="${repo_root}/config/imx91s-uuu.env.example"
fi
: "${GAR_IMX91S_DTB_UPDATE_OUTPUT:=${repo_root}/artifacts/from-codespace/Update-dtb-gar-servo-pet.lst}"
: "${GAR_IMX91S_UUU_BUNDLE:=${repo_root}/artifacts/from-codespace}"

export GAR_IMX91S_UUU_CONFIG GAR_IMX91S_DTB_UPDATE_OUTPUT
export GAR_IMX91S_UUU_BUNDLE
exec "${uuu_root}/generate-dtb-update.sh" "$@"
