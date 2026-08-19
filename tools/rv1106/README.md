# GarStreamTx RV1106 prototype assets

These files are Product-owned GarStreamTx experiments for the earlier Luckfox
RV1106 camera-transmitter profile:

- `app-template/`: legacy Product application scaffold
- `runtime/bin/`: rotary menu, ISP state, and monitor Product logic
- `scripts/`: RTSP sender/relay/viewer workflow helpers

Reusable RV1106 toolchain, USB/SSH bring-up, device-node providers, camera
tracing, and board data remain in `GAR/gar-tools/targets/luckfox-rv1106`.
The matching Product hardware assignment is in
`hardware/targets/luckfox-rv1106/`.
