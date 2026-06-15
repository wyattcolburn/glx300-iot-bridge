#!/usr/bin/env python3
"""
Generate a mosquitto bridge config for Azure IoT Hub using X.509 cert auth.
Writes mosquitto-bridge.conf and deploy_bridge.sh.
Requires device.crt and device.key to exist in the same directory.
"""
import os, time

HUB       = "GLX300.azure-devices.net"
DEVICE_ID = "py-poc-01"

out_dir    = os.path.dirname(os.path.abspath(__file__))
conf_path  = os.path.join(out_dir, "mosquitto-bridge.conf")
deploy_path = os.path.join(out_dir, "deploy_bridge.sh")

for f in ["device.crt", "device.key"]:
    if not os.path.exists(os.path.join(out_dir, f)):
        raise FileNotFoundError(f"{f} not found — run: openssl genrsa -out device.key 2048 && openssl req -new -x509 -key device.key -out device.crt -days 3650 -subj '/CN={DEVICE_ID}'")

conf = f"""\
# mosquitto bridge → Azure IoT Hub (X.509 cert auth)
# Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}

# Local broker: listen only on loopback
listener 1883 127.0.0.1
allow_anonymous true

# ── Bridge connection ─────────────────────────────────────────────────────
connection azure-iothub
address {HUB}:8883
clientid {DEVICE_ID}
username {HUB}/{DEVICE_ID}/?api-version=2021-04-12

bridge_protocol_version mqttv311
bridge_cafile /etc/ssl/certs/ca-certificates.crt
bridge_certfile /etc/mosquitto/device.crt
bridge_keyfile /etc/mosquitto/device.key
bridge_tls_version tlsv1.2
try_private false
cleansession true
start_type automatic
restart_timeout 10
notifications false

# ── Topic mapping ─────────────────────────────────────────────────────────
# D2C: publish locally to glx300/data → forwarded to IoT Hub events topic
topic data out 0 glx300/ devices/{DEVICE_ID}/messages/events/

# C2D: IoT Hub commands → delivered locally on glx300/cmd (QoS 0 — QoS 1 causes IoT Hub to drop)
topic # in 0 glx300/cmd/ devices/{DEVICE_ID}/messages/devicebound/
"""

deploy = f"""\
#!/bin/sh
# Deploy mosquitto bridge config + X.509 certs to GLX300
# Run from your laptop: bash deploy_bridge.sh

set -e
DEVICE=root@192.168.8.1

echo "Copying config and certs..."
scp mosquitto-bridge.conf "$DEVICE":/tmp/mosquitto-bridge.conf
scp device.crt device.key "$DEVICE":/tmp/

ssh "$DEVICE" '
  opkg list-installed | grep -q "^mosquitto-ssl" || opkg install mosquitto-ssl

  cp /tmp/mosquitto-bridge.conf /etc/mosquitto/mosquitto.conf
  cp /tmp/device.crt /tmp/device.key /etc/mosquitto/
  chmod 600 /etc/mosquitto/device.key

  /etc/init.d/glx300-bridge restart 2>/dev/null || mosquitto -c /etc/mosquitto/mosquitto.conf -d

  echo "Bridge started with X.509 auth."
'
"""

with open(conf_path, "w") as f:
    f.write(conf)

with open(deploy_path, "w") as f:
    f.write(deploy)

os.chmod(deploy_path, 0o755)

print(f"Written: {conf_path}")
print(f"Written: {deploy_path}")
print()
print("Next steps:")
print("  1. Deploy:  bash deploy_bridge.sh")
print("  2. Monitor: az iot hub monitor-events --hub-name GLX300 --output table")
