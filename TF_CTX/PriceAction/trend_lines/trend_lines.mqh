//+------------------------------------------------------------------+
//|                                    priceAction/trend_lines.mqh    |
//|  Advanced trend line detection based on fractals                 |
//+------------------------------------------------------------------+
#ifndef __TREND_LINES_MQH__
#define __TREND_LINES_MQH__

#include "../price_action_base.mqh"
#include "../price_action_types.mqh"
#include "trend_lines_defs.mqh"

class CTrendLines : public CPriceActionBase
  {
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;

   // configuration parameters
   color           m_resistance_color;
   ENUM_LINE_STYLE m_resistance_style;
   int             m_resistance_width;
   color           m_support_color;
   ENUM_LINE_STYLE m_support_style;
   int             m_support_width;
   ENUM_TIMEFRAMES m_fractal_tf;
   ENUM_TIMEFRAMES m_detail_tf;
   ENUM_TIMEFRAMES m_alert_tf;
   int             m_fractal_period_hours;
   int             m_max_bars_detail;
   bool            m_enable_alerts;
   bool            m_show_price_in_alert;
   int             m_price_decimal_places;
   bool            m_update_only_new_bar;
   bool            m_show_debug;

   // runtime variables
   int             m_fr_handle;
   bool            m_ready;
   datetime        m_last_bar_time;
   string          m_support_name;
   string          m_resistance_name;

   void            ReleaseHandle()
                    {
                     if(m_fr_handle!=INVALID_HANDLE)
                       {
                        IndicatorRelease(m_fr_handle);
                        m_fr_handle=INVALID_HANDLE;
                       }
                    }
   void            DeleteObjects()
                    {
                     if(StringLen(m_support_name)>0) ObjectDelete(0,m_support_name);
                     if(StringLen(m_resistance_name)>0) ObjectDelete(0,m_resistance_name);
                    }
   bool            IsNewBar()
                    {
                     if(!m_update_only_new_bar)
                        return true;
                     datetime t[];
                     ArrayResize(t,1);
                     if(CopyTime(m_symbol,m_timeframe,0,1,t)<=0)
                        return false;
                     if(t[0]!=m_last_bar_time)
                       {
                        m_last_bar_time=t[0];
                        return true;
                       }
                     return false;
                    }
public:
                    CTrendLines()
                      {
                       m_symbol="";
                       m_timeframe=PERIOD_CURRENT;
                       m_resistance_color=clrRed;
                       m_resistance_style=STYLE_SOLID;
                       m_resistance_width=2;
                       m_support_color=clrBlue;
                       m_support_style=STYLE_SOLID;
                       m_support_width=2;
                       m_fractal_tf=PERIOD_H4;
                       m_detail_tf=PERIOD_H1;
                       m_alert_tf=PERIOD_H1;
                       m_fractal_period_hours=4;
                       m_max_bars_detail=10;
                       m_enable_alerts=true;
                       m_show_price_in_alert=true;
                       m_price_decimal_places=0;
                       m_update_only_new_bar=true;
                       m_show_debug=false;
                       m_fr_handle=INVALID_HANDLE;
                       m_ready=false;
                       m_last_bar_time=0;
                       m_support_name="";
                       m_resistance_name="";
                      }
                   ~CTrendLines()
                      {
                       ReleaseHandle();
                       DeleteObjects();
                      }
   bool            Init(string symbol, ENUM_TIMEFRAMES timeframe, CTrendLinesConfig &cfg)
                      {
                       m_symbol=symbol;
                       m_timeframe=timeframe;
                       m_resistance_color=cfg.resistance_color;
                       m_resistance_style=cfg.resistance_style;
                       m_resistance_width=cfg.resistance_width;
                       m_support_color=cfg.support_color;
                       m_support_style=cfg.support_style;
                       m_support_width=cfg.support_width;
                       m_fractal_tf=cfg.fractal_timeframe;
                       m_detail_tf=cfg.detail_timeframe;
                       m_alert_tf=cfg.alert_timeframe;
                       m_fractal_period_hours=cfg.fractal_period_hours;
                       m_max_bars_detail=cfg.max_bars_detail;
                       m_enable_alerts=cfg.enable_alerts;
                       m_show_price_in_alert=cfg.show_price_in_alert;
                       m_price_decimal_places=cfg.price_decimal_places;
                       m_update_only_new_bar=cfg.update_only_new_bar;
                       m_show_debug=cfg.show_debug_info;

                       ReleaseHandle();
                       DeleteObjects();
                       m_fr_handle=iFractals(m_symbol,m_fractal_tf);
                       m_ready=false;
                       if(m_update_only_new_bar)
                         {
                          datetime t[];
                          ArrayResize(t,1);
                          if(CopyTime(m_symbol,m_timeframe,0,1,t)>0)
                             m_last_bar_time=t[0];
                         }
                       return (m_fr_handle!=INVALID_HANDLE);
                      }
   bool            Init(string symbol, ENUM_TIMEFRAMES timeframe, int period)
                      {
                       // backwards compatibility - use defaults
                       CTrendLinesConfig def;
                       return Init(symbol,timeframe,def);
                      }
   bool            Update()
                      {
                       if(m_fr_handle==INVALID_HANDLE)
                          return false;
                       if(!IsNewBar())
                          return m_ready;

                       int n,upper1,upper2,lower1,lower2;
                       double fr_down[],fr_up[];
                       ArraySetAsSeries(fr_up,true);
                       ArraySetAsSeries(fr_down,true);
                       int total=Bars(m_symbol,m_fractal_tf);
                       if(CopyBuffer(m_fr_handle,0,TimeCurrent(),total,fr_up)<=0)
                          return false;
                       if(CopyBuffer(m_fr_handle,1,TimeCurrent(),total,fr_down)<=0)
                          return false;

                       for(n=0;n<total;n++)
                         if(fr_up[n]!=EMPTY_VALUE) break;
                       upper1=n;
                       for(n=upper1+1;n<total;n++)
                         if(fr_up[n]!=EMPTY_VALUE) break;
                       upper2=n;

                       for(n=0;n<total;n++)
                         if(fr_down[n]!=EMPTY_VALUE) break;
                       lower1=n;
                       for(n=lower1+1;n<total;n++)
                         if(fr_down[n]!=EMPTY_VALUE) break;
                       lower2=n;

                       datetime up_time1[],up_time2[],low_time1[],low_time2[];
                       CopyTime(m_symbol,m_fractal_tf,upper1,1,up_time1);
                       CopyTime(m_symbol,m_fractal_tf,upper2,1,up_time2);
                       CopyTime(m_symbol,m_fractal_tf,lower1,1,low_time1);
                       CopyTime(m_symbol,m_fractal_tf,lower2,1,low_time2);

                       int sec=m_fractal_period_hours*3600;
                       datetime up1_detail=up_time1[0]+sec;
                       datetime up2_detail=up_time2[0]+sec;
                       datetime low1_detail=low_time1[0]+sec;
                       datetime low2_detail=low_time2[0]+sec;

                       double hi1[],hi2[],lo1[],lo2[];
                       CopyHigh(m_symbol,m_detail_tf,up_time1[0],up1_detail,hi1);
                       CopyHigh(m_symbol,m_detail_tf,up_time2[0],up2_detail,hi2);
                       CopyLow(m_symbol,m_detail_tf,low_time1[0],low1_detail,lo1);
                       CopyLow(m_symbol,m_detail_tf,low_time2[0],low2_detail,lo2);

                       datetime hi1_t[],hi2_t[],lo1_t[],lo2_t[];
                       CopyTime(m_symbol,m_detail_tf,up_time1[0],up1_detail,hi1_t);
                       CopyTime(m_symbol,m_detail_tf,up_time2[0],up2_detail,hi2_t);
                       CopyTime(m_symbol,m_detail_tf,low_time1[0],low1_detail,lo1_t);
                       CopyTime(m_symbol,m_detail_tf,low_time2[0],low2_detail,lo2_t);

                       int max1=ArrayMaximum(hi1,0,m_max_bars_detail);
                       int max2=ArrayMaximum(hi2,0,m_max_bars_detail);
                       int min1=ArrayMinimum(lo1,0,m_max_bars_detail);
                       int min2=ArrayMinimum(lo2,0,m_max_bars_detail);

                       if(StringLen(m_support_name)==0) m_support_name="TL_SUP_"+IntegerToString(GetTickCount());
                       if(StringLen(m_resistance_name)==0) m_resistance_name="TL_RES_"+IntegerToString(GetTickCount());

                       ObjectCreate(0,m_support_name,OBJ_TREND,0,lo2_t[min2],lo2[min2],lo1_t[min1],lo1[min1]);
                       ObjectSetInteger(0,m_support_name,OBJPROP_RAY_RIGHT,true);
                       ObjectSetInteger(0,m_support_name,OBJPROP_COLOR,m_support_color);
                       ObjectSetInteger(0,m_support_name,OBJPROP_STYLE,m_support_style);
                       ObjectSetInteger(0,m_support_name,OBJPROP_WIDTH,m_support_width);

                       ObjectCreate(0,m_resistance_name,OBJ_TREND,0,hi2_t[max2],hi2[max2],hi1_t[max1],hi1[max1]);
                       ObjectSetInteger(0,m_resistance_name,OBJPROP_RAY_RIGHT,true);
                       ObjectSetInteger(0,m_resistance_name,OBJPROP_COLOR,m_resistance_color);
                       ObjectSetInteger(0,m_resistance_name,OBJPROP_STYLE,m_resistance_style);
                       ObjectSetInteger(0,m_resistance_name,OBJPROP_WIDTH,m_resistance_width);

                       datetime tl_low2=(datetime)ObjectGetInteger(0,m_support_name,OBJPROP_TIME,0);
                       datetime tl_low1=(datetime)ObjectGetInteger(0,m_support_name,OBJPROP_TIME,1);
                       if(tl_low2!=lo2_t[min2] && tl_low1!=lo1_t[min1])
                          ObjectDelete(0,m_support_name);

                       datetime tl_up2=(datetime)ObjectGetInteger(0,m_resistance_name,OBJPROP_TIME,0);
                       datetime tl_up1=(datetime)ObjectGetInteger(0,m_resistance_name,OBJPROP_TIME,1);
                       if(tl_up2!=hi2_t[max2] && tl_up1!=hi1_t[max1])
                          ObjectDelete(0,m_resistance_name);

                       int bars_hi1=Bars(m_symbol,m_detail_tf,up_time1[0],up1_detail);
                       int bars_hi2=Bars(m_symbol,m_detail_tf,up_time2[0],up2_detail);
                       int bars_lo1=Bars(m_symbol,m_detail_tf,low_time1[0],low1_detail);
                       int bars_lo2=Bars(m_symbol,m_detail_tf,low_time2[0],low2_detail);
                       if(bars_hi1==0 || bars_hi2==0 || bars_lo1==0 || bars_lo2==0)
                          Alert("Not enough history for proper operation!");

                       double close[]; datetime close_t[];
                       CopyClose(m_symbol,m_alert_tf,TimeCurrent(),10,close);
                       CopyTime(m_symbol,m_alert_tf,TimeCurrent(),10,close_t);
                       ArraySetAsSeries(close,true); ArraySetAsSeries(close_t,true);

                       double price_sup=ObjectGetValueByTime(0,m_support_name,close_t[1]);
                       double price_res=ObjectGetValueByTime(0,m_resistance_name,close_t[1]);

                       bool breakdown=(close[1]<price_sup);
                       bool breakup=(close[1]>price_res);

                       if(m_enable_alerts)
                         {
                          string price_text="";
                          if(m_show_price_in_alert)
                             price_text=" - Preco: "+DoubleToString(close[1],m_price_decimal_places);
                          if(breakdown)
                             Alert(m_symbol+" - ROMPIMENTO SUPORTE"+price_text);
                          if(breakup)
                             Alert(m_symbol+" - ROMPIMENTO RESISTENCIA"+price_text);
                         }

                       if(m_show_debug)
                         {
                          string dbg="TrendLines Debug: Suporte: "+DoubleToString(price_sup,2)+
                                      " | Resistencia: "+DoubleToString(price_res,2)+
                                      " | Preco: "+DoubleToString(close[1],m_price_decimal_places);
                          Comment(dbg);
                         }
                       else
                         {
                          Comment("TrendLines Ativo - "+TimeToString(TimeCurrent(),TIME_MINUTES));
                         }
                       m_ready=true;
                       return true;
                      }
   bool            IsReady(){ return m_ready; }
  };

#endif // __TREND_LINES_MQH__
