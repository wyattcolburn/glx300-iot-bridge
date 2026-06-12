# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Two-script Python proof-of-concept for Azure IoT Hub device communication using the `azure-iot-device` SDK. The device identity is `py-poc-01` on hub `GLX300.azure-devices.net`.

## Running

```bash
# Send a single device-to-cloud (D2C) message
python send_one.py

# Listen for cloud-to-device (C2D) messages (runs until Ctrl+C)
python receive_c2d.py
```

**Dependency:** `pip install azure-iot-device`

## Architecture

- `send_one.py` — connects, sends one `Message`, disconnects.
- `receive_c2d.py` — connects, registers an `on_message_received` callback, then blocks in a `while True` loop to keep the process alive for async message delivery.

Both scripts use `IoTHubDeviceClient` with a hardcoded SAS connection string. The SDK handles SAS token generation and TLS negotiation on `client.connect()`. Always call `client.shutdown()` to cleanly close the AMQP connection.
