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
  string          m_obj_lta_ch;
  string          m_obj_ltb_ch;
  string          m_lbl_lta;
  string          m_lbl_ltb;

  int             m_breakout_confirm_bars;
  int             m_breakup_count;
  int             m_breakdown_count;
  bool            m_draw_channel;
  color           m_channel_color;
  ENUM_LINE_STYLE m_channel_style;
  int             m_channel_width;
  int             m_detail_bars;
  color           m_labels_color;
  int             m_labels_font_size;
  string          m_labels_font;

  // persistent buffers for price data
  double          m_highs[];
  double          m_lows[];
  double          m_opens[];
  double          m_closes[];

  // regression parameters
  double          m_lta_slope;
  double          m_lta_intercept;
  double          m_lta_stddev;
  double          m_ltb_slope;
  double          m_ltb_intercept;
  double          m_ltb_stddev;

   bool            CreateHandle();
   void            ReleaseHandle();
  void            DrawLines(datetime t1,double p1,datetime t2,double p2,
                             ENUM_TRENDLINE_SIDE side);
  void            CalculateRegression(const double &vals[],int bars,double &slope,
                                      double &intercept,double &stdev);

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
  bool            IsInsideChannel();
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
  m_obj_lta_ch="";
  m_obj_ltb_ch="";
  m_lbl_lta="";
  m_lbl_ltb="";
  m_breakout_confirm_bars=2;
  m_breakup_count=0;
  m_breakdown_count=0;
  m_draw_channel=false;
  m_channel_color=clrSilver;
  m_channel_style=STYLE_DOT;
  m_channel_width=1;
  m_detail_bars=10;
  m_labels_color=clrWhite;
  m_labels_font_size=8;
  m_labels_font="Arial";
  ArrayResize(m_highs,0);
  ArrayResize(m_lows,0);
  ArrayResize(m_opens,0);
  ArrayResize(m_closes,0);
  }

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTrendLine::~CTrendLine()
  {
  ReleaseHandle();
  if(StringLen(m_obj_lta)>0)
    {
     ObjectDelete(0,m_obj_lta);
     m_obj_lta="";
    }
  if(StringLen(m_obj_ltb)>0)
    {
     ObjectDelete(0,m_obj_ltb);
     m_obj_ltb="";
    }
  if(StringLen(m_obj_lta_ch)>0)
    {
     ObjectDelete(0,m_obj_lta_ch);
     m_obj_lta_ch="";
    }
  if(StringLen(m_obj_ltb_ch)>0)
    {
     ObjectDelete(0,m_obj_ltb_ch);
     m_obj_ltb_ch="";
    }
  if(StringLen(m_lbl_lta)>0)
    {
     ObjectDelete(0,m_lbl_lta);
     m_lbl_lta="";
    }
  if(StringLen(m_lbl_ltb)>0)
    {
     ObjectDelete(0,m_lbl_ltb);
     m_lbl_ltb="";
    }
  m_lta_val=0.0;
  m_ltb_val=0.0;
 }

//+------------------------------------------------------------------+
//| Create fractal handle                                             |
//+------------------------------------------------------------------+
bool CTrendLine::CreateHandle()
  {
   m_fractal_handle=INVALID_HANDLE;
   return true;
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
  m_breakout_confirm_bars=cfg.breakout_confirm_bars;
  m_draw_channel=cfg.draw_channel;
  m_channel_color=cfg.channel_color;
  m_channel_style=cfg.channel_style;
  m_channel_width=cfg.channel_width;
  m_detail_bars=cfg.detail_bars;
  m_labels_color=cfg.labels_color;
  m_labels_font_size=cfg.labels_font_size;
  m_labels_font=cfg.labels_font;
  m_breakup_count=0;
  m_breakdown_count=0;

   ReleaseHandle();
   bool ok=CreateHandle();
   if(ok)
     {
      string uid=IntegerToString(GetTickCount());
      m_obj_lta="TL_LTA_"+uid;
      m_obj_ltb="TL_LTB_"+uid;
      m_obj_lta_ch="TL_LTA_CH_"+uid;
      m_obj_ltb_ch="TL_LTB_CH_"+uid;
      m_lbl_lta="LBL_LTA_"+uid;
      m_lbl_ltb="LBL_LTB_"+uid;
     }
   int bars=m_period>0?m_period:50;
   ArrayResize(m_highs,bars);
   ArrayResize(m_lows,bars);
   ArrayResize(m_opens,bars);
   ArrayResize(m_closes,2); // only need last two closes
   ArraySetAsSeries(m_highs,true);
   ArraySetAsSeries(m_lows,true);
   ArraySetAsSeries(m_opens,true);
   ArraySetAsSeries(m_closes,true);
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
   return m_ready;
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
   bool exists=(ObjectFind(0,name)>=0);
   if(!exists)
      ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2);
   else
     {
      datetime ct1=ObjectGetInteger(0,name,OBJPROP_TIME,0);
      double   cp1=ObjectGetDouble(0,name,OBJPROP_PRICE,0);
      datetime ct2=ObjectGetInteger(0,name,OBJPROP_TIME,1);
      double   cp2=ObjectGetDouble(0,name,OBJPROP_PRICE,1);
      if(ct1!=t1 || cp1!=p1)
         ObjectMove(0,name,0,t1,p1);
      if(ct2!=t2 || cp2!=p2)
         ObjectMove(0,name,1,t2,p2);
     }
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,m_extend_right);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_STYLE,st);
  ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
  }

//+------------------------------------------------------------------+
//| Calculate linear regression parameters                            |
//+------------------------------------------------------------------+
void CTrendLine::CalculateRegression(const double &vals[],int bars,double &slope,
                                     double &intercept,double &stdev)
  {
   double sumx=0.0,sumy=0.0,sumxx=0.0,sumxy=0.0;
   for(int i=0;i<bars;i++)
     {
      double x=bars-1-i;
      double y=vals[i];
      sumx+=x;
      sumy+=y;
      sumxx+=x*x;
      sumxy+=x*y;
     }
   double denom=bars*sumxx-sumx*sumx;
   if(denom!=0.0)
      slope=(bars*sumxy-sumx*sumy)/denom;
   else
      slope=0.0;
   intercept=(sumy-slope*sumx)/bars;

   double res2=0.0;
   for(int j=0;j<bars;j++)
     {
      double x=bars-1-j;
      double pred=intercept+slope*x;
      double r=vals[j]-pred;
      res2+=r*r;
     }
   stdev=MathSqrt(res2/bars);
  }

//+------------------------------------------------------------------+
//| Update trend line values                                          |
//+------------------------------------------------------------------+
bool CTrendLine::Update()
  {
   int bars=m_period>0?m_period:50;

   double highs_reg[],lows_reg[];
   datetime times_reg[];
   ArraySetAsSeries(highs_reg,true);
   ArraySetAsSeries(lows_reg,true);
   ArraySetAsSeries(times_reg,true);

   if(CopyHigh(m_symbol,m_timeframe,0,bars,highs_reg)<=0)
      return m_ready;
   if(CopyLow(m_symbol,m_timeframe,0,bars,lows_reg)<=0)
      return m_ready;
   if(CopyTime(m_symbol,m_timeframe,0,bars,times_reg)<=0)
      return m_ready;

   CalculateRegression(lows_reg,bars,m_lta_slope,m_lta_intercept,m_lta_stddev);
   CalculateRegression(highs_reg,bars,m_ltb_slope,m_ltb_intercept,m_ltb_stddev);

   datetime t_old=times_reg[bars-1];
   datetime t_new=times_reg[0];
   double lta_old=m_lta_intercept;
   double lta_new=m_lta_intercept+m_lta_slope*(bars-1);
   double ltb_old=m_ltb_intercept;
   double ltb_new=m_ltb_intercept+m_ltb_slope*(bars-1);

   m_lta_val=lta_new;
   m_ltb_val=ltb_new;

   if(m_draw_lta)
      DrawLines(t_old,lta_old,t_new,lta_new,TRENDLINE_LTA);
   if(m_draw_ltb)
      DrawLines(t_old,ltb_old,t_new,ltb_new,TRENDLINE_LTB);

   if(m_draw_channel)
     {
      string obj=m_obj_lta_ch;
      double ch_old=lta_old+m_lta_stddev;
      double ch_new=lta_new+m_lta_stddev;
      bool ex=(ObjectFind(0,obj)>=0);
      if(!ex)
         ObjectCreate(0,obj,OBJ_TREND,0,t_old,ch_old,t_new,ch_new);
      else
        {
         datetime ot1=ObjectGetInteger(0,obj,OBJPROP_TIME,0);
         double   op1=ObjectGetDouble(0,obj,OBJPROP_PRICE,0);
         datetime ot2=ObjectGetInteger(0,obj,OBJPROP_TIME,1);
         double   op2=ObjectGetDouble(0,obj,OBJPROP_PRICE,1);
         if(ot1!=t_old || op1!=ch_old)
            ObjectMove(0,obj,0,t_old,ch_old);
         if(ot2!=t_new || op2!=ch_new)
            ObjectMove(0,obj,1,t_new,ch_new);
        }
      ObjectSetInteger(0,obj,OBJPROP_COLOR,m_channel_color);
      ObjectSetInteger(0,obj,OBJPROP_STYLE,m_channel_style);
      ObjectSetInteger(0,obj,OBJPROP_WIDTH,m_channel_width);
      ObjectSetInteger(0,obj,OBJPROP_RAY_RIGHT,m_extend_right);

      obj=m_obj_ltb_ch;
      ch_old=ltb_old-m_ltb_stddev;
      ch_new=ltb_new-m_ltb_stddev;
      ex=(ObjectFind(0,obj)>=0);
      if(!ex)
         ObjectCreate(0,obj,OBJ_TREND,0,t_old,ch_old,t_new,ch_new);
      else
        {
         datetime ot3=ObjectGetInteger(0,obj,OBJPROP_TIME,0);
         double   op3=ObjectGetDouble(0,obj,OBJPROP_PRICE,0);
         datetime ot4=ObjectGetInteger(0,obj,OBJPROP_TIME,1);
         double   op4=ObjectGetDouble(0,obj,OBJPROP_PRICE,1);
         if(ot3!=t_old || op3!=ch_old)
            ObjectMove(0,obj,0,t_old,ch_old);
         if(ot4!=t_new || op4!=ch_new)
            ObjectMove(0,obj,1,t_new,ch_new);
        }
      ObjectSetInteger(0,obj,OBJPROP_COLOR,m_channel_color);
      ObjectSetInteger(0,obj,OBJPROP_STYLE,m_channel_style);
      ObjectSetInteger(0,obj,OBJPROP_WIDTH,m_channel_width);
      ObjectSetInteger(0,obj,OBJPROP_RAY_RIGHT,m_extend_right);
     }

   datetime ct[];
   ArrayResize(ct,2);
   ArraySetAsSeries(ct,true);

  if(CopyHigh(m_symbol,m_alert_tf,0,2,m_highs)<=0)
     return m_ready;
  if(CopyLow(m_symbol,m_alert_tf,0,2,m_lows)<=0)
     return m_ready;
  if(CopyClose(m_symbol,m_alert_tf,0,2,m_closes)<=0)
     return m_ready;
  if(CopyTime(m_symbol,m_alert_tf,0,2,ct)<=0)
     return m_ready;

  double sup=GetLTAValue(1);
  double res=GetLTBValue(1);


  if(m_closes[1]<sup)
     m_breakdown_count++;
  else
     m_breakdown_count=0;
  if(m_closes[1]>res)
     m_breakup_count++;
  else
     m_breakup_count=0;

  m_breakdown=(m_breakdown_count>=m_breakout_confirm_bars);
  m_breakup=(m_breakup_count>=m_breakout_confirm_bars);

  if(m_show_labels)
    {
     string text="LTA";
     if(ObjectFind(0,m_lbl_lta)<0)
        ObjectCreate(0,m_lbl_lta,OBJ_TEXT,0,t_new,lta_new);
     else
       {
        datetime lt=(datetime)ObjectGetInteger(0,m_lbl_lta,OBJPROP_TIME);
        double   lp=ObjectGetDouble(0,m_lbl_lta,OBJPROP_PRICE);
        if(lt!=t_new || lp!=lta_new)
           ObjectMove(0,m_lbl_lta,0,t_new,lta_new);
       }
     ObjectSetString(0,m_lbl_lta,OBJPROP_TEXT,text);
     ObjectSetInteger(0,m_lbl_lta,OBJPROP_COLOR,m_labels_color);
     ObjectSetInteger(0,m_lbl_lta,OBJPROP_FONTSIZE,m_labels_font_size);
     ObjectSetString(0,m_lbl_lta,OBJPROP_FONT,m_labels_font);

     string text2="LTB";
     if(ObjectFind(0,m_lbl_ltb)<0)
        ObjectCreate(0,m_lbl_ltb,OBJ_TEXT,0,t_new,ltb_new);
     else
       {
        datetime lt2=(datetime)ObjectGetInteger(0,m_lbl_ltb,OBJPROP_TIME);
        double   lp2=ObjectGetDouble(0,m_lbl_ltb,OBJPROP_PRICE);
        if(lt2!=t_new || lp2!=ltb_new)
           ObjectMove(0,m_lbl_ltb,0,t_new,ltb_new);
       }
     ObjectSetString(0,m_lbl_ltb,OBJPROP_TEXT,text2);
     ObjectSetInteger(0,m_lbl_ltb,OBJPROP_COLOR,m_labels_color);
     ObjectSetInteger(0,m_lbl_ltb,OBJPROP_FONTSIZE,m_labels_font_size);
     ObjectSetString(0,m_lbl_ltb,OBJPROP_FONT,m_labels_font);
    }
  m_ready=true;
  return m_ready;
}

//+------------------------------------------------------------------+
//| LTA value                                                         |
//+------------------------------------------------------------------+
double CTrendLine::GetLTAValue(int shift)
  {
   int bars=m_period>0?m_period:50;
   double x=bars-1-shift;
   return m_lta_intercept+m_lta_slope*x;
  }

//+------------------------------------------------------------------+
//| LTB value                                                         |
//+------------------------------------------------------------------+
double CTrendLine::GetLTBValue(int shift)
  {
   int bars=m_period>0?m_period:50;
   double x=bars-1-shift;
   return m_ltb_intercept+m_ltb_slope*x;
  }

//+------------------------------------------------------------------+
//| Valid flags                                                       |
//+------------------------------------------------------------------+
bool CTrendLine::IsLTAValid(){ return m_lta_val!=0.0; }
bool CTrendLine::IsLTBValid(){ return m_ltb_val!=0.0; }
bool CTrendLine::IsBreakdown(){ return m_breakdown; }
bool CTrendLine::IsBreakup(){ return m_breakup; }

bool CTrendLine::IsInsideChannel()
  {
   datetime t=iTime(m_symbol,m_alert_tf,0);
   double price=iClose(m_symbol,m_alert_tf,0);
   double upper=0.0,lower=0.0;
   if(ObjectFind(0,m_obj_ltb_ch)>=0)
      upper=ObjectGetValueByTime(0,m_obj_ltb_ch,t);
   if(ObjectFind(0,m_obj_lta)>=0)
      lower=ObjectGetValueByTime(0,m_obj_lta,t);
   if(upper==0.0 || lower==0.0)
      return false;
   return(price<=upper && price>=lower);
  }

#endif // __TRENDLINE_MQH__
