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
  echo "Test with: mosquitto_pub -h 127.0.0.1 -p 1883 -t glx300/data -m \x27{"src":"glx300","msg":"hello"}\x27"
'
