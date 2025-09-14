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
            //strategy_ctx.GetStrategyNames(strategy_names);
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

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//+------------------------------------------------------------------+
//| Verificar se a tendência está forte baseada na distância entre médias |
//| Esta função mede a força da tendência comparando as distâncias       |
//| entre as médias móveis em relação ao ATR (volatilidade)              |
//+------------------------------------------------------------------+
bool IsStrongTrend(TF_CTX *ctx, double min_distance_9_21_atr = 0.3, double min_distance_21_50_atr = 0.5)
{
   // Verificação básica se o contexto é válido
   if (ctx == NULL)
      return false;

   // Obter os indicadores necessários do contexto
   CMovingAverages *ema9 = ctx.GetIndicator("ema9");   // Média móvel rápida (9 períodos)
   CMovingAverages *ema21 = ctx.GetIndicator("ema21"); // Média móvel intermediária (21 períodos)
   CMovingAverages *ema50 = ctx.GetIndicator("ema50"); // Média móvel lenta (50 períodos)
   CATR *atr = ctx.GetIndicator("ATR15");              // ATR para medir volatilidade

   // Verificar se todos os indicadores foram carregados corretamente
   if (ema9 == NULL || ema21 == NULL || ema50 == NULL || atr == NULL)
   {
      return false;
   }

   // Obter os valores atuais dos indicadores (barra anterior = índice 1)
   double ema9_val = ema9.GetValue(1);
   double ema21_val = ema21.GetValue(1);
   double ema50_val = ema50.GetValue(1);
   double atr_val = atr.GetValue(1);

   // Se ATR for zero ou negativo, não há volatilidade para medir
   if (atr_val <= 0)
      return false;

   // Calcular as distâncias entre as médias em termos de ATR
   // Isso normaliza a distância pela volatilidade atual do mercado
   double dist_9_21 = MathAbs(ema9_val - ema21_val) / atr_val;   // Distância EMA9-EMA21 / ATR
   double dist_21_50 = MathAbs(ema21_val - ema50_val) / atr_val; // Distância EMA21-EMA50 / ATR

   // Tendência é considerada forte se ambas as distâncias atingirem os valores mínimos
   // Quanto maior a distância, mais separadas estão as médias = tendência mais forte
   bool strong_trend = (dist_9_21 >= min_distance_9_21_atr && dist_21_50 >= min_distance_21_50_atr);

   return strong_trend;
}

//+------------------------------------------------------------------+
//| Verificar momentum bullish através de price action              |
//| Analisa se o preço está mostrando força de alta nos timeframes  |
//| M15 e M3 através de padrões de velas e posição em relação à EMA |
//+------------------------------------------------------------------+
bool HasBullishMomentum(TF_CTX *ctx_m15, TF_CTX *ctx_m3, int lookback_candles = 3)
{
   // Verificação básica dos contextos
   if (ctx_m15 == NULL || ctx_m3 == NULL)
      return false;

   // Obter EMA21 do timeframe M15 para análise
   CMovingAverages *ema21_m15 = ctx_m15.GetIndicator("ema21");
   if (ema21_m15 == NULL)
      return false;

   string symbol = Symbol(); // Símbolo atual do gráfico

   // === CRITÉRIO 1: Verificar se o preço está consistentemente acima da EMA21 no M15 ===
   int candles_above_ema21 = 0;
   for (int i = 1; i <= lookback_candles; i++)
   {
      double close = iClose(symbol, PERIOD_M15, i); // Preço de fechamento da vela
      double ema21_val = ema21_m15.GetValue(i);     // Valor da EMA21 na mesma vela
      if (close > ema21_val)                        // Se fechamento está acima da EMA21
      {
         candles_above_ema21++; // Conta velas acima da média
      }
   }
   // Pelo menos 2 das 3 últimas velas devem estar acima da EMA21
   bool price_above_ema21 = (candles_above_ema21 >= 2);

   // === CRITÉRIO 2: Verificar se não há sinais de pânico de venda (sombras inferiores muito grandes) ===
   bool no_panic_selling = true;
   for (int i = 1; i <= 2; i++) // Analisa as 2 últimas velas do M3
   {
      // Obter dados OHLC da vela
      double open = iOpen(symbol, PERIOD_M3, i);
      double close = iClose(symbol, PERIOD_M3, i);
      double low = iLow(symbol, PERIOD_M3, i);
      double high = iHigh(symbol, PERIOD_M3, i);

      // Calcular dimensões da vela
      double body_size = MathAbs(close - open);         // Tamanho do corpo da vela
      double lower_shadow = MathMin(open, close) - low; // Tamanho da sombra inferior
      double candle_range = high - low;                 // Tamanho total da vela

      if (candle_range > 0)
      {
         // Calcular proporção da sombra inferior em relação ao tamanho total
         double lower_shadow_ratio = lower_shadow / candle_range;
         if (lower_shadow_ratio > 0.6) // Se sombra inferior > 60% da vela
         {
            no_panic_selling = false; // Indica possível pânico de venda
            break;
         }
      }
   }

   // === CRITÉRIO 3: Verificar se a última vela mostra força de alta ===
   double last_open = iOpen(symbol, PERIOD_M3, 1);
   double last_close = iClose(symbol, PERIOD_M3, 1);
   bool last_candle_bullish = (last_close >= last_open); // Vela de alta ou doji de alta

   // Momentum é bullish se todos os critérios forem atendidos
   return price_above_ema21 && no_panic_selling && last_candle_bullish;
}

//+------------------------------------------------------------------+
//| Validar se é um pullback adequado (não muito profundo nem prolongado) |
//| Verifica se o movimento de correção está dentro de parâmetros      |
//| aceitáveis para ser considerado uma oportunidade de entrada        |
//+------------------------------------------------------------------+
bool IsValidPullback(SPositionInfo &position_info, double atr_value, TF_CTX *ctx, CMovingAverages *ma, double max_distance_atr = 0.8, int max_duration_candles = 3)
{
   // Verificações básicas de entrada
   if (ctx == NULL || ma == NULL || atr_value <= 0)
      return false;

   // === CRITÉRIO 1: Verificar se o pullback não é muito profundo ===
   // Se a distância atual for maior que 0.8 ATRs, o pullback é muito profundo
   if (position_info.distance > max_distance_atr * atr_value)
   {
      return false; // Pullback muito profundo - risco de reversão
   }

   // === CRITÉRIO 2: Verificar velocidade do pullback ===
   // Um pullback válido deve vir de uma posição mais afastada da média
   // Isso evita entradas em preços que estão "grudados" na média há muito tempo
   string symbol = Symbol();
   ENUM_TIMEFRAMES tf = ctx.GetTimeFrame();
   bool was_further_away = false;

   // Verificar se nas velas anteriores o preço estava mais distante da média
   for (int i = 2; i <= max_duration_candles + 1; i++)
   {
      double prev_close = iClose(symbol, tf, i);                  // Preço de fechamento anterior
      double prev_ma_value = ma.GetValue(i);                      // Valor da média anterior
      double prev_distance = MathAbs(prev_close - prev_ma_value); // Distância anterior

      // Se a distância anterior era 20% maior que a atual
      if (prev_distance > position_info.distance * 1.2)
      {
         was_further_away = true; // Confirma que houve um movimento de aproximação
         break;
      }
   }

   return was_further_away;
}

//+------------------------------------------------------------------+
//| Analisar ambiente de volatilidade                                |
//| Verifica se a volatilidade atual está em níveis adequados       |
//| para trading, comparando com a volatilidade histórica           |
//+------------------------------------------------------------------+
bool IsGoodVolatilityEnvironment(TF_CTX *ctx, int lookback_periods = 10, double min_volatility_ratio = 0.7, double max_volatility_ratio = 1.5)
{
   // Verificação básica do contexto
   if (ctx == NULL)
      return false;

   // Obter indicador ATR para medir volatilidade
   CATR *atr = ctx.GetIndicator("ATR15");
   if (atr == NULL)
      return false;

   // Obter volatilidade atual
   double current_atr = atr.GetValue(1);
   if (current_atr <= 0)
      return false;

   // === Calcular ATR médio dos últimos períodos para comparação ===
   double sum_atr = 0;
   int valid_periods = 0;

   for (int i = 1; i <= lookback_periods; i++)
   {
      double period_atr = atr.GetValue(i);
      if (period_atr > 0) // Apenas períodos válidos
      {
         sum_atr += period_atr;
         valid_periods++;
      }
   }

   // Se não há dados suficientes, não é possível avaliar
   if (valid_periods < lookback_periods / 2)
   {
      return false;
   }

   // Calcular ATR médio e ratio de volatilidade atual
   double avg_atr = sum_atr / valid_periods;
   double volatility_ratio = current_atr / avg_atr;

   // Volatilidade é adequada se estiver entre 70% e 150% da média histórica
   // Muito baixa = mercado sem movimento, muito alta = mercado muito arriscado
   return (volatility_ratio >= min_volatility_ratio && volatility_ratio <= max_volatility_ratio);
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em estrutura de alta                 |
//| Analisa se o contexto maior (SMA200) favorece operações de alta  |
//+------------------------------------------------------------------+
bool IsInBullishStructure(TF_CTX *ctx, double atr_value)
{
   // Verificação básica do contexto
   if (ctx == NULL)
      return false;

   // Obter indicadores necessários
   CMovingAverages *sma200 = ctx.GetIndicator("sma200"); // Média de longo prazo
   CATR *atr = ctx.GetIndicator("ATR15");                // ATR para normalização

   if (sma200 == NULL || atr == NULL)
      return false;

   string symbol = Symbol();
   ENUM_TIMEFRAMES tf = ctx.GetTimeFrame();

   // Obter dados atuais
   double current_close = iClose(symbol, tf, 1);
   double sma200_val = sma200.GetValue(1);
   double atr_val = atr.GetValue(1);

   if (atr_val <= 0)
      return false;

   // === CRITÉRIO 1: Preço deve estar acima da SMA200 ===
   if (current_close <= sma200_val)
   {
      return false; // Preço abaixo da média de longo prazo = estrutura baixista
   }

   // === CRITÉRIO 2: Preço deve estar a uma distância mínima da SMA200 ===
   // Isso evita falsos sinais quando o preço está muito próximo da média
   double distance_to_sma200 = (current_close - sma200_val) / atr_val;
   if (distance_to_sma200 < atr_value)
   {
      return false; // Muito próximo da SMA200
   }

   // === CRITÉRIO 3: SMA200 deve estar inclinada para cima ===
   // Verifica a direção da tendência de longo prazo
   SSlopeValidation sma200_slope = sma200.GetSlopeValidation(atr_val, COPY_MIDDLE);
   bool sma200_trending_up = (sma200_slope.simple_difference.trend_direction != "BAIXA" ||
                              sma200_slope.discrete_derivative.trend_direction != "BAIXA" ||
                              sma200_slope.linear_regression.trend_direction != "BAIXA");

   return sma200_trending_up;
}

//+------------------------------------------------------------------+
//| Compra em alta                                                   |
//+------------------------------------------------------------------+
bool CompraAlta(string symbol)
{
   // Reestruturado para coletar todos os dados antes de decidir e logar

   // === OBTER CONTEXTOS DOS TIMEFRAMES ===
   TF_CTX *ctx_m15 = g_config_manager.GetContext(symbol, PERIOD_M15); // Timeframe principal
   TF_CTX *ctx_m3 = g_config_manager.GetContext(symbol, PERIOD_M3);   // Timeframe de entrada

   bool have_ctx_m15 = (ctx_m15 != NULL);
   bool have_ctx_m3 = (ctx_m3 != NULL);
   if (!have_ctx_m15 || !have_ctx_m3)
   {
      Print("AVISO: Contextos ausentes em CompraAlta (M15:", have_ctx_m15, ", M3:", have_ctx_m3, ")");
   }

   // === INDICADORES M15 ===
   CMovingAverages *ema9_m15 = have_ctx_m15 ? ctx_m15.GetIndicator("ema9") : NULL;
   CMovingAverages *ema21_m15 = have_ctx_m15 ? ctx_m15.GetIndicator("ema21") : NULL;
   CMovingAverages *ema50_m15 = have_ctx_m15 ? ctx_m15.GetIndicator("ema50") : NULL;
   CATR *atr_m15 = have_ctx_m15 ? ctx_m15.GetIndicator("ATR15") : NULL;

   bool have_m15_emas = (ema9_m15 != NULL && ema21_m15 != NULL && ema50_m15 != NULL);
   if (!have_m15_emas)
      Print("AVISO: Indicadores EMA (M15) ausentes em CompraAlta");

   double ema9_value_m15 = have_m15_emas ? ema9_m15.GetValue(1) : 0.0;
   double ema21_value_m15 = have_m15_emas ? ema21_m15.GetValue(1) : 0.0;
   double ema50_value_m15 = have_m15_emas ? ema50_m15.GetValue(1) : 0.0;

   bool EMA9_above_EMA21_M15 = have_m15_emas ? (ema9_value_m15 > ema21_value_m15) : false;
   bool EMA21_above_EMA50_M15 = have_m15_emas ? (ema21_value_m15 > ema50_value_m15) : false;

   // === INDICADORES M3 ===
   CMovingAverages *ema9_m3 = have_ctx_m3 ? ctx_m3.GetIndicator("ema9") : NULL;
   CMovingAverages *ema21_m3 = have_ctx_m3 ? ctx_m3.GetIndicator("ema21") : NULL;
   CMovingAverages *ema50_m3 = have_ctx_m3 ? ctx_m3.GetIndicator("ema50") : NULL;
   CATR *atr_m3 = have_ctx_m3 ? ctx_m3.GetIndicator("ATR15") : NULL;

   bool have_m3_emas = (ema9_m3 != NULL && ema21_m3 != NULL && ema50_m3 != NULL);
   if (!have_m3_emas)
      Print("AVISO: Indicadores EMA (M3) ausentes em CompraAlta");

   double ema9_value_m3 = have_m3_emas ? ema9_m3.GetValue(1) : 0.0;
   double ema21_value_m3 = have_m3_emas ? ema21_m3.GetValue(1) : 0.0;
   double ema50_value_m3 = have_m3_emas ? ema50_m3.GetValue(1) : 0.0;

   bool EMA9_above_EMA21_M3 = have_m3_emas ? (ema9_value_m3 > ema21_value_m3) : false;
   bool EMA21_above_EMA50_M3 = have_m3_emas ? (ema21_value_m3 > ema50_value_m3) : false;

   double atr_value = (atr_m3 != NULL) ? atr_m3.GetValue(1) : 0.0;
   if (atr_m3 == NULL)
      Print("AVISO: ATR (M3) ausente em CompraAlta");

   // === FILTROS DEPENDENTES ===
   bool strong_trend_m15 = have_ctx_m15 ? IsStrongTrend(ctx_m15, 0.3, 0.5) : false;
   bool bullish_momentum = (have_ctx_m15 && have_ctx_m3) ? HasBullishMomentum(ctx_m15, ctx_m3, 3) : false;
   bool good_volatility_m15 = have_ctx_m15 ? IsGoodVolatilityEnvironment(ctx_m15, 10, 0.7, 1.5) : false;
   bool bullish_structure_m15 = have_ctx_m15 ? IsInBullishStructure(ctx_m15, 0.5) : false;
   bool bullish_structure_m3 = have_ctx_m3 ? IsInBullishStructure(ctx_m3, 0.5) : false;

   bool strong_trend_adx_m15 = false;
   double adx_value_m15 = 0.0;
   if (have_ctx_m15)
   {
      CADX *adx_m15 = ctx_m15.GetIndicator("ADX15");
      if (adx_m15 != NULL)
      {
         adx_value_m15 = adx_m15.GetValue(1);
         strong_trend_adx_m15 = (adx_value_m15 >= 25 && adx_value_m15 <= 60);
      }
   }

   // === PONTOS DE ENTRADA (somente se temos EMAs e ATR no M3) ===
   SPositionInfo ema9_m3_position;
   SPositionInfo ema21_m3_position;
   bool price_pullback_EMA9_M3 = false;
   bool valid_pullback_EMA9_M3 = false;
   bool price_pullback_EMA21_M3 = false;
   bool valid_pullback_EMA21_M3 = false;

   if (have_m3_emas && atr_value > 0.0 && have_ctx_m3)
   {
      ema9_m3_position = ema9_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
      price_pullback_EMA9_M3 = (ema9_m3_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
                                ema9_m3_position.position == INDICATOR_CROSSES_LOWER_BODY ||
                                ema9_m3_position.position == INDICATOR_CROSSES_CENTER_BODY);
      valid_pullback_EMA9_M3 = IsValidPullback(ema9_m3_position, atr_value, ctx_m3, ema9_m3, 0.8, 3);

      ema21_m3_position = ema21_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
      price_pullback_EMA21_M3 = (ema21_m3_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
                                 ema21_m3_position.position == INDICATOR_CROSSES_LOWER_BODY ||
                                 ema21_m3_position.position == INDICATOR_CROSSES_CENTER_BODY);
      valid_pullback_EMA21_M3 = IsValidPullback(ema21_m3_position, atr_value, ctx_m3, ema21_m3, 0.8, 3);
   }

   // === TESTES MULTI-TF ===
   bool price_tested_EMA50_as_support = false;
   bool price_tested_SMA200_as_support = false;
   TF_CTX *contexts[];
   ENUM_TIMEFRAMES tfs[];
   int count = g_config_manager.GetSymbolContexts(symbol, contexts, tfs);
   for (int i = 0; i < count; i++)
   {
      TF_CTX *ctx = contexts[i];
      if (ctx == NULL)
         continue;
      CMovingAverages *ema50 = ctx.GetIndicator("ema50");
      CMovingAverages *sma200 = ctx.GetIndicator("sma200");
      CATR *atr_any = ctx.GetIndicator("ATR15");
      double atr_any_val = (atr_any != NULL) ? atr_any.GetValue(1) : 0.0;
      if (ema50 != NULL && atr_any_val > 0)
      {
         SPositionInfo p = ema50.GetPositionInfo(1, COPY_MIDDLE, atr_any_val);
         if (p.position == INDICATOR_CROSSES_LOWER_SHADOW ||
             p.position == INDICATOR_CROSSES_LOWER_BODY ||
             p.position == INDICATOR_CROSSES_CENTER_BODY)
         {
            price_tested_EMA50_as_support = true;
         }
      }
      if (sma200 != NULL && atr_any_val > 0)
      {
         SPositionInfo p2 = sma200.GetPositionInfo(1, COPY_MIDDLE, atr_any_val);
         if (p2.position == INDICATOR_CROSSES_LOWER_SHADOW ||
             p2.position == INDICATOR_CROSSES_LOWER_BODY ||
             p2.position == INDICATOR_CROSSES_CENTER_BODY)
         {
            price_tested_SMA200_as_support = true;
         }
      }
   }

   // === SLOPES (com verificações) ===
   SSlopeValidation ema50_m3_slope;
   bool has_ema50_m3_slope = (have_m3_emas && atr_m3 != NULL && atr_value > 0);
   if (has_ema50_m3_slope)
      ema50_m3_slope = ema50_m3.GetSlopeValidation(atr_value, COPY_MIDDLE);
   bool is_ema50_m3_trend_up = has_ema50_m3_slope &&
                               ema50_m3_slope.linear_regression.trend_direction == "ALTA" &&
                               ema50_m3_slope.discrete_derivative.trend_direction == "ALTA" &&
                               ema50_m3_slope.simple_difference.trend_direction == "ALTA";

   SSlopeValidation ema50_m15_slope;
   bool has_ema50_m15_slope = (have_m15_emas && atr_m15 != NULL && atr_m15.GetValue(1) > 0);
   if (has_ema50_m15_slope)
      ema50_m15_slope = ema50_m15.GetSlopeValidation(atr_m15.GetValue(1), COPY_MIDDLE);
   bool is_ema50_m15_trend_up = has_ema50_m15_slope &&
                                ema50_m15_slope.linear_regression.trend_direction == "ALTA" &&
                                ema50_m15_slope.discrete_derivative.trend_direction == "ALTA" &&
                                ema50_m15_slope.simple_difference.trend_direction == "ALTA";

   CMovingAverages *sma200_m15 = have_ctx_m15 ? ctx_m15.GetIndicator("sma200") : NULL;
   CMovingAverages *sma200_m3 = have_ctx_m3 ? ctx_m3.GetIndicator("sma200") : NULL;
   SSlopeValidation sma200_m15_slope;
   SSlopeValidation sma200_m3_slope;
   bool has_sma200_m15_slope = (sma200_m15 != NULL && atr_m15 != NULL && atr_m15.GetValue(1) > 0);
   bool has_sma200_m3_slope = (sma200_m3 != NULL && atr_m3 != NULL && atr_value > 0);
   if (has_sma200_m15_slope)
      sma200_m15_slope = sma200_m15.GetSlopeValidation(atr_m15.GetValue(1), COPY_MIDDLE);
   if (has_sma200_m3_slope)
      sma200_m3_slope = sma200_m3.GetSlopeValidation(atr_value, COPY_MIDDLE);

   // === MÉTRICAS PARA DETALHAR FALHAS (valores atuais vs esperados) ===
   double m15_atr_val = (atr_m15 != NULL) ? atr_m15.GetValue(1) : 0.0;
   double dist_9_21_atr = 0.0;
   double dist_21_50_atr = 0.0;
   if (have_m15_emas && m15_atr_val > 0.0)
   {
      dist_9_21_atr = MathAbs(ema9_value_m15 - ema21_value_m15) / m15_atr_val;
      dist_21_50_atr = MathAbs(ema21_value_m15 - ema50_value_m15) / m15_atr_val;
   }

   int m15_candles_above_ema21 = 0;
   bool m3_last_candle_bullish = false;
   double m3_lower_shadow_ratio_max_last2 = 0.0;
   if (have_ctx_m15 && have_ctx_m3 && ema21_m15 != NULL)
   {
      string _sym = Symbol();
      for (int i = 1; i <= 3; i++)
      {
         double c = iClose(_sym, PERIOD_M15, i);
         double e = ema21_m15.GetValue(i);
         if (c > e)
            m15_candles_above_ema21++;
      }
      double lo_ratio_max = 0.0;
      for (int j = 1; j <= 2; j++)
      {
         double o = iOpen(_sym, PERIOD_M3, j);
         double c2 = iClose(_sym, PERIOD_M3, j);
         double l = iLow(_sym, PERIOD_M3, j);
         double h = iHigh(_sym, PERIOD_M3, j);
         double range = h - l;
         double lower = MathMin(o, c2) - l;
         if (range > 0.0)
         {
            double ratio = lower / range;
            if (ratio > lo_ratio_max)
               lo_ratio_max = ratio;
         }
      }
      m3_lower_shadow_ratio_max_last2 = lo_ratio_max;
      double last_o = iOpen(_sym, PERIOD_M3, 1);
      double last_c = iClose(_sym, PERIOD_M3, 1);
      m3_last_candle_bullish = (last_c >= last_o);
   }

   double vol_current_atr = m15_atr_val;
   double vol_avg_atr = 0.0;
   double vol_ratio = 0.0;
   if (atr_m15 != NULL)
   {
      double sum = 0.0;
      int valid = 0;
      for (int k = 1; k <= 10; k++)
      {
         double v = atr_m15.GetValue(k);
         if (v > 0.0)
         {
            sum += v;
            valid++;
         }
      }
      if (valid > 0)
         vol_avg_atr = sum / valid;
      if (vol_avg_atr > 0.0)
         vol_ratio = vol_current_atr / vol_avg_atr;
   }

   double m15_close = 0.0, m3_close = 0.0;
   double m15_sma200_val = 0.0, m3_sma200_val = 0.0;
   double m15_sma200_dist_atr = 0.0, m3_sma200_dist_atr = 0.0;
   if (sma200_m15 != NULL && have_ctx_m15)
   {
      m15_close = iClose(Symbol(), ctx_m15.GetTimeFrame(), 1);
      m15_sma200_val = sma200_m15.GetValue(1);
      if (m15_atr_val > 0.0)
         m15_sma200_dist_atr = (m15_close - m15_sma200_val) / m15_atr_val;
   }
   if (sma200_m3 != NULL && have_ctx_m3)
   {
      double m3_atr_val = (atr_m3 != NULL) ? atr_value : 0.0;
      m3_close = iClose(Symbol(), ctx_m3.GetTimeFrame(), 1);
      m3_sma200_val = sma200_m3.GetValue(1);
      if (m3_atr_val > 0.0)
         m3_sma200_dist_atr = (m3_close - m3_sma200_val) / m3_atr_val;
   }

   // Distância EMA50 ↔ SMA200 (absoluta e normalizada por ATR)
   double dist_ema50_sma200_m15 = 0.0;
   double dist_ema50_sma200_m15_atr = 0.0;
   if (have_m15_emas && sma200_m15 != NULL)
   {
      double sma200_val_m15 = sma200_m15.GetValue(1);
      dist_ema50_sma200_m15 = MathAbs(ema50_value_m15 - sma200_val_m15);
      if (m15_atr_val > 0.0)
         dist_ema50_sma200_m15_atr = dist_ema50_sma200_m15 / m15_atr_val;
   }
   double dist_ema50_sma200_m3 = 0.0;
   double dist_ema50_sma200_m3_atr = 0.0;
   if (have_m3_emas && sma200_m3 != NULL)
   {
      double sma200_val_m3 = sma200_m3.GetValue(1);
      dist_ema50_sma200_m3 = MathAbs(ema50_value_m3 - sma200_val_m3);
      if (atr_value > 0.0)
         dist_ema50_sma200_m3_atr = dist_ema50_sma200_m3 / atr_value;
   }

   // === CRITÉRIO FINAL DE ENTRADA ===
   bool filtros_ok = have_ctx_m15 && have_ctx_m3 && have_m15_emas && have_m3_emas &&
                     (atr_value > 0.0) &&
                     EMA9_above_EMA21_M15 && EMA21_above_EMA50_M15 &&
                     EMA9_above_EMA21_M3 && EMA21_above_EMA50_M3 &&
                     strong_trend_m15 && bullish_momentum && good_volatility_m15 &&
                     bullish_structure_m15 && bullish_structure_m3 &&
                     strong_trend_adx_m15;

   bool entrada_setup_ok = (price_pullback_EMA9_M3 && valid_pullback_EMA9_M3) ||
                           (price_pullback_EMA21_M3 && valid_pullback_EMA21_M3);

   bool entrada_valida = filtros_ok && entrada_setup_ok;

   // === LOG UNIFICADO (sempre) ===
   string titulo_status = entrada_valida ? "✅ COMPRA ALTA — SINAL VÁLIDO" : "❌ COMPRA ALTA — SINAL INVÁLIDO";
   Print("╔═══════════════════════════════════════════════════════════════════════╗");
   Print("║ ", StringFormat("%-67s", titulo_status), "║");
   Print("║                         SÍMBOLO: ", symbol, StringFormat("%*s", 35 - StringLen(symbol), ""), "║");
   Print("╠═══════════════════════════════════════════════════════════════════════╣");

   // SEÇÃO: VALORES DAS MÉDIAS MÓVEIS
   Print("║ 📊 MÉDIAS MÓVEIS EXPONENCIAIS                                          ║");
   Print("║                                                                       ║");
   Print("║   M15 → EMA9: ", have_m15_emas ? StringFormat("%8.5f", ema9_value_m15) : "   N/D  ",
         " | EMA21: ", have_m15_emas ? StringFormat("%8.5f", ema21_value_m15) : "   N/D  ",
         " | EMA50: ", have_m15_emas ? StringFormat("%8.5f", ema50_value_m15) : "   N/D  ", "  ║");
   Print("║   M3  → EMA9: ", have_m3_emas ? StringFormat("%8.5f", ema9_value_m3) : "   N/D  ",
         " | EMA21: ", have_m3_emas ? StringFormat("%8.5f", ema21_value_m3) : "   N/D  ",
         " | EMA50: ", have_m3_emas ? StringFormat("%8.5f", ema50_value_m3) : "   N/D  ", "  ║");
   Print("║   ATR M3: ", (atr_m3 != NULL ? StringFormat("%8.5f", atr_value) : "   N/D  "), StringFormat("%*s", 49, ""), "║");
   Print("║                                                                       ║");

   // SEÇÃO: VALIDAÇÕES DE FILTROS
   Print("║ ✅ VALIDAÇÕES DOS FILTROS PRINCIPAIS                                   ║");
   Print("║                                                                       ║");
   Print("║   [", (EMA9_above_EMA21_M15 ? "✓" : "✗"), "] Alinhamento M15  → EMA9 > EMA21", StringFormat("%*s", 32, ""), "║");
   Print("║   [", (EMA21_above_EMA50_M15 ? "✓" : "✗"), "] Alinhamento M15  → EMA21 > EMA50", StringFormat("%*s", 31, ""), "║");
   Print("║   [", (EMA9_above_EMA21_M3 ? "✓" : "✗"), "] Alinhamento M3   → EMA9 > EMA21", StringFormat("%*s", 32, ""), "║");
   Print("║   [", (EMA21_above_EMA50_M3 ? "✓" : "✗"), "] Alinhamento M3   → EMA21 > EMA50", StringFormat("%*s", 31, ""), "║");
   Print("║   [", (strong_trend_m15 ? "✓" : "✗"), "] Força da Tendência M15", StringFormat("%*s", 39, ""), "║");
   Print("║   [", (bullish_momentum ? "✓" : "✗"), "] Momentum Bullish", StringFormat("%*s", 46, ""), "║");
   Print("║   [", (good_volatility_m15 ? "✓" : "✗"), "] Volatilidade Adequada M15", StringFormat("%*s", 36, ""), "║");
   Print("║   [", (bullish_structure_m15 ? "✓" : "✗"), "] Estrutura Bullish M15", StringFormat("%*s", 40, ""), "║");
   Print("║   [", (bullish_structure_m3 ? "✓" : "✗"), "] Estrutura Bullish M3", StringFormat("%*s", 41, ""), "║");
   Print("║   [", (strong_trend_adx_m15 ? "✓" : "✗"), "] ADX M15 Tendência Forte", StringFormat("%*s", 38, ""), "║");
   Print("║                                                                       ║");

   // SEÇÃO: DETALHES QUANDO INVÁLIDO
   if (!entrada_valida)
   {
      Print("║ 🔎 DETALHES DOS FILTROS (INVÁLIDO)                                     ║");
      Print("║                                                                       ║");
      Print("║   EMA M15: EMA9=", have_m15_emas ? StringFormat("%8.5f", ema9_value_m15) : "N/D",
            " | EMA21=", have_m15_emas ? StringFormat("%8.5f", ema21_value_m15) : "N/D",
            " | EMA50=", have_m15_emas ? StringFormat("%8.5f", ema50_value_m15) : "N/D",
            " | Esperado: EMA9>EMA21>EMA50                               ║");
      Print("║   EMA M3 : EMA9=", have_m3_emas ? StringFormat("%8.5f", ema9_value_m3) : "N/D",
            " | EMA21=", have_m3_emas ? StringFormat("%8.5f", ema21_value_m3) : "N/D",
            " | EMA50=", have_m3_emas ? StringFormat("%8.5f", ema50_value_m3) : "N/D",
            " | Esperado: EMA9>EMA21>EMA50                               ║");
      Print("║   Tendência M15: dist(9-21)=", (m15_atr_val > 0 ? StringFormat("%5.3f", dist_9_21_atr) : "N/D"),
            " (>=0.300) | dist(21-50)=", (m15_atr_val > 0 ? StringFormat("%5.3f", dist_21_50_atr) : "N/D"),
            " (>=0.500)                                               ║");
      Print("║   Momentum: M15 velas acima EMA21=", (string)m15_candles_above_ema21, "/3 (>=2)",
            " | M3 sombra inf. máx (2) = ", StringFormat("%4.2f", m3_lower_shadow_ratio_max_last2), " (<=0.60)",
            " | Última M3 bullish=", (m3_last_candle_bullish ? "Sim" : "Não"), "                ║");
      Print("║   Volatilidade M15: ATR atual=", (vol_current_atr > 0 ? StringFormat("%8.5f", vol_current_atr) : "N/D"),
            " | ATR médio=", (vol_avg_atr > 0 ? StringFormat("%8.5f", vol_avg_atr) : "N/D"),
            " | ratio=", (vol_ratio > 0 ? StringFormat("%5.3f", vol_ratio) : "N/D"), " (0.70→1.50)   ║");
      Print("║   Estrutura M15: close=", (m15_close != 0 ? StringFormat("%8.5f", m15_close) : "N/D"),
            " | SMA200=", (m15_sma200_val != 0 ? StringFormat("%8.5f", m15_sma200_val) : "N/D"),
            " | distATR=", (m15_atr_val > 0 ? StringFormat("%5.3f", m15_sma200_dist_atr) : "N/D"), " (>", StringFormat("%4.2f", 0.5), ")      ║");
      Print("║   Estrutura M3 : close=", (m3_close != 0 ? StringFormat("%8.5f", m3_close) : "N/D"),
            " | SMA200=", (m3_sma200_val != 0 ? StringFormat("%8.5f", m3_sma200_val) : "N/D"),
            " | distATR=", (atr_value > 0 ? StringFormat("%5.3f", m3_sma200_dist_atr) : "N/D"), " (>", StringFormat("%4.2f", 0.5), ")      ║");
      Print("║   ADX M15: valor=", (adx_value_m15 > 0 ? StringFormat("%5.2f", adx_value_m15) : "N/D"),
            " (25→60)                                                    ║");
      Print("║   EMA50↔SMA200: M15 |Δ|=", (dist_ema50_sma200_m15 > 0 ? StringFormat("%8.5f", dist_ema50_sma200_m15) : "N/D"),
            " | Δ/ATR=", (dist_ema50_sma200_m15_atr > 0 ? StringFormat("%5.3f", dist_ema50_sma200_m15_atr) : "N/D"),
            " | M3 |Δ|=", (dist_ema50_sma200_m3 > 0 ? StringFormat("%8.5f", dist_ema50_sma200_m3) : "N/D"),
            " | Δ/ATR=", (dist_ema50_sma200_m3_atr > 0 ? StringFormat("%5.3f", dist_ema50_sma200_m3_atr) : "N/D"), "             ║");
      Print("║                                                                       ║");
   }

   // SEÇÃO: PONTOS DE ENTRADA
   Print("║ 🎯 ANÁLISE DOS PONTOS DE ENTRADA                                       ║");
   Print("║                                                                       ║");
   if (have_m3_emas && atr_value > 0.0)
   {
      Print("║   EMA9 M3  → Posição: ", StringFormat("%-15s", EnumToString(ema9_m3_position.position)),
            " | Pullback: [", (price_pullback_EMA9_M3 ? "✓" : "✗"), "] | Válido: [",
            (valid_pullback_EMA9_M3 ? "✓" : "✗"), "]  ║");
      Print("║   EMA21 M3 → Posição: ", StringFormat("%-15s", EnumToString(ema21_m3_position.position)),
            " | Pullback: [", (price_pullback_EMA21_M3 ? "✓" : "✗"), "] | Válido: [",
            (valid_pullback_EMA21_M3 ? "✓" : "✗"), "]  ║");
   }
   else
   {
      Print("║   EMA9 M3  → Posição: N/D | Pullback: [✗] | Válido: [✗]               ║");
      Print("║   EMA21 M3 → Posição: N/D | Pullback: [✗] | Válido: [✗]               ║");
   }
   Print("║   EMA50    → Teste como suporte (Multi-TF): [", (price_tested_EMA50_as_support ? "✓" : "✗"), "]", StringFormat("%*s", 20, ""), "║");
   Print("║   SMA200   → Teste como suporte (Multi-TF): [", (price_tested_SMA200_as_support ? "✓" : "✗"), "]", StringFormat("%*s", 19, ""), "║");
   Print("║                                                                       ║");

   // SEÇÃO: ANÁLISE DE INCLINAÇÃO (SLOPES)
   Print("║ 📈 ANÁLISE DE INCLINAÇÃO DAS MÉDIAS                                    ║");
   Print("║                                                                       ║");
   Print("║   Distância EMA50↔SMA200 M15: |Δ|=", (dist_ema50_sma200_m15 > 0 ? StringFormat("%8.5f", dist_ema50_sma200_m15) : "   N/D  "),
         " | Δ/ATR=", (dist_ema50_sma200_m15_atr > 0 ? StringFormat("%5.3f", dist_ema50_sma200_m15_atr) : " N/D"), StringFormat("%*s", 14, ""), "║");
   Print("║   Distância EMA50↔SMA200 M3 : |Δ|=", (dist_ema50_sma200_m3 > 0 ? StringFormat("%8.5f", dist_ema50_sma200_m3) : "   N/D  "),
         " | Δ/ATR=", (dist_ema50_sma200_m3_atr > 0 ? StringFormat("%5.3f", dist_ema50_sma200_m3_atr) : " N/D"), StringFormat("%*s", 14, ""), "║");
   Print("║                                                                       ║");
   if (has_ema50_m3_slope)
   {
      Print("║   EMA50 M3 Slopes:                                                    ║");
      Print("║     • Linear Regression: ", StringFormat("%-8s", ema50_m3_slope.linear_regression.trend_direction), StringFormat("%*s", 32, ""), "║");
      Print("║     • Simple Difference: ", StringFormat("%-8s", ema50_m3_slope.simple_difference.trend_direction), StringFormat("%*s", 32, ""), "║");
      Print("║     • Discrete Derivative: ", StringFormat("%-8s", ema50_m3_slope.discrete_derivative.trend_direction), StringFormat("%*s", 30, ""), "║");
   }
   else
   {
      Print("║   EMA50 M3 Slopes: N/D                                               ║");
   }
   Print("║                                                                       ║");
   if (has_ema50_m15_slope)
   {
      Print("║   EMA50 M15 Slopes:                                                   ║");
      Print("║     • Linear Regression: ", StringFormat("%-8s", ema50_m15_slope.linear_regression.trend_direction), StringFormat("%*s", 32, ""), "║");
      Print("║     • Simple Difference: ", StringFormat("%-8s", ema50_m15_slope.simple_difference.trend_direction), StringFormat("%*s", 32, ""), "║");
      Print("║     • Discrete Derivative: ", StringFormat("%-8s", ema50_m15_slope.discrete_derivative.trend_direction), StringFormat("%*s", 30, ""), "║");
   }
   else
   {
      Print("║   EMA50 M15 Slopes: N/D                                              ║");
   }
   Print("║                                                                       ║");
   if (has_sma200_m3_slope)
   {
      Print("║   SMA200 M3 Slopes:                                                   ║");
      Print("║     • Linear Regression: ", StringFormat("%-8s", sma200_m3_slope.linear_regression.trend_direction), StringFormat("%*s", 32, ""), "║");
      Print("║     • Simple Difference: ", StringFormat("%-8s", sma200_m3_slope.simple_difference.trend_direction), StringFormat("%*s", 32, ""), "║");
      Print("║     • Discrete Derivative: ", StringFormat("%-8s", sma200_m3_slope.discrete_derivative.trend_direction), StringFormat("%*s", 30, ""), "║");
   }
   else
   {
      Print("║   SMA200 M3 Slopes: N/D                                              ║");
   }
   Print("║                                                                       ║");
   if (has_sma200_m15_slope)
   {
      Print("║   SMA200 M15 Slopes:                                                  ║");
      Print("║     • Linear Regression: ", StringFormat("%-8s", sma200_m15_slope.linear_regression.trend_direction), StringFormat("%*s", 32, ""), "║");
      Print("║     • Simple Difference: ", StringFormat("%-8s", sma200_m15_slope.simple_difference.trend_direction), StringFormat("%*s", 32, ""), "║");
      Print("║     • Discrete Derivative: ", StringFormat("%-8s", sma200_m15_slope.discrete_derivative.trend_direction), StringFormat("%*s", 30, ""), "║");
   }
   else
   {
      Print("║   SMA200 M15 Slopes: N/D                                             ║");
   }
   Print("║                                                                       ║");

   // SEÇÃO: RESUMO FINAL
   Print("║ 🎉 RESULTADO FINAL                                                     ║");
   Print("║                                                                       ║");
   if (entrada_valida)
   {
      Print("║   STATUS: ✅ ENTRADA VÁLIDA - EXECUTAR COMPRA                          ║");
      Print("║   RAZÃO:  Pullback válido detectado em média móvel                   ║");
      Print("║   AÇÃO:   Posicionar compra conforme gestão de risco                 ║");
   }
   else
   {
      Print("║   STATUS: ❌ ENTRADA INVÁLIDA                                          ║");
      Print("║   RAZÃO:  Um ou mais filtros não foram atendidos                     ║");
      Print("║   AÇÃO:   Aguardar novo setup                                        ║");
   }
   Print("║                                                                       ║");
   Print("╚═══════════════════════════════════════════════════════════════════════╝");
   Print("");

   // Disparo de socket somente quando válido
   if (entrada_valida && FrancisSocketExists())
   {
      FrancisSocketSendStatus("COMPRA", "COMPRE MERMO", symbol);
   }

   return entrada_valida;
}

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

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