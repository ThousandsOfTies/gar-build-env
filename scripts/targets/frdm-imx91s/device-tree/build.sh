#!/usr/bin/env bash
# Build the Product DTB from the NXP base tree and capsule-owned overlay.
set -euo pipefail

capsule_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "${capsule_dir}/../../.." && pwd)"
default_kernel_dir="${repo_root}/artifacts/from-codespace/pub/kernel"
base_dtb="${GAR_IMX91S_BASE_DTB:-${default_kernel_dir}/imx91-11x11-frdm-imx91s.dtb}"
overlay_source="${GAR_IMX91S_DT_OVERLAY:-${capsule_dir}/device-tree/imx91s-gar-servo-pet-i2c4-overlay.dtso}"
output_dtb="${GAR_IMX91S_PRODUCT_DTB:-${default_kernel_dir}/imx91-11x11-frdm-imx91s-gar-servo-pet.dtb}"
work_dir=""

usage() {
  cat <<'EOF'
Usage: scripts/build-imx91s-dtb.sh [options]

Options:
  --base FILE       unmodified NXP FRDM-IMX91S DTB
  --overlay FILE    Product DT overlay source
  --output FILE     merged Product DTB
  -h, --help        show this help

The script uses local dtc/fdtoverlay when available. Otherwise it uses Docker
and a temporary Debian container with device-tree-compiler installed.
EOF
}

while (($#)); do
  case "$1" in
    --base)
      [[ $# -ge 2 ]] || { echo "--base requires a file" >&2; exit 2; }
      base_dtb="$2"
      shift 2
      ;;
    --overlay)
      [[ $# -ge 2 ]] || { echo "--overlay requires a file" >&2; exit 2; }
      overlay_source="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo "--output requires a file" >&2; exit 2; }
      output_dtb="$2"
      shift 2
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

[[ -f "$base_dtb" ]] || { echo "missing base DTB: $base_dtb" >&2; exit 1; }
[[ -f "$overlay_source" ]] || { echo "missing DT overlay: $overlay_source" >&2; exit 1; }

base_dtb="$(realpath "$base_dtb")"
overlay_source="$(realpath "$overlay_source")"
mkdir -p "$(dirname "$output_dtb")"
output_dtb="$(realpath -m "$output_dtb")"

if [[ "$base_dtb" == "$output_dtb" ]]; then
  echo "refusing to overwrite the base DTB: $base_dtb" >&2
  exit 1
fi

work_dir="$(mktemp -d /tmp/gar-servo-pet-dtb.XXXXXX)"
cleanup() {
  rm -rf -- "$work_dir"
}
trap cleanup EXIT

overlay_dtb="${work_dir}/imx91s-i2c4-pca9685.dtbo"
merged_dtb="${work_dir}/imx91s-gar-servo-pet.dtb"

verify_merged_dtb() {
  local candidate="$1"
  test "$(fdtget -t s "$candidate" /soc@0/bus@42000000/i2c@42540000 status)" = okay
  test "$(fdtget -t i "$candidate" /soc@0/bus@42000000/i2c@42540000 clock-frequency)" = 100000
  test "$(fdtget -t x "$candidate" /soc@0/bus@44000000/pinctrl@443c0000/lpi2c4-gar-servo-pet-grp fsl,pins)" = \
    "18 1c8 3fc 1 0 40000b9e 1c 1cc 3f8 1 0 40000b9e"
  fdtget "$candidate" /regulator-exp-3v3 regulator-always-on >/dev/null
  fdtget "$candidate" /regulator-exp-5v regulator-always-on >/dev/null
}

build_with_local_tools() {
  dtc -@ -I dts -O dtb -o "$overlay_dtb" "$overlay_source"
  fdtoverlay -i "$base_dtb" -o "$merged_dtb" "$overlay_dtb"
  verify_merged_dtb "$merged_dtb"
}

build_with_docker() {
  command -v docker >/dev/null 2>&1 || {
    echo "dtc/fdtoverlay are unavailable and Docker is not installed" >&2
    exit 1
  }
  docker run --rm \
    --volume "${base_dtb}:/input/base.dtb:ro" \
    --volume "${overlay_source}:/input/overlay.dtso:ro" \
    --volume "${work_dir}:/output" \
    debian:bookworm-slim \
    sh -euc '
      apt-get update >/dev/null
      apt-get install --yes --no-install-recommends device-tree-compiler >/dev/null
      dtc -@ -I dts -O dtb -o /output/overlay.dtbo /input/overlay.dtso
      fdtoverlay -i /input/base.dtb -o /output/imx91s-gar-servo-pet.dtb /output/overlay.dtbo
      test "$(fdtget -t s /output/imx91s-gar-servo-pet.dtb /soc@0/bus@42000000/i2c@42540000 status)" = okay
      test "$(fdtget -t i /output/imx91s-gar-servo-pet.dtb /soc@0/bus@42000000/i2c@42540000 clock-frequency)" = 100000
      test "$(fdtget -t x /output/imx91s-gar-servo-pet.dtb /soc@0/bus@44000000/pinctrl@443c0000/lpi2c4-gar-servo-pet-grp fsl,pins)" = \
        "18 1c8 3fc 1 0 40000b9e 1c 1cc 3f8 1 0 40000b9e"
      fdtget /output/imx91s-gar-servo-pet.dtb /regulator-exp-3v3 regulator-always-on >/dev/null
      fdtget /output/imx91s-gar-servo-pet.dtb /regulator-exp-5v regulator-always-on >/dev/null
    '
}

if command -v dtc >/dev/null 2>&1 \
  && command -v fdtoverlay >/dev/null 2>&1 \
  && command -v fdtget >/dev/null 2>&1; then
  build_with_local_tools >/dev/null
else
  build_with_docker
fi

install -m 0644 "$merged_dtb" "$output_dtb"
printf 'generated Product DTB: %s\n' "$output_dtb"
printf '  base:    %s\n' "$base_dtb"
printf '  overlay: %s\n' "$overlay_source"
printf '  LPI2C4:  100000 Hz, header pins 3/5\n'
printf '  power:   expansion 3.3 V and 5 V always on\n'
