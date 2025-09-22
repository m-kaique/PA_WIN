//+------------------------------------------------------------------+
//|                                                       PA_WIN.mq5 |
//|                                                   Copyright 2025 |
//|                                                 https://mql5.com |
//| 22.06.2025 - Updated with ConfigManager                          |
//+------------------------------------------------------------------+

#property copyright "Copyright 2025"
#property link "https://mql5.com"
#property version "2.00"

#include "config_manager/config_manager.mqh"
#include "provider/provider.mqh"
#include "utils/tester_qol.mqh"

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
   PersonalizarGrafico();
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

   // Listar contextos de símbolos criados
   Print("=== CONTEXTOS DE SÍMBOLOS CRIADOS ===");
   string symbols[];
   g_config_manager.GetConfiguredSymbols(symbols);
   for (int i = 0; i < ArraySize(symbols); i++)
   {
      Print("Símbolo configurado: ", symbols[i]);

      // Listar timeframes para cada símbolo
      TF_CTX *contexts[];
      ENUM_TIMEFRAMES timeframes[];
      int count = g_config_manager.GetSymbolContexts(symbols[i], contexts, timeframes);

      for (int j = 0; j < count; j++)
      {
         if (contexts[j] != NULL)
         {
            Print("  - TimeFrame: ", EnumToString(timeframes[j]));
         }
      }
   }

   // Listar contextos de estratégias criados
   Print("=== CONTEXTOS DE ESTRATÉGIAS CRIADOS ===");
   string strategy_setups[];
   g_config_manager.GetConfiguredStrategySetups(strategy_setups);

   if (ArraySize(strategy_setups) == 0)
   {
      Print("Nenhum setup de estratégia configurado ou ativo");
   }
   else
   {
      for (int i = 0; i < ArraySize(strategy_setups); i++)
      {
         Print("Setup configurado: ", strategy_setups[i]);

         // Obter contexto específico e listar estratégias
         STRATEGY_CTX *strategy_ctx = g_config_manager.GetStrategyContext(strategy_setups[i]);
         if (strategy_ctx != NULL)
         {
            Print("  - Total de estratégias: ", strategy_ctx.GetStrategyCount());

            // Listar nomes das estratégias
            string strategy_names[];
            // strategy_ctx.GetStrategyNames(strategy_names);
            for (int j = 0; j < ArraySize(strategy_names); j++)
            {
               Print("    * Estratégia: ", strategy_names[j]);
            }
         }
         else
         {
            Print("  - ERRO: Contexto não encontrado para setup: ", strategy_setups[i]);
         }
      }
   }

   // Obter todos os contextos de estratégia de uma vez (método alternativo)
   Print("=== VERIFICAÇÃO ADICIONAL DE ESTRATÉGIAS ===");
   STRATEGY_CTX *all_strategy_contexts[];
   string all_setup_names[];
   int total_strategy_contexts = g_config_manager.GetStrategyContexts(all_strategy_contexts, all_setup_names);

   Print("Total de contextos de estratégia ativos: ", total_strategy_contexts);
   for (int i = 0; i < total_strategy_contexts; i++)
   {
      if (all_strategy_contexts[i] != NULL)
      {
         Print("Contexto ", i, ": Setup '", all_setup_names[i], "' - ",
               all_strategy_contexts[i].GetStrategyCount(), " estratégias ativas");
      }
   }

   Print("=== INICIALIZAÇÃO CONCLUÍDA ===");
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
         boll_m3_status(symbol, tf);

         // Loop Pelos Contextos de Estratégias e chama CheckForSignal
         STRATEGY_CTX *strategy_contexts[];
         string setup_names[];
         int strategy_count = g_config_manager.GetStrategyContexts(strategy_contexts, setup_names);

         for (int j = 0; j < strategy_count; j++)
         {
            if (strategy_contexts[j] != NULL)
            {
               // strategy_contexts[j].Update(symbol, tf); // This calls CheckForSignal internally and passes the symbol and timeframe
               // //
               // CEmasBuyBull *strategy = strategy_contexts[j].GetStrategy("m15_m3_emas_buy_bull");
               // Print("INICIO DO LOG ######################################################################");
               // Print("INICIO DO LOG ######################################################################");
               // Print("INICIO DO LOG ######################################################################");
               //strategy.PrintFullDebugLog();
               // Print("FIM DO LOG #########################################################################");
               // Print("FIM DO LOG #########################################################################");
               // Print("FIM DO LOG #########################################################################");

               // if (strategy != NULL)
               // {
               //    ENUM_STRATEGY_STATE state = strategy.GetState();
               //    if (state != STRATEGY_IDLE)
               //    {
               //       strategy.SetState(STRATEGY_IDLE);
               //    }
               // }
            }
         }
      }
   } // Fim loop the atualização de contextos
}

void boll_m3_status(string symbol, ENUM_TIMEFRAMES tf)
{
    // === VALIDAÇÃO PRÉVIA ===
    if (tf != PERIOD_M3)
        return;

    if (g_config_manager == NULL || !g_config_manager.IsInitialized())
    {
        Print("ERRO: ConfigManager não inicializado");
        return;
    }

    // === OBTENÇÃO DO CONTEXTO ===
    TF_CTX *ctx = g_config_manager.GetContext(symbol, PERIOD_M3);
    if (ctx == NULL)
    {
        Print("ERRO: Contexto M3 não encontrado para ", symbol);
        return;
    }

    // === VALIDAÇÃO DE INDICADORES ===
    double atr_value = ctx.GetIndicatorValue("ATR15", 0);
    if (atr_value <= 0)
    {
        Print("WARNING: ATR15 inválido (", DoubleToString(atr_value, 5), "), usando default 0.001");
        atr_value = 0.001;
    }

    CBollinger *bollinger = (CBollinger*)ctx.GetIndicator("boll20");
    if (bollinger == NULL)
    {
        Print("ERRO: Indicador boll20 não encontrado");
        return;
    }

    // === CÁLCULO DO SINAL PRINCIPAL ===
    SCombinedSignal signal = bollinger.ComputeCombinedSignal(atr_value, 9, 0.02);

    // === COLETA DE DADOS BÁSICOS ===
    double upper = bollinger.GetUpper(0);
    double middle = bollinger.GetValue(0);
    double lower = bollinger.GetLower(0);
    double current_price = SymbolInfoDouble(symbol, SYMBOL_LAST);
    double band_width = upper - lower;

    // === VALIDAÇÕES DE SEGURANÇA ===
    if (band_width <= 0 || upper <= 0 || middle <= 0 || lower <= 0)
    {
        Print("ERRO: Valores inválidos das bandas - Width:", DoubleToString(band_width, 2),
              " Upper:", DoubleToString(upper, 2), " Middle:", DoubleToString(middle, 2),
              " Lower:", DoubleToString(lower, 2));
        return;
    }

    // === CÁLCULOS ESTATÍSTICOS ===
    double price_position = ((current_price - lower) / band_width) * 100.0;
    double distance_to_upper = upper - current_price;
    double distance_to_lower = current_price - lower;

    // === ANÁLISE HISTÓRICA ===
    double width_history[20];
    double width_sum = 0.0;
    int valid_widths = 0;

    for (int i = 0; i < 20; i++)
    {
        double u = bollinger.GetUpper(i);
        double l = bollinger.GetLower(i);
        if (u > 0 && l > 0 && u > l)
        {
            width_history[i] = u - l;
            width_sum += width_history[i];
            valid_widths++;
        }
    }

    double avg_width_20 = (valid_widths > 0) ? width_sum / valid_widths : band_width;
    double width_change_pct = (avg_width_20 > 0) ? ((band_width - avg_width_20) / avg_width_20) * 100.0 : 0.0;

    // === ANÁLISE DE SLOPES ===
    SSlopeValidation upper_slope = bollinger.GetSlopeValidation(atr_value, COPY_UPPER);
    SSlopeValidation middle_slope = bollinger.GetSlopeValidation(atr_value, COPY_MIDDLE);
    SSlopeValidation lower_slope = bollinger.GetSlopeValidation(atr_value, COPY_LOWER);

    // === ANÁLISE DE VOLATILIDADE ===
    double width_atr_ratio = band_width / atr_value;
    string volatility_state = "NORMAL";
    if (width_atr_ratio > 5.0) volatility_state = "VERY_HIGH";
    else if (width_atr_ratio > 3.5) volatility_state = "HIGH";
    else if (width_atr_ratio < 1.5) volatility_state = "LOW";
    else if (width_atr_ratio < 1.0) volatility_state = "VERY_LOW";

    // === ANÁLISE DE MERCADO ===
    string market_phase = "NORMAL";
    if (signal.region == WIDTH_VERY_NARROW) market_phase = "SQUEEZE";
    else if (signal.region == WIDTH_NARROW) market_phase = "CONTRACTION";
    else if (signal.region == WIDTH_WIDE) market_phase = "EXPANSION";
    else if (signal.region == WIDTH_VERY_WIDE) market_phase = "HIGH_EXPANSION";

    // === DETECÇÃO DE PADRÕES ===
    bool squeeze_detected = (signal.region == WIDTH_VERY_NARROW);
    bool expansion_detected = (signal.region == WIDTH_VERY_WIDE);
    bool convergence_detected = (upper_slope.linear_regression.slope_value < 0 &&
                                middle_slope.linear_regression.slope_value < 0 &&
                                lower_slope.linear_regression.slope_value < 0);

    // === ANÁLISE DE MOMENTUM ===
    string momentum_state = "NEUTRAL";
    if (signal.slope_state == SLOPE_EXPANDING && signal.confidence > 0.6) momentum_state = "BULLISH";
    else if (signal.slope_state == SLOPE_CONTRACTING && signal.confidence > 0.6) momentum_state = "BEARISH";
    else if (signal.slope_state == SLOPE_STABLE) momentum_state = "SIDEWAYS";

    // === POTENCIAL DE BREAKOUT ===
    string breakout_potential = "LOW";
    if (signal.confidence > 0.8)
    {
        if (price_position < 15 || price_position > 85) breakout_potential = "VERY_HIGH";
        else if (price_position < 25 || price_position > 75) breakout_potential = "HIGH";
        else breakout_potential = "MEDIUM";
    }
    else if (signal.confidence > 0.6)
    {
        if (price_position < 20 || price_position > 80) breakout_potential = "MEDIUM";
        else breakout_potential = "LOW";
    }

    // === ANÁLISE DE RISCO ===
    string risk_level = "MODERATE";
    if (volatility_state == "VERY_HIGH" && breakout_potential == "VERY_HIGH") risk_level = "VERY_HIGH";
    else if (volatility_state == "HIGH" || breakout_potential == "HIGH") risk_level = "HIGH";
    else if (volatility_state == "LOW" && breakout_potential == "LOW") risk_level = "LOW";

    // === RECOMENDAÇÕES ===
    string recommendation = "MONITOR";
    if (signal.direction == "BULL" && signal.confidence > 0.7 && price_position < 30)
        recommendation = "BUY_SIGNAL";
    else if (signal.direction == "BEAR" && signal.confidence > 0.7 && price_position > 70)
        recommendation = "SELL_SIGNAL";
    else if (squeeze_detected)
        recommendation = "WAIT_BREAKOUT";
    else if (expansion_detected && signal.confidence < 0.5)
        recommendation = "REDUCE_POSITION";

    // === ALERTAS ===
    string alerts = "";
    if (squeeze_detected) alerts += "SQUEEZE_ALERT ";
    if (expansion_detected && width_change_pct > 50) alerts += "RAPID_EXPANSION ";
    if (MathAbs(upper_slope.linear_regression.slope_value) > 0.1) alerts += "STRONG_UPPER_TREND ";
    if (MathAbs(lower_slope.linear_regression.slope_value) > 0.1) alerts += "STRONG_LOWER_TREND ";
    if (width_atr_ratio > 6) alerts += "EXTREME_VOLATILITY ";
    if (signal.confidence > 0.8) alerts += "HIGH_CONFIDENCE_SIGNAL ";
    if (alerts == "") alerts = "NONE";

    // === EXIBIÇÃO COMPLETA ===
    Print("=== BOLLINGER M3 COMPREHENSIVE ANALYSIS ===");
    Print("Symbol: ", symbol, " | Timeframe: M3 | Timestamp: ", TimeToString(TimeCurrent()));
    Print("");

    // SIGNAL ANALYSIS
    Print("--- PRIMARY SIGNAL ---");
    Print("Direction: ", signal.direction, " | Confidence: ", DoubleToString(signal.confidence, 3));
    Print("Region: ", EnumToString(signal.region), " | Slope State: ", EnumToString(signal.slope_state));
    Print("Reason: ", signal.reason);
    Print("");

    // BAND VALUES
    Print("--- BAND METRICS ---");
    Print("Upper Band: ", DoubleToString(upper, 2), " | Middle: ", DoubleToString(middle, 2), " | Lower: ", DoubleToString(lower, 2));
    Print("Band Width: ", DoubleToString(band_width, 2), " | Avg Width (20): ", DoubleToString(avg_width_20, 2));
    Print("Width Change: ", DoubleToString(width_change_pct, 1), "%");
    Print("");

    // PRICE ANALYSIS
    Print("--- PRICE POSITION ---");
    Print("Current Price: ", DoubleToString(current_price, 2), " | Position in Bands: ", DoubleToString(price_position, 1), "%");
    Print("Distance to Upper: ", DoubleToString(distance_to_upper, 2), " | Distance to Lower: ", DoubleToString(distance_to_lower, 2));
    Print("");

    // SLOPE ANALYSIS
    Print("--- SLOPE ANALYSIS ---");
    Print("Upper Slope: ", DoubleToString(upper_slope.linear_regression.slope_value, 4),
          " (R²=", DoubleToString(upper_slope.linear_regression.r_squared, 3), ")");
    Print("Middle Slope: ", DoubleToString(middle_slope.linear_regression.slope_value, 4),
          " (R²=", DoubleToString(middle_slope.linear_regression.r_squared, 3), ")");
    Print("Lower Slope: ", DoubleToString(lower_slope.linear_regression.slope_value, 4),
          " (R²=", DoubleToString(lower_slope.linear_regression.r_squared, 3), ")");
    Print("");

    // VOLATILITY ANALYSIS
    Print("--- VOLATILITY CONTEXT ---");
    Print("ATR Value: ", DoubleToString(atr_value, 5), " | Width/ATR Ratio: ", DoubleToString(width_atr_ratio, 2));
    Print("Volatility State: ", volatility_state, " | Market Phase: ", market_phase);
    Print("");

    // PATTERN DETECTION
    Print("--- PATTERN DETECTION ---");
    Print("Squeeze Detected: ", squeeze_detected ? "YES" : "NO");
    Print("Expansion Detected: ", expansion_detected ? "YES" : "NO");
    Print("Convergence Detected: ", convergence_detected ? "YES" : "NO");
    Print("Momentum State: ", momentum_state);
    Print("");

    // RISK & OPPORTUNITY
    Print("--- RISK & OPPORTUNITY ---");
    Print("Breakout Potential: ", breakout_potential, " | Risk Level: ", risk_level);
    Print("Recommendation: ", recommendation);
    Print("Active Alerts: ", alerts);
    Print("");

    // STATISTICAL SUMMARY
    Print("--- STATISTICAL SUMMARY ---");
    Print("Valid Width Samples: ", valid_widths, "/20");
    Print("Width StdDev Estimate: ", DoubleToString(MathAbs(band_width - avg_width_20), 2));
    Print("Slope Consensus: ", (upper_slope.linear_regression.slope_value * middle_slope.linear_regression.slope_value > 0) ? "ALIGNED" : "DIVERGENT");
    Print("==================================================");
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