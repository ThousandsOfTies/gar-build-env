# GarServoPet FRDM-IMX91S Target Capsule

This directory is the Product-side controller capsule for the NXP
FRDM-IMX91S. The deployment composer invokes `package.sh` only after it has
validated the shared Application Capsule, Product hardware binding, runtime
profiles, and artifact contract.

```text
frdm-imx91s/
├── package.sh
├── device-tree/
│   ├── build.sh
│   └── imx91s-gar-servo-pet-i2c4-overlay.dtso
└── provisioning/uuu/
    ├── common.sh
    ├── generate.sh
    ├── generate-dtb-update.sh
    ├── generate-layout-probe.sh
    └── stage.sh
```

The Device Tree subtree owns the controller pinmux and expansion-rail setup.
The UUU subtree owns only Product-specific defaults and delegates the board
protocol, NAND safety gates, and command templates to the reusable Target Pack
at `sources/gar-tools/targets/frdm-imx91s`.

New automation should select `config/deployments/frdm-imx91s.json` through
`scripts/package-target.sh`. The top-level `scripts/*imx91s*.sh` files remain
thin compatibility entrypoints; no NXP implementation lives in them.

The canonical local settings are copied from
`config/frdm-imx91s.env.example` to the ignored
`config/frdm-imx91s.env`. An existing ignored `config/imx91s-uuu.env` is
still recognized as a migration fallback.
