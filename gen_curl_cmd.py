#!/usr/bin/env python3
"""Generate a time-limited curl command to send one IoT Hub telemetry message."""
import base64, hmac, hashlib, time, urllib.parse

HUB       = "GLX300.azure-devices.net"
DEVICE_ID = "py-poc-01"
KEY_B64   = "3AZp2p2ey499BKvZhBJQCJCqr8S90fMdrK/Ivhok1L0="
DURATION  = 3600  # seconds

expiry  = int(time.time()) + DURATION
resource = f"{HUB}/devices/{DEVICE_ID}"
resource_enc = urllib.parse.quote(resource, safe="")

string_to_sign = f"{resource_enc}\n{expiry}"
key_bytes = base64.b64decode(KEY_B64)
sig = base64.b64encode(
    hmac.new(key_bytes, string_to_sign.encode(), hashlib.sha256).digest()
).decode()

sas = (f"SharedAccessSignature sr={resource_enc}"
       f"&sig={urllib.parse.quote(sig, safe='')}"
       f"&se={expiry}")

payload = '{"src":"glx300","msg":"hello via curl"}'

print("# Run this on the GLX300:")
print(f"""curl -v \\
  -X POST \\
  "https://{HUB}/devices/{DEVICE_ID}/messages/events?api-version=2018-06-30" \\
  -H 'Authorization: {sas}' \\
  -H 'Content-Type: application/json' \\
  -d '{payload}'""")
