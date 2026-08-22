#!/usr/bin/env bash
# Generate a read-only UUU script for inspecting the actual FRDM-IMX91S eMMC.
# This boots the manufacturing initramfs into RAM and never runs sfdisk/mkfs/dd.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${repo_root}/config/product.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/product.env"
fi

config_file="${GAR_IMX91S_UUU_CONFIG:-${repo_root}/config/imx91s-uuu.env}"
bundle_dir="${GAR_IMX91S_UUU_BUNDLE:-${repo_root}/artifacts/from-codespace}"
output="${GAR_IMX91S_LAYOUT_PROBE_OUTPUT:-${bundle_dir}/Inspect-imx91s-layout.lst}"
validate=0

usage() {
  cat <<'EOF'
Usage: scripts/generate-imx91s-layout-probe.sh [options]

Generate a read-only UUU script which boots the manufacturing initramfs and
prints the eMMC device/partition information. It never runs sfdisk, mkfs, dd,
mount, or any other persistent-write command.

Options:
  --config FILE       UUU/layout environment file
  --bundle-dir DIR    directory containing the existing UUU components
  --output FILE       generated probe script path
  --validate          run `uuu -dry` after generation
  -h, --help          show this help
EOF
}

while (($#)); do
  case "$1" in
    --config)
      [[ $# -ge 2 ]] || { echo "--config requires a file" >&2; exit 2; }
      config_file="$2"
      shift 2
      ;;
    --bundle-dir)
      [[ $# -ge 2 ]] || { echo "--bundle-dir requires a directory" >&2; exit 2; }
      bundle_dir="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "--output requires a file" >&2; exit 2; }
      output="$2"
      shift 2
      ;;
    --validate)
      validate=1
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
: "${GAR_IMX91S_DTB:=imx91-11x11-frdm-imx91s.dtb}"

required_files=(
  "pub/u-boot/flash_gar_servo_pet.bin"
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

mkdir -p "$(dirname "$output")"
cat > "$output" <<EOF
# Read-only FRDM-IMX91S eMMC layout probe.
# This script boots Linux into RAM and only prints information. It does not
# partition, format, mount, or write the target eMMC.
uuu_version ${GAR_UUU_VERSION}

SDPS: boot -f pub/u-boot/flash_gar_servo_pet.bin

FB: ucmd setenv gar_kernel_addr \${loadaddr}
FB: ucmd setenv fastboot_buffer \${loadaddr}
FB: download -f pub/kernel/Image
FB: ucmd setenv gar_kernel_size \${fastboot_bytes}

FB: ucmd setenv gar_dtb_addr \${fdt_addr_r}
FB: ucmd setenv fastboot_buffer \${fdt_addr_r}
FB: download -f pub/kernel/${GAR_IMX91S_DTB}
FB: ucmd setenv gar_dtb_size \${fastboot_bytes}

FB: ucmd setenv gar_initrd_addr \${ramdisk_addr_r}
FB: ucmd setenv fastboot_buffer \${ramdisk_addr_r}
FB: download -f pub/mfgtools/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst
FB: ucmd setenv gar_initrd_size \${fastboot_bytes}
FB: acmd booti \${gar_kernel_addr} \${gar_initrd_addr}:\${gar_initrd_size} \${gar_dtb_addr}

FBK: ucmd echo GAR_IMX91S_LAYOUT_PROBE_BEGIN
FBK: ucmd udevadm settle || true
FBK: ucmd cat /proc/partitions
FBK: ucmd ls -l /dev/mmcblk0* || true
FBK: ucmd ls -l /dev/mmcblk1* || true
FBK: ucmd cat /sys/block/mmcblk0/size || true
FBK: ucmd cat /sys/block/mmcblk1/size || true
FBK: ucmd blockdev --getsize64 /dev/mmcblk0 || true
FBK: ucmd blockdev --getsize64 /dev/mmcblk1 || true
FBK: ucmd sfdisk --dump /dev/mmcblk0 || true
FBK: ucmd sfdisk --dump /dev/mmcblk1 || true
FBK: ucmd cat /sys/block/mmcblk0/device/name || true
FBK: ucmd cat /sys/block/mmcblk1/device/name || true
FBK: ucmd cat /sys/block/mmcblk0/device/type || true
FBK: ucmd cat /sys/block/mmcblk1/device/type || true
FBK: ucmd echo GAR_IMX91S_LAYOUT_PROBE_END
FBK: acmd reboot
EOF

if ((validate)); then
  uuu_bin="${GAR_UUU_BIN:-}"
  if [[ -z "$uuu_bin" ]]; then
    uuu_bin="$(command -v uuu || true)"
  fi
  if [[ -z "$uuu_bin" || ! -x "$uuu_bin" ]]; then
    echo "--validate requires uuu (set GAR_UUU_BIN if it is not on PATH)" >&2
    exit 1
  fi
  echo "validating layout probe syntax with $uuu_bin -dry"
  (cd "$(dirname "$output")" && "$uuu_bin" -dry "$(basename "$output")")
fi

echo "generated read-only layout probe: $output"
