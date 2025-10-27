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
   SVolatilityEnvironment _volatility_env_M15;

   // Estruturas de Dados - ADX
   SStrongTrendADX SStrong_trend_ADX_m15;

   // Estruturas de Dados - Bollinger
   SBollingerStructure _bollinger_filter_M3;
   SBollingerStructure _bollinger_filter_M15;
   SBollingerStructure _bollinger_filter_H1;

   // Estruturas de Dados - Pullback
   SIsValidPullback _pullback_ema9_m3;
   SIsValidPullback _pullback_ema21_m3;

   // Estruturas de Dados - Momentum
   SBullishMomentum _bullish_momentum_data;

   // Estruturas de Dados - Estrutura Bullish
   SBullishStructure _bullish_structure_M15;
   SBullishStructure _bullish_structure_M3;

   double CalculateLotSize();
   double CalculateStopLoss(double entry_price);
   double CalculateTakeProfit(double entry_price, double stop_loss);

   // Métodos auxiliares migrados da lógica CompraAlta
   SStrongTrendEMAS IsStrongTrend(TF_CTX *ctx);
   SBullishMomentum HasBullishMomentum(TF_CTX *ctx_m15, TF_CTX *ctx_m3);
   SIsValidPullback IsValidPullback(SPositionInfo &position_info, double atr_value, TF_CTX *ctx, CMovingAverages *ma);
   SVolatilityEnvironment IsGoodVolatilityEnvironment(TF_CTX *ctx);
   SBullishStructure IsInBullishStructure(TF_CTX *ctx);
   SBollingerStructure BollingerHasValidStructure(TF_CTX *ctx);

   // Override do método de verificação de horário de operação
   virtual bool DoOperatingHoursCheck() override;

protected:
   virtual bool DoInit() override;
   virtual bool DoUpdate() override;
   virtual SStrategySignal CheckForSignal() override;
   virtual bool ValidateSignal(const SStrategySignal &signal) override;
   virtual void DoLog() override;
   virtual void ConfigureOrderSettings(SOrderManagerSettings &settings) override;

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
//| Retorna estrutura completa com dados de diagnóstico              |
//+------------------------------------------------------------------+
SStrongTrendEMAS CEmasBuyBull::IsStrongTrend(TF_CTX *ctx)
{
    SStrongTrendEMAS data;
    data.Reset();

    // Validação do contexto
    if (ctx == NULL)
    {
       data.fail_message = "Contexto NULL";
       return data;
    }

    // Obter indicadores
    CMovingAverages *ema9 = ctx.GetIndicator("ema9");
    CMovingAverages *ema21 = ctx.GetIndicator("ema21");
    CMovingAverages *ema50 = ctx.GetIndicator("ema50");
    CATR *atr = ctx.GetIndicator("ATR15");

    if (ema9 == NULL || ema21 == NULL || ema50 == NULL || atr == NULL)
    {
       data.fail_message = "Indicadores ausentes";
       return data;
    }

    // Obter valores dos indicadores
    data.ema9_value = ema9.GetValue(1);
    data.ema21_value = ema21.GetValue(1);
    data.ema50_value = ema50.GetValue(1);
    data.atr_value = atr.GetValue(1);
    data.timeframe = ctx.GetTimeFrame();

    if (data.atr_value <= 0)
    {
       data.fail_message = "ATR inválido: " + DoubleToString(data.atr_value, 5);
       return data;
    }

    // Calcular distâncias absolutas
    data.distance_ema_9_21 = MathAbs(data.ema21_value - data.ema9_value);
    data.distance_ema_21_50 = MathAbs(data.ema50_value - data.ema21_value);
    data.distance_ema_9_50 = MathAbs(data.ema50_value - data.ema9_value);

    // Calcular distâncias normalizadas por ATR
    data.distance_ema_9_21_by_atr = data.distance_ema_9_21 / data.atr_value;
    data.distance_ema_21_50_by_atr = data.distance_ema_21_50 / data.atr_value;
    data.distance_ema_9_50_by_atr = data.distance_ema_9_50 / data.atr_value;

    // Determinar thresholds baseados no timeframe
    if (data.timeframe == PERIOD_M15)
    {
       data.min_distance_9_21_threshold = m_config.min_distance_9_21_atr_m15;
       data.min_distance_21_50_threshold = m_config.min_distance_21_50_atr_m15;
    }
    else if (data.timeframe == PERIOD_M3)
    {
       data.min_distance_9_21_threshold = m_config.min_distance_9_21_atr_m3;
       data.min_distance_21_50_threshold = m_config.min_distance_21_50_atr_m3;
    }
    else
    {
       data.fail_message = "Timeframe não configurado: " + EnumToString(data.timeframe);
       return data;
    }

    // Validar critérios de tendência forte
    data.distance_9_21_ok = (data.distance_ema_9_21_by_atr >= data.min_distance_9_21_threshold);
    data.distance_21_50_ok = (data.distance_ema_21_50_by_atr >= data.min_distance_21_50_threshold);
    data.validation_result = data.distance_9_21_ok && data.distance_21_50_ok;

    if (data.validation_result)
    {
       data.success_message = "Tendência forte confirmada";
    }
    else
    {
       data.fail_message = "Distâncias insuficientes entre EMAs";
    }

    return data;
}

//+------------------------------------------------------------------+
//| Verificar momentum bullish através de price action              |
//| VERSÃO REFATORADA - Retorna estrutura completa com diagnóstico   |
//+------------------------------------------------------------------+
SBullishMomentum CEmasBuyBull::HasBullishMomentum(TF_CTX *ctx_m15, TF_CTX *ctx_m3)
{
    SBullishMomentum data;
    data.Reset();
    data.validation_result = false;

    // Validação dos contextos
    if (ctx_m15 == NULL || ctx_m3 == NULL)
    {
       data.fail_message = "Contextos NULL";
       return data;
    }

    // Configuração inicial
    data.timeframe_m15 = ctx_m15.GetTimeFrame();
    data.timeframe_m3 = ctx_m3.GetTimeFrame();
    data.lookback_candles = m_config.lookback_candles;
    data.min_candles_required = 2;

    // Obter EMA21 do M15
    CMovingAverages *ema21_m15 = ctx_m15.GetIndicator("ema21");
    if (ema21_m15 == NULL)
    {
       data.fail_message = "EMA21 (M15) ausente";
       return data;
    }

    data.ema21_m15_value = ema21_m15.GetValue(1);

    // ========================================================================
    // CRITÉRIO 1: Verificar se o preço está consistentemente acima da EMA21
    // ========================================================================
    for (int i = 1; i <= data.lookback_candles; i++)
    {
       double close = iClose(m_current_symbol, PERIOD_M15, i);
       double ema21_val = ema21_m15.GetValue(i);
       if (close > ema21_val)
       {
          data.candles_above_ema21++;
       }
    }
    data.price_above_ema21 = (data.candles_above_ema21 >= data.min_candles_required);

    // ========================================================================
    // CRITÉRIO 2: Verificar se não há sinais de pânico de venda
    // ========================================================================
    data.no_panic_selling = true;
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
             data.no_panic_selling = false;
             data.panic_candle_index = i;
             data.panic_lower_shadow_ratio = lower_shadow_ratio;
             break;
          }
       }
    }

    // ========================================================================
    // CRITÉRIO 3: Verificar se a última vela mostra força de alta
    // ========================================================================
    data.last_open = iOpen(m_current_symbol, PERIOD_M3, 1);
    data.last_close = iClose(m_current_symbol, PERIOD_M3, 1);
    data.last_candle_bullish = (data.last_close >= data.last_open);

    // ========================================================================
    // RESULTADO FINAL
    // ========================================================================
    data.validation_result = data.price_above_ema21 &&
                        data.no_panic_selling &&
                        data.last_candle_bullish;

    if (data.validation_result)
    {
       data.success_message = "Momentum bullish confirmado";
    }
    else
    {
       data.fail_message = "Critérios de momentum não atendidos";
    }

    return data;
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
    // ------------------ Setup ------------------
    const int CONFIRM_BAR = 1;   // vela 1: confirmação
    const int SETUP_BAR   = 2;   // vela 2: pullback toca/penetra EMA

    SIsValidPullback data; data.Reset(); data.validation_result = false;
    if (ctx == NULL || ma == NULL || atr_value <= 0) { data.fail_message = "Parâmetros inválidos"; return data; }

    data.digits = (int)SymbolInfoInteger(m_current_symbol, SYMBOL_DIGITS);
    data.point  = SymbolInfoDouble(m_current_symbol, SYMBOL_POINT);
    data.pip_value = (data.digits == 3 || data.digits == 5) ? data.point * 10.0 : data.point;
    data.criterion1_ok = (data.pip_value > 0);
    if (!data.criterion1_ok) { data.fail_message = "Pip value inválido"; return data; }

    data.timeframe = ctx.GetTimeFrame();
    data.tf_name   = EnumToString(data.timeframe);

    // OHLC e EMA para as duas velas relevantes
    const double close1 = iClose(m_current_symbol, data.timeframe, CONFIRM_BAR);
    const double open1  = iOpen (m_current_symbol, data.timeframe, CONFIRM_BAR);
    const double high1  = iHigh (m_current_symbol, data.timeframe, CONFIRM_BAR);
    const double low1   = iLow  (m_current_symbol, data.timeframe, CONFIRM_BAR);
    const double ema1   = ma.GetValue(CONFIRM_BAR);

    const double close2 = iClose(m_current_symbol, data.timeframe, SETUP_BAR);
    const double open2  = iOpen (m_current_symbol, data.timeframe, SETUP_BAR);
    const double high2  = iHigh (m_current_symbol, data.timeframe, SETUP_BAR);
    const double low2   = iLow  (m_current_symbol, data.timeframe, SETUP_BAR);
    const double ema2   = ma.GetValue(SETUP_BAR);

    // Distância do pullback (na vela 2) em unidades de preço
    data.distance_price = MathAbs(close2 - ema2);

    // ------------------ Critério 2: limite de profundidade (na vela 2) ------------------
    data.max_depth = (m_config.max_distance_atr + m_config.pullback_depth_buffer_atr) * atr_value;
    data.criterion2_ok = (data.distance_price <= data.max_depth);
    if (!data.criterion2_ok) { data.fail_message = "Distância excessiva"; return data; }

    // ------------------ Critério 3: veio de distância ANTERIOR MAIOR ------------------
    data.was_further = false;
    data.lookback_start = 3; // agora começamos antes da vela 2
    data.lookback_end   = MathMin(m_config.max_duration_candles + 2, 11);

    const double current_distance_atr = data.distance_price / atr_value;
    for (int i = data.lookback_start; i <= data.lookback_end; i++)
    {
        const double prev_close = iClose(m_current_symbol, data.timeframe, i);
        const double prev_ma    = ma.GetValue(i);
        if (prev_close > prev_ma)
        {
            const double prev_distance_atr = (prev_close - prev_ma) / atr_value;
            if (prev_distance_atr > current_distance_atr * m_config.pullback_improvement_factor)
            {
                data.was_further = true;
                data.found_at_bar = i;
                data.prev_distance_atr = prev_distance_atr;
                data.improvement_ratio  = prev_distance_atr / current_distance_atr;
                data.improvement_factor = m_config.pullback_improvement_factor;
                break;
            }
        }
    }
    data.criterion3_ok = data.was_further;
    if (!data.criterion3_ok) { data.fail_message = "Não veio de distância anterior maior"; return data; }

    // ------------------ Critério 4: posição da vela 2 é compatível com suporte na EMA ------------------
    // Em vez de usar position_info (que descreve a vela 1), avaliamos a geometria da vela 2:
    const bool crosses_lower_shadow_2 = (low2 <= ema2 && MathMax(open2, close2) >= ema2);
    const bool crosses_lower_body_2   = (MathMin(open2, close2) <= ema2 && MathMax(open2, close2) >= ema2);
    const bool center_body_2          = crosses_lower_body_2; // equivalente simples; ajuste conforme seu enum
    const bool upper_body_2           = (MathMin(open2, close2) >= ema2); // corpo acima, pavio pode tocar

    data.criterion4_ok = (crosses_lower_shadow_2 || crosses_lower_body_2 || center_body_2 || upper_body_2);
    if (!data.criterion4_ok) { data.fail_message = "Padrão de suporte inválido (vela 2)"; return data; }

    // ------------------ Critério 5: penetração abaixo da EMA na vela 2 não é excessiva ------------------
    data.max_penetration_below_ema = m_config.pullback_max_penetration_atr * atr_value;
    data.penetration = MathMax(0.0, ema2 - low2);
    data.criterion5_ok = (data.penetration <= data.max_penetration_below_ema);
    if (!data.criterion5_ok) { data.fail_message = "Penetração excessiva abaixo da EMA (vela 2)"; return data; }

    // ------------------ Confirmação (vela 1) ------------------
    // Sinais sugeridos (use qualquer combinação conforme seu setup):
    // A) fechamento acima da EMA1
    const bool close_above_ema1 = (close1 > ema1);
    // B) candle 1 altista
    const bool bullish_body1 = (close1 > open1);
    // C) retomada de momentum: rompimento do topo da vela 2
    const bool breaks_high2 = (high1 > high2);
    // D) inclinação positiva da EMA
    const bool ema_slope_up = (ema1 >= ema2);

    // Regra padrão: precisa fechar acima da EMA OU romper o topo da vela 2; e idealmente corpo altista e slope ≥ 0
    data.confirmation_ok = (close_above_ema1 || breaks_high2) && bullish_body1 && ema_slope_up;
    data.criterion6_ok = data.confirmation_ok;
    if (!data.criterion6_ok)
    {
        data.fail_message = "Sem confirmação na vela 1";
        return data;
    }

    // Opcional: filtro de volatilidade (evita confirmações fracas)
    const double range1 = high1 - low1;
    data.range_check_passed = (range1 >= m_config.pullback_min_confirm_range_atr * atr_value);
    data.criterion7_ok = data.range_check_passed;
    if (!data.criterion7_ok)
    {
        data.fail_message = "Confirmação fraca (range < limiar)";
        return data;
    }

    // ------------------ NOVO: Critério 8 - Validação Cruzada EMA9-EMA21 ------------------
    data.ema_spread_check_enabled = m_config.pullback_require_ema21_agreement;
    data.max_allowed_spread_atr = m_config.max_ema9_ema21_spread_atr;

    if (data.ema_spread_check_enabled) {
        // Obter EMA9 e EMA21
        CMovingAverages *ema9 = ctx.GetIndicator("ema9");
        CMovingAverages *ema21 = ctx.GetIndicator("ema21");

        if (ema9 == NULL || ema21 == NULL) {
            data.criterion8_ok = false;
            data.fail_message = "Indicadores EMA9/EMA21 ausentes para validação cruzada";
            return data;
        }

        // Calcular spread na vela de setup (vela 2)
        data.ema9_value_at_setup = ema9.GetValue(SETUP_BAR);
        data.ema21_value_at_setup = ema21.GetValue(SETUP_BAR);

        double spread_price = MathAbs(data.ema21_value_at_setup - data.ema9_value_at_setup);
        data.ema_spread_atr = spread_price / atr_value;

        data.ema_spread_ok = (data.ema_spread_atr <= data.max_allowed_spread_atr);
        data.criterion8_ok = data.ema_spread_ok;

        if (!data.criterion8_ok) {
            data.fail_message = "Spread EMA9-EMA21 excessivo: " + DoubleToString(data.ema_spread_atr, 2) +
                               " ATR (max: " + DoubleToString(data.max_allowed_spread_atr, 2) + ")";
            return data;
        }
    } else {
        data.criterion8_ok = true; // Desabilitado, passa automaticamente
    }

    // ------------------ Resultado ------------------
    data.validation_result = data.criterion1_ok && data.criterion2_ok &&
                            data.criterion3_ok && data.criterion4_ok &&
                            data.criterion5_ok && data.criterion6_ok &&
                            data.criterion7_ok && data.criterion8_ok;
    data.success_message = "Pullback válido confirmado (setup=vela 2, confirmação=vela 1)";
    return data;
}

//+------------------------------------------------------------------+
//| Analisar ambiente de volatilidade                               |
//| VERSÃO REFATORADA - Retorna estrutura completa com diagnóstico   |
//+------------------------------------------------------------------+
SVolatilityEnvironment CEmasBuyBull::IsGoodVolatilityEnvironment(TF_CTX *ctx)
{
    SVolatilityEnvironment data;
    data.Reset();

    // Validação do contexto
    if (ctx == NULL)
    {
       data.fail_message = "Contexto NULL";
       return data;
    }

    data.timeframe = ctx.GetTimeFrame();
    data.lookback_periods = m_config.lookback_periods;
    data.min_volatility_ratio = m_config.min_volatility_ratio;
    data.max_volatility_ratio = m_config.max_volatility_ratio;

    // Obter ATR
    CATR *atr = ctx.GetIndicator("ATR15");
    if (atr == NULL)
    {
       data.fail_message = "ATR ausente";
       return data;
    }

    data.atr_value = atr.GetValue(1);
    if (data.atr_value <= 0)
    {
       data.fail_message = "ATR inválido: " + DoubleToString(data.atr_value, 5);
       return data;
    }

    // ========================================================================
    // CÁLCULO DA MÉDIA DE ATR
    // ========================================================================
    for (int i = 1; i <= data.lookback_periods; i++)
    {
       double period_atr = atr.GetValue(i);
       if (period_atr > 0)
       {
          data.sum_atr += period_atr;
          data.valid_periods++;
       }
    }

    // Validar se temos dados suficientes
    int min_required_periods = data.lookback_periods / 2;
    data.has_valid_data = (data.valid_periods >= min_required_periods);

    if (!data.has_valid_data)
    {
       data.fail_message = "Dados insuficientes: " + IntegerToString(data.valid_periods) + "/" + IntegerToString(data.lookback_periods);
       return data;
    }

    // ========================================================================
    // CÁLCULO DO RATIO DE VOLATILIDADE
    // ========================================================================
    data.avg_atr = data.sum_atr / data.valid_periods;
    data.volatility_ratio = data.atr_value / data.avg_atr;

    // ========================================================================
    // VALIDAÇÃO DO RANGE
    // ========================================================================
    data.ratio_in_range = (data.volatility_ratio >= data.min_volatility_ratio &&
                           data.volatility_ratio <= data.max_volatility_ratio);

    // ========================================================================
    // RESULTADO FINAL
    // ========================================================================
    data.validation_result = data.has_valid_data && data.ratio_in_range;

    if (data.validation_result)
    {
       data.success_message = "Ambiente de volatilidade adequado";
    }
    else
    {
       data.fail_message = "Ratio de volatilidade fora do range";
    }

    return data;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em estrutura de alta                 |
//| VERSÃO REFATORADA - Retorna estrutura completa com diagnóstico   |
//+------------------------------------------------------------------+
SBullishStructure CEmasBuyBull::IsInBullishStructure(TF_CTX *ctx)
{
    SBullishStructure data;
    data.Reset();

    // Validação do contexto
    if (ctx == NULL)
    {
       data.fail_message = "Contexto NULL";
       return data;
    }

    data.timeframe = ctx.GetTimeFrame();
    data.min_distance_threshold = m_config.bullish_structure_atr_threshold;

    // Obter indicadores
    CMovingAverages *ema50 = ctx.GetIndicator("ema50");
    CATR *atr = ctx.GetIndicator("ATR15");

    if (ema50 == NULL || atr == NULL)
    {
       data.fail_message = "Indicadores ausentes";
       return data;
    }

    data.current_close = iClose(m_current_symbol, data.timeframe, 1);
    data.ema50_value = ema50.GetValue(1);
    data.atr_value = atr.GetValue(1);

    if (data.atr_value <= 0)
    {
       data.fail_message = "ATR inválido: " + DoubleToString(data.atr_value, 5);
       return data;
    }

    // ========================================================================
    // CRITÉRIO 1: Preço deve estar acima da EMA50
    // ========================================================================
    data.price_above_ema50 = (data.current_close > data.ema50_value);

    if (!data.price_above_ema50)
    {
       data.fail_message = "Preço abaixo da EMA50";
       return data;
    }

    // ========================================================================
    // CRITÉRIO 2: Preço deve estar a uma distância mínima da EMA50
    // ========================================================================
    data.distance_to_ema50 = data.current_close - data.ema50_value;
    data.distance_to_ema50_atr = data.distance_to_ema50 / data.atr_value;
    data.distance_ok = (data.distance_to_ema50_atr >= data.min_distance_threshold);

    if (!data.distance_ok)
    {
       data.fail_message = "Distância insuficiente da EMA50";
       return data;
    }

    // ========================================================================
    // CRITÉRIO 3: EMA50 deve estar inclinada para cima
    // ========================================================================
    SSlopeValidation slope_50 = ema50.GetSlopeValidation(data.atr_value, COPY_MIDDLE);
    data.ema50_trending_up = (slope_50.simple_difference.trend_direction != SLOPE_DOWN ||
                              slope_50.discrete_derivative.trend_direction != SLOPE_DOWN ||
                              slope_50.linear_regression.trend_direction != SLOPE_DOWN);

    // ========================================================================
    // RESULTADO FINAL
    // ========================================================================
    data.validation_result = data.price_above_ema50 &&
                                data.distance_ok &&
                                data.ema50_trending_up;

    if (data.validation_result)
    {
       data.success_message = "Estrutura bullish confirmada";
    }
    else
    {
       data.fail_message = "EMA50 não está em tendência de alta";
    }

    // ========================================================================
    // LOG DE DIAGNÓSTICO
    // ========================================================================
    return data;
}

//+------------------------------------------------------------------+
//| Filtro Bollinger                                                 |
//| VERSÃO REFATORADA - Retorna estrutura completa com diagnóstico   |
//+------------------------------------------------------------------+
SBollingerStructure CEmasBuyBull::BollingerHasValidStructure(TF_CTX *ctx)
{
    SBollingerStructure data;
    data.Reset();
    // Validação do contexto
    if (ctx == NULL)
    {
       data.fail_message = "Contexto NULL";
       return data;
    }

    data.timeframe = ctx.GetTimeFrame();

    // ========================================================================
    // CONFIGURAÇÃO BASEADA NO TIMEFRAME
    // ========================================================================
    if (data.timeframe == PERIOD_M3)
    {
       data.valid_min_width = m_config.boll_micro_m3_min_width;
       data.valid_max_width = m_config.boll_micro_m3_max_width;
       data.upper_lr_min = m_config.boll_micro_m3_upper_lr_min;
       data.upper_dd_min = m_config.boll_micro_m3_upper_dd_min;
       data.upper_sd_min = m_config.boll_micro_m3_upper_sd_min;
       data.lower_lr_abs_max = m_config.boll_micro_m3_lower_lr_abs_max;
       data.lower_dd_abs_max = m_config.boll_micro_m3_lower_dd_abs_max;
       data.lower_sd_abs_max = m_config.boll_micro_m3_lower_sd_abs_max;
    }
    else if (data.timeframe == PERIOD_M15)
    {
       data.valid_min_width = m_config.boll_micro_m15_min_width;
       data.valid_max_width = m_config.boll_micro_m15_max_width;
       data.upper_lr_min = m_config.boll_micro_m15_upper_lr_min;
       data.upper_dd_min = m_config.boll_micro_m15_upper_dd_min;
       data.upper_sd_min = m_config.boll_micro_m15_upper_sd_min;
       data.lower_lr_abs_max = m_config.boll_micro_m15_lower_lr_abs_max;
       data.lower_dd_abs_max = m_config.boll_micro_m15_lower_dd_abs_max;
       data.lower_sd_abs_max = m_config.boll_micro_m15_lower_sd_abs_max;
    }
    else if (data.timeframe == PERIOD_H1)
    {
       data.valid_min_width = m_config.boll_micro_h1_min_width;
       data.valid_max_width = m_config.boll_micro_h1_max_width;
       data.upper_lr_min = m_config.boll_micro_h1_upper_lr_min;
       data.upper_dd_min = m_config.boll_micro_h1_upper_dd_min;
       data.upper_sd_min = m_config.boll_micro_h1_upper_sd_min;
       data.lower_lr_abs_max = m_config.boll_micro_h1_lower_lr_abs_max;
       data.lower_dd_abs_max = m_config.boll_micro_h1_lower_dd_abs_max;
       data.lower_sd_abs_max = m_config.boll_micro_h1_lower_sd_abs_max;
    }
    else
    {
       data.fail_message = "Timeframe não suportado: " + EnumToString(data.timeframe);
       return data;
    }

    // Obter indicadores
    CBollinger *boll_ind = ctx.GetIndicator("boll20");
    CATR *atr = ctx.GetIndicator("ATR15");

    if (boll_ind == NULL || atr == NULL)
    {
       data.fail_message = "Indicadores ausentes";
       return data;
    }

    data.upper_band_value = boll_ind.GetUpper(1);
    data.lower_band_value = boll_ind.GetLower(1);
    data.boll_width = MathAbs(data.upper_band_value - data.lower_band_value);
    data.atr_value = atr.GetValue(1);

    // ========================================================================
    // CRITÉRIO 1: Largura da banda deve estar na faixa adequada
    // ========================================================================
    data.width_in_range = (data.boll_width >= data.valid_min_width &&
                           data.boll_width <= data.valid_max_width);

    if (!data.width_in_range)
    {
       data.fail_message = "Largura fora da faixa: " + DoubleToString(data.boll_width, 5);
       return data;
    }

    // ========================================================================
    // OBTER SLOPES
    // ========================================================================
    SSlopeValidation slope_upper = boll_ind.GetSlopeValidation(data.atr_value, COPY_UPPER);
    SSlopeValidation slope_middle = boll_ind.GetSlopeValidation(data.atr_value, COPY_MIDDLE);
    SSlopeValidation slope_lower = boll_ind.GetSlopeValidation(data.atr_value, COPY_LOWER);

    // ========================================================================
    // CRITÉRIO 2: Não pode estar em contração
    // ========================================================================
    data.contracting_upper = (slope_upper.bearish_count >= 2);
    data.contracting_lower = (slope_lower.bullish_count >= 2);
    data.is_contracting = data.contracting_upper && data.contracting_lower;

    if (data.is_contracting)
    {
       data.fail_message = "Bandas em contração";
       return data;
    }

    // ========================================================================
    // CRITÉRIO 3: Micro inclinação da banda superior
    // ========================================================================
    data.upper_is_sidewalk = (slope_upper.side_count >= 2);

    if (data.upper_is_sidewalk)
    {
       data.upper_lr_ok = (slope_upper.linear_regression.slope_value >= data.upper_lr_min);
       data.upper_dd_ok = (slope_upper.discrete_derivative.slope_value >= data.upper_dd_min);
       data.upper_sd_ok = (slope_upper.simple_difference.slope_value >= data.upper_sd_min);

       data.upper_micro_ok = data.upper_lr_ok && data.upper_dd_ok && data.upper_sd_ok;

       if (!data.upper_micro_ok)
       {
          data.fail_message = "Micro inclinação superior insuficiente";
          return data;
       }
    }
    else
    {
       data.upper_micro_ok = true; // Não é sidewalk, então não aplica critério
    }

    // ========================================================================
    // CRITÉRIO 4: Validação da banda inferior (sidewalk)
    // ========================================================================
    data.lower_is_sidewalk = (slope_lower.side_count >= 2);

    if (data.lower_is_sidewalk)
    {
       data.lower_lr_invalid = (slope_lower.linear_regression.slope_value > data.lower_lr_abs_max ||
                                slope_lower.linear_regression.slope_value < -data.lower_lr_abs_max);
       data.lower_dd_invalid = (slope_lower.discrete_derivative.slope_value > data.lower_dd_abs_max ||
                                slope_lower.discrete_derivative.slope_value < -data.lower_dd_abs_max);
       data.lower_sd_invalid = (slope_lower.simple_difference.slope_value > data.lower_sd_abs_max ||
                                slope_lower.simple_difference.slope_value < -data.lower_sd_abs_max);

       data.lower_sidewalk_invalid = data.lower_lr_invalid || data.lower_dd_invalid || data.lower_sd_invalid;

       if (data.lower_sidewalk_invalid)
       {
          data.fail_message = "Banda inferior sidewalk inválida";
          return data;
       }
    }

    // ========================================================================
    // RESULTADO FINAL
    // ========================================================================
    data.validation_result = data.width_in_range &&
                              !data.is_contracting &&
                              data.upper_micro_ok &&
                              !data.lower_sidewalk_invalid;

    if (data.validation_result)
    {
       data.success_message = "Estrutura Bollinger válida";
    }
    else
    {
       data.fail_message = "Estrutura Bollinger inválida";
    }

    return data;
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

   // === ANÁLISE DE TENDÊNCIA FORTE ===
   // Obter dados completos de tendência para diagnóstico
   _ema_data_M3 = IsStrongTrend(ctx_m3);
   _ema_data_M15 = IsStrongTrend(ctx_m15);

   // Validar tendência forte baseado na configuração
   bool strong_trend_m3 = m_config.enable_strong_trend_m3 ? _ema_data_M3.validation_result : true;
   bool strong_trend_m15 = m_config.enable_strong_trend_m15 ? _ema_data_M15.validation_result : true;

   // === ANÁLISE DE MOMENTUM ===
   _bullish_momentum_data = HasBullishMomentum(ctx_m15, ctx_m3);
   bool bullish_momentum = m_config.enable_bullish_momentum ? _bullish_momentum_data.validation_result : true;

   // === ANÁLISE DE VOLATILIDADE ===
   _volatility_env_M15 = IsGoodVolatilityEnvironment(ctx_m15);
   bool good_volatility_m15 = m_config.enable_good_volatility ? _volatility_env_M15.validation_result : true;

   _bullish_structure_M15 = IsInBullishStructure(ctx_m15);
   _bullish_structure_M3 = IsInBullishStructure(ctx_m3);
   bool bullish_structure_m15 = m_config.enable_bullish_structure_m15 ? _bullish_structure_M15.validation_result : true;
   bool bullish_structure_m3 = m_config.enable_bullish_structure_m3 ? _bullish_structure_M3.validation_result : true;

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
   SStrong_trend_ADX_m15.validation_result = strong_trend_adx_m15;

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

   // === FILTROS BOLLINGER ===
   _bollinger_filter_M3 = BollingerHasValidStructure(ctx_m3);
   _bollinger_filter_M15 = BollingerHasValidStructure(ctx_m15);
   _bollinger_filter_H1 = BollingerHasValidStructure(ctx_h1);

   bool is_bollinger_valid_m3 = m_config.enable_bollinger_filter_m3 ? _bollinger_filter_M3.validation_result : true;
   bool is_bollinger_valid_m15 = m_config.enable_bollinger_filter_m15 ? _bollinger_filter_M15.validation_result : true;
   bool is_bollinger_valid_h1 = m_config.enable_bollinger_filter_h1 ? _bollinger_filter_H1.validation_result : true;

   bool filtros_ok = ema_alignment_m15_ok && ema_alignment_m3_ok &&
                     strong_trend_m15 && strong_trend_m3 &&
                     bullish_momentum &&
                     good_volatility_m15 &&
                     bullish_structure_m15 && bullish_structure_m3 &&
                     strong_trend_adx_m15 && is_bollinger_valid_m3 && is_bollinger_valid_m15 && is_bollinger_valid_h1;

   // Simplificação: is_valid já inclui todas as validações necessárias
   bool pullback_ema9_ok = m_config.enable_pullback_ema9 ? _pullback_ema9_m3.validation_result : false;
   bool pullback_ema21_ok = m_config.enable_pullback_ema21 ? _pullback_ema21_m3.validation_result : false;
   bool entrada_setup_ok = pullback_ema9_ok || pullback_ema21_ok;
   bool entrada_valida = filtros_ok && entrada_setup_ok;

   // === LOG SIMPLIFICADO ===
   if (entrada_valida)
   {
      Print("✅ EMA Bull Buy - SINAL VÁLIDO para ", m_symbol);
      Print("   Filtros: Alinhamento EMAs ✓, Tendência forte ✓, Momentum bullish ✓");

      string ema_used = "desconhecida";
      if (pullback_ema9_ok && _pullback_ema9_m3.validation_result)
         ema_used = "EMA9";
      else if (pullback_ema21_ok && _pullback_ema21_m3.validation_result)
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
//+------------------------------------------------------------------+
//| Método especial para log completo de debug da estratégia         |
//| VERSÃO ENRIQUECIDA com métricas adicionais                       |
//+------------------------------------------------------------------+
void CEmasBuyBull::DoLog()
{
   if (true)
   {
      Print("================================================================================");
      Print("==================== EMA BULL BUY STRATEGY - DEBUG LOG =======================");
      Print("================================================================================");
      Print("Símbolo: ", m_symbol, " | Timestamp: ", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
      Print("Spread Atual: ", SymbolInfoInteger(m_symbol, SYMBOL_SPREAD), " points");
      Print("Bid: ", DoubleToString(SymbolInfoDouble(m_symbol, SYMBOL_BID), _Digits),
            " | Ask: ", DoubleToString(SymbolInfoDouble(m_symbol, SYMBOL_ASK), _Digits));
      Print("");

      // ========================================================================
      // STRONG TREND M15
      // ========================================================================
      if (true)
      {
         Print("┌─────────────────────────────────────────────────────────────────────────────┐");
         Print("│ STRONG TREND M15                                                            │");
         Print("└─────────────────────────────────────────────────────────────────────────────┘");
         Print("Timeframe: ", EnumToString(_ema_data_M15.timeframe));
         Print("EMA9: ", DoubleToString(_ema_data_M15.ema9_value, _Digits),
               " | EMA21: ", DoubleToString(_ema_data_M15.ema21_value, _Digits),
               " | EMA50: ", DoubleToString(_ema_data_M15.ema50_value, _Digits));
         Print("ATR: ", DoubleToString(_ema_data_M15.atr_value, 5));
         
         // NOVO: Calcular % de separação entre EMAs
         double sep_9_21_pct = (_ema_data_M15.ema21_value != 0) ? 
            ((_ema_data_M15.ema9_value - _ema_data_M15.ema21_value) / _ema_data_M15.ema21_value * 100.0) : 0.0;
         double sep_21_50_pct = (_ema_data_M15.ema50_value != 0) ? 
            ((_ema_data_M15.ema21_value - _ema_data_M15.ema50_value) / _ema_data_M15.ema50_value * 100.0) : 0.0;
         
         Print("Distância 9-21: ", DoubleToString(_ema_data_M15.distance_ema_9_21_by_atr, 2),
               " ATR (", DoubleToString(sep_9_21_pct, 2), "%) ",
               "(min: ", DoubleToString(_ema_data_M15.min_distance_9_21_threshold, 2), ") ",
               _ema_data_M15.distance_9_21_ok ? "✓" : "✗");
         Print("Distância 21-50: ", DoubleToString(_ema_data_M15.distance_ema_21_50_by_atr, 2),
               " ATR (", DoubleToString(sep_21_50_pct, 2), "%) ",
               "(min: ", DoubleToString(_ema_data_M15.min_distance_21_50_threshold, 2), ") ",
               _ema_data_M15.distance_21_50_ok ? "✓" : "✗");
         
         // NOVO: Distância total 9-50 (força geral do trend)
         Print("Distância Total 9-50: ", DoubleToString(_ema_data_M15.distance_ema_9_50_by_atr, 2), " ATR");
         
         // NOVO: Obter slopes das EMAs para contexto adicional
         TF_CTX *ctx_m15 = m_context_provider.GetContext(m_symbol, PERIOD_M15);
         if (ctx_m15 != NULL) {
            CMovingAverages *ema9_m15 = ctx_m15.GetIndicator("ema9");
            CMovingAverages *ema21_m15 = ctx_m15.GetIndicator("ema21");
            CMovingAverages *ema50_m15 = ctx_m15.GetIndicator("ema50");
            
            if (ema9_m15 != NULL && ema21_m15 != NULL && ema50_m15 != NULL) {
               SSlopeValidation slope9 = ema9_m15.GetSlopeValidation(_ema_data_M15.atr_value, COPY_MIDDLE);
               SSlopeValidation slope21 = ema21_m15.GetSlopeValidation(_ema_data_M15.atr_value, COPY_MIDDLE);
               SSlopeValidation slope50 = ema50_m15.GetSlopeValidation(_ema_data_M15.atr_value, COPY_MIDDLE);
               
               Print("Inclinações:");
               Print("  EMA9  - Bullish: ", slope9.bullish_count, "/3 | Bearish: ", slope9.bearish_count, 
                     "/3 | Side: ", slope9.side_count, "/3 | LR: ", DoubleToString(slope9.linear_regression.slope_value, 3));
               Print("  EMA21 - Bullish: ", slope21.bullish_count, "/3 | Bearish: ", slope21.bearish_count, 
                     "/3 | Side: ", slope21.side_count, "/3 | LR: ", DoubleToString(slope21.linear_regression.slope_value, 3));
               Print("  EMA50 - Bullish: ", slope50.bullish_count, "/3 | Bearish: ", slope50.bearish_count, 
                     "/3 | Side: ", slope50.side_count, "/3 | LR: ", DoubleToString(slope50.linear_regression.slope_value, 3));
            }
         }
         
         Print("Resultado: ", _ema_data_M15.validation_result ? "✅ TENDÊNCIA FORTE" : "✗ Tendência fraca");
         if (_ema_data_M15.fail_message != "")
            Print("Fail Message: ", _ema_data_M15.fail_message);
         if (_ema_data_M15.success_message != "")
            Print("Success Message: ", _ema_data_M15.success_message);
         Print("Habilitado: ", m_config.enable_strong_trend_m15 ? "SIM" : "NÃO");
         Print("");
      }

      // ========================================================================
      // STRONG TREND M3
      // ========================================================================
      if (true)
      {
         Print("┌─────────────────────────────────────────────────────────────────────────────┐");
         Print("│ STRONG TREND M3                                                             │");
         Print("└─────────────────────────────────────────────────────────────────────────────┘");
         Print("Timeframe: ", EnumToString(_ema_data_M3.timeframe));
         Print("EMA9: ", DoubleToString(_ema_data_M3.ema9_value, _Digits),
               " | EMA21: ", DoubleToString(_ema_data_M3.ema21_value, _Digits),
               " | EMA50: ", DoubleToString(_ema_data_M3.ema50_value, _Digits));
         Print("ATR: ", DoubleToString(_ema_data_M3.atr_value, 5));
         
         // NOVO: % de separação
         double sep_9_21_pct = (_ema_data_M3.ema21_value != 0) ? 
            ((_ema_data_M3.ema9_value - _ema_data_M3.ema21_value) / _ema_data_M3.ema21_value * 100.0) : 0.0;
         double sep_21_50_pct = (_ema_data_M3.ema50_value != 0) ? 
            ((_ema_data_M3.ema21_value - _ema_data_M3.ema50_value) / _ema_data_M3.ema50_value * 100.0) : 0.0;
         
         Print("Distância 9-21: ", DoubleToString(_ema_data_M3.distance_ema_9_21_by_atr, 2),
               " ATR (", DoubleToString(sep_9_21_pct, 2), "%) ",
               "(min: ", DoubleToString(_ema_data_M3.min_distance_9_21_threshold, 2), ") ",
               _ema_data_M3.distance_9_21_ok ? "✓" : "✗");
         Print("Distância 21-50: ", DoubleToString(_ema_data_M3.distance_ema_21_50_by_atr, 2),
               " ATR (", DoubleToString(sep_21_50_pct, 2), "%) ",
               "(min: ", DoubleToString(_ema_data_M3.min_distance_21_50_threshold, 2), ") ",
               _ema_data_M3.distance_21_50_ok ? "✓" : "✗");
         
         Print("Distância Total 9-50: ", DoubleToString(_ema_data_M3.distance_ema_9_50_by_atr, 2), " ATR");
         
         // NOVO: Slopes M3
         TF_CTX *ctx_m3 = m_context_provider.GetContext(m_symbol, PERIOD_M3);
         if (ctx_m3 != NULL) {
            CMovingAverages *ema9_m3 = ctx_m3.GetIndicator("ema9");
            CMovingAverages *ema21_m3 = ctx_m3.GetIndicator("ema21");
            CMovingAverages *ema50_m3 = ctx_m3.GetIndicator("ema50");
            
            if (ema9_m3 != NULL && ema21_m3 != NULL && ema50_m3 != NULL) {
               SSlopeValidation slope9 = ema9_m3.GetSlopeValidation(_ema_data_M3.atr_value, COPY_MIDDLE);
               SSlopeValidation slope21 = ema21_m3.GetSlopeValidation(_ema_data_M3.atr_value, COPY_MIDDLE);
               SSlopeValidation slope50 = ema50_m3.GetSlopeValidation(_ema_data_M3.atr_value, COPY_MIDDLE);
               
               Print("Inclinações:");
               Print("  EMA9  - Bullish: ", slope9.bullish_count, "/3 | Bearish: ", slope9.bearish_count, 
                     "/3 | Side: ", slope9.side_count, "/3 | LR: ", DoubleToString(slope9.linear_regression.slope_value, 3));
               Print("  EMA21 - Bullish: ", slope21.bullish_count, "/3 | Bearish: ", slope21.bearish_count, 
                     "/3 | Side: ", slope21.side_count, "/3 | LR: ", DoubleToString(slope21.linear_regression.slope_value, 3));
               Print("  EMA50 - Bullish: ", slope50.bullish_count, "/3 | Bearish: ", slope50.bearish_count, 
                     "/3 | Side: ", slope50.side_count, "/3 | LR: ", DoubleToString(slope50.linear_regression.slope_value, 3));
            }
         }
         
         Print("Resultado: ", _ema_data_M3.validation_result ? "✅ TENDÊNCIA FORTE" : "✗ Tendência fraca");
         if (_ema_data_M3.fail_message != "")
            Print("Fail Message: ", _ema_data_M3.fail_message);
         if (_ema_data_M3.success_message != "")
            Print("Success Message: ", _ema_data_M3.success_message);
         Print("Habilitado: ", m_config.enable_strong_trend_m3 ? "SIM" : "NÃO");
         Print("");
      }

      // ========================================================================
      // BULLISH MOMENTUM
      // ========================================================================
      if (true)
      {
         Print("┌─────────────────────────────────────────────────────────────────────────────┐");
         Print("│ BULLISH MOMENTUM                                                            │");
         Print("└─────────────────────────────────────────────────────────────────────────────┘");
         Print("Timeframes: ", EnumToString(_bullish_momentum_data.timeframe_m15), "/",
               EnumToString(_bullish_momentum_data.timeframe_m3));
         Print("EMA21 (M15): ", DoubleToString(_bullish_momentum_data.ema21_m15_value, _Digits));
         Print("Lookback: ", _bullish_momentum_data.lookback_candles, " candles");
         Print("Candles acima EMA21: ", _bullish_momentum_data.candles_above_ema21,
               "/", _bullish_momentum_data.lookback_candles,
               " (min: ", _bullish_momentum_data.min_candles_required, ") ",
               _bullish_momentum_data.price_above_ema21 ? "✓" : "✗");
         
         // NOVO: % de candles acima da EMA21
         double pct_above = (_bullish_momentum_data.lookback_candles > 0) ? 
            ((double)_bullish_momentum_data.candles_above_ema21 / _bullish_momentum_data.lookback_candles * 100.0) : 0.0;
         Print("  └─ Percentual acima: ", DoubleToString(pct_above, 1), "%");
         
         Print("Sem pânico: ", _bullish_momentum_data.no_panic_selling ? "✓" : "✗");
         if (!_bullish_momentum_data.no_panic_selling)
         {
            Print("  └─ Pânico detectado na barra ", _bullish_momentum_data.panic_candle_index,
                  " (shadow ratio: ", DoubleToString(_bullish_momentum_data.panic_lower_shadow_ratio, 3), ")");
         }
         
         Print("Última vela bullish: ", _bullish_momentum_data.last_candle_bullish ? "✓" : "✗",
               " (Open: ", DoubleToString(_bullish_momentum_data.last_open, _Digits),
               ", Close: ", DoubleToString(_bullish_momentum_data.last_close, _Digits), ")");
         
         // NOVO: Tamanho do corpo da última vela
         double body_size = MathAbs(_bullish_momentum_data.last_close - _bullish_momentum_data.last_open);
         double body_size_atr = (_ema_data_M3.atr_value > 0) ? body_size / _ema_data_M3.atr_value : 0.0;
         Print("  └─ Tamanho do corpo: ", DoubleToString(body_size_atr, 2), " ATR");
         
         Print("Resultado: ", _bullish_momentum_data.validation_result ? "✅ MOMENTUM CONFIRMADO" : "✗ Sem momentum");
         if (_bullish_momentum_data.fail_message != "")
            Print("Fail Message: ", _bullish_momentum_data.fail_message);
         if (_bullish_momentum_data.success_message != "")
            Print("Success Message: ", _bullish_momentum_data.success_message);
         Print("Habilitado: ", m_config.enable_bullish_momentum ? "SIM" : "NÃO");
         Print("");
      }

      // ========================================================================
      // VOLATILITY ENVIRONMENT
      // ========================================================================
      if (true)
      {
         Print("┌─────────────────────────────────────────────────────────────────────────────┐");
         Print("│ VOLATILITY ENVIRONMENT M15                                                  │");
         Print("└─────────────────────────────────────────────────────────────────────────────┘");
         Print("Timeframe: ", EnumToString(_volatility_env_M15.timeframe));
         Print("ATR atual: ", DoubleToString(_volatility_env_M15.atr_value, 5));
         Print("Lookback: ", _volatility_env_M15.lookback_periods, " períodos");
         Print("Períodos válidos: ", _volatility_env_M15.valid_periods, "/",
               _volatility_env_M15.lookback_periods, " ",
               _volatility_env_M15.has_valid_data ? "✓" : "✗");
         Print("ATR médio: ", DoubleToString(_volatility_env_M15.avg_atr, 5));
         Print("Ratio: ", DoubleToString(_volatility_env_M15.volatility_ratio, 3),
               " (range: ", DoubleToString(_volatility_env_M15.min_volatility_ratio, 2),
               " - ", DoubleToString(_volatility_env_M15.max_volatility_ratio, 2), ") ",
               _volatility_env_M15.ratio_in_range ? "✓" : "✗");
         
         // NOVO: Classificação de volatilidade
         string vol_class = "NORMAL";
         if (_volatility_env_M15.volatility_ratio < 0.7) vol_class = "BAIXA";
         else if (_volatility_env_M15.volatility_ratio > 1.3) vol_class = "ALTA";
         Print("  └─ Classificação: ", vol_class);
         
         // NOVO: Variação % do ATR em relação à média
         double var_pct = (_volatility_env_M15.avg_atr > 0) ? 
            ((_volatility_env_M15.atr_value - _volatility_env_M15.avg_atr) / _volatility_env_M15.avg_atr * 100.0) : 0.0;
         Print("  └─ Variação: ", DoubleToString(var_pct, 1), "% em relação à média");
         
         Print("Resultado: ", _volatility_env_M15.validation_result ? "✅ AMBIENTE ADEQUADO" : "✗ Ambiente inadequado");
         if (_volatility_env_M15.fail_message != "")
            Print("Fail Message: ", _volatility_env_M15.fail_message);
         if (_volatility_env_M15.success_message != "")
            Print("Success Message: ", _volatility_env_M15.success_message);
         Print("Habilitado: ", m_config.enable_good_volatility ? "SIM" : "NÃO");
         Print("");
      }

      // ========================================================================
      // ADX FILTER
      // ========================================================================
      if (true)
      {
         Print("┌─────────────────────────────────────────────────────────────────────────────┐");
         Print("│ ADX FILTER M15                                                              │");
         Print("└─────────────────────────────────────────────────────────────────────────────┘");
         Print("ADX Value: ", DoubleToString(SStrong_trend_ADX_m15.adx_value_tf, 2));
         Print("Range: ", DoubleToString(SStrong_trend_ADX_m15.config_min_value, 2),
               " - ", DoubleToString(SStrong_trend_ADX_m15.config_max_value, 2));
         
         // NOVO: Classificação de força da tendência por ADX
         string adx_strength = "INDEFINIDO";
         if (SStrong_trend_ADX_m15.adx_value_tf < 20) adx_strength = "FRACO/LATERAL";
         else if (SStrong_trend_ADX_m15.adx_value_tf < 25) adx_strength = "MODERADO";
         else if (SStrong_trend_ADX_m15.adx_value_tf < 40) adx_strength = "FORTE";
         else if (SStrong_trend_ADX_m15.adx_value_tf < 60) adx_strength = "MUITO FORTE";
         else adx_strength = "EXTREMO";
         Print("  └─ Força da tendência: ", adx_strength);
         
         // NOVO: Obter DI+ e DI- se disponível
         TF_CTX *ctx_m15 = m_context_provider.GetContext(m_symbol, PERIOD_M15);
         if (ctx_m15 != NULL) {
            CADX *adx = ctx_m15.GetIndicator("ADX15");
            if (adx != NULL) {
               double di_plus = adx.GetPlusDI(1);
               double di_minus = adx.GetMinusDI(1);
               Print("  └─ DI+: ", DoubleToString(di_plus, 2), 
                     " | DI-: ", DoubleToString(di_minus, 2),
                     " | Diferença: ", DoubleToString(di_plus - di_minus, 2));
            }
         }
         
         Print("Resultado: ", SStrong_trend_ADX_m15.validation_result ? "✅ ADX OK" : "✗ ADX fora do range");
         Print("Habilitado: ", m_config.enable_adx_filter ? "SIM" : "NÃO");
         Print("");
      }

      // ========================================================================
      // BULLISH STRUCTURE M15
      // ========================================================================
      if (true)
      {
         Print("┌─────────────────────────────────────────────────────────────────────────────┐");
         Print("│ BULLISH STRUCTURE M15                                                       │");
         Print("└─────────────────────────────────────────────────────────────────────────────┘");
         Print("Timeframe: ", EnumToString(_bullish_structure_M15.timeframe));
         Print("Preço: ", DoubleToString(_bullish_structure_M15.current_close, _Digits),
               " | EMA50: ", DoubleToString(_bullish_structure_M15.ema50_value, _Digits));
         Print("ATR: ", DoubleToString(_bullish_structure_M15.atr_value, 5));
         Print("Preço > EMA50: ", _bullish_structure_M15.price_above_ema50 ? "✓" : "✗");
         Print("Distância: ", DoubleToString(_bullish_structure_M15.distance_to_ema50_atr, 2),
               " ATR (min: ", DoubleToString(_bullish_structure_M15.min_distance_threshold, 2), ") ",
               _bullish_structure_M15.distance_ok ? "✓" : "✗");
         
         // NOVO: % de distância em relação à EMA50
         double dist_pct = (_bullish_structure_M15.ema50_value != 0) ? 
            (_bullish_structure_M15.distance_to_ema50 / _bullish_structure_M15.ema50_value * 100.0) : 0.0;
         Print("  └─ Percentual de distância: ", DoubleToString(dist_pct, 2), "%");
         
         Print("EMA50 inclinada: ", _bullish_structure_M15.ema50_trending_up ? "✓" : "✗");
         
         Print("Resultado: ", _bullish_structure_M15.validation_result ? "✅ ESTRUTURA BULLISH" : "✗ Estrutura não bullish");
         if (_bullish_structure_M15.fail_message != "")
            Print("Fail Message: ", _bullish_structure_M15.fail_message);
         if (_bullish_structure_M15.success_message != "")
            Print("Success Message: ", _bullish_structure_M15.success_message);
         Print("Habilitado: ", m_config.enable_bullish_structure_m15 ? "SIM" : "NÃO");
         Print("");
      }

      // ========================================================================
      // BULLISH STRUCTURE M3
      // ========================================================================
      if (true)
      {
         Print("┌─────────────────────────────────────────────────────────────────────────────┐");
         Print("│ BULLISH STRUCTURE M3                                                        │");
         Print("└─────────────────────────────────────────────────────────────────────────────┘");
         Print("Timeframe: ", EnumToString(_bullish_structure_M3.timeframe));
         Print("Preço: ", DoubleToString(_bullish_structure_M3.current_close, _Digits),
               " | EMA50: ", DoubleToString(_bullish_structure_M3.ema50_value, _Digits));
         Print("ATR: ", DoubleToString(_bullish_structure_M3.atr_value, 5));
         Print("Preço > EMA50: ", _bullish_structure_M3.price_above_ema50 ? "✓" : "✗");
         Print("Distância: ", DoubleToString(_bullish_structure_M3.distance_to_ema50_atr, 2),
               " ATR (min: ", DoubleToString(_bullish_structure_M3.min_distance_threshold, 2), ") ",
               _bullish_structure_M3.distance_ok ? "✓" : "✗");
         
         // NOVO: % de distância
         double dist_pct = (_bullish_structure_M3.ema50_value != 0) ? 
            (_bullish_structure_M3.distance_to_ema50 / _bullish_structure_M3.ema50_value * 100.0) : 0.0;
         Print("  └─ Percentual de distância: ", DoubleToString(dist_pct, 2), "%");
         
         Print("EMA50 inclinada: ", _bullish_structure_M3.ema50_trending_up ? "✓" : "✗");
         
         Print("Resultado: ", _bullish_structure_M3.validation_result ? "✅ ESTRUTURA BULLISH" : "✗ Estrutura não bullish");
         if (_bullish_structure_M3.fail_message != "")
            Print("Fail Message: ", _bullish_structure_M3.fail_message);
         if (_bullish_structure_M3.success_message != "")
            Print("Success Message: ", _bullish_structure_M3.success_message);
         Print("Habilitado: ", m_config.enable_bullish_structure_m3 ? "SIM" : "NÃO");
         Print("");
      }

      // ========================================================================
      // BOLLINGER M3
      // ========================================================================
      if (true)
      {
         Print("┌─────────────────────────────────────────────────────────────────────────────┐");
         Print("│ BOLLINGER FILTER M3                                                         │");
         Print("└─────────────────────────────────────────────────────────────────────────────┘");
         Print("Timeframe: ", EnumToString(_bollinger_filter_M3.timeframe));
         Print("Banda Superior: ", DoubleToString(_bollinger_filter_M3.upper_band_value, _Digits));
         Print("Banda Inferior: ", DoubleToString(_bollinger_filter_M3.lower_band_value, _Digits));
         Print("Largura: ", DoubleToString(_bollinger_filter_M3.boll_width, 5),
               " (range: ", DoubleToString(_bollinger_filter_M3.valid_min_width, 5),
               " - ", DoubleToString(_bollinger_filter_M3.valid_max_width, 5), ") ",
               _bollinger_filter_M3.width_in_range ? "✓" : "✗");
         Print("ATR: ", DoubleToString(_bollinger_filter_M3.atr_value, 5));
         
         // NOVO: Largura normalizada por ATR
         double width_atr = (_bollinger_filter_M3.atr_value > 0) ? 
            _bollinger_filter_M3.boll_width / _bollinger_filter_M3.atr_value : 0.0;
         Print("  └─ Largura normalizada: ", DoubleToString(width_atr, 2), " ATR");
         
         // NOVO: Posição do preço nas bandas
         TF_CTX *ctx_m3 = m_context_provider.GetContext(m_symbol, PERIOD_M3);
         if (ctx_m3 != NULL) {
            double close = iClose(m_symbol, PERIOD_M3, 1);
            double band_range = _bollinger_filter_M3.upper_band_value - _bollinger_filter_M3.lower_band_value;
            if (band_range > 0) {
               double price_position = (close - _bollinger_filter_M3.lower_band_value) / band_range * 100.0;
               Print("  └─ Posição do preço nas bandas: ", DoubleToString(price_position, 1), "%");
            }
         }
         
         Print("Em contração: ", _bollinger_filter_M3.is_contracting ? "✗" : "✓");
         Print("Banda Superior:");
         Print("  Sidewalk: ", _bollinger_filter_M3.upper_is_sidewalk ? "sim" : "não");
         if (_bollinger_filter_M3.upper_is_sidewalk)
         {
            Print("  Micro inclinação OK: ", _bollinger_filter_M3.upper_micro_ok ? "✓" : "✗");
            Print("    └─ LR: ", _bollinger_filter_M3.upper_lr_ok ? "✓" : "✗",
                  " | DD: ", _bollinger_filter_M3.upper_dd_ok ? "✓" : "✗",
                  " | SD: ", _bollinger_filter_M3.upper_sd_ok ? "✓" : "✗");
         }
         Print("Banda Inferior:");
         Print("  Sidewalk: ", _bollinger_filter_M3.lower_is_sidewalk ? "sim" : "não");
         if (_bollinger_filter_M3.lower_is_sidewalk)
         {
            Print("  Sidewalk válido: ", _bollinger_filter_M3.lower_sidewalk_invalid ? "✗" : "✓");
            if (_bollinger_filter_M3.lower_sidewalk_invalid) {
               Print("    └─ LR invalid: ", _bollinger_filter_M3.lower_lr_invalid ? "sim" : "não",
                     " | DD invalid: ", _bollinger_filter_M3.lower_dd_invalid ? "sim" : "não",
                     " | SD invalid: ", _bollinger_filter_M3.lower_sd_invalid ? "sim" : "não");
            }
         }
         Print("Resultado: ", _bollinger_filter_M3.validation_result ? "✅ ESTRUTURA VÁLIDA" : "✗ Estrutura inválida");
         if (_bollinger_filter_M3.fail_message != "")
            Print("Fail Message: ", _bollinger_filter_M3.fail_message);
         if (_bollinger_filter_M3.success_message != "")
            Print("Success Message: ", _bollinger_filter_M3.success_message);
         Print("Habilitado: ", m_config.enable_bollinger_filter_m3 ? "SIM" : "NÃO");
         Print("");
      }

      // ========================================================================
      // BOLLINGER M15
      // ========================================================================
      if (true)
      {
         Print("┌─────────────────────────────────────────────────────────────────────────────┐");
         Print("│ BOLLINGER FILTER M15                                                        │");
         Print("└─────────────────────────────────────────────────────────────────────────────┘");
         Print("Timeframe: ", EnumToString(_bollinger_filter_M15.timeframe));
         Print("Banda Superior: ", DoubleToString(_bollinger_filter_M15.upper_band_value, _Digits));
         Print("Banda Inferior: ", DoubleToString(_bollinger_filter_M15.lower_band_value, _Digits));
         Print("Largura: ", DoubleToString(_bollinger_filter_M15.boll_width, 5),
               " (range: ", DoubleToString(_bollinger_filter_M15.valid_min_width, 5),
               " - ", DoubleToString(_bollinger_filter_M15.valid_max_width, 5), ") ",
               _bollinger_filter_M15.width_in_range ? "✓" : "✗");
         Print("ATR: ", DoubleToString(_bollinger_filter_M15.atr_value, 5));
         
         // NOVO: Largura normalizada
         double width_atr = (_bollinger_filter_M15.atr_value > 0) ? 
            _bollinger_filter_M15.boll_width / _bollinger_filter_M15.atr_value : 0.0;
         Print("  └─ Largura normalizada: ", DoubleToString(width_atr, 2), " ATR");
         
         // NOVO: Posição do preço
         TF_CTX *ctx_m15 = m_context_provider.GetContext(m_symbol, PERIOD_M15);
         if (ctx_m15 != NULL) {
            double close = iClose(m_symbol, PERIOD_M15, 1);
            double band_range = _bollinger_filter_M15.upper_band_value - _bollinger_filter_M15.lower_band_value;
            if (band_range > 0) {
               double price_position = (close - _bollinger_filter_M15.lower_band_value) / band_range * 100.0;
               Print("  └─ Posição do preço nas bandas: ", DoubleToString(price_position, 1), "%");
            }
         }
         
         Print("Em contração: ", _bollinger_filter_M15.is_contracting ? "✗" : "✓");
         Print("Banda Superior:");
         Print("  Sidewalk: ", _bollinger_filter_M15.upper_is_sidewalk ? "sim" : "não");
         if (_bollinger_filter_M15.upper_is_sidewalk)
         {
            Print("  Micro inclinação OK: ", _bollinger_filter_M15.upper_micro_ok ? "✓" : "✗");
            Print("    └─ LR: ", _bollinger_filter_M15.upper_lr_ok ? "✓" : "✗",
                  " | DD: ", _bollinger_filter_M15.upper_dd_ok ? "✓" : "✗",
                  " | SD: ", _bollinger_filter_M15.upper_sd_ok ? "✓" : "✗");
         }
         Print("Banda Inferior:");
         Print("  Sidewalk: ", _bollinger_filter_M15.lower_is_sidewalk ? "sim" : "não");
         if (_bollinger_filter_M15.lower_is_sidewalk)
         {
            Print("  Sidewalk válido: ", _bollinger_filter_M15.lower_sidewalk_invalid ? "✗" : "✓");
            if (_bollinger_filter_M15.lower_sidewalk_invalid) {
               Print("    └─ LR invalid: ", _bollinger_filter_M15.lower_lr_invalid ? "sim" : "não",
                     " | DD invalid: ", _bollinger_filter_M15.lower_dd_invalid ? "sim" : "não",
                     " | SD invalid: ", _bollinger_filter_M15.lower_sd_invalid ? "sim" : "não");
            }
         }
         Print("Resultado: ", _bollinger_filter_M15.validation_result ? "✅ ESTRUTURA VÁLIDA" : "✗ Estrutura inválida");
         if (_bollinger_filter_M15.fail_message != "")
            Print("Fail Message: ", _bollinger_filter_M15.fail_message);
         if (_bollinger_filter_M15.success_message != "")
            Print("Success Message: ", _bollinger_filter_M15.success_message);
         Print("Habilitado: ", m_config.enable_bollinger_filter_m15 ? "SIM" : "NÃO");
         Print("");
      }

      // ========================================================================
      // BOLLINGER H1
      // ========================================================================
      if (m_config.enable_bollinger_filter_h1)  // Só mostra se habilitado
      {
         Print("┌─────────────────────────────────────────────────────────────────────────────┐");
         Print("│ BOLLINGER FILTER H1                                                         │");
         Print("└─────────────────────────────────────────────────────────────────────────────┘");
         Print("Timeframe: ", EnumToString(_bollinger_filter_H1.timeframe));
         Print("Banda Superior: ", DoubleToString(_bollinger_filter_H1.upper_band_value, _Digits));
         Print("Banda Inferior: ", DoubleToString(_bollinger_filter_H1.lower_band_value, _Digits));
         Print("Largura: ", DoubleToString(_bollinger_filter_H1.boll_width, 5),
               " (range: ", DoubleToString(_bollinger_filter_H1.valid_min_width, 5),
               " - ", DoubleToString(_bollinger_filter_H1.valid_max_width, 5), ") ",
               _bollinger_filter_H1.width_in_range ? "✓" : "✗");
         Print("ATR: ", DoubleToString(_bollinger_filter_H1.atr_value, 5));
         
         double width_atr = (_bollinger_filter_H1.atr_value > 0) ? 
            _bollinger_filter_H1.boll_width / _bollinger_filter_H1.atr_value : 0.0;
         Print("  └─ Largura normalizada: ", DoubleToString(width_atr, 2), " ATR");
         
         TF_CTX *ctx_h1 = m_context_provider.GetContext(m_symbol, PERIOD_H1);
         if (ctx_h1 != NULL) {
            double close = iClose(m_symbol, PERIOD_H1, 1);
            double band_range = _bollinger_filter_H1.upper_band_value - _bollinger_filter_H1.lower_band_value;
            if (band_range > 0) {
               double price_position = (close - _bollinger_filter_H1.lower_band_value) / band_range * 100.0;
               Print("  └─ Posição do preço nas bandas: ", DoubleToString(price_position, 1), "%");
            }
         }
         
         Print("Em contração: ", _bollinger_filter_H1.is_contracting ? "✗" : "✓");
         Print("Banda Superior:");
         Print("  Sidewalk: ", _bollinger_filter_H1.upper_is_sidewalk ? "sim" : "não");
         if (_bollinger_filter_H1.upper_is_sidewalk)
         {
            Print("  Micro inclinação OK: ", _bollinger_filter_H1.upper_micro_ok ? "✓" : "✗");
         }
         Print("Banda Inferior:");
         Print("  Sidewalk: ", _bollinger_filter_H1.lower_is_sidewalk ? "sim" : "não");
         if (_bollinger_filter_H1.lower_is_sidewalk)
         {
            Print("  Sidewalk válido: ", _bollinger_filter_H1.lower_sidewalk_invalid ? "✗" : "✓");
         }
         Print("Resultado: ", _bollinger_filter_H1.validation_result ? "✅ ESTRUTURA VÁLIDA" : "✗ Estrutura inválida");
         if (_bollinger_filter_H1.fail_message != "")
            Print("Fail Message: ", _bollinger_filter_H1.fail_message);
         if (_bollinger_filter_H1.success_message != "")
            Print("Success Message: ", _bollinger_filter_H1.success_message);
         Print("Habilitado: SIM");
         Print("");
      }

      // ========================================================================
      // PULLBACK EMA9 M3
      // ========================================================================
      if (true)
      {
         Print("┌─────────────────────────────────────────────────────────────────────────────┐");
         Print("│ PULLBACK EMA9 M3                                                            │");
         Print("└─────────────────────────────────────────────────────────────────────────────┘");
         Print("Timeframe: ", _pullback_ema9_m3.tf_name);
         Print("Preço: ", DoubleToString(_pullback_ema9_m3.last_close, _Digits),
               " | EMA: ", DoubleToString(_pullback_ema9_m3.current_ma_value, _Digits));
         Print("Distância atual: ", DoubleToString(_pullback_ema9_m3.distance_price, 5));
         
         // NOVO: Distância normalizada
         double dist_atr = (_ema_data_M3.atr_value > 0) ? 
            _pullback_ema9_m3.distance_price / _ema_data_M3.atr_value : 0.0;
         Print("  └─ Distância normalizada: ", DoubleToString(dist_atr, 2), " ATR");
         Print("");

         // Critérios detalhados de validação
         Print("📋 CRITÉRIOS DE VALIDAÇÃO:");
         Print("  1. Parâmetros válidos (Setup inicial): ", _pullback_ema9_m3.criterion1_ok ? "✅ Sim" : "✗ Não");
         if (_pullback_ema9_m3.criterion1_ok) {
            Print("  2. Profundidade máxima (Vela 2, Limita retração): ",
                  _pullback_ema9_m3.criterion2_ok ? "✅ OK" : "✗ Excessiva",
                  " (", DoubleToString(_pullback_ema9_m3.max_depth, 5), ")");
         }
         if (_pullback_ema9_m3.criterion1_ok && _pullback_ema9_m3.criterion2_ok) {
            Print("  3. Veio de mais longe (Vela 2, Confirma pullback): ", _pullback_ema9_m3.criterion3_ok ? "✅ Sim" : "✗ Não");
            if (_pullback_ema9_m3.criterion3_ok && _pullback_ema9_m3.was_further)
            {
               Print("     └─ Distância anterior: ", DoubleToString(_pullback_ema9_m3.prev_distance_atr, 2),
                     " ATR (barra ", _pullback_ema9_m3.found_at_bar, ") | Melhoria: ", 
                     DoubleToString(_pullback_ema9_m3.improvement_ratio, 2), "x");
               
               // NOVO: Mostrar faixa de busca
               Print("     └─ Faixa de busca: barras ", _pullback_ema9_m3.lookback_start, 
                     " a ", _pullback_ema9_m3.lookback_end);
            }
         }
         if (_pullback_ema9_m3.criterion1_ok && _pullback_ema9_m3.criterion2_ok && _pullback_ema9_m3.criterion3_ok) {
            Print("  4. Padrão de suporte (Vela 2, Geometria válida): ", _pullback_ema9_m3.criterion4_ok ? "✅ Sim" : "✗ Não");
         }
         if (_pullback_ema9_m3.criterion1_ok && _pullback_ema9_m3.criterion2_ok && _pullback_ema9_m3.criterion3_ok && _pullback_ema9_m3.criterion4_ok) {
            Print("  5. Penetração máxima (Vela 2, Controla risco): ",
                  _pullback_ema9_m3.criterion5_ok ? "✅ OK" : "✗ Excessiva",
                  " (", DoubleToString(_pullback_ema9_m3.penetration, 5), " ≤ ", 
                  DoubleToString(_pullback_ema9_m3.max_penetration_below_ema, 5), ")");
            
            // NOVO: % de penetração
            if (_pullback_ema9_m3.max_penetration_below_ema > 0) {
               double pen_pct = (_pullback_ema9_m3.penetration / _pullback_ema9_m3.max_penetration_below_ema) * 100.0;
               Print("     └─ Utilização do limite: ", DoubleToString(pen_pct, 1), "%");
            }
         }
         if (_pullback_ema9_m3.criterion1_ok && _pullback_ema9_m3.criterion2_ok && _pullback_ema9_m3.criterion3_ok && _pullback_ema9_m3.criterion4_ok && _pullback_ema9_m3.criterion5_ok) {
            Print("  6. Confirmação retomada (Vela 1, Sinal entrada): ", _pullback_ema9_m3.criterion6_ok ? "✅ OK" : "✗ Falhou");
         }
         if (_pullback_ema9_m3.criterion1_ok && _pullback_ema9_m3.criterion2_ok && _pullback_ema9_m3.criterion3_ok && _pullback_ema9_m3.criterion4_ok && _pullback_ema9_m3.criterion5_ok && _pullback_ema9_m3.criterion6_ok) {
            Print("  7. Range mínimo (Vela 1, Qualidade sinal): ", _pullback_ema9_m3.criterion7_ok ? "✅ OK" : "✗ Falhou");
         }
         if (_pullback_ema9_m3.ema_spread_check_enabled && _pullback_ema9_m3.criterion1_ok && _pullback_ema9_m3.criterion2_ok && _pullback_ema9_m3.criterion3_ok && _pullback_ema9_m3.criterion4_ok && _pullback_ema9_m3.criterion5_ok && _pullback_ema9_m3.criterion6_ok && _pullback_ema9_m3.criterion7_ok) {
            Print("  8. Spread EMA9-EMA21 (Vela 2, Evita sobreextensão): ",
                  _pullback_ema9_m3.criterion8_ok ? "✅ OK" : "✗ Excessivo",
                  " (", DoubleToString(_pullback_ema9_m3.ema_spread_atr, 2),
                  " ≤ ", DoubleToString(_pullback_ema9_m3.max_allowed_spread_atr, 2), " ATR)");
            Print("     └─ EMA9: ", DoubleToString(_pullback_ema9_m3.ema9_value_at_setup, _Digits),
                  " | EMA21: ", DoubleToString(_pullback_ema9_m3.ema21_value_at_setup, _Digits));
            
            // NOVO: % de utilização do spread permitido
            if (_pullback_ema9_m3.max_allowed_spread_atr > 0) {
               double spread_pct = (_pullback_ema9_m3.ema_spread_atr / _pullback_ema9_m3.max_allowed_spread_atr) * 100.0;
               Print("     └─ Utilização do limite: ", DoubleToString(spread_pct, 1), "%");
            }
         }

         Print("");
         
         // NOVO: Score de qualidade do pullback (0-8 ou 0-7)
         int max_criteria = _pullback_ema9_m3.ema_spread_check_enabled ? 8 : 7;
         int passed_criteria = 0;
         if (_pullback_ema9_m3.criterion1_ok) passed_criteria++;
         if (_pullback_ema9_m3.criterion2_ok) passed_criteria++;
         if (_pullback_ema9_m3.criterion3_ok) passed_criteria++;
         if (_pullback_ema9_m3.criterion4_ok) passed_criteria++;
         if (_pullback_ema9_m3.criterion5_ok) passed_criteria++;
         if (_pullback_ema9_m3.criterion6_ok) passed_criteria++;
         if (_pullback_ema9_m3.criterion7_ok) passed_criteria++;
         if (_pullback_ema9_m3.ema_spread_check_enabled && _pullback_ema9_m3.criterion8_ok) passed_criteria++;
         
         double quality_score = ((double)passed_criteria / max_criteria) * 100.0;
         Print("Score de Qualidade: ", passed_criteria, "/", max_criteria, 
               " (", DoubleToString(quality_score, 1), "%)");
         
         Print("Resultado: ", _pullback_ema9_m3.validation_result ? "✅ PULLBACK VÁLIDO" : "✗ Pullback inválido");
         if (_pullback_ema9_m3.fail_message != "")
            Print("Fail Message: ", _pullback_ema9_m3.fail_message);
         if (_pullback_ema9_m3.success_message != "")
            Print("Success Message: ", _pullback_ema9_m3.success_message);
         Print("Habilitado: ", m_config.enable_pullback_ema9 ? "SIM" : "NÃO");
         Print("");
      }

      // ========================================================================
      // PULLBACK EMA21 M3
      // ========================================================================
      if (true)
      {
         Print("┌─────────────────────────────────────────────────────────────────────────────┐");
         Print("│ PULLBACK EMA21 M3                                                           │");
         Print("└─────────────────────────────────────────────────────────────────────────────┘");
         Print("Timeframe: ", _pullback_ema21_m3.tf_name);
         Print("Preço: ", DoubleToString(_pullback_ema21_m3.last_close, _Digits),
               " | EMA: ", DoubleToString(_pullback_ema21_m3.current_ma_value, _Digits));
         Print("Distância atual: ", DoubleToString(_pullback_ema21_m3.distance_price, 5));
         
         // NOVO: Distância normalizada
         double dist_atr = (_ema_data_M3.atr_value > 0) ? 
            _pullback_ema21_m3.distance_price / _ema_data_M3.atr_value : 0.0;
         Print("  └─ Distância normalizada: ", DoubleToString(dist_atr, 2), " ATR");
         Print("");

         // Critérios detalhados de validação
         Print("📋 CRITÉRIOS DE VALIDAÇÃO:");
         Print("  1. Parâmetros válidos (Setup inicial): ", _pullback_ema21_m3.criterion1_ok ? "✅ Sim" : "✗ Não");
         if (_pullback_ema21_m3.criterion1_ok) {
            Print("  2. Profundidade máxima (Vela 2, Limita retração): ",
                  _pullback_ema21_m3.criterion2_ok ? "✅ OK" : "✗ Excessiva",
                  " (", DoubleToString(_pullback_ema21_m3.max_depth, 5), ")");
         }
         if (_pullback_ema21_m3.criterion1_ok && _pullback_ema21_m3.criterion2_ok) {
            Print("  3. Veio de mais longe (Vela 2, Confirma pullback): ", _pullback_ema21_m3.criterion3_ok ? "✅ Sim" : "✗ Não");
            if (_pullback_ema21_m3.criterion3_ok && _pullback_ema21_m3.was_further)
            {
               Print("     └─ Distância anterior: ", DoubleToString(_pullback_ema21_m3.prev_distance_atr, 2),
                     " ATR (barra ", _pullback_ema21_m3.found_at_bar, ") | Melhoria: ", 
                     DoubleToString(_pullback_ema21_m3.improvement_ratio, 2), "x");
               Print("     └─ Faixa de busca: barras ", _pullback_ema21_m3.lookback_start, 
                     " a ", _pullback_ema21_m3.lookback_end);
            }
         }
         if (_pullback_ema21_m3.criterion1_ok && _pullback_ema21_m3.criterion2_ok && _pullback_ema21_m3.criterion3_ok) {
            Print("  4. Padrão de suporte (Vela 2, Geometria válida): ", _pullback_ema21_m3.criterion4_ok ? "✅ Sim" : "✗ Não");
         }
         if (_pullback_ema21_m3.criterion1_ok && _pullback_ema21_m3.criterion2_ok && _pullback_ema21_m3.criterion3_ok && _pullback_ema21_m3.criterion4_ok) {
            Print("  5. Penetração máxima (Vela 2, Controla risco): ",
                  _pullback_ema21_m3.criterion5_ok ? "✅ OK" : "✗ Excessiva",
                  " (", DoubleToString(_pullback_ema21_m3.penetration, 5), " ≤ ", 
                  DoubleToString(_pullback_ema21_m3.max_penetration_below_ema, 5), ")");
            
            if (_pullback_ema21_m3.max_penetration_below_ema > 0) {
               double pen_pct = (_pullback_ema21_m3.penetration / _pullback_ema21_m3.max_penetration_below_ema) * 100.0;
               Print("     └─ Utilização do limite: ", DoubleToString(pen_pct, 1), "%");
            }
         }
         if (_pullback_ema21_m3.criterion1_ok && _pullback_ema21_m3.criterion2_ok && _pullback_ema21_m3.criterion3_ok && _pullback_ema21_m3.criterion4_ok && _pullback_ema21_m3.criterion5_ok) {
            Print("  6. Confirmação retomada (Vela 1, Sinal entrada): ", _pullback_ema21_m3.criterion6_ok ? "✅ OK" : "✗ Falhou");
         }
         if (_pullback_ema21_m3.criterion1_ok && _pullback_ema21_m3.criterion2_ok && _pullback_ema21_m3.criterion3_ok && _pullback_ema21_m3.criterion4_ok && _pullback_ema21_m3.criterion5_ok && _pullback_ema21_m3.criterion6_ok) {
            Print("  7. Range mínimo (Vela 1, Qualidade sinal): ", _pullback_ema21_m3.criterion7_ok ? "✅ OK" : "✗ Falhou");
         }
         if (_pullback_ema21_m3.ema_spread_check_enabled && _pullback_ema21_m3.criterion1_ok && _pullback_ema21_m3.criterion2_ok && _pullback_ema21_m3.criterion3_ok && _pullback_ema21_m3.criterion4_ok && _pullback_ema21_m3.criterion5_ok && _pullback_ema21_m3.criterion6_ok && _pullback_ema21_m3.criterion7_ok) {
            Print("  8. Spread EMA9-EMA21 (Vela 2, Evita sobreextensão): ",
                  _pullback_ema21_m3.criterion8_ok ? "✅ OK" : "✗ Excessivo",
                  " (", DoubleToString(_pullback_ema21_m3.ema_spread_atr, 2),
                  " ≤ ", DoubleToString(_pullback_ema21_m3.max_allowed_spread_atr, 2), " ATR)");
            Print("     └─ EMA9: ", DoubleToString(_pullback_ema21_m3.ema9_value_at_setup, _Digits),
                  " | EMA21: ", DoubleToString(_pullback_ema21_m3.ema21_value_at_setup, _Digits));
            
            if (_pullback_ema21_m3.max_allowed_spread_atr > 0) {
               double spread_pct = (_pullback_ema21_m3.ema_spread_atr / _pullback_ema21_m3.max_allowed_spread_atr) * 100.0;
               Print("     └─ Utilização do limite: ", DoubleToString(spread_pct, 1), "%");
            }
         }

         Print("");
         
         // NOVO: Score de qualidade
         int max_criteria = _pullback_ema21_m3.ema_spread_check_enabled ? 8 : 7;
         int passed_criteria = 0;
         if (_pullback_ema21_m3.criterion1_ok) passed_criteria++;
         if (_pullback_ema21_m3.criterion2_ok) passed_criteria++;
         if (_pullback_ema21_m3.criterion3_ok) passed_criteria++;
         if (_pullback_ema21_m3.criterion4_ok) passed_criteria++;
         if (_pullback_ema21_m3.criterion5_ok) passed_criteria++;
         if (_pullback_ema21_m3.criterion6_ok) passed_criteria++;
         if (_pullback_ema21_m3.criterion7_ok) passed_criteria++;
         if (_pullback_ema21_m3.ema_spread_check_enabled && _pullback_ema21_m3.criterion8_ok) passed_criteria++;
         
         double quality_score = ((double)passed_criteria / max_criteria) * 100.0;
         Print("Score de Qualidade: ", passed_criteria, "/", max_criteria, 
               " (", DoubleToString(quality_score, 1), "%)");
         
         Print("Resultado: ", _pullback_ema21_m3.validation_result ? "✅ PULLBACK VÁLIDO" : "✗ Pullback inválido");
         if (_pullback_ema21_m3.fail_message != "")
            Print("Fail Message: ", _pullback_ema21_m3.fail_message);
         if (_pullback_ema21_m3.success_message != "")
            Print("Success Message: ", _pullback_ema21_m3.success_message);
         Print("Habilitado: ", m_config.enable_pullback_ema21 ? "SIM" : "NÃO");
         Print("");
      }

      // ========================================================================
      // RESUMO FINAL DA ESTRATÉGIA
      // ========================================================================
      Print("┌─────────────────────────────────────────────────────────────────────────────┐");
      Print("│ RESUMO FINAL - DECISÃO DE ENTRADA                                          │");
      Print("└─────────────────────────────────────────────────────────────────────────────┘");
      
      // Validar todos os filtros
      bool ema_alignment_m15_ok = true;
      bool ema_alignment_m3_ok = true;
      
      TF_CTX *ctx_m15 = m_context_provider.GetContext(m_symbol, PERIOD_M15);
      TF_CTX *ctx_m3 = m_context_provider.GetContext(m_symbol, PERIOD_M3);
      
      if (m_config.enable_ema_alignment_m15 && ctx_m15 != NULL) {
         CMovingAverages *ema9_m15 = ctx_m15.GetIndicator("ema9");
         CMovingAverages *ema21_m15 = ctx_m15.GetIndicator("ema21");
         CMovingAverages *ema50_m15 = ctx_m15.GetIndicator("ema50");
         if (ema9_m15 != NULL && ema21_m15 != NULL && ema50_m15 != NULL) {
            double ema9_val = ema9_m15.GetValue(1);
            double ema21_val = ema21_m15.GetValue(1);
            double ema50_val = ema50_m15.GetValue(1);
            ema_alignment_m15_ok = (ema9_val > ema21_val && ema21_val > ema50_val);
         }
      } else if (!m_config.enable_ema_alignment_m15) {
         ema_alignment_m15_ok = true;
      }
      
      if (m_config.enable_ema_alignment_m3 && ctx_m3 != NULL) {
         CMovingAverages *ema9_m3 = ctx_m3.GetIndicator("ema9");
         CMovingAverages *ema21_m3 = ctx_m3.GetIndicator("ema21");
         CMovingAverages *ema50_m3 = ctx_m3.GetIndicator("ema50");
         if (ema9_m3 != NULL && ema21_m3 != NULL && ema50_m3 != NULL) {
            double ema9_val = ema9_m3.GetValue(1);
            double ema21_val = ema21_m3.GetValue(1);
            double ema50_val = ema50_m3.GetValue(1);
            ema_alignment_m3_ok = (ema9_val > ema21_val && ema21_val > ema50_val);
         }
      } else if (!m_config.enable_ema_alignment_m3) {
         ema_alignment_m3_ok = true;
      }
      
      bool strong_trend_m15 = m_config.enable_strong_trend_m15 ? _ema_data_M15.validation_result : true;
      bool strong_trend_m3 = m_config.enable_strong_trend_m3 ? _ema_data_M3.validation_result : true;
      bool bullish_momentum = m_config.enable_bullish_momentum ? _bullish_momentum_data.validation_result : true;
      bool good_volatility = m_config.enable_good_volatility ? _volatility_env_M15.validation_result : true;
      bool bullish_structure_m15 = m_config.enable_bullish_structure_m15 ? _bullish_structure_M15.validation_result : true;
      bool bullish_structure_m3 = m_config.enable_bullish_structure_m3 ? _bullish_structure_M3.validation_result : true;
      bool strong_trend_adx = m_config.enable_adx_filter ? SStrong_trend_ADX_m15.validation_result : true;
      bool is_bollinger_valid_m3 = m_config.enable_bollinger_filter_m3 ? _bollinger_filter_M3.validation_result : true;
      bool is_bollinger_valid_m15 = m_config.enable_bollinger_filter_m15 ? _bollinger_filter_M15.validation_result : true;
      bool is_bollinger_valid_h1 = m_config.enable_bollinger_filter_h1 ? _bollinger_filter_H1.validation_result : true;
      
      bool pullback_ema9_ok = m_config.enable_pullback_ema9 ? _pullback_ema9_m3.validation_result : false;
      bool pullback_ema21_ok = m_config.enable_pullback_ema21 ? _pullback_ema21_m3.validation_result : false;
      
      bool filtros_ok = ema_alignment_m15_ok && ema_alignment_m3_ok &&
                        strong_trend_m15 && strong_trend_m3 &&
                        bullish_momentum &&
                        good_volatility &&
                        bullish_structure_m15 && bullish_structure_m3 &&
                        strong_trend_adx && 
                        is_bollinger_valid_m3 && is_bollinger_valid_m15 && is_bollinger_valid_h1;
      
      bool entrada_setup_ok = pullback_ema9_ok || pullback_ema21_ok;
      bool entrada_valida = filtros_ok && entrada_setup_ok;
      
      // Exibir status de cada filtro
      Print("╔═════════════════════════════════════════════════════════════════════════════╗");
      Print("║ FILTROS DE CONTEXTO                                                         ║");
      Print("╠═════════════════════════════════════════════════════════════════════════════╣");
      Print("║ 1. Alinhamento EMAs M15    : ", ema_alignment_m15_ok ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_ema_alignment_m15 ? "YES" : "NO ", " ║");
      Print("║ 2. Alinhamento EMAs M3     : ", ema_alignment_m3_ok ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_ema_alignment_m3 ? "YES" : "NO ", " ║");
      Print("║ 3. Tendência Forte M15     : ", strong_trend_m15 ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_strong_trend_m15 ? "YES" : "NO ", " ║");
      Print("║ 4. Tendência Forte M3      : ", strong_trend_m3 ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_strong_trend_m3 ? "YES" : "NO ", " ║");
      Print("║ 5. Momentum Bullish        : ", bullish_momentum ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_bullish_momentum ? "YES" : "NO ", " ║");
      Print("║ 6. Volatilidade Adequada   : ", good_volatility ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_good_volatility ? "YES" : "NO ", " ║");
      Print("║ 7. Estrutura Bullish M15   : ", bullish_structure_m15 ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_bullish_structure_m15 ? "YES" : "NO ", " ║");
      Print("║ 8. Estrutura Bullish M3    : ", bullish_structure_m3 ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_bullish_structure_m3 ? "YES" : "NO ", " ║");
      Print("║ 9. ADX Filter M15          : ", strong_trend_adx ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_adx_filter ? "YES" : "NO ", " ║");
      Print("║10. Bollinger Filter M3     : ", is_bollinger_valid_m3 ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_bollinger_filter_m3 ? "YES" : "NO ", " ║");
      Print("║11. Bollinger Filter M15    : ", is_bollinger_valid_m15 ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_bollinger_filter_m15 ? "YES" : "NO ", " ║");
      Print("║12. Bollinger Filter H1     : ", is_bollinger_valid_h1 ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_bollinger_filter_h1 ? "YES" : "NO ", " ║");
      Print("╠═════════════════════════════════════════════════════════════════════════════╣");
      Print("║ STATUS FILTROS: ", filtros_ok ? "✅ TODOS OK                                             " : "✗ ALGUM FILTRO FALHOU                                  ", " ║");
      Print("╚═════════════════════════════════════════════════════════════════════════════╝");
      Print("");
      
      Print("╔═════════════════════════════════════════════════════════════════════════════╗");
      Print("║ SETUP DE ENTRADA (PULLBACK)                                                 ║");
      Print("╠═════════════════════════════════════════════════════════════════════════════╣");
      Print("║ Pullback EMA9 M3           : ", pullback_ema9_ok ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_pullback_ema9 ? "YES" : "NO ", " ║");
      Print("║ Pullback EMA21 M3          : ", pullback_ema21_ok ? "✅ OK      " : "✗ FALHOU  ", " │ Enabled: ", m_config.enable_pullback_ema21 ? "YES" : "NO ", " ║");
      Print("╠═════════════════════════════════════════════════════════════════════════════╣");
      Print("║ STATUS SETUP: ", entrada_setup_ok ? "✅ PELO MENOS UM PULLBACK VÁLIDO                       " : "✗ NENHUM PULLBACK VÁLIDO                               ", " ║");
      Print("╚═════════════════════════════════════════════════════════════════════════════╝");
      Print("");
      
      // NOVO: Contadores de filtros
      int total_filters = 12;
      int passed_filters = 0;
      if (ema_alignment_m15_ok) passed_filters++;
      if (ema_alignment_m3_ok) passed_filters++;
      if (strong_trend_m15) passed_filters++;
      if (strong_trend_m3) passed_filters++;
      if (bullish_momentum) passed_filters++;
      if (good_volatility) passed_filters++;
      if (bullish_structure_m15) passed_filters++;
      if (bullish_structure_m3) passed_filters++;
      if (strong_trend_adx) passed_filters++;
      if (is_bollinger_valid_m3) passed_filters++;
      if (is_bollinger_valid_m15) passed_filters++;
      if (is_bollinger_valid_h1) passed_filters++;
      
      double filter_pass_rate = ((double)passed_filters / total_filters) * 100.0;
      
      Print("╔═════════════════════════════════════════════════════════════════════════════╗");
      Print("║ ESTATÍSTICAS                                                                ║");
      Print("╠═════════════════════════════════════════════════════════════════════════════╣");
      Print("║ Filtros Aprovados          : ", passed_filters, "/", total_filters, " (", DoubleToString(filter_pass_rate, 1), "%)                              ║");
      
      // NOVO: Calcular risk/reward ratio
      if (entrada_valida) {
         double entry_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         double sl_price = CalculateStopLoss(entry_price);
         double tp_price = CalculateTakeProfit(entry_price, sl_price);
         double risk = entry_price - sl_price;
         double reward = tp_price - entry_price;
         double rr_ratio = (risk > 0) ? reward / risk : 0.0;
         
         Print("║ Entry Price                : ", DoubleToString(entry_price, _Digits), "                                       ║");
         Print("║ Stop Loss                  : ", DoubleToString(sl_price, _Digits), " (Risk: ", DoubleToString(risk, _Digits), ")              ║");
         Print("║ Take Profit                : ", DoubleToString(tp_price, _Digits), " (Reward: ", DoubleToString(reward, _Digits), ")           ║");
         Print("║ Risk/Reward Ratio          : 1:", DoubleToString(rr_ratio, 2), "                                          ║");
         
         // NOVO: Tamanho do lote e risco em moeda
         double lot_size = CalculateLotSize();
         double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
         double tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
         double risk_money = 0.0;
         if (tick_size > 0) {
            risk_money = (risk / tick_size) * tick_value * lot_size;
         }
         
         Print("║ Lot Size                   : ", DoubleToString(lot_size, 2), "                                            ║");
         Print("║ Risk Amount                : $", DoubleToString(risk_money, 2), "                                         ║");
         Print("║ Potential Profit           : $", DoubleToString(risk_money * rr_ratio, 2), "                                      ║");
         
         // NOVO: Verificar margem disponível
         double margin_required = 0;
         if (OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, lot_size, entry_price, margin_required)) {
            double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
            double margin_usage = (free_margin > 0) ? (margin_required / free_margin) * 100.0 : 0.0;
            Print("║ Margin Required            : $", DoubleToString(margin_required, 2), " (", DoubleToString(margin_usage, 1), "% of free)              ║");
         }
      }
      
      Print("╠═════════════════════════════════════════════════════════════════════════════╣");
      
      // Decisão final
      if (entrada_valida) {
         Print("║                                                                             ║");
         Print("║                     🎯 DECISÃO: ENTRADA AUTORIZADA 🎯                      ║");
         Print("║                                                                             ║");
         string entry_ema = "INDEFINIDA";
         if (pullback_ema9_ok && _pullback_ema9_m3.validation_result) {
            entry_ema = "EMA9";
         } else if (pullback_ema21_ok && _pullback_ema21_m3.validation_result) {
            entry_ema = "EMA21";
         }
         Print("║ Setup de Entrada           : Pullback em ", entry_ema, " (M3)                            ║");
         Print("║ Qualidade do Sinal         : ALTA                                          ║");
      } else {
         Print("║                                                                             ║");
         Print("║                      ⛔ DECISÃO: ENTRADA NEGADA ⛔                         ║");
         Print("║                                                                             ║");
         
         // Identificar motivo da rejeição
         string rejection_reason = "INDEFINIDO";
         if (!filtros_ok) {
            rejection_reason = "FILTROS DE CONTEXTO NÃO APROVADOS";
            
            // Detalhar qual filtro falhou
            if (!ema_alignment_m15_ok) rejection_reason = "Alinhamento EMAs M15";
            else if (!ema_alignment_m3_ok) rejection_reason = "Alinhamento EMAs M3";
            else if (!strong_trend_m15) rejection_reason = "Tendência Forte M15";
            else if (!strong_trend_m3) rejection_reason = "Tendência Forte M3";
            else if (!bullish_momentum) rejection_reason = "Momentum Bullish";
            else if (!good_volatility) rejection_reason = "Volatilidade";
            else if (!bullish_structure_m15) rejection_reason = "Estrutura Bullish M15";
            else if (!bullish_structure_m3) rejection_reason = "Estrutura Bullish M3";
            else if (!strong_trend_adx) rejection_reason = "ADX Filter";
            else if (!is_bollinger_valid_m3) rejection_reason = "Bollinger M3";
            else if (!is_bollinger_valid_m15) rejection_reason = "Bollinger M15";
            else if (!is_bollinger_valid_h1) rejection_reason = "Bollinger H1";
         } else if (!entrada_setup_ok) {
            rejection_reason = "NENHUM PULLBACK VÁLIDO DETECTADO";
         }
         
         Print("║ Motivo da Rejeição         : ", rejection_reason, "                     ║");
      }
      
      Print("╚═════════════════════════════════════════════════════════════════════════════╝");
      Print("");
      
      // NOVO: Informações de tempo
      Print("╔═════════════════════════════════════════════════════════════════════════════╗");
      Print("║ INFORMAÇÕES DE TEMPO                                                        ║");
      Print("╠═════════════════════════════════════════════════════════════════════════════╣");
      Print("║ Timestamp                  : ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS), "                          ║");
      
      // Verificar horário de operação
      bool within_hours = m_config.IsWithinOperatingHours();
      Print("║ Horário de Operação        : ", within_hours ? "✅ DENTRO DO HORÁRIO" : "✗ FORA DO HORÁRIO", "                              ║");
      
      Print("╚═════════════════════════════════════════════════════════════════════════════╝");
      
      Print("");
      Print("================================================================================");
      Print("========================== END OF DEBUG LOG ===================================");
      Print("================================================================================");
   }
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

void CEmasBuyBull::ConfigureOrderSettings(SOrderManagerSettings &settings)
{
   CStrategyBase::ConfigureOrderSettings(settings);

   string symbol = (m_current_symbol != "") ? m_current_symbol : m_symbol;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double pip_factor = (digits == 3 || digits == 5) ? 10.0 : 1.0;

   settings.risk_percent = m_config.risk_percent;
   settings.min_stop_loss_points = MathMax(10.0, m_config.stop_loss_pips * pip_factor);
   settings.max_stop_loss_points = settings.min_stop_loss_points * 4.0;
   settings.break_even_trigger_points = settings.min_stop_loss_points;
   settings.break_even_offset_points = pip_factor * 5.0;
   settings.enable_break_even = true;
   settings.enable_trailing_stop = true;
   settings.atr_period = 14;
   settings.atr_multiplier = 2.0;
   settings.atr_timeframe = PERIOD_M15;
   settings.enable_partial_closes = true;
   settings.max_total_risk_percent = MathMax(settings.risk_percent * 3.0, settings.risk_percent + 1.0);
   settings.minimum_partial_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

   ArrayResize(settings.partial_close_levels_points, 2);
   ArrayResize(settings.partial_close_percents, 2);
   settings.partial_close_levels_points[0] = settings.min_stop_loss_points;
   settings.partial_close_levels_points[1] = settings.min_stop_loss_points * 2.0;
   settings.partial_close_percents[0] = 0.5;
   settings.partial_close_percents[1] = 0.25;
}

#endif
