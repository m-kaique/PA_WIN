//+------------------------------------------------------------------+
//|                                         price_action_base.mqh     |
//|  Base abstract class for Price Action modules                    |
//+------------------------------------------------------------------+
#ifndef __PRICE_ACTION_BASE_MQH__
#define __PRICE_ACTION_BASE_MQH__

class CPriceActionBase
  {
  public:
   // Initialize with basic parameters
   virtual bool   Init(string symbol, ENUM_TIMEFRAMES timeframe, int period)=0;
   // Optional initialization with configuration structure. By default it simply
   // calls the basic Init() using the period from the configuration object.
   virtual bool   Init(string symbol, ENUM_TIMEFRAMES timeframe,
                       CPriceActionConfig &config)
                       { return Init(symbol,timeframe,config.period); }

   // Default update behaves like the indicator base - subclasses can override
   virtual bool   Update() { return IsReady(); }
   virtual bool   IsReady()=0;

   // Optional retrieval helpers for future extensions
   virtual double GetValue(int shift=0)      { return 0.0; }
   virtual bool   CopyValues(int shift,int count,double &buffer[])
                     { ArrayResize(buffer,0); return false; }

   virtual        ~CPriceActionBase(){}
  };

#endif // __PRICE_ACTION_BASE_MQH__
