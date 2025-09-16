//+------------------------------------------------------------------+
//|                                             francis_the_socket.mqh |
//|    Classe Singleton para envio de JSON via UDP                   |
//+------------------------------------------------------------------+
#property copyright "vegas"
#property version "2.01"

#import "Ws2_32.dll"
int WSAStartup(ushort wVersionRequested, uchar &lpWSAData[]);
int WSACleanup();
int socket(int af, int type, int protocol);
int sendto(int s, uchar &buf[], int len, int flags, uchar &to[], int tolen);
int closesocket(int s);
int WSAGetLastError();
#import

#include "../utils/common_types.mqh"

#define AF_INET 2
#define SOCK_DGRAM 2 // UDP
#define IPPROTO_UDP 17

//+------------------------------------------------------------------+
//| Classe Singleton para gerenciamento do Socket UDP                |
//+------------------------------------------------------------------+
class CFrancisSocket
{
private:
   static CFrancisSocket *m_instance; // Instância única
   int m_udp_socket;                  // Handle do socket UDP
   string m_host;                     // Host de destino
   int m_port;                        // Porta de destino
   bool m_initialized;                // Status de inicialização
   uchar m_sockaddr[16];              // Estrutura sockaddr

   // Construtor privado para implementar singleton
   CFrancisSocket() : m_udp_socket(INVALID_HANDLE),
                      m_host("127.0.0.1"),
                      m_port(5005),
                      m_initialized(false)
   {
      ZeroMemory(m_sockaddr);
   }

   // Destrutor privado
   ~CFrancisSocket()
   {
      Cleanup();
   }

   // Configurar sockaddr para o endereço especificado
   void ConfigureSockAddr()
   {
      ZeroMemory(m_sockaddr);
      m_sockaddr[0] = 2; // AF_INET
      m_sockaddr[1] = 0;

      // Converter porta para network byte order
      m_sockaddr[2] = (uchar)((m_port >> 8) & 0xFF); // High byte
      m_sockaddr[3] = (uchar)(m_port & 0xFF);        // Low byte

      // IP 127.0.0.1 (localhost) - pode ser expandido para outros IPs
      m_sockaddr[4] = 127;
      m_sockaddr[5] = 0;
      m_sockaddr[6] = 0;
      m_sockaddr[7] = 1;
   }

public:
   // Verificar se instância existe (sem criar uma nova)
   static bool InstanceExists()
   {
      return (m_instance != NULL);
   }

   // Obter instância única (singleton)
   static CFrancisSocket *GetInstance()
   {
      if (m_instance == NULL)
      {
         m_instance = new CFrancisSocket();
      }
      return m_instance;
   }

   // Destruir instância (chamado na deinicialização)
   static void DestroyInstance()
   {
      if (m_instance != NULL)
      {
         delete m_instance;
         m_instance = NULL;
      }
   }

   // Inicializar socket
   bool Initialize(string host = "127.0.0.1", int port = 5005)
   {
      if (m_initialized)
      {
         Print("Francis Socket: Socket já está inicializado");
         return true;
      }

      m_host = host;
      m_port = port;

      // Inicializar Winsock
      uchar wsaData[512];
      if (WSAStartup(0x0202, wsaData) != 0)
      {
         Print("ERRO Francis Socket: WSAStartup failed: ", WSAGetLastError());
         return false;
      }

      // Criar socket UDP
      m_udp_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
      if (m_udp_socket == INVALID_HANDLE)
      {
         Print("ERRO Francis Socket: UDP socket creation failed: ", WSAGetLastError());
         WSACleanup();
         return false;
      }

      // Configurar endereço de destino
      ConfigureSockAddr();

      m_initialized = true;
      Print("Francis Socket: Inicializado com sucesso (", m_host, ":", m_port, ")");
      return true;
   }

   // Verificar se está inicializado
   bool IsInitialized()
   {
      return m_initialized;
   }

   // Enviar JSON personalizado
   bool SendJson(string json_data)
   {
      if (!m_initialized)
      {
         Print("ERRO Francis Socket: Socket não inicializado. Chame Initialize() primeiro.");
         return false;
      }

      if (json_data == "")
      {
         Print("ERRO Francis Socket: JSON vazio");
         return false;
      }

      // Converter string para bytes
      uchar jsonBuffer[];
      StringToCharArray(json_data, jsonBuffer);
      int jsonSize = ArraySize(jsonBuffer) - 1; // -1 para remover o null terminator

      // Enviar via UDP
      int sent = sendto(m_udp_socket, jsonBuffer, jsonSize, 0, m_sockaddr, 16);
      if (sent <= 0)
      {
         Print("ERRO Francis Socket: Falha ao enviar UDP: ", WSAGetLastError());
         return false;
      }

      Print("Francis Socket: JSON enviado (", sent, " bytes) - ", StringSubstr(json_data, 0, 100),
            (StringLen(json_data) > 100 ? "..." : ""));
      return true;
   }

   // Enviar JSON de trade (método de conveniência)
   bool SendTradeJson(string action, double volume, double sl = 0, double tp = 0, string symbol = "")
   {
      if (symbol == "")
         symbol = Symbol();

      // VERSÃO NOVA - usando JAson.mqh
      CJAVal json;
      json["action"] = action;
      json["symbol"] = symbol;
      json["volume"] = volume; // Automaticamente formatado com precisão adequada
      json["sl"] = sl;         // Automaticamente formatado com precisão adequada
      json["tp"] = tp;         // Automaticamente formatado com precisão adequada
      json["timestamp"] = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);

      string jsonString = json.Serialize();

      return SendJson(jsonString);
   }

   // Enviar JSON de análise (método de conveniência)
   bool SendAnalysisJson(string timeframe, string indicator, string signal, double value = 0, string symbol = "")
   {
      if (symbol == "")
         symbol = Symbol();

      // VERSÃO NOVA - usando JAson.mqh
      CJAVal json;
      json["type"] = "analysis";
      json["symbol"] = symbol;
      json["timeframe"] = timeframe;
      json["indicator"] = indicator;
      json["signal"] = signal;
      json["value"] = CJAVal(value, 5); // 5 casas decimais para o valor
      json["timestamp"] = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);

      string jsonString = json.Serialize();

      return SendJson(jsonString);
   }

   // Enviar JSON de status (método de conveniência)
   bool SendStatusJson(string status, string message = "", string symbol = "")
   {
      if (symbol == "")
         symbol = Symbol();

      // VERSÃO NOVA - usando JAson.mqh
      CJAVal json;
      json["type"] = "status";
      json["symbol"] = symbol;
      json["status"] = status;
      json["message"] = message;
      json["timestamp"] = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);

      string jsonString = json.Serialize();

      return SendJson(jsonString);
   }

   // Configurar novo endereço de destino
   bool SetDestination(string host, int port)
   {
      if (m_initialized)
      {
         Print("AVISO Francis Socket: Alterando destino durante execução");
      }

      m_host = host;
      m_port = port;
      ConfigureSockAddr();

      Print("Francis Socket: Destino alterado para ", m_host, ":", m_port);
      return true;
   }

   // Obter informações da conexão
   string GetConnectionInfo()
   {
      return StringFormat("Francis Socket - Host: %s, Porta: %d, Status: %s",
                          m_host, m_port, (m_initialized ? "Inicializado" : "Não inicializado"));
   }

   // Limpeza dos recursos
   void Cleanup()
   {
      if (m_udp_socket != INVALID_HANDLE)
      {
         closesocket(m_udp_socket);
         m_udp_socket = INVALID_HANDLE;
      }

      if (m_initialized)
      {
         WSACleanup();
         m_initialized = false;
         Print("Francis Socket: Recursos liberados");
      }
   }
};

// Inicialização da instância estática
static CFrancisSocket *CFrancisSocket::m_instance = NULL;

//+------------------------------------------------------------------+
//| Funções de conveniência para acesso global                       |
//+------------------------------------------------------------------+

// Verificar se Francis Socket existe (sem criar instância)
bool FrancisSocketExists()
{
   return CFrancisSocket::InstanceExists();
}

// Verificar se Francis Socket está inicializado
bool FrancisSocketIsReady()
{
   if (!CFrancisSocket::InstanceExists())
      return false;
      
   CFrancisSocket *socket = CFrancisSocket::GetInstance();
   return socket.IsInitialized();
}

// Inicializar Francis Socket
bool FrancisSocketInit(string host = "127.0.0.1", int port = 5005)
{
   CFrancisSocket *socket = CFrancisSocket::GetInstance();
   return socket.Initialize(host, port);
}

// Enviar JSON (com verificação automática de inicialização)
bool FrancisSocketSend(string json_data)
{
   if (!FrancisSocketIsReady())
   {
      Print("AVISO Francis Socket: Socket não está pronto. Inicializando automaticamente...");
      if (!FrancisSocketInit())
      {
         Print("ERRO Francis Socket: Falha na inicialização automática");
         return false;
      }
   }
   
   CFrancisSocket *socket = CFrancisSocket::GetInstance();
   return socket.SendJson(json_data);
}

// Enviar JSON de trade (com verificação automática)
bool FrancisSocketSendTrade(string action, double volume, double sl = 0, double tp = 0, string symbol = "")
{
   if (!FrancisSocketIsReady())
   {
      Print("AVISO Francis Socket: Socket não está pronto. Inicializando automaticamente...");
      if (!FrancisSocketInit())
      {
         Print("ERRO Francis Socket: Falha na inicialização automática");
         return false;
      }
   }
   
   CFrancisSocket *socket = CFrancisSocket::GetInstance();
   return socket.SendTradeJson(action, volume, sl, tp, symbol);
}

// Enviar JSON de análise (com verificação automática)
bool FrancisSocketSendAnalysis(string timeframe, string indicator, string signal, double value = 0, string symbol = "")
{
   if (!FrancisSocketIsReady())
   {
      Print("AVISO Francis Socket: Socket não está pronto. Inicializando automaticamente...");
      if (!FrancisSocketInit())
      {
         Print("ERRO Francis Socket: Falha na inicialização automática");
         return false;
      }
   }
   
   CFrancisSocket *socket = CFrancisSocket::GetInstance();
   return socket.SendAnalysisJson(timeframe, indicator, signal, value, symbol);
}

// Enviar JSON de status (com verificação automática)
bool FrancisSocketSendStatus(string status, string message = "", string symbol = "")
{
   if (!FrancisSocketIsReady())
   {
      Print("AVISO Francis Socket: Socket não está pronto. Inicializando automaticamente...");
      if (!FrancisSocketInit())
      {
         Print("ERRO Francis Socket: Falha na inicialização automática");
         return false;
      }
   }
   
   CFrancisSocket *socket = CFrancisSocket::GetInstance();
   return socket.SendStatusJson(status, message, symbol);
}

// Obter informações de status
string FrancisSocketGetInfo()
{
   if (!CFrancisSocket::InstanceExists())
      return "Francis Socket: Instância não existe";
      
   CFrancisSocket *socket = CFrancisSocket::GetInstance();
   return socket.GetConnectionInfo();
}

// Limpar Francis Socket
void FrancisSocketCleanup()
{
   CFrancisSocket::DestroyInstance();
}

//+------------------------------------------------------------------+
//| Exemplo de uso das funções de verificação                        |
//+------------------------------------------------------------------+
/*
void ExemploUsoVerificacao()
{
   // Verificar se instância existe (sem criar)
   if (FrancisSocketExists())
   {
      Print("Francis Socket já foi criado");
   }
   else
   {
      Print("Francis Socket ainda não foi criado");
   }
   
   // Verificar se está pronto para uso
   if (FrancisSocketIsReady())
   {
      Print("Francis Socket está pronto para envio");
   }
   else
   {
      Print("Francis Socket precisa ser inicializado");
   }
   
   // Obter informações de status
   Print(FrancisSocketGetInfo());
   
   // Enviar dados (com inicialização automática se necessário)
   FrancisSocketSendTrade("buy", 0.01, 1.1550, 1.1300);
}
*/