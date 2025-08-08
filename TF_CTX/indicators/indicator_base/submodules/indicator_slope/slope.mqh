#ifndef __INDICATOR_SLOPE_MQH
#define __INDICATOR_SLOPE_MQH
#include "slope_defs.mqh"

class CSlope
{

private:
  string GetTrendClassification(double slope_value, double strong_threshold, double weak_threshold);

protected:
  // Métodos privados para validação cruzada

  double CalculateConfidenceScore(SSlopeValidation &validation);
  double CalculateConsensusStrength(SSlopeValidation &validation);
  double CalculateWeightedSlope(SSlopeValidation &validation, double &weights[]);
  string DetermineRiskLevel(SSlopeValidation &validation);
  double CalculateDirectionalConsensus(SSlopeValidation &validation);

public:
  string GetSlopeAnalysisReport(SSlopeValidation &validation);
  void DebugSlopeValidation(SSlopeValidation &validation);
  // Equações de slope/Inclinação
  SSlopeResult CalculateLinearRegressionSlope(string m_symbol, double &ma_values[], double atr, int lookback);
  SSlopeResult CalculateSimpleDifference(string m_symbol, double &ma_values[], double atr, int lookback);
  SSlopeResult CalculatePercentageChange(string m_symbol, double &ma_values[], int lookback);
  SSlopeResult CalculateDiscreteDerivative(string m_symbol, double &ma_values[],double atr);
  SSlopeResult CalculateAngleDegrees(string m_symbol, double &ma_values[], int lookback);
  SSlopeValidation AnalyzeMethodsConsensus(SSlopeValidation &validation, bool use_weighted_analysis);
};

//+---------------------------------------------------------------------------------------------------------------+
//
//| Funções de Cálculo                                                                                          |
//
//+---------------------------------------------------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calcular inclinação por regressão linear                       |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculateLinearRegressionSlope(string m_symbol, double &ma_values[], double atr, int lookback)
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
  // double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
  // int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
  // double pip_value = (digits == 5 || digits == 3) ? point * 10 : point;
  result.slope_value = result.slope_value / atr;

  return result;
}

//+------------------------------------------------------------------+
//| Calcular diferença simples                                     |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculateSimpleDifference(string m_symbol, double &ma_values[], double atr, int lookback)
{
  SSlopeResult result;
  result.slope_value = ma_values[0] - ma_values[lookback];

  // Normalizar para pips
  // double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
  // int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
  // double pip_value = (digits == 5 || digits == 3) ? point * 10 : point;
  result.slope_value = result.slope_value / atr;

  return result;
}


//+------------------------------------------------------------------+
//| Calcular derivada discreta                                     |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculateDiscreteDerivative(string m_symbol, double &ma_values[], double atr)
{
  SSlopeResult result;
  result.slope_value = ma_values[0] - ma_values[1];

  // Normalizar para pips
  // double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
  // int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
  // double pip_value = (digits == 5 || digits == 3) ? point * 10 : point;
  result.slope_value = result.slope_value / atr;

  return result;
}

//+------------------------------------------------------------------+
//| Calcular mudança percentual                                    |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculatePercentageChange(string m_symbol, double &ma_values[], int lookback)
{
  SSlopeResult result;

  if (ma_values[lookback] != 0.0)
  {
    result.slope_value = ((ma_values[0] / ma_values[lookback]) - 1.0) * 100.0;
  }

  return result;
}

//+------------------------------------------------------------------+
//| Calcular ângulo em graus                                       |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculateAngleDegrees(string m_symbol, double &ma_values[], int lookback)
{
  SSlopeResult result;

  double vertical_diff = ma_values[0] - ma_values[lookback];
  double horizontal_diff = lookback;

  double angle_rad = MathArctan(vertical_diff / horizontal_diff);
  result.slope_value = angle_rad * 180.0 / M_PI;

  return result;
}


//+---------------------------------------------------------------------------------------------------------------+
//
//| Funções de Análise                                                                                          |
//
//+---------------------------------------------------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Obter análise textual detalhada                               |
//+------------------------------------------------------------------+
string CSlope::GetSlopeAnalysisReport(SSlopeValidation &validation)
{
  string report = "";

  report += "=== RELATÓRIO DE ANÁLISE DE INCLINAÇÃO ===\n";
  report += "Tendência Final: " + validation.final_trend + "\n";
  report += "Confiança: " + DoubleToString(validation.confidence_score, 1) + "%\n";
  report += "Consenso: " + DoubleToString(validation.consensus_strength, 1) + "%\n";
  report += "Métodos Concordantes: " + IntegerToString(validation.methods_agreement) + "/5\n";
  report += "Inclinação Ponderada: " + DoubleToString(validation.weighted_slope, 3) + "\n";
  report += "Nível de Risco: " + validation.risk_level + "\n";
  report += "Sinal Confiável: " + (validation.is_reliable ? "SIM" : "NÃO") + "\n\n";

  report += "=== DETALHES POR MÉTODO ===\n";
  report += "Regressão Linear: " + validation.linear_regression.trend_direction +
            " (R²: " + DoubleToString(validation.linear_regression.r_squared, 3) + ")\n";
  report += "Diferença Simples: " + validation.simple_difference.trend_direction + "\n";
  report += "Mudança %: " + validation.percentage_change.trend_direction + "\n";
  report += "Derivada Discreta: " + validation.discrete_derivative.trend_direction + "\n";
  report += "Ângulo: " + validation.angle_degrees.trend_direction + "\n";

  return report;
}

//+------------------------------------------------------------------+
//| Função auxiliar para debug detalhado                           |
//+------------------------------------------------------------------+
void CSlope::DebugSlopeValidation(SSlopeValidation &validation)
{
  Print("=== DEBUG DETALHADO ===");
  Print("Linear Regression: slope=", validation.linear_regression.slope_value,
        ", trend=", validation.linear_regression.trend_direction,
        ", r2=", validation.linear_regression.r_squared);
  Print("Simple Difference: slope=", validation.simple_difference.slope_value,
        ", trend=", validation.simple_difference.trend_direction);

  Print("Discrete Derivative: slope=", validation.discrete_derivative.slope_value,
        ", trend=", validation.discrete_derivative.trend_direction);

  // Print("Percentage Change: slope=", validation.percentage_change.slope_value,
  //       ", trend=", validation.percentage_change.trend_direction);
        // Print("Angle Degrees: slope=", validation.angle_degrees.slope_value,
  //       ", trend=", validation.angle_degrees.trend_direction);

  
  // Print("Final: trend=", validation.final_trend,
  //       ", confidence=", validation.confidence_score,
  //       ", consensus=", validation.consensus_strength,
  //       ", risk=", validation.risk_level);
}


//+---------------------------------------------------------------------------------------------------------------+
//
//| CONFIG DE LIMIARES                                                                                         |
//
//+---------------------------------------------------------------------------------------------------------------+

SThresholdConfig GetOptimizedConfig(ENUM_TIMEFRAMES tf, ENUM_TRADING_STYLE style = TRADING_SWING)
{
  SThresholdConfig config;

  switch (tf)
  {
  case PERIOD_M1:
    config.lookback = (style == TRADING_SCALPING) ? 5 : (style == TRADING_SWING) ? 8
                                                                                 : 10;
    config.linear_regression_high = (style == TRADING_SCALPING) ? 0.25 : 0.2;
    config.simple_difference_high = (style == TRADING_SCALPING) ? 0.20 : 0.15;
    config.percentage_change_high = (style == TRADING_SCALPING) ? 0.008 : 0.01;
    config.discrete_derivative_high = (style == TRADING_SCALPING) ? 4.0 : 5.0;
    config.angle_degrees_high = (style == TRADING_SCALPING) ? 6.0 : 8.0;
    break;

  case PERIOD_M5:
    config.lookback = (style == TRADING_SCALPING) ? 6 : (style == TRADING_SWING) ? 10
                                                                                 : 12;
    config.linear_regression_high = (style == TRADING_SCALPING) ? 3.0 : 4.0;
    config.simple_difference_high = (style == TRADING_SCALPING) ? 20.0 : 25.0;
    config.percentage_change_high = (style == TRADING_SCALPING) ? 0.015 : 0.02;
    config.discrete_derivative_high = (style == TRADING_SCALPING) ? 6.0 : 8.0;
    config.angle_degrees_high = (style == TRADING_SCALPING) ? 10.0 : 12.0;
    break;

  case PERIOD_M15:
    config.lookback = (style == TRADING_SCALPING) ? 8 : (style == TRADING_SWING) ? 12
                                                                                 : 15;
    config.linear_regression_high = (style == TRADING_SCALPING) ? 0.15 : 0.2;
    config.simple_difference_high = (style == TRADING_SCALPING) ? 1.5 : 2.0;
    config.discrete_derivative_high = (style == TRADING_SCALPING) ? 0.15 : 0.2;

    // config.percentage_change_high = (style == TRADING_SCALPING) ? 0 : 0;
    // config.angle_degrees_high = (style == TRADING_SCALPING) ? 0 : 0;
    break;

  case PERIOD_M30:
    config.lookback = (style == TRADING_SCALPING) ? 10 : (style == TRADING_SWING) ? 15
                                                                                  : 20;
    config.linear_regression_high = 8.0;
    config.simple_difference_high = 50.0;
    config.percentage_change_high = 0.03;
    config.discrete_derivative_high = 15.0;
    config.angle_degrees_high = 22.0;
    break;

  case PERIOD_H1:
    config.lookback = (style == TRADING_SCALPING) ? 12 : (style == TRADING_SWING) ? 18
                                                                                  : 25;
    config.linear_regression_high = (style == TRADING_POSITION) ? 12.0 : 10.0;
    config.simple_difference_high = (style == TRADING_POSITION) ? 80.0 : 60.0;
    config.percentage_change_high = (style == TRADING_POSITION) ? 0.05 : 0.04;
    config.discrete_derivative_high = (style == TRADING_POSITION) ? 25.0 : 20.0;
    config.angle_degrees_high = (style == TRADING_POSITION) ? 35.0 : 30.0;
    break;

  case PERIOD_H4:
    config.lookback = (style == TRADING_SWING) ? 22 : (style == TRADING_POSITION) ? 30
                                                                                  : 25;
    config.linear_regression_high = (style == TRADING_POSITION) ? 18.0 : 15.0;
    config.simple_difference_high = (style == TRADING_POSITION) ? 120.0 : 100.0;
    config.percentage_change_high = (style == TRADING_POSITION) ? 0.08 : 0.06;
    config.discrete_derivative_high = (style == TRADING_POSITION) ? 35.0 : 30.0;
    config.angle_degrees_high = (style == TRADING_POSITION) ? 45.0 : 40.0;
    break;

  case PERIOD_D1:
    config.lookback = (style == TRADING_POSITION) ? 35 : 25;
    config.linear_regression_high = (style == TRADING_POSITION) ? 30.0 : 25.0;
    config.simple_difference_high = (style == TRADING_POSITION) ? 180.0 : 150.0;
    config.percentage_change_high = (style == TRADING_POSITION) ? 0.12 : 0.10;
    config.discrete_derivative_high = (style == TRADING_POSITION) ? 60.0 : 50.0;
    config.angle_degrees_high = (style == TRADING_POSITION) ? 70.0 : 60.0;
    break;
  }

  // Definir valores negativos
  config.linear_regression_low = -config.linear_regression_high;
  config.simple_difference_low = -config.simple_difference_high;
  config.percentage_change_low = -config.percentage_change_high;
  config.discrete_derivative_low = -config.discrete_derivative_high;
  config.angle_degrees_low = -config.angle_degrees_high;

  return config;
}

#endif