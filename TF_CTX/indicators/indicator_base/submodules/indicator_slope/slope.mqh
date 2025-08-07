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
  SSlopeResult CalculateLinearRegressionSlope(string m_symbol, double &ma_values[], int lookback);
  SSlopeResult CalculateSimpleDifference(string m_symbol, double &ma_values[], int lookback);
  SSlopeResult CalculatePercentageChange(string m_symbol, double &ma_values[], int lookback);
  SSlopeResult CalculateDiscreteDerivative(string m_symbol, double &ma_values[]);
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
  // double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
  // int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
  // double pip_value = (digits == 5 || digits == 3) ? point * 10 : point;
  //result.slope_value = result.slope_value / pip_value;

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
  // double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
  // int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
  // double pip_value = (digits == 5 || digits == 3) ? point * 10 : point;
  // result.slope_value = result.slope_value / pip_value;

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
//| Calcular derivada discreta                                     |
//+------------------------------------------------------------------+
SSlopeResult CSlope::CalculateDiscreteDerivative(string m_symbol, double &ma_values[])
{
  SSlopeResult result;
  result.slope_value = ma_values[0] - ma_values[1];

  // Normalizar para pips
  // double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
  // int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
  // double pip_value = (digits == 5 || digits == 3) ? point * 10 : point;
  // result.slope_value = result.slope_value / pip_value;

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
//| Obter classificação da tendência/Inclinação baseada em bandas   |
//+------------------------------------------------------------------+
string CSlope::GetTrendClassification(double slope_value,
                                      double strong_threshold = 1.0,
                                      double weak_threshold = 0.3)
{
  if (slope_value > strong_threshold)
    return "ALTA_FORTE";
  else if (slope_value > weak_threshold)
    return "ALTA_FRACA";
  else if (slope_value < -strong_threshold)
    return "BAIXA_FORTE";
  else if (slope_value < -weak_threshold)
    return "BAIXA_FRACA";
  else
    return "LATERAL";
}

//+------------------------------------------------------------------+
//| Analisar consenso entre métodos                                |
//+------------------------------------------------------------------+
SSlopeValidation CSlope::AnalyzeMethodsConsensus(SSlopeValidation &validation, bool use_weighted_analysis)
{
  // Array com as direções de cada método
  string directions[5] = {
      validation.linear_regression.trend_direction,
      validation.simple_difference.trend_direction,
      validation.percentage_change.trend_direction,
      validation.discrete_derivative.trend_direction,
      validation.angle_degrees.trend_direction};

  // Array com os valores de slope para análise adicional
  double slopes[5] = {
      validation.linear_regression.slope_value,
      validation.simple_difference.slope_value,
      validation.percentage_change.slope_value,
      validation.discrete_derivative.slope_value,
      validation.angle_degrees.slope_value};

  // Pesos para cada método (ajustáveis conforme preferência)
  double weights[5] = {0.30, 0.20, 0.20, 0.15, 0.15}; // Regressão linear tem maior peso

  // Contar votos para cada direção
  int votes_alta = 0, votes_baixa = 0, votes_lateral = 0;
  double weighted_alta = 0.0, weighted_baixa = 0.0, weighted_lateral = 0.0;

  for (int i = 0; i < 5; i++)
  {
    if (directions[i] == "ALTA")
    {
      votes_alta++;
      weighted_alta += weights[i];
    }
    else if (directions[i] == "BAIXA")
    {
      votes_baixa++;
      weighted_baixa += weights[i];
    }
    else
    {
      votes_lateral++;
      weighted_lateral += weights[i];
    }
  }

  // Determinar tendência final
  if (use_weighted_analysis)
  {
    // Análise ponderada
    if (weighted_alta > weighted_baixa && weighted_alta > weighted_lateral)
    {
      validation.final_trend = "ALTA";
      validation.methods_agreement = (int)(weighted_alta * 100);
    }
    else if (weighted_baixa > weighted_alta && weighted_baixa > weighted_lateral)
    {
      validation.final_trend = "BAIXA";
      validation.methods_agreement = (int)(weighted_baixa * 100);
    }
    else
    {
      validation.final_trend = "LATERAL";
      validation.methods_agreement = (int)(weighted_lateral * 100);
    }
  }
  else
  {
    // Análise por maioria simples
    if (votes_alta > votes_baixa && votes_alta > votes_lateral)
    {
      validation.final_trend = "ALTA";
      validation.methods_agreement = votes_alta;
    }
    else if (votes_baixa > votes_alta && votes_baixa > votes_lateral)
    {
      validation.final_trend = "BAIXA";
      validation.methods_agreement = votes_baixa;
    }
    else
    {
      validation.final_trend = "LATERAL";
      validation.methods_agreement = votes_lateral;
    }
  }

  // Calcular nível de confiança
  validation.confidence_score = CalculateConfidenceScore(validation);

  // Tentar calcular força do consenso, usar alternativa se falhar
  validation.consensus_strength = CalculateConsensusStrength(validation);

  if (validation.consensus_strength == 0.0)
  {
    validation.consensus_strength = CalculateDirectionalConsensus(validation);
  }

  // Calcular inclinação ponderada
  validation.weighted_slope = CalculateWeightedSlope(validation, weights);

  // Critério mais flexível para sinal confiável
  validation.is_reliable = (validation.confidence_score >= 50.0 && validation.methods_agreement >= 2);

  // Determinar nível de risco com correções
  validation.risk_level = DetermineRiskLevel(validation);

  return validation;
}

//+------------------------------------------------------------------+
//| Calcular score de confiança                                    |
//+------------------------------------------------------------------+
double CSlope::CalculateConfidenceScore(SSlopeValidation &validation)
{
  double score = 0.0;

  // CORREÇÃO: Peso baseado na concordância entre métodos (0-5 para 0-100)
  double agreement_ratio = (double)validation.methods_agreement / 5.0;
  if (validation.methods_agreement > 5) // Se for percentual
    agreement_ratio = (double)validation.methods_agreement / 100.0;

  score += agreement_ratio * 40.0;

  // Peso baseado na qualidade da regressão linear (R²)
  score += validation.linear_regression.r_squared * 30.0;

  // CORREÇÃO: Peso baseado na força média das tendências
  double avg_strength = (validation.linear_regression.trend_strength +
                         validation.simple_difference.trend_strength +
                         validation.percentage_change.trend_strength +
                         validation.discrete_derivative.trend_strength +
                         validation.angle_degrees.trend_strength) /
                        5.0;
  score += (avg_strength / 100.0) * 30.0;

  return MathMin(100.0, MathMax(0.0, score));
}
//+------------------------------------------------------------------+
//| Calcular força do consenso                                     |
//+------------------------------------------------------------------+
double CSlope::CalculateConsensusStrength(SSlopeValidation &validation)
{
  // Verificar consistência dos sinais
  double slopes[5] = {
      validation.linear_regression.slope_value,
      validation.simple_difference.slope_value,
      validation.percentage_change.slope_value,
      validation.discrete_derivative.slope_value,
      validation.angle_degrees.slope_value};

  // CORREÇÃO: Lógica correta para validar números
  int valid_count = 0;
  double valid_slopes[5];

  for (int i = 0; i < 5; i++)
  {
    // CORREÇÃO: Condição correta - pular se for 0 OU inválido
    if (slopes[i] == 0.0 || !MathIsValidNumber(slopes[i]))
      continue;
    valid_slopes[valid_count] = slopes[i];
    valid_count++;
  }

  if (valid_count < 2)
    return 0.0;

  // Calcular desvio padrão dos slopes válidos
  double mean = 0.0;
  for (int i = 0; i < valid_count; i++)
    mean += valid_slopes[i];
  mean /= valid_count;

  double variance = 0.0;
  for (int i = 0; i < valid_count; i++)
    variance += MathPow(valid_slopes[i] - mean, 2);
  variance /= valid_count;

  double std_dev = MathSqrt(variance);

  // CORREÇÃO: Ajustar desvio esperado baseado na magnitude dos valores
  double max_expected_deviation = MathMax(0.5, MathAbs(mean) * 0.3);
  double consensus = 100.0 * (1.0 - MathMin(std_dev / max_expected_deviation, 1.0));

  // // CORREÇÃO: Adicionar debug para diagnosticar
  // Print("DEBUG Consensus: valid_count=", valid_count, ", mean=", mean,
  //       ", std_dev=", std_dev, ", max_expected_dev=", max_expected_deviation,
  //       ", consensus=", consensus);

  return MathMax(0.0, consensus);
}

//+------------------------------------------------------------------+
//| Calcular inclinação ponderada                                  |
//+------------------------------------------------------------------+
double CSlope::CalculateWeightedSlope(SSlopeValidation &validation, double &weights[])
{
  double slopes[5] = {
      validation.linear_regression.slope_value,
      validation.simple_difference.slope_value,
      validation.percentage_change.slope_value,
      validation.discrete_derivative.slope_value,
      validation.angle_degrees.slope_value};

  double weighted_sum = 0.0;
  for (int i = 0; i < 5; i++)
    weighted_sum += slopes[i] * weights[i];

  return weighted_sum;
}

//+------------------------------------------------------------------+
//| Determinar nível de risco                                      |
//+------------------------------------------------------------------+
string CSlope::DetermineRiskLevel(SSlopeValidation &validation)
{
  // CORREÇÃO: Critérios mais balanceados e alternativos
  double confidence = validation.confidence_score;
  double consensus = validation.consensus_strength;
  int agreement = validation.methods_agreement;

  // Debug para diagnosticar
  // Print("DEBUG Risk: confidence=", confidence, ", consensus=", consensus,
  //       ", agreement=", agreement);

  // CORREÇÃO: Usar critérios alternativos quando consensus falha
  if (consensus > 0.0)
  {
    // Usar critério original quando consensus é válido
    if (confidence >= 70.0 && consensus >= 60.0)
      return "BAIXO";
    else if (confidence >= 50.0 && consensus >= 40.0)
      return "MEDIO";
    else
      return "ALTO";
  }
  else
  {
    // CORREÇÃO: Critério alternativo baseado em confidence e agreement
    if (confidence >= 80.0 && agreement >= 4)
      return "BAIXO";
    else if (confidence >= 60.0 && agreement >= 3)
      return "MEDIO";
    else
      return "ALTO";
  }
}
//+------------------------------------------------------------------+
//| Versão alternativa usando apenas direções (sem slopes)         |
//+------------------------------------------------------------------+
double CSlope::CalculateDirectionalConsensus(SSlopeValidation &validation)
{
  // Array com as direções de cada método
  string directions[5] = {
      validation.linear_regression.trend_direction,
      validation.simple_difference.trend_direction,
      validation.percentage_change.trend_direction,
      validation.discrete_derivative.trend_direction,
      validation.angle_degrees.trend_direction};

  // Contar concordâncias
  int max_agreement = 0;
  string directions_unique[3] = {"ALTA", "BAIXA", "LATERAL"};

  for (int i = 0; i < 3; i++)
  {
    int count = 0;
    for (int j = 0; j < 5; j++)
    {
      if (directions[j] == directions_unique[i])
        count++;
    }
    if (count > max_agreement)
      max_agreement = count;
  }

  // Converter para percentual
  double consensus = (max_agreement / 5.0) * 100.0;

  // Print("DEBUG Directional Consensus: max_agreement=", max_agreement,
  //       ", consensus=", consensus);

  return consensus;
}

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
  // Print("Percentage Change: slope=", validation.percentage_change.slope_value,
  //       ", trend=", validation.percentage_change.trend_direction);
  Print("Discrete Derivative: slope=", validation.discrete_derivative.slope_value,
        ", trend=", validation.discrete_derivative.trend_direction);
  // Print("Angle Degrees: slope=", validation.angle_degrees.slope_value,
  //       ", trend=", validation.angle_degrees.trend_direction);

  // Print("Final: trend=", validation.final_trend,
  //       ", confidence=", validation.confidence_score,
  //       ", consensus=", validation.consensus_strength,
  //       ", risk=", validation.risk_level);
}


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
    config.linear_regression_high = (style == TRADING_SCALPING) ? 0.2 : 0.2;
    config.simple_difference_high = (style == TRADING_SCALPING) ? 35.0 : 40.0;
    config.percentage_change_high = (style == TRADING_SCALPING) ? 0.02 : 0.025;
    config.discrete_derivative_high = (style == TRADING_SCALPING) ? 10.0 : 12.0;
    config.angle_degrees_high = (style == TRADING_SCALPING) ? 15.0 : 18.0;
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