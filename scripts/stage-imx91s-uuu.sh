#!/usr/bin/env bash
# Assemble the component files and generated UUU script into one GAR bundle.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi

input_dir="${GAR_UUU_INPUT_DIR:-}"
output_dir="${GAR_IMX91S_OUTPUT_DIR:-${repo_root}/artifacts/from-codespace}"
config_file="${GAR_IMX91S_UUU_CONFIG:-${repo_root}/config/imx91s-uuu.env}"
allow_unconfirmed=0
validate=0
force=0

usage() {
  cat <<'EOF'
Usage: scripts/stage-imx91s-uuu.sh --input-dir DIR [options]

DIR must contain the built component tree below:
  pub/u-boot/flash_gar_servo_pet.bin
  pub/kernel/Image
  pub/kernel/<DTB>
  pub/kernel/extlinux.conf
  pub/rootfs/rootfs.squashfs
  pub/rootfs/usr.local.tar.bz2
  pub/mfgtools/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst
  pub/layout/gar-servo-pet.sfdisk

Options:
  --input-dir DIR        component input tree (or GAR_UUU_INPUT_DIR)
  --output-dir DIR       output bundle (default: artifacts/from-codespace)
  --config FILE          UUU/layout environment file
  --allow-unconfirmed    stage a review/dry-run bundle while layout is 0
  --validate             run `uuu -dry` against the staged bundle
  --force                replace an existing output directory
  -h, --help             show this help
EOF
}

while (($#)); do
  case "$1" in
    --input-dir)
      [[ $# -ge 2 ]] || { echo "--input-dir requires a directory" >&2; exit 2; }
      input_dir="$2"
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || { echo "--output-dir requires a directory" >&2; exit 2; }
      output_dir="$2"
      shift 2
      ;;
    --config)
      [[ $# -ge 2 ]] || { echo "--config requires a file" >&2; exit 2; }
      config_file="$2"
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
    --force)
      force=1
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

if [[ -z "$input_dir" ]]; then
  echo "--input-dir (or GAR_UUU_INPUT_DIR) is required" >&2
  exit 2
fi
if [[ ! -d "$input_dir" ]]; then
  echo "missing component input directory: $input_dir" >&2
  exit 1
fi

if [[ -f "$config_file" ]]; then
  # shellcheck disable=SC1090
  source "$config_file"
elif [[ "$config_file" != "${repo_root}/config/imx91s-uuu.env" ]]; then
  echo "missing UUU config: $config_file" >&2
  exit 1
fi

: "${GAR_IMX91S_DTB:=imx91-11x11-frdm-imx91s.dtb}"
: "${GAR_IMX91S_LAYOUT_FILE:=pub/layout/gar-servo-pet.sfdisk}"
: "${GAR_IMX91S_LAYOUT_CONFIRMED:=0}"

if [[ "$GAR_IMX91S_LAYOUT_CONFIRMED" != "1" && "$allow_unconfirmed" != "1" ]]; then
  echo "refusing to stage an unconfirmed FRDM-IMX91S layout; use --allow-unconfirmed for review only" >&2
  exit 1
fi

case "$GAR_IMX91S_LAYOUT_FILE" in
  /*|*../*)
    echo "GAR_IMX91S_LAYOUT_FILE must be a relative path inside the bundle: $GAR_IMX91S_LAYOUT_FILE" >&2
    exit 1
    ;;
esac

required_files=(
  "pub/u-boot/flash_gar_servo_pet.bin"
  "pub/kernel/Image"
  "pub/kernel/${GAR_IMX91S_DTB}"
  "pub/kernel/extlinux.conf"
  "pub/rootfs/rootfs.squashfs"
  "pub/rootfs/usr.local.tar.bz2"
  "pub/mfgtools/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst"
  "$GAR_IMX91S_LAYOUT_FILE"
)

for relative in "${required_files[@]}"; do
  if [[ ! -f "${input_dir}/${relative}" ]]; then
    echo "missing component: ${input_dir}/${relative}" >&2
    exit 1
  fi
done

if [[ -e "$output_dir" && -n "$(find "$output_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  if (( ! force )); then
    echo "output directory is not empty (use --force): $output_dir" >&2
    exit 1
  fi
  rm -rf -- "$output_dir"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

for relative in "${required_files[@]}"; do
  install -D -m 0644 "${input_dir}/${relative}" "${tmp_dir}/${relative}"
done

generate_args=(
  --config "$config_file"
  --output "${tmp_dir}/Factory-uuu-gar-servo-pet.lst"
)
if ((allow_unconfirmed)); then
  generate_args+=(--allow-unconfirmed)
fi
if ((validate)); then
  generate_args+=(--validate)
fi
"${repo_root}/scripts/generate-imx91s-uuu.sh" "${generate_args[@]}"

mkdir -p "$output_dir"
cp -a "${tmp_dir}/." "$output_dir/"
(
  cd "$output_dir"
  sha256sum \
    Factory-uuu-gar-servo-pet.lst \
    pub/u-boot/flash_gar_servo_pet.bin \
    pub/kernel/Image \
    "pub/kernel/${GAR_IMX91S_DTB}" \
    pub/kernel/extlinux.conf \
    pub/uuu-ram/Image.padded \
    "pub/uuu-ram/${GAR_IMX91S_DTB}.padded" \
    pub/uuu-ram/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst.padded \
    pub/rootfs/rootfs.squashfs \
    pub/rootfs/usr.local.tar.bz2 \
    pub/mfgtools/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst \
    "$GAR_IMX91S_LAYOUT_FILE" > checksums.sha256
)

cat > "${output_dir}/bundle-info.txt" <<EOF
GarServoPet FRDM-IMX91S component UUU bundle
Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Layout confirmed: ${GAR_IMX91S_LAYOUT_CONFIRMED}
This bundle contains UUU components only; merge it with the Product app
artifact before invoking \`gar target deploy\`.
EOF

echo "staged UUU bundle: $output_dir"
