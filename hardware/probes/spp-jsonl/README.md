# Vibe Remote Bluetooth SPP probe

`bin/gar-spp-jsonl-probe` verifies the Vibe Remote newline-delimited JSON
protocol over a paired POSIX RFCOMM serial device. It is Product-owned because
the `hello`, `agentStatus`, token, and status payload contract is not an ESP32
or M5Stack capability.

```bash
hardware/probes/spp-jsonl/bin/gar-spp-jsonl-probe \
  /dev/rfcomm0 --token YOUR_TOKEN --status running
```
