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
