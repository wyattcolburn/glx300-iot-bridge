# GLX300 → Azure IoT Hub POC — Session Summary

**Repo:** `github.com/wyattcolburn/glx300-iot-bridge`

## Goal
Bidirectional RS485 ↔ Azure IoT Hub bridge on a GL.iNet GL-X300B industrial gateway. MQTT topics: `data` (RS485 → cloud), `cmd` (cloud → RS485).

---

## What We Have

### Device
- **GL.iNet GL-X300B**, OpenWrt 22.03.4
- CPU: Qualcomm Atheros QCA9533 — MIPS 24Kc, big-endian, soft-float, no FPU
- 16 MB flash (nearly full), 128 MB RAM
- IP: `192.168.8.1`, SSH as root
- Pre-installed: `curl` (OpenSSL/1.1.1t), `libmosquitto-ssl`, `openssl-util`, `wget`
- Installed: `mosquitto-ssl` (broker), `mosquitto-client-ssl`
- Available busybox tools: `hexdump`, `dd`, `wc`, `pgrep`, `date`, `mosquitto_pub`, `mosquitto_sub`, `start-stop-daemon`
- NOT available: `stty`, `od`, `base64`, `timeout`, `nohup`

### Azure IoT Hub
- Hub: `GLX300.azure-devices.net`
- Device identity: `py-poc-01`
- Secrets: use `IOT_HUB_CONNECTION_STRING` env var for Python scripts, `IOT_HUB_KEY` for `gen_bridge_config.py`

### RS485
- Port: `/dev/ttyS0` — already configured by GL.iNet firmware, no `stty` needed
- Baud: 115200, 8N1
- Protocol: Modbus RTU (binary frames, e.g. `01 03 00 12 00 03 a5 ce`)

---

## What Works

### 1. Python POC (laptop only)
`send_one.py` and `receive_c2d.py` use the `azure-iot-device` Python SDK. Connection string via `IOT_HUB_CONNECTION_STRING` env var.

### 2. curl from GLX300 ✅
```bash
export IOT_HUB_KEY="<base64 SharedAccessKey>"
python3 gen_curl_cmd.py   # generates curl command, paste on device
az iot hub monitor-events --hub-name GLX300 --output table
```

### 3. Full Bidirectional RS485 ↔ IoT Hub Pipeline ✅ CONFIRMED WORKING

```
RS485 device
    ↕ Modbus RTU at 115200 baud
/dev/ttyS0
    ↑ rs485_forward.sh (dd + busybox hexdump)     [D2C]
    ↓ rs485_cmd.sh (mosquitto_sub + printf hex)   [C2D]
mosquitto broker (127.0.0.1:1883)
    ↕ bridge over TLS port 8883, SAS token auth
Azure IoT Hub (GLX300.azure-devices.net)
```

**Everything starts on boot automatically** via `/etc/init.d/glx300-bridge`.

**To restart manually:**
```bash
ssh root@192.168.8.1 '/etc/init.d/glx300-bridge restart'
```

**To monitor D2C on laptop:**
```bash
az iot hub monitor-events --hub-name GLX300 --output table
```

**To send a C2D command from laptop (plain hex Modbus frame):**
```bash
az iot device c2d-message send --hub-name GLX300 --device-id py-poc-01 --data "010300120003a5ce"
```

**Sample D2C payload received by IoT Hub:**
```json
{"ts":1781289134,"proto":"modbus_rtu","bytes":8,"hex":"010300120003a5ce"}
```

**C2D payload format:** plain hex string, e.g. `010300120003a5ce` — written as binary to `/dev/ttyS0`.

**Mosquitto bridge config flags that were required:**
- `notifications false` — prevents mosquitto publishing `$SYS` status to IoT Hub
- `try_private false` — disables private bridge protocol IoT Hub doesn't understand
- `cleansession true` — fresh session on each connect
- QoS 0 for both D2C and C2D — QoS 1 caused IoT Hub to drop the connection

**SAS token** in `/etc/mosquitto/mosquitto.conf` valid until **2027-06-12**. To regenerate:
```bash
export IOT_HUB_KEY="<base64 SharedAccessKey>"
python3 gen_bridge_config.py
bash deploy_bridge.sh
```

### 4. Persistence ✅
`/etc/init.d/glx300-bridge` (START=95) starts mosquitto + both scripts on boot.
Scripts live at `/etc/rs485_forward.sh` and `/etc/rs485_cmd.sh` (persistent, not `/tmp/`).
Uses `start-stop-daemon -S -b` to daemonize — `nohup` is not available on this busybox build.

---

## What Is Unresolved

### Modbus frame bundling
`dd` sometimes reads multiple Modbus frames in a single call (e.g. 48 bytes = 6×8-byte frames). Acceptable for POC. Production needs proper inter-frame gap detection or a Modbus parser.

### Azure IoT C SDK cross-compile (parked)
Cross-compiled for MIPS using OpenWrt SDK + mbedTLS. Binary crashes with SIGABRT on first `DoWork()` call. Parked in favour of mosquitto bridge approach.

---

## File Map

| File | Purpose |
|------|---------|
| `rs485_forward.sh` | D2C — reads RS485, publishes hex JSON to IoT Hub. Deployed to `/etc/` on device |
| `rs485_cmd.sh` | C2D — subscribes to `glx300/cmd/#`, writes hex payload as binary to RS485. Deployed to `/etc/` on device |
| `glx300-bridge` | OpenWrt init script. Deployed to `/etc/init.d/` on device |
| `deploy_init.sh` | Deploys rs485_forward.sh, rs485_cmd.sh, glx300-bridge to device and restarts |
| `gen_bridge_config.py` | Generates mosquitto bridge config with 1-year SAS token (needs `IOT_HUB_KEY` env var) |
| `deploy_bridge.sh` | Deploys mosquitto config only |
| `mosquitto-bridge.conf` | Generated bridge config — **gitignored** (contains live SAS token) |
| `gen_curl_cmd.py` | Generates one-shot curl test command (needs `IOT_HUB_KEY` env var) |
| `send_one.py` | Python D2C POC (laptop, needs `IOT_HUB_CONNECTION_STRING` env var) |
| `receive_c2d.py` | Python C2D listener (laptop, needs `IOT_HUB_CONNECTION_STRING` env var) |
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

1. **Proper Modbus framing** — detect inter-frame gaps so each Modbus PDU is a separate MQTT message
2. **Production hardening** — replace SAS tokens with X.509 device certificates
3. **Reconnection logic** — handle mosquitto bridge drops gracefully
