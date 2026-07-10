#!/usr/bin/env bash
# Copy this file to scripts/product-sim-build.sh on a product branch, then
# replace product_sim_build with the product's simulation build command.
#
# GaplessAgentRuntime invokes scripts/product-sim-build.sh for `gar sim build`.
# The script runs from either a configured local product workspace or its
# Codespaces workspace; keep all paths relative to this repository root.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi

# Product branches normally keep their application and the shared simulation
# assets as submodules below sources/.  Override either path in product.env
# when a product uses a different layout.
app_dir="${repo_root}/${GAR_SIM_APP_DIR:-sources/your-app}"
tools_dir="${repo_root}/${GAR_TOOLS_DIR:-sources/gar-tools}"

if [[ ! -d "${app_dir}" || ! -d "${tools_dir}" ]]; then
  echo "missing simulation sources; run: git submodule update --init --recursive" >&2
  exit 1
fi

product_sim_build() {
  # Replace this example with the application's simulation build command.
  # Pass GAR_TOOLS_ROOT="${tools_dir}" when the application's build supports
  # it, so that it uses this branch's checked-out gar-tools revision.
  #
  # Example:
  #   make -C "${app_dir}" sim-build GAR_TOOLS_ROOT="${tools_dir}"
  echo "No simulation build command configured for ${GAR_PRODUCT_NAME:-this product}." >&2
  echo "Edit scripts/product-sim-build.sh on this product branch." >&2
  return 1
}

product_sim_build
