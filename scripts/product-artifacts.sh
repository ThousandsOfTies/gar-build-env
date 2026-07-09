#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
artifact_root="${1:-${repo_root}/artifacts/from-codespace}"
package_dir="${VIBE_REMOTE_PACKAGE_DIR:-sources/gar-vibe-ui/vibe-remote}"
package_root="${repo_root}/${package_dir}"
manifest_path="${repo_root}/${PRODUCT_ARTIFACT_MANIFEST:-config/artifact-manifest.json}"
extension_out="${artifact_root}/files/vibe-remote-extension"
firmware_out="${artifact_root}/files/m5stickc-firmware"

if [[ ! -f "${manifest_path}" ]]; then
  echo "missing artifact manifest: ${manifest_path}" >&2
  exit 1
fi

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

python3 - "${manifest_path}" "${artifact_root}/artifact.json" "${firmware_json}" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
firmware_artifact = json.loads(sys.argv[3])

payload = json.loads(manifest_path.read_text(encoding="utf-8"))
payload.setdefault("deploy", {}).setdefault("m5stickcFirmware", {})["artifact"] = firmware_artifact
output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

echo "Wrote artifact bundle: ${artifact_root}"
