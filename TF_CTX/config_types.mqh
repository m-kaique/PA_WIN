//+------------------------------------------------------------------+
//|                                               config_types.mqh   |
//|  Structures for timeframe and indicator configuration            |
//+------------------------------------------------------------------+

#ifndef __CONFIG_TYPES_MQH__
#define __CONFIG_TYPES_MQH__

#include "indicators/vwap.mqh"

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
    double deviation;
    ENUM_APPLIED_PRICE applied_price;
    ENUM_VWAP_CALC_MODE vwap_calc_mode;
    ENUM_TIMEFRAMES     vwap_session_tf;
    ENUM_VWAP_PRICE_TYPE vwap_price_type;
    datetime            vwap_start_time;
    color  vwap_color;
    ENUM_LINE_STYLE vwap_style;
    int    vwap_width;
    bool   enabled;
    double level_1;
    double level_2;
    double level_3;
    double level_4;
    double level_5;
    double level_6;
    color  levels_color;
    int    levels_style;
    int    levels_width;
    double ext_1;
    double ext_2;
    double ext_3;
    color  extensions_color;
    int    extensions_style;
    int    extensions_width;
    color  parallel_color;
    int    parallel_style;
    int    parallel_width;
    bool   show_labels;
    color  labels_color;
    int    labels_font_size;
    string labels_font;

    // Construtor com valores padrao
    void InitDefaults()
      {
       name="";
       type="";
       period=0;
       method=MODE_SMA;
       dperiod=3;
       slowing=3;
       shift=0;
       price_field=STO_LOWHIGH;
       deviation=2.0;
       applied_price=PRICE_CLOSE;
       vwap_calc_mode=VWAP_CALC_BAR;
       vwap_session_tf=PERIOD_D1;
       vwap_price_type=VWAP_PRICE_FINANCIAL_AVERAGE;
       vwap_start_time=0;
       vwap_color=clrAqua;
       vwap_style=STYLE_SOLID;
       vwap_width=1;
       enabled=true;
       level_1=23.6; level_2=38.2; level_3=50.0;
       level_4=61.8; level_5=78.6; level_6=100.0;
       levels_color=clrOrange; levels_style=STYLE_SOLID; levels_width=1;
       ext_1=127.0; ext_2=161.8; ext_3=261.8;
       extensions_color=clrOrange; extensions_style=STYLE_DASH; extensions_width=1;
       parallel_color=clrYellow; parallel_style=STYLE_SOLID; parallel_width=1;
       show_labels=true; labels_color=clrWhite; labels_font_size=8; labels_font="Arial";
      }
};

struct STimeframeConfig
{
    bool enabled;
    int  num_candles;
    SIndicatorConfig indicators[];
};

#endif // __CONFIG_TYPES_MQH__

