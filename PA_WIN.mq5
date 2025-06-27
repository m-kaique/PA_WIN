//+------------------------------------------------------------------+
//|                                                       PA_WIN.mq5 |
//|                                                   Copyright 2025 |
//|                                                 https://mql5.com |
//| 22.06.2025 - Updated with ConfigManager and PriceAction support |
//| 27.06.2025 - Added LTA/LTB TrendLine functionality               |
//+------------------------------------------------------------------+

#property copyright "Copyright 2025"
#property link "https://mql5.com"
#property version "3.10"

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
   m_control_tf = PERIOD_D1;
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
//| Executar lógica apenas em novo candle                           |
//+------------------------------------------------------------------+
void ExecuteOnNewBar()
{
   Print("=== NOVO CANDLE ", EnumToString(m_control_tf), " ===");
   Print("Tempo do candle: ", TimeToString(m_last_bar_time, TIME_DATE | TIME_MINUTES));

   string configured_symbol = "WIN$N"; // Usar símbolo fixo do JSON

   // Obter contexto D1 se habilitado
   TF_CTX *D1_ctx = g_config_manager.GetContext(configured_symbol, PERIOD_D1);
   if (D1_ctx != NULL)
   {
      D1_ctx.Update();

      Print("=== Contexto D1 - Indicadores ===");
      // Acessar indicadores (lógica existente)
      for (int i = 1; i < 3; i++)
      {
         double ema9  = D1_ctx.GetIndicatorValue("ema9", i);
         double ema21 = D1_ctx.GetIndicatorValue("ema21", i);
         Print("EMA9 D1 Shift: ", i, " = ", ema9);
         Print("EMA21 D1 Shift: ", i, " = ", ema21);
      }

      Print("=== Contexto D1 - Price Action LTA/LTB ===");
      // Acessar Price Action - LTA/LTB corrigido
      double lta_price = D1_ctx.GetPriceActionValue("LTA_LTB", 0);
      Print("LTA (Linha de Tendência de Alta - mínimos ascendentes) shift 0: ", lta_price);
      
      if (lta_price > 0)
      {
         Print("Linha de Tendência de Alta detectada em: ", lta_price);
         Print("*** LTA conecta MÍNIMOS ASCENDENTES e aponta para CIMA ***");
         
         // Verificar preços históricos da LTA
         for(int j = 0; j < 3; j++)
         {
            double lta_hist = D1_ctx.GetPriceActionValue("LTA_LTB", j);
            Print("LTA shift ", j, ": ", lta_hist);
         }
      }
      else
      {
         Print("Nenhuma Linha de Tendência de Alta válida encontrada");
      }
      
      // Copiar valores da LTA para análise
      double lta_buffer[];
      if(D1_ctx.CopyPriceActionValues("LTA_LTB", 0, 5, lta_buffer))
      {
         Print("=== Valores LTA copiados ===");
         for(int k = 0; k < ArraySize(lta_buffer); k++)
         {
            Print("LTA[", k, "] = ", lta_buffer[k]);
         }
      }
   }
   else
   {
      Print("AVISO: Contexto D1 não encontrado para símbolo: ", configured_symbol);
   }

   // Exemplo adicional: acessar contexto H4 se disponível
   TF_CTX *H4_ctx = g_config_manager.GetContext(configured_symbol, PERIOD_H4);
   if (H4_ctx != NULL)
   {
      H4_ctx.Update();

      Print("=== Contexto H4 - Price Action ===");
      
      // Verificar múltiplas configurações de TrendLine no H4
      double swing_lta = H4_ctx.GetPriceActionValue("swing_lines", 0);
      if (swing_lta > 0)
      {
         Print("H4 Swing Lines LTA (mínimos ascendentes): ", swing_lta);
      }
      
      double trend_ltb = H4_ctx.GetPriceActionValue("trend_h1", 0);
      if (trend_ltb > 0)
      {
         Print("H4 Trend H1 LTB (máximos descendentes): ", trend_ltb);
      }
      
      // Demonstrar análise de tendência corrigida
      if(swing_lta > 0 && trend_ltb > 0)
      {
         double current_price = iClose(configured_symbol, PERIOD_H4, 0);
         if(current_price > swing_lta)
         {
            Print("ANÁLISE: Preço acima da LTA (", swing_lta, ") - tendência de alta confirmada");
         }
         if(current_price < trend_ltb)
         {
            Print("ANÁLISE: Preço abaixo da LTB (", trend_ltb, ") - pressão de baixa confirmada");
         }
      }
   }
   
   Print("=== Análise Completa ===");
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