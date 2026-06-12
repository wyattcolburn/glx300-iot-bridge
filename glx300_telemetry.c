#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "iothub.h"
#include "iothub_device_client_ll.h"
#include "iothub_client_options.h"
#include "iothub_message.h"
#include "azure_c_shared_utility/threadapi.h"
#include "azure_c_shared_utility/shared_util_options.h"
#include "iothubtransportmqtt.h"

static const char* CONNECTION_STRING =
    "HostName=GLX300.azure-devices.net;"
    "DeviceId=py-poc-01;"
    "SharedAccessKey=3AZp2p2ey499BKvZhBJQCJCqr8S90fMdrK/Ivhok1L0=";

#define MESSAGE_COUNT 3

static size_t g_confirmations = 0;
static bool g_done = false;

static void send_confirm_callback(IOTHUB_CLIENT_CONFIRMATION_RESULT result, void* ctx)
{
    (void)ctx;
    g_confirmations++;
    printf("[%zu] confirm: %s\n", g_confirmations,
           result == IOTHUB_CLIENT_CONFIRMATION_OK ? "OK" : "FAIL");
    if (g_confirmations >= MESSAGE_COUNT)
        g_done = true;
}

static void connection_status_callback(IOTHUB_CLIENT_CONNECTION_STATUS status,
                                        IOTHUB_CLIENT_CONNECTION_STATUS_REASON reason,
                                        void* ctx)
{
    (void)reason; (void)ctx;
    printf("connection: %s\n",
           status == IOTHUB_CLIENT_CONNECTION_AUTHENTICATED ? "connected" : "disconnected");
}

int main(void)
{
    IoTHub_Init();

    IOTHUB_DEVICE_CLIENT_LL_HANDLE handle =
        IoTHubDeviceClient_LL_CreateFromConnectionString(CONNECTION_STRING, MQTT_Protocol);

    if (!handle) {
        fprintf(stderr, "Failed to create IoTHub handle — check connection string\n");
        IoTHub_Deinit();
        return 1;
    }

    bool url_encode = true;
    IoTHubDeviceClient_LL_SetOption(handle, OPTION_AUTO_URL_ENCODE_DECODE, &url_encode);
    IoTHubDeviceClient_LL_SetConnectionStatusCallback(handle, connection_status_callback, NULL);

    for (int i = 1; i <= MESSAGE_COUNT && !g_done; i++) {
        char msg[64];
        snprintf(msg, sizeof(msg), "{\"src\":\"glx300\",\"seq\":%d,\"msg\":\"hello\"}", i);

        printf("Creating message %d\n", i); fflush(stdout);
        IOTHUB_MESSAGE_HANDLE m = IoTHubMessage_CreateFromString(msg);
        printf("Setting content type\n"); fflush(stdout);
        IoTHubMessage_SetContentTypeSystemProperty(m, "application%2Fjson");
        IoTHubMessage_SetContentEncodingSystemProperty(m, "utf-8");

        printf("Sending message %d: %s\n", i, msg); fflush(stdout);
        IoTHubDeviceClient_LL_SendEventAsync(handle, m, send_confirm_callback, NULL);
        printf("Destroying message handle\n"); fflush(stdout);
        IoTHubMessage_Destroy(m);

        /* pump the SDK until this message is confirmed or we time out (~5 s) */
        for (int t = 0; t < 5000 && g_confirmations < (size_t)i; t++) {
            if (t == 0) { printf("Entering DoWork loop\n"); fflush(stdout); }
            IoTHubDeviceClient_LL_DoWork(handle);
            ThreadAPI_Sleep(1);
        }
    }

    /* final drain */
    for (int t = 0; t < 3000 && !g_done; t++) {
        IoTHubDeviceClient_LL_DoWork(handle);
        ThreadAPI_Sleep(1);
    }

    IoTHubDeviceClient_LL_Destroy(handle);
    IoTHub_Deinit();

    printf("Done. %zu/%d messages confirmed.\n", g_confirmations, MESSAGE_COUNT);
    return (g_confirmations == MESSAGE_COUNT) ? 0 : 1;
}
