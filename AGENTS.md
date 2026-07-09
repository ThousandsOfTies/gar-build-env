# gar-build-env Agent Rules

This repository is the GAR Codespaces/devcontainer runtime. Product-specific
configuration lives on long-lived product branches of this repository.

## GarVibeRemote Branch

This branch configures the Vibe Remote product devspace.

- Product source submodule: `sources/gar-vibe-ui`
- Package root: `sources/gar-vibe-ui/vibe-remote`
- Setup hook: `scripts/product-setup.sh`
- Build hook: `scripts/product-build.sh`
- Artifact hook: `scripts/product-artifacts.sh`

Use `make setup`, `make build`, and `make artifacts` from the repository root.
Set `VIBE_BUILD_FIRMWARE=1` when the M5StickC firmware package should also be
built. Otherwise the default build focuses on the VS Code extension and bridge.

When editing product source, commit and push `sources/gar-vibe-ui` first, then
commit the parent submodule pointer in this repository.

## Roles

- `main`: common devspace runtime, setup sequence, shared defaults.
- Product branches: product-specific config, optional `sources/*` submodules,
  and setup/build hooks.
- Submodules, when present on a product branch: official editable source
  repositories, not ignored scratch space.

## Setup Flow

Codespaces runs `scripts/post-create.sh`, which delegates to:

```text
scripts/bootstrap.sh
  scripts/setup-common.sh
  scripts/setup-product.sh
```

`setup-product.sh` is intentionally optional-file friendly:

```bash
[ -f config/product.env ] && source config/product.env
[ -f .gitmodules ] && git submodule update --init --recursive
[ -x scripts/product-setup.sh ] && scripts/product-setup.sh
```

## Product Branches

Do not add product-specific source repositories to `main`. Put each product's
repository set, config, and setup/build hooks on that product's branch.

## Submodule Edits

On product branches that use submodules, commit and push the child repository
first, then commit the parent submodule pointer.

```bash
cd path/to/submodule
git add -A
git commit -m "Describe child repo change"
git push

cd path/to/gar-build-env
git add path/to/submodule
git commit -m "Update <repo> submodule pointer"
git push
```

Do not treat product-branch submodules as disposable generated directories. They
are canonical product repositories for AI-assisted edits.
