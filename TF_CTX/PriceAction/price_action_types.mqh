//+------------------------------------------------------------------+
//|                                         price_action_types.mqh   |
//|  OOP Price Action configuration types                            |
//+------------------------------------------------------------------+
#ifndef __PRICE_ACTION_CONFIG_TYPES_MQH__
#define __PRICE_ACTION_CONFIG_TYPES_MQH__

class CPriceActionConfig
  {
public:
   string name;
   string type;
   bool   enabled;
   virtual ~CPriceActionConfig(){}
  };

class CTrendLinesConfig : public CPriceActionConfig
  {
public:
   color           resistance_color;
   ENUM_LINE_STYLE resistance_style;
   int             resistance_width;
   color           support_color;
   ENUM_LINE_STYLE support_style;
   int             support_width;
   ENUM_TIMEFRAMES fractal_timeframe;
   ENUM_TIMEFRAMES detail_timeframe;
   ENUM_TIMEFRAMES alert_timeframe;
   int             fractal_period_hours;
   int             max_bars_detail;
   bool            enable_alerts;
   bool            show_price_in_alert;
   int             price_decimal_places;
   bool            update_only_new_bar;
   bool            show_debug_info;

   CTrendLinesConfig()
     {
      resistance_color=clrRed;
      resistance_style=STYLE_SOLID;
      resistance_width=2;
      support_color=clrBlue;
      support_style=STYLE_SOLID;
      support_width=2;
      fractal_timeframe=PERIOD_H4;
      detail_timeframe=PERIOD_H1;
      alert_timeframe=PERIOD_H1;
      fractal_period_hours=4;
      max_bars_detail=10;
      enable_alerts=true;
      show_price_in_alert=true;
      price_decimal_places=0;
      update_only_new_bar=true;
      show_debug_info=false;
     }
  };

#endif // __PRICE_ACTION_CONFIG_TYPES_MQH__
