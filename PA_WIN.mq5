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
   // CheckCOnditions(PERIOD_M5);
   // manage_positions(PERIOD_M5);
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
//| Informações sobre a TrendLine de um TF                           |
//+------------------------------------------------------------------+
void CheckCtxTrendLine(ENUM_TIMEFRAMES tf, TF_CTX &ctx)
{
   if (tf == PERIOD_H1)
   {
      CIndicatorBase *pa = ctx.GetIndicator("swing_lines");
      if (pa != NULL)
      {
         CTrendLine *tl = (CTrendLine *)pa;
         string pos = tl.GetPricePositionString();
         if (pos != "")
            Print("Posicao do preco em H1: ", pos);

         CTrendLine::SCandleFullInfo cd;
         cd = tl.GetCandleFullInfo(1);

         // Cabeçalho da análise do candle
         Print("========== ANÁLISE CANDLE[1] - H1 ==========");

         // Informações de cruzamento do corpo
         Print("CRUZAMENTOS DO CORPO:");
         PrintFormat("  • LTA: %s | LTA2: %s",
                     cd.trend.body_cross_lta ? "SIM" : "NÃO",
                     cd.trend.body_cross_lta2 ? "SIM" : "NÃO");
         PrintFormat("  • LTB: %s | LTB2: %s",
                     cd.trend.body_cross_ltb ? "SIM" : "NÃO",
                     cd.trend.body_cross_ltb2 ? "SIM" : "NÃO");

         // Posicionamento entre linhas
         Print("POSICIONAMENTO:");
         PrintFormat("  • Entre LTAs: %s",
                     cd.trend.between_ltas ? "SIM" : "NÃO");
         PrintFormat("  • Entre LTBs: %s",
                     cd.trend.between_ltbs ? "SIM" : "NÃO");

         // Posicionamento nas linhas
         Print("POSIÇÃO NAS LINHAS:");
         PrintFormat("  • LTA Superior: %s | LTA Inferior: %s",
                     cd.trend.on_lta_upper ? "SIM" : "NÃO",
                     cd.trend.on_lta_lower ? "SIM" : "NÃO");
         PrintFormat("  • LTA2 Superior: %s | LTA2 Inferior: %s",
                     cd.trend.on_lta2_upper ? "SIM" : "NÃO",
                     cd.trend.on_lta2_lower ? "SIM" : "NÃO");
         PrintFormat("  • LTB Superior: %s | LTB Inferior: %s",
                     cd.trend.on_ltb_upper ? "SIM" : "NÃO",
                     cd.trend.on_ltb_lower ? "SIM" : "NÃO");
         PrintFormat("  • LTB2 Superior: %s | LTB2 Inferior: %s",
                     cd.trend.on_ltb2_upper ? "SIM" : "NÃO",
                     cd.trend.on_ltb2_lower ? "SIM" : "NÃO");

         // Distâncias
         Print("DISTÂNCIAS DO FECHAMENTO:");
         PrintFormat("  • LTA: %.5f | LTA2: %.5f",
                     cd.trend.dist_close_lta, cd.trend.dist_close_lta2);
         PrintFormat("  • LTB: %.5f | LTB2: %.5f",
                     cd.trend.dist_close_ltb, cd.trend.dist_close_ltb2);

         // Fakeouts
         Print("FAKEOUTS:");
         PrintFormat("  • LTA: %s | LTA2: %s",
                     cd.trend.fakeout_lta ? "SIM" : "NÃO",
                     cd.trend.fakeout_lta2 ? "SIM" : "NÃO");
         PrintFormat("  • LTB: %s | LTB2: %s",
                     cd.trend.fakeout_ltb ? "SIM" : "NÃO",
                     cd.trend.fakeout_ltb2 ? "SIM" : "NÃO");

         Print("==========================================");
      }
   }
}

//+------------------------------------------------------------------+
//| Informações sobre a TrendLine de um TF                           |
//+------------------------------------------------------------------+
void CheckSlopePosM15(ENUM_TIMEFRAMES tf, TF_CTX &ctx)
{
   if (tf == PERIOD_M15)
   {
      double tf_ctx_atr = 0;

      CATR *atr_m15 = ctx.GetIndicator("ATR15");
      if (atr_m15 != NULL)
      {
         Print("###  atr_m15");
         double atr_value = atr_m15.GetValue(1);
         tf_ctx_atr = atr_value;
         Print("valor: " + (string)atr_value);
      }
      else
      {
         Print("Atr Não Configurado ou Com Problemas...");
      }

      if (tf_ctx_atr != 0)
      {
         // EMA 9
         CMovingAverages *ema = ctx.GetIndicator("ema9");
         if (ema != NULL)
         {
            // Slope
            Print("###  EMA9");
            SSlopeValidation full_validation;
            full_validation = ema.GetSlopeValidation(tf_ctx_atr);
            ema.m_slope.DebugSlopeValidation(full_validation);

            // Pos
            SPositionInfo pos_ema9;
            pos_ema9 = ema.GetPositionInfo(1, COPY_MIDDLE, tf_ctx_atr);
            Print("Posição EMA9: " + ema.m_candle_distance.GetCandlePositionDescription(pos_ema9.position));
            Print("Distância EMA9: " + string(pos_ema9.distance));
            Print("GAP EMA9: " + string(pos_ema9.gap));
            Print("ATR EMA9: " + string(pos_ema9.atr));
         }

         // EMA21
         CMovingAverages *ema21 = ctx.GetIndicator("ema21");
         if (ema21 != NULL)
         {
            // Slope
            Print("###  EMA21");
            SSlopeValidation full_validation;
            full_validation = ema21.GetSlopeValidation(tf_ctx_atr);
            ema21.m_slope.DebugSlopeValidation(full_validation);

            // Pos
            SPositionInfo pos_ema21;
            pos_ema21 = ema21.GetPositionInfo(1, COPY_MIDDLE, tf_ctx_atr);
            Print("Posição EMA21: " + ema21.m_candle_distance.GetCandlePositionDescription(pos_ema21.position));
            Print("Distância EMA21: " + string(pos_ema21.distance));
            Print("GAP EMA21: " + string(pos_ema21.gap));
            Print("ATR EMA21: " + string(pos_ema21.atr));
         }

         // VWAP
         CVWAP *vwap = ctx.GetIndicator("vwap_diario_fin");
         if (vwap != NULL)
         {
            // Slope
            Print("###  VWAP");
            SSlopeValidation full_validation;
            full_validation = vwap.GetSlopeValidation(tf_ctx_atr);
            vwap.m_slope.DebugSlopeValidation(full_validation);

            // Pos
            SPositionInfo pos_vwap;
            pos_vwap = vwap.GetPositionInfo(1, COPY_MIDDLE, tf_ctx_atr);
            Print("Posição VWAP: " + vwap.m_candle_distance.GetCandlePositionDescription(pos_vwap.position));
            Print("Distância VWAP: " + string(pos_vwap.distance));
            Print("GAP VWAP: " + string(pos_vwap.gap));
            Print("ATR VWAP: " + string(pos_vwap.atr));
         }

         // BOLL
         CBollinger *boll = ctx.GetIndicator("boll20");
         if (boll != NULL)
         {

            // Slope Superior
            Print("###  BOLL SUPERIOR");
            SSlopeValidation full_validation_superior;
            full_validation_superior = boll.GetSlopeValidation(tf_ctx_atr, COPY_UPPER);
            boll.m_slope.DebugSlopeValidation(full_validation_superior);

            // Pos Superior
            SPositionInfo pos_boll_superior;
            pos_boll_superior = boll.GetPositionInfo(1, COPY_UPPER, tf_ctx_atr);
            Print("Posição: " + boll.m_candle_distance.GetCandlePositionDescription(pos_boll_superior.position));
            Print("Distância: " + string(pos_boll_superior.distance));
            Print("GAP: " + string(pos_boll_superior.gap));
            Print("ATR: " + string(pos_boll_superior.atr));

            // ---

            // Slope Centro
            Print("###  BOLL CENTRO");
            SSlopeValidation full_validation;
            full_validation = boll.GetSlopeValidation(tf_ctx_atr, COPY_MIDDLE);
            boll.m_slope.DebugSlopeValidation(full_validation);

            // Pos Centro
            SPositionInfo pos_boll_meio;
            pos_boll_meio = boll.GetPositionInfo(1, COPY_MIDDLE, tf_ctx_atr);
            Print("Posição: " + boll.m_candle_distance.GetCandlePositionDescription(pos_boll_meio.position));
            Print("Distância: " + string(pos_boll_meio.distance));
            Print("GAP: " + string(pos_boll_meio.gap));
            Print("ATR: " + string(pos_boll_meio.atr));

            // ---

            // Slope Inferior
            Print("###  BOLL INFERIOR");
            SSlopeValidation full_validation_inferior;
            full_validation_inferior = boll.GetSlopeValidation(tf_ctx_atr, COPY_LOWER);
            boll.m_slope.DebugSlopeValidation(full_validation_inferior);

            // Pos Inferior
            SPositionInfo pos_boll_inferior;
            pos_boll_inferior = boll.GetPositionInfo(1, COPY_LOWER, tf_ctx_atr);
            Print("Posição: " + boll.m_candle_distance.GetCandlePositionDescription(pos_boll_inferior.position));
            Print("Distância: " + string(pos_boll_inferior.distance));
            Print("GAP: " + string(pos_boll_inferior.gap));
            Print("ATR: " + string(pos_boll_inferior.atr));
         }
      }
   }
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

   for (int i = 0; i < count; i++)
   {
      TF_CTX *ctx = contexts[i];
      ENUM_TIMEFRAMES tf = tfs[i];
      if (ctx == NULL)
         continue;

      if (ctx.HasNewBar())
      {
         ctx.Update();
         CheckSlopePosM15(tf, ctx);
         // CheckCandlePosition(tf, ctx);
         // CheckM15Vol(tf, ctx);
      }
   }
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