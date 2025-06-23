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

// Configuração hardcoded em JSON
const string HARDCODED_CONFIG = 
"{"
"   \"WIN$N\": {"
"      \"D1\": {"
"         \"enabled\": true,"
"         \"num_candles\": 9,"
"         \"moving_averages\": {"
"            \"ema9\": {"
"               \"period\": 9,"
"               \"method\": \"EMA\","
"               \"enabled\": true"
"            },"
"            \"ema21\": {"
"               \"period\": 21,"
"               \"method\": \"EMA\","
"               \"enabled\": true"
"            },"
"            \"ema50\": {"
"               \"period\": 50,"
"               \"method\": \"EMA\","
"               \"enabled\": false"
"            },"
"            \"sma200\": {"
"               \"period\": 200,"
"               \"method\": \"SMA\","
"               \"enabled\": false"
"            }"
"         }"
"      },"
"      \"H4\": {"
"         \"enabled\": true,"
"         \"num_candles\": 18,"
"         \"moving_averages\": {"
"            \"ema9\": {"
"               \"period\": 9,"
"               \"method\": \"SMA\","
"               \"enabled\": true"
"            },"
"            \"ema21\": {"
"               \"period\": 21,"
"               \"method\": \"EMA\","
"               \"enabled\": false"
"            },"
"            \"ema50\": {"
"               \"period\": 50,"
"               \"method\": \"EMA\","
"               \"enabled\": false"
"            },"
"            \"sma200\": {"
"               \"period\": 200,"
"               \"method\": \"SMA\","
"               \"enabled\": true"
"            }"
"         }"
"      }"
"   },"
"}";

// Gerenciador de configuração
CConfigManager* g_config_manager;

// Parâmetros de entrada
// Quando 'false', o EA tenta carregar as configurações do arquivo JSON
// localizado na pasta MQL5/Files (ou Common\Files quando FILE_COMMON é usado)
input bool UseHardcodedConfig = false; // Usar configuração hardcoded
input string JsonConfigFile = "config.json"; // Nome do arquivo JSON (se não usar hardcoded)

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
   if(g_config_manager == NULL)
   {
      Print("ERRO: Falha ao criar ConfigManager");
      return INIT_FAILED;
   }
   
   // Inicializar com configuração escolhida
   bool init_success = false;
   
   if(UseHardcodedConfig)
   {
      Print("Usando configuração hardcoded...");
      init_success = g_config_manager.Init(HARDCODED_CONFIG);
   }
   else
   {
      Print("Tentando carregar arquivo JSON: ", JsonConfigFile);
      init_success = g_config_manager.InitFromFile(JsonConfigFile);
   }
   
   if(!init_success)
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
   for(int i = 0; i < ArraySize(symbols); i++)
   {
      Print("Símbolo configurado: ", symbols[i]);
      
      // Verificar contextos habilitados
      if(g_config_manager.IsContextEnabled(symbols[i], PERIOD_D1))
         Print("  - D1 habilitado");
      if(g_config_manager.IsContextEnabled(symbols[i], PERIOD_H4))
         Print("  - H4 habilitado");
   }
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Limpar gerenciador de configuração
   if(g_config_manager != NULL)
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
   if(!IsNewBar(m_control_tf))
      return; // Sair se não for um novo candle

   // Verificar se o gerenciador está inicializado
   if(g_config_manager == NULL || !g_config_manager.IsInitialized())
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
   if(m_last_bar_time != current_bar_time)
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

   string current_symbol = Symbol();
   
   // Obter contexto D1 se habilitado
   TF_CTX* D1_ctx = g_config_manager.GetContext(current_symbol, PERIOD_D1);
   if(D1_ctx != NULL)
   {
      D1_ctx.Update();
      
      Print("=== Contexto D1 ===");
      for(int i = 1; i < 5; i++)
      {
         double ema9 = D1_ctx.get_ema9(i);
         double ema21 = D1_ctx.get_ema21(i);
         Print("EMA9 D1 Shift: ", i, " = ", ema9);
         Print("EMA21 D1 Shift: ", i, " = ", ema21);
      }
   }
   else
   {
      Print("AVISO: Contexto D1 não encontrado para símbolo: ", current_symbol);
   }
   
   // Obter contexto H4 se habilitado
   TF_CTX* H4_ctx = g_config_manager.GetContext(current_symbol, PERIOD_H4);
   if(H4_ctx != NULL)
   {
      H4_ctx.Update();
      
      Print("=== Contexto H4 ===");
      for(int i = 1; i < 3; i++)
      {
         double ema9 = H4_ctx.get_ema9(i);
         double sma200 = H4_ctx.get_sma_200(i);
         Print("EMA9 H4 Shift: ", i, " = ", ema9);
         Print("SMA200 H4 Shift: ", i, " = ", sma200);
      }
   }
   else
   {
      Print("AVISO: Contexto H4 não encontrado para símbolo: ", current_symbol);
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
   if(g_config_manager == NULL)
      return false;
      
   // Limpar configuração atual
   g_config_manager.Cleanup();
   
   // Recarregar
   bool success = false;
   if(UseHardcodedConfig)
   {
      success = g_config_manager.Init(HARDCODED_CONFIG);
   }
   else
   {
      success = g_config_manager.InitFromFile(JsonConfigFile);
   }
   
   if(success)
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