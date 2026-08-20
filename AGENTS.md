# GarServoPet Agent Rules

This repository is the GarServoPet Product root. It owns the reproducible source
set, Product-specific hardware data, and GAR build/deployment configuration.

## Repository roles

- `sources/gar-servo-pet`: application behavior and motion logic.
- `sources/gar-tools`: reusable target and simulation tooling.
- `hardware`: GarServoPet-specific components, wiring, servo channel mapping,
  direction, neutral point, pulse limits, and mechanical calibration.
- `config`: Product build and artifact configuration.

Do not place Product-specific hardware CSV or calibration data under
`sources/gar-tools/targets`.

## Submodule workflow

Commit and push child repository changes before updating the parent pointer.
Do not treat submodules as generated or disposable directories.

## Artifact ownership

Product hooks generate `artifact.json` with `deploy.app`. GAR alone generates
the schema-v2 `artifact-info.json` provenance and checksum metadata.

Generated artifacts are not committed.
