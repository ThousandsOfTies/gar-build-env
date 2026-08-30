#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/gar-luckfox-clean-test.XXXXXX)"
trap 'rm -rf -- "$test_root"' EXIT

bundle="${test_root}/from-codespace"
mkdir -p "${bundle}/files/gar-servo-pet"
printf 'generated Lyra payload\n' >"${bundle}/files/gar-servo-pet/run"
cp "${repo_root}/config/deployments/luckfox-rk3506.artifact.json" \
  "${bundle}/artifact.json"

make -C "$repo_root" clean DEPLOYMENT=luckfox-rk3506 ARTIFACT_ROOT="$bundle" >/dev/null
test ! -e "$bundle"

# A Lyra cleanup must not remove an artifact selected for a different Target.
mkdir -p "${bundle}/files/gar-servo-pet"
printf 'preserve NXP payload\n' >"${bundle}/files/gar-servo-pet/run"
cp "${repo_root}/config/deployments/frdm-imx91s.artifact.json" \
  "${bundle}/artifact.json"
before="$(sha256sum "${bundle}/artifact.json" "${bundle}/files/gar-servo-pet/run")"
make -C "$repo_root" clean DEPLOYMENT=luckfox-rk3506 ARTIFACT_ROOT="$bundle" >/dev/null
after="$(sha256sum "${bundle}/artifact.json" "${bundle}/files/gar-servo-pet/run")"
test "$before" = "$after"

echo "test_luckfox_target_clean: OK"
