# GarServoPet Luckfox Lyra Plus Target Capsule

This Product-side capsule composes the reusable `luckfox-rk3506` Target Pack
with GarServoPet. It owns only the Product's controller binding:

- cross-build `gar-servoctl` as a static ARMv7 hard-float executable;
- package the Product I2C and servo configuration for SSH deployment;
- enable RK3506 I2C1 at 100 kHz on RM_IO10/RM_IO11;
- expose a non-actuating lifecycle health check.

`configure-target` checks for the exact `Luckfox Lyra Plus` model before it
touches `/dev/mtdblock1`. It preserves the first boot partition image under
`/var/lib/gar/backups`, patches only the FIT Device Tree payload and its SHA-256
metadata, verifies the write-back, and returns status 10 when a reboot is
needed. GAR's reusable BusyBox installer handles that status and starts the
application after reboot.

The Product entrypoint has a safe no-argument service mode: it validates its
configuration and waits without opening I2C or enabling PWM. Explicit CLI
arguments continue to run one bounded command.
