//+------------------------------------------------------------------+
//|                                                emas_bull_buy.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include "../strategy_base/strategy_base.mqh"
#include "../strategies_types.mqh"

//+------------------------------------------------------------------+
//| Estratégia EMA Buy Bull - Compra em tendência de alta com EMAs  |
//+------------------------------------------------------------------+
class CEmasBuyBull : public CStrategyBase
{
private:
   CEmasBullBuyConfig m_config;
   int m_ema_fast_handle;
   int m_ema_slow_handle;
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   double m_ema_fast_buffer[];
   double m_ema_slow_buffer[];

   bool CheckEMACrossover();
   bool CheckTrendDirection();
   double CalculateLotSize();
   double CalculateStopLoss(double entry_price);
   double CalculateTakeProfit(double entry_price, double stop_loss);

protected:
   virtual bool DoInit() override;
   virtual bool DoUpdate() override;
   virtual SStrategySignal CheckForSignal() override;
   virtual bool ValidateSignal(const SStrategySignal &signal) override;

public:
   CEmasBuyBull();
   ~CEmasBuyBull();
   
   bool Init(string name, const CEmasBullBuyConfig &config);
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CEmasBuyBull::CEmasBuyBull()
{
   m_ema_fast_handle = INVALID_HANDLE;
   m_ema_slow_handle = INVALID_HANDLE;
   m_symbol = Symbol();
   m_timeframe = Period();
   ArraySetAsSeries(m_ema_fast_buffer, true);
   ArraySetAsSeries(m_ema_slow_buffer, true);
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CEmasBuyBull::~CEmasBuyBull()
{
   if (m_ema_fast_handle != INVALID_HANDLE)
      IndicatorRelease(m_ema_fast_handle);
   if (m_ema_slow_handle != INVALID_HANDLE)
      IndicatorRelease(m_ema_slow_handle);
}

//+------------------------------------------------------------------+
//| Inicialização com configuração específica                       |
//+------------------------------------------------------------------+
bool CEmasBuyBull::Init(string name, const CEmasBullBuyConfig &config)
{
   m_config = config;
   return CStrategyBase::Init(name, config);
}

//+------------------------------------------------------------------+
//| Inicialização específica da estratégia                          |
//+------------------------------------------------------------------+
bool CEmasBuyBull::DoInit()
{
   // Criar handles para as EMAs
   m_ema_fast_handle = iMA(m_symbol, m_timeframe, m_config.ema_fast_period, 
                           0, MODE_EMA, PRICE_CLOSE);
   if (m_ema_fast_handle == INVALID_HANDLE)
   {
      Print("ERRO: Falha ao criar handle para EMA rápida (", m_config.ema_fast_period, ")");
      return false;
   }

   m_ema_slow_handle = iMA(m_symbol, m_timeframe, m_config.ema_slow_period, 
                           0, MODE_EMA, PRICE_CLOSE);
   if (m_ema_slow_handle == INVALID_HANDLE)
   {
      Print("ERRO: Falha ao criar handle para EMA lenta (", m_config.ema_slow_period, ")");
      return false;
   }

   Print("EMAs inicializadas - Rápida: ", m_config.ema_fast_period, 
         ", Lenta: ", m_config.ema_slow_period);
   return true;
}

//+------------------------------------------------------------------+
//| Atualização específica da estratégia                            |
//+------------------------------------------------------------------+
bool CEmasBuyBull::DoUpdate()
{
   // Copiar dados das EMAs
   if (CopyBuffer(m_ema_fast_handle, 0, 0, 3, m_ema_fast_buffer) != 3)
   {
      Print("ERRO: Falha ao copiar dados da EMA rápida");
      return false;
   }

   if (CopyBuffer(m_ema_slow_handle, 0, 0, 3, m_ema_slow_buffer) != 3)
   {
      Print("ERRO: Falha ao copiar dados da EMA lenta");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Verificar por sinal de entrada                                  |
//+------------------------------------------------------------------+
SStrategySignal CEmasBuyBull::CheckForSignal()
{
   SStrategySignal signal;
   signal.Reset();

   // Verificar se há dados suficientes
   if (ArraySize(m_ema_fast_buffer) < 3 || ArraySize(m_ema_slow_buffer) < 3)
      return signal;

   // Verificar cruzamento de EMAs (EMA rápida cruzando acima da lenta)
   if (!CheckEMACrossover())
      return signal;

   // Verificar direção da tendência
   if (!CheckTrendDirection())
      return signal;

   // Criar sinal de compra
   signal.type = SIGNAL_BUY;
   signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   signal.lot_size = CalculateLotSize();
   signal.stop_loss = CalculateStopLoss(signal.entry_price);
   signal.take_profit = CalculateTakeProfit(signal.entry_price, signal.stop_loss);
   signal.signal_time = TimeCurrent();
   signal.comment = "EMA Bull Buy - " + m_name;
   signal.is_valid = true;

   return signal;
}

//+------------------------------------------------------------------+
//| Verificar cruzamento das EMAs                                   |
//+------------------------------------------------------------------+
bool CEmasBuyBull::CheckEMACrossover()
{
   // EMA rápida atual acima da lenta E EMA rápida anterior abaixo da lenta
   bool current_above = m_ema_fast_buffer[0] > m_ema_slow_buffer[0];
   bool previous_below = m_ema_fast_buffer[1] <= m_ema_slow_buffer[1];
   
   return current_above && previous_below;
}

//+------------------------------------------------------------------+
//| Verificar direção da tendência                                  |
//+------------------------------------------------------------------+
bool CEmasBuyBull::CheckTrendDirection()
{
   // EMAs devem estar em tendência de alta (valores atuais > anteriores)
   bool fast_rising = m_ema_fast_buffer[0] > m_ema_fast_buffer[1];
   bool slow_rising = m_ema_slow_buffer[0] > m_ema_slow_buffer[1];
   
   return fast_rising && slow_rising;
}

//+------------------------------------------------------------------+
//| Calcular tamanho do lote                                        |
//+------------------------------------------------------------------+
double CEmasBuyBull::CalculateLotSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = balance * (m_config.risk_percent / 100.0);
   
   // Cálculo básico - pode ser refinado
   double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   
   // Cálculo simples baseado no risco
   double lot_size = MathMax(min_lot, risk_amount / 1000.0); // Simplificado
   lot_size = MathMin(lot_size, max_lot);
   
   // Arredondar para o step correto
   lot_size = MathFloor(lot_size / lot_step) * lot_step;
   
   return lot_size;
}

//+------------------------------------------------------------------+
//| Calcular stop loss                                              |
//+------------------------------------------------------------------+
double CEmasBuyBull::CalculateStopLoss(double entry_price)
{
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   return entry_price - (m_config.stop_loss_pips * point);
}

//+------------------------------------------------------------------+
//| Calcular take profit                                            |
//+------------------------------------------------------------------+
double CEmasBuyBull::CalculateTakeProfit(double entry_price, double stop_loss)
{
   double risk_distance = entry_price - stop_loss;
   return entry_price + (risk_distance * m_config.take_profit_ratio);
}

//+------------------------------------------------------------------+
//| Validar sinal                                                   |
//+------------------------------------------------------------------+
bool CEmasBuyBull::ValidateSignal(const SStrategySignal &signal)
{
   // Verificações básicas de validação
   if (signal.type != SIGNAL_BUY)
      return false;
      
   if (signal.entry_price <= 0 || signal.lot_size <= 0)
      return false;
      
   if (signal.stop_loss >= signal.entry_price)
      return false;
      
   if (signal.take_profit <= signal.entry_price)
      return false;

   // Verificações de margem disponível
   double margin_required = 0;
   if (!OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, signal.lot_size, 
                        signal.entry_price, margin_required))
      return false;
      
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if (margin_required > free_margin)
   {
      Print("AVISO: Margem insuficiente para o sinal");
      return false;
   }

   return true;
}