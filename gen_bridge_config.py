#!/usr/bin/env python3
"""
Generate a mosquitto bridge config for Azure IoT Hub.
Writes mosquitto-bridge.conf and a deploy script.
"""
import base64, hmac, hashlib, time, urllib.parse, os

HUB       = "GLX300.azure-devices.net"
DEVICE_ID = "py-poc-01"
KEY_B64   = os.environ.get("IOT_HUB_KEY", "")  # export IOT_HUB_KEY=<base64 SharedAccessKey>
DURATION  = 365 * 24 * 3600  # 1 year SAS token for the bridge

def make_sas(duration_secs):
    expiry = int(time.time()) + duration_secs
    resource = f"{HUB}/devices/{DEVICE_ID}"
    resource_enc = urllib.parse.quote(resource, safe="")
    string_to_sign = f"{resource_enc}\n{expiry}"
    key_bytes = base64.b64decode(KEY_B64)
    sig = base64.b64encode(
        hmac.new(key_bytes, string_to_sign.encode(), hashlib.sha256).digest()
    ).decode()
    return (f"SharedAccessSignature sr={resource_enc}"
            f"&sig={urllib.parse.quote(sig, safe='')}"
            f"&se={expiry}")

sas = make_sas(DURATION)

conf = f"""\
# mosquitto bridge → Azure IoT Hub
# Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}
# SAS token valid for 1 year — regenerate with gen_bridge_config.py before expiry

# Local broker: listen only on loopback
listener 1883 127.0.0.1
allow_anonymous true

# ── Bridge connection ─────────────────────────────────────────────────────
connection azure-iothub
address {HUB}:8883
clientid {DEVICE_ID}
username {HUB}/{DEVICE_ID}/?api-version=2021-04-12
password {sas}

bridge_protocol_version mqttv311
bridge_cafile /etc/ssl/certs/ca-certificates.crt
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
# Deploy mosquitto bridge config to GLX300
# Run from your laptop: bash deploy_bridge.sh

set -e
DEVICE=root@192.168.8.1

scp mosquitto-bridge.conf "$DEVICE":/tmp/
ssh "$DEVICE" '
  # Install mosquitto broker with SSL if not present
  opkg list-installed | grep -q "^mosquitto-ssl" || opkg install mosquitto-ssl

  # Install config
  cp /tmp/mosquitto-bridge.conf /etc/mosquitto/mosquitto.conf

  # Restart mosquitto
  /etc/init.d/mosquitto restart 2>/dev/null || mosquitto -c /etc/mosquitto/mosquitto.conf -d

  echo "Bridge started."
  echo "Test with: mosquitto_pub -h 127.0.0.1 -p 1883 -t glx300/data -m \\x27{{\"src\":\"glx300\",\"msg\":\"hello\"}}\\x27"
'
"""

out_dir = os.path.dirname(os.path.abspath(__file__))
conf_path = os.path.join(out_dir, "mosquitto-bridge.conf")
deploy_path = os.path.join(out_dir, "deploy_bridge.sh")

with open(conf_path, "w") as f:
    f.write(conf)

with open(deploy_path, "w") as f:
    f.write(deploy)

os.chmod(deploy_path, 0o755)

print(f"Written: {conf_path}")
print(f"Written: {deploy_path}")
print()
print("SAS token expires:", time.strftime('%Y-%m-%d', time.localtime(time.time() + DURATION)))
print()
print("Next steps:")
print("  1. Check device has mosquitto-ssl: ssh root@192.168.8.1 'opkg install mosquitto-ssl'")
print("  2. Deploy:  bash deploy_bridge.sh")
print("  3. Monitor: az iot hub monitor-events --hub-name GLX300 --output table")
print("  4. Test:    ssh root@192.168.8.1 'mosquitto_pub -h 127.0.0.1 -p 1883 -t glx300/data -m '{\"msg\":\"hello\"}'")
