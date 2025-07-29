//+------------------------------------------------------------------+
//|                                         indicators/indicator_base_defs.mqh |
//|  Definitions for CIndicatorBase and related functionalities       |
//+------------------------------------------------------------------+
#ifndef __INDICATOR_BASE_DEFS_MQH__
#define __INDICATOR_BASE_DEFS_MQH__

// //+------------------------------------------------------------------+
// //| Enumeração para métodos de cálculo de inclinação               |
// //+------------------------------------------------------------------+
// enum ENUM_SLOPE_METHOD
// {
//   SLOPE_LINEAR_REGRESSION,   // Regressão linear (mínimos quadrados)
//   SLOPE_SIMPLE_DIFFERENCE,   // Diferença simples entre períodos
//   SLOPE_PERCENTAGE_CHANGE,   // Mudança percentual
//   SLOPE_DISCRETE_DERIVATIVE, // Derivada discreta
//   SLOPE_ANGLE_DEGREES        // Ângulo em graus
// };

// //+------------------------------------------------------------------+
// //| Estrutura para resultado da análise de inclinação              |
// //+------------------------------------------------------------------+
// struct SSlopeResult
// {
//   double slope_value;     // Valor da inclinação
//   double r_squared;       // Coeficiente de determinação (apenas para regressão linear)
//   string trend_direction; // "ALTA", "BAIXA", "LATERAL"
//   double trend_strength;  // Força da tendência (0-100)
// };

// //+------------------------------------------------------------------+
// //| Estrutura para resultado da validação cruzada                  |
// //+------------------------------------------------------------------+
// struct SSlopeValidation
// {
//   // Resultados individuais de cada método
//   SSlopeResult linear_regression;
//   SSlopeResult simple_difference;
//   SSlopeResult percentage_change;
//   SSlopeResult discrete_derivative;
//   SSlopeResult angle_degrees;

//   // Análise consolidada
//   string final_trend;        // Tendência final consolidada
//   double confidence_score;   // Nível de confiança (0-100)
//   double consensus_strength; // Força do consenso entre métodos
//   int methods_agreement;     // Quantos métodos concordam
//   bool is_reliable;          // Se o sinal é confiável

//   // Pesos e scores
//   double weighted_slope; // Inclinação ponderada
//   string risk_level;     // Nível de risco do sinal
// };

// enum COPY_METHOD
// {
//   COPY_UPPER,
//   COPY_LOWER,
//   COPY_MIDDLE
// };

//+------------------------------------------------------------------+
//| Enumeração para a posição do candle em relação ao indicador      |
//+------------------------------------------------------------------+
enum ENUM_CANDLE_POSITION
{
  CANDLE_COMPLETELY_ABOVE = 0,          // Candle completamente acima do indicador
  CANDLE_COMPLETELY_BELOW = 1,          // Candle completamente abaixo do indicador
  INDICATOR_CROSSES_UPPER_BODY = 2,     // Indicador cruza a parte superior do corpo
  INDICATOR_CROSSES_LOWER_BODY = 3,     // Indicador cruza a parte inferior do corpo
  INDICATOR_CROSSES_UPPER_SHADOW = 4,   // Indicador cruza a sombra superior
  INDICATOR_CROSSES_LOWER_SHADOW = 5,   // Indicador cruza a sombra inferior
  INDICATOR_ON_CANDLE_EXACT = 6,        // Indicador no nível exato do candle
  INDICATOR_CANDLE_POSITION_FAILED = 7, // Falha ao determinar a posição
  CANDLE_ABOVE_WITH_DISTANCE = 8,       // Candle completamente acima com distância
  CANDLE_BELOW_WITH_DISTANCE = 9        // Candle completamente abaixo com distância
};

//+------------------------------------------------------------------+
//| Estrutura para informações detalhadas da posição do candle       |
//+------------------------------------------------------------------+
struct SPositionInfo
{
  ENUM_CANDLE_POSITION position; // Posição do candle
  double distance;               // Distância em pips (se aplicável)
};

// struct SThresholdConfig {
//     int lookback;
//     double linear_regression_high, linear_regression_low;
//     double simple_difference_high, simple_difference_low;
//     double percentage_change_high, percentage_change_low;
//     double discrete_derivative_high, discrete_derivative_low;
//     double angle_degrees_high, angle_degrees_low;
// };

// enum ENUM_TRADING_STYLE {
//     TRADING_SCALPING,
//     TRADING_SWING,
//     TRADING_POSITION
// };
#endif // __INDICATOR_BASE_DEFS_MQH__
