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

   // === OBTER CONTEXTOS DOS TIMEFRAMES ===
   TF_CTX *ctx_m15 = g_config_manager.GetContext(symbol, PERIOD_M15); // Timeframe principal
   TF_CTX *ctx_m3 = g_config_manager.GetContext(symbol, PERIOD_M3);   // Timeframe de entrada

   if (ctx_m15 == NULL || ctx_m3 == NULL)
   {
      Print(" ========== BERGAMOTAS"); // Log de erro básico
   }

   // === FILTRO 1: ALINHAMENTO DE MÉDIAS EMA em M15 ===
   // Verifica se as médias estão alinhadas em ordem crescente (EMA9 > EMA21 > EMA50)
   CMovingAverages *ema9_m15 = ctx_m15.GetIndicator("ema9");
   CMovingAverages *ema21_m15 = ctx_m15.GetIndicator("ema21");
   CMovingAverages *ema50_m15 = ctx_m15.GetIndicator("ema50");

   if (ema9_m15 == NULL || ema21_m15 == NULL || ema50_m15 == NULL)
   {
      Print("AVISO: Indicadores EMA não encontrados em M15 para CompraAlta");
      return false;
   }

   // Obter valores das médias em M15
   double ema9_value_m15 = ema9_m15.GetValue(1);
   double ema21_value_m15 = ema21_m15.GetValue(1);
   double ema50_value_m15 = ema50_m15.GetValue(1);

   // Verificar alinhamento bullish: EMA9 > EMA21 > EMA50
   bool EMA9_above_EMA21_M15 = (ema9_value_m15 > ema21_value_m15);
   bool EMA21_above_EMA50_M15 = (ema21_value_m15 > ema50_value_m15);

   if (!EMA9_above_EMA21_M15 || !EMA21_above_EMA50_M15)
   {
      return false; // Médias não alinhadas para alta em M15
   }

   // === FILTRO 2: ALINHAMENTO DE MÉDIAS EMA em M3 ===
   // Mesmo critério aplicado ao timeframe de entrada
   CMovingAverages *ema9_m3 = ctx_m3.GetIndicator("ema9");
   CMovingAverages *ema21_m3 = ctx_m3.GetIndicator("ema21");
   CMovingAverages *ema50_m3 = ctx_m3.GetIndicator("ema50");

   if (ema9_m3 == NULL || ema21_m3 == NULL || ema50_m3 == NULL)
   {
      Print("AVISO: Indicadores EMA não encontrados em M3 para CompraAlta");
      return false;
   }

   // Obter valores das médias em M3
   double ema9_value_m3 = ema9_m3.GetValue(1);
   double ema21_value_m3 = ema21_m3.GetValue(1);
   double ema50_value_m3 = ema50_m3.GetValue(1);

   // Verificar alinhamento bullish em M3
   bool EMA9_above_EMA21_M3 = (ema9_value_m3 > ema21_value_m3);
   bool EMA21_above_EMA50_M3 = (ema21_value_m3 > ema50_value_m3);

   if (!EMA9_above_EMA21_M3 || !EMA21_above_EMA50_M3)
   {
      return false; // Médias não alinhadas para alta em M3
   }

   // === FILTRO 3: FORÇA DA TENDÊNCIA ===
   // Verifica se a tendência em M15 é forte o suficiente
   bool strong_trend_m15 = IsStrongTrend(ctx_m15, 0.3, 0.5);
   if (!strong_trend_m15)
   {
      return false; // Tendência fraca demais em M15
   }

   // === FILTRO 4: MOMENTUM BULLISH ===
   // Analisa se há momentum de alta através de price action
   bool bullish_momentum = HasBullishMomentum(ctx_m15, ctx_m3, 3);
   if (!bullish_momentum)
   {
      return false; // Falta momentum para compra
   }

   // === FILTRO 5: AMBIENTE DE VOLATILIDADE ===
   // Verifica se a volatilidade está adequada para trading
   bool good_volatility_m15 = IsGoodVolatilityEnvironment(ctx_m15, 10, 0.7, 1.5);
   if (!good_volatility_m15)
   {
      return false; // Volatilidade inadequada em M15
   }

   // === FILTRO 6: ESTRUTURA DE MERCADO M15 ===
   // Verifica se o contexto maior favorece alta (SMA200)
   bool bullish_structure_m15 = IsInBullishStructure(ctx_m15, 0.5);
   if (!bullish_structure_m15)
   {
      return false; // Estrutura não favorece alta em M15
   }

   // === FILTRO 7: ESTRUTURA DE MERCADO M3 ===
   // Verifica estrutura também no timeframe de entrada
   bool bullish_structure_m3 = IsInBullishStructure(ctx_m3, 0.5);
   if (!bullish_structure_m3)
   {
      return false; // Estrutura não favorece alta em M3
   }

   // === FILTRO 8: ADX M15 ===
   bool strong_trend_adx_m15 = false;
   CADX *adx_m15 = ctx_m15.GetIndicator("ADX15");
   if (adx_m15 != NULL)
   {
      double adx_value = adx_m15.GetValue(1);
      strong_trend_adx_m15 = (adx_value >= 25 && adx_value <= 60);
   }

   if (!strong_trend_adx_m15)
   {
      return false; // ADX não confirma tendência forte
   }

   // === OBTER ATR PARA CÁLCULOS DE ENTRADA ===
   CATR *atr_m3 = ctx_m3.GetIndicator("ATR15");
   double atr_value = atr_m3.GetValue(1);

   // === IDENTIFICAR PONTOS DE ENTRADA ===

   // === ENTRADA 1: Pullback para EMA9 em M3 ===
   // Preço testando a EMA9 como suporte após movimento de alta
   SPositionInfo ema9_m3_position = ema9_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
   bool price_pullback_EMA9_M3 = (ema9_m3_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
                                  ema9_m3_position.position == INDICATOR_CROSSES_LOWER_BODY ||
                                  ema9_m3_position.position == INDICATOR_CROSSES_CENTER_BODY);

   // Validar se o pullback da EMA9 tem qualidade adequada
   bool valid_pullback_EMA9_M3 = IsValidPullback(ema9_m3_position, atr_value, ctx_m3, ema9_m3, 0.8, 3);

   // === ENTRADA 2: Pullback para EMA21 em M3 ===
   // Preço testando a EMA21 como suporte (pullback mais profundo)
   SPositionInfo ema21_m3_position = ema21_m3.GetPositionInfo(1, COPY_MIDDLE, atr_value);
   bool price_pullback_EMA21_M3 = (ema21_m3_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
                                   ema21_m3_position.position == INDICATOR_CROSSES_LOWER_BODY ||
                                   ema21_m3_position.position == INDICATOR_CROSSES_CENTER_BODY);

   // Validar se o pullback da EMA21 tem qualidade adequada
   bool valid_pullback_EMA21_M3 = IsValidPullback(ema21_m3_position, atr_value, ctx_m3, ema21_m3, 0.8, 3);

   // === ENTRADA 3: Teste de EMA50 como suporte em qualquer timeframe ===
   // Busca por testes da EMA50 em todos os timeframes disponíveis
   bool price_tested_EMA50_as_support = false;
   TF_CTX *contexts[];    // Array para armazenar contextos
   ENUM_TIMEFRAMES tfs[]; // Array para armazenar timeframes
   int count = g_config_manager.GetSymbolContexts(symbol, contexts, tfs);

   // Percorrer todos os timeframes disponíveis
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

         // Verificar se EMA50 está sendo testada como suporte
         if (ema50_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
             ema50_position.position == INDICATOR_CROSSES_LOWER_BODY ||
             ema50_position.position == INDICATOR_CROSSES_CENTER_BODY)
         {
            price_tested_EMA50_as_support = true;
            break;
         }
      }
   }

   // === ENTRADA 4: Teste de SMA200 como suporte em qualquer timeframe ===
   // Busca por testes da SMA200 (suporte de longo prazo)
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

         // Verificar se SMA200 está sendo testada como suporte
         if (sma200_position.position == INDICATOR_CROSSES_LOWER_SHADOW ||
             sma200_position.position == INDICATOR_CROSSES_LOWER_BODY ||
             sma200_position.position == INDICATOR_CROSSES_CENTER_BODY)
         {
            price_tested_SMA200_as_support = true;
            break;
         }
      }
   }

   // === ANÁLISE DE INCLINAÇÃO DAS MÉDIAS ===
   // Verificar se as médias de longo prazo estão em tendência de alta

   // Análise da EMA50 M3
   SSlopeValidation ema50_m3_slope = ema50_m3.GetSlopeValidation(atr_m3.GetValue(1), COPY_MIDDLE);
   bool is_ema50_m3_trend_up = ema50_m3_slope.linear_regression.trend_direction == "ALTA" &&
                               ema50_m3_slope.discrete_derivative.trend_direction == "ALTA" &&
                               ema50_m3_slope.simple_difference.trend_direction == "ALTA";

   // Análise da EMA50 M15
   CATR *atr_m15 = ctx_m15.GetIndicator("ATR15");
   SSlopeValidation ema50_m15_slope = ema50_m15.GetSlopeValidation(atr_m15.GetValue(1), COPY_MIDDLE);
   bool is_ema50_m15_trend_up = ema50_m15_slope.linear_regression.trend_direction == "ALTA" &&
                                ema50_m15_slope.discrete_derivative.trend_direction == "ALTA" &&
                                ema50_m15_slope.simple_difference.trend_direction == "ALTA";

   // === CRITÉRIO FINAL DE ENTRADA ===
   // Pelo menos uma das entradas principais deve ser válida
   bool entrada_valida = ((price_pullback_EMA9_M3 && valid_pullback_EMA9_M3) ||
                          (price_pullback_EMA21_M3 && valid_pullback_EMA21_M3));

   // Obter análise de inclinação da SMA200 para logs detalhados
   CMovingAverages *sma200_m15 = ctx_m15.GetIndicator("sma200");
   if (sma200_m15 == NULL)
   {
      return false; // SMA200 é crítica para a análise
   }
   SSlopeValidation sma200_m15_slope = sma200_m15.GetSlopeValidation(atr_m15.GetValue(1), COPY_MIDDLE);

   CMovingAverages *sma200_m3 = ctx_m3.GetIndicator("sma200");
   SSlopeValidation sma200_m3_slope = sma200_m3.GetSlopeValidation(atr_m3.GetValue(1), COPY_MIDDLE);

   if (entrada_valida)
   {
      if (FrancisSocketExists())
      {
         FrancisSocketSendStatus("COMPRA", "COMPRE MERMO", symbol);
      }

      Print("╔═══════════════════════════════════════════════════════════════════════╗");
      Print("║                      📈 SINAL DE COMPRA ALTA DETECTADO                ║");
      Print("║                         SÍMBOLO: ", symbol, StringFormat("%*s", 35 - StringLen(symbol), ""), "║");
      Print("╠═══════════════════════════════════════════════════════════════════════╣");

      // SEÇÃO: VALORES DAS MÉDIAS MÓVEIS
      Print("║ 📊 MÉDIAS MÓVEIS EXPONENCIAIS                                          ║");
      Print("║                                                                       ║");
      Print("║   M15 → EMA9: ", StringFormat("%8.5f", ema9_value_m15),
            " | EMA21: ", StringFormat("%8.5f", ema21_value_m15),
            " | EMA50: ", StringFormat("%8.5f", ema50_value_m15), "  ║");
      Print("║   M3  → EMA9: ", StringFormat("%8.5f", ema9_value_m3),
            " | EMA21: ", StringFormat("%8.5f", ema21_value_m3),
            " | EMA50: ", StringFormat("%8.5f", ema50_value_m3), "  ║");
      Print("║   ATR M3: ", StringFormat("%8.5f", atr_value), StringFormat("%*s", 49, ""), "║");
      Print("║                                                                       ║");

      // SEÇÃO: VALIDAÇÕES DE FILTROS
      Print("║ ✅ VALIDAÇÕES DOS FILTROS PRINCIPAIS                                   ║");
      Print("║                                                                       ║");
      Print("║   [", (EMA9_above_EMA21_M15 ? "✓" : "✗"), "] Alinhamento M15  → EMA9 > EMA21",
            StringFormat("%*s", 32, ""), "║");
      Print("║   [", (EMA21_above_EMA50_M15 ? "✓" : "✗"), "] Alinhamento M15  → EMA21 > EMA50",
            StringFormat("%*s", 31, ""), "║");
      Print("║   [", (EMA9_above_EMA21_M3 ? "✓" : "✗"), "] Alinhamento M3   → EMA9 > EMA21",
            StringFormat("%*s", 32, ""), "║");
      Print("║   [", (EMA21_above_EMA50_M3 ? "✓" : "✗"), "] Alinhamento M3   → EMA21 > EMA50",
            StringFormat("%*s", 31, ""), "║");
      Print("║   [", (strong_trend_m15 ? "✓" : "✗"), "] Força da Tendência M15",
            StringFormat("%*s", 39, ""), "║");
      Print("║   [", (bullish_momentum ? "✓" : "✗"), "] Momentum Bullish",
            StringFormat("%*s", 46, ""), "║");
      Print("║   [", (good_volatility_m15 ? "✓" : "✗"), "] Volatilidade Adequada M15",
            StringFormat("%*s", 36, ""), "║");
      Print("║   [", (bullish_structure_m15 ? "✓" : "✗"), "] Estrutura Bullish M15",
            StringFormat("%*s", 40, ""), "║");
      Print("║   [", (bullish_structure_m3 ? "✓" : "✗"), "] Estrutura Bullish M3",
            StringFormat("%*s", 41, ""), "║");
      Print("║   [", (strong_trend_adx_m15 ? "✓" : "✗"), "] ADX M15 Tendência Forte",
            StringFormat("%*s", 38, ""), "║");
      Print("║                                                                       ║");

      // SEÇÃO: PONTOS DE ENTRADA
      Print("║ 🎯 ANÁLISE DOS PONTOS DE ENTRADA                                       ║");
      Print("║                                                                       ║");
      Print("║   EMA9 M3  → Posição: ", StringFormat("%-15s", EnumToString(ema9_m3_position.position)),
            " | Pullback: [", (price_pullback_EMA9_M3 ? "✓" : "✗"), "] | Válido: [",
            (valid_pullback_EMA9_M3 ? "✓" : "✗"), "]  ║");
      Print("║   EMA21 M3 → Posição: ", StringFormat("%-15s", EnumToString(ema21_m3_position.position)),
            " | Pullback: [", (price_pullback_EMA21_M3 ? "✓" : "✗"), "] | Válido: [",
            (valid_pullback_EMA21_M3 ? "✓" : "✗"), "]  ║");
      Print("║   EMA50    → Teste como suporte (Multi-TF): [",
            (price_tested_EMA50_as_support ? "✓" : "✗"), "]", StringFormat("%*s", 20, ""), "║");
      Print("║   SMA200   → Teste como suporte (Multi-TF): [",
            (price_tested_SMA200_as_support ? "✓" : "✗"), "]", StringFormat("%*s", 19, ""), "║");
      Print("║                                                                       ║");

      // SEÇÃO: ANÁLISE DE INCLINAÇÃO (SLOPES)
      Print("║ 📈 ANÁLISE DE INCLINAÇÃO DAS MÉDIAS                                    ║");
      Print("║                                                                       ║");
      Print("║   EMA50 M3 Slopes:                                                    ║");
      Print("║     • Linear Regression: ", StringFormat("%-8s", ema50_m3_slope.linear_regression.trend_direction),
            StringFormat("%*s", 32, ""), "║");
      Print("║     • Simple Difference: ", StringFormat("%-8s", ema50_m3_slope.simple_difference.trend_direction),
            StringFormat("%*s", 32, ""), "║");
      Print("║     • Discrete Derivative: ", StringFormat("%-8s", ema50_m3_slope.discrete_derivative.trend_direction),
            StringFormat("%*s", 30, ""), "║");
      Print("║                                                                       ║");
      Print("║   EMA50 M15 Slopes:                                                   ║");
      Print("║     • Linear Regression: ", StringFormat("%-8s", ema50_m15_slope.linear_regression.trend_direction),
            StringFormat("%*s", 32, ""), "║");
      Print("║     • Simple Difference: ", StringFormat("%-8s", ema50_m15_slope.simple_difference.trend_direction),
            StringFormat("%*s", 32, ""), "║");
      Print("║     • Discrete Derivative: ", StringFormat("%-8s", ema50_m15_slope.discrete_derivative.trend_direction),
            StringFormat("%*s", 30, ""), "║");
      Print("║                                                                       ║");
      Print("║   SMA200 M3 Slopes:                                                   ║");
      Print("║     • Linear Regression: ", StringFormat("%-8s", sma200_m3_slope.linear_regression.trend_direction),
            StringFormat("%*s", 32, ""), "║");
      Print("║     • Simple Difference: ", StringFormat("%-8s", sma200_m3_slope.simple_difference.trend_direction),
            StringFormat("%*s", 32, ""), "║");
      Print("║     • Discrete Derivative: ", StringFormat("%-8s", sma200_m3_slope.discrete_derivative.trend_direction),
            StringFormat("%*s", 30, ""), "║");
      Print("║                                                                       ║");
      Print("║   SMA200 M15 Slopes:                                                  ║");
      Print("║     • Linear Regression: ", StringFormat("%-8s", sma200_m15_slope.linear_regression.trend_direction),
            StringFormat("%*s", 32, ""), "║");
      Print("║     • Simple Difference: ", StringFormat("%-8s", sma200_m15_slope.simple_difference.trend_direction),
            StringFormat("%*s", 32, ""), "║");
      Print("║     • Discrete Derivative: ", StringFormat("%-8s", sma200_m15_slope.discrete_derivative.trend_direction),
            StringFormat("%*s", 30, ""), "║");
      Print("║                                                                       ║");

      // SEÇÃO: RESUMO FINAL
      Print("║ 🎉 RESULTADO FINAL                                                     ║");
      Print("║                                                                       ║");
      Print("║   STATUS: ✅ ENTRADA VÁLIDA - EXECUTAR COMPRA                          ║");
      Print("║   RAZÃO:  Pullback válido detectado em média móvel                   ║");
      Print("║   AÇÃO:   Posicionar compra conforme gestão de risco                 ║");
      Print("║                                                                       ║");
      Print("╚═══════════════════════════════════════════════════════════════════════╝");
      Print("");
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