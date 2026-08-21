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
`artifact.json` format with `deploy.app`, a single factory UUU script in
`deploy.image`, and the script's component files in `deploy.uuu`. The IMX91S
UUU Target executes the script from the artifact root; GAR adds
`artifact-info.json` when it captures the resulting artifact snapshot.

The intended IMX91S artifact shape is:

```text
Factory-uuu-gar-servo-pet.lst
pub/u-boot/flash_gar_servo_pet.bin
pub/rootfs/rootfs.squashfs
pub/rootfs/usr.local.tar.bz2
pub/mfgtools/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst
```

This is deliberately component-based rather than a single `.wic` image. The
UUU script must be board-specific: it owns the SDP/FBK sequence, partition
numbers, overlay/storage mounts, and factory updater initialization.

The example target id is `frdm-imx91s`. Select the target backend in `gar setup`
or the workspace configuration; the Target Pack chooses UUU, SSH, or another
registered backend through `defaultBackends.target`.

For USB-C boot verification, set the workspace `target.serial` to the first
CH343 debug-UART device (for example `/dev/ttyCH343USB0`).

## Current status

The repositories and ownership boundaries are initialized. Servo roles,
mechanical layout, PCA9685 bus/address selection, pulse limits, and power design
remain explicit design decisions for the next step.

The browser simulator currently represents one PCA9685 board and four
individually identified SG90 servos. It intentionally does not render the FRDM-IMX91S: the VM and
GarServoPet application are the controller side of the simulation.
