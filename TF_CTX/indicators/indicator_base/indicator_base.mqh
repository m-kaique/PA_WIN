//+------------------------------------------------------------------+
//|                                   indicators/indicator_base.mqh |
//|  Base abstract class for indicators                             |
//+------------------------------------------------------------------+

#ifndef __INDICATOR_BASE_MQH__
#define __INDICATOR_BASE_MQH__
#include "indicator_base_defs.mqh"
#include "submodules/indicator_slope/slope.mqh" 
#include "submodules/indicator_candle_distance/indicator_candle_distance.mqh"


class CIndicatorBase{
 
protected:
  
  string m_symbol;             // Símbolo
  ENUM_TIMEFRAMES m_timeframe; // TimeFrame
  int handle;                  // Handlef
  bool attach_chart;           // Flag para acoplar ao gráfico
  ENUM_TIMEFRAMES alert_tf;    // TF para alertas
  // Métodos privados para cálculo de inclinação avançada
  virtual SSlopeResult GetAdvancedSlope(ENUM_SLOPE_METHOD method, int lookback, double threshold_high, double threshold_low, COPY_METHOD copy_method = COPY_MIDDLE);



  public:

  virtual bool Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_MA_METHOD method) = 0;
  virtual double GetValue(int shift = 0) = 0;
  virtual bool CopyValues(int shift, int count, double &buffer[]) = 0;
  virtual bool IsReady() = 0;
  virtual bool Update() { return IsReady(); }
  virtual ~CIndicatorBase() {}

  // Metodos publicos slope
  virtual SSlopeValidation GetSlopeValidation(bool use_weighted_analysis, COPY_METHOD copy_method = COPY_MIDDLE);
  bool AttachToChart()
  {
    if (attach_chart && handle != INVALID_HANDLE)
    {
      if (!ChartIndicatorAdd(0, 0, handle))
      {
        Print("ERRO: Falha ao adicionar indicador ao gráfico.");
        return false;
      }
      Print("Indicador acoplado ao gráfico com sucesso.");
      return true;
    }
    return false; // não precisa acoplar
  }
  SPositionInfo GetPreviousCandlePosition(int shift, string symbol, ENUM_TIMEFRAMES tf);
  string GetCandlePositionDescription(ENUM_CANDLE_POSITION position);
  SPositionInfo GetPositionInfo(int shift);
  CSlope m_slope;              // Classe Cálculo Inclinação 
  CIndCandleDistance m_candle_distance;
};


//+------------------------------------------------------------------+
//| Validação cruzada com múltiplos métodos de inclinação          |
//+------------------------------------------------------------------+
// PA_WIN CALL
SSlopeValidation CIndicatorBase::GetSlopeValidation(bool use_weighted_analysis = true, COPY_METHOD copy_method = COPY_MIDDLE)
{
  SSlopeValidation validation;

  // TYPES ----------
  // TRADING_SCALPING
  // TRADING_SWING
  // TRADING_POSITION

  // Obter configuração otimizada
  SThresholdConfig config = GetOptimizedConfig(m_timeframe, TRADING_SCALPING);

  // Calcular inclinação com configurações específicas
  validation.linear_regression = GetAdvancedSlope(SLOPE_LINEAR_REGRESSION, config.lookback,
                                                  config.linear_regression_high, config.linear_regression_low);
  validation.simple_difference = GetAdvancedSlope(SLOPE_SIMPLE_DIFFERENCE, config.lookback,
                                                  config.simple_difference_high, config.simple_difference_low);
  validation.percentage_change = GetAdvancedSlope(SLOPE_PERCENTAGE_CHANGE, config.lookback,
                                                  config.percentage_change_high, config.percentage_change_low);
  validation.discrete_derivative = GetAdvancedSlope(SLOPE_DISCRETE_DERIVATIVE, config.lookback,
                                                    config.discrete_derivative_high, config.discrete_derivative_low);
  validation.angle_degrees = GetAdvancedSlope(SLOPE_ANGLE_DEGREES, config.lookback,
                                              config.angle_degrees_high, config.angle_degrees_low);

  // Analisar consenso entre métodos
  validation = m_slope.AnalyzeMethodsConsensus(validation, use_weighted_analysis);

  return validation;
}


 //+------------------------------------------------------------------+
//| Calcular inclinação avançada do Indicador                       |
//+------------------------------------------------------------------+
// INDICADOR_BASE.GetSlopeValidation->GetAdvancedslope
SSlopeResult CIndicatorBase::GetAdvancedSlope(ENUM_SLOPE_METHOD method,
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

  if (lookback <= 0)
  {
    Print("ERRO: Lookback deve ser maior que zero");
    return result;
  }

  // Obter valores da MA
  double ma_values[];
  if (!CopyValues(0, lookback + 1, ma_values))
  {
    Print("ERRO: Falha ao obter valores para cálculo da inclinação");
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




SPositionInfo CIndicatorBase::GetPositionInfo(int shift){
  SPositionInfo result;
  result.distance = 0.0;
  result = GetPreviousCandlePosition(shift, m_symbol, m_timeframe);
  return result;
}

//+------------------------------------------------------------------------+
//| Retorna a posição do candle anterior em relação ao valor do indicador |
//+------------------------------------------------------------------------+
SPositionInfo CIndicatorBase::GetPreviousCandlePosition(int shift, string symbol, ENUM_TIMEFRAMES tf)
{
  SPositionInfo result;
  result.distance = 0.0;
  double indicator_value = GetValue(shift);
  double open_price = iOpen(symbol, tf, shift);
  double close_price = iClose(symbol, tf, shift);
  double high_price = iHigh(symbol, tf, shift);
  double low_price = iLow(symbol, tf, shift);

  if (indicator_value == EMPTY_VALUE || !MathIsValidNumber(indicator_value) ||
      open_price == EMPTY_VALUE || !MathIsValidNumber(open_price) ||
      close_price == EMPTY_VALUE || !MathIsValidNumber(close_price) ||
      high_price == EMPTY_VALUE || !MathIsValidNumber(high_price) ||
      low_price == EMPTY_VALUE || !MathIsValidNumber(low_price))
  {
    Print("AVISO: Valores inválidos para cálculo da posição do candle em GetPreviousCandlePosition");
    result.position = INDICATOR_CANDLE_POSITION_FAILED;
    return result;
  }

  double tolerance = SymbolInfoDouble(symbol, SYMBOL_POINT) * 15;
  double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
  int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
  double pip_value = (digits == 5 || digits == 3) ? point * 10 : point;

  double body_top = MathMax(open_price, close_price);
  double body_bottom = MathMin(open_price, close_price);

  if (low_price > indicator_value + tolerance)
  {
    result.position = CANDLE_ABOVE_WITH_DISTANCE;
    result.distance = (low_price - indicator_value) / pip_value;
    return result;
  }

  if (high_price < indicator_value - tolerance)
  {
    result.position = CANDLE_BELOW_WITH_DISTANCE;
    result.distance = (indicator_value - high_price) / pip_value;
    return result;
  }

  if (indicator_value > body_top + tolerance && indicator_value <= high_price)
  {
    result.position = INDICATOR_CROSSES_UPPER_SHADOW;
    return result;
  }

  if (indicator_value < body_bottom - tolerance && indicator_value >= low_price)
  {
    result.position = INDICATOR_CROSSES_LOWER_SHADOW;
    return result;
  }

  if (indicator_value >= body_bottom - tolerance && indicator_value <= body_top + tolerance)
  {
    double body_midpoint = (body_top + body_bottom) / 2.0;

    if (indicator_value > body_midpoint + tolerance)
    {
      result.position = INDICATOR_CROSSES_UPPER_BODY;
      return result;
    }
    else if (indicator_value < body_midpoint - tolerance)
    {
      result.position = INDICATOR_CROSSES_LOWER_BODY;
      return result;
    }
    else
    {
      result.position = INDICATOR_ON_CANDLE_EXACT;
      return result;
    }
  }

  result.position = INDICATOR_CANDLE_POSITION_FAILED;
  return result;
}


//+------------------------------------------------------------------+
//| Função auxiliar para obter descrição textual da posição         |
//+------------------------------------------------------------------+
string CIndicatorBase::GetCandlePositionDescription(ENUM_CANDLE_POSITION position)
{
  switch (position)
  {
  case CANDLE_ABOVE_WITH_DISTANCE:
    return "Candle completamente acima do indicador (com distância)";
  case CANDLE_BELOW_WITH_DISTANCE:
    return "Candle completamente abaixo do indicador (com distância)";
  case INDICATOR_CROSSES_UPPER_BODY:
    return "Indicador cruza a parte superior do corpo";
  case INDICATOR_CROSSES_LOWER_BODY:
    return "Indicador cruza a parte inferior do corpo";
  case INDICATOR_CROSSES_UPPER_SHADOW:
    return "Indicador cruza a sombra superior";
  case INDICATOR_CROSSES_LOWER_SHADOW:
    return "Indicador cruza a sombra inferior";
  case INDICATOR_ON_CANDLE_EXACT:
    return "Indicador no nível exato do candle";
  case INDICATOR_CANDLE_POSITION_FAILED:
    return "Falha ao determinar a posição do candle";
  default:
    return "Posição indefinida";
  }
}

#endif // __INDICATOR_BASE_MQH__
