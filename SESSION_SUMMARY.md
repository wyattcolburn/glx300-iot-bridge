# GLX300 → Azure IoT Hub POC — Session Summary

## Goal
Send telemetry from a GL.iNet GL-X300B industrial gateway to Azure IoT Hub, with a longer-term plan to bridge RS485 data (MQTT topics: `data` for received, `cmd` for outbound).

---

## What We Have

### Device
- **GL.iNet GL-X300B**, OpenWrt 22.03.4
- CPU: Qualcomm Atheros QCA9533 — MIPS 24Kc, big-endian, soft-float, no FPU
- 16 MB flash (nearly full), 128 MB RAM
- IP: `192.168.8.1`, SSH as root
- Pre-installed: `curl` (OpenSSL/1.1.1t), `libmosquitto-ssl`, `openssl-util`, `wget`
- Installed this session: `mosquitto-ssl` (broker), `mosquitto-client-ssl`
- Available busybox tools: `hexdump`, `dd`, `wc`, `pgrep`, `date` — but NOT `stty`, `od`, `base64`, `timeout`

### Azure IoT Hub
- Hub: `GLX300.azure-devices.net`
- Device identity: `py-poc-01`
- Connection string in `send_one.py`

### RS485
- Port: `/dev/ttyS0` — already configured by GL.iNet firmware, no `stty` needed
- Baud: 115200, 8N1
- Protocol: Modbus RTU (binary frames, e.g. `01 03 00 12 00 03 a5 ce`)

---

## What Works

### 1. Python POC (laptop only)
`send_one.py` and `receive_c2d.py` use the `azure-iot-device` Python SDK to send/receive messages. Confirmed working.

### 2. curl from GLX300 ✅
The device uses `curl` with its existing OpenSSL to POST to the IoT Hub REST API.

```bash
# On laptop — generate a fresh SAS token + curl command (valid 1 hour):
python3 /home/wyatt/glx300/gen_curl_cmd.py

# On laptop — monitor incoming messages:
az iot hub monitor-events --hub-name GLX300 --output table

# On device (paste the curl output from gen_curl_cmd.py):
curl -X POST "https://GLX300.azure-devices.net/devices/py-poc-01/messages/events?api-version=2018-06-30" \
  -H 'Authorization: SharedAccessSignature sr=...' \
  -H 'Content-Type: application/json' \
  -d '{"src":"glx300","msg":"hello via curl"}'
```

### 3. Full RS485 → IoT Hub Pipeline ✅ CONFIRMED WORKING

```
RS485 device
    ↓ Modbus RTU frames at 115200 baud
/dev/ttyS0
    ↓ rs485_forward.sh (dd + busybox hexdump)
mosquitto broker (127.0.0.1:1883)
    ↓ bridge over TLS port 8883, SAS token auth
Azure IoT Hub (GLX300.azure-devices.net)
```

**To run the full pipeline:**
```bash
# On device — start bridge + forwarder:
ssh root@192.168.8.1 'mosquitto -c /etc/mosquitto/mosquitto.conf -d && /tmp/rs485_forward.sh'

# On laptop — monitor:
az iot hub monitor-events --hub-name GLX300 --output table
```

**Sample IoT Hub payload:**
```json
{"ts":1781289134,"proto":"modbus_rtu","bytes":8,"hex":"010300120003a5ce"}
```

**Mosquitto bridge config flags that were required:**
- `notifications false` — prevents mosquitto publishing `$SYS` status to IoT Hub
- `try_private false` — disables private bridge protocol IoT Hub doesn't understand
- `cleansession true` — fresh session on each connect
- QoS 0 for D2C — QoS 1 caused IoT Hub to drop the connection

**SAS token** in `/etc/mosquitto/mosquitto.conf` valid until **2027-06-12**. To regenerate:
```bash
python3 /home/wyatt/glx300/gen_bridge_config.py
bash /home/wyatt/glx300/deploy_bridge.sh
```

---

## What Is Unresolved

### C2D via mosquitto bridge
IoT Hub closes the connection when mosquitto subscribes to `devices/py-poc-01/messages/devicebound/#`. Root cause unknown — not yet investigated.

### Modbus frame bundling
`dd` sometimes reads multiple Modbus frames in a single call (e.g. 48 bytes = 6×8-byte frames). Acceptable for POC. Production needs proper inter-frame gap detection (VTIME via stty, not available on this device, or a small C/Python parser).

### Azure IoT C SDK cross-compile (parked)
Cross-compiled for MIPS using OpenWrt SDK + mbedTLS. Binary runs but crashes with SIGABRT on first `DoWork()` call. Parked in favour of the mosquitto bridge approach.

---

## File Map (`/home/wyatt/glx300/`)

| File | Purpose |
|------|---------|
| `rs485_forward.sh` | **Main pipeline script** — reads RS485, publishes to IoT Hub via bridge |
| `gen_bridge_config.py` | Generates mosquitto bridge config with 1-year SAS token |
| `deploy_bridge.sh` | Installs mosquitto-ssl + deploys config to device |
| `mosquitto-bridge.conf` | Current working bridge config (D2C only) |
| `gen_curl_cmd.py` | Generates one-shot curl test command |
| `send_one.py` | Python D2C POC (laptop) |
| `receive_c2d.py` | Python C2D listener (laptop) |
| `glx300_telemetry.c` | C telemetry app (SDK approach, parked) |
| `build_glx300.sh` | Builds C SDK + app for MIPS (OpenWrt toolchain + mbedTLS) |
| `toolchain-mips-openwrt.cmake` | CMake cross-compile config |

## Key Paths
- OpenWrt SDK: `~/openwrt-sdk-22.03.4-ath79-generic_gcc-11.2.0_musl.Linux-x86_64/`
- Cross-compiler: `...staging_dir/toolchain-mips_24kc_gcc-11.2.0_musl/bin/mips-openwrt-linux-musl-gcc`
- mbedTLS sysroot: `~/mips-sysroot/`
- Azure IoT C SDK: `~/azure-iot-sdk-c/`

---

## Next Steps

1. **Persistence** — make the bridge and forwarder survive reboots via OpenWrt's init system (`/etc/init.d/`)
2. **C2D commands** — fix the mosquitto bridge C2D subscription so commands from IoT Hub reach the device on `glx300/cmd`
3. **Proper Modbus framing** — detect inter-frame gaps to ensure each Modbus PDU is a separate MQTT message
4. **Production hardening** — replace SAS tokens with X.509 device certificates; add reconnection logic
