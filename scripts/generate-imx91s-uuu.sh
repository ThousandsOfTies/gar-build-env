#!/usr/bin/env bash
# Generate the Product-owned FRDM-IMX91S component UUU script.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi

config_file="${GAR_IMX91S_UUU_CONFIG:-${repo_root}/config/imx91s-uuu.env}"
template="${GAR_IMX91S_TEMPLATE:-${repo_root}/config/Factory-uuu-gar-servo-pet.lst.in}"
output="${GAR_IMX91S_OUTPUT:-${repo_root}/artifacts/from-codespace/Factory-uuu-gar-servo-pet.lst}"
bundle_dir="${GAR_IMX91S_UUU_BUNDLE:-}"
allow_unconfirmed=0
validate=0
dry_run=0

usage() {
  cat <<'EOF'
Usage: scripts/generate-imx91s-uuu.sh [options]

Options:
  --config FILE          UUU/layout environment file
  --template FILE        .lst.in template (default: config/Factory-uuu-gar-servo-pet.lst.in)
  --output FILE          generated .lst path
  --bundle-dir DIR       directory containing pub/ component files
  --allow-unconfirmed    generate while GAR_IMX91S_LAYOUT_CONFIRMED is 0
  --validate             run `uuu -dry` after generation
  --dry-run              print the resolved values without writing a file
  -h, --help             show this help
EOF
}

while (($#)); do
  case "$1" in
    --config)
      [[ $# -ge 2 ]] || { echo "--config requires a file" >&2; exit 2; }
      config_file="$2"
      shift 2
      ;;
    --template)
      [[ $# -ge 2 ]] || { echo "--template requires a file" >&2; exit 2; }
      template="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "--output requires a file" >&2; exit 2; }
      output="$2"
      shift 2
      ;;
    --bundle-dir)
      [[ $# -ge 2 ]] || { echo "--bundle-dir requires a directory" >&2; exit 2; }
      bundle_dir="$2"
      shift 2
      ;;
    --allow-unconfirmed)
      allow_unconfirmed=1
      shift
      ;;
    --validate)
      validate=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -f "$config_file" ]]; then
  # shellcheck disable=SC1090
  source "$config_file"
elif [[ "$config_file" != "${repo_root}/config/imx91s-uuu.env" ]]; then
  echo "missing UUU config: $config_file" >&2
  exit 1
fi

: "${GAR_UUU_VERSION:=1.5.243}"
: "${GAR_UUU_TRANSFER_TIMEOUT_MS:=30000}"
: "${GAR_IMX91S_FASTBOOT_BUFFER:=0x82800000}"
: "${GAR_UUU_TRANSFER_CHUNK_SIZE:=0x100000}"
: "${GAR_IMX91S_DTB:=imx91-11x11-frdm-imx91s.dtb}"
: "${GAR_IMX91S_DISK:=/dev/mmcblk0}"
: "${GAR_IMX91S_BOOT_PART:=1}"
: "${GAR_IMX91S_ROOTFS_PART:=2}"
: "${GAR_IMX91S_OVERLAY_PART:=3}"
: "${GAR_IMX91S_STORAGE_PART:=4}"
: "${GAR_IMX91S_LAYOUT_FILE:=pub/layout/gar-servo-pet.sfdisk}"
: "${GAR_IMX91S_LAYOUT_CONFIRMED:=0}"

if [[ -z "$bundle_dir" ]]; then
  bundle_dir="${GAR_IMX91S_UUU_BUNDLE:-$(cd "$(dirname "$output")" && pwd)}"
fi

for value_name in \
  GAR_UUU_VERSION \
  GAR_UUU_TRANSFER_TIMEOUT_MS \
  GAR_IMX91S_FASTBOOT_BUFFER \
  GAR_UUU_TRANSFER_CHUNK_SIZE \
  GAR_IMX91S_DTB \
  GAR_IMX91S_DISK \
  GAR_IMX91S_BOOT_PART \
  GAR_IMX91S_ROOTFS_PART \
  GAR_IMX91S_OVERLAY_PART \
  GAR_IMX91S_STORAGE_PART \
  GAR_IMX91S_LAYOUT_FILE; do
  if [[ -z "${!value_name}" ]]; then
    echo "${value_name} must not be empty" >&2
    exit 1
  fi
done

if [[ ! "$GAR_UUU_TRANSFER_TIMEOUT_MS" =~ ^[1-9][0-9]*$ ]]; then
  echo "GAR_UUU_TRANSFER_TIMEOUT_MS must be a positive integer: $GAR_UUU_TRANSFER_TIMEOUT_MS" >&2
  exit 1
fi
for hex_value_name in GAR_IMX91S_FASTBOOT_BUFFER GAR_UUU_TRANSFER_CHUNK_SIZE; do
  if [[ ! "${!hex_value_name}" =~ ^0x[0-9A-Fa-f]+$ ]]; then
    echo "${hex_value_name} must be a hexadecimal UUU value: ${!hex_value_name}" >&2
    exit 1
  fi
done

if [[ ! -f "$template" ]]; then
  echo "missing UUU template: $template" >&2
  exit 1
fi

if [[ "$GAR_IMX91S_LAYOUT_CONFIRMED" != "1" && "$allow_unconfirmed" != "1" ]]; then
  cat >&2 <<EOF
FRDM-IMX91S partition layout is not confirmed.
Set GAR_IMX91S_LAYOUT_CONFIRMED=1 only after checking the real board, or use
--allow-unconfirmed to generate a dry-run/review bundle.
EOF
  exit 1
fi

echo "UUU version:     $GAR_UUU_VERSION"
echo "Transfer timeout: ${GAR_UUU_TRANSFER_TIMEOUT_MS} ms"
echo "Fastboot buffer:  ${GAR_IMX91S_FASTBOOT_BUFFER}"
echo "Transfer chunk:   ${GAR_UUU_TRANSFER_CHUNK_SIZE}"
echo "DTB:             $GAR_IMX91S_DTB"
echo "Linux disk:      $GAR_IMX91S_DISK"
echo "Partitions:      boot=$GAR_IMX91S_BOOT_PART rootfs=$GAR_IMX91S_ROOTFS_PART overlay=$GAR_IMX91S_OVERLAY_PART storage=$GAR_IMX91S_STORAGE_PART"
echo "Layout confirmed: $GAR_IMX91S_LAYOUT_CONFIRMED"

if ((dry_run)); then
  echo "would generate: $output"
  exit 0
fi

required_files=(
  "pub/kernel/Image"
  "pub/kernel/${GAR_IMX91S_DTB}"
  "pub/mfgtools/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst"
)
for relative in "${required_files[@]}"; do
  if [[ ! -f "${bundle_dir}/${relative}" ]]; then
    echo "missing UUU component: ${bundle_dir}/${relative}" >&2
    exit 1
  fi
done

file_size_hex() {
  printf '0x%X' "$(stat -c '%s' "$1")"
}

kernel_size="$(file_size_hex "${bundle_dir}/pub/kernel/Image")"
dtb_size="$(file_size_hex "${bundle_dir}/pub/kernel/${GAR_IMX91S_DTB}")"
initrd_size="$(file_size_hex "${bundle_dir}/pub/mfgtools/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst")"

mkdir -p "$(dirname "$output")"
cp "$template" "$output"

replace_token() {
  local token="$1"
  local value="$2"
  local escaped
  escaped="$(printf '%s' "$value" | sed 's/[\\&|]/\\&/g')"
  sed -i "s|@@${token}@@|${escaped}|g" "$output"
}

replace_token UUU_VERSION "$GAR_UUU_VERSION"
replace_token TRANSFER_TIMEOUT_MS "$GAR_UUU_TRANSFER_TIMEOUT_MS"
replace_token FASTBOOT_BUFFER "$GAR_IMX91S_FASTBOOT_BUFFER"
replace_token TRANSFER_CHUNK_SIZE "$GAR_UUU_TRANSFER_CHUNK_SIZE"
replace_token KERNEL_SIZE "$kernel_size"
replace_token DTB_SIZE "$dtb_size"
replace_token INITRD_SIZE "$initrd_size"
replace_token DTB "$GAR_IMX91S_DTB"
replace_token DISK "$GAR_IMX91S_DISK"
replace_token BOOT_PART "$GAR_IMX91S_BOOT_PART"
replace_token ROOTFS_PART "$GAR_IMX91S_ROOTFS_PART"
replace_token OVERLAY_PART "$GAR_IMX91S_OVERLAY_PART"
replace_token STORAGE_PART "$GAR_IMX91S_STORAGE_PART"

if grep -Eq '@@[A-Z0-9_]+@@' "$output"; then
  echo "unresolved placeholders remain in $output" >&2
  exit 1
fi

if [[ "$(sed -n '1p' "$output")" != "uuu_version "* ]]; then
  echo "UUU command list must begin with uuu_version: $output" >&2
  exit 1
fi

if ((validate)); then
  uuu_bin="${GAR_UUU_BIN:-}"
  if [[ -z "$uuu_bin" ]]; then
    uuu_bin="$(command -v uuu || true)"
  fi
  if [[ -z "$uuu_bin" || ! -x "$uuu_bin" ]]; then
    echo "--validate requires uuu (set GAR_UUU_BIN if it is not on PATH)" >&2
    exit 1
  fi
  echo "validating UUU syntax with $uuu_bin -dry"
  (cd "$(dirname "$output")" && "$uuu_bin" -dry "$(basename "$output")")
fi

echo "generated: $output"
