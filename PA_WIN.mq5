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

         BollAnalysis(tf, ctx);
 

         // Loop Pelos Contextos de Estratégias e chama CheckForSignal
         STRATEGY_CTX *strategy_contexts[];
         string setup_names[];
         int strategy_count = g_config_manager.GetStrategyContexts(strategy_contexts, setup_names);

         for (int j = 0; j < strategy_count; j++)
         {
            if (strategy_contexts[j] != NULL)
            {
               strategy_contexts[j].Update(symbol, tf); // This calls CheckForSignal internally and passes the symbol and timeframe
               //
               CEmasBuyBull *strategy = strategy_contexts[j].GetStrategy("m15_m3_emas_buy_bull");
               // Print("INICIO DO LOG ######################################################################");
               // Print("INICIO DO LOG ######################################################################");
               // Print("INICIO DO LOG ######################################################################");
               //strategy.PrintFullDebugLog();
               // Print("FIM DO LOG #########################################################################");
               // Print("FIM DO LOG #########################################################################");
               // Print("FIM DO LOG #########################################################################");

               if (strategy != NULL)
               {
                  ENUM_STRATEGY_STATE state = strategy.GetState();
                  if (state != STRATEGY_IDLE)
                  {
                     strategy.SetState(STRATEGY_IDLE);
                  }
               }
            }
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

void BollAnalysis(ENUM_TIMEFRAMES tf, TF_CTX &ctx)
{
   // Obter o indicador Bandas de Bollinger do contexto
   CIndicatorBase *base_indicator = ctx.GetIndicator("boll20");
   if (base_indicator == NULL)
   {
      Print("BollAnalysis: Indicador Bollinger 'boll20' não encontrado no contexto");
      return;
   }

   // Converter para CBollinger para acessar métodos de análise de largura
   CBollinger *bollinger = dynamic_cast<CBollinger*>(base_indicator);
   if (bollinger == NULL)
   {
      Print("BollAnalysis: Falha ao converter indicador para CBollinger");
      return;
   }

   // Get complete width analysis for last closed candle
   SWidthAnalysis analysis = bollinger.GetWidthMetric(1);

   // Get price for last closed candle
   double current_price = iClose(Symbol(), tf, 1);
   double upper_band = bollinger.GetUpper(1);
   double lower_band = bollinger.GetLower(1);
   double middle_band = bollinger.GetValue(1);

   // Calcular posição relativa às bandas
   string position_status;
   if (current_price >= upper_band)
      position_status = "ACIMA DA BANDA SUPERIOR";
   else if (current_price <= lower_band)
      position_status = "ABAIXO DA BANDA INFERIOR";
   else if (current_price >= middle_band)
      position_status = "ACIMA DA BANDA MÉDIA";
   else
      position_status = "ABAIXO DA BANDA MÉDIA";

   // Registrar análise detalhada das Bandas de Bollinger
   Print("=== ANÁLISE DAS BANDAS DE BOLLINGER ===");
   Print("TimeFrame: ", EnumToString(tf));
   Print("Símbolo: ", Symbol());
   Print("Horário Atual: ", TimeToString(TimeCurrent()));

   Print("--- VALORES DAS BANDAS ---");
   Print("Banda Superior: ", DoubleToString(upper_band, 5));
   Print("Banda Média: ", DoubleToString(middle_band, 5));
   Print("Banda Inferior: ", DoubleToString(lower_band, 5));
   Print("Preço Atual: ", DoubleToString(current_price, 5));
   Print("Status da Posição: ", position_status);

   Print("--- ANÁLISE DA LARGURA ---");
   Print("Valor da Largura: ", DoubleToString(analysis.width, 5));
   Print("Percentil: ", DoubleToString(analysis.percentile, 2), "%");
   Print("Z-Score: ", DoubleToString(analysis.zscore, 3));
   Print("Valor da Inclinação: ", DoubleToString(analysis.slope_value, 5));
   Print("Direção da Inclinação: ", analysis.slope_direction);

   Print("--- AVALIAÇÃO DAS CONDIÇÕES DE MERCADO ---");

   // Avaliação da Posição da Largura
   if (analysis.percentile < 20)
      Print("POSIÇÃO DA LARGURA: COMPRIMIDA (Bandas estreitas - potencial breakout)");
   else if (analysis.percentile > 80)
      Print("POSIÇÃO DA LARGURA: EXPANDIDA (Bandas largas - potencial reversão)");
   else
      Print("POSIÇÃO DA LARGURA: NORMAL (Volatilidade padrão)");

   // Avaliação da Tendência da Largura
   if (analysis.slope_direction == "EXPANDINDO")
      Print("TENDÊNCIA DA LARGURA: EXPANDINDO (Bandas ficando mais largas)");
   else if (analysis.slope_direction == "CONTRAINDO")
      Print("TENDÊNCIA DA LARGURA: CONTRAINDO (Bandas ficando mais estreitas)");
   else
      Print("TENDÊNCIA DA LARGURA: ESTÁVEL (Largura inalterada)");

   // Avaliação Combinada de Sinais
   Print("--- ANÁLISE COMBINADA DE SINAIS ---");

   if (analysis.percentile < 20 && analysis.slope_direction == "EXPANDINDO")
   {
      Print("🚀 SINAL DE BREAKOUT: Bandas estreitas expandindo - Alta probabilidade de breakout");
      if (position_status == "ACIMA DA BANDA SUPERIOR")
         Print("   + Breakout bullish confirmado (preço acima da banda superior em expansão)");
      else if (position_status == "ABAIXO DA BANDA INFERIOR")
         Print("   + Breakout bearish confirmado (preço abaixo da banda inferior em expansão)");
   }
   else if (analysis.percentile > 80 && analysis.slope_direction == "CONTRAINDO")
   {
      Print("⚠️ SINAL DE REVERSÃO: Bandas largas contraindo - Potencial reversão");
      if (position_status == "ACIMA DA BANDA SUPERIOR")
         Print("   + Potencial reversão bearish (preço em banda superior estendida)");
      else if (position_status == "ABAIXO DA BANDA INFERIOR")
         Print("   + Potencial reversão bullish (preço em banda inferior estendida)");
   }
   else if (analysis.percentile < 20 && analysis.slope_direction == "CONTRAINDO")
   {
      Print("📉 SINAL DE CONTINUAÇÃO: Bandas estreitas contraindo - Continuação de tendência provável");
   }
   else if (analysis.percentile > 80 && analysis.slope_direction == "EXPANDINDO")
   {
      Print("📈 SINAL DE TENDÊNCIA: Bandas largas expandindo - Forte continuação de tendência");
   }
   else
   {
      Print("🔄 NEUTRO: Nenhum sinal significativo baseado na largura detectado");
   }

   // Contexto Estatístico
   Print("--- CONTEXTO ESTATÍSTICO ---");
   if (analysis.zscore < -2.0)
      Print("Z-SCORE: Bandas extremamente estreitas (evento raro)");
   else if (analysis.zscore < -1.0)
      Print("Z-SCORE: Bandas significativamente estreitas");
   else if (analysis.zscore > 2.0)
      Print("Z-SCORE: Bandas extremamente largas (evento raro)");
   else if (analysis.zscore > 1.0)
      Print("Z-SCORE: Bandas significativamente largas");
   else
      Print("Z-SCORE: Largura normal das bandas");

   Print("=== FIM DA ANÁLISE BOLLINGER ===");
   Print("");
}