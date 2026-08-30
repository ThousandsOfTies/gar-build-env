#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/gar-product-clean-test.XXXXXX)"
trap 'rm -rf -- "$test_root"' EXIT

bundle="${test_root}/from-codespace"
overlay="${test_root}/overlay"
mkdir -p \
  "${overlay}/usr/local/gar-servo-pet" \
  "${overlay}/opt/gar/apps/gar-servo-pet"
printf 'preserve me\n' > "${overlay}/usr/local/gar-servo-pet/README.md"
printf 'remove me\n' > "${overlay}/opt/gar/apps/gar-servo-pet/run"
python3 "${repo_root}/scripts/overlay_archive.py" create \
  --input "$overlay" \
  --output "${bundle}/pub/rootfs/usr.local.tar.bz2"

required=(
  Factory-uuu-gar-servo-pet.lst
  pub/u-boot/flash_gar_servo_pet.bin
  pub/u-boot/flash_gar_servo_pet_spinand.bin
  pub/kernel/Image
  pub/kernel/imx91-11x11-frdm-imx91s-gar-servo-pet.dtb
  pub/uuu-ram/flash_gar_servo_pet_spinand.bin.padded
  pub/uuu-ram/Image.padded
  pub/uuu-ram/imx91-11x11-frdm-imx91s-gar-servo-pet.dtb.padded
  pub/uuu-ram/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst.padded
  pub/rootfs/rootfs.squashfs
  pub/mfgtools/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst
)
for relative in "${required[@]}"; do
  mkdir -p "$(dirname "${bundle}/${relative}")"
  printf '%s\n' "$relative" > "${bundle}/${relative}"
done
mkdir -p "${bundle}/files/gar-servo-pet"
printf 'direct app\n' > "${bundle}/files/gar-servo-pet/run"
cp "${repo_root}/config/deployments/frdm-imx91s.artifact.json" \
  "${bundle}/artifact.json"

GAR_IMX91S_UUU_CONFIG="${repo_root}/config/frdm-imx91s.env.example" \
  make -C "$repo_root" clean DEPLOYMENT=frdm-imx91s ARTIFACT_ROOT="$bundle" >/dev/null
test ! -e "${bundle}/files/gar-servo-pet"
test ! -e "${bundle}/artifact.json"
test ! -e "${bundle}/.gar-base"
grep -F "SPI-NAND layout confirmed: 0" "${bundle}/bundle-info.txt" >/dev/null
(
  cd "$bundle"
  sha256sum -c checksums.sha256 >/dev/null
)
python3 "${repo_root}/scripts/overlay_archive.py" extract \
  --input "${bundle}/pub/rootfs/usr.local.tar.bz2" \
  --output "${test_root}/cleaned"
test ! -e "${test_root}/cleaned/opt/gar/apps/gar-servo-pet"
test -f "${test_root}/cleaned/usr/local/gar-servo-pet/README.md"

# FRDM cleanup must not mutate an artifact owned by the Lyra deployment.
mkdir -p "${bundle}/files/gar-servo-pet"
printf 'preserve Lyra payload\n' > "${bundle}/files/gar-servo-pet/run"
cp "${repo_root}/config/deployments/luckfox-rk3506.artifact.json" \
  "${bundle}/artifact.json"
before="$(sha256sum \
  "${bundle}/pub/rootfs/usr.local.tar.bz2" \
  "${bundle}/artifact.json" \
  "${bundle}/files/gar-servo-pet/run")"
make -C "$repo_root" clean DEPLOYMENT=frdm-imx91s ARTIFACT_ROOT="$bundle" >/dev/null
after="$(sha256sum \
  "${bundle}/pub/rootfs/usr.local.tar.bz2" \
  "${bundle}/artifact.json" \
  "${bundle}/files/gar-servo-pet/run")"
test "$before" = "$after"

# A malformed overlay must fail before the adjacent completed tree replaces
# the current artifact root.
mkdir -p "${bundle}/files/gar-servo-pet"
printf 'direct app\n' > "${bundle}/files/gar-servo-pet/run"
cp "${repo_root}/config/deployments/frdm-imx91s.artifact.json" \
  "${bundle}/artifact.json"
python3 - "${bundle}/pub/rootfs/usr.local.tar.bz2" <<'PY'
import sys
import tarfile

member = tarfile.TarInfo("opt/gar/apps/gar-servo-pet")
member.type = tarfile.SYMTYPE
member.linkname = "/tmp"
with tarfile.open(sys.argv[1], "w:bz2") as archive:
    archive.addfile(member)
PY
before="$(sha256sum \
  "${bundle}/pub/rootfs/usr.local.tar.bz2" \
  "${bundle}/artifact.json" \
  "${bundle}/files/gar-servo-pet/run")"
if GAR_ARTIFACT_ROOT="$bundle" \
  "${repo_root}/scripts/product-target-build.sh" clean \
  >"${test_root}/expected-failure.log" 2>&1; then
  echo "FAIL: malformed overlay cleanup unexpectedly succeeded" >&2
  exit 1
fi
after="$(sha256sum \
  "${bundle}/pub/rootfs/usr.local.tar.bz2" \
  "${bundle}/artifact.json" \
  "${bundle}/files/gar-servo-pet/run")"
test "$before" = "$after"

echo "test_frdm_imx91s_target_clean: OK"
