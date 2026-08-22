#!/usr/bin/env bash
# Product compatibility wrapper around the reusable FRDM-IMX91S Target Pack.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
uuu_root="${repo_root}/sources/gar-tools/targets/frdm-imx91s/provisioning/uuu"

if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi
# shellcheck disable=SC1091
source "${repo_root}/config/imx91s-uuu.env.example"

: "${GAR_IMX91S_UUU_CONFIG:=${repo_root}/config/imx91s-uuu.env}"
if [[ ! -f "$GAR_IMX91S_UUU_CONFIG" ]]; then
  GAR_IMX91S_UUU_CONFIG="${repo_root}/config/imx91s-uuu.env.example"
fi
: "${GAR_IMX91S_OUTPUT_DIR:=${repo_root}/artifacts/nand-final}"
: "${GAR_IMX91S_FACTORY_SCRIPT_NAME:=Factory-uuu-gar-servo-pet.lst}"

export GAR_IMX91S_UUU_CONFIG GAR_IMX91S_OUTPUT_DIR
export GAR_IMX91S_FACTORY_SCRIPT_NAME GAR_PRODUCT_NAME
exec "${uuu_root}/stage.sh" "$@"
