# GarServoPet

GAR Product repository for a four-axis desk robot using the NXP
FRDM-IMX91S, a PCA9685 PWM controller, and four SG90 servos.

This parent repository pins every source revision needed for a reproducible
build. Application behavior lives in the `gar-servo-pet` child repository;
Product-specific hardware mappings and deployment settings live here.

## Layout

```text
GarServoPet/
  config/
    artifact-manifest.example.json
    common.env
    product.env
  hardware/
    README.md
    components.csv
    connections.csv
    i2c.csv
  panel/
    components/       # purchase-unit Web Components
    index.html
  scripts/
  sources/
    gar-servo-pet/    # application source submodule
    gar-tools/        # shared Target Pack and simulation tools submodule
  artifacts/          # generated output, ignored
```

## Ownership boundary

- `sources/gar-servo-pet` owns motion behavior, control APIs, and application
  code.
- `hardware` owns servo channel assignments, direction, pulse limits,
  calibration, components, and wiring for this Product.
- `sources/gar-tools/targets` owns reusable target provisioning and lifecycle
  recipes. It must not contain GarServoPet-specific servo calibration.
- GaplessAgentRuntime owns artifact capture, validation, and deployment
  contracts.

## Setup

Clone with the pinned child repositories:

```bash
git clone --recurse-submodules https://github.com/ThousandsOfTies/GarServoPet
cd GarServoPet
make setup
```

For an existing checkout:

```bash
git submodule update --init --recursive
```

The parent always records exact child commits. Commit and push a child change
before updating its submodule pointer here.

## GAR artifact contract

`config/artifact-manifest.example.json` uses the current Product-owned
`artifact.json` format with `deploy.app`. GAR adds `artifact-info.json` when it
captures the resulting artifact snapshot.

The example target id is `frdm-imx91s`. A reusable Target Pack for that board
still needs to be added to `gar-tools` before physical deployment is enabled.

## Current status

The repositories and ownership boundaries are initialized. Servo roles,
mechanical layout, PCA9685 bus/address selection, pulse limits, and power design
remain explicit design decisions for the next step.

The browser simulator currently represents one PCA9685 board and four
individually identified SG90 servos. It intentionally does not render the FRDM-IMX91S: the VM and
GarServoPet application are the controller side of the simulation.
