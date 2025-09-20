//+------------------------------------------------------------------+
//|                                    indicators/bollinger.mqh      |
//|  Bollinger Bands indicator derived from CIndicatorBase           |
//+------------------------------------------------------------------+
#ifndef __BOLLINGER_MQH__
#define __BOLLINGER_MQH__

#include "../indicator_base/indicator_base.mqh"
#include "../indicators_types.mqh"
#include "bollinger_defs.mqh"

//+------------------------------------------------------------------+
//| Structure to hold width analysis results                        |
//+------------------------------------------------------------------+
struct SWidthAnalysis
{
   double percentile;    // Percentile position (0-100)
   double zscore;        // Z-score (standard deviations from mean)
   double width;         // Current width value
   double slope_value;   // Slope/inclinação of width (rate of change)
   string slope_direction; // "EXPANDING", "CONTRACTING", or "STABLE"
};

class CBollinger : public CIndicatorBase
{
private:
   int m_period;
   int m_shift;
   double m_deviation;
   ENUM_APPLIED_PRICE m_price;

   // Width analysis configuration
   int m_width_lookback_period;
   bool m_use_percentile_for_width;

  bool CreateHandle();
  void ReleaseHandle();
  double GetBufferValue(int buffer_index, int shift = 0);
  virtual bool OnCopyValuesForSlope(int shift, int count, double &buffer[], COPY_METHOD copy_method) override;
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
  double GetWidth(int shift = 0); // Width (Upper - Lower)

  virtual bool CopyValues(int shift, int count, double &buffer[]); // middle
  bool CopyUpper(int shift, int count, double &buffer[]);
  bool CopyLower(int shift, int count, double &buffer[]);
  bool CopyWidth(int shift, int count, double &buffer[]);

  virtual bool IsReady();
  virtual bool Update() override;

  // Width analysis methods
  // These methods provide advanced analysis of Bollinger Bands width:
  // - Percentile: Position of current width relative to historical distribution (0-100)
  //   Low percentile (< 20) indicates compressed/narrow bands
  //   High percentile (> 80) indicates expanded/wide bands
  // - Z-score: Standard deviation distance from historical mean
  //   Negative Z-score indicates narrower than average bands
  //   Positive Z-score indicates wider than average bands
  // - Slope: Rate of change of width over time (expanding/contracting)
  double GetWidthPercentile(int shift, int lookback_period = 200);
  double GetWidthZScore(int shift, int lookback_period = 200);
  SWidthAnalysis GetWidthMetric(int shift, int lookback_period = 0); // Returns both percentile and Z-score
  void GetWidthAnalysis(int shift, double &percentile, double &zscore, int lookback_period = 0); // Returns both metrics
  SSlopeValidation GetWidthSlopeValidation(double atr);
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
   m_width_lookback_period = 200;  // Default value, will be overridden by config
   m_use_percentile_for_width = true;  // Default to percentile

   // Initialize slope_values array with default values for width configuration
   ArrayResize(slope_values, 4);
   slope_values[3].lookback = 9;
   slope_values[3].simple_diff = 0.001;  // Small threshold for width slope
   slope_values[3].linear_reg = 0.001;   // Small threshold for width slope
   slope_values[3].discrete_der = 0.001; // Small threshold for width slope

   handle = INVALID_HANDLE;
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

   // Copy slope values and ensure we have at least 4 elements for width configuration
   ArrayCopy(slope_values, config.slope_values);

   // Ensure slope_values array has at least 4 elements (0,1,2 for bands, 3 for width)
   if (ArraySize(slope_values) < 4)
   {
      ArrayResize(slope_values, 4);
      // Initialize width slope configuration (index 3) with default values
      slope_values[3].lookback = 9;
      slope_values[3].simple_diff = 0.001;  // Small threshold for width slope
      slope_values[3].linear_reg = 0.001;   // Small threshold for width slope
      slope_values[3].discrete_der = 0.001; // Small threshold for width slope
   }

   m_width_lookback_period = config.width_lookback_period;
   m_use_percentile_for_width = config.use_percentile_for_width;
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
//| Width (Upper - Lower)                                            |
//+------------------------------------------------------------------+
double CBollinger::GetWidth(int shift)
{
  double upper = GetUpper(shift);
  double lower = GetLower(shift);
  if (upper == 0.0 && lower == 0.0)
    return 0.0;
  return upper - lower;
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
//| Copy width values (Upper - Lower)                                |
//+------------------------------------------------------------------+
bool CBollinger::CopyWidth(int shift, int count, double &buffer[])
{
  if (handle == INVALID_HANDLE)
    return false;

  ArrayResize(buffer, count);
  ArraySetAsSeries(buffer, true);

  double upper_buffer[];
  double lower_buffer[];

  if (!CopyUpper(shift, count, upper_buffer) || !CopyLower(shift, count, lower_buffer))
    return false;

  for (int i = 0; i < count; i++)
  {
    buffer[i] = upper_buffer[i] - lower_buffer[i];
  }

  return true;
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

  case COPY_WIDTH:
    //Print("COPIANDO - WIDTH");
    return CopyWidth(shift, count, buffer);

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
  else if (copy_method == COPY_WIDTH)
  {
    return GetWidth(shift);
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
  else if (copy_method == COPY_WIDTH)
  {
        //Print("RETORNANDO WIDTH");
    return 3; // Assuming width uses a 4th configuration slot
  }

  return 1;
}

//+------------------------------------------------------------------+
//| Calculate width percentile relative to historical data          |
//+------------------------------------------------------------------+
double CBollinger::GetWidthPercentile(int shift, int lookback_period)
{
  // Use configured lookback period if not specified
  if (lookback_period == 0)
    lookback_period = m_width_lookback_period;

  double current_width = GetWidth(shift);
  if (current_width == 0.0 || lookback_period <= 0)
    return 50.0; // Return neutral percentile if invalid

  double width_history[];
  if (!CopyWidth(shift, lookback_period, width_history))
    return 50.0;

  // Sort the historical widths to calculate percentile
  double sorted_widths[];
  ArrayCopy(sorted_widths, width_history);
  ArraySort(sorted_widths);

  // Count how many historical values are less than current width
  int count_less = 0;
  for (int i = 0; i < lookback_period; i++)
  {
    if (sorted_widths[i] < current_width)
      count_less++;
    else if (sorted_widths[i] == current_width)
      count_less += 0.5; // Handle ties
  }

  // Calculate percentile: (number of values less than current / total values) * 100
  return (double)count_less / lookback_period * 100.0;
}

//+------------------------------------------------------------------+
//| Calculate width Z-score relative to historical data             |
//+------------------------------------------------------------------+
double CBollinger::GetWidthZScore(int shift, int lookback_period)
{
  // Use configured lookback period if not specified
  if (lookback_period == 0)
    lookback_period = m_width_lookback_period;

  double current_width = GetWidth(shift);
  if (current_width == 0.0 || lookback_period <= 1)
    return 0.0; // Return neutral Z-score if invalid

  double width_history[];
  if (!CopyWidth(shift, lookback_period, width_history))
    return 0.0;

  // Calculate mean
  double sum = 0.0;
  for (int i = 0; i < lookback_period; i++)
  {
    sum += width_history[i];
  }
  double mean = sum / lookback_period;

  // Calculate standard deviation
  double sum_squared_diff = 0.0;
  for (int i = 0; i < lookback_period; i++)
  {
    double diff = width_history[i] - mean;
    sum_squared_diff += diff * diff;
  }
  double variance = sum_squared_diff / (lookback_period - 1);
  double std_dev = MathSqrt(variance);

  // Calculate Z-score: (current - mean) / std_dev
  if (std_dev == 0.0)
    return 0.0; // No variation in historical data

  return (current_width - mean) / std_dev;
}

//+------------------------------------------------------------------+
//| Get slope validation for width using existing slope system      |
//+------------------------------------------------------------------+
SSlopeValidation CBollinger::GetWidthSlopeValidation(double atr)
{
  return GetSlopeValidation(atr, COPY_WIDTH);
}

//+------------------------------------------------------------------+
//| Get complete width analysis (percentile, Z-score, and slope)    |
//+------------------------------------------------------------------+
SWidthAnalysis CBollinger::GetWidthMetric(int shift, int lookback_period)
{
  SWidthAnalysis result;

  // Use configured lookback period if not specified
  if (lookback_period == 0)
    lookback_period = m_width_lookback_period;

  // Get current width
  result.width = GetWidth(shift);

  // Calculate percentile and Z-score
  result.percentile = GetWidthPercentile(shift, lookback_period);
  result.zscore = GetWidthZScore(shift, lookback_period);

  // Get slope analysis using ATR for normalization
  double atr = iATR(m_symbol, m_timeframe, 14); // Use ATR for slope normalization
  SSlopeValidation slope_val = GetWidthSlopeValidation(atr);

  // Extract slope value and determine direction
  result.slope_value = slope_val.linear_regression.slope_value;

  // Determinar direção da inclinação
  if (result.slope_value > 0.01) // Pequeno limiar para evitar ruído
    result.slope_direction = "EXPANDINDO";
  else if (result.slope_value < -0.01)
    result.slope_direction = "CONTRAINDO";
  else
    result.slope_direction = "ESTÁVEL";

  return result;
}

//+------------------------------------------------------------------+
//| Get both width analysis metrics (percentile and Z-score)        |
//+------------------------------------------------------------------+
void CBollinger::GetWidthAnalysis(int shift, double &percentile, double &zscore, int lookback_period)
{
  // Use configured lookback period if not specified
  if (lookback_period == 0)
    lookback_period = m_width_lookback_period;

  percentile = GetWidthPercentile(shift, lookback_period);
  zscore = GetWidthZScore(shift, lookback_period);
}

/*
USAGE EXAMPLE:

// Initialize Bollinger Bands (config loaded from JSON)
CBollingerConfig config;
// Config values are loaded from config.json:
// - width_lookback_period: 200
// - use_percentile_for_width: true

CBollinger boll;
boll.Init(_Symbol, _Period, config);

// Get COMPLETE width analysis (percentile, Z-score, and slope)
SWidthAnalysis analysis = boll.GetWidthMetric(0);
Print("Width: ", analysis.width);
Print("Percentile: ", analysis.percentile);
Print("Z-Score: ", analysis.zscore);
Print("Slope: ", analysis.slope_value);
Print("Direction: ", analysis.slope_direction);

// Alternative: Get individual metrics
double only_percentile = boll.GetWidthPercentile(0, 200);
double only_zscore = boll.GetWidthZScore(0, 200);

// Interpret results - Width Position
if (analysis.percentile < 20) Print("Bands are compressed (narrow)");
else if (analysis.percentile > 80) Print("Bands are expanded (wide)");
else Print("Bands are normal width");

// Interpret results - Width Trend/Slope
if (analysis.slope_direction == "EXPANDING")
  Print("Width is increasing (bands expanding)");
else if (analysis.slope_direction == "CONTRACTING")
  Print("Width is decreasing (bands contracting)");
else
  Print("Width is stable");

// Use Z-score for additional analysis
if (analysis.zscore < -1.0) Print("Bands significantly narrower than average");
else if (analysis.zscore > 1.0) Print("Bands significantly wider than average");

// Combined signal example
if (analysis.percentile < 20 && analysis.slope_direction == "EXPANDING")
  Print("CONFIRMED: Bands are narrow AND expanding - potential breakout setup");
else if (analysis.percentile > 80 && analysis.slope_direction == "CONTRACTING")
  Print("CONFIRMED: Bands are wide AND contracting - potential reversal setup");
*/

#endif // __BOLLINGER_MQH__
