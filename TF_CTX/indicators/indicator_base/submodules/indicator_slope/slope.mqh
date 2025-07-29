#ifndef __INDICATOR_SLOPE_MQH
#define __INDICATOR_SLOPE_MQH
#include "slope_defs.mqh"

class CSlope
{

private:


public:
   SSlopeResult CalculateLinearRegressionSlope(string m_symbol, double &ma_values[], int lookback);
   SSlopeResult CalculateSimpleDifference(string m_symbol, double &ma_values[], int lookback);
   SSlopeResult CalculatePercentageChange(string m_symbol,double &ma_values[], int lookback);
   SSlopeResult CalculateDiscreteDerivative(string m_symbol,double &ma_values[]);
   SSlopeResult CalculateAngleDegrees(string m_symbol,double &ma_values[], int lookback);
};


//+------------------------------------------------------------------+
//| Calcular inclinação por regressão linear                       |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculateLinearRegressionSlope(string m_symbol, double &ma_values[], int lookback)
{
  SSlopeResult result;
  result.slope_value = 0.0;
  result.r_squared = 0.0;

  double sum_x = 0.0, sum_y = 0.0, sum_xy = 0.0, sum_x2 = 0.0, sum_y2 = 0.0;
  int n = lookback;

  // CORREÇÃO: Usar índices temporais corretos
  // x representa tempo: valores maiores = mais recente
  // y representa valor da MA
  for (int i = 0; i < n; i++)
  {
    double x = n - i;        // ✅ Tempo crescente: passado → presente
    double y = ma_values[i]; // ma_values[0] = mais recente

    sum_x += x;
    sum_y += y;
    sum_xy += x * y;
    sum_x2 += x * x;
    sum_y2 += y * y;
  }

  // Calcular slope (inclinação)
  double denominator = n * sum_x2 - sum_x * sum_x;
  if (denominator != 0.0)
  {
    result.slope_value = (n * sum_xy - sum_x * sum_y) / denominator;

    // Calcular R² (coeficiente de determinação)
    double numerator = n * sum_xy - sum_x * sum_y;
    double denom_r2 = MathSqrt((n * sum_x2 - sum_x * sum_x) * (n * sum_y2 - sum_y * sum_y));
    if (denom_r2 != 0.0)
    {
      double r = numerator / denom_r2;
      result.r_squared = r * r;
    }
  }

  // Normalizar para pips
  double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
  int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
  double pip_value = (digits == 5 || digits == 3) ? point * 10 : point;
  result.slope_value = result.slope_value / pip_value;

  return result;
}

//+------------------------------------------------------------------+
//| Calcular diferença simples                                     |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculateSimpleDifference(string m_symbol, double &ma_values[], int lookback)
{
  SSlopeResult result;
  result.slope_value = ma_values[0] - ma_values[lookback];

  // Normalizar para pips
  double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
  int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
  double pip_value = (digits == 5 || digits == 3) ? point * 10 : point;
  result.slope_value = result.slope_value / pip_value;

  return result;
}

//+------------------------------------------------------------------+
//| Calcular mudança percentual                                    |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculatePercentageChange(string m_symbol,double &ma_values[], int lookback)
{
  SSlopeResult result;

  if (ma_values[lookback] != 0.0)
  {
    result.slope_value = ((ma_values[0] / ma_values[lookback]) - 1.0) * 100.0;
  }

  return result;
}

//+------------------------------------------------------------------+
//| Calcular derivada discreta                                     |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculateDiscreteDerivative(string m_symbol,double &ma_values[])
{
  SSlopeResult result;
  result.slope_value = ma_values[0] - ma_values[1];

  // Normalizar para pips
  double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
  int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
  double pip_value = (digits == 5 || digits == 3) ? point * 10 : point;
  result.slope_value = result.slope_value / pip_value;

  return result;
}

//+------------------------------------------------------------------+
//| Calcular ângulo em graus                                       |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculateAngleDegrees(string m_symbol,double &ma_values[], int lookback)
{
  SSlopeResult result;

  double vertical_diff = ma_values[0] - ma_values[lookback];
  double horizontal_diff = lookback;

  double angle_rad = MathArctan(vertical_diff / horizontal_diff);
  result.slope_value = angle_rad * 180.0 / M_PI;

  return result;
}

#endif