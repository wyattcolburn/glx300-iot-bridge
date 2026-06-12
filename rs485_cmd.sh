#!/bin/sh
# IoT Hub C2D → RS485
# Subscribes to glx300/cmd/#, converts hex payload to binary, writes to /dev/ttyS0
# Expected payload format: plain hex string, e.g. 010300120003a5ce

BROKER=127.0.0.1
PORT_RS485=/dev/ttyS0
TOPIC="glx300/cmd/#"

echo "C2D->RS485 listener started: $TOPIC -> $PORT_RS485"

mosquitto_sub -h "$BROKER" -p 1883 -t "$TOPIC" | while read -r PAYLOAD; do
    [ -z "$PAYLOAD" ] && continue

    # Validate: must be non-empty hex string (even number of hex chars)
    echo "$PAYLOAD" | grep -qE '^[0-9a-fA-F]+$' || {
        echo "Ignoring non-hex payload: $PAYLOAD"
        continue
    }

    BYTES=$(echo "$PAYLOAD" | wc -c)
    echo "CMD: $PAYLOAD ($(( (BYTES - 1) / 2 )) bytes)"

    # Convert hex to binary and write to RS485
    printf "$(echo "$PAYLOAD" | sed 's/../\\x&/g')" > "$PORT_RS485"
done
