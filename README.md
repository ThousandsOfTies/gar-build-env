# gar-build-env

Gapless Agent Runtime 用の Codespaces/devcontainer ビルド環境です。

## GarVibeRemote Branch

このブランチは Vibe Remote 製品用の devspace 定義です。共通 runtime は
`main` と同じまま、製品固有の設定だけをこのブランチに保持します。

```text
sources/gar-vibe-ui/          # product source submodule
config/product.env            # GarVibeRemote settings
scripts/product-setup.sh      # npm dependency setup
scripts/product-build.sh      # extension compile/typecheck/lint/test
scripts/product-artifacts.sh  # artifact bundle writer
scripts/product-clean.sh      # generated output cleanup
```

通常の入口:

```bash
make setup
make build
make artifacts
```

M5StickC firmware artifact も作る場合:

```bash
VIBE_BUILD_FIRMWARE=1 make build
make artifacts
```

製品ソースを更新したら、先に `sources/gar-vibe-ui` 側を commit/push し、
その後このリポジトリで submodule pointer を commit/push してください。

---

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
    product.env.example
  Makefile
  scripts/
    bootstrap.sh
    setup-common.sh
    setup-product.sh
  artifacts/             # generated output, ignored
```

## Setup

Codespaces 起動時は `.devcontainer/devcontainer.json` の `postCreateCommand` が
`scripts/post-create.sh` を実行します。実体は `scripts/bootstrap.sh` です。

起動時の流れ:

```text
scripts/setup-common.sh
scripts/setup-product.sh
  config/product.env があれば読む
  .gitmodules があれば git submodule update --init --recursive
  scripts/product-setup.sh が実行可能なら実行
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

## Product Branches

製品ブランチでは、共通シーケンスをなるべく触らず、個別定義だけを追加します。

```text
config/product.env
scripts/product-setup.sh
scripts/product-build.sh
scripts/product-artifacts.sh
scripts/product-clean.sh
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
scripts/product-setup.sh
scripts/product-build.sh
scripts/product-artifacts.sh
scripts/product-clean.sh
```

`make build` は `scripts/product-build.sh` があれば実行します。
`make artifacts` は `scripts/product-artifacts.sh` があれば実行します。

PlatformIO は Python 仮想環境 `~/.venvs/platformio` にインストールされ、
`~/.bashrc` に PATH が追加されます。
