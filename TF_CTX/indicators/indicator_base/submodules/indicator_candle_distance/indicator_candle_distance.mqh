#ifndef __IND_CANDLE_DISTANCE_MQH__
#define __IND_CANDLE_DISTANCE_MQH__
#include "candle_distance_defs.mqh"

class CIndCandleDistance{
   public:
   SPositionInfo GetPreviousCandlePosition(int shift, string symbol, ENUM_TIMEFRAMES tf, double indValue);
   string GetCandlePositionDescription(ENUM_CANDLE_POSITION position);
};


//+------------------------------------------------------------------------+
//| Retorna a posição do candle anterior em relação ao valor do indicador |
//+------------------------------------------------------------------------+
SPositionInfo CIndCandleDistance::GetPreviousCandlePosition(int shift, string symbol, ENUM_TIMEFRAMES tf,double indValue)
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
string CIndCandleDistance::GetCandlePositionDescription(ENUM_CANDLE_POSITION position)
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

#endif