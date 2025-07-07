#ifndef __CHART_UTILS_MQH__
#define __CHART_UTILS_MQH__

//+------------------------------------------------------------------+
//| Helper chart functions                                           |
//+------------------------------------------------------------------+

// Find chart matching symbol and timeframe
inline long FindChartByTF(const string symbol,const ENUM_TIMEFRAMES tf)
  {
   long chart_id=ChartFirst();
   while(chart_id!=-1)
     {
      if(ChartSymbol(chart_id)==symbol && ChartPeriod(chart_id)==tf)
         return chart_id;
      chart_id=ChartNext(chart_id);
     }
   return -1; // not found
  }

#endif // __CHART_UTILS_MQH__
