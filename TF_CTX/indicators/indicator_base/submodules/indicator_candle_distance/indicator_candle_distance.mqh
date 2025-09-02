#ifndef __IND_CANDLE_DISTANCE_MQH__
#define __IND_CANDLE_DISTANCE_MQH__
#include "candle_distance_defs.mqh"

class CIndCandleDistance
{
public:
  SPositionInfo GetPreviousCandlePosition(int shift, string symbol, ENUM_TIMEFRAMES tf, double indValue, double atr);
  string GetCandlePositionDescription(ENUM_CANDLE_POSITION position);
};

//+------------------------------------------------------------------------+
//| Retorna a posição do candle anterior em relação ao valor do indicador |
//+------------------------------------------------------------------------+
SPositionInfo CIndCandleDistance::GetPreviousCandlePosition(int shift, string symbol, ENUM_TIMEFRAMES tf, double indValue, double atr)
{
  SPositionInfo result;
  result.distance = 0.0;
  double indicator_value = indValue;
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

  double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
  int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

  double pip_value = (digits == 5 || digits == 3) ? point * 10 : point;
  double tolerance = point * (atr * 0.09); // Tolerância de +- 15 pontos com atr em prox de 165

  double body_top = MathMax(open_price, close_price);
  double body_bottom = MathMin(open_price, close_price);
  bool has_body = (MathAbs(open_price - close_price) > tolerance);
  bool has_upper_shadow = (high_price > body_top);
  bool has_lower_shadow = (low_price < body_bottom);

  // Conditions

  // above
  bool is_above_with_distance = (low_price > indicator_value + tolerance);
  bool is_above = (low_price > indicator_value);

  // below
  bool is_below_with_distance = (high_price < indicator_value - tolerance);
  bool is_below = (high_price < indicator_value);

  // shadow
  bool is_upper_shadow_cross = has_upper_shadow && (indicator_value > body_top) && (indicator_value <= high_price);
  bool is_lower_shadow_cross = has_lower_shadow && (indicator_value < body_bottom) && (indicator_value >= low_price);

  if (is_above_with_distance)
  {
    result.position = CANDLE_ABOVE_WITH_DISTANCE;
    result.distance = (low_price - indicator_value) / pip_value;
    return result;
  }

  if (is_above)
  {
    result.position = CANDLE_ABOVE;
    result.distance = (low_price - indicator_value) / pip_value;
    return result;
  }

  if (is_upper_shadow_cross)
  {
    result.position = INDICATOR_CROSSES_UPPER_SHADOW;
    return result;
  }

  if (is_below_with_distance)
  {
    result.position = CANDLE_BELOW_WITH_DISTANCE;
    result.distance = (indicator_value - high_price) / pip_value;
    return result;
  }

  if (is_below)
  {
    result.position = CANDLE_BELOW;
    result.distance = (indicator_value - high_price) / pip_value;
    return result;
  }

  if (is_lower_shadow_cross)
  {
    result.position = INDICATOR_CROSSES_LOWER_SHADOW;
    return result;
  }

  if (has_body)
  {
    // body maths
    double body_gap = (body_top - body_bottom) * 0.3; // 30% do corpo
    double upper_start = body_top - body_gap;
    double bottom_start = body_bottom + body_gap;

    bool is_on_body = (indicator_value >= body_bottom) && (indicator_value <= body_top);
    bool is_upper_body_cross = (indicator_value >= upper_start);
    bool is_lower_body_cross = (indicator_value <= bottom_start);

    if (is_on_body)
    {
      if (is_upper_body_cross)
      {
        result.position = INDICATOR_CROSSES_UPPER_BODY;
        return result;
      }
      else if (is_lower_body_cross)
      {
        result.position = INDICATOR_CROSSES_LOWER_BODY;
        return result;
      }
      else
      {
        result.position = INDICATOR_CROSSES_CENTER_BODY;
        return result;
      }
    }
  }

  // Se não há corpo, mas o indicador está no nível do preço de abertura/fechamento
  if (indicator_value == open_price && indicator_value == close_price)
  {
    result.position = INDICATOR_CROSSES_CENTER_BODY;
    return result;
  }

  result.position = INDICATOR_CANDLE_POSITION_FAILED;
  Print("Falha ao classificar posição com os valores:");
  Print("Open: ", (string)open_price);
  Print("Close: ", (string)close_price);
  Print("High: ", (string)high_price);
  Print("Low: ", (string)low_price);
  Print("ATR: ", (string)atr);
  Print("ATR * 0.09: ", (string)tolerance);

  return result;
}

//+------------------------------------------------------------------+
//| Função auxiliar para obter descrição textual da posição         |
//+------------------------------------------------------------------+
string CIndCandleDistance::GetCandlePositionDescription(ENUM_CANDLE_POSITION position)
{
  switch (position)
  {
  case CANDLE_ABOVE:

    return "Candle acima do indicador";
  case CANDLE_ABOVE_WITH_DISTANCE:
    return "Candle completamente acima do indicador (com distância)";
  case CANDLE_BELOW:
    return "Candle abaixo do indicador";
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
  case INDICATOR_CROSSES_CENTER_BODY:
    return "Indicador no nível exato do candle";
  case INDICATOR_CANDLE_POSITION_FAILED:
    return "Falha ao determinar a posição do candle";
  default:
    return "Posição indefinida";
  }
}

#endif