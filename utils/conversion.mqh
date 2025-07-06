#ifndef __CONVERSION_MQH__
#define __CONVERSION_MQH__

//+------------------------------------------------------------------+
//| Helper conversion functions                                      |
//+------------------------------------------------------------------+

// Convert string to ENUM_TIMEFRAMES
inline ENUM_TIMEFRAMES ToTimeframe(const string tf_str)
  {
   if(tf_str=="M1")  return PERIOD_M1;
   if(tf_str=="M5")  return PERIOD_M5;
   if(tf_str=="M15") return PERIOD_M15;
   if(tf_str=="M30") return PERIOD_M30;
   if(tf_str=="H1")  return PERIOD_H1;
   if(tf_str=="H4")  return PERIOD_H4;
   if(tf_str=="D1")  return PERIOD_D1;
   return PERIOD_CURRENT;
  }

// Convert string to ENUM_MA_METHOD
inline ENUM_MA_METHOD ToMaMethod(const string method_str)
  {
   if(method_str=="SMA")  return MODE_SMA;
   if(method_str=="EMA")  return MODE_EMA;
   if(method_str=="SMMA") return MODE_SMMA;
   if(method_str=="LWMA") return MODE_LWMA;
   return MODE_SMA;
  }

// Convert string to ENUM_STO_PRICE
inline ENUM_STO_PRICE ToPriceField(const string field_str)
  {
   if(field_str=="CLOSECLOSE" || field_str=="CLOSE_CLOSE")
      return STO_CLOSECLOSE;
   return STO_LOWHIGH;
  }

// Convert string to ENUM_APPLIED_PRICE
inline ENUM_APPLIED_PRICE ToAppliedPrice(const string price_str)
  {
   if(price_str=="OPEN")     return PRICE_OPEN;
   if(price_str=="HIGH")     return PRICE_HIGH;
   if(price_str=="LOW")      return PRICE_LOW;
   if(price_str=="MEDIAN")   return PRICE_MEDIAN;
   if(price_str=="TYPICAL")  return PRICE_TYPICAL;
   if(price_str=="WEIGHTED") return PRICE_WEIGHTED;
   return PRICE_CLOSE;
  }

// Convert string to ENUM_VWAP_CALC_MODE
inline ENUM_VWAP_CALC_MODE ToVWAPCalcMode(const string mode_str)
  {
   if(mode_str=="PERIODIC")  return VWAP_CALC_PERIODIC;
   if(mode_str=="FROM_DATE") return VWAP_CALC_FROM_DATE;
   return VWAP_CALC_BAR;
  }

// Convert string to ENUM_VWAP_PRICE_TYPE
inline ENUM_VWAP_PRICE_TYPE ToVWAPPriceType(const string type_str)
  {
   if(type_str=="OPEN")  return VWAP_PRICE_OPEN;
   if(type_str=="HIGH")  return VWAP_PRICE_HIGH;
   if(type_str=="LOW")   return VWAP_PRICE_LOW;
   if(type_str=="CLOSE") return VWAP_PRICE_CLOSE;
   if(type_str=="HL2")   return VWAP_PRICE_HL2;
   if(type_str=="HLC3")  return VWAP_PRICE_HLC3;
   if(type_str=="OHLC4") return VWAP_PRICE_OHLC4;
   return VWAP_PRICE_FINANCIAL_AVERAGE;
  }

// Convert string to ENUM_LINE_STYLE
inline ENUM_LINE_STYLE ToLineStyle(const string style_str)
  {
   if(style_str=="SOLID")     return STYLE_SOLID;
   if(style_str=="DASH")      return STYLE_DASH;
   if(style_str=="DOT")       return STYLE_DOT;
   if(style_str=="DASHDOT")   return STYLE_DASHDOT;
   if(style_str=="DASHDOTDOT")return STYLE_DASHDOTDOT;
   return STYLE_SOLID;
  }

// Convert string to color
inline color ToColor(const string color_str)
  {
   if(color_str=="Red")    return clrRed;
   if(color_str=="Blue")   return clrBlue;
   if(color_str=="Yellow") return clrYellow;
   if(color_str=="Green")  return clrGreen;
   if(color_str=="Orange") return clrOrange;
   if(color_str=="White")  return clrWhite;
   if(color_str=="Black")  return clrBlack;
   if(StringLen(color_str)>0)
      return (color)StringToInteger(color_str);
   return clrNONE;
  }

#endif // __CONVERSION_MQH__
