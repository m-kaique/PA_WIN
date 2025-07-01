//+------------------------------------------------------------------+
//|                                                sup_res.mqh       |
//|  Simple support and resistance lines                             |
//+------------------------------------------------------------------+
#ifndef __SUP_RES_MQH__
#define __SUP_RES_MQH__

#include "../priceaction_base.mqh"
#include "sup_res_defs.mqh"
#include "../../config_types.mqh"

class CSupRes : public CPriceActionBase
  {
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int             m_period;
   bool            m_draw_sup;
   bool            m_draw_res;
   color           m_sup_color;
   color           m_res_color;
   ENUM_LINE_STYLE m_sup_style;
   ENUM_LINE_STYLE m_res_style;
   int             m_sup_width;
   int             m_res_width;
   bool            m_extend_right;
   bool            m_show_labels;
   ENUM_TIMEFRAMES m_alert_tf;
   bool            m_ready;
   double          m_sup_val;
   double          m_res_val;
   bool            m_breakdown;
   bool            m_breakup;
   string          m_obj_sup;
   string          m_obj_res;

   void            DrawLine(string name,double price,color col,ENUM_LINE_STYLE st,int width);

public:
                     CSupRes();
                    ~CSupRes();

   bool             Init(string symbol,ENUM_TIMEFRAMES timeframe,CSupResConfig &cfg);
   virtual bool     Init(string symbol,ENUM_TIMEFRAMES timeframe,int period);
   virtual double   GetValue(int shift=0); // returns support value
   virtual bool     CopyValues(int shift,int count,double &buffer[]);
   virtual bool     IsReady();
   virtual bool     Update();

   double           GetSupportValue(int shift=0);
   double           GetResistanceValue(int shift=0);
   bool             IsBreakdown();
   bool             IsBreakup();
  };

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSupRes::CSupRes()
  {
   m_symbol="";
   m_timeframe=PERIOD_CURRENT;
   m_period=50;
   m_draw_sup=true;
   m_draw_res=true;
   m_sup_color=clrBlue;
   m_res_color=clrRed;
   m_sup_style=STYLE_SOLID;
   m_res_style=STYLE_SOLID;
   m_sup_width=1;
   m_res_width=1;
   m_extend_right=true;
   m_show_labels=false;
   m_alert_tf=PERIOD_CURRENT;
   m_ready=false;
   m_sup_val=0.0;
   m_res_val=0.0;
   m_breakdown=false;
   m_breakup=false;
   m_obj_sup="";
   m_obj_res="";
  }

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSupRes::~CSupRes()
  {
   if(StringLen(m_obj_sup)>0)
      ObjectDelete(0,m_obj_sup);
   if(StringLen(m_obj_res)>0)
      ObjectDelete(0,m_obj_res);
  }

//+------------------------------------------------------------------+
//| Draw horizontal line                                              |
//+------------------------------------------------------------------+
void CSupRes::DrawLine(string name,double price,color col,ENUM_LINE_STYLE st,int width)
  {
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   else
      ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_STYLE,st);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,m_extend_right);
  }

//+------------------------------------------------------------------+
//| Init using configuration                                          |
//+------------------------------------------------------------------+
bool CSupRes::Init(string symbol,ENUM_TIMEFRAMES timeframe,CSupResConfig &cfg)
  {
   m_symbol=symbol;
   m_timeframe=timeframe;
   m_period=cfg.period;
   m_draw_sup=cfg.draw_sup;
   m_draw_res=cfg.draw_res;
   m_sup_color=cfg.sup_color;
   m_res_color=cfg.res_color;
   m_sup_style=cfg.sup_style;
   m_res_style=cfg.res_style;
   m_sup_width=cfg.sup_width;
   m_res_width=cfg.res_width;
   m_extend_right=cfg.extend_right;
   m_show_labels=cfg.show_labels;
   m_alert_tf=cfg.alert_tf;

   m_obj_sup="SR_SUP_"+IntegerToString(GetTickCount());
   m_obj_res="SR_RES_"+IntegerToString(GetTickCount());

   return Update();
  }

//+------------------------------------------------------------------+
//| Default init                                                      |
//+------------------------------------------------------------------+
bool CSupRes::Init(string symbol,ENUM_TIMEFRAMES timeframe,int period)
  {
   CSupResConfig tmp;
   tmp.period=period;
   return Init(symbol,timeframe,tmp);
  }

//+------------------------------------------------------------------+
//| Support value                                                     |
//+------------------------------------------------------------------+
double CSupRes::GetSupportValue(int shift)
  {
   if(shift==0)
      return m_sup_val;
   datetime t=iTime(m_symbol,m_alert_tf,shift);
   if(t==0) return 0.0;
   double val=ObjectGetValueByTime(0,m_obj_sup,t);
   return val;
  }

//+------------------------------------------------------------------+
//| Resistance value                                                  |
//+------------------------------------------------------------------+
double CSupRes::GetResistanceValue(int shift)
  {
   if(shift==0)
      return m_res_val;
   datetime t=iTime(m_symbol,m_alert_tf,shift);
   if(t==0) return 0.0;
   double val=ObjectGetValueByTime(0,m_obj_res,t);
   return val;
  }

//+------------------------------------------------------------------+
//| GetValue (support)                                                |
//+------------------------------------------------------------------+
double CSupRes::GetValue(int shift)
  {
   return GetSupportValue(shift);
  }

//+------------------------------------------------------------------+
//| CopyValues (support)                                              |
//+------------------------------------------------------------------+
bool CSupRes::CopyValues(int shift,int count,double &buffer[])
  {
   ArrayResize(buffer,count);
   for(int i=0;i<count;i++)
      buffer[i]=GetValue(shift+i);
   return true;
  }

//+------------------------------------------------------------------+
//| Ready flag                                                        |
//+------------------------------------------------------------------+
bool CSupRes::IsReady()
  {
   return m_ready;
  }

//+------------------------------------------------------------------+
//| Update support/resistance values                                  |
//+------------------------------------------------------------------+
bool CSupRes::Update()
  {
   int bars=m_period>0?m_period:50;
   double highs[],lows[];
   ArraySetAsSeries(highs,true);
   ArraySetAsSeries(lows,true);
   if(CopyHigh(m_symbol,m_timeframe,0,bars,highs)<=0)
      return false;
   if(CopyLow(m_symbol,m_timeframe,0,bars,lows)<=0)
      return false;

   int hi_idx=ArrayMaximum(highs);
   int lo_idx=ArrayMinimum(lows);
   m_res_val=highs[hi_idx];
   m_sup_val=lows[lo_idx];
   datetime hi_time=iTime(m_symbol,m_timeframe,hi_idx);
   datetime lo_time=iTime(m_symbol,m_timeframe,lo_idx);

   if(m_draw_res)
      DrawLine(m_obj_res,m_res_val,m_res_color,m_res_style,m_res_width);
   if(m_draw_sup)
      DrawLine(m_obj_sup,m_sup_val,m_sup_color,m_sup_style,m_sup_width);

   double close[];
   ArraySetAsSeries(close,true);
   if(CopyClose(m_symbol,m_alert_tf,0,2,close)>0)
     {
      m_breakup=(close[1]>m_res_val);
      m_breakdown=(close[1]<m_sup_val);
     }
   else
     {
      m_breakup=false;
      m_breakdown=false;
     }

   m_ready=true;
   return true;
  }

bool CSupRes::IsBreakdown(){ return m_breakdown; }
bool CSupRes::IsBreakup(){ return m_breakup; }

#endif // __SUP_RES_MQH__
