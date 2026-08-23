# GarServoPet hardware

This directory owns hardware information specific to the GarServoPet Product.

## Confirmed components

- NXP FRDM-IMX91S development board
- One PCA9685 16-channel I2C PWM controller module
- Four individually connected SG90 servo motors

`components.csv` records the five simulated physical components. The FRDM-IMX91S is
the physical deployment target, not a Product Web Component: in EC2 or
VirtualBox simulation its role is taken by the VM and application.

`connections.csv` maps PCA9685 channels 0 through 3 to the four servo signal
inputs. `i2c.csv` selects address `0x40` on `/dev/i2c-3`. The Product DT
overlay enables SoC LPI2C4 on expansion-header pin 3 (SDA) and pin 5 (SCL);
the Linux `i2c3` alias makes that controller `/dev/i2c-3`.

`devicetree/imx91s-i2c4-pca9685.dtso` owns this Product pinmux choice. It
cannot be combined with an RGB display configuration that claims GPIO_IO02
and GPIO_IO03 for display VSYNC/HSYNC.

## Pending decisions

- Mechanical role and name of each servo
- Servo channel assignment and direction
- Neutral position, safe pulse range, and mechanical travel for each servo
- Dedicated 5 V servo supply and current capacity
- Chassis, linkage, and homing procedure

Do not add guessed values to the runtime configuration. Record measured values
here once the wiring and chassis are fixed.

The servo supply must be separate from the FRDM-IMX91S board supply, with a
shared signal ground. Final current capacity and protection must be selected
after measuring the actual SG90 units used in the build.
