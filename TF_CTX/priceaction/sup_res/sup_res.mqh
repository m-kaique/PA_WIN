//+------------------------------------------------------------------+
//|                                                sup_res.mqh       |
//|  Simple support and resistance lines                             |
//+------------------------------------------------------------------+
#ifndef __SUP_RES_MQH__
#define __SUP_RES_MQH__

#include "../priceaction_base.mqh"
#include "sup_res_defs.mqh"
#include "../../config_types.mqh"

// Structure representing a support/resistance zone
struct SRZone
  {
   double upper;   // upper price limit of the zone
   double lower;   // lower price limit of the zone
   int    touches; // number of touches inside the zone
  };

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
  int             m_touch_lookback;
  double          m_touch_tolerance;
  double          m_zone_range;      // max range to group touches as one zone
  int             m_min_touches;
  ENUM_SUPRES_VALIDATION m_validation;
  bool            m_sup_valid;
  bool            m_res_valid;
  bool            m_ready;
  double          m_sup_val;
  double          m_res_val;
  bool            m_breakdown;
  bool            m_breakup;
  string          m_obj_sup;
  string          m_obj_res;
  string          m_obj_sup_zone;
  string          m_obj_res_zone;
  SRZone          m_sup_zone;
  SRZone          m_res_zone;

  void            DrawLine(string name,double price,color col,ENUM_LINE_STYLE st,int width);
  void            DrawZone(string name,double lower,double upper,color col);
  void            CalculateZone(const double &src[],int bars,double range,bool is_support,SRZone &zone);
  bool            IsBullPinBar(const double &o[],const double &c[],const double &h[],const double &l[],int index);
  bool            IsBearPinBar(const double &o[],const double &c[],const double &h[],const double &l[],int index);
  bool            IsBullEngulf(const double &o[],const double &c[],int index);
  bool            IsBearEngulf(const double &o[],const double &c[],int index);
  bool            IsDoji(const double &o[],const double &c[],const double &h[],const double &l[],int index);
  bool            IsBullMarubozu(const double &o[],const double &c[],const double &h[],const double &l[],int index);
  bool            IsBearMarubozu(const double &o[],const double &c[],const double &h[],const double &l[],int index);
  bool            IsInsideBar(const double &h[],const double &l[],int index);
  bool            IsOutsideBar(const double &h[],const double &l[],int index);

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

  // Counters for touches and patterns
  int             m_sup_touches;
  int             m_res_touches;
  int             m_sup_pinbar;
  int             m_res_pinbar;
  int             m_sup_engulf;
  int             m_res_engulf;
  int             m_sup_doji;
  int             m_res_doji;
  int             m_sup_maru_bull;
  int             m_res_maru_bull;
  int             m_sup_maru_bear;
  int             m_res_maru_bear;
  int             m_sup_insidebar;
  int             m_res_insidebar;
  int             m_sup_outsidebar;
  int             m_res_outsidebar;
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
  m_touch_lookback=20;
  m_touch_tolerance=0.0;
  m_zone_range=10.0;
  m_min_touches=2;
  m_validation=SUPRES_VALIDATE_TOUCHES;
  m_sup_touches=0;
  m_res_touches=0;
  m_sup_pinbar=0;
  m_res_pinbar=0;
  m_sup_engulf=0;
  m_res_engulf=0;
  m_sup_doji=0;
  m_res_doji=0;
  m_sup_maru_bull=0;
  m_res_maru_bull=0;
  m_sup_maru_bear=0;
  m_res_maru_bear=0;
  m_sup_insidebar=0;
  m_res_insidebar=0;
  m_sup_outsidebar=0;
  m_res_outsidebar=0;
  m_sup_valid=false;
  m_res_valid=false;
  m_ready=false;
   m_sup_val=0.0;
   m_res_val=0.0;
  m_breakdown=false;
  m_breakup=false;
  m_obj_sup="";
  m_obj_res="";
  m_obj_sup_zone="";
  m_obj_res_zone="";
  m_sup_zone.touches=0; m_sup_zone.lower=0; m_sup_zone.upper=0;
  m_res_zone.touches=0; m_res_zone.lower=0; m_res_zone.upper=0;
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
  if(StringLen(m_obj_sup_zone)>0)
     ObjectDelete(0,m_obj_sup_zone);
  if(StringLen(m_obj_res_zone)>0)
     ObjectDelete(0,m_obj_res_zone);
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
//| Draw support/resistance zone                                      |
//+------------------------------------------------------------------+
void CSupRes::DrawZone(string name,double lower,double upper,color col)
  {
   datetime t1=iTime(m_symbol,m_timeframe,m_period-1);
   datetime t2=iTime(m_symbol,m_timeframe,0);
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,lower,t2,upper);
   else
     {
      ObjectMove(0,name,0,t1,lower);
      ObjectMove(0,name,1,t2,upper);
     }
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
  }

//+------------------------------------------------------------------+
//| Check for bullish pin bar (hammer)                                |
//+------------------------------------------------------------------+
bool CSupRes::IsBullPinBar(const double &o[],const double &c[],const double &h[],const double &l[],int index)
  {
   double body=MathAbs(o[index]-c[index]);
   double upper=h[index]-MathMax(o[index],c[index]);
   double lower=MathMin(o[index],c[index])-l[index];
   return(lower>body*2 && upper<body);
  }

//+------------------------------------------------------------------+
//| Check for bearish pin bar (shooting star)                         |
//+------------------------------------------------------------------+
bool CSupRes::IsBearPinBar(const double &o[],const double &c[],const double &h[],const double &l[],int index)
  {
   double body=MathAbs(o[index]-c[index]);
   double upper=h[index]-MathMax(o[index],c[index]);
   double lower=MathMin(o[index],c[index])-l[index];
   return(upper>body*2 && lower<body);
  }

//+------------------------------------------------------------------+
//| Check for bullish engulfing                                       |
//+------------------------------------------------------------------+
bool CSupRes::IsBullEngulf(const double &o[],const double &c[],int index)
  {
   if(index+1>=ArraySize(o))
      return false;
   double o1=o[index+1];
   double c1=c[index+1];
   double o2=o[index];
   double c2=c[index];
   return(c1<o1 && c2>o2 && c2>o1 && o2<c1);
  }

//+------------------------------------------------------------------+
//| Check for bearish engulfing                                       |
//+------------------------------------------------------------------+
bool CSupRes::IsBearEngulf(const double &o[],const double &c[],int index)
  {
   if(index+1>=ArraySize(o))
      return false;
   double o1=o[index+1];
   double c1=c[index+1];
   double o2=o[index];
   double c2=c[index];
   return(c1>o1 && c2<o2 && c2<o1 && o2>c1);
  }

//+------------------------------------------------------------------+
//| Check for doji                                                    |
//+------------------------------------------------------------------+
bool CSupRes::IsDoji(const double &o[],const double &c[],const double &h[],const double &l[],int index)
  {
   double range=h[index]-l[index];
   if(range==0.0) return false;
   double body=MathAbs(o[index]-c[index]);
   return(body<=range*0.1);
  }

//+------------------------------------------------------------------+
//| Check for bullish marubozu                                        |
//+------------------------------------------------------------------+
bool CSupRes::IsBullMarubozu(const double &o[],const double &c[],const double &h[],const double &l[],int index)
  {
   double body=c[index]-o[index];
   double upper=h[index]-c[index];
   double lower=o[index]-l[index];
   return(body>0 && upper<=body*0.1 && lower<=body*0.1);
  }

//+------------------------------------------------------------------+
//| Check for bearish marubozu                                        |
//+------------------------------------------------------------------+
bool CSupRes::IsBearMarubozu(const double &o[],const double &c[],const double &h[],const double &l[],int index)
  {
   double body=o[index]-c[index];
   double upper=h[index]-o[index];
   double lower=c[index]-l[index];
   return(body>0 && upper<=body*0.1 && lower<=body*0.1);
  }

//+------------------------------------------------------------------+
//| Check for inside bar                                              |
//+------------------------------------------------------------------+
bool CSupRes::IsInsideBar(const double &h[],const double &l[],int index)
  {
   if(index+1>=ArraySize(h))
      return false;
   return(h[index]<h[index+1] && l[index]>l[index+1]);
  }

//+------------------------------------------------------------------+
//| Check for outside bar                                             |
//+------------------------------------------------------------------+
bool CSupRes::IsOutsideBar(const double &h[],const double &l[],int index)
  {
   if(index+1>=ArraySize(h))
      return false;
   return(h[index]>h[index+1] && l[index]<l[index+1]);
  }

//+------------------------------------------------------------------+
//| Calculate zone from price array                                   |
//+------------------------------------------------------------------+
void CSupRes::CalculateZone(const double &src[],int bars,double range,bool is_support,SRZone &zone)
  {
   SRZone zones[];
   ArrayResize(zones,0);

   // Agrupa preços iniciais em zonas considerando o range
   for(int i=1;i<bars;i++)
     {
      double price=src[i];
      bool added=false;
      for(int j=0;j<ArraySize(zones);j++)
        {
         if(price>=zones[j].lower-range && price<=zones[j].upper+range)
           {
            if(price<zones[j].lower) zones[j].lower=price;
            if(price>zones[j].upper) zones[j].upper=price;
            zones[j].touches++;
            added=true;
            break;
           }
        }
      if(!added)
        {
         int pos=ArraySize(zones);
         ArrayResize(zones,pos+1);
         zones[pos].lower=price;
         zones[pos].upper=price;
         zones[pos].touches=1;
        }
     }

   // Mescla zonas sobrepostas somando seus toques
   bool merged=true;
   while(merged)
     {
      merged=false;
      for(int i=0;i<ArraySize(zones);i++)
        {
         for(int j=i+1;j<ArraySize(zones);j++)
           {
            if(zones[i].upper>=zones[j].lower && zones[i].lower<=zones[j].upper)
              {
               zones[i].lower=MathMin(zones[i].lower,zones[j].lower);
               zones[i].upper=MathMax(zones[i].upper,zones[j].upper);
               zones[i].touches+=zones[j].touches;
               for(int k=j;k<ArraySize(zones)-1;k++)
                  zones[k]=zones[k+1];
               ArrayResize(zones,ArraySize(zones)-1);
               merged=true;
               j--; // voltar um passo pois os índices mudaram
              }
           }
        }
     }

   // Seleciona a zona com mais toques
   int best=-1;
   for(int j=0;j<ArraySize(zones);j++)
     {
      if(best==-1 || zones[j].touches>zones[best].touches ||
         (zones[j].touches==zones[best].touches &&
          ((is_support && zones[j].lower<zones[best].lower) || (!is_support && zones[j].upper>zones[best].upper))))
           best=j;
     }

   if(best>=0)
     zone=zones[best];
   else
     {
      zone.lower=0; zone.upper=0; zone.touches=0;
     }
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
  m_touch_lookback=cfg.touch_lookback;
  m_touch_tolerance=cfg.touch_tolerance;
  m_zone_range=cfg.zone_range;
  m_min_touches=cfg.min_touches;
  m_validation=cfg.validation;
  m_sup_touches=0;
  m_res_touches=0;
  m_sup_pinbar=0;
  m_res_pinbar=0;
  m_sup_engulf=0;
  m_res_engulf=0;
  m_sup_doji=0;
  m_res_doji=0;
  m_sup_maru_bull=0;
  m_res_maru_bull=0;
  m_sup_maru_bear=0;
  m_res_maru_bear=0;
  m_sup_insidebar=0;
  m_res_insidebar=0;
  m_sup_outsidebar=0;
  m_res_outsidebar=0;
  m_sup_valid=false;
  m_res_valid=false;

  m_obj_sup="SR_SUP_"+IntegerToString(GetTickCount());
  m_obj_res="SR_RES_"+IntegerToString(GetTickCount());
  m_obj_sup_zone="SR_SUP_ZONE_"+IntegerToString(GetTickCount());
  m_obj_res_zone="SR_RES_ZONE_"+IntegerToString(GetTickCount());

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
   return m_sup_val; // for older interface shift ignored
  }

//+------------------------------------------------------------------+
//| Resistance value                                                  |
//+------------------------------------------------------------------+
double CSupRes::GetResistanceValue(int shift)
  {
   if(shift==0)
      return m_res_val;
   return m_res_val; // shift ignored with zones
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
   double highs[],lows[],opens[],closes[];
   ArraySetAsSeries(highs,true);
   ArraySetAsSeries(lows,true);
   ArraySetAsSeries(opens,true);
   ArraySetAsSeries(closes,true);
   if(CopyHigh(m_symbol,m_timeframe,0,bars,highs)<=0)
      return false;
   if(CopyLow(m_symbol,m_timeframe,0,bars,lows)<=0)
      return false;
   if(CopyOpen(m_symbol,m_timeframe,0,bars,opens)<=0)
      return false;
   if(CopyClose(m_symbol,m_timeframe,0,bars,closes)<=0)
      return false;

  int hi_idx=ArrayMaximum(highs);
  int lo_idx=ArrayMinimum(lows);
  CalculateZone(highs,bars,m_zone_range,false,m_res_zone);
  CalculateZone(lows,bars,m_zone_range,true,m_sup_zone);
  m_res_val=m_res_zone.upper;
  m_sup_val=m_sup_zone.lower;
 datetime hi_time=iTime(m_symbol,m_timeframe,hi_idx);
 datetime lo_time=iTime(m_symbol,m_timeframe,lo_idx);

 if(m_draw_res)
    DrawZone(m_obj_res_zone,m_res_zone.lower,m_res_zone.upper,m_res_color);
 if(m_draw_sup)
    DrawZone(m_obj_sup_zone,m_sup_zone.lower,m_sup_zone.upper,m_sup_color);

  // reset counters
  m_sup_touches=0;
  m_res_touches=0;
  m_sup_pinbar=0;
  m_res_pinbar=0;
  m_sup_engulf=0;
  m_res_engulf=0;
  m_sup_doji=0;
  m_res_doji=0;
  m_sup_maru_bull=0;
  m_res_maru_bull=0;
  m_sup_maru_bear=0;
  m_res_maru_bear=0;
  m_sup_insidebar=0;
  m_res_insidebar=0;
  m_sup_outsidebar=0;
  m_res_outsidebar=0;

  int lookback=MathMin(m_touch_lookback,bars-1);
  for(int i=1;i<=lookback;i++)
    {
     bool sup_touch=(highs[i]>=m_sup_zone.lower-m_touch_tolerance && lows[i]<=m_sup_zone.upper+m_touch_tolerance);
     bool res_touch=(highs[i]>=m_res_zone.lower-m_touch_tolerance && lows[i]<=m_res_zone.upper+m_touch_tolerance);
     if(sup_touch)
       {
        m_sup_touches++;
        if(IsBullPinBar(opens,closes,highs,lows,i))   m_sup_pinbar++;
        if(IsBullEngulf(opens,closes,i))              m_sup_engulf++;
        if(IsDoji(opens,closes,highs,lows,i))         m_sup_doji++;
        if(IsBullMarubozu(opens,closes,highs,lows,i)) m_sup_maru_bull++;
        if(IsBearMarubozu(opens,closes,highs,lows,i)) m_sup_maru_bear++;
        if(IsInsideBar(highs,lows,i))                 m_sup_insidebar++;
        if(IsOutsideBar(highs,lows,i))                m_sup_outsidebar++;
       }
     if(res_touch)
       {
        m_res_touches++;
        if(IsBearPinBar(opens,closes,highs,lows,i))   m_res_pinbar++;
        if(IsBearEngulf(opens,closes,i))              m_res_engulf++;
        if(IsDoji(opens,closes,highs,lows,i))         m_res_doji++;
        if(IsBullMarubozu(opens,closes,highs,lows,i)) m_res_maru_bull++;
        if(IsBearMarubozu(opens,closes,highs,lows,i)) m_res_maru_bear++;
        if(IsInsideBar(highs,lows,i))                 m_res_insidebar++;
        if(IsOutsideBar(highs,lows,i))                m_res_outsidebar++;
       }
    }

  m_sup_valid=true;
  m_res_valid=true;
  if(m_validation==SUPRES_VALIDATE_TOUCHES)
    {
     m_sup_valid=(m_sup_touches>=m_min_touches);
     m_res_valid=(m_res_touches>=m_min_touches);
    }
  else if(m_validation==SUPRES_VALIDATE_PATTERNS)
    {
     int sup_pat=m_sup_pinbar+m_sup_engulf+m_sup_doji+m_sup_maru_bull+m_sup_maru_bear+m_sup_insidebar+m_sup_outsidebar;
     int res_pat=m_res_pinbar+m_res_engulf+m_res_doji+m_res_maru_bull+m_res_maru_bear+m_res_insidebar+m_res_outsidebar;
     m_sup_valid=(sup_pat>0);
     m_res_valid=(res_pat>0);
    }
  else if(m_validation==SUPRES_VALIDATE_BOTH)
    {
     int sup_pat=m_sup_pinbar+m_sup_engulf+m_sup_doji+m_sup_maru_bull+m_sup_maru_bear+m_sup_insidebar+m_sup_outsidebar;
     int res_pat=m_res_pinbar+m_res_engulf+m_res_doji+m_res_maru_bull+m_res_maru_bear+m_res_insidebar+m_res_outsidebar;
     m_sup_valid=(m_sup_touches>=m_min_touches && sup_pat>0);
     m_res_valid=(m_res_touches>=m_min_touches && res_pat>0);
    }

   double close[];
   ArraySetAsSeries(close,true);
   if(CopyClose(m_symbol,m_alert_tf,0,2,close)>0)
     {
      m_breakup=(close[1]>m_res_zone.upper);
      m_breakdown=(close[1]<m_sup_zone.lower);
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
