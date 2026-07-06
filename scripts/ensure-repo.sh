#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "usage: $0 <git-url> <destination>" >&2
  exit 2
fi

url="$1"
dst="$2"

if [[ -d "${dst}/.git" ]]; then
  echo "repo exists: ${dst}"
elif [[ -e "${dst}" ]]; then
  echo "using existing non-git path: ${dst}"
else
  mkdir -p "$(dirname "${dst}")"
  git clone "${url}" "${dst}"
fi
