#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
artifact_root="${1:-${repo_root}/artifacts/from-codespace}"
package_dir="${VIBE_REMOTE_PACKAGE_DIR:-sources/gar-vibe-ui/vibe-remote}"
package_root="${repo_root}/${package_dir}"
extension_out="${artifact_root}/files/vibe-remote-extension"
firmware_out="${artifact_root}/files/m5stickc-firmware"

rm -rf "${artifact_root}"
mkdir -p "${extension_out}"

cp "${package_root}/package.json" "${extension_out}/"
cp "${package_root}/package-lock.json" "${extension_out}/"
cp "${package_root}/README.md" "${extension_out}/"
cp -R "${package_root}/dist" "${extension_out}/dist"
cp -R "${package_root}/scripts" "${extension_out}/scripts"

firmware_json="null"
firmware_artifacts_dir="${package_root}/m5stickc-client/artifacts"
latest_firmware=""
if [[ -d "${firmware_artifacts_dir}" ]]; then
  latest_firmware="$(
    find "${firmware_artifacts_dir}" -mindepth 1 -maxdepth 1 -type d \
      | sort \
      | tail -n 1
  )"
fi

if [[ -n "${latest_firmware}" ]]; then
  mkdir -p "${firmware_out}"
  cp -R "${latest_firmware}/." "${firmware_out}/"
  firmware_json='"files/m5stickc-firmware"'
fi

cat > "${artifact_root}/artifact.json" <<EOF
{
  "name": "gar-vibe-remote-bundle",
  "deploy": {
    "vscodeExtension": {
      "files": [
        {
          "src": "files/vibe-remote-extension",
          "dest": "~/vibe-remote-extension"
        }
      ]
    },
    "m5stickcFirmware": {
      "artifact": ${firmware_json}
    }
  }
}
EOF

echo "Wrote artifact bundle: ${artifact_root}"
