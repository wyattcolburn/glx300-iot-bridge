
from azure.iot.device import IoTHubDeviceClient

import os
CONNECTION_STRING = os.environ["IOT_HUB_CONNECTION_STRING"]
def on_message(message):
    print("=== C2D message received ===")
    print("  payload:", message.data)                 # raw bytes from the cloud
    print("  properties:", message.custom_properties)  # any key/value you attached

client = IoTHubDeviceClient.create_from_connection_string(CONNECTION_STRING)
client.on_message_received = on_message     # register the handler BEFORE connecting
client.connect()
print("connected — waiting for C2D messages. Ctrl+C to stop.")

try:
    while True:
        pass          # keep the process alive so the handler can fire
except KeyboardInterrupt:
    print("stopping")
finally:
    client.shutdown()

 	
