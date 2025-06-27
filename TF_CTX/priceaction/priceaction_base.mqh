//+------------------------------------------------------------------+
//|                                    priceaction/priceaction_base.mqh |
//|  Base abstract class for price action patterns                    |
//+------------------------------------------------------------------+
#ifndef __PRICEACTION_BASE_MQH__
#define __PRICEACTION_BASE_MQH__

class CPriceActionBase
  {
public:
   virtual bool   Init(string symbol, ENUM_TIMEFRAMES timeframe, int period) = 0;
   virtual double GetValue(int shift = 0) = 0;
   virtual bool   CopyValues(int shift, int count, double &buffer[]) = 0;
   virtual bool   IsReady() = 0;
   // Default update simply checks readiness. Price action patterns can override
   // this method when they need to refresh internal state (e.g. recalculate
   // trend lines, update pattern detection).
   virtual bool   Update() { return IsReady(); }
   virtual        ~CPriceActionBase() {}
  };

#endif // __PRICEACTION_BASE_MQH__