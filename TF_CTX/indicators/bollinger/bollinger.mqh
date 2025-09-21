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
  ArrayResize(width_array, m_width_history);
  for(int i = 0; i < m_width_history; i++)
  {
    width_array[i] = GetUpper(i) - GetLower(i);
  }
}

//+------------------------------------------------------------------+
//| Calculate Z-score of the most recent width                       |
//+------------------------------------------------------------------+
double CBollinger::CalculateWidthZScore(const double &width_array[], int length, int lookback)
{
  if (length < 1 || lookback < 1) return 0.0;
  int actual_lookback = MathMin(lookback, length);
  double sum = 0.0;
  for(int i = 0; i < actual_lookback; i++)
    sum += width_array[i];
  double mean = sum / actual_lookback;
  double sum_sq = 0.0;
  for(int i = 0; i < actual_lookback; i++)
  {
    double diff = width_array[i] - mean;
    sum_sq += diff * diff;
  }
  double variance = sum_sq / actual_lookback;
  double std = MathSqrt(variance);
  if (std == 0.0) return 0.0;
  double current = width_array[0];
  return (current - mean) / std;
}

//+------------------------------------------------------------------+
//| Calculate percentile of the most recent width                    |
//+------------------------------------------------------------------+
double CBollinger::CalculateWidthPercentile(const double &width_array[], int length, int lookback)
{
  if (length < 1 || lookback < 1) return 0.0;
  int actual_lookback = MathMin(lookback, length);
  double current = width_array[0];
  int count_below = 0;
  for(int i = 0; i < actual_lookback; i++)
  {
    if (width_array[i] < current) count_below++;
  }
  if (actual_lookback <= 1) return 50.0;
  return (double)count_below / (actual_lookback - 1) * 100.0;
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
//| Compute combined signal integrating all components               |
//+------------------------------------------------------------------+
SCombinedSignal CBollinger::ComputeCombinedSignal(double atr, int lookback, double threshold)
{
  SCombinedSignal signal;
  signal.confidence = 0.0;
  signal.direction = "NEUTRAL";
  signal.reason = "";
  signal.region = WIDTH_NORMAL;
  signal.slope_state = SLOPE_STABLE;

  // Get slope validations for each band
  SSlopeValidation upper_val = GetSlopeValidation(atr, COPY_UPPER);
  SSlopeValidation middle_val = GetSlopeValidation(atr, COPY_MIDDLE);
  SSlopeValidation lower_val = GetSlopeValidation(atr, COPY_LOWER);

  // Determine band directions based on linear regression slope
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

  // Base score: proportion of bands aligned
  double base_score = 0.0;
  if (up_count == 3) { base_score = 1.0; signal.direction = "BULL"; }
  else if (down_count == 3) { base_score = 1.0; signal.direction = "BEAR"; }
  else if (neutral_count == 3) { base_score = 0.5; signal.direction = "NEUTRAL"; }
  else { base_score = 0.5; signal.direction = "NEUTRAL"; } // mixed

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

  // Calculate confidence using weights
  double band_component = base_score * m_weights[0];
  double slope_component = slope_strength * r_squared_factor * m_weights[1];
  double width_component = width_modifier * m_weights[2];
  signal.confidence = MathMin(1.0, band_component + slope_component + width_component);

  // Build reason
  signal.reason = StringFormat("Bands:%dU/%dD/%dN, Width:%s, Slope:%s, Conf:%.2f",
                               up_count, down_count, neutral_count,
                               EnumToString(signal.region), EnumToString(signal.slope_state),
                               signal.confidence);

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

  // Resize width_array if needed
  if (ArraySize(width_array) != m_width_history)
  {
    ArrayResize(width_array, m_width_history);
  }
}

#endif // __BOLLINGER_MQH__
