#!/bin/sh
# Deploy init script + forwarder to GLX300, enable on boot
# Run from laptop: bash deploy_init.sh

set -e
DEVICE=root@192.168.8.1

echo "Copying files..."
scp rs485_forward.sh "$DEVICE":/etc/rs485_forward.sh
scp rs485_cmd.sh     "$DEVICE":/etc/rs485_cmd.sh
scp glx300-bridge    "$DEVICE":/etc/init.d/glx300-bridge

echo "Setting permissions..."
ssh "$DEVICE" '
    chmod +x /etc/rs485_forward.sh
    chmod +x /etc/rs485_cmd.sh
    chmod +x /etc/init.d/glx300-bridge

    # Stop anything already running
    killall mosquitto 2>/dev/null || true
    killall rs485_forward.sh 2>/dev/null || true
    sleep 1

    # Enable (creates /etc/rc.d/S95glx300-bridge symlink)
    /etc/init.d/glx300-bridge enable

    # Start now
    /etc/init.d/glx300-bridge start
'

echo ""
echo "Done. Service will start automatically on reboot."
echo "Commands on device:"
echo "  /etc/init.d/glx300-bridge start"
echo "  /etc/init.d/glx300-bridge stop"
echo "  /etc/init.d/glx300-bridge disable   # remove from boot"
