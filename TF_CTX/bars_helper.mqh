#ifndef __BARS_HELPER_MQH__
#define __BARS_HELPER_MQH__

//+------------------------------------------------------------------+
//| Clamp requested bars to available bars on chart                   |
//+------------------------------------------------------------------+
inline int ClampBars(string symbol, ENUM_TIMEFRAMES timeframe, int requested)
  {
   int available = Bars(symbol, timeframe);
   if(available <= 0)
      return 0;
   if(requested <= 0)
      return available;
   return MathMin(requested, available);
  }

//+------------------------------------------------------------------+
//| Clamp requested bars to available bars for indicator handle       |
//+------------------------------------------------------------------+
inline int ClampBars(int handle, int requested)
  {
   int available = BarsCalculated(handle);
   if(available <= 0)
      return 0;
   if(requested <= 0)
      return available;
   return MathMin(requested, available);
  }

#endif // __BARS_HELPER_MQH__
