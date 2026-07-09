#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="${1:-${repo_root}/repos/product.repos}"
dst="${GAR_VCS_IMPORT_DIR:-${repo_root}/repos/imported}"

if [[ ! -f "$repos_file" ]]; then
  exit 0
fi

if ! command -v vcs >/dev/null 2>&1; then
  echo "vcs is required to import ${repos_file}" >&2
  echo "Install vcstool or remove the optional product.repos file." >&2
  exit 1
fi

mkdir -p "$dst"
vcs import "$dst" < "$repos_file"
