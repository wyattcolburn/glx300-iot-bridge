
from azure.iot.device import IoTHubDeviceClient, Message

import os
CONNECTION_STRING = os.environ["IOT_HUB_CONNECTION_STRING"]

client = IoTHubDeviceClient.create_from_connection_string(CONNECTION_STRING)
client.connect()                              # SDK generates the SAS token + does TLS here
print("connected")

client.send_message(Message("hello from my laptop"))
print("sent")

client.shutdown()
print("done")

 	
