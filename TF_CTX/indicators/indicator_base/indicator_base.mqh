//+------------------------------------------------------------------+
//|                                   indicators/indicator_base.mqh |
//|  Base abstract class for indicators                             |
//+------------------------------------------------------------------+

#ifndef __INDICATOR_BASE_MQH__
#define __INDICATOR_BASE_MQH__
#include "indicator_base_defs.mqh"
#include "submodules/indicator_slope/slope.mqh"
#include "submodules/indicator_candle_distance/indicator_candle_distance.mqh"

class CIndicatorBase
{

protected:
  string m_symbol;             // Símbolo
  ENUM_TIMEFRAMES m_timeframe; // TimeFrame
  int handle;                  // Handlef
  bool attach_chart;           // Flag para acoplar ao gráfico
  ENUM_TIMEFRAMES alert_tf;    // TF para alertas
  // Métodos privados para cálculo de inclinação avançada
  SSlopeResult GetAdvancedSlope(ENUM_SLOPE_METHOD method, int lookback, double atr, COPY_METHOD copy_method = COPY_MIDDLE);
  virtual bool OnCopyValuesForSlope(int shift, int count, double &buffer[], COPY_METHOD copy_method) { return CopyValues(shift, count, buffer); }
  virtual double OnGetIndicatorValue(int shift, COPY_METHOD copy_method) { return GetValue(shift); }
  virtual int OnGetSlopeConfigIndex(COPY_METHOD copy_method) {return 0;};
  SSlopeValues slope_values[];

public:
  virtual bool Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_MA_METHOD method) = 0;
  virtual double GetValue(int shift = 0) = 0;
  virtual bool CopyValues(int shift, int count, double &buffer[]) = 0;
  virtual bool IsReady() = 0;
  virtual bool Update() { return IsReady(); }
  virtual ~CIndicatorBase() {}
  SSlopeValidation GetSlopeValidation(double atr, COPY_METHOD copy_method = COPY_MIDDLE);

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

  SPositionInfo GetPositionInfo(int shift, COPY_METHOD copy_method = COPY_MIDDLE);
  CSlope m_slope; // Classe Cálculo Inclinação
  CIndCandleDistance m_candle_distance;
};
 

//+------------------------------------------------------------------+
//| Validação cruzada com múltiplos métodos de inclinação          |
//+------------------------------------------------------------------+
// PA_WIN CALL
SSlopeValidation CIndicatorBase::GetSlopeValidation(double atr, COPY_METHOD copy_method = COPY_MIDDLE)
{

  int slope_conf_index = OnGetSlopeConfigIndex(copy_method);

  SSlopeValidation validation;

  validation.linear_regression = GetAdvancedSlope(
      SLOPE_LINEAR_REGRESSION,
      slope_values[slope_conf_index].lookback,
      atr);

  validation.simple_difference = GetAdvancedSlope(
      SLOPE_SIMPLE_DIFFERENCE,
      slope_values[slope_conf_index].lookback,
      atr);

  validation.discrete_derivative = GetAdvancedSlope(
      SLOPE_DISCRETE_DERIVATIVE,
      slope_values[slope_conf_index].lookback,
      atr);

  if (validation.linear_regression.slope_value > slope_values[slope_conf_index].linear_reg)
  {
    validation.linear_regression.trend_direction = "_UP";
  }
  else if (validation.linear_regression.slope_value < -slope_values[slope_conf_index].linear_reg)
  {
    validation.linear_regression.trend_direction = "_DOWN";
  }
  else
  {
    validation.linear_regression.trend_direction = "_SIDEWALK";
  }

  // RL norm DIFF
  if (validation.simple_difference.slope_value > slope_values[slope_conf_index].simple_diff)
  {
    validation.simple_difference.trend_direction = "_UP";
  }
  else if (validation.simple_difference.slope_value < -slope_values[slope_conf_index].simple_diff)
  {
    validation.simple_difference.trend_direction = "_DOWN";
  }
  else
  {
    validation.simple_difference.trend_direction = "_SIDEWALK";
  }

  // RL norm ATR
  if (validation.discrete_derivative.slope_value > slope_values[slope_conf_index].discrete_der)
  {
    validation.discrete_derivative.trend_direction = "_UP";
  }
  else if (validation.discrete_derivative.slope_value < -slope_values[slope_conf_index].discrete_der)
  {
    validation.discrete_derivative.trend_direction = "_DOWN";
  }
  else
  {
    validation.discrete_derivative.trend_direction = "_SIDEWALK";
  }

  validation.linear_config_value = slope_values[slope_conf_index].linear_reg;
  validation.difference_config_value = slope_values[slope_conf_index].simple_diff;
  validation.derivative_config_value = slope_values[slope_conf_index].discrete_der;
  validation.lookback_config_value = slope_values[slope_conf_index].lookback;

  return validation;
}

//+------------------------------------------------------------------+
//| Calcular inclinação avançada do Indicador                       |
//+------------------------------------------------------------------+
// INDICADOR_BASE.GetSlopeValidation->GetAdvancedslope
SSlopeResult CIndicatorBase::GetAdvancedSlope(ENUM_SLOPE_METHOD method,
                                              int lookback = 10,
                                              double atr = 0,
                                              COPY_METHOD copy_method = COPY_MIDDLE)
{
  SSlopeResult result;

  if (lookback <= 0)
  {
    Print("ERRO: Lookback deve ser maior que zero");
    return result;
  }

  // Obter valores do buffer usando o método template
  double ma_values[];
  if (!OnCopyValuesForSlope(0, lookback + 1, ma_values, copy_method))
  {
    Print("ERRO: Falha ao obter valores para cálculo da inclinação");
    return result;
  }

  switch (method)
  {
  case SLOPE_LINEAR_REGRESSION:
    result = m_slope.CalculateLinearRegressionSlope(m_symbol, ma_values, atr, lookback);
    break;

  case SLOPE_SIMPLE_DIFFERENCE:
    result = m_slope.CalculateSimpleDifference(m_symbol, ma_values, atr, lookback);
    break;

  case SLOPE_DISCRETE_DERIVATIVE:
    result = m_slope.CalculateDiscreteDerivative(m_symbol, ma_values, atr);
    break;
  }

  return result;
}

SPositionInfo CIndicatorBase::GetPositionInfo(int shift, COPY_METHOD copy_method = COPY_MIDDLE)
{
  double ind_value = OnGetIndicatorValue(shift, copy_method);
  SPositionInfo result;
  result.distance = 0.0;
  result = m_candle_distance.GetPreviousCandlePosition(shift, m_symbol, m_timeframe, ind_value);
  return result;
}

#endif // __INDICATOR_BASE_MQH__
