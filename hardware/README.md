# GarServoPet hardware

This directory owns hardware information specific to the GarServoPet Product.

## Product components

- NXP FRDM-IMX91S or Luckfox Lyra Plus development board
- One PCA9685 16-channel I2C PWM controller module
- Four individually connected SG90 servo motors

`components.csv` records the five simulated physical components. The selected
controller board is the physical deployment target, not a Product Web
Component: in EC2 or VirtualBox simulation its role is taken by the VM and
application.

`connections.csv` maps PCA9685 channels 0 through 3 to the four servo signal
inputs. The controller-specific portion is selected separately:

- `bindings/frdm-imx91s.json` and `profiles/frdm-imx91s/i2c.csv` select NXP
  LPI2C4, address `0x40`, and `/dev/i2c-3` on expansion-header pins 3/5.
- `bindings/luckfox-rk3506.json` and `profiles/luckfox-rk3506/i2c.csv` select
  Lyra Plus I2C1, address `0x40`, and `/dev/i2c-1`. Physical pin 17 is
  RM_IO11/SDA and pin 19 is RM_IO10/SCL.

Both bindings use 100 kHz and 3.3 V logic. The top-level `i2c.csv` is retained
as an identical legacy simulation input for the NXP profile. The deployment
composer checks that each selected CSV bus/device/address agrees with its
binding before a target-specific build starts.

`servo-calibration.csv` is the runtime calibration gate. The installed
four-corner chassis was measured on 2026-08-26 with the body raised and the
linkages unloaded. Channels 0 through 3 are front-left, front-right, rear-left,
and rear-right respectively. A positive normalized position moves an arm
toward the front of the chassis, so the left channels use `direction=-1` and
the right channels use `direction=1`. All four use a measured neutral of
1500 us and were checked without contact, binding, or continuous buzzing over
1250..1750 us. The configured operating range is deliberately narrower at
1300..1700 us, with an initial rate limit of 400 us/s and `calibrated=1`.

The NXP controller pinmux implementation is isolated in the FRDM-IMX91S
Product Target Capsule as
`scripts/targets/frdm-imx91s/device-tree/imx91s-gar-servo-pet-i2c4-overlay.dtso`.
It cannot be combined with an RGB display configuration that claims GPIO_IO02
and GPIO_IO03 for display VSYNC/HSYNC. The same overlay keeps the
PCAL6524-controlled expansion-header 3.3 V and 5 V regulators enabled; the NXP
base DT otherwise switches both rails off as unclaimed regulators during boot.
The binding and runtime CSV in this directory remain the authoritative
electrical contract. The 3.3 V rail powers PCA9685 logic only. Do not power
the servos from the header 5 V rail.

The Lyra pinmux is isolated in the Lyra Product Target Capsule as
`scripts/targets/luckfox-rk3506/rk3506-gar-servo-pet-i2c1-overlay.dts`. Its
guarded deployment hook patches the installed FIT Device Tree only after
checking the exact board model and keeps a one-time original boot-partition
backup. The overlay uses the official RM_IO10 I2C1 SCL function 32 and RM_IO11
I2C1 SDA function 33 with pull-ups. As on NXP, the 3.3 V header connection is
for PCA9685 logic; servo V+ must use the separate 5 V supply.

## Pending decisions

- Dedicated 5 V servo supply and current capacity
- Loaded travel and current measurements
- Gait, startup pose, and homing procedure

Do not widen the configured range from the short unloaded test alone. Record
loaded measurements before changing the pulse envelope or rate limit.

The servo supply must be separate from the controller-board supply, with a
shared signal ground. Final current capacity and protection must be selected
after measuring the actual SG90 units used in the build.
