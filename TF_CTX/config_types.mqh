//+------------------------------------------------------------------+
//|                                               config_types.mqh   |
//|  Wrapper for indicator configuration types                      |
//+------------------------------------------------------------------+

#ifndef __CONFIG_TYPES_MQH__
#define __CONFIG_TYPES_MQH__

#include "indicators/indicators_config_types.mqh"

//--- Timeframe configuration
struct STimeframeConfig
  {
   bool              enabled;
   int               num_candles;
   CIndicatorConfig *indicators[];
  };

#endif // __CONFIG_TYPES_MQH__
