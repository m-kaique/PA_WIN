//+------------------------------------------------------------------+
//|                                                trendline.mqh     |
//|  Trend line price action                                         |
//+------------------------------------------------------------------+
#ifndef __TRENDLINE_MQH__
#define __TRENDLINE_MQH__

#include "../priceaction_base.mqh"
#include "trendline_defs.mqh"
#include "../../config_types.mqh"

class CTrendLine : public CPriceActionBase
  {
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int             m_period;
   int             m_left;
   int             m_right;
   bool            m_draw_lta;
   bool            m_draw_ltb;
   color           m_lta_color;
   color           m_ltb_color;
   ENUM_LINE_STYLE m_lta_style;
   ENUM_LINE_STYLE m_ltb_style;
   int             m_lta_width;
   int             m_ltb_width;
   bool            m_extend_right;
  bool            m_show_labels;
  ENUM_TIMEFRAMES m_fractal_tf;
  ENUM_TIMEFRAMES m_detail_tf;
  ENUM_TIMEFRAMES m_alert_tf;
  bool            m_breakdown;
  bool            m_breakup;

   int             m_fractal_handle;
   bool            m_ready;
   double          m_lta_val;
   double          m_ltb_val;

   string          m_obj_lta;
   string          m_obj_ltb;

   bool            CreateHandle();
   void            ReleaseHandle();
   void            DrawLines(datetime t1,double p1,datetime t2,double p2,
                             ENUM_TRENDLINE_SIDE side);

public:
                     CTrendLine();
                    ~CTrendLine();

   bool            Init(string symbol,ENUM_TIMEFRAMES timeframe,CTrendLineConfig &cfg);
   virtual bool    Init(string symbol,ENUM_TIMEFRAMES timeframe,int period);
   virtual double  GetValue(int shift=0); // returns LTA value
   virtual bool    CopyValues(int shift,int count,double &buffer[]);
   virtual bool    IsReady();
   virtual bool    Update();

   double          GetLTAValue(int shift=0);
   double          GetLTBValue(int shift=0);
  bool            IsLTAValid();
  bool            IsLTBValid();
  bool            IsBreakdown();
  bool            IsBreakup();
  };

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTrendLine::CTrendLine()
  {
   m_symbol="";
   m_timeframe=PERIOD_CURRENT;
   m_period=20;
   m_left=3;
   m_right=3;
   m_draw_lta=true;
   m_draw_ltb=true;
   m_lta_color=clrGreen;
   m_ltb_color=clrRed;
   m_lta_style=STYLE_SOLID;
   m_ltb_style=STYLE_SOLID;
   m_lta_width=1;
   m_ltb_width=1;
   m_extend_right=true;
   m_show_labels=false;
   m_fractal_tf=PERIOD_H4;
   m_detail_tf=PERIOD_H1;
   m_alert_tf=PERIOD_H1;
   m_breakdown=false;
   m_breakup=false;
   m_fractal_handle=INVALID_HANDLE;
   m_ready=false;
   m_lta_val=0.0;
   m_ltb_val=0.0;
   m_obj_lta="";
   m_obj_ltb="";
  }

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTrendLine::~CTrendLine()
  {
   ReleaseHandle();
   if(StringLen(m_obj_lta)>0) ObjectDelete(0,m_obj_lta);
   if(StringLen(m_obj_ltb)>0) ObjectDelete(0,m_obj_ltb);
  }

//+------------------------------------------------------------------+
//| Create fractal handle                                             |
//+------------------------------------------------------------------+
bool CTrendLine::CreateHandle()
  {
  m_fractal_handle=iFractals(m_symbol,m_fractal_tf);
   return(m_fractal_handle!=INVALID_HANDLE);
  }

//+------------------------------------------------------------------+
//| Release handle                                                    |
//+------------------------------------------------------------------+
void CTrendLine::ReleaseHandle()
  {
   if(m_fractal_handle!=INVALID_HANDLE)
     {
      IndicatorRelease(m_fractal_handle);
      m_fractal_handle=INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Init using config                                                 |
//+------------------------------------------------------------------+
bool CTrendLine::Init(string symbol,ENUM_TIMEFRAMES timeframe,CTrendLineConfig &cfg)
  {
   m_symbol=symbol;
   m_timeframe=timeframe;
   m_period=cfg.period;
   m_left=cfg.left;
   m_right=cfg.right;
   m_draw_lta=cfg.draw_lta;
   m_draw_ltb=cfg.draw_ltb;
   m_lta_color=cfg.lta_color;
   m_ltb_color=cfg.ltb_color;
  m_lta_style=cfg.lta_style;
  m_ltb_style=cfg.ltb_style;
  m_lta_width=cfg.lta_width;
  m_ltb_width=cfg.ltb_width;
  m_extend_right=cfg.extend_right;
  m_show_labels=cfg.show_labels;
  m_fractal_tf=cfg.fractal_tf;
  m_detail_tf=cfg.detail_tf;
  m_alert_tf=cfg.alert_tf;

   ReleaseHandle();
   bool ok=CreateHandle();
   if(ok)
     {
      m_obj_lta="TL_LTA_"+IntegerToString(GetTickCount());
      m_obj_ltb="TL_LTB_"+IntegerToString(GetTickCount());
     }
   return ok;
  }

//+------------------------------------------------------------------+
//| Default init                                                      |
//+------------------------------------------------------------------+
bool CTrendLine::Init(string symbol,ENUM_TIMEFRAMES timeframe,int period)
  {
   CTrendLineConfig tmp;
   tmp.period=period;
   return Init(symbol,timeframe,tmp);
  }

//+------------------------------------------------------------------+
//| GetValue (LTA)                                                    |
//+------------------------------------------------------------------+
double CTrendLine::GetValue(int shift)
  {
   return GetLTAValue(shift);
  }

//+------------------------------------------------------------------+
//| CopyValues                                                        |
//+------------------------------------------------------------------+
bool CTrendLine::CopyValues(int shift,int count,double &buffer[])
  {
   ArrayResize(buffer,count);
   for(int i=0;i<count;i++)
      buffer[i]=GetValue(shift+i);
   return true;
  }

//+------------------------------------------------------------------+
//| Ready                                                             |
//+------------------------------------------------------------------+
bool CTrendLine::IsReady()
  {
   return(m_fractal_handle!=INVALID_HANDLE && m_ready);
  }

//+------------------------------------------------------------------+
//| Draw trend line                                                   |
//+------------------------------------------------------------------+
void CTrendLine::DrawLines(datetime t1,double p1,datetime t2,double p2,ENUM_TRENDLINE_SIDE side)
  {
   string name=(side==TRENDLINE_LTA)?m_obj_lta:m_obj_ltb;
   color col=(side==TRENDLINE_LTA)?m_lta_color:m_ltb_color;
   ENUM_LINE_STYLE st=(side==TRENDLINE_LTA)?m_lta_style:m_ltb_style;
   int width=(side==TRENDLINE_LTA)?m_lta_width:m_ltb_width;
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2);
   else
      ObjectMove(0,name,0,t1,p1);
   ObjectMove(0,name,1,t2,p2);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,m_extend_right);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_STYLE,st);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
  }

//+------------------------------------------------------------------+
//| Update trend line values                                          |
//+------------------------------------------------------------------+
bool CTrendLine::Update()
  {
   if(m_fractal_handle==INVALID_HANDLE)
      return false;

   int bars=m_period>0?m_period:50;
   double up[],down[];
   ArraySetAsSeries(up,true);
   ArraySetAsSeries(down,true);
   if(CopyBuffer(m_fractal_handle,0,0,bars,up)<=0)
      return false;
   if(CopyBuffer(m_fractal_handle,1,0,bars,down)<=0)
      return false;

   int up1=-1,up2=-1,lo1=-1,lo2=-1;
   for(int i=m_left;i<bars;i++)
     if(up[i]!=EMPTY_VALUE){ up1=i; break; }
   for(int i=up1+1;i<bars;i++)
     if(up[i]!=EMPTY_VALUE){ up2=i; break; }
   for(int i=m_left;i<bars;i++)
     if(down[i]!=EMPTY_VALUE){ lo1=i; break; }
   for(int i=lo1+1;i<bars;i++)
     if(down[i]!=EMPTY_VALUE){ lo2=i; break; }

   m_ready=false;
   if(up1>0 && up2>0)
     {
      datetime t1=iTime(m_symbol,m_fractal_tf,up1);
      datetime t2=iTime(m_symbol,m_fractal_tf,up2);
      double p1=up[up1];
      double p2=up[up2];
      m_ltb_val=p1 + (p1-p2)/(t1-t2)*(t1-iTime(m_symbol,m_fractal_tf,0));
      if(m_draw_ltb)
         DrawLines(t2,p2,t1,p1,TRENDLINE_LTB);
      m_ready=true;
     }
  if(lo1>0 && lo2>0)
    {
      datetime t1=iTime(m_symbol,m_fractal_tf,lo1);
      datetime t2=iTime(m_symbol,m_fractal_tf,lo2);
      double p1=down[lo1];
      double p2=down[lo2];
      m_lta_val=p1 + (p1-p2)/(t1-t2)*(t1-iTime(m_symbol,m_fractal_tf,0));
      if(m_draw_lta)
         DrawLines(t2,p2,t1,p1,TRENDLINE_LTA);
      m_ready=true;
    }

  double close[];       // Dynamic array
  datetime ct[];        // Dynamic array
  ArrayResize(close, 2);
  ArrayResize(ct, 2);
  ArraySetAsSeries(close, true);
  ArraySetAsSeries(ct, true);
  
  if(CopyClose(m_symbol,m_alert_tf,0,2,close)>0 &&
     CopyTime(m_symbol,m_alert_tf,0,2,ct)>0)
    {
     double sup=ObjectGetValueByTime(0,m_obj_lta,ct[1]);
     double res=ObjectGetValueByTime(0,m_obj_ltb,ct[1]);
     m_breakdown=(close[1]<sup);
     m_breakup=(close[1]>res);
    }
  return m_ready;
 }

//+------------------------------------------------------------------+
//| LTA value                                                         |
//+------------------------------------------------------------------+
double CTrendLine::GetLTAValue(int shift)
  {
   if(shift==0)
      return m_lta_val;
   datetime t=iTime(m_symbol,m_alert_tf,shift);
   if(t==0) return 0.0;
   double val=ObjectGetValueByTime(0,m_obj_lta,t);
   return val;
  }

//+------------------------------------------------------------------+
//| LTB value                                                         |
//+------------------------------------------------------------------+
double CTrendLine::GetLTBValue(int shift)
  {
   if(shift==0)
      return m_ltb_val;
   datetime t=iTime(m_symbol,m_alert_tf,shift);
   if(t==0) return 0.0;
   double val=ObjectGetValueByTime(0,m_obj_ltb,t);
   return val;
  }

//+------------------------------------------------------------------+
//| Valid flags                                                       |
//+------------------------------------------------------------------+
bool CTrendLine::IsLTAValid(){ return (m_lta_val!=0.0); }
bool CTrendLine::IsLTBValid(){ return (m_ltb_val!=0.0); }
bool CTrendLine::IsBreakdown(){ return m_breakdown; }
bool CTrendLine::IsBreakup(){ return m_breakup; }

#endif // __TRENDLINE_MQH__
