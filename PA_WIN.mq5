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
     // === VALIDAÇÃO DO TIMEFRAME ===
     // Explicação: Esta função é específica para análise M3
     // Apenas processa quando chamado com timeframe M3
     if (tf != PERIOD_M3)
         return;

     // === OBTENÇÃO DO CONTEXTO M3 ===
     // Explicação: O TF_CTX contém todos os indicadores configurados
     // para este símbolo e timeframe específico
     TF_CTX *ctx = g_config_manager.GetContext(symbol, PERIOD_M3);
     if (ctx == NULL)
     {
         Print("ERRO: Contexto M3 não encontrado para símbolo: ", symbol);
         return;
     }

     // === OBTENÇÃO DO ATR ===
     // Explicação: ATR (Average True Range) mede a volatilidade
     // Usamos ATR15 (período 15) como referência de volatilidade
     double atr_value = ctx.GetIndicatorValue("ATR15", 1);
     if (atr_value > 0)
     {
         Print("ATR value retrieved: ", DoubleToString(atr_value, 5));
     }
     else
     {
         Print("WARNING: ATR15 indicator not found or invalid, using default ATR = 0.001");
         atr_value = 0.001;
     }

     // === OBTENÇÃO DO INDICADOR BOLLINGER ===
     // Explicação: boll20 = Bollinger Bands com período 20
     // Este indicador foi aprimorado com todas as melhorias implementadas
     CBollinger *bollinger = (CBollinger*)ctx.GetIndicator("boll20");
     if (bollinger == NULL)
     {
         Print("WARNING: boll20 indicator not found in M3 context");
     }

     // === CÁLCULO DO SINAL COMBINADO ===
     // Explicação: Esta é a chamada principal que executa toda a lógica
     // aprimorada do indicador Bollinger (consenso ponderado, etc.)
     SCombinedSignal signal = bollinger.ComputeCombinedSignal(atr_value, 9, 0.02);

    // === COLETA DE DADOS DAS BANDAS ===
    // Explicação: Obter valores atuais de cada banda para análise completa
    // Estes dados são fundamentais para entender o contexto do sinal

    double upper_band = bollinger.GetUpper(1);
    // Banda superior (resistência) - nível onde pressão vendedora aumenta
    double middle_band = bollinger.GetValue(1);
    // Média móvel (linha central) - tendência de médio prazo
    double lower_band = bollinger.GetLower(1);
    // Banda inferior (suporte) - nível onde pressão compradora aumenta
    double band_width = upper_band - lower_band;
    // Largura das bandas - medida de volatilidade atual

    /*
     * INTERPRETAÇÃO DAS BANDAS:
     * ------------------------
     * Upper Band: Nível de resistência dinâmica (pressão de venda)
     * Middle Band: Média móvel (tendência de médio prazo)
     * Lower Band: Nível de suporte dinâmico (pressão de compra)
     * Width: Medida de volatilidade (expansion = alta volatilidade)
     */

    // === ANÁLISE DE POSICIONAMENTO DO PREÇO ===
    // Explicação: Determinar onde o preço está posicionado dentro das bandas
    // Fundamental para avaliar se está próximo de suporte/resistência

    double current_price = iClose(symbol, tf, 1);
    // Preço de fechamento do candle anterior (shift=1)

    // Cálculo da posição percentual dentro das bandas
    double price_position = 0.0;
    if (band_width > 0)  // Verificação de segurança
    {
        // Fórmula: (preço - banda_inferior) / largura_total * 100
        price_position = (current_price - lower_band) / band_width * 100.0;
    }

    /*
     * INTERPRETAÇÃO DA POSIÇÃO:
     * -------------------------
     * 0-25%: Preço próximo à banda inferior (possível zona de compra)
     * 25-75%: Posição intermediária (movimento normal)
     * 75-100%: Preço próximo à banda superior (possível zona de venda)
     *
     * Para WIN$N especificamente:
     * - Valores abaixo de 20% podem indicar oversold
     * - Valores acima de 80% podem indicar overbought
     */

    // Calculate average width from recent history (approximate)
    double avg_width = band_width; // Default to current
    double upper_history[], lower_history[];
    if (bollinger.CopyUpper(0, 20, upper_history) && bollinger.CopyLower(0, 20, lower_history)) {
        double total_width = 0.0;
        int valid_count = 0;
        for (int i = 0; i < ArraySize(upper_history) && i < ArraySize(lower_history); i++) {
            double w = upper_history[i] - lower_history[i];
            if (w > 0) {
                total_width += w;
                valid_count++;
            }
        }
        if (valid_count > 0) {
            avg_width = total_width / valid_count;
        }
    }

    // Get slope details
    SSlopeValidation upper_slope = bollinger.GetSlopeValidation(atr_value, COPY_UPPER);
    SSlopeValidation middle_slope = bollinger.GetSlopeValidation(atr_value, COPY_MIDDLE);
    SSlopeValidation lower_slope = bollinger.GetSlopeValidation(atr_value, COPY_LOWER);

    // Determine market context
    string market_phase = "NORMAL";
    if (signal.region == WIDTH_VERY_NARROW || signal.region == WIDTH_NARROW) {
        market_phase = "CONTRACTION";
    } else if (signal.region == WIDTH_VERY_WIDE || signal.region == WIDTH_WIDE) {
        market_phase = "EXPANSION";
    }

    bool squeeze_detected = (signal.region == WIDTH_VERY_NARROW);

    string breakout_potential = "LOW";
    if (signal.confidence > 0.7) {
        if (price_position < 20 || price_position > 80) {
            breakout_potential = "HIGH";
        } else {
            breakout_potential = "MEDIUM";
        }
    }

    string volatility_state = "NORMAL";
    double width_atr_ratio = band_width / atr_value;
    if (width_atr_ratio > 4.0) {
        volatility_state = "HIGH";
    } else if (width_atr_ratio < 2.0) {
        volatility_state = "LOW";
    }

    // === EXIBIÇÃO DA ANÁLISE DETALHADA ===
    // Explicação: Apresentar todas as informações coletadas de forma
    // estruturada e legível para análise técnica do WIN$N em M3
    Print("=== BOLLINGER M3 DETAILED ANALYSIS ===");
    Print("Symbol: ", symbol, " | Timeframe: M3");
    Print("Timestamp: ", TimeToString(TimeCurrent()));
    Print("");
    Print("--- SIGNAL ANALYSIS ---");
    // Seção com informações básicas do sinal (direção, confiança, etc.)
    Print("Direction: ", signal.direction);
    Print("Confidence: ", DoubleToString(signal.confidence, 3));
    Print("Region: ", EnumToString(signal.region));
    Print("Slope State: ", EnumToString(signal.slope_state));
    Print("Reason: ", signal.reason);
    Print("");
    Print("--- BAND VALUES ---");
    Print("Upper Band: ", DoubleToString(upper_band, 2));
    Print("Middle Band: ", DoubleToString(middle_band, 2));
    Print("Lower Band: ", DoubleToString(lower_band, 2));
    Print("Band Width: ", DoubleToString(band_width, 2));
    Print("");
    Print("--- PRICE ANALYSIS ---");
    Print("Current Price: ", DoubleToString(current_price, 2));
    Print("Price Position in Bands: ", DoubleToString(price_position, 1), "%");
    Print("Distance to Upper: ", DoubleToString(upper_band - current_price, 2));
    Print("Distance to Lower: ", DoubleToString(current_price - lower_band, 2));
    Print("");
    Print("--- SLOPE DETAILS ---");
    Print("Upper Slope: ", DoubleToString(upper_slope.linear_regression.slope_value, 4));
    Print("Middle Slope: ", DoubleToString(middle_slope.linear_regression.slope_value, 4));
    Print("Lower Slope: ", DoubleToString(lower_slope.linear_regression.slope_value, 4));
    Print("Slope R²: Upper=", DoubleToString(upper_slope.linear_regression.r_squared, 3),
          " Mid=", DoubleToString(middle_slope.linear_regression.r_squared, 3),
          " Low=", DoubleToString(lower_slope.linear_regression.r_squared, 3));
    Print("");
    Print("--- VOLATILITY CONTEXT ---");
    Print("ATR Value: ", DoubleToString(atr_value, 5));
    Print("Width vs ATR Ratio: ", DoubleToString(width_atr_ratio, 2));
    Print("Volatility State: ", volatility_state);
    Print("Average Width (20 bars): ", DoubleToString(avg_width, 2));
    Print("");
    Print("--- MARKET CONTEXT ---");
    Print("Market Phase: ", market_phase);
    Print("Squeeze Detected: ", squeeze_detected ? "YES" : "NO");
    Print("Breakout Potential: ", breakout_potential);
    Print("========================================");

    // Note: Don't delete bollinger as it's managed by TF_CTX
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