#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

ensure_path_line() {
  local file="$1"
  local line="$2"

  touch "$file"
  if ! grep -Fqx "$line" "$file"; then
    printf '\n%s\n' "$line" >> "$file"
  fi
}

install_platformio() {
  local venv_path="${HOME}/.venvs/platformio"
  local bin_path="${HOME}/.local/bin"
  local path_line='export PATH="$HOME/.venvs/platformio/bin:$PATH"'

  if [[ ! -x "${venv_path}/bin/pio" ]]; then
    echo "Installing PlatformIO..."
    python3 -m venv "${venv_path}"
    "${venv_path}/bin/python" -m pip install --upgrade pip
    "${venv_path}/bin/pip" install --upgrade platformio
  fi

  ensure_path_line "${HOME}/.bashrc" "$path_line"
  mkdir -p "$bin_path"
  ln -sf "${venv_path}/bin/pio" "${bin_path}/pio"
  export PATH="${venv_path}/bin:${PATH}"
}

install_packages
make -C "${repo_root}" setup

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

install_platformio

echo "Gapless Agent Runtime build environment is ready."
