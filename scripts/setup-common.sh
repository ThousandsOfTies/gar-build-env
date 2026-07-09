#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${repo_root}/config/common.env" ]]; then
  # shellcheck disable=SC1091
  source "${repo_root}/config/common.env"
fi

as_root() {
  if [[ "$(id -u)" == "0" ]]; then
    "$@"
  else
    sudo "$@"
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
      ccache \
      cmake \
      dfu-util \
      file \
      gcc-aarch64-linux-gnu \
      git \
      libffi-dev \
      libfuse3-dev \
      libfuse3-dev:arm64 \
      libssl-dev \
      libusb-1.0-0 \
      make \
      ninja-build \
      openssh-client \
      python3 \
      python3-pip \
      python3-venv
  fi
}

ensure_path_line() {
  local file="$1"
  local line="$2"

  touch "$file"
  if ! grep -Fqx "$line" "$file"; then
    printf '\n%s\n' "$line" >> "$file"
  fi
}

install_esp_idf() {
  if [[ "${GAR_INSTALL_ESP_IDF:-1}" != "1" ]]; then
    return
  fi

  local idf_path="${GAR_ESP_IDF_PATH:-${HOME}/esp-idf}"
  local idf_version="${GAR_ESP_IDF_VERSION:-v5.3.1}"

  if [[ ! -d "${idf_path}" ]]; then
    echo "Installing ESP-IDF for ESP32..."
    git clone -b "${idf_version}" --recursive https://github.com/espressif/esp-idf.git "${idf_path}"
    "${idf_path}/install.sh" esp32
    echo "ESP-IDF installed. Use 'source ${idf_path}/export.sh' to activate."
  fi
}

install_platformio() {
  if [[ "${GAR_INSTALL_PLATFORMIO:-1}" != "1" ]]; then
    return
  fi

  local venv_path="${GAR_PLATFORMIO_VENV:-${HOME}/.venvs/platformio}"
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
install_esp_idf
install_platformio
