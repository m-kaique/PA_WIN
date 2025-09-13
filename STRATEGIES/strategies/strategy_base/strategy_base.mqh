//+------------------------------------------------------------------+
//|                                                strategy_base.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include "../strategies_types.mqh"

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

   // Métodos virtuais puros que devem ser implementados pelas classes derivadas
   virtual bool DoInit() = 0;
   virtual bool DoUpdate() = 0;
   virtual SStrategySignal CheckForSignal() = 0;
   virtual bool ValidateSignal(const SStrategySignal &signal) = 0;

public:
   // Construtor e destrutor
   CStrategyBase();
   virtual ~CStrategyBase();

   // Métodos públicos principais
   virtual bool Init(string name, const CStrategyConfig &config);
   virtual bool Update();
   virtual void Reset();

   // Getters
   string GetName() const { return m_name; }
   string GetType() const { return m_type; }
   bool IsEnabled() const { return m_enabled; }
   bool IsInitialized() const { return m_initialized; }
   ENUM_STRATEGY_STATE GetState() const { return m_state; }
   SStrategySignal GetLastSignal() const { return m_last_signal; }
   datetime GetLastUpdate() const { return m_last_update; }

   // Setters
   void SetEnabled(bool enabled) { m_enabled = enabled; }
   void SetState(ENUM_STRATEGY_STATE state) { m_state = state; }

   // Métodos de utilidade
   bool HasValidSignal() const { return m_last_signal.is_valid; }
   void ClearSignal() { m_last_signal.Reset(); }
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

   // Chamar inicialização específica da estratégia derivada
   if (!DoInit())
   {
      Print("ERRO: Falha na inicialização específica da estratégia ", m_name);
      return false;
   }

   m_initialized = true;
   m_state = STRATEGY_IDLE;
   m_last_signal.Reset();

   Print("Estratégia ", m_name, " (", m_type, ") inicializada com sucesso");
   return true;
}

//+------------------------------------------------------------------+
//| Atualização principal                                            |
//+------------------------------------------------------------------+
bool CStrategyBase::Update()
{
   if (!m_initialized || !m_enabled)
      return true;

   m_last_update = TimeCurrent();

   // Chamar atualização específica da estratégia derivada
   if (!DoUpdate())
   {
      Print("ERRO: Falha na atualização da estratégia ", m_name);
      return false;
   }

   // Verificar por novos sinais apenas se estivermos em estado idle
   if (m_state == STRATEGY_IDLE)
   {
      SStrategySignal signal = CheckForSignal();
      
      if (signal.is_valid && ValidateSignal(signal))
      {
         m_last_signal = signal;
         m_state = STRATEGY_SIGNAL_FOUND;
         
         Print("SINAL ENCONTRADO - ", m_name, ": ", 
               EnumToString(signal.type), " @ ", DoubleToString(signal.entry_price, _Digits));
      }
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
}