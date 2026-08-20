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
inputs. `i2c.csv` selects the reusable PCA9685 register simulation at address
`0x40` for the VM-facing `/dev/i2c-1` interface.

## Pending decisions

- Mechanical role and name of each servo
- PCA9685 I2C bus and address on the FRDM-IMX91S
- Servo channel assignment and direction
- Neutral position, safe pulse range, and mechanical travel for each servo
- Dedicated 5 V servo supply and current capacity
- Chassis, linkage, and homing procedure

Do not add guessed values to the runtime configuration. Record measured values
here once the wiring and chassis are fixed.

The servo supply must be separate from the FRDM-IMX91S board supply, with a
shared signal ground. Final current capacity and protection must be selected
after measuring the actual SG90 units used in the build.
