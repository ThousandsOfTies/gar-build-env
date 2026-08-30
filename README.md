# GarServoPet

GAR Product repository for a four-axis desk robot using an NXP FRDM-IMX91S or
Luckfox Lyra Plus controller, a PCA9685 PWM controller, and four SG90 servos.

This parent repository pins every source revision needed for a reproducible
build. Application behavior lives in the `gar-servo-pet` child repository;
Product-specific hardware mappings and deployment settings live here.

## Layout

```text
GarServoPet/
  config/
    common.env
    frdm-imx91s.env.example
    luckfox-rk3506.env.example
    deployments/
      frdm-imx91s.json
      frdm-imx91s.artifact.json
      luckfox-rk3506.json
      luckfox-rk3506.artifact.json
    product.env
  hardware/
    README.md
    bindings/
      frdm-imx91s.json
      luckfox-rk3506.json
    components.csv
    connections.csv
    i2c.csv
    profiles/frdm-imx91s/i2c.csv
    profiles/luckfox-rk3506/i2c.csv
  panel/
    components/       # purchase-unit Web Components
    index.html
  scripts/
    package-target.sh # target-independent deployment entrypoint
    targets/frdm-imx91s/
      device-tree/
      provisioning/uuu/
    targets/luckfox-rk3506/
  sources/
    gar-servo-pet/    # Application Capsule source submodule (app.json)
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

## Deployment capsules

The physical build is selected by a Deployment Profile instead of wiring an
application path directly into a board script:

- `sources/gar-servo-pet/app.json` declares the Application Capsule build
  goal, binary, runtime entrypoint, installation directory, and configuration
  destinations.
- `config/deployments/frdm-imx91s.json` composes that application with one
  target, hardware binding, runtime profiles, and artifact contract.
- `config/deployments/luckfox-rk3506.json` composes the same application and
  mechanical calibration with the Lyra Plus I2C1 binding and SSH artifact.
- `scripts/targets/frdm-imx91s` contains the Product-side Target Capsule. Its
  Device Tree and UUU composition sources stay behind this boundary.
- `scripts/targets/luckfox-rk3506` contains the Product-side ARMv7 build and
  guarded Lyra FIT Device Tree configuration hook.
- `scripts/package-target.sh` validates the composition and dispatches to the
  selected Target Capsule.

Inspect the composition without building or touching artifacts:

```bash
scripts/package-target.sh --deployment frdm-imx91s --describe
scripts/package-target.sh --deployment luckfox-rk3506 --describe
```

`GAR_DEPLOYMENT=<id>` is the environment equivalent. Controller replacement is
therefore limited to a binding, runtime profile, Deployment Profile, and Target
Capsule; it does not change the application build contract or servo calibration.

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

## Four-servo control application

The first physical-target application is a dependency-light C command line
controller at `sources/gar-servo-pet`. It reads the Product-owned I2C and servo
calibration CSV files instead of embedding FRDM pin, channel, direction, or
pulse assumptions in application code.

The checked-in `hardware/servo-calibration.csv` records the installed
four-corner mechanism measured on 2026-08-26. Channels 0 through 3 are
front-left, front-right, rear-left, and rear-right. Positive normalized motion
means arm-forward on both sides; the mirrored mounting is represented by the
per-channel direction. All four use 1500 us neutral, a conservative
1300..1700 us operating range inside the separately checked 1250..1750 us
envelope, and an initial 400 us/s rate limit.

On the target, use the bundled entrypoint:

```bash
cd /opt/gar/apps/gar-servo-pet
./run validate
./run probe
./run off

# One declared channel only; output is disabled automatically after 500 ms.
./run calibrate --channel 0 --pulse-us 1500 --confirm-pulse-us 1500 \
  --hold-ms 500 --ack-motion
```

After a row is measured and set to `calibrated=1`:

```bash
./run neutral servo-1 --hold-ms 500
./run move servo-1 --from-position 0 --position 250 \
  --duration-ms 500 --hold-ms 250 --ack-position-known
```

The start-position acknowledgement is required because PWM is disabled between
commands and software cannot observe whether a servo was moved by hand. Moving
all four to neutral is never implicit; it requires
`neutral all --hold-ms N --ack-all`. Calibration and stored endpoints are
bounded to 500..2500 us as a gross-input guard, but mechanical safety must still
be established from 1500 us in small unloaded steps.

Every motion command has a bounded runtime and finishes with PCA9685 outputs
disabled, including SIGINT/SIGTERM handling. This does not switch off the
external servo 5 V supply, and a process killed with SIGKILL cannot run its
cleanup path. Keep the mechanism unloaded during calibration.

The initial coordinated command is deliberately named `air-walk`: it is a
small diagonal-pair motion for a lifted chassis, not a validated ground gait.
It requires all four calibrated roles, a known neutral start, three explicit
acknowledgements, and returns to neutral with outputs disabled:

```bash
./run neutral all --hold-ms 1000 --ack-all
./run air-walk --amplitude 100 --cycles 1 --step-ms 750 --pause-ms 150 \
  --ack-all --ack-neutral-known --body-lifted
./run off
```

Amplitude is capped at 250 normalized units, so this commissioning sequence
uses at most one quarter of each configured calibrated travel. Ground-contact
motion remains a separate mechanical test and tuning step.

Build the AArch64 binary and merge it into the existing component-based UUU
bundle without rebuilding Linux or Yocto:

```bash
scripts/package-target.sh --deployment frdm-imx91s
```

`scripts/product-target-build.sh` remains as a compatibility entrypoint and
selects the same Deployment Profile.

Set `GAR_VALIDATE_UUU=1` (and `GAR_UUU_BIN` when it is outside `PATH`) to run
`uuu -dry` as part of the build. A confirmed local NAND layout remains required
for a deployable bundle. An intentionally write-blocked review bundle requires
the explicit `GAR_ALLOW_UNCONFIRMED_UUU=1` opt-in. Overlay archives are handled
by the checked-in safe Python tool. If the host lacks the AArch64 toolchain, the
hook uses an already-built local `gar-build-env:latest` Docker image and never
pulls an unreviewed replacement.

The hook writes both `artifacts/from-codespace/files/gar-servo-pet` for GAR's
`deploy.app` contract and the same `/opt/gar/apps/gar-servo-pet` payload inside
`pub/rootfs/usr.local.tar.bz2` for the UUU/SPI-NAND installation path. Existing
NXP U-Boot, kernel, rootfs, DTB, and manufacturing-initramfs components must
already be present under `artifacts/from-codespace`.

## Luckfox Lyra Plus build and deployment

The Lyra deployment uses the reusable `luckfox-rk3506` SSH/BusyBox Target Pack
and the same Application Capsule. Its Product binding selects RK3506 I2C1 as
`/dev/i2c-1` at 100 kHz: physical pin 17 is RM_IO11/SDA and physical pin 19 is
RM_IO10/SCL. Both are 3.3 V logic signals.

With the Luckfox SDK in the sibling workspace location
`../LuckFox/luckfox-lyra-sdk-250815`, build the SSH artifact with:

```bash
scripts/package-target.sh --deployment luckfox-rk3506
```

For another SDK location, copy `config/luckfox-rk3506.env.example` to the
ignored `config/luckfox-rk3506.env` and set `GAR_LUCKFOX_SDK_ROOT`. The capsule
uses Luckfox's `arm-none-linux-gnueabihf` compiler, forces a fresh static ARMv7
hard-float build, bundles the matching Device Tree utilities, and emits
`artifacts/from-codespace/artifact.json` plus
`files/gar-servo-pet/`. Switching back to NXP also forces recompilation, so the
shared application output path cannot retain the wrong architecture.

Prepare the board once with the reusable Target Pack, then build and deploy
through GAR using a workspace whose target is `luckfox-rk3506`:

```bash
gar target prepare --workspace <name>
gar target build --workspace <name>
gar target deploy --workspace <name>
```

On the first deploy, the constrained root hook verifies the exact Lyra Plus
model, saves the original boot partition, enables only I2C1 and its two header
pins in the installed FIT Device Tree, updates the FIT size/hash, and verifies
the write-back. GAR reports that a reboot is required instead of starting the
application against the old tree. After reboot, `/dev/i2c-1` must exist.

The boot service is intentionally non-actuating: no-argument `run` validates
configuration and waits without opening I2C. The lifecycle `health` hook also
does not access the PCA9685; use `./run probe` explicitly after wiring the
controller. Servo V+ still requires a separate suitably rated 5 V supply with
a common ground; do not power four servos from the Lyra header.

## GAR artifact contract

`config/deployments/frdm-imx91s.artifact.json` uses the current Product-owned
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
pub/kernel/imx91-11x11-frdm-imx91s-gar-servo-pet.dtb
pub/uuu-ram/flash_gar_servo_pet_spinand.bin.padded
pub/uuu-ram/Image.padded
pub/uuu-ram/imx91-11x11-frdm-imx91s-gar-servo-pet.dtb.padded
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

The reusable board protocol is owned by the `frdm-imx91s` Target Pack. The
Product Target Capsule supplies GarServoPet filenames, configuration, Device
Tree handling, and output locations; the top-level Product scripts are only
compatibility entrypoints:

```bash
cp config/frdm-imx91s.env.example config/frdm-imx91s.env
# Generate and execute the read-only probe, then confirm its MTD table.
scripts/generate-imx91s-layout-probe.sh --config config/frdm-imx91s.env --validate
# Set GAR_IMX91S_NAND_LAYOUT_CONFIRMED=1 only after that confirmation.
scripts/stage-imx91s-uuu.sh --input-dir /path/to/built-components \
  --config config/frdm-imx91s.env --validate
```

`--allow-unconfirmed` produces a review bundle with a U-Boot `test 0 = 1`
command before the first NAND write. Set
`GAR_IMX91S_NAND_LAYOUT_CONFIRMED=1` only after the probe agrees with the DTS.
The generic implementation, board bring-up record, and troubleshooting matrix
are under `sources/gar-tools/targets/frdm-imx91s/`. Product-specific Device
Tree and UUU composition sources are under
`scripts/targets/frdm-imx91s/`; servo and application data remain outside the
reusable Target Pack and controller capsule.

## PCA9685 expansion-header I2C

The NXP base DTB leaves the 40-pin header's I2C4 function disabled.
GarServoPet owns a small DT overlay that assigns pin 3 to LPI2C4 SDA and pin 5
to LPI2C4 SCL at 100 kHz. It also keeps the board's switched expansion-header
3.3 V and 5 V regulators enabled; the NXP base DT otherwise turns both off as
unclaimed rails during Linux boot. Generate the Product DTB without replacing
the NXP base file:

```bash
scripts/build-imx91s-dtb.sh
```

The output is
`artifacts/from-codespace/pub/kernel/imx91-11x11-frdm-imx91s-gar-servo-pet.dtb`.
The generator verifies the live node path, clock rate, both pinmux tuples, and
both always-on regulator properties after applying the overlay. It uses local
`dtc` tools when installed and an ephemeral Docker tool container otherwise.

To update an already provisioned board without rewriting its bootloader,
kernel, config, or rootfs, generate the guarded DTB-only UUU command list:

```bash
GAR_UUU_BIN=/home/user/.local/bin/uuu \
  scripts/generate-imx91s-dtb-update.sh --validate
```

Disconnect the external servo 5 V supply and leave the mechanism unloaded
during provisioning. The DTB update changes expansion-power and pinmux state
as Linux starts.

Put the board in Serial Downloader mode and run the generated
`artifacts/from-codespace/Update-dtb-gar-servo-pet.lst`. Success ends with
`GAR_IMX91S_DTB_UPDATE_COMPLETE`; then power-cycle in internal SPI-NAND boot
mode. The Linux alias for LPI2C4 is `i2c3`, so the expected interface is
`/dev/i2c-3`.

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
