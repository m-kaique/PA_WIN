//+------------------------------------------------------------------+
//|                                         indicators/indicator_base.mqh |
//|  Base abstract class for indicators                               |
//+------------------------------------------------------------------+
#ifndef __INDICATOR_BASE_MQH__
#define __INDICATOR_BASE_MQH__

class CIndicatorBase
  {
public:
   virtual bool   Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_MA_METHOD method) = 0;
   virtual double GetValue(int shift = 0) = 0;
   virtual bool   CopyValues(int shift, int count, double &buffer[]) = 0;
   virtual bool   IsReady() = 0;
   virtual        ~CIndicatorBase() {}
  };

#endif // __INDICATOR_BASE_MQH__
