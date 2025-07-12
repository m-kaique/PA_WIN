//+------------------------------------------------------------------+
//|                                                       PA_WIN.mq5 |
//|                                                   Copyright 2025 |
//|                                                 https://mql5.com |
//| 22.06.2025 - Updated with ConfigManager                          |
//+------------------------------------------------------------------+

#property copyright "Copyright 2025"
#property link "https://mql5.com"
#property version "2.00"

#include "TF_CTX/config_manager.mqh"

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
   // Limpar gerenciador de configuração
   if (g_config_manager != NULL)
   {
      delete g_config_manager;
      g_config_manager = NULL;
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Verificar se há um novo candle no período especificado
   if (!IsNewBar(m_control_tf))
      return; // Sair se não for um novo candle

   // Verificar se o gerenciador está inicializado
   if (g_config_manager == NULL || !g_config_manager.IsInitialized())
   {
      Print("ERRO: ConfigManager não está inicializado");
      return;
   }

   // Executar lógica apenas em novo candle
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
   for (int i = 0; i < count; i++)
   {
      TF_CTX *ctx = contexts[i];
      ENUM_TIMEFRAMES tf = tfs[i];
      if (ctx == NULL)
         continue;
      ctx.Update();
      if (tf == PERIOD_H1)
      {
         CPriceActionBase *pa = ctx.GetPriceAction("swing_lines");
         if (pa != NULL)
         {
            CTrendLine *tl = (CTrendLine *)pa;
            string pos = tl.GetPricePositionString();
            if (pos != "")
               Print("Posicao do preco em H1: ", pos);
           
            CTrendLine::SCandleFullInfo cd = tl.GetCandleFullInfo(1);
           
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
}

//+------------------------------------------------------------------+
//| Executar lógica apenas em novo candle                           |
//+------------------------------------------------------------------+
void ExecuteOnNewBar()
{
   Print("=== NOVO CANDLE ", EnumToString(m_control_tf), " ===");
   Print("Tempo do candle: ", TimeToString(m_last_bar_time, TIME_DATE | TIME_MINUTES));

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