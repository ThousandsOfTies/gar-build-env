#!/usr/bin/env bash
# Product compatibility wrapper around the reusable FRDM-IMX91S Target Pack.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
uuu_root="${repo_root}/sources/gar-tools/targets/frdm-imx91s/provisioning/uuu"

if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi
# Product defaults are committed; the local config may override only the
# destructive-write confirmation after a live board probe.
# shellcheck disable=SC1091
source "${repo_root}/config/imx91s-uuu.env.example"

: "${GAR_IMX91S_UUU_CONFIG:=${repo_root}/config/imx91s-uuu.env}"
if [[ ! -f "$GAR_IMX91S_UUU_CONFIG" ]]; then
  GAR_IMX91S_UUU_CONFIG="${repo_root}/config/imx91s-uuu.env.example"
fi
: "${GAR_IMX91S_TEMPLATE:=${uuu_root}/factory-spinand.lst.in}"
: "${GAR_IMX91S_OUTPUT:=${repo_root}/artifacts/from-codespace/Factory-uuu-gar-servo-pet.lst}"
: "${GAR_IMX91S_UUU_BUNDLE:=${repo_root}/artifacts/from-codespace}"

export GAR_IMX91S_UUU_CONFIG GAR_IMX91S_TEMPLATE GAR_IMX91S_OUTPUT
export GAR_IMX91S_UUU_BUNDLE GAR_PRODUCT_NAME
exec "${uuu_root}/generate.sh" "$@"
