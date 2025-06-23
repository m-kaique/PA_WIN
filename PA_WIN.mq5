//+------------------------------------------------------------------+
//|                                                       PA_WIN.mq5 |
//|                                                   Copyright 2025 |
//|                                                 https://mql5.com |
//| 22.06.2025 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link "https://mql5.com"
#property version "1.00"

#include "TF_CTX/tf_ctx.mqh"

TF_CTX *D1_ctx;

// Variáveis para controle de novo candle
datetime m_last_bar_time;     // Tempo do último candle processado
ENUM_TIMEFRAMES m_control_tf; // TimeFrame para controle de novo candle

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   D1_ctx = new TF_CTX(PERIOD_D1, 9);

   // Initialize the TF_CTX object
   if (!D1_ctx.Init())
   {
      Print("ERRO: Falha ao inicializar D1_ctx");
      delete D1_ctx;
      D1_ctx = NULL;
      return (INIT_FAILED);
   }

   // Inicializar controle de novo candle com o mesmo período do contexto
   m_control_tf = PERIOD_D1;
   m_last_bar_time = 0; // Forçar execução no primeiro tick

   Print("D1_ctx inicializado com sucesso");
   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up the TF_CTX object
   if (D1_ctx != NULL)
   {
      delete D1_ctx;
      D1_ctx = NULL;
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

   // Check if D1_ctx is properly initialized
   if (D1_ctx == NULL || !D1_ctx.IsInitialized())
   {
      Print("ERRO: D1_ctx não está inicializado");
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

   D1_ctx.Update();

   for (int i = 1; i < 5; i++)
   {
      double shift = D1_ctx.get_ema21(i);
      Print("MEDIA 21 - D1 Shift: " + (string)i + " --- " + (string)shift);
   }
   // Aqui você pode adicionar toda sua lógica de trading
   // que deve ser executada apenas a cada novo candle
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
//| TesterDeinit function                                            |
//+------------------------------------------------------------------+
void OnTesterDeinit()
{
   //---
}

//+------------------------------------------------------------------+