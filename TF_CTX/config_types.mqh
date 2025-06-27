//+------------------------------------------------------------------+
//|                                               config_types.mqh   |
//|  OOP indicator configuration types                               |
//+------------------------------------------------------------------+

#ifndef __CONFIG_TYPES_MQH__
#define __CONFIG_TYPES_MQH__

#include "indicators/indicators_types.mqh"
#include "priceAction/price_action_types.mqh"

//--- Timeframe configuration

struct STimeframeConfig
  {
   bool              enabled;
   int               num_candles;
   CIndicatorConfig *indicators[];
   CPriceActionConfig *price_actions[];
  };

#endif // __CONFIG_TYPES_MQH__
