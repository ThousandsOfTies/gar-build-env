# agp-build-env

AgentCockpit 関連の Codespaces/devcontainer 起動用リポジトリです。

Codespaces 起動後、`postCreateCommand` が `scripts/post-create.sh` を実行し、以下のリポジトリを `repos/` 配下へ clone します。通常、ユーザーがこのスクリプトを直接実行する必要はありません。

- `ThousandsOfTies/agp-tools`
- `ThousandsOfTies/embedded-poc-app`

## Layout After Codespaces Setup

```text
agp-build-env/
  repos/
    agp-tools/
    embedded-poc-app/
```

## Manual Setup

Codespaces 外で同じ構成にしたい場合だけ、手動で実行します。

```bash
bash scripts/post-create.sh
```
