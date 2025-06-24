//+------------------------------------------------------------------+
//|                                               config_types.mqh   |
//|  Structures for timeframe and indicator configuration            |
//+------------------------------------------------------------------+

#ifndef __CONFIG_TYPES_MQH__
#define __CONFIG_TYPES_MQH__

struct SIndicatorConfig
{
    string name;
    string type;
    int    period;
    ENUM_MA_METHOD method;
    int    dperiod;
    int    slowing;
    int    shift;
    ENUM_STO_PRICE price_field;
    bool   enabled;
};

struct STimeframeConfig
{
    bool enabled;
    int  num_candles;
    SIndicatorConfig indicators[];
};

#endif // __CONFIG_TYPES_MQH__

