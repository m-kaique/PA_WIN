#ifndef __INETWORK_CLIENT_MQH__
#define __INETWORK_CLIENT_MQH__

//+------------------------------------------------------------------+
//| Interface for network communication                             |
//+------------------------------------------------------------------+
interface INetworkClient
{
public:
    // Initialize network connection
    virtual bool Initialize(string host = "127.0.0.1", int port = 5005) = 0;

    // Send JSON data
    virtual bool SendJson(string json_data) = 0;

    // Check if connected/initialized
    virtual bool IsInitialized() = 0;

    // Get connection info
    virtual string GetConnectionInfo() = 0;
};

#endif // __INETWORK_CLIENT_MQH__