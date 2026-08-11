# gar-build-env

Gapless Agent Runtime 用の Codespaces/devcontainer ビルド環境です。

このリポジトリは Codespaces/devcontainer の共通実行基盤です。

`main` は共通 devspace runtime だけを持ちます。製品ごとの設定は
`gar-build-env` の製品ブランチに保存します。製品ブランチは
`config/product.env`、任意の `scripts/product-*.sh`、必要なら
`sources/*` submodule を持ちます。

## Layout

```text
gar-build-env/
  .devcontainer/
  config/
    common.env
    artifact-manifest.example.json
    product.env.example
  Makefile
  scripts/
    bootstrap.sh
    setup-common.sh
    setup-product-branch.sh
    product-sim-build.sh.example
    product-sim-build.sh       # product branch
    product-target-build.sh    # product branch
  artifacts/             # generated output, ignored
```

## Setup

Codespaces 起動時は `.devcontainer/devcontainer.json` の `postCreateCommand` が
`scripts/post-create.sh` を実行します。実体は `scripts/bootstrap.sh` です。

起動時の流れ:

```text
scripts/setup-common.sh
scripts/setup-product-branch.sh
  config/product.env があれば読む
  .gitmodules があれば git submodule update --init --recursive
  scripts/product-install.sh が実行可能なら実行
```

手動で実行する場合:

```bash
make setup
```

製品ブランチ側で submodule を使っている場合に明示的に最新化するには:

```bash
make sync
```

`make setup` は製品ブランチに定義された設定を読み、必要な準備だけを実行します。
`.gitmodules` がある場合は、親リポジトリが記録している submodule commit を再現します。
`make sync` は branch checkout されている submodule だけ `git pull --ff-only` します。
`make build` と `make artifacts` はセットアップを自動実行しません。起動時セットアップは
Devcontainer の `postCreateCommand` に限定し、必要な場合だけ明示的に `make setup` を実行します。

## GAR Simulation Build Hook

`gar sim build` の入口は Codespaces 固有ではなく、ローカルまたは Codespaces 上で動く
GaplessAgentRuntime です。製品 branch で simulation build が必要な場合は、
`scripts/product-sim-build.sh.example` を `scripts/product-sim-build.sh` にコピーして
アプリ固有の build コマンドを定義してください。GAR はその script を呼び出します。

通常、製品 branch はアプリを `sources/<app>`、共有 simulation asset を
`sources/gar-tools` に submodule として持ちます。template の `GAR_SIM_APP_DIR` と
`GAR_TOOLS_DIR` はその配置を参照し、アプリ側の command には
`GAR_TOOLS_ROOT` として後者を渡せます。

## GarStream system topology

GarStream の system topology は RX parent の
`/path/to/GarStreamRx/gar-system.json` が所有します。TX/RX をまとめて操作する場合は
次を使います。

```bash
gar system build --file /path/to/GarStreamRx/gar-system.json --json
gar system deploy --file /path/to/GarStreamRx/gar-system.json --json
gar system start --file /path/to/GarStreamRx/gar-system.json --json
```

GAR が `/etc/gar/system/gar-stream-tx.env` へ注入する値は topology から得る runtime
設定です。UDP discoveryのrequest/announceは逆向きの2 linkとして宣言されます。これは
persistent target config の `/etc/gar/gar-stream-tx.env` と分離され、
artifact には persistent target config や machine IP を含めません。

## GAR Target Build Hook

`gar target build`は、選択したBuildEnvironmentで
`scripts/product-target-build.sh`を実行します。このhookは製品applicationだけをbuild・
stageし、出力先に`artifact.json`とdeploy対象fileを作ります。選択Target IDは
`GAR_TARGET`で渡されるため、対応していないTargetはhook側で明示的に失敗させます。

Raspberry Pi OS/systemd Targetでは、root管理のserviceやsimulation stubをartifactへ
含めません。application directory内に実行可能な`run`を置き、Target recipeが用意した
共通`gar-app@.service`から起動できる形にします。GarStreamTxは
`/opt/gar/apps/gar-stream-tx/run`をこのcontractのreference実装としています。

## Product Branches

製品ブランチでは、共通シーケンスをなるべく触らず、個別定義だけを追加します。

```text
config/product.env
scripts/product-install.sh
scripts/product-build.sh
scripts/product-artifacts.sh
scripts/product-clean.sh
scripts/product-sim-build.sh
scripts/product-target-build.sh
sources/* submodules
AGENTS.md
```

関連リポジトリを submodule として持つ製品ブランチでは、子リポジトリを先に
commit/push し、そのあと親の submodule pointer を更新してください。

```bash
cd path/to/submodule
git add -A
git commit -m "Update product repo"
git push

cd path/to/gar-build-env
git add path/to/submodule
git commit -m "Update product submodule pointer"
git push
```

## Product Build Hooks

`main` は製品固有のビルド手順を持ちません。製品ブランチで必要に応じて
次の hook を追加します。

```text
scripts/product-install.sh
scripts/product-build.sh
scripts/product-artifacts.sh
scripts/product-clean.sh
scripts/product-target-build.sh
```

`make build` は `scripts/product-build.sh` があれば実行します。
`make artifacts` は `scripts/product-artifacts.sh` があれば実行します。
`gar target build`は`scripts/product-target-build.sh`を直接呼び出します。
Artifact manifest は製品固有の定義です。必要な製品ブランチで
`config/artifact-manifest.example.json` を参考に、製品用の設定ファイルや
`scripts/product-artifacts.sh` を追加してください。

PlatformIO は Python 仮想環境 `~/.venvs/platformio` にインストールされ、
`~/.bashrc` に PATH が追加されます。

## GarStreamTx simulation

ブラウザの PC カメラは Web Panel から Bridge へ JPEG フレームとして入り、Bridge が
GStreamer と `v4l2loopback` を使って `/dev/video0` に YUY2 形式で書き込みます。
Tx アプリは実機と同じ `v4l2src device=/dev/video0` から映像を取得し、MJPEG/RTP/UDP
SourceとしてUDP 5601で自己広告します。GarStreamRxは検出したSourceをチャンネル一覧へ
保持し、選択したTXへlease付き送信要求を返します。TXは要求元IPのRTP port 5600へだけ
送信するため、TX側にRXのaddress設定はありません。

シミュレータ固有なのは `/dev/video0` を作る入力側だけです。実機では同じデバイスパスに
USB UVC カメラを接続し、カメラ固有の caps と I/O mode を環境変数
`GAR_CAMERA_CAPS` / `GAR_CAMERA_IO_MODE` で指定します。アプリとネットワーク経路は
シミュレータ・実機で共通です。

## Raspberry Pi 5 実機deploy

このproductの実機Targetは `raspberry-pi-5`、実機環境は `ssh_scp` を使用します。
初回だけTarget/OS recipeを適用し、その後は同じapplication directoryを更新します。

```bash
gar target prepare --workspace Local/GarStreamTx
gar target build --workspace Local/GarStreamTx
gar target deploy --workspace Local/GarStreamTx
```

`prepare`はRaspberry Pi OS上に共通の`gar` service account、Python/GStreamerの
reference runtime、限定deploy helper、`gar-app@.service`を導入します。製品artifactは
simulation stubや独自のroot service fileを持たず、実機とsimulationで共通のPython
moduleと、標準entry point `/opt/gar/apps/gar-stream-tx/run`だけを配置します。

TXはhostnameを既定のSource名として自己広告するため、初回deployに設定入力は不要です。
カメラやLCD、Source表示名を上書きしたい場合だけ、同梱exampleから任意envを作ります。

```bash
ssh raspi5
sudo install -D -m 0644 \
  /opt/gar/apps/gar-stream-tx/gar-stream-tx.env.example \
  /etc/gar/gar-stream-tx.env
sudo editor /etc/gar/gar-stream-tx.env
sudo systemctl restart gar-app@gar-stream-tx.service
systemctl status gar-app@gar-stream-tx.service --no-pager
```

boot時は`gar-app@gar-stream-tx.service`として自動起動します。Target recipeを
再適用してもSSH鍵や任意の`/etc/gar/gar-stream-tx.env`は消えません。同一LANでは
RXが自動検出し、network越しではRX側のdiscovery peer設定からTXへqueryします。
