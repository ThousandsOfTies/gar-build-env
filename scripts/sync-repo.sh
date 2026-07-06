#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "usage: $0 <repository>" >&2
  exit 2
fi

repo="$1"

if [[ ! -d "${repo}/.git" ]]; then
  echo "not a git repository: ${repo}" >&2
  exit 1
fi

git -C "${repo}" pull --ff-only
