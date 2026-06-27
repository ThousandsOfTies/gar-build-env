# gar-build-env

Gapless Agent Runtime 関連の Codespaces/devcontainer 起動用リポジトリです。

Codespaces 起動後、`postCreateCommand` が `scripts/post-create.sh` を実行し、以下のリポジトリを `repos/` 配下へ clone します。通常、ユーザーがこのスクリプトを直接実行する必要はありません。

- `ThousandsOfTies/gar-tools`
- `ThousandsOfTies/embedded-poc-app`
- `ThousandsOfTies/gar-vibe-ui`

また、ARM64 Linux artifact 用のクロスコンパイラと、ESP32/M5Stack firmware build 用の
PlatformIO を準備します。PlatformIO は Python 仮想環境
`~/.venvs/platformio` にインストールされ、`~/.bashrc` に PATH が追加されます。

## Layout After Codespaces Setup

```text
gar-build-env/
  repos/
    gar-tools/
    embedded-poc-app/
    gar-vibe-ui/
```

## Build

Codespaces では `repos/` 配下の repo を使い、WSL の `/home/user/Yurufuwa` 直下では sibling repo を使います。参照元 GitHub は同じなので、どちらでも同じ Makefile ターゲットでビルドできます。

```bash
make build
make artifacts
```

WSL 直下で実行する場合も `aarch64-linux-gnu-gcc` などのクロスビルド依存が必要です。未導入の場合は Codespaces で実行するか、`scripts/post-create.sh` 相当のセットアップを行ってください。

`make artifacts` はビルドも実行し、`artifacts/from-codespace/` に deploy 用 bundle を作成します。

```text
artifacts/from-codespace/
  artifact.json
  files/
    sensor_demo
    cuse_i2c
    cuse_spi
    web-bridge/
```

M5Stack / M5StickC firmware をビルドする場合:

```bash
cd repos/gar-vibe-ui/vibe-remote/m5stack-client
make vm-package PIO_ENV=m5stickc-plus2-vibe-min
```

artifact は `repos/gar-vibe-ui/vibe-remote/m5stack-client/artifacts/` 配下に作成されます。

## Manual Setup

Codespaces 外で同じ構成にしたい場合だけ、手動で実行します。

```bash
bash scripts/post-create.sh
```
