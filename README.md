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
pub/u-boot/flash_gar_servo_pet_spinand.bin
pub/kernel/Image
pub/kernel/imx91-11x11-frdm-imx91s.dtb
pub/uuu-ram/flash_gar_servo_pet_spinand.bin.padded
pub/uuu-ram/Image.padded
pub/uuu-ram/imx91-11x11-frdm-imx91s.dtb.padded
pub/uuu-ram/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst.padded
pub/rootfs/rootfs.squashfs
pub/rootfs/usr.local.tar.bz2
pub/mfgtools/fsl-image-mfgtool-initramfs-imx_mfgtools.cpio.zst
```

This is deliberately component-based rather than a single `.wic` image. The
UUU script is board-specific: it RAM-boots the proven SD/manufacturing U-Boot,
installs the separate SPI-NAND image with `fspinand`, boots the manufacturing
initramfs, writes the raw kernel and DTB MTD partitions, then creates a
writable UBIFS `rootfs` volume from the Product SquashFS. The MTD indices and
names must match the fixed partitions in `imx91-11x11-frdm-imx91s.dts` before
a real write is enabled.

The UBIFS expansion deliberately ignores ownership stored in the Product
overlay archive and normalizes the deployed filesystem root to `root:root`
mode `0755`. The UUU command list verifies those attributes before reporting
completion. This prevents a host build UID from causing systemd-tmpfiles to
reject `/var`, `/tmp`, and `/run` as unsafe path transitions on first boot.

The reusable implementation is owned by the `frdm-imx91s` Target Pack. These
Product scripts are compatibility wrappers which supply GarServoPet filenames,
configuration, and output locations:

```bash
cp config/imx91s-uuu.env.example config/imx91s-uuu.env
# Generate and execute the read-only probe, then confirm its MTD table.
scripts/generate-imx91s-layout-probe.sh --config config/imx91s-uuu.env --validate
# Set GAR_IMX91S_NAND_LAYOUT_CONFIRMED=1 only after that confirmation.
scripts/stage-imx91s-uuu.sh --input-dir /path/to/built-components \
  --config config/imx91s-uuu.env --validate
```

`--allow-unconfirmed` produces a review bundle with a U-Boot `test 0 = 1`
command before the first NAND write. Set
`GAR_IMX91S_NAND_LAYOUT_CONFIRMED=1` only after the probe agrees with the DTS.
The generic implementation, board bring-up record, and troubleshooting matrix
are under `sources/gar-tools/targets/frdm-imx91s/`; Product-specific servo and
application information remains outside the Target Pack.

The component build follows the NXP BSP values already checked into the local
build notes: U-Boot `lf_v2024.04` with
`imx91_11x11_frdm_imx91s_spinand_defconfig`, Linux `lf-6.6.y` with the
FRDM-IMX91S DT patches, ATF `lf_v2.8`, and imx-mkimage
`lf-6.6.3_1.0.0`. The four LPDDR4 training binaries and NXP ELE firmware are
inputs to `flash_singleboot_spinand`; they are not invented or copied from the
Stella2 product. Build output can therefore be produced independently and
then staged into the UUU tree above.

When UUU is run through WSL2/usbipd, the generated component scripts use
chunked `FB: write` transfers with `FB[-t 30000]` by default. This avoids the
short fixed bulk timeout used by the older `FB: download` implementation and
copies each chunk into the correct RAM offset before booting Linux. The
generator also creates transfer-only copies under `pub/uuu-ram`, zero-padded
to the chunk boundary. This prevents the deterministic Fastboot timeout seen
on the final short chunk. The manufacturing initramfs remains a legacy U-Boot
ramdisk, so its header retains the authoritative payload size passed through
`booti`. The command-line option `uuu -T` only controls waiting for a USB
device at a stage change.
Override the transfer timeout or chunk size with
`GAR_UUU_TRANSFER_TIMEOUT_MS`/`GAR_UUU_TRANSFER_CHUNK_SIZE` in the local UUU
environment if the host link is slower.

The manufacturing initramfs is loaded at `GAR_IMX91S_INITRD_ADDR` (default
`0x85000000`). The U-Boot default `0x83800000` is not used because this image
extends across the FRDM-IMX91S ELE reserved range at `0x84120000`, which causes
the S400 fuse driver to fault during Linux device probing.

The example target id is `frdm-imx91s`. Select the target backend in `gar setup`
or the workspace configuration; the Target Pack chooses UUU, SSH, or another
registered backend through `defaultBackends.target`.

For USB-C boot verification, set the workspace `target.serial` to the first
CH342/CH343 debug-UART device. With the observed WSL2 adapter this is usually
`/dev/ttyACM0` (the second channel is `/dev/ttyACM1`).

For the UUU USB1 device under WSL2, bind bus `4-3` once from an elevated
Windows PowerShell and use auto-attach. The board changes from ROM
`1fc9:0159` to U-Boot fastboot `1fc9:0152` after the SDPS stage; without
auto-attach, UUU cannot see that second enumeration.

```powershell
usbipd bind --busid 4-3
usbipd attach --wsl --busid 4-3 --auto-attach
```

## Current status

The SPI-NAND factory path has been validated on hardware through NAND boot and
first-login service checks. Its reusable implementation is pinned through the
`gar-tools` submodule; generated artifacts remain ignored.

The browser simulator currently represents one PCA9685 board and four
individually identified SG90 servos. It intentionally does not render the FRDM-IMX91S: the VM and
GarServoPet application are the controller side of the simulation.
