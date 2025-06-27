//+------------------------------------------------------------------+
//|                                         price_action_base.mqh     |
//|  Base abstract class for Price Action modules                    |
//+------------------------------------------------------------------+
#ifndef __PRICE_ACTION_BASE_MQH__
#define __PRICE_ACTION_BASE_MQH__

class CPriceActionBase
  {
public:
   virtual bool   Init(string symbol, ENUM_TIMEFRAMES timeframe, int period)=0;
   virtual bool   Update()=0;
   virtual bool   IsReady()=0;
   // Default implementations for value retrieval
   virtual double GetValue(int shift=0)      { return 0.0; }
   virtual bool   CopyValues(int shift,int count,double &buffer[])
                     { ArrayResize(buffer,0); return false; }
   virtual        ~CPriceActionBase(){}
  };

#endif // __PRICE_ACTION_BASE_MQH__
