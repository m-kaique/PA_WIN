//+------------------------------------------------------------------+
//|                                          francis_the_socket.mqh  |
//|    Envia JSON via UDP usando a biblioteca JAson.mqh             |
//+------------------------------------------------------------------+
#property copyright "vegas"
#property version   "2.00"

#include "../utils/JAson.mqh"

#import "Ws2_32.dll"
   int WSAStartup(ushort wVersionRequested, uchar &lpWSAData[]);
   int WSACleanup();
   int socket(int af, int type, int protocol);
   int sendto(int s, uchar &buf[], int len, int flags, uchar &to[], int tolen);
   int closesocket(int s);
   int WSAGetLastError();
#import

#define AF_INET     2
#define SOCK_DGRAM  2   // UDP
#define IPPROTO_UDP 17

int udpSocket = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   uchar wsaData[512];
   if(WSAStartup(0x0202, wsaData) != 0)
   {
      Print("WSAStartup failed: ", WSAGetLastError());
      return INIT_FAILED;
   }

   udpSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
   if(udpSocket == INVALID_HANDLE)
   {
      Print("UDP socket creation failed: ", WSAGetLastError());
      return INIT_FAILED;
   }

   Print("UDP socket criado com sucesso (localhost:5005).");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Função para criar JSON de ordem usando JAson.mqh               |
//+------------------------------------------------------------------+
string CreateOrderJson(string action, double volume, double sl, double tp, string symbol = "")
{
   CJAVal json;
   
   // Definindo os campos do JSON
   json["action"] = action;
   json["volume"] = volume;
   json["sl"] = sl;
   json["tp"] = tp;
   
   // Adicionando símbolo se fornecido
   if(symbol != "")
   {
      json["symbol"] = symbol;
   }
   
   // Adicionando timestamp
   json["timestamp"] = (long)TimeCurrent();
   
   // Adicionando informações de mercado se disponíveis
   if(SymbolInfoDouble(Symbol(), SYMBOL_BID) > 0)
   {
      json["current_bid"] = SymbolInfoDouble(Symbol(), SYMBOL_BID);
      json["current_ask"] = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      json["current_symbol"] = Symbol();
   }
   
   return json.Serialize();
}

//+------------------------------------------------------------------+
//| Função para criar JSON de status usando JAson.mqh              |
//+------------------------------------------------------------------+
string CreateStatusJson()
{
   CJAVal json;
   
   json["type"] = "status";
   json["timestamp"] = (long)TimeCurrent();
   json["account_info"]["balance"] = AccountInfoDouble(ACCOUNT_BALANCE);
   json["account_info"]["equity"] = AccountInfoDouble(ACCOUNT_EQUITY);
   json["account_info"]["margin"] = AccountInfoDouble(ACCOUNT_MARGIN);
   json["account_info"]["free_margin"] = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   json["account_info"]["profit"] = AccountInfoDouble(ACCOUNT_PROFIT);
   
   // Informações do símbolo atual
   json["symbol_info"]["symbol"] = Symbol();
   json["symbol_info"]["bid"] = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   json["symbol_info"]["ask"] = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   json["symbol_info"]["spread"] = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   
   return json.Serialize();
}

//+------------------------------------------------------------------+
//| Função para criar JSON de array de posições                     |
//+------------------------------------------------------------------+
string CreatePositionsJson()
{
   CJAVal json;
   CJAVal positions;
   
   json["type"] = "positions";
   json["timestamp"] = (long)TimeCurrent();
   
   // Iterar pelas posições abertas
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         CJAVal position;
         position["ticket"] = PositionGetInteger(POSITION_TICKET);
         position["symbol"] = PositionGetString(POSITION_SYMBOL);
         position["type"] = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "buy" : "sell";
         position["volume"] = PositionGetDouble(POSITION_VOLUME);
         position["price_open"] = PositionGetDouble(POSITION_PRICE_OPEN);
         position["sl"] = PositionGetDouble(POSITION_SL);
         position["tp"] = PositionGetDouble(POSITION_TP);
         position["profit"] = PositionGetDouble(POSITION_PROFIT);
         position["swap"] = PositionGetDouble(POSITION_SWAP);
        
         positions.Add(position);
      }
   }
   
   json["positions"] = positions;
   json["total_positions"] = PositionsTotal();
   
   return json.Serialize();
}

//+------------------------------------------------------------------+
//| Função genérica para enviar JSON via UDP                        |
//+------------------------------------------------------------------+
bool SendJsonUDP(string jsonString)
{
   if(udpSocket == INVALID_HANDLE)
   {
      Print("Socket UDP não inicializado!");
      return false;
   }

   // Converter string para array de bytes
   uchar jsonBuffer[];
   StringToCharArray(jsonString, jsonBuffer);
   int jsonSize = ArraySize(jsonBuffer) - 1; // -1 para remover o null terminator

   // Configurar sockaddr para 127.0.0.1:5005
   uchar sockaddr[16] = {0};
   sockaddr[0] = 2;        // AF_INET
   sockaddr[1] = 0;
   sockaddr[2] = 0x13;     // Porta 5005 = 0x138D → bytes [0x13, 0x8D]
   sockaddr[3] = 0x8D;
   sockaddr[4] = 127;      // IP 127.0.0.1
   sockaddr[5] = 0;
   sockaddr[6] = 0;
   sockaddr[7] = 1;

   int sent = sendto(udpSocket, jsonBuffer, jsonSize, 0, sockaddr, 16);
   if(sent <= 0)
   {
      Print("Erro ao enviar via UDP: ", WSAGetLastError());
      return false;
   }
   else
   {
      Print("JSON enviado via UDP (", sent, " bytes): ", StringSubstr(jsonString, 0, 100), "...");
      return true;
   }
}

//+------------------------------------------------------------------+
//| Envio de JSON de ordem de compra                                |
//+------------------------------------------------------------------+
void SendBuyOrder(double volume = 0.01, double sl = 0, double tp = 0)
{
   string json = CreateOrderJson("buy", volume, sl, tp, Symbol());
   SendJsonUDP(json);
}

//+------------------------------------------------------------------+
//| Envio de JSON de ordem de venda                                 |
//+------------------------------------------------------------------+
void SendSellOrder(double volume = 0.01, double sl = 0, double tp = 0)
{
   string json = CreateOrderJson("sell", volume, sl, tp, Symbol());
   SendJsonUDP(json);
}

//+------------------------------------------------------------------+
//| Envio de JSON de status da conta                                |
//+------------------------------------------------------------------+
void SendAccountStatus()
{
   string json = CreateStatusJson();
   SendJsonUDP(json);
}

//+------------------------------------------------------------------+
//| Envio de JSON com posições abertas                              |
//+------------------------------------------------------------------+
void SendOpenPositions()
{
   string json = CreatePositionsJson();
   SendJsonUDP(json);
}

//+------------------------------------------------------------------+
//| Exemplo de uso no OnTick                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastSent = 0;
   
   // Enviar dados a cada 10 segundos para não sobrecarregar
   if(TimeCurrent() - lastSent >= 10)
   {
      // Exemplo: enviar diferentes tipos de dados
      static int counter = 0;
      
      switch(counter % 4)
      {
         case 0:
            SendBuyOrder(0.01, SymbolInfoDouble(Symbol(), SYMBOL_BID) - 100*Point(), 
                        SymbolInfoDouble(Symbol(), SYMBOL_ASK) + 150*Point());
            break;
         case 1:
            SendSellOrder(0.01, SymbolInfoDouble(Symbol(), SYMBOL_ASK) + 100*Point(), 
                         SymbolInfoDouble(Symbol(), SYMBOL_BID) - 150*Point());
            break;
         case 2:
            SendAccountStatus();
            break;
         case 3:
            SendOpenPositions();
            break;
      }
      
      counter++;
      lastSent = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Deinicialização                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(udpSocket != INVALID_HANDLE)
   {
      closesocket(udpSocket);
   }
   WSACleanup();
   Print("Socket UDP fechado.");
}