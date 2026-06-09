#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_dir="${repo_root}/repos"

as_root() {
  if [[ "$(id -u)" == "0" ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

install_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    local apt=(apt-get)
    if [[ "$(id -u)" != "0" ]]; then
      apt=(sudo apt-get)
    fi

    as_root dpkg --add-architecture arm64
    configure_arm64_apt_sources

    "${apt[@]}" update
    "${apt[@]}" install -y \
      build-essential \
      file \
      gcc-aarch64-linux-gnu \
      git \
      libfuse3-dev \
      libfuse3-dev:arm64 \
      make \
      openssh-client \
      python3 \
      python3-pip \
      python3-venv \
      cmake \
      ninja-build \
      ccache \
      libffi-dev \
      libssl-dev \
      dfu-util \
      libusb-1.0-0
  fi
}

configure_arm64_apt_sources() {
  local sources_file="/etc/apt/sources.list.d/ubuntu.sources"
  local arm64_sources_file="/etc/apt/sources.list.d/ubuntu-ports-arm64.sources"

  if [[ -f "$sources_file" ]] && ! grep -q "^Architectures:" "$sources_file"; then
    as_root cp "$sources_file" "${sources_file}.bak-gar-build-env"
    as_root sed -i "/^Types: deb/a Architectures: amd64" "$sources_file"
  fi

  local tmp_sources
  tmp_sources="$(mktemp)"
  cat > "$tmp_sources" <<'EOF'
Types: deb
Architectures: arm64
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
Architectures: arm64
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: noble-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
  as_root install -m 644 "$tmp_sources" "$arm64_sources_file"
  rm -f "$tmp_sources"
}

clone_or_update() {
  local url="$1"
  local name="$2"
  local dst="${repos_dir}/${name}"

  if [[ -d "${dst}/.git" ]]; then
    git -C "${dst}" pull --ff-only
  else
    git clone "${url}" "${dst}"
  fi
}

install_packages
mkdir -p "${repos_dir}"

clone_or_update "https://github.com/ThousandsOfTies/gar-tools.git" "gar-tools"
clone_or_update "https://github.com/ThousandsOfTies/embedded-poc-app.git" "embedded-poc-app"

install_esp_idf() {
  local idf_path="${HOME}/esp-idf"
  if [[ ! -d "${idf_path}" ]]; then
    echo "Installing ESP-IDF for ESP32..."
    git clone -b v5.3.1 --recursive https://github.com/espressif/esp-idf.git "${idf_path}"
    "${idf_path}/install.sh" esp32
    echo "ESP-IDF installed. Use 'source ~/esp-idf/export.sh' to activate."
  fi
}

install_esp_idf

echo "Gapless Agent Runtime build environment is ready."
