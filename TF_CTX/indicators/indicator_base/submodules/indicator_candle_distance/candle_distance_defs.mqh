#ifndef __IND_CANDLE_DISTANCE_DEFS_MQH__
#define __IND_CANDLE_DISTANCE_DEFS_MQH__


// Definição dos enums fornecidos
enum ENUM_CANDLE_POSITION
{
  CANDLE_COMPLETELY_ABOVE = 0,          // Candle completamente acima do indicador
  CANDLE_COMPLETELY_BELOW = 1,          // Candle completamente abaixo do indicador
  INDICATOR_CROSSES_UPPER_BODY = 2,     // Indicador cruza a parte superior do corpo
  INDICATOR_CROSSES_LOWER_BODY = 3,     // Indicador cruza a parte inferior do corpo
  INDICATOR_CROSSES_UPPER_SHADOW = 4,   // Indicador cruza a sombra superior
  INDICATOR_CROSSES_LOWER_SHADOW = 5,   // Indicador cruza a sombra inferior
  INDICATOR_CROSSES_CENTER_BODY = 6,    // Indicador cruza meio do corpo
  INDICATOR_CANDLE_POSITION_FAILED = 7, // Falha ao determinar a posição
  CANDLE_ABOVE_WITH_DISTANCE = 8,       // Candle completamente acima com distância
  CANDLE_BELOW_WITH_DISTANCE = 9,       // Candle completamente abaixo com distância
  CANDLE_ABOVE = 10,
  CANDLE_BELOW = 11,
  INDICATOR_TOUCH_LOW,
  INDICATOR_TOUCH_HIGH,
  INDICATOR_TOUCH_BODY_BOTTOM,
  INDICATOR_TOUCH_BODY_TOP,
  INDICATOR_INSIDE_BODY,
  INDICATOR_INSIDE_DOJI


};

//+------------------------------------------------------------------+
//| Estrutura para informações detalhadas da posição do candle       |
//+------------------------------------------------------------------+
struct SPositionInfo
{
  ENUM_CANDLE_POSITION position; // Posição do candle
  double distance;               // Distância em pips (se aplicável)
};
 

#endif