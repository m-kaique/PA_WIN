//+------------------------------------------------------------------+
//|                                         price_action_base.mqh     |
//|  Base abstract class for Price Action modules                    |
//+------------------------------------------------------------------+
#ifndef __PRICE_ACTION_BASE_MQH__
#define __PRICE_ACTION_BASE_MQH__

#include "price_action_types.mqh"

class CPriceActionBase
  {
  public:
   // Initialize with basic parameters
   virtual bool   Init(string symbol, ENUM_TIMEFRAMES timeframe, int period)=0;
   // Optional initialization with configuration structure. Each derived
   // module decides how to interpret the configuration object.
   virtual bool   Init(string symbol, ENUM_TIMEFRAMES timeframe,
                       CPriceActionConfig &config)=0;

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
