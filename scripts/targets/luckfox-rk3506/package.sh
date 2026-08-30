#!/usr/bin/env bash
# Luckfox Lyra Plus Target Capsule: cross-build the selected Application
# Capsule for RK3506/armv7 and produce GAR's SSH application artifact.
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

# Target-local settings may select an SDK, but cannot replace the validated
# deployment composition supplied by package_target.py.
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

# shellcheck disable=SC1090
source "$GAR_TARGET_DEFAULT_CONFIG"
if [[ -f "$GAR_TARGET_LOCAL_CONFIG" ]]; then
  # shellcheck disable=SC1090
  source "$GAR_TARGET_LOCAL_CONFIG"
fi

die() {
  echo "luckfox-rk3506 package: $*" >&2
  exit 1
}

[[ "$GAR_TARGET" == "luckfox-rk3506" ]] || \
  die "deployment target must be luckfox-rk3506: $GAR_TARGET"
[[ "$GAR_PRODUCT_ID" == "gar-servo-pet" ]] || \
  die "deployment product must be gar-servo-pet: $GAR_PRODUCT_ID"
[[ "$GAR_APP_ID" == "gar-servo-pet" ]] || \
  die "this Product Target Capsule expects gar-servo-pet: $GAR_APP_ID"
[[ "$GAR_TARGET_ARTIFACT_KIND" == "ssh-app" ]] || \
  die "deployment artifact kind must be ssh-app: $GAR_TARGET_ARTIFACT_KIND"

app_dir="$GAR_APP_ROOT"
artifact_root_requested="${GAR_ARTIFACT_ROOT:-${repo_root}/artifacts/from-codespace}"
if [[ "$artifact_root_requested" != /* ]]; then
  artifact_root_requested="${repo_root}/${artifact_root_requested}"
fi
[[ ! -L "$artifact_root_requested" ]] || \
  die "refusing symlink artifact root: $artifact_root_requested"
artifact_root="$(realpath -m "$artifact_root_requested")"
repo_parent="$(dirname "$repo_root")"
case "$artifact_root" in
  /|/home|/home/user|"$repo_parent"|"$repo_root") \
    die "refusing unsafe artifact root: $artifact_root" ;;
esac
case "$artifact_root" in
  "${repo_root}/"*|/tmp/gar-*) ;;
  *)
    [[ "${GAR_ALLOW_EXTERNAL_ARTIFACT_ROOT:-0}" == 1 ]] || \
      die "external artifact root requires GAR_ALLOW_EXTERNAL_ARTIFACT_ROOT=1: $artifact_root"
    ;;
esac

case "$app_dir" in
  "${repo_root}/"*) ;;
  *) die "application directory must be inside the Product repository: $app_dir" ;;
esac
case "$GAR_APP_BINARY" in
  "${app_dir}/"*) ;;
  *) die "application binary must be inside the Application Capsule: $GAR_APP_BINARY" ;;
esac

capsule_dir="${repo_root}/scripts/targets/luckfox-rk3506"
target_configurer="${capsule_dir}/configure-target"
i2c_overlay="${capsule_dir}/rk3506-gar-servo-pet-i2c1-overlay.dts"
health_hook="${capsule_dir}/health"

required_files=(
  "$GAR_DEPLOYMENT_PROFILE"
  "$GAR_HARDWARE_BINDING"
  "$GAR_TARGET_ARTIFACT_MANIFEST"
  "$GAR_APP_ENTRYPOINT"
  "$GAR_APP_README"
  "$GAR_RUNTIME_I2C_CONFIG"
  "$GAR_RUNTIME_CONNECTIONS_CONFIG"
  "$GAR_RUNTIME_SERVO_CONFIG"
  "$target_configurer"
  "$i2c_overlay"
  "$health_hook"
)
for required in "${required_files[@]}"; do
  [[ -f "$required" ]] || die "required input is missing: $required"
done
[[ -f "${app_dir}/Makefile" ]] || die "application Makefile is missing"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

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

artifact_is_replaceable_product_output() {
  [[ -f "${artifact_root}/artifact.json" ]] || return 1
  python3 - "${artifact_root}/artifact.json" "$GAR_APP_ID" "$GAR_APP_INSTALL_DIR" <<'PY'
import json
import sys
from pathlib import Path

path, app, destination = sys.argv[1:]
try:
    manifest = json.loads(Path(path).read_text(encoding="utf-8"))
    files = manifest["deploy"]["app"]["files"]
except (OSError, ValueError, KeyError, TypeError):
    raise SystemExit(1)
expected = {"src": f"files/{app}", "dest": destination, "mode": "0755"}
known_targets = {"frdm-imx91s", "luckfox-rk3506"}
raise SystemExit(0 if manifest.get("target") in known_targets and expected in files else 1)
PY
}

if [[ "${1:-}" == "clean" ]]; then
  if command -v make >/dev/null 2>&1; then
    make -C "$app_dir" clean
  fi
  if [[ -e "$artifact_root" ]]; then
    [[ ! -L "$artifact_root" ]] || die "refusing symlink artifact root: $artifact_root"
    if artifact_is_this_deployment; then
      rm -rf -- "$artifact_root"
      echo "removed Luckfox Lyra artifact: $artifact_root"
    else
      echo "preserved artifact root owned by another deployment: $artifact_root"
    fi
  fi
  exit 0
fi
[[ $# -eq 0 ]] || die "unknown argument: $1"

if [[ -e "$artifact_root" ]]; then
  [[ -d "$artifact_root" ]] || die "artifact root exists and is not a directory: $artifact_root"
  artifact_is_replaceable_product_output || \
    die "refusing to replace an artifact root not owned by a known GarServoPet deployment: $artifact_root"
fi

sdk_root="${GAR_LUCKFOX_SDK_ROOT:-${LUCKFOX_LYRA_SDK_ROOT:-}}"
if [[ -z "$sdk_root" && -d "${repo_root}/../LuckFox/luckfox-lyra-sdk-250815" ]]; then
  sdk_root="$(realpath "${repo_root}/../LuckFox/luckfox-lyra-sdk-250815")"
fi
triple="${GAR_LUCKFOX_TRIPLE:-arm-none-linux-gnueabihf}"
toolchain_bin="${GAR_LUCKFOX_TOOLCHAIN_BIN:-}"
runtime_root="${GAR_LUCKFOX_RUNTIME_ROOT:-}"
if [[ -n "$sdk_root" ]]; then
  toolchain_bin="${toolchain_bin:-${sdk_root}/prebuilts/gcc/linux-x86/arm/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin}"
  runtime_root="${runtime_root:-${sdk_root}/output/buildroot/target}"
fi
if [[ -n "$toolchain_bin" ]]; then
  toolchain_bin="$(realpath -m "$toolchain_bin")"
fi
if [[ -n "$runtime_root" ]]; then
  runtime_root="$(realpath -m "$runtime_root")"
fi

target_cc="${TARGET_CC:-}"
if [[ -z "$target_cc" && -n "$toolchain_bin" ]]; then
  target_cc="${toolchain_bin}/${triple}-gcc"
elif [[ -z "$target_cc" ]]; then
  target_cc="$(command -v "${triple}-gcc" || true)"
fi
if [[ -n "$target_cc" && "$target_cc" != */* ]]; then
  target_cc="$(command -v "$target_cc" || true)"
fi
[[ -n "$target_cc" && -x "$target_cc" ]] || {
  cat >&2 <<EOF
luckfox-rk3506 package: official RK3506 compiler was not found.
Set GAR_LUCKFOX_SDK_ROOT in config/luckfox-rk3506.env, or set
GAR_LUCKFOX_TOOLCHAIN_BIN and GAR_LUCKFOX_RUNTIME_ROOT directly.
EOF
  exit 1
}
[[ -n "$runtime_root" && -d "$runtime_root" ]] || \
  die "Luckfox Buildroot target runtime is missing: ${runtime_root:-unset}"
case "$(uname -m)" in
  x86_64|amd64) ;;
  *) die "the official Luckfox SDK compiler requires an x86_64 build host" ;;
esac

readelf_tool="${GAR_LUCKFOX_READELF:-}"
if [[ -z "$readelf_tool" && -n "$toolchain_bin" && -x "${toolchain_bin}/${triple}-readelf" ]]; then
  readelf_tool="${toolchain_bin}/${triple}-readelf"
elif [[ -z "$readelf_tool" ]]; then
  readelf_tool="$(command -v readelf || true)"
fi
if [[ -n "$readelf_tool" && "$readelf_tool" != */* ]]; then
  readelf_tool="$(command -v "$readelf_tool" || true)"
fi
[[ -n "$readelf_tool" && -x "$readelf_tool" ]] || die "readelf is required"

# The application manifest uses one target output path for every controller.
# Force recompilation so switching from AArch64 to ARMv7 cannot reuse a stale
# binary merely because its source timestamps are unchanged.
make -B -C "$app_dir" "$GAR_APP_BUILD_GOAL" \
  TARGET_CC="$target_cc" TARGET_LDFLAGS=-static
[[ -x "$GAR_APP_BINARY" ]] || die "target binary was not generated: $GAR_APP_BINARY"

strip_tool="${GAR_LUCKFOX_STRIP:-}"
if [[ -z "$strip_tool" && -n "$toolchain_bin" && -x "${toolchain_bin}/${triple}-strip" ]]; then
  strip_tool="${toolchain_bin}/${triple}-strip"
fi
if [[ -n "$strip_tool" && "$strip_tool" != */* ]]; then
  strip_tool="$(command -v "$strip_tool" || true)"
fi
if [[ -n "$strip_tool" ]]; then
  "$strip_tool" "$GAR_APP_BINARY"
fi

header="$($readelf_tool -h "$GAR_APP_BINARY")"
attributes="$($readelf_tool -A "$GAR_APP_BINARY")"
program_headers="$($readelf_tool -l "$GAR_APP_BINARY")"
dynamic_section="$($readelf_tool -d "$GAR_APP_BINARY" 2>/dev/null || true)"
grep -Eq 'Class:[[:space:]]+ELF32' <<<"$header" || die "application binary is not ELF32"
grep -Eq 'Machine:[[:space:]]+ARM' <<<"$header" || die "application binary is not ARM"
grep -Eq 'Tag_CPU_arch:[[:space:]]+v7' <<<"$attributes" || die "application binary is not ARMv7"
grep -Eq 'Tag_ABI_VFP_args:[[:space:]]+VFP registers' <<<"$attributes" || \
  die "application binary does not use the gnueabihf ABI"
if grep -q 'INTERP' <<<"$program_headers"; then
  die "application binary is dynamically linked"
fi
if grep -q 'NEEDED' <<<"$dynamic_section"; then
  die "application binary has shared-library dependencies"
fi

dt_tools=(dtc fdtget fdtoverlay fdtput)
for tool in "${dt_tools[@]}"; do
  [[ -x "${runtime_root}/usr/bin/${tool}" ]] || \
    die "Luckfox runtime Device Tree tool is missing: ${runtime_root}/usr/bin/${tool}"
  tool_header="$($readelf_tool -h "${runtime_root}/usr/bin/${tool}")"
  grep -Eq 'Class:[[:space:]]+ELF32' <<<"$tool_header" || \
    die "Luckfox runtime tool is not ELF32: $tool"
  grep -Eq 'Machine:[[:space:]]+ARM' <<<"$tool_header" || \
    die "Luckfox runtime tool is not ARM: $tool"
done
libfdt_source="$(readlink -f "${runtime_root}/usr/lib/libfdt.so.1" 2>/dev/null || true)"
[[ -n "$libfdt_source" && -f "$libfdt_source" ]] || \
  die "Luckfox runtime libfdt.so.1 is missing"
case "$libfdt_source" in
  "${runtime_root}/"*) ;;
  *) die "libfdt resolves outside the Luckfox runtime: $libfdt_source" ;;
esac
libfdt_header="$($readelf_tool -h "$libfdt_source")"
grep -Eq 'Class:[[:space:]]+ELF32' <<<"$libfdt_header" || \
  die "Luckfox runtime libfdt is not ELF32"
grep -Eq 'Machine:[[:space:]]+ARM' <<<"$libfdt_header" || \
  die "Luckfox runtime libfdt is not ARM"

work_dir="$(mktemp -d "/tmp/${GAR_APP_ID}-luckfox-rk3506.XXXXXX")"
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

app_package="${work_dir}/${GAR_APP_ID}"
install -D -m 0755 "$GAR_APP_BINARY" "${app_package}/${GAR_APP_BINARY_NAME}"
install -D -m 0755 "$GAR_APP_ENTRYPOINT" "${app_package}/${GAR_APP_ENTRYPOINT_NAME}"
install -D -m 0644 "$GAR_APP_README" "${app_package}/README.md"
install -D -m 0644 "$GAR_RUNTIME_I2C_CONFIG" "${app_package}/${GAR_APP_I2C_CONFIG_DEST}"
install -D -m 0644 "$GAR_RUNTIME_CONNECTIONS_CONFIG" "${app_package}/${GAR_APP_CONNECTIONS_CONFIG_DEST}"
install -D -m 0644 "$GAR_RUNTIME_SERVO_CONFIG" "${app_package}/${GAR_APP_SERVO_CONFIG_DEST}"
install -D -m 0755 "$target_configurer" "${app_package}/configure-target"
install -D -m 0755 "$health_hook" "${app_package}/health"
install -D -m 0644 "$i2c_overlay" "${app_package}/$(basename "$i2c_overlay")"
for tool in "${dt_tools[@]}"; do
  install -D -m 0755 "${runtime_root}/usr/bin/${tool}" "${app_package}/tools/${tool}"
done
install -D -m 0644 "$libfdt_source" "${app_package}/lib/libfdt.so.1"

artifact_parent="$(dirname "$artifact_root")"
artifact_name="$(basename "$artifact_root")"
mkdir -p "$artifact_parent"
[[ ! -L "$artifact_root" ]] || die "refusing symlink artifact root: $artifact_root"
next_root="$(mktemp -d "${artifact_parent}/.${artifact_name}.next.XXXXXX")"
mkdir -p "${next_root}/files/${GAR_APP_ID}"
cp -a "${app_package}/." "${next_root}/files/${GAR_APP_ID}/"
install -m 0644 "$GAR_TARGET_ARTIFACT_MANIFEST" "${next_root}/artifact.json"

if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
  [[ "$SOURCE_DATE_EPOCH" =~ ^[0-9]+$ ]] || die "SOURCE_DATE_EPOCH must be an integer"
  bundle_generated="$(date -u -d "@${SOURCE_DATE_EPOCH}" +%Y-%m-%dT%H:%M:%SZ)"
else
  bundle_generated="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi
cat >"${next_root}/bundle-info.txt" <<EOF
${GAR_PRODUCT_NAME:-GarServoPet} Luckfox Lyra Plus target bundle
Generated: ${bundle_generated}
Target ABI: ARMv7 hard-float (gnueabihf), static application
Application: ${GAR_APP_INSTALL_DIR}/${GAR_APP_ENTRYPOINT_NAME}
Target configuration: guarded I2C1 FIT Device Tree update; first deploy may require reboot
EOF

[[ -x "${next_root}/files/${GAR_APP_ID}/${GAR_APP_ENTRYPOINT_NAME}" ]] || \
  die "staged application entrypoint is not executable"
[[ -x "${next_root}/files/${GAR_APP_ID}/${GAR_APP_BINARY_NAME}" ]] || \
  die "staged application binary is not executable"
[[ -x "${next_root}/files/${GAR_APP_ID}/configure-target" ]] || \
  die "staged target configuration hook is not executable"
[[ -x "${next_root}/files/${GAR_APP_ID}/health" ]] || \
  die "staged health hook is not executable"

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
rm -rf -- "$work_dir"
trap - EXIT

echo "${GAR_APP_ID} ARMv7 application: ${GAR_APP_BINARY}"
echo "GAR target artifact: ${artifact_root}"
