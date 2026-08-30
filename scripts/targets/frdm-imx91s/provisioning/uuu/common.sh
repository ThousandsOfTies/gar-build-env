#!/usr/bin/env bash
# Shared Product-side configuration for FRDM-IMX91S UUU helpers.

frdm_imx91s_uuu_init() {
  if [[ "${GAR_FRDM_IMX91S_UUU_INITIALIZED:-0}" == 1 ]]; then
    return 0
  fi

  GAR_FRDM_IMX91S_CAPSULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  GAR_FRDM_IMX91S_REPO_ROOT="$(cd "${GAR_FRDM_IMX91S_CAPSULE_DIR}/../../.." && pwd)"
  GAR_FRDM_IMX91S_TARGET_UUU_ROOT="${GAR_FRDM_IMX91S_REPO_ROOT}/sources/gar-tools/targets/frdm-imx91s/provisioning/uuu"

  if [[ -f "${GAR_FRDM_IMX91S_REPO_ROOT}/config/product.env" ]]; then
    # shellcheck disable=SC1091
    source "${GAR_FRDM_IMX91S_REPO_ROOT}/config/product.env"
  fi

  local default_config
  local local_config
  local legacy_local_config
  local selected_config
  default_config="${GAR_TARGET_DEFAULT_CONFIG:-${GAR_FRDM_IMX91S_REPO_ROOT}/config/frdm-imx91s.env.example}"
  local_config="${GAR_TARGET_LOCAL_CONFIG:-${GAR_FRDM_IMX91S_REPO_ROOT}/config/frdm-imx91s.env}"
  legacy_local_config="${GAR_FRDM_IMX91S_REPO_ROOT}/config/imx91s-uuu.env"

  if [[ ! -f "$default_config" ]]; then
    echo "missing FRDM-IMX91S default config: $default_config" >&2
    return 1
  fi
  if [[ ! -d "$GAR_FRDM_IMX91S_TARGET_UUU_ROOT" ]]; then
    echo "missing reusable FRDM-IMX91S Target Pack: $GAR_FRDM_IMX91S_TARGET_UUU_ROOT" >&2
    return 1
  fi

  # Defaults are layered first. The reusable Target Pack then sources the
  # selected local file, whose intentionally sparse overrides remain valid.
  # shellcheck disable=SC1090
  source "$default_config"
  if [[ -n "${GAR_IMX91S_UUU_CONFIG:-}" ]]; then
    selected_config="$GAR_IMX91S_UUU_CONFIG"
  elif [[ -f "$local_config" ]]; then
    selected_config="$local_config"
  elif [[ -f "$legacy_local_config" ]]; then
    selected_config="$legacy_local_config"
  else
    selected_config="$default_config"
  fi
  if [[ ! -f "$selected_config" ]]; then
    echo "missing FRDM-IMX91S local config: $selected_config" >&2
    return 1
  fi

  : "${GAR_PRODUCT_NAME:=GarServoPet}"
  GAR_IMX91S_UUU_CONFIG="$selected_config"
  GAR_FRDM_IMX91S_UUU_INITIALIZED=1
  export GAR_PRODUCT_NAME GAR_IMX91S_UUU_CONFIG
  export GAR_FRDM_IMX91S_CAPSULE_DIR GAR_FRDM_IMX91S_REPO_ROOT
  export GAR_FRDM_IMX91S_TARGET_UUU_ROOT GAR_FRDM_IMX91S_UUU_INITIALIZED
}
