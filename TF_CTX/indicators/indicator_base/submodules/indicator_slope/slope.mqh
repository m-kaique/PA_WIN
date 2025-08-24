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
  SSlopeResult CalculateDiscreteDerivative(string m_symbol, double &ma_values[], double atr, int lookback);
  SSlopeResult CalculateAngleDegrees(string m_symbol, double &ma_values[], int lookback);
  SSlopeValidation AnalyzeMethodsConsensus(SSlopeValidation &validation, bool use_weighted_analysis);
};

//+---------------------------------------------------------------------------------------------------------------+
//
//| Funções de Cálculo                                                                                          |
//
//+---------------------------------------------------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calcular inclinação por regressão linear (normalizado por ATR)  |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculateLinearRegressionSlope(string m_symbol, double &ma_values[], double atr, int lookback)
{
  SSlopeResult result;
  result.slope_value = 0.0;
  result.r_squared = 0.0;

  double sum_x = 0.0, sum_y = 0.0, sum_xy = 0.0, sum_x2 = 0.0, sum_y2 = 0.0;
  int n = lookback;

  for (int i = 0; i < n; i++)
  {
    double x = i;                      // tempo: passado → presente
    double y = ma_values[n - 1 - i];   // inverter: ma_values[0] = mais recente
    sum_x  += x;
    sum_y  += y;
    sum_xy += x * y;
    sum_x2 += x * x;
    sum_y2 += y * y;
  }

  double denominator = n * sum_x2 - sum_x * sum_x;
  if (denominator != 0.0)
  {
    result.slope_value = (n * sum_xy - sum_x * sum_y) / denominator;

    double numerator = n * sum_xy - sum_x * sum_y;
    double denom_r2 = MathSqrt((n * sum_x2 - sum_x * sum_x) * (n * sum_y2 - sum_y * sum_y));
    if (denom_r2 != 0.0)
    {
      double r = numerator / denom_r2;
      result.r_squared = r * r;
    }
  }

  if (atr != 0.0)
    result.slope_value /= atr;   // ✅ normalizar pela volatilidade
  else
    result.slope_value = 0.0;

  return result;
}

//+------------------------------------------------------------------+
//| Calcular diferença simples (normalizado por ATR)                |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculateSimpleDifference(string m_symbol, double &ma_values[], double atr, int lookback)
{
  SSlopeResult result;
  result.slope_value = ma_values[0] - ma_values[lookback - 1];  // corrigido índice

  if (atr != 0.0)
    result.slope_value /= atr;   // ✅ normalizar pela volatilidade
  else
    result.slope_value = 0.0;

  return result;
}

//+------------------------------------------------------------------+
//| Calcular derivada discreta (normalizado por ATR)                |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculateDiscreteDerivative(string m_symbol, double &ma_values[], double atr, int lookback)
{
  SSlopeResult result;
  
  // Usar o mesmo lookback dos outros métodos para consistência
  int period = (lookback > 1) ? lookback : 2;
  
  // Calcular a derivada discreta: (f(x) - f(x-n)) / n
  // Onde n é o período de lookback
  result.slope_value = (ma_values[0] - ma_values[period - 1]) / (double)period;

  if (atr != 0.0)
    result.slope_value /= atr;   // normalizar pela volatilidade
  else
    result.slope_value = 0.0;

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
  report += "Derivada Discreta: " + validation.discrete_derivative.trend_direction + "\n"; 

  return report;
}

//+------------------------------------------------------------------+
//| Função auxiliar para debug detalhado                           |
//+------------------------------------------------------------------+
void CSlope::DebugSlopeValidation(SSlopeValidation &validation)
{
  Print("=== DEBUG DETALHADO ===");
  Print("Linear Regression: slope=", (string)validation.linear_regression.slope_value,
        ", trend=", validation.linear_regression.trend_direction,
        ", r2=", (string)validation.linear_regression.r_squared);
  Print("Simple Difference: slope=", (string)validation.simple_difference.slope_value,
        ", trend=", validation.simple_difference.trend_direction);

  Print("Discrete Derivative: slope=", (string)validation.discrete_derivative.slope_value,
        ", trend=", validation.discrete_derivative.trend_direction);

  Print("# JSON VALUES # " , "LR: " ,validation.linear_config_value, " SD: ", validation.difference_config_value, " DD: ",
  validation.derivative_config_value,  " Lookback: " , validation.lookback_config_value);

}

#endif