//+------------------------------------------------------------------+
//|                                    indicators/bollinger.mqh      |
//|  Bollinger Bands indicator derived from CIndicatorBase           |
//+------------------------------------------------------------------+
#ifndef __BOLLINGER_MQH__
#define __BOLLINGER_MQH__

#include "../indicator_base/indicator_base.mqh"
#include "../../config_types.mqh"
#include "bollinger_defs.mqh"

class CBollinger : public CIndicatorBase
{
private:
  int m_period;
  int m_shift;
  double m_deviation;
  ENUM_APPLIED_PRICE m_price;

  bool CreateHandle();
  void ReleaseHandle();
  double GetBufferValue(int buffer_index, int shift = 0);
  virtual SSlopeResult GetAdvancedSlope(ENUM_SLOPE_METHOD method, int lookback, double threshold_high, double threshold_low, COPY_METHOD copy_method = COPY_MIDDLE) override;

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
  SSlopeValidation GetSlopeValidation(bool use_weighted_analysis, COPY_METHOD copy_method = COPY_MIDDLE) override;
  SPositionInfo GetPositionInfo(int shift, COPY_METHOD copy_method = COPY_MIDDLE) override;
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
    Print("ERRO: Falha ao criar handle Bollinger para ", m_symbol);
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
  return GetBufferValue(0, shift);
}

//+------------------------------------------------------------------+
//| Upper band (buffer 0)                                            |
//+------------------------------------------------------------------+
double CBollinger::GetUpper(int shift)
{
  return GetBufferValue(1, shift);
}

//+------------------------------------------------------------------+
//| Lower band (buffer 1)                                            |
//+------------------------------------------------------------------+
double CBollinger::GetLower(int shift)
{
  return GetBufferValue(2, shift);
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
  return CopyBuffer(handle, 0, shift, count, buffer) > 0;
}

//+------------------------------------------------------------------+
//| Copy upper band values                                           |
//+------------------------------------------------------------------+
bool CBollinger::CopyUpper(int shift, int count, double &buffer[])
{
  if (handle == INVALID_HANDLE)
    return false;
  ArrayResize(buffer, count);
  ArraySetAsSeries(buffer, true);
  return CopyBuffer(handle, 1, shift, count, buffer) > 0;
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
  return CopyBuffer(handle, 2, shift, count, buffer) > 0;
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
//| Calcular inclinação avançada da média móvel                    |
//+------------------------------------------------------------------+
SSlopeResult CBollinger::GetAdvancedSlope(ENUM_SLOPE_METHOD method,
                                          int lookback = 10,
                                          double threshold_high = 0.5,
                                          double threshold_low = -0.5,
                                          COPY_METHOD copy_method = COPY_MIDDLE)
{
  SSlopeResult result;
  result.slope_value = 0.0;
  result.r_squared = 0.0;
  result.trend_direction = "LATERAL";
  result.trend_strength = 0.0;

  if (handle == INVALID_HANDLE)
  {
    Print("ERRO: Handle do indicador inválido para cálculo da inclinação avançada");
    return result;
  }

  if (lookback <= 0)
  {
    Print("ERRO: Lookback deve ser maior que zero");
    return result;
  }

  // Obter valores da MA
  double ma_values[];

  switch (copy_method)
  {
  case COPY_LOWER:
    if (!CopyLower(0, lookback + 1, ma_values))
    {
      Print("ERRO: Falha ao obter valores para cálculo da inclinação");
      return result;
    }
    break;

  case COPY_UPPER:
    if (!CopyUpper(0, lookback + 1, ma_values))
    {
      Print("ERRO: Falha ao obter valores para cálculo da inclinação");
      return result;
    }
    break;

  case COPY_MIDDLE:
    if (!CopyValues(0, lookback + 1, ma_values))
    {
      Print("ERRO: Falha ao obter valores para cálculo da inclinação");
      return result;
    }
    break;

  default:
    Print("ERRO: Método de cópia inválido");
    return result;
  }

  switch (method)
  {
  case SLOPE_LINEAR_REGRESSION:
    result = m_slope.CalculateLinearRegressionSlope(m_symbol, ma_values, lookback);
    break;

  case SLOPE_SIMPLE_DIFFERENCE:
    result = m_slope.CalculateSimpleDifference(m_symbol, ma_values, lookback);
    break;

  case SLOPE_PERCENTAGE_CHANGE:
    result = m_slope.CalculatePercentageChange(m_symbol, ma_values, lookback);
    break;

  case SLOPE_DISCRETE_DERIVATIVE:
    result = m_slope.CalculateDiscreteDerivative(m_symbol, ma_values);
    break;

  case SLOPE_ANGLE_DEGREES:
    result = m_slope.CalculateAngleDegrees(m_symbol, ma_values, lookback);
    break;
  }

  // Determinar direção
  if (result.slope_value > threshold_high)
    result.trend_direction = "ALTA";
  else if (result.slope_value < threshold_low)
    result.trend_direction = "BAIXA";
  else
    result.trend_direction = "LATERAL";

  // Calcular força (0-100)
  result.trend_strength = MathMin(100.0, MathAbs(result.slope_value) * 100.0);

  return result;
}

//+------------------------------------------------------------------+
//| Validação cruzada com múltiplos métodos de inclinação          |
//+------------------------------------------------------------------+
SSlopeValidation CBollinger::GetSlopeValidation(bool use_weighted_analysis = true,
                                                COPY_METHOD copy_method = COPY_MIDDLE)
{
  SSlopeValidation validation;

  if (handle == INVALID_HANDLE)
  {
    Print("ERRO: Handle do indicador inválido para validação de inclinação");
    return validation;
  }

  // TYPES ----------
  // TRADING_SCALPING
  // TRADING_SWING
  // TRADING_POSITION

  // Obter configuração otimizada
  SThresholdConfig config = GetOptimizedConfig(m_timeframe, TRADING_SCALPING);

  // Calcular inclinação com configurações específicas
  validation.linear_regression = GetAdvancedSlope(SLOPE_LINEAR_REGRESSION, config.lookback,
                                                  config.linear_regression_high, config.linear_regression_low, copy_method);
  validation.simple_difference = GetAdvancedSlope(SLOPE_SIMPLE_DIFFERENCE, config.lookback,
                                                  config.simple_difference_high, config.simple_difference_low, copy_method);
  validation.percentage_change = GetAdvancedSlope(SLOPE_PERCENTAGE_CHANGE, config.lookback,
                                                  config.percentage_change_high, config.percentage_change_low, copy_method);
  validation.discrete_derivative = GetAdvancedSlope(SLOPE_DISCRETE_DERIVATIVE, config.lookback,
                                                    config.discrete_derivative_high, config.discrete_derivative_low, copy_method);
  validation.angle_degrees = GetAdvancedSlope(SLOPE_ANGLE_DEGREES, config.lookback,
                                              config.angle_degrees_high, config.angle_degrees_low, copy_method);

  // Analisar consenso entre métodos
  validation = m_slope.AnalyzeMethodsConsensus(validation, use_weighted_analysis);

  return validation;
}

SPositionInfo CBollinger::GetPositionInfo(int shift, COPY_METHOD copy_method = COPY_MIDDLE)
{

  double ind_value = 0;

  if (copy_method == COPY_LOWER)
  {
    Print("COPIA - LOWER");
    ind_value = GetLower(shift);
  }
  else if (copy_method == COPY_UPPER)
  {
        Print("COPIA - UPPER");
    ind_value = GetUpper(shift);
  }
  else
  {
        Print("COPIA - MIDDLE");
    ind_value = GetValue(shift);
  }

  SPositionInfo result;
  result.distance = 0.0;
  result = m_candle_distance.GetPreviousCandlePosition(shift, m_symbol, m_timeframe, ind_value);
  return result;
}

#endif // __BOLLINGER_MQH__
