#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi

if [[ -f "${repo_root}/.gitmodules" ]]; then
  git -C "${repo_root}" submodule update --init --recursive
fi

if [[ -f "${repo_root}/repos/product.repos" ]]; then
  "${repo_root}/scripts/import-repos.sh" "${repo_root}/repos/product.repos"
fi

if [[ -x "${repo_root}/scripts/product-setup.sh" ]]; then
  "${repo_root}/scripts/product-setup.sh"
fi
