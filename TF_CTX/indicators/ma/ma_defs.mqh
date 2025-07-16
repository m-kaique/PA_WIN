#ifndef __MA_DEFS_MQH__
#define __MA_DEFS_MQH__

// Enumerations for Moving Average indicator

enum ENUM_MA_TYPE
{
  MA_TYPE_SMA = MODE_SMA,
  MA_TYPE_EMA = MODE_EMA,
  MA_TYPE_SMMA = MODE_SMMA,
  MA_TYPE_LWMA = MODE_LWMA
};

//+------------------------------------------------------------------+
//| Enumeração para métodos de cálculo de inclinação               |
//+------------------------------------------------------------------+
enum ENUM_SLOPE_METHOD
{
  SLOPE_LINEAR_REGRESSION,   // Regressão linear (mínimos quadrados)
  SLOPE_SIMPLE_DIFFERENCE,   // Diferença simples entre períodos
  SLOPE_PERCENTAGE_CHANGE,   // Mudança percentual
  SLOPE_DISCRETE_DERIVATIVE, // Derivada discreta
  SLOPE_ANGLE_DEGREES        // Ângulo em graus
};

//+------------------------------------------------------------------+
//| Estrutura para resultado da análise de inclinação              |
//+------------------------------------------------------------------+
struct SSlopeResult
{
  double slope_value;     // Valor da inclinação
  double r_squared;       // Coeficiente de determinação (apenas para regressão linear)
  string trend_direction; // "ALTA", "BAIXA", "LATERAL"
  double trend_strength;  // Força da tendência (0-100)
};

//+------------------------------------------------------------------+
//| Estrutura para resultado da validação cruzada                  |
//+------------------------------------------------------------------+
struct SSlopeValidation
{
    // Resultados individuais de cada método
    SSlopeResult linear_regression;
    SSlopeResult simple_difference;
    SSlopeResult percentage_change;
    SSlopeResult discrete_derivative;
    SSlopeResult angle_degrees;
    
    // Análise consolidada
    string final_trend;           // Tendência final consolidada
    double confidence_score;      // Nível de confiança (0-100)
    double consensus_strength;    // Força do consenso entre métodos
    int methods_agreement;        // Quantos métodos concordam
    bool is_reliable;            // Se o sinal é confiável
    
    // Pesos e scores
    double weighted_slope;        // Inclinação ponderada
    string risk_level;           // Nível de risco do sinal
};
#endif // __MA_DEFS_MQH__
