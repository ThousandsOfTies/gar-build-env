# Deployment Profiles

A Deployment Profile is the only place that selects an Application Capsule
and a physical target together. Its Product id is independent of the
Application id, so a compatible application can be replaced without changing
the hardware binding. Each `<id>.json` references:

- one application manifest (`sources/<app>/app.json`);
- one target id and Product hardware binding;
- the runtime configuration files installed with that application;
- the target artifact contract and local/default target configuration; and
- one executable Product-side Target Capsule packager.

Run `scripts/package-target.sh --deployment <id> --describe` to validate and
inspect a composition without building it. To add another controller, create
its binding, runtime profile, artifact contract, and Target Capsule, then add
a Deployment Profile. The application manifest does not need board-specific
fields.

All Product-side controller implementation belongs below
`scripts/targets/<target-id>/`. Configuration and electrical data remain in
`config/deployments/` and `hardware/`; top-level board-named scripts may exist
only as compatibility dispatchers.
