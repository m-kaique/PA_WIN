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

   // Estruturas de Dados - Strong Trend EMAS
   SStrongTrendEMAS _ema_data_M3;
   SStrongTrendEMAS _ema_data_M15;

   // Estruturas de Dados - Volatilidade
   SVolatilityEnv volatilityEnv_M15;

   // Estruturas de Dados - ADX
   SStrongTrendADX SStrong_trend_ADX_m15;

   // Estruturas de Dados - Bollinger
   SBollingerValidStructure _m3_boll_filter;

   // Estruturas de Dados - Pullback
   SIsValidPullback _pullback_ema9_m3;
   SIsValidPullback _pullback_ema21_m3;

   double CalculateLotSize();
   double CalculateStopLoss(double entry_price);
   double CalculateTakeProfit(double entry_price, double stop_loss);

   // Métodos auxiliares migrados da lógica CompraAlta
   bool IsStrongTrend(TF_CTX *ctx);
   bool HasBullishMomentum(TF_CTX *ctx_m15, TF_CTX *ctx_m3);
   SIsValidPullback IsValidPullback(SPositionInfo &position_info, double atr_value, TF_CTX *ctx, CMovingAverages *ma);
   bool IsGoodVolatilityEnvironment(TF_CTX *ctx);
   bool IsInBullishStructure(TF_CTX *ctx);
   bool BollingerHasValidStructure(TF_CTX *ctx);

   // Override do método de verificação de horário de operação
   virtual bool DoOperatingHoursCheck() override;

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

   if (ctx.GetTimeFrame() == PERIOD_M15)
   {
      _ema_data_M15.distance_ema_21_50 = MathAbs(ema50_val - ema21_val);
      _ema_data_M15.distance_ema_9_21 = MathAbs(ema21_val - ema9_val);
      _ema_data_M15.distance_ema_9_50 = MathAbs(ema50_val - ema9_val);

      _ema_data_M15.distance_ema_21_50_by_atr = MathAbs(ema50_val - ema21_val) / atr_val;
      _ema_data_M15.distance_ema_9_21_by_atr = MathAbs(ema21_val - ema9_val) / atr_val;
      _ema_data_M15.distance_ema_9_50_by_atr = MathAbs(ema50_val - ema9_val) / atr_val;

      // Print("Estou usando M15 - #### CEmasBuyBull::IsStrongTrend");
      strong_trend = (dist_9_21 >= m_config.min_distance_9_21_atr_m15 && dist_21_50 >= m_config.min_distance_21_50_atr_m15);

      _ema_data_M15.is_strong_trend = strong_trend;
      _ema_data_M15.ema9_value = ema9_val;
      _ema_data_M15.ema21_value = ema21_val;
      _ema_data_M15.ema50_value = ema50_val;
      _ema_data_M15.atr_value = atr_val;
   }

   else if (ctx.GetTimeFrame() == PERIOD_M3)
   {
      _ema_data_M3.distance_ema_21_50 = MathAbs(ema50_val - ema21_val);
      _ema_data_M3.distance_ema_9_21 = MathAbs(ema21_val - ema9_val);
      _ema_data_M3.distance_ema_9_50 = MathAbs(ema50_val - ema9_val);

      _ema_data_M3.distance_ema_21_50_by_atr = MathAbs(ema50_val - ema21_val) / atr_val;
      _ema_data_M3.distance_ema_9_21_by_atr = MathAbs(ema21_val - ema9_val) / atr_val;
      _ema_data_M3.distance_ema_9_50_by_atr = MathAbs(ema50_val - ema9_val) / atr_val;

      // Print("Estou usando M3 - #### CEmasBuyBull::IsStrongTrend");
      strong_trend = (dist_9_21 >= m_config.min_distance_9_21_atr_m3 && dist_21_50 >= m_config.min_distance_21_50_atr_m3);
      _ema_data_M3.is_strong_trend = strong_trend;
      _ema_data_M3.ema9_value = ema9_val;
      _ema_data_M3.ema21_value = ema21_val;
      _ema_data_M3.ema50_value = ema50_val;
      _ema_data_M3.atr_value = atr_val;
   }
   else
   {
      Print("!!!!!!!!!!!!!!!!!!!!!!!!!! STRONG TREND NÃO CONFIGURADA EM CEmasBuyBull::IsStrongTrend  - !M3 ou M15!");
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

   return price_above_ema21 && no_panic_selling && last_candle_bullish;
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

SIsValidPullback CEmasBuyBull::IsValidPullback(SPositionInfo &position_info, double atr_value, TF_CTX *ctx, CMovingAverages *ma)
{
   SIsValidPullback data;
   data.is_valid = false;

   if (ctx == NULL || ma == NULL || atr_value <= 0)
   {
      // false;
      return data;
   }

   data.digits = (int)SymbolInfoInteger(m_current_symbol, SYMBOL_DIGITS);
   data.point = SymbolInfoDouble(m_current_symbol, SYMBOL_POINT);
   data.pip_value = (data.digits == 3 || data.digits == 5) ? data.point * 10.0 : data.point;

   if (data.pip_value <= 0)
   {
      // false;
      return data;
   }

   // position_info.distance vem em pips. Convertendo para preço garante que as
   // comparações com o ATR (que está em preço) utilizem a mesma unidade.
   data.distance_price = position_info.distance * data.pip_value;

   data.tf_enum = ctx.GetTimeFrame();
   data.last_close = iClose(m_current_symbol, data.tf_enum, 1);
   data.last_low = iLow(m_current_symbol, data.tf_enum, 1);
   data.current_ma_value = ma.GetValue(1);
   data.tf_name = EnumToString(data.tf_enum);

   // Print("[PULLBACK DEBUG] ========================================");
   // Print("[PULLBACK DEBUG] Iniciando validação de pullback para ", tf_name);
   // Print("[PULLBACK DEBUG] Preço Atual: ", DoubleToString(last_close, _Digits));
   // Print("[PULLBACK DEBUG] EMA Atual: ", DoubleToString(current_ma, _Digits));
   // Print("[PULLBACK DEBUG] ATR Valor: ", DoubleToString(atr_value, 5));
   // Print("[PULLBACK DEBUG] Distance Info (pips): ", DoubleToString(position_info.distance, 5));
   // Print("[PULLBACK DEBUG] Distance Info (preço): ", DoubleToString(distance_price, 5));
   // Print("[PULLBACK DEBUG] Position Type: ", EnumToString(position_info.position));

   // ========================================================================
   // CRITÉRIO 1 (CORRIGIDO): Estava em estrutura de alta anteriormente
   // ========================================================================
   // NÃO exigir que o preço atual esteja acima
   // Apenas validar que VEIO de uma posição acima (Critério 3)
   // Um pullback POR DEFINIÇÃO começa quando o preço cruza/toca o suporte (EMA)

   // Print("[PULLBACK DEBUG] ✓ Critério 1 SKIP: Será validado pelo Critério 3 (estrutura anterior)");

   // ========================================================================
   // CRITÉRIO 2: Distância não pode ser excessiva (limite de profundidade)
   // ========================================================================
   // O pullback não pode descer mais que a profundidade máxima permitida
   data.max_depth = (m_config.max_distance_atr + m_config.pullback_depth_buffer_atr) * atr_value;

   // Print("[PULLBACK DEBUG] Critério 2 - Profundidade:");
   // Print("[PULLBACK DEBUG]    Distance atual: ", DoubleToString(distance_price, 5), " (", DoubleToString(distance_price / atr_value, 2), " ATR)");
   // Print("[PULLBACK DEBUG]    Max permitido: ", DoubleToString(max_depth, 5), " (", DoubleToString(max_depth / atr_value, 2), " ATR)");
   // Print("[PULLBACK DEBUG]    Config: max_distance_atr=", DoubleToString(m_config.max_distance_atr, 2), " + pullback_depth_buffer_atr=", DoubleToString(m_config.pullback_depth_buffer_atr, 2));

   if (data.distance_price > data.max_depth)
   {
      // false;
      return data;
   }
   // Print("[PULLBACK DEBUG] ✓ Critério 2 OK: Profundidade dentro dos limites");

   // ========================================================================
   // CRITÉRIO 3 (CRÍTICO): Validar que veio de distância ANTERIOR MAIOR
   // ========================================================================
   // Este é o CORAÇÃO da validação de pullback
   // Confirma que o preço estava significativamente mais longe da EMA
   // Isso prova que é pullback (retração) e não apenas "perto da EMA"

   data.was_further = false;
   data.lookback_start = 2;
   data.lookback_end = MathMin(m_config.max_duration_candles + 1, 10);

   // Print("[PULLBACK DEBUG] Critério 3 - Distância anterior maior:");
   // Print("[PULLBACK DEBUG]    Procurando barras ", lookback_start, " a ", lookback_end);
   // Print("[PULLBACK DEBUG]    Distância atual (ATR): ", DoubleToString(distance_price / atr_value, 2));
   // Print("[PULLBACK DEBUG]    Improvement factor: ", DoubleToString(m_config.pullback_improvement_factor, 2));
   // Print("[PULLBACK DEBUG]    Necessário mínimo: ", DoubleToString((distance_price / atr_value) * m_config.pullback_improvement_factor, 2), " ATR");

   for (int i = data.lookback_start; i <= data.lookback_end; i++) 
   {
      double prev_close = iClose(m_current_symbol, data.tf_enum, i);
      double prev_ma = ma.GetValue(i);

      // Print("[PULLBACK DEBUG]    Barra ", i, ": Close=", DoubleToString(prev_close, _Digits), " MA=", DoubleToString(prev_ma, _Digits));

      if (prev_close > prev_ma)
      {
         double prev_distance = prev_close - prev_ma;
         double prev_distance_atr = prev_distance / atr_value;
         double current_distance_atr = data.distance_price / atr_value;

         // Print("[PULLBACK DEBUG]      Distância anterior (ATR): ", DoubleToString(prev_distance_atr, 2));

         // IMPORTANTE: improvement_factor é suficiente para provar que é pullback
         // Não exigir 1.3x (30%) que é muito restritivo
         if (prev_distance_atr > current_distance_atr * m_config.pullback_improvement_factor)
         {
            data.was_further = true;
            // Print("[PULLBACK DEBUG] ✓ Encontrado pullback válido na barra ", i);
            break;
         }
      }
   }

   if (!data.was_further)
   {
      // false;
      return data;
   }

   // ========================================================================
   // CRITÉRIO 4: Padrão de posição é razoável para pullback
   // ========================================================================
   // Rejeita APENAS posições que indicam estrutura completamente errada
   // Aceita qualquer coisa que indique aproximação da EMA

   // Print("[PULLBACK DEBUG] Critério 4 - Padrão de posição:");
   // Print("[PULLBACK DEBUG]    Position atual: ", EnumToString(position_info.position));

   data.invalid_position_for_pullback = (position_info.position == INDICATOR_CROSSES_UPPER_SHADOW || // EMA acima da vela -> preço perdeu suporte
                                         position_info.position == CANDLE_BELOW ||
                                         position_info.position == CANDLE_COMPLETELY_BELOW ||       // Muito abaixo (reversão completa)
                                         position_info.position == CANDLE_BELOW_WITH_DISTANCE ||    // Abaixo (já reversão)
                                         position_info.position == INDICATOR_CANDLE_POSITION_FAILED // Posição não confiável
   );

   if (data.invalid_position_for_pullback)
   {
      Print("[PULLBACK DEBUG] ❌ CRITÉRIO 4 FALHOU: Padrão indica reversão, não pullback");
      //false;
      return data;
   }

   // Print("[PULLBACK DEBUG] ✓ Critério 4 OK: Padrão de posição válido");

   // ========================================================================
   // CRITÉRIO 4.5: Validar padrão específico de suporte na EMA
   // ========================================================================
   // Para pullback válido, a EMA deve estar atuando como suporte
   // Aceita apenas posições onde a EMA cruza a parte inferior do candle
   // Isso garante que o preço está testando a EMA como suporte, não resistência

   data.valid_support_positions = (position_info.position == INDICATOR_CROSSES_LOWER_SHADOW ||
                                   position_info.position == INDICATOR_CROSSES_LOWER_BODY ||
                                   position_info.position == INDICATOR_CROSSES_CENTER_BODY ||
                                   position_info.position == INDICATOR_CROSSES_UPPER_BODY);

   Print("[PULLBACK DEBUG] Critério 4.5 - Validação de posição de suporte:");
   Print("[PULLBACK DEBUG]    Position atual: ", EnumToString(position_info.position));
   Print("[PULLBACK DEBUG]    Posição válida para suporte: ", data.valid_support_positions ? "SIM" : "NÃO");

   if (!data.valid_support_positions)
   {
      Print("[PULLBACK DEBUG] ❌ CRITÉRIO 4.5 FALHOU: EMA não está atuando como suporte válido");
      Print("[PULLBACK DEBUG]    Para pullback válido, a EMA deve cruzar a parte inferior do candle");
      return data;
   }

   Print("[PULLBACK DEBUG] ✓ Critério 4.5 OK: EMA está em posição de suporte válida");

   // ========================================================================
   // CRITÉRIO 5: Penetração abaixo da EMA não é excessiva
   // ========================================================================
   // Um pullback pode penetrar levemente abaixo da EMA (até max_penetration_atr ATR)
   // Isso é normal e esperado em price action real
   // O stop loss será colocado abaixo dessa penetração

   data.max_penetration_below_ema = m_config.pullback_max_penetration_atr * atr_value;

   // Usamos o fundo da última vela para medir a penetração real. Assim,
   // pavios longos (que caracterizam pullbacks saudáveis) não são ignorados.
   data.penetration = MathMax(0, data.current_ma_value - data.last_low);

   // Print("[PULLBACK DEBUG] Critério 5 - Penetração abaixo da EMA:");
   // Print("[PULLBACK DEBUG]    Penetração atual: ", DoubleToString(penetration, 5), " (", DoubleToString(penetration / atr_value, 2), " ATR)");
   // Print("[PULLBACK DEBUG]    Max permitido: ", DoubleToString(max_penetration_below_ema, 5), " (", DoubleToString(max_penetration_below_ema / atr_value, 2), " ATR)");
   // Print("[PULLBACK DEBUG]    Config: pullback_max_penetration_atr=", DoubleToString(m_config.pullback_max_penetration_atr, 2));

   if (data.penetration > data.max_penetration_below_ema)
   {
      // false;
      return data;
   }
   // ========================================================================
   // VALIDAÇÃO FINAL
   // ========================================================================
   // Print("[PULLBACK DEBUG] ✅ PULLBACK VÁLIDO CONFIRMADO - ESTRUTURA DE ALTA COMPROVADA");
   // Print("[PULLBACK DEBUG] ========================================");
   data.is_valid = true;
   return data;
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
      return false;
   }

   double avg_atr = sum_atr / valid_periods;
   double volatility_ratio = current_atr / avg_atr;

   volatilityEnv_M15.avg_atr = avg_atr;
   volatilityEnv_M15.volatility_ratio = volatility_ratio;

   return (volatility_ratio >= m_config.min_volatility_ratio && volatility_ratio <= m_config.max_volatility_ratio);
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em estrutura de alta                 |
//+------------------------------------------------------------------+
bool CEmasBuyBull::IsInBullishStructure(TF_CTX *ctx)
{
   if (ctx == NULL)
      return false;

   CMovingAverages *ema50 = ctx.GetIndicator("ema50");
   CATR *atr = ctx.GetIndicator("ATR15");

   if (ema50 == NULL || atr == NULL)
      return false;

   ENUM_TIMEFRAMES tf = ctx.GetTimeFrame();

   double current_close = iClose(m_current_symbol, tf, 1);
   double ema50_val = ema50.GetValue(1);
   double atr_val = atr.GetValue(1);

   if (atr_val <= 0)
      return false;

   // Critério 1: Preço deve estar acima da ema50
   if (current_close <= ema50_val)
   {
      return false;
   }

   // Critério 2: Preço deve estar a uma distância mínima da ema50
   double distance_to_ema50 = (current_close - ema50_val) / atr_val;
   if (distance_to_ema50 < m_config.bullish_structure_atr_threshold)
   {
      return false;
   }

   // Critério 3: ema50 deve estar inclinada para cima
   SSlopeValidation ema50_slope = ema50.GetSlopeValidation(atr_val, COPY_MIDDLE);
   bool ema50_trending_up = (ema50_slope.simple_difference.trend_direction != SLOPE_DOWN ||
                             ema50_slope.discrete_derivative.trend_direction != SLOPE_DOWN ||
                             ema50_slope.linear_regression.trend_direction != SLOPE_DOWN);

   return ema50_trending_up;
}

//+------------------------------------------------------------------+
//| Filtro Bollinger                                                 |
//+------------------------------------------------------------------+
bool CEmasBuyBull::BollingerHasValidStructure(TF_CTX *ctx)
{
   // Valores min e max de largura from config baseados no timeframe
   double valid_min_width, valid_max_width;
   double upper_lr_min, upper_dd_min, upper_sd_min;
   double lower_lr_abs_max, lower_dd_abs_max, lower_sd_abs_max;

   if (ctx.GetTimeFrame() == PERIOD_M3)
   {
      valid_min_width = m_config.boll_micro_m3_min_width;
      valid_max_width = m_config.boll_micro_m3_max_width;
      upper_lr_min = m_config.boll_micro_m3_upper_lr_min;
      upper_dd_min = m_config.boll_micro_m3_upper_dd_min;
      upper_sd_min = m_config.boll_micro_m3_upper_sd_min;
      lower_lr_abs_max = m_config.boll_micro_m3_lower_lr_abs_max;
      lower_dd_abs_max = m_config.boll_micro_m3_lower_dd_abs_max;
      lower_sd_abs_max = m_config.boll_micro_m3_lower_sd_abs_max;
   }
   else if (ctx.GetTimeFrame() == PERIOD_M15)
   {
      valid_min_width = m_config.boll_micro_m15_min_width;
      valid_max_width = m_config.boll_micro_m15_max_width;
      upper_lr_min = m_config.boll_micro_m15_upper_lr_min;
      upper_dd_min = m_config.boll_micro_m15_upper_dd_min;
      upper_sd_min = m_config.boll_micro_m15_upper_sd_min;
      lower_lr_abs_max = m_config.boll_micro_m15_lower_lr_abs_max;
      lower_dd_abs_max = m_config.boll_micro_m15_lower_dd_abs_max;
      lower_sd_abs_max = m_config.boll_micro_m15_lower_sd_abs_max;
   }
   else if (ctx.GetTimeFrame() == PERIOD_H1)
   {
      valid_min_width = m_config.boll_micro_h1_min_width;
      valid_max_width = m_config.boll_micro_h1_max_width;
      upper_lr_min = m_config.boll_micro_h1_upper_lr_min;
      upper_dd_min = m_config.boll_micro_h1_upper_dd_min;
      upper_sd_min = m_config.boll_micro_h1_upper_sd_min;
      lower_lr_abs_max = m_config.boll_micro_h1_lower_lr_abs_max;
      lower_dd_abs_max = m_config.boll_micro_h1_lower_dd_abs_max;
      lower_sd_abs_max = m_config.boll_micro_h1_lower_sd_abs_max;
   }
   else
   {
      Print("AVISO: BollingerHasValidStructure chamado para timeframe não suportado: ", EnumToString(ctx.GetTimeFrame()), " - retornando false");
      return false;
   }

   // Acesso ao indicador e copia dos valores min e max
   CBollinger *boll_ind = ctx.GetIndicator("boll20");
   double upper_band_value = boll_ind.GetUpper(1);
   double lower_band_value = boll_ind.GetLower(1);

   // Largura da banda
   double boll_width = MathAbs(upper_band_value - lower_band_value);

   // Se a largura não está na faixa adequada, retorna falso
   if (boll_width < valid_min_width || boll_width > valid_max_width)
   {
      return false;
   }

   CATR *atr = ctx.GetIndicator("ATR15");
   double atr_value = atr.GetValue(1);

   SSlopeValidation slope_upper = boll_ind.GetSlopeValidation(atr_value, COPY_UPPER);
   SSlopeValidation slope_middle = boll_ind.GetSlopeValidation(atr_value, COPY_MIDDLE);
   SSlopeValidation slope_lower = boll_ind.GetSlopeValidation(atr_value, COPY_LOWER);

   // Contracting
   bool contracting_1 = slope_upper.bearish_count >= 2;
   bool contracting_2 = slope_lower.bullish_count >= 2;
   bool contracting_condition = contracting_1 && contracting_2;

   if (contracting_condition)
   {
      return false;
   }

   // Micro Inclinação Banda Superior
   // sidewalk >=2 && bear == 0
   bool c1 = slope_upper.side_count >= 2;
   Print("Contagem de Lateral: ", slope_upper.side_count);
   Print("Contagem de Bull: ", slope_upper.bullish_count);
   Print("Contagem de Bear: ", slope_upper.bearish_count);
   if (c1)
   {
      bool c2 = slope_upper.linear_regression.slope_value >= upper_lr_min;
      bool c3 = slope_upper.discrete_derivative.slope_value >= upper_dd_min;
      bool c4 = slope_upper.simple_difference.slope_value >= upper_sd_min;

      Print("SLOPE VALUES MICRO INCLINAÇÃO: &&&&&&&&&&&&&&&");
      Print("LR: ", slope_upper.linear_regression.slope_value);
      Print("DD: ", slope_upper.discrete_derivative.slope_value);
      Print("SD: ", slope_upper.simple_difference.slope_value);

      if (!c2 || !c3 || !c4)
      {
         return false;
      }
   }

   bool slope_lower_is_side_walk = slope_lower.side_count >= 2;
   if (slope_lower_is_side_walk)
   {
      bool c5 = slope_lower.linear_regression.slope_value <= lower_lr_abs_max && slope_lower.linear_regression.slope_value >= -lower_lr_abs_max;
      bool c6 = slope_lower.discrete_derivative.slope_value <= lower_dd_abs_max && slope_lower.discrete_derivative.slope_value >= -lower_dd_abs_max;
      bool c7 = slope_lower.simple_difference.slope_value <= lower_sd_abs_max && slope_lower.simple_difference.slope_value >= -lower_sd_abs_max;

      if (c5 || c6 || c7)
      {
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Verificar por sinal de entrada - LÓGICA                          |
//+------------------------------------------------------------------+
SStrategySignal CEmasBuyBull::CheckForSignal()
{
   SStrategySignal signal;
   signal.Reset();

   // Obter contextos dos timeframes
   TF_CTX *ctx_m15 = m_context_provider.GetContext(m_symbol, PERIOD_M15);
   TF_CTX *ctx_m3 = m_context_provider.GetContext(m_symbol, PERIOD_M3);
   TF_CTX *ctx_h1 = m_context_provider.GetContext(m_symbol, PERIOD_H1);

   bool have_ctx_m15 = (ctx_m15 != NULL);
   bool have_ctx_m3 = (ctx_m3 != NULL);
   bool have_ctx_h1 = (ctx_h1 != NULL);

   if (!have_ctx_m15 || !have_ctx_m3 || !have_ctx_h1)
   {
      Print("AVISO: Contextos ausentes em CheckForSignal (M15:", have_ctx_m15, ", M3:", have_ctx_m3, ", H1:", have_ctx_h1, ")");
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

   bool strong_trend_m3 = m_config.enable_strong_trend_m3 ? IsStrongTrend(ctx_m3) : true;
   bool strong_trend_m15 = m_config.enable_strong_trend_m15 ? IsStrongTrend(ctx_m15) : true;
   bool bullish_momentum = m_config.enable_bullish_momentum ? HasBullishMomentum(ctx_m15, ctx_m3) : true;
   bool good_volatility_m15 = m_config.enable_good_volatility ? IsGoodVolatilityEnvironment(ctx_m15) : true;
   bool bullish_structure_m15 = m_config.enable_bullish_structure_m15 ? IsInBullishStructure(ctx_m15) : true;
   bool bullish_structure_m3 = m_config.enable_bullish_structure_m3 ? IsInBullishStructure(ctx_m3) : true;

   // Verificar ADX
   bool strong_trend_adx_m15 = false;
   double adx_value_m15 = 0.0;
   CADX *adx_m15 = ctx_m15.GetIndicator("ADX15");
   if (adx_m15 != NULL)
   {
      adx_value_m15 = adx_m15.GetValue(1);
      strong_trend_adx_m15 = (adx_value_m15 >= m_config.adx_min_value && adx_value_m15 <= m_config.adx_max_value);
   }
   if (!m_config.enable_adx_filter)
      strong_trend_adx_m15 = true;

   SStrong_trend_ADX_m15.adx_value_tf = adx_value_m15;
   SStrong_trend_ADX_m15.config_max_value = m_config.adx_max_value;
   SStrong_trend_ADX_m15.config_min_value = m_config.adx_min_value;
   SStrong_trend_ADX_m15.isStrongTrendADX = strong_trend_adx_m15;

   // === PONTOS DE ENTRADA - VALIDAÇÃO DE PULLBACK ===
   // O método IsValidPullback agora inclui validação de posição específica
   // Não é mais necessário verificar position_info.position separadamente

   SPositionInfo ema9_m3_position = ema9_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
   _pullback_ema9_m3 = IsValidPullback(ema9_m3_position, atr_value, ctx_m3, ema9_m3);

   SPositionInfo ema21_m3_position = ema21_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
   _pullback_ema21_m3 = IsValidPullback(ema21_m3_position, atr_value, ctx_m3, ema21_m3);
   
   // === CRITÉRIO FINAL DE ENTRADA ===
   bool ema_alignment_m15_ok = m_config.enable_ema_alignment_m15 ? (EMA9_above_EMA21_M15 && EMA21_above_EMA50_M15) : true;
   bool ema_alignment_m3_ok = m_config.enable_ema_alignment_m3 ? (EMA9_above_EMA21_M3 && EMA21_above_EMA50_M3) : true;

   _m3_boll_filter.is_valid = m_config.enable_bollinger_filter_m3 ? BollingerHasValidStructure(ctx_m3) : true;
   bool is_bollinger_valid_m15 = m_config.enable_bollinger_filter_m15 ? BollingerHasValidStructure(ctx_m15) : true;
   bool is_bollinger_valid_h1 = m_config.enable_bollinger_filter_h1 ? BollingerHasValidStructure(ctx_h1) : true;

   bool filtros_ok = ema_alignment_m15_ok && ema_alignment_m3_ok &&
                     strong_trend_m15 && strong_trend_m3 &&
                     bullish_momentum &&
                     good_volatility_m15 &&
                     bullish_structure_m15 && bullish_structure_m3 &&
                     strong_trend_adx_m15 && _m3_boll_filter.is_valid && is_bollinger_valid_m15 && is_bollinger_valid_h1;

   // Simplificação: is_valid já inclui todas as validações necessárias
   bool pullback_ema9_ok = m_config.enable_pullback_ema9 ? _pullback_ema9_m3.is_valid : false;
   bool pullback_ema21_ok = m_config.enable_pullback_ema21 ? _pullback_ema21_m3.is_valid : false;
   bool entrada_setup_ok = pullback_ema9_ok || pullback_ema21_ok;
   bool entrada_valida = filtros_ok && entrada_setup_ok;

   // === LOG SIMPLIFICADO ===
   if (entrada_valida)
   {
      Print("✅ EMA Bull Buy - SINAL VÁLIDO para ", m_symbol);
      Print("   Filtros: Alinhamento EMAs ✓, Tendência forte ✓, Momentum bullish ✓");

      string ema_used = "desconhecida";
      if (pullback_ema9_ok && _pullback_ema9_m3.is_valid)
         ema_used = "EMA9";
      else if (pullback_ema21_ok && _pullback_ema21_m3.is_valid)
         ema_used = "EMA21";

      Print("   Entrada: Pullback válido detectado em ", ema_used, " M3");
      Print("   Posição EMA: ", EnumToString(ema_used == "EMA9" ? ema9_m3_position.position : ema21_m3_position.position));
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

   Print("=== FIM DO DEBUG LOG ===");
}

//+------------------------------------------------------------------+
//| Implementação específica da verificação de horário de operação  |
//+------------------------------------------------------------------+
bool CEmasBuyBull::DoOperatingHoursCheck()
{
   return m_config.IsWithinOperatingHours();
}

//+------------------------------------------------------------------+
//| Retornar configuração da estratégia                              |
//+------------------------------------------------------------------+
CStrategyConfig *CEmasBuyBull::GetStrategyConfig()
{
   return &m_config;
}

#endif