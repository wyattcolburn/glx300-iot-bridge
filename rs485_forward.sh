#!/bin/sh
# RS485 Modbus RTU → Azure IoT Hub via mosquitto bridge
# Reads from /dev/ttyS0, publishes hex-encoded frames to glx300/data

PORT=/dev/ttyS0
TOPIC=glx300/data
BROKER=127.0.0.1
TMPFILE=/tmp/rs485_frame.bin

# Ensure mosquitto is running
if ! pgrep mosquitto > /dev/null; then
    echo "Starting mosquitto..."
    mosquitto -c /etc/mosquitto/mosquitto.conf -d
    sleep 2
fi

echo "RS485 forwarder started: $PORT -> IoT Hub ($TOPIC)"

while true; do
    # Block until data arrives, read up to 256 bytes (one Modbus frame)
    dd if="$PORT" of="$TMPFILE" bs=256 count=1 2>/dev/null

    BYTES=$(wc -c < "$TMPFILE")
    if [ "$BYTES" -gt 0 ]; then
        HEX=$(busybox hexdump -v -e '/1 "%02x"' "$TMPFILE")
        TS=$(date +%s)

        PAYLOAD="{\"ts\":$TS,\"proto\":\"modbus_rtu\",\"bytes\":$BYTES,\"hex\":\"$HEX\"}"

        mosquitto_pub -h "$BROKER" -p 1883 -t "$TOPIC" -m "$PAYLOAD"
        echo "$TS | $BYTES bytes | $HEX"
    fi
done
