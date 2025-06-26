//+------------------------------------------------------------------+
//|                                               config_types.mqh   |
//|  OOP indicator configuration types                               |
//+------------------------------------------------------------------+

#ifndef __CONFIG_TYPES_MQH__
#define __CONFIG_TYPES_MQH__

#include "vwap_defs.mqh"
#include "ma_defs.mqh"
#include "stochastic_defs.mqh"
#include "volume_defs.mqh"
#include "bollinger_defs.mqh"
#include "fibonacci_defs.mqh"

//--- Base configuration
class CIndicatorConfig
  {
public:
   string name;
   string type;
   bool   enabled;
   virtual ~CIndicatorConfig(){}
  };

//--- Moving Average
class CMAConfig : public CIndicatorConfig
  {
public:
   int             period;
   ENUM_MA_METHOD  method;
   CMAConfig(){ period=0; method=MODE_SMA; }
  };

//--- Stochastic
class CStochasticConfig : public CIndicatorConfig
  {
public:
   int             period;
   int             dperiod;
   int             slowing;
   ENUM_MA_METHOD  method;
   ENUM_STO_PRICE  price_field;
   CStochasticConfig(){ period=0; dperiod=3; slowing=3; method=MODE_SMA; price_field=STO_LOWHIGH; }
  };

//--- Volume
class CVolumeConfig : public CIndicatorConfig
  {
public:
   int shift;
   CVolumeConfig(){ shift=0; }
  };

//--- VWAP
class CVWAPConfig : public CIndicatorConfig
  {
public:
   int                 period;
   ENUM_MA_METHOD      method;
   ENUM_VWAP_CALC_MODE calc_mode;
   ENUM_TIMEFRAMES     session_tf;
   ENUM_VWAP_PRICE_TYPE price_type;
   datetime            start_time;
   color               line_color;
   ENUM_LINE_STYLE     line_style;
   int                 line_width;
   CVWAPConfig()
     {
      period=0; method=MODE_SMA; calc_mode=VWAP_CALC_BAR;
      session_tf=PERIOD_D1; price_type=VWAP_PRICE_FINANCIAL_AVERAGE;
      start_time=0; line_color=clrAqua; line_style=STYLE_SOLID; line_width=1;
     }
  };

//--- Bollinger Bands
class CBollingerConfig : public CIndicatorConfig
  {
public:
   int               period;
   int               shift;
   double            deviation;
   ENUM_APPLIED_PRICE applied_price;
   CBollingerConfig(){ period=20; shift=0; deviation=2.0; applied_price=PRICE_CLOSE; }
  };

//--- Fibonacci
class CFiboConfig : public CIndicatorConfig
  {
public:
   int    period;
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
   CFiboConfig()
     {
      period=0; level_1=23.6; level_2=38.2; level_3=50.0;
      level_4=61.8; level_5=78.6; level_6=100.0;
      levels_color=clrOrange; levels_style=STYLE_SOLID; levels_width=1;
      ext_1=127.0; ext_2=161.8; ext_3=261.8;
      extensions_color=clrOrange; extensions_style=STYLE_DASH; extensions_width=1;
      parallel_color=clrYellow; parallel_style=STYLE_SOLID; parallel_width=1;
      show_labels=true; labels_color=clrWhite; labels_font_size=8; labels_font="Arial";
     }
  };

//--- Timeframe configuration
struct STimeframeConfig
  {
   bool              enabled;
   int               num_candles;
   CIndicatorConfig *indicators[];
  };

#endif // __CONFIG_TYPES_MQH__
