#!/usr/bin/env bash
# FRDM-IMX91S Target Capsule: build the selected Application Capsule and merge
# it into the Product's UUU component bundle. BSP components remain inputs.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

: "${GAR_DEPLOYMENT:?deployment dispatcher did not set GAR_DEPLOYMENT}"
: "${GAR_DEPLOYMENT_PROFILE:?deployment dispatcher did not set GAR_DEPLOYMENT_PROFILE}"
: "${GAR_PRODUCT_ID:?deployment dispatcher did not set GAR_PRODUCT_ID}"
: "${GAR_TARGET:?deployment dispatcher did not set GAR_TARGET}"
: "${GAR_TARGET_ARTIFACT_KIND:?deployment dispatcher did not set GAR_TARGET_ARTIFACT_KIND}"
: "${GAR_TARGET_ARTIFACT_MANIFEST:?deployment dispatcher did not set GAR_TARGET_ARTIFACT_MANIFEST}"
: "${GAR_TARGET_DEFAULT_CONFIG:?deployment dispatcher did not set GAR_TARGET_DEFAULT_CONFIG}"
: "${GAR_TARGET_LOCAL_CONFIG:?deployment dispatcher did not set GAR_TARGET_LOCAL_CONFIG}"
: "${GAR_APP_ID:?deployment dispatcher did not set GAR_APP_ID}"
: "${GAR_APP_MANIFEST:?deployment dispatcher did not set GAR_APP_MANIFEST}"
: "${GAR_APP_ROOT:?deployment dispatcher did not set GAR_APP_ROOT}"
: "${GAR_APP_BUILD_GOAL:?deployment dispatcher did not set GAR_APP_BUILD_GOAL}"
: "${GAR_APP_BINARY:?deployment dispatcher did not set GAR_APP_BINARY}"
: "${GAR_APP_BINARY_NAME:?deployment dispatcher did not set GAR_APP_BINARY_NAME}"
: "${GAR_APP_ENTRYPOINT:?deployment dispatcher did not set GAR_APP_ENTRYPOINT}"
: "${GAR_APP_ENTRYPOINT_NAME:?deployment dispatcher did not set GAR_APP_ENTRYPOINT_NAME}"
: "${GAR_APP_README:?deployment dispatcher did not set GAR_APP_README}"
: "${GAR_APP_INSTALL_DIR:?deployment dispatcher did not set GAR_APP_INSTALL_DIR}"
: "${GAR_APP_I2C_CONFIG_DEST:?deployment dispatcher did not set GAR_APP_I2C_CONFIG_DEST}"
: "${GAR_APP_CONNECTIONS_CONFIG_DEST:?deployment dispatcher did not set GAR_APP_CONNECTIONS_CONFIG_DEST}"
: "${GAR_APP_SERVO_CONFIG_DEST:?deployment dispatcher did not set GAR_APP_SERVO_CONFIG_DEST}"
: "${GAR_HARDWARE_BINDING:?deployment dispatcher did not set GAR_HARDWARE_BINDING}"
: "${GAR_RUNTIME_I2C_CONFIG:?deployment dispatcher did not set GAR_RUNTIME_I2C_CONFIG}"
: "${GAR_RUNTIME_CONNECTIONS_CONFIG:?deployment dispatcher did not set GAR_RUNTIME_CONNECTIONS_CONFIG}"
: "${GAR_RUNTIME_SERVO_CONFIG:?deployment dispatcher did not set GAR_RUNTIME_SERVO_CONFIG}"

# Target-local settings may tune UUU, but cannot replace the composition that
# package_target.py already validated.
readonly GAR_DEPLOYMENT GAR_DEPLOYMENT_PROFILE GAR_PRODUCT_ID GAR_TARGET
readonly GAR_TARGET_ARTIFACT_KIND GAR_TARGET_ARTIFACT_MANIFEST
readonly GAR_TARGET_DEFAULT_CONFIG GAR_TARGET_LOCAL_CONFIG
readonly GAR_APP_ID GAR_APP_MANIFEST GAR_APP_ROOT GAR_APP_BUILD_GOAL
readonly GAR_APP_BINARY GAR_APP_BINARY_NAME GAR_APP_ENTRYPOINT
readonly GAR_APP_ENTRYPOINT_NAME GAR_APP_README GAR_APP_INSTALL_DIR
readonly GAR_APP_I2C_CONFIG_DEST GAR_APP_CONNECTIONS_CONFIG_DEST
readonly GAR_APP_SERVO_CONFIG_DEST
readonly GAR_HARDWARE_BINDING GAR_RUNTIME_I2C_CONFIG
readonly GAR_RUNTIME_CONNECTIONS_CONFIG GAR_RUNTIME_SERVO_CONFIG

# The target-id based filename is canonical. Preserve an existing local
# config/imx91s-uuu.env until the operator chooses to rename it.
legacy_target_local_config="${repo_root}/config/imx91s-uuu.env"
if [[ -n "${GAR_IMX91S_UUU_CONFIG:-}" ]]; then
  target_local_config="$GAR_IMX91S_UUU_CONFIG"
else
  target_local_config="$GAR_TARGET_LOCAL_CONFIG"
fi
if [[ -z "${GAR_IMX91S_UUU_CONFIG:-}" && \
      ! -f "$target_local_config" && \
      -f "$legacy_target_local_config" ]]; then
  target_local_config="$legacy_target_local_config"
fi

# shellcheck disable=SC1090
source "$GAR_TARGET_DEFAULT_CONFIG"
if [[ -f "$target_local_config" ]]; then
  # shellcheck disable=SC1090
  source "$target_local_config"
fi

app_dir="$GAR_APP_ROOT"
tools_dir="${repo_root}/${GAR_TOOLS_DIR:-sources/gar-tools}"
artifact_root_requested="${GAR_ARTIFACT_ROOT:-${repo_root}/artifacts/from-codespace}"
build_image="${GAR_BUILD_IMAGE:-gar-build-env:latest}"
target_cc="${TARGET_CC:-aarch64-linux-gnu-gcc}"
archive_tool="${repo_root}/scripts/overlay_archive.py"
: "${GAR_IMX91S_FACTORY_SCRIPT_NAME:=Factory-uuu-gar-servo-pet.lst}"

die() {
  echo "frdm-imx91s package: $*" >&2
  exit 1
}

if [[ "$artifact_root_requested" != /* ]]; then
  artifact_root_requested="${repo_root}/${artifact_root_requested}"
fi
[[ ! -L "$artifact_root_requested" ]] || \
  die "refusing symlink artifact root: $artifact_root_requested"
artifact_root="$(realpath -m "$artifact_root_requested")"
repo_parent="$(dirname "$repo_root")"
case "$artifact_root" in
  /|/home|/home/user|"$repo_parent"|"$repo_root")
    die "refusing unsafe artifact root: $artifact_root"
    ;;
esac
case "$artifact_root" in
  "${repo_root}/"*|/tmp/gar-*) ;;
  *)
    [[ "${GAR_ALLOW_EXTERNAL_ARTIFACT_ROOT:-0}" == 1 ]] || \
      die "external artifact root requires GAR_ALLOW_EXTERNAL_ARTIFACT_ROOT=1: $artifact_root"
    ;;
esac

[[ "$GAR_TARGET" == "frdm-imx91s" ]] || \
  die "deployment target must be frdm-imx91s: $GAR_TARGET"
[[ "$GAR_PRODUCT_ID" == "gar-servo-pet" ]] || \
  die "deployment product must be gar-servo-pet: $GAR_PRODUCT_ID"
[[ "$GAR_APP_ID" == "gar-servo-pet" ]] || \
  die "this Product Target Capsule expects gar-servo-pet: $GAR_APP_ID"
[[ "$GAR_TARGET_ARTIFACT_KIND" == "uuu-image-and-app" ]] || \
  die "deployment artifact kind must be uuu-image-and-app: $GAR_TARGET_ARTIFACT_KIND"
[[ -f "$GAR_DEPLOYMENT_PROFILE" ]] || die "deployment profile is missing"
[[ -f "$GAR_HARDWARE_BINDING" ]] || die "hardware binding is missing"
[[ -f "$GAR_TARGET_ARTIFACT_MANIFEST" ]] || die "artifact manifest is missing"

case "$app_dir" in
  "${repo_root}/"*) app_relative="${app_dir#"${repo_root}/"}" ;;
  *) die "application directory must be inside the Product repository: $app_dir" ;;
esac
case "$GAR_APP_BINARY" in
  "${app_dir}/"*) app_binary_relative="${GAR_APP_BINARY#"${app_dir}/"}" ;;
  *) die "application binary must be inside the Application Capsule: $GAR_APP_BINARY" ;;
esac
uuu_stage="${tools_dir}/targets/frdm-imx91s/provisioning/uuu/stage.sh"

[[ -d "$app_dir" ]] || die "missing application submodule: $app_dir"
[[ -d "$tools_dir" ]] || die "missing gar-tools submodule: $tools_dir"
[[ -x "$uuu_stage" ]] || die "FRDM-IMX91S staging tool is missing: $uuu_stage"
[[ -f "${app_dir}/Makefile" ]] || die "application Makefile is missing: ${app_dir}/Makefile"
[[ -f "$GAR_APP_ENTRYPOINT" ]] || die "application entrypoint is missing: $GAR_APP_ENTRYPOINT"
[[ -f "$GAR_APP_README" ]] || die "application README is missing: $GAR_APP_README"
[[ -f "$GAR_RUNTIME_I2C_CONFIG" ]] || die "runtime I2C config is missing"
[[ -f "$GAR_RUNTIME_CONNECTIONS_CONFIG" ]] || die "runtime connections config is missing"
[[ -f "$GAR_RUNTIME_SERVO_CONFIG" ]] || die "runtime servo config is missing"
[[ -f "$archive_tool" ]] || die "overlay archive tool is missing: $archive_tool"
command -v python3 >/dev/null 2>&1 || die "python3 is required"
[[ "$GAR_IMX91S_FACTORY_SCRIPT_NAME" == "Factory-uuu-gar-servo-pet.lst" ]] || \
  die "factory script name differs from the deployment artifact manifest"
[[ "$GAR_IMX91S_RAM_BOOT_IMAGE" == "flash_gar_servo_pet.bin" ]] || \
  die "RAM boot filename differs from the deployment artifact manifest"
[[ "$GAR_IMX91S_NAND_BOOT_IMAGE" == "flash_gar_servo_pet_spinand.bin" ]] || \
  die "SPI-NAND boot filename differs from the deployment artifact manifest"
[[ "$GAR_IMX91S_DTB" == "imx91-11x11-frdm-imx91s-gar-servo-pet.dtb" ]] || \
  die "DTB filename differs from the deployment artifact manifest"

require_build_container() {
  command -v docker >/dev/null 2>&1 || \
    die "${target_cc} is unavailable and Docker is not installed"
  docker image inspect "$build_image" >/dev/null 2>&1 || \
    die "required local build image is missing: $build_image"
}

make_in_container() {
  local goal="$1"
  require_build_container
  local force=()
  if [[ "$goal" != clean ]]; then
    force=(-B)
  fi
  docker run --rm \
    --pull=never \
    --user "$(id -u):$(id -g)" \
    -v "${repo_root}:/workspace" \
    -w "/workspace/${app_relative}" \
    "$build_image" \
    make "${force[@]}" "$goal" TARGET_CC=aarch64-linux-gnu-gcc
}

uuu_checksum_paths=(
  "${GAR_IMX91S_FACTORY_SCRIPT_NAME}"
  "pub/u-boot/${GAR_IMX91S_RAM_BOOT_IMAGE}"
  "pub/u-boot/${GAR_IMX91S_NAND_BOOT_IMAGE}"
  "pub/kernel/Image"
  "pub/kernel/${GAR_IMX91S_DTB}"
  "pub/uuu-ram/${GAR_IMX91S_NAND_BOOT_IMAGE}.padded"
  "pub/uuu-ram/Image.padded"
  "pub/uuu-ram/${GAR_IMX91S_DTB}.padded"
  "pub/uuu-ram/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst.padded"
  "pub/rootfs/rootfs.squashfs"
  "pub/rootfs/usr.local.tar.bz2"
  "pub/mfgtools/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst"
)

write_uuu_checksums() {
  local root="$1"
  local relative
  for relative in "${uuu_checksum_paths[@]}"; do
    [[ -f "${root}/${relative}" ]] || die "cannot checksum missing UUU component: ${root}/${relative}"
  done
  (
    cd "$root"
    temporary=".checksums.sha256.$$"
    trap 'rm -f -- "$temporary"' EXIT
    sha256sum "${uuu_checksum_paths[@]}" > "$temporary"
    mv -f -- "$temporary" checksums.sha256
  )
}

artifact_is_this_deployment() {
  [[ -f "${artifact_root}/artifact.json" ]] || return 1
  python3 - "${artifact_root}/artifact.json" "$GAR_TARGET" "$GAR_APP_ID" "$GAR_APP_INSTALL_DIR" <<'PY'
import json
import sys
from pathlib import Path

path, target, app, destination = sys.argv[1:]
try:
    manifest = json.loads(Path(path).read_text(encoding="utf-8"))
    files = manifest["deploy"]["app"]["files"]
except (OSError, ValueError, KeyError, TypeError):
    raise SystemExit(1)
expected = {"src": f"files/{app}", "dest": destination, "mode": "0755"}
raise SystemExit(0 if manifest.get("target") == target and expected in files else 1)
PY
}

if [[ "${1:-}" == "clean" ]]; then
  if command -v make >/dev/null 2>&1; then
    make -C "$app_dir" clean
  else
    make_in_container clean
  fi
  cleaned_artifact=0
  if [[ -d "$artifact_root" ]] && artifact_is_this_deployment; then
    for path in \
      "$artifact_root" \
      "${artifact_root}/pub" \
      "${artifact_root}/pub/rootfs" \
      "${artifact_root}/files"; do
      [[ ! -L "$path" ]] || die "refusing symlink in artifact cleanup path: $path"
    done
    [[ ! -L "${artifact_root}/pub/rootfs/usr.local.tar.bz2" ]] || \
      die "refusing symlink rootfs overlay"

    clean_work="$(mktemp -d "/tmp/${GAR_APP_ID}-clean.XXXXXX")"
    clean_parent="$(dirname "$artifact_root")"
    clean_name="$(basename "$artifact_root")"
    mkdir -p "$clean_parent"
    clean_next="$(mktemp -d "${clean_parent}/.${clean_name}.clean.XXXXXX")"
    clean_backup=""
    # shellcheck disable=SC2317
    clean_cleanup() {
      local status=$?
      trap - EXIT
      if [[ -n "$clean_backup" && -e "$clean_backup" && ! -e "$artifact_root" ]]; then
        mv -- "$clean_backup" "$artifact_root"
      fi
      [[ ! -e "$clean_next" ]] || rm -rf -- "$clean_next"
      rm -rf -- "$clean_work"
      exit "$status"
    }
    trap clean_cleanup EXIT
    cp -a "${artifact_root}/." "$clean_next/"

    python3 "$archive_tool" extract \
      --input "${clean_next}/pub/rootfs/usr.local.tar.bz2" \
      --output "${clean_work}/overlay"
    rm -rf -- "${clean_work}/overlay${GAR_APP_INSTALL_DIR}"
    python3 "$archive_tool" create \
      --input "${clean_work}/overlay" \
      --output "${clean_work}/usr.local.tar.bz2"
    install -m 0644 \
      "${clean_work}/usr.local.tar.bz2" \
      "${clean_next}/pub/rootfs/usr.local.tar.bz2"
    rm -rf -- "${clean_next}/files/${GAR_APP_ID}" "${clean_next}/.gar-base"
    rm -f -- "${clean_next}/artifact.json" "${clean_next}/bundle-info.txt"
    cat > "${clean_work}/bundle-info.txt" <<EOF
${GAR_PRODUCT_NAME:-GarServoPet} FRDM-IMX91S component UUU bundle
Application capsule ${GAR_APP_ID} removed by package-target.sh clean.
SPI-NAND layout confirmed: ${GAR_IMX91S_NAND_LAYOUT_CONFIRMED:-0}
EOF
    install -m 0644 "${clean_work}/bundle-info.txt" "${clean_next}/bundle-info.txt"
    write_uuu_checksums "$clean_next"
    (
      cd "$clean_next"
      sha256sum -c checksums.sha256 >/dev/null
    )

    clean_backup="${clean_parent}/.${clean_name}.previous.$$"
    [[ ! -e "$clean_backup" ]] || \
      die "temporary artifact backup already exists: $clean_backup"
    mv -- "$artifact_root" "$clean_backup"
    if ! mv -- "$clean_next" "$artifact_root"; then
      mv -- "$clean_backup" "$artifact_root"
      clean_backup=""
      die "failed to install cleaned artifact tree"
    fi
    clean_next=""
    rm -rf -- "$clean_backup"
    clean_backup=""
    rm -rf -- "$clean_work"
    trap - EXIT
    cleaned_artifact=1
  elif [[ -e "$artifact_root" ]]; then
    echo "preserved artifact root not owned by the FRDM-IMX91S deployment: $artifact_root"
  fi
  if [[ "$cleaned_artifact" == 1 ]]; then
    echo "removed ${GAR_APP_ID} application output and restored the reusable BSP/UUU overlay"
  else
    echo "no FRDM-IMX91S application artifact to clean"
  fi
  exit 0
fi
[[ $# -eq 0 ]] || die "unknown argument: $1"

if [[ -e "$artifact_root" ]]; then
  [[ -d "$artifact_root" ]] || \
    die "artifact root exists and is not a directory: $artifact_root"
  if [[ -f "${artifact_root}/artifact.json" ]]; then
    artifact_is_this_deployment || \
      die "refusing to replace an artifact root owned by another deployment: $artifact_root"
  fi
fi

if command -v "$target_cc" >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
  make -B -C "$app_dir" "$GAR_APP_BUILD_GOAL" TARGET_CC="$target_cc"
else
  make_in_container "$GAR_APP_BUILD_GOAL"
fi

app_binary="$GAR_APP_BINARY"
[[ -x "$app_binary" ]] || die "target binary was not generated: $app_binary"

verify_aarch64() {
  local binary="$1"
  if command -v readelf >/dev/null 2>&1; then
    readelf -h "$binary" | grep -Eq 'Machine:[[:space:]]+AArch64'
    return
  fi
  require_build_container
  docker run --rm \
    --pull=never \
    -v "${repo_root}:/workspace:ro" \
    "$build_image" \
    readelf -h "/workspace/${app_relative}/${app_binary_relative}" \
    | grep -Eq 'Machine:[[:space:]]+AArch64'
}
verify_aarch64 "$app_binary" || die "application binary is not AArch64"

required_inputs=(
  "pub/u-boot/${GAR_IMX91S_RAM_BOOT_IMAGE}"
  "pub/u-boot/${GAR_IMX91S_NAND_BOOT_IMAGE}"
  "pub/kernel/Image"
  "pub/kernel/${GAR_IMX91S_DTB}"
  "pub/rootfs/rootfs.squashfs"
  "pub/rootfs/usr.local.tar.bz2"
  "pub/mfgtools/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst"
)
for relative in "${required_inputs[@]}"; do
  [[ -f "${artifact_root}/${relative}" ]] || \
    die "missing BSP component ${artifact_root}/${relative}; stage the existing IMX91S components first"
done

work_dir="$(mktemp -d "/tmp/${GAR_APP_ID}-frdm-imx91s.XXXXXX")"
next_root=""
backup_root=""
cleanup() {
  local status=$?
  trap - EXIT
  if [[ -n "$backup_root" && -e "$backup_root" && ! -e "$artifact_root" ]]; then
    mv -- "$backup_root" "$artifact_root"
  fi
  [[ -z "$next_root" || ! -e "$next_root" ]] || rm -rf -- "$next_root"
  rm -rf -- "$work_dir"
  exit "$status"
}
trap cleanup EXIT
component_input="${work_dir}/components"
app_package="${work_dir}/${GAR_APP_ID}"
overlay_root="${work_dir}/overlay"
staged_bundle="${work_dir}/staged"

for relative in "${required_inputs[@]}"; do
  if [[ "$relative" == "pub/rootfs/usr.local.tar.bz2" ]]; then
    continue
  fi
  install -D -m 0644 "${artifact_root}/${relative}" "${component_input}/${relative}"
done

install -D -m 0755 "$app_binary" "${app_package}/${GAR_APP_BINARY_NAME}"
install -D -m 0755 "$GAR_APP_ENTRYPOINT" "${app_package}/${GAR_APP_ENTRYPOINT_NAME}"
install -D -m 0644 "$GAR_APP_README" "${app_package}/README.md"
install -D -m 0644 \
  "$GAR_RUNTIME_I2C_CONFIG" \
  "${app_package}/${GAR_APP_I2C_CONFIG_DEST}"
install -D -m 0644 \
  "$GAR_RUNTIME_CONNECTIONS_CONFIG" \
  "${app_package}/${GAR_APP_CONNECTIONS_CONFIG_DEST}"
install -D -m 0644 \
  "$GAR_RUNTIME_SERVO_CONFIG" \
  "${app_package}/${GAR_APP_SERVO_CONFIG_DEST}"

python3 "$archive_tool" extract \
  --input "${artifact_root}/pub/rootfs/usr.local.tar.bz2" \
  --output "$overlay_root"

overlay_app="${overlay_root}${GAR_APP_INSTALL_DIR}"
rm -rf -- "$overlay_app"
mkdir -p "$overlay_app"
cp -a "${app_package}/." "$overlay_app/"

mkdir -p "${component_input}/pub/rootfs"
python3 "$archive_tool" create \
  --input "$overlay_root" \
  --output "${component_input}/pub/rootfs/usr.local.tar.bz2"

uuu_config="${GAR_IMX91S_UUU_CONFIG:-$target_local_config}"
if [[ ! -f "$uuu_config" ]]; then
  uuu_config="$GAR_TARGET_DEFAULT_CONFIG"
fi
stage_args=(
  --input-dir "$component_input"
  --output-dir "$staged_bundle"
  --config "$uuu_config"
)
if [[ "${GAR_IMX91S_NAND_LAYOUT_CONFIRMED:-0}" != "1" ]]; then
  [[ "${GAR_ALLOW_UNCONFIRMED_UUU:-0}" == "1" ]] || \
    die "NAND layout is unconfirmed; set GAR_ALLOW_UNCONFIRMED_UUU=1 only for an intentionally write-blocked review artifact"
  stage_args+=(--allow-unconfirmed)
fi
if [[ "${GAR_VALIDATE_UUU:-0}" == "1" ]]; then
  stage_args+=(--validate)
fi
export GAR_IMX91S_FACTORY_SCRIPT_NAME GAR_PRODUCT_NAME
"$uuu_stage" "${stage_args[@]}"
(
  cd "$staged_bundle"
  sha256sum -c checksums.sha256 >/dev/null
)

artifact_parent="$(dirname "$artifact_root")"
artifact_name="$(basename "$artifact_root")"
mkdir -p "$artifact_parent"
[[ ! -L "$artifact_root" ]] || die "refusing symlink artifact root: $artifact_root"
next_root="$(mktemp -d "${artifact_parent}/.${artifact_name}.next.XXXXXX")"
if [[ -d "$artifact_root" ]]; then
  cp -a "${artifact_root}/." "$next_root/"
fi
cp -a "${staged_bundle}/." "$next_root/"
rm -f -- "${next_root}/Factory-uuu-frdm-imx91s.lst"
rm -rf -- "${next_root}/.gar-base"

app_destination="${next_root}/files/${GAR_APP_ID}"
rm -rf -- "$app_destination"
mkdir -p "$app_destination"
cp -a "${app_package}/." "$app_destination/"
install -m 0644 \
  "$GAR_TARGET_ARTIFACT_MANIFEST" \
  "${next_root}/artifact.json"
if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
  [[ "$SOURCE_DATE_EPOCH" =~ ^[0-9]+$ ]] || die "SOURCE_DATE_EPOCH must be an integer"
  bundle_generated="$(date -u -d "@${SOURCE_DATE_EPOCH}" +%Y-%m-%dT%H:%M:%SZ)"
else
  bundle_generated="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi
cat > "${next_root}/bundle-info.txt" <<EOF
${GAR_PRODUCT_NAME:-GarServoPet} FRDM-IMX91S target bundle
Generated: ${bundle_generated}
SPI-NAND layout confirmed: ${GAR_IMX91S_NAND_LAYOUT_CONFIRMED:-0}
Application: ${GAR_APP_INSTALL_DIR}/${GAR_APP_ENTRYPOINT_NAME}
The same application payload is present in deploy.app and in the Product
rootfs overlay used by the UUU factory script.
EOF

[[ -x "${next_root}/files/${GAR_APP_ID}/${GAR_APP_ENTRYPOINT_NAME}" ]] || \
  die "staged application entrypoint is not executable"
[[ -x "${next_root}/files/${GAR_APP_ID}/${GAR_APP_BINARY_NAME}" ]] || \
  die "staged application binary is not executable"
[[ -f "${next_root}/${GAR_IMX91S_FACTORY_SCRIPT_NAME}" ]] || die "staged factory script is missing"
(
  cd "$next_root"
  sha256sum -c checksums.sha256 >/dev/null
)

backup_root="${artifact_parent}/.${artifact_name}.previous.$$"
[[ ! -e "$backup_root" ]] || die "temporary artifact backup already exists: $backup_root"
if [[ -e "$artifact_root" ]]; then
  mv -- "$artifact_root" "$backup_root"
fi
if ! mv -- "$next_root" "$artifact_root"; then
  [[ ! -e "$backup_root" ]] || mv -- "$backup_root" "$artifact_root"
  backup_root=""
  die "failed to install completed artifact tree"
fi
next_root=""
if [[ -e "$backup_root" ]]; then
  rm -rf -- "$backup_root"
fi
backup_root=""

echo "${GAR_APP_ID} AArch64 application: ${app_binary}"
echo "GAR target artifact: ${artifact_root}"
