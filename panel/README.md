# GarServoPet simulator components

The panel represents individually connectable physical components rather than
the complete robot or an Amazon order.

- `<gar-pca9685 id="pca9685-1" device="/dev/i2c-1" address="0x40">`
  represents one PCA9685 controller board on a VM I2C device.
- `<gar-sg90 id="sg90-1" controller="pca9685-1" channel="0">` represents one
  SG90 servo and its connection to a controller output.

The elements consume `init.state.i2c.pca9685` and live `pca9685` messages from
the shared GAR web bridge. The controller/VM is deliberately not represented by
a Product component: in simulation the VM and GarServoPet application take that
role.

The standard HTML `id` is the Product-wide physical component identity. The
`controller` attribute references another element by that ID, while `channel`
selects its output. `/dev/i2c-*` belongs to the PCA9685/controller side and must
not be used as an SG90 identity. Custom elements require explicit closing tags
in HTML; do not use `<gar-sg90/>`.

The SG90 angle is a visual estimate derived from the PWM pulse. Set
`min-pulse-us` and `max-pulse-us` after measuring the physical servo and linkage;
the preview defaults are not hardware calibration data.
