//+------------------------------------------------------------------+
//|                                               config_types.mqh   |
//|  OOP indicator configuration types                               |
//+------------------------------------------------------------------+

#ifndef __CONFIG_TYPES_MQH__
#define __CONFIG_TYPES_MQH__

#include "indicators/vwap/vwap_defs.mqh"
#include "indicators/ma/ma_defs.mqh"
#include "indicators/stochastic/stochastic_defs.mqh"
#include "indicators/volume/volume_defs.mqh"
#include "indicators/bollinger/bollinger_defs.mqh"
#include "indicators/fibonacci/fibonacci_defs.mqh"
#include "indicators/trendline/trendline_defs.mqh"
#include "indicators/sup_res/sup_res_defs.mqh"

//--- Base configuration
class CIndicatorConfig
{
public:
  string name;
  string type;
  bool enabled;
  bool attach_chart;        // Nova flag para acoplar ao gráfico o indicador
  ENUM_TIMEFRAMES alert_tf; // TF alert
  virtual ~CIndicatorConfig() {}
};

//--- Moving Average
class CMAConfig : public CIndicatorConfig
{
public:
  int period;
  ENUM_MA_METHOD method;
  CMAConfig()
  {
    period = 0; 
    method = MODE_SMA;
  }
};

//--- Stochastic
class CStochasticConfig : public CIndicatorConfig
{
public:
  int period;
  int dperiod;
  int slowing;
  ENUM_MA_METHOD method;
  ENUM_STO_PRICE price_field;
  CStochasticConfig()
  {
    period = 0;
    dperiod = 3;
    slowing = 3;
    method = MODE_SMA;
    price_field = STO_LOWHIGH;
  }
};


//--- ADX
class CAdxConfig : public CIndicatorConfig
{
public:
  int period;
  CAdxConfig() { period = 11; }
};

//--- ATR
class CAtrConfig : public CIndicatorConfig
{
public:
  int period;
  CAtrConfig() { period = 14; }
};

//--- Volume
class CVolumeConfig : public CIndicatorConfig
{
public:
  int shift;
  CVolumeConfig() { shift = 0; }
};

//--- VWAP
class CVWAPConfig : public CIndicatorConfig
{
public:
  int period;
  ENUM_MA_METHOD method;
  ENUM_VWAP_CALC_MODE calc_mode;
  ENUM_TIMEFRAMES session_tf;
  ENUM_VWAP_PRICE_TYPE price_type;
  datetime start_time;
  color line_color;
  ENUM_LINE_STYLE line_style;
  int line_width;
  CVWAPConfig()
  {
    period = 0;
    method = MODE_SMA;
    calc_mode = VWAP_CALC_BAR;
    session_tf = PERIOD_D1;
    price_type = VWAP_PRICE_FINANCIAL_AVERAGE;
    start_time = 0;
    line_color = clrAqua;
    line_style = STYLE_SOLID;
    line_width = 1;
  }
};

//--- Bollinger Bands
class CBollingerConfig : public CIndicatorConfig
{
public:
  int period;
  int shift;
  double deviation;
  ENUM_APPLIED_PRICE applied_price;
  CBollingerConfig()
  {
    period = 20;
    shift = 0;
    deviation = 2.0;
    applied_price = PRICE_CLOSE;
  }
};

//--- Fibonacci
class CFiboConfig : public CIndicatorConfig
{
public:
  int period;
  double level_1;
  double level_2;
  double level_3;
  double level_4;
  double level_5;
  double level_6;
  color levels_color;
  int levels_style;
  int levels_width;
  double ext_1;
  double ext_2;
  double ext_3;
  color extensions_color;
  int extensions_style;
  int extensions_width;
  color parallel_color;
  int parallel_style;
  int parallel_width;
  bool show_labels;
  color labels_color;
  int labels_font_size;
  string labels_font;
  CFiboConfig()
  {
    period = 0;
    level_1 = 23.6;
    level_2 = 38.2;
    level_3 = 50.0;
    level_4 = 61.8;
    level_5 = 78.6;
    level_6 = 100.0;
    levels_color = clrOrange;
    levels_style = STYLE_SOLID;
    levels_width = 1;
    ext_1 = 127.0;
    ext_2 = 161.8;
    ext_3 = 261.8;
    extensions_color = clrOrange;
    extensions_style = STYLE_DASH;
    extensions_width = 1;
    parallel_color = clrYellow;
    parallel_style = STYLE_SOLID;
    parallel_width = 1;
    show_labels = true;
    labels_color = clrWhite;
    labels_font_size = 8;
    labels_font = "Arial";
  }
};

//--- Base configuration for PriceActions
class CPriceActionConfig
{
public:
  string name;
  string type;
  bool enabled;
  virtual ~CPriceActionConfig() {}
};

//--- Additional structs for TrendLine advanced options
struct TrendlineStatusFlags
{
  bool enable_body_cross;
  bool enable_between_ltas;
  bool enable_between_ltbs;
  bool enable_distance_points;
  TrendlineStatusFlags()
  {
    enable_body_cross = true;
    enable_between_ltas = true;
    enable_between_ltbs = true;
    enable_distance_points = true;
  }
};

struct TrendlineContextConfig
{
  bool enabled;
  int lookback;
  double trend_threshold;
  double consolidation_threshold;
  TrendlineContextConfig()
  {
    enabled = false;
    lookback = 9;
    trend_threshold = 0.7;
    consolidation_threshold = 0.6;
  }
};

struct TrendlineAdvancedFeatures
{
  bool detect_fakeout;
  bool count_touches;
  double touch_tolerance_points;
  string status_evaluate_mode;
  bool register_resets;
  TrendlineAdvancedFeatures()
  {
    detect_fakeout = false;
    count_touches = false;
    touch_tolerance_points = 0.0;
    status_evaluate_mode = "close_only";
    register_resets = false;
  }
};

//--- TrendLine configuration
class CTrendLineConfig : public CIndicatorConfig
{
public:
  int period;
  int pivot_left;
  int pivot_right;
  bool draw_lta;
  bool draw_ltb;
  color lta_color;
  color ltb_color;
  ENUM_LINE_STYLE lta_style;
  ENUM_LINE_STYLE ltb_style;
  int lta_width;
  int ltb_width;
  bool extend_right;
  // ENUM_TIMEFRAMES alert_tf;
  double min_angle;
  int candles_lookback;
  TrendlineStatusFlags status_flags;
  TrendlineContextConfig context_analysis;
  TrendlineAdvancedFeatures advanced_features;
  CTrendLineConfig()
  {
    period = 20;
    pivot_left = 3;
    pivot_right = 3;
    draw_lta = true;
    draw_ltb = true;
    lta_color = clrGreen;
    ltb_color = clrRed;
    lta_style = STYLE_SOLID;
    ltb_style = STYLE_SOLID;
    lta_width = 1;
    ltb_width = 1;
    extend_right = true;
    min_angle = 20.0;
    candles_lookback = 9;
  }
};

//--- Support/Resistance configuration
class CSupResConfig : public CIndicatorConfig
{
public:
  int period;
  bool draw_sup;
  bool draw_res;
  color sup_color;
  color res_color;
  ENUM_LINE_STYLE sup_style;
  ENUM_LINE_STYLE res_style;
  int sup_width;
  int res_width;
  bool extend_right;
  bool show_labels;
  int touch_lookback;
  double touch_tolerance;
  double zone_range;
  int max_zones_to_draw;
  int min_touches;
  ENUM_SUPRES_VALIDATION validation;
  CSupResConfig()
  {
    period = 50;
    draw_sup = true;
    draw_res = true;
    sup_color = clrBlue;
    res_color = clrRed;
    sup_style = STYLE_SOLID;
    res_style = STYLE_SOLID;
    sup_width = 1;
    res_width = 1;
    extend_right = true;
    show_labels = false;
    alert_tf = PERIOD_H1;
    touch_lookback = 20;
    touch_tolerance = 0.0;
    zone_range = 10.0;
    max_zones_to_draw = 3;
    min_touches = 2;
    validation = SUPRES_VALIDATE_TOUCHES;
  }
};

//--- Timeframe configuration
struct STimeframeConfig
{
  bool enabled;
  int num_candles;
  CIndicatorConfig *indicators[];
  CPriceActionConfig *priceactions[];
};

#endif // __CONFIG_TYPES_MQH__
