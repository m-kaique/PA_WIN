//+------------------------------------------------------------------+
//|                                               config_types.mqh   |
//|  Structures for timeframe and moving average configuration       |
//+------------------------------------------------------------------+

#ifndef __CONFIG_TYPES_MQH__
#define __CONFIG_TYPES_MQH__

struct SMovingAverageConfig
{
    int period;
    ENUM_MA_METHOD method;
    bool enabled;
};

struct STimeframeConfig
{
    bool enabled;
    int num_candles;
    SMovingAverageConfig ema9;
    SMovingAverageConfig ema21;
    SMovingAverageConfig ema50;
    SMovingAverageConfig sma200;
};

#endif // __CONFIG_TYPES_MQH__

