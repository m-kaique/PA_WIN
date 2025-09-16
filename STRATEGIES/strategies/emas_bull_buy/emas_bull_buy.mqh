#ifndef __EMAS_BULL_BUY_MQH__
#define __EMAS_BULL_BUY_MQH__

//+------------------------------------------------------------------+
//|                                                emas_bull_buy.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include "../../../interfaces/icontext_provider.mqh"
#include "../strategy_base/strategy_base.mqh"
#include "../strategies_types.mqh"

//+------------------------------------------------------------------+
//| Estratégia EMA Buy Bull - Compra em tendência de alta com EMAs  |
//+------------------------------------------------------------------+
class CEmasBuyBull : public CStrategyBase
{
private:
    CEmasBullBuyConfig m_config;
    IContextProvider *m_context_provider;

    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;

   double CalculateLotSize();
   double CalculateStopLoss(double entry_price);
   double CalculateTakeProfit(double entry_price, double stop_loss);

   // Métodos auxiliares migrados da lógica CompraAlta
   bool IsStrongTrend(TF_CTX *ctx, double min_distance_9_21_atr = 0.3, double min_distance_21_50_atr = 0.5);
   bool HasBullishMomentum(TF_CTX *ctx_m15, TF_CTX *ctx_m3, int lookback_candles = 3);
   bool IsValidPullback(SPositionInfo &position_info, double atr_value, TF_CTX *ctx, CMovingAverages *ma, double max_distance_atr = 0.8, int max_duration_candles = 3);
   bool IsGoodVolatilityEnvironment(TF_CTX *ctx, int lookback_periods = 10, double min_volatility_ratio = 0.7, double max_volatility_ratio = 1.5);
   bool IsInBullishStructure(TF_CTX *ctx, double atr_value);

protected:
   virtual bool DoInit() override;
   virtual bool DoUpdate() override;
   virtual SStrategySignal CheckForSignal() override;
   virtual bool ValidateSignal(const SStrategySignal &signal) override;

public:
    CEmasBuyBull(IContextProvider *context_provider = NULL);
    ~CEmasBuyBull();

    bool Init(string name, const CEmasBullBuyConfig &config);
   void PrintFullDebugLog();
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CEmasBuyBull::CEmasBuyBull(IContextProvider *context_provider)
{
    m_context_provider = context_provider;
    m_symbol = Symbol();
    m_timeframe = Period();
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CEmasBuyBull::~CEmasBuyBull()
{
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
   return true;
}

//+------------------------------------------------------------------+
//| Atualização específica da estratégia                            |
//+------------------------------------------------------------------+
bool CEmasBuyBull::DoUpdate()
{
   return true;
}

//+------------------------------------------------------------------+
//| Verificar se há tendência forte baseada na distância entre médias |
//+------------------------------------------------------------------+
bool CEmasBuyBull::IsStrongTrend(TF_CTX *ctx, double min_distance_9_21_atr = 0.3, double min_distance_21_50_atr = 0.5)
{
   if (ctx == NULL)
      return false;

   CMovingAverages *ema9 = ctx.GetIndicator("ema9");
   CMovingAverages *ema21 = ctx.GetIndicator("ema21");
   CMovingAverages *ema50 = ctx.GetIndicator("ema50");
   CATR *atr = ctx.GetIndicator("ATR15");

   if (ema9 == NULL || ema21 == NULL || ema50 == NULL || atr == NULL)
      return false;

   double ema9_val = ema9.GetValue(1);
   double ema21_val = ema21.GetValue(1);
   double ema50_val = ema50.GetValue(1);
   double atr_val = atr.GetValue(1);

   if (atr_val <= 0)
      return false;

   double dist_9_21 = MathAbs(ema9_val - ema21_val) / atr_val;
   double dist_21_50 = MathAbs(ema21_val - ema50_val) / atr_val;

   bool strong_trend = (dist_9_21 >= min_distance_9_21_atr && dist_21_50 >= min_distance_21_50_atr);

   return strong_trend;
}

//+------------------------------------------------------------------+
//| Verificar momentum bullish através de price action              |
//+------------------------------------------------------------------+
bool CEmasBuyBull::HasBullishMomentum(TF_CTX *ctx_m15, TF_CTX *ctx_m3, int lookback_candles = 3)
{
   if (ctx_m15 == NULL || ctx_m3 == NULL)
      return false;

   CMovingAverages *ema21_m15 = ctx_m15.GetIndicator("ema21");
   if (ema21_m15 == NULL)
      return false;

   string symbol = Symbol();

   // Critério 1: Verificar se o preço está consistentemente acima da EMA21 no M15
   int candles_above_ema21 = 0;
   for (int i = 1; i <= lookback_candles; i++)
   {
      double close = iClose(symbol, PERIOD_M15, i);
      double ema21_val = ema21_m15.GetValue(i);
      if (close > ema21_val)
      {
         candles_above_ema21++;
      }
   }
   bool price_above_ema21 = (candles_above_ema21 >= 2);

   // Critério 2: Verificar se não há sinais de pânico de venda
   bool no_panic_selling = true;
   for (int i = 1; i <= 2; i++)
   {
      double open = iOpen(symbol, PERIOD_M3, i);
      double close = iClose(symbol, PERIOD_M3, i);
      double low = iLow(symbol, PERIOD_M3, i);
      double high = iHigh(symbol, PERIOD_M3, i);

      double body_size = MathAbs(close - open);
      double lower_shadow = MathMin(open, close) - low;
      double candle_range = high - low;

      if (candle_range > 0)
      {
         double lower_shadow_ratio = lower_shadow / candle_range;
         if (lower_shadow_ratio > 0.6)
         {
            no_panic_selling = false;
            break;
         }
      }
   }

   // Critério 3: Verificar se a última vela mostra força de alta
   double last_open = iOpen(symbol, PERIOD_M3, 1);
   double last_close = iClose(symbol, PERIOD_M3, 1);
   bool last_candle_bullish = (last_close >= last_open);

   return price_above_ema21 && no_panic_selling && last_candle_bullish;
}

//+------------------------------------------------------------------+
//| Validar se é um pullback adequado                               |
//+------------------------------------------------------------------+
bool CEmasBuyBull::IsValidPullback(SPositionInfo &position_info, double atr_value, TF_CTX *ctx, CMovingAverages *ma, double max_distance_atr = 0.8, int max_duration_candles = 3)
{
   if (ctx == NULL || ma == NULL || atr_value <= 0)
      return false;

   // Critério 1: Verificar se o pullback não é muito profundo
   if (position_info.distance > max_distance_atr * atr_value)
   {
      return false;
   }

   // Critério 2: Verificar velocidade do pullback
   string symbol = Symbol();
   ENUM_TIMEFRAMES tf = ctx.GetTimeFrame();
   bool was_further_away = false;

   for (int i = 2; i <= max_duration_candles + 1; i++)
   {
      double prev_close = iClose(symbol, tf, i);
      double prev_ma_value = ma.GetValue(i);
      double prev_distance = MathAbs(prev_close - prev_ma_value);

      if (prev_distance > position_info.distance * 1.2)
      {
         was_further_away = true;
         break;
      }
   }

   return was_further_away;
}

//+------------------------------------------------------------------+
//| Analisar ambiente de volatilidade                               |
//+------------------------------------------------------------------+
bool CEmasBuyBull::IsGoodVolatilityEnvironment(TF_CTX *ctx, int lookback_periods = 10, double min_volatility_ratio = 0.7, double max_volatility_ratio = 1.5)
{
   if (ctx == NULL)
      return false;

   CATR *atr = ctx.GetIndicator("ATR15");
   if (atr == NULL)
      return false;

   double current_atr = atr.GetValue(1);
   if (current_atr <= 0)
      return false;

   double sum_atr = 0;
   int valid_periods = 0;

   for (int i = 1; i <= lookback_periods; i++)
   {
      double period_atr = atr.GetValue(i);
      if (period_atr > 0)
      {
         sum_atr += period_atr;
         valid_periods++;
      }
   }

   if (valid_periods < lookback_periods / 2)
   {
      return false;
   }

   double avg_atr = sum_atr / valid_periods;
   double volatility_ratio = current_atr / avg_atr;

   return (volatility_ratio >= min_volatility_ratio && volatility_ratio <= max_volatility_ratio);
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em estrutura de alta                |
//+------------------------------------------------------------------+
bool CEmasBuyBull::IsInBullishStructure(TF_CTX *ctx, double atr_value)
{
   if (ctx == NULL)
      return false;

   CMovingAverages *sma200 = ctx.GetIndicator("sma200");
   CATR *atr = ctx.GetIndicator("ATR15");

   if (sma200 == NULL || atr == NULL)
      return false;

   string symbol = Symbol();
   ENUM_TIMEFRAMES tf = ctx.GetTimeFrame();

   double current_close = iClose(symbol, tf, 1);
   double sma200_val = sma200.GetValue(1);
   double atr_val = atr.GetValue(1);

   if (atr_val <= 0)
      return false;

   // Critério 1: Preço deve estar acima da SMA200
   if (current_close <= sma200_val)
   {
      return false;
   }

   // Critério 2: Preço deve estar a uma distância mínima da SMA200
   double distance_to_sma200 = (current_close - sma200_val) / atr_val;
   if (distance_to_sma200 < atr_value)
   {
      return false;
   }

   // Critério 3: SMA200 deve estar inclinada para cima
   SSlopeValidation sma200_slope = sma200.GetSlopeValidation(atr_val, COPY_MIDDLE);
   bool sma200_trending_up = (sma200_slope.simple_difference.trend_direction != "BAIXA" ||
                              sma200_slope.discrete_derivative.trend_direction != "BAIXA" ||
                              sma200_slope.linear_regression.trend_direction != "BAIXA");

   return sma200_trending_up;
}

//+------------------------------------------------------------------+
//| Verificar por sinal de entrada - LÓGICA MIGRADA DA CompraAlta   |
//+------------------------------------------------------------------+
SStrategySignal CEmasBuyBull::CheckForSignal()
{
   SStrategySignal signal;
   signal.Reset();

   // Obter contextos dos timeframes
   TF_CTX *ctx_m15 = m_context_provider.GetContext(m_symbol, PERIOD_M15);
   TF_CTX *ctx_m3 = m_context_provider.GetContext(m_symbol, PERIOD_M3);

   bool have_ctx_m15 = (ctx_m15 != NULL);
   bool have_ctx_m3 = (ctx_m3 != NULL);

   if (!have_ctx_m15 || !have_ctx_m3)
   {
      Print("AVISO: Contextos ausentes em CheckForSignal (M15:", have_ctx_m15, ", M3:", have_ctx_m3, ")");
      return signal;
   }

   // === INDICADORES M15 ===
   CMovingAverages *ema9_m15 = ctx_m15.GetIndicator("ema9");
   CMovingAverages *ema21_m15 = ctx_m15.GetIndicator("ema21");
   CMovingAverages *ema50_m15 = ctx_m15.GetIndicator("ema50");
   CATR *atr_m15 = ctx_m15.GetIndicator("ATR15");

   bool have_m15_emas = (ema9_m15 != NULL && ema21_m15 != NULL && ema50_m15 != NULL);
   if (!have_m15_emas)
   {
      Print("AVISO: Indicadores EMA (M15) ausentes em CheckForSignal");
      return signal;
   }

   double ema9_value_m15 = ema9_m15.GetValue(1);
   double ema21_value_m15 = ema21_m15.GetValue(1);
   double ema50_value_m15 = ema50_m15.GetValue(1);

   bool EMA9_above_EMA21_M15 = (ema9_value_m15 > ema21_value_m15);
   bool EMA21_above_EMA50_M15 = (ema21_value_m15 > ema50_value_m15);

   // === INDICADORES M3 ===
   CMovingAverages *ema9_m3 = ctx_m3.GetIndicator("ema9");
   CMovingAverages *ema21_m3 = ctx_m3.GetIndicator("ema21");
   CMovingAverages *ema50_m3 = ctx_m3.GetIndicator("ema50");
   CATR *atr_m3 = ctx_m3.GetIndicator("ATR15");

   bool have_m3_emas = (ema9_m3 != NULL && ema21_m3 != NULL && ema50_m3 != NULL);
   if (!have_m3_emas)
   {
      Print("AVISO: Indicadores EMA (M3) ausentes em CheckForSignal");
      return signal;
   }

   double ema9_value_m3 = ema9_m3.GetValue(1);
   double ema21_value_m3 = ema21_m3.GetValue(1);
   double ema50_value_m3 = ema50_m3.GetValue(1);

   bool EMA9_above_EMA21_M3 = (ema9_value_m3 > ema21_value_m3);
   bool EMA21_above_EMA50_M3 = (ema21_value_m3 > ema50_value_m3);

   double atr_value = (atr_m3 != NULL) ? atr_m3.GetValue(1) : 0.0;
   if (atr_m3 == NULL || atr_value <= 0.0)
   {
      Print("AVISO: ATR (M3) ausente ou inválido em CheckForSignal");
      return signal;
   }

   // === FILTROS DEPENDENTES ===
   bool strong_trend_m15 = IsStrongTrend(ctx_m15, 0.3, 0.5);
   bool bullish_momentum = HasBullishMomentum(ctx_m15, ctx_m3, 3);
   bool good_volatility_m15 = IsGoodVolatilityEnvironment(ctx_m15, 10, 0.7, 1.5);
   bool bullish_structure_m15 = IsInBullishStructure(ctx_m15, 0.5);
   bool bullish_structure_m3 = IsInBullishStructure(ctx_m3, 0.5);

   // Verificar ADX
   bool strong_trend_adx_m15 = false;
   double adx_value_m15 = 0.0;
   CADX *adx_m15 = ctx_m15.GetIndicator("ADX15");
   if (adx_m15 != NULL)
   {
      adx_value_m15 = adx_m15.GetValue(1);
      strong_trend_adx_m15 = (adx_value_m15 >= 25 && adx_value_m15 <= 60);
   }

   // === PONTOS DE ENTRADA ===
   SPositionInfo ema9_m3_position = ema9_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
   bool price_pullback_EMA9_M3 = (ema9_m3_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
                                  ema9_m3_position.position == INDICATOR_CROSSES_LOWER_BODY ||
                                  ema9_m3_position.position == INDICATOR_CROSSES_CENTER_BODY);
   bool valid_pullback_EMA9_M3 = IsValidPullback(ema9_m3_position, atr_value, ctx_m3, ema9_m3, 0.8, 3);

   SPositionInfo ema21_m3_position = ema21_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
   bool price_pullback_EMA21_M3 = (ema21_m3_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
                                   ema21_m3_position.position == INDICATOR_CROSSES_LOWER_BODY ||
                                   ema21_m3_position.position == INDICATOR_CROSSES_CENTER_BODY);
   bool valid_pullback_EMA21_M3 = IsValidPullback(ema21_m3_position, atr_value, ctx_m3, ema21_m3, 0.8, 3);

   // === CRITÉRIO FINAL DE ENTRADA ===
   bool filtros_ok = EMA9_above_EMA21_M15 && EMA21_above_EMA50_M15 &&
                     EMA9_above_EMA21_M3 && EMA21_above_EMA50_M3 &&
                     strong_trend_m15 && bullish_momentum && good_volatility_m15 &&
                     bullish_structure_m15 && bullish_structure_m3 &&
                     strong_trend_adx_m15;

   bool entrada_setup_ok = (price_pullback_EMA9_M3 && valid_pullback_EMA9_M3) ||
                           (price_pullback_EMA21_M3 && valid_pullback_EMA21_M3);

   bool entrada_valida = filtros_ok && entrada_setup_ok;

   // === LOG SIMPLIFICADO ===
   if (entrada_valida)
   {
      Print("✅ EMA Bull Buy - SINAL VÁLIDO para ", m_symbol);
      Print("   Filtros: Alinhamento EMAs ✓, Tendência forte ✓, Momentum bullish ✓");
      Print("   Entrada: Pullback válido detectado em ", 
            (price_pullback_EMA9_M3 && valid_pullback_EMA9_M3) ? "EMA9" : "EMA21", " M3");
   }
   else
   {
      Print("❌ EMA Bull Buy - Sinal inválido para ", m_symbol);
      Print("   Filtros OK: ", filtros_ok ? "Sim" : "Não", " | Setup OK: ", entrada_setup_ok ? "Sim" : "Não");
   }

   // Criar sinal se válido
   if (entrada_valida)
   {
      signal.type = SIGNAL_BUY;
      signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      signal.lot_size = CalculateLotSize();
      signal.stop_loss = CalculateStopLoss(signal.entry_price);
      signal.take_profit = CalculateTakeProfit(signal.entry_price, signal.stop_loss);
      signal.signal_time = TimeCurrent();
      signal.comment = "EMA Bull Buy - " + m_name;
      signal.is_valid = true;
   }

   return signal;
}

//+------------------------------------------------------------------+
//| Calcular tamanho do lote                                        |
//+------------------------------------------------------------------+
double CEmasBuyBull::CalculateLotSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = balance * (m_config.risk_percent / 100.0);

   double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

   double lot_size = MathMax(min_lot, risk_amount / 1000.0);
   lot_size = MathMin(lot_size, max_lot);

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
   if (signal.type != SIGNAL_BUY)
      return false;

   if (signal.entry_price <= 0 || signal.lot_size <= 0)
      return false;

   if (signal.stop_loss >= signal.entry_price)
      return false;

   if (signal.take_profit <= signal.entry_price)
      return false;

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

//+------------------------------------------------------------------+
//| Método especial para log completo de debug da estratégia         |
//+------------------------------------------------------------------+
void CEmasBuyBull::PrintFullDebugLog()
{
    Print("=== DEBUG LOG COMPLETO - EMA Bull Buy ===");
    Print("Símbolo: ", m_symbol, " | Timeframe Atual: ", EnumToString(m_timeframe));
    Print("Estado da Estratégia: ", EnumToString(GetState()));
    Print("Último Sinal: ", GetLastSignal().is_valid ? "Válido" : "Inválido");

    // Obter contextos
    TF_CTX *ctx_m15 = m_context_provider.GetContext(m_symbol, PERIOD_M15);
    TF_CTX *ctx_m3 = m_context_provider.GetContext(m_symbol, PERIOD_M3);

    if (ctx_m15 == NULL || ctx_m3 == NULL)
    {
        Print("ERRO: Contextos ausentes (M15: ", ctx_m15 != NULL, ", M3: ", ctx_m3 != NULL, ")");
        return;
    }

    // Indicadores M15
    CMovingAverages *ema9_m15 = ctx_m15.GetIndicator("ema9");
    CMovingAverages *ema21_m15 = ctx_m15.GetIndicator("ema21");
    CMovingAverages *ema50_m15 = ctx_m15.GetIndicator("ema50");
    CATR *atr_m15 = ctx_m15.GetIndicator("ATR15");
    CADX *adx_m15 = ctx_m15.GetIndicator("ADX15");

    Print("--- INDICADORES M15 ---");
    if (ema9_m15) Print("EMA9: ", DoubleToString(ema9_m15.GetValue(1), _Digits));
    if (ema21_m15) Print("EMA21: ", DoubleToString(ema21_m15.GetValue(1), _Digits));
    if (ema50_m15) Print("EMA50: ", DoubleToString(ema50_m15.GetValue(1), _Digits));
    if (atr_m15) Print("ATR: ", DoubleToString(atr_m15.GetValue(1), 5));
    if (adx_m15) Print("ADX: ", DoubleToString(adx_m15.GetValue(1), 2));

    // Indicadores M3
    CMovingAverages *ema9_m3 = ctx_m3.GetIndicator("ema9");
    CMovingAverages *ema21_m3 = ctx_m3.GetIndicator("ema21");
    CMovingAverages *ema50_m3 = ctx_m3.GetIndicator("ema50");
    CATR *atr_m3 = ctx_m3.GetIndicator("ATR15");

    Print("--- INDICADORES M3 ---");
    if (ema9_m3) Print("EMA9: ", DoubleToString(ema9_m3.GetValue(1), _Digits));
    if (ema21_m3) Print("EMA21: ", DoubleToString(ema21_m3.GetValue(1), _Digits));
    if (ema50_m3) Print("EMA50: ", DoubleToString(ema50_m3.GetValue(1), _Digits));
    if (atr_m3) Print("ATR: ", DoubleToString(atr_m3.GetValue(1), 5));

    // Valores calculados
    double atr_value = (atr_m3 != NULL) ? atr_m3.GetValue(1) : 0.0;
    Print("ATR Value (usado): ", DoubleToString(atr_value, 5));

    // Condições booleanas
    bool EMA9_above_EMA21_M15 = (ema9_m15 && ema21_m15) ? (ema9_m15.GetValue(1) > ema21_m15.GetValue(1)) : false;
    bool EMA21_above_EMA50_M15 = (ema21_m15 && ema50_m15) ? (ema21_m15.GetValue(1) > ema50_m15.GetValue(1)) : false;
    bool EMA9_above_EMA21_M3 = (ema9_m3 && ema21_m3) ? (ema9_m3.GetValue(1) > ema21_m3.GetValue(1)) : false;
    bool EMA21_above_EMA50_M3 = (ema21_m3 && ema50_m3) ? (ema21_m3.GetValue(1) > ema50_m3.GetValue(1)) : false;

    Print("--- CONDIÇÕES DE ALINHAMENTO EMAs ---");
    Print("M15 - EMA9 > EMA21: ", EMA9_above_EMA21_M15 ? "Sim" : "Não");
    Print("M15 - EMA21 > EMA50: ", EMA21_above_EMA50_M15 ? "Sim" : "Não");
    Print("M3 - EMA9 > EMA21: ", EMA9_above_EMA21_M3 ? "Sim" : "Não");
    Print("M3 - EMA21 > EMA50: ", EMA21_above_EMA50_M3 ? "Sim" : "Não");

    // Filtros dependentes
    bool strong_trend_m15 = IsStrongTrend(ctx_m15, 0.3, 0.5);
    bool bullish_momentum = HasBullishMomentum(ctx_m15, ctx_m3, 3);
    bool good_volatility_m15 = IsGoodVolatilityEnvironment(ctx_m15, 10, 0.7, 1.5);
    bool bullish_structure_m15 = IsInBullishStructure(ctx_m15, 0.5);
    bool bullish_structure_m3 = IsInBullishStructure(ctx_m3, 0.5);
    bool strong_trend_adx_m15 = (adx_m15 != NULL) ? (adx_m15.GetValue(1) >= 25 && adx_m15.GetValue(1) <= 60) : false;

    Print("--- FILTROS DEPENDENTES ---");
    Print("Tendência Forte (M15): ", strong_trend_m15 ? "Sim" : "Não");
    Print("Momentum Bullish: ", bullish_momentum ? "Sim" : "Não");
    Print("Volatilidade Boa (M15): ", good_volatility_m15 ? "Sim" : "Não");
    Print("Estrutura Bullish (M15): ", bullish_structure_m15 ? "Sim" : "Não");
    Print("Estrutura Bullish (M3): ", bullish_structure_m3 ? "Sim" : "Não");
    Print("ADX Forte (M15): ", strong_trend_adx_m15 ? "Sim" : "Não");

    // Pontos de entrada
    SPositionInfo ema9_m3_position = ema9_m3 ? ema9_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value) : SPositionInfo();
    SPositionInfo ema21_m3_position = ema21_m3 ? ema21_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value) : SPositionInfo();

    bool price_pullback_EMA9_M3 = (ema9_m3_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
                                   ema9_m3_position.position == INDICATOR_CROSSES_LOWER_BODY ||
                                   ema9_m3_position.position == INDICATOR_CROSSES_CENTER_BODY);
    bool valid_pullback_EMA9_M3 = ema9_m3 ? IsValidPullback(ema9_m3_position, atr_value, ctx_m3, ema9_m3, 0.8, 3) : false;

    bool price_pullback_EMA21_M3 = (ema21_m3_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
                                    ema21_m3_position.position == INDICATOR_CROSSES_LOWER_BODY ||
                                    ema21_m3_position.position == INDICATOR_CROSSES_CENTER_BODY);
    bool valid_pullback_EMA21_M3 = ema21_m3 ? IsValidPullback(ema21_m3_position, atr_value, ctx_m3, ema21_m3, 0.8, 3) : false;

    Print("--- PONTOS DE ENTRADA (M3) ---");
    Print("Pullback EMA9: Posição=", EnumToString(ema9_m3_position.position), " | Válido=", valid_pullback_EMA9_M3 ? "Sim" : "Não");
    Print("Pullback EMA21: Posição=", EnumToString(ema21_m3_position.position), " | Válido=", valid_pullback_EMA21_M3 ? "Sim" : "Não");

    // Critérios finais
    bool filtros_ok = EMA9_above_EMA21_M15 && EMA21_above_EMA50_M15 &&
                      EMA9_above_EMA21_M3 && EMA21_above_EMA50_M3 &&
                      strong_trend_m15 && bullish_momentum && good_volatility_m15 &&
                      bullish_structure_m15 && bullish_structure_m3 &&
                      strong_trend_adx_m15;

    bool entrada_setup_ok = (price_pullback_EMA9_M3 && valid_pullback_EMA9_M3) ||
                            (price_pullback_EMA21_M3 && valid_pullback_EMA21_M3);

    bool entrada_valida = filtros_ok && entrada_setup_ok;

    Print("--- CRITÉRIOS FINAIS ---");
    Print("Filtros OK: ", filtros_ok ? "Sim" : "Não");
    Print("Setup de Entrada OK: ", entrada_setup_ok ? "Sim" : "Não");
    Print("ENTRADA VÁLIDA: ", entrada_valida ? "SIM" : "NÃO");

    Print("=== FIM DO DEBUG LOG ===");
}
#endif