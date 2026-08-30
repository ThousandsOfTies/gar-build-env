#!/usr/bin/env bash
# Compose Product defaults with the reusable FRDM-IMX91S UUU staging tool.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${script_dir}/common.sh"
frdm_imx91s_uuu_init

: "${GAR_IMX91S_OUTPUT_DIR:=${GAR_FRDM_IMX91S_REPO_ROOT}/artifacts/nand-final}"
: "${GAR_IMX91S_FACTORY_SCRIPT_NAME:=Factory-uuu-gar-servo-pet.lst}"

export GAR_IMX91S_OUTPUT_DIR GAR_IMX91S_FACTORY_SCRIPT_NAME
exec "${GAR_FRDM_IMX91S_TARGET_UUU_ROOT}/stage.sh" "$@"
