//+------------------------------------------------------------------+
//|                                                       PA_WIN.mq5 |
//|                                                   Copyright 2025 |
//|                                                 https://mql5.com |
//| 22.06.2025 - Updated with ConfigManager                          |
//+------------------------------------------------------------------+

#property copyright "Copyright 2025"
#property link "https://mql5.com"
#property version "2.00"

#include "CONFIG_MANAGER/config_manager.mqh"
#include "PROVIDER/provider.mqh"

// Gerenciador de configuração
CConfigManager *g_config_manager;

// Parâmetros de entrada
input string JsonConfigFile = "config.json"; // Nome do arquivo JSON

// Variáveis para controle de novo candle
datetime m_last_bar_time;     // Tempo do último candle processado
ENUM_TIMEFRAMES m_control_tf; // TimeFrame para controle de novo candle

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Inicializar socket
   FrancisSocketInit();

   // Criar gerenciador de configuração
   g_config_manager = new CConfigManager();
   if (g_config_manager == NULL)
   {
      Print("ERRO: Falha ao criar ConfigManager");
      return INIT_FAILED;
   }

   // Inicializar com configuração escolhida
   bool init_success = false;

   Print("Tentando carregar arquivo JSON: ", JsonConfigFile);
   init_success = g_config_manager.InitFromFile(JsonConfigFile);

   if (!init_success)
   {
      Print("ERRO: Falha ao inicializar ConfigManager");
      delete g_config_manager;
      g_config_manager = NULL;
      return INIT_FAILED;
   }

   // Inicializar controle de novo candle com D1
   m_control_tf = PERIOD_CURRENT;
   m_last_bar_time = 0; // Forçar execução no primeiro tick

   Print("ConfigManager inicializado com sucesso");

   // Listar contextos criados
   string symbols[];
   g_config_manager.GetConfiguredSymbols(symbols);
   for (int i = 0; i < ArraySize(symbols); i++)
   {
      Print("Símbolo configurado: ", symbols[i]);
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== INICIANDO DEINICIALIZAÇÃO ===");
   Print("Motivo: ", reason);

   // Limpar gerenciador de configuração
   if (g_config_manager != NULL)
   {
      Print("Limpando ConfigManager...");
      delete g_config_manager;
      g_config_manager = NULL;
   }

   // Garantir limpeza final do singleton
   CIndicatorFactory::Cleanup();
   FrancisSocketCleanup();

   // Pequena pausa e limpeza adicional se necessário
   if (reason == REASON_REMOVE || reason == REASON_CHARTCHANGE || reason == REASON_PARAMETERS)
   {
      Sleep(200); // Pausa para garantir que tudo foi processado

      ObjectsDeleteAll(0, 0); // remove todos os objetos da janela principal

      // Limpeza forçada final se ainda houverem indicadores
      int total_remaining = 0;
      for (int window = 0; window <= 10; window++)
      {
         total_remaining += ChartIndicatorsTotal(0, window);
      }

      if (total_remaining > 0)
      {
         Print("AVISO: ", total_remaining, " indicadores ainda presentes. Executando limpeza final...");

         for (int window = 0; window <= 10; window++)
         {
            int total = ChartIndicatorsTotal(0, window);
            for (int i = total - 1; i >= 0; i--)
            {
               string name = ChartIndicatorName(0, window, i);
               Print("Indicator Name = " + name);
               ChartIndicatorDelete(0, window, name);
            }
         }
         ChartRedraw(0);
      }
   }

   Print("=== DEINICIALIZAÇÃO CONCLUÍDA ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{

   // Verificar se o gerenciador está inicializado
   if (g_config_manager == NULL || !g_config_manager.IsInitialized())
   {
      Print("ERRO: ConfigManager não está inicializado");
      return;
   }

   // Executar lógica apenas em novos candles
   ExecuteOnNewBar();
}

//+------------------------------------------------------------------+
//| Verificar se há um novo candle no timeframe especificado        |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES timeframe)
{
   datetime current_bar_time = iTime(Symbol(), timeframe, 0);

   // Se é a primeira execução ou se o tempo do candle atual é diferente do último
   if (m_last_bar_time != current_bar_time)
   {
      m_last_bar_time = current_bar_time;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Verificar se a tendência está forte baseada na distância entre médias |
//+------------------------------------------------------------------+
bool IsStrongTrend(TF_CTX* ctx, double min_distance_9_21_atr = 0.3, double min_distance_21_50_atr = 0.5)
{
   if (ctx == NULL) return false;
   
   CMovingAverages *ema9 = ctx.GetIndicator("ema9");
   CMovingAverages *ema21 = ctx.GetIndicator("ema21");
   CMovingAverages *ema50 = ctx.GetIndicator("ema50");
   CATR *atr = ctx.GetIndicator("ATR15");
   
   if (ema9 == NULL || ema21 == NULL || ema50 == NULL || atr == NULL)
   {
      return false;
   }
   
   double ema9_val = ema9.GetValue(1);
   double ema21_val = ema21.GetValue(1);
   double ema50_val = ema50.GetValue(1);
   double atr_val = atr.GetValue(1);
   
   if (atr_val <= 0) return false;
   
   // Calcular distâncias em termos de ATR
   double dist_9_21 = MathAbs(ema9_val - ema21_val) / atr_val;
   double dist_21_50 = MathAbs(ema21_val - ema50_val) / atr_val;
   
   bool strong_trend = (dist_9_21 >= min_distance_9_21_atr && dist_21_50 >= min_distance_21_50_atr);
   
   return strong_trend;
}

//+------------------------------------------------------------------+
//| Verificar momentum bullish através de price action              |
//+------------------------------------------------------------------+
bool HasBullishMomentum(TF_CTX* ctx_m15, TF_CTX* ctx_m3, int lookback_candles = 3)
{
   if (ctx_m15 == NULL || ctx_m3 == NULL) return false;
   
   CMovingAverages *ema21_m15 = ctx_m15.GetIndicator("ema21");
   if (ema21_m15 == NULL) return false;
   
   string symbol = Symbol();
   
   // 1. Verificar se o preço está consistentemente acima da EMA21 no M15
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
   
   // 2. Verificar se não há candles com sombra inferior muito grande (panic selling)
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
   
   // 3. Verificar se o último candle mostra força
   double last_open = iOpen(symbol, PERIOD_M3, 1);
   double last_close = iClose(symbol, PERIOD_M3, 1);
   bool last_candle_bullish = (last_close >= last_open);
   
   return price_above_ema21 && no_panic_selling && last_candle_bullish;
}

//+------------------------------------------------------------------+
//| Verificar momentum bearish através de price action              |
//+------------------------------------------------------------------+
bool HasBearishMomentum(TF_CTX* ctx_m15, TF_CTX* ctx_m3, int lookback_candles = 3)
{
   if (ctx_m15 == NULL || ctx_m3 == NULL) return false;
   
   CMovingAverages *ema21_m15 = ctx_m15.GetIndicator("ema21");
   if (ema21_m15 == NULL) return false;
   
   string symbol = Symbol();
   
   // 1. Verificar se o preço está consistentemente abaixo da EMA21 no M15
   int candles_below_ema21 = 0;
   for (int i = 1; i <= lookback_candles; i++)
   {
      double close = iClose(symbol, PERIOD_M15, i);
      double ema21_val = ema21_m15.GetValue(i);
      if (close < ema21_val)
      {
         candles_below_ema21++;
      }
   }
   bool price_below_ema21 = (candles_below_ema21 >= 2);
   
   // 2. Verificar se não há candles com sombra superior muito grande (panic buying)
   bool no_panic_buying = true;
   for (int i = 1; i <= 2; i++)
   {
      double open = iOpen(symbol, PERIOD_M3, i);
      double close = iClose(symbol, PERIOD_M3, i);
      double low = iLow(symbol, PERIOD_M3, i);
      double high = iHigh(symbol, PERIOD_M3, i);
      
      double body_size = MathAbs(close - open);
      double upper_shadow = high - MathMax(open, close);
      double candle_range = high - low;
      
      if (candle_range > 0)
      {
         double upper_shadow_ratio = upper_shadow / candle_range;
         if (upper_shadow_ratio > 0.6)
         {
            no_panic_buying = false;
            break;
         }
      }
   }
   
   // 3. Verificar se o último candle mostra força bearish
   double last_open = iOpen(symbol, PERIOD_M3, 1);
   double last_close = iClose(symbol, PERIOD_M3, 1);
   bool last_candle_bearish = (last_close <= last_open);
   
   return price_below_ema21 && no_panic_buying && last_candle_bearish;
}

//+------------------------------------------------------------------+
//| Compra em alta                                                   |
//+------------------------------------------------------------------+
bool CompraAlta(string symbol)
{

   TF_CTX *ctx_m15 = g_config_manager.GetContext(symbol, PERIOD_M15);
   TF_CTX *ctx_m3 = g_config_manager.GetContext(symbol, PERIOD_M3);

   // if (g_config_manager.IsContextEnabled(symbol, PERIOD_M3) || g_config_manager.IsContextEnabled(symbol, PERIOD_M15))
   // {
   //    Print("ERRO: Contextos M15 ou M3 são nulos em CompraAlta");
   //    return false;
   // }

   if (ctx_m15 == NULL || ctx_m3 == NULL)
   {
      Print(" ========== BERGAMOTAS");
   }

   // === ALINHAMENTO DE MÉDIAS EMA em M15 ===
   CMovingAverages *ema9_m15 = ctx_m15.GetIndicator("ema9");
   CMovingAverages *ema21_m15 = ctx_m15.GetIndicator("ema21");
   CMovingAverages *ema50_m15 = ctx_m15.GetIndicator("ema50");

   if (ema9_m15 == NULL || ema21_m15 == NULL || ema50_m15 == NULL)
   {
      Print("AVISO: Indicadores EMA não encontrados em M15 para CompraAlta");
      return false;
   }

   // Verificar alinhamento EMA9 > EMA21 > EMA50 em M15
   double ema9_value_m15 = ema9_m15.GetValue(1);
   double ema21_value_m15 = ema21_m15.GetValue(1);
   double ema50_value_m15 = ema50_m15.GetValue(1);

   bool EMA9_above_EMA21_M15 = (ema9_value_m15 > ema21_value_m15);
   bool EMA21_above_EMA50_M15 = (ema21_value_m15 > ema50_value_m15);

   if (!EMA9_above_EMA21_M15 || !EMA21_above_EMA50_M15)
   {
      return false; // Não há alinhamento de alta em M15
   }

   // === ALINHAMENTO DE MÉDIAS EMA em M3 ===
   CMovingAverages *ema9_m3 = ctx_m3.GetIndicator("ema9");
   CMovingAverages *ema21_m3 = ctx_m3.GetIndicator("ema21");
   CMovingAverages *ema50_m3 = ctx_m3.GetIndicator("ema50");

   if (ema9_m3 == NULL || ema21_m3 == NULL || ema50_m3 == NULL)
   {
      Print("AVISO: Indicadores EMA não encontrados em M3 para CompraAlta");
      return false;
   }

   // Verificar alinhamento EMA9 > EMA21 > EMA50 em M3
   double ema9_value_m3 = ema9_m3.GetValue(1);
   double ema21_value_m3 = ema21_m3.GetValue(1);
   double ema50_value_m3 = ema50_m3.GetValue(1);

   bool EMA9_above_EMA21_M3 = (ema9_value_m3 > ema21_value_m3);
   bool EMA21_above_EMA50_M3 = (ema21_value_m3 > ema50_value_m3);

   if (!EMA9_above_EMA21_M3 || !EMA21_above_EMA50_M3)
   {
      return false; // Não há alinhamento de alta em M3
   }

   // === FILTRO DE FORÇA DA TENDÊNCIA ===
   // Verificar se a tendência está forte em M15
   bool strong_trend_m15 = IsStrongTrend(ctx_m15, 0.3, 0.5);
   if (!strong_trend_m15)
   {
      return false; // Tendência não está forte o suficiente em M15
   }

   // === FILTRO DE MOMENTUM ===
   // Verificar momentum bullish através de price action
   bool bullish_momentum = HasBullishMomentum(ctx_m15, ctx_m3, 3);
   if (!bullish_momentum)
   {
      return false; // Momentum não está favorável para compra
   }

   // === OBTER ATR PARA CÁLCULOS ===
   CATR *atr_m3 = ctx_m3.GetIndicator("ATR15"); // PADRONIZAR NOME ATR
   double atr_value = atr_m3.GetValue(1);

   // === PONTOS DE ENTRADA - USANDO GetPositionInfo  ===

   // 1. Verificar pullback para EMA9 em M3 - preço testando a EMA como suporte
   SPositionInfo ema9_m3_position = ema9_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
   bool price_pullback_EMA9_M3 = (ema9_m3_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
                                  ema9_m3_position.position == INDICATOR_CROSSES_LOWER_BODY ||
                                  ema9_m3_position.position == INDICATOR_CROSSES_CENTER_BODY);

   // 2. Verificar pullback para EMA21 em M3 - preço testando a EMA como suporte
   SPositionInfo ema21_m3_position = ema21_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
   bool price_pullback_EMA21_M3 = (ema21_m3_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
                                   ema21_m3_position.position == INDICATOR_CROSSES_LOWER_BODY ||
                                   ema21_m3_position.position == INDICATOR_CROSSES_CENTER_BODY);

   // 3. Verificar teste de EMA50 como suporte em qualquer timeframe
   bool price_tested_EMA50_as_support = false;
   TF_CTX *contexts[];
   ENUM_TIMEFRAMES tfs[];
   int count = g_config_manager.GetSymbolContexts(symbol, contexts, tfs);

   for (int i = 0; i < count; i++)
   {
      TF_CTX *ctx = contexts[i];
      if (ctx == NULL)
         continue;

      CMovingAverages *ema50 = ctx.GetIndicator("ema50");
      CATR *atr = ctx.GetIndicator("ATR15");

      if (ema50 != NULL && atr != NULL)
      {
         SPositionInfo ema50_position = ema50.GetPositionInfo(1, COPY_MIDDLE, atr.GetValue(1));

         // EMA50 como suporte: candle testou mas não rompeu com distância
         if (ema50_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
             ema50_position.position == INDICATOR_CROSSES_LOWER_BODY ||
             ema50_position.position == INDICATOR_CROSSES_CENTER_BODY)
         {
            price_tested_EMA50_as_support = true;
            // Print("EMA50 testada como suporte em ", EnumToString(tfs[i]),
            //       " - Posição: ", ema50_position.position);
            break;
         }
      }
   }

   // 4. Verificar teste de SMA200 como suporte em qualquer timeframe
   bool price_tested_SMA200_as_support = false;
   for (int i = 0; i < count; i++)
   {
      TF_CTX *ctx = contexts[i];
      if (ctx == NULL)
         continue;

      CMovingAverages *sma200 = ctx.GetIndicator("sma200");
      CATR *atr = ctx.GetIndicator("ATR15");

      if (sma200 != NULL && atr != NULL)
      {
         SPositionInfo sma200_position = sma200.GetPositionInfo(1, COPY_MIDDLE, atr.GetValue(1));

         // SMA200 como suporte: candle testou mas não rompeu com distância
         if (sma200_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
             sma200_position.position == INDICATOR_CROSSES_LOWER_BODY ||
             sma200_position.position == INDICATOR_CROSSES_CENTER_BODY)
         {
            price_tested_SMA200_as_support = true;
            // Print("SMA200 testada como suporte em ", EnumToString(tfs[i]),
            //       " - Posição: ", sma200_position.position);
            break;
         }
      }
   }

   // === CONDIÇÕES FINAIS PARA COMPRA ===
   // bool entrada_valida = ((price_pullback_EMA9_M3 || price_pullback_EMA21_M3) &&
   //                        (price_tested_EMA50_as_support || price_tested_SMA200_as_support));
    

   SSlopeValidation ema50_m3_slope = ema50_m3.GetSlopeValidation(atr_m3.GetValue(1), COPY_MIDDLE);

   bool is_ema50_m3_trend_up = ema50_m3_slope.linear_regression.trend_direction == "ALTA" &&
                               ema50_m3_slope.discrete_derivative.trend_direction == "ALTA" &&
                               ema50_m3_slope.simple_difference.trend_direction == "ALTA";

   CATR *atr_m15 = ctx_m15.GetIndicator("ATR15");
   SSlopeValidation ema50_m15_slope = ema50_m15.GetSlopeValidation(atr_m15.GetValue(1), COPY_MIDDLE);

   bool is_ema50_m15_trend_up = ema50_m15_slope.linear_regression.trend_direction == "ALTA" &&
                                ema50_m15_slope.discrete_derivative.trend_direction == "ALTA" &&
                                ema50_m15_slope.simple_difference.trend_direction == "ALTA";

   bool entrada_valida = (price_pullback_EMA9_M3 || price_pullback_EMA21_M3);

   if (entrada_valida)
   {
      if (FrancisSocketExists())
      {
         FrancisSocketSendStatus("COMPRA", "COMPRE MERMO", symbol);
      }

      Print("=== SINAL DE COMPRA ALTA DETECTADO ===");
      Print("Símbolo: ", symbol);
      Print("EMA9 M15: ", DoubleToString(ema9_value_m15, _Digits),
            " | EMA21 M15: ", DoubleToString(ema21_value_m15, _Digits),
            " | EMA50 M15: ", DoubleToString(ema50_value_m15, _Digits));
      Print("EMA9 M3: ", DoubleToString(ema9_value_m3, _Digits),
            " | EMA21 M3: ", DoubleToString(ema21_value_m3, _Digits),
            " | EMA50 M3: ", DoubleToString(ema50_value_m3, _Digits));
      Print("ATR M3: ", DoubleToString(atr_value, _Digits));
      Print("---");
      Print("Alinhamento M15 - EMA9>EMA21: ", EMA9_above_EMA21_M15 ? "✓" : "✗",
            " | EMA21>EMA50: ", EMA21_above_EMA50_M15 ? "✓" : "✗");
      Print("Alinhamento M3 - EMA9>EMA21: ", EMA9_above_EMA21_M3 ? "✓" : "✗",
            " | EMA21>EMA50: ", EMA21_above_EMA50_M3 ? "✓" : "✗");
      Print("Força da Tendência M15: ", strong_trend_m15 ? "✓" : "✗");
      Print("Momentum Bullish: ", bullish_momentum ? "✓" : "✗");
      Print("---");
      Print("Posição EMA9 M3: ", ema9_m3_position.position,
            " | Pullback EMA9: ", price_pullback_EMA9_M3 ? "✓" : "✗");
      Print("Posição EMA21 M3: ", ema21_m3_position.position,
            " | Pullback EMA21: ", price_pullback_EMA21_M3 ? "✓" : "✗");
      Print("Teste EMA50 suporte: ", price_tested_EMA50_as_support ? "✓" : "✗");
      Print("Teste SMA200 suporte: ", price_tested_SMA200_as_support ? "✓" : "✗");
      Print("---");
      Print("EMA 50 M3 SLOPES");
      Print(" | Linear: ", ema50_m3_slope.linear_regression.trend_direction);
      Print(" | Simple: ", ema50_m3_slope.simple_difference.trend_direction);
      Print(" | Derivative: ", ema50_m3_slope.discrete_derivative.trend_direction);
      Print("---");
      Print("EMA 50 M15 SLOPES");
      Print(" | Linear: ", ema50_m15_slope.linear_regression.trend_direction);
      Print(" | Simple: ", ema50_m15_slope.simple_difference.trend_direction);
      Print(" | Derivative: ", ema50_m15_slope.discrete_derivative.trend_direction);
      Print("====================================");
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Venda em baixa                                                   |
//+------------------------------------------------------------------+
bool VendaBaixa(string symbol)
{
   TF_CTX *ctx_m15 = g_config_manager.GetContext(symbol, PERIOD_M15);
   TF_CTX *ctx_m3 = g_config_manager.GetContext(symbol, PERIOD_M3);

   if (ctx_m15 == NULL || ctx_m3 == NULL)
   {
      Print("ERRO: Contextos M15 ou M3 são nulos em VendaBaixa");
      return false;
   }

   // === ALINHAMENTO DE MÉDIAS EMA em M15 ===
   CMovingAverages *ema9_m15 = ctx_m15.GetIndicator("ema9");
   CMovingAverages *ema21_m15 = ctx_m15.GetIndicator("ema21");
   CMovingAverages *ema50_m15 = ctx_m15.GetIndicator("ema50");

   if (ema9_m15 == NULL || ema21_m15 == NULL || ema50_m15 == NULL)
   {
      Print("AVISO: Indicadores EMA não encontrados em M15 para VendaBaixa");
      return false;
   }

   // Verificar alinhamento EMA9 < EMA21 < EMA50 em M15
   double ema9_value_m15 = ema9_m15.GetValue(1);
   double ema21_value_m15 = ema21_m15.GetValue(1);
   double ema50_value_m15 = ema50_m15.GetValue(1);

   bool EMA9_below_EMA21_M15 = (ema9_value_m15 < ema21_value_m15);
   bool EMA21_below_EMA50_M15 = (ema21_value_m15 < ema50_value_m15);

   if (!EMA9_below_EMA21_M15 || !EMA21_below_EMA50_M15)
   {
      return false; // Não há alinhamento de baixa em M15
   }

   // === ALINHAMENTO DE MÉDIAS EMA em M3 ===
   CMovingAverages *ema9_m3 = ctx_m3.GetIndicator("ema9");
   CMovingAverages *ema21_m3 = ctx_m3.GetIndicator("ema21");
   CMovingAverages *ema50_m3 = ctx_m3.GetIndicator("ema50");

   if (ema9_m3 == NULL || ema21_m3 == NULL || ema50_m3 == NULL)
   {
      Print("AVISO: Indicadores EMA não encontrados em M3 para VendaBaixa");
      return false;
   }

   // Verificar alinhamento EMA9 < EMA21 < EMA50 em M3
   double ema9_value_m3 = ema9_m3.GetValue(1);
   double ema21_value_m3 = ema21_m3.GetValue(1);
   double ema50_value_m3 = ema50_m3.GetValue(1);

   bool EMA9_below_EMA21_M3 = (ema9_value_m3 < ema21_value_m3);
   bool EMA21_below_EMA50_M3 = (ema21_value_m3 < ema50_value_m3);

   if (!EMA9_below_EMA21_M3 || !EMA21_below_EMA50_M3)
   {
      return false; // Não há alinhamento de baixa em M3
   }

   // === FILTRO DE FORÇA DA TENDÊNCIA ===
   // Verificar se a tendência está forte em M15
   bool strong_trend_m15 = IsStrongTrend(ctx_m15, 0.3, 0.5);
   if (!strong_trend_m15)
   {
      return false; // Tendência não está forte o suficiente em M15
   }

   // === FILTRO DE MOMENTUM ===
   // Verificar momentum bearish através de price action
   bool bearish_momentum = HasBearishMomentum(ctx_m15, ctx_m3, 3);
   if (!bearish_momentum)
   {
      return false; // Momentum não está favorável para venda
   }

   // === OBTER ATR PARA CÁLCULOS ===
   CATR *atr_m3 = ctx_m3.GetIndicator("ATR15"); // PADRONIZAR NOME ATR
   double atr_value = atr_m3.GetValue(1);

   // === PONTOS DE ENTRADA - USANDO GetPositionInfo  ===

   // 1. Verificar pullback para EMA9 em M3 - preço testando a EMA como resistência
   SPositionInfo ema9_m3_position = ema9_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
   bool price_pullback_EMA9_M3 = (ema9_m3_position.position == INDICATOR_CROSSES_UPPER_SHADOW ||
                                  ema9_m3_position.position == INDICATOR_CROSSES_UPPER_BODY ||
                                  ema9_m3_position.position == INDICATOR_CROSSES_CENTER_BODY);

   // 2. Verificar pullback para EMA21 em M3 - preço testando a EMA como resistência
   SPositionInfo ema21_m3_position = ema21_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
   bool price_pullback_EMA21_M3 = (ema21_m3_position.position == INDICATOR_CROSSES_UPPER_SHADOW ||
                                   ema21_m3_position.position == INDICATOR_CROSSES_UPPER_BODY ||
                                   ema21_m3_position.position == INDICATOR_CROSSES_CENTER_BODY);

   // 3. Verificar teste de EMA50 como resistência em qualquer timeframe
   bool price_tested_EMA50_as_resistance = false;
   TF_CTX *contexts[];
   ENUM_TIMEFRAMES tfs[];
   int count = g_config_manager.GetSymbolContexts(symbol, contexts, tfs);

   for (int i = 0; i < count; i++)
   {
      TF_CTX *ctx = contexts[i];
      if (ctx == NULL)
         continue;

      CMovingAverages *ema50 = ctx.GetIndicator("ema50");
      CATR *atr = ctx.GetIndicator("ATR15");

      if (ema50 != NULL && atr != NULL)
      {
         SPositionInfo ema50_position = ema50.GetPositionInfo(1, COPY_MIDDLE, atr.GetValue(1));

         // EMA50 como resistência: candle testou mas não rompeu com distância
         if (ema50_position.position == INDICATOR_CROSSES_UPPER_SHADOW ||
             ema50_position.position == INDICATOR_CROSSES_UPPER_BODY ||
             ema50_position.position == INDICATOR_CROSSES_CENTER_BODY ||
             ema50_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
             ema50_position.position == INDICATOR_CROSSES_LOWER_BODY)
         {
            price_tested_EMA50_as_resistance = true;
            // Print("EMA50 testada como resistência em ", EnumToString(tfs[i]),
            //       " - Posição: ", ema50_position.position);
            break;
         }
      }
   }

   // 4. Verificar teste de SMA200 como resistência em qualquer timeframe
   bool price_tested_SMA200_as_resistance = false;
   for (int i = 0; i < count; i++)
   {
      TF_CTX *ctx = contexts[i];
      if (ctx == NULL)
         continue;

      CMovingAverages *sma200 = ctx.GetIndicator("sma200");
      CATR *atr = ctx.GetIndicator("ATR15");

      if (sma200 != NULL && atr != NULL)
      {
         SPositionInfo sma200_position = sma200.GetPositionInfo(1, COPY_MIDDLE, atr.GetValue(1));

         // SMA200 como resistência: candle testou mas não rompeu com distância
         if (sma200_position.position == INDICATOR_CROSSES_UPPER_SHADOW ||
             sma200_position.position == INDICATOR_CROSSES_UPPER_BODY ||
             sma200_position.position == INDICATOR_CROSSES_CENTER_BODY ||
             sma200_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
             sma200_position.position == INDICATOR_CROSSES_LOWER_BODY)
         {
            price_tested_SMA200_as_resistance = true;
            // Print("SMA200 testada como resistência em ", EnumToString(tfs[i]),
            //       " - Posição: ", sma200_position.position);
            break;
         }
      }
   }

   // === CONDIÇÕES FINAIS PARA VENDA ===
   bool entrada_valida = ((price_pullback_EMA9_M3 || price_pullback_EMA21_M3) &&
                          (price_tested_EMA50_as_resistance || price_tested_SMA200_as_resistance));

   if (entrada_valida)
   {
      Print("=== SINAL DE VENDA BAIXA DETECTADO ===");
      Print("Símbolo: ", symbol);
      Print("EMA9 M15: ", DoubleToString(ema9_value_m15, _Digits),
            " | EMA21 M15: ", DoubleToString(ema21_value_m15, _Digits),
            " | EMA50 M15: ", DoubleToString(ema50_value_m15, _Digits));
      Print("EMA9 M3: ", DoubleToString(ema9_value_m3, _Digits),
            " | EMA21 M3: ", DoubleToString(ema21_value_m3, _Digits),
            " | EMA50 M3: ", DoubleToString(ema50_value_m3, _Digits));
      Print("ATR M3: ", DoubleToString(atr_value, _Digits));
      Print("---");
      Print("Alinhamento M15 - EMA9<EMA21: ", EMA9_below_EMA21_M15 ? "✓" : "✗",
            " | EMA21<EMA50: ", EMA21_below_EMA50_M15 ? "✓" : "✗");
      Print("Alinhamento M3 - EMA9<EMA21: ", EMA9_below_EMA21_M3 ? "✓" : "✗",
            " | EMA21<EMA50: ", EMA21_below_EMA50_M3 ? "✓" : "✗");
      Print("Força da Tendência M15: ", strong_trend_m15 ? "✓" : "✗");
      Print("Momentum Bearish: ", bearish_momentum ? "✓" : "✗");
      Print("---");
      Print("Posição EMA9 M3: ", ema9_m3_position.position,
            " | Pullback EMA9: ", price_pullback_EMA9_M3 ? "✓" : "✗");
      Print("Posição EMA21 M3: ", ema21_m3_position.position,
            " | Pullback EMA21: ", price_pullback_EMA21_M3 ? "✓" : "✗");
      Print("Teste EMA50 resistência: ", price_tested_EMA50_as_resistance ? "✓" : "✗");
      Print("Teste SMA200 resistência: ", price_tested_SMA200_as_resistance ? "✓" : "✗");
      Print("====================================");
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Atualizar todos os contextos de um símbolo                       |
//+------------------------------------------------------------------+
void UpdateSymbolContexts(string symbol)
{
   TF_CTX *contexts[];
   ENUM_TIMEFRAMES tfs[];
   int count = g_config_manager.GetSymbolContexts(symbol, contexts, tfs);
   if (count == 0)
   {
      Print("AVISO: Nenhum contexto encontrado para símbolo: ", symbol);
      return;
   }

   // loop the atualização de contextos
   for (int i = 0; i < count; i++)
   {
      TF_CTX *ctx = contexts[i];
      ENUM_TIMEFRAMES tf = tfs[i];
      if (ctx == NULL)
         continue;

      if (ctx.HasNewBar())
      {
         ctx.Update();
         // CheckSlopePosM15(tf, ctx);
         // Check_SR(tf, ctx);

         // Check de condições
         if (ctx.GetTimeFrame() == PERIOD_M3)
         {
            bool is_compra = CompraAlta(symbol);
         }
      }
   } // Fim loop the atualização de contextos
}

//+------------------------------------------------------------------+
//| Executar lógica apenas em novo candle                           |
//+------------------------------------------------------------------+
void ExecuteOnNewBar()
{
   string symbols[];
   g_config_manager.GetConfiguredSymbols(symbols);

   for (int i = 0; i < ArraySize(symbols); i++)
   {
      UpdateSymbolContexts(symbols[i]);
   }
}

//+------------------------------------------------------------------+
//| Método para alterar o timeframe de controle                     |

//+------------------------------------------------------------------+
void SetControlTimeframe(ENUM_TIMEFRAMES new_timeframe)
{
   m_control_tf = new_timeframe;
   m_last_bar_time = 0; // Reset para forçar execução no próximo tick
   Print("Timeframe de controle alterado para: ", EnumToString(m_control_tf));
}

//+------------------------------------------------------------------+
//| Método para recarregar configuração (útil para desenvolvimento) |
//+------------------------------------------------------------------+
bool ReloadConfig()
{
   if (g_config_manager == NULL)
      return false;

   // Limpar configuração atual
   g_config_manager.Cleanup();

   // Recarregar
   bool success = false;

   success = g_config_manager.InitFromFile(JsonConfigFile);

   if (success)
   {
      Print("Configuração recarregada com sucesso");
   }
   else
   {
      Print("ERRO: Falha ao recarregar configuração");
   }

   return success;
}

//+------------------------------------------------------------------+
//| TesterDeinit function                                            |
//+------------------------------------------------------------------+
void OnTesterDeinit()
{
   //---
}