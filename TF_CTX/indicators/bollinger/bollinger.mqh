//+------------------------------------------------------------------+
//|                                    indicators/bollinger.mqh      |
//|  Bollinger Bands indicator derived from CIndicatorBase           |
//+------------------------------------------------------------------+
#ifndef __BOLLINGER_MQH__
#define __BOLLINGER_MQH__

#include "../indicator_base/indicator_base.mqh"
#include "../indicators_types.mqh"
#include "bollinger_defs.mqh"

class CBollinger : public CIndicatorBase
{
private:
  int m_period;
  int m_shift;
  double m_deviation;
  ENUM_APPLIED_PRICE m_price;
  double width_array[];

  // Configurable parameters
  int m_width_history;
  int m_width_lookback;
  int m_slope_lookback;
  int m_percentile_thresholds[4];
  double m_weights[3]; // band, slope, width

  // Width calculation optimization
  bool m_width_data_dirty;
  double m_cached_percentile;
  double m_cached_zscore;
  int m_cached_lookback;

  bool CreateHandle();
  void ReleaseHandle();
  double GetBufferValue(int buffer_index, int shift = 0);
  void CalculateWidths();
  static double CalculateWidthZScore(const double &width_array[], int length, int lookback);
  static double CalculateWidthPercentile(const double &width_array[], int length, int lookback);
  ENUM_WIDTH_REGION ClassifyWidthRegion(double percentile);
  static ENUM_MARKET_PHASE MapRegionToPhase(ENUM_WIDTH_REGION region);
  SSlopeResult CalculateWidthSlopeLinearRegression(double atr, int lookback);
  SSlopeResult CalculateWidthSlopeSimpleDifference(double atr, int lookback);
  SSlopeResult CalculateWidthSlopeDiscreteDerivative(double atr, int lookback);
  static ENUM_SLOPE_STATE ClassifySlopeState(double slope_value, double threshold);
  virtual bool OnCopyValuesForSlope(int shift, int count, double &buffer[], COPY_METHOD copy_method) override;

  // New helper methods for enhanced signal computation
  double CalculatePositionStrength();
  double GetBandConvergence(double atr);
  bool DetectSqueeze(double threshold);
  double CalculateWeightedDirectionConsensus(const SSlopeValidation &upper, const SSlopeValidation &middle, const SSlopeValidation &lower);
  double CalculateIntegratedConfidence(double direction_score, double slope_strength, double width_modifier, double position_strength, double convergence_factor, bool is_squeeze);
  string BuildEnhancedReason(int up_count, int down_count, int neutral_count, ENUM_WIDTH_REGION region, ENUM_SLOPE_STATE slope_state, double position_strength, double convergence_factor, bool is_squeeze);

  // New helper methods for parameter refinement
  void ValidateAndCorrectParameters();
  void AdaptParametersToMarket(double atr);
  void LoadPresetForSymbol(string symbol);

  // New helper methods for width calculation optimization
  bool IsWidthDataValid();
  int GetOptimalLookback();
  void CacheWidthStats();

  // New helper method for WIN$N timeframe calibration
  void CalibrateForWinIndex(ENUM_TIMEFRAMES timeframe);

public:
  SCombinedSignal ComputeCombinedSignal(double atr, int lookback, double threshold);
  virtual double OnGetIndicatorValue(int shift, COPY_METHOD copy_method) override;
  virtual int OnGetSlopeConfigIndex(COPY_METHOD copy_method) override;

public:
  CBollinger();
  ~CBollinger();

  bool Init(string symbol, ENUM_TIMEFRAMES timeframe,
            int period, int shift, double deviation,
            ENUM_APPLIED_PRICE price);

  bool Init(string symbol, ENUM_TIMEFRAMES timeframe,
            CBollingerConfig &config);

  // Compatibilidade com interface base
  virtual bool Init(string symbol, ENUM_TIMEFRAMES timeframe,
                    int period, ENUM_MA_METHOD method);

  virtual double GetValue(int shift = 0); // Middle band
  double GetUpper(int shift = 0);
  double GetLower(int shift = 0);

  virtual bool CopyValues(int shift, int count, double &buffer[]); // middle
  bool CopyUpper(int shift, int count, double &buffer[]);
  bool CopyLower(int shift, int count, double &buffer[]);

  virtual bool IsReady();
  virtual bool Update() override;

  // Set configurable parameters
  void SetConfigurableParameters(int width_history, int width_lookback, int slope_lookback,
                                 int &percentile_thresholds[], double &weights[]);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBollinger::CBollinger()
{
  m_symbol = "";
  m_timeframe = PERIOD_CURRENT;
  m_period = 20;
  m_shift = 0;
  m_deviation = 2.0;
  m_price = PRICE_CLOSE;
  handle = INVALID_HANDLE;

  // Initialize configurable parameters with defaults
  m_width_history = WIDTH_HISTORY;
  m_width_lookback = WIDTH_LOOKBACK;
  m_slope_lookback = SLOPE_LOOKBACK;
  m_percentile_thresholds[0] = PERCENTILE_THRESHOLD_VERY_NARROW;
  m_percentile_thresholds[1] = PERCENTILE_THRESHOLD_NARROW;
  m_percentile_thresholds[2] = PERCENTILE_THRESHOLD_NORMAL;
  m_percentile_thresholds[3] = PERCENTILE_THRESHOLD_WIDE;
  m_weights[0] = WEIGHT_BAND;
  m_weights[1] = WEIGHT_SLOPE;
  m_weights[2] = WEIGHT_WIDTH;

  // Initialize width calculation cache
  m_width_data_dirty = true;
  m_cached_percentile = 0.0;
  m_cached_zscore = 0.0;
  m_cached_lookback = 0;

  ArrayResize(width_array, m_width_history);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBollinger::~CBollinger()
{
  ReleaseHandle();
}

//+------------------------------------------------------------------+
//| Init with full parameters                                        |
//+------------------------------------------------------------------+
bool CBollinger::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                      int period, int shift, double deviation,
                      ENUM_APPLIED_PRICE price)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_period = period;
   m_shift = shift;
   m_deviation = deviation;
   m_price = price;

   // Auto-calibrate for WIN$N symbols based on timeframe
   if (StringFind(m_symbol, "WIN") >= 0)
      CalibrateForWinIndex(m_timeframe);

   ReleaseHandle();
   return CreateHandle();
}

//+------------------------------------------------------------------+
//| Interface base implementation (uses defaults)                    |
//+------------------------------------------------------------------+
bool CBollinger::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                      int period, ENUM_MA_METHOD method)
{
  // method parameter not used; default shift 0, deviation 2, PRICE_CLOSE
  return Init(symbol, timeframe, period, 0, 2.0, PRICE_CLOSE);
}

bool CBollinger::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                      CBollingerConfig &config)
{
   attach_chart = config.attach_chart;
   ArrayCopy(slope_values, config.slope_values);

   // Set configurable parameters from config
   m_width_history = config.width_history;
   m_width_lookback = config.width_lookback;
   m_slope_lookback = config.slope_lookback;
   ArrayCopy(m_percentile_thresholds, config.percentile_thresholds);
   ArrayCopy(m_weights, config.weights);

   // Validate and apply presets
   ValidateAndCorrectParameters();
   LoadPresetForSymbol(symbol);

   return Init(symbol, timeframe, config.period, config.shift,
               config.deviation, config.applied_price);
}

//+------------------------------------------------------------------+
//| Create indicator handle                                          |
//+------------------------------------------------------------------+
bool CBollinger::CreateHandle()
{
  handle = iBands(m_symbol, m_timeframe, m_period, m_shift, m_deviation, m_price);
  if (handle == INVALID_HANDLE)
  {
    //Print("ERRO: Falha ao criar handle Bollinger para ", m_symbol);
    return false;
  }
  return true;
}

//+------------------------------------------------------------------+
//| Release handle                                                   |
//+------------------------------------------------------------------+
void CBollinger::ReleaseHandle()
{
  if (handle != INVALID_HANDLE)
  {
    IndicatorRelease(handle);
    handle = INVALID_HANDLE;
  }
}

//+------------------------------------------------------------------+
//| Get buffer value                                                 |
//+------------------------------------------------------------------+
double CBollinger::GetBufferValue(int buffer_index, int shift)
{
  if (handle == INVALID_HANDLE)
    return 0.0;
  double buf[];
  ArraySetAsSeries(buf, true);
  if (CopyBuffer(handle, buffer_index, shift, 1, buf) <= 0)
    return 0.0;
  return buf[0];
}

//+------------------------------------------------------------------+
//| Middle band (buffer 2)                                           |
//+------------------------------------------------------------------+
double CBollinger::GetValue(int shift)
{
  return GetBufferValue(BASE_LINE, shift);
}

//+------------------------------------------------------------------+
//| Upper band (buffer 0)                                            |
//+------------------------------------------------------------------+
double CBollinger::GetUpper(int shift)
{
  return GetBufferValue(UPPER_BAND, shift);
}

//+------------------------------------------------------------------+
//| Lower band (buffer 1)                                            |
//+------------------------------------------------------------------+
double CBollinger::GetLower(int shift)
{
  return GetBufferValue(LOWER_BAND, shift);
}

//+------------------------------------------------------------------+
//| Copy middle band values                                          |
//+------------------------------------------------------------------+
bool CBollinger::CopyValues(int shift, int count, double &buffer[])
{
  if (handle == INVALID_HANDLE)
    return false;
  ArrayResize(buffer, count);
  ArraySetAsSeries(buffer, true);
  return CopyBuffer(handle, BASE_LINE, shift, count, buffer) > 0;
}

//+------------------------------------------------------------------+
//| Copy upper band values                                           |
//+------------------------------------------------------------------+
bool CBollinger::CopyUpper(int shift, int count, double &buffer[])
{
  // 0 - BASE_LINE, 1 - UPPER_BAND, 2 - LOWER_BAND
  if (handle == INVALID_HANDLE)
    return false;
  ArrayResize(buffer, count);
  ArraySetAsSeries(buffer, true);
  return CopyBuffer(handle, UPPER_BAND, shift, count, buffer) > 0;
}

//+------------------------------------------------------------------+
//| Copy lower band values                                           |
//+------------------------------------------------------------------+
bool CBollinger::CopyLower(int shift, int count, double &buffer[])
{
  if (handle == INVALID_HANDLE)
    return false;
  ArrayResize(buffer, count);
  ArraySetAsSeries(buffer, true);
  return CopyBuffer(handle, LOWER_BAND, shift, count, buffer) > 0;
}

//+------------------------------------------------------------------+
//| Check readiness                                                  |
//+------------------------------------------------------------------+
bool CBollinger::IsReady()
{
  return (BarsCalculated(handle) > 0);
}

//+------------------------------------------------------------------+
//| Recreate handle if necessary                                      |
//+------------------------------------------------------------------+
bool CBollinger::Update()
{
   if (handle == INVALID_HANDLE)
      return CreateHandle();

   if (BarsCalculated(handle) <= 0)
      return false;

   // Mark width data as dirty for recalculation with new bars
   m_width_data_dirty = true;
   CalculateWidths();
   return true;
}

//+------------------------------------------------------------------+
//| Implementação do método template para copiar valores para o cálculo de inclinação |
//+------------------------------------------------------------------+
bool CBollinger::OnCopyValuesForSlope(int shift, int count, double &buffer[], COPY_METHOD copy_method)
{
  if (handle == INVALID_HANDLE)
    return false;

    //Print("METODO DE COPIA: " + EnumToString(copy_method));
  switch (copy_method)
  { 
    case COPY_LOWER:
  //Print("COPIANDO - LOWER");
    return CopyLower(shift, count, buffer);

  case COPY_UPPER:
    //Print("COPIANDO - UPPER");
    return CopyUpper(shift, count, buffer);

  case COPY_MIDDLE:
    //Print("COPIANDO - MIDDLE");
    return CopyValues(shift, count, buffer);

  default:
    //Print("ERRO: Método de cópia inválido");
    return false;
  }
};

//+------------------------------------------------------------------+
//| Implementação do método template para obter o valor do indicador |
//+------------------------------------------------------------------+
double CBollinger::OnGetIndicatorValue(int shift, COPY_METHOD copy_method)
{  //Print("OnGetIndicatorValue bollinger class: " + EnumToString(copy_method));
  //Print("OnGetIndicatorValue bollinger class: " + (string)(copy_method));
  if (copy_method == COPY_LOWER)
  {
    return GetLower(shift);
  }
  else if (copy_method == COPY_UPPER)
  {
    return GetUpper(shift);
  }
  else
  {
    return GetValue(shift);
  }
}

int CBollinger::OnGetSlopeConfigIndex(COPY_METHOD copy_method)
{

  if (copy_method == COPY_MIDDLE)
  {
    //Print("RETORNANDO MIDDLE");
    return 1;
  }
  else if (copy_method == COPY_UPPER)
  {
        //Print("RETORNANDO UPPER");
    return 0;
  }
  else if (copy_method == COPY_LOWER)
  {
        //Print("RETORNANDO LOWER");
    return 2;
  }

  return 1;
}

//+------------------------------------------------------------------+
//| Calculate width of bands for each bar                            |
//+------------------------------------------------------------------+
void CBollinger::CalculateWidths()
{
   if (!m_width_data_dirty) return; // Skip recalculation if data is clean

   ArrayResize(width_array, m_width_history);

   for(int i = 0; i < m_width_history; i++)
   {
      double upper = GetUpper(i);
      double lower = GetLower(i);
      width_array[i] = (upper > lower && MathIsValidNumber(upper) && MathIsValidNumber(lower)) ?
                       upper - lower : 0.0;
   }

   // Mark data as clean and update cache
   m_width_data_dirty = false;
   CacheWidthStats();
}

//+------------------------------------------------------------------+
//| Calculate Z-score of the most recent width                       |
//| FÓRMULA MATEMÁTICA: Z-score = (valor_atual - média) / desvio_padrão |
//| LÓGICA: Mede quantos desvios padrão o valor atual está da média histórica |
//| INTERPRETAÇÃO: Z > 0 = acima da média, Z < 0 = abaixo da média |
//| EXEMPLO: Z = 2.0 significa valor 2 desvios acima da média (evento raro) |
double CBollinger::CalculateWidthZScore(const double &width_array[], int length, int lookback)
{
   // VALIDAÇÃO: Z-score precisa de pelo menos 1 valor, mas estatisticamente 2+ é melhor
   if (length < 1 || lookback < 1) return 0.0; // Retorna neutro se dados insuficientes

   int actual_lookback = MathMin(lookback, length); // Limita ao tamanho disponível

   // CÁLCULO DA MÉDIA ARITMÉTICA: Soma todos os valores e divide por quantidade
   // FÓRMULA: média = Σ(valores) / n
   double sum = 0.0;
   for(int i = 0; i < actual_lookback; i++)
     sum += width_array[i];
   double mean = sum / actual_lookback;

   // CÁLCULO DA VARIÂNCIA: Mede dispersão dos dados em torno da média
   // FÓRMULA: variância = Σ(diferenças_ao_quadrado) / n
   // ONDE: diferença = valor - média
   double sum_sq = 0.0;
   for(int i = 0; i < actual_lookback; i++)
   {
     double diff = width_array[i] - mean;     // Diferença em relação à média
     sum_sq += diff * diff;                    // Soma dos quadrados das diferenças
   }
   double variance = sum_sq / actual_lookback; // Variância populacional

   // DESVIO PADRÃO: Raiz quadrada da variância (mede volatilidade)
   // FÓRMULA: σ = √(variância)
   double std = MathSqrt(variance);

   // PREVENÇÃO DE DIVISÃO POR ZERO: Se todos os valores são iguais
   if (std == 0.0) return 0.0; // Z-score = 0 (valor na média)

   // CÁLCULO FINAL DO Z-SCORE
   double current = width_array[0]; // Valor mais recente
   return (current - mean) / std;   // Normalização: quantos σ o valor está da média
}

//+------------------------------------------------------------------+
//| Calculate percentile of the most recent width (improved with sorting) |
//| FÓRMULA MATEMÁTICA: Percentil = [posição_ordenada / (n-1)] × 100 |
//| LÓGICA: Ordena histórico de larguras e encontra posição relativa do valor atual |
//| INTERPOLAÇÃO: Para valores entre posições, usa interpolação linear |
//| EXEMPLO: Se valor atual é 3º em array de 10 elementos → percentil = (3/9)×100 = 33.33% |
double CBollinger::CalculateWidthPercentile(const double &width_array[], int length, int lookback)
{
    // VALIDAÇÃO ESTATÍSTICA: Percentil precisa de mínimo 2 valores para distribuição válida
    if (length < 2 || lookback < 2) return 50.0; // Retorna mediana (50%) como valor padrão

    int actual_lookback = MathMin(lookback, length); // Garante não ultrapassar tamanho do array
    if (actual_lookback < 2) return 50.0;

    // CRIAÇÃO DE CÓPIA ORDENADA: Preserva array original para outros cálculos
    // Array ordenado necessário para cálculo preciso de percentil
    double sorted[];
    ArrayResize(sorted, actual_lookback);
    ArrayCopy(sorted, width_array, 0, 0, actual_lookback);

    // ALGORITMO DE ORDENAÇÃO: Bubble Sort O(n²) - aceitável para arrays pequenos (< 200 elementos)
    // ORDENAÇÃO CRESCENTE: Valores menores primeiro, maiores depois
    for(int i = 0; i < actual_lookback - 1; i++)
    {
       for(int j = i + 1; j < actual_lookback; j++)
       {
          if (sorted[i] > sorted[j])
          {
             // TROCA DE ELEMENTOS: Move valores maiores para posições posteriores
             double temp = sorted[i];
             sorted[i] = sorted[j];
             sorted[j] = temp;
          }
       }
    }

    double current = width_array[0]; // Valor mais recente (candle atual)

    // BUSCA SEQUENCIAL: Encontra posição do valor atual na distribuição ordenada
    // Complexidade O(n) mas array pequeno justifica abordagem simples
    int pos = 0;
    while (pos < actual_lookback && sorted[pos] < current) pos++;

    // TRATAMENTO DE CASOS EXTREMOS:
    if (pos == 0) return 0.0;                    // Valor menor que todos = percentil mínimo
    if (pos >= actual_lookback) return 100.0;    // Valor maior que todos = percentil máximo

    // CÁLCULO DE PERCENTIL COM INTERPOLAÇÃO:
    if (sorted[pos] == current)
    {
       // CORRESPONDÊNCIA EXATA: Cálculo direto da posição relativa
       // FÓRMULA: percentil = (posição_encontrada / total_posições) × 100
       // NOTA: Divide por (n-1) para normalização correta
       return (double)pos / (actual_lookback - 1) * 100.0;
    }
    else
    {
       // INTERPOLAÇÃO LINEAR: Valor entre duas posições ordenadas
       // FÓRMULA: percentil = [(posição - 1) + fração_interpolada] / (n-1) × 100
       // ONDE: fração = (valor_atual - valor_inferior) / (valor_superior - valor_inferior)
       double lower = sorted[pos-1];    // Valor na posição anterior
       double upper = sorted[pos];      // Valor na posição atual
       double fraction = (current - lower) / (upper - lower); // Fração linear entre posições
       return ((pos - 1 + fraction) / (actual_lookback - 1)) * 100.0;
    }
}

//+------------------------------------------------------------------+
//| Classify width region based on percentile                        |
//+------------------------------------------------------------------+
ENUM_WIDTH_REGION CBollinger::ClassifyWidthRegion(double percentile)
{
  if (percentile < m_percentile_thresholds[0]) return WIDTH_VERY_NARROW;
  if (percentile >= m_percentile_thresholds[0] && percentile < m_percentile_thresholds[1]) return WIDTH_NARROW;
  if (percentile >= m_percentile_thresholds[1] && percentile < m_percentile_thresholds[2]) return WIDTH_NORMAL;
  if (percentile >= m_percentile_thresholds[2] && percentile < m_percentile_thresholds[3]) return WIDTH_WIDE;
  return WIDTH_VERY_WIDE;
}

//+------------------------------------------------------------------+
//| Map width region to market phase                                 |
//+------------------------------------------------------------------+
ENUM_MARKET_PHASE CBollinger::MapRegionToPhase(ENUM_WIDTH_REGION region)
{
  if (region == WIDTH_VERY_NARROW || region == WIDTH_NARROW) return PHASE_CONTRACTION;
  if (region == WIDTH_NORMAL) return PHASE_NORMAL;
  return PHASE_EXPANSION;
}

//+------------------------------------------------------------------+
//| Calculate width slope using linear regression                    |
//+------------------------------------------------------------------+
SSlopeResult CBollinger::CalculateWidthSlopeLinearRegression(double atr, int lookback)
{
  return m_slope.CalculateLinearRegressionSlope(m_symbol, width_array, atr, lookback);
}

//+------------------------------------------------------------------+
//| Calculate width slope using simple difference                    |
//+------------------------------------------------------------------+
SSlopeResult CBollinger::CalculateWidthSlopeSimpleDifference(double atr, int lookback)
{
  return m_slope.CalculateSimpleDifference(m_symbol, width_array, atr, lookback);
}

//+------------------------------------------------------------------+
//| Calculate width slope using discrete derivative                  |
//+------------------------------------------------------------------+
SSlopeResult CBollinger::CalculateWidthSlopeDiscreteDerivative(double atr, int lookback)
{
  return m_slope.CalculateDiscreteDerivative(m_symbol, width_array, atr, lookback);
}

//+------------------------------------------------------------------+
//| Classify slope state based on threshold                          |
//+------------------------------------------------------------------+
ENUM_SLOPE_STATE CBollinger::ClassifySlopeState(double slope_value, double threshold)
{
  if (slope_value >= threshold) return SLOPE_EXPANDING;
  if (slope_value <= -threshold) return SLOPE_CONTRACTING;
  return SLOPE_STABLE;
}

//+------------------------------------------------------------------+
//| ComputeCombinedSignal - Cálculo Aprimorado de Sinal Combinado    |
//| Propósito: Determinar direção (BULL/BEAR/NEUTRAL) com confiança |
//| Melhorias implementadas:                                         |
//| - Análise ponderada das três bandas (superior/média/inferior)   |
//| - Cálculo de confiança baseado em múltiplos fatores            |
//| - Detecção de squeeze e expansão das bandas                     |
//+------------------------------------------------------------------+
SCombinedSignal CBollinger::ComputeCombinedSignal(double atr, int lookback, double threshold)
{
  SCombinedSignal signal;
  signal.confidence = 0.0;
  signal.direction = "NEUTRAL";
  signal.reason = "";
  signal.region = WIDTH_NORMAL;
  signal.slope_state = SLOPE_STABLE;

  // === ANÁLISE DAS BANDAS INDIVIDUAIS ===
  // Explicação: Cada banda (superior, média, inferior) tem uma inclinação
  // que indica a tendência local. Analisamos as três separadamente para
  // obter um quadro completo da movimentação do mercado.

  SSlopeValidation upper_val = GetSlopeValidation(atr, COPY_UPPER);
  // Obter validação da inclinação da banda superior
  // COPY_UPPER = constante que especifica qual buffer copiar (banda superior)

  SSlopeValidation middle_val = GetSlopeValidation(atr, COPY_MIDDLE);
  // Banda média (linha central) - tendência de médio prazo

  SSlopeValidation lower_val = GetSlopeValidation(atr, COPY_LOWER);
  // Banda inferior - nível de suporte dinâmico

  // === SISTEMA DE CONSENSO PONDERADO ===
  // Explicação: Substituímos a contagem simples (up/down) por um sistema
  // de consenso que considera a força relativa de cada banda.
  // Banda superior tem mais peso (resistência), inferior tem menos (suporte)

  double direction_score = CalculateWeightedDirectionConsensus(upper_val, middle_val, lower_val);
  // Calcula score de 0-1 baseado na força e direção das inclinações
  // 0.6+ = BULL, 0.4- = BEAR, meio = NEUTRAL

  // === DETERMINAÇÃO DA DIREÇÃO ===
  // Explicação: A direção final é determinada pelo consenso das bandas
  // Thresholds assimétricos para evitar sinais neutros desnecessários

  if (direction_score > 0.6) signal.direction = "BULL";
  else if (direction_score < 0.4) signal.direction = "BEAR";
  else signal.direction = "NEUTRAL";

  // Count bands for reason string
  int up_count = 0, down_count = 0, neutral_count = 0;

  if (upper_val.linear_regression.slope_value > 0) up_count++;
  else if (upper_val.linear_regression.slope_value < 0) down_count++;
  else neutral_count++;

  if (middle_val.linear_regression.slope_value > 0) up_count++;
  else if (middle_val.linear_regression.slope_value < 0) down_count++;
  else neutral_count++;

  if (lower_val.linear_regression.slope_value > 0) up_count++;
  else if (lower_val.linear_regression.slope_value < 0) down_count++;
  else neutral_count++;

  // Get width percentile and region
  double percentile = CalculateWidthPercentile(width_array, ArraySize(width_array), m_width_lookback);
  signal.region = ClassifyWidthRegion(percentile);

  // Width modifier
  double width_modifier = 0.0;
  if (signal.region == WIDTH_VERY_NARROW || signal.region == WIDTH_VERY_WIDE)
    width_modifier = 0.25;

  // Get width slope
  SSlopeResult width_slope = CalculateWidthSlopeLinearRegression(atr, m_slope_lookback);
  signal.slope_state = ClassifySlopeState(width_slope.slope_value, threshold);

  // Slope strength (normalized, capped at 1.0)
  double slope_strength = MathMin(1.0, MathAbs(width_slope.slope_value));

  // R-squared factor
  double r_squared_factor = width_slope.r_squared;

  // Calculate additional factors
  double position_strength = CalculatePositionStrength();
  double convergence_factor = GetBandConvergence(atr);
  bool is_squeeze = DetectSqueeze(threshold);

  // Calculate integrated confidence
  signal.confidence = CalculateIntegratedConfidence(direction_score, slope_strength * r_squared_factor,
                                                    width_modifier, position_strength,
                                                    convergence_factor, is_squeeze);

  // Build enhanced reason
  signal.reason = BuildEnhancedReason(up_count, down_count, neutral_count,
                                      signal.region, signal.slope_state,
                                      position_strength, convergence_factor, is_squeeze);

  return signal;
}

//+------------------------------------------------------------------+
//| Set configurable parameters                                      |
//+------------------------------------------------------------------+
void CBollinger::SetConfigurableParameters(int width_history, int width_lookback, int slope_lookback,
                                          int &percentile_thresholds[], double &weights[])
{
  m_width_history = width_history > 0 ? width_history : WIDTH_HISTORY;
  m_width_lookback = width_lookback > 0 ? width_lookback : WIDTH_LOOKBACK;
  m_slope_lookback = slope_lookback > 0 ? slope_lookback : SLOPE_LOOKBACK;

  if (ArraySize(percentile_thresholds) >= 4)
  {
    for(int i = 0; i < 4; i++)
      m_percentile_thresholds[i] = percentile_thresholds[i];
  }

  if (ArraySize(weights) >= 3)
  {
    for(int i = 0; i < 3; i++)
      m_weights[i] = weights[i];
  }

  // Validate and correct parameters
  ValidateAndCorrectParameters();

  // Load symbol-specific presets
  LoadPresetForSymbol(m_symbol);

  // Note: Market adaptation with ATR is performed in Update() when ATR is available

  // Resize width_array if needed
  if (ArraySize(width_array) != m_width_history)
  {
    ArrayResize(width_array, m_width_history);
    m_width_data_dirty = true; // Mark for recalculation
  }
}

//+------------------------------------------------------------------+
//| CalculatePositionStrength - Força da Posição do Preço           |
//| Propósito: Medir quão forte é a posição atual do preço          |
//| Retorno: Valor entre 0.0-1.0 (0=fraco, 1=forte)               |
//| Uso: Componente para cálculo de confiança do sinal             |
//+------------------------------------------------------------------+
double CBollinger::CalculatePositionStrength()
{
   /*
    * LÓGICA DE CÁLCULO:
    * ----------------
    * A força da posição é determinada pela proximidade do preço
    * às bandas e pela consistência da direção das bandas.
    *
    * Fatores considerados:
    * 1. Distância relativa do preço às bandas
    * 2. Alinhamento das inclinações das bandas
    * 3. Volatilidade atual vs histórica
    */

   double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   // Preço atual do ativo para análise de posicionamento

   double middle = GetValue(0);   // Banda média (linha central)
   double upper = GetUpper(0);    // Banda superior (resistência)
   double lower = GetLower(0);    // Banda inferior (suporte)
   double width = upper - lower;  // Largura total das bandas

   // Verificação de segurança para evitar divisão por zero
   if (width <= 0.0)
      return 0.0;   // Largura inválida = força zero

   // Calcular posição relativa (0% = banda inferior, 100% = banda superior)
   double position_pct = (price - lower) / width * 100.0;

   /*
    * INTERPRETAÇÃO DA POSIÇÃO:
    * -------------------------
    * 0-25%: Preço próximo à banda inferior (possível zona de compra)
    * 25-75%: Posição intermediária (normal)
    * 75-100%: Preço próximo à banda superior (possível zona de venda)
    *
    * Para WIN$N especificamente:
    * - Valores abaixo de 20% podem indicar oversold
    * - Valores acima de 80% podem indicar overbought
    */

   return MathMin(1.0, position_pct / 100.0);
}

//+------------------------------------------------------------------+
//| Calculate band convergence factor                                |
//+------------------------------------------------------------------+
double CBollinger::GetBandConvergence(double atr)
{
  double current_width = GetUpper(0) - GetLower(0);

  if (atr <= 0.0 || ArraySize(width_array) == 0)
     return 0.0;

  // Calculate average width from history
  double avg_width = 0.0;
  for(int i = 0; i < ArraySize(width_array); i++)
  {
     avg_width += width_array[i];
  }
  avg_width /= ArraySize(width_array);

  if (avg_width <= 0.0)
     return 0.0;

  // Convergence factor: higher when current width is smaller than average
  double convergence = 1.0 - (current_width / avg_width);

  // Normalize by ATR for volatility adjustment
  convergence /= (atr > 0.0 ? atr : 1.0);

  return MathMax(0.0, MathMin(1.0, convergence));
}

//+------------------------------------------------------------------+
//| Detect squeeze conditions                                        |
//+------------------------------------------------------------------+
bool CBollinger::DetectSqueeze(double threshold)
{
  // Get current width percentile and region
  double percentile = CalculateWidthPercentile(width_array, ArraySize(width_array), m_width_lookback);
  ENUM_WIDTH_REGION region = ClassifyWidthRegion(percentile);

  // Get width slope
  SSlopeResult width_slope = CalculateWidthSlopeLinearRegression(0, m_slope_lookback); // atr=0 for simplicity
  ENUM_SLOPE_STATE slope_state = ClassifySlopeState(width_slope.slope_value, threshold);

  // Squeeze: very narrow bands AND contracting slope
  return (region == WIDTH_VERY_NARROW && slope_state == SLOPE_CONTRACTING);
}

//+------------------------------------------------------------------+
//| Calculate weighted direction consensus from band slopes         |
//| FÓRMULA: Consenso = Σ(força_direção × peso_banda) |
//| LÓGICA: Sistema de votação ponderada onde cada banda tem influência diferente |
//| PESOS: Upper=50% (resistência), Middle=30% (tendência), Lower=20% (suporte) |
//| RESULTADO: Score de 0-1 onde 0.6+ = BULL, 0.4- = BEAR, meio = NEUTRAL |
double CBollinger::CalculateWeightedDirectionConsensus(const SSlopeValidation &upper,
                                                      const SSlopeValidation &middle,
                                                      const SSlopeValidation &lower)
{
   // DEFINIÇÃO DE PESOS: Baseado na importância técnica de cada banda
   // Upper Band (50%): Resistência dinâmica - mais importante para pressão vendedora
   // Middle Band (30%): Tendência central - indicador principal de direção
   // Lower Band (20%): Suporte dinâmico - menos influente que resistência
   const double UPPER_WEIGHT = 0.5;
   const double MIDDLE_WEIGHT = 0.3;
   const double LOWER_WEIGHT = 0.2;

   // ACUMULADORES: Separam força de alta e baixa
   double total_up = 0.0;    // Soma das forças direcionais de alta
   double total_down = 0.0;  // Soma das forças direcionais de baixa

   // ANÁLISE BANDA SUPERIOR: Resistência mais importante
   double upper_strength = MathAbs(upper.linear_regression.slope_value) * UPPER_WEIGHT;
   if (upper.linear_regression.slope_value > 0)
      total_up += upper_strength;     // Banda superior subindo = pressão compradora
   else if (upper.linear_regression.slope_value < 0)
      total_down += upper_strength;   // Banda superior descendo = pressão vendedora

   // ANÁLISE BANDA CENTRAL: Tendência principal
   double middle_strength = MathAbs(middle.linear_regression.slope_value) * MIDDLE_WEIGHT;
   if (middle.linear_regression.slope_value > 0)
      total_up += middle_strength;    // Tendência central de alta
   else if (middle.linear_regression.slope_value < 0)
      total_down += middle_strength;  // Tendência central de baixa

   // ANÁLISE BANDA INFERIOR: Suporte menos influente
   double lower_strength = MathAbs(lower.linear_regression.slope_value) * LOWER_WEIGHT;
   if (lower.linear_regression.slope_value > 0)
      total_up += lower_strength;     // Suporte subindo = força compradora
   else if (lower.linear_regression.slope_value < 0)
      total_down += lower_strength;   // Suporte descendo = força vendedora

   // CÁLCULO DO CONSENSO: Diferença entre forças opostas
   // FÓRMULA: consenso = força_alta_total - força_baixa_total
   // INTERVALO: [-1, +1] onde +1 = todas as bandas subindo, -1 = todas descendo
   double consensus = total_up - total_down;

   // NORMALIZAÇÃO: Converte para escala 0-1 para facilitar interpretação
   // FÓRMULA: score_normalizado = (consenso_bruto + 1) / 2
   // RESULTADO: 0.0 = consenso total de baixa, 1.0 = consenso total de alta
   return (consensus + 1.0) / 2.0;
}

//+------------------------------------------------------------------+
//| Calculate integrated confidence score                            |
//| FÓRMULA: Confiança = Σ(componente × peso) + bônus_condicional |
//| COMPONENTES: direção_bandas(40%), slope(40%), width(20%) + extras(10% cada) |
//| LÓGICA: Combina múltiplos fatores técnicos em score unificado 0-1 |
//| BÔNUS: +20% para squeeze (condições de alta probabilidade) |
double CBollinger::CalculateIntegratedConfidence(double direction_score, double slope_strength,
                                                double width_modifier, double position_strength,
                                                double convergence_factor, bool is_squeeze)
{
   // COMPONENTES PRINCIPAIS: Usam pesos configuráveis do sistema
   // 1. DIREÇÃO DAS BANDAS: Score de consenso (0-1) × peso_banda
   double band_component = direction_score * m_weights[0];

   // 2. FORÇA DO SLOPE: Intensidade da inclinação × peso_slope
   double slope_component = slope_strength * m_weights[1];

   // 3. MODIFICADOR DE LARGURA: Bonus para regiões extremas × peso_width
   double width_component = width_modifier * m_weights[2];

   // COMPONENTES ADICIONAIS: Pesos fixos para fatores complementares
   // 4. POSIÇÃO DO PREÇO: Força relativa nas bandas (10% do total)
   double position_component = position_strength * 0.1;

   // 5. CONVERGÊNCIA DAS BANDAS: Fator de squeeze/contração (10% do total)
   double convergence_component = convergence_factor * 0.1;

   // BÔNUS CONDICIONAL: Recompensa condições especiais
   // 6. SQUEEZE BONUS: +20% quando detectado squeeze (alta probabilidade)
   double squeeze_bonus = is_squeeze ? 0.2 : 0.0;

   // SOMA INTEGRADA: Combinação linear de todos os fatores
   // FÓRMULA: confiança_total = Σ(componentes) + bônus
   double total_confidence = band_component + slope_component + width_component +
                           position_component + convergence_component + squeeze_bonus;

   // NORMALIZAÇÃO: Garante que resultado esteja no intervalo [0, 1]
   // IMPORTANTE: Previne valores negativos ou > 100%
   return MathMin(1.0, MathMax(0.0, total_confidence));
}

//+------------------------------------------------------------------+
//| Build enhanced reason string with new factors                   |
//+------------------------------------------------------------------+
string CBollinger::BuildEnhancedReason(int up_count, int down_count, int neutral_count,
                                     ENUM_WIDTH_REGION region, ENUM_SLOPE_STATE slope_state,
                                     double position_strength, double convergence_factor, bool is_squeeze)
{
   return StringFormat("Bands:%dU/%dD/%dN, Width:%s, Slope:%s, Pos:%.2f, Conv:%.2f, Squeeze:%s",
                      up_count, down_count, neutral_count,
                      EnumToString(region), EnumToString(slope_state),
                      position_strength, convergence_factor, is_squeeze ? "YES" : "NO");
}

//+------------------------------------------------------------------+
//| Validate and auto-correct configurable parameters                |
//+------------------------------------------------------------------+
void CBollinger::ValidateAndCorrectParameters()
{
   // Validate and correct width_history
   if (m_width_history < 10) m_width_history = 10;
   if (m_width_history > 500) m_width_history = 500;

   // Validate and correct width_lookback
   if (m_width_lookback < 5) m_width_lookback = 5;
   if (m_width_lookback > 200) m_width_lookback = 200;

   // Validate and correct slope_lookback
   if (m_slope_lookback < 3) m_slope_lookback = 3;
   if (m_slope_lookback > 50) m_slope_lookback = 50;

   // Validate percentile thresholds (must be strictly increasing 0-100)
   if (m_percentile_thresholds[0] <= 0) m_percentile_thresholds[0] = PERCENTILE_THRESHOLD_VERY_NARROW;
   if (m_percentile_thresholds[1] <= m_percentile_thresholds[0]) m_percentile_thresholds[1] = PERCENTILE_THRESHOLD_NARROW;
   if (m_percentile_thresholds[2] <= m_percentile_thresholds[1]) m_percentile_thresholds[2] = PERCENTILE_THRESHOLD_NORMAL;
   if (m_percentile_thresholds[3] <= m_percentile_thresholds[2]) m_percentile_thresholds[3] = PERCENTILE_THRESHOLD_WIDE;
   if (m_percentile_thresholds[3] >= 100) m_percentile_thresholds[3] = 95;

   // Validate weights (each 0.0-1.0, normalize if sum != 1.0)
   double weight_sum = 0.0;
   for(int i = 0; i < 3; i++)
   {
      if (m_weights[i] < 0.0) m_weights[i] = 0.0;
      if (m_weights[i] > 1.0) m_weights[i] = 1.0;
      weight_sum += m_weights[i];
   }

   // Normalize weights to sum to 1.0
   if (weight_sum > 0.0)
   {
      for(int i = 0; i < 3; i++)
         m_weights[i] /= weight_sum;
   }
   else
   {
      // Fallback to defaults
      m_weights[0] = WEIGHT_BAND;
      m_weights[1] = WEIGHT_SLOPE;
      m_weights[2] = WEIGHT_WIDTH;
   }
}

//+------------------------------------------------------------------+
//| Adapt parameters based on current market conditions (ATR)       |
//+------------------------------------------------------------------+
void CBollinger::AdaptParametersToMarket(double atr)
{
   if (atr <= 0.0) return;

   // Calculate current ATR relative to price
   double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double atr_ratio = (current_price > 0.0) ? (atr / current_price) * 100.0 : 0.0;

   // High volatility: increase lookbacks for stability
   if (atr_ratio > 1.0) // ATR > 1% of price
   {
      m_width_lookback = (int)MathMin(200, m_width_lookback * 1.2);
      m_slope_lookback = (int)MathMin(50, m_slope_lookback * 1.2);
   }
   // Low volatility: decrease lookbacks for responsiveness
   else if (atr_ratio < 0.2) // ATR < 0.2% of price
   {
      m_width_lookback = (int)MathMax(5, m_width_lookback * 0.8);
      m_slope_lookback = (int)MathMax(3, m_slope_lookback * 0.8);
   }

   // Re-validate after adaptation
   ValidateAndCorrectParameters();
}

//+------------------------------------------------------------------+
//| Load optimized presets for specific symbols                      |
//+------------------------------------------------------------------+
void CBollinger::LoadPresetForSymbol(string symbol)
{
   if (StringFind(symbol, "WIN") >= 0)
   {
      // Optimized presets for WIN$N and similar symbols
      // More sensitive thresholds for crypto-like behavior
      m_percentile_thresholds[0] = 5;   // Very narrow
      m_percentile_thresholds[1] = 20;  // Narrow
      m_percentile_thresholds[2] = 80;  // Normal
      m_percentile_thresholds[3] = 95;  // Wide

      // Adjusted weights: more emphasis on slope for volatile assets
      m_weights[0] = 0.3; // Band
      m_weights[1] = 0.4; // Slope
      m_weights[2] = 0.3; // Width

      // Shorter lookbacks for faster response
      m_width_lookback = MathMax(5, m_width_lookback - 10);
      m_slope_lookback = MathMax(3, m_slope_lookback - 2);
   }
   // Could add more presets for other symbols if needed

   // Validate after loading preset
   ValidateAndCorrectParameters();
}

//+------------------------------------------------------------------+
//| Check if width data is valid for calculations                   |
//+------------------------------------------------------------------+
bool CBollinger::IsWidthDataValid()
{
   int size = ArraySize(width_array);
   if (size < 2) return false;

   // Check for valid numeric values
   for(int i = 0; i < size; i++)
   {
      if (width_array[i] <= 0.0 || !MathIsValidNumber(width_array[i]))
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Get optimal lookback period based on data characteristics       |
//+------------------------------------------------------------------+
int CBollinger::GetOptimalLookback()
{
   // Use configured lookback as base
   int optimal = m_width_lookback;

   // Adjust based on available data
   int available_data = ArraySize(width_array);
   if (available_data < optimal)
      optimal = MathMax(2, available_data - 1);

   // Ensure minimum for statistical validity
   return MathMax(2, optimal);
}

//+------------------------------------------------------------------+
//| Cache width statistics to avoid repeated calculations           |
//+------------------------------------------------------------------+
void CBollinger::CacheWidthStats()
{
   if (!IsWidthDataValid())
   {
      m_cached_percentile = 50.0; // Default
      m_cached_zscore = 0.0;
      m_cached_lookback = m_width_lookback;
      return;
   }

   int optimal_lookback = GetOptimalLookback();
   m_cached_percentile = CalculateWidthPercentile(width_array, ArraySize(width_array), optimal_lookback);
   m_cached_zscore = CalculateWidthZScore(width_array, ArraySize(width_array), optimal_lookback);
   m_cached_lookback = optimal_lookback;
   m_width_data_dirty = false;
}

//+------------------------------------------------------------------+
//| CalibrateForWinIndex - Calibração Específica para WIN$N         |
//| PROPÓSITO: Ajustar parâmetros baseado no timeframe do WIN$N     |
//| FUNDAMENTO: Cada timeframe tem características de volatilidade distintas |
//| MÉTODO: Switch case com configurações otimizadas por timeframe |
//| VALIDAÇÃO: Parâmetros corrigidos automaticamente após calibração |
void CBollinger::CalibrateForWinIndex(ENUM_TIMEFRAMES timeframe)
{
     /*
      * FUNDAMENTO TÉCNICO DO WIN$N:
      * ----------------------------
      * WIN$N (Mini Índice Ibovespa) características específicas:
      * - Tick size: 5 pontos (R$ 0,05 por ponto)
      * - Volatilidade: Alta durante pregão (9:00-17:00 B3)
      * - Padrões: Diferentes por timeframe devido ao ruído
      *
      * ESTRATÉGIA DE CALIBRAÇÃO:
      * - M1: Filtros rigorosos contra ruído de alta frequência
      * - M3: Balance otimizado baseado em dados históricos reais
      * - M15+: Lookback maior pois trends são mais claras
      */

     switch(timeframe)
     {
        case PERIOD_M1:
           /*
            * CONFIGURAÇÃO M1 (1 MINUTO):
            * OBJETIVO: Filtrar ruído mantendo reatividade
            * LÓGICA: Histórico maior + lookback curto = suavização com resposta rápida
            */
           m_width_history = 150;      // HISTÓRICO AMPLIO: Suaviza ruído de 1min
           m_width_lookback = 30;      // LOOKBACK CURTO: Reage rápido a mudanças
           m_slope_lookback = 6;       // SLOPE RÁPIDO: Detecção imediata de tendência

           // THRESHOLDS MAIS SENSÍVEIS: Capturam mudanças rápidas
           m_percentile_thresholds[0] = 20;  // Very narrow (mais permissivo)
           m_percentile_thresholds[1] = 40;  // Narrow
           m_percentile_thresholds[2] = 60;  // Normal
           m_percentile_thresholds[3] = 80;  // Wide

           // PESOS EQUILIBRADOS: Banda e slope têm mesma importância
           m_weights[0] = 0.4;  // Band: 40% (resistência/suporte)
           m_weights[1] = 0.4;  // Slope: 40% (inclinação - crítico em M1)
           m_weights[2] = 0.2;  // Width: 20% (volatilidade)
           break;

        case PERIOD_M3:
           /*
            * CONFIGURAÇÃO M3 (3 MINUTOS) - OTIMIZADA:
            * BASE: Análise de dados históricos reais do WIN$N
            * OBJETIVO: Melhor balance entre sensibilidade e robustez
            * MÉTODO: Parâmetros ajustados para capturar oportunidades reais
            */
           // PARÂMETROS DE HISTÓRICO: Otimizados para WIN$N M3
           m_width_history = 100;      // BASE DE DADOS: 100 candles históricos
           m_width_lookback = 40;      // ANÁLISE: 40 candles para estatísticas (aumentado de 50)
           m_slope_lookback = 8;       // MOMENTUM: 8 candles para detecção rápida

           // THRESHOLDS PERMISSIVOS: Facilitam detecção de squeezes/expansões
           m_percentile_thresholds[0] = 20;  // Very narrow (mais permissivo que padrão)
           m_percentile_thresholds[1] = 40;  // Narrow
           m_percentile_thresholds[2] = 60;  // Normal
           m_percentile_thresholds[3] = 80;  // Wide

           // PESOS BALANCEADOS: Ênfase em slope para momentum
           m_weights[0] = 0.4;  // Band: 40% (direção das bandas)
           m_weights[1] = 0.4;  // Slope: 40% (maior peso - momentum crítico)
           m_weights[2] = 0.2;  // Width: 20% (modificadores de volatilidade)
           break;

      case PERIOD_M5:
         // M5: More filters, balanced approach
         m_width_history = 80;
         m_width_lookback = 80;
         m_slope_lookback = 12;
         m_percentile_thresholds[0] = 10;  // Very narrow
         m_percentile_thresholds[1] = 30;  // Narrow
         m_percentile_thresholds[2] = 70;  // Normal
         m_percentile_thresholds[3] = 90;  // Wide
         m_weights[0] = 0.6;  // Band (conservative)
         m_weights[1] = 0.2;  // Slope
         m_weights[2] = 0.2;  // Width
         break;

      case PERIOD_M15:
         // M15: Longer lookbacks, less noise
         m_width_history = 80;
         m_width_lookback = 80;
         m_slope_lookback = 12;
         m_percentile_thresholds[0] = 10;  // Very narrow
         m_percentile_thresholds[1] = 30;  // Narrow
         m_percentile_thresholds[2] = 70;  // Normal
         m_percentile_thresholds[3] = 90;  // Wide
         m_weights[0] = 0.6;  // Band
         m_weights[1] = 0.2;  // Slope
         m_weights[2] = 0.2;  // Width
         break;

      case PERIOD_H1:
         // H1: Conservative parameters for longer timeframe
         m_width_history = 60;
         m_width_lookback = 60;
         m_slope_lookback = 15;
         m_percentile_thresholds[0] = 5;   // Very narrow
         m_percentile_thresholds[1] = 25;  // Narrow
         m_percentile_thresholds[2] = 75;  // Normal
         m_percentile_thresholds[3] = 95;  // Wide
         m_weights[0] = 0.7;  // Band (very conservative)
         m_weights[1] = 0.2;  // Slope
         m_weights[2] = 0.1;  // Width
         break;

      default:
         // For other timeframes, use M3 as reference
         CalibrateForWinIndex(PERIOD_M3);
         break;
   }

   // Validate parameters after calibration
   ValidateAndCorrectParameters();
}

#endif // __BOLLINGER_MQH__
