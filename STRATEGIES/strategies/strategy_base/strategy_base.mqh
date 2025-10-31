#ifndef __STRATEGY_BASE_MQH__
#define __STRATEGY_BASE_MQH__

//+------------------------------------------------------------------+
//|                                                strategy_base.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include "../strategies_types.mqh"
#include "../../../tf_ctx/tf_ctx.mqh"
#include "../../../interfaces/icontext_provider.mqh"
#include "../../../interfaces/inetwork_client.mqh"
#include "../../../provider/provider.mqh"
#include "../../../orders/order_manager.mqh"

//+------------------------------------------------------------------+
//| Enumerações para estados de estratégia                          |
//+------------------------------------------------------------------+
enum ENUM_STRATEGY_STATE
{
   STRATEGY_IDLE,           // Aguardando sinal
   STRATEGY_SIGNAL_FOUND,   // Sinal encontrado
   STRATEGY_POSITION_OPEN,  // Posição aberta
   STRATEGY_POSITION_CLOSED // Posição fechada
};

enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE,
   SIGNAL_BUY,
   SIGNAL_SELL
};

//+------------------------------------------------------------------+
//| Estrutura para sinais de estratégia                             |
//+------------------------------------------------------------------+
struct SStrategySignal
{
   ENUM_SIGNAL_TYPE type;
   double entry_price;
   double stop_loss;
   double take_profit;
   double lot_size;
   string comment;
   datetime signal_time;
   bool is_valid;
   
   void Reset()
   {
      type = SIGNAL_NONE;
      entry_price = 0.0;
      stop_loss = 0.0;
      take_profit = 0.0;
      lot_size = 0.0;
      comment = "";
      signal_time = 0;
      is_valid = false;
   }
};

//+------------------------------------------------------------------+
//| Classe base para todas as estratégias                           |
//+------------------------------------------------------------------+
class CStrategyBase
{
protected:
     string m_name;
     string m_type;
     bool m_enabled;
     bool m_initialized;
     ENUM_STRATEGY_STATE m_state;
     SStrategySignal m_last_signal;
     datetime m_last_update;
     IContextProvider *m_context_provider;
     INetworkClient *m_network_client;
     string m_current_symbol;
     ENUM_TIMEFRAMES m_current_timeframe;
     COrderManager m_order_manager;

     int GenerateMagicNumberFromName() const
     {
         int magic = 0;
         int len = StringLen(m_name);
         for (int i = 0; i < len; i++)
         {
             magic = (magic * 31) + (int)StringGetCharacter(m_name, i);
         }
         if (magic == 0)
             magic = (int)GetTickCount();
         return (int)MathAbs((double)magic);
     }

   // Métodos virtuais puros que devem ser implementados pelas classes derivadas
   virtual bool DoInit() = 0;
   virtual bool DoUpdate() = 0;
   virtual SStrategySignal CheckForSignal() = 0;
   virtual bool ValidateSignal(const SStrategySignal &signal) = 0;
   virtual void ConfigureOrderSettings(SOrderManagerSettings &settings)
   {
      // Configuração padrão pode ser sobrescrita pelas estratégias derivadas
      settings.magic_number = GenerateMagicNumberFromName();
   }

   // Método para enviar sinal ao servidor
   virtual void SendSignalToServer();

   // Método para validar se timeframe está autorizado para esta estratégia
   virtual bool IsTimeframeAuthorized(ENUM_TIMEFRAMES timeframe)
   {
       CStrategyConfig *config = GetStrategyConfig();
       if (config == NULL)
           return true; // Se não há configuração, permite todos os timeframes

       // Verificar se é uma configuração que suporta timeframes autorizados
       string config_type = config.type;
       if (config_type == "emas_buy_bull")
       {
           CEmasBullBuyConfig *emas_config = dynamic_cast<CEmasBullBuyConfig*>(config);
           if (emas_config != NULL)
           {
               return emas_config.IsTimeframeAuthorized(timeframe);
           }
       }
       else if (config_type == "emas_sell_bear")
       {
           CEmasBearSellConfig *emas_config = dynamic_cast<CEmasBearSellConfig*>(config);
           if (emas_config != NULL)
           {
               return emas_config.IsTimeframeAuthorized(timeframe);
           }
       }

       // Para outras estratégias sem configuração específica de timeframes, permitir todos
       return true;
   }

   // Método auxiliar para obter configuração da estratégia (deve ser implementado pelas classes derivadas)
   virtual CStrategyConfig *GetStrategyConfig() { return NULL; }

   // Método para verificar se estamos dentro do horário de operação
   virtual bool IsWithinOperatingHours()
   {
       return DoOperatingHoursCheck();
   }

   // Método virtual para implementação específica de verificação de horário de operação
   virtual bool DoOperatingHoursCheck()
   {
       // Implementação padrão: sempre permitir operação
       return true;
   }

protected:
   // Método virtual para implementação específica de log em cada estratégia
   virtual void DoLog() { }

public:
   // Construtor e destrutor
   CStrategyBase();
   virtual ~CStrategyBase();

   // Métodos públicos principais
   virtual bool Init(string name, const CStrategyConfig &config);
   virtual bool Update(string symbol = "", ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   virtual void Reset();

   // Getters
   string GetName() const { return m_name; }
   string GetType() const { return m_type; }
   bool IsEnabled() const { return m_enabled; }
   bool IsInitialized() const { return m_initialized; }
   ENUM_STRATEGY_STATE GetState() const { return m_state; }
   SStrategySignal GetLastSignal() const { return m_last_signal; }
   datetime GetLastUpdate() const { return m_last_update; }
   IContextProvider *GetContextProvider() const { return m_context_provider; }
   INetworkClient *GetNetworkClient() const { return m_network_client; }

   // Setters
   void SetEnabled(bool enabled) { m_enabled = enabled; }
   void SetState(ENUM_STRATEGY_STATE state) { m_state = state; }
   void SetContextProvider(IContextProvider *context_provider) { m_context_provider = context_provider; }
   void SetNetworkClient(INetworkClient *network_client)
   {
       m_network_client = network_client;
       m_order_manager.SetNetworkClient(network_client);
   }

   // Métodos de utilidade
   bool HasValidSignal() const { return m_last_signal.is_valid; }
   void ClearSignal() { m_last_signal.Reset(); }
   COrderManager &GetOrderManager() { return m_order_manager; }

   // Método para exibir log de debug (chama método virtual DoLog)
   void ShowLog()
   {
       DoLog();
   }

   // Método público para verificar se timeframe está autorizado
   bool IsTimeframeAuthorizedPublic(ENUM_TIMEFRAMES timeframe)
   {
       CStrategyConfig *config = GetStrategyConfig();
       if (config == NULL)
           return true; // Se não há configuração, permite todos os timeframes

       // Verificar se é uma configuração que suporta timeframes autorizados
       string config_type = config.type;
       if (config_type == "emas_buy_bull")
       {
           CEmasBullBuyConfig *emas_config = dynamic_cast<CEmasBullBuyConfig*>(config);
           if (emas_config != NULL)
           {
               return emas_config.IsTimeframeAuthorized(timeframe);
           }
       }
       else if (config_type == "emas_sell_bear")
       {
           CEmasBearSellConfig *emas_config = dynamic_cast<CEmasBearSellConfig*>(config);
           if (emas_config != NULL)
           {
               return emas_config.IsTimeframeAuthorized(timeframe);
           }
       }

       // Para outras estratégias sem configuração específica de timeframes, permitir todos
       return true;
   }

};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CStrategyBase::CStrategyBase()
{
     m_name = "";
     m_type = "";
     m_enabled = false;
     m_initialized = false;
     m_state = STRATEGY_IDLE;
     m_last_signal.Reset();
     m_last_update = 0;
     m_context_provider = NULL;
     m_network_client = NULL;
     m_current_symbol = "";
     m_current_timeframe = PERIOD_CURRENT;
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CStrategyBase::~CStrategyBase()
{
   // Limpeza base se necessária
}

//+------------------------------------------------------------------+
//| Inicialização base                                               |
//+------------------------------------------------------------------+
bool CStrategyBase::Init(string name, const CStrategyConfig &config)
{
   m_name = name;
   m_type = config.type;
   m_enabled = config.enabled;

   if (!m_enabled)
   {
      Print("Estratégia ", m_name, " está desabilitada");
      return true; // Não é erro, apenas desabilitada
   }

   m_order_manager.SetStrategyName(m_name);
   m_order_manager.SetNetworkClient(m_network_client);

   // Chamar inicialização específica da estratégia derivada
   if (!DoInit())
   {
      Print("ERRO: Falha na inicialização específica da estratégia ", m_name);
      return false;
   }

   SOrderManagerSettings settings;
   ConfigureOrderSettings(settings);
   m_order_manager.Configure(settings);

   m_initialized = true;
   m_state = STRATEGY_IDLE;
   m_last_signal.Reset();

   Print("Estratégia ", m_name, " (", m_type, ") inicializada com sucesso");
   return true;
}

//+------------------------------------------------------------------+
//| Atualização principal                                            |
//+------------------------------------------------------------------+
bool CStrategyBase::Update(string symbol, ENUM_TIMEFRAMES timeframe)
{
    if (!m_initialized || !m_enabled)
       return true;

    // Store the current symbol and timeframe for use in derived methods
    if (symbol != "")
       m_current_symbol = symbol;
    else if (m_current_symbol == "")
       Print("CStrategyBase::UPdate - PROBLEMAS !!!!!!!!!!!!!!!!!!!!!!!!");

    if (timeframe != PERIOD_CURRENT)
       m_current_timeframe = timeframe;
    else if (m_current_timeframe == PERIOD_CURRENT)
       Print("CStrategyBase::UPdate - PROBLEMAS !!!!!!!!!!!!!!!!!!!!!!!!");

    m_last_update = TimeCurrent();

    // Atualizar símbolo e timeframe atuais no gerenciador de ordens
    string active_symbol = (m_current_symbol != "") ? m_current_symbol : Symbol();
    m_order_manager.SetSymbol(active_symbol);
    m_order_manager.SetStrategyName(m_name);

    // Chamar atualização específica da estratégia derivada
    if (!DoUpdate())
    {
       Print("ERRO: Falha na atualização da estratégia ", m_name);
       return false;
    }

    // Verificar por novos sinais apenas se estivermos em estado idle, timeframe estiver autorizado e dentro do horário de operação
    if (m_state == STRATEGY_IDLE && IsTimeframeAuthorized(m_current_timeframe))
    {
       // Verificar se estamos dentro do horário de operação
       if (!IsWithinOperatingHours())
       {
          Print("AVISO: Estratégia ", m_name, " fora do horário de operação");
          return true;
       }

       SStrategySignal signal = CheckForSignal();

       if (signal.is_valid && ValidateSignal(signal))
       {
          m_last_signal = signal;
          m_state = STRATEGY_SIGNAL_FOUND;

          Print("SINAL ENCONTRADO - ", m_name, " (", EnumToString(m_current_timeframe), "): ",
                EnumToString(signal.type), " @ ", DoubleToString(signal.entry_price, _Digits));

          SendSignalToServer();

          ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY;
          if (signal.type == SIGNAL_SELL)
             order_type = ORDER_TYPE_SELL;

          double stop_loss = signal.stop_loss;
          double take_profit = signal.take_profit;
          string comment = signal.comment;

          if (stop_loss <= 0)
          {
              double point = SymbolInfoDouble(active_symbol, SYMBOL_POINT);
              double sl_points =  m_order_manager.GetSettings().min_stop_loss_points * point;
              stop_loss = (signal.type == SIGNAL_BUY) ? signal.entry_price - sl_points : signal.entry_price + sl_points;
          }

          SOrderExecutionResult execution = m_order_manager.OpenMarketOrder(order_type, stop_loss, take_profit, comment, signal.lot_size);
          if (execution.success)
          {
             m_state = STRATEGY_POSITION_OPEN;
             Print("Ordem aberta pela estratégia ", m_name, " ticket ", execution.ticket, " volume ", DoubleToString(execution.volume, 2));
          }
          else
          {
             Print("Falha ao abrir ordem: ", execution.message);
          }
       }
    }
    else if (m_state == STRATEGY_IDLE && !IsTimeframeAuthorized(m_current_timeframe))
    {
       Print("AVISO: Estratégia ", m_name, " não está autorizada para timeframe ", EnumToString(m_current_timeframe));
    }

    m_order_manager.UpdateOpenPositions(m_current_timeframe);

    if (m_state == STRATEGY_POSITION_OPEN && !m_order_manager.HasOpenPositions())
    {
        m_state = STRATEGY_IDLE;
        ClearSignal();
    }

    return true;
}

//+------------------------------------------------------------------+
//| Reset da estratégia                                              |
//+------------------------------------------------------------------+
void CStrategyBase::Reset()
{
     m_state = STRATEGY_IDLE;
     m_last_signal.Reset();
     m_last_update = 0;
     m_context_provider = NULL;
     m_network_client = NULL;
}

//+------------------------------------------------------------------+
//| Enviar sinal ao servidor                                         |
//+------------------------------------------------------------------+
void CStrategyBase::SendSignalToServer()
{
    // Use the global functions from provider.mqh
    if (!FrancisSocketIsReady())
    {
        Print("Network client not available or not initialized for strategy ", m_name);
        return;
    }

    string json = StringFormat(
        "{\"type\":\"signal\",\"strategy\":\"%s\",\"signal_type\":\"%s\",\"entry_price\":%.5f,\"symbol\":\"%s\",\"timestamp\":\"%s\"}",
        m_name,
        EnumToString(m_last_signal.type),
        m_last_signal.entry_price,
        m_current_symbol,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)
    );

    if (!FrancisSocketSend(json))
    {
        Print("Failed to send signal to server from strategy ", m_name);
    }
    else
    {
        Print("Signal sent to server from strategy ", m_name);
    }
}

#endif