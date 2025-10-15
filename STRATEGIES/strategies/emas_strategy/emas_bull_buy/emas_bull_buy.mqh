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

#include "../../strategy_base/strategy_base.mqh"
// #include "emas_bull_buy_defs.mqh"
#include "../emas_strategy_defs.mqh"

//+------------------------------------------------------------------+
//| Estratégia EMA Buy Bull - Compra em tendência de alta com EMAs  |
//+------------------------------------------------------------------+
class CEmasBuyBull : public CStrategyBase
{
private:
   CEmasBullBuyConfig m_config;

   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;

   // Estruturas de Dados
   SDistance_MA distance_ma_m3;
   SDistance_MA distance_ma_m15;
   SVolatilityEnv volatilityEnv_M15;
   SStrongTrendADX SStrong_trend_ADX_m15;
   SBollingerValidStructure bollStructure_M3;
   SBullishMomentum bullishMomentumState;
   SBullishStructure bullishStructureState_M15;
   SBullishStructure bullishStructureState_M3;
   SEMAAlignmentState emaAlignmentState_M15;
   SEMAAlignmentState emaAlignmentState_M3;
   SPullbackValidation pullbackEMA9State_M3;
   SPullbackValidation pullbackEMA21State_M3;
   SLastSignalEvaluation lastSignalEvaluation;

   void ResetValidationState();
   void PopulateDistanceState(SDistance_MA &state,
                              ENUM_TIMEFRAMES timeframe,
                              double ema9_val,
                              double ema21_val,
                              double ema50_val,
                              double atr_val,
                              double min_distance_9_21_cfg,
                              double min_distance_21_50_cfg);

   double CalculateLotSize();
   double CalculateStopLoss(double entry_price);
   double CalculateTakeProfit(double entry_price, double stop_loss);

   // Métodos auxiliares migrados da lógica CompraAlta
   bool IsStrongTrend(TF_CTX *ctx);
   bool HasBullishMomentum(TF_CTX *ctx_m15, TF_CTX *ctx_m3);
   bool IsValidPullback(SPositionInfo &position_info, double atr_value, TF_CTX *ctx, CMovingAverages *ma, SPullbackValidation &validation_state);
   bool IsGoodVolatilityEnvironment(TF_CTX *ctx);
   void DiagnoseFailedPullback(const SPullbackValidation &validation_state);
   bool IsInBullishStructure(TF_CTX *ctx);
   bool EvaluateBullishStructure(TF_CTX *ctx, SBullishStructure &structure_state);
   bool BollingerHasValidStructure(TF_CTX *ctx);

protected:
   virtual bool DoInit() override;
   virtual bool DoUpdate() override;
   virtual SStrategySignal CheckForSignal() override;
   virtual bool ValidateSignal(const SStrategySignal &signal) override;
   virtual void DoLog() override;

public:
   CEmasBuyBull(IContextProvider *context_provider = NULL);
   ~CEmasBuyBull();

   bool Init(string name, const CEmasBullBuyConfig &config);

   // Override to return strategy configuration
   virtual CStrategyConfig *GetStrategyConfig() override;
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
//| Resetar estado interno das validações                           |
//+------------------------------------------------------------------+
void CEmasBuyBull::ResetValidationState()
{
   distance_ma_m3.Reset();
   distance_ma_m15.Reset();
   volatilityEnv_M15.Reset();
   SStrong_trend_ADX_m15.Reset();
   bollStructure_M3.Reset();
   bullishMomentumState.Reset();
   bullishStructureState_M15.Reset();
   bullishStructureState_M3.Reset();
   emaAlignmentState_M15.Reset();
   emaAlignmentState_M3.Reset();
   pullbackEMA9State_M3.Reset();
   pullbackEMA21State_M3.Reset();
   lastSignalEvaluation.Reset();
}

void CEmasBuyBull::PopulateDistanceState(SDistance_MA &state,
                                         ENUM_TIMEFRAMES timeframe,
                                         double ema9_val,
                                         double ema21_val,
                                         double ema50_val,
                                         double atr_val,
                                         double min_distance_9_21_cfg,
                                         double min_distance_21_50_cfg)
{
   state.Reset();
   state.timeframe = timeframe;
   state.is_enabled = true;
   state.is_evaluated = true;
   state.ema9_value = ema9_val;
   state.ema21_value = ema21_val;
   state.ema50_value = ema50_val;
   state.atr_value = atr_val;
   state.min_distance_9_21_config = min_distance_9_21_cfg;
   state.min_distance_21_50_config = min_distance_21_50_cfg;

   state.ema_21_50 = MathAbs(ema50_val - ema21_val);
   state.ema_9_21 = MathAbs(ema21_val - ema9_val);
   state.ema_9_50 = MathAbs(ema50_val - ema9_val);

   state.ema_21_50_by_atr = state.ema_21_50 / atr_val;
   state.ema_9_21_by_atr = state.ema_9_21 / atr_val;
   state.ema_9_50_by_atr = state.ema_9_50 / atr_val;
}

//+------------------------------------------------------------------+
//| Verificar se há tendência forte baseada na distância entre médias |
//+------------------------------------------------------------------+
bool CEmasBuyBull::IsStrongTrend(TF_CTX *ctx)
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

   bool strong_trend = false;
   ENUM_TIMEFRAMES timeframe = ctx.GetTimeFrame();
   double min_distance_9_21_cfg = 0.0;
   double min_distance_21_50_cfg = 0.0;

   if (timeframe == PERIOD_M15)
   {
      min_distance_9_21_cfg = m_config.min_distance_9_21_atr_m15;
      min_distance_21_50_cfg = m_config.min_distance_21_50_atr_m15;
      PopulateDistanceState(distance_ma_m15, timeframe, ema9_val, ema21_val, ema50_val, atr_val,
                            min_distance_9_21_cfg, min_distance_21_50_cfg);
   }
   else if (timeframe == PERIOD_M3)
   {
      min_distance_9_21_cfg = m_config.min_distance_9_21_atr_m3;
      min_distance_21_50_cfg = m_config.min_distance_21_50_atr_m3;
      PopulateDistanceState(distance_ma_m3, timeframe, ema9_val, ema21_val, ema50_val, atr_val,
                            min_distance_9_21_cfg, min_distance_21_50_cfg);
   }
   else
   {
      Print("!!!!!!!!!!!!!!!!!!!!!!!!!! STRONG TREND NÃO CONFIGURADA EM CEmasBuyBull::IsStrongTrend  - !M3 ou M15!");
   }

   if (timeframe == PERIOD_M15)
   {
      strong_trend = (dist_9_21 >= m_config.min_distance_9_21_atr_m15 && dist_21_50 >= m_config.min_distance_21_50_atr_m15);
   }
   else if (timeframe == PERIOD_M3)
   {
      strong_trend = (dist_9_21 >= m_config.min_distance_9_21_atr_m3 && dist_21_50 >= m_config.min_distance_21_50_atr_m3);
   }

   if (timeframe == PERIOD_M15)
   {
      distance_ma_m15.is_strong_trend = strong_trend;
   }
   else if (timeframe == PERIOD_M3)
   {
      distance_ma_m3.is_strong_trend = strong_trend;
   }

   return strong_trend;
}

//+------------------------------------------------------------------+
//| Verificar momentum bullish através de price action              |
//+------------------------------------------------------------------+
bool CEmasBuyBull::HasBullishMomentum(TF_CTX *ctx_m15, TF_CTX *ctx_m3)
{
   if (ctx_m15 == NULL || ctx_m3 == NULL)
      return false;

   CMovingAverages *ema21_m15 = ctx_m15.GetIndicator("ema21");
   if (ema21_m15 == NULL)
      return false;

   string symbol = Symbol();

   bullishMomentumState.Reset();
   bullishMomentumState.is_enabled = true;
   bullishMomentumState.is_evaluated = true;

   // Critério 1: Verificar se o preço está consistentemente acima da EMA21 no M15
   int candles_above_ema21 = 0;
   for (int i = 1; i <= m_config.lookback_candles; i++)
   {
      double close = iClose(m_current_symbol, PERIOD_M15, i);
      double ema21_val = ema21_m15.GetValue(i);
      if (close > ema21_val)
      {
         candles_above_ema21++;
      }
   }
   bool price_above_ema21 = (candles_above_ema21 >= 2);

   bullishMomentumState.candles_above_ema21 = candles_above_ema21;
   bullishMomentumState.price_above_ema21 = price_above_ema21;

   // Critério 2: Verificar se não há sinais de pânico de venda
   bool no_panic_selling = true;
   for (int i = 1; i <= 2; i++)
   {
      double open = iOpen(m_current_symbol, PERIOD_M3, i);
      double close = iClose(m_current_symbol, PERIOD_M3, i);
      double low = iLow(m_current_symbol, PERIOD_M3, i);
      double high = iHigh(m_current_symbol, PERIOD_M3, i);

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
   double last_open = iOpen(m_current_symbol, PERIOD_M3, 1);
   double last_close = iClose(m_current_symbol, PERIOD_M3, 1);
   bool last_candle_bullish = (last_close >= last_open);

   bullishMomentumState.no_panic_selling = no_panic_selling;
   bullishMomentumState.last_candle_bullish = last_candle_bullish;

   bullishMomentumState.is_valid = price_above_ema21 && no_panic_selling && last_candle_bullish;

   return bullishMomentumState.is_valid;
}

//+------------------------------------------------------------------+
//| Validar se é um pullback adequado (para BAIXO, até suporte EMA) |
//| VERSÃO FINAL - BASEADA EM CONCEITO REAL DE PULLBACK             |
//+------------------------------------------------------------------+
// Conceito: Pullback é uma RETRAÇÃO TEMPORÁRIA em uma tendência
// Em tendência de ALTA (bull):
// 1. Preço estava LONGE acima da EMA (estrutura clara de alta)
// 2. Preço RECUA (pode cruzar ou tocar levemente a EMA)
// 3. A penetração abaixo da EMA é permitida (dentro de limites)
// 4. O importante é que veio de distância anterior MAIOR
//+------------------------------------------------------------------+

bool CEmasBuyBull::IsValidPullback(SPositionInfo &position_info, double atr_value, TF_CTX *ctx, CMovingAverages *ma, SPullbackValidation &validation_state)
{
   string label = validation_state.label;
   validation_state.Reset();
   validation_state.label = label;
   validation_state.is_enabled = true;
   validation_state.is_valid = false;

   if (ctx == NULL || ma == NULL || atr_value <= 0)
   {
      Print("[PULLBACK DEBUG] Contexto ou indicadores nulos. Retornando false.");

      validation_state.timeframe = (ctx != NULL) ? ctx.GetTimeFrame() : PERIOD_CURRENT;
      validation_state.position_info = position_info;
      validation_state.atr_value = atr_value;
      validation_state.inputs_valid = false;
      validation_state.is_evaluated = true;

      return false;
   }

   int digits = (int)SymbolInfoInteger(m_current_symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(m_current_symbol, SYMBOL_POINT);
   double pip_value = (digits == 3 || digits == 5) ? point * 10.0 : point;

   validation_state.pip_value = pip_value;

   if (pip_value <= 0)
   {
      Print("[PULLBACK DEBUG] Pip value inválido. Retornando false.");

      validation_state.timeframe = ctx.GetTimeFrame();
      validation_state.position_info = position_info;
      validation_state.atr_value = atr_value;
      validation_state.inputs_valid = false;
      validation_state.is_evaluated = true;

      return false;
   }

   // position_info.distance vem em pips. Convertendo para preço garante que as
   // comparações com o ATR (que está em preço) utilizem a mesma unidade.
   double distance_price = position_info.distance * pip_value;

   ENUM_TIMEFRAMES tf = ctx.GetTimeFrame();
   double last_close = iClose(m_current_symbol, tf, 1);
   double last_low = iLow(m_current_symbol, tf, 1);
   double current_ma = ma.GetValue(1);
   string tf_name = EnumToString(tf);

   validation_state.timeframe = tf;
   validation_state.position_info = position_info;
   validation_state.atr_value = atr_value;
   validation_state.current_ma = current_ma;
   validation_state.last_close = last_close;
   validation_state.last_low = last_low;
   validation_state.distance_price = distance_price;
   validation_state.inputs_valid = true;
   validation_state.is_evaluated = true;

   Print("[PULLBACK DEBUG] ========================================");
   Print("[PULLBACK DEBUG] Iniciando validação de pullback para ", tf_name);
   Print("[PULLBACK DEBUG] Preço Atual: ", DoubleToString(last_close, _Digits));
   Print("[PULLBACK DEBUG] EMA Atual: ", DoubleToString(current_ma, _Digits));
   Print("[PULLBACK DEBUG] ATR Valor: ", DoubleToString(atr_value, 5));
   Print("[PULLBACK DEBUG] Distance Info (pips): ", DoubleToString(position_info.distance, 5));
   Print("[PULLBACK DEBUG] Distance Info (preço): ", DoubleToString(distance_price, 5));
   Print("[PULLBACK DEBUG] Position Type: ", EnumToString(position_info.position));

   Print("[PULLBACK DEBUG] ✓ Critério 1 SKIP: Será validado pelo Critério 3 (estrutura anterior)");

   // CRITÉRIO 2
   double max_depth = (m_config.max_distance_atr + 0.5) * atr_value;
   bool depth_ok = (distance_price <= max_depth);

   validation_state.max_depth = max_depth;
   validation_state.depth_ok = depth_ok;

   if (!depth_ok)
   {
      Print("[PULLBACK DEBUG] ❌ CRITÉRIO 2 FALHOU: Pullback muito profundo");
      Print("[PULLBACK DEBUG]    Distance: ", DoubleToString(distance_price, 5),
            " > Max permitido: ", DoubleToString(max_depth, 5),
            " (config: ", DoubleToString(m_config.max_distance_atr, 2), " ATR + 0.5 buffer)");
      return false;
   }

   Print("[PULLBACK DEBUG] ✓ Critério 2 OK: Profundidade dentro dos limites (",
         DoubleToString(distance_price / atr_value, 2), " ATR)");

   // CRITÉRIO 3
   bool was_further_above = false;
   int lookback_start = 2;
   int lookback_end = MathMin(m_config.max_duration_candles + 1, 10);
   double current_distance_atr = distance_price / atr_value;
   double best_previous_atr = 0.0;
   int found_at_bar = -1;

   validation_state.lookback_start = lookback_start;
   validation_state.lookback_end = lookback_end;
   validation_state.current_distance_atr = current_distance_atr;

   Print("[PULLBACK DEBUG] Procurando por distância anterior MAIOR (barras ", lookback_start, " a ", lookback_end, ")");

   for (int i = lookback_start; i <= lookback_end; i++)
   {
      double prev_close = iClose(m_current_symbol, tf, i);
      double prev_ma = ma.GetValue(i);

      if (prev_close > prev_ma)
      {
         double prev_distance = prev_close - prev_ma;
         double prev_distance_atr = prev_distance / atr_value;

         if (prev_distance_atr > best_previous_atr)
            best_previous_atr = prev_distance_atr;

         if (prev_distance_atr > current_distance_atr * 1.15)
         {
            was_further_above = true;
            found_at_bar = i;
            Print("[PULLBACK DEBUG] ✓ Encontrado pullback válido na barra ", i);
            Print("[PULLBACK DEBUG]    Distância anterior (ATR): ", DoubleToString(prev_distance_atr, 2),
                  " | Distância atual (ATR): ", DoubleToString(current_distance_atr, 2));
            break;
         }
      }
   }

   validation_state.was_further_above = was_further_above;
   validation_state.found_at_bar = found_at_bar;
   validation_state.best_previous_distance_atr = best_previous_atr;

   if (!was_further_above)
   {
      Print("[PULLBACK DEBUG] ❌ CRITÉRIO 3 FALHOU: Não veio de distância anterior significativa");
      Print("[PULLBACK DEBUG]    Nenhuma barra anterior teve distância >15% maior que atual");
      return false;
   }

   Print("[PULLBACK DEBUG] ✓ Critério 3 OK: Comprovado retração de posição anterior");

   // CRITÉRIO 4
   bool invalid_position_for_pullback = (
      position_info.position == INDICATOR_CROSSES_UPPER_SHADOW ||
      position_info.position == CANDLE_BELOW ||
      position_info.position == CANDLE_COMPLETELY_BELOW ||
      position_info.position == CANDLE_BELOW_WITH_DISTANCE ||
      position_info.position == INDICATOR_CANDLE_POSITION_FAILED
   );

   validation_state.invalid_position_for_pullback = invalid_position_for_pullback;

   if (invalid_position_for_pullback)
   {
      Print("[PULLBACK DEBUG] ❌ CRITÉRIO 4 FALHOU: Padrão indica reversão, não pullback");
      Print("[PULLBACK DEBUG]    Position: ", EnumToString(position_info.position));
      return false;
   }

   Print("[PULLBACK DEBUG] ✓ Critério 4 OK: Padrão de posição válido (", EnumToString(position_info.position), ")");

   // CRITÉRIO 5
   double max_penetration_below_ema = 1.5 * atr_value;
   double penetration = MathMax(0, current_ma - last_low);
   bool penetration_ok = (penetration <= max_penetration_below_ema);

   validation_state.max_penetration_allowed = max_penetration_below_ema;
   validation_state.penetration = penetration;
   validation_state.penetration_ok = penetration_ok;

   if (!penetration_ok)
   {
      Print("[PULLBACK DEBUG] ❌ CRITÉRIO 5 FALHOU: Penetração muito profunda abaixo da EMA");
      Print("[PULLBACK DEBUG]    Penetração: ", DoubleToString(penetration, 5),
            " > Max permitido: ", DoubleToString(max_penetration_below_ema, 5),
            " (1.5 ATR)");
      return false;
   }

   Print("[PULLBACK DEBUG] ✓ Critério 5 OK: Penetração abaixo da EMA dentro dos limites (",
         DoubleToString(penetration, 5), " pontos)");

   validation_state.is_valid = true;

   Print("[PULLBACK DEBUG] ✅ PULLBACK VÁLIDO CONFIRMADO - ESTRUTURA DE ALTA COMPROVADA");
   Print("[PULLBACK DEBUG] ========================================");
   return true;
}

//+------------------------------------------------------------------+
// FUNÇÃO AUXILIAR: Diagnóstico completo
//+------------------------------------------------------------------+
void CEmasBuyBull::DiagnoseFailedPullback(const SPullbackValidation &validation_state)
{
   if (!validation_state.is_evaluated || validation_state.is_valid || !validation_state.inputs_valid)
      return;

   Print("\n[DIAGNÓSTICO] ==========================================");
   Print("[DIAGNÓSTICO] Diagnóstico de falha de pullback ", validation_state.label != "" ? "(" + validation_state.label + ")" : "", " para ", EnumToString(validation_state.timeframe));
   Print("[DIAGNÓSTICO] Preço: ", DoubleToString(validation_state.last_close, _Digits),
         " | EMA: ", DoubleToString(validation_state.current_ma, _Digits));
   Print("[DIAGNÓSTICO] Distance (pips): ", DoubleToString(validation_state.position_info.distance, 5));
   Print("[DIAGNÓSTICO] Distance (preço): ", DoubleToString(validation_state.distance_price, 5));
   Print("[DIAGNÓSTICO] Position: ", EnumToString(validation_state.position_info.position));
   Print("[DIAGNÓSTICO] ATR: ", DoubleToString(validation_state.atr_value, 5));

   int criteria_passed = 0;

   Print("[DIAGNÓSTICO] ✓ Critério 1: Pulado (será validado por Critério 3)");
   criteria_passed++;

   if (validation_state.depth_ok)
   {
      Print("[DIAGNÓSTICO] ✓ Critério 2: Profundidade OK");
      criteria_passed++;
   }
   else
   {
      Print("[DIAGNÓSTICO] ❌ Critério 2 FALHOU: Profundidade excessiva");
      Print("[DIAGNÓSTICO]    Distance: ", DoubleToString(validation_state.distance_price, 5),
            " | Max: ", DoubleToString(validation_state.max_depth, 5));
   }

   if (validation_state.was_further_above)
   {
      Print("[DIAGNÓSTICO] ✓ Critério 3: Distância anterior significativa");
      Print("[DIAGNÓSTICO]    Encontrado na barra ", validation_state.found_at_bar);
      criteria_passed++;
   }
   else
   {
      Print("[DIAGNÓSTICO] ❌ Critério 3 FALHOU: Sem distância anterior 15% maior");
      Print("[DIAGNÓSTICO]    Distância atual: ", DoubleToString(validation_state.current_distance_atr, 2), " ATR");
      Print("[DIAGNÓSTICO]    Melhor distância anterior: ", DoubleToString(validation_state.best_previous_distance_atr, 2), " ATR");
      Print("[DIAGNÓSTICO]    Necessário: ", DoubleToString(validation_state.current_distance_atr * 1.15, 2), " ATR");
   }

   if (!validation_state.invalid_position_for_pullback)
   {
      Print("[DIAGNÓSTICO] ✓ Critério 4: Padrão de posição válido");
      criteria_passed++;
   }
   else
   {
      Print("[DIAGNÓSTICO] ❌ Critério 4 FALHOU: Padrão inválido");
      Print("[DIAGNÓSTICO]    Position: ", EnumToString(validation_state.position_info.position));
   }

   if (validation_state.penetration_ok)
   {
      Print("[DIAGNÓSTICO] ✓ Critério 5: Penetração abaixo da EMA OK");
      criteria_passed++;
   }
   else
   {
      Print("[DIAGNÓSTICO] ❌ Critério 5 FALHOU: Penetração excessiva");
      Print("[DIAGNÓSTICO]    Penetração: ", DoubleToString(validation_state.penetration, 5),
            " | Max permitido: ", DoubleToString(validation_state.max_penetration_allowed, 5));
   }

   Print("[DIAGNÓSTICO] ==========================================");
   Print("[DIAGNÓSTICO] RESULTADO: ", criteria_passed, "/5 critérios passaram");
   Print("[DIAGNÓSTICO] ==========================================\n");
}
//+------------------------------------------------------------------+
//| Analisar ambiente de volatilidade                               |
//+------------------------------------------------------------------+
bool CEmasBuyBull::IsGoodVolatilityEnvironment(TF_CTX *ctx)
{
   if (ctx == NULL)
      return false;

   CATR *atr = ctx.GetIndicator("ATR15");
   if (atr == NULL)
      return false;

   double current_atr = atr.GetValue(1);
   if (current_atr <= 0)
      return false;

   volatilityEnv_M15.Reset();
   volatilityEnv_M15.is_enabled = true;
   volatilityEnv_M15.is_evaluated = true;
   volatilityEnv_M15.current_atr = current_atr;

   double sum_atr = 0;
   int valid_periods = 0;

   for (int i = 1; i <= m_config.lookback_periods; i++)
   {
      double period_atr = atr.GetValue(i);
      if (period_atr > 0)
      {
         sum_atr += period_atr;
         valid_periods++;
      }
   }

   if (valid_periods < m_config.lookback_periods / 2)
   {
      volatilityEnv_M15.valid_periods = valid_periods;
      volatilityEnv_M15.avg_atr = (valid_periods > 0) ? sum_atr / valid_periods : 0.0;
      volatilityEnv_M15.volatility_ratio = 0.0;
      volatilityEnv_M15.is_good_volatility = false;
      return false;
   }

   double avg_atr = sum_atr / valid_periods;
   double volatility_ratio = current_atr / avg_atr;

   volatilityEnv_M15.avg_atr = avg_atr;
   volatilityEnv_M15.volatility_ratio = volatility_ratio;
    volatilityEnv_M15.valid_periods = valid_periods;

   bool result = (volatility_ratio >= m_config.min_volatility_ratio && volatility_ratio <= m_config.max_volatility_ratio);
   volatilityEnv_M15.is_good_volatility = result;

   return result;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em estrutura de alta                |
//+------------------------------------------------------------------+
bool CEmasBuyBull::IsInBullishStructure(TF_CTX *ctx)
{
   if (ctx == NULL)
      return false;

   ENUM_TIMEFRAMES tf = ctx.GetTimeFrame();

   if (tf == PERIOD_M15)
      return EvaluateBullishStructure(ctx, bullishStructureState_M15);

   if (tf == PERIOD_M3)
      return EvaluateBullishStructure(ctx, bullishStructureState_M3);

   SBullishStructure temp_state;
   temp_state.Reset();
   return EvaluateBullishStructure(ctx, temp_state);
}

bool CEmasBuyBull::EvaluateBullishStructure(TF_CTX *ctx, SBullishStructure &structure_state)
{
   CMovingAverages *ema50 = ctx.GetIndicator("ema50");
   CATR *atr = ctx.GetIndicator("ATR15");

   if (ema50 == NULL || atr == NULL)
      return false;

   structure_state.Reset();
   structure_state.timeframe = ctx.GetTimeFrame();
   structure_state.is_enabled = true;

   double current_close = iClose(m_current_symbol, structure_state.timeframe, 1);
   double ema50_val = ema50.GetValue(1);
   double atr_val = atr.GetValue(1);

   if (atr_val <= 0)
   {
      structure_state.atr_value = atr_val;
      structure_state.is_valid = false;
      structure_state.is_evaluated = true;
      return false;
   }

   structure_state.current_close = current_close;
   structure_state.ema50_value = ema50_val;
   structure_state.atr_value = atr_val;
   structure_state.threshold_config = m_config.bullish_structure_atr_threshold;
   structure_state.is_evaluated = true;

   if (current_close <= ema50_val)
   {
      structure_state.price_above_ema50 = false;
      structure_state.is_valid = false;
      return false;
   }

   structure_state.price_above_ema50 = true;

   double distance_to_ema50 = (current_close - ema50_val) / atr_val;
   structure_state.distance_to_ema50 = distance_to_ema50;

   if (distance_to_ema50 < m_config.bullish_structure_atr_threshold)
   {
      structure_state.distance_ok = false;
      structure_state.is_valid = false;
      return false;
   }

   structure_state.distance_ok = true;

   SSlopeValidation ema50_slope = ema50.GetSlopeValidation(atr_val, COPY_MIDDLE);
   bool ema50_trending_up = (ema50_slope.simple_difference.trend_direction != SLOPE_DOWN ||
                             ema50_slope.discrete_derivative.trend_direction != SLOPE_DOWN ||
                             ema50_slope.linear_regression.trend_direction != SLOPE_DOWN);

   structure_state.ema50_slope = ema50_slope;
   structure_state.ema50_trending_up = ema50_trending_up;
   structure_state.is_valid = ema50_trending_up;

   return ema50_trending_up;
}

//+------------------------------------------------------------------+
//| Filtro Bollinger                                                 |
//+------------------------------------------------------------------+
bool CEmasBuyBull::BollingerHasValidStructure(TF_CTX *ctx)
{
   if (ctx == NULL)
      return false;

   bollStructure_M3.Reset();
   bollStructure_M3.is_enabled = true;

   // Valores min e max de largura
   double valid_min_width, valid_max_width;
   valid_min_width = 500;
   valid_max_width = 3000;

   bollStructure_M3.valid_min_width = valid_min_width;
   bollStructure_M3.valid_max_width = valid_max_width;

   // Acesso ao indicador e copia dos valores min e max
   CBollinger *boll_ind = ctx.GetIndicator("boll20");
   if (boll_ind == NULL)
      return false;

   double upper_band_value = boll_ind.GetUpper(1);
   double middle_band_value = boll_ind.GetValue(1);
   double lower_band_value = boll_ind.GetLower(1);

   // Largura da banda
   double boll_width = MathAbs(upper_band_value - lower_band_value);

   bollStructure_M3.upper_band_value = upper_band_value;
   bollStructure_M3.middle_band_value = middle_band_value;
   bollStructure_M3.lower_band_value = lower_band_value;
   bollStructure_M3.boll_width = boll_width;

   // Se a largura não está na faixa adequada, retorna falso
   if (boll_width < valid_min_width || boll_width > valid_max_width)
   {
      bollStructure_M3.is_valid = false;
      bollStructure_M3.is_evaluated = true;
      return false;
   }

   CATR *atr = ctx.GetIndicator("ATR15");
   if (atr == NULL)
      return false;

   double atr_value = atr.GetValue(1);
   bollStructure_M3.atr_value = atr_value;

   bollStructure_M3.is_evaluated = true;

   SSlopeValidation slope_upper = boll_ind.GetSlopeValidation(atr_value, COPY_UPPER);
   SSlopeValidation slope_middle = boll_ind.GetSlopeValidation(atr_value, COPY_MIDDLE);
   SSlopeValidation slope_lower = boll_ind.GetSlopeValidation(atr_value, COPY_LOWER);

   bollStructure_M3.slope_upper = slope_upper;
   bollStructure_M3.slope_middle = slope_middle;
   bollStructure_M3.slope_lower = slope_lower;

   // Contracting
   bool contracting_1 = slope_upper.bearish_count >= 2;
   bool contracting_2 = slope_lower.bullish_count >= 2;
   bool contracting_condition = contracting_1 && contracting_2;

   bollStructure_M3.contracting_condition = contracting_condition;

   if (contracting_condition)
   {
      bollStructure_M3.is_valid = false;
      return false;
   }

   // Micro Inclinação Banda Superior
   // sidewalk >=2 && bear == 0
   bool c1 = slope_upper.side_count >= 2;
   bollStructure_M3.slope_upper_sidewalk = c1;
   Print("Contagem de Lateral: ", slope_upper.side_count);
   Print("Contagem de Bull: ", slope_upper.bullish_count);
   Print("Contagem de Bear: ", slope_upper.bearish_count);
   if (c1)
   {
      bool c2 = slope_upper.linear_regression.slope_value >= 0.05;
      bool c3 = slope_upper.discrete_derivative.slope_value >= 0.04;
      bool c4 = slope_upper.simple_difference.slope_value >= 0.20;

      bollStructure_M3.slope_upper_micro_ok = (c2 && c3 && c4);

      Print("SLOPE VALUES MICRO INCLINAÇÃO: &&&&&&&&&&&&&&&");
      Print("LR: ", slope_upper.linear_regression.slope_value);
      Print("DD: ", slope_upper.discrete_derivative.slope_value);
      Print("SD: ", slope_upper.simple_difference.slope_value);

      if (!c2 || !c3 || !c4)
      {
         bollStructure_M3.is_valid = false;
         return false;
      }
   }

   if (!c1)
      bollStructure_M3.slope_upper_micro_ok = true;

   bool slope_lower_is_side_walk = slope_lower.side_count >= 2;
   bollStructure_M3.slope_lower_sidewalk = slope_lower_is_side_walk;
   if (slope_lower_is_side_walk)
   {
      bool c5 = slope_lower.linear_regression.slope_value <= 0.05 && slope_lower.linear_regression.slope_value >= -0.05;
      bool c6 = slope_lower.discrete_derivative.slope_value <= 0.04 && slope_lower.discrete_derivative.slope_value >= -0.04;
      bool c7 = slope_lower.simple_difference.slope_value <= 0.2 && slope_lower.simple_difference.slope_value >= -0.2;

      if (c5 || c6 || c7)
      {
         bollStructure_M3.slope_lower_micro_ok = false;
         bollStructure_M3.is_valid = false;
         return false;
      }
      bollStructure_M3.slope_lower_micro_ok = true;
   }
   else
   {
      bollStructure_M3.slope_lower_micro_ok = true;
   }

   bollStructure_M3.is_valid = true;
   return true;
}
//+------------------------------------------------------------------+
//| Verificar por sinal de entrada - LÓGICA MIGRADA DA CompraAlta   |
//+------------------------------------------------------------------+
SStrategySignal CEmasBuyBull::CheckForSignal()
{
   SStrategySignal signal;
   signal.Reset();

   ResetValidationState();

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

   bullishMomentumState.is_enabled = m_config.enable_bullish_momentum;
   volatilityEnv_M15.is_enabled = m_config.enable_good_volatility;
   bullishStructureState_M15.is_enabled = m_config.enable_bullish_structure_m15;
   bullishStructureState_M3.is_enabled = m_config.enable_bullish_structure_m3;
   emaAlignmentState_M15.is_enabled = m_config.enable_ema_alignment_m15;
   emaAlignmentState_M3.is_enabled = m_config.enable_ema_alignment_m3;
   pullbackEMA9State_M3.is_enabled = m_config.enable_pullback_ema9;
   pullbackEMA21State_M3.is_enabled = m_config.enable_pullback_ema21;
   bollStructure_M3.is_enabled = true;

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

   emaAlignmentState_M15.timeframe = PERIOD_M15;
   emaAlignmentState_M15.ema9_value = ema9_value_m15;
   emaAlignmentState_M15.ema21_value = ema21_value_m15;
   emaAlignmentState_M15.ema50_value = ema50_value_m15;
   emaAlignmentState_M15.ema9_vs_ema21 = EMA9_above_EMA21_M15;
   emaAlignmentState_M15.ema21_vs_ema50 = EMA21_above_EMA50_M15;
   emaAlignmentState_M15.is_valid = EMA9_above_EMA21_M15 && EMA21_above_EMA50_M15;

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

   emaAlignmentState_M3.timeframe = PERIOD_M3;
   emaAlignmentState_M3.ema9_value = ema9_value_m3;
   emaAlignmentState_M3.ema21_value = ema21_value_m3;
   emaAlignmentState_M3.ema50_value = ema50_value_m3;
   emaAlignmentState_M3.ema9_vs_ema21 = EMA9_above_EMA21_M3;
   emaAlignmentState_M3.ema21_vs_ema50 = EMA21_above_EMA50_M3;
   emaAlignmentState_M3.is_valid = EMA9_above_EMA21_M3 && EMA21_above_EMA50_M3;

   double atr_value = (atr_m3 != NULL) ? atr_m3.GetValue(1) : 0.0;
   if (atr_m3 == NULL || atr_value <= 0.0)
   {
      Print("AVISO: ATR (M3) ausente ou inválido em CheckForSignal");
      return signal;
   }

   // === FILTROS DEPENDENTES ===
   bool strong_trend_m3 = true;
   if (m_config.enable_strong_trend_m3)
   {
      strong_trend_m3 = IsStrongTrend(ctx_m3);
   }
   else
   {
      distance_ma_m3.is_enabled = false;
      distance_ma_m3.is_evaluated = false;
      distance_ma_m3.is_strong_trend = true;
   }

   bool strong_trend_m15 = true;
   if (m_config.enable_strong_trend_m15)
   {
      strong_trend_m15 = IsStrongTrend(ctx_m15);
   }
   else
   {
      distance_ma_m15.is_enabled = false;
      distance_ma_m15.is_evaluated = false;
      distance_ma_m15.is_strong_trend = true;
   }

   bool bullish_momentum = true;
   if (m_config.enable_bullish_momentum)
   {
      bullish_momentum = HasBullishMomentum(ctx_m15, ctx_m3);
   }
   else
   {
      bullishMomentumState.is_enabled = false;
      bullishMomentumState.is_evaluated = false;
      bullishMomentumState.is_valid = true;
   }

   bool good_volatility_m15 = true;
   if (m_config.enable_good_volatility)
   {
      good_volatility_m15 = IsGoodVolatilityEnvironment(ctx_m15);
   }
   else
   {
      volatilityEnv_M15.is_enabled = false;
      volatilityEnv_M15.is_evaluated = false;
      volatilityEnv_M15.is_good_volatility = true;
   }

   bool bullish_structure_m15 = true;
   if (m_config.enable_bullish_structure_m15)
   {
      bullish_structure_m15 = IsInBullishStructure(ctx_m15);
   }
   else
   {
      bullishStructureState_M15.is_enabled = false;
      bullishStructureState_M15.is_evaluated = false;
      bullishStructureState_M15.is_valid = true;
   }

   bool bullish_structure_m3 = true;
   if (m_config.enable_bullish_structure_m3)
   {
      bullish_structure_m3 = IsInBullishStructure(ctx_m3);
   }
   else
   {
      bullishStructureState_M3.is_enabled = false;
      bullishStructureState_M3.is_evaluated = false;
      bullishStructureState_M3.is_valid = true;
   }

   // Verificar ADX
   bool strong_trend_adx_m15 = false;
   double adx_value_m15 = 0.0;
   CADX *adx_m15 = ctx_m15.GetIndicator("ADX15");
   if (adx_m15 != NULL)
   {
      adx_value_m15 = adx_m15.GetValue(1);
      strong_trend_adx_m15 = (adx_value_m15 >= m_config.adx_min_value && adx_value_m15 <= m_config.adx_max_value);
      SStrong_trend_ADX_m15.is_evaluated = true;
   }
   else
   {
      SStrong_trend_ADX_m15.is_evaluated = false;
   }
   SStrong_trend_ADX_m15.is_enabled = m_config.enable_adx_filter;
   if (!m_config.enable_adx_filter)
      strong_trend_adx_m15 = true;

   SStrong_trend_ADX_m15.adx_value_tf = adx_value_m15;
   SStrong_trend_ADX_m15.config_max_value = m_config.adx_max_value;
   SStrong_trend_ADX_m15.config_min_value = m_config.adx_min_value;
   SStrong_trend_ADX_m15.isStrongTrendADX = strong_trend_adx_m15;

   if (!m_config.enable_adx_filter)
   {
      SStrong_trend_ADX_m15.is_enabled = false;
      SStrong_trend_ADX_m15.is_evaluated = false;
   }

   // === PONTOS DE ENTRADA ===
   SPositionInfo ema9_m3_position = ema9_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
   pullbackEMA9State_M3.label = "EMA9";
   // Aceitamos apenas padrões onde a EMA atua como suporte (dentro/abaixo do candle).
   // Mantemos a mesma regra adotada em logs/validações para facilitar a leitura do diagnóstico.
   bool price_pullback_EMA9_M3 = (
      ema9_m3_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
      ema9_m3_position.position == INDICATOR_CROSSES_LOWER_BODY ||
      ema9_m3_position.position == INDICATOR_CROSSES_CENTER_BODY ||
      ema9_m3_position.position == INDICATOR_CROSSES_UPPER_BODY
   );
   pullbackEMA9State_M3.price_condition = price_pullback_EMA9_M3;
   bool valid_pullback_EMA9_M3 = false;
   if (m_config.enable_pullback_ema9)
   {
      valid_pullback_EMA9_M3 = IsValidPullback(ema9_m3_position, atr_value, ctx_m3, ema9_m3, pullbackEMA9State_M3);
      DiagnoseFailedPullback(pullbackEMA9State_M3);
   }

   SPositionInfo ema21_m3_position = ema21_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
   pullbackEMA21State_M3.label = "EMA21";
   bool price_pullback_EMA21_M3 = (
      ema21_m3_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
      ema21_m3_position.position == INDICATOR_CROSSES_LOWER_BODY ||
      ema21_m3_position.position == INDICATOR_CROSSES_CENTER_BODY ||
      ema21_m3_position.position == INDICATOR_CROSSES_UPPER_BODY
   );
   pullbackEMA21State_M3.price_condition = price_pullback_EMA21_M3;
   bool valid_pullback_EMA21_M3 = false;
   if (m_config.enable_pullback_ema21)
   {
      valid_pullback_EMA21_M3 = IsValidPullback(ema21_m3_position, atr_value, ctx_m3, ema21_m3, pullbackEMA21State_M3);
      DiagnoseFailedPullback(pullbackEMA21State_M3);
   }

   // === CRITÉRIO FINAL DE ENTRADA ===
   bool ema_alignment_m15_ok = m_config.enable_ema_alignment_m15 ? (EMA9_above_EMA21_M15 && EMA21_above_EMA50_M15) : true;
   bool ema_alignment_m3_ok = m_config.enable_ema_alignment_m3 ? (EMA9_above_EMA21_M3 && EMA21_above_EMA50_M3) : true;

   bool is_bollinger_valid = BollingerHasValidStructure(ctx_m3);

   bool filtros_ok = ema_alignment_m15_ok && ema_alignment_m3_ok &&
                     strong_trend_m15 && strong_trend_m3 &&
                     bullish_momentum &&
                     good_volatility_m15 &&
                     bullish_structure_m15 && bullish_structure_m3 &&
                     strong_trend_adx_m15 && is_bollinger_valid;

   bool pullback_ema9_ok = m_config.enable_pullback_ema9 ? (price_pullback_EMA9_M3 && valid_pullback_EMA9_M3) : false;
   bool pullback_ema21_ok = m_config.enable_pullback_ema21 ? (price_pullback_EMA21_M3 && valid_pullback_EMA21_M3) : false;

   bool entrada_setup_ok = pullback_ema9_ok || pullback_ema21_ok;

   bool entrada_valida = filtros_ok && entrada_setup_ok;

   lastSignalEvaluation.filtros_ok = filtros_ok;
   lastSignalEvaluation.setup_ok = entrada_setup_ok;
   lastSignalEvaluation.entrada_valida = entrada_valida;
   lastSignalEvaluation.atr_value_m3 = atr_value;

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
void CEmasBuyBull::DoLog()
{
   Print("=== DEBUG LOG COMPLETO - EMA Bull Buy ===");
   Print("Símbolo: ", m_symbol, " | Timeframe Atual: ", EnumToString(m_timeframe));
   Print("Estado da Estratégia: ", EnumToString(GetState()));
   Print("Último Sinal: ", GetLastSignal().is_valid ? "Válido" : "Inválido");

   // Configuração
   Print("--- CONFIGURAÇÃO ---");
   Print("Nome: ", m_config.name);
   Print("Tipo: ", m_config.type);
   Print("Habilitado: ", m_config.enabled ? "Sim" : "Não");
   Print("Risco %: ", DoubleToString(m_config.risk_percent, 2));
   Print("Stop Loss Pips: ", DoubleToString(m_config.stop_loss_pips, 1));
   Print("Take Profit Ratio: ", DoubleToString(m_config.take_profit_ratio, 1));
   Print("Min Dist 9-21 ATR M3: ", DoubleToString(m_config.min_distance_9_21_atr_m3, 2));
   Print("Min Dist 21-50 ATR M3: ", DoubleToString(m_config.min_distance_21_50_atr_m3, 2));
   Print("Min Dist 9-21 ATR M15: ", DoubleToString(m_config.min_distance_9_21_atr_m15, 2));
   Print("Min Dist 21-50 ATR M15: ", DoubleToString(m_config.min_distance_21_50_atr_m15, 2));
   Print("Lookback Candles: ", IntegerToString(m_config.lookback_candles));
   Print("Max Distance ATR: ", DoubleToString(m_config.max_distance_atr, 2));
   Print("Max Duration Candles: ", IntegerToString(m_config.max_duration_candles));
   Print("Lookback Periods: ", IntegerToString(m_config.lookback_periods));
   Print("Min Volatility Ratio: ", DoubleToString(m_config.min_volatility_ratio, 2));
   Print("Max Volatility Ratio: ", DoubleToString(m_config.max_volatility_ratio, 2));
   Print("Bullish Structure ATR Threshold: ", DoubleToString(m_config.bullish_structure_atr_threshold, 2));
   Print("ADX Min Value: ", IntegerToString(m_config.adx_min_value));
   Print("ADX Max Value: ", IntegerToString(m_config.adx_max_value));
   Print("Enable EMA Alignment M15: ", m_config.enable_ema_alignment_m15 ? "Sim" : "Não");
   Print("Enable EMA Alignment M3: ", m_config.enable_ema_alignment_m3 ? "Sim" : "Não");
   Print("Enable Strong Trend M15: ", m_config.enable_strong_trend_m15 ? "Sim" : "Não");
   Print("Enable Strong Trend M3: ", m_config.enable_strong_trend_m3 ? "Sim" : "Não");
   Print("Enable Bullish Momentum: ", m_config.enable_bullish_momentum ? "Sim" : "Não");
   Print("Enable Good Volatility: ", m_config.enable_good_volatility ? "Sim" : "Não");
   Print("Enable Bullish Structure M15: ", m_config.enable_bullish_structure_m15 ? "Sim" : "Não");
   Print("Enable Bullish Structure M3: ", m_config.enable_bullish_structure_m3 ? "Sim" : "Não");
   Print("Enable ADX Filter: ", m_config.enable_adx_filter ? "Sim" : "Não");
   Print("Enable Pullback EMA9: ", m_config.enable_pullback_ema9 ? "Sim" : "Não");
   Print("Enable Pullback EMA21: ", m_config.enable_pullback_ema21 ? "Sim" : "Não");

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
   if (ema9_m15)
   {
      Print("EMA9: ", DoubleToString(ema9_m15.GetValue(1), _Digits));
      SSlopeValidation ema9_slopes_m15 = ema9_m15.GetSlopeValidation(atr_m15.GetValue());
      Print("-- EMA9 LR: ", ema9_slopes_m15.linear_regression.slope_value, " ", EnumToString(ema9_slopes_m15.linear_regression.trend_direction));
      Print("-- EMA9 DD: ", ema9_slopes_m15.discrete_derivative.slope_value, " ", EnumToString(ema9_slopes_m15.discrete_derivative.trend_direction));
      Print("-- EMA9 SD: ", ema9_slopes_m15.simple_difference.slope_value, " ", EnumToString(ema9_slopes_m15.simple_difference.trend_direction));
   }
   if (ema21_m15)
   {
      Print("EMA21: ", DoubleToString(ema21_m15.GetValue(1), _Digits));
      SSlopeValidation ema21_slopes_m15 = ema21_m15.GetSlopeValidation(atr_m15.GetValue());
      Print("-- EMA21 LR: ", ema21_slopes_m15.linear_regression.slope_value, " ", EnumToString(ema21_slopes_m15.linear_regression.trend_direction));
      Print("-- EMA21 DD: ", ema21_slopes_m15.discrete_derivative.slope_value, " ", EnumToString(ema21_slopes_m15.discrete_derivative.trend_direction));
      Print("-- EMA21 SD: ", ema21_slopes_m15.simple_difference.slope_value, " ", EnumToString(ema21_slopes_m15.simple_difference.trend_direction));
   }
   if (ema50_m15)
   {
      Print("EMA50: ", DoubleToString(ema50_m15.GetValue(1), _Digits));
      SSlopeValidation ema50_slopes_m15 = ema50_m15.GetSlopeValidation(atr_m15.GetValue());
      Print("-- EMA50 LR: ", ema50_slopes_m15.linear_regression.slope_value, " ", EnumToString(ema50_slopes_m15.linear_regression.trend_direction));
      Print("-- EMA50 DD: ", ema50_slopes_m15.discrete_derivative.slope_value, " ", EnumToString(ema50_slopes_m15.discrete_derivative.trend_direction));
      Print("-- EMA50 SD: ", ema50_slopes_m15.simple_difference.slope_value, " ", EnumToString(ema50_slopes_m15.simple_difference.trend_direction));
   }
   if (atr_m15)
   {
      Print("ATR: ", DoubleToString(atr_m15.GetValue(1), 5));
      Print("Average Period: ", m_config.lookback_candles);
      Print("Average ATR:", volatilityEnv_M15.avg_atr);
      string vol_status = "N/A";
      if (!volatilityEnv_M15.is_enabled)
         vol_status = "Desabilitada";
      else if (volatilityEnv_M15.is_evaluated)
         vol_status = volatilityEnv_M15.is_good_volatility ? "Sim" : "Não";
      Print("Volatilidade Boa (M15): ", vol_status);
      if (volatilityEnv_M15.is_evaluated)
      {
         Print("Current Volatility Ratio:", volatilityEnv_M15.volatility_ratio);
         Print("Valid Periods: ", volatilityEnv_M15.valid_periods);
      }
      Print(".config Min Volatility Ratio: ", m_config.min_volatility_ratio);
      Print(".config Max Volatility Ratio: ", m_config.max_volatility_ratio);
   }
   if (adx_m15)
   {
      Print("ADX: ", SStrong_trend_ADX_m15.adx_value_tf);
      Print("Conf.min.value: ", SStrong_trend_ADX_m15.config_min_value);
      Print("Conf.max.value: ", SStrong_trend_ADX_m15.config_max_value);
      Print("Is Strong Trend: ", SStrong_trend_ADX_m15.isStrongTrendADX ? "Sim" : "Não");
   }

   Print("EMA9 - EMA 21 Distance: ", distance_ma_m15.ema_9_21);
   Print("EMA9 - EMA 21 Distance by ATR: ", distance_ma_m15.ema_9_21_by_atr);

   Print("EMA21 - EMA 50 Distance: ", distance_ma_m15.ema_21_50);
   Print("EMA21 - EMA 50 Distance by ATR: ", distance_ma_m15.ema_21_50_by_atr);

   // Indicadores M3
   CMovingAverages *ema9_m3 = ctx_m3.GetIndicator("ema9");
   CMovingAverages *ema21_m3 = ctx_m3.GetIndicator("ema21");
   CMovingAverages *ema50_m3 = ctx_m3.GetIndicator("ema50");
   CATR *atr_m3 = ctx_m3.GetIndicator("ATR15");

   Print("--- INDICADORES M3 ---");
   if (ema9_m3)
   {
      Print("EMA9: ", DoubleToString(ema9_m3.GetValue(1), _Digits));
      SSlopeValidation ema9_slopes_m3 = ema9_m3.GetSlopeValidation(atr_m3.GetValue());
      Print("-- EMA9 LR: ", ema9_slopes_m3.linear_regression.slope_value, " ", EnumToString(ema9_slopes_m3.linear_regression.trend_direction));
      Print("-- EMA9 DD: ", ema9_slopes_m3.discrete_derivative.slope_value, " ", EnumToString(ema9_slopes_m3.discrete_derivative.trend_direction));
      Print("-- EMA9 SD: ", ema9_slopes_m3.simple_difference.slope_value, " ", EnumToString(ema9_slopes_m3.simple_difference.trend_direction));
   }
   // cavalo
   if (ema21_m3)
   {
      Print("EMA21: ", DoubleToString(ema21_m3.GetValue(1), _Digits));
      SSlopeValidation ema21_slopes_m3 = ema21_m3.GetSlopeValidation(atr_m3.GetValue());
      Print("-- EMA21 LR: ", ema21_slopes_m3.linear_regression.slope_value, " ", EnumToString(ema21_slopes_m3.linear_regression.trend_direction));
      Print("-- EMA21 DD: ", ema21_slopes_m3.discrete_derivative.slope_value, " ", EnumToString(ema21_slopes_m3.discrete_derivative.trend_direction));
      Print("-- EMA21 SD: ", ema21_slopes_m3.simple_difference.slope_value, " ", EnumToString(ema21_slopes_m3.simple_difference.trend_direction));
   }
   if (ema50_m3)
   {
      Print("EMA50: ", DoubleToString(ema50_m3.GetValue(1), _Digits));
      SSlopeValidation ema50_slopes_m3 = ema50_m3.GetSlopeValidation(atr_m3.GetValue());
      Print("-- EMA50 LR: ", ema50_slopes_m3.linear_regression.slope_value, " ", EnumToString(ema50_slopes_m3.linear_regression.trend_direction));
      Print("-- EMA50 DD: ", ema50_slopes_m3.discrete_derivative.slope_value, " ", EnumToString(ema50_slopes_m3.discrete_derivative.trend_direction));
      Print("-- EMA50 SD: ", ema50_slopes_m3.simple_difference.slope_value, " ", EnumToString(ema50_slopes_m3.simple_difference.trend_direction));
   }
   if (atr_m3)
   {
      Print("ATR: ", DoubleToString(atr_m3.GetValue(1), 5));
   }

   Print("EMA9 - EMA 21 Distance: ", distance_ma_m3.ema_9_21);
   Print("EMA9 - EMA 21 Distance by ATR: ", distance_ma_m3.ema_9_21_by_atr);

   Print("EMA21 - EMA 50 Distance: ", distance_ma_m3.ema_21_50);
   Print("EMA21 - EMA 50 Distance by ATR: ", distance_ma_m3.ema_21_50_by_atr);

   // Valores calculados
   double atr_value = (atr_m3 != NULL) ? atr_m3.GetValue(1) : 0.0;
   Print("ATR Value (M3): ", DoubleToString(atr_value, 5));

   // Bollinger Bands M3
   CBollinger *boll_m3 = ctx_m3.GetIndicator("boll20");
   if (boll_m3 != NULL)
   {
      double upper_band = boll_m3.GetUpper(1);
      double middle_band = boll_m3.GetValue(1);
      double lower_band = boll_m3.GetLower(1);
      double band_width = upper_band - lower_band;

      Print("--- BOLLINGER BANDS M3 ---");
      Print("Upper: ", DoubleToString(upper_band, _Digits));
      Print("Middle: ", DoubleToString(middle_band, _Digits));
      Print("Lower: ", DoubleToString(lower_band, _Digits));
      Print("Width: ", DoubleToString(band_width, 2));

      SSlopeValidation slope_upper = boll_m3.GetSlopeValidation(atr_value, COPY_UPPER);
      SSlopeValidation slope_middle = boll_m3.GetSlopeValidation(atr_value, COPY_MIDDLE);
      SSlopeValidation slope_lower = boll_m3.GetSlopeValidation(atr_value, COPY_LOWER);

      Print("--- BOLLINGER SLOPES M3 ---");
      Print("Upper - Linear Regr: ", DoubleToString(slope_upper.linear_regression.slope_value, 5), " Dir: ", EnumToString(slope_upper.linear_regression.trend_direction));
      Print("Upper - Discrt Der: ", DoubleToString(slope_upper.discrete_derivative.slope_value, 5), " Dir: ", EnumToString(slope_upper.discrete_derivative.trend_direction));
      Print("Upper - Simple Diff: ", DoubleToString(slope_upper.simple_difference.slope_value, 5), " Dir: ", EnumToString(slope_upper.simple_difference.trend_direction));
      Print("Middle - Linear Regr: ", DoubleToString(slope_middle.linear_regression.slope_value, 5), " Dir: ", EnumToString(slope_middle.linear_regression.trend_direction));
      Print("Middle - Discrt Der: ", DoubleToString(slope_middle.discrete_derivative.slope_value, 5), " Dir: ", EnumToString(slope_middle.discrete_derivative.trend_direction));
      Print("Middle - Simple Diff: ", DoubleToString(slope_middle.simple_difference.slope_value, 5), " Dir: ", EnumToString(slope_middle.simple_difference.trend_direction));
      Print("Lower - Linear Regr: ", DoubleToString(slope_lower.linear_regression.slope_value, 5), " Dir: ", EnumToString(slope_lower.linear_regression.trend_direction));
      Print("Lower - Discrt Der: ", DoubleToString(slope_lower.discrete_derivative.slope_value, 5), " Dir: ", EnumToString(slope_lower.discrete_derivative.trend_direction));
      Print("Lower - Simple Diff: ", DoubleToString(slope_lower.simple_difference.slope_value, 5), " Dir: ", EnumToString(slope_lower.simple_difference.trend_direction));
   }

   // Condições booleanas
   bool EMA9_above_EMA21_M15 = emaAlignmentState_M15.ema9_vs_ema21;
   bool EMA21_above_EMA50_M15 = emaAlignmentState_M15.ema21_vs_ema50;
   bool EMA9_above_EMA21_M3 = emaAlignmentState_M3.ema9_vs_ema21;
   bool EMA21_above_EMA50_M3 = emaAlignmentState_M3.ema21_vs_ema50;

   Print("--- VALIDAÇÕES HABILITADAS ---");
   Print("EMA Alignment M15: ", m_config.enable_ema_alignment_m15 ? "Habilitada" : "Desabilitada");
   Print("EMA Alignment M3: ", m_config.enable_ema_alignment_m3 ? "Habilitada" : "Desabilitada");
   Print("Strong Trend: ", m_config.enable_strong_trend_m15 ? "Habilitada" : "Desabilitada");
   Print("Bullish Momentum: ", m_config.enable_bullish_momentum ? "Habilitada" : "Desabilitada");
   Print("Good Volatility: ", m_config.enable_good_volatility ? "Habilitada" : "Desabilitada");
   Print("Bullish Structure M15: ", m_config.enable_bullish_structure_m15 ? "Habilitada" : "Desabilitada");
   Print("Bullish Structure M3: ", m_config.enable_bullish_structure_m3 ? "Habilitada" : "Desabilitada");
   Print("ADX Filter: ", m_config.enable_adx_filter ? "Habilitada" : "Desabilitada");
   Print("Pullback EMA9: ", m_config.enable_pullback_ema9 ? "Habilitada" : "Desabilitada");
   Print("Pullback EMA21: ", m_config.enable_pullback_ema21 ? "Habilitada" : "Desabilitada");

   Print("--- CONDIÇÕES DE ALINHAMENTO EMAs ---");
   string ema_m15_9_21_status = emaAlignmentState_M15.is_enabled ? (EMA9_above_EMA21_M15 ? "Sim" : "Não") : "Desabilitada";
   string ema_m15_21_50_status = emaAlignmentState_M15.is_enabled ? (EMA21_above_EMA50_M15 ? "Sim" : "Não") : "Desabilitada";
   string ema_m3_9_21_status = emaAlignmentState_M3.is_enabled ? (EMA9_above_EMA21_M3 ? "Sim" : "Não") : "Desabilitada";
   string ema_m3_21_50_status = emaAlignmentState_M3.is_enabled ? (EMA21_above_EMA50_M3 ? "Sim" : "Não") : "Desabilitada";
   Print("M15 - EMA9 > EMA21: ", ema_m15_9_21_status);
   Print("M15 - EMA21 > EMA50: ", ema_m15_21_50_status);
   Print("M3 - EMA9 > EMA21: ", ema_m3_9_21_status);
   Print("M3 - EMA21 > EMA50: ", ema_m3_21_50_status);

   Print("--- FILTROS DEPENDENTES ---");
   string bollinger_status = bollStructure_M3.is_evaluated ? (bollStructure_M3.is_valid ? "Sim" : "Não") : "N/A";
   Print("Bollinger Válida (M3): ", bollinger_status);

   string strong_trend_m15_status = SStrong_trend_ADX_m15.is_enabled ?
      (SStrong_trend_ADX_m15.is_evaluated ? (SStrong_trend_ADX_m15.isStrongTrendADX ? "Sim" : "Não") : "N/A") : "Desabilitada";
   Print("Tendência Forte (M15): ", strong_trend_m15_status);

   string strong_trend_m3_status = distance_ma_m3.is_enabled ?
      (distance_ma_m3.is_evaluated ? (distance_ma_m3.is_strong_trend ? "Sim" : "Não") : "N/A") : "Desabilitada";
   Print("Tendência Forte (M3): ", strong_trend_m3_status);

   string momentum_status = bullishMomentumState.is_enabled ?
      (bullishMomentumState.is_evaluated ? (bullishMomentumState.is_valid ? "Sim" : "Não") : "N/A") : "Desabilitada";
   Print("Momentum Bullish: ", momentum_status);

   string volatility_status = volatilityEnv_M15.is_enabled ?
      (volatilityEnv_M15.is_evaluated ? (volatilityEnv_M15.is_good_volatility ? "Sim" : "Não") : "N/A") : "Desabilitada";
   Print("Volatilidade Boa (M15): ", volatility_status);

   string bullish_structure_m15_status = bullishStructureState_M15.is_enabled ?
      (bullishStructureState_M15.is_evaluated ? (bullishStructureState_M15.is_valid ? "Sim" : "Não") : "N/A") : "Desabilitada";
   Print("Estrutura Bullish (M15): ", bullish_structure_m15_status);

   string bullish_structure_m3_status = bullishStructureState_M3.is_enabled ?
      (bullishStructureState_M3.is_evaluated ? (bullishStructureState_M3.is_valid ? "Sim" : "Não") : "N/A") : "Desabilitada";
   Print("Estrutura Bullish (M3): ", bullish_structure_m3_status);

   string adx_status = SStrong_trend_ADX_m15.is_enabled ?
      (SStrong_trend_ADX_m15.is_evaluated ? (SStrong_trend_ADX_m15.isStrongTrendADX ? "Sim" : "Não") : "N/A") : "Desabilitada";
   Print("ADX Forte (M15): ", adx_status);

   // Pontos de entrada
   Print("--- PONTOS DE ENTRADA (M3) ---");
   if (pullbackEMA9State_M3.is_evaluated)
   {
      Print("Pullback EMA9: Posição=", EnumToString(pullbackEMA9State_M3.position_info.position),
            " | Condição=", pullbackEMA9State_M3.price_condition ? "Sim" : "Não",
            " | Válido=", pullbackEMA9State_M3.is_valid ? "Sim" : "Não");
   }
   else
   {
      Print("Pullback EMA9: Não avaliado");
   }

   if (pullbackEMA21State_M3.is_evaluated)
   {
      Print("Pullback EMA21: Posição=", EnumToString(pullbackEMA21State_M3.position_info.position),
            " | Condição=", pullbackEMA21State_M3.price_condition ? "Sim" : "Não",
            " | Válido=", pullbackEMA21State_M3.is_valid ? "Sim" : "Não");
   }
   else
   {
      Print("Pullback EMA21: Não avaliado");
   }

   // Critérios finais
   Print("--- CRITÉRIOS FINAIS ---");
   Print("Filtros OK: ", lastSignalEvaluation.filtros_ok ? "Sim" : "Não");
   Print("Setup de Entrada OK: ", lastSignalEvaluation.setup_ok ? "Sim" : "Não");
   Print("ENTRADA VÁLIDA: ", lastSignalEvaluation.entrada_valida ? "SIM" : "NÃO");

   Print("=== FIM DO DEBUG LOG ===");
}

//+------------------------------------------------------------------+
//| Retornar configuração da estratégia                              |
//+------------------------------------------------------------------+
CStrategyConfig *CEmasBuyBull::GetStrategyConfig()
{
   return &m_config;
}

#endif